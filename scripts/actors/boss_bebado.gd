class_name BossBebado
extends BebadoEnemy

## Boss do posto: leitura de padrão, pressão e uso inteligente do cenário.
## Não adiciona novos sprites. Reaproveita exclusivamente os frames oficiais do Bêbado.

const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")

const BASE_HEALTH: float = 540.0
const VISUAL_SCALE: float = 1.25

# A primeira recuperação é uma revelação obrigatória da mecânica do boss.
const FIRST_RECOVERY_RATIO: float = 0.78
const FIRST_RECOVERY_HEAL: float = 65.0
const FIRST_RECOVERY_DURATION: float = 0.72
const FIRST_RECOVERY_SEARCH_SPEED: float = 128.0
const FIRST_RECOVERY_APPROACH_RADIUS: float = 52.0
const FIRST_RECOVERY_APPROACH_Y_OFFSET: float = 48.0
const AERIAL_EVASION_CHANCE: float = 0.55
const AERIAL_EVASION_COOLDOWN: float = 1.35
const PHASE_THREE_RATIO: float = 0.33
const PHASE_THREE_PRESSURE_COOLDOWN: float = 2.75
const PHASE_THREE_PRESSURE_TELEGRAPH: float = 0.32
const PHASE_THREE_PRESSURE_STAGGER: float = 0.22
const PHASE_THREE_PRESSURE_RUSH: float = 0.46
const PHASE_THREE_PRESSURE_RECOVERY: float = 0.62

# Anti-mash: três impactos rápidos abrem o contra-ataque e anulam o terceiro golpe.
const PRESSURE_HIT_THRESHOLD: int = 3
const PRESSURE_WINDOW: float = 1.05
const PRESSURE_COOLDOWN: float = 4.50
const PRESSURE_TELEGRAPH_TIME: float = 0.24
const PRESSURE_STAGGER_TIME: float = 0.18
const PRESSURE_RUSH_TIME: float = 0.38
const PRESSURE_RECOVERY_TIME: float = 0.45
const PRESSURE_RUSH_SPEED: float = 330.0
const PRESSURE_RUSH_RANGE: float = 122.0
const PRESSURE_RUSH_DEPTH: float = 32.0
const PRESSURE_RUSH_DAMAGE: float = 30.0

# Entrada: alta o suficiente para ser percebida, lenta o bastante para leitura visual.
const INTRO_HEIGHT: float = 290.0
const INTRO_FALL_DURATION: float = 1.10
const INTRO_IMPACT_SHAKE: float = 18.0
const INTRO_IMPACT_SHAKE_TIME: float = 0.38
const INTRO_PLAYER_OFFSET_X: float = 112.0

# Ataques normais.
const ATTACK_DAMAGE_JAB: float = 18.0
const ATTACK_DAMAGE_HOOK: float = 22.0
const ATTACK_DAMAGE_PUNCH: float = 26.0
const ATTACK_DAMAGE_HEAVY: float = 32.0

enum BossMode {
	INTRO,
	NORMAL,
	FIRST_RECOVERY,
	PRESSURE_TELEGRAPH,
	PRESSURE_STAGGER,
	PRESSURE_RUSH,
	PRESSURE_RECOVERY,
	DEFEATED
}

var is_boss: bool = true
var _boss_mode: BossMode = BossMode.INTRO
var _first_recovery_used: bool = false
var _phase_three_announced: bool = false
var _first_recovery_timer: float = 0.0
var _recovery_bottle_target: Node2D = null
var _recovery_bottle_point: Vector2 = Vector2.ZERO
var _recovery_is_drinking: bool = false
var _pressure_hits: int = 0
var _pressure_window_timer: float = 0.0
var _pressure_cooldown: float = 0.0
var _pressure_timer: float = 0.0
var _pressure_rush_direction: float = 1.0
var _pressure_rush_velocity: Vector2 = Vector2.ZERO
var _aerial_evasion_cooldown: float = 0.0
var _attack_index: int = 0
var _intro_active: bool = true
var _body_collision: CollisionShape2D = null
var _attack_hitbox: Area2D = null
var _saved_player_process_mode: int = Node.PROCESS_MODE_INHERIT
var _difficulty_damage_scale: float = 1.0
var _scaled_base_attack_windup: float = 0.22
var _scaled_base_attack_cooldown: float = 0.70


