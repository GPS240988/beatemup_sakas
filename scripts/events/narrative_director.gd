class_name NarrativeDirector
extends CanvasLayer

## Diretor e Apresentador Narrativo Cinemático para Beat 'em Up 2.5D (Saka's: A Última Ficha).
## Gerencia cenas narrativas estáticas e cinemáticas com zooms sutis em Pixel Art HD,
## transições com fade, glitches de 2 a 3 frames, legendas curtas e controles não-bloqueantes.
## Totalmente compatível com Teclado, Gamepad, Mouse e Toque Mobile.
## Em estrita conformidade com GAME_RULES.md (Dark Premium Medieval / Cyber-Arcade).

signal sequence_started(sequence_id: String)
signal event_started(event_id: String, text_index: int)
signal event_completed(event_id: String)
signal sequence_completed(sequence_id: String)
signal sequence_skipped(sequence_id: String)

const StoryEventClass = preload("res://scripts/events/story_event.gd")
const StorySequenceClass = preload("res://scripts/events/story_sequence.gd")

@export var default_sequence_path: String = "res://resources/story/story_intro_map1.tres"
@export var auto_start_on_ready: bool = false

var is_playing: bool = false
var current_sequence: Resource = null
var current_event_index: int = 0
var current_text_index: int = 0

var _is_transitioning_block: bool = false
var _active_tween: Tween = null
var _zoom_tween: Tween = null
var _glitch_timer: float = 0.0

# Nós visuais internos
var _root_control: Control
var _dark_base: ColorRect
var _image_rect: TextureRect
var _glitch_bars: Control
var _title_container: CenterContainer
var _title_header_label: Label
var _title_sub_label: Label
var _subtitle_container: MarginContainer
var _speaker_label: Label
var _dialogue_label: Label
var _btn_skip: Button
var _prompt_label: Label
var _fade_overlay: ColorRect
var _audio_player: AudioStreamPlayer

# Efeitos sonoros procedurais integrados
var _sfx_deep_hum: AudioStreamWAV
var _sfx_nostalgia: AudioStreamWAV
var _sfx_glitch: AudioStreamWAV
var _sfx_advance: AudioStreamWAV


func _init() -> void:
	layer = 120 # Acima da HUD e do mundo, abaixo de menus críticos de sistema


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
	_image_rect = get_node_or_null("%ImageDisplay") as TextureRect
	_glitch_bars = get_node_or_null("%GlitchBars") as Control
	_title_container = get_node_or_null("%TitleCardContainer") as CenterContainer
	_title_header_label = get_node_or_null("%TitleHeader") as Label
	_title_sub_label = get_node_or_null("%TitleSub") as Label
	_subtitle_container = get_node_or_null("%SubtitleContainer") as MarginContainer
	_speaker_label = get_node_or_null("%SpeakerLabel") as Label
	_dialogue_label = get_node_or_null("%DialogueLabel") as Label
	_btn_skip = get_node_or_null("%BtnSkip") as Button
	_prompt_label = get_node_or_null("%PromptLabel") as Label
	_fade_overlay = get_node_or_null("%FadeOverlay") as ColorRect
	_audio_player = get_node_or_null("%AudioPlayer") as AudioStreamPlayer

	if _root_control != null and not _root_control.gui_input.is_connected(_on_root_gui_input):
		_root_control.gui_input.connect(_on_root_gui_input)
	if _btn_skip != null and not _btn_skip.pressed.is_connected(skip_sequence):
		_btn_skip.pressed.connect(skip_sequence)


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		skip_sequence()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
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
	# Fallback de segurança: encerra sem travar o jogador
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

	# Bloqueia gameplay enquanto a cena estiver ativa
	_set_gameplay_suspended(true)

	visible = true
	if _fade_overlay != null:
		_fade_overlay.modulate.a = 1.0 # Inicia em preto
	if _title_container != null:
		_title_container.visible = false
	if _subtitle_container != null:
		_subtitle_container.visible = false
	if _image_rect != null:
		_image_rect.visible = false
	if _glitch_bars != null:
		_glitch_bars.visible = false

	var seq_id: String = str(current_sequence.get("sequence_id"))
	sequence_started.emit(seq_id)

	# Fade inicial para preto e breve pausa de silêncio (0.5s)
	_play_initial_fade_in()


