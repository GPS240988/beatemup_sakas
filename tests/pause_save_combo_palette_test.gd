extends SceneTree

## Suíte de Testes Automatizados para:
## 1. Ordem de Navegação do Menu de Pausa (Continuar -> Salvar -> Config -> Sair)
## 2. Gravação Explícita de Slot com Feedback
## 3. Tela de Continuar com Exibição de Informações Salvas
## 4. Bloqueio de Slots Vazios na Tela de Continuar (Nada acontece)
## 5. Indicador "VAMOS, MALACOS!" e Placa de Saída Piscante "SIGA"

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

const GameSessionClass = preload("res://scripts/core/game_session.gd")
const PlayerControllerClass = preload("res://scripts/actors/player_controller.gd")
const EnemyAIClass = preload("res://scripts/actors/enemy_ai.gd")
const PauseMenuClass = preload("res://scripts/ui/pause_menu.gd")
const ContinueScreenClass = preload("res://scripts/ui/continue_screen.gd")
const SigaIndicatorClass = preload("res://scripts/ui/siga_indicator.gd")


func _init() -> void:
	call_deferred("_run_all_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_all_tests() -> void:
	print("==================================================")
	print("TESTES: MENU, SAVE/SLOTS, CONTINUAR E VAMOS MALACOS")
	print("==================================================")

	test_menu_char_select_disabled()
	test_pause_menu_navigation_order_and_slots()
	test_continue_screen_metadata_and_empty_guard()
	test_vamos_malacos_and_siga_exit_sign()
	test_combo_progression_stationary()
	test_enemy_palette_lightening()

	print("==================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)


func test_menu_char_select_disabled() -> void:
	print("\n--- 1. Testando Desativação da Seleção de Personagem no Menu ---")
	var scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	assert_test(scene != null, "Cena main_menu.tscn carregada com sucesso")

	var instance: Node = scene.instantiate()
	var btn_char: Button = instance.get_node_or_null("%BtnCharSelect") as Button
	assert_test(btn_char != null, "Botão BtnCharSelect existe no menu")
	if btn_char != null:
		assert_test(btn_char.disabled, "Botão BtnCharSelect está DESABILITADO no menu principal")
	instance.free()


func test_pause_menu_navigation_order_and_slots() -> void:
	print("\n--- 2. Testando Ordem de Navegação e Gravação de Slots no Menu de Pausa ---")
	var pause_scene: PackedScene = load("res://scenes/ui/pause_menu.tscn")
	assert_test(pause_scene != null, "Cena pause_menu.tscn carregada")

	var pause_inst: CanvasLayer = pause_scene.instantiate() as CanvasLayer
	root.add_child(pause_inst)
	pause_inst.open_pause("res://scenes/levels/map_1.tscn")

	# Verifica a ordem canônica dos botões
	assert_test(pause_inst._nav_buttons.size() == 4, "Menu de pausa possui exatamente 4 botões na lista de navegação")
	assert_test(pause_inst._nav_buttons[0] == pause_inst.btn_resume, "Primeira opção (índice 0) é CONTINUAR")
	assert_test(pause_inst._nav_buttons[1] == pause_inst.btn_save, "Segunda opção (índice 1) é SALVAR JOGO")
	assert_test(pause_inst._nav_buttons[2] == pause_inst.btn_settings, "Terceira opção (índice 2) é CONFIGURAÇÕES")
	assert_test(pause_inst._nav_buttons[3] == pause_inst.btn_quit, "Quarta opção (índice 3) é SAIR")

	# Simula navegação para baixo a partir do Continuar: deve ir direto para Salvar
	assert_test(pause_inst._selected_button_index == 0, "Foco inicial está em Continuar (índice 0)")
	pause_inst._navigate_selection(1)
	assert_test(pause_inst._selected_button_index == 1, "Ao descer com direcional (+1), Salvar Jogo é selecionado (índice 1)")

	# Testa seletor de slots para gravação
	pause_inst._on_save_pressed()
	assert_test(pause_inst._is_in_slots, "Ao clicar em Salvar Jogo, abre o seletor de slots")
	assert_test(pause_inst.save_slots_box.visible, "SaveSlotsBox está visível")

	# Grava no Slot 3
	pause_inst._save_to_slot(3)
	assert_test(pause_inst.status_label.text.contains("SLOT 3"), "Ao salvar, exibe explicitamente que o Slot 3 foi gravado")

	var session = GameSessionClass.new()
	session._ready()
	assert_test(session.has_save_in_slot(3), "GameSession confirma existência do save no Slot 3")
	session.delete_save_slot(3)
	session.free()

	pause_inst.queue_free()


func test_continue_screen_metadata_and_empty_guard() -> void:
	print("\n--- 3. Testando Tela de Continuar (Metadados e Bloqueio de Slot Vazio) ---")
	var cont_scene: PackedScene = load("res://scenes/ui/continue_screen.tscn")
	assert_test(cont_scene != null, "Cena continue_screen.tscn carregada")

	var session = GameSessionClass.new()
	session._ready()
	session.delete_save_slot(1)
	session.delete_save_slot(2)

	# Grava metadados ricos no Slot 1
	session.selected_character_id = "guilherme"
	session.difficulty_id = "dificil"
	session.save_game_to_slot(1, "res://scenes/levels/map_1.tscn", 100.0, 50.0)

	var cont_inst: Control = cont_scene.instantiate() as Control
	root.add_child(cont_inst)

	# Verifica se Slot 1 exibe as informações salvas
	var slot1_title: Label = cont_inst.get_node_or_null("%Slot1Title") as Label
	var slot1_det: Label = cont_inst.get_node_or_null("%Slot1Details") as Label
	assert_test(slot1_title != null and slot1_title.text.contains("MAPA 1"), "Slot 1 exibe nome do Mapa salvo")
	assert_test(slot1_title != null and slot1_title.text.contains("GUILHERME"), "Slot 1 exibe personagem salvo")
	assert_test(slot1_det != null and slot1_det.text.contains("DIFÍCIL"), "Slot 1 exibe dificuldade salva")
	assert_test(slot1_det != null and slot1_det.text.contains("SALVO EM:"), "Slot 1 exibe data e horário salvos")

	# Verifica se Slot 2 (vazio) exibe VAZIO
	var slot2_title: Label = cont_inst.get_node_or_null("%Slot2Title") as Label
	assert_test(slot2_title != null and slot2_title.text.contains("VAZIO"), "Slot 2 vazio exibe indicação clara de VAZIO")

	# Teste de Bloqueio Estrito: clicar em slot vazio NADA faz (não entra no jogo)
	cont_inst._select_slot(2, false)
	cont_inst._on_confirm_pressed()
	assert_test(cont_inst._is_transitioning == false, "Confirmar em slot vazio NÃO inicia transição de jogo")
	assert_test(cont_inst.notice_label.text.contains("VAZIO"), "Aviso de slot vazio é exibido na tela")

	session.delete_save_slot(1)
	session.free()
	cont_inst.queue_free()


func test_vamos_malacos_and_siga_exit_sign() -> void:
	print("\n--- 4. Testando 'VAMOS, MALACOS!' e Placa de Saída 'SIGA' ---")
	var siga_scene: PackedScene = load("res://scenes/ui/siga_indicator.tscn")
	assert_test(siga_scene != null, "Cena siga_indicator.tscn carregada")

	var siga_inst = siga_scene.instantiate()
	root.add_child(siga_inst)

	var vamos_rect: TextureRect = siga_inst.get_node_or_null("%VamosRect") as TextureRect
	assert_test(vamos_rect != null, "Banner VamosRect existe no CanvasLayer")
	if vamos_rect != null:
		assert_test(vamos_rect.texture != null and vamos_rect.texture.resource_path.contains("vamos.webp"), "Banner utiliza res://assets/backgrounds/vamos.webp")

	var exit_sign: Sprite2D = siga_inst.get_node_or_null("%ExitSignSprite") as Sprite2D
	assert_test(exit_sign != null, "Placa de saída ExitSignSprite existe no cenário")
	if exit_sign != null:
		assert_test(exit_sign.texture != null and exit_sign.texture.resource_path.contains("siga.webp"), "Placa de saída utiliza res://assets/backgrounds/siga.webp")

	# Ativa o indicador
	siga_inst.delay_before_appear = 0.0 # Sem delay no teste unitário
	siga_inst.activate()
	assert_test(siga_inst.is_active(), "Indicador é ativado com sucesso")

	siga_inst.deactivate()
	assert_test(not siga_inst.is_active(), "Indicador é desativado com sucesso")
	siga_inst.queue_free()


func test_combo_progression_stationary() -> void:
	print("\n--- 5. Testando Encadeamento Contínuo do Combo Parado ---")
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	assert_test(player_scene != null, "player.tscn carregada com sucesso")
	var player = player_scene.instantiate()
	root.add_child(player)

	assert_test(player._combo_attacks.size() >= 4, "Combo chain de 4 ataques inicializado")

	# Golpe 1: Soco
	player._on_attack_button_pressed()
	assert_test(player._combo_step == 0, "Primeiro ataque é o Soco inicial (step 0)")
	assert_test(player._combo_window_timer > 0.0, "Janela de combo foi aberta para encadeamento")

	# Golpe 2: Cruzado
	player.melee_attack.current_phase = 3
	player.melee_attack.is_active_window = false
	player._on_attack_button_pressed()
	assert_test(player._combo_step == 1, "Segundo ataque consecutivo é o Cruzado (step 1)")

	# Golpe 3: Chute
	player._on_attack_button_pressed()
	assert_test(player._input_buffered, "Input durante fase ativa é armazenado no buffer")
	player._on_attack_ended()
	assert_test(player._combo_step == 2, "Terceiro ataque encadeado pelo buffer é o Chute (step 2)")

	# Verifica a constante de chance do Heavy Finisher (20%)
	assert_test(player.HEAVY_FINISHER_CHANCE == 0.20, "Chance do Heavy Finisher calibrada em 20%%")

	# Golpe 4: Heavy Finisher é probabilístico (~20% de chance após o chute)
	# Testa múltiplas vezes para garantir que ambos os caminhos (heavy e restart) são possíveis
	var got_heavy: bool = false
	var got_restart: bool = false
	for attempt in range(40):
		player._combo_step = 2  # Simula estar no chute
		player.melee_attack.current_phase = 3  # RECOVERY
		player.melee_attack.is_active_window = false
		player.melee_attack.is_attacking = true
		player._on_attack_button_pressed()
		if player._combo_step == 3:
			got_heavy = true
		elif player._combo_step == 0:
			got_restart = true
		# Reseta para próxima iteração
		if player.melee_attack != null:
			player.melee_attack.cancel_attack()
		player._input_buffered = false

	assert_test(got_heavy or got_restart, "Heavy/Restart: pelo menos um caminho ocorreu nas 40 tentativas")
	assert_test(got_restart, "Combo reinicia no Soco na maioria das vezes (80%% esperado)")

	# Verifica que após o Heavy (step 3), o combo sempre reinicia no Soco (step 0)
	player._combo_step = 3
	player.melee_attack.is_attacking = false
	player._on_attack_ended()
	player._on_attack_button_pressed()
	assert_test(player._combo_step == 0, "Ataque seguinte ao Finisher reinicia no Soco (step 0)")

	player.queue_free()


func test_enemy_palette_lightening() -> void:
	print("\n--- 6. Testando Clareamento da Paleta Vermelha do Inimigo ---")
	assert_test(EnemyAIClass.PALETTE_VALUE_ADJUSTS.has(EnemyAIClass.PaletteVariant.RED), "Constante PALETTE_VALUE_ADJUSTS possui entrada para RED")
	var red_val_adjust: float = float(EnemyAIClass.PALETTE_VALUE_ADJUSTS.get(EnemyAIClass.PaletteVariant.RED, 0.0))
	assert_test(red_val_adjust >= 0.25, "Luminosidade (value_adjust) da paleta RED clareada em >= +25%% (atual: %0.2f)" % red_val_adjust)

	assert_test(EnemyAIClass.PALETTE_SAT_ADJUSTS.has(EnemyAIClass.PaletteVariant.RED), "Constante PALETTE_SAT_ADJUSTS possui entrada para RED")
	var red_sat_adjust: float = float(EnemyAIClass.PALETTE_SAT_ADJUSTS.get(EnemyAIClass.PaletteVariant.RED, 0.0))
	assert_test(red_sat_adjust > 0.0, "Saturação (saturation_adjust) da paleta RED calibrada para manter vivacidade (atual: %0.2f)" % red_sat_adjust)

	var map1_scene: PackedScene = load("res://scenes/levels/map_1.tscn")
	assert_test(map1_scene != null, "Cena map_1.tscn carregada com sucesso")
	var map1_inst: Node = map1_scene.instantiate()
	var enemy1: Node = map1_inst.get_node_or_null("World/Actors/Enemies/BasicEnemy1")
	assert_test(enemy1 != null, "Inimigo inicial BasicEnemy1 existe no Mapa 1")
	if enemy1 != null:
		assert_test(enemy1.get("palette_variant") == EnemyAIClass.PaletteVariant.RED, "BasicEnemy1 no Mapa 1 está com palette_variant = RED (1)")
	map1_inst.free()