func _ready() -> void:
	# Define o valor-base antes do parent para que o CombatDirector aplique sua
	# multiplicação de dificuldade sobre 540, sem qualquer segunda escala local.
	base_health = BASE_HEALTH
	super._ready()

	is_boss = true
	display_name = "O BÊBADO"

	# Mantém a personalidade do Bêbado sem depender do crawl como solução única.
	crawl_spontaneous_chance = 0.12
	crawl_spontaneous_min_interval = 7.0
	crawl_spontaneous_max_interval = 11.0
	dodge_chance = 0.18
	dodge_cooldown_time = 3.8
	drink_cooldown_time = 999.0
	drink_heal_amount = FIRST_RECOVERY_HEAL

	speed_x = 150.0
	speed_y = 104.0
	attack_horizontal_distance = 84.0
	attack_depth_tolerance = 26.0
	recovery_duration = 0.38
	hurt_duration = 0.18
	recoil_distance = 56.0

	# O CombatDirector já aplicou o perfil global durante o ready do parent.
	if health_component != null and not health_component.health_changed.is_connected(_on_boss_health_changed):
		health_component.health_changed.connect(_on_boss_health_changed)

	_ensure_internal_refs()
	if melee_attack != null:
		_difficulty_damage_scale = maxf(0.1, melee_attack.damage / 16.0)
	_scaled_base_attack_windup = maxf(0.05, attack_windup_seconds)
	_scaled_base_attack_cooldown = maxf(0.20, attack_cooldown)
	_body_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	_attack_hitbox = get_node_or_null("MeleeAttack/HitboxArea") as Area2D

	# Maior visual sem mover a âncora física dos pés.
	if visual_root != null:
		visual_root.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)

	call_deferred("_start_boss_intro")


func _physics_process(delta: float) -> void:
	if _aerial_evasion_cooldown > 0.0:
		_aerial_evasion_cooldown = maxf(0.0, _aerial_evasion_cooldown - delta)

	if _pressure_window_timer > 0.0:
		_pressure_window_timer = maxf(0.0, _pressure_window_timer - delta)
		if _pressure_window_timer <= 0.0:
			_pressure_hits = 0

	if _pressure_cooldown > 0.0:
		_pressure_cooldown = maxf(0.0, _pressure_cooldown - delta)

	match _boss_mode:
		BossMode.INTRO:
			velocity = Vector2.ZERO
			return
		BossMode.FIRST_RECOVERY:
			_process_first_recovery(delta)
			return
		BossMode.PRESSURE_TELEGRAPH, BossMode.PRESSURE_STAGGER, BossMode.PRESSURE_RUSH, BossMode.PRESSURE_RECOVERY:
			_process_pressure_breaker(delta)
			return
		BossMode.DEFEATED:
			velocity = Vector2.ZERO
			return
		_:
			pass

	super._physics_process(delta)
	if current_state != State.DEAD:
		_update_phase_tuning()


func _update_phase_tuning() -> void:
	if health_component == null or health_component.max_health <= 0.0:
		return
	var ratio: float = health_component.current_health / health_component.max_health
	if ratio <= PHASE_THREE_RATIO and not _phase_three_announced:
		_phase_three_announced = true
		_pressure_cooldown = 1.0
		CombatFeedbackClass.trigger_screen_shake(self, 8.0, 0.20)
		CombatFeedbackClass.flash_node(visual_root, Color(1.65, 0.28, 0.24, 1.0), 0.12)
	if ratio <= PHASE_THREE_RATIO:
		# Terceira fase: o Bêbado fica mais perigoso, mas não mais caótico.
		# O jogador ainda vence lendo o telegraph, desviando da investida e
		# punindo a recuperação. A mesma regra vale para ataques à distância.
		speed_x = 195.0
		speed_y = 125.0
		attack_windup_seconds = _scaled_base_attack_windup * 0.84
		attack_cooldown = _scaled_base_attack_cooldown * 0.78
		dodge_chance = 0.26
		crawl_spontaneous_chance = 0.16
	elif ratio <= 0.66:
		speed_x = 176.0
		speed_y = 116.0
		attack_windup_seconds = _scaled_base_attack_windup * 0.90
		attack_cooldown = _scaled_base_attack_cooldown * 0.88
		dodge_chance = 0.20
		crawl_spontaneous_chance = 0.15
	else:
		speed_x = 150.0
		speed_y = 104.0
		attack_windup_seconds = _scaled_base_attack_windup
		attack_cooldown = _scaled_base_attack_cooldown
		dodge_chance = 0.18
		crawl_spontaneous_chance = 0.12


