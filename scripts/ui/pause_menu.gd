class_name PauseMenu
extends CanvasLayer

## Menu de Pausa In-Game — Projeto Sakas
## Visual Transparente "Dark Premium Medieval" com suporte completo a Teclado, Mouse e Gamepad.
## Opções: Continuar / Salvar (com seletor de Slots 1 a 4) / Configurações / Sair

signal resumed()
signal saved(slot_idx: int)
signal quit_to_menu()

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

@onready var background_dim: ColorRect = %BackgroundDim
@onready var main_panel: PanelContainer = %MainPanel
@onready var title_label: Label = %TitleLabel
@onready var status_label: Label = %StatusLabel

@onready var buttons_box: VBoxContainer = %ButtonsBox
@onready var btn_resume: Button = %BtnResume
@onready var btn_save: Button = %BtnSave
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit

@onready var save_slots_box: VBoxContainer = %SaveSlotsBox
@onready var btn_slot_1_save: Button = %BtnSlot1Save
@onready var btn_slot_2_save: Button = %BtnSlot2Save
@onready var btn_slot_3_save: Button = %BtnSlot3Save
@onready var btn_slot_4_save: Button = %BtnSlot4Save
@onready var btn_back_slot_save: Button = %BtnBackSlotSave

@onready var settings_box: VBoxContainer = %SettingsBox
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value_label: Label = %VolumeValueLabel
@onready var btn_back_settings: Button = %BtnBackSettings

@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var _current_level_path: String = ""
var _selected_button_index: int = 0
var _nav_buttons: Array[Button] = []
var _slot_buttons: Array[Button] = []
var _selected_slot_index: int = 0

var _is_in_slots: bool = false
var _is_in_settings: bool = false

var _sfx_move: AudioStreamWAV
var _sfx_confirm: AudioStreamWAV
var _sfx_cancel: AudioStreamWAV


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_generate_audio_effects()
	_setup_buttons()
	_setup_slot_buttons()
	_setup_volume_controls()


func _setup_buttons() -> void:
	# Ordem canônica rigorosa: 0=Continuar, 1=Salvar, 2=Configurações, 3=Sair
	_nav_buttons = [btn_resume, btn_save, btn_settings, btn_quit]

	for i in range(_nav_buttons.size()):
		var btn := _nav_buttons[i]
		if btn != null:
			btn.mouse_entered.connect(_on_btn_hovered.bind(i))
			btn.focus_mode = Control.FOCUS_NONE

	if btn_resume != null:
		btn_resume.pressed.connect(_on_resume_pressed)
	if btn_save != null:
		btn_save.pressed.connect(_on_save_pressed)
	if btn_settings != null:
		btn_settings.pressed.connect(_on_settings_pressed)
	if btn_quit != null:
		btn_quit.pressed.connect(_on_quit_pressed)

	if btn_back_settings != null:
		btn_back_settings.pressed.connect(_on_back_settings_pressed)


func _setup_slot_buttons() -> void:
	_slot_buttons = [btn_slot_1_save, btn_slot_2_save, btn_slot_3_save, btn_slot_4_save, btn_back_slot_save]

	for i in range(_slot_buttons.size()):
		var btn := _slot_buttons[i]
		if btn != null:
			btn.mouse_entered.connect(_on_slot_btn_hovered.bind(i))
			btn.focus_mode = Control.FOCUS_NONE

	if btn_slot_1_save != null:
		btn_slot_1_save.pressed.connect(func(): _save_to_slot(1))
	if btn_slot_2_save != null:
		btn_slot_2_save.pressed.connect(func(): _save_to_slot(2))
	if btn_slot_3_save != null:
		btn_slot_3_save.pressed.connect(func(): _save_to_slot(3))
	if btn_slot_4_save != null:
		btn_slot_4_save.pressed.connect(func(): _save_to_slot(4))
	if btn_back_slot_save != null:
		btn_back_slot_save.pressed.connect(_on_back_slot_save_pressed)


func _setup_volume_controls() -> void:
	if volume_slider != null:
		var bus_idx := AudioServer.get_bus_index("Master")
		if bus_idx >= 0:
			var db_val := AudioServer.get_bus_volume_db(bus_idx)
			var linear_val := db_to_linear(db_val)
			volume_slider.value = linear_val * 100.0
		volume_slider.value_changed.connect(_on_volume_changed)
		_update_volume_label(volume_slider.value)


