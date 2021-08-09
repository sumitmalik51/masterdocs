Param (
    [Parameter(Mandatory = $true)]
    [string]
    $AzureUserName,
    [string]
    $AzurePassword,
    [string]
    $AzureTenantID,
    [string]
    $AzureSubscriptionID,
    [string]
    $ODLID,
    [string]
    $DeploymentID,
    [string]
    $azuserobjectid,
    [string]
    $InstallCloudLabsShadow

)

Start-Transcript -Path C:\WindowsAzure\Logs\CloudLabsCustomScriptExtension.txt -Append
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 

#Import Common Functions
$path = pwd
$path=$path.Path
$commonscriptpath = "$path" + "\cloudlabs-common\cloudlabs-windows-functions.ps1"
. $commonscriptpath

# Run Imported functions from cloudlabs-windows-functions.ps1
WindowsServerCommon
InstallCloudLabsShadow $ODLID $InstallCloudLabsShadow
CreateCredFile $AzureUserName $AzurePassword $AzureTenantID $AzureSubscriptionID $DeploymentID $azuserobjectid
InstallVSCode
choco install azure-data-studio
choco install dotnetcore-sdk
choco install azure-functions-core-tools
InstallAzCLI
sleep 10

#Shortcut for Azure Data Studio
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Azure Studio.lnk")
$Shortcut.TargetPath = """C:\Program Files\Azure Data Studio\azuredatastudio.exe"""
$Shortcut.Save()


#Assign Packages to Install
choco install vscode
choco install git

#DownloadFiles
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://experienceazure.blob.core.windows.net/templates/innovate-and-modernize-apps-with-data-and-ai/scripts/extensions.bat","C:\Packages\extensions.bat")

$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://experienceazure.blob.core.windows.net/templates/innovate-and-modernize-apps-with-data-and-ai/scripts/logontask.ps1","C:\Packages\logontask.ps1")

$securePassword = $AzurePassword | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $AzureUsername, $securePassword

function InstallAzPowerShellModule
{
  Install-PackageProvider NuGet -Force
  Set-PSRepository PSGallery -InstallationPolicy Trusted
  Install-Module Az -Repository PSGallery -Force -AllowClobber
}
InstallAzPowerShellModule

#Install synapse modules
Install-PackageProvider NuGet -Force

sleep 5

#installing extensions to vscode
code --install-extension ms-dotnettools.csharp 
code --install-extension vsciot-vscode.azure-iot-tools
code --install-extension ms-azuretools.vscode-azurefunctions
choco install vscode-gitignore

#Enable Autologon
$AutoLogonRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $AutoLogonRegPath -Name "AutoAdminLogon" -Value "1" -type String 
Set-ItemProperty -Path $AutoLogonRegPath -Name "DefaultUsername" -Value "$($env:ComputerName)\demouser" -type String  
Set-ItemProperty -Path $AutoLogonRegPath -Name "DefaultPassword" -Value "Password.1!!" -type String
Set-ItemProperty -Path $AutoLogonRegPath -Name "AutoLogonCount" -Value "1" -type DWord

$Trigger= New-ScheduledTaskTrigger -AtLogOn
$User= "$($env:ComputerName)\demouser" 
$Action= New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe" -Argument "-executionPolicy Unrestricted -File C:\Packages\logontask.ps1"
Register-ScheduledTask -TaskName "vscode-extensions" -Trigger $Trigger -User $User -Action $Action -RunLevel Highest –Force


Restart-Computer -Force 
Stop-Transcript