func _is_phase_three() -> bool:
	if health_component == null or health_component.max_health <= 0.0:
		return false
	return health_component.current_health / health_component.max_health <= PHASE_THREE_RATIO


func _pressure_cooldown_duration() -> float:
	return PHASE_THREE_PRESSURE_COOLDOWN if _is_phase_three() else PRESSURE_COOLDOWN


func _pressure_telegraph_duration() -> float:
	return PHASE_THREE_PRESSURE_TELEGRAPH if _is_phase_three() else PRESSURE_TELEGRAPH_TIME


func _pressure_stagger_duration() -> float:
	return PHASE_THREE_PRESSURE_STAGGER if _is_phase_three() else PRESSURE_STAGGER_TIME


func _pressure_rush_duration() -> float:
	return PHASE_THREE_PRESSURE_RUSH if _is_phase_three() else PRESSURE_RUSH_TIME


func _pressure_recovery_duration() -> float:
	return PHASE_THREE_PRESSURE_RECOVERY if _is_phase_three() else PRESSURE_RECOVERY_TIME


func _trigger_attack() -> void:
	if melee_attack == null or _boss_mode != BossMode.NORMAL or _intro_active:
		return

	current_state = State.ATTACKING
	_attack_index = (_attack_index + 1) % 4
	var heavy: bool = false
	if health_component != null and health_component.max_health > 0.0:
		var ratio: float = health_component.current_health / health_component.max_health
		heavy = _attack_index == 3 or (ratio <= 0.66 and _attack_index == 1) or (ratio <= PHASE_THREE_RATIO and _attack_index in [0, 2])

	if heavy:
		_play_anim("lunge_pose")
		melee_attack.damage = (36.0 if _is_phase_three() else ATTACK_DAMAGE_HEAVY) * _difficulty_damage_scale
		melee_attack.impact_profile = "finisher"
		melee_attack.preferred_regions = ["upper_torso", "head"]
		melee_attack.hitbox_offset_y = -96.0
		melee_attack.horizontal_range = 120.0
		melee_attack.depth_tolerance = 30.0
		melee_attack.active_duration = 0.20
		CombatFeedbackClass.spawn_afterimage(self, Color(0.90, 0.22, 0.28, 0.46), 0.15)
		CombatFeedbackClass.spawn_dust(self, global_position, 0.78)
		CombatFeedbackClass.trigger_screen_shake(self, 5.5, 0.14)
	else:
		match _attack_index % 3:
			0:
				_play_anim("attack_jab")
				melee_attack.damage = ATTACK_DAMAGE_JAB * _difficulty_damage_scale
				melee_attack.impact_profile = "punch"
				melee_attack.preferred_regions = ["head", "upper_torso"]
				melee_attack.hitbox_offset_y = -90.0
				melee_attack.horizontal_range = 88.0
			1:
				_play_anim("attack_hook")
				melee_attack.damage = ATTACK_DAMAGE_HOOK * _difficulty_damage_scale
				melee_attack.impact_profile = "punch"
				melee_attack.preferred_regions = ["upper_torso", "head"]
				melee_attack.hitbox_offset_y = -90.0
				melee_attack.horizontal_range = 92.0
			_:
				_play_anim("attack_punch")
				melee_attack.damage = ATTACK_DAMAGE_PUNCH * _difficulty_damage_scale
				melee_attack.impact_profile = "punch"
				melee_attack.preferred_regions = ["head", "upper_torso"]
				melee_attack.hitbox_offset_y = -92.0
				melee_attack.horizontal_range = 100.0
		melee_attack.depth_tolerance = 26.0
		melee_attack.active_duration = 0.17

	melee_attack.execute_attack(facing_direction)


