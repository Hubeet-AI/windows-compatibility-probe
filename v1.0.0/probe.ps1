$ErrorActionPreference = "Stop"

$Work = Join-Path $env:TEMP "hubeet-windows-probe"

Write-Host ""
Write-Host "Hubeet Windows Compatibility Probe"
Write-Host "==================================="
Write-Host ""

Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $Work | Out-Null

Set-Location $Work

Write-Host "[1/4] Preparando entorno Python..."

powershell -ExecutionPolicy Bypass -c `
  "irm https://astral.sh/uv/install.ps1 | iex"

$env:Path = "$env:USERPROFILE\.local\bin;$env:Path"

Write-Host "[2/4] Descargando JEV Windows Agent..."

Invoke-WebRequest `
  "https://github.com/VBS2004/jev-windows-agent/archive/refs/heads/main.zip" `
  -OutFile "jev.zip"

Expand-Archive "jev.zip" -DestinationPath .

Set-Location "jev-windows-agent-main"

Write-Host "[3/4] Instalando dependencias..."

uv venv --python 3.12 .venv
uv pip install --python .venv\Scripts\python.exe -e ".[windows]"

Write-Host ""
Write-Host "================================================"
Write-Host " ABRI OCTOSIS Y DEJALO EN PRIMER PLANO"
Write-Host " Tenes 10 segundos..."
Write-Host "================================================"
Write-Host ""

Start-Sleep -Seconds 10

Write-Host "[4/4] Analizando interfaz..."

& .\.venv\Scripts\python.exe `
    examples\windows_uia_probe.py `
    --delay 1 `
    --limit 500 |
    Tee-Object "$env:USERPROFILE\Desktop\octosis-uia-report.txt"

Write-Host ""
Write-Host "PRUEBA TERMINADA"
Write-Host ""
Write-Host "Resultado:"
Write-Host "$env:USERPROFILE\Desktop\octosis-uia-report.txt"
Write-Host ""

Read-Host "Presiona ENTER para cerrar"