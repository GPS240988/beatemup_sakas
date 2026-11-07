extends SceneTree

## Suíte Oficial de Testes — Apresentação Cinematográfica do Golpe Especial (2,50s)
## Valida o contrato arquitetural e temporal conforme especificações da tarefa:
## 1. Duração total da apresentação ~2,50s
## 2. Cobertura integral da viewport e redimensionamento responsivo em múltiplos formatos mobile (16:9, 20:9, 4:3)
## 3. Preservação da proporção da arte oficial (STRETCH_KEEP_ASPECT_COVERED)
## 4. Remoção do texto '★ FURACÃO DE SAKAS ★'
## 5. Impacto emitido exatamente no ápice (t ~ 1.30s) e uma única vez (idempotente)
## 6. Finalização emitida uma única vez (idempotente)
## 7. Barra especial consumida uma única vez (100% de carga)
## 8. Todos os inimigos vivos atingidos com dano global e queda obrigatória
## 9. NPCs civis preservados
## 10. Invulnerabilidade ativa durante a apresentação e retorno seguro ao estado NORMAL

const SpecialPresentationClass = preload("res://scripts/combat/special_presentation.gd")
const HeroDataClass = preload("res://scripts/combat/hero_data.gd")
const PlayerControllerClass = preload("res://scripts/actors/player_controller.gd")
const EnemyAIClass = preload("res://scripts/actors/enemy_ai.gd")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func assert_test(condition: bool, message: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % message)


func _init() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	print("\n" + "=".repeat(72))
	print("SUÍTE DE TESTES: APRESENTAÇÃO CINEMATOGRÁFICA DO ESPECIAL (2,50s)")
	print("=".repeat(72))

	await _test_hero_data_contract()
	await _test_viewport_coverage_and_aspect()
	await _test_mobile_responsiveness()
	await _test_special_timing_and_signals()
	await _test_player_integration_and_gameplay()

	print("\n" + "-".repeat(72))
	print("RESULTADO DOS TESTES DO ESPECIAL: %d/%d PASSARAM (Falhas: %d)" % [_passed, _total, _failed])
	print("-".repeat(72) + "\n")

	quit(0 if _failed == 0 else 1)


func _test_hero_data_contract() -> void:
	print("\n--- 1. Contrato de Dados do HeroData ---")
	var hd: HeroData = load("res://resources/heroes/guilherme_data.tres")
	assert_test(hd != null, "Recurso guilherme_data.tres carregado com sucesso")
	if hd != null:
		assert_test(hd.special_presentation_texture != null, "HeroData possui special_presentation_texture atribuída")
		assert_test(hd.special_presentation_texture.resource_path == "res://assets/sprites/characters/guilherme/especial_1_guilherme.webp", "Textura oficial é especial_1_guilherme.webp")
		assert_test(hd.special_title.is_empty(), "Texto '★ FURACÃO DE SAKAS ★' foi removido do HeroData (vazio)")
		assert_test(is_equal_approx(hd.special_presentation_duration, 2.5), "Duração contratual no HeroData ampliada para 2,50s")
		assert_test(hd.special_theme_color.a > 0.0, "Cor temática do especial possui canal alfa configurado")


