# Copies the Waterboy Reimagined addon into the WoW Forever AddOns folder (overwriting the installed copy).
param(
    [string]$WowRoot = "C:\Program Files (x86)\World of Warcraft"
)

$src = Join-Path $PSScriptRoot "WaterboyReimagined"
$addons = Join-Path $WowRoot "_forever_\Interface\AddOns"
if (-not (Test-Path $addons)) {
    Write-Error "AddOns folder not found: $addons  (pass -WowRoot to point at your install)"
    exit 1
}

$dst = Join-Path $addons "WaterboyReimagined"
New-Item -ItemType Directory -Force $dst | Out-Null
Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force

# Fill the .toc's @project-version@ the way the BigWigs packager does from the release tag.
$version = git -C $PSScriptRoot describe --tags --always --dirty 2>$null
if (-not $version) { $version = "dev" }
Get-ChildItem $dst -Filter *.toc | ForEach-Object {
    $text = [IO.File]::ReadAllText($_.FullName)
    [IO.File]::WriteAllText($_.FullName, $text.Replace("@project-version@", $version))
}
Write-Host "Installed WaterboyReimagined ($version) to $dst"
