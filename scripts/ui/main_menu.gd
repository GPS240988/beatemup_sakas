class_name MainMenu
extends Control
## Menu Principal com arte neutra 16:9 HD (menu_state_vf.webp) e seletor dinâmico overlay.
## Em estrita conformidade com GAME_RULES.md (Persona Senior Front-End e Arquitetura UI).
const TITLE_SCREEN_SCENE: String = "res://scenes/ui/title_screen.tscn"
const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const CREDITS_SCENE: String = "res://scenes/ui/credits.tscn"
const CONTINUE_SCENE: String = "res://scenes/ui/continue_screen.tscn"
const MAP_MENU_SCENE: String = "res://scenes/ui/map_menu.tscn"
const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")

const BASE_WIDTH: float = 1920.0
const BASE_HEIGHT: float = 1080.0
## Coordenadas calibradas com precisão milimétrica no espaço 1920x1080 da arte menu_state_vf.webp:
## cy: centro vertical exato do texto
## bx: coordenada X inicial da pincelada de realce
## bw: largura da pincelada de realce
const OPTION_CONFIGS: Array[Dictionary] = [
	{ "cy": 519.0, "lx": 615.0, "rx": 1256.0, "bx": 668.0, "bw": 584.0 }, # 0: NOVO JOGO
	{ "cy": 609.0, "lx": 615.0, "rx": 1256.0, "bx": 668.0, "bw": 584.0 }, # 1: CONTINUAR
	{ "cy": 693.0, "lx": 615.0, "rx": 1256.0, "bx": 668.0, "bw": 584.0 }, # 2: PERSONAGENS
	{ "cy": 777.5, "lx": 615.0, "rx": 1256.0, "bx": 668.0, "bw": 584.0 }, # 3: MAPA
	{ "cy": 860.0, "lx": 615.0, "rx": 1256.0, "bx": 668.0, "bw": 584.0 }, # 4: CONFIGURAÇÕES
	{ "cy": 941.0, "lx": 615.0, "rx": 1256.0, "bx": 668.0, "bw": 584.0 }  # 5: SAIR
]

@onready var background_slot: TextureRect = %BackgroundSlot
@onready var aspect_wrapper: AspectRatioContainer = %AspectWrapper
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

@onready var selector_overlay: Control = %SelectorOverlay
@onready var brush_highlight: TextureRect = %BrushHighlight
@onready var left_chevron: TextureRect = %LeftChevron
@onready var right_chevron: TextureRect = %RightChevron
@onready var btn_new_game: Button = %BtnNewGame
@onready var btn_continue: Button = %BtnContinue
@onready var btn_char_select: Button = %BtnCharSelect
@onready var btn_map: Button = %BtnMap
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit
@onready var btn_credits: Button = %BtnCredits

var _buttons: Array[Button] = []
var _current_index: int = 0
var _move_tween: Tween
var _pulse_tween: Tween
var _shake_tween: Tween
var _blink_tween: Tween
var _is_transitioning: bool = false
var _sfx_move: AudioStream
var _sfx_confirm: AudioStream
var _sfx_denied: AudioStream


func _ready() -> void:
	_buttons = [btn_new_game, btn_continue, btn_char_select, btn_map, btn_settings, btn_quit]
	_generate_audio_effects()
	_setup_hitboxes()

	# Chevrons (< e >) eliminados permanentemente tanto no PC quanto no Mobile
	if left_chevron != null:
		left_chevron.visible = false
	if right_chevron != null:
		right_chevron.visible = false

	if aspect_wrapper != null:
		aspect_wrapper.resized.connect(_on_aspect_wrapper_resized)

	if _is_mobile_runtime():
		_apply_mobile_fullscreen()
		var nav_layer := get_node_or_null("MobileNavigationLayer") as CanvasLayer
		if nav_layer != null:
			nav_layer.visible = false
		if brush_highlight != null:
			brush_highlight.visible = false

	# Aguarda frame para o sistema de layout do Godot resolver os tamanhos e posições reais
	await get_tree().process_frame
	if _is_mobile_runtime():
		_set_selected_index(-1, false)
	else:
		_set_selected_index(0, false)
		_start_idle_pulse()


func _input(event: InputEvent) -> void:
	# O toque nativo é tratado antes da conversão opcional para mouse do Godot.
	# Um único toque na opção executa a ação imediatamente com feedback tátil visual.
	if not _is_mobile_runtime() or _is_transitioning:
		return
	if not (event is InputEventScreenTouch and event.pressed and event.index == 0):
		return

	var touch_position: Vector2 = event.position
	if _is_mobile_dock_touch(touch_position):
		return

	for idx in range(_buttons.size()):
		var menu_button: Button = _buttons[idx]
		if menu_button == null or not menu_button.is_visible_in_tree():
			continue
		if menu_button.get_global_rect().has_point(touch_position):
			_safe_handle_input()
			if menu_button.disabled:
				# Opções desabilitadas (Personagens e Configurações):
				# A princípio ao clicar nada acontece, exatamente igual ao desktop
				return
			_set_selected_index(idx, false)
			_activate_option(idx)
			return


