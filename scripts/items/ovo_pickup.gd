extends Node2D
class_name OvoPickup

## Item de cura fixa (+50 HP) posicionado no cenário.
## Mesma mecânica de proximidade, botão "Pegar" e feedback do CocaPickup,
## mas cura um valor absoluto em vez de porcentagem.

@export_range(1.0, 500.0, 1.0) var heal_amount: float = 50.0
@export_range(8.0, 160.0, 1.0) var pickup_range_x: float = 64.0
@export_range(4.0, 96.0, 1.0) var pickup_depth_tolerance: float = 28.0
@export_file("*.png") var item_texture_path: String = "res://assets/sprites/itens/ovo.png"

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const DroppedItemVisualsScript: Script = preload("res://scripts/items/dropped_item_visuals.gd")
const INTERACTIVE_PICKUPS_GROUP: StringName = &"interactive_dropped_pickups"

var _consumed: bool = false
var _player_in_range: bool = false
var _nearby_player: Node = null
var _registered_player: Node = null
var _hint_button: Button = null
var _visuals: Node2D = null

@onready var visual_root: Node2D = $Visual
@onready var item_sprite: Sprite2D = $Visual/Sprite
@onready var fallback_visual: Node2D = $Visual/Fallback


func _ready() -> void:
	y_sort_enabled = true
	z_index = 1
	add_to_group("health_pickups")
	add_to_group("dropped_items")
	add_to_group(INTERACTIVE_PICKUPS_GROUP)

	var old_shadow := get_node_or_null("Shadow") as CanvasItem
	if old_shadow != null:
		old_shadow.visible = false

	_load_item_texture()
	_setup_visuals()
	_build_interaction_hint()


func _setup_visuals() -> void:
	if visual_root == null:
		return
	_visuals = DroppedItemVisualsScript.new()
	_visuals.name = "DroppedItemVisuals"
	add_child(_visuals)
	_visuals.call("setup", visual_root, true, Vector2(30.0, 10.0), Vector2(38.0, 14.0))


func _build_interaction_hint() -> void:
	_hint_button = Button.new()
	_hint_button.name = "PickUpHint"
	_hint_button.text = "Pegar"
	_hint_button.scale = Vector2(2.0, 2.0)
	_hint_button.custom_minimum_size = Vector2(96.0, 48.0)
	_hint_button.size = Vector2(96.0, 48.0)
	_hint_button.position = Vector2(-96.0, -152.0)
	_hint_button.z_index = 100
	_hint_button.z_as_relative = false
	_hint_button.focus_mode = Control.FOCUS_NONE
	_hint_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint_button.add_theme_font_override("font", ARCADE_FONT)
	_hint_button.add_theme_font_size_override("font_size", 16)
	_hint_button.add_theme_color_override("font_color", Color(0.85, 1.0, 0.88, 1.0))
	_hint_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	_hint_button.add_theme_color_override("font_pressed_color", Color(0.60, 0.95, 0.65, 1.0))
	_hint_button.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.02, 1.0))
	_hint_button.add_theme_constant_override("outline_size", 4)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.025, 0.035, 0.055, 0.92)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(0.35, 0.95, 0.45, 0.95)
	normal_style.set_corner_radius_all(6)
	normal_style.content_margin_left = 12.0
	normal_style.content_margin_right = 12.0
	_hint_button.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.04, 0.10, 0.05, 0.96)
	hover_style.border_color = Color(0.55, 1.0, 0.60, 1.0)
	_hint_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.08, 0.18, 0.09, 0.98)
	_hint_button.add_theme_stylebox_override("pressed", pressed_style)

	_hint_button.pressed.connect(_on_hint_button_pressed)
	_hint_button.visible = false
	add_child(_hint_button)


func _on_hint_button_pressed() -> void:
	if _nearby_player != null and is_instance_valid(_nearby_player):
		try_consume(_nearby_player)


func _process(_delta: float) -> void:
	if _consumed:
		return

	var player_node: Node2D = _get_active_player()
	if player_node != null and is_instance_valid(player_node):
		var offset: Vector2 = player_node.global_position - global_position
		var in_range: bool = absf(offset.x) <= pickup_range_x and absf(offset.y) <= pickup_depth_tolerance
		if in_range != _player_in_range:
			_player_in_range = in_range
			_nearby_player = player_node if in_range else null
			if not in_range and _registered_player == player_node:
				_set_registered_player(null)
			_refresh_group_for_player(player_node)
		elif in_range:
			_refresh_group_for_player(player_node)
	elif _player_in_range:
		_player_in_range = false
		_nearby_player = null
		_set_registered_player(null)


func _get_active_player() -> Node2D:
	if _nearby_player != null and is_instance_valid(_nearby_player):
		return _nearby_player as Node2D
	if get_tree() != null:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and is_instance_valid(players[0]) and (players[0] is Node2D):
			return players[0] as Node2D
	return null


## Retorna true se o item estiver ao alcance e o jogador puder receber cura.
func can_offer_hint_to(player: Node) -> bool:
	if _consumed or not is_instance_valid(player) or not (player is Node2D):
		return false
	if not _player_in_range or _nearby_player != player:
		return false

	var health_component: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null or health_component.is_dead:
		return false
	if health_component.max_health <= 0.0 or health_component.current_health >= health_component.max_health:
		return false

	return true


