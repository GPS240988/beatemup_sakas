extends "res://scripts/levels/mobile_base_level.gd"

## Intercepta a passagem do segundo mapa da Fase 1 (map_2) para map_3.
## Exibe a cena cinematográfica story_intro_fase1_3.tscn (diálogo com vídeos de André e Juliana)
## antes de carregar map_3.tscn (fase 1-3: Rua do Beco / Bêbados).

const MAP_3_SCENE_PATH: String = "res://scenes/levels/map_3.tscn"
const STORY_INTERLUDE_SCENE_PATH: String = "res://scenes/story/story_intro_fase1_3.tscn"


func _advance_to_next_map() -> void:
	var should_show_interlude: bool = (
		map_group == "fase1"
		and map_index == 2
		and next_map_scene_path == MAP_3_SCENE_PATH
	)

	if not should_show_interlude:
		super._advance_to_next_map()
		return

	if not ResourceLoader.exists(STORY_INTERLUDE_SCENE_PATH):
		push_warning(
			"Cena story_intro_fase1_3.tscn não encontrada. "
			+ "A transição seguirá diretamente para map_3.tscn."
		)
		super._advance_to_next_map()
		return

	# O método original salva vida, especial e fichas antes de trocar a cena.
	# A substituição temporária do destino mantém esse comportamento intacto.
	var original_next_scene: String = next_map_scene_path
	next_map_scene_path = STORY_INTERLUDE_SCENE_PATH
	super._advance_to_next_map()
	next_map_scene_path = original_next_scene

