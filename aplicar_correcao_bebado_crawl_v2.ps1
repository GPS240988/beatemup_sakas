param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$target = Join-Path $ProjectRoot 'scripts/actors/bebado_enemy.gd'
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    throw "Arquivo nao encontrado: $target. Execute na raiz do projeto ou informe -ProjectRoot."
}

$original = [System.IO.File]::ReadAllText($target)
$hadCrLf = $original.Contains("`r`n")
$content = $original -replace "`r`n", "`n"

function Get-MatchCount {
    param([string]$Text, [string]$Pattern)
    return [regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline).Count
}

function Replace-One {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Replacement,
        [string]$Label
    )
    $count = Get-MatchCount $Text $Pattern
    if ($count -ne 1) {
        throw "Nao foi possivel atualizar '$Label': esperado 1 ponto de insercao, encontrado $count. O arquivo original foi preservado."
    }
    return [regex]::Replace($Text, $Pattern, $Replacement, [System.Text.RegularExpressions.RegexOptions]::Multiline)
}

# 1) Parametro configuravel para o gatilho de vida baixa.
if ($content -notmatch '(?m)^\s*@export_range\([^\r\n]*\)\s*var\s+crawl_low_health_threshold\s*:') {
    $anchor = '(?<line>^[\t ]*@export\s+var\s+crawl_duration\s*:[^\r\n]*$)'
    $replacement = '@export_range(0.05, 0.95, 0.05) var crawl_low_health_threshold: float = 0.50' + "`n" + '${line}'
    $content = Replace-One $content $anchor $replacement 'limiar de vida baixa'
}

# 2) Estado que mantem a decisao pendente ate um momento seguro.
if ($content -notmatch '(?m)^\s*var\s+_spontaneous_crawl_pending\s*:') {
    $anchor = '(?<line>^[\t ]*var\s+_next_spontaneous_crawl_time\s*:[^\r\n]*$)'
    $replacement = '${line}' + "`n" + 'var _spontaneous_crawl_pending: bool = false' + "`n" + 'var _low_health_crawl_used: bool = false'
    $content = Replace-One $content $anchor $replacement 'variaveis do crawl espontaneo'
} elseif ($content -notmatch '(?m)^\s*var\s+_low_health_crawl_used\s*:') {
    $anchor = '(?<line>^[\t ]*var\s+_spontaneous_crawl_pending\s*:[^\r\n]*$)'
    $replacement = '${line}' + "`n" + 'var _low_health_crawl_used: bool = false'
    $content = Replace-One $content $anchor $replacement 'controle de crawl por vida baixa'
}

# 3) Troca o antigo gatilho restrito a FLANKING/distancia por uma unica decisao central.
# Se a versao local ainda possuir o bloco antigo, neutraliza somente sua condicao.
$legacyCondition = '(?<indent>^[\t ]*)if\s+bebado_state\s*==\s*BebadoState\.NONE\s+and\s+current_state\s*==\s*State\.FLANKING\s+and\s+_crawl_cooldown\s*<=\s*0\.0\s*:'
if ((Get-MatchCount $content $legacyCondition) -eq 1) {
    $content = [regex]::Replace($content, $legacyCondition, '${indent}if false:', [System.Text.RegularExpressions.RegexOptions]::Multiline)
} elseif ((Get-MatchCount $content $legacyCondition) -gt 1) {
    throw 'Foram encontrados varios gatilhos antigos de crawl; o arquivo original foi preservado.'
}

# 4) Chama o novo avaliador antes da acao contextual de beber.
if ($content -notmatch '(?m)^\s*if\s+_update_spontaneous_crawl\(delta\)\s*:') {
    $anchor = '(?<indent>^[\t ]*)if\s+_can_attempt_drink\(\)\s*:'
    $replacement = '${indent}# O crawl espontaneo nao depende do estado FLANKING nem da distancia.' + "`n" + '${indent}if _update_spontaneous_crawl(delta):' + "`n" + '${indent}' + "`t" + 'return' + "`n`n" + '${indent}if _can_attempt_drink():'
    $content = Replace-One $content $anchor $replacement 'chamada do avaliador de crawl'
}

