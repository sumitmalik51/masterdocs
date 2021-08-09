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
InstallPowerBIDesktop
choco install dotnetcore-sdk
choco install azure-functions-core-tools
InstallAzCLI
choco install powerbi -y -force
sleep 10

#Shortcut for Azure Data Studio
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Azure Studio.lnk")
$Shortcut.TargetPath = """C:\Program Files\Azure Data Studio\azuredatastudio.exe"""
$Shortcut.Save()

#Download lab files
New-Item -ItemType directory -Path C:\MCW
$WebClient = New-Object System.Net.WebClient
#Download lab files
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://github.com/microsoft/MCW-Innovate-and-modernize-apps-with-Data-and-AI/archive/main.zip","C:\MCW\MCW-Innovate-and-modernize-apps-with-Data-and-AI.zip")

#unziping folder
function Expand-ZIPFile($file, $destination)
{
$shell = new-object -com shell.application
$zip = $shell.NameSpace($file)
foreach($item in $zip.items())
{
$shell.Namespace($destination).copyhere($item)
}
}
Expand-ZIPFile -File "C:\MCW\MCW-Innovate-and-modernize-apps-with-Data-and-AI.zip" -Destination "C:\"

#Assign Packages to Install
choco install vscode
choco install git

#DownloadFiles
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://experienceazure.blob.core.windows.net/templates/innovate-and-modernize-apps-with-data-and-ai/scripts/extensions.bat","C:\Packages\extensions.bat")

$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://experienceazure.blob.core.windows.net/templates/innovate-and-modernize-apps-with-data-and-ai/scripts/logontask.ps1","C:\Packages\logontask.ps1")

New-Item -ItemType directory -Path "C:\Temp\IoT Edge"
New-Item -ItemType directory -Path "C:\Temp\Azure Functions"

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
Install-Module -Name Az.Synapse -RequiredVersion 0.3.0 -AllowClobber -Force

sleep 5
Import-Module Az.Synapse

. C:\LabFiles\AzureCreds.ps1

Connect-AzAccount -Credential $cred | Out-Null

# Template deployment
$resourceGroupName = (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "*modernize-app-*" }).ResourceGroupName
$deploymentId =  (Get-AzResourceGroup -Name $resourceGroupName).Tags["DeploymentId"]

$url = "https://experienceazure.blob.core.windows.net/templates/innovate-and-modernize-apps-with-data-and-ai/deploy-01.parameters.json"
$output = "c:\LabFiles\parameters.json";
$wclient = New-Object System.Net.WebClient;
$wclient.CachePolicy = new-object System.Net.Cache.RequestCachePolicy([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore);
$wclient.Headers.Add("Cache-Control", "no-cache");
$wclient.DownloadFile($url, $output)
(Get-Content -Path "c:\LabFiles\parameters.json") | ForEach-Object {$_ -Replace "GET-AZUSER-PASSWORD", "$AzurePassword"} | Set-Content -Path "c:\LabFiles\parameters.json"
(Get-Content -Path "c:\LabFiles\parameters.json") | ForEach-Object {$_ -Replace "GET-DEPLOYMENT-ID", "$DeploymentID"} | Set-Content -Path "c:\LabFiles\parameters.json"
(Get-Content -Path "c:\LabFiles\parameters.json") | ForEach-Object {$_ -Replace "GET-AZUSER-UPN", "$AzureUserName "} | Set-Content -Path "c:\LabFiles\parameters.json"
(Get-Content -Path "c:\LabFiles\parameters.json") | ForEach-Object {$_ -Replace "GET-AZUSER-OBJECTID", "$azuserobjectid"} | Set-Content -Path "c:\LabFiles\parameters.json"

 

Write-Host "Starting main deployment." -ForegroundColor Green -Verbose
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateUri "https://experienceazure.blob.core.windows.net/templates/innovate-and-modernize-apps-with-data-and-ai/deploy-01.json" -TemplateParameterFile "c:\LabFiles\parameters.json"

New-AzRoleAssignment -ResourceGroupName $resourceGroupName -ErrorAction Ignore -ObjectId "37548b2e-e5ab-4d2b-b0da-4d812f56c30e" -RoleDefinitionName "Owner"

#Role assignment on synapse workspace for AAD group
$workspacename = "asaworkspace$($deploymentId)"
New-AzSynapseRoleAssignment -WorkspaceName $workspacename -RoleDefinitionId "6e4bf58a-b8e1-4cc3-bbf9-d73143322b78" -ObjectId "37548b2e-e5ab-4d2b-b0da-4d812f56c30e"
New-AzSynapseRoleAssignment -WorkspaceName $workspacename -RoleDefinitionId "7af0c69a-a548-47d6-aea3-d00e69bd83aa" -ObjectId "37548b2e-e5ab-4d2b-b0da-4d812f56c30e"
New-AzSynapseRoleAssignment -WorkspaceName $workspacename -RoleDefinitionId "c3a6d2f1-a26f-4810-9b0f-591308d5cbf1" -ObjectId "37548b2e-e5ab-4d2b-b0da-4d812f56c30e"

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

Write-Host "Restarting-Computer" 
Restart-Computer -Force 
Stop-Transcript
