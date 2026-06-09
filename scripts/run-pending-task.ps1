# Show (and copy) the pending cross-device Agent prompt for THIS machine.
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$PendingFile = Join-Path $Root "docs\cross-device\pending-on-pc.md"
if (-not (Test-Path $PendingFile)) {
  Write-Host "No pending file at docs/cross-device/pending-on-pc.md"
  exit 0
}

$raw = Get-Content $PendingFile -Raw
if ($raw -notmatch 'cross_device_status:\s*pending') {
  Write-Host "No pending PC task (cross_device_status is not pending)." -ForegroundColor Green
  Write-Host "File: docs/cross-device/pending-on-pc.md"
  exit 0
}

$title = ""
if ($raw -match 'title:\s*(.+)') { $title = $Matches[1].Trim().Trim('"').Trim("'") }

$prompt = "Run the pending cross-device task in @docs/cross-device/pending-on-pc.md"

Write-Host ""
Write-Host "PENDING PC TASK$(if ($title) { ": $title" })" -ForegroundColor Yellow
Write-Host "=============================================="
Write-Host ""
Write-Host "1. Open Cursor Agent on this PC"
Write-Host "2. Send this (copied to clipboard):"
Write-Host ""
Write-Host $prompt -ForegroundColor Cyan
Write-Host ""

Set-Clipboard $prompt
Write-Host "Copied to clipboard." -ForegroundColor Green