func take_damage(damage_input: Variant) -> bool:
	if _boss_mode in [BossMode.INTRO, BossMode.FIRST_RECOVERY, BossMode.DEFEATED]:
		# A busca e o gole da primeira recuperação são uma janela narrativa
		# invulnerável; nenhuma fonte externa pode acelerar ou interromper o ritual.
		return false

	var is_special: bool = false
	if damage_input is RefCounted:
		is_special = (
			str(damage_input.get("damage_type")) == "special"
			or str(damage_input.get("impact_profile")) == "special"
		)
	if is_special:
		return super.take_damage(damage_input)

	# A garrafa é uma armadilha: acerta o Bêbado, mas recupera vida.
	# Esta decisão vem antes da esquiva e do dano herdados para que o impacto
	# nunca seja convertido em dano negativo + cura.
	if _is_bottle_hit(damage_input):
		_return_bottle_health()
		return true

	# A voadora é forte, mas não pode ser uma fonte de dano garantido. O boss
	# ganha uma leitura específica para esse golpe, com cooldown próprio, sem
	# criar imunidade permanente e mantendo a resposta visual de dodge existente.
	if _is_aerial_player_attack(damage_input) and _aerial_evasion_cooldown <= 0.0 and randf() < AERIAL_EVASION_CHANCE and _can_attempt_dodge():
		_aerial_evasion_cooldown = AERIAL_EVASION_COOLDOWN
		start_dodge()
		_spawn_miss_text()
		return false

	# O jogador precisa atravessar as janelas do encontro, não trocar dano cego.
	if _boss_mode in [BossMode.FIRST_RECOVERY, BossMode.PRESSURE_TELEGRAPH, BossMode.PRESSURE_STAGGER, BossMode.PRESSURE_RUSH, BossMode.PRESSURE_RECOVERY]:
		return false

	# Terceiro golpe rápido é bloqueado e abre a sequência pesada.
	if _counts_as_player_attack(damage_input):
		if _pressure_window_timer <= 0.0:
			_pressure_hits = 0
			_pressure_window_timer = PRESSURE_WINDOW
		_pressure_hits += 1
		if _pressure_hits >= PRESSURE_HIT_THRESHOLD:
			if _pressure_cooldown <= 0.0:
				_start_pressure_breaker()
			else:
				# Mesmo durante a recarga do contra-ataque, o terceiro spam não entra.
				# O jogador precisa quebrar o ritmo para continuar causando dano.
				_pressure_hits = 0
				_pressure_window_timer = 0.0
			return false

	return super.take_damage(damage_input)


func _counts_as_player_attack(damage_input: Variant) -> bool:
	if damage_input is float or damage_input is int:
		return true
	if damage_input == null or not (damage_input is RefCounted):
		return false
	var attacker: Node = damage_input.get("attacker") as Node
	return attacker != null and is_instance_valid(attacker) and attacker.is_in_group("player")


func _is_bottle_hit(damage_input: Variant) -> bool:
	if damage_input == null or not (damage_input is RefCounted):
		return false
	var damage_type: String = str(damage_input.get("damage_type"))
	var impact_profile: String = str(damage_input.get("impact_profile"))
	var attacker: Node = damage_input.get("attacker") as Node
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_in_group("player"):
		return false
	return (
		damage_type in ["bottle", "bottle_projectile", "gas_bottle"]
		or impact_profile in ["bottle", "glass_shatter"]
		or (damage_type == "projectile" and impact_profile == "heavy")
	)


func _is_aerial_player_attack(damage_input: Variant) -> bool:
	if damage_input == null or not (damage_input is RefCounted):
		return false
	var attacker: Node = damage_input.get("attacker") as Node
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_in_group("player"):
		return false
	var impact_profile: String = str(damage_input.get("impact_profile"))
	if impact_profile != "kick":
		return false
	return "_is_jumping" in attacker and bool(attacker.get("_is_jumping"))


func _return_bottle_health() -> void:
	if health_component == null or health_component.is_dead:
		return
	var recovered: float = health_component.heal(FIRST_RECOVERY_HEAL)
	if recovered <= 0.0:
		return
	_pressure_hits = 0
	_pressure_window_timer = 0.0
	CombatFeedbackClass.flash_node(visual_root, Color(0.35, 2.0, 0.55, 1.0), 0.12)
	CombatFeedbackClass.spawn_dust(self, global_position, 0.55)
	CombatFeedbackClass.play_impact_sound(self, "glass_shatter")
	CombatFeedbackClass.trigger_screen_shake(self, 4.0, 0.12)
	if _boss_mode == BossMode.FIRST_RECOVERY:
		_first_recovery_timer = 0.0


