class_name NarrativeDirector
extends CanvasLayer

## Diretor e Apresentador Narrativo Cinemático para Beat 'em Up 2.5D (Saka's: A Última Ficha).
## Implementa o Padrão Oficial de Apresentação Arcade:
## - Enquadramento seguro sem cortes ou distorção (STRETCH_KEEP_ASPECT_CENTERED com fundo ambiente).
## - Moldura oficial 9-patch em estética arcade dos anos 90 (#100D18 com contorno dourado #EAB308).
## - Tipografia arcade oficial (arcade_bold.ttf) para títulos, orador, diálogos, contador e prompts.
## - Avanço de falas estritamente manual: NENHUMA fala avança ou desaparece por temporizador automático.
## - Proteção contra avanços repetidos acidentais e isolamento de entrada contra sangramento no gameplay.
## - Transições cinematográficas com fade e crossfade sóbrios (~0.32s), glitch analógico e áudio procedural.
## - Suporte a Teclado (Espaço/Enter), Gamepad (A/ui_accept), Mouse e Toque Mobile nativo.
## Em estrita conformidade com Direcao_de_Arte.md e GAME_RULES.md.

signal sequence_started(sequence_id: String)
signal event_started(event_id: String, text_index: int)
signal event_completed(event_id: String)
signal sequence_completed(sequence_id: String)
signal sequence_skipped(sequence_id: String)

const StoryEventClass = preload("res://scripts/events/story_event.gd")
const StorySequenceClass = preload("res://scripts/events/story_sequence.gd")

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const DIALOG_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/hud/dialog_frame_9patch.png")
const SPEAKER_BADGE_TEXTURE: Texture2D = preload("res://assets/ui/hud/speaker_badge_9patch.png")

@export var default_sequence_path: String = "res://resources/story/story_intro_map1.tres"
@export var auto_start_on_ready: bool = false

var is_playing: bool = false
var current_sequence: Resource = null
var current_event_index: int = 0
var current_text_index: int = 0

var _is_transitioning: bool = false
var _active_tween: Tween = null
var _pulse_tween: Tween = null
var _zoom_tween: Tween = null

# Nós visuais internos
var _root_control: Control
var _dark_base: ColorRect
var _ambient_bg: TextureRect
var _art_stage: Control
var _image_rect: TextureRect
var _glitch_bars: Control
var _title_container: CenterContainer
var _title_header_label: Label
var _title_sub_label: Label
var _dialogue_area: MarginContainer
var _dialogue_frame: NinePatchRect
var _speaker_badge: NinePatchRect
var _speaker_label: Label
var _dialogue_label: Label
var _scene_counter_label: Label
var _prompt_label: Label
var _btn_mobile_advance: Button
var _btn_skip: Button
var _top_overlay: MarginContainer
var _fade_overlay: ColorRect
var _audio_player: AudioStreamPlayer

# Efeitos sonoros procedurais integrados
var _sfx_deep_hum: AudioStreamWAV
var _sfx_nostalgia: AudioStreamWAV
var _sfx_glitch: AudioStreamWAV
var _sfx_advance: AudioStreamWAV


func _init() -> void:
	layer = 120 # Acima do jogo e da HUD, abaixo de menus críticos de sistema


func _ready() -> void:
	add_to_group("narrative_director")
	if has_node("%RootControl"):
		_bind_scene_nodes()
	elif _root_control == null:
		_build_ui_nodes()
	_generate_sound_effects()

	if auto_start_on_ready and not default_sequence_path.is_empty():
		play_sequence_from_path(default_sequence_path)


