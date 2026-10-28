class_name MapMenu
extends Control

## Tela de Menu de Mapa com arte oficial 16:9 HD (assets/backgrounds/Mapa.webp).
## Integração com fluxo de campanha (DifficultySelect -> MapMenu -> LoadingScreen/Instruções -> Fase 1)
## e acesso direto via Menu Principal com suporte a mouse, teclado e touch mobile.
## Em estrita conformidade com GAME_RULES.md.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const DIFFICULTY_SELECT_SCENE: String = "res://scenes/ui/difficulty_select.tscn"
const INSTRUCTIONS_SCENE: String = "res://scenes/ui/loading_screen.tscn"

const MAP_IMAGE_PATH: String = "res://assets/backgrounds/Mapa.webp"
const FALLBACK_MAP_IMAGE_PATH: String = "res://assets/backgrounds/mapa.webp"

@onready var background_texture: TextureRect = %BackgroundTexture
@onready var btn_back: Button = %BtnBack
@onready var btn_confirm: Button = %BtnConfirm
@onready var notice_label: Label = %NoticeLabel
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var _is_transitioning: bool = false
var _sfx_confirm: AudioStreamWAV
var _sfx_cancel: AudioStreamWAV


func _ready() -> void:
	_generate_audio_effects()
	_load_background_image()
	_setup_buttons()

	# Oculta aviso em tempo de execução para manter a arte do mapa limpa e imersiva
	if notice_label != null:
		notice_label.visible = false


func _load_background_image() -> void:
	if background_texture == null:
		return

	var tex: Texture2D = null
	if ResourceLoader.exists(MAP_IMAGE_PATH):
		tex = load(MAP_IMAGE_PATH) as Texture2D
	elif ResourceLoader.exists(FALLBACK_MAP_IMAGE_PATH):
		tex = load(FALLBACK_MAP_IMAGE_PATH) as Texture2D

	if tex == null:
		for path_to_try in [MAP_IMAGE_PATH, FALLBACK_MAP_IMAGE_PATH]:
			var global_p := ProjectSettings.globalize_path(path_to_try)
			if FileAccess.file_exists(global_p):
				var img := Image.load_from_file(global_p)
				if img != null:
					tex = ImageTexture.create_from_image(img)
					tex.resource_path = path_to_try
					break

	if tex != null:
		background_texture.texture = tex


func _setup_buttons() -> void:
	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)
		btn_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if btn_confirm != null:
		btn_confirm.pressed.connect(_on_confirm_pressed)
		btn_confirm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_safe_handle_input()
		_on_confirm_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_on_back_pressed()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_safe_handle_input()
		_on_confirm_pressed()


func _on_back_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sound(_sfx_cancel)
	_safe_handle_input()

	var session = get_node_or_null("/root/GameSession")
	var is_in_game_flow: bool = (session != null and "difficulty_id" in session and session.difficulty_id != "")
	var target_scene := DIFFICULTY_SELECT_SCENE if is_in_game_flow else MAIN_MENU_SCENE

	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		err = get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		if err != OK:
			_is_transitioning = false
			printerr("Erro ao retornar do mapa: ", err)


func _on_confirm_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sound(_sfx_confirm)
	_safe_handle_input()

	var session = get_node_or_null("/root/GameSession")
	if session != null:
		if not ("selected_character_id" in session) or session.selected_character_id == "":
			session.selected_character_id = "guilherme"
		if not ("difficulty_id" in session) or session.difficulty_id == "":
			session.difficulty_id = "normal"

	var err := get_tree().change_scene_to_file(INSTRUCTIONS_SCENE)
	if err != OK:
		_is_transitioning = false
		printerr("Erro ao transicionar para instruções da fase: ", err)


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _play_sound(stream: AudioStreamWAV) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()


func _generate_audio_effects() -> void:
	_sfx_confirm = _create_wav(1040.0, 0.12, 0.40)
	_sfx_cancel = _create_wav(160.0, 0.14, 0.40)


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
		var sample: float = sin(t * freq * TAU) * volume * envelope
		var byte_val: int = clampi(int(sample * 127.0 + 128.0), 0, 255)
		data[i] = byte_val
	wav.data = data
	return wav
