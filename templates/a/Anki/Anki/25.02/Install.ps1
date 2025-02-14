
Get-Content .env | Foreach-Object {
    if ($_ -match "^(\w+)\s*=\s*'([^']+)'\s*$") {
        if ($Matches[1] -eq 'CERT_PASSWORD') {
            $Password = $Matches[2]
        } elseif ($Matches[1] -eq 'CERT_PFX') {
            $CertPfx = $Matches[2]
        }
    }
}
if ($Password -eq $null -or $CertPfx -eq $null) {
    throw "Cert file and password not provided"
}

$Uri = 'https://github.com/ankitects/anki/releases/download/25.02/anki-25.02-windows-qt6.exe'
$Sha = '16e3076dde0048cf7247af001552682d96ca3d0e9ca8ce16a6bb2d63e6ac57c8'

$Exe = "$env:TEMP\anki.exe"
$Msix = "$env:UserProfile\Desktop\Anki.Anki.msix"

if (! (Test-Path $Exe)) {
    Invoke-WebRequest -Uri $Uri -OutFile $Exe
}
if ((Get-FileHash -Algorithm SHA256 -Path $Exe).Hash -ne $Sha) {
    throw "Invalid SHA256 Hash"
}

sudo MsixPackagingTool.exe create-package --template $PSScriptRoot\Anki.Anki_template.xml

$Signtool = 'C:\Program Files (x86)\Windows Kits\10\App Certification Kit\signtool.exe'

& $Signtool sign /fd SHA256 /f $CertPfx /p $Password $Msix
