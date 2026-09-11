# Voca Dictionary - one-line installer for Windows (PowerShell).
#
#   $env:VOCA_REPO = "<owner>/<repo>"
#   iwr "https://github.com/$env:VOCA_REPO/releases/latest/download/install.ps1" -UseBasicParsing | iex
#
# Downloads the latest voca.jar, ensures PostgreSQL (auto via Docker), then runs the app.
$ErrorActionPreference = "Stop"

$Repo = $env:VOCA_REPO
if (-not $Repo) { Write-Error "Set `$env:VOCA_REPO = '<owner>/<repo>' first."; exit 1 }
$Dir  = if ($env:VOCA_DIR) { $env:VOCA_DIR } else { "voca" }
$Port = if ($env:PORT) { $env:PORT } else { "22052" }

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
Set-Location $Dir
$Download = Join-Path (Get-Location) "voca.jar.download"
$PidFile = Join-Path (Get-Location) ".voca.pid"

Write-Host "-> Downloading voca.jar (latest release of $Repo) ..."
Invoke-WebRequest "https://github.com/$Repo/releases/latest/download/voca.jar" -OutFile $Download -UseBasicParsing

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
  Write-Error "Java 21+ required. Install a JDK 21 (e.g. 'winget install EclipseAdoptium.Temurin.21.JDK') then re-run."
  exit 1
}

if (Get-Command docker -ErrorAction SilentlyContinue) {
  $exists = docker ps -a --format '{{.Names}}' | Select-String -Pattern '^voca-db$'
  if ($exists) { docker start voca-db | Out-Null }
  else {
    Write-Host "-> Starting PostgreSQL (docker: voca-db) ..."
    docker run -d --name voca-db -e POSTGRES_USER=voca -e POSTGRES_PASSWORD=voca -e POSTGRES_DB=voca -p 5432:5432 postgres:16 | Out-Null
  }
  Write-Host "-> Waiting for DB ..."
  do { Start-Sleep -Seconds 1 } until (docker exec voca-db pg_isready -U voca 2>$null)
} else {
  Write-Host "! Docker not found. Ensure PostgreSQL (db=voca user=voca pass=voca) on :5432."
}

function Stop-ExistingVoca([int]$ProcessId) {
  $Info = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
  $Command = if ($Info) { [string]$Info.CommandLine } else { "" }
  if ($Command -notmatch '(?i)java' -or $Command -notmatch '(?i)voca\.jar') {
    throw "Port $Port is used by another process (PID $ProcessId). Stop it or use another PORT."
  }
  Write-Host "-> Stopping previous Voca process (PID $ProcessId) ..."
  Stop-Process -Id $ProcessId -ErrorAction SilentlyContinue
  try {
    Wait-Process -Id $ProcessId -Timeout 15 -ErrorAction Stop
  } catch {
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
  }
}

$ListenerPid = $null
if (Test-Path $PidFile) {
  $SavedPid = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
  if ($SavedPid -match '^\d+$' -and (Get-Process -Id ([int]$SavedPid) -ErrorAction SilentlyContinue)) {
    $ListenerPid = [int]$SavedPid
  }
}
if (-not $ListenerPid -and (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
  $Connection = Get-NetTCPConnection -LocalPort ([int]$Port) -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($Connection) { $ListenerPid = [int]$Connection.OwningProcess }
}
if ($ListenerPid) { Stop-ExistingVoca $ListenerPid }

Move-Item -Force $Download (Join-Path (Get-Location) "voca.jar")

Write-Host "-> Starting Voca at http://localhost:$Port (Ctrl+C to stop) ..."
$App = Start-Process -FilePath "java" -ArgumentList @("-jar", "voca.jar", "--server.port=$Port") -NoNewWindow -PassThru
Set-Content -Path $PidFile -Value $App.Id
try {
  $App.WaitForExit()
  $ExitCode = $App.ExitCode
} finally {
  if (-not $App.HasExited) { Stop-Process -Id $App.Id -ErrorAction SilentlyContinue }
  if (Test-Path $PidFile) { Remove-Item $PidFile -Force }
}
exit $ExitCode
