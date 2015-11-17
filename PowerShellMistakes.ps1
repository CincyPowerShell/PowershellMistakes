#region Not Using -WhatIf, When you write an advanced function, make sure it supports -WhatIf
    ##### BAD #####
    Function DeleteFile($fileName){
        del $fileName
    }

    DeleteFile 'C:\Temp\temp.txt'

    ##### GOOD #####
    Function Remove-File{
        [CmdletBinding(SupportsShouldProcess)]
        Param(
            [ValidateScript({Test-Path -Path $_})]
            $files 
        )
        foreach($file in $files){
            If($PSCmdlet.ShouldProcess($file,"Remove File")){
                Remove-Item -Path $file
            }
        }
    }

    ## Files don't exist
    Remove-Item  'foo.txt','foo1.txt'
    Remove-File -Files @('foo.txt','foo1.txt') -WhatIf

    ## Files exist
    New-item 'foo.txt','foo1.txt'
    Remove-File -Files @('foo.txt','foo1.txt') -WhatIf
#endregion

#region Validate Parameters, limit the type of input
    ##### BAD #####
    Function ComputerInfo($computerName){
        Get-WmiObject -ComputerName $computerName -Class Win32_ComputerSystem
    }

    ComputerInfo 'localhost'

    ##### GOOD #####
    Function Get-ComputerInfo{
        [CmdletBinding()]
        Param(
            [ValidateNotNullOrEmpty()]
            [ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1})]
            [string]$computerName
        )
        Get-WmiObject -ComputerName $computerName -Class Win32_ComputerSystem
    }

    ## Works
    Get-ComputerInfo -computerName 'localhost'

    Function Get-ComputerInfo{
        [CmdletBinding()]
        Param(
            [ValidateNotNullOrEmpty()]
            [ValidateSet('localhost','compA')]
            [string]$computerName
        )
        Get-WmiObject -ComputerName $computerName -Class Win32_ComputerSystem
    }

    ## Doesn't Work
    Get-ComputerInfo -computerName 'comp1'
#endregion

#region Not Handling Errors, only silencing them
    ##### BAD #####
    $ErrorActionPreference = 'SilentlyContinue'
    $computers = @('localhost','comp1','comp2')
    ForEach($computer in $computers){
        Get-WmiObject -ComputerName $computer -Class Win32_ComputerSystem
    }

    ##### Better #####
    $ErrorActionPreference = 'Continue'     #Set it back to default
    $computers = @('localhost','comp1','comp2')
    If(Test-Connection -ComputerName $computers -Quiet -Count 1){
        ForEach($computer in $computers){
            Get-WmiObject -ComputerName $computer -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
        }
    }

    ##### BEST #####
    $computers = @('localhost','comp1','comp2')
    ForEach($computer in $computers){
        Try{
            Get-WmiObject -ComputerName $computer -Class Win32_ComputerSystem -ErrorAction Stop   #Force this to be a Terminating Error
        }Catch{
            Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
            #Throw "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"  #Stops all execution, Jumps out of the loop
        }
    }
#endregion

#region Don't use write-host, save the puppies
    Start-Process 'https://www.youtube.com/watch?v=JPXumlUCzK8'
#endregion

#region What's the big deal with Quotes?
    #Everything inside the Double Quotes is evaluated
    Write-Output "`t This line starts with a tab"
    #Everything inside Single Quotes are literal
    Write-Output '`t This line is interpreted literally'

    $foo = 'PowerShell is Cool'
    Write-Output "$foo -eq PowerShell is Cool"
    Write-Output '$foo -ne PowerShell is Cool'
#endregion
