# Test mobile Hangman guess + app chat labels (run while Node is on :3847)
param(
  [string]$BaseUrl = "http://127.0.0.1:3847",
  [string]$DeviceId = "pc-hangman-test",
  [string]$Letter = "e",
  [string]$TikTokUser = "y666.suf",
  [string]$DisplayName = "Yusuf"
)

$ErrorActionPreference = "Stop"

function Invoke-JsonPost($Url, $Body, $Headers = @{}) {
  $h = @{ "Content-Type" = "application/json" } + $Headers
  return Invoke-RestMethod -Uri $Url -Method POST -Headers $h -Body ($Body | ConvertTo-Json -Compress)
}

function Invoke-JsonGet($Url, $Headers = @{}) {
  return Invoke-RestMethod -Uri $Url -Method GET -Headers $Headers
}

Write-Host "=== Link start ===" -ForegroundColor Cyan
$start = Invoke-JsonPost "$BaseUrl/api/mobile/link/start" @{ deviceId = $DeviceId } @{
  "X-Client-App" = "nfg-hangman"
  "X-Device-Id"  = $DeviceId
}
$start | ConvertTo-Json

Write-Host "`n=== Simulate TikTok !link on platform chat ===" -ForegroundColor Cyan
$chatBody = @{
  userId      = $TikTokUser
  displayName = $DisplayName
  message     = $start.tiktokCommand
} | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "$BaseUrl/api/chat" -Method POST -ContentType "application/json" -Body $chatBody | Out-Null

$status = Invoke-JsonGet "$BaseUrl/api/mobile/link/status/$($start.code)"
$status | ConvertTo-Json
if ($status.status -ne "linked" -or -not $status.token) {
  Write-Host "Link failed — run while LIVE or check mobile-auth." -ForegroundColor Red
  exit 1
}

Write-Host "`n=== Mobile hangman guess ($Letter) ===" -ForegroundColor Cyan
$guess = Invoke-JsonPost "$BaseUrl/api/mobile/hangman/guess" @{ letter = $Letter } @{
  "Authorization" = "Bearer $($status.token)"
  "X-Client-App"  = "nfg-hangman"
  "X-Device-Id"   = $DeviceId
}
$guess | ConvertTo-Json -Depth 5

Write-Host "`n=== App chat sample ===" -ForegroundColor Cyan
Invoke-JsonGet "$BaseUrl/api/mobile/chat?limit=3" | ConvertTo-Json -Depth 6

Write-Host "`nDone. Electron should still be running." -ForegroundColor Green
