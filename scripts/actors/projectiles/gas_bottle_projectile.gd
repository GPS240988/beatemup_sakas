class_name GasBottleProjectile
extends Area2D

## Garrafa arremessada pelo jogador na Fase 2-1.
## A raiz acompanha a pista 2.5D; somente sprite e hitbox recebem a elevação balística.
## O projétil detecta hurtboxes de alvos, nunca colisores sólidos do cenário.

const BOTTLE_TEXTURE: Texture2D = preload("res://assets/sprites/items/soda_glass_bottle.png")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")

@export_range(160.0, 700.0, 10.0) var speed: float = 540.0
@export_range(120.0, 500.0, 10.0) var max_distance: float = 340.0
@export_range(1.0, 80.0, 1.0) var damage: float = 26.0
@export_range(12.0, 120.0, 1.0) var depth_tolerance: float = 36.0
@export_range(16.0, 180.0, 4.0) var flight_arc_height: float = 38.0
@export_range(12.0, 72.0, 1.0) var landing_drop: float = 32.0
@export_range(0.0, 200.0, 1.0) var knockback_force: float = 92.0

@onready var bottle_sprite: Sprite2D = $BottleSprite as Sprite2D
@onready var bottle_shape: CollisionShape2D = $CollisionShape2D as CollisionShape2D

var thrower: Node = null
var _facing: float = 1.0
var _aim_direction: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0
var _flight_duration: float = 0.0
var _flight_gravity: float = 0.0
var _initial_vertical_velocity: float = 0.0
var _flight_apex_time: float = 0.0
var _launched: bool = false
var _has_hit: bool = false


func _ready() -> void:
	add_to_group("projectiles")
	add_to_group("player_projectiles")
	add_to_group("gas_bottle_projectile")
	y_sort_enabled = true
	# Faixa de renderização do projétil: sobre props comuns (Z 0), sob Foreground (Z 10).
	# Evita que a garrafa seja encoberta por sprites grandes de bombas/props estáticos.
	z_index = 5
	z_as_relative = false
	collision_layer = 8
	# Layer 2: mundo sólido / obstáculos do mapa; Layer 3: hurtboxes de props; Layer 4: hurtboxes de inimigos.
	collision_mask = 14
	monitoring = true
	monitorable = false
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if bottle_sprite != null:
		bottle_sprite.texture = BOTTLE_TEXTURE
		bottle_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bottle_sprite.region_enabled = false
		bottle_sprite.scale = Vector2(0.20, 0.20)
	if bottle_shape != null and bottle_shape.shape is CircleShape2D:
		(bottle_shape.shape as CircleShape2D).radius = 11.0
	set_physics_process(false)


func launch(source: Node, facing: float, aim_direction: Vector2 = Vector2.ZERO) -> void:
	if source == null or not is_instance_valid(source):
		queue_free()
		return
	var source_2d: Node2D = source as Node2D
	if source_2d == null:
		queue_free()
		return

	thrower = source
	_facing = -1.0 if facing < 0.0 else 1.0
	_aim_direction = aim_direction
	if _aim_direction.length_squared() < 0.01:
		_aim_direction = Vector2(_facing, 0.0)
	else:
		_aim_direction = _aim_direction.normalized()
	_facing = -1.0 if _aim_direction.x < 0.0 else 1.0
	# O deslocamento inicial já respeita a pista escolhida sem mover a origem do atacante.
	global_position = source_2d.global_position + _aim_direction * 36.0
	_elapsed = 0.0
	_flight_duration = max_distance / maxf(speed, 1.0)
	_flight_duration = maxf(_flight_duration, 0.01)
	# Física balística independente do deslocamento no plano 2.5D (eixo Y).
	# A raiz segue a pista; a altura aparente é aplicada somente ao sprite e hitbox.
	var root_term: float = sqrt(2.0 * flight_arc_height) + sqrt(2.0 * (flight_arc_height + landing_drop))
	_flight_gravity = root_term * root_term / (_flight_duration * _flight_duration)
	_initial_vertical_velocity = -sqrt(2.0 * flight_arc_height * _flight_gravity)
	_flight_apex_time = -_initial_vertical_velocity / _flight_gravity
	_has_hit = false
	_launched = true
	_update_flight_pose(0.0)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _launched or _has_hit:
		return
	if thrower == null or not is_instance_valid(thrower):
		queue_free()
		return

	# Constant planar speed + gravity produce a true ballistic parabola.
	# Clamp the final step so the projectile lands exactly at max_distance.
	var remaining_time: float = maxf(_flight_duration - _elapsed, 0.0)
	var step_time: float = minf(delta, remaining_time)
	global_position += _aim_direction * speed * step_time
	_elapsed += step_time
	_update_flight_pose(_elapsed)

	if _elapsed >= _flight_duration:
		_break_bottle()


