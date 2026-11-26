class_name Map8ToiletDialogue
extends Node

## Orquestra a conversa ambiental inicial dos três gorduchos no toalete (Map 8)
## e as falas curtas e esparsas durante o combate, reutilizando o padrão visual
## de balão Dark Premium Medieval do projeto.

signal intro_dialogue_finished()

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

const INTRO_LINES: Array[Dictionary] = [
	{"actor": "lider", "speaker": "LÍDER", "text": "Cadê aquela comanda limpa que o cara tá levando?", "duration": 3.0},
	{"actor": "g2", "speaker": "GORDUCHO 2", "text": "Vai dar ruim! A nossa virou um pastel de gordura!", "duration": 3.0},
	{"actor": "g3", "speaker": "GORDUCHO 3", "text": "Eu falei pra não colocar a pizza em cima do papel!", "duration": 3.0},
	{"actor": "lider", "speaker": "LÍDER", "text": "O dono vai olhar aquela porcaria e cobrar até o nosso peso!", "duration": 3.2},
	{"actor": "g2", "speaker": "GORDUCHO 2", "text": "Então pega a comanda dele! É só trocar!", "duration": 2.9},
	{"actor": "g3", "speaker": "GORDUCHO 3", "text": "Mas eu ainda tô com fome...", "duration": 2.6},
	{"actor": "lider", "speaker": "LÍDER", "text": "VOCÊ JÁ COMEU QUATRO PIZZAS, ANIMAL!", "duration": 3.0},
	{"actor": "lider", "speaker": "LÍDER", "text": "Chega de conversa! Passa essa comanda!", "duration": 2.6, "turn_to_player": true},
	{"actor": "g2", "speaker": "GORDUCHO 2", "text": "Não deixa ele sair com o papel!", "duration": 2.4, "turn_to_player": true}
]

const COMBAT_BANTER_LINES: Array[String] = [
	"Protege o papel!",
	"Não deixa ele sair com a comanda!",
	"Cuidado com a barriga, pô!",
	"Minha coluna!",
	"Pega esse papel!",
	"Eu não vou pagar essa conta!"
]

var _actors: Dictionary = {}
var _player: Node2D = null
var _canvas_layer: CanvasLayer = null
var _ui_root: Control = null
var _bubble: PanelContainer = null
var _tail: Polygon2D = null
var _speaker_label: Label = null
var _dialogue_label: Label = null
var _current_speaker: Node2D = null
var _bubble_vertical_offset: float = 195.0

var _intro_active: bool = false
var _intro_index: int = -1
var _line_timer: float = 0.0
var _skip_guard_timer: float = 0.0
var _fade_tween: Tween = null

var _combat_banter_active: bool = false
var _combat_banter_cooldown: float = 0.0
var _combat_bubble_timer: float = 0.0
var _last_banter_idx: int = -1


func setup(lider: Node2D, g2: Node2D, g3: Node2D, player_node: Node2D) -> void:
	_actors = {
		"lider": lider,
		"g2": g2,
		"g3": g3
	}
	_player = player_node
	_ensure_bubble_ui()


func start_intro_dialogue() -> void:
	_ensure_bubble_ui()
	_intro_active = true
	_combat_banter_active = false
	_intro_index = -1
	_show_next_intro_line()


func skip_intro_dialogue() -> void:
	if not _intro_active:
		return
	_finish_intro_dialogue()


func start_combat_banter() -> void:
	_combat_banter_active = true
	_combat_bubble_timer = 0.0
	_combat_banter_cooldown = randf_range(4.5, 6.5)


func stop_combat_banter() -> void:
	_combat_banter_active = false
	_combat_bubble_timer = 0.0
	_hide_bubble()


func is_intro_active() -> bool:
	return _intro_active


func get_intro_lines() -> Array[Dictionary]:
	return INTRO_LINES


func get_current_intro_index() -> int:
	return _intro_index


