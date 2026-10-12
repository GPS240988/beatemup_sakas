class_name TouchControls
extends Control

## Componente de controles virtuais na tela para dispositivos móveis com suporte a multitouch.
## Controla um analógico virtual no canto esquerdo e botões de ação no canto direito.

## Parâmetros do joystick virtual
@export var joystick_radius: float = 75.0
@export var knob_radius: float = 32.0
@export var deadzone: float = 0.15

## Exibição do botão de reinício (desativado por padrão conforme solicitado)
@export var show_restart_button: bool = false

## Posições base na resolução de referência 1280x720
var joystick_base_pos: Vector2 = Vector2(160, 560)
var attack_button_pos: Vector2 = Vector2(1130, 560)
var attack_button_radius: float = 46.0

var restart_button_pos: Vector2 = Vector2(1130, 440)
var restart_button_radius: float = 28.0

## Estados de toque (índices de dedo para multitouch)
var joystick_touch_index: int = -1
var attack_touch_index: int = -1
var restart_touch_index: int = -1

var joystick_knob_offset: Vector2 = Vector2.ZERO
var is_attack_pressed: bool = false
var is_restart_pressed: bool = false


func _ready() -> void:
	# Ajusta âncoras para cobrir a tela inteira de forma transparente
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_PASS


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Suporta tanto toques na tela quanto cliques de mouse (emulate_touch_from_mouse)
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
		# Verifica se o toque começou na área do joystick
		if joystick_touch_index == -1 and event.position.distance_to(joystick_base_pos) <= joystick_radius * 1.5:
			joystick_touch_index = event.index
			_update_joystick_pos(event.position)
		# Verifica botão de ataque
		elif attack_touch_index == -1 and event.position.distance_to(attack_button_pos) <= attack_button_radius * 1.2:
			attack_touch_index = event.index
			is_attack_pressed = true
			Input.action_press("attack")
			queue_redraw()
		# Verifica botão de reinício (somente se habilitado)
		elif show_restart_button and restart_touch_index == -1 and event.position.distance_to(restart_button_pos) <= restart_button_radius * 1.2:
			restart_touch_index = event.index
			is_restart_pressed = true
			Input.action_press("restart")
			queue_redraw()
	else:
		# Soltou o toque correspondente
		if event.index == joystick_touch_index:
			_release_joystick()
		if event.index == attack_touch_index:
			attack_touch_index = -1
			is_attack_pressed = false
			Input.action_release("attack")
			queue_redraw()
		if show_restart_button and event.index == restart_touch_index:
			restart_touch_index = -1
			is_restart_pressed = false
			Input.action_release("restart")
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
	var dist: float = offset.length()
	
	if dist > joystick_radius:
		offset = offset.normalized() * joystick_radius
	joystick_knob_offset = offset
	queue_redraw()

	# Aplica força nos eixos do Input Map
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

	# 2. Botão de Ataque (SOCO)
	var atk_bg_color: Color = Color(0.95, 0.25, 0.25, 0.85) if is_attack_pressed else Color(0.75, 0.2, 0.2, 0.55)
	draw_circle(attack_button_pos, attack_button_radius, atk_bg_color)
	draw_arc(attack_button_pos, attack_button_radius, 0, TAU, 32, Color(1, 0.8, 0.4, 0.8), 2.5)
	draw_string(ThemeDB.fallback_font, attack_button_pos + Vector2(-22, 6), "SOCO", HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color.WHITE)

	# 3. Botão de Reinício (ocultado por hora conforme solicitado)
	if show_restart_button:
		var rst_bg_color: Color = Color(0.3, 0.5, 0.8, 0.85) if is_restart_pressed else Color(0.2, 0.35, 0.6, 0.55)
		draw_circle(restart_button_pos, restart_button_radius, rst_bg_color)
		draw_arc(restart_button_pos, restart_button_radius, 0, TAU, 24, Color(0.6, 0.8, 1.0, 0.75), 2.0)
		draw_string(ThemeDB.fallback_font, restart_button_pos + Vector2(-12, 5), "RST", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)
