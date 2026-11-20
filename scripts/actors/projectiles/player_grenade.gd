class_name PlayerGrenade
extends Node2D

## Granada arcade 2.5D de Gabriel.
## O cronômetro de 2s começa no arremesso; o objeto aterrissa e permanece visível
## até a detonação. O dano é radial e inclui o próprio lançador quando estiver no raio.

const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")

@export var fuse_duration: float = 2.0
@export var flight_duration: float = 0.38
@export var throw_distance: float = 136.0
@export var throw_arc_height: float = 76.0
@export var blast_radius: float = 150.0
@export var enemy_damage: float = 46.0
@export var prop_damage: float = 56.0
@export var self_damage: float = 30.0
@export var enemy_knockback: float = 155.0
@export var self_knockback: float = 95.0
@export var explosion_frame_duration: float = 0.075

@onready var grenade_sprite: Sprite2D = $GrenadeSprite
@onready var explosion_sprite: Sprite2D = $ExplosionSprite

var thrower: Node = null
var _facing: float = 1.0
var _flight_origin: Vector2 = Vector2.ZERO
var _landing_position: Vector2 = Vector2.ZERO
var _fuse_elapsed: float = 0.0
var _flight_elapsed: float = 0.0
var _frame_elapsed: float = 0.0
var _blink_elapsed: float = 0.0
var _explosion_elapsed: float = 0.0
var _detonated: bool = false
var _launched: bool = false

## Bounce state
var _bounce_count: int = 0
var _max_bounces: int = 1
var _bounce_arc_height: float = 0.0
var _bounce_distance: float = 0.0
var _bounce_duration: float = 0.0
var _bounce_origin: Vector2 = Vector2.ZERO
var _bounce_target: Vector2 = Vector2.ZERO
var _bounce_elapsed: float = 0.0
var _is_bouncing: bool = false
var _settled: bool = false


func _ready() -> void:
	z_as_relative = true
	if explosion_sprite != null:
		explosion_sprite.visible = false
	set_process(false)


func launch(source: Node, facing: float) -> void:
	if source == null or not is_instance_valid(source):
		queue_free()
		return
	thrower = source
	_facing = -1.0 if facing < 0.0 else 1.0
	_flight_origin = source.global_position + Vector2(_facing * 34.0, -116.0)
	_landing_position = source.global_position + Vector2(_facing * throw_distance, 0.0)
	# O nó raiz permanece ancorado no ponto de aterrissagem para preservar
	# o Y-sort e manter a sombra no chão enquanto somente o sprite percorre o arco.
	global_position = _landing_position
	if grenade_sprite != null:
		grenade_sprite.global_position = _flight_origin + Vector2(0.0, -14.0)
	_fuse_elapsed = 0.0
	_flight_elapsed = 0.0
	_frame_elapsed = 0.0
	_blink_elapsed = 0.0
	_detonated = false
	_launched = true
	set_process(true)


func _process(delta: float) -> void:
	if not _launched:
		return
	if _detonated:
		_update_explosion(delta)
		return

	_fuse_elapsed += delta

	# Phase 1: initial arc flight
	if not _settled and not _is_bouncing:
		_flight_elapsed = minf(flight_duration, _flight_elapsed + delta)
		var flight_t: float = clampf(_flight_elapsed / maxf(flight_duration, 0.001), 0.0, 1.0)
		var flight_position: Vector2 = _flight_origin.lerp(_landing_position, flight_t)
		flight_position.y -= sin(flight_t * PI) * throw_arc_height
		if grenade_sprite != null:
			grenade_sprite.global_position = flight_position + Vector2(0.0, -14.0)
			grenade_sprite.rotation_degrees = lerpf(0.0, _facing * 360.0, flight_t)

		if flight_t >= 1.0:
			if _bounce_count < _max_bounces:
				_start_bounce()
			else:
				_settled = true
				if grenade_sprite != null:
					grenade_sprite.rotation_degrees = 0.0

	# Phase 2: bounce arc(s)
	elif _is_bouncing:
		_bounce_elapsed = minf(_bounce_duration, _bounce_elapsed + delta)
		var bt: float = clampf(_bounce_elapsed / maxf(_bounce_duration, 0.001), 0.0, 1.0)
		var bounce_pos: Vector2 = _bounce_origin.lerp(_bounce_target, bt)
		bounce_pos.y -= sin(bt * PI) * _bounce_arc_height
		if grenade_sprite != null:
			grenade_sprite.global_position = bounce_pos + Vector2(0.0, -14.0)
			grenade_sprite.rotation_degrees = lerpf(0.0, _facing * 180.0, bt)

		if bt >= 1.0:
			_bounce_count += 1
			_is_bouncing = false
			# Update the root node position to the bounce landing for correct blast center
			global_position = _bounce_target
			if _bounce_count < _max_bounces:
				_start_bounce()
			else:
				_settled = true
				if grenade_sprite != null:
					grenade_sprite.rotation_degrees = 0.0

	# Sprite frame cycling
	_frame_elapsed += delta
	if grenade_sprite != null and _frame_elapsed >= 0.09:
		_frame_elapsed = fmod(_frame_elapsed, 0.09)
		grenade_sprite.frame = (grenade_sprite.frame + 1) % 4

	# Pavio visual acelera o piscar na reta final, sem antecipar a detonação.
	if grenade_sprite != null and _fuse_elapsed >= fuse_duration - 0.9:
		_blink_elapsed += delta
		var blink_interval: float = lerpf(0.18, 0.055, clampf((_fuse_elapsed - (fuse_duration - 0.9)) / 0.9, 0.0, 1.0))
		if _blink_elapsed >= blink_interval:
			_blink_elapsed = 0.0
			grenade_sprite.modulate.a = 0.28 if grenade_sprite.modulate.a > 0.5 else 1.0

	if _fuse_elapsed >= fuse_duration:
		_detonate()
		return

	# Detecção de impacto direto contra inimigos ou o chefe Alessandro
	_check_impact_collision()


