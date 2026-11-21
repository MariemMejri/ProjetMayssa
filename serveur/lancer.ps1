# Lance le serveur d'analyse et relie le téléphone branché en USB.
# Usage (dans le dossier serveur) :  .\lancer.ps1
# Dans l'appli, adresse du serveur : http://127.0.0.1:8000

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

# Tunnel USB : sur le téléphone, 127.0.0.1:8000 = ce PC, port 8000.
# Il disparaît si on débranche le téléphone : relancer ce script.
& $adb reverse tcp:8000 tcp:8000
if ($LASTEXITCODE -eq 0) {
    Write-Host "Tunnel USB OK : dans l'appli, utiliser http://127.0.0.1:8000" -ForegroundColor Green
} else {
    Write-Host "Aucun téléphone USB trouvé (le serveur démarre quand même)." -ForegroundColor Yellow
}

& "$PSScriptRoot\.venv\Scripts\uvicorn.exe" main:app --host 0.0.0.0 --port 8000 --reload --app-dir $PSScriptRoot
