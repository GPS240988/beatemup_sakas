class_name BossBebado
extends BebadoEnemy

## Bêbado chefe do Map 5.
## Reutiliza os frames oficiais do inimigo comum e especializa somente o
## comportamento, escala de presença, colisões, feedback e ritmo de combate.

const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")

const BOSS_VISUAL_SCALE: float = 1.25
const BASE_HEALTH: float = 540.0
const PHASE_TWO_RATIO: float = 0.66
const PHASE_THREE_RATIO: float = 0.33

const INTRO_OFFSET_X: float = 112.0
const INTRO_DROP_HEIGHT: float = 250.0
const INTRO_FALL_SECONDS: float = 0.92
const INTRO_SETTLE_SECONDS: float = 0.10
const INTRO_IMPACT_SHAKE_FORCE: float = 18.0
const INTRO_IMPACT_SHAKE_SECONDS: float = 0.38

const COUNTER_HIT_THRESHOLD: int = 3
const COUNTER_WINDOW_SECONDS: float = 1.00
const COUNTER_COOLDOWN_SECONDS: float = 4.2
const COUNTER_DELAY_SECONDS: float = 0.22

const DRINK_HEALTH_RATIO: float = 0.60
const DRINK_HEAL_AMOUNT: float = 65.0
const DRINK_COOLDOWN_LOCK: float = 999.0
const BOTTLE_HEAL_AMOUNT: float = 65.0

const HEAVY_RANGE: float = 128.0
const HEAVY_DEPTH: float = 31.0
const FEINT_CHANCE_PHASE_TWO: float = 0.18
const FEINT_CHANCE_PHASE_THREE: float = 0.28

enum BossPhase {
	ONE,
	TWO,
	THREE,
	DEFEATED
}

var is_boss: bool = true
var _boss_phase: BossPhase = BossPhase.ONE
var _intro_active: bool = true
var _saved_player_process_mode: int = Node.PROCESS_MODE_INHERIT
var _body_collision: CollisionShape2D = null
var _attack_hitbox: Area2D = null
var _boss_visual_base_scale: float = BOSS_VISUAL_SCALE

var _counter_hits: int = 0
var _counter_window_timer: float = 0.0
var _counter_cooldown_timer: float = 0.0
var _counter_pending_timer: float = -1.0
var _drink_used: bool = false
var _attack_index: int = 0



func _ready() -> void:
	super._ready()

	is_boss = true
	display_name = "O BÊBADO"

	# O chefe usa o mesmo sistema de crawl/esquiva do Bêbado comum, mas com
	# frequência escalonada por fase e uma única recuperação por bebida na fase 2.
	crawl_low_health_threshold = 0.48
	crawl_spontaneous_chance = 0.28
	crawl_after_downed_chance = 0.45
	crawl_spontaneous_min_interval = 7.0
	crawl_spontaneous_max_interval = 10.0
	dodge_chance = 0.32
	dodge_cooldown_time = 2.75
	dodge_speed = 225.0
	drink_cooldown_time = DRINK_COOLDOWN_LOCK
	drink_heal_amount = DRINK_HEAL_AMOUNT
	_reset_spontaneous_crawl_timer()

	if health_component != null:
		health_component.max_health = BASE_HEALTH
		health_component.current_health = BASE_HEALTH

	if visual_root != null:
		# Escalar o ROOT, e não o AnimatedSprite2D isoladamente, mantém a origem
		# física dos pés em (0,0) e impede que o personagem pareça flutuar.
		visual_root.scale = Vector2(_boss_visual_base_scale, _boss_visual_base_scale)

	_body_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	_attack_hitbox = get_node_or_null("MeleeAttack/HitboxArea") as Area2D

	if melee_attack != null:
		melee_attack.damage = 18.0
		melee_attack.horizontal_range = 92.0
		melee_attack.depth_tolerance = 26.0
		melee_attack.active_duration = 0.17

	call_deferred("_start_boss_intro")


