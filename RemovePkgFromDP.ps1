# Look up the site code for the SMS Provider, given a server name
Function GetSiteCode($tSiteServer){
    # Dynamically obtain SMS provider location based only on server name
    $tSiteCode = (Get-WmiObject -ComputerName $tSiteServer -Class SMS_ProviderLocation -Namespace root\sms).NamespacePath
    # Return only the last 3 characters of the NamespacePath property, which indicates the site code
    return $tSiteCode.SubString($tSiteCode.Length - 3).ToLower()
}

# Move Package files to Temporary Backup Location
Function BackupPKG($BDP, $PKGID){
	$blankdirAcl = New-Object System.Security.AccessControl.DirectorySecurity
	$blankdirAcl.SetOwner([System.Security.Principal.NTAccount]'BUILTIN\Administrators')
	$DirACL = New-Object System.Security.AccessControl.DirectorySecurity
	$DirACL.SetAccessRuleProtection($False, $True) #(Block Inheritance, Copy Parent ACLs)
	$Folder = "\\$BDP\C$\SMSPKGC$\$PKGID"
	If($BDPWrkFldr){
		If(Test-Path "\\$BDP\C$\BdpTmpWrkFldr"){
			if(!(Test-Path "\\$BDP\C$\SCCMBackup")){New-Item -ItemType directory -Path "\\$BDP\C$\SCCMBackup" | out-null}
			$wrkfldr = Get-ChildItem "\\$BDP\C$\BDPTmpWrkFldr" -ErrorAction SilentlyContinue -ErrorVariable err | ? {$_.PSIsContainer}
			if($err -and (!$wrkfldr -eq $null)){
				Service $BDP "CCMExec" "Stop"
				Service $BDP "BITS" "Stop"
				$command = 'cmd /c "$CurrentDir\psexec.exe" \\' +$BDP+' takeown /f "C:\BDPTmpWrkFldr" /r /a /d y'
				Invoke-Expression -command $command
				icacls "\\$BDP\C$\BDPTmpWrkFldr" /reset /T > $null #Don't write to screen
				$wrkfldr = Get-ChildItem "\\$BDP\C$\BDPTmpWrkFldr"
				$err.Clear()
			}
			if($wrkfldr -ne $Null){
				Move-Item "\\$BDP\C$\BDPTmpWrkFldr\$WrkFldr" "\\$BDP\C$\SCCMBackup"
				Rename-Item "\\$BDP\C$\SCCMBackup\$WrkFldr" $PKGID
				If($Restrict){
					$arg = "/S /Z /MIR /IPG:1200 /r:5 /w:10 \\SR2MS001\SCCMPKG$\SMSPKG\$PKGID \\$BDP\C$\SCCMBackup\$PKGID"
					Start-Process robocopy $arg
				}else{
					$arg = "/S /Z /MIR /r:5 /w:10 \\SR2MS001\SCCMPKG$\SMSPKG\$PKGID \\$BDP\C$\SCCMBackup\$PKGID"
					Start-Process robocopy $arg
				}
			}
		}
	}Else{	
		If(Test-Path $Folder){
			if(!(Test-Path "\\$BDP\C$\SCCMBackup")){New-Item -ItemType directory -Path "\\$BDP\C$\SCCMBackup" | out-null}
			try{
				Move-Item $Folder "\\$BDP\C$\SCCMBackup" -ErrorAction SilentlyContinue -ErrorVariable err
				If($err){
					write-host -fore Yellow "$(Get-Date -format yyyyMMdd-hh:mm:ss): WARNING $err - Unable to Backup Package, trying to take ownership of package."
					$err.Clear()
					$command = 'cmd /c "$CurrentDir\psexec.exe" \\' +$BDP+' takeown /f "$Folder" /r /a /d y'
					Invoke-Expression -command $command
					icacls "$Folder" /reset /T > $null #Don't write to screen
					Move-Item $Folder "\\$BDP\C$\SCCMBackup\$PKGID"
				}else{
					write-host "$(Get-Date -format yyyyMMdd-hh:mm:ss): Successfully backed up Package $PKGID on $BDP"
				}
			}catch{
				write-host "$(Get-Date -format yyyyMMdd-hh:mm:ss): FATAL Error $_ ,Unable to Backup Package"
			}
		}else{
			write-host -fore red "$(Get-Date -format yyyyMMdd-hh:mm:ss): $Folder does not exist"
		}
	}
}

