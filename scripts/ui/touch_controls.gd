class_name TouchControls
extends Control

## Controles arcade premium exclusivos de mobile.
## Mantém o contrato original do InputMap: move_*, attack, attack_aerial,
## attack_special e guard. Não altera o PlayerController nem a física do jogo.

const REFERENCE_VIEWPORT: Vector2 = Vector2(1280.0, 720.0)
const COLOR_TEXT: Color = Color(0.98, 0.96, 0.89, 0.98)

@export_range(0.0, 1.0, 0.01) var deadzone: float = 0.15

var joystick_base_pos: Vector2 = Vector2.ZERO
var combo_btn_pos: Vector2 = Vector2.ZERO
var aerial_btn_pos: Vector2 = Vector2.ZERO
var special_btn_pos: Vector2 = Vector2.ZERO
var guard_btn_pos: Vector2 = Vector2.ZERO

var joystick_radius: float = 84.0
var knob_radius: float = 34.0
var combo_btn_radius: float = 54.0
var aerial_btn_radius: float = 46.0
var special_btn_radius: float = 43.0
var guard_btn_radius: float = 43.0

var _layout_scale: float = 1.0
var _joystick_touch_index: int = -1
var _combo_touch_index: int = -1
var _aerial_touch_index: int = -1
var _special_touch_index: int = -1
var _guard_touch_index: int = -1
var _joystick_knob_offset: Vector2 = Vector2.ZERO
var _combo_pressed: bool = false
var _aerial_pressed: bool = false
var _special_pressed: bool = false
var _guard_pressed: bool = false


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 20
	visible = _is_mobile_runtime()
	set_process_input(visible)
	if not resized.is_connected(_recalculate_layout):
		resized.connect(_recalculate_layout)
	call_deferred("_recalculate_layout")


func set_controls_enabled(enabled: bool) -> void:
	var should_enable: bool = enabled and _is_mobile_runtime()
	if visible == should_enable:
		if not should_enable:
			release_all_virtual_actions()
		return
	visible = should_enable
	set_process_input(should_enable)
	if not should_enable:
		release_all_virtual_actions()
	else:
		call_deferred("_recalculate_layout")
	queue_redraw()


func _is_mobile_runtime() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)


