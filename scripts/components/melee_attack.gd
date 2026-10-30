class_name MeleeAttack
extends Node2D

## Fases formais do ciclo de ataque arcade 2.5D
enum Phase {
	INACTIVE,
	STARTUP,
	ACTIVE,
	RECOVERY
}

## Sinal emitido na transição de fases do ataque
signal attack_phase_changed(new_phase: Phase)

## Sinal emitido quando o golpe é iniciado
signal attack_started()

## Sinal emitido quando o golpe é concluído (incluindo cooldown/recovery)
signal attack_ended()

## Sinal emitido quando um alvo válido é atingido
signal target_hit(target: Node, damage: float)

## Dano causado pelo ataque
@export var damage: float = 20.0

## Alcance horizontal máximo em pixels
@export var horizontal_range: float = 70.0

## Tolerância de alinhamento em profundidade no eixo Y (em pixels no chão)
@export var depth_tolerance: float = 26.0

## Duração em segundos da preparação antes da abertura da hitbox
@export var startup_duration: float = 0.0

## Duração em segundos em que a janela de acerto fica ativa
@export var active_duration: float = 0.15

## Duração em segundos da recuperação pós-janela ativa (se 0.0, deriva de attack_cooldown)
@export var recovery_duration: float = 0.25

## Intervalo total entre ataques mantido para compatibilidade
@export var attack_cooldown: float = 0.40

const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")
const ImpactZonesClass = preload("res://scripts/combat/impact_zones.gd")

## Propriedades físicas e de impacto do golpe
@export var knockback_force: float = 50.0
@export var hitstun_duration: float = 0.22
@export var can_knockdown: bool = false
@export var hitstop_duration: float = 0.05
@export var impact_profile: String = "punch"

## Regiões anatômicas preferenciais para este ataque ("head", "upper_torso", "lower_torso", "legs")
@export var preferred_regions: Array[String] = []

## Ajuste de altura vertical da hitbox relativo ao centro padrão (valores negativos sobem)
@export var hitbox_offset_y: float = 0.0
var _base_hitbox_y: float = -100.0

## Grupo de alvos válidos ("enemies" ou "player")
@export var target_group: String = "enemies"

## Habilita atingir objetos destrutíveis em paralelo ao grupo alvo
@export var can_hit_props: bool = true

## Validação de linha de visão física (impede golpes através de paredes e balcões na Layer 2)
@export var check_obstacles: bool = true
@export var obstacle_collision_mask: int = 2

var hitbox_area: Area2D
var hitbox_shape: CollisionShape2D

## Estados internos
var is_attacking: bool = false
var is_active_window: bool = false
var current_phase: Phase = Phase.INACTIVE

var facing_direction: float = 1.0 # 1.0 = Direita, -1.0 = Esquerda
var hit_targets: Array[Node] = []

var _phase_timer: float = 0.0
var _hitstop_timer: float = 0.0
var _owner_actor: CharacterBody2D


func is_in_hitstop() -> bool:
	return _hitstop_timer > 0.0


## Aplica hitstop local no componente de ataque para congelar timers de fase e preservar hitbox
func apply_hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	_hitstop_timer = maxf(_hitstop_timer, duration)


func _ready() -> void:
	if _owner_actor == null:
		_owner_actor = get_parent() as CharacterBody2D
	_ensure_hitbox_nodes()
	_set_hitbox_active(false)


func _physics_process(delta: float) -> void:
	# Hitstop local: congela temporizadores de fase e preserva a janela ativa sem avançar o ciclo
	if _hitstop_timer > 0.0:
		_hitstop_timer -= delta
		if _hitstop_timer <= 0.0:
			_hitstop_timer = 0.0
		return

	match current_phase:
		Phase.STARTUP:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				current_phase = Phase.ACTIVE
				is_active_window = true
				_ensure_hitbox_nodes()
				_update_hitbox_transform()
				_set_hitbox_active(true)
				_phase_timer += active_duration
				attack_phase_changed.emit(Phase.ACTIVE)
				_poll_overlapping_targets(true)

		Phase.ACTIVE:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				is_active_window = false
				_set_hitbox_active(false)
				var rec_dur: float = recovery_duration if recovery_duration > 0.0 else maxf(0.0, attack_cooldown - (startup_duration + active_duration))
				if rec_dur > 0.0:
					current_phase = Phase.RECOVERY
					_phase_timer += rec_dur
					attack_phase_changed.emit(Phase.RECOVERY)
				else:
					_finish_attack()
			else:
				_poll_overlapping_targets(false)

		Phase.RECOVERY:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_finish_attack()

		Phase.INACTIVE:
			pass


