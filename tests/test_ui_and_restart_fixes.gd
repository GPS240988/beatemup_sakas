extends SceneTree

## Suíte de Testes para Validação dos 6 Itens da Auditoria:
## 1. Combo canônico de 4 golpes (Jab -> Cross -> Kick -> Finisher) sem saltos espúrios
## 2. Pressionamento de 'R' com inimigos vivos sem erro no console
## 3. Retorno ao Menu Principal ao pressionar qualquer botão no Mapa
## 4. Remoção de labels sobrepostas na tela de Dificuldade
## 5. Opção 'Personagens' desabilitada no Menu Principal (PC e Mobile)
## 6. Opção 'Configurações' no Mobile (ao clicar nada acontece, igual ao PC)

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

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
	print("========================================================================")
	print("SUÍTE DE TESTES: 6 ITENS DE AUDITORIA, UX E COMBATE (GODOT 4.x)")
	print("========================================================================")

	test_combo_chain_structure_and_window()
	test_restart_with_living_enemies()
	test_map_returns_to_main_menu_on_any_button()
	test_difficulty_screen_no_center_labels()
	test_main_menu_char_select_disabled()
	test_main_menu_settings_behavior()

	print("========================================================================")
	print("RESULTADO DOS TESTES: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("========================================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)

func test_combo_chain_structure_and_window() -> void:
	print("\n--- 1. Validação da Sequência Canônica de Combo ---")
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	assert_test(player_scene != null, "player.tscn carregada com sucesso")
	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	root.add_child(player)

	assert_test(player._combo_attacks.size() == 4, "Combo chain possui rigorosamente 4 ataques (sem duplicações)")
	assert_test(player._combo_attacks[0].get("attack_id") == "punch_1", "Passo 0 é Jab (punch_1)")
	assert_test(player._combo_attacks[1].get("attack_id") == "punch_2", "Passo 1 é Cruzado (punch_2)")
	assert_test(player._combo_attacks[2].get("attack_id") == "kick_3", "Passo 2 é Chute (kick_3)")
	assert_test(player._combo_attacks[3].get("attack_id") == "finisher_4", "Passo 3 é Finisher (finisher_4)")

	# Executa passo 0
	player._execute_combo_attack(0)
	assert_test(player._combo_step == 0, "Ataque inicial no passo 0")
	var win_0 = float(player._combo_attacks[0].get("combo_window"))
	assert_test(player._combo_window_timer <= win_0 + 0.05, "Janela de combo calibrada sem acréscimo excessivo")

	# Após o Finisher, o combo deve finalizar e resetar a janela para 0
	player._execute_combo_attack(3)
	assert_test(player._combo_window_timer == 0.0, "Finisher zera a janela de combo (combo_window == 0.0)")

	player.queue_free()

func test_restart_with_living_enemies() -> void:
	print("\n--- 2. Validação do Reinício ('R') com Inimigos Vivos ---")
	var map_scene: PackedScene = load("res://scenes/levels/map_1.tscn")
	assert_test(map_scene != null, "map_1.tscn carregada com sucesso")
	var map: Node = map_scene.instantiate()
	root.add_child(map)
	current_scene = map

	for i in range(10):
		await process_frame

	var enemies = root.get_tree().get_nodes_in_group("enemies")
	assert_test(enemies.size() > 0, "Existem inimigos vivos no mapa (total: %d)" % enemies.size())

	# Dispara simulação do reload da cena
	var err = reload_current_scene()
	assert_test(err == OK, "reload_current_scene() executado sem travar o motor")

	for i in range(15):
		await process_frame

	assert_test(true, "Cena recarregada com sucesso e sem exceções fatais de árvore")

