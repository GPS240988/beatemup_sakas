class_name TouchControls
extends Control

## Controles arcade virtuais mobile — Projeto Sakas (Beat 'em Up 2.5D)
## Reproduz com fidelidade a identidade visual neon dark glass da referência oficial.
## Mapeamento:
## - Punho (J): Ataque principal (maior botão, aro laranja neon, punho fechado)
## - Voadora (SPACE): Golpe de voadora aérea (aro metálico azul, silhueta voadora)
## - Especial (E / O): Golpe especial (contorno de fogo/energia, efeito chama)
## - Bloqueio (K): Defesa (aro metálico azul, seta para cima)
## - Pause: Botão quadrado com cantos arredondados, fundo azul-marinho e duas barras verticais
## - Direcional: Base circular translúcida, 4 setas e controle central

signal pause_requested

const REFERENCE_VIEWPORT: Vector2 = Vector2(1280.0, 720.0)

# Assets visuais dedicados (Pixel Art HD neon dark glass)
const TEX_ATTACK: Texture2D = preload("res://assets/ui/mobile/button_attack.png")
const TEX_KICK: Texture2D = preload("res://assets/ui/mobile/button_kick.png")
const TEX_SPECIAL: Texture2D = preload("res://assets/ui/mobile/button_special.png")
const TEX_BLOCK: Texture2D = preload("res://assets/ui/mobile/button_block.png")
const TEX_PAUSE: Texture2D = preload("res://assets/ui/mobile/button_pause.png")
const TEX_DPAD_BASE: Texture2D = preload("res://assets/ui/mobile/mobile_dpad_base.png")
const TEX_DPAD_ARROWS: Texture2D = preload("res://assets/ui/mobile/mobile_dpad_arrows.png")
const TEX_DPAD_THUMB: Texture2D = preload("res://assets/ui/mobile/mobile_dpad_thumb.png")

@export_range(0.0, 1.0, 0.01) var deadzone: float = 0.15

# Permite forçar ativação em suítes de testes unitários headless
var test_mode: bool = false

# Posições dos controles (calculadas responsivamente no viewport)
var joystick_base_pos: Vector2 = Vector2.ZERO
var combo_btn_pos: Vector2 = Vector2.ZERO    # Ataque principal (J)
var aerial_btn_pos: Vector2 = Vector2.ZERO   # Voadora (Space)
var special_btn_pos: Vector2 = Vector2.ZERO  # Especial (E)
var guard_btn_pos: Vector2 = Vector2.ZERO    # Bloqueio (K)
var block_btn_pos: Vector2:                  # Alias para guard_btn_pos
	get:
		return guard_btn_pos
	set(value):
		guard_btn_pos = value
var pause_btn_pos: Vector2 = Vector2.ZERO    # Pause (Canto superior direito)

# Dimensões e raios dos controles
var joystick_radius: float = 96.0
var knob_radius: float = 40.0
var combo_btn_radius: float = 68.0           # Maior botão do conjunto
var aerial_btn_radius: float = 46.0          # Botão menor (voadora)
var special_btn_radius: float = 52.0         # Botão intermediário com aura de fogo
var guard_btn_radius: float = 46.0           # Botão superior (bloqueio)
var block_btn_radius: float:                 # Alias para guard_btn_radius
	get:
		return guard_btn_radius
	set(value):
		guard_btn_radius = value
var pause_btn_size: Vector2 = Vector2(52.0, 52.0)

var _layout_scale: float = 1.0

# Índices multi-touch para suporte a múltiplos dedos simultâneos
var _joystick_touch_index: int = -1
var _combo_touch_index: int = -1
var _aerial_touch_index: int = -1
var _special_touch_index: int = -1
var _guard_touch_index: int = -1
var _pause_touch_index: int = -1

