# Quick smoke test: Hangman mobile guess returns JSON without killing Node on 3847.
$ErrorActionPreference = "Stop"
$base = if ($env:NFG_TEST_BASE) { $env:NFG_TEST_BASE.TrimEnd("/") } else { "http://127.0.0.1:3847" }

function Invoke-NfgJson {
  param([string]$Method, [string]$Path, [hashtable]$Headers = @{}, [string]$Body = $null)
  $uri = "$base$Path"
  $params = @{
    Uri         = $uri
    Method      = $Method
    Headers     = $Headers
    ContentType = "application/json"
    TimeoutSec  = 15
  }
  if ($Body) { $params.Body = $Body }
  try {
    $resp = Invoke-WebRequest @params -UseBasicParsing
    return @{ Status = [int]$resp.StatusCode; Text = $resp.Content }
  } catch {
    if ($_.Exception.Response) {
      $r = $_.Exception.Response
      $reader = New-Object System.IO.StreamReader($r.GetResponseStream())
      $text = $reader.ReadToEnd()
      return @{ Status = [int]$r.StatusCode; Text = $text }
    }
    throw
  }
}

Write-Host "NFG mobile guess + chat smoke test"
Write-Host "Base: $base"
Write-Host ""

try {
  $ping = Invoke-WebRequest -Uri "$base/api/mobile/platform/status" -UseBasicParsing -TimeoutSec 5
} catch {
  Write-Host "FAIL - nothing listening on $base"
  Write-Host "Start: .\run-electron-cloudflare.bat"
  exit 1
}

$fail = 0

function Assert-Json {
  param([hashtable]$Result, [string]$Label)
  try {
    $null = $Result.Text | ConvertFrom-Json
    Write-Host "[OK] $Label (HTTP $($Result.Status))"
    return $true
  } catch {
    Write-Host "[FAIL] $Label - not JSON (HTTP $($Result.Status))"
    Write-Host $Result.Text.Substring(0, [Math]::Min(200, $Result.Text.Length))
    $script:fail++
    return $false
  }
}

$r = Invoke-NfgJson GET "/api/mobile/platform/status"
Assert-Json $r "platform/status" | Out-Null

$r = Invoke-NfgJson GET "/api/mobile/chat?limit=5"
Assert-Json $r "mobile/chat" | Out-Null

$stateHeaders = @{ "X-Client-App" = "nfg-hangman" }
$r = Invoke-NfgJson GET "/api/mobile/hangman/state" $stateHeaders
if ($r.Status -eq 404) {
  Write-Host "[FAIL] GET /api/mobile/hangman/state returned 404 - pull latest server and restart Electron"
  $fail++
} elseif (-not (Assert-Json $r "hangman/state")) {
  $fail++
} else {
  try {
    $st = $r.Text | ConvertFrom-Json
    if ($st.ok -ne $true) {
      Write-Host "[FAIL] hangman/state ok not true: $($st.error)"
      $fail++
    } elseif (-not $st.maskedWord -and -not $st.slots) {
      Write-Host "[FAIL] hangman/state missing maskedWord/slots (game may not be ready)"
      $fail++
    } else {
      Write-Host "[OK] hangman/state has word + keyboard fields"
    }
  } catch {
    Write-Host "[FAIL] hangman/state parse"
    $fail++
  }
}

$headers = @{
  "X-Client-App" = "nfg-hangman"
  "X-Device-Id"  = "pc-guess-test"
  "Content-Type" = "application/json"
}
$r = Invoke-NfgJson POST "/api/mobile/hangman/guess" $headers '{"letter":"z"}'
if ($r.Status -ne 401) {
  Write-Host "[FAIL] guess without auth should be 401, got $($r.Status)"
  $fail++
} else {
  Assert-Json $r 'guess unauthenticated 401' | Out-Null
}

$r = Invoke-NfgJson POST "/api/mobile/hangman/guess" $headers '{"letter":""}'
if ($r.Status -lt 400 -or $r.Status -ge 500) {
  Write-Host "[FAIL] invalid letter should be 4xx, got $($r.Status)"
  $fail++
} else {
  Assert-Json $r "guess invalid letter" | Out-Null
}

# Server must still answer after guess attempts (no crash).
Start-Sleep -Milliseconds 400
$r = Invoke-NfgJson GET "/api/mobile/status"
if (-not (Assert-Json $r "crash status after guess attempts")) { }

Write-Host ""
if ($fail -eq 0) {
  Write-Host "PASS - guess endpoints return JSON; platform still up."
  Write-Host "Restart Electron and test a linked letter guess on device."
  exit 0
}
Write-Host "FAIL - $fail check(s) failed. Fix server before restarting Electron."
exit 1
