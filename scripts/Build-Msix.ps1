Param (
    [Parameter(Mandatory)]
    [string]$TemplatePath,

    [string]$InstallerPath,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $TemplatePath)) {
    throw "Invalid TemplatePath"
}
if (-not (Test-Path $OutputPath)) {
    throw "Invalid OutputPath"
} else {
    $OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path
}

[xml]$Template = Get-Content $TemplatePath
$PackageName = $Template.MsixPackagingToolTemplate.PackageInformation.PackageName

if ($Template.MsixPackagingToolTemplate.Installer.Uri) {
    $Uri = $Template.MsixPackagingToolTemplate.Installer.Uri
    $Sha = $Template.MsixPackagingToolTemplate.Installer.Sha256
    $Ext = $Template.MsixPackagingToolTemplate.Installer.Extension
    $Template.MsixPackagingToolTemplate.Installer.RemoveAttribute("Uri")
    $Template.MsixPackagingToolTemplate.Installer.RemoveAttribute("Sha256")
    $Template.MsixPackagingToolTemplate.Installer.RemoveAttribute("Extension")

    $InstallerPath = New-TemporaryFile | Rename-Item -NewName { [IO.Path]::ChangeExtension($_, ".$Ext") } -PassThru
    $null = Register-EngineEvent PowerShell.Exiting -Action {
        Remove-Item -Path $InstallerPath -ErrorAction SilentlyContinue
    }
    Invoke-WebRequest -Uri $Uri -OutFile $InstallerPath
    $Hash = (Get-FileHash $InstallerPath).Hash
    if ($Hash -ne $Sha) {
        throw "Invalid uri hash: Expected $Sha, Got $Hash"
    }
} elseif (-not (Test-Path $InstallerPath)) {
    throw "Missing InstallerPath"
}

$Template.MsixPackagingToolTemplate.Installer.Path = "$InstallerPath"
$Template.MsixPackagingToolTemplate.SaveLocation.PackagePath = "$OutputPath\$PackageName.msix"
$Template.MsixPackagingToolTemplate.SaveLocation.TemplatePath = "$OutputPath\${PackageName}_template.yaml"

$OutputTemplate = New-TemporaryFile | Rename-Item -NewName { [IO.Path]::ChangeExtension($_, ".xml") } -PassThru
$null = Register-EngineEvent PowerShell.Exiting -Action {
    Remove-Item -Path $OutputTemplate -ErrorAction SilentlyContinue
}

$Template.Save($OutputTemplate)

Get-Content $OutputTemplate | Write-Output

MsixPackagingTool create-package --template $OutputTemplate