func _get_current_ground_position() -> Vector2:
	if _settled:
		return global_position
	if _is_bouncing:
		var bt: float = clampf(_bounce_elapsed / maxf(_bounce_duration, 0.001), 0.0, 1.0)
		return _bounce_origin.lerp(_bounce_target, bt)
	var flight_t: float = clampf(_flight_elapsed / maxf(flight_duration, 0.001), 0.0, 1.0)
	return _flight_origin.lerp(_landing_position, flight_t)


func _check_impact_collision() -> void:
	if _detonated or not _launched or get_tree() == null:
		return
	
	var current_ground: Vector2 = _get_current_ground_position()
	var current_sprite_y: float = grenade_sprite.global_position.y if grenade_sprite != null else current_ground.y
	
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy: Node in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var health: Node = enemy.get_node_or_null("HealthComponent")
		if health != null and "is_dead" in health and bool(health.get("is_dead")):
			continue
		if "is_dead" in enemy and bool(enemy.get("is_dead")):
			continue
		
		var enemy_2d: Node2D = enemy as Node2D
		var enemy_pos: Vector2 = enemy_2d.global_position
		
		# 1. Alinhamento de profundidade 2.5D no solo
		var depth_diff: float = absf(enemy_pos.y - current_ground.y)
		if depth_diff > 36.0:
			continue
		
		# 2. Contato horizontal: verifica largura do corpo/hurtbox
		var dist_x: float = absf(enemy_pos.x - current_ground.x)
		if dist_x > 40.0:
			continue
		
		# 3. Altura 2.5D: granada na altura do corpo do adversário (de Y=0 a Y=-200)
		var height_above_feet: float = enemy_pos.y - current_sprite_y
		if height_above_feet < -20.0 or height_above_feet > 220.0:
			continue
		
		# Contato confirmado! Detona imediatamente no ponto de impacto
		global_position = current_ground
		_detonate()
		return


func _start_bounce() -> void:
	_is_bouncing = true
	_bounce_elapsed = 0.0
	_bounce_origin = _landing_position if _bounce_count == 0 else _bounce_target
	_bounce_distance = throw_distance * 0.35
	_bounce_arc_height = throw_arc_height * 0.35
	_bounce_duration = flight_duration * 0.5
	_bounce_target = _bounce_origin + Vector2(_facing * _bounce_distance, 0.0)


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	global_position = _get_current_ground_position()
	if grenade_sprite != null:
		grenade_sprite.visible = false
	if explosion_sprite != null:
		explosion_sprite.visible = true
		explosion_sprite.frame = 0

	_apply_radial_damage()
	CombatFeedbackClass.trigger_screen_shake(self, 8.0, 0.28)
	CombatFeedbackClass.play_impact_sound(self, "heavy")


func _apply_radial_damage() -> void:
	if get_tree() == null:
		return
	var candidates: Array[Node] = get_tree().get_nodes_in_group("damageable")
	for target: Node in candidates:
		if target == null or not is_instance_valid(target) or not target is Node2D:
			continue
		var is_self: bool = target == thrower
		if not is_self:
			if target.is_in_group("npcs") or target.is_in_group("civilians") or target.is_in_group("allies") or target.is_in_group("player"):
				continue
			if not target.is_in_group("enemies") and not target.is_in_group("destructibles") and not target.is_in_group("destructible_props"):
				continue
			if target.is_in_group("enemies"):
				var health: Node = target.get_node_or_null("HealthComponent")
				if health != null and "is_dead" in health and bool(health.get("is_dead")):
					continue
			if ("is_broken" in target and bool(target.get("is_broken"))) or ("is_destroyed" in target and bool(target.get("is_destroyed"))):
				continue
		if not target.has_method("take_damage"):
			continue

		var target_2d: Node2D = target as Node2D
		var offset: Vector2 = target_2d.global_position - global_position
		# O eixo Y representa profundidade da pista 2.5D; a distância vertical
		# recebe peso menor que a distância horizontal, mas não é ignorada.
		var distance: float = Vector2(offset.x, offset.y * 0.78).length()
		if distance > blast_radius:
			continue

		var falloff: float = lerpf(0.58, 1.0, 1.0 - clampf(distance / blast_radius, 0.0, 1.0))
		var base_damage: float = self_damage if is_self else (prop_damage if target.is_in_group("destructibles") or target.is_in_group("destructible_props") else enemy_damage)
		var amount: float = base_damage * falloff
		var direction: Vector2 = offset.normalized()
		if direction == Vector2.ZERO:
			direction = Vector2(_facing, 0.0)
		var impact_position: Vector2 = target_2d.global_position + Vector2(-direction.x * 12.0, -92.0)
		if target.has_method("get_impact_point"):
			impact_position = target.call("get_impact_point", global_position, -direction.x)

		var damage_info: RefCounted = DamageInfoClass.new(
			amount,
			thrower,
			global_position,
			direction,
			"hazard",
			self_knockback if is_self else enemy_knockback,
			0.42,
			true,
			not is_self,
			0.045,
			"heavy",
			"upper_torso",
			impact_position
		)
		target.call("take_damage", damage_info)


func _update_explosion(delta: float) -> void:
	_explosion_elapsed += delta
	if explosion_sprite != null:
		var frame_index: int = int(floor(_explosion_elapsed / maxf(explosion_frame_duration, 0.001)))
		explosion_sprite.frame = mini(frame_index, 7)
	if _explosion_elapsed >= explosion_frame_duration * 8.0:
		queue_free()
