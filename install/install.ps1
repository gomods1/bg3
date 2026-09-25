# BG3 Access installer (gate.md section 16). Plain console text, so a screen reader reads it.
#
# What it does, in order:
#   1. finds Baldur's Gate 3 (Steam libraries, GOG, or -GamePath), refuses while the game runs;
#   2. checks the game version against the tested one (a warning, not a stop);
#   3. installs the Script Extender if it is missing: its official updater DWrite.dll, downloaded
#      from the Script Extender's GitHub releases (never bundled);
#   4. copies the mod's files: bin\version.dll (loads the speech bridge), bin\BG3Access\ (bridge,
#      Prism speech library and its licences), and BG3Access.pak into the profile's Mods folder;
#   5. adds BG3 Access to modsettings.lsx (a backup is kept next to it; before the game's first
#      start there is none, and a minimal one is written so the mod reads the first-run screens);
#   6. puts a desktop shortcut "Baldur's Gate 3 (BG3 Access)" that starts bing3.exe with the
#      game's own --skip-launcher: Larian's launcher, which screen readers cannot use well, opens
#      on every Steam start (the Script Extender's DisableLauncher did not skip it, 2026-09-24);
#   7. writes a manifest (bin\BG3Access\install-manifest.json) so uninstall removes exactly this;
#   8. checks that every file is in place.
#
# Usage: install.bat (or: powershell -ExecutionPolicy Bypass -File install.ps1 [-GamePath <folder>]
#        [-ProfilePath <folder>])
param(
    [string]$GamePath = "",
    [string]$ProfilePath = "" # the game's user folder when it is not the usual one under LOCALAPPDATA
)

$ErrorActionPreference = "Stop"

$ModUuid = "808d24db-b159-4ee7-b745-408923b186ab"
$ModVersion64 = "36028797018963968"
$TestedGameVersion = "4.1.1.7398727"
$SteamAppId = "1086940"
$GogGameId = "1456460669"
$SeReleasesApi = "https://api.github.com/repos/Norbyte/bg3se/releases/latest"

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Files = Join-Path $Here "files"
$GameProfile = if ($ProfilePath) { $ProfilePath } else { Join-Path $env:LOCALAPPDATA "Larian Studios\Baldur's Gate 3" }
$ModSettings = Join-Path $GameProfile "PlayerProfiles\Public\modsettings.lsx"

function Say([string]$text) { Write-Host $text }
function Fail([string]$text) {
    Write-Host ""
    Write-Host "Installation stopped: $text"
    exit 1
}

function Test-GameFolder([string]$folder) {
    return $folder -and (Test-Path (Join-Path $folder "bin\bg3.exe"))
}

# Steam library folders from libraryfolders.vdf ("path" entries), plus Steam's own folder.
function Get-SteamLibraries {
    $out = @()
    $steam = $null
    try { $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath } catch { }
    if (-not $steam) { return $out }
    $steam = $steam -replace "/", "\"
    $out += $steam
    $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
            $out += ($m.Groups[1].Value -replace "\\\\", "\")
        }
    }
    return $out | Select-Object -Unique
}

function Find-Game {
    if ($GamePath) {
        if (Test-GameFolder $GamePath) { return $GamePath }
        Fail "no bin\bg3.exe in $GamePath."
    }
    foreach ($lib in Get-SteamLibraries) {
        $folder = Join-Path $lib "steamapps\common\Baldurs Gate 3"
        if (Test-GameFolder $folder) { return $folder }
    }
    foreach ($key in @("HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\$GogGameId", "HKLM:\SOFTWARE\GOG.com\Games\$GogGameId")) {
        try {
            $folder = (Get-ItemProperty $key -ErrorAction Stop).path
            if (Test-GameFolder $folder) { return $folder }
        } catch { }
    }
    Say "Baldur's Gate 3 was not found in the Steam libraries or GOG."
    $folder = Read-Host "Type the game folder (the one that contains the bin folder) and press Enter"
    if (Test-GameFolder $folder) { return $folder }
    Fail "no bin\bg3.exe in $folder."
}

