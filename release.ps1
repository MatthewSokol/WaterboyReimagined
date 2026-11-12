# Builds the CurseForge upload: dist\WaterboyReimagined-<version>.zip with one top-level WaterboyReimagined\ folder
# (the addon files plus LICENSE). The version comes from the vX.Y.Z tag on HEAD and fills the .toc's @project-version@. Zip entries use forward slashes, which
# Compress-Archive on Windows PowerShell 5.1 doesn't. Every entry is dated 00:00 UTC of today, like the
# commits, so the zip doesn't show when you worked.
# Test build from an untagged commit: -Version 1.2.3-test
param([string]$Version)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$root = $PSScriptRoot
$src = Join-Path $root "WaterboyReimagined"
# The release tag on HEAD gives the version (v1.2.3 -> 1.2.3). git's stderr must not stop the script.
$tag = $null
if (-not $Version) {
    $ErrorActionPreference = "Continue"
    $tag = git -C $root describe --tags --exact-match --match "v[0-9]*" 2>$null
    $ErrorActionPreference = "Stop"
    if (-not $tag) { throw "HEAD has no release tag. Tag the release on main first (git tag vX.Y.Z), or pass -Version for a test build." }
    $Version = $tag -replace '^v', ''
}
$tocVersion = if ($tag) { $tag } else { $Version }

# The release notes: every candidate's CHANGELOG.md entry since the last release (dev-routine gives each merged
# change its own entry), from this version's entry down to the previous release tag's. A test build takes one entry.
$changelog = [IO.File]::ReadAllText((Join-Path $root "CHANGELOG.md"))
$start = [regex]::Match($changelog, "(?m)^## \[" + [regex]::Escape($version) + "\]")
if (-not $start.Success) { throw "CHANGELOG.md has no '## [$version]' entry" }
$rest = $changelog.Substring($start.Index)
$prev = $null
if ($tag) {
    $ErrorActionPreference = "Continue"
    $prev = git -C $root describe --tags --abbrev=0 --match "v[0-9]*" "$tag^" 2>$null
    $ErrorActionPreference = "Stop"
}
$next = if ($tag -and $prev) { "(?m)^## \[" + [regex]::Escape(($prev -replace '^v', '')) + "\]" } elseif ($tag) { "(?!)" } else { "(?m)(?<!\A)^## \[" }
$end = [regex]::Match($rest, $next)
$notes = if ($end.Success) { $rest.Substring(0, $end.Index) } else { $rest }

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force $dist | Out-Null
$notesPath = Join-Path $dist "WaterboyReimagined-$version-changelog.md"
[IO.File]::WriteAllText($notesPath, $notes.Trim() + "`n")
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
        try {
            if ($f.Path -like '*.toc') {
                $bytes = [Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($f.Path).Replace('@project-version@', $tocVersion))
                $out.Write($bytes, 0, $bytes.Length)
            } else { $in.CopyTo($out) }
        } finally { $in.Dispose(); $out.Dispose() }
    }
} finally { $zip.Dispose() }
Write-Host "Built $zipPath ($($files.Count) files)"
Write-Host "Release notes (paste into CurseForge): $notesPath"
