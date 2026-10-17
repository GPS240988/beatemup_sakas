class_name TouchControls
extends Control

## Componente de controles virtuais na tela para dispositivos móveis com suporte a multitouch.
## Controla um analógico virtual no canto esquerdo e botões dedicados de combate no canto direito:
## [SOCO], [CHUTE], [ESP] (Especial), [AÉREO] e [DEF] (Guarda).

## Parâmetros do joystick virtual
@export var joystick_radius: float = 75.0
@export var knob_radius: float = 32.0
@export var deadzone: float = 0.15

## Posições base na resolução de referência 1280x720
var joystick_base_pos: Vector2 = Vector2(160, 560)

var punch_btn_pos: Vector2 = Vector2(1060, 590)
var punch_btn_radius: float = 36.0

var kick_btn_pos: Vector2 = Vector2(1170, 590)
var kick_btn_radius: float = 36.0

var special_btn_pos: Vector2 = Vector2(1170, 480)
var special_btn_radius: float = 34.0

var aerial_btn_pos: Vector2 = Vector2(1060, 480)
var aerial_btn_radius: float = 34.0

var guard_btn_pos: Vector2 = Vector2(950, 590)
var guard_btn_radius: float = 32.0

## Estados de toque (índices de dedo para multitouch)
var joystick_touch_index: int = -1
var punch_touch_index: int = -1
var kick_touch_index: int = -1
var special_touch_index: int = -1
var aerial_touch_index: int = -1
var guard_touch_index: int = -1