# .NET directly: Get-FileHash is missing where the Utility module does not autoload.
function Get-FileSha256([string]$path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($path)
    try { return [System.BitConverter]::ToString($sha.ComputeHash($stream)) } finally { $stream.Dispose(); $sha.Dispose() }
}

# Copies src to dst and records it in the manifest list.
function Install-File([string]$src, [string]$dst, [System.Collections.ArrayList]$installed) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
    [void]$installed.Add($dst)
}

function Install-ScriptExtender([string]$bin) {
    $dwrite = Join-Path $bin "DWrite.dll"
    if (Test-Path $dwrite) {
        Say "Script Extender: already installed."
        return $false
    }
    Say "Script Extender: downloading from its official GitHub releases..."
    $release = Invoke-RestMethod -Uri $SeReleasesApi -Headers @{ "User-Agent" = "BG3Access-installer" }
    $asset = $release.assets | Where-Object { $_.name -like "BG3SE-Updater*.zip" } | Select-Object -First 1
    if (-not $asset) { Fail "the Script Extender release has no updater download. Install it by hand from https://github.com/Norbyte/bg3se/releases and run this again." }
    $zip = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
    try {
        $entry = $archive.Entries | Where-Object { $_.Name -eq "DWrite.dll" } | Select-Object -First 1
        if (-not $entry) { Fail "the Script Extender download has no DWrite.dll." }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dwrite, $true)
    } finally {
        $archive.Dispose()
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    }
    Say "Script Extender: installed ($($release.tag_name)). It downloads its own files when the game starts."
    return $true
}

# The file the game writes on its first start, with only its own GustavX module (game 4.1.1).
$DefaultModSettings = @"
<?xml version="1.0" encoding="UTF-8"?>
<save>
    <version major="4" minor="8" revision="0" build="700"/>
    <region id="ModuleSettings">
        <node id="root">
            <children>
                <node id="Mods">
                    <children>
                        <node id="ModuleShortDesc">
                            <attribute id="Folder" type="LSString" value="GustavX"/>
                            <attribute id="MD5" type="LSString" value=""/>
                            <attribute id="Name" type="LSString" value="GustavX"/>
                            <attribute id="PublishHandle" type="uint64" value="0"/>
                            <attribute id="UUID" type="guid" value="cb555efe-2d9e-131f-8195-a89329d218ea"/>
                            <attribute id="Version64" type="int64" value="36028797018963968"/>
                        </node>
                    </children>
                </node>
            </children>
        </node>
    </region>
</save>
"@

# Adds the mod's ModuleShortDesc after the last module in the Mods list of modsettings.lsx.
function Register-Mod {
    if (-not (Test-Path $ModSettings)) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ModSettings) | Out-Null
        [System.IO.File]::WriteAllText($ModSettings, ($DefaultModSettings -replace "`r`n", "`n"))
        Say "Mod list: the game has not been started yet; wrote its default modsettings.lsx."
    }
    $text = [System.IO.File]::ReadAllText($ModSettings)
    if ($text.Contains($ModUuid)) {
        Say "Mod list: BG3 Access is already in modsettings.lsx."
        return $false
    }
    $backup = "$ModSettings.bg3access-backup"
    if (-not (Test-Path $backup)) { Copy-Item -LiteralPath $ModSettings -Destination $backup }
    $entry = @"
                        <node id="ModuleShortDesc">
                            <attribute id="Folder" type="LSString" value="BG3Access"/>
                            <attribute id="MD5" type="LSString" value=""/>
                            <attribute id="Name" type="LSString" value="BG3 Access"/>
                            <attribute id="PublishHandle" type="uint64" value="0"/>
                            <attribute id="UUID" type="guid" value="$ModUuid"/>
                            <attribute id="Version64" type="int64" value="$ModVersion64"/>
                        </node>

"@
    $pattern = '( *)</node>\r?\n(?=\s*</children>\s*</node>\s*</children>\s*</node>\s*</region>)'
    $found = [regex]::Matches($text, $pattern)
    if ($found.Count -eq 0) { Fail "modsettings.lsx has an unexpected layout; add BG3 Access with BG3 Mod Manager instead." }
    $last = $found[$found.Count - 1]
    $pos = $last.Index + $last.Length
    $text = $text.Substring(0, $pos) + $entry + $text.Substring($pos)
    [System.IO.File]::WriteAllText($ModSettings, $text)
    Say "Mod list: BG3 Access added to modsettings.lsx (backup: modsettings.lsx.bg3access-backup)."
    return $true
}