func _play_initial_fade_in() -> void:
	_kill_tweens()
	_active_tween = create_tween()
	# Transiciona o fade_overlay de 1.0 para 0.0 para revelar a DarkBase
	if _fade_overlay != null:
		_active_tween.tween_property(_fade_overlay, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_interval(0.2) # Pequena pausa de silêncio
	_active_tween.tween_callback(func():
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

	# Identifica se é Tela de Título (CENA 01) ou Cena com Imagem
	if ev_id == "title_card" or img_path.is_empty():
		_display_title_card(ev)
	else:
		_display_image_event(ev, img_path, entry_eff, zoom_start, zoom_end, glitch_frames)


## CENA 01 — Tela preta com título Saka's e subtítulo A ÚLTIMA FICHA
func _display_title_card(ev: Resource) -> void:
	_image_rect.visible = false
	_subtitle_container.visible = false
	_title_container.visible = true
	_title_container.modulate.a = 0.0

	var texts: Array = ev.get("texts")
	var header_text: String = str(texts[0]) if texts.size() > 0 else "Saka's"
	var sub_text: String = str(texts[1]) if texts.size() > 1 else "A ÚLTIMA FICHA"

	_title_header_label.text = header_text
	_title_sub_label.text = sub_text
	_title_sub_label.modulate.a = 0.0

	_kill_tweens()
	_active_tween = create_tween()

	# 1. Fade In "Saka's"
	_active_tween.tween_property(_title_container, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_interval(0.3)
	# 2. Fade In "A ÚLTIMA FICHA"
	_active_tween.tween_property(_title_sub_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	# 3. Hold por aproximadamente 2 segundos
	_active_tween.tween_interval(1.8)
	# 4. Fade Out
	_active_tween.tween_property(_title_container, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_callback(func():
		_advance_to_next_event()
	)


## CENAS COM IMAGEM (CENA 02 e CENA 03)
func _display_image_event(
	ev: Resource,
	img_path: String,
	entry_eff: String,
	zoom_start: float,
	zoom_end: float,
	glitch_frames: int
) -> void:
	_title_container.visible = false
	_load_texture_to_rect(img_path)
	_image_rect.visible = true

	# Reseta scale / pivot para zoom suave central
	_image_rect.pivot_offset = _image_rect.size * 0.5
	_image_rect.scale = Vector2.ONE * zoom_start

	_kill_tweens()
	_active_tween = create_tween().set_parallel(true)

	if entry_eff == "slow_zoom":
		_image_rect.modulate.a = 0.0
		_active_tween.tween_property(_image_rect, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
		# Leve zoom de 100% para 103%
		if zoom_end != zoom_start:
			_active_tween.tween_property(_image_rect, "scale", Vector2.ONE * zoom_end, 7.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif entry_eff == "glitch":
		_image_rect.modulate.a = 1.0
		_trigger_glitch_effect(glitch_frames)
	else: # crossfade / fade_in padrão
		_image_rect.modulate.a = 0.0
		_active_tween.tween_property(_image_rect, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)

	# Exibe o primeiro bloco de texto da cena
	_show_current_text_block(ev)


func _show_current_text_block(ev: Resource) -> void:
	var texts: Array = ev.get("texts")
	if texts.is_empty():
		_advance_to_next_event()
		return

	if current_text_index >= texts.size():
		_advance_to_next_event()
		return

	var text_content: String = str(texts[current_text_index])
	var speaker_name: String = str(ev.get("speaker"))
	var block_duration: float = float(ev.get("duration_per_text"))

	if speaker_name.is_empty():
		_speaker_label.visible = false
	else:
		_speaker_label.visible = true
		_speaker_label.text = speaker_name.to_upper()

	_dialogue_label.text = text_content
	_subtitle_container.visible = true
	_subtitle_container.modulate.a = 0.0

	var ev_id: String = str(ev.get("id"))
	event_started.emit(ev_id, current_text_index)

	# Animação suave de entrada do texto
	var text_tween := create_tween()
	text_tween.tween_property(_subtitle_container, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	text_tween.tween_interval(block_duration)
	text_tween.tween_callback(func():
		_on_text_block_timeout(ev)
	)


func _on_text_block_timeout(ev: Resource) -> void:
	var texts: Array = ev.get("texts")
	if current_text_index + 1 < texts.size():
		current_text_index += 1
		_show_current_text_block(ev)
	else:
		_advance_to_next_event()


## Avança para o próximo bloco de texto ou evento via interação do jogador
func advance_or_skip_text() -> void:
	if not is_playing or current_sequence == null:
		return

	var events: Array = current_sequence.get("events")
	if current_event_index >= events.size():
		_finish_sequence()
		return

	var ev: Resource = events[current_event_index]
	var texts: Array = ev.get("texts")

	_play_sound(_sfx_advance)

	# Se for título (CENA 01), avança direto para o próximo evento
	if str(ev.get("id")) == "title_card":
		_kill_tweens()
		_advance_to_next_event()
		return

	# Avança para o próximo bloco de texto do mesmo evento
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


## Pula imediatamente toda a sequência com segurança
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
	_kill_tweens()

	# Registra no GameSession que o prólogo inicial já foi concluído
	var session = get_node_or_null("/root/GameSession")
	if session != null and "has_played_intro" in session:
		session.has_played_intro = true

	# Fade out suave da camada narrativa para revelar o jogo
	var exit_tween := create_tween()
	exit_tween.tween_property(_fade_overlay, "modulate:a", 1.0, 0.25)
	exit_tween.tween_callback(func():
		_image_rect.visible = false
		_title_container.visible = false
		_subtitle_container.visible = false
		_glitch_bars.visible = false
	)
	exit_tween.tween_property(_fade_overlay, "modulate:a", 0.0, 0.45)
	exit_tween.tween_callback(func():
		visible = false
		_set_gameplay_suspended(false)
		var seq_id: String = str(current_sequence.get("sequence_id")) if current_sequence != null else ""
		sequence_completed.emit(seq_id)
	)


## Efeito de glitch visual de 2 ou 3 frames com ruído analógico
func _trigger_glitch_effect(frames_count: int = 3) -> void:
	if _glitch_bars == null:
		return

	_glitch_bars.visible = true
	# Limpa barras antigas
	for c in _glitch_bars.get_children():
		c.queue_free()

	# Gera faixas horizontais de ruído cromático
	var colors := [Color(0.2, 0.9, 1.0, 0.6), Color(1.0, 0.2, 0.4, 0.6), Color(0.9, 0.9, 0.9, 0.7)]
	for i in range(5):
		var bar := ColorRect.new()
		bar.color = colors[i % colors.size()]
		var bar_h: float = randf_range(8.0, 24.0)
		var bar_y: float = randf_range(50.0, 1000.0)
		bar.position = Vector2(randf_range(-15.0, 15.0), bar_y)
		bar.size = Vector2(1920.0 + 30.0, bar_h)
		_glitch_bars.add_child(bar)

	# Duração de ~2 a 3 frames (40ms a 60ms)
	var glitch_tween := create_tween()
	glitch_tween.tween_interval(0.055)
	glitch_tween.tween_callback(func():
		if _glitch_bars != null:
			_glitch_bars.visible = false
			for c in _glitch_bars.get_children():
				c.queue_free()
	)


## Suspende ou restaura controles e IA de combate durante a cutscene
func _set_gameplay_suspended(suspended: bool) -> void:
	if get_tree() == null:
		return

	# Pausa/retoma o jogador
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

	# Suspende spawns ou combate ativo caso existam
	var combat_director = get_tree().get_first_node_in_group("combat_director")
	if combat_director != null and is_instance_valid(combat_director):
		if "is_encounter_active" in combat_director:
			if suspended:
				combat_director.set_process(false)
			else:
				combat_director.set_process(true)


func _load_texture_to_rect(path: String) -> void:
	if _image_rect == null or path.is_empty():
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
		_image_rect.texture = tex


func _kill_tweens() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()


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


## Constrói os nós visuais com estilização Dark Premium Medieval / Cyber-Arcade
func _build_ui_nodes() -> void:
	_root_control = Control.new()
	_root_control.name = "Root"
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.anchor_right = 1.0
	_root_control.anchor_bottom = 1.0
	_root_control.custom_minimum_size = Vector2(1920, 1080)
	_root_control.mouse_filter = Control.MOUSE_FILTER_PASS
	_root_control.gui_input.connect(_on_root_gui_input)
	add_child(_root_control)

	# Fundo preto absoluto
	_dark_base = ColorRect.new()
	_dark_base.name = "DarkBase"
	_dark_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark_base.color = Color(0.01, 0.01, 0.02, 1.0)
	_dark_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_dark_base)

	# Imagem cinemática
	_image_rect = TextureRect.new()
	_image_rect.name = "ImageDisplay"
	_image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_image_rect)

	# Faixas de Glitch
	_glitch_bars = Control.new()
	_glitch_bars.name = "GlitchBars"
	_glitch_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glitch_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_bars.visible = false
	_root_control.add_child(_glitch_bars)

	# CENA 01: Cartão de Título Centralizado
	_title_container = CenterContainer.new()
	_title_container.name = "TitleCardContainer"
	_title_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_title_container)

	var title_vbox := VBoxContainer.new()
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vbox.add_theme_constant_override("separation", 12)
	_title_container.add_child(title_vbox)

	_title_header_label = Label.new()
	_title_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_header_label.add_theme_font_size_override("font_size", 26)
	_title_header_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	_title_header_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title_header_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_header_label.add_theme_constant_override("shadow_offset_y", 2)
	_title_header_label.text = "Saka's"
	title_vbox.add_child(_title_header_label)

	_title_sub_label = Label.new()
	_title_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_sub_label.add_theme_font_size_override("font_size", 44)
	_title_sub_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_title_sub_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.1, 0.15, 0.9))
	_title_sub_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_sub_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_sub_label.text = "A ÚLTIMA FICHA"
	title_vbox.add_child(_title_sub_label)

	# Container de Legendas (CENAS 02 e 03)
	_subtitle_container = MarginContainer.new()
	_subtitle_container.name = "SubtitleContainer"
	_subtitle_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_container.offset_top = -140.0
	_subtitle_container.add_theme_constant_override("margin_left", 60)
	_subtitle_container.add_theme_constant_override("margin_right", 60)
	_subtitle_container.add_theme_constant_override("margin_bottom", 40)
	_subtitle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_subtitle_container)

	var sub_panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.09, 0.88)
	panel_style.border_color = Color(0.85, 0.65, 0.15, 0.8)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.7)
	panel_style.shadow_size = 10
	sub_panel.add_theme_stylebox_override("panel", panel_style)
	_subtitle_container.add_child(sub_panel)

	var sub_margin := MarginContainer.new()
	sub_margin.add_theme_constant_override("margin_left", 24)
	sub_margin.add_theme_constant_override("margin_top", 14)
	sub_margin.add_theme_constant_override("margin_right", 24)
	sub_margin.add_theme_constant_override("margin_bottom", 14)
	sub_panel.add_child(sub_margin)

	var sub_vbox := VBoxContainer.new()
	sub_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_vbox.add_theme_constant_override("separation", 6)
	sub_margin.add_child(sub_vbox)

	_speaker_label = Label.new()
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker_label.add_theme_font_size_override("font_size", 14)
	_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2, 1.0))
	sub_vbox.add_child(_speaker_label)

	_dialogue_label = Label.new()
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_font_size_override("font_size", 21)
	_dialogue_label.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 1.0))
	_dialogue_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_dialogue_label.add_theme_constant_override("shadow_offset_x", 1)
	_dialogue_label.add_theme_constant_override("shadow_offset_y", 1)
	sub_vbox.add_child(_dialogue_label)

	# Barra Superior com Instruções e Botão Pular Mobile/Desktop
	var top_bar := MarginContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 65.0
	top_bar.add_theme_constant_override("margin_left", 28)
	top_bar.add_theme_constant_override("margin_top", 18)
	top_bar.add_theme_constant_override("margin_right", 28)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(top_hbox)

	_prompt_label = Label.new()
	_prompt_label.text = "[ESPAÇO / TOQUE] Avançar"
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.88, 0.7))
	top_hbox.add_child(_prompt_label)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(top_spacer)

	_btn_skip = Button.new()
	_btn_skip.text = "PULAR ⏩"
	_btn_skip.custom_minimum_size = Vector2(110, 36)
	_btn_skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var skip_style := StyleBoxFlat.new()
	skip_style.bg_color = Color(0.12, 0.14, 0.22, 0.85)
	skip_style.border_color = Color(0.5, 0.55, 0.7, 0.8)
	skip_style.border_width_left = 1
	skip_style.border_width_top = 1
	skip_style.border_width_right = 1
	skip_style.border_width_bottom = 1
	skip_style.corner_radius_top_left = 6
	skip_style.corner_radius_top_right = 6
	skip_style.corner_radius_bottom_right = 6
	skip_style.corner_radius_bottom_left = 6
	_btn_skip.add_theme_stylebox_override("normal", skip_style)
	_btn_skip.add_theme_font_size_override("font_size", 14)
	_btn_skip.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0, 1.0))
	_btn_skip.pressed.connect(skip_sequence)
	top_hbox.add_child(_btn_skip)

	# Overlay de Fade
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color(0, 0, 0, 1)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.modulate.a = 0.0
	_root_control.add_child(_fade_overlay)

	# Player de áudio
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "AudioPlayer"
	add_child(_audio_player)


func _on_root_gui_input(event: InputEvent) -> void:
	if not is_playing:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_safe_handle_input()
		advance_or_skip_text()


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

