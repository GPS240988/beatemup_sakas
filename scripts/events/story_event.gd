class_name StoryEvent
extends Resource

## Recurso declarativo para definição de evento narrativo / cutscene cinemática.
## Suporta imagem, textos curtos por bloco, orador, temporização, efeitos de transição,
## zoom sutil em pixel art e efeitos de glitch e áudio.
## Em estrita conformidade com GAME_RULES.md.

@export var id: String = ""
@export var image_path: String = ""
@export var texts: Array[String] = []
@export var speaker: String = ""
@export var duration_per_text: float = 2.5
@export var entry_effect: String = "fade_in" # "fade_in", "slow_zoom", "crossfade", "glitch", "none"
@export var exit_effect: String = "fade_out" # "fade_out", "crossfade", "glitch", "none"
@export var pause_after: float = 0.4
@export var zoom_start: float = 1.0
@export var zoom_end: float = 1.0
@export var glitch_frames: int = 0
@export var sound_effect_name: String = ""


static func create(
	p_id: String,
	p_image_path: String,
	p_texts: Array,
	p_speaker: String = "",
	p_duration: float = 2.5,
	p_entry: String = "fade_in",
	p_exit: String = "fade_out",
	p_pause: float = 0.4,
	p_zoom_start: float = 1.0,
	p_zoom_end: float = 1.0,
	p_glitch: int = 0,
	p_sound: String = ""
) -> Resource:
	var ev: Resource = (load("res://scripts/events/story_event.gd") as GDScript).new()
	var arr: Array[String] = []
	for t in p_texts:
		arr.append(str(t))
	ev.set("id", p_id)
	ev.set("image_path", p_image_path)
	ev.set("texts", arr)
	ev.set("speaker", p_speaker)
	ev.set("duration_per_text", p_duration)
	ev.set("entry_effect", p_entry)
	ev.set("exit_effect", p_exit)
	ev.set("pause_after", p_pause)
	ev.set("zoom_start", p_zoom_start)
	ev.set("zoom_end", p_zoom_end)
	ev.set("glitch_frames", p_glitch)
	ev.set("sound_effect_name", p_sound)
	return ev
