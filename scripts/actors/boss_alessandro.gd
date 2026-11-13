class_name BossAlessandro
extends EnemyAI

## Controlador do chefe Alessandro — gerente da locadora.
## Mantém os contratos da IA base e adiciona pressão de longa duração,
## salvas de trufas ricocheteantes e arrancadas evasivas 2.5D.

enum SpecialBehavior {
	NONE,
	TRUFFLE_WINDUP,
	THROWING_TRUFFLES,
	EVADING,
	MEAT_SEEKING
}

const TRUFFLE_SCENE: PackedScene = preload("res://scenes/actors/projectiles/trufa.tscn")
const TRUFFLE_COUNT: int = 3
const TRUFFLE_WINDUP_SECONDS: float = 0.42
const TRUFFLE_INTERVAL: float = 0.28
const TRUFFLE_IMPULSE: float = 330.0
const TRUFFLE_INITIAL_COOLDOWN: float = 5.0
const TRUFFLE_COOLDOWN_PHASE_ONE: float = 5.0
const TRUFFLE_COOLDOWN_PHASE_TWO: float = 5.0
const TRUFFLE_DAMAGE: float = 10.0
const TRUFFLE_SPREAD_ANGLE: float = 0.58
const TRUFFLE_DEPTH_SPREAD: float = 105.0
const CLOSE_TRUFFLE_CHANCE: float = 0.30

const BOSS_MAX_HEALTH: float = 900.0
const PHASE_TWO_HEALTH_RATIO: float = 0.5

const EVADE_TRIGGER_DISTANCE: float = 112.0
const EVADE_DEPTH_TOLERANCE: float = 48.0
const EVADE_INITIAL_COOLDOWN: float = 2.0
const EVADE_COOLDOWN_PHASE_ONE: float = 1.25
const EVADE_COOLDOWN_PHASE_TWO: float = 1.6
const EVADE_CHANCE_PHASE_ONE: float = 0.80
const EVADE_CHANCE_PHASE_TWO: float = 0.50
const EVADE_DURATION_PHASE_ONE: float = 0.58
const EVADE_DURATION_PHASE_TWO: float = 0.62
const EVADE_SPEED_X_PHASE_ONE: float = 390.0
const EVADE_SPEED_Y_PHASE_ONE: float = 220.0
const EVADE_SPEED_X_PHASE_TWO: float = 470.0
const EVADE_SPEED_Y_PHASE_TWO: float = 280.0

const MEAT_SCENE: PackedScene = preload("res://scenes/props/alessandro_meat.tscn")
const MEAT_TRIGGER_HEALTH: float = 450.0
const MEAT_HEAL_AMOUNT: float = 300.0
const MEAT_DROP_OFFSET_X: float = 520.0
const MEAT_SEEK_SPEED: float = 128.0
const MEAT_ARRIVAL_DISTANCE: float = 88.0

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
var _meat_instances: Array[DestructibleProp] = []
var _meat_target: DestructibleProp = null
var _meat_phase_used: bool = false
var _speech_bubble: PanelContainer = null
var _meat_chatter_timer: float = 0.0
const MEAT_CHATTER_INTERVAL: float = 3.4


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

	# Alessandro usa seus sprites originais; não aplicar o shader de paleta dos capangas.
	palette_variant = PaletteVariant.ORIGINAL
	super._ready()
	if anim_sprite != null:
		anim_sprite.material = null
		anim_sprite.modulate = Color.WHITE
	if visual_root != null:
		visual_root.modulate = Color.WHITE

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

	if health_component != null and not health_component.health_changed.is_connected(_on_boss_health_changed):
		health_component.health_changed.connect(_on_boss_health_changed)

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
		var player_distance: float = global_position.distance_to(player_target.global_position)
		if player_distance > 245.0 or randf() < CLOSE_TRUFFLE_CHANCE:
			_start_truffle_barrage()
		else:
			_truffle_cooldown = 0.75


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

		SpecialBehavior.MEAT_SEEKING:
			_process_meat_seeking(delta)


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
	var depth_offset: float = float(shot_index - 1) * TRUFFLE_DEPTH_SPREAD
	target_point.y += depth_offset + randf_range(-28.0, 28.0)
	target_vector = target_point - truffle.global_position
	var spread_angle: float = float(shot_index - 1) * TRUFFLE_SPREAD_ANGLE + randf_range(-0.12, 0.12)
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


func _on_boss_health_changed(current: float, _maximum: float) -> void:
	if _meat_phase_used or current > MEAT_TRIGGER_HEALTH or current <= 0.0:
		return
	_activate_healing_meat()


func _activate_healing_meat() -> void:
	if _meat_phase_used or current_state == State.DEAD:
		return
	_meat_phase_used = true
	var world_root: Node = get_tree().current_scene
	var destructibles: Node = world_root.find_child("Destructibles", true, false) if world_root != null else null
	if destructibles == null:
		destructibles = get_parent()
	if destructibles == null:
		push_warning("BossAlessandro: container Destructibles não encontrado.")
		return

	# Um único drop, ancorado no plano do chão (Y da origem física do chefe).
	var meat: DestructibleProp = MEAT_SCENE.instantiate() as DestructibleProp
	if meat == null:
		push_warning("BossAlessandro: não foi possível instanciar a carne de cura.")
		return
	destructibles.add_child(meat)
	var drop_direction: float = -1.0 if global_position.x >= 1025.0 else 1.0
	var drop_position := Vector2(
		clampf(global_position.x + drop_direction * MEAT_DROP_OFFSET_X, 100.0, 1950.0),
		clampf(global_position.y, 545.0, 735.0)
	)
	meat.global_position = drop_position
	meat.prop_destroyed.connect(_on_healing_meat_destroyed.bind(meat), CONNECT_ONE_SHOT)
	_meat_instances.append(meat)
	CombatFeedback.spawn_dust(destructibles, drop_position + Vector2(0.0, 2.0), 0.72)

	_release_combat_resources()
	if melee_attack != null:
		melee_attack.cancel_attack()
	_special_behavior = SpecialBehavior.MEAT_SEEKING
	velocity = Vector2.ZERO
	_select_next_healing_meat()
	if _meat_target != null:
		_meat_chatter_timer = MEAT_CHATTER_INTERVAL
		_show_meat_chase_dialogue()
	if anim_sprite != null:
		_play_anim("walk")

