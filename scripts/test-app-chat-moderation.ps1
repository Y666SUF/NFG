$ErrorActionPreference = "Stop"
$base = if ($env:NFG_TEST_BASE) { $env:NFG_TEST_BASE.TrimEnd("/") } else { "http://127.0.0.1:3847" }

function Invoke-StatusCheck {
  param([string]$Uri)
  try {
    $r = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 15
    return @{ StatusCode = [int]$r.StatusCode; Content = $r.Content }
  } catch {
    if ($_.Exception.Response) {
      $resp = $_.Exception.Response
      $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
      $text = $reader.ReadToEnd()
      return @{ StatusCode = [int]$resp.StatusCode; Content = $text }
    }
    throw
  }
}

Write-Host "==> GET /api/mobile/chat"
$h = Invoke-RestMethod "$base/api/mobile/chat?limit=3"
if (-not $h.ok) { throw "chat failed" }
Write-Host "  OK messages=$($h.messages.Count)"

Write-Host "==> moderation route (must NOT be 404)"
$r = Invoke-StatusCheck "$base/api/mobile/chat/moderation"
if ($r.StatusCode -eq 404 -and $r.Content -like "*Cannot GET*") {
  throw "FAIL: /api/mobile/chat/moderation not registered"
}
Write-Host "  status $($r.StatusCode) (401 without token = OK)"

$r2 = Invoke-StatusCheck "https://y666suf.com/api/mobile/chat/moderation"
Write-Host "  tunnel status $($r2.StatusCode)"
if ($r2.StatusCode -eq 404 -and $r2.Content -like "*Cannot GET*") {
  throw "FAIL: tunnel still 404"
}

Write-Host "PASS"
