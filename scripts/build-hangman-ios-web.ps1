# Build Hangman iOS web bundle (Vite) for Capacitor / next Mac IPA archive.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AppDir = Join-Path $Root "hangman v2\iOS\app"

if (-not (Test-Path (Join-Path $AppDir "package.json"))) {
  Write-Host "Missing: $AppDir"
  exit 1
}

Push-Location $AppDir
try {
  if (-not (Test-Path "node_modules")) {
    Write-Host "npm install (Hangman iOS app)..."
    npm install --include=dev
  }
  Write-Host "vite build (web companion @ /hangman-app on same host)..."
  $env:PATH = "$(Join-Path $AppDir 'node_modules\.bin');$env:PATH"
  npx vite build --mode web
  Write-Host ""
  Write-Host "iPhone Safari: https://y666suf.com/hangman-app/  (or http://127.0.0.1:3847/hangman-app/)"
  Write-Host "Capacitor IPA build on Mac: npx vite build --mode production  (base /)"
  $dist = Join-Path $AppDir "dist"
  if (Test-Path $dist) {
    Get-ChildItem $dist -Recurse -File | Measure-Object -Property Length -Sum | ForEach-Object {
      Write-Host "Built www: $dist ($([math]::Round($_.Sum/1KB, 1)) KB)"
    }
    Write-Host ""
    Write-Host "On Mac: cd hangman v2/iOS/app && npx cap sync ios && archive IPA -> releases/ipa/NFG-Hangman.ipa"
    Write-Host "Then on PC: .\scripts\refresh-hangman-ipa-download.ps1"
  }
} finally {
  Pop-Location
}