# Estados de pressionamento para feedback tátil visual
var _joystick_knob_offset: Vector2 = Vector2.ZERO
var _combo_pressed: bool = false
var _aerial_pressed: bool = false
var _special_pressed: bool = false
var _guard_pressed: bool = false
var _pause_pressed: bool = false


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 25
	visible = is_controls_active()
	set_process_input(visible)
	if not resized.is_connected(_recalculate_layout):
		resized.connect(_recalculate_layout)
	call_deferred("_recalculate_layout")


func _exit_tree() -> void:
	release_all_virtual_actions()


func is_controls_active() -> bool:
	return test_mode or _is_mobile_runtime()


func set_controls_enabled(enabled: bool) -> void:
	var should_enable: bool = enabled and is_controls_active()
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
	if not is_controls_active():
		return

	var area: Vector2 = get_rect().size
	if area.x <= 1.0 or area.y <= 1.0:
		area = get_viewport_rect().size
	if area.x <= 1.0 or area.y <= 1.0:
		area = REFERENCE_VIEWPORT

	_layout_scale = clampf(
		minf(area.x / REFERENCE_VIEWPORT.x, area.y / REFERENCE_VIEWPORT.y),
		0.72,
		1.25
	)

	# Escala geométrica dos controles
	joystick_radius = 96.0 * _layout_scale
	knob_radius = 40.0 * _layout_scale
	combo_btn_radius = 68.0 * _layout_scale      # Punho (J) maior que os demais
	aerial_btn_radius = 46.0 * _layout_scale     # Voadora (Space)
	special_btn_radius = 52.0 * _layout_scale    # Especial (E)
	guard_btn_radius = 46.0 * _layout_scale      # Bloqueio (K)
	pause_btn_size = Vector2(52.0, 52.0) * _layout_scale

	# Direcional: quadrante inferior esquerdo
	var dpad_margin_x: float = maxf(joystick_radius + 36.0 * _layout_scale, area.x * 0.11)
	var dpad_margin_y: float = area.y - joystick_radius - 38.0 * _layout_scale
	joystick_base_pos = Vector2(dpad_margin_x, dpad_margin_y)

	# Agrupamento de combate: quadrante inferior direito (disposição exata da referência)
	# 1. Ataque principal (J): canto inferior direito, maior botão
	combo_btn_pos = Vector2(area.x - 110.0 * _layout_scale, area.y - 95.0 * _layout_scale)
	# 2. Bloqueio (K): diretamente acima do ataque principal, topo do cluster
	guard_btn_pos = Vector2(area.x - 110.0 * _layout_scale, area.y - 235.0 * _layout_scale)
	# 3. Voadora (Space): inferior esquerda do agrupamento
	aerial_btn_pos = Vector2(area.x - 305.0 * _layout_scale, area.y - 85.0 * _layout_scale)
	# 4. Especial (E): intermediário entre voadora, bloqueio e ataque
	special_btn_pos = Vector2(area.x - 215.0 * _layout_scale, area.y - 175.0 * _layout_scale)

	# Botão de Pause: canto superior direito abaixo do avatar do EnemyHUD (Y >= 78px) para não sobrepor o inimigo
	var pause_margin_top: float = 86.0 * _layout_scale
	pause_btn_pos = Vector2(area.x - 38.0 * _layout_scale - pause_btn_size.x * 0.5, pause_margin_top + pause_btn_size.y * 0.5)

	# Limite de segurança lateral para telas ultrawide
	var right_edge: float = area.x - combo_btn_radius - 16.0
	if combo_btn_pos.x > right_edge:
		var delta_x: float = combo_btn_pos.x - right_edge
		combo_btn_pos.x -= delta_x
		guard_btn_pos.x -= delta_x
		aerial_btn_pos.x -= delta_x
		special_btn_pos.x -= delta_x

	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or not is_controls_active():
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# 1. Botão de Pause (Canto superior direito)
		var pause_rect := Rect2(pause_btn_pos - pause_btn_size * 0.5, pause_btn_size)
		if _pause_touch_index == -1 and (pause_rect.has_point(event.position) or event.position.distance_to(pause_btn_pos) <= pause_btn_size.x * 0.75):
			_pause_touch_index = event.index
			_pause_pressed = true
			queue_redraw()
			_trigger_pause()
			return

		# 2. Direcional Joystick (Quadrante inferior esquerdo)
		if _joystick_touch_index == -1 and event.position.distance_to(joystick_base_pos) <= joystick_radius * 1.45:
			_joystick_touch_index = event.index
			_update_joystick_pos(event.position)
			return

		# 3. Ataque Principal J (Inferior direito, maior botão)
		if _combo_touch_index == -1 and event.position.distance_to(combo_btn_pos) <= combo_btn_radius * 1.15:
			_combo_touch_index = event.index
			_combo_pressed = true
			Input.action_press("attack")
			Input.action_press("attack_punch")
			queue_redraw()
			return

		# 4. Voadora SPACE (Inferior esquerdo do agrupamento)
		if _aerial_touch_index == -1 and event.position.distance_to(aerial_btn_pos) <= aerial_btn_radius * 1.20:
			_aerial_touch_index = event.index
			_aerial_pressed = true
			Input.action_press("attack_aerial")
			Input.action_press("jump")
			queue_redraw()
			return

		# 5. Especial E (Intermediário com efeito de fogo)
		if _special_touch_index == -1 and event.position.distance_to(special_btn_pos) <= special_btn_radius * 1.20:
			_special_touch_index = event.index
			_special_pressed = true
			Input.action_press("attack_special")
			Input.action_press("special")
			queue_redraw()
			return

		# 6. Bloqueio K (Superior do agrupamento com seta para cima)
		if _guard_touch_index == -1 and event.position.distance_to(guard_btn_pos) <= guard_btn_radius * 1.20:
			_guard_touch_index = event.index
			_guard_pressed = true
			Input.action_press("guard")
			queue_redraw()
			return
	else:
		# Liberação dos toques independentemente (suporte multitouch)
		if event.index == _joystick_touch_index:
			_release_joystick()
		if event.index == _combo_touch_index:
			_combo_touch_index = -1
			_combo_pressed = false
			Input.action_release("attack")
			Input.action_release("attack_punch")
			queue_redraw()
		if event.index == _aerial_touch_index:
			_aerial_touch_index = -1
			_aerial_pressed = false
			Input.action_release("attack_aerial")
			Input.action_release("jump")
			queue_redraw()
		if event.index == _special_touch_index:
			_special_touch_index = -1
			_special_pressed = false
			Input.action_release("attack_special")
			Input.action_release("special")
			queue_redraw()
		if event.index == _guard_touch_index:
			_guard_touch_index = -1
			_guard_pressed = false
			Input.action_release("guard")
			queue_redraw()
		if event.index == _pause_touch_index:
			_pause_touch_index = -1
			_pause_pressed = false
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
	_pause_touch_index = -1
	_joystick_knob_offset = Vector2.ZERO
	_combo_pressed = false
	_aerial_pressed = false
	_special_pressed = false
	_guard_pressed = false
	_pause_pressed = false
	_release_direction_inputs()
	Input.action_release("attack")
	Input.action_release("attack_punch")
	Input.action_release("attack_aerial")
	Input.action_release("jump")
	Input.action_release("attack_special")
	Input.action_release("special")
	Input.action_release("guard")
	queue_redraw()


