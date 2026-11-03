@echo off
rem install\atualizar_lista.bat - atualiza a lista de produtos do plugin (03/11/2026)
rem Arraste o JSON exportado da plataforma em cima deste arquivo.
rem 1. compara com a lista publicada (comparar_lista.ps1) e mostra o que mudou;
rem 2. pergunta se publica;
rem 3. se sim, roda publicar_semana.ps1 (lista + versao + commit + release).
rem Precisa: repo na main, sem mudanca local, git e gh logados nesta maquina.
setlocal
cd /d "%~dp0.."

if "%~1"=="" (
    echo.
    echo Arraste o arquivo JSON da plataforma em cima deste .bat.
    echo.
    pause
    exit /b 1
)

echo.
echo === Comparando %~nx1 com a lista publicada ===
powershell -NoProfile -ExecutionPolicy Bypass -File "install\comparar_lista.ps1" -Json "%~1"
if errorlevel 2 goto perguntar
if errorlevel 1 goto fim

:perguntar
echo.
choice /c SN /m "Publicar esta lista para o time agora"
if errorlevel 2 (
    echo Nada foi publicado.
    goto fim
)

echo.
echo === Publicando ===
powershell -NoProfile -ExecutionPolicy Bypass -File "install\publicar_semana.ps1" -Json "%~1"

:fim
echo.
pause
