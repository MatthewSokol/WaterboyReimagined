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
Write-Host "Installed WaterboyReimagined to $dst"