func open_pause(level_path: String = "") -> void:
	_current_level_path = level_path
	if _current_level_path == "" and get_tree().current_scene != null:
		_current_level_path = get_tree().current_scene.scene_file_path

	_is_in_settings = false
	_is_in_slots = false

	if buttons_box != null:
		buttons_box.visible = true
	if save_slots_box != null:
		save_slots_box.visible = false
	if settings_box != null:
		settings_box.visible = false
	if status_label != null:
		status_label.text = ""

	# Inicia no Continuar (índice 0). Pressionar baixo vai diretamente para Salvar (índice 1).
	_selected_button_index = 0
	_update_button_focus()

	visible = true
	get_tree().paused = true
	_play_sound(_sfx_confirm)


func resume_game() -> void:
	_play_sound(_sfx_cancel)
	visible = false
	get_tree().paused = false
	resumed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		if _is_in_slots:
			_on_back_slot_save_pressed()
		elif _is_in_settings:
			_on_back_settings_pressed()
		else:
			resume_game()
		return

	if _is_in_slots:
		_handle_slots_input(event)
		return

	if _is_in_settings:
		_handle_settings_input(event)
		return

	# Navegação no menu principal de pausa (Continuar -> Salvar -> Configurações -> Sair)
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_W or event.keycode == KEY_UP)):
		_safe_handle_input()
		_navigate_selection(-1)
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_S or event.keycode == KEY_DOWN)):
		_safe_handle_input()
		_navigate_selection(1)
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		_activate_selected_button()


func _handle_slots_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_W or event.keycode == KEY_UP)):
		_safe_handle_input()
		_navigate_slot_selection(-1)
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_S or event.keycode == KEY_DOWN)):
		_safe_handle_input()
		_navigate_slot_selection(1)
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		_activate_selected_slot()


func _handle_settings_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_A or event.keycode == KEY_LEFT)):
		_safe_handle_input()
		if volume_slider != null:
			volume_slider.value = clampf(volume_slider.value - 5.0, 0.0, 100.0)
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_D or event.keycode == KEY_RIGHT)):
		_safe_handle_input()
		if volume_slider != null:
			volume_slider.value = clampf(volume_slider.value + 5.0, 0.0, 100.0)
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		_on_back_settings_pressed()


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _navigate_selection(delta: int) -> void:
	if _nav_buttons.is_empty():
		return
	_selected_button_index = (_selected_button_index + delta) % _nav_buttons.size()
	if _selected_button_index < 0:
		_selected_button_index += _nav_buttons.size()
	_update_button_focus()
	_play_sound(_sfx_move)


func _navigate_slot_selection(delta: int) -> void:
	if _slot_buttons.is_empty():
		return
	_selected_slot_index = (_selected_slot_index + delta) % _slot_buttons.size()
	if _selected_slot_index < 0:
		_selected_slot_index += _slot_buttons.size()
	_update_slot_button_focus()
	_play_sound(_sfx_move)


func _on_btn_hovered(index: int) -> void:
	if _selected_button_index != index:
		_selected_button_index = index
		_update_button_focus()
		_play_sound(_sfx_move)


func _on_slot_btn_hovered(index: int) -> void:
	if _selected_slot_index != index:
		_selected_slot_index = index
		_update_slot_button_focus()
		_play_sound(_sfx_move)


func _update_button_focus() -> void:
	for i in range(_nav_buttons.size()):
		var btn := _nav_buttons[i]
		if btn == null:
			continue
		if i == _selected_button_index:
			btn.modulate = Color(1.25, 1.15, 0.75, 1.0)
		else:
			btn.modulate = Color(0.85, 0.85, 0.9, 0.85)


func _update_slot_button_focus() -> void:
	for i in range(_slot_buttons.size()):
		var btn := _slot_buttons[i]
		if btn == null:
			continue
		if i == _selected_slot_index:
			btn.modulate = Color(1.25, 1.15, 0.75, 1.0)
		else:
			btn.modulate = Color(0.85, 0.85, 0.9, 0.85)


func _activate_selected_button() -> void:
	match _selected_button_index:
		0: _on_resume_pressed()
		1: _on_save_pressed()
		2: _on_settings_pressed()
		3: _on_quit_pressed()


func _activate_selected_slot() -> void:
	if _selected_slot_index >= 0 and _selected_slot_index <= 3:
		_save_to_slot(_selected_slot_index + 1)
	elif _selected_slot_index == 4:
		_on_back_slot_save_pressed()


func _on_resume_pressed() -> void:
	resume_game()


func _on_save_pressed() -> void:
	_play_sound(_sfx_confirm)
	_is_in_slots = true
	_is_in_settings = false

	if buttons_box != null:
		buttons_box.visible = false
	if settings_box != null:
		settings_box.visible = false
	if save_slots_box != null:
		save_slots_box.visible = true

	_refresh_save_slot_labels()
	_selected_slot_index = 0
	_update_slot_button_focus()


