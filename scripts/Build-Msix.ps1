[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$TemplatePath,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [Parameter(Mandatory)]
    [string]$Architecture
)

$ErrorActionPreference = "Stop"
[console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::UTF8

# Dependencies:
#   powershell-yaml (https://github.com/cloudbase/powershell-yaml)
#   MsixPackagingTool (https://github.com/microsoft/win32-app-isolation)
Import-Module powershell-yaml
$null = Get-Command MsixPackagingTool

if (-not (Test-Path $TemplatePath)) {
    throw "Invalid TemplatePath"
}
if (-not (Test-Path $OutputPath)) {
    throw "Invalid OutputPath"
}
if ($Architecture -eq $null) {
    throw "Invalid Architecture"
}


$OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path

# Variant of New-TemporaryFile that creates files with a given extension and cleans up at exit
function New-TemporaryFileExt {
    param (
        [string]$Extension
    )

    $Path = New-TemporaryFile | `
        Rename-Item -NewName { [IO.Path]::ChangeExtension($_, ".$Extension") } -PassThru
    $null = Register-EngineEvent PowerShell.Exiting -Action {
        Remove-Item -Path $Path -ErrorAction SilentlyContinue
    }

    Write-Verbose "Created temporary file $Path"
    return $Path
}

[xml]$Template = Get-Content $TemplatePath
$PkgInfo = $Template.MsixPackagingToolTemplate.PackageInformation
$PackageName = $PkgInfo.PackageName
$PackageVersion = $PkgInfo.Version

# Normalize the version for MSIX packaging
$MsixVersion = [version]$PackageVersion
$PkgInfo.Version = [version]::new(
    [int]::Max($MsixVersion.Major, 0),
    [int]::Max($MsixVersion.Minor, 0),
    [int]::Max($MsixVersion.Build, 0),
    [int]::Max($MsixVersion.Revision, 0)
).ToString()

Write-Verbose "Building MSIX for $PackageName version $PackageVersion ($($PkgInfo.Version))"

# Retrieve the WinGet manifest from the official GitHub repo
$WinGetUri = "https://raw.githubusercontent.com/microsoft/winget-pkgs/refs/heads/master/manifests"
$Com, $Pkg = $PackageName.Split(".")
$C = [char]::ToLower($Com[0])
$ManifestUri = "$WinGetUri/$C/$Com/$Pkg/$PackageVersion/$Com.$Pkg.installer.yaml"
$ManifestPath = New-TemporaryFileExt -Extension yaml
Invoke-WebRequest -Uri $ManifestUri -OutFile $ManifestPath
$Manifest = Get-Content $ManifestPath | ConvertFrom-Yaml

# Get the installer for this run of Build-Msix
$Installer = $Manifest.Installers | Where-Object { $_.Architecture -eq $Architecture }

# The template file needs the Installer::Path to have the right file extension
$Ext = switch -exact ($Manifest.InstallerType) {
    "nullsoft" { "exe" }
    "exe"      { "exe" }
    "msi"      { "msi" }
    default { throw "Unrecognized InstallerType $($Manifest.InstallerType)" }
}

Write-Verbose "Installer:"
Write-Verbose $Installer

# Download the installer
$InstallerPath = New-TemporaryFileExt -Extension $Ext
Invoke-WebRequest -Uri $Installer.InstallerUrl -OutFile $InstallerPath
if ((Get-FileHash $InstallerPath).Hash -ne $Installer.InstallerSha256) {
    throw "Installer file has invalid file hash"
}

# Setup the paths in the packaging template
$Template.MsixPackagingToolTemplate.Installer.Path = "$InstallerPath"
$Template.MsixPackagingToolTemplate.SaveLocation.PackagePath = "$OutputPath\${PackageName}_$Architecture.msix"
$Template.MsixPackagingToolTemplate.SaveLocation.TemplatePath = "$OutputPath\${PackageName}_${Architecture}_template.yaml"

$OutputTemplate = New-TemporaryFileExt -Extension xml
$Template.Save($OutputTemplate)

Write-Verbose "`n${OutputTemplate}:`n"
Get-Content $OutputTemplate | Write-Verbose

# Build the package
MsixPackagingTool create-package --template $OutputTemplate