func _update_flight_pose(elapsed: float) -> void:
	# y(t) = v0*t + 1/2*g*t². The apex is flight_arc_height above
	# the release point; the endpoint is landing_drop lower, near the floor.
	var vertical_displacement: float = _initial_vertical_velocity * elapsed + 0.5 * _flight_gravity * elapsed * elapsed
	var vertical_velocity: float = _initial_vertical_velocity + _flight_gravity * elapsed
	var sprite_y: float = -58.0 + vertical_displacement

	if bottle_sprite != null:
		bottle_sprite.position = Vector2(0.0, sprite_y)
		# A inclinação acompanha a direção do movimento ao longo do voo.
		var flight_tangent: Vector2 = Vector2(
			_aim_direction.x * speed,
			_aim_direction.y * speed + vertical_velocity
		)
		bottle_sprite.rotation = flight_tangent.angle() + PI * 0.5
	if bottle_shape != null:
		bottle_shape.position = Vector2(0.0, sprite_y)


func _on_area_entered(area: Area2D) -> void:
	if _has_hit or area == null or not is_instance_valid(area):
		return
	_try_hit(area)


func _on_body_entered(body: Node) -> void:
	if _has_hit or body == null or not is_instance_valid(body):
		return
	if body == thrower:
		return
	if body.is_in_group("player") or body.is_in_group("npcs") or body.is_in_group("civilians") or body.is_in_group("allies"):
		return
	if body.is_in_group("enemies") or body.is_in_group("setpiece_punk") or body.is_in_group("destructibles") or body.is_in_group("destructible_props") or body.is_in_group("vehicles"):
		_try_hit(body)
		return
	# Colisão com corpo físico / obstáculo sólido do mapa (Layer 2)
	_hit_map_obstacle(body)


func _hit_map_obstacle(_obstacle: Node) -> void:
	if _has_hit:
		return
	_has_hit = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	var hit_pos: Vector2 = bottle_shape.global_position if bottle_shape != null else global_position
	CombatFeedbackClass.spawn_hit_spark(self, hit_pos, _aim_direction, "heavy", "upper_torso")
	CombatFeedbackClass.play_impact_sound(self, "glass_shatter")
	_play_blink_and_shatter()


