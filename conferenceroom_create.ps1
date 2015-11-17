# & 'C:\Program Files\Microsoft\Exchange Server\V14\bin\RemoteExchange.ps1'
#Connect-ExchangeServer -server SVREXCH01
# sleep 5
add-pssnapin quest.activeroles.admanagement
connect-QADService -service 'SRVDC01.contoso.com'
Start-FFBExchangeAdmin

cls
Write-Host "============ Create new Conference Room ============" -foregroundcolor Cyan
$Mboxname = Read-Host "Conference Room Alias (Conf_SITECODE.Name) NO SPACES! "
## check if only letters were used 
$regex = "^([a-zA-Z0-9_/.]+)$" ## only text, no spaces, no numbers 
If ($Mboxname -notmatch $regex) { 
      Write-Host "Invalid Alias specified. $Mboxname" -foregroundcolor Red 
      break 
} 
## Check if there's already a user with this samAccountName 
$dom = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain() 
$domainnb = "hq.first.int" 
$root = $dom.GetDirectoryEntry()  
$search = [System.DirectoryServices.DirectorySearcher]$root 
$search.Filter = "(samAccountName=$Mboxname)" 
$result = $search.FindOne()  
if ($result -ne $null) { 
      $user = $result.GetDirectoryEntry() 
      Write-Host "There is already an account named $Mboxname." -foregroundcolor Red 
      Write-Host "User found: " $user.distinguishedName -foregroundcolor Red
     break 
}
$Displayname = Read-Host "Display Name (Name shown in Outlook) "
## check if only letters and spaces were used
$regex = "^([a-zA-Z0-9_/. ]+)$" ## only text
If ($Mboxname -notmatch $regex) { 
      Write-Host "Invalid Display name specified. $Mboxname Please use only letters and spaces" -foregroundcolor Red 
      break 
} 
$description = "Exchange Conference Resource"
$RoomCapacity = Read-Host "Number of Seats in the Conference Room - Leave Blank if Hotel"
$CustomResource = Read-Host "Enter a Resource from the list if present (Easel,Projector,Whiteboard,TVMonitor)"
if($CustomResource -eq "Projector")
{$Title = "Projector=Yes"}
elseif($CustomResource -eq "TVMonitor")
{$Title = "TV=Yes"}
else{$Title = "Projector=No"}
$PhoneNumber = Read-Host "Enter Conf Room Phone Number if known - 513-246-0000"
Write-Host "================================================" -foregroundcolor Cyan 
Write-Host "Creating Conference Room Administrative Group" -foregroundcolor Cyan 
[string[]] $userlist = (Read-Host "Enter a space seperated list of Conf Room Manangers if group is already created, leave blank").split('') | % {$_.trim()}
if ($userlist){
New-QADGroup -ParentContainer  'ou=Conference Rooms,ou=Mail,ou=Departments,dc=contoso,dc=com' `
	-Name "$Displayname Admins" `
	-Displayname "$Displayname Admins" `
	-SamAccountName "$Displayname Admins" `
	-Description $description `
	-GroupScope Global `
	-GroupType Security `
	-Member ($userlist)
	## -UseGlobalCatalog `
	## -WhatIf
	
repadmin /syncall /P srvdc01
$groupmembers = Get-QADGroupMember "$Displayname Admins"
Write-Host "Security group created with the following users: " -ForegroundColor Cyan
$groupmembers
}else {$existinggroup = Read-Host "Enter the name of the group already created for managing this resource"}


function existinggroup{
	Write-Host "Granting full access to shared mailbox: $Mboxname for group $existinggroup" -ForegroundColor Cyan
	Add-MailboxPermission -Identity $Mboxname `
	-User "$existinggroup" `
	-DomainController "SRVDC01.contoso.com" `
	-AccessRights Fullaccess `
	-InheritanceType all
}


## sleep 5
Write-Host "================================================" -foregroundcolor Cyan 
Write-Host "Creating Conference Room $DisplayName..." -foregroundcolor Cyan 
New-Mailbox $DisplayName.Trim() `
	-UserPrincipalName $Mboxname@hq.first.int `
	-Alias $Mboxname `
	-DomainController 'SRVDC01.contoso.com' `
	-Room `
	-ResourceCapacity $RoomCapacity `
	-DisplayName ($DisplayName.Trim()) `
	-FirstName $Mboxname `
	-LastName '' `
 	-OrganizationalUnit "contoso.com/Departments/Mail/Conference Rooms" `
	-SamAccountName $Mboxname
	#-Whatif
	#-Password (ConvertTo-SecureString 'Password1' -AsPlainText -Force)

repadmin /syncall /P srvdc01 | Out-Null
Write-Output "[INFO] Waiting For AD Replication"
sleep 10

Do {Write-output "[INFO] - Testing Mailbox creation";sleep -Seconds 10}
until (Get-CalendarProcessing $mboxname)

if($userlist){get-mailbox $Mboxname | Set-Mailbox -ResourceCustom $CustomResource}
get-mailbox $Mboxname | Set-CalendarProcessing -AutomateProcessing 'AutoAccept' -DeleteSubject $false -BookingWindowInDays '365'
Set-MailboxFolderPermission $Mboxname":\Calendar" -User default -AccessRights Author


# Mailbox created. Setting Description

Set-ADUser $Mboxname -Description $description -Title $Title -Office "$RoomCapacity seats" 
if($Phonenumber)
{
    set-aduser $mboxname -homephone $PhoneNumber
}

# Grant full mailbox permission
if ($userlist){
Write-Host "Granting full access to shared mailbox: $Mboxname for group $DisplayName Admins" -ForegroundColor Cyan
Add-MailboxPermission -Identity $Mboxname `
	-User "$Displayname Admins" `
	-DomainController "SRVDC01.contoso.com" `
	-AccessRights Fullaccess `
	-InheritanceType all}
	elseif ($existinggroup) {existinggroup}

Get-Globaladdresslist | update-globaladdresslist
#Listing properties
$info = Get-ADUser -Identity $Mboxname -Properties * | Select-Object DisplayName,samaccountname,description
  
Write-Host "Shared Mailbox created with the following properties: " -ForegroundColor Cyan
$info

Write-Host "================= Script End =================" -foregroundcolor Cyan