func _process(delta: float) -> void:
	if _intro_active:
		_skip_guard_timer = maxf(0.0, _skip_guard_timer - delta)
		_update_bubble_position()
		_line_timer -= delta
		if _line_timer <= 0.0:
			_show_next_intro_line()
		return

	if _combat_banter_active:
		if _combat_bubble_timer > 0.0:
			_combat_bubble_timer -= delta
			_update_bubble_position()
			if _combat_bubble_timer <= 0.0:
				_hide_bubble()
		else:
			_combat_banter_cooldown -= delta
			if _combat_banter_cooldown <= 0.0:
				_trigger_random_combat_banter()


func _input(event: InputEvent) -> void:
	if not _intro_active or _skip_guard_timer > 0.0:
		return
	if _is_advance_event(event):
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		_show_next_intro_line()


func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J]
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		return joy_event.pressed and joy_event.button_index == JOY_BUTTON_A
	return false


func _show_next_intro_line() -> void:
	_intro_index += 1
	if _intro_index >= INTRO_LINES.size():
		_finish_intro_dialogue()
		return

	var line: Dictionary = INTRO_LINES[_intro_index]
	var actor_key: String = str(line.get("actor", "lider"))
	var speaker_node: Node2D = _actors.get(actor_key, null) as Node2D
	if bool(line.get("turn_to_player", false)):
		_face_all_enemies_toward_player()
	if speaker_node != null and is_instance_valid(speaker_node):
		_pulse_speaker_gesture(speaker_node)

	var is_lider: bool = (actor_key == "lider")
	_bubble_vertical_offset = 365.0 if is_lider else 195.0
	_show_bubble(speaker_node, str(line.get("speaker", "")), str(line.get("text", "")))
	_line_timer = float(line.get("duration", 2.9))
	_skip_guard_timer = 0.22


func _finish_intro_dialogue() -> void:
	_intro_active = false
	_hide_bubble()
	_face_all_enemies_toward_player()
	intro_dialogue_finished.emit()


func _face_all_enemies_toward_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for key in _actors.keys():
		var actor = _actors[key]
		if actor != null and is_instance_valid(actor) and actor.has_method("_update_facing"):
			actor.call("_update_facing", _player.global_position.x)


