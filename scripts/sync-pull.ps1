# Pull latest NFG code from GitHub (run on PC before working, or after Mac pushed).
param(
  [switch]$NoStash
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$dirty = git status --porcelain
$stashed = $false

if ($dirty -and -not $NoStash) {
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
  Write-Host "Stashing local changes ($stamp)..." -ForegroundColor Yellow
  git stash push -u -m "sync-pull auto-stash $stamp"
  $stashed = $true
} elseif ($dirty) {
  Write-Host "Local changes present. Commit, stash, or discard before pulling." -ForegroundColor Red
  git status -sb
  exit 1
}

git fetch origin
git pull --rebase origin main

if ($stashed) {
  Write-Host "Re-applying your stashed changes..." -ForegroundColor Yellow
  git stash pop
}

Write-Host ""
Write-Host "Synced with origin/main:" -ForegroundColor Green
git log -1 --oneline

& (Join-Path $PSScriptRoot "run-pending-task.ps1")
