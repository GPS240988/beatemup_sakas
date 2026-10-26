extends SceneTree

## Suíte de Testes Automatizados Headless para o Fluxo de Menu, Seleção e Sessão de Jogo.

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
	print("==================================================")
	print("INICIANDO TESTES DO FLUXO DE MENU E SELEÇÃO (GODOT 4.x)")
	print("==================================================")

	test_game_session_state_and_rules()
	test_title_screen_scene()
	test_main_menu_scene()
	test_credits_scene()
	test_character_select_scene()
	test_skin_select_scene()
	test_difficulty_select_scene()

	print("==================================================")
	print("RESULTADO DOS TESTES UI: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)


func test_game_session_state_and_rules() -> void:
	print("\n--- Testando GameSession (Estado e Regras de Negócio) ---")
	var session = GameSessionClass.new()
	session._ready()

	# Estado inicial
	assert_test(session.selected_character_id == "guilherme", "Personagem inicial padrão é 'guilherme'")
	assert_test(session.selected_skin_id == "palmeirense", "Skin inicial padrão é 'palmeirense'")
	assert_test(session.difficulty_id == "", "Dificuldade inicial é vazia até escolha do usuário")

	# Desbloqueio de personagens
	assert_test(session.is_character_unlocked("guilherme"), "Guilherme está DESBLOQUEADO")
	assert_test(not session.is_character_unlocked("alessandro"), "Alessandro está BLOQUEADO")
	assert_test(not session.is_character_unlocked("andre"), "André está BLOQUEADO")
	assert_test(not session.is_character_unlocked("fernando"), "Fernando está BLOQUEADO")
	assert_test(not session.is_character_unlocked("gabriel"), "Gabriel está BLOQUEADO")
	assert_test(not session.is_character_unlocked("juliana"), "Juliana está BLOQUEADO")

	# Tentativa de confirmação de personagem bloqueado
	var select_locked: bool = session.select_character("alessandro")
	assert_test(not select_locked, "Tentativa de selecionar personagem bloqueado retorna false")
	assert_test(session.selected_character_id == "guilherme", "Personagem selecionado não foi alterado para personagem bloqueado")

	# Confirmação válida
	var select_valid: bool = session.select_character("guilherme")
	assert_test(select_valid and session.selected_character_id == "guilherme", "Confirmação de Guilherme é aceita com sucesso")

	# Desbloqueio de skins
	assert_test(session.is_skin_unlocked("palmeirense"), "Skin Palmeirense está DESBLOQUEADA")
	assert_test(not session.is_skin_unlocked("pelado"), "Skin Pelado está BLOQUEADA")

	var skin_locked: bool = session.select_skin("pelado")
	assert_test(not skin_locked, "Tentativa de selecionar skin Pelado bloqueada retorna false")
	assert_test(session.selected_skin_id == "palmeirense", "Skin selecionada permanece 'palmeirense'")

	# Dificuldades
	assert_test(session.is_difficulty_valid("normal"), "Dificuldade 'normal' é válida")
	assert_test(session.is_difficulty_valid("dificil"), "Dificuldade 'dificil' é válida")
	assert_test(not session.is_difficulty_valid("impossivel"), "Dificuldade desconhecida é inválida")

	session.free()


func test_title_screen_scene() -> void:
	print("\n--- Testando Cena de Título Animada (title_screen.tscn) ---")
	var scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	assert_test(scene != null, "Cena title_screen.tscn carregada com sucesso")

	var instance: Node = scene.instantiate()
	assert_test(instance is Control, "TitleScreen é um nó Control")

	var bg_img: TextureRect = instance.get_node_or_null("%BackgroundImage") as TextureRect
	assert_test(bg_img != null, "BackgroundImage (TextureRect) existe na tela de título")
	if bg_img != null:
		assert_test(bg_img.texture != null, "BackgroundImage possui textura oficial (main.webp)")

	var touch_btn: Button = instance.get_node_or_null("%TouchButton") as Button
	assert_test(touch_btn != null, "Botão de toque mobile/desktop existe")

	instance.free()


func test_main_menu_scene() -> void:
	print("\n--- Testando Cena do Menu Principal (main_menu.tscn) ---")
	var scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	assert_test(scene != null, "Cena main_menu.tscn carregada com sucesso")

	var instance: Node = scene.instantiate()
	assert_test(instance is Control, "MainMenu é um nó Control")

	# BackgroundSlot
	var bg_slot: TextureRect = instance.get_node_or_null("%BackgroundSlot") as TextureRect
	assert_test(bg_slot != null, "BackgroundSlot existe na cena")
	if bg_slot != null:
		assert_test(bg_slot.texture != null, "BackgroundSlot possui textura oficial (menu.jpg)")
		assert_test(bg_slot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "BackgroundSlot não intercepta eventos do mouse")

	# AspectWrapper 16:9 Responsivo
	var aspect_wrap: AspectRatioContainer = instance.get_node_or_null("%AspectWrapper") as AspectRatioContainer
	assert_test(aspect_wrap != null, "AspectWrapper existe na cena do menu")
	if aspect_wrap != null:
		assert_test(is_equal_approx(aspect_wrap.ratio, 1.777778), "AspectWrapper utiliza proporção widescreen 16:9 (1.777778)")

	# Seletor Dinâmico Overlay (Camada 2 / 3)
	var overlay: Control = instance.get_node_or_null("%SelectorOverlay") as Control
	assert_test(overlay != null, "SelectorOverlay existe na cena")
	var l_chev: TextureRect = instance.get_node_or_null("%LeftChevron") as TextureRect
	assert_test(l_chev != null and l_chev.texture != null, "LeftChevron existe com textura atribuída")
	var r_chev: TextureRect = instance.get_node_or_null("%RightChevron") as TextureRect
	assert_test(r_chev != null and r_chev.texture != null, "RightChevron existe com textura atribuída")
	var brush_hl: TextureRect = instance.get_node_or_null("%BrushHighlight") as TextureRect
	assert_test(brush_hl != null and brush_hl.texture != null, "BrushHighlight existe com textura atribuída")

	# Botões
	var btn_new: Button = instance.get_node_or_null("%BtnNewGame") as Button
	assert_test(btn_new != null and not btn_new.disabled, "Botão Novo Jogo existe e está HABILITADO")

	var btn_cont: Button = instance.get_node_or_null("%BtnContinue") as Button
	assert_test(btn_cont != null and not btn_cont.disabled, "Botão Continuar existe e está HABILITADO")

	var btn_char: Button = instance.get_node_or_null("%BtnCharSelect") as Button
	assert_test(btn_char != null and btn_char.disabled, "Botão Seleção de Personagens existe e está DESABILITADO no menu")

	instance.free()


func test_credits_scene() -> void:
	print("\n--- Testando Cena de Créditos (credits.tscn) ---")
	var scene: PackedScene = load("res://scenes/ui/credits.tscn")
	assert_test(scene != null, "Cena credits.tscn carregada com sucesso")

	var instance: Node = scene.instantiate()
	var btn_back: Button = instance.get_node_or_null("%BtnBack") as Button
	assert_test(btn_back != null, "Botão Voltar existe na cena de créditos")
	instance.free()


func test_character_select_scene() -> void:
	print("\n--- Testando Cena de Seleção de Personagens (character_select.tscn) ---")
	var scene: PackedScene = load("res://scenes/ui/character_select.tscn")
	assert_test(scene != null, "Cena character_select.tscn carregada com sucesso")

	var instance: Node = scene.instantiate()
	var grid: GridContainer = instance.get_node_or_null("%GridCharacters") as GridContainer
	assert_test(grid != null, "GridContainer de personagens existe")

	if grid != null:
		var expected_chars: Array[String] = ["guilherme", "alessandro", "andre", "fernando", "gabriel", "juliana"]
		var found_all: bool = true
		for c_id in expected_chars:
			if grid.get_node_or_null("Card_" + c_id) == null:
				found_all = false
				break
		assert_test(found_all, "Exatamente os 6 cartões de personagens estão presentes no layout")

		# Verifica prévia de Guilherme com arquivo real
		var guilherme_card = grid.get_node_or_null("Card_guilherme")
		if guilherme_card != null:
			var img_node: TextureRect = guilherme_card.get_node_or_null("VBox/PreviewContainer/PreviewImg") as TextureRect
			assert_test(img_node != null and img_node.texture != null, "Card de Guilherme possui TextureRect com textura atribuída")
			if img_node != null and img_node.texture != null:
				assert_test(img_node.texture.resource_path == "res://assets/sprites/characters/guilherme/idle.png", "Card de Guilherme utiliza res://assets/sprites/characters/guilherme/idle.png real")

	var btn_confirm: Button = instance.get_node_or_null("%BtnConfirm") as Button
	assert_test(btn_confirm != null, "Botão Escolher Personagem existe")

	var btn_back: Button = instance.get_node_or_null("%BtnBack") as Button
	assert_test(btn_back != null, "Botão Voltar existe")

	instance.free()


func test_skin_select_scene() -> void:
	print("\n--- Testando Cena de Seleção de Skins (skin_select.tscn) ---")
	var scene: PackedScene = load("res://scenes/ui/skin_select.tscn")
	assert_test(scene != null, "Cena skin_select.tscn carregada com sucesso")

	var instance: Node = scene.instantiate()
	var card_palm: Button = instance.get_node_or_null("%Card_palmeirense") as Button
	assert_test(card_palm != null, "Card da skin Palmeirense existe")

	var card_pel: Button = instance.get_node_or_null("%Card_pelado") as Button
	assert_test(card_pel != null, "Card da skin Pelado existe")

	var btn_confirm: Button = instance.get_node_or_null("%BtnConfirm") as Button
	assert_test(btn_confirm != null, "Botão Confirmar Skin existe")

	var btn_back: Button = instance.get_node_or_null("%BtnBack") as Button
	assert_test(btn_back != null, "Botão Voltar aos Heróis existe")

	instance.free()


func test_difficulty_select_scene() -> void:
	print("\n--- Testando Cena de Seleção de Dificuldade (difficulty_select.tscn) ---")
	var scene: PackedScene = load("res://scenes/ui/difficulty_select.tscn")
	assert_test(scene != null, "Cena difficulty_select.tscn carregada com sucesso")

	var instance: Node = scene.instantiate()
	var card_norm: Button = instance.get_node_or_null("%Card_normal") as Button
	assert_test(card_norm != null, "Opção de Dificuldade Normal existe")

	var card_dif: Button = instance.get_node_or_null("%Card_dificil") as Button
	assert_test(card_dif != null, "Opção de Dificuldade Difícil existe")

	var btn_start: Button = instance.get_node_or_null("%BtnStartGame") as Button
	assert_test(btn_start != null, "Botão Iniciar Fase 1 existe")

	var btn_back: Button = instance.get_node_or_null("%BtnBack") as Button
	assert_test(btn_back != null, "Botão Voltar às Skins existe")

	instance.free()