# Remove PKG From Distribution Point
Function RemovePKGFromDP($BDP){
	$tSysQuery = "select * from SMS_DistributionPoint WHERE PackageID='" + $PKGID + "'"
    $tWmiNs = "root\sms\site_" + $SccmSiteCode
    $Resources = Get-WmiObject -ComputerName $SccmServer -Namespace $tWmiNs -Query $tSysQuery
	if ($Resources -eq $null) { 
		write-host "Can't find any resources" 
		return 
	}else {
		foreach($resource in $resources){
			If($($resource.ServerNALPath).Contains($BDP)){
				try{
					$resource.Delete()
					write-host -fore Cyan "$(Get-Date -format yyyyMMdd-hh:mm:ss): Successfully removed $PKGID from $BDP"
				}catch{
					write-host "Unable to Remove $PKGID from $BDP"
				}
			}
		}
	}
}

# Restore Package files from Temporary Backup Location
Function RestorePKG($BDP, $PKGID){
	Move-Item "\\$BDP\C$\SCCMBackup\$PKGID" "\\$BDP\C$\SMSPKGC$\$PKGID" -ErrorAction SilentlyContinue -ErrorVariable err
	If($err){
		write-host -fore Red "Error $err - Unable to Restore Package"
		$err.Clear()
	}else{
		write-host "$(Get-Date -format yyyyMMdd-hh:mm:ss): Successfully restored $PKGID on $BDP"
	}
}

# Add PKG To Distribution Point
Function AddPKGToDP($BDP){
	$Namespace = "root\sms\site_" + $SccmSiteCode
	$Query = "select NALPath from SMS_DistributionPointInfo WHERE ServerName='" + $BDP + "'"
    	$DPInfo = Get-WmiObject -ComputerName $SccmServer -Namespace $Namespace -Query $Query
	$DPClass = [wmiclass] "\\$SccmServer\root\sms\site_$($SccmSiteCode):SMS_DistributionPoint"
	$DPClass = $DPClass.CreateInstance()
	$DPClass.ServerNALPath = $DPInfo.NALPath
	$DPClass.PackageID = $PKGID
	$DPClass.SiteCode = "ILB"
	$DPClass.Put() > $null
	Write-host -fore white "$(Get-Date -format yyyyMMdd-hh:mm:ss): Successfully added $PKGID to $BDP"
}

# Download Machine Policy on BDP's
Function DownloadMachinePolicy($BDP){
	$Status = Service $BDP "CCMExec" "Status"
	If($Status -ne 'Running'){
		Service $BDP "CCMExec" "Start"
		write-host "Starting CCMExec and waiting 45 seconds for it to start."
		Sleep 45
	}
	$SMSCli = [wmiclass] "\\$BDP\root\ccm:SMS_Client"
	If($SMSCli){
		$SMSCli.RequestMachinePolicy() | out-null
	}
	write-host "$(Get-Date -format yyyyMMdd-hh:mm:ss): Successfully downloaded machine policy on $BDP"
}

# Prestage content on BDP's
Function Prestage($BDP, $PKGID){
	Copy-Item "\\SR2MS001\SCCMPKG$\SMSPKG\$PKGID" "\\$BDP\C$\SCCMBackup" -recurse
	write-host "$(Get-Date -format yyyyMMdd-hh:mm:ss): Prestaging package from: \\SR2MS001\SCCMPKG$\SMSPKG\$PKGID"
}

# Take Action/Retrieve Info about a service
Function Service($PCName,$SvcName,$Action){
	$svc = get-service -ComputerName $PCName -Name $SvcName
	If($Action -eq 'Start'){
		$svc.Start()
	}ElseIf($Action -eq 'Stop'){
		$svc.Stop()
	}Else{
		$svc.$Action
	}
}

