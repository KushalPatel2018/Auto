<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the Uninstallation of given software(s) in CSV.

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('HardUninstall', 'SoftUninstall')]
    [String]$DeploymentType = 'HardUninstall',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
    ##*===============================================
	## Enter Vendor who created the Installation file/Software name:
    [string]$appVendor = 'Cap'
    ##*===============================================
    ## Enter Software Name (preferebly in ARP unless if it's different)
	[string]$appName = 'Reclaimer'
    ##*===============================================
    ## Enter Version that shows in ARP (Programs & Features/Add or Remove)
	[string]$appVersion = '1.0'
    ##*===============================================
    ## OPTIONAL: Enter if Installation file is x86 or x64
	[string]$appArch = ''
    ##*===============================================
    ## OPTIONAL: Enter Language 
	[string]$appLang = 'EN'
    ##*===============================================
    ## OPTIONAL: Enter if this is first Revision of the Script or more
	[string]$appRevision = '01'
    ##*===============================================
    ## OPTIONAL: Enter if this is first Revision of the Script or more
	[string]$appScriptVersion = '1.0.0'
    ##*===============================================
    ## Enter the Packaging Date.
	[string]$appScriptDate = '7/11/2023'
    ##*===============================================
    ## Enter your name (Packager)
	[string]$appScriptAuthor = 'Kushal Patel'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    ## OPTIONAL: Leave this Blank
	[string]$installName = ''
    ##*===============================================
    ## Enter name that shows in Add or Remove Programs/Programs & Features.
    ## **Only enter this if it's different from line 68**
    [string]$arpname = ''
    ##*===============================================
	[string]$installTitle = "$appName"
    ##*===============================================
    ## Set Log file (location) of Install Toolkit
   	[string]$ToolkitLogPath = "$env:SystemDrive\Installs\$($appVendor)\$($appVersion)"
    ##*===============================================
    ## Set Log file (location) of Uninstall Toolkit, where do you want to save the uninstall log file?
    [string]$configToolkitLogDir = "$env:SystemDrive\Installs\CET\Logs\"
    ##*===============================================
    ## Set Log file (location) of uninstall MSI log.
    [string]$configMSILogDir = "$configToolkitLogDir"
    ##*===============================================

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.1'
    [String]$deployAppScriptDate = '20/01/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================
    
    If ($deploymentType -ine 'SoftUninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        
#------------------------------------------------------------------------------------------
#Read software names from CSV file and get the UninstallString and QuietUninstallString
#Parse the UninstallString and QuitUninstallString values and get the MsiExec and Exe path
#Execute the MsiExec package removel step and trigger uninstall.exe along with argument list
#./Scriptname.ps1
#------------------------------------------------------------------------------------------

$MyDir = "C:\Temp\Reclaimer"

$softwarelistcsv = "$DirFiles\software.csv"
#$LogFile = "$MyDir\log.txt"

$32bitpath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
$64bitpath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"

<#
#---------------------------------------------------------------
#Function caputre the log information and place into log file
#---------------------------------------------------------------

function Write-Log -Message
{
    Param ([string]$LogString)
    $LogMessage = "$LogString"
    Add-content $LogFile -value $LogMessage
}
#>
#---------------------------------------------------------------
#Function used to return the data and time for loging purpose
#---------------------------------------------------------------

function dt 
{
    Write-Log -Message $(get-date -Format 'dd-MM-yyyy hh:mm:ss tt')
}

#---------------------------------------------------------------
#Function Get all the apllication list from computer
#---------------------------------------------------------------

function Uninstall-Applications($32bitpath, $64bitpath)
{

    $installed64 = Get-ItemProperty "$32bitpath" | Where-Object { $_.DisplayName -ne $null } | Select-Object DisplayName, DisplayVersion, UninstallString, QuietUninstallString

    $installed32 = Get-ItemProperty "$64bitpath" | Where-Object { $_.DisplayName -ne $null } | Select-Object DisplayName, DisplayVersion, UninstallString, QuietUninstallString
    
    $installed = $installed32 + $installed64

    $installed | Select-Object DisplayName, DisplayVersion, UninstallString, QuietUninstallString    

}

#---------------------------------------------------------------
#Function Uninstall MSI Packages
#---------------------------------------------------------------

function Uninstall-MSIpackage($UninstallPath)
{

    $uninstallString = $UninstallPath -Replace "msiexec.exe","" -Replace "/I","" -Replace "/X",""
    $uninstallString = $uninstallString.Trim()    

    Write-Log -Message  "$softwarename - Uninstalling..."
    try
    {

        Start-Process -Wait -FilePath MsiExec.exe -Argumentlist "/X $uninstallString /quiet /norestart" 
    }
    catch
    {
        Write-Log -Message "$($_.Exception)"
        Write-Log -Message "$($softwarename) - $($uninstallString) -  Uninstallation failed, please check manually"                                    
    }
}

#---------------------------------------------------------------
#Functoon Uninstall exe packages
#---------------------------------------------------------------

function Uninstall-EXE($UninstallPath)
{
        
    $isExeOnly = Test-Path -LiteralPath "$($UninstallPath)"
    if ($isExeOnly) { $UninstallPath = "`"$UninstallPath`"" }     
    
    # Split the command line into argument list.            
    if ($UninstallPath[0] -eq '"') {
        $unused, $exe, $argList = $UninstallPath -split '"', 3
    }
    else 
    {
        $exe, $argList = $UninstallPath -split ' ', 2
    }
    
    
    Write-Log -Message "$softwarename - Uninstalling..."

    try
    {
    
        #Check any default arugument list exist
        if ($argList -ne '')
        {
            try
            {
                Start-Process -FilePath "$exe" -ArgumentList $argList -Verb runas -Wait -PassThru 
            }
            catch    
            {
                Write-Log -Message "$($_.Exception)"
                Write-Log -Message "$($softwarename) - $($uninstallString) -  Uninstallation failed, please check manually"                                    
            }

            #Unstallation failed when used default argument list
            if ($res.ExitCode -ne 0)
            {
                try
                {
                    Start-Process -FilePath "$exe" -ArgumentList '/quiet /qn /S /norestart /silent' -Verb runas -Wait -PassThru 
                }
                catch    
                {
                    Write-Log -Message "$($_.Exception)"
                    Write-Log -Message "$($softwarename) - $($uninstallString) -  Uninstallation failed, please check manually"                                    
                }
            }
        }
        else
        {

            #When default argument list failed script passing necessary prameter and try to uninstall the exe
            try
            {
                Start-Process -FilePath "$exe" -ArgumentList '/quiet /qn /S /norestart /silent' -Verb runas -Wait -PassThru 
            }
            catch    
            {
                Write-Log -Message "$($_.Exception)"
                Write-Log -Message "$($softwarename) - $($uninstallString) -  Uninstallation failed, please check manually"                                    
            }

        }


    }
    catch    
    {
        Write-Log -Message "$($_.Exception)"
        Write-Log -Message "$($softwarename) - $($uninstallString) -  Uninstallation failed, please check manually"                                    
    }
}

#---------------------------------------------------------------
#Get all softwares UninstallString, QuietUninstallString values 
#---------------------------------------------------------------

$csvsoftwares = Import-CSV -Path $softwarelistcsv | Select-Object -ExpandProperty Software_Name

$quietuninstallapp =  Uninstall-Applications $32bitpath $64bitpath

#Get each software from csv and check against the main list from registry and perform the uninstallation steps
$csvsoftwares | ForEach-Object {

    $softwarename = $_
    
    if (($quietuninstallapp | Where-Object { $csvsoftwares -contains $_.DisplayName} | Measure-Object).Count -ge 1)
    {
                
        Write-Log -Message "App (from csv) - $softwarename installed, proceding further step"
            
                $cursoft = $quietuninstallapp | Where-Object { $softwarename -contains $_.DisplayName}                            
            
                $softwarename = $cursoft.DisplayName
                $softwareversion = $cursoft.DisplayVersion    
                $quietuninstallstring = $cursoft.QuietUninstallString
                $uninstallstring = $cursoft.UninstallString                   
#---------------------------------------------------------------
#---------------------------------------------------------------                
     # dialog box
    $dialogbox = Show-InstallationPrompt -Title 'Vuln Application Found' -Message "We found following apps $($csvsoftwares -join ',') on your workstations that are not permissible to the environment. If you would like to uninstall these apps now, press Uninstall. If you would like to uninstall it at a later date click Snooze and you will be reminded in one week from this notification. If you want to fill out the eApl request, press EAPL." -ButtonRightText 'eAPL' -MessageAlignment Center -ButtonLeftText Uninstall -ButtonMiddleText Snooze -Icon Warning
    
    if($dialogbox -eq 'Uninstall')
    {
    Write-Log -Message "User pressed uninstall - we're going to remove $($csvsoftwares)"
    }

    if($dialogbox -eq 'Snooze')
    {
    Write-Log -Message "User has pressed Snooze"
    #Exit-Script -ExitCode 60015
    }

    if($dialogbox -eq 'eApl')
    {
    Write-Log -Message "User has chosen to access/submit eApl Request"
    Start-Process "www.Google.com"
    #Exit-Script -ExitCode 60016
    }
#---------------------------------------------------------------
#---------------------------------------------------------------                   
                Write-Log -Message "Processing software - $($softwarename)"

                if (($uninstallstring.Length -eq 0) -and ($quietuninstallstring.Length -eq 0))
                {
                    Write-Log -Message "$($softwarename) - not able to get both Uninstall and Quiet Uninstall string"                    
                }             
                                    
                #Check QuietUninstallString  value exist, if yes then follow the QuietUninstallString string value
                #If QuietUninstallString not exist then script will use UninstallString value
                $UninstallPath = $quietuninstallstring
                   
                if ($UninstallPath.length -ne 0)
                {

                    #if UninstallString value has MsiExec else Uninstall EXE
                    if ($UninstallPath -like "*MsiExec.exe*")
                    {
        
                        Write-Log -Message "Calling MSI Package remover function (path from UninstallString) - $($UninstallPath)"
                        Uninstall-MSIpackage $UninstallPath
    
                    }
                    else
                    {
            
                        Write-Log -Message "Calling EXE remover function (path from UninstallString) - $($UninstallPath)"    

                        Uninstall-EXE "$UninstallPath"
                
                    }

                }     
                
                #--------------------------------------------------------------------
                #When QuietUninstallString value empty then getting UninstallString
                #--------------------------------------------------------------------

                $UninstallPath = $uninstallstring

                if($UninstallPath.Length -ne 0)
                {               
                    
                    #if UninstallString value has MsiExec else Uninstall EXE
                    if ($UninstallPath -like "*MsiExec.exe*")
                    {
        
                        Write-Log -Message "Calling MSI Package remover function (path QuietUninstallString) - $($UninstallPath)"
                        Uninstall-MSIpackage $UninstallPath
    
                    }
                    else
                    {
            
                        Write-Log -Message "Calling EXE remover function (path from QuietUninstallString) - $($UninstallPath)"    
                        
                        Uninstall-EXE "$UninstallPath"
                
                    }
                }    

                #if (($uninstallstring.Length -eq 0) -and ($quietuninstallstring.Length -eq 0))
                #{
                #    Write-Log -Message "$($softwarename) - not able to get both Uninstall and Quiet Uninstall string"
                #}             
    
        Write-Log -Message "---------------------------------------------------------------------"

    }
    else
    {
        Write-Log -Message "App (from csv) - $softwarename not installed"

        Write-Log -Message "---------------------------------------------------------------------"
    }    
}


    }

    ElseIf ($deploymentType -ieq 'SofUninstall') {
        


    }
   
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}