func _bind_scene_nodes() -> void:
	_root_control = get_node_or_null("%RootControl") as Control
	_dark_base = get_node_or_null("%DarkBase") as ColorRect
	_ambient_bg = get_node_or_null("%AmbientBackground") as TextureRect
	_art_stage = get_node_or_null("%ArtStage") as Control
	_image_rect = get_node_or_null("%ImageDisplay") as TextureRect
	_glitch_bars = get_node_or_null("%GlitchBars") as Control
	_title_container = get_node_or_null("%TitleCardContainer") as CenterContainer
	_title_header_label = get_node_or_null("%TitleHeader") as Label
	_title_sub_label = get_node_or_null("%TitleSub") as Label
	_dialogue_area = get_node_or_null("%DialogueArea") as MarginContainer
	_dialogue_frame = get_node_or_null("%DialogueFrame") as NinePatchRect
	_speaker_badge = get_node_or_null("%SpeakerBadge") as NinePatchRect
	_speaker_label = get_node_or_null("%SpeakerLabel") as Label
	_dialogue_label = get_node_or_null("%DialogueLabel") as Label
	_scene_counter_label = get_node_or_null("%SceneCounterLabel") as Label
	_prompt_label = get_node_or_null("%PromptLabel") as Label
	_btn_mobile_advance = get_node_or_null("%BtnMobileAdvance") as Button
	_top_overlay = get_node_or_null("%TopOverlay") as MarginContainer
	_btn_skip = get_node_or_null("%BtnSkip") as Button
	_fade_overlay = get_node_or_null("%FadeOverlay") as ColorRect
	_audio_player = get_node_or_null("%AudioPlayer") as AudioStreamPlayer

	if _root_control != null and not _root_control.gui_input.is_connected(_on_root_gui_input):
		_root_control.gui_input.connect(_on_root_gui_input)
	if _btn_skip != null and not _btn_skip.pressed.is_connected(skip_sequence):
		_btn_skip.pressed.connect(skip_sequence)
	if _btn_mobile_advance != null and not _btn_mobile_advance.pressed.is_connected(advance_or_skip_text):
		_btn_mobile_advance.pressed.connect(advance_or_skip_text)


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing or _is_transitioning:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		skip_sequence()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_safe_handle_input()
		advance_or_skip_text()


func _on_root_gui_input(event: InputEvent) -> void:
	if not is_playing or _is_transitioning:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_safe_handle_input()
		advance_or_skip_text()


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


## Carrega e inicia sequência a partir de um caminho de recurso .tres
func play_sequence_from_path(res_path: String) -> void:
	if ResourceLoader.exists(res_path):
		var res := load(res_path)
		if res != null:
			play_sequence(res)
			return

	printerr("NarrativeDirector: Não foi possível carregar sequência em: ", res_path)
	_finish_sequence()


## Inicia a reprodução de uma sequência StorySequence
func play_sequence(sequence: Resource) -> void:
	if sequence == null:
		_finish_sequence()
		return

	if _fade_overlay == null or _root_control == null:
		if has_node("%RootControl"):
			_bind_scene_nodes()
		else:
			_build_ui_nodes()

	current_sequence = sequence
	current_event_index = 0
	current_text_index = 0
	is_playing = true
	_is_transitioning = true

	# Bloqueia movimentação e combate do jogador durante a cena
	_set_gameplay_suspended(true)

	visible = true
	if _fade_overlay != null:
		_fade_overlay.modulate.a = 1.0 # Inicia totalmente em preto
	if _title_container != null:
		_title_container.visible = false
	if _dialogue_area != null:
		_dialogue_area.visible = false
	if _image_rect != null:
		_image_rect.visible = false
	if _ambient_bg != null:
		_ambient_bg.visible = false
	if _glitch_bars != null:
		_glitch_bars.visible = false

	var seq_id: String = str(current_sequence.get("sequence_id"))
	sequence_started.emit(seq_id)

	# Fade inicial a partir do preto (~0.32s)
	_play_initial_fade_in()