func _is_mobile_dock_touch(screen_position: Vector2) -> bool:
	var navigation_layer: CanvasLayer = get_node_or_null("MobileNavigationLayer") as CanvasLayer
	if navigation_layer == null:
		return false

	for candidate in navigation_layer.find_children("*", "Button", true, false):
		var action_button: Button = candidate as Button
		if action_button != null and action_button.is_visible_in_tree():
			if action_button.get_global_rect().has_point(screen_position):
				return true
	return false


func _is_mobile_runtime() -> bool:
	return MobileScreenAction.is_mobile_runtime()


func _setup_hitboxes() -> void:
	for idx in range(_buttons.size()):
		var b = _buttons[idx]
		if b == null:
			continue
		b.flat = not _is_mobile_runtime()
		b.text = ""
		if _is_mobile_runtime():
			b.anchor_left = 0.25
			b.anchor_right = 0.75
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.mouse_entered.connect(_on_button_hovered.bind(idx))
		b.pressed.connect(_on_button_clicked.bind(idx))

		# Blindagem contra caixas cinzas/apagadas padrão do tema Godot
		var transparent_style := _make_mobile_selector_style(false)
		b.add_theme_stylebox_override("normal", transparent_style)
		b.add_theme_stylebox_override("hover", transparent_style)
		b.add_theme_stylebox_override("pressed", transparent_style)
		b.add_theme_stylebox_override("disabled", transparent_style)
		b.add_theme_stylebox_override("focus", transparent_style)

	if btn_char_select != null:
		btn_char_select.disabled = true
	if btn_settings != null:
		# No mobile e no menu geral, configurações NÃO fica apagada (disabled = false)
		btn_settings.disabled = false


func _apply_mobile_fullscreen() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1280.0, 720.0)

	var dark_base := get_node_or_null("DarkBase") as ColorRect
	if dark_base != null:
		dark_base.color = Color(0.025, 0.035, 0.07, 1.0)
	if aspect_wrapper != null and vp_size.y > 0.0:
		aspect_wrapper.ratio = vp_size.x / vp_size.y
		aspect_wrapper.stretch_mode = AspectRatioContainer.STRETCH_FIT
		aspect_wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		aspect_wrapper.offset_left = 0.0
		aspect_wrapper.offset_top = 0.0
		aspect_wrapper.offset_right = 0.0
		aspect_wrapper.offset_bottom = 0.0
	if background_slot != null:
		background_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background_slot.stretch_mode = TextureRect.STRETCH_SCALE
		background_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background_slot.offset_left = 0.0
		background_slot.offset_top = 0.0
		background_slot.offset_right = 0.0
		background_slot.offset_bottom = 0.0
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_mobile_fullscreen):
		get_viewport().size_changed.connect(_apply_mobile_fullscreen)


func _on_aspect_wrapper_resized() -> void:
	if _is_mobile_runtime() and aspect_wrapper != null:
		var vp_size: Vector2 = get_viewport_rect().size
		if vp_size.y > 0.0:
			var target_ratio: float = vp_size.x / vp_size.y
			if absf(aspect_wrapper.ratio - target_ratio) > 0.001:
				aspect_wrapper.ratio = target_ratio
	_update_selector_positions(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_S or event.keycode == KEY_DOWN)):
		_move_selection(1)
		_safe_handle_input()
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_W or event.keycode == KEY_UP)):
		_move_selection(-1)
		_safe_handle_input()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		_activate_option(_current_index)
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_play_sound(_sfx_denied)
		get_tree().change_scene_to_file(TITLE_SCREEN_SCENE)


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _move_selection(delta: int) -> void:
	var next_idx = (_current_index + delta) % 6
	if next_idx < 0:
		next_idx += 6
	_set_selected_index(next_idx, true)


func _on_button_hovered(index: int) -> void:
	if _is_mobile_runtime():
		return # No mobile não há hover
	if _current_index != index:
		_set_selected_index(index, true)


func _on_button_clicked(index: int) -> void:
	if index >= 0 and index < _buttons.size():
		var btn = _buttons[index]
		if btn != null and btn.disabled:
			# Opção desabilitada: nada acontece
			return
	_set_selected_index(index, true)
	_activate_option(index)


