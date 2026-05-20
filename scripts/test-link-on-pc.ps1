# Run on the Windows GAME PC (PowerShell) while npm start is running.
param(
  [Parameter(Mandatory = $true)]
  [string]$Code,
  [string]$User = "y666.suf",
  [string]$BaseUrl = "http://127.0.0.1:3847"
)

Write-Host "=== Pending link codes on this PC ===" -ForegroundColor Cyan
try {
  Invoke-RestMethod -Uri "$BaseUrl/api/mobile/link/debug" | ConvertTo-Json -Depth 5
} catch {
  Write-Host "debug failed (update mobile-auth.js?): $_" -ForegroundColor Yellow
}

Write-Host "`n=== Simulating TikTok comment: !link $Code ===" -ForegroundColor Cyan
$body = @{ userId = $User; displayName = $User; message = "!link $Code" } | ConvertTo-Json -Compress
$chat = Invoke-RestMethod -Uri "$BaseUrl/api/chat" -Method POST -Body $body -ContentType "application/json; charset=utf-8"
$chat | ConvertTo-Json -Depth 5

Write-Host "`n=== Link status ===" -ForegroundColor Cyan
$status = Invoke-RestMethod -Uri "$BaseUrl/api/mobile/link/status/$Code"
$status | ConvertTo-Json -Depth 5

if ($status.status -eq "linked") {
  Write-Host "`nSUCCESS - iPhone should detect this within a few seconds." -ForegroundColor Green
} else {
  Write-Host "`nNOT LINKED - check game console for [Mobile link] lines. Generate a fresh code on iPhone." -ForegroundColor Red
}