func _play_initial_fade_in() -> void:
	_kill_tweens()
	_active_tween = create_tween()
	if _fade_overlay != null:
		_active_tween.tween_property(_fade_overlay, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_interval(0.15) # Pausa sóbria
	_active_tween.tween_callback(func():
		_is_transitioning = false
		_process_current_event()
	)


func _process_current_event() -> void:
	if not is_playing or current_sequence == null:
		_finish_sequence()
		return

	var events: Array = current_sequence.get("events")
	if current_event_index >= events.size():
		_finish_sequence()
		return

	var ev: Resource = events[current_event_index]
	current_text_index = 0

	var ev_id: String = str(ev.get("id"))
	var img_path: String = str(ev.get("image_path"))
	var sound_name: String = str(ev.get("sound_effect_name"))
	var entry_eff: String = str(ev.get("entry_effect"))
	var zoom_start: float = float(ev.get("zoom_start"))
	var zoom_end: float = float(ev.get("zoom_end"))
	var glitch_frames: int = int(ev.get("glitch_frames"))

	_play_audio_by_name(sound_name)

	# Identifica se é Tela de Abertura (CENA 01) ou Cena Narrativa com Imagem
	if ev_id == "title_card" or img_path.is_empty():
		_display_title_card(ev)
	else:
		_display_image_event(ev, img_path, entry_eff, zoom_start, zoom_end, glitch_frames)


## CENA 01 — Cartão de Título Cinemático (Saka's / A ÚLTIMA FICHA)
func _display_title_card(ev: Resource) -> void:
	if _image_rect != null:
		_image_rect.visible = false
	if _ambient_bg != null:
		_ambient_bg.visible = false
	if _dialogue_area != null:
		_dialogue_area.visible = false
	if _title_container != null:
		_title_container.visible = true
		_title_container.modulate.a = 0.0

	var texts: Array = ev.get("texts")
	var header_text: String = str(texts[0]) if texts.size() > 0 else "Saka's"
	var sub_text: String = str(texts[1]) if texts.size() > 1 else "A ÚLTIMA FICHA"

	if _title_header_label != null:
		_title_header_label.text = header_text
	if _title_sub_label != null:
		_title_sub_label.text = sub_text
		_title_sub_label.modulate.a = 0.0

	var ev_id: String = str(ev.get("id"))
	event_started.emit(ev_id, 0)

	_kill_tweens()
	_active_tween = create_tween()

	# 1. Fade In "Saka's" (0.35s)
	_active_tween.tween_property(_title_container, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_interval(0.20)
	# 2. Fade In "A ÚLTIMA FICHA" (0.40s)
	if _title_sub_label != null:
		_active_tween.tween_property(_title_sub_label, "modulate:a", 1.0, 0.40).set_trans(Tween.TRANS_SINE)
	# 3. Hold confortável (2.0s)
	_active_tween.tween_interval(2.0)
	# 4. Fade Out suave para o próximo evento
	_active_tween.tween_property(_title_container, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_callback(func():
		_advance_to_next_event()
	)


## CENAS COM IMAGEM (CENA 02, CENA 03 e Próximas Cenas)
func _display_image_event(
	ev: Resource,
	img_path: String,
	entry_eff: String,
	zoom_start: float,
	zoom_end: float,
	glitch_frames: int
) -> void:
	if _title_container != null:
		_title_container.visible = false

	_load_texture_to_rect(img_path)

	if _ambient_bg != null:
		_ambient_bg.visible = true
	if _image_rect != null:
		_image_rect.visible = true
		_image_rect.pivot_offset = _image_rect.size * 0.5
		_image_rect.scale = Vector2.ONE * zoom_start

	_is_transitioning = true
	_kill_tweens()
	_active_tween = create_tween()

	var trans_dur: float = float(ev.get("transition_duration")) if ev.get("transition_duration") != null else 0.32
	if trans_dur <= 0.0:
		trans_dur = 0.32

	if entry_eff == "slow_zoom":
		if _image_rect != null:
			_image_rect.modulate.a = 0.0
			_active_tween.tween_property(_image_rect, "modulate:a", 1.0, trans_dur).set_trans(Tween.TRANS_SINE)
			if zoom_end != zoom_start:
				_zoom_tween = create_tween()
				_zoom_tween.tween_property(_image_rect, "scale", Vector2.ONE * zoom_end, 7.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif entry_eff == "glitch":
		if _image_rect != null:
			_image_rect.modulate.a = 1.0
		_trigger_glitch_effect(glitch_frames)
		_active_tween.tween_interval(0.12)
	else: # crossfade / fade_in oficial
		if _image_rect != null:
			_image_rect.modulate.a = 0.0
			_active_tween.tween_property(_image_rect, "modulate:a", 1.0, trans_dur).set_trans(Tween.TRANS_SINE)

	_active_tween.tween_callback(func():
		_is_transitioning = false
		_show_current_text_block(ev)
	)


## Apresenta o bloco de diálogo atual dentro da Moldura Oficial Arcade
## COMPORTAMENTO CANÔNICO: Permanece na tela INDEFINIDAMENTE até que o jogador confirme o avanço!
func _show_current_text_block(ev: Resource) -> void:
	var texts: Array = ev.get("texts")
	if texts.is_empty() or current_text_index >= texts.size():
		_advance_to_next_event()
		return

	var text_content: String = str(texts[current_text_index])
	var speaker_name: String = str(ev.get("speaker")).strip_edges()

	# Configura Orador
	if _speaker_badge != null and _speaker_label != null:
		if speaker_name.is_empty():
			_speaker_badge.visible = false
		else:
			_speaker_badge.visible = true
			_speaker_label.text = speaker_name.to_upper()

	# Configura Texto do Diálogo
	if _dialogue_label != null:
		_dialogue_label.text = text_content

	# Configura Contador de Cenas (ex: CENA 02 / 03)
	if _scene_counter_label != null:
		var total_events: int = current_sequence.get("events").size() if current_sequence != null else 3
		_scene_counter_label.text = "CENA %02d / %02d" % [current_event_index + 1, total_events]

	# Exibe Área de Diálogo com animação suave de entrada da moldura
	if _dialogue_area != null:
		_dialogue_area.visible = true
		_dialogue_area.modulate.a = 0.0

		var panel_tween := create_tween()
		panel_tween.tween_property(_dialogue_area, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)

	_start_prompt_pulse()

	var ev_id: String = str(ev.get("id"))
	event_started.emit(ev_id, current_text_index)

	# NOTA ARQUITETURAL CANÔNICA (Padrão Sakas):
	# NENHUM temporizador é agendado aqui. A fala NÃO avança automaticamente.
	# O avanço ocorre exclusivamente via interação do jogador em advance_or_skip_text().


## Avanço Manual de Fala: acionado por [Espaço], [Enter], Gamepad (A) ou Toque Mobile
func advance_or_skip_text() -> void:
	if not is_playing or current_sequence == null:
		return

	var events: Array = current_sequence.get("events")
	if current_event_index >= events.size():
		_finish_sequence()
		return

	var ev: Resource = events[current_event_index]

	# Se estiver na tela de título (CENA 01), avança imediatamente mesmo se em transição
	if str(ev.get("id")) == "title_card":
		_kill_tweens()
		_is_transitioning = false
		_advance_to_next_event()
		return

	if _is_transitioning:
		return

	var texts: Array = ev.get("texts")
	_play_sound(_sfx_advance)

	# Avança para o próximo bloco de diálogo da mesma cena
	if current_text_index + 1 < texts.size():
		current_text_index += 1
		_show_current_text_block(ev)
	else:
		_advance_to_next_event()


func _advance_to_next_event() -> void:
	var events: Array = current_sequence.get("events") if current_sequence != null else []
	if current_event_index < events.size():
		var prev_ev: Resource = events[current_event_index]
		event_completed.emit(str(prev_ev.get("id")))

	current_event_index += 1
	if current_event_index >= events.size():
		_finish_sequence()
	else:
		_process_current_event()


## Pula toda a sequência cinematográfica com segurança imediata
func skip_sequence() -> void:
	if not is_playing:
		return
	var seq_id: String = str(current_sequence.get("sequence_id")) if current_sequence != null else ""
	sequence_skipped.emit(seq_id)
	_finish_sequence()


func _finish_sequence() -> void:
	if not is_playing:
		return

	is_playing = false
	_is_transitioning = true
	_kill_tweens()

	# Registra no GameSession que o prólogo já foi assistido
	var session = get_node_or_null("/root/GameSession")
	if session != null and "has_played_intro" in session:
		session.has_played_intro = true

	# Fade out suave da camada narrativa (~0.32s)
	var exit_tween := create_tween()
	if _fade_overlay != null:
		exit_tween.tween_property(_fade_overlay, "modulate:a", 1.0, 0.25)
	exit_tween.tween_callback(func():
		if _image_rect != null:
			_image_rect.visible = false
		if _ambient_bg != null:
			_ambient_bg.visible = false
		if _title_container != null:
			_title_container.visible = false
		if _dialogue_area != null:
			_dialogue_area.visible = false
		if _glitch_bars != null:
			_glitch_bars.visible = false
	)
	if _fade_overlay != null:
		exit_tween.tween_property(_fade_overlay, "modulate:a", 0.0, 0.32)
	exit_tween.tween_callback(func():
		visible = false
		_is_transitioning = false
		_set_gameplay_suspended(false)
		var seq_id: String = str(current_sequence.get("sequence_id")) if current_sequence != null else ""
		sequence_completed.emit(seq_id)
	)


## Efeito de glitch visual analógico de 2 a 3 frames
func _trigger_glitch_effect(frames_count: int = 3) -> void:
	if _glitch_bars == null:
		return

	_glitch_bars.visible = true
	for c in _glitch_bars.get_children():
		c.queue_free()

	var colors := [Color(0.2, 0.9, 1.0, 0.6), Color(1.0, 0.2, 0.4, 0.6), Color(0.9, 0.9, 0.9, 0.7)]
	for i in range(5):
		var bar := ColorRect.new()
		bar.color = colors[i % colors.size()]
		var bar_h: float = randf_range(8.0, 24.0)
		var bar_y: float = randf_range(50.0, 700.0)
		bar.position = Vector2(randf_range(-15.0, 15.0), bar_y)
		bar.size = Vector2(1920.0 + 30.0, bar_h)
		_glitch_bars.add_child(bar)

	var delay: float = maxf(float(frames_count) * 0.02, 0.05)
	get_tree().create_timer(delay).timeout.connect(func():
		if _glitch_bars != null and is_instance_valid(_glitch_bars):
			_glitch_bars.visible = false
	)


## Suspende/Restabelece física e controle do jogador durante cutscenes
func _set_gameplay_suspended(suspended: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		if suspended:
			player.set_physics_process(false)
			player.set_process_unhandled_input(false)
			if "velocity" in player:
				player.velocity = Vector2.ZERO
		else:
			player.set_physics_process(true)
			player.set_process_unhandled_input(true)

	var combat_director = get_tree().get_first_node_in_group("combat_director")
	if combat_director != null and is_instance_valid(combat_director):
		if "is_encounter_active" in combat_director:
			combat_director.set_process(not suspended)


func _load_texture_to_rect(path: String) -> void:
	if path.is_empty():
		return

	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D

	# Fallbacks resilientes
	if tex == null:
		var fallback_p := ""
		if path.contains("intro_group"):
			fallback_p = "res://assets/backgrounds/intro_cena02.webp"
		elif path.contains("missing_friends"):
			fallback_p = "res://assets/backgrounds/intro_cena03.webp"

		if not fallback_p.is_empty() and ResourceLoader.exists(fallback_p):
			tex = load(fallback_p) as Texture2D

	if tex == null:
		var global_p := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_p):
			var img := Image.load_from_file(global_p)
			if img != null:
				tex = ImageTexture.create_from_image(img)

	if tex != null:
		if _image_rect != null:
			_image_rect.texture = tex
		if _ambient_bg != null:
			_ambient_bg.texture = tex


func _start_prompt_pulse() -> void:
	if _prompt_label == null:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_prompt_label, "modulate:a", 0.45, 0.45).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_prompt_label, "modulate:a", 1.00, 0.45).set_trans(Tween.TRANS_SINE)


func _kill_tweens() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
		_zoom_tween = null


func _play_audio_by_name(sound_name: String) -> void:
	match sound_name:
		"deep_intro_hum":
			_play_sound(_sfx_deep_hum)
		"nostalgia_chime":
			_play_sound(_sfx_nostalgia)
		"glitch_static":
			_play_sound(_sfx_glitch)
		_:
			pass


func _play_sound(stream: AudioStreamWAV) -> void:
	if _audio_player != null and stream != null:
		_audio_player.stream = stream
		_audio_player.play()


## Constrói os nós visuais programaticamente com estilização Neo-16-bit oficial
func _build_ui_nodes() -> void:
	_root_control = Control.new()
	_root_control.name = "RootControl"
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.anchor_right = 1.0
	_root_control.anchor_bottom = 1.0
	_root_control.custom_minimum_size = Vector2(1280, 720)
	_root_control.mouse_filter = Control.MOUSE_FILTER_PASS
	_root_control.gui_input.connect(_on_root_gui_input)
	add_child(_root_control)

	# Fundo escuro absoluto
	_dark_base = ColorRect.new()
	_dark_base.name = "DarkBase"
	_dark_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark_base.color = Color(0.02, 0.02, 0.04, 1.0)
	_dark_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_dark_base)

	# Fundo ambiente derivado da imagem para preencher telas ultra-wide / fora de 16:9
	_ambient_bg = TextureRect.new()
	_ambient_bg.name = "AmbientBackground"
	_ambient_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ambient_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ambient_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_ambient_bg.modulate = Color(0.20, 0.20, 0.28, 0.35)
	_ambient_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient_bg.visible = false
	_root_control.add_child(_ambient_bg)

	# Palco Superior da Imagem (Área Segura que NUNCA é encoberta pela caixa de diálogo)
	_art_stage = Control.new()
	_art_stage.name = "ArtStage"
	_art_stage.anchor_top = 0.0
	_art_stage.anchor_bottom = 0.74
	_art_stage.anchor_left = 0.0
	_art_stage.anchor_right = 1.0
	_art_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_art_stage)

	_image_rect = TextureRect.new()
	_image_rect.name = "ImageDisplay"
	_image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_stage.add_child(_image_rect)

	_glitch_bars = Control.new()
	_glitch_bars.name = "GlitchBars"
	_glitch_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glitch_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_bars.visible = false
	_art_stage.add_child(_glitch_bars)

	# CENA 01: Cartão de Título Centralizado
	_title_container = CenterContainer.new()
	_title_container.name = "TitleCardContainer"
	_title_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_container.visible = false
	_root_control.add_child(_title_container)

	var title_vbox := VBoxContainer.new()
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vbox.add_theme_constant_override("separation", 14)
	_title_container.add_child(title_vbox)

	_title_header_label = Label.new()
	_title_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_header_label.add_theme_font_override("font", ARCADE_FONT)
	_title_header_label.add_theme_font_size_override("font_size", 32)
	_title_header_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.10, 1.0)) # Dourado arcade
	_title_header_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title_header_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_header_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_header_label.text = "Saka's"
	title_vbox.add_child(_title_header_label)

	_title_sub_label = Label.new()
	_title_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_sub_label.add_theme_font_override("font", ARCADE_FONT)
	_title_sub_label.add_theme_font_size_override("font_size", 48)
	_title_sub_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_title_sub_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.1, 0.15, 0.95))
	_title_sub_label.add_theme_constant_override("shadow_offset_x", 4)
	_title_sub_label.add_theme_constant_override("shadow_offset_y", 4)
	_title_sub_label.text = "A ÚLTIMA FICHA"
	title_vbox.add_child(_title_sub_label)

	# Área de Diálogo com Moldura Oficial Arcade 9-Patch
	_dialogue_area = MarginContainer.new()
	_dialogue_area.name = "DialogueArea"
	_dialogue_area.anchor_top = 0.74
	_dialogue_area.anchor_bottom = 0.97
	_dialogue_area.anchor_left = 0.0
	_dialogue_area.anchor_right = 1.0
	_dialogue_area.add_theme_constant_override("margin_left", 50)
	_dialogue_area.add_theme_constant_override("margin_right", 50)
	_dialogue_area.add_theme_constant_override("margin_bottom", 12)
	_dialogue_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_area.visible = false
	_root_control.add_child(_dialogue_area)

	_dialogue_frame = NinePatchRect.new()
	_dialogue_frame.name = "DialogueFrame"
	_dialogue_frame.texture = DIALOG_FRAME_TEXTURE
	_dialogue_frame.patch_margin_left = 16
	_dialogue_frame.patch_margin_top = 16
	_dialogue_frame.patch_margin_right = 16
	_dialogue_frame.patch_margin_bottom = 16
	_dialogue_frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	_dialogue_frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	_dialogue_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	_dialogue_area.add_child(_dialogue_frame)

	# Cartão/Badge do Orador fixado na borda superior da moldura
	_speaker_badge = NinePatchRect.new()
	_speaker_badge.name = "SpeakerBadge"
	_speaker_badge.texture = SPEAKER_BADGE_TEXTURE
	_speaker_badge.patch_margin_left = 8
	_speaker_badge.patch_margin_top = 8
	_speaker_badge.patch_margin_right = 8
	_speaker_badge.patch_margin_bottom = 8
	_speaker_badge.custom_minimum_size = Vector2(180, 32)
	_speaker_badge.position = Vector2(24, -22)
	_dialogue_frame.add_child(_speaker_badge)

	var badge_margin := MarginContainer.new()
	badge_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_margin.add_theme_constant_override("margin_left", 12)
	badge_margin.add_theme_constant_override("margin_right", 12)
	badge_margin.add_theme_constant_override("margin_top", 4)
	badge_margin.add_theme_constant_override("margin_bottom", 4)
	_speaker_badge.add_child(badge_margin)

	_speaker_label = Label.new()
	_speaker_label.name = "SpeakerLabel"
	_speaker_label.add_theme_font_override("font", ARCADE_FONT)
	_speaker_label.add_theme_font_size_override("font_size", 14)
	_speaker_label.add_theme_color_override("font_color", Color(0.92, 0.70, 0.10, 1.0))
	_speaker_label.text = "SAKAS"
	badge_margin.add_child(_speaker_label)

	# Conteúdo interno do Diálogo e Rodapé
	var content_margin := MarginContainer.new()
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 28)
	content_margin.add_theme_constant_override("margin_right", 28)
	content_margin.add_theme_constant_override("margin_top", 18)
	content_margin.add_theme_constant_override("margin_bottom", 12)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_frame.add_child(content_margin)

	var content_vbox := VBoxContainer.new()
	content_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	content_vbox.add_theme_constant_override("separation", 8)
	content_margin.add_child(content_vbox)

	_dialogue_label = Label.new()
	_dialogue_label.name = "DialogueLabel"
	_dialogue_label.add_theme_font_override("font", ARCADE_FONT)
	_dialogue_label.add_theme_font_size_override("font_size", 18)
	_dialogue_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.91, 1.0)) # Marfim #F4F0E8
	_dialogue_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_dialogue_label.add_theme_constant_override("shadow_offset_x", 2)
	_dialogue_label.add_theme_constant_override("shadow_offset_y", 2)
	_dialogue_label.add_theme_constant_override("line_spacing", 6)
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(_dialogue_label)

	# Rodapé do Diálogo (Contador de Cena à esquerda, Prompt / Botão à direita)
	var footer_hbox := HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(footer_hbox)

	_scene_counter_label = Label.new()
	_scene_counter_label.name = "SceneCounterLabel"
	_scene_counter_label.add_theme_font_override("font", ARCADE_FONT)
	_scene_counter_label.add_theme_font_size_override("font_size", 13)
	_scene_counter_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.72, 0.85)) # Cinza/Prata arcade
	_scene_counter_label.text = "CENA 02 / 03"
	footer_hbox.add_child(_scene_counter_label)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(footer_spacer)

	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.add_theme_font_override("font", ARCADE_FONT)
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.28, 1.0)) # Ouro
	_prompt_label.text = "[ ESPAÇO ] AVANÇAR ❯"
	footer_hbox.add_child(_prompt_label)

	_btn_mobile_advance = Button.new()
	_btn_mobile_advance.name = "BtnMobileAdvance"
	_btn_mobile_advance.text = "AVANÇAR ❯"
	_btn_mobile_advance.custom_minimum_size = Vector2(100, 32)
	_btn_mobile_advance.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_mobile_advance.add_theme_font_override("font", ARCADE_FONT)
	_btn_mobile_advance.add_theme_font_size_override("font_size", 12)
	_btn_mobile_advance.pressed.connect(advance_or_skip_text)
	footer_hbox.add_child(_btn_mobile_advance)

	# Barra de Ações Superior (Botão PULAR ⏩)
	_top_overlay = MarginContainer.new()
	_top_overlay.name = "TopOverlay"
	_top_overlay.anchor_top = 0.0
	_top_overlay.anchor_right = 1.0
	_top_overlay.offset_bottom = 60.0
	_top_overlay.add_theme_constant_override("margin_top", 14)
	_top_overlay.add_theme_constant_override("margin_right", 24)
	_top_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_top_overlay)

	var top_hbox := HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_END
	_top_overlay.add_child(top_hbox)

	_btn_skip = Button.new()
	_btn_skip.name = "BtnSkip"
	_btn_skip.text = "PULAR ⏩"
	_btn_skip.custom_minimum_size = Vector2(105, 34)
	_btn_skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_skip.add_theme_font_override("font", ARCADE_FONT)
	_btn_skip.add_theme_font_size_override("font_size", 12)
	_btn_skip.pressed.connect(skip_sequence)
	top_hbox.add_child(_btn_skip)

	# Camada Superior de Fade para Preto
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color(0, 0, 0, 1)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.modulate.a = 0.0
	_root_control.add_child(_fade_overlay)

	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "AudioPlayer"
	add_child(_audio_player)


func _generate_sound_effects() -> void:
	_sfx_deep_hum = _create_wav(55.0, 1.8, 0.45)
	_sfx_nostalgia = _create_wav(660.0, 0.35, 0.35)
	_sfx_glitch = _create_noise_wav(0.08, 0.5)
	_sfx_advance = _create_wav(980.0, 0.06, 0.3)


func _create_wav(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var sample_count: int = int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t: float = float(i) / 22050.0
		var envelope: float = 1.0 - (float(i) / float(sample_count))
		var wave: float = sin(t * freq * TAU)
		var val: float = (wave * volume * envelope) * 127.0 + 128.0
		data[i] = int(clamp(val, 0.0, 255.0))
	wav.data = data
	return wav


func _create_noise_wav(duration: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var sample_count: int = int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var noise: float = randf_range(-1.0, 1.0)
		var val: float = (noise * volume) * 127.0 + 128.0
		data[i] = int(clamp(val, 0.0, 255.0))
	wav.data = data
	return wav
