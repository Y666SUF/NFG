param(
  [string]$BaseUrl = "http://127.0.0.1:3847",
  [string]$DeviceId = "ios-dev-local-test"
)

$ErrorActionPreference = "Stop"

Write-Host "== NFG Crash mobile sanity test =="
Write-Host "Base URL: $BaseUrl"
Write-Host ""

function Invoke-JsonGet($url) {
  Invoke-RestMethod -Method Get -Uri $url -TimeoutSec 8
}

function Invoke-JsonPost($url, $bodyObj) {
  $json = $bodyObj | ConvertTo-Json -Depth 8
  Invoke-RestMethod -Method Post -Uri $url -ContentType "application/json" -Body $json -TimeoutSec 8
}

# 1) Core status endpoints
$state = Invoke-JsonGet "$BaseUrl/api/state"
Write-Host "State ok: phase=$($state.phase) roundId=$($state.roundId)"

$mobileStatus = Invoke-JsonGet "$BaseUrl/api/mobile/status"
Write-Host "Mobile status ok: service=$($mobileStatus.service) sharedData=$($mobileStatus.sharedData)"

$balances = Invoke-JsonGet "$BaseUrl/api/balances"
Write-Host "Balances ok: rows=$($balances.balances.Count)"

# 2) Link start + status (no TikTok required for this basic test)
$start = Invoke-JsonPost "$BaseUrl/api/mobile/link/start" @{ deviceId = $DeviceId }
Write-Host "Link start ok: code=$($start.code) expiresIn=$($start.expiresInSeconds)s command=$($start.tiktokCommand)"

$status = Invoke-JsonGet "$BaseUrl/api/mobile/link/status/$($start.code)"
Write-Host "Link status now: $($status.status)"

# 3) Mobile chat without bearer must be 401
$mobileBody = @{
  source = "mobile"
  user = "spoofed-user"
  message = "!balance"
}
$mobileJson = $mobileBody | ConvertTo-Json -Depth 6
try {
  Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/chat" -ContentType "application/json" -Body $mobileJson -TimeoutSec 8 | Out-Null
  Write-Host "ERROR: mobile /api/chat without Bearer unexpectedly succeeded" -ForegroundColor Red
  exit 1
} catch {
  if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 401) {
    Write-Host "Auth check ok: /api/chat source=mobile without token => 401"
  } else {
    throw
  }
}

Write-Host ""
Write-Host "Sanity test complete."
Write-Host "Next: comment !link $($start.code) on TikTok live, then poll /api/mobile/link/status/$($start.code)"
