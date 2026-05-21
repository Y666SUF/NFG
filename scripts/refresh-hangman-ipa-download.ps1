# Copy latest Hangman IPA from repo to Downloads so Node serves it on y666suf.com
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$RepoIpa = Join-Path $Root "releases\ipa\NFG-Hangman.ipa"
$Dl = Join-Path $env:USERPROFILE "Downloads\NFG-Hangman.ipa"

if (-not (Test-Path $RepoIpa)) {
  Write-Host "Missing: $RepoIpa — run: git pull origin main"
  exit 1
}

Copy-Item -Force $RepoIpa $Dl
$item = Get-Item $Dl
Write-Host "Copied Hangman IPA to Downloads:"
Write-Host "  $($item.FullName)"
Write-Host "  $([math]::Round($item.Length/1MB, 2)) MB  $($item.LastWriteTime)"

try {
  $info = Invoke-RestMethod "http://127.0.0.1:3847/api/ipa/download-info"
  $hm = $info.apps.hangman
  Write-Host ""
  Write-Host "Local download-info:"
  Write-Host "  ok=$($hm.ok)  sizeBytes=$($hm.sizeBytes)  updatedAt=$($hm.updatedAt)"
} catch {
  Write-Host ""
  Write-Host "Node not running on 3847 — start run-electron-cloudflare.bat, then re-run this script."
}

Write-Host ""
Write-Host "Public URL (when tunnel is up): https://y666suf.com/download/nfg-hangman.ipa"
Write-Host "Sideload page: https://y666suf.com/sideload"
