[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "    Hubeet Windows Compatibility Probe    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # ----------------------------------------------------
    # 0. Determinar ubicacion del reporte (Fool-proof Desktop)
    # ----------------------------------------------------
    $DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)

    if (-not $DesktopPath -or -not (Test-Path $DesktopPath)) {
        $candidates = @(
            (Join-Path $env:USERPROFILE "OneDrive\Desktop"),
            (Join-Path $env:USERPROFILE "Desktop"),
            $env:USERPROFILE,
            $env:TEMP
        )
        foreach ($cand in $candidates) {
            if ($cand -and (Test-Path $cand)) {
                $DesktopPath = $cand
                break
            }
        }
    }

    if (-not (Test-Path $DesktopPath)) {
        New-Item -ItemType Directory -Path $DesktopPath -Force | Out-Null
    }

    $ReportPath = Join-Path $DesktopPath "octosis-uia-report.txt"

    # ----------------------------------------------------
    # 1. Preparar directorio temporal de trabajo
    # ----------------------------------------------------
    $Work = Join-Path $env:TEMP "hubeet-windows-probe"
    if (Test-Path $Work) {
        try {
            Remove-Item $Work -Recurse -Force -ErrorAction Stop
        } catch {
            # Si algun archivo previo quedo bloqueado por procesos anteriores
            $Work = Join-Path $env:TEMP ("hubeet-windows-probe-" + [Guid]::NewGuid().ToString().Substring(0, 8))
        }
    }
    New-Item -ItemType Directory -Path $Work -Force | Out-Null
    Set-Location $Work

    # ----------------------------------------------------
    # 2. Preparar entorno Python y herramienta UV
    # ----------------------------------------------------
    Write-Host "[1/4] Preparando entorno Python (uv)..." -ForegroundColor Yellow

    $uvBin = $null
    $existingUv = Get-Command uv -ErrorAction SilentlyContinue
    if ($existingUv) {
        $uvBin = $existingUv.Source
    }

    if (-not $uvBin) {
        $possibleUv = @(
            "$env:USERPROFILE\.local\bin\uv.exe",
            "$env:CARGO_HOME\bin\uv.exe",
            "$env:USERPROFILE\.cargo\bin\uv.exe",
            "$env:APPDATA\uv\uv.exe",
            "$env:LOCALAPPDATA\uv\uv.exe"
        )
        foreach ($p in $possibleUv) {
            if (Test-Path $p) {
                $uvBin = $p
                break
            }
        }
    }

    if (-not $uvBin) {
        Write-Host "      Descargando e instalando uv..." -ForegroundColor Gray
        try {
            powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://astral.sh/uv/install.ps1 | iex"
        } catch {
            throw "Error al instalar uv: $($_.Exception.Message)"
        }

        # Actualizar PATH del proceso actual y rebuscar
        $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
        $newUv = Get-Command uv -ErrorAction SilentlyContinue
        if ($newUv) {
            $uvBin = $newUv.Source
        } else {
            foreach ($p in $possibleUv) {
                if (Test-Path $p) {
                    $uvBin = $p
                    break
                }
            }
        }
    }

    if (-not $uvBin -or -not (Test-Path $uvBin)) {
        throw "No se pudo localizar el ejecutable de uv tras la instalacion."
    }

    Write-Host "      uv listo: $uvBin" -ForegroundColor Green

    # ----------------------------------------------------
    # 3. Descargar y descomprimir JEV Windows Agent
    # ----------------------------------------------------
    Write-Host "[2/4] Descargando JEV Windows Agent..." -ForegroundColor Yellow

    $zipPath = Join-Path $Work "jev.zip"
    $agentUrl = "https://github.com/VBS2004/jev-windows-agent/archive/refs/heads/main.zip"

    Invoke-WebRequest -Uri $agentUrl -OutFile $zipPath -UseBasicParsing

    Expand-Archive -Path $zipPath -DestinationPath $Work -Force

    $agentDir = Get-ChildItem -Path $Work -Directory | Where-Object { $_.Name -like "jev-windows-agent*" } | Select-Object -First 1
    if (-not $agentDir) {
        throw "No se encontro el directorio extraido de jev-windows-agent."
    }
    Set-Location $agentDir.FullName

    # ----------------------------------------------------
    # 4. Crear venv e instalar dependencias
    # ----------------------------------------------------
    Write-Host "[3/4] Instalando dependencias de Python..." -ForegroundColor Yellow

    & $uvBin venv --python 3.12 .venv
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo al inicializar el entorno virtual con Python 3.12."
    }

    $pythonExe = Join-Path (Get-Location) ".venv\Scripts\python.exe"
    if (-not (Test-Path $pythonExe)) {
        throw "No se encontro el interprete de Python en: $pythonExe"
    }

    & $uvBin pip install --python $pythonExe -e ".[windows]"
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo al instalar las dependencias con uv pip."
    }

    $probeScript = Join-Path (Get-Location) "examples\windows_uia_probe.py"
    if (-not (Test-Path $probeScript)) {
        throw "No se encontro el script de prueba en: $probeScript"
    }

    # ----------------------------------------------------
    # 5. Cuenta regresiva y ejecucion de la prueba
    # ----------------------------------------------------
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Magenta
    Write-Host " ABRI OCTOSIS Y DEJALO EN PRIMER PLANO" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host " Tenes 10 segundos..." -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Magenta
    Write-Host ""

    for ($i = 10; $i -gt 0; $i--) {
        Write-Host -NoNewline "`rEsperando... $i segundos restantes "
        Start-Sleep -Seconds 1
    }
    Write-Host "`rIniciando analisis...                     " -ForegroundColor Green

    Write-Host "[4/4] Analizando interfaz y generando reporte..." -ForegroundColor Yellow

    # Ejecutar probe redirigiendo a la consola y al archivo asegurado
    & $pythonExe $probeScript --delay 1 --limit 500 | Tee-Object -FilePath $ReportPath

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "            PRUEBA TERMINADA              " -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Reporte guardado exitosamente en:" -ForegroundColor White
    Write-Host "  $ReportPath" -ForegroundColor Cyan
    Write-Host ""

    # Abrir el explorador de Windows seleccionando el archivo generado
    try {
        if (Test-Path $ReportPath) {
            & explorer.exe /select,$ReportPath
        }
    } catch {
        # Silenciar si el entorno no permite abrir Explorer
    }

} catch {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "             OCURRIO UN ERROR             " -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Detalle del error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
} finally {
    Write-Host ""
    Read-Host "Presiona ENTER para cerrar esta ventana"
}