func _trigger_pause() -> void:
	# Libera todas as ações ativas antes de congelar a cena
	release_all_virtual_actions()
	pause_requested.emit()

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	# Procura o menu de pausa implementado na cena atual ou no root
	var current_scene: Node = tree.current_scene
	var pause_menu: Node = null
	if current_scene != null:
		pause_menu = current_scene.find_child("PauseMenu", true, false)
		if pause_menu == null and current_scene.get("pause_menu") != null:
			pause_menu = current_scene.get("pause_menu") as Node

	if pause_menu == null and tree.root != null:
		pause_menu = tree.root.find_child("PauseMenu", true, false)

	if pause_menu != null and pause_menu.has_method("open_pause"):
		var scene_path: String = current_scene.scene_file_path if current_scene != null else ""
		pause_menu.call("open_pause", scene_path)
	else:
		# Fallback desacoplado: simula tecla de escape / pausa
		tree.paused = true
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = true
		Input.parse_input_event(ev)


func _draw() -> void:
	if not visible or not is_controls_active():
		return

	# 1. Direcional Analógico (Base + Setas + Knob)
	_draw_joystick()

	# 2. Quatro Botões de Combate (Neon Dark Glass HD)
	# Punho (J) — Maior botão, aro laranja neon
	_draw_button_texture(TEX_ATTACK, combo_btn_pos, combo_btn_radius, _combo_pressed)

	# Voadora (Space) — Aro metálico azulado, silhueta voadora
	_draw_button_texture(TEX_KICK, aerial_btn_pos, aerial_btn_radius, _aerial_pressed)

	# Especial (E) — Contorno de fogo e energia
	_draw_button_texture(TEX_SPECIAL, special_btn_pos, special_btn_radius, _special_pressed)

	# Bloqueio (K) — Aro metálico e seta para cima
	_draw_button_texture(TEX_BLOCK, guard_btn_pos, guard_btn_radius, _guard_pressed)

	# 3. Botão de Pause no topo direito
	_draw_pause_button()