# 5) Insere a rotina, caso ainda nao exista.
if ($content -notmatch '(?m)^func\s+_update_spontaneous_crawl\(') {
    $helper = @'

## Decide o crawl espontaneo durante a batalha, sem interromper acoes criticas.
## Abaixo do limiar de vida, deixa a decisao pendente ate o primeiro estado seguro.
func _update_spontaneous_crawl(delta: float) -> bool:
	if health_component == null or health_component.is_dead or current_state == State.DEAD:
		return false
	if player_target == null or not is_instance_valid(player_target):
		return false

	var player_health := player_target.get_node_or_null("HealthComponent") as HealthComponent
	if player_health != null and player_health.is_dead:
		return false

	var health_ratio: float = health_component.current_health / maxf(health_component.max_health, 1.0)
	var low_health_trigger: bool = (
		health_ratio <= clampf(crawl_low_health_threshold, 0.05, 0.95)
		and not _low_health_crawl_used
	)
	if low_health_trigger:
		_spontaneous_crawl_pending = true

	# Primeira tentativa apos 6-12 s; se falhar, tenta novamente a cada segundo.
	if not _spontaneous_crawl_pending:
		_next_spontaneous_crawl_time -= delta
		if _next_spontaneous_crawl_time <= 0.0:
			if randf() <= clampf(crawl_spontaneous_chance, 0.0, 1.0):
				_spontaneous_crawl_pending = true
			else:
				_next_spontaneous_crawl_time = 1.0

	if not _spontaneous_crawl_pending or _crawl_cooldown > 0.0:
		return false

	# Nao interrompe ataque, preparacao, hitstun, queda ou levantamento.
	if not current_state in [
		State.IDLE,
		State.WAITING,
		State.FLANKING,
		State.ALIGNING_DEPTH,
		State.APPROACHING,
		State.RECOVERY
	]:
		return false

	start_crawl()
	if low_health_trigger:
		_low_health_crawl_used = true
	_spontaneous_crawl_pending = false
	_reset_spontaneous_crawl_timer()
	return true


func _reset_spontaneous_crawl_timer() -> void:
	var minimum_interval: float = maxf(1.0, crawl_spontaneous_min_interval)
	var maximum_interval: float = maxf(minimum_interval, crawl_spontaneous_max_interval)
	_next_spontaneous_crawl_time = randf_range(minimum_interval, maximum_interval)

'@
    $anchor = '(?m)^func\s+_can_attempt_dodge\(\)\s*->\s*bool\s*:'
    $content = Replace-One $content $anchor ($helper + 'func _can_attempt_dodge() -> bool:') 'rotina de decisao do crawl'
}

# 6) Impede que alguma chamada externa inicie crawl depois da morte.
if ($content -notmatch '(?s)func\s+start_crawl\(\)\s*->\s*void\s*:\s*\n\s*_ensure_internal_refs\(\)\s*\n\s*if current_state == State\.DEAD') {
    $pattern = '(?<head>func[\t ]+start_crawl\(\)[\t ]*->[\t ]*void[\t ]*:[\t ]*\n[\t ]*_ensure_internal_refs\(\)[\t ]*\n)'
    $replacement = '${head}' + "`tif current_state == State.DEAD or (health_component != null and health_component.is_dead):`n`t`treturn`n"
    $content = Replace-One $content $pattern $replacement 'protecao contra crawl apos a morte'
}

# 7) Grava somente depois que todas as validacoes e insercoes terminaram.
$normalizedOriginal = $original -replace "`r`n", "`n"
if ($content -eq $normalizedOriginal) {
    Write-Host 'A correcao ja parece estar aplicada; nenhum arquivo foi alterado.' -ForegroundColor Yellow
    exit 0
}

$backup = "$target.before_crawl_v2_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
[System.IO.File]::Copy($target, $backup, $false)
if ($hadCrLf) { $content = $content -replace "`n", "`r`n" }
$utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
[System.IO.File]::WriteAllText($target, $content, $utf8NoBom)

Write-Host 'Correcao v2 aplicada.' -ForegroundColor Green
Write-Host "Arquivo: $target"
Write-Host "Backup: $backup"
Write-Host 'O crawl espontaneo agora tenta ocorrer durante a batalha e recebe prioridade ao atingir 50% de vida.'