func _refresh_save_slot_labels() -> void:
	var session = get_node_or_null("/root/GameSession")
	var slot_btns: Array[Button] = [btn_slot_1_save, btn_slot_2_save, btn_slot_3_save, btn_slot_4_save]

	for idx in range(4):
		var slot_num: int = idx + 1
		var btn: Button = slot_btns[idx]
		if btn == null:
			continue

		if session != null and session.has_method("has_save_in_slot") and session.has_save_in_slot(slot_num):
			var data: Dictionary = session.get_save_info(slot_num)
			var lvl: String = str(data.get("level_name", "Fase"))
			var date_str: String = str(data.get("date_time", ""))
			btn.text = "SLOT %d: %s (%s)" % [slot_num, lvl, date_str]
			btn.modulate = Color(0.9, 1.0, 0.9, 1.0)
		else:
			btn.text = "SLOT %d: — VAZIO —" % slot_num
			btn.modulate = Color(0.75, 0.75, 0.8, 0.8)


func _save_to_slot(slot_idx: int) -> void:
	_play_sound(_sfx_confirm)
	var session = get_node_or_null("/root/GameSession")
	if session != null and session.has_method("save_game_to_slot"):
		var player = get_tree().get_first_node_in_group("player")
		var cur_hp: float = -1.0
		var cur_sp: float = -1.0
		if player != null:
			if "health_component" in player and player.health_component != null:
				cur_hp = player.health_component.current_health
			if "current_special" in player:
				cur_sp = player.current_special

		# Notificação explícita do slot que está sendo gravado
		_show_status("GRAVANDO NO SLOT %d..." % slot_idx, Color(1.0, 0.85, 0.2, 1.0))

		var ok: bool = session.save_game_to_slot(slot_idx, _current_level_path, cur_hp, cur_sp)
		if ok:
			_show_status("✓ JOGO GRAVADO NO SLOT %d COM SUCESSO!" % slot_idx, Color(0.4, 1.0, 0.5, 1.0))
			saved.emit(slot_idx)
			_refresh_save_slot_labels()
		else:
			_show_status("✗ ERRO AO GRAVAR NO SLOT %d." % slot_idx, Color(1.0, 0.3, 0.3, 1.0))
	else:
		_show_status("Sessão de jogo indisponível.", Color(1.0, 0.8, 0.2, 1.0))


func _on_back_slot_save_pressed() -> void:
	_play_sound(_sfx_cancel)
	_is_in_slots = false
	if save_slots_box != null:
		save_slots_box.visible = false
	if buttons_box != null:
		buttons_box.visible = true
	_update_button_focus()


func _on_settings_pressed() -> void:
	_play_sound(_sfx_confirm)
	_is_in_settings = true
	_is_in_slots = false
	if buttons_box != null:
		buttons_box.visible = false
	if save_slots_box != null:
		save_slots_box.visible = false
	if settings_box != null:
		settings_box.visible = true
	if status_label != null:
		status_label.text = ""


func _on_back_settings_pressed() -> void:
	_play_sound(_sfx_cancel)
	_is_in_settings = false
	if settings_box != null:
		settings_box.visible = false
	if buttons_box != null:
		buttons_box.visible = true
	_update_button_focus()


func _on_quit_pressed() -> void:
	_play_sound(_sfx_confirm)
	visible = false
	get_tree().paused = false
	quit_to_menu.emit()
	var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if err != OK:
		printerr("Erro ao retornar ao menu principal: ", err)


func _on_volume_changed(val: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var linear_val := clampf(val / 100.0, 0.0, 1.0)
		var db_val := linear_to_db(linear_val) if linear_val > 0.001 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db_val)
	_update_volume_label(val)


func _update_volume_label(val: float) -> void:
	if volume_value_label != null:
		volume_value_label.text = "%d%%" % int(val)


func _show_status(text: String, col: Color) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_label.modulate = col


func _play_sound(stream: AudioStreamWAV) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()


func _generate_audio_effects() -> void:
	_sfx_move = _create_wav(680.0, 0.035, 0.25)
	_sfx_confirm = _create_wav(1040.0, 0.10, 0.40)
	_sfx_cancel = _create_wav(180.0, 0.12, 0.40)


func _create_wav(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var sample_count: int = int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t := float(i) / 22050.0
		var envelope := 1.0 - (float(i) / float(sample_count))
		var wave := sin(t * freq * TAU)
		var val := (wave * volume * envelope) * 127.0 + 128.0
		data[i] = int(clamp(val, 0.0, 255.0))
	wav.data = data
	return wav
