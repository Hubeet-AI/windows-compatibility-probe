# windows-compatibility-probe

Ejecutar el siguiente comando en PowerShell:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $u='https://raw.githubusercontent.com/Hubeet-AI/windows-compatibility-probe/refs/heads/main/v1.0.0/probe.ps1'; $f="$env:TEMP\hubeet-probe.ps1"; Invoke-WebRequest $u -OutFile $f -UseBasicParsing; powershell.exe -NoProfile -ExecutionPolicy Bypass -File $f
```
