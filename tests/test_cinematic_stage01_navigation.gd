extends SceneTree

## Suíte de Testes Automatizados Headless: Navegação Cinematográfica do Stage 01
## Valida:
## 1. Integridade estrutural do MapContainer (pan/zoom) e UILayer (HUD fixa)
## 2. Nível A (Overview): exibe apenas Estágio 01, Bônus (arte distinta) e Estágio 02 (inabilitado)
## 3. Nível B: expansão via zoom para os 4 mapas (1-1, 1-2, 1-3, 1-4)
## 4. Retorno ao Nível A via zoom out ocultando novamente os sub-mapas 1-2, 1-3, 1-4
## 5. Eliminação da seta duplicada e normalização da seta única piscante (arcade blink)
## 6. Clamping matemático estrito aos limites de mapa_base.webp (zero bordas pretas)
## 7. Interrupção suave e redirecionamento de câmera (retarget)
## 8. Extração e exibição fiel dos textos narrativos canônicos no painel fixo
## 9. Navegação direcional sequencial (1-1 <-> 1-2 <-> 1-3 <-> 1-4)

const MAP_MENU_SCENE_PATH: String = "res://scenes/ui/map_menu.tscn"

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
	print("INICIANDO TESTES: NAVEGAÇÃO CINEMATOGRÁFICA DO STAGE 01 (GODOT 4.x)")
	print("========================================================================")

	var session = root.get_node_or_null("GameSession")
	if session == null:
		var session_script = load("res://scripts/core/game_session.gd")
		if session_script != null:
			session = session_script.new()
			session.name = "GameSession"
			root.add_child(session)
	if session != null and session.has_method("unlock_bonus_stage"):
		session.unlock_bonus_stage()

	var packed_scene = ResourceLoader.load(MAP_MENU_SCENE_PATH) as PackedScene
	assert_test(packed_scene != null, "Cena map_menu.tscn carregada com sucesso")
	if packed_scene == null:
		_finish_test()
		return

	var map_menu = packed_scene.instantiate() as Control
	root.add_child(map_menu)
	await process_frame

	# 1. Estrutura do MapContainer e UILayer
	print("\n--- 1. Validação Estrutural dos Nós e Camadas ---")
	var map_container = map_menu.get_node_or_null("%MapContainer") as Control
	assert_test(map_container != null, "MapContainer existe e hospeda o cenário navegável")
	if map_container != null:
		assert_test(map_container.size.x >= 1920.0 and map_container.size.y >= 1080.0, "MapContainer possui dimensões canônicas 1920x1080")

	var bg_texture = map_menu.get_node_or_null("%BackgroundTexture") as TextureRect
	assert_test(bg_texture != null and bg_texture.get_parent() == map_container, "BackgroundTexture está encapsulado no MapContainer")

	var hotspots_container = map_menu.get_node_or_null("%HotspotsContainer") as Control
	assert_test(hotspots_container != null and hotspots_container.get_parent() == map_container, "HotspotsContainer está encapsulado no MapContainer")

	var moving_arrow = map_menu.get_node_or_null("%MovingArrow") as Node2D
	assert_test(moving_arrow != null and moving_arrow.get_parent() == map_container, "MovingArrow está encapsulada no MapContainer")

	var narrative_panel = map_menu.get_node_or_null("%NarrativePanel") as Control
	assert_test(narrative_panel != null, "NarrativePanel fixo existe na UILayer")

	var narrative_badge = map_menu.get_node_or_null("%NarrativeBadge") as Label
	var narrative_title = map_menu.get_node_or_null("%NarrativeTitle") as Label
	var narrative_synopsis = map_menu.get_node_or_null("%NarrativeSynopsis") as Label
	var narrative_objective = map_menu.get_node_or_null("%NarrativeObjective") as Label
	assert_test(narrative_badge != null and narrative_title != null and narrative_synopsis != null and narrative_objective != null, "Campos narrativos existem no NarrativePanel")

	# 2. Validação do Nível A (Overview) Inicial
	print("\n--- 2. Validação do Nível A (Overview) ---")
	assert_test(map_menu.get("_nav_state") == map_menu.NavState.OVERVIEW, "Menu inicia no Nível A (NavState.OVERVIEW)")
	var hotspots: Array = map_menu.get("_hotspot_nodes")
	assert_test(hotspots.size() == 6, "Total de 6 hotspots configurados")

	# No Nível A, deve aparecer o Estágio 01 (hotspot 0), Bônus (hotspot 4) e Estágio 02 (hotspot 5, bloqueado)
	assert_test(hotspots[0].visible == true, "Nível A: Estágio 01 está visível")
	assert_test(hotspots[1].visible == false, "Nível A: Fase 1-2 está oculta no overview")
	assert_test(hotspots[2].visible == false, "Nível A: Fase 1-3 está oculta no overview")
	assert_test(hotspots[3].visible == false, "Nível A: Fase 1-4 está oculta no overview")
	assert_test(hotspots[4].visible == true, "Nível A: Fase Bônus está visível")
	assert_test(hotspots[5].visible == true, "Nível A: Estágio 02 está visível mas inabilitado")
	assert_test(map_menu.is_stage_unlocked(5) == false, "Nível A: Estágio 02 reporta is_stage_unlocked == false (inabilitado)")

	# Arte Diferenciada para a Fase Bônus
	var bonus_node = hotspots[4]
	assert_test(bonus_node.get("is_bonus") == true, "Hotspot da Garagem está configurado com is_bonus == true")
	var bonus_tag = bonus_node.get_node_or_null("%TagLabel") as Label
	var bonus_medallion = bonus_node.get_node_or_null("%MedallionLabel") as Label
	assert_test(bonus_tag != null and "BÔNUS" in bonus_tag.text, "Tag da Garagem possui identificador exclusivo de Bônus: %s" % (bonus_tag.text if bonus_tag else ""))
	assert_test(bonus_medallion != null and bonus_medallion.text == "★", "Medalhão da Garagem Bônus exibe ícone de estrela '★' exclusivo")

	# 3. Eliminação da Seta Duplicada e Seta Única Piscante
	print("\n--- 3. Validação de Seta Única Piscante (Sem Duplicação) ---")
	for i in range(hotspots.size()):
		var pt_arrow = hotspots[i].get_node_or_null("%ArrowLabel") as Label
		assert_test(pt_arrow == null or pt_arrow.visible == false, "Hotspot %d não exibe ArrowLabel interna (sem seta sobreposta)" % i)
	assert_test(moving_arrow.visible == true, "MovingArrow única do MapMenu está visível")
	assert_test(map_menu.get("_arrow_blink_tween") != null, "MovingArrow possui _arrow_blink_tween ativo para efeito piscante")

	# 4. Expansão via Zoom para o Nível B (Stage Navigation)
	print("\n--- 4. Validação da Expansão via Zoom para o Nível B ---")
	map_menu._enter_stage_01(0)
	assert_test(map_menu.get("_nav_state") == map_menu.NavState.STAGE_NAVIGATION, "Estado comutado para STAGE_NAVIGATION")
	assert_test(hotspots[0].visible == true, "Nível B: Fase 1-1 visível")
	assert_test(hotspots[1].visible == true, "Nível B: Fase 1-2 expandida e visível")
	assert_test(hotspots[2].visible == true, "Nível B: Fase 1-3 expandida e visível")
	assert_test(hotspots[3].visible == true, "Nível B: Fase 1-4 expandida e visível")

	# 5. Clamping Matemático de Bounding (Sem Bordas Pretas)
	print("\n--- 5. Validação Matemática de Clamping e Bounding ---")
	var base_zoom: float = map_menu.BASE_ZOOM
	var stage_zoom: float = map_menu.STAGE_ZOOM
	assert_test(is_equal_approx(base_zoom, 1280.0 / 1920.0), "BASE_ZOOM corresponde a 1280/1920 = 0.666667")
	assert_test(stage_zoom > base_zoom, "STAGE_ZOOM proporciona aproximação moderada (> BASE_ZOOM)")

	for i in range(map_menu.STAGE_CONFIGS.size()):
		var cfg = map_menu.STAGE_CONFIGS[i]
		var world_pos = Vector2(cfg["pos_ratio"].x * 1920.0, cfg["pos_ratio"].y * 1080.0)
		var clamped_pos: Vector2 = map_menu._calculate_camera_position(world_pos, stage_zoom)
		var min_x := 1280.0 - 1920.0 * stage_zoom
		var min_y := 720.0 - 1080.0 * stage_zoom
		assert_test(clamped_pos.x >= min_x - 0.01 and clamped_pos.x <= 0.01, "Posição X para fase %s está perfeitamente delimitada [min_x, 0]" % cfg["id"])
		assert_test(clamped_pos.y >= min_y - 0.01 and clamped_pos.y <= 0.01, "Posição Y para fase %s está perfeitamente delimitada [min_y, 0]" % cfg["id"])

	# 6. Interrupção Fluida e Suporte a Retarget
	print("\n--- 6. Validação do Mecanismo de Retarget de Câmera ---")
	map_menu._pan_camera_to(Vector2(-100, -50), stage_zoom, 0.4, true)
	assert_test(map_menu.get("_camera_tween") != null and (map_menu.get("_camera_tween") as Tween).is_valid(), "Tween de câmera ativo após pan")
	map_menu._pan_camera_to(Vector2(-200, -80), stage_zoom, 0.4, true)
	assert_test(map_menu.get("_camera_tween") != null and (map_menu.get("_camera_tween") as Tween).is_valid(), "Retarget bem-sucedido sem erros ou solavancos")

	# 7. Painel Narrativo Canônico
	print("\n--- 7. Validação dos Dados Narrativos Canônicos ---")
	map_menu._select_stage(0, false, false)
	assert_test("1-1" in narrative_badge.text or "01" in narrative_badge.text, "Badge da Fase 1-1")
	assert_test(narrative_title.text == "A ÚLTIMA FICHA", "Título da Fase 1-1 é 'A ÚLTIMA FICHA'")
	assert_test("sala secreta" in narrative_synopsis.text or "arruaceiros" in narrative_synopsis.text, "Sinopse da Fase 1-1 extraída fielmente do enredo")
	assert_test("emboscada" in narrative_objective.text or "locadora" in narrative_objective.text, "Objetivo da Fase 1-1 documentado com sucesso")

	map_menu._select_stage(1, false, false)
	assert_test(narrative_badge.text == "MISSÃO 1-2", "Badge da Fase 1-2 é 'MISSÃO 1-2'")
	assert_test(narrative_title.text == "INVASÃO NO FLIPERAMA", "Título da Fase 1-2 é 'INVASÃO NO FLIPERAMA'")

	map_menu._select_stage(2, false, false)
	assert_test(narrative_badge.text == "MISSÃO 1-3", "Badge da Fase 1-3 é 'MISSÃO 1-3'")
	assert_test(narrative_title.text == "EMBOSCADA NA TRAVESSA", "Título da Fase 1-3 é 'EMBOSCADA NA TRAVESSA'")

	map_menu._select_stage(3, false, false)
	assert_test(narrative_badge.text == "MISSÃO 1-4", "Badge da Fase 1-4 é 'MISSÃO 1-4'")
	assert_test(narrative_title.text == "O BECO FINAL & ALESSANDRO", "Título da Fase 1-4 é 'O BECO FINAL & ALESSANDRO'")

	map_menu._select_stage(4, false, false)
	assert_test(narrative_badge.text == "ESTÁGIO BÔNUS", "Badge da Garagem é 'ESTÁGIO BÔNUS'")
	assert_test(narrative_title.text == "DESTRUIÇÃO NA GARAGEM", "Título da Garagem é 'DESTRUIÇÃO NA GARAGEM'")

	map_menu._select_stage(5, false, false)
	assert_test(narrative_badge.text == "ESTÁGIO 02", "Badge do Estágio 02 é 'ESTÁGIO 02'")
	assert_test(narrative_title.text == "AVENIDA DOS ACONTECIMENTOS", "Título do Estágio 02 é 'AVENIDA DOS ACONTECIMENTOS'")

	# 8. Navegação Sequencial Interna no Stage 01
	print("\n--- 8. Validação da Navegação Direcional Sequencial ---")
	map_menu._enter_stage_01(0)
	assert_test(map_menu.get("_nav_state") == map_menu.NavState.STAGE_NAVIGATION, "Estado atual é STAGE_NAVIGATION")
	assert_test(map_menu.get("_selected_index") == 0, "Início no índice 0 (Fase 1-1)")

	map_menu._navigate_stages(1)
	assert_test(map_menu.get("_selected_index") == 1, "Avanço para índice 1 (Fase 1-2)")

	map_menu._navigate_stages(1)
	assert_test(map_menu.get("_selected_index") == 2, "Avanço para índice 2 (Fase 1-3)")

	map_menu._navigate_stages(1)
	assert_test(map_menu.get("_selected_index") == 3, "Avanço para índice 3 (Fase 1-4)")

	map_menu._navigate_stages(1)
	assert_test(map_menu.get("_selected_index") == 3, "Navegação respeita limite superior do Stage 01 (permanece em 3)")

	map_menu._navigate_stages(-1)
	assert_test(map_menu.get("_selected_index") == 2, "Recuo para índice 2 (Fase 1-3)")

	# 9. Retorno ao Nível A com Zoom Out e Ocultação das Fases 1-2..1-4
	print("\n--- 9. Validação do Retorno ao Nível A via Botão Voltar ---")
	map_menu._on_back_pressed()
	assert_test(map_menu.get("_nav_state") == map_menu.NavState.OVERVIEW, "Pressionar Voltar no Stage 01 retorna ao modo OVERVIEW (Nível A)")
	assert_test(hotspots[0].visible == true, "Retorno Nível A: Estágio 01 está visível")
	assert_test(hotspots[1].visible == false, "Retorno Nível A: Fase 1-2 voltou a ficar oculta")
	assert_test(hotspots[2].visible == false, "Retorno Nível A: Fase 1-3 voltou a ficar oculta")
	assert_test(hotspots[3].visible == false, "Retorno Nível A: Fase 1-4 voltou a ficar oculta")
	assert_test(hotspots[4].visible == true, "Retorno Nível A: Bônus continua visível com arte especial")
	assert_test(hotspots[5].visible == true, "Retorno Nível A: Estágio 02 permanece inabilitado")

	map_menu.queue_free()
	_finish_test()


func _finish_test() -> void:
	print("\n========================================================================")
	print("RESULTADO DOS TESTES CINEMÁTICOS: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("========================================================================")
	quit(0 if failed_tests == 0 else 1)
