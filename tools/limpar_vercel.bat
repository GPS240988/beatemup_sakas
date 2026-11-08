@echo off
REM =========================================================================
REM tools/limpar_vercel.bat
REM Limpeza automatica de deploys antigos da Vercel
REM =========================================================================

echo [Vercel Clean] Iniciando limpeza em lote de deploys antigos...
python "%~dp0cleanup_vercel_deployments.py" --execute
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERRO] Ocorreu uma falha na limpeza. Verifique as mensagens acima.
    pause
    exit /b %ERRORLEVEL%
)
echo.
echo [Vercel Clean] Limpeza concluida com sucesso!
pause