func _set_selected_index(new_idx: int, animate: bool = false) -> void:
	if new_idx < 0:
		_current_index = -1
		if brush_highlight != null:
			brush_highlight.visible = false
		if _is_mobile_runtime():
			for i in range(_buttons.size()):
				var menu_button: Button = _buttons[i]
				if menu_button != null:
					menu_button.add_theme_stylebox_override("normal", _make_mobile_selector_style(false))
					menu_button.add_theme_stylebox_override("hover", _make_mobile_selector_style(false))
					menu_button.add_theme_stylebox_override("pressed", _make_mobile_selector_style(false))
		return

	_current_index = clampi(new_idx, 0, 5)
	_update_selector_positions(animate)
	if not _is_mobile_runtime():
		_start_idle_pulse()

	if _is_mobile_runtime():
		for i in range(_buttons.size()):
			var menu_button: Button = _buttons[i]
			if menu_button != null:
				var selected := i == _current_index
				menu_button.add_theme_stylebox_override("normal", _make_mobile_selector_style(selected))
				menu_button.add_theme_stylebox_override("hover", _make_mobile_selector_style(selected))
				menu_button.add_theme_stylebox_override("pressed", _make_mobile_selector_style(selected))


func _calculate_selector_transforms(index: int) -> Dictionary:
	if aspect_wrapper == null or index < 0 or index >= OPTION_CONFIGS.size():
		return {}
	var view_size: Vector2 = aspect_wrapper.size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return {}

	var sx: float = view_size.x / BASE_WIDTH
	var sy: float = view_size.y / BASE_HEIGHT

	var cfg: Dictionary = OPTION_CONFIGS[index]
	var target_cy: float = float(cfg["cy"]) * sy
	var target_bx: float = float(cfg["bx"]) * sx
	var target_bw: float = float(cfg["bw"]) * sx
	var brush_h: float = 60.0 * sy

	return {
		"brush_pos": Vector2(target_bx, target_cy - (brush_h * 0.5)),
		"brush_size": Vector2(target_bw, brush_h)
	}


func _update_selector_positions(animate: bool = false) -> void:
	if _is_mobile_runtime():
		# No mobile, o seletor fica oculto durante o repouso para exibição limpa da arte
		if brush_highlight != null and not _is_transitioning:
			brush_highlight.visible = false
		return

	if aspect_wrapper == null or brush_highlight == null:
		return
	if _current_index < 0 or _current_index >= OPTION_CONFIGS.size():
		return

	var transforms: Dictionary = _calculate_selector_transforms(_current_index)
	if transforms.is_empty():
		return

	brush_highlight.visible = true
	brush_highlight.pivot_offset = transforms["brush_size"] * 0.5

	# Ajusta tom de cor: âmbar suave para opções normais, grafite para desabilitadas
	var base_color: Color = Color(1.3, 1.15, 0.75, 0.95)
	if _current_index == 2: # Personagens (2) (desabilitada)
		base_color = Color(0.55, 0.55, 0.60, 0.45)

	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()

	if animate:
		_move_tween = create_tween().set_parallel(true)
		_move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_move_tween.tween_property(brush_highlight, "position", transforms["brush_pos"], 0.10)
		_move_tween.tween_property(brush_highlight, "size", transforms["brush_size"], 0.10)
		_move_tween.tween_property(brush_highlight, "modulate", base_color, 0.10)
		_play_sound(_sfx_move)
	else:
		brush_highlight.position = transforms["brush_pos"]
		brush_highlight.size = transforms["brush_size"]
		brush_highlight.modulate = base_color


func _make_mobile_selector_style(_selected: bool = false) -> StyleBoxFlat:
	# No mobile, os botões são hitboxes transparentes sobre a arte oficial sem molduras retangulares.
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.shadow_color = Color.TRANSPARENT
	style.shadow_size = 0
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	return style


