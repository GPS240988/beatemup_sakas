class_name StoryIntroFase1_4
extends Control

## Apresenta a introdução cinematográfica do Chefe Alessandro para a Fase 1-4 (O Beco Final):
## 1. Vídeo do Alessandro ('video_fase1_4_alessandro.ogv') com áudio estéreo Vorbis integrado.
## 2. Enquadramento no palco superior (16:9) e StandardDialogueBox na área inferior.
## 3. Diálogo de confronto do Chefe Alessandro com efeito typewriter e avanço por toque/tecla.
## 4. Transição fluida (fade out) para map_4.tscn ao terminar ou pular.

const MAP_4_SCENE_PATH: String = "res://scenes/levels/map_4.tscn"
const VIDEO_ALESSANDRO_PATH: String = "res://assets/videos/stage1/video_fase1_4_alessandro.ogv"
const PORTRAIT_ALESSANDRO_PATH: String = "res://assets/sprites/characters/chefes/alessandro/sprite-frame-caminhar-1.webp"

const TEXT_ALESSANDRO: String = "Vocês acharam que podiam invadir a locadora e sair impunes? Daqui ninguém passa!"

const StandardDialogueBoxClass = preload("res://scripts/ui/standard_dialogue_box.gd")
const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")

@export_range(0.1, 2.0, 0.05) var fade_duration: float = 0.55

var _fade_overlay: ColorRect
var _video_stage: MarginContainer
var _video_wrapper: AspectRatioContainer
var _video_player: VideoStreamPlayer
var _dialogue_ui: Dictionary = {}

var _is_typing: bool = false
var _typewriter_tween: Tween
var _prompt_tween: Tween
var _transition_started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_scene()
	call_deferred("_start_presentation")


func _is_mobile_runtime() -> bool:
	return MobileScreenAction.is_mobile_runtime()


func _build_scene() -> void:
	# Fundo preto arcade sólido
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.008, 0.010, 0.018, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Palco Superior: Reserva até 68% da tela para o vídeo em 16:9
	_video_stage = MarginContainer.new()
	_video_stage.name = "VideoStage"
	_video_stage.anchor_left = 0.0
	_video_stage.anchor_top = 0.0
	_video_stage.anchor_right = 1.0
	_video_stage.anchor_bottom = 0.68 if _is_mobile_runtime() else 0.69
	_video_stage.offset_left = 8.0
	_video_stage.offset_top = 8.0
	_video_stage.offset_right = -8.0
	_video_stage.offset_bottom = -4.0
	_video_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_video_stage)

	_video_wrapper = AspectRatioContainer.new()
	_video_wrapper.name = "VideoWrapper"
	_video_wrapper.ratio = 16.0 / 9.0
	_video_wrapper.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_video_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video_stage.add_child(_video_wrapper)

	_video_player = VideoStreamPlayer.new()
	_video_player.name = "VideoStreamPlayer"
	_video_player.expand = true
	_video_player.bus = &"Master"
	_video_player.loop = false
	_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video_player.finished.connect(_on_video_finished)
	_video_wrapper.add_child(_video_player)

	# Interface Oficial de Diálogo (StandardDialogueBox) na área inferior
	_dialogue_ui = StandardDialogueBoxClass.build_dialogue_ui(self, _is_mobile_runtime())
	if not _dialogue_ui.is_empty() and _dialogue_ui.has("dialogue_area"):
		var dialogue_area: Control = _dialogue_ui["dialogue_area"] as Control
		if dialogue_area != null:
			dialogue_area.visible = false

	# Overlay para Fades e Transições
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color.BLACK
	_fade_overlay.modulate.a = 1.0
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)


func _start_presentation() -> void:
	if _fade_overlay == null:
		return

	# Pausa a BGM ambiente para destacar o áudio/vozes do vídeo de Alessandro
	var session = get_node_or_null("/root/GameSession")
	if session != null and session.has_method("stop_bgm"):
		session.stop_bgm()

	var fade_in := create_tween()
	fade_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var fade_in_tweener: PropertyTweener = fade_in.tween_property(
		_fade_overlay, "modulate:a", 0.0, fade_duration
	)
	fade_in_tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished

	if not is_inside_tree():
		return

	_play_video(VIDEO_ALESSANDRO_PATH)
	_show_dialogue("ALESSANDRO", TEXT_ALESSANDRO, PORTRAIT_ALESSANDRO_PATH)