func _pulse_speaker_gesture(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var visual := actor.get_node_or_null("Visual") as Node2D
	if visual == null:
		return
	var base_y: float = visual.scale.y
	var base_x: float = visual.scale.x
	var tw := actor.create_tween()
	tw.tween_property(visual, "scale", Vector2(base_x * 1.03, base_y * 1.03), 0.10)
	tw.tween_property(visual, "scale", Vector2(base_x, base_y), 0.12)


func _trigger_random_combat_banter() -> void:
	var living: Array[String] = []
	for key in _actors.keys():
		var actor = _actors[key]
		if actor == null or not is_instance_valid(actor):
			continue
		if "current_state" in actor and int(actor.get("current_state")) == EnemyAI.State.DEAD:
			continue
		var hc = actor.get_node_or_null("HealthComponent")
		if hc != null and is_instance_valid(hc) and bool(hc.get("is_dead")):
			continue
		living.append(str(key))

	if living.is_empty():
		stop_combat_banter()
		return

	var chosen_key: String = living[randi() % living.size()]
	var speaker_raw = _actors[chosen_key]
	if speaker_raw == null or not is_instance_valid(speaker_raw):
		return
	var speaker_node: Node2D = speaker_raw as Node2D
	var speaker_name: String = "LÍDER" if chosen_key == "lider" else ("GORDUCHO 2" if chosen_key == "g2" else "GORDUCHO 3")
	_bubble_vertical_offset = 365.0 if chosen_key == "lider" else 195.0

	var line_idx: int = randi() % COMBAT_BANTER_LINES.size()
	if COMBAT_BANTER_LINES.size() > 1 and line_idx == _last_banter_idx:
		line_idx = (line_idx + 1) % COMBAT_BANTER_LINES.size()
	_last_banter_idx = line_idx

	_show_bubble(speaker_node, speaker_name, COMBAT_BANTER_LINES[line_idx])
	_combat_bubble_timer = 2.2
	_combat_banter_cooldown = randf_range(6.5, 9.5)


func _ensure_bubble_ui() -> void:
	if _canvas_layer != null and is_instance_valid(_canvas_layer):
		return
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "ToiletDialogueLayer"
	_canvas_layer.layer = 32
	add_child(_canvas_layer)

	_ui_root = Control.new()
	_ui_root.name = "ToiletDialogueRoot"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_ui_root)

	_bubble = PanelContainer.new()
	_bubble.name = "SpeechBubble"
	_bubble.custom_minimum_size = Vector2(360.0, 0.0)
	_bubble.size = Vector2(360.0, 68.0)
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.modulate.a = 0.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.030, 0.050, 0.96)
	panel_style.border_color = Color(0.94, 0.75, 0.39, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_bottom = 10.0
	_bubble.add_theme_stylebox_override("panel", panel_style)
	_ui_root.add_child(_bubble)

	_tail = Polygon2D.new()
	_tail.name = "SpeechTail"
	_tail.color = Color(0.94, 0.75, 0.39, 1.0)
	_tail.polygon = PackedVector2Array([-9.0, 0.0, 9.0, 0.0, 0.0, 13.0])
	_tail.visible = false
	_ui_root.add_child(_tail)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_bubble.add_child(content)

	_speaker_label = Label.new()
	_speaker_label.name = "Speaker"
	_speaker_label.add_theme_font_override("font", ARCADE_FONT)
	_speaker_label.add_theme_font_size_override("font_size", 16)
	_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28, 1.0))
	_speaker_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_speaker_label.add_theme_constant_override("outline_size", 3)
	content.add_child(_speaker_label)

	_dialogue_label = Label.new()
	_dialogue_label.name = "Dialogue"
	_dialogue_label.add_theme_font_override("font", ARCADE_FONT)
	_dialogue_label.add_theme_font_size_override("font_size", 18)
	_dialogue_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90, 1.0))
	_dialogue_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_dialogue_label.add_theme_constant_override("outline_size", 2)
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_dialogue_label)


func _show_bubble(speaker_node: Node2D, speaker_name: String, text: String) -> void:
	if _bubble == null:
		return
	_current_speaker = speaker_node
	_speaker_label.text = speaker_name
	_dialogue_label.text = text
	_bubble.size = Vector2(360.0, 0.0)
	_bubble.reset_size()
	_bubble.visible = true
	if _tail != null:
		_tail.visible = true
	_bubble.modulate.a = 0.0
	_update_bubble_position()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bubble, "modulate:a", 1.0, 0.12)


func _hide_bubble() -> void:
	if _bubble != null:
		_bubble.visible = false
		_bubble.modulate.a = 0.0
	if _tail != null:
		_tail.visible = false
	_current_speaker = null


func _update_bubble_position() -> void:
	if _current_speaker == null or not is_instance_valid(_current_speaker) or _bubble == null or not _bubble.visible:
		return
	var anchor: Vector2 = _current_speaker.get_global_transform_with_canvas().origin
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var bsize: Vector2 = _bubble.get_combined_minimum_size()
	bsize.x = maxf(bsize.x, 360.0)
	_bubble.size = bsize
	var desired := Vector2(anchor.x - bsize.x * 0.5, anchor.y - _bubble_vertical_offset - bsize.y)
	_bubble.position = Vector2(
		clampf(desired.x, 14.0, maxf(14.0, viewport_size.x - bsize.x - 14.0)),
		clampf(desired.y, 92.0, maxf(92.0, viewport_size.y - bsize.y - 24.0))
	)
	if _tail != null:
		var tail_x: float = clampf(anchor.x, _bubble.position.x + 24.0, _bubble.position.x + bsize.x - 24.0)
		_tail.position = Vector2(tail_x, _bubble.position.y + bsize.y - 1.0)