## Executa a tentativa de ataque na direção informada (1.0 ou -1.0)
func execute_attack(direction: float) -> bool:
	if is_attacking or current_phase != Phase.INACTIVE:
		return false

	if _owner_actor == null:
		_owner_actor = get_parent() as CharacterBody2D

	if _owner_actor != null:
		var health := _find_health_component(_owner_actor)
		if health != null and health.is_dead:
			return false

	facing_direction = 1.0 if direction >= 0.0 else -1.0
	is_attacking = true
	hit_targets.clear()

	_ensure_hitbox_nodes()
	_update_hitbox_transform()

	if startup_duration > 0.0:
		current_phase = Phase.STARTUP
		is_active_window = false
		_phase_timer = startup_duration
		_set_hitbox_active(false)
		attack_phase_changed.emit(Phase.STARTUP)
		attack_started.emit()
	else:
		current_phase = Phase.ACTIVE
		is_active_window = true
		_phase_timer = active_duration
		_set_hitbox_active(true)
		attack_phase_changed.emit(Phase.ACTIVE)
		attack_started.emit()
		_poll_overlapping_targets(true)

	return true


## Finaliza o ataque ao término de todas as fases temporais
func _finish_attack() -> void:
	current_phase = Phase.INACTIVE
	is_attacking = false
	is_active_window = false
	_phase_timer = 0.0
	_set_hitbox_active(false)
	attack_phase_changed.emit(Phase.INACTIVE)
	attack_ended.emit()


## Cancela qualquer ataque em andamento de forma limpa e imediata
func cancel_attack() -> void:
	current_phase = Phase.INACTIVE
	is_attacking = false
	is_active_window = false
	_phase_timer = 0.0
	_hitstop_timer = 0.0
	hit_targets.clear()
	_set_hitbox_active(false)
	attack_phase_changed.emit(Phase.INACTIVE)


## Retorna a duração total da sequência completa do ataque (startup + active + recovery)
func get_total_duration() -> float:
	var rec: float = recovery_duration if recovery_duration > 0.0 else maxf(0.0, attack_cooldown - (startup_duration + active_duration))
	return startup_duration + active_duration + rec


## Garante a presença dos nós de Hitbox mesmo se instanciado puramente por código
func _ensure_hitbox_nodes() -> void:
	if hitbox_area == null:
		hitbox_area = get_node_or_null("HitboxArea") as Area2D
	if hitbox_area == null:
		hitbox_area = Area2D.new()
		hitbox_area.name = "HitboxArea"
		hitbox_area.collision_layer = 8
		hitbox_area.collision_mask = 4
		hitbox_area.monitoring = false
		hitbox_area.monitorable = false
		add_child(hitbox_area)

	if hitbox_shape == null:
		hitbox_shape = hitbox_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if hitbox_shape == null:
		hitbox_shape = CollisionShape2D.new()
		hitbox_shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(horizontal_range, 44.0)
		hitbox_shape.shape = rect
		hitbox_area.add_child(hitbox_shape)

	if hitbox_area != null and hitbox_area.position.y != 0.0:
		_base_hitbox_y = hitbox_area.position.y

	if not hitbox_area.area_entered.is_connected(_on_hitbox_detect):
		hitbox_area.area_entered.connect(_on_hitbox_detect)
	if not hitbox_area.body_entered.is_connected(_on_hitbox_detect):
		hitbox_area.body_entered.connect(_on_hitbox_detect)


## Atualiza o posicionamento horizontal e vertical da hitbox conforme a direção e tipo de golpe
func _update_hitbox_transform() -> void:
	if hitbox_area != null:
		hitbox_area.position.x = (horizontal_range * 0.5) * facing_direction
		if hitbox_offset_y != 0.0:
			hitbox_area.position.y = hitbox_offset_y
		elif _base_hitbox_y != 0.0:
			hitbox_area.position.y = _base_hitbox_y


## Liga ou desliga a monitoração da Hitbox de forma segura
func _set_hitbox_active(active: bool) -> void:
	is_active_window = active
	if hitbox_area != null and is_instance_valid(hitbox_area):
		hitbox_area.set_deferred("monitoring", active)
		hitbox_area.set_deferred("monitorable", false)
	if hitbox_shape != null and is_instance_valid(hitbox_shape):
		hitbox_shape.set_deferred("disabled", not active)


## Analisa os nós que colidiram com a Hitbox
func _on_hitbox_detect(collider: Node) -> void:
	if not is_active_window or current_phase != Phase.ACTIVE:
		return
	_try_hit_target(collider)


