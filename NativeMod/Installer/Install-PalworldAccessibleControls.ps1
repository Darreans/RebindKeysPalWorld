param(
    [string]$GamePath
)

$ErrorActionPreference = "Stop"

function Test-PalworldPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $executable = Join-Path $Path "Pal\Binaries\Win64\Palworld-Win64-Shipping.exe"
    return Test-Path -LiteralPath $executable
}

function Find-PalworldPath {
    param([string]$RequestedPath)

    if (Test-PalworldPath $RequestedPath) {
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $steamRoots = [System.Collections.Generic.List[string]]::new()
    foreach ($registryPath in @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam"
    )) {
        try {
            $steamValue = Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop
            foreach ($name in @("SteamPath", "InstallPath")) {
                $value = $steamValue.$name
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    $steamRoots.Add($value)
                }
            }
        } catch {
        }
    }

    foreach ($fallback in @(
        "$env:ProgramFiles(x86)\Steam",
        "$env:ProgramFiles\Steam"
    )) {
        if (-not [string]::IsNullOrWhiteSpace($fallback)) {
            $steamRoots.Add($fallback)
        }
    }

    $libraryRoots = [System.Collections.Generic.List[string]]::new()
    foreach ($steamRoot in $steamRoots | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $steamRoot)) {
            continue
        }

        $libraryRoots.Add($steamRoot)
        $libraryFile = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path -LiteralPath $libraryFile) {
            $content = Get-Content -LiteralPath $libraryFile -Raw
            foreach ($match in [regex]::Matches($content, '"path"\s+"([^"]+)"')) {
                $libraryRoots.Add($match.Groups[1].Value.Replace('\\', '\'))
            }
        }
    }

    foreach ($libraryRoot in $libraryRoots | Select-Object -Unique) {
        $candidate = Join-Path $libraryRoot "steamapps\common\Palworld"
        if (Test-PalworldPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Steam Palworld was not found. Re-run with -GamePath 'X:\Steam\steamapps\common\Palworld'."
}

if (Get-Process -Name "Palworld-Win64-Shipping" -ErrorAction SilentlyContinue) {
    throw "Close Palworld before installing the mod."
}

$resolvedGamePath = Find-PalworldPath $GamePath
$win64Path = Join-Path $resolvedGamePath "Pal\Binaries\Win64"
$payloadPath = Join-Path $PSScriptRoot "Payload\Win64"
$payloadModPath = Join-Path $payloadPath "ue4ss\Mods\PalworldAccessibleControls"
$targetRuntimePath = Join-Path $win64Path "ue4ss"
$targetModsPath = Join-Path $targetRuntimePath "Mods"
$targetModPath = Join-Path $targetModsPath "PalworldAccessibleControls"

if (-not (Test-Path -LiteralPath $payloadModPath)) {
    throw "The install payload is incomplete. Extract the entire zip before running the installer."
}

$runtimeInstalled = Test-Path -LiteralPath (Join-Path $targetRuntimePath "UE4SS.dll")
if (-not $runtimeInstalled) {
    $proxyPath = Join-Path $win64Path "dwmapi.dll"
    if (Test-Path -LiteralPath $proxyPath) {
        throw "A different dwmapi.dll loader is already installed. Remove it or install this mod into the existing loader manually."
    }

    Copy-Item -LiteralPath (Join-Path $payloadPath "dwmapi.dll") -Destination $proxyPath
    New-Item -ItemType Directory -Path $targetRuntimePath -Force | Out-Null
    foreach ($file in @("UE4SS.dll", "UE4SS-settings.ini", "MemberVariableLayout.ini", "LICENSE")) {
        Copy-Item -LiteralPath (Join-Path $payloadPath "ue4ss\$file") -Destination (Join-Path $targetRuntimePath $file)
    }
    Write-Host "Installed the Palworld-compatible UE4SS runtime." -ForegroundColor Cyan
} else {
    Write-Host "Existing UE4SS runtime detected and preserved." -ForegroundColor DarkCyan
}

New-Item -ItemType Directory -Path $targetModsPath -Force | Out-Null

$savedConfig = $null
$existingConfigPath = Join-Path $targetModPath "config.ini"
if (Test-Path -LiteralPath $existingConfigPath) {
    $savedConfig = Get-Content -LiteralPath $existingConfigPath -Raw
}

if (Test-Path -LiteralPath $targetModPath) {
    $resolvedModsPath = (Resolve-Path -LiteralPath $targetModsPath).Path
    $resolvedTargetPath = (Resolve-Path -LiteralPath $targetModPath).Path
    if (-not $resolvedTargetPath.StartsWith($resolvedModsPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to replace a mod path outside the UE4SS Mods directory."
    }
    Remove-Item -LiteralPath $resolvedTargetPath -Recurse -Force
}

Copy-Item -LiteralPath $payloadModPath -Destination $targetModPath -Recurse
if ($null -ne $savedConfig) {
    [IO.File]::WriteAllText((Join-Path $targetModPath "config.ini"), $savedConfig)
}

Write-Host ""
Write-Host "Palworld Accessible Controls is installed." -ForegroundColor Green
Write-Host "Game: $resolvedGamePath"
Write-Host "Start Palworld through Steam, accept its normal mod warning, and open Options."
Write-Host "There is no desktop app or tray icon to run."
