class_name StoryStage2Intro
extends Control

## Abertura narrativa do Estágio 02 — ligação de Sérgio, manifestação da máquina
## e decisão do grupo antes da entrada direta na Fase 2-1.

const TARGET_LEVEL_SCENE: String = "res://scenes/levels/map_5.tscn"
const STORY_SEQUENCE_PATH: String = "res://resources/story/story_intro_stage2.tres"

@onready var narrative_director: NarrativeDirector = %NarrativeDirector

var _is_transitioning: bool = false


func _ready() -> void:
	if narrative_director == null:
		push_error("StoryStage2Intro: NarrativeDirector não foi encontrado.")
		return

	narrative_director.sequence_completed.connect(_on_intro_completed)
	narrative_director.sequence_skipped.connect(_on_intro_skipped)
	narrative_director.play_sequence_from_path(STORY_SEQUENCE_PATH)


func _on_intro_completed(_sequence_id: String) -> void:
	_advance_to_stage2()


func _on_intro_skipped(_sequence_id: String) -> void:
	_advance_to_stage2()


func _advance_to_stage2() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

	# Evita que o último comando usado na narrativa chegue ao primeiro frame do mapa.
	for action_name: String in [
		"move_left",
		"move_right",
		"move_up",
		"move_down",
		"attack",
		"attack_punch",
		"attack_aerial",
		"special",
		"jump",
		"defend",
		"ui_accept",
		"ui_cancel"
	]:
		if InputMap.has_action(action_name):
			Input.action_release(action_name)

	await get_tree().create_timer(0.08).timeout
	if not is_inside_tree():
		return

	var session = get_node_or_null("/root/GameSession")
	if session != null:
		session.set("has_seen_stage_2_transition", true)

	if not ResourceLoader.exists(TARGET_LEVEL_SCENE):
		_is_transitioning = false
		push_error("StoryStage2Intro: mapa de destino não encontrado: " + TARGET_LEVEL_SCENE)
		return

	var error: Error = get_tree().change_scene_to_file(TARGET_LEVEL_SCENE)
	if error != OK:
		_is_transitioning = false
		push_error("StoryStage2Intro: falha ao carregar a Fase 2-1. Código: %d" % error)
