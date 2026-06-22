param(
  # Comma-separated from .bat (e.g. 3847,19876,8001) or a single port when called from PowerShell.
  [string]$Ports = "3847,19876",
  [switch]$Quiet,
  [switch]$KillElectron,
  [switch]$KillCloudflared,
  [switch]$KillNodeNfg,
  [string]$RepoRoot = ""
)

$ErrorActionPreference = "SilentlyContinue"
$total = 0
$repo = ""
if ($RepoRoot) {
  $repo = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction SilentlyContinue).Path
  if (-not $repo) { $repo = $RepoRoot.TrimEnd('\', '/') }
}

function Get-PortNumbers([string]$Raw) {
  $text = [string]$Raw
  if (-not $text.Trim()) { return @(3847, 19876) }
  $nums = @($text -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
  if ($nums.Count -gt 0) { return $nums }
  return @(3847, 19876)
}

$portList = Get-PortNumbers $Ports

function Stop-ListenersOnPort([int]$Port) {
  $killed = 0
  $pids = @()

  try {
    $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    foreach ($c in $conns) {
      if ($c.OwningProcess -and $c.OwningProcess -ne $PID) {
        $pids += $c.OwningProcess
      }
    }
  } catch {
    $lines = netstat -ano -p tcp | Select-String ":$Port\s"
    foreach ($line in $lines) {
      if ($line -notmatch "LISTENING") { continue }
      $parts = ($line -replace "\s+", " ").Trim().Split(" ")
      $pidVal = [int]$parts[-1]
      if ($pidVal -and $pidVal -ne $PID) { $pids += $pidVal }
    }
  }

  foreach ($procId in ($pids | Select-Object -Unique)) {
    try {
      Stop-Process -Id $procId -Force -ErrorAction Stop
      $killed++
    } catch {
      try {
        & taskkill /PID $procId /F /T | Out-Null
        $killed++
      } catch {}
    }
  }
  return $killed
}

function Stop-ProcessesByMatch([string]$NamePattern, [string]$CommandMatch, [string]$Label) {
  $killed = 0
  $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like $NamePattern -and $_.CommandLine -and $_.CommandLine -match $CommandMatch }
  foreach ($p in $procs) {
    if ($p.ProcessId -eq $PID) { continue }
    try {
      Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
      $killed++
    } catch {
      try {
        & taskkill /PID $p.ProcessId /F /T | Out-Null
        $killed++
      } catch {}
    }
  }
  if (-not $Quiet -and $killed -gt 0) {
    Write-Host "[NFG] Stopped $killed $Label process(es)"
  }
  return $killed
}

foreach ($p in $portList) {
  $total += Stop-ListenersOnPort -Port $p
}

if ($KillElectron) {
  if ($repo) {
    $repoEsc = [regex]::Escape($repo)
    $total += Stop-ProcessesByMatch "electron.exe" "electron[\\/]main\.js|$repoEsc" "Electron"
  } else {
    $total += Stop-ProcessesByMatch "electron.exe" "electron[\\/]main\.js" "Electron"
  }
}

if ($KillNodeNfg) {
  if ($repo) {
    $repoEsc = [regex]::Escape($repo)
    $total += Stop-ProcessesByMatch "node.exe" "server[\\/]index\.js|$repoEsc" "Node"
  } else {
    $total += Stop-ProcessesByMatch "node.exe" "server[\\/]index\.js" "Node"
  }
}

if ($KillCloudflared) {
  $killed = 0
  $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ieq "cloudflared.exe" }
  foreach ($p in $procs) {
    if ($p.ProcessId -eq $PID) { continue }
    try {
      Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
      $killed++
    } catch {
      try {
        & taskkill /PID $p.ProcessId /F /T | Out-Null
        $killed++
      } catch {}
    }
  }
  if (-not $Quiet -and $killed -gt 0) {
    Write-Host "[NFG] Stopped $killed cloudflared process(es)"
  }
  $total += $killed
}

if (-not $Quiet) {
  Write-Host "[NFG] Cleared $total stale process(es) on port(s) $($portList -join ', ')"
}

exit 0
