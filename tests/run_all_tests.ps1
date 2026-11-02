# Script de Execução de Todas as Suítes de Teste Headless (Godot 4.x) — CI/CD e Baseline
$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "EXECUTANDO BATERIA COMPLETA DE TESTES HEADLESS (GODOT 4.x)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$test_files = @(
    "tests/map_structure_test.gd",
    "tests/prop_contracts_test.gd",
    "tests/actor_contracts_test.gd",
    "tests/actor_contract_test.gd",
    "tests/spawn_points_test.gd",
    "tests/destructible_prop_test.gd",
    "tests/combat_director_test.gd",
    "tests/combat_smoke_test.gd",
    "tests/boss_alessandro_test.gd",
    "tests/map_progression_test.gd",
    "tests/loading_screen_test.gd",
    "tests/ui_flow_test.gd",
    "tests/combat_integration_test.gd",
    "tests/npc_test.gd",
    "tests/level_events_test.gd",
    "tests/navigation_integrity_test.gd",
    "tests/performance_audit_test.gd",
    "tests/arcade_combat_system_test.gd",
    "tests/player_hud_test.gd",
    "tests/arcade_hud_refinement_test.gd",
    "tests/sergio_npc_test.gd"
)


$failed_suites = @()
$passed_suites = 0

foreach ($test in $test_files) {
    Write-Host "`n>>> Executando: $test" -ForegroundColor Yellow
    $process = Start-Process -FilePath "godot_console.exe" -ArgumentList "--headless", "-s", $test -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -eq 0) {
        Write-Host "[OK] Suíte $test concluída com sucesso." -ForegroundColor Green
        $passed_suites++
    } else {
        Write-Host "[FALHA] Suíte $test encerrou com código $($process.ExitCode)." -ForegroundColor Red
        $failed_suites += $test
    }
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "RESUMO FINAL: $passed_suites/$($test_files.Count) SUÍTES PASSARAM." -ForegroundColor $(if ($failed_suites.Count -eq 0) { "Green" } else { "Red" })
Write-Host "==================================================" -ForegroundColor Cyan

if ($failed_suites.Count -gt 0) {
    Write-Host "Suítes que falharam: $($failed_suites -join ', ')" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Todas as suítes passaram com 100% de sucesso!" -ForegroundColor Green
    exit 0
}
