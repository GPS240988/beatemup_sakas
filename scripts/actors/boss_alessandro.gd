class_name BossAlessandro
extends EnemyAI

## Controlador Especial do Chefe Alessandro (Fase 1 - O Gerente da Locadora).
## Utiliza os sprites oficiais em 250x330 e preserva a IA base do combate.

enum SpecialBehavior {
	NONE,
	THROWING_TRUFFLES
}

const TRUFFLE_SCENE: PackedScene = preload("res://scenes/actors/projectiles/trufa.tscn")
const TRUFFLE_COUNT: int = 3
const TRUFFLE_INTERVAL: float = 0.18
const TRUFFLE_INITIAL_COOLDOWN: float = 4.0
const TRUFFLE_COOLDOWN_PHASE_ONE: float = 8.0
const TRUFFLE_COOLDOWN_PHASE_TWO: float = 6.5

@onready var boss_name_label: Label = $Visual/BossNameLabel

var _attack_variant: int = 0
var _anim_locked: bool = false
var _special_behavior: SpecialBehavior = SpecialBehavior.NONE
var _truffle_cooldown: float = TRUFFLE_INITIAL_COOLDOWN
var _truffle_shot_timer: float = 0.0
var _truffles_remaining: int = 0


func _ready() -> void:
	# Configurações de Chefe (atributos superiores aos capangas normais)
	speed_x = 160.0
	speed_y = 110.0
	attack_horizontal_distance = 85.0
	attack_depth_tolerance = 22.0
	attack_windup_seconds = 0.20
	attack_cooldown = 0.65
	recoil_distance = 35.0
	recovery_duration = 0.35
	hurt_duration = 0.18
	chase_timeout_seconds = 4.0
	post_hurt_cooldown = 0.30

	super._ready()

	if health_component != null:
		health_component.max_health = 200.0
		health_component.current_health = 200.0
		if health_bar != null:
			health_bar.visible = false
			health_bar.max_value = 200.0
			health_bar.value = 200.0

	if melee_attack != null:
		melee_attack.damage = 25.0
		melee_attack.horizontal_range = 95.0
		melee_attack.depth_tolerance = 28.0

	if anim_sprite != null:
		anim_sprite.play("idle")


func _physics_process(delta: float) -> void:
	if _special_behavior != SpecialBehavior.NONE:
		_process_special_behavior(delta)
		move_and_slide()
		_update_boss_visuals()
		return

	super._physics_process(delta)
	_update_boss_visuals()

	if current_state == State.DEAD or player_target == null:
		return

	_truffle_cooldown = maxf(0.0, _truffle_cooldown - delta)
	if _truffle_cooldown <= 0.0 and _can_start_truffle_barrage():
		_start_truffle_barrage()


func _can_start_truffle_barrage() -> bool:
	if _special_behavior != SpecialBehavior.NONE:
		return false
	if current_state not in [State.FLANKING, State.WAITING, State.IDLE]:
		return false
	if melee_attack != null and melee_attack.is_attacking:
		return false
	return player_target != null and is_instance_valid(player_target)


func _start_truffle_barrage() -> void:
	_special_behavior = SpecialBehavior.THROWING_TRUFFLES
	_truffles_remaining = TRUFFLE_COUNT
	_truffle_shot_timer = 0.0
	velocity = Vector2.ZERO
	_release_combat_resources()

	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false
	if anim_sprite != null:
		_play_anim("guard")


func _process_special_behavior(delta: float) -> void:
	velocity = Vector2.ZERO
	if current_state == State.DEAD or health_component == null or health_component.is_dead:
		_finish_special_behavior()
		return

	match _special_behavior:
		SpecialBehavior.THROWING_TRUFFLES:
			_truffle_shot_timer -= delta
			if _truffle_shot_timer <= 0.0 and _truffles_remaining > 0:
				_throw_truffle()
				_truffles_remaining -= 1
				_truffle_shot_timer = TRUFFLE_INTERVAL

			if _truffles_remaining <= 0:
				_finish_special_behavior()


func _throw_truffle() -> void:
	if not is_instance_valid(player_target):
		return

	var truffle := TRUFFLE_SCENE.instantiate() as RigidBody2D
	if truffle == null:
		push_warning("BossAlessandro: não foi possível instanciar a trufa.")
		return

	var projectile_container: Node = get_parent()
	if projectile_container == null:
		truffle.free()
		return

	projectile_container.add_child(truffle)
	truffle.global_position = global_position + Vector2(facing_direction * 34.0, -105.0)

	var target_vector: Vector2 = player_target.global_position - truffle.global_position
	if target_vector.length_squared() < 1.0:
		target_vector = Vector2(facing_direction, 0.0)
	var base_angle: float = target_vector.normalized().angle()
	var spread_step: float = 0.13
	var shot_index: int = TRUFFLE_COUNT - _truffles_remaining
	var spread_angle: float = float(shot_index - 1) * spread_step
	var launch_direction := Vector2.RIGHT.rotated(base_angle + spread_angle)

	truffle.set("attacker", self)
	truffle.apply_central_impulse(launch_direction * 310.0)


