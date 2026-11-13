class_name AlessandroTruffle
extends RigidBody2D

## Projétil de trufa lançado por Alessandro.
## O corpo físico ricocheteia no mundo; a Hitbox separada respeita o contrato 2.5D.

const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

const DAMAGE: float = 10.0
const KNOCKBACK_FORCE: float = 55.0
const HITSTUN_DURATION: float = 0.22
const HITSTOP_DURATION: float = 0.025
const MAX_BOUNCES: int = 4

@export var attacker: Node

@onready var hitbox: Area2D = $Hitbox
@onready var lifetime_timer: Timer = $LifetimeTimer

var _has_hit: bool = false
var _bounces_remaining: int = MAX_BOUNCES


func _ready() -> void:
	add_to_group("alessandro_truffles")
	if hitbox != null:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	if lifetime_timer != null:
		lifetime_timer.timeout.connect(queue_free)
	body_entered.connect(_on_world_body_entered)


func _on_world_body_entered(_body: Node) -> void:
	if _has_hit:
		return
	_bounces_remaining -= 1
	if _bounces_remaining <= 0:
		queue_free()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if _has_hit or area == null or not is_instance_valid(area):
		return

	var player_actor: Node = _find_player_actor(area)
	if player_actor == null:
		return

	# O salto desloca apenas o nó Visual no eixo vertical; a origem física e a
	# Hurtbox permanecem no chão. A trufa é anulada se o jogador estiver no ar.
	if _is_player_jumping(player_actor):
		_show_miss_feedback(player_actor)
		_has_hit = true
		queue_free()
		return

	var health: HealthComponent = player_actor.get_node_or_null("HealthComponent") as HealthComponent
	var hit_direction: Vector2 = Vector2.RIGHT
	if player_actor is Node2D:
		var direction_vector: Vector2 = (player_actor as Node2D).global_position - global_position
		if direction_vector.length_squared() > 0.001:
			hit_direction = direction_vector.normalized()

	var impact_position: Vector2 = global_position
	var damage_info: RefCounted = DamageInfoClass.new(
		DAMAGE,
		attacker,
		global_position,
		hit_direction,
		"projectile",
		KNOCKBACK_FORCE,
		HITSTUN_DURATION,
		false,
		false,
		HITSTOP_DURATION,
		"kick",
		"upper_torso",
		impact_position
	)

	var applied: bool = false
	if health != null:
		applied = health.take_damage(damage_info)
	elif player_actor.has_method("take_damage"):
		applied = bool(player_actor.call("take_damage", damage_info))

	if applied:
		_has_hit = true
		queue_free()


func _is_player_jumping(player_actor: Node) -> bool:
	for property_info: Dictionary in player_actor.get_property_list():
		if str(property_info.get("name", "")) == "_is_jumping":
			return bool(player_actor.get("_is_jumping"))
	return false


func _show_miss_feedback(player_actor: Node) -> void:
	var actor_2d: Node2D = player_actor as Node2D
	var feedback_parent: Node = actor_2d.get_parent() if actor_2d != null and actor_2d.get_parent() is Node2D else player_actor
	var feedback := Label.new()
	feedback.name = "TruffleMissFeedback"
	feedback.text = "MISS"
	feedback.add_theme_font_override("font", ARCADE_FONT)
	feedback.add_theme_font_size_override("font_size", 24)
	feedback.add_theme_color_override("font_color", Color(1.0, 0.92, 0.28, 1.0))
	feedback.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	feedback.add_theme_constant_override("outline_size", 6)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	feedback.size = Vector2(120.0, 40.0)
	feedback.top_level = true
	feedback.z_index = 100
	feedback.z_as_relative = false
	feedback.process_mode = Node.PROCESS_MODE_ALWAYS
	feedback_parent.add_child(feedback)
	if actor_2d != null:
		# Coordenada global do jogador: o MISS não depende da posição do boss,
		# da orientação do sprite nem da transformação do container de atores.
		feedback.global_position = actor_2d.global_position + Vector2(-60.0, -210.0)
	else:
		feedback.position = Vector2(-60.0, -210.0)

	var tween: Tween = feedback.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(feedback, "position:y", -250.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.55).set_delay(0.12)
	tween.chain().tween_callback(feedback.queue_free)


func _find_player_actor(start_node: Node) -> Node:
	var candidate: Node = start_node
	while candidate != null:
		if candidate.is_in_group("player"):
			return candidate
		candidate = candidate.get_parent()
	return null