func _draw_joystick() -> void:
	var base_rect := Rect2(
		joystick_base_pos - Vector2(joystick_radius, joystick_radius),
		Vector2(joystick_radius * 2.0, joystick_radius * 2.0)
	)
	# Base circular translúcida com anel metálico azulado
	if TEX_DPAD_BASE != null:
		draw_texture_rect(TEX_DPAD_BASE, base_rect, false)

	# 4 Indicadores direcionais
	if TEX_DPAD_ARROWS != null:
		draw_texture_rect(TEX_DPAD_ARROWS, base_rect, false)

	# Controle central translúcido (Thumb Knob)
	var thumb_center: Vector2 = joystick_base_pos + _joystick_knob_offset
	var thumb_rect := Rect2(
		thumb_center - Vector2(knob_radius, knob_radius),
		Vector2(knob_radius * 2.0, knob_radius * 2.0)
	)
	var thumb_modulate: Color = Color(1.3, 1.2, 1.0, 1.0) if _joystick_touch_index != -1 else Color.WHITE
	if TEX_DPAD_THUMB != null:
		draw_texture_rect(TEX_DPAD_THUMB, thumb_rect, false, thumb_modulate)


func _draw_button_texture(texture: Texture2D, center: Vector2, radius: float, is_pressed: bool) -> void:
	if texture == null:
		return

	# Feedback tátil visual: leve compressão e aumento sutil de luminosidade quando pressionado
	var scale_factor: float = 0.94 if is_pressed else 1.0
	var draw_radius: float = radius * scale_factor
	var pressed_offset: Vector2 = Vector2(0.0, 2.0 * _layout_scale) if is_pressed else Vector2.ZERO
	var p: Vector2 = center + pressed_offset

	var rect := Rect2(p - Vector2(draw_radius, draw_radius), Vector2(draw_radius * 2.0, draw_radius * 2.0))
	var modulate_color: Color = Color(1.28, 1.28, 1.28, 1.0) if is_pressed else Color.WHITE

	draw_texture_rect(texture, rect, false, modulate_color)


func _draw_pause_button() -> void:
	if TEX_PAUSE == null:
		return

	var scale_factor: float = 0.93 if _pause_pressed else 1.0
	var draw_size: Vector2 = pause_btn_size * scale_factor
	var pressed_offset: Vector2 = Vector2(0.0, 2.0 * _layout_scale) if _pause_pressed else Vector2.ZERO
	var p: Vector2 = pause_btn_pos + pressed_offset

	var rect := Rect2(p - draw_size * 0.5, draw_size)
	var modulate_color: Color = Color(1.35, 1.35, 1.35, 1.0) if _pause_pressed else Color.WHITE

	draw_texture_rect(TEX_PAUSE, rect, false, modulate_color)