func _try_hit(collider: Node) -> bool:
	if _has_hit or collider == null or not is_instance_valid(collider):
		return false

	var target: Node = _find_target_actor(collider)
	if target == null or target == thrower or not target is Node2D:
		return false
	if target.is_in_group("enemies"):
		var health_node: Node = target.get_node_or_null("HealthComponent")
		if health_node != null and "is_dead" in health_node and bool(health_node.get("is_dead")):
			return false
		if "is_dead" in target and bool(target.get("is_dead")):
			return false
	if ("is_broken" in target and bool(target.get("is_broken"))) or ("is_destroyed" in target and bool(target.get("is_destroyed"))):
		return false

	var target_2d: Node2D = target as Node2D
	# A caçamba ocupa outra faixa: somente os punks da set piece recebem tolerância ampliada.
	var allowed_depth_tolerance: float = depth_tolerance
	if target.is_in_group("setpiece_punk"):
		allowed_depth_tolerance = maxf(allowed_depth_tolerance, 104.0)
	if absf(target_2d.global_position.y - global_position.y) > allowed_depth_tolerance:
		return false
	if _is_actor_jumping(target):
		return false

	var impact_probe_position: Vector2 = bottle_shape.global_position if bottle_shape != null else global_position + Vector2(0.0, -58.0)
	var impact_position: Vector2 = impact_probe_position
	if target.has_method("get_impact_point"):
		impact_position = target.call("get_impact_point", impact_probe_position, _facing)

	var damage_info := DamageInfoClass.new(
		damage,
		thrower,
		(thrower as Node2D).global_position,
		_aim_direction,
		"bottle_projectile",
		knockback_force,
		0.28,
		true,
		false,
		0.033,
		"bottle",
		"upper_torso",
		impact_position
	)

	var applied: bool = false
	if target.has_method("take_damage"):
		applied = bool(target.call("take_damage", damage_info))
	else:
		var target_health: Node = target.get_node_or_null("HealthComponent")
		if target_health != null and target_health.has_method("take_damage"):
			applied = bool(target_health.call("take_damage", damage_info))
	if not applied:
		return false

	_has_hit = true
	CombatFeedbackClass.spawn_hit_spark(self, impact_position, _aim_direction, "heavy", "upper_torso")
	CombatFeedbackClass.apply_hitstop(thrower, target, 0.033)

	var is_bebado: bool = target is BebadoEnemy or target.is_in_group("bebado") or target.name.to_lower().contains("bebado")
	if is_bebado:
		damage_info.burp_played = true
		CombatFeedbackClass.play_bebado_burp(target)
	CombatFeedbackClass.play_impact_sound(self, "glass_shatter")
	if thrower.has_method("_on_projectile_hit"):
		thrower.call("_on_projectile_hit", target, damage)
	_play_blink_and_shatter()
	return true


func _find_target_actor(start_node: Node) -> Node:
	var candidate: Node = start_node
	while candidate != null:
		if candidate.is_in_group("player") or candidate.is_in_group("npcs") or candidate.is_in_group("civilians") or candidate.is_in_group("allies"):
			return null
		if candidate.is_in_group("enemies") or candidate.is_in_group("setpiece_punk") or candidate.is_in_group("destructibles") or candidate.is_in_group("destructible_props") or candidate.is_in_group("vehicles"):
			return candidate
		candidate = candidate.get_parent()
	return null


func _is_actor_jumping(actor: Node) -> bool:
	if actor != null and actor.is_in_group("setpiece_punk"):
		return false
	if "_is_jumping" in actor and bool(actor.get("_is_jumping")):
		return true
	var visual: Node2D = actor.get_node_or_null("Visual") as Node2D
	return visual != null and visual.position.y <= -12.0


func _break_bottle() -> void:
	if _has_hit:
		return
	_has_hit = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	CombatFeedbackClass.play_impact_sound(self, "glass_shatter")
	_play_blink_and_shatter()


func _play_blink_and_shatter() -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)
	if bottle_shape != null and is_instance_valid(bottle_shape):
		bottle_shape.set_deferred("disabled", true)
	if bottle_sprite == null or not is_instance_valid(bottle_sprite):
		queue_free()
		return
	# Piscar e sumir: modulação de flash visível e estilhaçamento cadenciado mais perceptível
	var tween: Tween = create_tween()
	if tween != null:
		tween.tween_property(bottle_sprite, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.08)
		tween.tween_property(bottle_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.25), 0.07)
		tween.tween_property(bottle_sprite, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.08)
		tween.tween_property(bottle_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.25), 0.07)
		tween.tween_property(bottle_sprite, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.08)
		tween.tween_property(bottle_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.08)
		tween.tween_callback(queue_free)
	else:
		queue_free()
