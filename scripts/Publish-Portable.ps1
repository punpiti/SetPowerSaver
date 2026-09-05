[CmdletBinding()]
param(
    [string]$Version = '0.1.0',
    [ValidateSet('win-x64', 'win-arm64')]
    [string]$Runtime = 'win-x64'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'TemporaryLaptopModes\TemporaryLaptopModes.csproj'
$releaseRoot = Join-Path $root "artifacts\TemporaryLaptopModes-$Version-$Runtime"
$zipPath = "$releaseRoot.zip"

Remove-Item $releaseRoot -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

dotnet publish $project -c Release -r $Runtime --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    -o $releaseRoot
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }

@"
Temporary Laptop Modes $Version

1. Extract this ZIP anywhere.
2. Run TemporaryLaptopModes.exe.
3. Right-click the tray icon to choose a temporary mode.

No .NET installation is required: this is a self-contained build.
"@ | Set-Content -Path (Join-Path $releaseRoot 'README.txt') -Encoding utf8

Compress-Archive -Path (Join-Path $releaseRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Created portable release: $zipPath" -ForegroundColor Green