func _on_boss_health_changed(current: float, maximum: float) -> void:
	if _boss_mode in [BossMode.DEFEATED, BossMode.FIRST_RECOVERY]:
		return
	if maximum <= 0.0 or current <= 0.0:
		return
	if not _first_recovery_used and current / maximum <= FIRST_RECOVERY_RATIO:
		_start_first_recovery()


func _start_first_recovery() -> void:
	if _first_recovery_used or health_component == null or health_component.is_dead:
		return
	_first_recovery_used = true
	_first_recovery_timer = FIRST_RECOVERY_DURATION
	_boss_mode = BossMode.FIRST_RECOVERY
	_recovery_is_drinking = false
	_recovery_bottle_target = _find_nearest_bottle_crate()
	_recovery_bottle_point = global_position
	if _recovery_bottle_target != null and is_instance_valid(_recovery_bottle_target):
		var away_from_player: float = 1.0
		if player_target != null and is_instance_valid(player_target):
			away_from_player = signf(_recovery_bottle_target.global_position.x - player_target.global_position.x)
		if away_from_player == 0.0:
			away_from_player = 1.0
		# Os engradados ficam atrás da borda de circulação da pista; aproximar
		# exatamente no Y do engradado pode encostar no limite superior do mapa
		# (especialmente no engradado esquerdo). O ponto de interação fica
		# deliberadamente abaixo dele, mantendo o acesso físico livre.
		_recovery_bottle_point = Vector2(
			_recovery_bottle_target.global_position.x + away_from_player * 58.0,
			_recovery_bottle_target.global_position.y + FIRST_RECOVERY_APPROACH_Y_OFFSET
		)
	_release_combat_resources()
	if melee_attack != null:
		melee_attack.cancel_attack()
	velocity = Vector2.ZERO
	CombatFeedbackClass.spawn_dust(self, global_position, 0.48)


func _find_nearest_bottle_crate() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for node in get_tree().get_nodes_in_group("gas_bottle_crates"):
		if not node is Node2D or not is_instance_valid(node):
			continue
		var crate := node as Node2D
		var distance: float = global_position.distance_squared_to(crate.global_position)
		if distance < nearest_distance:
			nearest = crate
			nearest_distance = distance
	return nearest


func _process_first_recovery(delta: float) -> void:
	# O boss inteiro fica invulnerável desde a busca até o fim do gole.
	# Isso evita que o jogador interrompa artificialmente a única revelação da luta.
	velocity = Vector2.ZERO
	if _recovery_bottle_target != null and is_instance_valid(_recovery_bottle_target) and not _recovery_is_drinking:
		var to_bottle: Vector2 = _recovery_bottle_point - global_position
		if to_bottle.length() > FIRST_RECOVERY_APPROACH_RADIUS:
			_update_facing(_recovery_bottle_point.x)
			if nav_agent != null and is_instance_valid(nav_agent) and _has_obstacle_between(global_position, _recovery_bottle_point):
				nav_agent.target_position = _recovery_bottle_point
				_follow_agent_path(delta)
			else:
				velocity = to_bottle.normalized() * FIRST_RECOVERY_SEARCH_SPEED
			_play_anim("walk")
			move_and_slide()
			return
		_recovery_is_drinking = true
		_first_recovery_timer = FIRST_RECOVERY_DURATION
		velocity = Vector2.ZERO
		_update_facing(player_target.global_position.x if player_target != null and is_instance_valid(player_target) else global_position.x)
		_play_anim("drink")
		CombatFeedbackClass.spawn_dust(self, global_position, 0.52)

	if not _recovery_is_drinking:
		# Fallback seguro para cenas de teste sem engradado: não bloqueia o boss
		# permanentemente e ainda preserva a janela de invulnerabilidade.
		_recovery_is_drinking = true
		_first_recovery_timer = FIRST_RECOVERY_DURATION
		_play_anim("drink")

	_first_recovery_timer -= delta
	if _first_recovery_timer <= 0.0:
		if health_component != null and not health_component.is_dead:
			var recovered: float = health_component.heal(FIRST_RECOVERY_HEAL)
			if recovered > 0.0:
				CombatFeedbackClass.flash_node(visual_root, Color(0.35, 2.0, 0.55, 1.0), 0.12)
				_spawn_heal_feedback(recovered)
				CombatFeedbackClass.play_impact_sound(self, "glass_shatter")
				CombatFeedbackClass.play_bebado_burp(self)
				CombatFeedbackClass.trigger_screen_shake(self, 3.5, 0.10)
		_end_first_recovery()