var joystick_knob_offset: Vector2 = Vector2.ZERO
var is_punch_pressed: bool = false
var is_kick_pressed: bool = false
var is_special_pressed: bool = false
var is_aerial_pressed: bool = false
var is_guard_pressed: bool = false


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_PASS


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and joystick_touch_index == 999:
		_handle_mouse_motion(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Joystick
		if joystick_touch_index == -1 and event.position.distance_to(joystick_base_pos) <= joystick_radius * 1.5:
			joystick_touch_index = event.index
			_update_joystick_pos(event.position)
		# Botão SOCO
		elif punch_touch_index == -1 and event.position.distance_to(punch_btn_pos) <= punch_btn_radius * 1.2:
			punch_touch_index = event.index
			is_punch_pressed = true
			Input.action_press("attack_punch")
			Input.action_press("attack")
			queue_redraw()
		# Botão CHUTE
		elif kick_touch_index == -1 and event.position.distance_to(kick_btn_pos) <= kick_btn_radius * 1.2:
			kick_touch_index = event.index
			is_kick_pressed = true
			Input.action_press("attack_kick")
			queue_redraw()
		# Botão ESPECIAL
		elif special_touch_index == -1 and event.position.distance_to(special_btn_pos) <= special_btn_radius * 1.2:
			special_touch_index = event.index
			is_special_pressed = true
			Input.action_press("attack_special")
			queue_redraw()
		# Botão AÉREO
		elif aerial_touch_index == -1 and event.position.distance_to(aerial_btn_pos) <= aerial_btn_radius * 1.2:
			aerial_touch_index = event.index
			is_aerial_pressed = true
			Input.action_press("attack_aerial")
			queue_redraw()
		# Botão GUARDA / DEF
		elif guard_touch_index == -1 and event.position.distance_to(guard_btn_pos) <= guard_btn_radius * 1.2:
			guard_touch_index = event.index
			is_guard_pressed = true
			Input.action_press("guard")
			queue_redraw()
	else:
		if event.index == joystick_touch_index:
			_release_joystick()
		if event.index == punch_touch_index:
			punch_touch_index = -1
			is_punch_pressed = false
			Input.action_release("attack_punch")
			Input.action_release("attack")
			queue_redraw()
		if event.index == kick_touch_index:
			kick_touch_index = -1
			is_kick_pressed = false
			Input.action_release("attack_kick")
			queue_redraw()
		if event.index == special_touch_index:
			special_touch_index = -1
			is_special_pressed = false
			Input.action_release("attack_special")
			queue_redraw()
		if event.index == aerial_touch_index:
			aerial_touch_index = -1
			is_aerial_pressed = false
			Input.action_release("attack_aerial")
			queue_redraw()
		if event.index == guard_touch_index:
			guard_touch_index = -1
			is_guard_pressed = false
			Input.action_release("guard")
			queue_redraw()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == joystick_touch_index:
		_update_joystick_pos(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var touch_sim := InputEventScreenTouch.new()
	touch_sim.index = 999
	touch_sim.position = event.position
	touch_sim.pressed = event.pressed
	_handle_touch(touch_sim)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var drag_sim := InputEventScreenDrag.new()
	drag_sim.index = 999
	drag_sim.position = event.position
	_handle_drag(drag_sim)


func _update_joystick_pos(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - joystick_base_pos
	if offset.length() > joystick_radius:
		offset = offset.normalized() * joystick_radius

	joystick_knob_offset = offset
	queue_redraw()

	var normal_offset: Vector2 = offset / joystick_radius
	_apply_input_axes(normal_offset)


func _apply_input_axes(normal_offset: Vector2) -> void:
	var deadzone_len: float = normal_offset.length()
	if deadzone_len < deadzone:
		_release_direction_inputs()
		return

	# Eixo X
	if normal_offset.x > 0.2:
		Input.action_press("move_right", normal_offset.x)
		Input.action_release("move_left")
	elif normal_offset.x < -0.2:
		Input.action_press("move_left", absf(normal_offset.x))
		Input.action_release("move_right")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	# Eixo Y
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
	joystick_touch_index = -1
	joystick_knob_offset = Vector2.ZERO
	_release_direction_inputs()
	queue_redraw()


func _release_direction_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")


func _draw() -> void:
	if not visible:
		return

	# 1. Base do Joystick Virtual
	draw_circle(joystick_base_pos, joystick_radius, Color(0.12, 0.14, 0.2, 0.45))
	draw_arc(joystick_base_pos, joystick_radius, 0, TAU, 32, Color(0.9, 0.85, 0.5, 0.55), 2.5)

	# Setas guias no joystick
	draw_line(joystick_base_pos + Vector2(-joystick_radius * 0.7, 0), joystick_base_pos + Vector2(-joystick_radius * 0.35, 0), Color(1, 1, 1, 0.4), 2.0)
	draw_line(joystick_base_pos + Vector2(joystick_radius * 0.35, 0), joystick_base_pos + Vector2(joystick_radius * 0.7, 0), Color(1, 1, 1, 0.4), 2.0)
	draw_line(joystick_base_pos + Vector2(0, -joystick_radius * 0.7), joystick_base_pos + Vector2(0, -joystick_radius * 0.35), Color(1, 1, 1, 0.4), 2.0)
	draw_line(joystick_base_pos + Vector2(0, joystick_radius * 0.35), joystick_base_pos + Vector2(0, joystick_radius * 0.7), Color(1, 1, 1, 0.4), 2.0)

	# Manípulo do Joystick (Knob)
	var knob_center: Vector2 = joystick_base_pos + joystick_knob_offset
	var knob_color: Color = Color(0.95, 0.4, 0.2, 0.85) if joystick_touch_index != -1 else Color(0.8, 0.8, 0.8, 0.6)
	draw_circle(knob_center, knob_radius, knob_color)
	draw_arc(knob_center, knob_radius, 0, TAU, 24, Color(1, 1, 1, 0.8), 2.0)

	# 2. Botão SOCO (J)
	var punch_bg: Color = Color(0.95, 0.25, 0.25, 0.85) if is_punch_pressed else Color(0.75, 0.2, 0.2, 0.55)
	draw_circle(punch_btn_pos, punch_btn_radius, punch_bg)
	draw_arc(punch_btn_pos, punch_btn_radius, 0, TAU, 28, Color(1, 0.8, 0.4, 0.8), 2.0)
	draw_string(ThemeDB.fallback_font, punch_btn_pos + Vector2(-18, 5), "SOCO", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

	# 3. Botão CHUTE (K)
	var kick_bg: Color = Color(0.95, 0.55, 0.15, 0.85) if is_kick_pressed else Color(0.8, 0.4, 0.1, 0.55)
	draw_circle(kick_btn_pos, kick_btn_radius, kick_bg)
	draw_arc(kick_btn_pos, kick_btn_radius, 0, TAU, 28, Color(1, 0.85, 0.4, 0.8), 2.0)
	draw_string(ThemeDB.fallback_font, kick_btn_pos + Vector2(-22, 5), "CHUTE", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

	# 4. Botão ESPECIAL (L)
	var esp_bg: Color = Color(0.85, 0.2, 0.85, 0.85) if is_special_pressed else Color(0.65, 0.15, 0.65, 0.55)
	draw_circle(special_btn_pos, special_btn_radius, esp_bg)
	draw_arc(special_btn_pos, special_btn_radius, 0, TAU, 28, Color(1, 0.6, 1.0, 0.8), 2.0)
	draw_string(ThemeDB.fallback_font, special_btn_pos + Vector2(-14, 5), "ESP", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

	# 5. Botão AÉREO (U)
	var aer_bg: Color = Color(0.2, 0.65, 0.95, 0.85) if is_aerial_pressed else Color(0.15, 0.45, 0.75, 0.55)
	draw_circle(aerial_btn_pos, aerial_btn_radius, aer_bg)
	draw_arc(aerial_btn_pos, aerial_btn_radius, 0, TAU, 28, Color(0.6, 0.9, 1.0, 0.8), 2.0)
	draw_string(ThemeDB.fallback_font, aerial_btn_pos + Vector2(-20, 5), "AÉREO", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)

	# 6. Botão GUARDA / DEF (Espaço / H)
	var grd_bg: Color = Color(0.25, 0.85, 0.45, 0.85) if is_guard_pressed else Color(0.15, 0.6, 0.3, 0.55)
	draw_circle(guard_btn_pos, guard_btn_radius, grd_bg)
	draw_arc(guard_btn_pos, guard_btn_radius, 0, TAU, 24, Color(0.6, 1.0, 0.6, 0.8), 2.0)
	draw_string(ThemeDB.fallback_font, guard_btn_pos + Vector2(-14, 5), "DEF", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)
