@echo off
REM =========================================================================
REM tools/deploy_web.bat
REM Script de automação de 1 clique para deploy do Beat 'em Up Sakas na Vercel
REM =========================================================================

echo [Sakas Deploy] Iniciando verificacao e deploy para Vercel...
python "%~dp0deploy_web.py" %*
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERRO] Ocorreu uma falha no deploy. Verifique as mensagens acima.
    pause
    exit /b %ERRORLEVEL%
)
echo.
echo [Sakas Deploy] Processo finalizado!
pause