func _spawn_heal_feedback(recovered: float) -> void:
	if recovered <= 0.0:
		return
	var feedback := Label.new()
	feedback.name = "BossHealFeedback"
	feedback.text = "+%d VIDA" % roundi(recovered)
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
	var head_marker := get_node_or_null("ImpactZones/Head") as Node2D
	if head_marker != null:
		spawn_position = to_local(head_marker.global_position) + Vector2(0.0, -28.0)
	feedback.position = spawn_position - Vector2(feedback.size.x * 0.5, feedback.size.y * 0.5)
	add_child(feedback)
	var feedback_start_y: float = feedback.position.y

	var tween := feedback.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(feedback, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(feedback, "position:y", feedback_start_y - 42.0, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.28)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.22)
	tween.tween_callback(feedback.queue_free)


func _end_first_recovery() -> void:
	_recovery_bottle_target = null
	_recovery_is_drinking = false
	_boss_mode = BossMode.NORMAL
	current_state = State.FLANKING
	_attack_timer = 0.85
	_pressure_hits = 0
	_pressure_window_timer = 0.0
	_play_anim("idle")


func _start_pressure_breaker() -> void:
	if _boss_mode != BossMode.NORMAL or _pressure_cooldown > 0.0:
		return
	_pressure_cooldown = _pressure_cooldown_duration()
	_pressure_hits = 0
	_pressure_window_timer = 0.0
	_pressure_timer = _pressure_telegraph_duration()
	_boss_mode = BossMode.PRESSURE_TELEGRAPH
	velocity = Vector2.ZERO
	_release_combat_resources()
	if melee_attack != null:
		melee_attack.cancel_attack()

	if player_target != null and is_instance_valid(player_target):
		_update_facing(player_target.global_position.x)
		_pressure_rush_direction = signf(player_target.global_position.x - global_position.x)
		if _pressure_rush_direction == 0.0:
			_pressure_rush_direction = facing_direction
	else:
		_pressure_rush_direction = facing_direction

	_pressure_rush_velocity = Vector2(_pressure_rush_direction, 0.0)
	if player_target != null and is_instance_valid(player_target):
		var rush_target: Vector2 = player_target.global_position - global_position
		if rush_target.length_squared() > 0.01:
			_pressure_rush_velocity = rush_target.normalized()

	_play_anim("lunge_pose")
	CombatFeedbackClass.trigger_screen_shake(self, 3.0, 0.10)


func _process_pressure_breaker(delta: float) -> void:
	velocity = Vector2.ZERO
	_pressure_timer -= delta

	match _boss_mode:
		BossMode.PRESSURE_TELEGRAPH:
			_play_anim("lunge_pose")
			if _pressure_timer <= 0.0:
				_boss_mode = BossMode.PRESSURE_STAGGER
				_pressure_timer = _pressure_stagger_duration()
				_play_anim("dodge_duck")
				CombatFeedbackClass.spawn_dust(self, global_position, 0.70)
		BossMode.PRESSURE_STAGGER:
			_play_anim("dodge_duck")
			if _pressure_timer <= 0.0:
				_boss_mode = BossMode.PRESSURE_RUSH
				_pressure_timer = _pressure_rush_duration()
				velocity = _pressure_rush_velocity * PRESSURE_RUSH_SPEED
				_play_anim("lunge_pose")
				melee_attack.damage = PRESSURE_RUSH_DAMAGE * _difficulty_damage_scale
				melee_attack.impact_profile = "finisher"
				melee_attack.preferred_regions = ["upper_torso", "head"]
				melee_attack.hitbox_offset_y = -96.0
				melee_attack.horizontal_range = PRESSURE_RUSH_RANGE
				melee_attack.depth_tolerance = PRESSURE_RUSH_DEPTH
				melee_attack.active_duration = 0.20
				melee_attack.execute_attack(_pressure_rush_direction)
				CombatFeedbackClass.spawn_afterimage(self, Color(0.95, 0.28, 0.24, 0.50), 0.15)
				CombatFeedbackClass.trigger_screen_shake(self, 6.5, 0.16)
		BossMode.PRESSURE_RUSH:
			velocity = _pressure_rush_velocity * PRESSURE_RUSH_SPEED
			move_and_slide()
			if _pressure_timer <= 0.0:
				velocity = Vector2.ZERO
				_boss_mode = BossMode.PRESSURE_RECOVERY
				_pressure_timer = _pressure_recovery_duration()
				current_state = State.RECOVERY
				_play_anim("idle")
				CombatFeedbackClass.spawn_dust(self, global_position, 0.65)
		BossMode.PRESSURE_RECOVERY:
			velocity = Vector2.ZERO
			_play_anim("idle")
			if _pressure_timer <= 0.0:
				_boss_mode = BossMode.NORMAL
				current_state = State.FLANKING
				_attack_timer = 0.55


