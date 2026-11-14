class_name StageSectionSelect
extends Control

## Modal de Seleção de Seções / Mapas do Estágio 1 — Projeto Sakas
## Visual Dark Premium Medieval / Neo-16-bit Urban Arcade
## Permite ao jogador escolher e jogar qualquer um dos 4 mapas da Fase 1
## após ter concluído o estágio durante a gameplay (ou em campanha salva).

signal section_selected(scene_path: String, section_name: String)
signal closed()

const SFX_MOVE_PATH := "res://assets/audio/sfx/Mover Cursor_sfx_move.mp3"
const SFX_CONFIRM_PATH := "res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3"
const SFX_CANCEL_PATH := "res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3"

const SECTIONS: Array[Dictionary] = [
	{
		"id": "1-1",
		"title": "A ENTRADA DA RUA",
		"subtitle": "Locadora · Início da Jornada",
		"scene": "res://scenes/levels/map_1.tscn"
	},
	{
		"id": "1-2",
		"title": "BALCÃO DA LOCADORA",
		"subtitle": "Interior da Loja · Primeiros Capangas",
		"scene": "res://scenes/levels/map_2.tscn"
	},
	{
		"id": "1-3",
		"title": "TRAVESSA DA LOCADORA",
		"subtitle": "Beco Externo · Emboscada e Agressores",
		"scene": "res://scenes/levels/map_3.tscn"
	},
	{
		"id": "1-4",
		"title": "O BECO FINAL",
		"subtitle": "Bar da Vila · Clímax & Chefe Alessandro",
		"scene": "res://scenes/levels/map_4.tscn"
	}
]

@onready var dim_overlay: ColorRect = get_node_or_null("%DimOverlay") as ColorRect
@onready var panel_container: PanelContainer = get_node_or_null("%PanelContainer") as PanelContainer
@onready var btn_close: Button = get_node_or_null("%BtnClose") as Button
@onready var btn_back: Button = get_node_or_null("%BtnBack") as Button
@onready var buttons_vbox: VBoxContainer = get_node_or_null("%ButtonsVBox") as VBoxContainer

var _sfx_move: AudioStream
var _sfx_confirm: AudioStream
var _sfx_cancel: AudioStream
var _audio_player: AudioStreamPlayer
var _section_buttons: Array[Button] = []


func _ready() -> void:
	_resolve_nodes()
	_init_audio()
	_setup_buttons()

	if dim_overlay != null:
		dim_overlay.gui_input.connect(_on_dim_overlay_input)
	if btn_close != null:
		btn_close.pressed.connect(_on_close_pressed)
	if btn_back != null:
		btn_back.pressed.connect(_on_close_pressed)


func _resolve_nodes() -> void:
	if dim_overlay == null:
		dim_overlay = get_node_or_null("DimOverlay") as ColorRect
	if panel_container == null:
		panel_container = get_node_or_null("CenterContainer/PanelContainer") as PanelContainer
	if btn_close == null:
		btn_close = get_node_or_null("CenterContainer/PanelContainer/Margin/MainVBox/HeaderHBox/BtnClose") as Button
	if btn_back == null:
		btn_back = get_node_or_null("CenterContainer/PanelContainer/Margin/MainVBox/FooterHBox/BtnBack") as Button
	if buttons_vbox == null:
		buttons_vbox = get_node_or_null("CenterContainer/PanelContainer/Margin/MainVBox/ButtonsVBox") as VBoxContainer


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


func _setup_buttons() -> void:
	_section_buttons.clear()
	if buttons_vbox == null:
		return

	var children := buttons_vbox.get_children()
	for i in range(mini(children.size(), SECTIONS.size())):
		var btn := children[i] as Button
		if btn == null:
			continue
		var section_data: Dictionary = SECTIONS[i]
		var scene_path: String = str(section_data["scene"])
		var sec_name: String = str(section_data["title"])

		btn.mouse_entered.connect(func(): _play_sound(_sfx_move))
		btn.focus_entered.connect(func(): _play_sound(_sfx_move))
		btn.pressed.connect(func(): _on_section_pressed(scene_path, sec_name))
		_section_buttons.append(btn)


func open() -> void:
	visible = true
	modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)

	if not _section_buttons.is_empty() and _section_buttons[0] != null:
		_section_buttons[0].grab_focus()

	_play_sound(_sfx_move)


func close() -> void:
	_play_sound(_sfx_cancel)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
	await tw.finished
	visible = false
	closed.emit()


func _on_close_pressed() -> void:
	close()


func _on_dim_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
	elif event is InputEventScreenTouch and event.pressed:
		close()


func _on_section_pressed(scene_path: String, sec_name: String) -> void:
	_play_sound(_sfx_confirm)
	visible = false
	section_selected.emit(scene_path, sec_name)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		close()


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _play_sound(stream: AudioStream) -> void:
	if _audio_player != null and stream != null:
		_audio_player.stream = stream
		_audio_player.play()