func _play_video(video_path: String) -> void:
	if _video_player == null:
		return

	if ResourceLoader.exists(video_path):
		var stream: VideoStream = ResourceLoader.load(video_path) as VideoStream
		if stream != null:
			_video_player.stream = stream
			_video_player.play()
		else:
			push_warning("[StoryIntroFase1_4] Falha ao instanciar stream de vídeo: " + video_path)
	else:
		push_warning("[StoryIntroFase1_4] Recurso de vídeo não encontrado: " + video_path)


func _show_dialogue(speaker: String, text: String, portrait_path: String) -> void:
	if _dialogue_ui.is_empty():
		return

	var dialogue_area: Control = _dialogue_ui.get("dialogue_area") as Control
	var speaker_label: Label = _dialogue_ui.get("speaker_label") as Label
	var dialogue_label: Label = _dialogue_ui.get("dialogue_label") as Label
	var portrait: TextureRect = _dialogue_ui.get("portrait") as TextureRect
	var prompt_label: Label = _dialogue_ui.get("prompt_label") as Label

	if dialogue_area != null:
		dialogue_area.visible = true

	if speaker_label != null:
		speaker_label.text = speaker

	if portrait != null and ResourceLoader.exists(portrait_path):
		var p_tex: Texture2D = ResourceLoader.load(portrait_path) as Texture2D
		if p_tex != null:
			portrait.texture = p_tex

	if prompt_label != null:
		prompt_label.visible = false
		prompt_label.text = "►"

	if dialogue_label != null:
		dialogue_label.text = text
		dialogue_label.visible_characters = 0
		_is_typing = true

		if _typewriter_tween != null and _typewriter_tween.is_valid():
			_typewriter_tween.kill()

		var duration: float = maxf(0.5, float(text.length()) / StandardDialogueBoxClass.TYPEWRITER_SPEED_CPS)
		_typewriter_tween = create_tween()
		_typewriter_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_typewriter_tween.tween_property(dialogue_label, "visible_characters", text.length(), duration)
		_typewriter_tween.finished.connect(func():
			_is_typing = false
			_show_prompt()
		)


func _show_prompt() -> void:
	var prompt_label: Label = _dialogue_ui.get("prompt_label") as Label
	if prompt_label != null and not _transition_started:
		prompt_label.visible = true
		prompt_label.modulate.a = 1.0
		if _prompt_tween != null and _prompt_tween.is_valid():
			_prompt_tween.kill()
		_prompt_tween = create_tween().set_loops()
		_prompt_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_prompt_tween.tween_property(prompt_label, "modulate:a", 0.35, 0.45).set_trans(Tween.TRANS_SINE)
		_prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)


func _skip_or_advance() -> void:
	if _transition_started:
		return

	var dialogue_label: Label = _dialogue_ui.get("dialogue_label") as Label
	if _is_typing and dialogue_label != null:
		if _typewriter_tween != null and _typewriter_tween.is_valid():
			_typewriter_tween.kill()
		dialogue_label.visible_characters = dialogue_label.text.length()
		_is_typing = false
		_show_prompt()
		return

	_transition_to_map_4()


func _on_video_finished() -> void:
	if _is_typing:
		var dialogue_label: Label = _dialogue_ui.get("dialogue_label") as Label
		if dialogue_label != null:
			if _typewriter_tween != null and _typewriter_tween.is_valid():
				_typewriter_tween.kill()
			dialogue_label.visible_characters = dialogue_label.text.length()
			_is_typing = false
			_show_prompt()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_skip_or_advance()
	elif event is InputEventScreenTouch and event.pressed:
		_skip_or_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("attack") or event.is_action_pressed("jump"):
		_skip_or_advance()
	elif event.is_action_pressed("ui_cancel"):
		_transition_to_map_4()


func _transition_to_map_4() -> void:
	if _transition_started:
		return
	_transition_started = true

	var session = get_node_or_null("/root/GameSession")
	if session != null:
		session.set("has_seen_fase1_4_intro", true)

	if _video_player != null and _video_player.is_playing():
		_video_player.stop()

	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()

	Input.action_release("attack")
	Input.action_release("jump")
	Input.action_release("ui_accept")

	var fade_out := create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var fade_out_tweener: PropertyTweener = fade_out.tween_property(
		_fade_overlay, "modulate:a", 1.0, fade_duration
	)
	fade_out_tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished

	if not is_inside_tree():
		return

	if not ResourceLoader.exists(MAP_4_SCENE_PATH):
		push_error("Mapa de destino não encontrado: " + MAP_4_SCENE_PATH)
		_transition_started = false
		return

	var error: Error = get_tree().change_scene_to_file(MAP_4_SCENE_PATH)
	if error != OK:
		push_error("Falha ao solicitar carregamento de map_4.tscn. Código: %d" % error)
		_transition_started = false

