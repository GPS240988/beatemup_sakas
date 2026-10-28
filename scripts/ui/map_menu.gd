class_name MapMenu
extends Control

## Tela de Menu de Mapa com arte oficial 16:9 HD (assets/backgrounds/Mapa.webp).
## Em estrita conformidade com GAME_RULES.md (Persona Senior Front-End e Arquitetura UI).

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

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

	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_confirm != null:
		btn_confirm.pressed.connect(_on_confirm_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_on_back_pressed()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		_on_confirm_pressed()


func _on_back_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sound(_sfx_cancel)

	_safe_handle_input()
	var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if err != OK:
		_is_transitioning = false
		printerr("Erro ao retornar ao menu principal: ", err)


func _on_confirm_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sound(_sfx_confirm)
	_show_notice("Funcionalidade em desenvolvimento.", Color(1.0, 0.5, 0.3, 1.0))
	_safe_handle_input()
	_is_transitioning = false


func _show_notice(msg: String, col: Color = Color(1.0, 0.35, 0.35, 1.0)) -> void:
	if notice_label != null:
		notice_label.text = msg
		notice_label.modulate = col


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