# Determine Action to take against BDP's
Function BDPAction{
	If(Test-path "\\$BDP\c$\SMSPKGC$\$PKGID"){
		$SMSPKG = "Exists"
	}Else{
		$SMSPKG = "Does Not Exist"
	}
	If(Test-Path "\\$BDP\c$\SCCMBackup"){
		$folders = get-childitem "\\$BDP\c$\SCCMBackup" | ? {$_.PSIsContainer}
		If($folders.count -gt 0){
			If(Test-Path "\\$BDP\c$\SCCMBackup\$PKGID"){
				$SCCMBackup = "Exists"
			}Else{
				$SCCMBackup = "Dirty Folder"
			}
		}Else{
			$SCCMBackup = "Empty"
		}
	}Else{
		$SCCMBackup	= "Does Not Exist"
	}
	write-host $BDP " - Backup Folder" $SCCMBackup " - SMSPKG Folder" $SMSPKG
	Add-Content $CurrentDir\exist.csv -value $BDP","$($SCCMBackup)","$($SMSPKG)
}

# Check for PKG Delete Events
Function CheckEvent($BDP, $PKGID){
    get-content "\\$BDP\C$\Windows\SysWow64\CCM\Logs\PeerDPAgent.log" | ForEach-Object {
        if (-not($_.endswith('">'))){
            $string += $_
            $frag= $true    
        }Else{
            $string += $_
            $frag =$false
        }
        if (-not($frag)){
            $msg = ($string -Split 'LOG')[1].trimstart('[').trimend(']')
            $msg = ($msg -Split 'PDPPkgDeleteEvent')[1]
            $time = ($msg -Split 'DateTime')[1]
            $msg = ($msg -Split 'PackageID')[1]
            $msg = ($msg -Split ';')[0]
            $msg = $msg -replace "=",""
            $msg = $msg -replace """",""
            $msg = $msg -replace " ",""
            $time = ($time -Split ';')[0]
            $time = ($time -Split ".", 0, "simplematch")[0]
            $time = $time -replace "=","" 
            $time = $time -replace """",""
            $time = $time -replace " ",""
            If($msg -eq $PKGID){
				# write-host "Package Remove Time: $time"
				# write-host "Script Started Time: $CurrentTime"
                If($time -gt $CurrentTime){
					# write-host "Package removal entry found in log."
					Remove-Variable string
					Return $TRUE
                }else{
				}
            }
            Remove-Variable string
        }
    } 
}

$CurrentDir=Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$PKGList = Get-Content $CurrentDir'\PKGList.txt'
$Prestage = $FALSE
$BDPWrkFldr = $FALSE
$Restrict = $FALSE
$BDPList = Get-Content $CurrentDir'\RemovePkgFromDP.txt'
$SccmServer = 'SR1MS001' 						
$SccmSiteCode = GetSiteCode $SccmServer
ForEach($BDP in $BDPList){;
	If($BDP.StartsWith("#")){
		continue
	}
	ForEach($PKGID in $PKGList){
		BDPAction
		If($Prestage){ Prestage $BDP $PKGID }else{ BackupPKG $BDP $PKGID }
		$CurrentTime = ((Get-Date).ToUniversalTime()).ToString("yyyyMMddHHmmss")
		RemovePKGFromDP $BDP
		Start-Sleep 45
		DownloadMachinePolicy $BDP
		While(!(CheckEvent $BDP $PKGID)){ 
			write-host "$(Get-Date -format yyyyMMdd-hh:mm:ss): Sleeping for 20 seconds to wait until $PKGID is removed from $BDP."
           	Start-Sleep 20
        }
		RestorePKG $BDP $PKGID
		AddPKGToDP $BDP
		write-host "$(Get-Date -format yyyyMMdd-hh:mm:ss): Sleeping for 45 seconds to wait for package to be added to $BDP."
		Start-Sleep 45
		DownloadMachinePolicy $BDP
		write-host -fore magenta "--------------------------------------------------------------------------------------------------------"
	}
}