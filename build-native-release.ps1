param(
    [string]$Version = "1.0.55"
)

$ErrorActionPreference = "Stop"

$runtimeUrl = "https://github.com/Okaetsu/RE-UE4SS/releases/download/experimental-palworld/UE4SS-Palworld.zip"
$runtimeSha256 = "7C80B2F4A29BAF0F384552C8517E58196E78C8A1B8530637B7179EDDAE1B54A9"
$cachePath = Join-Path $PSScriptRoot ".cache"
$runtimeZip = Join-Path $cachePath "UE4SS-Palworld-2026-07-09.zip"
$runtimeExtract = Join-Path $cachePath "UE4SS-Palworld-2026-07-09"
$releasePath = Join-Path $PSScriptRoot "release"
$stagePath = Join-Path $releasePath "PalworldAccessibleControls-Steam"
$zipPath = Join-Path $releasePath "PalworldAccessibleControls-Steam-v$Version.zip"

New-Item -ItemType Directory -Path $cachePath,$releasePath -Force | Out-Null

if (-not (Test-Path -LiteralPath $runtimeZip)) {
    Write-Host "Downloading the pinned Palworld UE4SS runtime..."
    Invoke-WebRequest -Uri $runtimeUrl -OutFile $runtimeZip
}

$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $runtimeZip).Hash
if ($actualHash -ne $runtimeSha256) {
    throw "UE4SS runtime digest mismatch. Expected $runtimeSha256 but received $actualHash."
}

if (-not (Test-Path -LiteralPath (Join-Path $runtimeExtract "ue4ss\UE4SS.dll"))) {
    if (Test-Path -LiteralPath $runtimeExtract) {
        $resolvedCache = (Resolve-Path -LiteralPath $cachePath).Path
        $resolvedExtract = (Resolve-Path -LiteralPath $runtimeExtract).Path
        if (-not $resolvedExtract.StartsWith($resolvedCache + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clear a runtime path outside the build cache."
        }
        Remove-Item -LiteralPath $resolvedExtract -Recurse -Force
    }
    Expand-Archive -LiteralPath $runtimeZip -DestinationPath $runtimeExtract
}

if (Test-Path -LiteralPath $stagePath) {
    $resolvedRelease = (Resolve-Path -LiteralPath $releasePath).Path
    $resolvedStage = (Resolve-Path -LiteralPath $stagePath).Path
    if (-not $resolvedStage.StartsWith($resolvedRelease + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clear a stage path outside the release directory."
    }
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}

New-Item -ItemType Directory -Path (Join-Path $stagePath "Payload\Win64\ue4ss\Mods") -Force | Out-Null

$installerSource = Join-Path $PSScriptRoot "NativeMod\Installer"
Copy-Item -Path (Join-Path $installerSource "*") -Destination $stagePath -Recurse
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "LICENSE") -Destination (Join-Path $stagePath "LICENSE")

$payloadWin64 = Join-Path $stagePath "Payload\Win64"
Copy-Item -LiteralPath (Join-Path $runtimeExtract "dwmapi.dll") -Destination (Join-Path $payloadWin64 "dwmapi.dll")
foreach ($file in @("UE4SS.dll", "UE4SS-settings.ini", "MemberVariableLayout.ini", "LICENSE")) {
    Copy-Item -LiteralPath (Join-Path $runtimeExtract "ue4ss\$file") -Destination (Join-Path $payloadWin64 "ue4ss\$file")
}

$modSource = Join-Path $PSScriptRoot "NativeMod\PalworldAccessibleControls"
$modDestination = Join-Path $payloadWin64 "ue4ss\Mods\PalworldAccessibleControls"
Copy-Item -LiteralPath $modSource -Destination $modDestination -Recurse

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $stagePath "*") -DestinationPath $zipPath -CompressionLevel Optimal

$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash
Write-Host "Release package: $zipPath" -ForegroundColor Green
Write-Host "SHA-256: $zipHash"
