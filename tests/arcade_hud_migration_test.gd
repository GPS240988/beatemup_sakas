extends SceneTree

var _passed_count: int = 0
var _failed_count: int = 0


func assert_test(condition: bool, message: String) -> void:
	if condition:
		_passed_count += 1
		print("  [OK] %s" % message)
	else:
		_failed_count += 1
		printerr("  [FALHA] %s" % message)


func _init() -> void:
	print("\n==================================================")
	print("INICIANDO SUITE DE TESTES: MIGRAÇÃO DEFINITIVA HUD ARCADE")
	print("==================================================\n")
	_run_tests_async()


func _run_tests_async() -> void:
	# 1. Carregamento da Cena PrototypeHud
	var hud_scene: PackedScene = load("res://scenes/ui/prototype_hud.tscn")
	assert_test(hud_scene != null, "Cena prototype_hud.tscn carregada com sucesso")

	var hud: PrototypeHud = hud_scene.instantiate() as PrototypeHud
	assert_test(hud != null, "Instância de PrototypeHud criada com sucesso")
	root.add_child(hud)
	await process_frame

	# 2. Verificação dos Três Módulos Centrais (Top Bar Arcade)
	print("\n--- 1. Verificando Composição da Top Bar Arcade ---")
	assert_test(hud.player_hud != null, "Módulo PlayerHUD existe na HUD")
	assert_test(hud.center_hud != null, "Módulo CenterHUD (Fase e Cronômetro) existe na HUD")
	assert_test(hud.enemy_hud != null, "Módulo EnemyHUD (Alvo Inimigo) existe na HUD")

	# 3. Verificação do Módulo PlayerHUD
	print("\n--- 2. Verificando Proporções e Elementos da PlayerHUD ---")
	assert_test(hud.player_hud.custom_minimum_size == Vector2(340, 78), "PlayerHUD tem dimensões compactas oficiais (340x78)")
	assert_test(hud.player_hud.hp_bar != null and hud.player_hud.hp_bar is SegmentedBar, "HpBar do jogador é SegmentedBar")
	assert_test(hud.player_hud.special_bar != null and hud.player_hud.special_bar is SegmentedBar, "SpecialBar do jogador é SegmentedBar")
	assert_test(hud.player_hud.hp_bar.filled_color == Color(1.0, 0.72, 0.05, 1.0), "Vida do jogador utiliza segmentos amarelos/dourados da referência 2")
	assert_test(hud.player_hud.hp_bar.frame_color == Color(0.0, 0.65, 1.0, 1.0), "Moldura da vida utiliza azul neon arcade (#00A2FF)")
	assert_test(hud.player_hud.name_label != null and hud.player_hud.name_label.visible, "Nome do jogador visível e nítido")
	assert_test(hud.player_hud.continue_label != null, "ContinueLabel existe para contador de fichas")
	assert_test(hud.player_hud.continue_label.text == "CONTINUE ×1", "ContinueLabel exibe texto canônico 'CONTINUE ×1'")
	assert_test(hud.player_hud.get_node_or_null("MainRow/BarsColumn/HeaderRow/ContinueContainer/DiceIcon") != null, "Ícone de dado arcade (DiceIcon) configurado na linha do nome")
	assert_test(hud.player_hud.special_bar.custom_minimum_size.x < hud.player_hud.hp_bar.custom_minimum_size.x, "Barra Especial (~150px) é significativamente mais curta que a barra de vida (~250px)")
	assert_test(hud.player_hud.combo_container != null, "ComboContainer arcade existe")

	# 4. Verificação do Módulo CenterHUD (Fase e Cronômetro)
	print("\n--- 3. Verificando Fase e Cronômetro (CenterHUD) ---")
	assert_test(hud.center_hud.stage_label != null, "StageLabel existe no centro superior")
	assert_test(hud.center_hud.timer_label != null, "TimerLabel existe no centro superior")
	assert_test(hud.center_hud.stage_label.text.contains("FASE"), "StageLabel exibe texto de fase")
	hud.center_hud.set_stage_index(1, 2)
	assert_test(hud.center_hud.stage_label.text == "FASE 1-2", "Atualização dinâmica de fase para 'FASE 1-2'")
	hud.center_hud.set_time_seconds(157)
	assert_test(hud.center_hud.timer_label.text == "02:37", "Cronômetro formata segundos em MM:SS ('02:37')")

	# 5. Verificação do Módulo EnemyHUD (Canto Superior Direito)
	print("\n--- 4. Verificando Alvo Inimigo (EnemyHUD) ---")
	assert_test(hud.enemy_hud.custom_minimum_size == Vector2(340, 78), "EnemyHUD tem dimensões compactas oficiais (340x78)")
	assert_test(hud.enemy_hud.enemy_name_label != null, "EnemyNameLabel existe alinhado à direita")
	assert_test(hud.enemy_hud.enemy_name_label.text == "JOGADOR DE MAGIC", "Nome do inimigo padrão é 'JOGADOR DE MAGIC'")
	assert_test(hud.enemy_hud.hp_bar != null and hud.enemy_hud.hp_bar is SegmentedBar, "Barra de vida do inimigo é SegmentedBar")
	assert_test(hud.enemy_hud.hp_bar.filled_color == Color(0.95, 0.12, 0.12, 1.0), "Barra de vida do inimigo utiliza segmentos vermelhos da referência 2")
	assert_test(hud.enemy_hud.portrait_texture != null and hud.enemy_hud.portrait_texture.texture != null, "Retrato do inimigo carregado")

	# 6. Testando Atualizações Dinâmicas Integradas
	print("\n--- 5. Verificando Atualizações Dinâmicas Integradas ---")
	hud.update_enemy_health(60.0, 100.0)
	assert_test(is_equal_approx(hud.enemy_hud.current_hp, 60.0), "update_enemy_health atualiza EnemyHUD para 60.0")
	assert_test(hud.enemy_hud.hp_bar.value <= 60.0, "HpBar do inimigo reflete novo valor")

	hud.set_stage_section(1, 4)
	assert_test(hud.center_hud.stage_label.text == "FASE 1-4", "set_stage_section atualiza fase no CenterHUD para FASE 1-4")

	hud.set_combo_hits(8)
	assert_test(hud.player_hud.combo_container.visible, "ComboContainer visível com 8 hits")
	assert_test(hud.player_hud.combo_hits_label.text == "8 HITS", "ComboHitsLabel exibe '8 HITS'")

	# Finalização
	hud.queue_free()

	print("\n==================================================")
	print("RESULTADO FINAL: %d PASSARAM (Falhas: %d)" % [_passed_count, _failed_count])
	print("==================================================")

	if _failed_count > 0:
		print("\n[ERRO] Falhas detectadas na suíte de testes da HUD Arcade.")
		quit(1)
	else:
		print("\n[OK] Todos os testes da HUD Arcade passaram com 100% de sucesso!")
		quit(0)