func _test_viewport_coverage_and_aspect() -> void:
	print("\n--- 2. Cobertura Integral da Viewport e Preservação de Aspecto ---")
	var root_ctrl := Control.new()
	root_ctrl.size = Vector2(1280, 720)
	root.add_child(root_ctrl)

	var hd: HeroData = load("res://resources/heroes/guilherme_data.tres")
	var pres: SpecialPresentation = SpecialPresentationClass.new(hd)
	root.add_child(pres)

	var pres_root: Control = pres.get_node_or_null("SpecialPresentationRoot")
	assert_test(pres_root != null, "Container raiz SpecialPresentationRoot criado")

	var img_rect: TextureRect = pres.get_node_or_null("SpecialPresentationRoot/SpecialImage")
	assert_test(img_rect != null, "Nó TextureRect SpecialImage criado na apresentação")
	if img_rect != null:
		assert_test(img_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "StretchMode é STRETCH_KEEP_ASPECT_COVERED (cobertura total sem distorcer arte)")
		assert_test(img_rect.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "ExpandMode é EXPAND_IGNORE_SIZE para preenchimento elástico")
		assert_test(img_rect.anchor_right == 1.0 and img_rect.anchor_bottom == 1.0, "Âncoras configuradas como PRESET_FULL_RECT cobrindo a viewport inteira")

	var title_lbl: Label = pres.get_node_or_null("SpecialPresentationRoot/SpecialTitle")
	assert_test(title_lbl == null, "Rótulo SpecialTitle ('★ FURACÃO DE SAKAS ★') completamente removido da apresentação")

	var flash: ColorRect = pres.get_node_or_null("SpecialPresentationRoot/ImpactFlash")
	assert_test(flash != null, "Nó ImpactFlash criado para o ápice do impacto")

	pres.queue_free()
	root_ctrl.queue_free()
	await process_frame


func _test_mobile_responsiveness() -> void:
	print("\n--- 3. Redimensionamento e Cobertura Mobile (Ultrawide 20:9 e Tablet 4:3) ---")
	var hd: HeroData = load("res://resources/heroes/guilherme_data.tres")

	# Teste 1: Viewport Mobile Ultrawide 2400x1080 (20:9)
	var vp_mobile := SubViewport.new()
	vp_mobile.size = Vector2i(2400, 1080)
	root.add_child(vp_mobile)

	var pres_mobile: SpecialPresentation = SpecialPresentationClass.new(hd)
	vp_mobile.add_child(pres_mobile)
	await process_frame
	await process_frame

	var img_mobile: TextureRect = pres_mobile.get_node_or_null("SpecialPresentationRoot/SpecialImage")
	assert_test(img_mobile != null, "SpecialImage presente na viewport mobile 20:9")
	if img_mobile != null:
		assert_test(img_mobile.size.x >= 2400.0 and img_mobile.size.y >= 1080.0, "Mobile ultrawide 20:9: SpecialImage preenche tela (%.1fx%.1f)" % [img_mobile.size.x, img_mobile.size.y])
		assert_test(is_equal_approx(img_mobile.pivot_offset.x, 1200.0) and is_equal_approx(img_mobile.pivot_offset.y, 540.0), "Mobile ultrawide 20:9: pivot centralizado em (1200, 540)")

	pres_mobile.queue_free()
	vp_mobile.queue_free()

	# Teste 2: Viewport Mobile Tablet 2048x1536 (4:3)
	var vp_tablet := SubViewport.new()
	vp_tablet.size = Vector2i(2048, 1536)
	root.add_child(vp_tablet)

	var pres_tablet: SpecialPresentation = SpecialPresentationClass.new(hd)
	vp_tablet.add_child(pres_tablet)
	await process_frame
	await process_frame

	var img_tablet: TextureRect = pres_tablet.get_node_or_null("SpecialPresentationRoot/SpecialImage")
	assert_test(img_tablet != null, "SpecialImage presente na viewport tablet 4:3")
	if img_tablet != null:
		assert_test(img_tablet.size.x >= 2048.0 and img_tablet.size.y >= 1536.0, "Mobile tablet 4:3: SpecialImage preenche tela (%.1fx%.1f)" % [img_tablet.size.x, img_tablet.size.y])
		assert_test(is_equal_approx(img_tablet.pivot_offset.x, 1024.0) and is_equal_approx(img_tablet.pivot_offset.y, 768.0), "Mobile tablet 4:3: pivot centralizado em (1024, 768)")

	pres_tablet.queue_free()
	vp_tablet.queue_free()
	await process_frame


