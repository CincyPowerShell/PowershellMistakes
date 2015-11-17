<#
.Synopsis
   Remove's Dameware Mini Remote Control
.DESCRIPTION
   Stop DWRCS
   Remove DWRCS Components
   Remove Files
   Send Software Inventory
.EXAMPLE
   Remove-DWRCS -ComputerName
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Remove-DWRCS{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $ComputerName
    )

    Begin{}
    Process{
        ForEach($Computer in $ComputerName){
            If(Test-Path "\\$Computer\C$\Windows\DWRCS"){
                $action = $true      
                Invoke-Command -ComputerName $Computer -ScriptBlock {
                    Stop-Service DWRCS -ErrorAction SilentlyContinue
                    If(Test-Path -Path C:\Windows\DWRCS\DWRCS.exe){
                        Start-Process -FilePath C:\Windows\DWRCS\DWRCS.exe -ArgumentList "-Remove"
                    }
                }
                Remove-Item -Path "\\$computer\C$\Windows\DWRCS" -Recurse -Force -ErrorAction Stop
            }Else{
                $action = $false
            }
            If($action){
                Write-Output "Successfully Removed Dameware on $Computer."
                Invoke-Command -ComputerName $Computer -ScriptBlock ${function:Invoke-SCCMTask} -ArgumentList SoftwareInventory,$true
            }Else{
                Write-Output "Nothing to do on $Computer."
            }
        }
    }
    End{}
}

Function Invoke-SCCMTask {
<#
.SYNOPSIS
	Triggers SCCM to invoke the relevant task
.DESCRIPTION
	Triggers SCCM to invoke the relevant task
.EXAMPLE
	Invoke-SCCMTask "SoftwareUpdatesScan"
.PARAMETER ScheduleId
	ScheduleId
.EXAMPLE
	Invoke-SCCMTask
.PARAMETER ContinueOnError
	Continue if an error is encountered
.NOTES
.LINK
	Http://psappdeploytoolkit.codeplex.com
#>
	[CmdletBinding()]
	Param(
		[ValidateSet("HardwareInventory","SoftwareInventory","HeartbeatDiscovery","SoftwareInventoryFileCollection","RequestMachinePolicy","EvaluateMachinePolicy","LocationServicesCleanup","SoftwareMeteringReport","SourceUpdate","PolicyAgentCleanup","RequestMachinePolicy2","CertificateMaintenance","PeerDistributionPointStatus","PeerDistributionPointProvisioning","ComplianceIntervalEnforcement","SoftwareUpdatesAgentAssignmentEvaluation","UploadStateMessage","StateMessageManager","SoftwareUpdatesScan","AMTProvisionCycle")]
		[string] $ScheduleID,
		[boolean] $ContinueOnError = $true
	)

	$ScheduleIds = @{
		HardwareInventory = "{00000000-0000-0000-0000-000000000001}";							# Hardware Inventory Collection Task
		SoftwareInventory = "{00000000-0000-0000-0000-000000000002}"; 							# Software Inventory Collection Task
		HeartbeatDiscovery = "{00000000-0000-0000-0000-000000000003}"; 							# Heartbeat Discovery Cycle
		SoftwareInventoryFileCollection = "{00000000-0000-0000-0000-000000000010}"; 			# Software Inventory File Collection Task
		RequestMachinePolicy = "{00000000-0000-0000-0000-000000000021}"; 						# Request Machine Policy Assignments
		EvaluateMachinePolicy = "{00000000-0000-0000-0000-000000000022}"; 						# Evaluate Machine Policy Assignments
		RefreshDefaultMp = "{00000000-0000-0000-0000-000000000023}"; 							# Refresh Default MP Task
		RefreshLocationServices = "{00000000-0000-0000-0000-000000000024}"; 					# Refresh Location Services Task
		LocationServicesCleanup = "{00000000-0000-0000-0000-000000000025}"; 					# Location Services Cleanup Task
		SoftwareMeteringReport = "{00000000-0000-0000-0000-000000000031}"; 						# Software Metering Report Cycle
		SourceUpdate = "{00000000-0000-0000-0000-000000000032}"; 								# Source Update Manage Update Cycle
		PolicyAgentCleanup = "{00000000-0000-0000-0000-000000000040}"; 							# Policy Agent Cleanup Cycle
		RequestMachinePolicy2 = "{00000000-0000-0000-0000-000000000042}"; 						# Request Machine Policy Assignments
		CertificateMaintenance = "{00000000-0000-0000-0000-000000000051}"; 						# Certificate Maintenance Cycle
		PeerDistributionPointStatus = "{00000000-0000-0000-0000-000000000061}"; 				# Peer Distribution Point Status Task
		PeerDistributionPointProvisioning = "{00000000-0000-0000-0000-000000000062}"; 			# Peer Distribution Point Provisioning Status Task
		ComplianceIntervalEnforcement = "{00000000-0000-0000-0000-000000000071}"; 				# Compliance Interval Enforcement
		SoftwareUpdatesAgentAssignmentEvaluation = "{00000000-0000-0000-0000-000000000108}"; 	# Software Updates Agent Assignment Evaluation Cycle
		UploadStateMessage = "{00000000-0000-0000-0000-000000000111}"; 							# Send Unsent State Messages
		StateMessageManager = "{00000000-0000-0000-0000-000000000112}"; 						# State Message Manager Task
		SoftwareUpdatesScan = "{00000000-0000-0000-0000-000000000113}"; 						# Force Update Scan
		AMTProvisionCycle = "{00000000-0000-0000-0000-000000000120}"; 							# AMT Provision Cycle
	}

	Write-Output "Invoking SCCM Task [$ScheduleId]..."

	# Trigger SCCM task
	Try {
		$SmsClient = [wmiclass]"\ROOT\ccm:SMS_Client"
		$SmsClient.TriggerSchedule($ScheduleIds.$ScheduleID) | Out-Null
	}
	Catch [Exception] {
		If($ContinueOnError -eq $true){
			Write-Output "Trigger SCCM Schedule failed for Schedule ID $($ScheduleIds.$ScheduleId): $($_.Exception.Message)"
		}Else {
			Throw "Trigger SCCM Schedule failed for Schedule ID $($ScheduleIds.$ScheduleId): $($_.Exception.Message)"
		}
	}

}