func _refresh_group_for_player(player: Node) -> void:
	if get_tree() == null or player == null or not is_instance_valid(player) or not (player is Node2D):
		return

	var items: Array[Node] = get_tree().get_nodes_in_group(INTERACTIVE_PICKUPS_GROUP)
	var player_2d := player as Node2D

	var dialogue_already_open: bool = false
	for candidate: Node in items:
		if candidate.has_method("is_dialogue_open_for_player") and candidate.call("is_dialogue_open_for_player", player):
			dialogue_already_open = true
			break

	var preferred: Node = null
	var best_distance: float = INF
	if not dialogue_already_open:
		for candidate: Node in items:
			if candidate == null or not is_instance_valid(candidate):
				continue
			if not candidate.has_method("can_offer_hint_to") or not candidate.call("can_offer_hint_to", player):
				continue
			var cand_2d := candidate as Node2D
			if cand_2d == null:
				continue
			var distance_sq: float = cand_2d.global_position.distance_squared_to(player_2d.global_position)
			if distance_sq < best_distance or (
				is_equal_approx(distance_sq, best_distance)
				and (preferred == null or candidate.get_instance_id() < preferred.get_instance_id())
			):
				best_distance = distance_sq
				preferred = candidate

	for candidate: Node in items:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var is_selected: bool = (candidate == preferred)
		if candidate.has_method("set_hint_selected"):
			candidate.call("set_hint_selected", is_selected, player)


func set_hint_selected(selected: bool, player: Node) -> void:
	_set_hint_visible(selected)
	_set_registered_player(player if selected else null)


func _set_hint_visible(should_be_visible: bool) -> void:
	if _hint_button != null:
		_hint_button.visible = should_be_visible and not _consumed


func _set_registered_player(player: Node) -> void:
	if _registered_player == player:
		return
	if _registered_player != null and is_instance_valid(_registered_player):
		if _registered_player.has_method("unregister_interactable"):
			_registered_player.call("unregister_interactable", self)
	_registered_player = null

	if player != null and is_instance_valid(player):
		_registered_player = player
		if _registered_player.has_method("register_interactable"):
			_registered_player.call("register_interactable", self)


## Contrato de interação do Player (J / Gamepad / Mobile)
func interact(player: Node) -> bool:
	return try_consume(player)


func is_consumed() -> bool:
	return _consumed


func _load_item_texture() -> void:
	if item_texture_path.is_empty() or not ResourceLoader.exists(item_texture_path):
		return

	var loaded_texture: Texture2D = load(item_texture_path) as Texture2D
	if loaded_texture == null:
		return

	item_sprite.texture = loaded_texture
	fallback_visual.visible = false


## Consome o item se o jogador estiver perto e tiver vida para recuperar.
func try_consume(player: Node) -> bool:
	if _consumed or not is_instance_valid(player) or not (player is Node2D):
		return false

	var player_node: Node2D = player as Node2D
	var offset: Vector2 = player_node.global_position - global_position
	if absf(offset.x) > pickup_range_x or absf(offset.y) > pickup_depth_tolerance:
		return false

	var health_component: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null or health_component.is_dead:
		return false
	if health_component.max_health <= 0.0 or health_component.current_health >= health_component.max_health:
		return false

	var recovered: float = health_component.heal(heal_amount)
	if recovered <= 0.0:
		return false

	_consumed = true
	remove_from_group("health_pickups")
	remove_from_group("dropped_items")
	remove_from_group(INTERACTIVE_PICKUPS_GROUP)
	_set_hint_visible(false)
	_set_registered_player(null)

	CombatFeedback.play_pickup_sound(self, "coca")
	_spawn_heal_feedback(player_node, recovered)
	_play_consumed_animation()
	return true


## Mostra o ganho de vida sobre a cabeça do jogador.
func _spawn_heal_feedback(player_node: Node2D, recovered: float) -> void:
	if player_node == null or not is_instance_valid(player_node):
		return

	var feedback := Label.new()
	feedback.name = "HealPickupFeedback"
	feedback.text = "+%d HP" % int(recovered)
	feedback.add_theme_font_override("font", ARCADE_FONT)
	feedback.add_theme_font_size_override("font_size", 21)
	feedback.add_theme_color_override("font_color", Color(0.48, 1.0, 0.52, 1.0))
	feedback.add_theme_color_override("font_outline_color", Color(0.025, 0.075, 0.035, 1.0))
	feedback.add_theme_constant_override("outline_size", 6)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	feedback.size = Vector2(240.0, 42.0)
	feedback.modulate = Color(1.0, 1.0, 1.0, 0.0)
	feedback.z_index = 100
	feedback.z_as_relative = false
	feedback.process_mode = Node.PROCESS_MODE_ALWAYS
	feedback.add_to_group("pickup_feedback_labels")

	var spawn_position := Vector2(0.0, -220.0)
	var head_marker := player_node.get_node_or_null("ImpactZones/Head") as Node2D
	if head_marker != null:
		spawn_position = player_node.to_local(head_marker.global_position) + Vector2(0.0, -28.0)
	feedback.position = spawn_position - Vector2(feedback.size.x * 0.5, feedback.size.y * 0.5)
	player_node.add_child(feedback)
	var feedback_start_y: float = feedback.position.y

	var tween := feedback.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(feedback, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(feedback, "position:y", feedback_start_y - 42.0, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.28)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.22)
	tween.tween_callback(feedback.queue_free)


## Pisca três vezes e encolhe antes de desaparecer.
func _play_consumed_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	for blink_index: int in range(3):
		tween.tween_property(visual_root, "modulate:a", 0.12, 0.09)
		tween.tween_property(visual_root, "modulate:a", 1.0, 0.09)
	tween.tween_property(visual_root, "scale", Vector2(0.01, 0.01), 0.12)
	tween.tween_callback(queue_free)


func _exit_tree() -> void:
	_set_registered_player(null)
