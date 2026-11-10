# tests/test_arcade_map_menu.gd
extends SceneTree

## Teste Automatizado da Nova Interface do Mapa da Vila (Arcade Map Menu)
## Valida:
## 1. Carregamento da cena e nós fundamentais (%BtnBack, %BtnPlayStage, etc.)
## 2. Geração e propriedades dos 4 pontos de fase (01, B, 02, 03)
## 3. Seleção de fase e atualização de dados no card do rodapé
## 4. Desbloqueio inicial da Fase 01 e do Bônus 1 (GARAGEM)
## 5. Roteamento: 01 -> map_1.tscn / loading_screen.tscn; B -> bonus_garage.tscn
## 6. Comportamento do botão Voltar (%BtnBack)

const MAP_MENU_SCENE_PATH: String = "res://scenes/ui/map_menu.tscn"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n========================================================")
	print(" INICIANDO TESTE: ARCADE MAP MENU (SELEÇÃO DE FASES)")
	print("========================================================\n")

	_run_tests()


func _run_tests() -> void:
	var packed_scene = ResourceLoader.load(MAP_MENU_SCENE_PATH) as PackedScene
	_assert(packed_scene != null, "A cena map_menu.tscn deve ser carregada com sucesso")
	if packed_scene == null:
		_finish_test()
		return

	var map_menu = packed_scene.instantiate() as Control
	root.add_child(map_menu)
	await process_frame

	# 1. Nós essenciais
	var btn_back = map_menu.get_node_or_null("%BtnBack") as Button
	_assert(btn_back != null, "Botão %BtnBack deve existir no TopBar")

	var btn_play_stage = map_menu.get_node_or_null("%BtnPlayStage") as Control
	_assert(btn_play_stage != null, "Botão %BtnPlayStage deve existir no Rodapé")

	var stage_number_lbl = map_menu.get_node_or_null("%StageNumberLabel") as Label
	_assert(stage_number_lbl != null, "Label %StageNumberLabel deve existir no SelectionCard")

	var stage_title_lbl = map_menu.get_node_or_null("%StageTitleLabel") as Label
	_assert(stage_title_lbl != null, "Label %StageTitleLabel deve existir no SelectionCard")

	var map_status_lbl = map_menu.get_node_or_null("%MapStatusLabel") as Label
	_assert(map_status_lbl != null, "Label %MapStatusLabel deve existir no rodapé")

	var hotspots_container = map_menu.get_node_or_null("%HotspotsContainer") as Control
	_assert(hotspots_container != null, "Container %HotspotsContainer deve existir")

	var bg_texture = map_menu.get_node_or_null("%BackgroundTexture") as TextureRect
	_assert(bg_texture != null, "TextureRect %BackgroundTexture deve existir")
	if bg_texture != null and bg_texture.texture != null:
		var tex_path = bg_texture.texture.resource_path
		_assert("sakas-map.webp" in tex_path or "Mapa.webp" in tex_path, "Textura do mapa deve ser sakas-map.webp ou Mapa.webp: %s" % tex_path)

	# 2. Configuração inicial
	_assert(map_menu.get("_selected_index") == 0, "A fase inicialmente selecionada deve ser o índice 0 (Fase 1)")
	if stage_number_lbl != null:
		_assert(stage_number_lbl.text == "01", "Número da fase inicial deve ser '01'")
	if stage_title_lbl != null:
		_assert(stage_title_lbl.text == "O REENCONTRO", "Título da fase inicial deve ser 'O REENCONTRO'")

	# 3. Validação dos marcadores gerados
	var hotspot_nodes: Array = map_menu.get("_hotspot_nodes")
	_assert(hotspot_nodes.size() == 4, "Devem existir 4 marcadores de fase no mapa (encontrados %d)" % hotspot_nodes.size())

	# 4. Desbloqueio inicial
	_assert(map_menu.is_stage_unlocked(0) == true, "Fase 01 deve estar desbloqueada inicialmente")
	_assert(map_menu.is_stage_unlocked(1) == true, "Fase B (BÔNUS / GARAGEM) deve estar desbloqueada inicialmente")
	_assert(map_menu.is_stage_unlocked(2) == false, "Fase 02 (HAPPEN) deve estar bloqueada no mapa")
	_assert(map_menu.is_stage_unlocked(3) == false, "Fase 03 (METRÔ) deve estar bloqueada no mapa")

	# 5. Seleção da Fase Bônus (índice 1)
	map_menu._select_stage(1, false)
	_assert(map_menu.get("_selected_index") == 1, "Índice selecionado deve ser 1 após _select_stage(1)")
	if stage_number_lbl != null:
		_assert(stage_number_lbl.text == "B", "Número da fase deve ser 'B' após selecionar bônus")
	if stage_title_lbl != null:
		_assert(stage_title_lbl.text == "GARAGEM", "Título da fase deve ser 'GARAGEM' após selecionar bônus")

	# 6. Seleção da Fase 1 novamente (índice 0)
	map_menu._select_stage(0, false)
	_assert(map_menu.get("_selected_index") == 0, "Índice selecionado deve retornar a 0")
	if stage_number_lbl != null:
		_assert(stage_number_lbl.text == "01", "Número da fase deve retornar a '01'")
	if stage_title_lbl != null:
		_assert(stage_title_lbl.text == "O REENCONTRO", "Título da fase deve retornar a 'O REENCONTRO'")

	# 6.1. Seleção da Fase 2 (índice 2) — deve estar bloqueada
	map_menu._select_stage(2, false)
	_assert(map_menu.get("_selected_index") == 2, "Índice selecionado deve ser 2 após _select_stage(2)")
	_assert(map_menu.is_stage_unlocked(2) == false, "Estágio 2 selecionado deve reportar is_stage_unlocked == false")
	if btn_play_stage != null:
		_assert(btn_play_stage.get("disabled") == true, "Botão JOGAR FASE deve estar desabilitado para o Estágio 2")
	if map_status_lbl != null:
		_assert("BLOQUEADA" in map_status_lbl.text, "Status label deve indicar que a fase está bloqueada")

	# Retorna para Fase 01
	map_menu._select_stage(0, false)

	# 7. Verificação dos alvos de roteamento das fases
	var configs: Array = map_menu.STAGE_CONFIGS
	_assert(configs.size() >= 2, "Devem existir pelo menos 2 configurações de estágio")
	if configs.size() >= 2:
		var cfg_01 = configs[0]
		_assert(cfg_01["id"] == "01", "ID do estágio 0 deve ser '01'")
		_assert("map_1.tscn" in str(cfg_01["scene"]), "Cena do estágio 01 deve ser map_1.tscn")

		var cfg_b = configs[1]
		_assert(cfg_b["id"] == "B", "ID do estágio 1 deve ser 'B'")
		_assert("bonus_garage.tscn" in str(cfg_b["scene"]), "Cena do estágio B deve ser bonus_garage.tscn")

	# 8. Validação do botão voltar
	_assert(btn_back.has_signal("pressed"), "BtnBack deve possuir sinal 'pressed'")

	# 9. Limpeza e encerramento
	map_menu.queue_free()
	_finish_test()


func _finish_test() -> void:
	print("\n========================================================")
	print(" RESULTADO: %d passaram, %d falharam" % [passed, failed])
	print("========================================================\n")
	quit(0 if failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % message)
	else:
		failed += 1
		printerr("  [FALHA] %s" % message)
