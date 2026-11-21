extends Node

## Escala somente a apresentação visual dos atores conforme a profundidade Y.
## A raiz CharacterBody2D continua sendo o ponto dos pés usado pela física e pelo Y-Sort.

@export var far_lane_y: float = 425.0
@export var near_lane_y: float = 662.0
@export_range(0.50, 1.00, 0.01) var far_scale: float = 0.82
@export_range(0.50, 1.20, 0.01) var near_scale: float = 1.0
@export_range(1.0, 30.0, 0.5) var smoothing_speed: float = 12.0

var _actors_root: Node
var _tracked_actors: Array[CharacterBody2D] = []
var _tracked_actor_ids: Array[int] = []
var _base_visual_scales: Dictionary = {}


func _ready() -> void:
	process_physics_priority = 100
	_actors_root = get_parent().get_node_or_null("World/Actors")
	get_tree().node_added.connect(_on_tree_node_added)

	# Registro único dos atores existentes; não há varredura de grupos por frame.
	for candidate in get_tree().get_nodes_in_group("actors"):
		_register_actor(candidate)


func _on_tree_node_added(node: Node) -> void:
	if node is CharacterBody2D:
		call_deferred("_register_actor", node)


func _register_actor(candidate: Node) -> void:
	var actor: CharacterBody2D = candidate as CharacterBody2D
	if actor == null or not actor.is_inside_tree() or not actor.is_in_group("actors"):
		return
	if _actors_root == null or not _actors_root.is_ancestor_of(actor):
		return

	var visual: Node2D = actor.get_node_or_null("Visual") as Node2D
	if visual == null:
		return

	var actor_id: int = actor.get_instance_id()
	if _base_visual_scales.has(actor_id):
		return

	_tracked_actors.append(actor)
	_tracked_actor_ids.append(actor_id)
	_base_visual_scales[actor_id] = Vector2(
		maxf(absf(visual.scale.x), 0.001),
		maxf(absf(visual.scale.y), 0.001)
	)


func _physics_process(delta: float) -> void:
	var blend: float = 1.0 - exp(-smoothing_speed * delta)
	for index in range(_tracked_actors.size() - 1, -1, -1):
		var actor: CharacterBody2D = _tracked_actors[index]
		var actor_id: int = _tracked_actor_ids[index]
		if not is_instance_valid(actor):
			_tracked_actors.remove_at(index)
			_tracked_actor_ids.remove_at(index)
			_base_visual_scales.erase(actor_id)
			continue

		var visual: Node2D = actor.get_node_or_null("Visual") as Node2D
		if visual == null:
			continue

		var base_scale: Vector2 = _base_visual_scales[actor_id]
		var depth_ratio: float = clampf(
			(actor.global_position.y - far_lane_y) / maxf(near_lane_y - far_lane_y, 1.0),
			0.0,
			1.0
		)
		var target_factor: float = lerpf(far_scale, near_scale, depth_ratio)
		var current_factor: float = visual.scale.y / base_scale.y
		var factor: float = lerpf(current_factor, target_factor, blend)
		var facing_sign: float = -1.0 if visual.scale.x < 0.0 else 1.0

		# Mantém facing horizontal e aplica escala uniforme sem tocar na raiz física.
		visual.scale = Vector2(base_scale.x * factor * facing_sign, base_scale.y * factor)
