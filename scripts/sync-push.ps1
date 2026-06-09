# Push local NFG changes to GitHub (run on PC after Cursor edits).
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Message
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

git fetch origin 2>$null
$behind = git rev-list HEAD..origin/main --count 2>$null
if ($behind -and [int]$behind -gt 0) {
  Write-Host "You are $behind commit(s) behind origin/main." -ForegroundColor Yellow
  Write-Host "Run .\scripts\sync-pull.ps1 first, then push again."
  exit 1
}

$dirty = git status --porcelain
if (-not $dirty) {
  Write-Host "Nothing to commit. Working tree clean."
  exit 0
}

Write-Host "Changes to push:" -ForegroundColor Cyan
git status -sb
Write-Host ""

git add -A
git commit -m $Message
git push origin main

Write-Host ""
Write-Host "Pushed to https://github.com/Y666SUF/NFG (main)" -ForegroundColor Green
Write-Host "On MacBook:  cd ~/Documents/NFG && ./scripts/sync-pull.sh"
