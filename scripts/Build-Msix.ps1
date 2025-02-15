Param (
    [Parameter(Mandatory)]
    [string]$TemplatePath,

    [Parameter(Mandatory)]
    [string]$InstallerPath,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $TemplatePath)) {
    throw "Invalid TemplatePath"
}
if (-not (Test-Path $InstallerPath)) {
    throw "Invalid InstallerPath"
}
if (-not (Test-Path $OutputPath)) {
    throw "Invalid OutputPath"
}

[xml]$Template = Get-Content $TemplatePath
$PackageName = $Template.MsixPackagingToolTemplate.PackageInformation.PackageName
$Template.MsixPackagingToolTemplate.Installer.Path = "$InstallerPath"
$Template.MsixPackagingToolTemplate.SaveLocation.PackagePath = "$OutputPath\$PackageName.msix"
$Template.MsixPackagingToolTemplate.SaveLocation.TemplatePath = "$OutputPath\${PackageName}_template.yaml"

$OutputTemplate = New-TemporaryFile
Register-EngineEvent PowerShell.Exiting -Action {
    Remove-Item -Path $OutputTemplate -ErrorAction SilentlyContinue
}

$Template.Save($OutputTemplate)

MsixPackagingTool create-package --template $OutputTemplate
