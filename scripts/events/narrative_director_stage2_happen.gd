extends "res://scripts/events/narrative_director_stage2.gd"

## Diretor de diálogo da entrada da Fase 2-1; acrescenta retrato do Alessandro.

const ALESSANDRO_PORTRAIT: String = "res://assets/ui/hud/portraits/portrait_alessandro.png"


func _resolve_speaker_portrait(speaker_name: String, ev: Resource) -> Texture2D:
	if speaker_name.strip_edges().to_upper() == "ALESSANDRO":
		if ResourceLoader.exists(ALESSANDRO_PORTRAIT):
			return load(ALESSANDRO_PORTRAIT) as Texture2D
		push_warning("NarrativeDirectorStage2Happen: retrato de Alessandro não encontrado.")
		return null
	return super._resolve_speaker_portrait(speaker_name, ev)
