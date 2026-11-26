extends SceneTree

const MAP_MENU_SCENE_PATH: String = "res://scenes/ui/map_menu.tscn"
const GAME_SESSION_SCRIPT: String = "res://scripts/core/game_session.gd"
const MAP5_PATH: String = "res://scenes/levels/map_5.tscn"
const MAP6_PATH: String = "res://scenes/levels/map_6.tscn"
const MAP7_PATH: String = "res://scenes/levels/map_7.tscn"
const MAP8_PATH: String = "res://scenes/levels/map_8.tscn"

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var session = root.get_node_or_null("GameSession")
	if session == null:
		var session_script: Script = load(GAME_SESSION_SCRIPT) as Script
		if session_script != null:
			session = session_script.new()
			session.name = "GameSession"
			root.add_child(session)

	_assert(session != null, "GameSession está disponível")
	if session == null:
		_finish()
		return

	session.set_meta("map_entry_context", "continue")
	var packed_scene: PackedScene = load(MAP_MENU_SCENE_PATH) as PackedScene
	_assert(packed_scene != null, "map_menu.tscn carrega")
	if packed_scene == null:
		_finish()
		return

	var map_menu: Control = packed_scene.instantiate() as Control
	root.add_child(map_menu)
	await process_frame
	map_menu.set("_entry_context", "continue")

	_assert(map_menu.get("_hotspot_nodes").size() == 6, "Overview preserva os seis marcadores macro")
	_assert(map_menu.get("_stage2_hotspot_nodes").size() == 4, "Estágio 02 cria quatro marcadores internos")
	_assert(map_menu.is_stage_unlocked(5) == true, "HAPPEN fica liberado no contexto continue/deploy")

	var configs: Array = map_menu.STAGE2_MAP_CONFIGS
	_assert(configs.size() == 4, "Estágio 02 possui quatro localidades")
	if configs.size() == 4:
		_assert(configs[0]["id"] == "2-1" and configs[0]["scene"] == MAP5_PATH, "2-1 aponta para Rua da Vila Ema / Map 5")
		_assert(configs[1]["id"] == "2-2" and configs[1]["scene"] == MAP6_PATH, "2-2 aponta para Conversa com Pelé / Map 6")
		_assert(configs[2]["id"] == "2-3" and configs[2]["scene"] == MAP7_PATH, "2-3 aponta para Interior da HAPPEN / Map 7")
		_assert(configs[3]["id"] == "2-4" and configs[3]["scene"] == MAP8_PATH, "2-4 aponta para Toalete / Map 8")

	_assert(ResourceLoader.exists(MAP5_PATH), "Map 5 existe")
	_assert(ResourceLoader.exists(MAP6_PATH), "Map 6 existe")
	_assert(ResourceLoader.exists(MAP7_PATH), "Map 7 existe")
	_assert(ResourceLoader.exists(MAP8_PATH), "Map 8 existe no repositório")

	if OS.is_debug_build():
		map_menu.call("_enter_stage_02", 0)
		await process_frame
		_assert(map_menu.call("is_stage2_navigation_active"), "HAPPEN abre o Nível B do Estágio 02")

		var points: Array = map_menu.get("_stage2_hotspot_nodes")
		for i in range(points.size()):
			_assert(points[i].visible, "Ponto %s fica visível no Nível B" % str(configs[i]["id"]))

		_assert(map_menu.get_node("%StageNumberLabel").text == "2-1", "Foco inicial apresenta 2-1")
		_assert(map_menu.get_node("%StageTitleLabel").text == "RUA DA VILA EMA", "2-1 apresenta a Rua da Vila Ema")
		_assert(map_menu.call("is_stage2_map_playable", 0), "2-1 pode iniciar Map 5 em debug")

		map_menu.call("_select_stage2_map", 1, false, false)
		_assert(map_menu.get_node("%StageNumberLabel").text == "2-2", "Seleção apresenta 2-2")
		_assert(map_menu.get_node("%StageTitleLabel").text == "CONVERSA COM PELÉ", "2-2 apresenta a conversa com Pelé")
		_assert(map_menu.call("is_stage2_map_playable", 1), "2-2 pode iniciar Map 6 em debug")

		map_menu.call("_select_stage2_map", 2, false, false)
		_assert(map_menu.get_node("%StageNumberLabel").text == "2-3", "Seleção apresenta 2-3")
		_assert(map_menu.get_node("%StageTitleLabel").text == "INTERIOR DA HAPPEN", "2-3 apresenta o salão principal")
		_assert(map_menu.call("is_stage2_map_playable", 2), "2-3 pode iniciar Map 7 em debug")

		map_menu.call("_select_stage2_map", 3, false, false)
		_assert(map_menu.get_node("%StageNumberLabel").text == "2-4", "Seleção permite inspecionar 2-4")
		_assert(map_menu.call("is_stage2_map_playable", 3), "2-4 pode iniciar Map 8 em debug")
		_assert(not map_menu.get_node("%BtnPlayStage").get("disabled"), "Botão de início de 2-4 fica habilitado")

		map_menu.call("_on_back_pressed")
		await process_frame
		_assert(not map_menu.call("is_stage2_navigation_active"), "Voltar restaura o Overview")
		for point in points:
			_assert(not point.visible, "Pontos internos 2-x ficam ocultos no Overview")

	map_menu.queue_free()
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("[OK] ", message)
	else:
		failed += 1
		push_error("[FALHA] " + message)


func _finish() -> void:
	print("TESTE MAPAS DO ESTÁGIO 02: %d passaram, %d falharam" % [passed, failed])
	quit(0 if failed == 0 else 1)
