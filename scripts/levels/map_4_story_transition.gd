extends "res://scripts/levels/mobile_base_level.gd"

## Controlador de Fase 1-4 (O Beco Final / Chefe Alessandro).
## Garante que o vídeo de introdução do Chefe Alessandro seja apresentado assim
## que a fase começar, mesmo se carregada diretamente.

const STORY_INTRO_FASE1_4_PATH: String = "res://scenes/story/story_intro_fase1_4.tscn"


func _ready() -> void:
	var session = get_node_or_null("/root/GameSession")
	var has_seen: bool = false
	if session != null:
		if "has_seen_fase1_4_intro" in session:
			has_seen = bool(session.has_seen_fase1_4_intro)
		elif session.get("has_seen_fase1_4_intro") != null:
			has_seen = bool(session.get("has_seen_fase1_4_intro"))

	if not has_seen:
		if session != null:
			if "has_seen_fase1_4_intro" in session:
				session.has_seen_fase1_4_intro = true
			else:
				session.set("has_seen_fase1_4_intro", true)
		if ResourceLoader.exists(STORY_INTRO_FASE1_4_PATH):
			get_tree().change_scene_to_file(STORY_INTRO_FASE1_4_PATH)
			return
	super._ready()