## Varre os alvos potenciais (via Area2D overlapping e verificação direta do grupo apenas quando necessário)
func _poll_overlapping_targets(force_group_scan: bool = false) -> void:
	if not is_active_window or current_phase != Phase.ACTIVE:
		return

	var has_monitoring_hitbox: bool = (hitbox_area != null and is_instance_valid(hitbox_area) and is_inside_tree() and hitbox_area.monitoring)

	if has_monitoring_hitbox:
		for body in hitbox_area.get_overlapping_bodies():
			_try_hit_target(body)
		for area in hitbox_area.get_overlapping_areas():
			_try_hit_target(area)

	# Varredura direta dos atores do grupo no SceneTree: executada apenas no frame inicial (force_group_scan)
	# ou como fallback resiliente caso hitbox_area não esteja em monitoramento ativo (ex: testes headless/física pausada).
	# Isso elimina alocações contínuas de arrays por frame a 60 FPS durante o combate.
	if (force_group_scan or not has_monitoring_hitbox) and is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree != null:
			for candidate in tree.get_nodes_in_group(target_group):
				_try_hit_target(candidate)
			if can_hit_props:
				for prop_candidate in tree.get_nodes_in_group("destructibles"):
					_try_hit_target(prop_candidate)


## Verifica se o nó ou entidade corresponde ao grupo alvo
func _is_target_group_match(candidate: Node) -> bool:
	if candidate == null:
		return false
	if candidate.is_in_group(target_group):
		return true
	# Alvos destrutíveis podem ser atingidos se can_hit_props estiver ativo
	if can_hit_props and (candidate.is_in_group("destructibles") or candidate.is_in_group("destructible_props")):
		return true
	# Se configurado para alvos danificáveis gerais
	if target_group == "damageable" and candidate.is_in_group("damageable"):
		return true
	return false


## Valida as 6 regras de acerto 2.5D antes de aplicar dano
func _try_hit_target(node: Node) -> void:
	if node == null or not is_active_window or current_phase != Phase.ACTIVE:
		return

	# Obtém a entidade principal caso o colisor seja um Hurtbox/Area filha
	var target_actor: Node = node
	if not _is_target_group_match(target_actor):
		var parent: Node = node.get_parent()
		if parent != null and _is_target_group_match(parent):
			target_actor = parent
		else:
			return

	# Não atinge o próprio atacante
	if target_actor == _owner_actor or target_actor == self:
		return

	# Regra 6: Alvo não pode já ter sido atingido nesta execução do golpe
	if target_actor in hit_targets:
		return

	# Regra 1: Alvo deve possuir HealthComponent ou método take_damage(), e estar vivo
	var target_health := _find_health_component(target_actor)
	if target_health != null:
		if target_health.is_dead:
			return
	elif target_actor.has_method("take_damage"):
		if target_actor.get("is_broken") == true:
			return
	else:
		return

	# Validação geométrica 2.5D baseada na posição dos pés no chão (global_position)
	var attacker_pos: Vector2 = _owner_actor.global_position if _owner_actor != null else global_position
	var target_node2d := target_actor as Node2D
	if target_node2d == null:
		return
	
	# Para props/veículos volumosos, utiliza o ponto de contato mais próximo na base física/hurtbox
	var target_pos: Vector2 = target_node2d.global_position
	if target_actor.has_method("get_closest_contact_point"):
		target_pos = target_actor.call("get_closest_contact_point", attacker_pos)

	# Regra 2 & 4: Alcance horizontal e à frente do atacante
	var diff_x: float = target_pos.x - attacker_pos.x
	var forward_distance: float = diff_x * facing_direction
	if forward_distance < -10.0 or forward_distance > horizontal_range:
		return

	# Regra 3: Alinhamento no eixo de profundidade Y (perspectiva 2.5D)
	var depth_diff: float = absf(target_pos.y - attacker_pos.y)
	if depth_diff > depth_tolerance:
		return

	# Regra 5: Linha de visão física desobstruída (impede golpes através de paredes e balcões na Layer 2)
	if _has_obstacle_between(attacker_pos, target_pos, target_actor):
		return

	# Registra que o alvo foi atingido neste golpe (impede dano múltiplo)
	hit_targets.append(target_actor)

	# Determinação anatômica da região e da coordenada espacial do impacto
	var hitbox_gpos: Vector2 = hitbox_area.global_position if hitbox_area != null else (attacker_pos + Vector2(facing_direction * (horizontal_range * 0.5), -100.0))
	var hitbox_sz: Vector2 = Vector2(horizontal_range, 70.0)
	if hitbox_shape != null and hitbox_shape.shape is RectangleShape2D:
		hitbox_sz = (hitbox_shape.shape as RectangleShape2D).size

	# Se o atacante estiver no ar (ex: voadora / jump kick), ajusta pelo deslocamento vertical do visual
	if _owner_actor != null:
		var visual: Node2D = _owner_actor.get_node_or_null("Visual") as Node2D
		if visual != null and visual.position.y != 0.0:
			hitbox_gpos.y += visual.position.y

	var impact_res: Dictionary = ImpactZonesClass.resolve_impact_on_target(
		target_actor,
		hitbox_gpos,
		hitbox_sz,
		preferred_regions,
		facing_direction,
		impact_profile
	)
	var impact_region: String = impact_res.get("region", "upper_torso")
	var spark_pos: Vector2 = impact_res.get("position", target_pos + Vector2(0.0, -85.0))

	# Criação desacoplada de DamageInfo (FASE 6 / COMBATE ARCADE)
	var damage_info := DamageInfoClass.new(
		damage,
		_owner_actor,
		attacker_pos,
		Vector2(facing_direction, 0.0),
		"melee",
		knockback_force,
		hitstun_duration,
		can_hit_props,
		can_knockdown,
		hitstop_duration,
		impact_profile,
		impact_region,
		spark_pos
	)

	# Aplica o dano: O atacante entrega DamageInfo, o receptor decide como processar
	var applied: bool = false
	if target_actor.has_method("take_damage"):
		applied = target_actor.take_damage(damage_info)
	elif target_health != null:
		applied = target_health.take_damage(damage_info)

	if applied:
		CombatFeedbackClass.apply_hitstop(_owner_actor, target_actor, hitstop_duration)
		CombatFeedbackClass.spawn_hit_spark(self, spark_pos, Vector2(facing_direction, 0), impact_profile, impact_region)
		CombatFeedbackClass.play_impact_sound(self, impact_profile)
		if impact_profile in ["heavy", "finisher", "special"]:
			CombatFeedbackClass.trigger_screen_shake(self, 6.0, 0.22)
		target_hit.emit(target_actor, damage)