func _start_boss_intro() -> void:
	if not is_inside_tree() or health_component == null or health_component.is_dead:
		return

	_intro_active = true
	_boss_mode = BossMode.INTRO
	velocity = Vector2.ZERO
	current_state = State.IDLE

	var player_node: CharacterBody2D = player_target
	if player_node != null and is_instance_valid(player_node):
		_saved_player_process_mode = player_node.process_mode
		player_node.process_mode = Node.PROCESS_MODE_DISABLED
		player_node.velocity = Vector2.ZERO
		global_position = Vector2(player_node.global_position.x + INTRO_PLAYER_OFFSET_X, player_node.global_position.y)
		_update_facing(player_node.global_position.x)

	if _body_collision != null:
		_body_collision.set_deferred("disabled", true)
	if _attack_hitbox != null:
		_attack_hitbox.set_deferred("monitoring", false)
	if visual_root != null:
		visual_root.position.y = -INTRO_HEIGHT
	_play_anim("lunge_pose")

	var tween: Tween = create_tween()
	if tween == null:
		_finish_boss_intro()
		return
	tween.tween_property(visual_root, "position:y", 0.0, INTRO_FALL_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_boss_intro)


func _finish_boss_intro() -> void:
	if not _intro_active:
		return
	_intro_active = false
	_boss_mode = BossMode.NORMAL
	if visual_root != null:
		visual_root.position.y = 0.0
	if _body_collision != null:
		_body_collision.set_deferred("disabled", false)
	CombatFeedbackClass.spawn_dust(self, global_position, 1.10)
	CombatFeedbackClass.play_enemy_fall_sound(self)
	CombatFeedbackClass.play_impact_sound(self, "finisher")
	CombatFeedbackClass.trigger_screen_shake(self, INTRO_IMPACT_SHAKE, INTRO_IMPACT_SHAKE_TIME)
	CombatFeedbackClass.apply_hitstop(self, self, 0.08)

	var player_node: CharacterBody2D = player_target
	if player_node != null and is_instance_valid(player_node):
		player_node.process_mode = _saved_player_process_mode
	current_state = State.FLANKING
	_attack_timer = 1.10


func _spawn_miss_text() -> void:
	# O boss comunica a esquiva pelo próprio movimento, sem texto flutuante.
	CombatFeedbackClass.spawn_afterimage(self, Color(0.95, 0.90, 0.30, 0.40), 0.12)
	CombatFeedbackClass.spawn_dust(self, global_position, 0.40)


func _on_damaged(amount: float) -> void:
	if _boss_mode in [BossMode.FIRST_RECOVERY, BossMode.PRESSURE_TELEGRAPH, BossMode.PRESSURE_STAGGER, BossMode.PRESSURE_RUSH, BossMode.PRESSURE_RECOVERY, BossMode.INTRO]:
		return
	super._on_damaged(amount)


func _on_damaged_info(info: RefCounted) -> void:
	if _boss_mode in [BossMode.FIRST_RECOVERY, BossMode.PRESSURE_TELEGRAPH, BossMode.PRESSURE_STAGGER, BossMode.PRESSURE_RUSH, BossMode.PRESSURE_RECOVERY, BossMode.INTRO]:
		return
	super._on_damaged_info(info)


func _on_died() -> void:
	_boss_mode = BossMode.DEFEATED
	_intro_active = false
	_pressure_hits = 0
	_pressure_window_timer = 0.0
	if melee_attack != null:
		melee_attack.cancel_attack()
	var player_node: CharacterBody2D = player_target
	if player_node != null and is_instance_valid(player_node):
		player_node.process_mode = _saved_player_process_mode
	CombatFeedbackClass.trigger_screen_shake(self, 11.0, 0.30)
	CombatFeedbackClass.spawn_dust(self, global_position, 1.15)
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
