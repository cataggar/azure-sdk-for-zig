param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("x86_64", "aarch64")]
    [string]$Architecture
)

$ErrorActionPreference = "Stop"
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio/Installer/vswhere.exe"
$component = if ($Architecture -eq "aarch64") {
    "Microsoft.VisualStudio.Component.VC.Tools.ARM64"
} else {
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
}
$installation = & $vswhere -latest -products * -requires $component -property installationPath
if (-not $installation) { throw "MSVC reference-build toolchain is unavailable" }
$developerArchitecture = if ($Architecture -eq "aarch64") { "arm64" } else { "amd64" }
. (Join-Path $installation "Common7/Tools/Launch-VsDevShell.ps1") `
    -Arch $developerArchitecture -HostArch $developerArchitecture -SkipAutomaticLocation
if (Test-Path "C:/Strawberry/perl/bin/perl.exe") {
    $env:PATH = "C:\Strawberry\perl\bin;$env:PATH"
}
python3 "$PSScriptRoot/prepare_openssl.py" --target "$Architecture-windows-msvc"
if ($LASTEXITCODE -ne 0) { throw "Pinned OpenSSL CLI reference build failed" }