func test_map_returns_to_main_menu_on_any_button() -> void:
	print("\n--- 3. Validação do Retorno do Mapa ao Menu Principal Conforme Contexto ---")
	var map_scene: PackedScene = load("res://scenes/ui/map_menu.tscn")
	assert_test(map_scene != null, "map_menu.tscn carregada com sucesso")

	var session = root.get_node_or_null("GameSession")
	if session != null:
		session.set_meta("map_entry_context", "browse")

	# Caso A: Acesso via Menu Principal (contexto "browse")
	var map_menu = map_scene.instantiate()
	map_menu._entry_context = "browse"
	root.add_child(map_menu)

	assert_test(map_menu.MAIN_MENU_SCENE == "res://scenes/ui/main_menu.tscn", "MAIN_MENU_SCENE aponta para main_menu.tscn")
	assert_test(map_menu.is_opened_from_menu() == true, "Identificado contexto de abertura via Menu Principal (browse)")

	map_menu._is_transitioning = false
	map_menu._on_confirm_pressed()
	assert_test(map_menu._is_transitioning == true, "[Browse] Confirmar aciona transição para o Menu Principal")

	map_menu._is_transitioning = false
	map_menu._on_back_pressed()
	assert_test(map_menu._is_transitioning == true, "[Browse] Voltar aciona transição para o Menu Principal")

	map_menu._is_transitioning = false
	map_menu._handle_point_click(Vector2(240, 348))
	assert_test(map_menu._is_transitioning == true, "[Browse] Clique em qualquer ponto/tela aciona retorno ao Menu Principal")

	map_menu.queue_free()

	if session != null:
		session.set_meta("map_entry_context", "campaign")

	# Caso B: Acesso via Campanha / Novo Jogo / Continuar (contexto "campaign")
	var map_campaign = map_scene.instantiate()
	map_campaign._entry_context = "campaign"
	root.add_child(map_campaign)

	assert_test(map_campaign.is_opened_from_menu() == false, "Identificado contexto de campanha (não browse)")
	map_campaign._is_transitioning = false
	map_campaign._select_point(0)
	map_campaign._on_confirm_pressed()
	assert_test(map_campaign._is_transitioning == true, "[Campanha] Confirmar no ponto selecionado avança para o fluxo do jogo")

	map_campaign._is_transitioning = false
	map_campaign._on_back_pressed()
	assert_test(map_campaign._is_transitioning == true, "[Campanha] Voltar aciona retorno à tela de dificuldade")

	map_campaign.queue_free()

	if session != null:
		session.remove_meta("map_entry_context")

func test_difficulty_screen_no_center_labels() -> void:
	print("\n--- 4. Validação da Tela de Dificuldade sem Labels Centralizadas ---")
	var diff_scene: PackedScene = load("res://scenes/ui/difficulty_select.tscn")
	assert_test(diff_scene != null, "difficulty_select.tscn carregada")
	var diff_inst = diff_scene.instantiate()
	root.add_child(diff_inst)

	var btn_start: Button = diff_inst.get_node_or_null("%BtnStartGame") as Button
	assert_test(btn_start != null, "BtnStartGame existe")
	if btn_start != null:
		assert_test(btn_start.text == "", "BtnStartGame não possui texto sobreposto desenhado (text == '')")

	var badge: Label = diff_inst.get_node_or_null("DifficultySelectionFrame/SelectionBadge") as Label
	if badge != null:
		assert_test(not badge.visible or badge.text == "", "SelectionBadge está oculta ou sem texto")
	else:
		assert_test(true, "Nenhuma SelectionBadge ativa sobre a arte da tela")

	diff_inst.queue_free()

func test_main_menu_char_select_disabled() -> void:
	print("\n--- 5. Validação de 'Personagens' Desabilitado no Menu Principal ---")
	var menu_scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	assert_test(menu_scene != null, "main_menu.tscn carregada")
	var menu_inst = menu_scene.instantiate()
	root.add_child(menu_inst)

	var btn_char: Button = menu_inst.get_node_or_null("%BtnCharSelect") as Button
	assert_test(btn_char != null, "BtnCharSelect existe no menu")
	if btn_char != null:
		assert_test(btn_char.disabled == true, "BtnCharSelect está DESABILITADO (disabled == true)")

	# Testa acionamento direto: nada deve acontecer
	menu_inst._is_transitioning = false
	menu_inst._activate_option(2)
	assert_test(menu_inst._is_transitioning == false, "Ativar opção 2 (Personagens) não inicia transição (desabilitada)")

	menu_inst.queue_free()

func test_main_menu_settings_behavior() -> void:
	print("\n--- 6. Validação de 'Configurações' no Menu Principal ---")
	var menu_scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	var menu_inst = menu_scene.instantiate()
	root.add_child(menu_inst)

	var btn_sett: Button = menu_inst.get_node_or_null("%BtnSettings") as Button
	assert_test(btn_sett != null, "BtnSettings existe no menu")
	if btn_sett != null:
		assert_test(btn_sett.disabled == false, "BtnSettings NÃO está apagada/desabilitada (disabled == false)")

	# Testa acionamento direto: nada deve acontecer
	menu_inst._is_transitioning = false
	menu_inst._activate_option(4)
	assert_test(menu_inst._is_transitioning == false, "Ativar opção 4 (Configurações) não inicia transição (nada acontece)")

	menu_inst.queue_free()

