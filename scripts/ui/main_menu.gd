class_name MainMenu
extends Control

## Menu Principal com arte neutra 16:9 HD (menu_state_vf.webp) e seletor dinâmico overlay.
## Em estrita conformidade com GAME_RULES.md (Persona Senior Front-End e Arquitetura UI).

const TITLE_SCREEN_SCENE: String = "res://scenes/ui/title_screen.tscn"
const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const CREDITS_SCENE: String = "res://scenes/ui/credits.tscn"

const BASE_WIDTH: float = 1920.0
const BASE_HEIGHT: float = 1080.0

## Coordenadas calibradas com precisão milimétrica no espaço 1920x1080 da arte menu_state_vf.webp:
## cy: centro vertical exato do texto
## lx: coordenada X do chevron esquerdo '<'
## rx: coordenada X do chevron direito '>' emoldurando o texto
## bx: coordenada X inicial da pincelada de realce
## bw: largura da pincelada de realce
const OPTION_CONFIGS: Array[Dictionary] = [
	{ "cy": 540.5, "lx": 715.0, "rx": 1015.0, "bx": 690.0, "bw": 400.0 }, # 0: NOVO JOGO
	{ "cy": 615.0, "lx": 715.0, "rx": 985.0,  "bx": 690.0, "bw": 370.0 }, # 1: CONTINUAR
	{ "cy": 690.0, "lx": 715.0, "rx": 1175.0, "bx": 690.0, "bw": 550.0 }, # 2: SELECIONAR PERSONAGENS
	{ "cy": 762.5, "lx": 715.0, "rx": 880.0,  "bx": 690.0, "bw": 270.0 }, # 3: MAPA
	{ "cy": 833.5, "lx": 715.0, "rx": 1055.0, "bx": 690.0, "bw": 440.0 }, # 4: CONFIGURAÇÕES
	{ "cy": 908.5, "lx": 715.0, "rx": 870.0,  "bx": 690.0, "bw": 260.0 }  # 5: SAIR
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

var _sfx_move: AudioStreamWAV
var _sfx_confirm: AudioStreamWAV
var _sfx_denied: AudioStreamWAV


func _ready() -> void:
	_buttons = [btn_new_game, btn_continue, btn_char_select, btn_map, btn_settings, btn_quit]
	_generate_audio_effects()
	_setup_hitboxes()

	if aspect_wrapper != null:
		aspect_wrapper.resized.connect(_on_aspect_wrapper_resized)

	# Aguarda frame para o sistema de layout do Godot resolver os tamanhos e posições reais
	await get_tree().process_frame
	_set_selected_index(0, false)
	_start_idle_pulse()


func _setup_hitboxes() -> void:
	for idx in range(_buttons.size()):
		var b = _buttons[idx]
		if b == null:
			continue
		b.flat = true
		b.text = ""
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.mouse_entered.connect(_on_button_hovered.bind(idx))
		b.pressed.connect(_on_button_clicked.bind(idx))

	if btn_continue != null:
		btn_continue.disabled = true
	if btn_map != null:
		btn_map.disabled = true
	if btn_settings != null:
		btn_settings.disabled = true


func _on_aspect_wrapper_resized() -> void:
	_update_selector_positions(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_S or event.keycode == KEY_DOWN)):
		_move_selection(1)
		_safe_handle_input()
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_W or event.keycode == KEY_UP)):
		_move_selection(-1)
		_safe_handle_input()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
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
	if _current_index != index:
		_set_selected_index(index, true)


func _on_button_clicked(index: int) -> void:
	_activate_option(index)


func _set_selected_index(new_idx: int, animate: bool = false) -> void:
	_current_index = clampi(new_idx, 0, 5)
	_update_selector_positions(animate)


func _update_selector_positions(animate: bool = false) -> void:
	if aspect_wrapper == null or left_chevron == null or right_chevron == null or brush_highlight == null:
		return

	var view_size: Vector2 = aspect_wrapper.size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return

	if _current_index < 0 or _current_index >= OPTION_CONFIGS.size():
		return

	var sx: float = view_size.x / BASE_WIDTH
	var sy: float = view_size.y / BASE_HEIGHT

	var cfg: Dictionary = OPTION_CONFIGS[_current_index]
	var target_cy: float = float(cfg["cy"]) * sy
	var target_lx: float = float(cfg["lx"]) * sx
	var target_rx: float = float(cfg["rx"]) * sx
	var target_bx: float = float(cfg["bx"]) * sx
	var target_bw: float = float(cfg["bw"]) * sx

	var chev_h: float = 65.0 * sy
	var chev_w: float = 90.0 * sx
	var brush_h: float = 75.0 * sy

	# Alinhamento vertical centralizado rigorosamente na linha do texto
	var l_pos = Vector2(target_lx, target_cy - (chev_h * 0.5))
	var r_pos = Vector2(target_rx, target_cy - (chev_h * 0.5))
	var b_pos = Vector2(target_bx, target_cy - (brush_h * 0.5))
	var b_size = Vector2(target_bw, brush_h)

	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()

	if animate:
		_move_tween = create_tween().set_parallel(true)
		_move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_move_tween.tween_property(left_chevron, "position", l_pos, 0.12)
		_move_tween.tween_property(right_chevron, "position", r_pos, 0.12)
		_move_tween.tween_property(brush_highlight, "position", b_pos, 0.12)
		_move_tween.tween_property(brush_highlight, "size", b_size, 0.12)
		_play_sound(_sfx_move)
	else:
		left_chevron.position = l_pos
		left_chevron.size = Vector2(chev_w, chev_h)
		right_chevron.position = r_pos
		right_chevron.size = Vector2(chev_w, chev_h)
		brush_highlight.position = b_pos
		brush_highlight.size = b_size


func _start_idle_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(brush_highlight, "modulate:a", 0.70, 0.45).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(brush_highlight, "modulate:a", 1.00, 0.45).set_trans(Tween.TRANS_SINE)


func _activate_option(index: int) -> void:
	match index:
		0: # NOVO JOGO
			_play_sound(_sfx_confirm)
			var session = get_node_or_null("/root/GameSession")
			if session != null and session.has_method("reset_session"):
				session.reset_session()
			get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

		1: # CONTINUAR (Desabilitado)
			_deny_action("Continuar indisponível no momento.")

		2: # SELECIONAR PERSONAGENS
			_play_sound(_sfx_confirm)
			get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

		3: # MAPA (Desabilitado)
			_deny_action("Modo Mapa em desenvolvimento.")

		4: # CONFIGURAÇÕES (Desabilitado)
			_deny_action("Configurações em desenvolvimento.")

		5: # SAIR
			_play_sound(_sfx_confirm)
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


func _play_sound(stream: AudioStreamWAV) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()


func _generate_audio_effects() -> void:
	_sfx_move = _create_wav(720.0, 0.04, 0.3)
	_sfx_confirm = _create_wav(1040.0, 0.12, 0.4)
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