func _physics_process(delta: float) -> void:
	if _counter_window_timer > 0.0:
		_counter_window_timer = maxf(0.0, _counter_window_timer - delta)
		if _counter_window_timer <= 0.0:
			_counter_hits = 0

	if _counter_cooldown_timer > 0.0:
		_counter_cooldown_timer = maxf(0.0, _counter_cooldown_timer - delta)

	if _intro_active:
		velocity = Vector2.ZERO
		_play_anim("lunge_pose")
		return

	if _counter_pending_timer >= 0.0:
		_counter_pending_timer -= delta
		if _counter_pending_timer <= 0.0:
			_counter_pending_timer = -1.0
			if current_state in [State.IDLE, State.WAITING, State.FLANKING, State.ALIGNING_DEPTH]:
				_trigger_counter_attack()

	super._physics_process(delta)

	if current_state != State.DEAD:
		_update_boss_phase()


func _update_boss_phase() -> void:
	if health_component == null or health_component.max_health <= 0.0:
		return

	var ratio: float = health_component.current_health / health_component.max_health
	var next_phase: BossPhase = BossPhase.ONE
	if ratio <= PHASE_THREE_RATIO:
		next_phase = BossPhase.THREE
	elif ratio <= PHASE_TWO_RATIO:
		next_phase = BossPhase.TWO

	if next_phase == _boss_phase:
		return

	_boss_phase = next_phase
	match _boss_phase:
		BossPhase.ONE:
			dodge_chance = 0.32
			dodge_cooldown_time = 2.75
			crawl_spontaneous_chance = 0.28
			crawl_spontaneous_min_interval = 7.0
			crawl_spontaneous_max_interval = 10.0
			attack_cooldown = 0.72
		BossPhase.TWO:
			dodge_chance = 0.42
			dodge_cooldown_time = 2.20
			crawl_spontaneous_chance = 0.45
			crawl_spontaneous_min_interval = 5.5
			crawl_spontaneous_max_interval = 8.0
			attack_cooldown = 0.60
		BossPhase.THREE:
			dodge_chance = 0.50
			dodge_cooldown_time = 1.80
			crawl_spontaneous_chance = 0.58
			crawl_spontaneous_min_interval = 4.5
			crawl_spontaneous_max_interval = 6.5
			dodge_speed = 245.0
			attack_cooldown = 0.50
		BossPhase.DEFEATED:
			pass
	_reset_spontaneous_crawl_timer()
	CombatFeedbackClass.trigger_screen_shake(self, 7.0, 0.18)
	if visual_root != null:
		CombatFeedbackClass.flash_node(visual_root, Color(1.65, 0.32, 0.28, 1.0), 0.10)


func _trigger_attack() -> void:
	if melee_attack == null or _boss_phase == BossPhase.DEFEATED:
		return

	_attack_index = (_attack_index + 1) % 6
	var feint_chance: float = FEINT_CHANCE_PHASE_TWO if _boss_phase == BossPhase.TWO else FEINT_CHANCE_PHASE_THREE
	if _boss_phase >= BossPhase.TWO and randf() < feint_chance:
		# Finta: anuncia um golpe e abandona a iniciativa para uma esquiva curta.
		# O token é liberado para o combate continuar sem travar o CombatDirector.
		_release_combat_resources()
		CombatFeedbackClass.flash_node(visual_root, Color(1.0, 0.88, 0.45, 1.0), 0.08)
		start_dodge()
		return

	current_state = State.ATTACKING

	var heavy_attack: bool = false
	match _boss_phase:
		BossPhase.ONE:
			heavy_attack = _attack_index == 0
		BossPhase.TWO:
			heavy_attack = _attack_index in [1, 4]
		BossPhase.THREE:
			heavy_attack = _attack_index in [0, 2, 4, 5]

	if heavy_attack:
		_play_anim("lunge_pose")
		melee_attack.damage = 32.0 if _boss_phase < BossPhase.THREE else 36.0
		melee_attack.impact_profile = "finisher"
		melee_attack.preferred_regions = ["upper_torso", "head"]
		melee_attack.hitbox_offset_y = -104.0
		melee_attack.horizontal_range = HEAVY_RANGE + (10.0 if _boss_phase == BossPhase.THREE else 0.0)
		melee_attack.depth_tolerance = HEAVY_DEPTH
		melee_attack.active_duration = 0.20
		CombatFeedbackClass.spawn_afterimage(self, Color(0.86, 0.22, 0.30, 0.44), 0.16)
		CombatFeedbackClass.spawn_dust(self, global_position, 0.90)
		CombatFeedbackClass.trigger_screen_shake(self, 6.5, 0.16)
	else:
		match _attack_index % 3:
			0:
				_play_anim("attack_jab")
				melee_attack.damage = 18.0 if _boss_phase == BossPhase.ONE else 20.0
				melee_attack.impact_profile = "punch"
				melee_attack.preferred_regions = ["head", "upper_torso"]
				melee_attack.hitbox_offset_y = -98.0
				melee_attack.horizontal_range = 92.0
			1:
				_play_anim("attack_hook")
				melee_attack.damage = 22.0 if _boss_phase != BossPhase.THREE else 24.0
				melee_attack.impact_profile = "punch"
				melee_attack.preferred_regions = ["upper_torso", "head"]
				melee_attack.hitbox_offset_y = -98.0
				melee_attack.horizontal_range = 96.0
			_:
				_play_anim("attack_punch")
				melee_attack.damage = 26.0 if _boss_phase < BossPhase.THREE else 28.0
				melee_attack.impact_profile = "punch"
				melee_attack.preferred_regions = ["head", "upper_torso"]
				melee_attack.hitbox_offset_y = -100.0
				melee_attack.horizontal_range = 104.0
		melee_attack.active_duration = 0.17

	melee_attack.execute_attack(facing_direction)


