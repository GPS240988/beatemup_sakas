class_name SettingsPanel
extends Control

## Painel de Configurações Funcional — Projeto Sakas
## Visual Arcade Neo-16-bit com cantos chanfrados e fundo navy translúcido.
## Controla o bus "Master" do AudioServer em tempo real.
## Suporta contexto de origem ("main_menu" ou "pause_menu") para retorno correto.

signal closed(origin: String)

@export var settings_origin: String = "main_menu"

@onready var panel_container: PanelContainer = %PanelContainer
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value_label: Label = %VolumeValueLabel
@onready var btn_back: Button = %BtnBack
@onready var btn_top_back: Button = get_node_or_null("%BtnTopBack") as Button
@onready var origin_indicator: Label = %OriginIndicator

const SFX_MOVE_PATH := "res://assets/audio/sfx/Mover Cursor_sfx_move.mp3"
const SFX_CONFIRM_PATH := "res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3"
const SFX_CANCEL_PATH := "res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3"

var _sfx_move: AudioStream
var _sfx_confirm: AudioStream
var _sfx_cancel: AudioStream
var _audio_player: AudioStreamPlayer


func _ready() -> void:
	_init_audio()
	_setup_volume_controls()
	_update_origin_display()

	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_top_back != null:
		btn_top_back.pressed.connect(_on_back_pressed)


func _init_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)

	if ResourceLoader.exists(SFX_MOVE_PATH):
		_sfx_move = load(SFX_MOVE_PATH) as AudioStream
	if ResourceLoader.exists(SFX_CONFIRM_PATH):
		_sfx_confirm = load(SFX_CONFIRM_PATH) as AudioStream
	if ResourceLoader.exists(SFX_CANCEL_PATH):
		_sfx_cancel = load(SFX_CANCEL_PATH) as AudioStream


func _setup_volume_controls() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0 and volume_slider != null:
		var current_db := AudioServer.get_bus_volume_db(bus_idx)
		var linear_val := db_to_linear(current_db)
		volume_slider.value = linear_val * 100.0
		_update_volume_label(volume_slider.value)
		volume_slider.value_changed.connect(_on_volume_changed)


func _on_volume_changed(val: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var linear_val := clampf(val / 100.0, 0.0, 1.0)
		var db_val := linear_to_db(linear_val) if linear_val > 0.0001 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db_val)
	_update_volume_label(val)


func _update_volume_label(val: float) -> void:
	if volume_value_label != null:
		volume_value_label.text = "%d%%" % int(round(val))


func _update_origin_display() -> void:
	if origin_indicator != null:
		var origin_text := "MENU PRINCIPAL" if settings_origin == "main_menu" else "JOGO EM PAUSA"
		origin_indicator.text = "ORIGEM: %s" % origin_text


func _on_back_pressed() -> void:
	_play_sfx(_sfx_cancel)
	closed.emit(settings_origin)


func _play_sfx(stream: AudioStream) -> void:
	if _audio_player != null and stream != null:
		_audio_player.stream = stream
		_audio_player.play()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_ESCAPE):
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		_on_back_pressed()
