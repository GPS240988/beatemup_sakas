class_name Map5TruckAttackStone
extends Area2D

## Pedra lançada pelos punks da set piece.
## A trajetória é balística visual, independente da colisão do mundo, para
## atravessar a fronteira da calçada sem colidir com a barreira do jogador.

const STONE_TEXTURE: Texture2D = preload(
	"res://assets/sprites/stage2/truck_attack_sequence/stone.png"
)
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")

var _source: Node = null
var _target_position := Vector2.ZERO
var _start_position := Vector2.ZERO
var _elapsed: float = 0.0
var _duration: float = 0.0
var _arc_height: float = 74.0
var _damage: float = 8.0
var _direction := Vector2.RIGHT
var _consumed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	add_to_group("projectiles")
	add_to_group("setpiece_stone_projectile")
	collision_layer = 8
	collision_mask = 1
	monitoring = true
	monitorable = false
	z_index = 4
	z_as_relative = false

	var sprite := Sprite2D.new()
	sprite.name = "StoneSprite"
	sprite.texture = STONE_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2.ZERO
	add_child(sprite)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)


func launch(source: Node, start_position: Vector2, target_position: Vector2, damage: float) -> void:
	_source = source
	_start_position = start_position
	_target_position = target_position
	_damage = damage
	global_position = start_position

	var distance: float = _start_position.distance_to(_target_position)
	_duration = clampf(distance / 380.0, 0.42, 1.20)
	_elapsed = 0.0
	_consumed = false
	_direction = (_target_position - _start_position).normalized()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _consumed:
		return

	_elapsed += delta
	var t: float = clampf(_elapsed / maxf(_duration, 0.01), 0.0, 1.0)
	var planar: Vector2 = _start_position.lerp(_target_position, t)
	planar.y -= 4.0 * _arc_height * t * (1.0 - t)
	global_position = planar

	var sprite := get_node_or_null("StoneSprite") as Sprite2D
	if sprite != null:
		sprite.rotation = _direction.angle() + t * PI * 2.0

	if t >= 1.0:
		_consume()


func _on_body_entered(body: Node) -> void:
	if _consumed or body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("player"):
		return

	var impact_position := global_position + Vector2(0.0, -4.0)
	var info := DamageInfoClass.new(
		_damage,
		_source,
		_start_position,
		_direction,
		"stone_projectile",
		54.0,
		0.16,
		true,
		false,
		0.033,
		"heavy",
		"upper_torso",
		impact_position
	)

	var applied: bool = false
	if body.has_method("take_damage"):
		applied = bool(body.call("take_damage", info))

	_consumed = true
	if applied:
		CombatFeedbackClass.spawn_hit_spark(
			self,
			impact_position,
			_direction,
			"heavy",
			"upper_torso"
		)
	queue_free()


func _consume() -> void:
	if _consumed:
		return
	_consumed = true
	queue_free()
