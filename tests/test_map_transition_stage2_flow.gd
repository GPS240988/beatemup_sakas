extends SceneTree

const SCRIPT_PATH := "res://scripts/ui/map_transition_stage2.gd"
const SCENE_PATH := "res://scenes/ui/map_transition.tscn"
const POINT_SCENE_PATH := "res://scenes/ui/components/map_stage_point.tscn"
const INTRO_SCENE_PATH := "res://scenes/story/story_stage2_intro.tscn"
const MAP_MENU_SCRIPT_PATH := "res://scripts/ui/map_menu.gd"
const GAME_SESSION_SCRIPT_PATH := "res://scripts/core/game_session.gd"
const CREDITS_SCRIPT_PATH := "res://scripts/ui/credits.gd"

var _errors: int = 0


func _initialize() -> void:
	var script_file := FileAccess.open(SCRIPT_PATH, FileAccess.READ)
	var scene_file := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var map_menu_file := FileAccess.open(MAP_MENU_SCRIPT_PATH, FileAccess.READ)
	var game_session_file := FileAccess.open(GAME_SESSION_SCRIPT_PATH, FileAccess.READ)
	var credits_file := FileAccess.open(CREDITS_SCRIPT_PATH, FileAccess.READ)
	if script_file == null or scene_file == null or map_menu_file == null or game_session_file == null or credits_file == null:
		_fail("Não foi possível abrir o script ou a cena de transição especializada.")
		quit(1)
		return

	var script_text := script_file.get_as_text()
	var scene_text := scene_file.get_as_text()
	var map_menu_text := map_menu_file.get_as_text()
	var game_session_text := game_session_file.get_as_text()
	var credits_text := credits_file.get_as_text()
	script_file.close()
	scene_file.close()
	map_menu_file.close()
	game_session_file.close()
	credits_file.close()

	_assert(scene_text.contains("map_transition_stage2.gd"), "A cena deve usar o controlador especializado.")
	_assert(script_text.contains("MAP_MENU_SCRIPT.ROUTE_SEGMENTS"), "A transição deve reutilizar a rota oficial do MapMenu.")
	_assert(script_text.contains("MAP_MENU_SCRIPT.STAGE_CONFIGS"), "A transição deve reutilizar as coordenadas oficiais dos estágios.")
	_assert(script_text.contains("STAGE_ARROW_OFFSET"), "A seta deve usar o mesmo deslocamento superior do MapMenu.")
	_assert(not script_text.contains("OS.is_debug_build()"), "O desbloqueio do Estágio 02 está liberado também no deploy.")
	_assert(not map_menu_text.contains("if not OS.is_debug_build():"), "O MapMenu libera o Estágio 02 também em release/deploy.")
	_assert(credits_text.contains("STAGE2_INTRO_SCENE"), "Os créditos encaminham para a transição do Estágio 02.")
	_assert(script_text.contains("session.unlock_stage_2()"), "O desbloqueio deve usar o contrato do GameSession.")
	_assert(script_text.contains("MAP_STAGE_POINT_SCENE"), "Os marcadores devem reutilizar MapStagePoint.")
	_assert(ResourceLoader.exists(POINT_SCENE_PATH), "A cena MapStagePoint precisa existir no projeto-base.")
	_assert(ResourceLoader.exists(INTRO_SCENE_PATH), "A introdução do Estágio 02 precisa estar instalada.")

	quit(0 if _errors == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_errors += 1
	push_error("[test_map_transition_stage2_flow] " + message)
