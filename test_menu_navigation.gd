extends SceneTree

func _init() -> void:
	print("\n--- TESTANDO NAVEGAÇÃO E DESTAQUE DINÂMICO DO MENU PRINCIPAL ---")
	var scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	if scene == null:
		print("FALHA: Não foi possível carregar main_menu.tscn")
		quit(1)
		return

	var menu = scene.instantiate()
	root.add_child(menu)

	# Simula tamanho de tela 1920x1080
	menu.size = Vector2(1920.0, 1080.0)
	var aspect_wrap = menu.get_node("%AspectWrapper") as AspectRatioContainer
	if aspect_wrap != null:
		aspect_wrap.size = Vector2(1920.0, 1080.0)

	# 1. Estado inicial
	assert(menu._current_index == 0, "Index inicial deve ser 0 (NOVO JOGO)")
	print("[PASS] Index inicial é 0 (NOVO JOGO)")

	# 2. Navegação para baixo (Down arrow / KEY_DOWN)
	for i in range(1, 6):
		menu._move_selection(1)
		assert(menu._current_index == i, "Ao avançar 1, index deve ser %d" % i)
		print("[PASS] Avançou para opção %d com sucesso" % i)

	# 3. Wrapping circular no final (5 -> 0)
	menu._move_selection(1)
	assert(menu._current_index == 0, "Wrapping circular para baixo: 5 -> 0")
	print("[PASS] Wrapping circular para baixo: 5 -> 0")

	# 4. Navegação para cima (Up arrow / KEY_UP)
	menu._move_selection(-1)
	assert(menu._current_index == 5, "Wrapping circular para cima: 0 -> 5")
	print("[PASS] Wrapping circular para cima: 0 -> 5")

	menu._move_selection(-1)
	assert(menu._current_index == 4, "Ao recuar 1, index deve ser 4")
	print("[PASS] Recuou para opção 4 com sucesso")

	# Retorna ao index 0
	menu._set_selected_index(0, false)
	assert(menu._current_index == 0, "Index resetado para 0")

	# 5. Validação das coordenadas do seletor para todos os 6 itens
	var brush = menu.get_node("%BrushHighlight") as TextureRect
	var l_chev = menu.get_node("%LeftChevron") as TextureRect
	var r_chev = menu.get_node("%RightChevron") as TextureRect

	assert(brush != null and l_chev != null and r_chev != null, "Nós visuais do seletor existem")

	for idx in range(6):
		menu._set_selected_index(idx, false)
		var cfg = menu.OPTION_CONFIGS[idx]
		var expected_cy = float(cfg["cy"])
		var expected_lx = float(cfg["lx"])
		var expected_rx = float(cfg["rx"])
		var expected_bx = float(cfg["bx"])
		var expected_bw = float(cfg["bw"])

		assert(abs(brush.position.x - expected_bx) < 1.0, "Brush X incorreto na opção %d" % idx)
		assert(abs(brush.size.x - expected_bw) < 1.0, "Brush largura incorreta na opção %d" % idx)
		assert(abs(l_chev.position.x - expected_lx) < 1.0, "LeftChevron X incorreto na opção %d" % idx)
		assert(abs(r_chev.position.x - expected_rx) < 1.0, "RightChevron X incorreto na opção %d" % idx)
		print("[PASS] Coordenadas milimétricas validadas para opção %d (cy: %.1f)" % [idx, expected_cy])

	# 6. Validação das opções de texto mobile
	assert(menu.MOBILE_LABELS.size() == 6, "MOBILE_LABELS deve ter 6 itens")
	assert(menu.MOBILE_LABELS[2] == "PERSONAGENS", "Opção 2 deve ser estritamente 'PERSONAGENS'")
	print("[PASS] MOBILE_LABELS tem 6 opções e a 3ª é estritamente 'PERSONAGENS'")

	print("\n==================================================")
	print("TODOS OS TESTES DE MENU PASSARAM COM SUCESSO!")
	print("==================================================")
	menu.queue_free()
	quit(0)

