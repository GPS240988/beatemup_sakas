class_name BossAlessandro
extends EnemyAI

## Controlador do chefe Alessandro — gerente da locadora.
## Mantém os contratos da IA base e adiciona pressão de longa duração,
## salvas de trufas ricocheteantes e arrancadas evasivas 2.5D.

enum SpecialBehavior {
	NONE,
	TRUFFLE_WINDUP,
	THROWING_TRUFFLES,
	EVADING
}

const TRUFFLE_SCENE: PackedScene = preload("res://scenes/actors/projectiles/trufa.tscn")
const TRUFFLE_COUNT: int = 3
const TRUFFLE_WINDUP_SECONDS: float = 0.42
const TRUFFLE_INTERVAL: float = 0.18
const TRUFFLE_IMPULSE: float = 330.0
const TRUFFLE_INITIAL_COOLDOWN: float = 3.8
const TRUFFLE_COOLDOWN_PHASE_ONE: float = 8.0
const TRUFFLE_COOLDOWN_PHASE_TWO: float = 6.0

const BOSS_MAX_HEALTH: float = 1000.0
const PHASE_TWO_HEALTH_RATIO: float = 0.5

const EVADE_TRIGGER_DISTANCE: float = 112.0
const EVADE_DEPTH_TOLERANCE: float = 48.0
const EVADE_INITIAL_COOLDOWN: float = 2.0
const EVADE_COOLDOWN_PHASE_ONE: float = 5.8
const EVADE_COOLDOWN_PHASE_TWO: float = 4.5
const EVADE_DURATION_PHASE_ONE: float = 0.58
const EVADE_DURATION_PHASE_TWO: float = 0.62
const EVADE_SPEED_X_PHASE_ONE: float = 390.0
const EVADE_SPEED_Y_PHASE_ONE: float = 220.0
const EVADE_SPEED_X_PHASE_TWO: float = 470.0
const EVADE_SPEED_Y_PHASE_TWO: float = 280.0

@onready var boss_name_label: Label = $Visual/BossNameLabel

var _attack_variant: int = 0
var _anim_locked: bool = false
var _special_behavior: SpecialBehavior = SpecialBehavior.NONE
var _special_timer: float = 0.0
var _truffle_cooldown: float = TRUFFLE_INITIAL_COOLDOWN
var _truffle_shot_timer: float = 0.0
var _truffles_remaining: int = 0
var _active_truffles: Array[Node2D] = []
var _evasion_cooldown: float = EVADE_INITIAL_COOLDOWN
var _evasion_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Perfil de chefe: mais resistente, mas ainda sujeito a controle e punição.
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
		health_component.max_health = BOSS_MAX_HEALTH
		health_component.current_health = BOSS_MAX_HEALTH
		health_component.health_changed.emit(
			health_component.current_health,
			health_component.max_health
		)
		if health_bar != null:
			health_bar.visible = false
			health_bar.max_value = BOSS_MAX_HEALTH
			health_bar.value = BOSS_MAX_HEALTH

	if melee_attack != null:
		melee_attack.damage = 25.0
		melee_attack.horizontal_range = 95.0
		melee_attack.depth_tolerance = 28.0

	if anim_sprite != null:
		anim_sprite.play("idle")


func _physics_process(delta: float) -> void:
	# A IA base continua sendo a autoridade do hitstop local.
	if is_in_hitstop():
		super._physics_process(delta)
		_update_boss_visuals()
		return

	if _special_behavior != SpecialBehavior.NONE:
		_process_special_behavior(delta)
		move_and_slide()
		_update_boss_visuals()
		return

	super._physics_process(delta)
	_update_boss_visuals()

	if current_state == State.DEAD or not _is_player_target_valid():
		return

	_truffle_cooldown = maxf(0.0, _truffle_cooldown - delta)
	_evasion_cooldown = maxf(0.0, _evasion_cooldown - delta)

	# A fuga tem prioridade para dar ao jogador uma mudança legível de ritmo.
	if _try_start_evasion():
		return

	if _truffle_cooldown <= 0.0 and _can_start_truffle_barrage():
		_start_truffle_barrage()


func _is_player_target_valid() -> bool:
	if player_target == null or not is_instance_valid(player_target):
		return false
	var player_health: HealthComponent = player_target.get_node_or_null("HealthComponent") as HealthComponent
	return player_health == null or not player_health.is_dead


