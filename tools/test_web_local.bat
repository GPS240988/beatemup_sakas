@echo off
REM =========================================================================
REM tools/test_web_local.bat
REM Inicia o servidor local com suporte a Multi-PCK e COOP/COEP
REM Garante a atualização dos pacotes e binários antes de servir
REM =========================================================================

echo [Sakas Web Local] Sincronizando e verificando pacotes Web...
python "%~dp0deploy_web.py" --verify-only
if %ERRORLEVEL% NEQ 0 (
    echo [ERRO] Falha na verificacao dos pacotes Web!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [Sakas Web Local] Iniciando servidor de testes...
python "%~dp0test_web_local.py"
pause