func _recalculate_layout() -> void:
	if not _is_mobile_runtime():
		return

	var area: Vector2 = get_rect().size
	if area.x <= 1.0 or area.y <= 1.0:
		area = get_viewport_rect().size
	if area.x <= 1.0 or area.y <= 1.0:
		area = REFERENCE_VIEWPORT

	_layout_scale = clampf(
		minf(area.x / REFERENCE_VIEWPORT.x, area.y / REFERENCE_VIEWPORT.y),
		0.68,
		1.10
	)
	joystick_radius = 84.0 * _layout_scale
	knob_radius = 34.0 * _layout_scale
	combo_btn_radius = 54.0 * _layout_scale
	aerial_btn_radius = 46.0 * _layout_scale
	special_btn_radius = 43.0 * _layout_scale
	guard_btn_radius = 43.0 * _layout_scale

	# Respeita margens inferiores e laterais para não encostar na borda do aparelho.
	var is_portrait: bool = area.x / maxf(area.y, 1.0) < 1.0
	joystick_base_pos = Vector2(maxf(joystick_radius + 28.0, area.x * 0.13), area.y * 0.79)
	if is_portrait:
		# No modo vertical, o conjunto de ações abre em leque para evitar colisões.
		combo_btn_pos = Vector2(area.x * 0.82, area.y * 0.80)
		aerial_btn_pos = Vector2(area.x * 0.56, area.y * 0.65)
		special_btn_pos = Vector2(area.x * 0.84, area.y * 0.57)
		guard_btn_pos = Vector2(area.x * 0.56, area.y * 0.83)
	else:
		combo_btn_pos = Vector2(area.x * 0.88, area.y * 0.79)
		aerial_btn_pos = Vector2(area.x * 0.75, area.y * 0.62)
		special_btn_pos = Vector2(area.x * 0.90, area.y * 0.57)
		guard_btn_pos = Vector2(area.x * 0.74, area.y * 0.83)

	# Corrige a posição em telas estreitas mantendo o grupo de ações dentro do viewport.
	var right_limit: float = area.x - combo_btn_radius - 24.0
	combo_btn_pos.x = minf(combo_btn_pos.x, right_limit)
	special_btn_pos.x = minf(special_btn_pos.x, area.x - special_btn_radius - 24.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or not _is_mobile_runtime():
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Entrada multi-touch: um dedo no movimento e outros nas ações.
		if _joystick_touch_index == -1 and event.position.distance_to(joystick_base_pos) <= joystick_radius * 1.48:
			_joystick_touch_index = event.index
			_update_joystick_pos(event.position)
		elif _combo_touch_index == -1 and event.position.distance_to(combo_btn_pos) <= combo_btn_radius * 1.25:
			_combo_touch_index = event.index
			_combo_pressed = true
			Input.action_press("attack")
			queue_redraw()
		elif _aerial_touch_index == -1 and event.position.distance_to(aerial_btn_pos) <= aerial_btn_radius * 1.28:
			_aerial_touch_index = event.index
			_aerial_pressed = true
			Input.action_press("attack_aerial")
			queue_redraw()
		elif _special_touch_index == -1 and event.position.distance_to(special_btn_pos) <= special_btn_radius * 1.28:
			_special_touch_index = event.index
			_special_pressed = true
			Input.action_press("attack_special")
			queue_redraw()
		elif _guard_touch_index == -1 and event.position.distance_to(guard_btn_pos) <= guard_btn_radius * 1.28:
			_guard_touch_index = event.index
			_guard_pressed = true
			Input.action_press("guard")
			queue_redraw()
	else:
		if event.index == _joystick_touch_index:
			_release_joystick()
		if event.index == _combo_touch_index:
			_combo_touch_index = -1
			_combo_pressed = false
			Input.action_release("attack")
			queue_redraw()
		if event.index == _aerial_touch_index:
			_aerial_touch_index = -1
			_aerial_pressed = false
			Input.action_release("attack_aerial")
			queue_redraw()
		if event.index == _special_touch_index:
			_special_touch_index = -1
			_special_pressed = false
			Input.action_release("attack_special")
			queue_redraw()
		if event.index == _guard_touch_index:
			_guard_touch_index = -1
			_guard_pressed = false
			Input.action_release("guard")
			queue_redraw()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joystick_touch_index:
		_update_joystick_pos(event.position)


func _update_joystick_pos(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - joystick_base_pos
	if offset.length() > joystick_radius:
		offset = offset.normalized() * joystick_radius
	_joystick_knob_offset = offset
	queue_redraw()
	_apply_input_axes(offset / maxf(joystick_radius, 1.0))


func _apply_input_axes(normal_offset: Vector2) -> void:
	if normal_offset.length() < deadzone:
		_release_direction_inputs()
		return

	if normal_offset.x > 0.2:
		Input.action_press("move_right", normal_offset.x)
		Input.action_release("move_left")
	elif normal_offset.x < -0.2:
		Input.action_press("move_left", absf(normal_offset.x))
		Input.action_release("move_right")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	if normal_offset.y > 0.2:
		Input.action_press("move_down", normal_offset.y)
		Input.action_release("move_up")
	elif normal_offset.y < -0.2:
		Input.action_press("move_up", absf(normal_offset.y))
		Input.action_release("move_down")
	else:
		Input.action_release("move_up")
		Input.action_release("move_down")


func _release_joystick() -> void:
	_joystick_touch_index = -1
	_joystick_knob_offset = Vector2.ZERO
	_release_direction_inputs()
	queue_redraw()


func _release_direction_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")


func release_all_virtual_actions() -> void:
	_joystick_touch_index = -1
	_combo_touch_index = -1
	_aerial_touch_index = -1
	_special_touch_index = -1
	_guard_touch_index = -1
	_joystick_knob_offset = Vector2.ZERO
	_combo_pressed = false
	_aerial_pressed = false
	_special_pressed = false
	_guard_pressed = false
	_release_direction_inputs()
	Input.action_release("attack")
	Input.action_release("attack_aerial")
	Input.action_release("attack_special")
	Input.action_release("guard")
	queue_redraw()


func _draw() -> void:
	if not visible or not _is_mobile_runtime():
		return
	_draw_joystick()
	_draw_action_button(combo_btn_pos, combo_btn_radius, "A", "SOCO", _combo_pressed,
		Color(0.77, 0.16, 0.13, 0.94), Color(1.0, 0.39, 0.24, 1.0))
	_draw_action_button(aerial_btn_pos, aerial_btn_radius, "B", "VOADORA", _aerial_pressed,
		Color(0.10, 0.39, 0.69, 0.94), Color(0.32, 0.72, 1.0, 1.0))
	_draw_action_button(special_btn_pos, special_btn_radius, "X", "ESPECIAL", _special_pressed,
		Color(0.48, 0.18, 0.65, 0.94), Color(0.82, 0.49, 1.0, 1.0))
	_draw_action_button(guard_btn_pos, guard_btn_radius, "Y", "DEFESA", _guard_pressed,
		Color(0.10, 0.44, 0.31, 0.94), Color(0.42, 0.91, 0.59, 1.0))


func _draw_joystick() -> void:
	var center := joystick_base_pos
	var knob_center := center + _joystick_knob_offset
	draw_circle(center + Vector2(0.0, 5.0 * _layout_scale), joystick_radius + 5.0 * _layout_scale, Color(0.0, 0.0, 0.0, 0.42))
	draw_circle(center, joystick_radius, Color(0.025, 0.04, 0.065, 0.78))
	draw_arc(center, joystick_radius - 1.0, 0.0, TAU, 64, Color(0.84, 0.75, 0.54, 0.88), 3.0 * _layout_scale, true)
	draw_arc(center, joystick_radius * 0.73, 0.0, TAU, 64, Color(0.55, 0.66, 0.77, 0.28), 1.5 * _layout_scale, true)
	_draw_direction_mark(center + Vector2(0.0, -joystick_radius * 0.55), Vector2.UP)
	_draw_direction_mark(center + Vector2(0.0, joystick_radius * 0.55), Vector2.DOWN)
	_draw_direction_mark(center + Vector2(-joystick_radius * 0.55, 0.0), Vector2.LEFT)
	_draw_direction_mark(center + Vector2(joystick_radius * 0.55, 0.0), Vector2.RIGHT)

	var knob_color := Color(0.96, 0.70, 0.34, 1.0) if _joystick_touch_index != -1 else Color(0.73, 0.81, 0.88, 0.98)
	draw_circle(knob_center + Vector2(0.0, 3.0 * _layout_scale), knob_radius + 3.0 * _layout_scale, Color(0.0, 0.0, 0.0, 0.52))
	draw_circle(knob_center, knob_radius, Color(0.055, 0.075, 0.10, 0.98))
	draw_circle(knob_center, knob_radius * 0.83, knob_color)
	draw_arc(knob_center, knob_radius * 0.83, 0.0, TAU, 40, Color(1.0, 0.97, 0.86, 0.92), 2.0 * _layout_scale, true)
	draw_arc(knob_center, knob_radius * 0.61, PI * 1.05, PI * 1.95, 24, Color(1.0, 1.0, 1.0, 0.36), 2.0 * _layout_scale, true)
	_draw_centered_text(center + Vector2(0.0, joystick_radius * 0.30), "MOV", maxi(9, int(11.0 * _layout_scale)), Color(0.9, 0.94, 0.98, 0.72))


func _draw_direction_mark(position: Vector2, direction: Vector2) -> void:
	var side := Vector2(-direction.y, direction.x)
	var tip := position + direction * 5.0 * _layout_scale
	var base := position - direction * 4.0 * _layout_scale
	var points := PackedVector2Array([
		tip,
		base + side * 4.0 * _layout_scale,
		base - side * 4.0 * _layout_scale
	])
	draw_colored_polygon(points, Color(0.78, 0.84, 0.9, 0.48))


func _draw_action_button(
	center: Vector2,
	radius: float,
	letter: String,
	label: String,
	is_pressed: bool,
	base_color: Color,
	accent_color: Color
) -> void:
	var pressed_offset := Vector2(0.0, 2.5 * _layout_scale) if is_pressed else Vector2.ZERO
	var p := center + pressed_offset
	# Sombra e aro externo simulam um botão físico sem perder legibilidade sobre a fase.
	draw_circle(p + Vector2(0.0, 4.0 * _layout_scale), radius + 3.0 * _layout_scale, Color(0.0, 0.0, 0.0, 0.55))
	draw_circle(p, radius + 3.0 * _layout_scale, Color(0.015, 0.022, 0.035, 0.94))
	draw_circle(p, radius, accent_color if is_pressed else base_color)
	draw_arc(p, radius - 1.0, 0.0, TAU, 48, Color(1.0, 0.93, 0.76, 0.92), 2.4 * _layout_scale, true)
	draw_circle(p, radius * 0.76, Color(0.025, 0.035, 0.052, 0.68))
	draw_arc(p, radius * 0.72, PI * 1.08, PI * 1.92, 32, Color(1.0, 1.0, 1.0, 0.30), 1.5 * _layout_scale, true)
	var main_size := maxi(17, int(radius * 0.62))
	_draw_centered_text(p + Vector2(0.0, -2.0 * _layout_scale), letter, main_size, COLOR_TEXT)
	_draw_centered_text(p + Vector2(0.0, radius * 0.52), label, maxi(8, int(9.0 * _layout_scale)), Color(1.0, 0.96, 0.86, 0.98))


func _draw_centered_text(position: Vector2, value: String, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, position + Vector2(-text_width * 0.5, float(font_size) * 0.34), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
