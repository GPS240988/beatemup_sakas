class_name QTEPromptOverlay
extends CanvasLayer

## Overlay de Quick Time Event (QTE) multiplataforma (PC Teclado + Mobile Touch).
## Valida uma sequência exata de ações lógicas dentro de uma janela de tempo (padrão 1.5s).

signal qte_succeeded()
signal qte_failed(reason: String)

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const TEX_MOBILE_ATTACK: Texture2D = preload("res://assets/ui/mobile/button_attack.png")

const DEFAULT_SEQUENCE: Array[StringName] = [
	&"move_down",
	&"move_up",
	&"move_right",
	&"move_left",
	&"attack",
]

const MONITORED_ACTIONS: Array[StringName] = [
	&"move_down",
	&"move_up",
	&"move_right",
	&"move_left",
	&"attack",
	&"attack_punch",
	&"jump",
	&"guard",
	&"attack_special",
]

const ACTION_LABELS_PC: Dictionary = {
	&"move_down": "S",
	&"move_up": "W",
	&"move_right": "D",
	&"move_left": "A",
	&"attack": "J",
}

const ACTION_LABELS_MOBILE: Dictionary = {
	&"move_down": "▼",
	&"move_up": "▲",
	&"move_right": "►",
	&"move_left": "◄",
	&"attack": "SOCO",
}

var sequence: Array[StringName] = []
var duration: float = 4.0
var _time_left: float = 4.0
var _current_index: int = 0
var _active: bool = false
var _input_grace_timer: float = 0.0
var _use_mobile_labels: bool = false

var _panel: PanelContainer = null
var _title_label: Label = null
var _timer_bar: ProgressBar = null
var _timer_label: Label = null
var _slots_hbox: HBoxContainer = null
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detect_mobile_mode()
	_build_ui()
	visible = false


func _detect_mobile_mode() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		_use_mobile_labels = true
		return
	var touch_controls := get_tree().get_first_node_in_group("touch_controls")
	if touch_controls != null and touch_controls is CanvasItem and (touch_controls as CanvasItem).visible:
		_use_mobile_labels = true
		return
	_use_mobile_labels = false


func start_qte(custom_sequence: Array[StringName] = [], custom_duration: float = 4.0) -> void:
	_detect_mobile_mode()
	sequence.clear()
	if custom_sequence.is_empty():
		sequence.assign(DEFAULT_SEQUENCE)
	else:
		sequence.assign(custom_sequence)

	duration = maxf(0.25, custom_duration)
	_time_left = duration
	_current_index = 0
	_input_grace_timer = 0.06
	_active = true

	_rebuild_slots()
	_update_visuals()
	visible = true


func cancel_qte() -> void:
	_active = false
	visible = false


func is_qte_active() -> bool:
	return _active


func get_remaining_time() -> float:
	return _time_left


func get_current_index() -> int:
	return _current_index


func _process(delta: float) -> void:
	if not _active:
		return

	if _input_grace_timer > 0.0:
		_input_grace_timer = maxf(0.0, _input_grace_timer - delta)

	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_update_visuals()
		_finish_failed("timeout")
		return

	_update_visuals()


func _input(event: InputEvent) -> void:
	if not _active or _input_grace_timer > 0.0:
		return
	if event == null or event.is_echo():
		return

	for action in MONITORED_ACTIONS:
		if event.is_action_pressed(action, false):
			get_viewport().set_input_as_handled()
			var normalized := _normalize_action(action)
			process_action_input(normalized)
			return


func simulate_action_input(action: StringName) -> void:
	if not _active:
		return
	process_action_input(_normalize_action(action))


func _normalize_action(action: StringName) -> StringName:
	if action == &"attack_punch":
		return &"attack"
	return action


func process_action_input(action: StringName) -> void:
	if not _active:
		return
	if _current_index < 0 or _current_index >= sequence.size():
		return

	var expected: StringName = sequence[_current_index]
	if action == expected:
		_current_index += 1
		_update_visuals()
		if _current_index >= sequence.size():
			_finish_succeeded()
	else:
		_finish_failed("wrong_input")


func _finish_succeeded() -> void:
	_active = false
	visible = false
	qte_succeeded.emit()


func _finish_failed(reason: String) -> void:
	_active = false
	visible = false
	qte_failed.emit(reason)


