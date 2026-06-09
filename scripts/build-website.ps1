# Build React marketing site served at https://y666suf.com on port 3847
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Frontend = Join-Path $Root "_import_Y666SUF_website\frontend"
$BuildIndex = Join-Path $Frontend "build\index.html"

if (-not (Test-Path (Join-Path $Frontend "package.json"))) {
  Write-Host "Missing frontend at: $Frontend"
  exit 1
}

Push-Location $Frontend
try {
  if (-not (Test-Path "node_modules\@craco\craco")) {
    Write-Host "yarn install (including devDependencies for craco)..."
    $env:NODE_ENV = ""
    corepack yarn install --production=false
  }
  $env:PATH = "$(Join-Path $Frontend 'node_modules\.bin');$env:PATH"
  Remove-Item Env:NODE_ENV -ErrorAction SilentlyContinue
  $env:REACT_APP_BACKEND_URL = ""
  $env:CI = "true"
  $env:GENERATE_SOURCEMAP = "false"
  Write-Host "yarn build..."
  corepack yarn build
} finally {
  Pop-Location
}

if (-not (Test-Path $BuildIndex)) {
  Write-Host "Build failed — no build\index.html"
  exit 1
}

Write-Host ""
Write-Host "OK: $BuildIndex"
Write-Host "Restart run-electron-cloudflare.bat so y666suf.com serves the React site (not website/)."