func _trigger_counter_attack() -> void:
	if melee_attack == null or current_state == State.DEAD:
		return

	if player_target != null and is_instance_valid(player_target):
		_update_facing(player_target.global_position.x)

	current_state = State.ATTACKING
	_play_anim("attack_punch")
	melee_attack.damage = 30.0
	melee_attack.impact_profile = "finisher"
	melee_attack.preferred_regions = ["head", "upper_torso"]
	melee_attack.hitbox_offset_y = -100.0
	melee_attack.horizontal_range = 116.0
	melee_attack.depth_tolerance = 30.0
	melee_attack.active_duration = 0.20

	_counter_cooldown_timer = COUNTER_COOLDOWN_SECONDS
	_counter_hits = 0
	_counter_window_timer = 0.0
	CombatFeedbackClass.spawn_afterimage(self, Color(0.94, 0.26, 0.30, 0.50), 0.13)
	CombatFeedbackClass.trigger_screen_shake(self, 6.0, 0.16)
	melee_attack.execute_attack(facing_direction)


func _is_player_attack(damage_input: Variant) -> bool:
	if not (damage_input is RefCounted):
		return false
	var attacker: Node = damage_input.get("attacker") as Node
	return attacker != null and is_instance_valid(attacker) and attacker.is_in_group("player")


func take_damage(damage_input: Variant) -> bool:
	if _intro_active or _boss_phase == BossPhase.DEFEATED:
		return false

	# A garrafa de vidro é uma armadilha narrativa/combat design: acertar o
	# Bêbado com ela não causa dano; ele bebe o impacto e recupera vida.
	if _is_bottle_hit(damage_input):
		_apply_bottle_heal()
		return true

	var accepted: bool = super.take_damage(damage_input)
	if accepted and _is_player_attack(damage_input):
		if _counter_window_timer <= 0.0:
			_counter_hits = 0
			_counter_window_timer = COUNTER_WINDOW_SECONDS
		_counter_hits += 1
		if _counter_hits >= COUNTER_HIT_THRESHOLD and _counter_cooldown_timer <= 0.0 and _counter_pending_timer < 0.0:
			_counter_hits = 0
			_counter_pending_timer = COUNTER_DELAY_SECONDS
	return accepted




func _is_bottle_hit(damage_input: Variant) -> bool:
	if not (damage_input is RefCounted):
		return false
	return (
		str(damage_input.get("damage_type")) == "projectile"
		and str(damage_input.get("impact_profile")) == "heavy"
		and is_equal_approx(float(damage_input.get("amount")), 26.0)
	)


func _apply_bottle_heal() -> void:
	if health_component == null or health_component.is_dead:
		return
	health_component.heal(BOTTLE_HEAL_AMOUNT)
	CombatFeedbackClass.flash_node(visual_root, Color(0.35, 1.35, 0.48, 1.0), 0.14)
	CombatFeedbackClass.spawn_dust(self, global_position, 0.55)
	CombatFeedbackClass.trigger_screen_shake(self, 4.0, 0.12)


