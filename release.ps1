# Builds the CurseForge upload: dist\WaterboyReimagined-<version>.zip with one top-level WaterboyReimagined\ folder
# (the addon files plus LICENSE). The version comes from the .toc. Zip entries use forward slashes, which
# Compress-Archive on Windows PowerShell 5.1 doesn't. Every entry is dated 00:00 UTC of today, like the
# commits, so the zip doesn't show when you worked.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$root = $PSScriptRoot
$src = Join-Path $root "WaterboyReimagined"
$toc = Get-Content (Join-Path $src "WaterboyReimagined.toc")
$version = ($toc | Where-Object { $_ -match '^## Version:\s*(.+)$' } | ForEach-Object { $Matches[1].Trim() }) | Select-Object -First 1
if (-not $version) { throw "No '## Version:' line in the .toc" }

# The release notes: this version's CHANGELOG.md entry, which must be there.
$changelog = [IO.File]::ReadAllText((Join-Path $root "CHANGELOG.md"))
$m = [regex]::Match($changelog, "(?ms)^## \[" + [regex]::Escape($version) + "\][^\n]*\n(.*?)(?=^## \[|\z)")
if (-not $m.Success) { throw "CHANGELOG.md has no '## [$version]' entry" }

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force $dist | Out-Null
$notesPath = Join-Path $dist "WaterboyReimagined-$version-changelog.md"
[IO.File]::WriteAllText($notesPath, $m.Groups[1].Value.Trim() + "`n")
$zipPath = Join-Path $dist "WaterboyReimagined-$version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$files = @(Get-ChildItem $src -Recurse -File | ForEach-Object {
    @{ Path = $_.FullName; Entry = "WaterboyReimagined/" + $_.FullName.Substring($src.Length + 1).Replace('\', '/') }
})
$files += @{ Path = (Join-Path $root "LICENSE"); Entry = "WaterboyReimagined/LICENSE" }

$stamp = [DateTimeOffset]::new([DateTime]::UtcNow.Date, [TimeSpan]::Zero)
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in $files) {
        $entry = $zip.CreateEntry($f.Entry, [System.IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = $stamp
        $out = $entry.Open()
        $in = [System.IO.File]::OpenRead($f.Path)
        try { $in.CopyTo($out) } finally { $in.Dispose(); $out.Dispose() }
    }
} finally { $zip.Dispose() }
Write-Host "Built $zipPath ($($files.Count) files)"
Write-Host "Release notes (paste into CurseForge): $notesPath"