# --- main ---

Say "BG3 Access installer."
if (-not (Test-Path $Files)) { Fail "the files folder is missing next to this script. Extract the whole download first." }
$game = Find-Game
$bin = Join-Path $game "bin"
Say "Game found: $game"
if (Get-Process -Name "bg3", "bg3_dx11" -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($bin, [System.StringComparison]::OrdinalIgnoreCase) }) {
    Fail "Baldur's Gate 3 is running. Quit the game and run this again."
}

# ProductVersion holds the game's version string (4.1.1.7398727); FileVersion reads 1.0.0.0.
$version = (Get-Item (Join-Path $bin "bg3.exe")).VersionInfo.ProductVersion
if ($version -ne $TestedGameVersion) {
    Say "Warning: game version $version; BG3 Access was tested on $TestedGameVersion. It may still work; if the game is silent after the update, check for a new BG3 Access."
} else {
    Say "Game version ${version}: tested."
}

# Another mod's version.dll would be replaced by ours: stop instead.
$ourProxy = Join-Path $Files "bin\version.dll"
$theirProxy = Join-Path $bin "version.dll"
$manifestPath = Join-Path $bin "BG3Access\install-manifest.json"
if ((Test-Path $theirProxy) -and -not (Test-Path $manifestPath) -and ((Get-FileSha256 $theirProxy) -ne (Get-FileSha256 $ourProxy))) {
    Fail "bin\version.dll already exists and belongs to another program. BG3 Access needs that file name to load its speech bridge."
}

$previous = if (Test-Path $manifestPath) { Get-Content $manifestPath -Raw | ConvertFrom-Json } else { $null }
$seInstalled = Install-ScriptExtender $bin

$installed = New-Object System.Collections.ArrayList
Install-File $ourProxy $theirProxy $installed
Get-ChildItem -Path (Join-Path $Files "bin\BG3Access") -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring((Join-Path $Files "bin\BG3Access").Length + 1)
    Install-File $_.FullName (Join-Path $bin "BG3Access\$relative") $installed
}
Install-File (Join-Path $Files "Mods\BG3Access.pak") (Join-Path $GameProfile "Mods\BG3Access.pak") $installed
Say "Files copied: $($installed.Count)."

[void](Register-Mod)

# A desktop shortcut that starts the game without Larian's launcher (Steam must be running for a
# Steam copy; it starts the game's own executable, as Steam does after the launcher).
$shortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Baldur's Gate 3 (BG3 Access).lnk"
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($shortcut)
$link.TargetPath = Join-Path $bin "bg3.exe"
$link.Arguments = "--skip-launcher"
$link.WorkingDirectory = $bin
$link.Description = "Baldur's Gate 3 without the launcher, with BG3 Access"
$link.Save()
[void]$installed.Add($shortcut)
Say "Desktop shortcut: Baldur's Gate 3 (BG3 Access). It starts the game without Larian's launcher."

$manifest = [ordered]@{
    version = 1
    game = $game
    files = @($installed)
    scriptExtenderInstalled = $seInstalled -or ($previous -and $previous.scriptExtenderInstalled)
}
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json))

# Self-test: every file is where the game and the Script Extender look for it.
$missing = @($installed | Where-Object { -not (Test-Path $_) })
if (-not (Test-Path (Join-Path $bin "DWrite.dll"))) { $missing += "bin\DWrite.dll (Script Extender)" }
if (-not ([System.IO.File]::ReadAllText($ModSettings)).Contains($ModUuid)) { $missing += "the modsettings.lsx entry" }
if ($missing.Count -gt 0) { Fail "missing after install: $($missing -join ', ')." }

Say ""
Say "BG3 Access is installed. Start the game with the desktop shortcut Baldur's Gate 3 (BG3 Access); Steam must be running for a Steam copy."
Say "About 20 seconds after the game starts you should hear: BG3 Access loaded. Control M opens the mod menu."
Say "If the game stays silent, see the README (logs, and the note about the game's crash check)."
exit 0