func _finish_special_behavior() -> void:
	if _special_behavior == SpecialBehavior.NONE:
		return

	_special_behavior = SpecialBehavior.NONE
	_truffles_remaining = 0
	_truffle_shot_timer = 0.0
	_truffle_cooldown = (
		TRUFFLE_COOLDOWN_PHASE_TWO
		if health_component != null and health_component.current_health <= 100.0
		else TRUFFLE_COOLDOWN_PHASE_ONE
	)

	if current_state != State.DEAD:
		current_state = State.FLANKING
		_attack_timer = maxf(_attack_timer, 0.65)
		_play_anim("idle")


func _update_boss_visuals() -> void:
	if visual_root == null:
		return

	# Orientação horizontal da face
	if facing_direction != 0.0:
		visual_root.scale.x = abs(visual_root.scale.x) * facing_direction

	if anim_sprite == null or _anim_locked:
		return

	match current_state:
		State.IDLE, State.WAITING:
			if anim_sprite.animation != &"idle":
				anim_sprite.play("idle")
		State.FLANKING, State.ALIGNING_DEPTH, State.APPROACHING:
			if velocity.length_squared() > 25.0:
				if anim_sprite.animation != &"walk":
					anim_sprite.play("walk")
			else:
				if anim_sprite.animation != &"idle":
					anim_sprite.play("idle")
		State.TELEGRAPH:
			if anim_sprite.animation != &"idle" and anim_sprite.animation != &"guard":
				anim_sprite.play("idle")


func _trigger_attack() -> void:
	if melee_attack == null:
		return

	current_state = State.ATTACKING

	# Alterna variantes de ataque arcade (Soco -> Chute -> Combo -> Aéreo)
	_attack_variant = (_attack_variant + 1) % 4
	var anim_name: StringName = &"punch"
	match _attack_variant:
		0:
			anim_name = &"punch"
			melee_attack.damage = 20.0
			melee_attack.impact_profile = "punch"
			melee_attack.preferred_regions = ["head", "upper_torso"]
			melee_attack.hitbox_offset_y = -135.0
		1:
			anim_name = &"kick"
			melee_attack.damage = 25.0
			melee_attack.impact_profile = "kick"
			melee_attack.preferred_regions = ["lower_torso"]
			melee_attack.hitbox_offset_y = -75.0
		2:
			anim_name = &"combo"
			melee_attack.damage = 30.0
			melee_attack.impact_profile = "finisher"
			melee_attack.preferred_regions = ["upper_torso", "head"]
			melee_attack.hitbox_offset_y = -130.0
		3:
			anim_name = &"jump_atk"
			melee_attack.damage = 28.0
			melee_attack.impact_profile = "kick"
			melee_attack.preferred_regions = ["head"]
			melee_attack.hitbox_offset_y = -150.0

	if anim_sprite != null and anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)

	melee_attack.execute_attack(facing_direction)


func _on_attack_ended() -> void:
	super._on_attack_ended()
	if current_state != State.DEAD and current_state != State.HURT:
		if anim_sprite != null:
			anim_sprite.play("idle")


func _on_damaged(amount: float) -> void:
	# Ser atingido interrompe a preparação do ataque especial sem prender a IA.
	_finish_special_behavior()
	super._on_damaged(amount)
	if current_state == State.DEAD:
		return

	if anim_sprite != null and anim_sprite.sprite_frames.has_animation("hurt"):
		anim_sprite.play("hurt")


func _on_died() -> void:
	_special_behavior = SpecialBehavior.NONE
	_truffles_remaining = 0
	_truffle_shot_timer = 0.0
	super._on_died()
	_anim_locked = true

	# Restaura rotação para que a animação nativa de morte (deitado) seja exibida perfeitamente
	if visual_root != null:
		visual_root.rotation_degrees = 0.0
		visual_root.position.y = 0.0

	if anim_sprite != null and anim_sprite.sprite_frames.has_animation("death"):
		anim_sprite.play("death")
		anim_sprite.position = Vector2(0, -50) # Alinha o corpo deitado ao piso