func _select_next_healing_meat() -> void:
	for meat: DestructibleProp in _meat_instances.duplicate():
		if not is_instance_valid(meat) or meat.is_prop_destroyed():
			_meat_instances.erase(meat)
	_meat_target = null
	var best_distance: float = INF
	for meat: DestructibleProp in _meat_instances:
		var distance: float = global_position.distance_to(meat.global_position)
		if distance < best_distance:
			best_distance = distance
			_meat_target = meat
	if _meat_target == null and _special_behavior == SpecialBehavior.MEAT_SEEKING:
		_finish_special_behavior()


func _process_meat_seeking(delta: float) -> void:
	_meat_chatter_timer -= delta
	if _meat_chatter_timer <= 0.0:
		_show_meat_chase_dialogue()
		_meat_chatter_timer = MEAT_CHATTER_INTERVAL

	if _meat_target == null or not is_instance_valid(_meat_target) or _meat_target.is_prop_destroyed():
		_select_next_healing_meat()
		if _meat_target == null:
			return

	var to_meat: Vector2 = _meat_target.global_position - global_position
	# O corpo físico pode parar alguns pixels antes do centro da prop; use uma
	# janela de chegada compatível com as duas CollisionShape2D.
	if absf(to_meat.x) <= MEAT_ARRIVAL_DISTANCE and absf(to_meat.y) <= 38.0:
		var eaten_meat: DestructibleProp = _meat_target
		_meat_instances.erase(eaten_meat)
		_meat_target = null
		if health_component != null and not health_component.is_dead:
			health_component.heal(MEAT_HEAL_AMOUNT)
		_show_meat_dialogue()
		if is_instance_valid(eaten_meat):
			eaten_meat.queue_free()
		_select_next_healing_meat()
		return

	var direction: Vector2 = to_meat.normalized()
	velocity = direction * MEAT_SEEK_SPEED
	if absf(direction.x) > 0.05:
		facing_direction = signf(direction.x)


func _on_healing_meat_destroyed(meat: DestructibleProp) -> void:
	_meat_instances.erase(meat)
	if _meat_target == meat:
		_meat_target = null
		if _special_behavior == SpecialBehavior.MEAT_SEEKING:
			_select_next_healing_meat()


func _show_meat_chase_dialogue() -> void:
	_show_speech_bubble("¡Uy, salió la carne jugosa!", 2.8)


func _show_meat_dialogue() -> void:
	_show_speech_bubble("La verdadera picaña es la uruguaya", 2.8)


func _show_speech_bubble(dialogue_text: String, duration: float) -> void:
	if _speech_bubble != null and is_instance_valid(_speech_bubble):
		_speech_bubble.queue_free()
	_speech_bubble = PanelContainer.new()
	_speech_bubble.name = "UruguayanMeatSpeechBubble"
	_speech_bubble.position = Vector2(-190.0, -250.0)
	_speech_bubble.custom_minimum_size = Vector2(380.0, 58.0)
	_speech_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_bubble.z_index = 120
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.91, 0.73, 0.97)
	style.border_color = Color(0.12, 0.07, 0.04, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_speech_bubble.add_theme_stylebox_override("panel", style)
	var speech := Label.new()
	speech.text = dialogue_text
	speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speech.add_theme_font_override("font", preload("res://assets/fonts/arcade_bold.ttf"))
	speech.add_theme_font_size_override("font_size", 15)
	speech.add_theme_color_override("font_color", Color(0.12, 0.07, 0.04, 1.0))
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_bubble.add_child(speech)
	add_child(_speech_bubble)
	_speech_bubble.scale = Vector2.ONE
	var bubble_ref: WeakRef = weakref(_speech_bubble)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		var bubble: PanelContainer = bubble_ref.get_ref() as PanelContainer
		if bubble != null and is_instance_valid(bubble):
			bubble.queue_free()
	)


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
	var evade_chance: float = EVADE_CHANCE_PHASE_TWO if _is_phase_two() else EVADE_CHANCE_PHASE_ONE
	if randf() > evade_chance:
		_evasion_cooldown = 0.35
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
	_truffle_cooldown = 0.0
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
		if finished_behavior == SpecialBehavior.EVADING and _truffle_cooldown <= 0.0 and _can_start_truffle_barrage():
			_start_truffle_barrage()


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
		SpecialBehavior.EVADING, SpecialBehavior.MEAT_SEEKING:
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
	# Receber golpes não cancela a busca: o chefe continua tentando alcançar a carne.
	if _special_behavior != SpecialBehavior.MEAT_SEEKING:
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
	for meat: DestructibleProp in _meat_instances:
		if is_instance_valid(meat):
			meat.queue_free()
	_meat_instances.clear()
	_meat_target = null
	_meat_chatter_timer = 0.0
	if _speech_bubble != null and is_instance_valid(_speech_bubble):
		_speech_bubble.queue_free()
	_speech_bubble = null
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
