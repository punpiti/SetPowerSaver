[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$IdentityName,
    [Parameter(Mandatory = $true)][string]$Publisher,
    [string]$PublisherDisplayName = 'Temporary Laptop Modes',
    [string]$Version = '0.1.0.0',
    [string]$WindowsSdkRoot,
    [string]$CertificatePath,
    [securestring]$CertificatePassword
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'TemporaryLaptopModes\TemporaryLaptopModes.csproj'
$artifactRoot = Join-Path $root 'artifacts\msix'
$stage = Join-Path $artifactRoot 'stage'
$package = Join-Path $artifactRoot "TemporaryLaptopModes-$Version.msix"

$defaultSdkRoot = "${env:ProgramFiles(x86)}\Windows Kits\10"
$sdkRoot = if ($WindowsSdkRoot) { $WindowsSdkRoot } else { $defaultSdkRoot }
$makeAppx = Get-ChildItem (Join-Path $sdkRoot 'bin\*\x64\makeappx.exe') -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $makeAppx) {
    throw "makeappx.exe was not found under '$sdkRoot'. Install the Windows SDK there, or pass -WindowsSdkRoot with its exact path."
}

Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $package -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stage -Force | Out-Null

dotnet publish $project -c Release -r win-x64 --self-contained true `
    -p:PublishSingleFile=false -p:DebugType=None -p:DebugSymbols=false -o $stage
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }

$assets = Join-Path $stage 'Assets'
& (Join-Path $PSScriptRoot 'New-MsixAssets.ps1') -Destination $assets

$manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
         IgnorableNamespaces="uap rescap">
  <Identity Name="$IdentityName" Publisher="$Publisher" Version="$Version" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>Temporary Laptop Modes</DisplayName>
    <PublisherDisplayName>$PublisherDisplayName</PublisherDisplayName>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>
  <Resources><Resource Language="en-us" /></Resources>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.28000.0" />
  </Dependencies>
  <Capabilities><rescap:Capability Name="runFullTrust" /></Capabilities>
  <Applications>
    <Application Id="App" Executable="TemporaryLaptopModes.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements DisplayName="Temporary Laptop Modes" Description="Temporary laptop power modes that restore automatically." BackgroundColor="transparent" Square150x150Logo="Assets\Square150x150Logo.png" Square44x44Logo="Assets\Square44x44Logo.png">
        <uap:DefaultTile Wide310x150Logo="Assets\Wide310x150Logo.png" />
      </uap:VisualElements>
    </Application>
  </Applications>
</Package>
"@
$manifest | Set-Content -Path (Join-Path $stage 'AppxManifest.xml') -Encoding utf8

& $makeAppx pack /d $stage /p $package /o
if ($LASTEXITCODE -ne 0) { throw 'MSIX packaging failed.' }

if ($CertificatePath) {
    $signTool = Get-ChildItem (Join-Path $sdkRoot 'bin\*\x64\signtool.exe') -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $signTool) { throw 'signtool.exe was not found. Install the Windows SDK, then run this command again.' }
    $password = if ($CertificatePassword) { @('/p', ([System.Net.NetworkCredential]::new('', $CertificatePassword).Password)) } else { @() }
    & $signTool sign /fd SHA256 /a /f $CertificatePath @password $package
    if ($LASTEXITCODE -ne 0) { throw 'MSIX signing failed.' }
}

Write-Host "Created MSIX package: $package" -ForegroundColor Green
if (-not $CertificatePath) {
    Write-Host 'This unsigned package is suitable for Microsoft Store submission. Sign it with a trusted certificate before direct sideload distribution.' -ForegroundColor Yellow
}
