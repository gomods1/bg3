# BG3 Access uninstaller: removes exactly what install.ps1 recorded in its manifest
# (bin\BG3Access\install-manifest.json) and the mod's entry in modsettings.lsx. The Script
# Extender stays (other mods use it) unless -RemoveScriptExtender is given and the installer had
# installed it. Plain console text, so a screen reader reads it.
#
# Usage: uninstall.bat (or: powershell -ExecutionPolicy Bypass -File uninstall.ps1 [-GamePath <folder>]
#        [-ProfilePath <folder>] [-RemoveScriptExtender])
param(
    [string]$GamePath = "",
    [string]$ProfilePath = "", # the game's user folder when it is not the usual one under LOCALAPPDATA
    [switch]$RemoveScriptExtender
)

$ErrorActionPreference = "Stop"

$ModUuid = "808d24db-b159-4ee7-b745-408923b186ab"
$GameProfile = if ($ProfilePath) { $ProfilePath } else { Join-Path $env:LOCALAPPDATA "Larian Studios\Baldur's Gate 3" }
$ModSettings = Join-Path $GameProfile "PlayerProfiles\Public\modsettings.lsx"

function Say([string]$text) { Write-Host $text }
function Fail([string]$text) {
    Write-Host ""
    Write-Host "Uninstall stopped: $text"
    exit 1
}

function Find-Manifest {
    if ($GamePath) { return Join-Path $GamePath "bin\BG3Access\install-manifest.json" }
    $steam = $null
    try { $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath -replace "/", "\" } catch { }
    $libraries = @()
    if ($steam) {
        $libraries += $steam
        $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libraries += ($m.Groups[1].Value -replace "\\\\", "\") }
        }
    }
    foreach ($lib in $libraries) {
        $candidate = Join-Path $lib "steamapps\common\Baldurs Gate 3\bin\BG3Access\install-manifest.json"
        if (Test-Path $candidate) { return $candidate }
    }
    $folder = Read-Host "Type the game folder (the one that contains the bin folder) and press Enter"
    return Join-Path $folder "bin\BG3Access\install-manifest.json"
}

# Removes the ModuleShortDesc node that carries the mod's UUID.
function Unregister-Mod {
    if (-not (Test-Path $ModSettings)) { return }
    $text = [System.IO.File]::ReadAllText($ModSettings)
    $pattern = ' *<node id="ModuleShortDesc">(?:(?!</node>).)*?' + [regex]::Escape($ModUuid) + '.*?</node>\r?\n'
    $new = [regex]::Replace($text, $pattern, "", [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($new -ne $text) {
        [System.IO.File]::WriteAllText($ModSettings, $new)
        Say "Mod list: BG3 Access removed from modsettings.lsx."
    }
}

Say "BG3 Access uninstaller."
$manifestPath = Find-Manifest
if (-not (Test-Path $manifestPath)) { Fail "no install manifest at ${manifestPath}: BG3 Access does not seem to be installed there." }
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$gameBin = Join-Path $manifest.game "bin"
if (Get-Process -Name "bg3", "bg3_dx11" -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($gameBin, [System.StringComparison]::OrdinalIgnoreCase) }) {
    Fail "Baldur's Gate 3 is running. Quit the game and run this again."
}

$removed = 0
foreach ($file in $manifest.files) {
    if (Test-Path -LiteralPath $file) {
        Remove-Item -LiteralPath $file -Force
        $removed++
    }
}
Say "Files removed: $removed."

Unregister-Mod

$bin = Join-Path $manifest.game "bin"
if ($RemoveScriptExtender -and $manifest.scriptExtenderInstalled) {
    Remove-Item -LiteralPath (Join-Path $bin "DWrite.dll") -Force -ErrorAction SilentlyContinue
    Say "Script Extender removed."
} else {
    Say "Script Extender kept (other mods may use it; run with -RemoveScriptExtender to remove it)."
}

Remove-Item -LiteralPath $manifestPath -Force
$folder = Join-Path $bin "BG3Access"
if ((Test-Path $folder) -and -not (Get-ChildItem -LiteralPath $folder -Recurse -File)) {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

Say ""
Say "BG3 Access is uninstalled. Your saves were not changed."
exit 0
