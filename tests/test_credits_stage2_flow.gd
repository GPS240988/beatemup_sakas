extends SceneTree

const CREDITS_SCRIPT_PATH := "res://scripts/ui/credits.gd"
const CREDITS_SCENE_PATH := "res://scenes/ui/credits.tscn"
const MAP_TRANSITION_PATH := "res://scenes/ui/map_transition.tscn"
const STAGE2_INTRO_PATH := "res://scenes/story/story_stage2_intro.tscn"


func _initialize() -> void:
	var script_file := FileAccess.open(CREDITS_SCRIPT_PATH, FileAccess.READ)
	var scene_file := FileAccess.open(CREDITS_SCENE_PATH, FileAccess.READ)
	if script_file == null or scene_file == null:
		_fail("Não foi possível abrir os arquivos da tela de créditos.")
		return

	var script_text := script_file.get_as_text()
	var scene_text := scene_file.get_as_text()
	script_file.close()
	scene_file.close()

	_assert(script_text.contains("video_player.loop = false"), "O vídeo precisa tocar uma única vez.")
	_assert(script_text.contains("video_player.finished.connect(_on_video_finished"), "O fim do vídeo precisa disparar a transição.")
	_assert(script_text.contains("pending_map_transition_mode = 1"), "A transição precisa usar BONUS_TO_POINT2.")
	_assert(script_text.contains("pending_transition_target = STAGE2_INTRO_SCENE"), "O destino precisa ser a introdução do Estágio 02.")
	_assert(script_text.contains("change_scene_to_file(MAP_TRANSITION_SCENE)"), "A tela precisa abrir a transição do mapa.")
	_assert(scene_text.contains("VideoPlayer"), "A cena precisa manter o VideoStreamPlayer.")
	_assert(not scene_text.contains("BtnBack"), "A cena não pode conter botão de retorno.")
	_assert(not script_text.contains("_on_back_pressed"), "O script não pode manter ação de retorno ao menu.")
	_assert(ResourceLoader.exists(MAP_TRANSITION_PATH), "A cena de transição do mapa precisa existir no projeto.")
	_assert(ResourceLoader.exists(STAGE2_INTRO_PATH), "A cena da introdução do Estágio 02 precisa existir no projeto.")

	quit(0 if _errors == 0 else 1)


var _errors: int = 0


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_errors += 1
	push_error("[test_credits_stage2_flow] " + message)
