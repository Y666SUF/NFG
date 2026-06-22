# Pull latest NFG code from GitHub (run on PC before working, or after Mac pushed).
param(
  [switch]$NoStash,
  # Safer for PC live edits: commit local work, then merge (no stash/rebase).
  [switch]$Merge
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

# Stale lock from interrupted git
if (Test-Path (Join-Path $Root ".git\index.lock")) {
  Write-Host "Removing stale .git/index.lock..." -ForegroundColor Yellow
  Remove-Item (Join-Path $Root ".git\index.lock") -Force
}

$dirty = git status --porcelain
$stashed = $false

if ($Merge) {
  if ($dirty) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    Write-Host "Committing local PC work before merge ($stamp)..." -ForegroundColor Yellow
    git add -A
    git commit -m "PC live: local server tweaks before sync-pull merge $stamp"
  }
  git fetch origin
  $behind = [int](git rev-list HEAD..origin/main --count 2>$null)
  if ($behind -eq 0) {
    Write-Host "Already up to date with origin/main." -ForegroundColor Green
  } else {
    Write-Host "Merging $behind commit(s) from origin/main..." -ForegroundColor Cyan
    git merge origin/main -m "Merge origin/main into PC live branch"
    if ($LASTEXITCODE -ne 0) {
      Write-Host ""
      Write-Host "Merge conflicts — resolve markers, then:" -ForegroundColor Red
      Write-Host '  git add <resolved files>'      Write-Host "  git commit -m ""Merge origin/main while keeping PC live features"""
      Write-Host ""
      Write-Host "See docs/WINDOWS_MERGE_PULL_PROMPT.txt for conflict rules." -ForegroundColor Yellow
      exit 1
    }
  }
} else {
  if ($dirty -and -not $NoStash) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    Write-Host "Stashing local changes ($stamp)..." -ForegroundColor Yellow
    git stash push -u -m "sync-pull auto-stash $stamp"
    $stashed = $true
  } elseif ($dirty) {
    Write-Host "Local changes present. Use one of:" -ForegroundColor Red
    Write-Host "  .\scripts\sync-pull.ps1 -Merge     # commit + merge (recommended on PC)"
    Write-Host "  git add -A; git commit -m ""...""; .\scripts\sync-pull.ps1 -NoStash"
    git status -sb
    exit 1
  }

  git fetch origin
  git pull --rebase origin main

  if ($stashed) {
    Write-Host "Re-applying your stashed changes..." -ForegroundColor Yellow
    git stash pop
    if ($LASTEXITCODE -ne 0) {
      Write-Host ""
      Write-Host "Stash pop failed (conflicts). Options:" -ForegroundColor Red
      Write-Host "  git status"
      Write-Host "  Resolve conflicts, then: git add . ; git stash drop"
      Write-Host "  Or abort and use: .\scripts\sync-pull.ps1 -Merge"
      exit 1
    }
  }
}

Write-Host ""
Write-Host "Synced with origin/main:" -ForegroundColor Green
git log -1 --oneline

& (Join-Path $PSScriptRoot "run-pending-task.ps1")
