class_name MainMenu
extends Control

## Menu Principal com arte de fundo e navegação direta baseada em imagem.
## Cada opção selecionada reflete a pincelada vermelha oficial nos menus da arte menu.jpg.

const TITLE_SCREEN_SCENE: String = "res://scenes/ui/title_screen.tscn"
const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const CREDITS_SCENE: String = "res://scenes/ui/credits.tscn"

const STATE_TEXTURES: Array[String] = [
	"res://assets/backgrounds/menu_states/menu_state_0.png", # 0: Novo Jogo
	"res://assets/backgrounds/menu_states/menu_state_1.png", # 1: Continuar
	"res://assets/backgrounds/menu_states/menu_state_2.png", # 2: Seleção de Personagens
	"res://assets/backgrounds/menu_states/menu_state_3.png", # 3: Mapa
	"res://assets/backgrounds/menu_states/menu_state_4.png", # 4: Configurações
	"res://assets/backgrounds/menu_states/menu_state_5.png"  # 5: Sair
]

@onready var background_slot: TextureRect = %BackgroundSlot
@onready var aspect_wrapper: AspectRatioContainer = %AspectWrapper
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

@onready var btn_new_game: Button = %BtnNewGame
@onready var btn_continue: Button = %BtnContinue
@onready var btn_char_select: Button = %BtnCharSelect
@onready var btn_map: Button = %BtnMap
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit
@onready var btn_credits: Button = %BtnCredits

var _textures: Array[Texture2D] = []
var _current_index: int = 0
var _shake_tween: Tween

var _sfx_move: AudioStreamWAV
var _sfx_confirm: AudioStreamWAV
var _sfx_denied: AudioStreamWAV


func _ready() -> void:
	_load_state_textures()
	_generate_audio_effects()
	_setup_hitboxes()
	_set_selected_index(0, false)


func _load_state_textures() -> void:
	_textures.clear()
	for path in STATE_TEXTURES:
		var tex = load(path) as Texture2D
		if tex != null:
			_textures.append(tex)
		else:
			var fallback = load("res://assets/backgrounds/menu.jpg") as Texture2D
			_textures.append(fallback)


func _setup_hitboxes() -> void:
	var buttons = [btn_new_game, btn_continue, btn_char_select, btn_map, btn_settings, btn_quit]
	for idx in range(buttons.size()):
		var b = buttons[idx]
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_S or event.keycode == KEY_DOWN)):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_W or event.keycode == KEY_UP)):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
		_activate_option(_current_index)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_play_sound(_sfx_denied)
		get_tree().change_scene_to_file(TITLE_SCREEN_SCENE)
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


func _set_selected_index(new_idx: int, _play_sfx: bool = false) -> void:
	_current_index = new_idx
	if background_slot != null and new_idx < _textures.size() and _textures[new_idx] != null:
		background_slot.texture = _textures[new_idx]


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

		2: # SELEÇÃO DE PERSONAGENS
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
