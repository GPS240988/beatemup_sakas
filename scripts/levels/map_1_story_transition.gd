extends "res://scripts/levels/base_level.gd"

## Intercepta somente a passagem do primeiro mapa da Fase 1 para map_2.
## A lógica original de BaseLevel continua salvando a progressão e limpando
## reforços pendentes; apenas o destino imediato é substituído pela cena narrativa.

const MAP_2_SCENE_PATH: String = "res://scenes/levels/map_2.tscn"
const STORY_INTERLUDE_SCENE_PATH: String = "res://scenes/story/story_intro_fase1_2.tscn"


func _advance_to_next_map() -> void:
	var should_show_interlude: bool = (
		map_group == "fase1"
		and map_index == 1
		and next_map_scene_path == MAP_2_SCENE_PATH
	)

	if not should_show_interlude:
		super._advance_to_next_map()
		return

	if not ResourceLoader.exists(STORY_INTERLUDE_SCENE_PATH):
		push_warning(
			"Cena story_intro_fase1_2.tscn não encontrada. "
			+ "A transição seguirá diretamente para map_2.tscn."
		)
		super._advance_to_next_map()
		return

	# O método original salva vida, especial e fichas antes de trocar a cena.
	# A substituição temporária do destino mantém esse comportamento intacto.
	var original_next_scene: String = next_map_scene_path
	next_map_scene_path = STORY_INTERLUDE_SCENE_PATH
	super._advance_to_next_map()
	next_map_scene_path = original_next_scene