func _can_attempt_drink() -> bool:
	if _drink_used or _boss_phase < BossPhase.TWO:
		return false
	if health_component == null or health_component.max_health <= 0.0:
		return false

	var ratio: float = health_component.current_health / health_component.max_health
	if ratio > DRINK_HEALTH_RATIO:
		return false

	# Libera a única bebida no momento em que o boss cruza o limiar.
	# Depois que start_drink() for chamado, o cooldown de 999s impede repetição.
	_drink_cooldown = 0.0
	if not super._can_attempt_drink():
		return false
	_drink_used = true
	return true


func _update_spontaneous_crawl(delta: float) -> bool:
	return super._update_spontaneous_crawl(delta)


func _on_damaged(amount: float) -> void:
	super._on_damaged(amount)
	_update_boss_phase()


func _on_damaged_info(info: RefCounted) -> void:
	super._on_damaged_info(info)
	_update_boss_phase()


func _on_boss_health_changed(_current: float, _maximum: float) -> void:
	_update_boss_phase()


func _start_boss_intro() -> void:
	if not is_inside_tree() or health_component == null or health_component.is_dead:
		return

	_intro_active = true
	current_state = State.IDLE
	velocity = Vector2.ZERO

	var player_node: CharacterBody2D = player_target
	var landing_position: Vector2 = global_position
	if player_node != null and is_instance_valid(player_node):
		_saved_player_process_mode = player_node.process_mode
		player_node.process_mode = Node.PROCESS_MODE_DISABLED
		player_node.velocity = Vector2.ZERO
		landing_position = Vector2(
			player_node.global_position.x + INTRO_OFFSET_X,
			player_node.global_position.y
		)
		global_position = landing_position - Vector2(0.0, INTRO_DROP_HEIGHT)
		_update_facing(player_node.global_position.x)

	if _body_collision != null:
		_body_collision.set_deferred("disabled", true)
	if _attack_hitbox != null:
		_attack_hitbox.set_deferred("monitoring", false)

	_play_anim("lunge_pose")

	var tween: Tween = create_tween()
	if tween == null:
		_finish_boss_intro()
		return

	tween.tween_property(self, "global_position:y", landing_position.y, INTRO_FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(INTRO_SETTLE_SECONDS)
	tween.tween_callback(_finish_boss_intro)


func _finish_boss_intro() -> void:
	if not _intro_active:
		return

	_intro_active = false
	global_position.y = player_target.global_position.y if player_target != null and is_instance_valid(player_target) else global_position.y

	if _body_collision != null:
		_body_collision.set_deferred("disabled", false)

	CombatFeedbackClass.spawn_dust(self, global_position, 1.55)
	CombatFeedbackClass.play_enemy_fall_sound(self)
	CombatFeedbackClass.play_impact_sound(self, "finisher")
	CombatFeedbackClass.trigger_screen_shake(self, INTRO_IMPACT_SHAKE_FORCE, INTRO_IMPACT_SHAKE_SECONDS)
	CombatFeedbackClass.flash_node(visual_root, Color(1.8, 0.55, 0.22, 1.0), 0.08)
	var player_node: CharacterBody2D = player_target
	if player_node != null and is_instance_valid(player_node):
		CombatFeedbackClass.apply_hitstop(self, player_node, 0.10)
		player_node.process_mode = _saved_player_process_mode

	_attack_timer = 1.15
	current_state = State.FLANKING




func _on_died() -> void:
	_boss_phase = BossPhase.DEFEATED
	_intro_active = false
	_counter_pending_timer = -1.0
	CombatFeedbackClass.trigger_screen_shake(self, 11.0, 0.30)
	CombatFeedbackClass.spawn_dust(self, global_position, 1.15)

	var player_node: CharacterBody2D = player_target
	if player_node != null and is_instance_valid(player_node):
		player_node.process_mode = _saved_player_process_mode

	super._on_died()


func _start_death_fade_sequence() -> void:
	if visual_root == null:
		queue_free()
		return

	_play_anim("knockdown")
	visual_root.rotation_degrees = 0.0
	visual_root.position.y = 0.0

	var tween: Tween = create_tween()
	if tween == null:
		queue_free()
		return

	tween.tween_property(visual_root, "modulate:a", 0.35, 0.30)
	tween.tween_interval(0.45)
	tween.tween_property(visual_root, "modulate:a", 0.0, 0.45)
	tween.tween_callback(queue_free)
