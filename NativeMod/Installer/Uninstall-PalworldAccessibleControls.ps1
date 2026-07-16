param(
    [string]$GamePath
)

$ErrorActionPreference = "Stop"

function Test-PalworldPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return Test-Path -LiteralPath (Join-Path $Path "Pal\Binaries\Win64\Palworld-Win64-Shipping.exe")
}

function Find-PalworldPath {
    param([string]$RequestedPath)
    if (Test-PalworldPath $RequestedPath) { return (Resolve-Path -LiteralPath $RequestedPath).Path }

    $roots = [System.Collections.Generic.List[string]]::new()
    try {
        $steam = Get-ItemProperty -LiteralPath "HKCU:\Software\Valve\Steam" -ErrorAction Stop
        if ($steam.SteamPath) { $roots.Add($steam.SteamPath) }
    } catch {
    }

    foreach ($root in $roots) {
        $rootsToCheck = [System.Collections.Generic.List[string]]::new()
        $rootsToCheck.Add($root)
        $libraryFile = Join-Path $root "steamapps\libraryfolders.vdf"
        if (Test-Path -LiteralPath $libraryFile) {
            $content = Get-Content -LiteralPath $libraryFile -Raw
            foreach ($match in [regex]::Matches($content, '"path"\s+"([^"]+)"')) {
                $rootsToCheck.Add($match.Groups[1].Value.Replace('\\', '\'))
            }
        }
        foreach ($library in $rootsToCheck) {
            $candidate = Join-Path $library "steamapps\common\Palworld"
            if (Test-PalworldPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
        }
    }

    throw "Steam Palworld was not found. Re-run with -GamePath 'X:\Steam\steamapps\common\Palworld'."
}

if (Get-Process -Name "Palworld-Win64-Shipping" -ErrorAction SilentlyContinue) {
    throw "Close Palworld before uninstalling the mod."
}

$resolvedGamePath = Find-PalworldPath $GamePath
$modsPath = Join-Path $resolvedGamePath "Pal\Binaries\Win64\ue4ss\Mods"
$modPath = Join-Path $modsPath "PalworldAccessibleControls"

if (-not (Test-Path -LiteralPath $modPath)) {
    Write-Host "Palworld Accessible Controls is not installed." -ForegroundColor Yellow
    exit 0
}

$resolvedModsPath = (Resolve-Path -LiteralPath $modsPath).Path
$resolvedModPath = (Resolve-Path -LiteralPath $modPath).Path
if (-not $resolvedModPath.StartsWith($resolvedModsPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove a path outside the UE4SS Mods directory."
}

Remove-Item -LiteralPath $resolvedModPath -Recurse -Force
Write-Host "Palworld Accessible Controls was removed." -ForegroundColor Green
Write-Host "The shared UE4SS runtime was preserved in case another mod uses it."
