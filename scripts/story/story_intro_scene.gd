class_name StoryIntroScene
extends Control

## Cena dedicada para apresentação da Abertura Narrativa de Saka's: A Última Ficha.
## Transiciona automaticamente para a Fase 1 (scenes/levels/map_1.tscn) ao concluir ou pular.
## Em estrita conformidade com GAME_RULES.md.

const TARGET_LEVEL_SCENE: String = "res://scenes/levels/map_1.tscn"
const STORY_SEQUENCE_PATH: String = "res://resources/story/story_intro_map1.tres"

@onready var narrative_director: NarrativeDirector = %NarrativeDirector

var _is_transitioning: bool = false


func _ready() -> void:
	if narrative_director != null:
		narrative_director.sequence_completed.connect(_on_intro_completed)
		narrative_director.sequence_skipped.connect(_on_intro_skipped)
		narrative_director.play_sequence_from_path(STORY_SEQUENCE_PATH)


func _on_intro_completed(_seq_id: String) -> void:
	_advance_to_game()


func _on_intro_skipped(_seq_id: String) -> void:
	_advance_to_game()


func _advance_to_game() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	var session = get_node_or_null("/root/GameSession")
	if session != null and "has_played_intro" in session:
		session.has_played_intro = true

	if get_viewport() != null:
		get_viewport().set_input_as_handled()

	var err := get_tree().change_scene_to_file(TARGET_LEVEL_SCENE)
	if err != OK:
		_is_transitioning = false
		printerr("Erro ao carregar a Fase 1 a partir da introdução: ", err)
