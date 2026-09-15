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
$toolsets = @(Get-ChildItem -LiteralPath (Join-Path $installation "VC/Tools/MSVC") -Directory |
    Where-Object { $_.Name -match '^14\.44\.\d+(\.\d+)?$' } |
    Sort-Object { [version]$_.Name } -Descending)
if ($toolsets.Count -eq 0) {
    throw "OpenSSL reference requires an installed MSVC 14.44 toolset; no fallback or installation is performed"
}
# Allow servicing within the approved line, never the Visual Studio latest default.
$toolset = $toolsets[0]
$developerArchitecture = if ($Architecture -eq "aarch64") { "arm64" } else { "amd64" }
$binaryArchitecture = if ($Architecture -eq "aarch64") { "arm64" } else { "x64" }
$toolBin = Join-Path $toolset.FullName "bin/Host$binaryArchitecture/$binaryArchitecture"
foreach ($name in @("cl.exe", "link.exe", "lib.exe", "nmake.exe")) {
    if (-not (Test-Path -LiteralPath (Join-Path $toolBin $name) -PathType Leaf)) {
        throw "MSVC $($toolset.Name) lacks the required $binaryArchitecture host/target tool $name"
    }
}
$developerModule = Join-Path $installation "Common7/Tools/Microsoft.VisualStudio.DevShell.dll"
Import-Module $developerModule
$developerShell = Get-Command Enter-VsDevShell -CommandType Cmdlet
if (-not $developerShell.Parameters.ContainsKey("DevCmdArguments")) {
    throw "Visual Studio developer shell cannot accept explicit toolset selection"
}
Enter-VsDevShell -VsInstallPath $installation -SkipAutomaticLocation `
    -DevCmdArguments "-arch=$developerArchitecture -host_arch=$developerArchitecture -vcvars_ver=$($toolset.Name)"
if ($env:VCToolsVersion -ne $toolset.Name) {
    throw "Developer shell selected MSVC '$env:VCToolsVersion', expected '$($toolset.Name)'"
}
$architectureAliases = if ($Architecture -eq "aarch64") { @("arm64") } else { @("x64", "amd64") }
if ($env:VSCMD_ARG_HOST_ARCH -notin $architectureAliases -or
    $env:VSCMD_ARG_TGT_ARCH -notin $architectureAliases) {
    throw "Developer shell did not select the required native $binaryArchitecture host and target"
}
if (Test-Path "C:/Strawberry/perl/bin/perl.exe") {
    $env:PATH = "C:\Strawberry\perl\bin;$env:PATH"
}

function Get-ReferenceTool([string]$Name, [string]$VersionPrefix) {
    # Validate the PATH winner, not the array of all matching applications.
    $actual = (Get-Command $Name -CommandType Application | Select-Object -First 1).Source
    $expected = Join-Path $toolBin $Name
    if ([IO.Path]::GetFullPath($actual) -ine [IO.Path]::GetFullPath($expected)) {
        throw "PATH selected '$actual' instead of pinned reference tool '$expected'"
    }
    $info = (Get-Item -LiteralPath $actual).VersionInfo
    if (-not $info.FileVersion -or -not $info.FileVersion.StartsWith($VersionPrefix)) {
        throw "Unexpected $Name version '$($info.FileVersion)'; expected $VersionPrefix"
    }
    return [ordered]@{
        executable = $actual
        product = $info.ProductName
        file_version = $info.FileVersion
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $actual).Hash.ToLowerInvariant()
    }
}

if (-not $env:WindowsSDKVersion -or -not $env:UCRTVersion) {
    throw "Windows SDK/UCRT version metadata is unavailable in the selected developer shell"
}
$metadata = [ordered]@{
    policy = "installed-msvc-14.44-no-fallback"
    toolset_version = $toolset.Name
    toolset_directory = $toolset.FullName
    host_architecture = $binaryArchitecture
    target_architecture = $binaryArchitecture
    windows_sdk_version = $env:WindowsSDKVersion.TrimEnd('\')
    ucrt_version = $env:UCRTVersion
    compiler = (Get-ReferenceTool "cl.exe" "19.44.")
    linker = (Get-ReferenceTool "link.exe" "14.44.")
    librarian = (Get-ReferenceTool "lib.exe" "14.44.")
    make = (Get-ReferenceTool "nmake.exe" "14.44.")
}
$scratch = Join-Path $env:GITHUB_WORKSPACE ".agent-scratch"
New-Item -ItemType Directory -Force -Path $scratch | Out-Null
$metadataPath = Join-Path $scratch "openssl-windows-toolchain.json"
$json = $metadata | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText($metadataPath, $json + "`n", [Text.UTF8Encoding]::new($false))
Write-Output $json
python3 "$PSScriptRoot/prepare_openssl.py" --target "$Architecture-windows-msvc" `
    --windows-toolchain $metadataPath
if ($LASTEXITCODE -ne 0) { throw "Pinned OpenSSL CLI reference build failed" }
