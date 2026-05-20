# Prints full path to node.exe and exits 0, or exits 1 with no output.
$ErrorActionPreference = 'SilentlyContinue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Try-Node([string] $Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return }
  if (Test-Path -LiteralPath $Path) {
    Write-Output ((Resolve-Path -LiteralPath $Path).Path)
    exit 0
  }
}

# Portable copy next to this project (no installer needed)
Try-Node (Join-Path $root 'tools\node\node.exe')

# Common install locations
$paths = @(
  (Join-Path $env:ProgramFiles 'nodejs\node.exe'),
  (Join-Path ${env:ProgramFiles(x86)} 'nodejs\node.exe'),
  (Join-Path $env:LOCALAPPDATA 'Programs\nodejs\node.exe'),
  (Join-Path $env:USERPROFILE 'scoop\apps\nodejs\current\node.exe'),
  (Join-Path $env:USERPROFILE '.volta\bin\node.exe'),
  'C:\nodejs\node.exe',
  (Join-Path $env:ProgramData 'chocolatey\bin\node.exe')
)
foreach ($p in $paths) { Try-Node $p }

# nvm-windows often exposes these
if ($env:NVM_SYMLINK) { Try-Node (Join-Path $env:NVM_SYMLINK.TrimEnd('\') 'node.exe') }

# Official Windows installer stores InstallPath in the registry
$regKeys = @(
  'HKLM:\SOFTWARE\Node.js',
  'HKLM:\SOFTWARE\WOW6432Node\Node.js',
  'HKCU:\SOFTWARE\Node.js'
)
foreach ($k in $regKeys) {
  $ip = (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue).InstallPath
  if ($ip) {
    $base = $ip.Trim().TrimEnd('\').TrimEnd('/')
    Try-Node (Join-Path $base 'node.exe')
  }
}

# WinGet package folder (name usually starts with OpenJS.NodeJS)
$wingetRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
if (Test-Path -LiteralPath $wingetRoot) {
  Get-ChildItem -LiteralPath $wingetRoot -Directory -Filter 'OpenJS.NodeJS*' -ErrorAction SilentlyContinue |
    ForEach-Object {
      Try-Node (Join-Path $_.FullName 'node.exe')
      $hit = Get-ChildItem -LiteralPath $_.FullName -Filter 'node.exe' -File -Recurse -Depth 6 -ErrorAction SilentlyContinue |
        Select-Object -First 1
      if ($hit) { Try-Node $hit.FullName }
    }
}

exit 1
