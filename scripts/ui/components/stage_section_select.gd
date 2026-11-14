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
@onready var eyebrow_label: Label = get_node_or_null("CenterContainer/PanelContainer/Margin/MainVBox/HeaderHBox/TitlesVBox/EyebrowLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("CenterContainer/PanelContainer/Margin/MainVBox/SubtitleLabel") as Label

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
	if eyebrow_label == null:
		eyebrow_label = get_node_or_null("CenterContainer/PanelContainer/Margin/MainVBox/HeaderHBox/TitlesVBox/EyebrowLabel") as Label
	if subtitle_label == null:
		subtitle_label = get_node_or_null("CenterContainer/PanelContainer/Margin/MainVBox/SubtitleLabel") as Label


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

	# Atualiza estado de desbloqueio de cada seção/mapa com base na progressão salva
	_update_section_lock_states()

	if not _section_buttons.is_empty() and _section_buttons[0] != null:
		# Foca no primeiro botão habilitado
		for btn in _section_buttons:
			if btn != null and not btn.disabled:
				btn.grab_focus()
				break

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
	# Bloqueia seleção se o botão clicado estiver desabilitado (mapa bloqueado)
	for i in range(mini(_section_buttons.size(), SECTIONS.size())):
		if str(SECTIONS[i].get("scene", "")) == scene_path:
			if _section_buttons[i] != null and _section_buttons[i].disabled:
				_play_sound(_sfx_cancel)
				return
	_play_sound(_sfx_confirm)
	visible = false
	section_selected.emit(scene_path, sec_name)


## Atualiza o estado visual e funcional dos botões de seção com base no desbloqueio progressivo
func _update_section_lock_states() -> void:
	var session: Node = null
	if is_inside_tree():
		session = get_node_or_null("/root/GameSession")
	if session == null:
		var main_loop = Engine.get_main_loop()
		if main_loop is SceneTree and main_loop.root != null:
			session = main_loop.root.get_node_or_null("GameSession")

	var has_save: bool = false
	var max_m: int = 0
	var is_stage_done: bool = false
	if session != null:
		if session.has_method("has_any_save"):
			has_save = session.has_any_save()
		if "max_unlocked_map" in session:
			max_m = int(session.max_unlocked_map)
		if session.has_method("is_stage_completed"):
			is_stage_done = session.is_stage_completed(1)

	# Atualiza cabeçalho do modal conforme status real de progressão
	if eyebrow_label != null:
		if not has_save or max_m <= 0:
			eyebrow_label.text = "NENHUM SAVE REGISTRADO • MAPAS BLOQUEADOS"
			eyebrow_label.modulate = Color(1.0, 0.45, 0.45, 0.95)
		elif is_stage_done:
			eyebrow_label.text = "ESTÁGIO 01 CONCLUÍDO • SELEÇÃO LIVRE"
			eyebrow_label.modulate = Color(1.0, 0.85, 0.25, 1.0)
		else:
			eyebrow_label.text = "PROGRESSÃO DA CAMPANHA • MAPAS LIBERADOS"
			eyebrow_label.modulate = Color(0.0, 0.94, 1.0, 1.0)

	if subtitle_label != null:
		if not has_save or max_m <= 0:
			subtitle_label.text = "Inicie pelo 'Novo Jogo' no Menu Principal para liberar as seções da fase."
		else:
			subtitle_label.text = "Selecione o mapa desejado para continuar a partida:"

	for i in range(_section_buttons.size()):
		var btn := _section_buttons[i]
		if btn == null:
			continue
		var map_num: int = i + 1  # Mapas de 1 a 4
		var is_unlocked: bool = false

		if session != null and session.has_method("is_map_unlocked"):
			is_unlocked = session.is_map_unlocked(map_num)

		btn.disabled = not is_unlocked

		# Feedback visual: dimming e cursor para mapas bloqueados
		if is_unlocked:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			btn.modulate = Color(0.40, 0.40, 0.45, 0.55)
			btn.mouse_default_cursor_shape = Control.CURSOR_ARROW


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