func _play_selection_feedback(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	if brush_highlight == null:
		return

	var transforms: Dictionary = _calculate_selector_transforms(index)
	if transforms.is_empty():
		return

	# Interrompe tweens anteriores de movimento ou pulso
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()

	brush_highlight.visible = true
	brush_highlight.position = transforms["brush_pos"]
	brush_highlight.size = transforms["brush_size"]
	brush_highlight.pivot_offset = transforms["brush_size"] * 0.5

	# Feedback de confirmação Arcade Premium (tanto no PC quanto no Mobile):
	# Piscar rápido com pico de luminosidade e sutil punch de escala na pincelada dourada.
	# ZERO retângulos ou molduras compridas — apenas a iluminação brilhante da própria arte.
	_blink_tween = create_tween()
	# 1. Pico de impacto inicial (flash branco-ouro + leve expansão punch)
	_blink_tween.parallel().tween_property(brush_highlight, "modulate", Color(2.6, 2.3, 1.4, 1.0), 0.05)
	_blink_tween.parallel().tween_property(brush_highlight, "scale", Vector2(1.03, 1.08), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. Queda rápida de contraste (strobe dip)
	_blink_tween.chain().tween_property(brush_highlight, "modulate", Color(0.8, 0.7, 0.4, 0.25), 0.05)
	_blink_tween.parallel().tween_property(brush_highlight, "scale", Vector2.ONE, 0.05)

	# 3. Segundo flash de confirmação
	_blink_tween.chain().tween_property(brush_highlight, "modulate", Color(2.3, 2.0, 1.2, 1.0), 0.05)

	# 4. Assentamento estável em ouro luminoso para a transição
	_blink_tween.chain().tween_property(brush_highlight, "modulate", Color(1.6, 1.4, 0.8, 0.95), 0.08)


func _start_idle_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	if _is_mobile_runtime() or brush_highlight == null:
		return

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(brush_highlight, "modulate:a", 0.70, 0.45).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(brush_highlight, "modulate:a", 1.00, 0.45).set_trans(Tween.TRANS_SINE)


func _activate_option(index: int) -> void:
	if _is_transitioning:
		return

	if index == 2 or index == 4: # PERSONAGENS (2) e CONFIGURAÇÕES (4) (Desabilitados - a princípio nada acontece)
		return

	_is_transitioning = true
	_play_sound(_sfx_confirm)
	_play_selection_feedback(index)

	# Feedback amigável ao usuário: intervalo de exibição antes da transição de tela
	var delay: float = 0.35
	if index == 5: # SAIR
		delay = 0.25
	var timer := get_tree().create_timer(delay)
	await timer.timeout

	match index:
		0: # NOVO JOGO
			var session = get_node_or_null("/root/GameSession")
			if session != null and session.has_method("reset_session"):
				session.reset_session()
			get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

		1: # CONTINUAR
			get_tree().change_scene_to_file(CONTINUE_SCENE)

		2: # PERSONAGENS
			get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

		3: # MAPA
			var session_map = get_node_or_null("/root/GameSession")
			if session_map != null:
				session_map.set_meta("map_entry_context", "browse")
			get_tree().change_scene_to_file(MAP_MENU_SCENE)

		5: # SAIR
			if _is_mobile_runtime():
				_quit_mobile_game()
			else:
				get_tree().quit()


## Encerra o app nativo. No Web mobile, o shell tenta fechar a janela e
## apresenta uma tela de encerramento caso o navegador bloqueie window.close().
func _quit_mobile_game() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (typeof window.sakasQuitGame === 'function') { window.sakasQuitGame(); }")
	get_tree().quit()


func _deny_action(_reason: String) -> void:
	_play_sound(_sfx_denied)
	# Efeito de shake sutil na tela para feedback arcade imediato
	if aspect_wrapper != null:
		if _shake_tween != null and _shake_tween.is_valid():
			_shake_tween.kill()
		_shake_tween = create_tween()
		var orig_pos: Vector2 = aspect_wrapper.position
		_shake_tween.tween_property(aspect_wrapper, "position:x", orig_pos.x - 8.0, 0.04)
		_shake_tween.tween_property(aspect_wrapper, "position:x", orig_pos.x + 8.0, 0.04)
		_shake_tween.tween_property(aspect_wrapper, "position:x", orig_pos.x - 4.0, 0.04)
		_shake_tween.tween_property(aspect_wrapper, "position:x", orig_pos.x, 0.04)


func _play_sound(stream: AudioStream) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()


func _generate_audio_effects() -> void:
	if ResourceLoader.exists("res://assets/audio/sfx/Mover Cursor_sfx_move.mp3"):
		_sfx_move = load("res://assets/audio/sfx/Mover Cursor_sfx_move.mp3")
	else:
		_sfx_move = _create_wav(720.0, 0.04, 0.3)

	if ResourceLoader.exists("res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3"):
		_sfx_confirm = load("res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3")
	else:
		_sfx_confirm = _create_wav(1040.0, 0.12, 0.4)

	if ResourceLoader.exists("res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3"):
		_sfx_denied = load("res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3")
	else:
		_sfx_denied = _create_wav(160.0, 0.16, 0.5)


func _create_wav(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var sample_count: int = int(22050.0 * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t = float(i) / 22050.0
		var envelope = 1.0 - (float(i) / float(sample_count))
		var wave = sin(t * freq * TAU)
		var val = (wave * volume * envelope) * 127.0 + 128.0
		data[i] = int(clamp(val, 0.0, 255.0))
	wav.data = data
	return wav
