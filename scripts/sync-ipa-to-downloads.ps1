# Copy IPAs from releases\ipa to Downloads so /download/nfg-*.ipa works.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$srcDir = Join-Path $root "releases\ipa"
$dstDir = Join-Path $env:USERPROFILE "Downloads"

$pairs = @(
  @{ Src = "NFG-Crash.ipa"; Dst = "NFG-Crash.ipa" },
  @{ Src = "NFG-Hangman.ipa"; Dst = "NFG-Hangman.ipa" }
)

$ok = 0
foreach ($p in $pairs) {
  $src = Join-Path $srcDir $p.Src
  $dst = Join-Path $dstDir $p.Dst
  if (-not (Test-Path $src)) {
    Write-Host "[skip] Missing $src"
    continue
  }
  Copy-Item -Force $src $dst
  $mb = [math]::Round((Get-Item $dst).Length / 1MB, 1)
  Write-Host "[ok] $dst ($mb MB)"
  $ok++
}

if ($ok -eq 0) {
  Write-Host ""
  Write-Host "No IPAs in releases\ipa. After Mac build, copy:"
  Write-Host "  releases\ipa\NFG-Crash.ipa"
  Write-Host "  releases\ipa\NFG-Hangman.ipa"
  exit 1
}

Write-Host ""
Write-Host "Done. Restart run-electron-cloudflare.bat to refresh download URLs."
exit 0