func _is_phase_two() -> bool:
	return health_component != null and health_component.current_health <= BOSS_MAX_HEALTH * PHASE_TWO_HEALTH_RATIO


func _can_start_truffle_barrage() -> bool:
	if _special_behavior != SpecialBehavior.NONE or not _is_player_target_valid():
		return false
	if current_state not in [State.FLANKING, State.WAITING, State.IDLE]:
		return false
	if melee_attack != null and melee_attack.is_attacking:
		return false
	return true


func _start_truffle_barrage() -> void:
	if not _can_start_truffle_barrage():
		return

	_special_behavior = SpecialBehavior.TRUFFLE_WINDUP
	_special_timer = TRUFFLE_WINDUP_SECONDS
	_truffle_shot_timer = 0.0
	_truffles_remaining = TRUFFLE_COUNT
	velocity = Vector2.ZERO
	_release_combat_resources()

	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false
	if anim_sprite != null:
		_play_anim("guard")


func _process_special_behavior(delta: float) -> void:
	if current_state == State.DEAD or health_component == null or health_component.is_dead:
		_finish_special_behavior()
		return
	if not _is_player_target_valid():
		_finish_special_behavior()
		return

	match _special_behavior:
		SpecialBehavior.TRUFFLE_WINDUP:
			velocity = Vector2.ZERO
			_special_timer = maxf(0.0, _special_timer - delta)
			if _special_timer <= 0.0:
				_special_behavior = SpecialBehavior.THROWING_TRUFFLES
				_truffle_shot_timer = 0.0

		SpecialBehavior.THROWING_TRUFFLES:
			velocity = Vector2.ZERO
			_truffle_shot_timer -= delta
			if _truffle_shot_timer <= 0.0 and _truffles_remaining > 0:
				_throw_truffle()
				_truffles_remaining -= 1
				_truffle_shot_timer = TRUFFLE_INTERVAL
			if _truffles_remaining <= 0:
				_finish_special_behavior()

		SpecialBehavior.EVADING:
			_process_evasion(delta)


func _throw_truffle() -> void:
	if not _is_player_target_valid():
		return

	var truffle: RigidBody2D = TRUFFLE_SCENE.instantiate() as RigidBody2D
	if truffle == null:
		push_warning("BossAlessandro: não foi possível instanciar o projétil de trufa.")
		return

	var projectile_container: Node = get_parent()
	if projectile_container == null:
		truffle.free()
		return

	projectile_container.add_child(truffle)
	truffle.global_position = global_position + Vector2(facing_direction * 34.0, 0.0)
	truffle.set("attacker", self)
	truffle.tree_exiting.connect(_on_truffle_tree_exiting.bind(truffle), CONNECT_ONE_SHOT)
	_active_truffles.append(truffle)

	# Mira no centro real da Hurtbox do jogador, não na origem dos pés.
	var target_point: Vector2 = player_target.global_position
	var player_hurtbox: Area2D = player_target.get_node_or_null("Hurtbox") as Area2D
	if player_hurtbox != null:
		target_point = player_hurtbox.global_position

	var target_vector: Vector2 = target_point - truffle.global_position
	if target_vector.length_squared() < 1.0:
		target_vector = Vector2(facing_direction, 0.0)

	var shot_index: int = TRUFFLE_COUNT - _truffles_remaining
	var spread_angle: float = float(shot_index - 1) * 0.13
	var launch_direction: Vector2 = Vector2.RIGHT.rotated(target_vector.normalized().angle() + spread_angle)
	truffle.apply_central_impulse(launch_direction * TRUFFLE_IMPULSE)


func _on_truffle_tree_exiting(truffle: Node2D) -> void:
	_active_truffles.erase(truffle)


func _clear_active_truffles() -> void:
	var pending: Array[Node2D] = _active_truffles.duplicate()
	_active_truffles.clear()
	for truffle: Node2D in pending:
		if is_instance_valid(truffle):
			truffle.queue_free()


func _can_start_evasion() -> bool:
	if _special_behavior != SpecialBehavior.NONE or not _is_player_target_valid():
		return false
	if current_state not in [State.FLANKING, State.WAITING, State.IDLE, State.ALIGNING_DEPTH, State.APPROACHING]:
		return false
	if melee_attack != null and melee_attack.is_attacking:
		return false

	var horizontal_distance: float = absf(player_target.global_position.x - global_position.x)
	var depth_distance: float = absf(player_target.global_position.y - global_position.y)
	return horizontal_distance <= EVADE_TRIGGER_DISTANCE and depth_distance <= EVADE_DEPTH_TOLERANCE