func _build_ui() -> void:
	var root_center := CenterContainer.new()
	root_center.name = "CenterContainer"
	root_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root_center.offset_top = 86.0
	root_center.offset_bottom = 260.0
	root_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_center)

	_panel = PanelContainer.new()
	_panel.name = "QTEPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.05, 0.09, 0.90)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.83, 0.69, 0.22, 0.95)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.content_margin_left = 22.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 16.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	root_center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	var header_hbox := HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 16)
	header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header_hbox)

	_title_label = Label.new()
	_title_label.text = "DESVIE DA CADEIRADA!"
	_title_label.add_theme_font_override("font", ARCADE_FONT)
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30, 1.0))
	_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_title_label.add_theme_constant_override("outline_size", 4)
	header_hbox.add_child(_title_label)

	_timer_label = Label.new()
	_timer_label.text = "4.0s"
	_timer_label.add_theme_font_override("font", ARCADE_FONT)
	_timer_label.add_theme_font_size_override("font_size", 18)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80, 1.0))
	header_hbox.add_child(_timer_label)

	_slots_hbox = HBoxContainer.new()
	_slots_hbox.name = "SlotsContainer"
	_slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_hbox.add_theme_constant_override("separation", 12)
	_slots_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_slots_hbox)

	_timer_bar = ProgressBar.new()
	_timer_bar.name = "TimerBar"
	_timer_bar.custom_minimum_size = Vector2(360.0, 12.0)
	_timer_bar.show_percentage = false
	_timer_bar.min_value = 0.0
	_timer_bar.max_value = 1.0
	_timer_bar.value = 1.0

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.14, 0.12, 0.18, 0.95)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_right = 4
	bar_bg.corner_radius_bottom_left = 4
	_timer_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.95, 0.78, 0.22, 1.0)
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_right = 4
	bar_fill.corner_radius_bottom_left = 4
	_timer_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_timer_bar)


func _rebuild_slots() -> void:
	for child in _slots_hbox.get_children():
		child.queue_free()
	_slot_panels.clear()
	_slot_labels.clear()

	for i in range(sequence.size()):
		var act: StringName = sequence[i]
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(62.0, 56.0)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_gui_input.bind(act))

		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", ARCADE_FONT)
		lbl.add_theme_font_size_override("font_size", 22 if not _use_mobile_labels else 18)
		lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.text = _get_action_label(act)
		slot.add_child(lbl)

		_slots_hbox.add_child(slot)
		_slot_panels.append(slot)
		_slot_labels.append(lbl)


func _on_slot_gui_input(event: InputEvent, act: StringName) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		process_action_input(act)
	elif event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		process_action_input(act)


func _get_action_label(act: StringName) -> String:
	if _use_mobile_labels:
		return str(ACTION_LABELS_MOBILE.get(act, str(act).to_upper()))
	return str(ACTION_LABELS_PC.get(act, str(act).to_upper()))


func _update_visuals() -> void:
	if _timer_bar != null:
		var ratio: float = clampf(_time_left / maxf(duration, 0.001), 0.0, 1.0)
		_timer_bar.value = ratio
		var fill_box := _timer_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_box != null:
			fill_box.bg_color = Color(0.95, 0.25, 0.22, 1.0) if ratio < 0.32 else Color(0.95, 0.78, 0.22, 1.0)

	if _timer_label != null:
		_timer_label.text = "%.1fs" % maxf(0.0, _time_left)
		_timer_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.35, 0.30, 1.0) if _time_left < 0.45 else Color(1.0, 0.95, 0.80, 1.0)
		)

	for i in range(_slot_panels.size()):
		var panel := _slot_panels[i]
		var lbl := _slot_labels[i]
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2

		if i < _current_index:
			# Já acertado
			style.bg_color = Color(0.10, 0.36, 0.16, 0.95)
			style.border_color = Color(0.32, 0.95, 0.45, 1.0)
			lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65, 1.0))
			panel.scale = Vector2.ONE
		elif i == _current_index:
			# Próximo botão esperado
			style.bg_color = Color(0.26, 0.18, 0.05, 0.98)
			style.border_color = Color(1.0, 0.86, 0.22, 1.0)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.60, 1.0))
			panel.scale = Vector2(1.08, 1.08)
		else:
			# Pendente na fila
			style.bg_color = Color(0.10, 0.10, 0.15, 0.85)
			style.border_color = Color(0.42, 0.42, 0.52, 0.85)
			lbl.add_theme_color_override("font_color", Color(0.80, 0.82, 0.88, 0.90))
			panel.scale = Vector2.ONE

		panel.add_theme_stylebox_override("panel", style)