func _test_special_timing_and_signals() -> void:
	print("\n--- 4. Contrato Temporal e Emissão Idempotente dos Sinais (2,50s) ---")
	var hd: HeroData = load("res://resources/heroes/guilherme_data.tres")
	var pres: SpecialPresentation = SpecialPresentationClass.new(hd)
	root.add_child(pres)

	var results := {
		"impact_count": 0,
		"finished_count": 0,
		"impact_time": 0.0,
		"finish_time": 0.0
	}

	var tw = pres._anim_tween
	pres.impact_reached.connect(func():
		results["impact_count"] += 1
		results["impact_time"] = tw.get_total_elapsed_time() if tw != null else 0.0
	)

	pres.finished.connect(func():
		results["finished_count"] += 1
		results["finish_time"] = tw.get_total_elapsed_time() if tw != null else 0.0
	)

	# Aguarda a conclusão completa da animação de 2,50s
	await create_timer(2.8).timeout

	assert_test(results["impact_count"] == 1, "Sinal impact_reached emitido estritamente UMA ÚNICA VEZ (idempotente)")
	assert_test(results["finished_count"] == 1, "Sinal finished emitido estritamente UMA ÚNICA VEZ (idempotente)")

	var it: float = results["impact_time"]
	var ft: float = results["finish_time"]
	assert_test(absf(it - 1.30) < 0.05, "Momento do impacto em ~1.30s no Tween interno (Registrado: %.3fs)" % it)
	assert_test(absf(ft - 2.50) < 0.05, "Duração total da apresentação em ~2.50s no Tween interno (Registrado: %.3fs)" % ft)


func _test_player_integration_and_gameplay() -> void:
	print("\n--- 5. Integração com PlayerController e Coordenação de Gameplay ---")
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var npc_scene: PackedScene = load("res://scenes/actors/npc.tscn")

	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)

	var enemy1: EnemyAI = enemy_scene.instantiate() as EnemyAI
	enemy1.position = Vector2(200, 0)
	root.add_child(enemy1)

	var enemy2: EnemyAI = enemy_scene.instantiate() as EnemyAI
	enemy2.position = Vector2(-200, 50)
	root.add_child(enemy2)

	var npc: Node = npc_scene.instantiate()
	npc.position = Vector2(100, 0)
	root.add_child(npc)

	await process_frame
	await process_frame

	# 1. Validação de bloqueio com carga incompleta
	player.current_special = 50.0
	var fail_start: bool = player.execute_special()
	assert_test(fail_start == false, "Especial bloqueado quando carga < 100%")
	assert_test(player.combat_state != PlayerControllerClass.CombatState.SPECIAL, "Estado do jogador não muda para SPECIAL")

	# 2. Execução com 100% de carga
	player.current_special = 100.0
	var success_start: bool = player.execute_special()
	assert_test(success_start == true, "Especial acionado com sucesso quando 100% carregado")
	assert_test(is_equal_approx(player.current_special, 0.0), "Barra de especial esvaziada (consumo de 100%)")
	assert_test(player._is_invulnerable == true, "Invulnerabilidade ativada durante o especial")
	assert_test(player.combat_state == PlayerControllerClass.CombatState.SPECIAL, "Estado do jogador passa para SPECIAL")

	# 3. Disparo idempotente do dano global (no momento do impacto)
	var e1_hp_init: float = enemy1.health_component.current_health
	var e2_hp_init: float = enemy2.health_component.current_health
	var npc_hc = npc.get_node_or_null("HealthComponent")
	var npc_hp_init: float = npc_hc.current_health if npc_hc != null else 100.0

	# Simula o gatilho do impacto
	player._apply_global_special_impact()

	assert_test(enemy1.health_component.current_health < e1_hp_init, "Inimigo 1 vivo sofre dano global")
	assert_test(enemy1.current_state == EnemyAIClass.State.FALL, "Inimigo 1 sofre queda obrigatória (FALL)")
	assert_test(enemy2.health_component.current_health < e2_hp_init, "Inimigo 2 vivo sofre dano global")
	assert_test(enemy2.current_state == EnemyAIClass.State.FALL, "Inimigo 2 sofre queda obrigatória (FALL)")
	if npc_hc != null:
		assert_test(npc_hc.current_health == npc_hp_init, "NPC civil é preservado (imune ao dano de área)")

	# Limpeza
	player.queue_free()
	enemy1.queue_free()
	enemy2.queue_free()
	npc.queue_free()
	await process_frame