## Aplica os parâmetros completos de um AttackData no componente de ataque
func apply_attack_data(data: RefCounted) -> void:
	if data == null:
		return
	damage = float(data.get("damage"))
	horizontal_range = float(data.get("horizontal_range"))
	depth_tolerance = float(data.get("depth_tolerance"))
	if data.get("startup") != null:
		startup_duration = float(data.get("startup"))
	else:
		startup_duration = 0.0
	active_duration = float(data.get("active"))
	if data.get("recovery") != null:
		recovery_duration = float(data.get("recovery"))
	else:
		recovery_duration = attack_cooldown
	attack_cooldown = recovery_duration
	knockback_force = float(data.get("knockback"))
	hitstun_duration = float(data.get("hitstun"))
	can_knockdown = bool(data.get("can_knockdown"))
	if data.has_method("get_hitstop_duration"):
		hitstop_duration = data.get_hitstop_duration()
	elif data.get("hitstop_frames") != null:
		hitstop_duration = float(data.get("hitstop_frames")) / 60.0
	impact_profile = str(data.get("impact_profile"))
	if data.get("preferred_regions") != null:
		var pr = data.get("preferred_regions")
		preferred_regions.clear()
		if pr is Array:
			for r in pr:
				preferred_regions.append(str(r))
	else:
		preferred_regions.clear()
	if data.get("hitbox_offset_y") != null:
		hitbox_offset_y = float(data.get("hitbox_offset_y"))
	else:
		hitbox_offset_y = 0.0




## Verifica se há um obstáculo sólido (parede/mobília) entre o atacante e o alvo na camada de mundo (Layer 2)
func _has_obstacle_between(start_pos: Vector2, end_pos: Vector2, target_actor: Node) -> bool:
	if not check_obstacles or not is_inside_tree():
		return false

	var world_2d := get_world_2d()
	if world_2d == null:
		return false

	var space := world_2d.direct_space_state
	if space == null:
		return false

	var exclude_rids: Array[RID] = []
	if _owner_actor != null:
		exclude_rids.append(_owner_actor.get_rid())
	if target_actor is CollisionObject2D:
		exclude_rids.append((target_actor as CollisionObject2D).get_rid())

	# Testa a linha de visão um pouco acima da linha do chão (Y - 15px)
	var ray_start := start_pos + Vector2(0.0, -15.0)
	var ray_end := end_pos + Vector2(0.0, -15.0)

	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end, obstacle_collision_mask, exclude_rids)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit := space.intersect_ray(query)
	return not hit.is_empty()


## Localiza o HealthComponent em um nó mesmo se renomeado
func _find_health_component(actor: Node) -> HealthComponent:
	if actor == null:
		return null
	var comp: HealthComponent = actor.get_node_or_null("HealthComponent") as HealthComponent
	if comp != null:
		return comp
	for child in actor.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null