func _try_start_evasion() -> bool:
	if _evasion_cooldown > 0.0 or not _can_start_evasion():
		return false
	_start_evasion()
	return true


func _start_evasion() -> void:
	if not _is_player_target_valid():
		return

	_release_combat_resources()
	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false

	var escape_x: float = signf(global_position.x - player_target.global_position.x)
	if is_zero_approx(escape_x):
		escape_x = -facing_direction if not is_zero_approx(facing_direction) else 1.0
	var escape_y: float = signf(global_position.y - player_target.global_position.y)
	_evasion_direction = Vector2(escape_x, escape_y * 0.35).normalized()
	if _evasion_direction.length_squared() < 0.01:
		_evasion_direction = Vector2(escape_x, 0.0)

	facing_direction = escape_x
	_special_behavior = SpecialBehavior.EVADING
	_special_timer = EVADE_DURATION_PHASE_TWO if _is_phase_two() else EVADE_DURATION_PHASE_ONE
	_evasion_cooldown = EVADE_COOLDOWN_PHASE_TWO if _is_phase_two() else EVADE_COOLDOWN_PHASE_ONE
	velocity = Vector2.ZERO

	if anim_sprite != null:
		anim_sprite.speed_scale = 1.5 if _is_phase_two() else 1.35
		_play_anim("walk")


func _process_evasion(delta: float) -> void:
	_special_timer = maxf(0.0, _special_timer - delta)
	var run_x: float = EVADE_SPEED_X_PHASE_TWO if _is_phase_two() else EVADE_SPEED_X_PHASE_ONE
	var run_y: float = EVADE_SPEED_Y_PHASE_TWO if _is_phase_two() else EVADE_SPEED_Y_PHASE_ONE
	velocity = Vector2(_evasion_direction.x * run_x, _evasion_direction.y * run_y)
	if _special_timer <= 0.0:
		_finish_special_behavior()


func _finish_special_behavior() -> void:
	if _special_behavior == SpecialBehavior.NONE:
		return

	var finished_behavior: SpecialBehavior = _special_behavior
	_special_behavior = SpecialBehavior.NONE
	_special_timer = 0.0
	_truffle_shot_timer = 0.0
	_truffles_remaining = 0

	if finished_behavior in [SpecialBehavior.TRUFFLE_WINDUP, SpecialBehavior.THROWING_TRUFFLES]:
		_truffle_cooldown = TRUFFLE_COOLDOWN_PHASE_TWO if _is_phase_two() else TRUFFLE_COOLDOWN_PHASE_ONE
	if finished_behavior == SpecialBehavior.EVADING and anim_sprite != null:
		anim_sprite.speed_scale = 1.0

	if current_state != State.DEAD:
		velocity = Vector2.ZERO
		current_state = State.FLANKING
		_attack_timer = maxf(_attack_timer, 0.75)
		_play_anim("idle")


func _update_boss_visuals() -> void:
	if visual_root == null:
		return

	if facing_direction != 0.0:
		visual_root.scale.x = absf(visual_root.scale.y) * facing_direction

	if anim_sprite == null or _anim_locked:
		return

	match _special_behavior:
		SpecialBehavior.TRUFFLE_WINDUP, SpecialBehavior.THROWING_TRUFFLES:
			_play_anim("guard")
			return
		SpecialBehavior.EVADING:
			_play_anim("walk")
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
	_finish_special_behavior()
	super._on_damaged(amount)
	if current_state == State.DEAD:
		return

	if anim_sprite != null and anim_sprite.sprite_frames.has_animation("hurt"):
		anim_sprite.play("hurt")


func _on_died() -> void:
	_special_behavior = SpecialBehavior.NONE
	_special_timer = 0.0
	_truffles_remaining = 0
	_truffle_shot_timer = 0.0
	_clear_active_truffles()
	if anim_sprite != null:
		anim_sprite.speed_scale = 1.0

	super._on_died()
	_anim_locked = true

	# A animação oficial de morte já é deitada; alinha o sprite ao piso.
	if visual_root != null:
		visual_root.rotation_degrees = 0.0
		visual_root.position.y = 0.0
	if anim_sprite != null and anim_sprite.sprite_frames.has_animation("death"):
		anim_sprite.play("death")
		anim_sprite.position = Vector2(0.0, -50.0)
