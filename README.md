# windows-compatibility-probe
Ejecutar el siguiente comando:
```
$u='https://raw.githubusercontent.com/Hubeet-AI/windows-compatibility-probe/refs/heads/main/v1.0.0/probe.ps1'; $f="$env:TEMP\hubeet-probe.ps1"; Invoke-WebRequest $u -OutFile $f; powershell.exe -NoProfile -ExecutionPolicy Bypass -File $f
```

