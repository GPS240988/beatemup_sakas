extends Node2D

## Conversa ambiental não bloqueante entre os dois Pizza Brawlers do balcão.
## É disparada uma única vez quando o jogador entra no salão próximo à despensa.

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

const BANTER_LINES: Array[Dictionary] = [
	{
		"actor": "counter",
		"speaker": "BALCÃO",
		"text": "Na despensa, essa pizza tá azeda. Tem barata no queijo e rato dormindo no saco de farinha.",
		"duration": 3.2
	},
	{
		"actor": "side",
		"speaker": "COLEGA",
		"text": "E o orégano veio com uns pentelhos. Achei que era tempero novo.",
		"duration": 3.0
	},
	{
		"actor": "counter",
		"speaker": "BALCÃO",
		"text": "O gerente mandou peneirar e servir. Disse que proteína extra não se cobra.",
		"duration": 3.1
	},
	{
		"actor": "side",
		"speaker": "COLEGA",
		"text": "Você peneirou?! Eu vi a barata voltar pro pote depois!",
		"duration": 2.8
	},
	{
		"actor": "counter",
		"speaker": "BALCÃO",
		"text": "Fala baixo. Tem cliente vindo. Põe a pizza bonita na frente.",
		"duration": 2.8
	},
	{
		"actor": "side",
		"speaker": "COLEGA",
		"text": "A bonita é a que só tem duas baratas?! Eu vou pedir demissão.",
		"duration": 3.0
	}
]

@export var counter_speaker_path: NodePath
@export var side_speaker_path: NodePath
@export_range(240.0, 900.0, 10.0) var trigger_radius: float = 420.0
@export var bubble_vertical_offset: float = 330.0

var _counter_speaker: Node2D = null
var _side_speaker: Node2D = null
var _trigger: Area2D = null
var _canvas_layer: CanvasLayer = null
var _ui_root: Control = null
var _bubble: PanelContainer = null
var _speaker_label: Label = null
var _dialogue_label: Label = null
var _current_speaker: Node2D = null
var _line_index: int = -1
var _line_timer: float = 0.0
var _is_playing: bool = false
var _has_played: bool = false
var _fade_tween: Tween = null


func _ready() -> void:
	_counter_speaker = get_node_or_null(counter_speaker_path) as Node2D
	_side_speaker = get_node_or_null(side_speaker_path) as Node2D
	if _counter_speaker == null or _side_speaker == null:
		push_error("Map7CounterBanter: os dois interlocutores precisam existir no Map 7.")
		return

	_create_proximity_trigger()
	_create_speech_bubble()


func _process(delta: float) -> void:
	if not _is_playing:
		return

	_update_bubble_position()
	_line_timer -= delta
	if _line_timer <= 0.0:
		_show_next_line()


func _create_proximity_trigger() -> void:
	_trigger = Area2D.new()
	_trigger.name = "TriggerArea"
	_trigger.collision_layer = 0
	_trigger.collision_mask = 1
	_trigger.monitoring = true
	_trigger.monitorable = false
	add_child(_trigger)
	_trigger.global_position = (_counter_speaker.global_position + _side_speaker.global_position) * 0.5

	var shape := CircleShape2D.new()
	shape.radius = trigger_radius
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	_trigger.add_child(collision)
	_trigger.body_entered.connect(_on_trigger_body_entered)


func _create_speech_bubble() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "CounterBanterLayer"
	_canvas_layer.layer = 24
	add_child(_canvas_layer)

	_ui_root = Control.new()
	_ui_root.name = "CounterBanterRoot"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_ui_root)

	_bubble = PanelContainer.new()
	_bubble.name = "SpeechBubble"
	_bubble.custom_minimum_size = Vector2(420.0, 112.0)
	_bubble.size = _bubble.custom_minimum_size
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.modulate.a = 0.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.024, 0.038, 0.96)
	panel_style.border_color = Color(1.0, 0.78, 0.24, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(2)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_bottom = 10.0
	_bubble.add_theme_stylebox_override("panel", panel_style)
	_ui_root.add_child(_bubble)

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


func _on_trigger_body_entered(body: Node2D) -> void:
	if _has_played or body == null or not body.is_in_group("player"):
		return
	_has_played = true
	_is_playing = true
	_line_index = -1
	_trigger.set_deferred("monitoring", false)
	_show_next_line()


func _show_next_line() -> void:
	_line_index += 1
	if _line_index >= BANTER_LINES.size():
		_is_playing = false
		_bubble.visible = false
		return

	var line: Dictionary = BANTER_LINES[_line_index]
	_current_speaker = _counter_speaker if str(line.actor) == "counter" else _side_speaker
	_speaker_label.text = str(line.speaker)
	_dialogue_label.text = str(line.text)
	_line_timer = float(line.get("duration", 2.8))
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	_update_bubble_position()

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bubble, "modulate:a", 1.0, 0.12)


func _update_bubble_position() -> void:
	if _current_speaker == null or not is_instance_valid(_current_speaker) or _bubble == null:
		return

	var anchor: Vector2 = _current_speaker.get_global_transform_with_canvas().origin
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var desired := Vector2(anchor.x - _bubble.size.x * 0.5, anchor.y - bubble_vertical_offset)
	_bubble.position = Vector2(
		clampf(desired.x, 12.0, maxf(12.0, viewport_size.x - _bubble.size.x - 12.0)),
		clampf(desired.y, 90.0, maxf(90.0, viewport_size.y - _bubble.size.y - 18.0))
	)


func get_dialogue_line_count() -> int:
	return BANTER_LINES.size()


func get_dialogue_line(index: int) -> Dictionary:
	if index < 0 or index >= BANTER_LINES.size():
		return {}
	return BANTER_LINES[index].duplicate(true)
