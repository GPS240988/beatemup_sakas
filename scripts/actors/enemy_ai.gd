class_name EnemyAI
extends CharacterBody2D

## Estados da Máquina de Estados Finita do Inimigo Arcade 2.5D
enum State {
	IDLE,
	WAITING,
	FLANKING,
	ALIGNING_DEPTH,
	APPROACHING,
	TELEGRAPH,
	ATTACKING,
	RECOVERY,
	HURT,
	FALL,
	DOWNED,
	GETUP,
	DEAD,
	CHASE,  # Compatibilidade com referências legadas
	ATTACK  # Compatibilidade com referências legadas
}

## Arquétipos de Comportamento Tático Arcade
enum Archetype {
	GRUNT,
	AGGRESSOR,
	TANK,
	FLANKER
}

## Variantes de paleta de cores para diferenciar visualmente os inimigos
enum PaletteVariant {
	ORIGINAL,   ## Azul original do casaco
	RED,        ## Casaco vermelho
	GREEN,      ## Casaco verde
	PURPLE,     ## Casaco roxo
	ORANGE,     ## Casaco laranja
	CYAN,       ## Casaco ciano/turquesa
	RANDOM      ## Sorteia aleatoriamente ao spawnar
}

## Nome exibido na HUD Arcade quando o inimigo é alvo
@export var display_name: String = "JOGADOR DE MAGIC"

## Arquétipo tático deste inimigo
@export var archetype: Archetype = Archetype.GRUNT

## Variante de paleta de cores deste inimigo (shader hue-shift)
@export var palette_variant: PaletteVariant = PaletteVariant.ORIGINAL

## Sinal emitido quando o inimigo é derrotado
signal enemy_defeated()

## Velocidades de movimentação
@export var speed_x: float = 140.0
@export var speed_y: float = 100.0


## Distância de ataque horizontal e tolerância de alinhamento em profundidade (eixo Y)
@export var attack_horizontal_distance: float = 70.0
@export var attack_depth_tolerance: float = 15.0

## Duração da preparação visual do golpe (telegraph / windup)
@export var attack_windup_seconds: float = 0.25

## Intervalo entre ataques (cooldown)
@export var attack_cooldown: float = 0.8

## Recuo (recoil) após ataque e duração da recuperação
@export var recoil_distance: float = 50.0
@export var recovery_duration: float = 0.4

## Duração do atordoamento ao sofrer dano (hit stun)
@export var hurt_duration: float = 0.22

## Tempo limite perseguindo o jogador com token antes de liberar a iniciativa (segundos)
@export var chase_timeout_seconds: float = 3.5

## Cooldown mínimo para novo golpe após recuperação de dano (segundos)
@export var post_hurt_cooldown: float = 0.40

const CombatDirectorClass = preload("res://scripts/combat/combat_director.gd")
const PaletteSwapShader: Shader = preload("res://shaders/palette_swap.gdshader")

## Mapeamento de PaletteVariant → hue_shift em graus
## Azul original ≈ 220°. Rotação relativa para cada cor:
const PALETTE_HUE_SHIFTS: Dictionary = {
	PaletteVariant.ORIGINAL: 0.0,
	PaletteVariant.RED: 140.0,      # 220 + 140 = 360 → vermelho
	PaletteVariant.GREEN: 260.0,    # 220 + 260 = 480 ≡ 120 → verde
	PaletteVariant.PURPLE: 80.0,    # 220 + 80 = 300 → roxo/magenta
	PaletteVariant.ORANGE: 170.0,   # 220 + 170 = 390 ≡ 30 → laranja
	PaletteVariant.CYAN: 320.0,     # 220 + 320 = 540 ≡ 180 → ciano
}

## Ajuste de luminosidade (value) específico para cada paleta:
## Clareia o casaco vermelho para evitar o aspecto escuro/marrom em cenários
const PALETTE_VALUE_ADJUSTS: Dictionary = {
	PaletteVariant.ORIGINAL: 0.0,
	PaletteVariant.RED: 0.32,       # Clareia a jaqueta vermelha para tom vivo e nítido (+32% brilho)
	PaletteVariant.GREEN: 0.08,
	PaletteVariant.PURPLE: 0.12,
	PaletteVariant.ORANGE: 0.18,
	PaletteVariant.CYAN: 0.05,
}

## Ajuste de saturação específico para cada paleta
const PALETTE_SAT_ADJUSTS: Dictionary = {
	PaletteVariant.ORIGINAL: 0.0,
	PaletteVariant.RED: 0.12,       # Realça o tom vermelho vivo
	PaletteVariant.GREEN: 0.0,
	PaletteVariant.PURPLE: 0.0,
	PaletteVariant.ORANGE: 0.05,
	PaletteVariant.CYAN: 0.0,
}

## Referências internas
@onready var visual_root: Node2D = $Visual
@onready var health_component: HealthComponent = $HealthComponent
@onready var melee_attack: MeleeAttack = $MeleeAttack
@onready var punch_visual: Node2D = get_node_or_null("Visual/PunchVisual")
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("Visual/AnimatedSprite2D")
@onready var health_bar: ProgressBar = $FloatingHealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")

## Diretor de Combate (descoberto via grupo ou atribuído)
var combat_director: Node = null

var current_state: State = State.IDLE
var player_target: CharacterBody2D = null
var facing_direction: float = -1.0 # Inicia virado para a esquerda por padrão

var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _chase_timer: float = 0.0
var _has_token: bool = false
var _is_dead_recorded: bool = false
var _hitstop_timer: float = 0.0
var _saved_anim_speed_scale: float = 1.0


func is_in_hitstop() -> bool:
	return _hitstop_timer > 0.0


## Aplica hitstop local controlado sem travar a interface nem timers globais
func apply_hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	if _hitstop_timer <= 0.0 and anim_sprite != null:
		_saved_anim_speed_scale = anim_sprite.speed_scale if anim_sprite.speed_scale > 0.0 else 1.0
		anim_sprite.speed_scale = 0.0
	_hitstop_timer = maxf(_hitstop_timer, duration)
	if melee_attack != null and is_instance_valid(melee_attack):
		melee_attack.apply_hitstop(duration)


func _ready() -> void:
	add_to_group("actors")
	add_to_group("enemies")
	add_to_group("damageable")

	_apply_archetype_configuration()
	_apply_palette_swap()

	if health_component != null:
		health_component.damaged.connect(_on_damaged)
		health_component.damaged_info.connect(_on_damaged_info)
		health_component.died.connect(_on_died)
		health_component.health_changed.connect(_on_health_changed)

		if health_bar != null:
			health_bar.max_value = health_component.max_health
			health_bar.value = health_component.current_health

	if melee_attack != null:
		melee_attack.attack_started.connect(_on_attack_started)
		melee_attack.attack_ended.connect(_on_attack_ended)

	if punch_visual != null:
		punch_visual.visible = false

	if nav_agent != null:
		nav_agent.velocity_computed.connect(_on_velocity_computed)
		call_deferred("_initialize_navigation")

	# Vincula o diretor de combate se houver na cena
	_find_combat_director()
	_find_player_target()

	current_state = State.FLANKING


func _find_combat_director() -> void:
	var found: Node = get_tree().get_first_node_in_group("combat_director")
	if found != null and found is CombatDirectorClass:
		combat_director = found
		combat_director.register_enemy(self)


func _find_player_target() -> void:
	var found: Node = get_tree().get_first_node_in_group("player")
	if found is CharacterBody2D:
		player_target = found as CharacterBody2D


func _physics_process(delta: float) -> void:
	if _hitstop_timer > 0.0:
		_hitstop_timer -= delta
		if _hitstop_timer <= 0.0:
			_hitstop_timer = 0.0
			if anim_sprite != null:
				anim_sprite.speed_scale = _saved_anim_speed_scale
		return

	if current_state == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Re-procura jogador e diretor se necessário
	if combat_director == null or not is_instance_valid(combat_director):
		_find_combat_director()

	if player_target == null or not is_instance_valid(player_target):
		_find_player_target()
		if player_target == null:
			current_state = State.IDLE
			velocity = Vector2.ZERO
			move_and_slide()
			return

	# Verifica se o jogador foi derrotado
	var player_health: HealthComponent = player_target.get_node_or_null("HealthComponent") as HealthComponent
	if player_health != null and player_health.is_dead:
		_release_combat_resources()
		current_state = State.IDLE
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _attack_timer > 0.0:
		_attack_timer -= delta

	match current_state:
		State.IDLE, State.WAITING:
			_process_waiting(delta)
		State.FLANKING:
			_process_flanking(delta)
		State.ALIGNING_DEPTH:
			_process_aligning_depth(delta)
		State.APPROACHING, State.CHASE:
			_process_approaching(delta)
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.ATTACKING, State.ATTACK:
			_process_attacking(delta)
		State.RECOVERY:
			_process_recovery(delta)
		State.HURT:
			_process_hurt(delta)
		State.FALL:
			_process_fall(delta)
		State.DOWNED:
			_process_downed(delta)
		State.GETUP:
			_process_getup(delta)

	move_and_slide()

	if current_state in [State.FLANKING, State.ALIGNING_DEPTH, State.APPROACHING, State.CHASE]:
		if velocity.length() > 5.0:
			_play_anim("walk")
		else:
			_play_anim("idle")



## Executa animação no AnimatedSprite2D de forma segura e resiliente
func _play_anim(anim_name: String) -> void:
	if anim_sprite != null and anim_sprite.sprite_frames != null:
		if anim_sprite.sprite_frames.has_animation(anim_name):
			if anim_sprite.animation != anim_name or not anim_sprite.is_playing():
				anim_sprite.play(anim_name)


## Atualiza a direção visual para encarar o alvo
func _update_facing(target_x: float) -> void:
	var diff_x: float = target_x - global_position.x
	if absf(diff_x) > 6.0:
		facing_direction = 1.0 if diff_x > 0.0 else -1.0
		if visual_root != null:
			visual_root.scale.x = absf(visual_root.scale.y) * facing_direction


## Estado de espera observacional
func _process_waiting(_delta: float) -> void:
	velocity = Vector2.ZERO
	_play_anim("idle")
	_update_facing(player_target.global_position.x)

	if _attack_timer <= 0.0:
		if _request_token():
			current_state = State.ALIGNING_DEPTH
		else:
			current_state = State.FLANKING


func _initialize_navigation() -> void:
	await get_tree().physics_frame
	if nav_agent != null and is_instance_valid(nav_agent) and nav_agent.is_inside_tree():
		var map_id: RID = nav_agent.get_navigation_map()
		if map_id.is_valid():
			while NavigationServer2D.map_get_iteration_id(map_id) == 0:
				await get_tree().physics_frame


## Verifica se há colisão/obstáculo sólido entre duas coordenadas do mapa
func _has_obstacle_between(start_pos: Vector2, end_pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	# Collision mask 2 = obstáculos estáticos (mobílias, paredes, estantes)
	var query := PhysicsRayQueryParameters2D.create(start_pos, end_pos, 2, [get_rid()])
	var result := space.intersect_ray(query)
	return not result.is_empty()


## Guia o inimigo através dos pontos da malha de navegação (NavigationAgent2D)
func _follow_agent_path(_delta: float) -> void:
	if nav_agent == null or not is_instance_valid(nav_agent):
		return
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var diff := next_pos - global_position
	if diff.length() > 6.0:
		var dir := diff.normalized()
		var desired_vel := Vector2(dir.x * speed_x, dir.y * speed_y)
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(desired_vel)
		else:
			velocity = desired_vel
	else:
		velocity = Vector2.ZERO


## Callback de avoidance local (RVO) para evitar empilhamento mútuo entre inimigos
func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if current_state in [State.FLANKING, State.ALIGNING_DEPTH, State.APPROACHING, State.CHASE]:
		velocity = safe_velocity


## Estado de flanqueamento: mantém distância sem aglomerar com outros inimigos
func _process_flanking(delta: float) -> void:
	_update_facing(player_target.global_position.x)

	# Se puder obter token, assume a iniciativa ofensiva
	if _attack_timer <= 0.0 and _request_token():
		current_state = State.ALIGNING_DEPTH
		return

	# Calcula destino de espera designado pelo diretor para ocupar pista alternativa
	var target_pos: Vector2 = Vector2.ZERO
	if combat_director != null and is_instance_valid(combat_director):
		target_pos = combat_director.get_flank_target_position(self)
	else:
		# Fallback autônomo sem diretor (ex: testes unitários isolados)
		var side: float = -1.0 if (get_instance_id() % 2 == 0) else 1.0
		target_pos = player_target.global_position + Vector2(side * 140.0, 30.0)

	var to_target: Vector2 = target_pos - global_position
	if to_target.length() > 20.0:
		if nav_agent != null and _has_obstacle_between(global_position, target_pos):
			nav_agent.target_position = target_pos
			_follow_agent_path(delta)
		else:
			var dir := to_target.normalized()
			velocity.x = dir.x * (speed_x * 0.75)
			velocity.y = dir.y * (speed_y * 0.75)
	else:
		velocity = Vector2.ZERO


## Estágio 1 do combate 2.5D: alinhamento gradual no eixo de profundidade (Y)
func _process_aligning_depth(delta: float) -> void:
	if not _has_token and not _request_token():
		current_state = State.FLANKING
		return

	_chase_timer += delta
	if _chase_timer >= chase_timeout_seconds:
		_chase_timer = 0.0
		_release_combat_resources()
		_attack_timer = 1.0
		current_state = State.FLANKING
		return

	_update_facing(player_target.global_position.x)

	var target_y: float = player_target.global_position.y
	var diff_y: float = target_y - global_position.y

	# Se o alinhamento de profundidade estiver dentro da tolerância, avança para estágio 2
	if absf(diff_y) <= attack_depth_tolerance:
		velocity.y = 0.0
		current_state = State.APPROACHING
		return

	# Checa se há obstáculo vertical no caminho até o alinhamento
	var vert_target := Vector2(global_position.x, target_y)
	if nav_agent != null and _has_obstacle_between(global_position, vert_target):
		nav_agent.target_position = vert_target
		_follow_agent_path(delta)
	else:
		velocity.x = 0.0
		velocity.y = signf(diff_y) * speed_y


## Estágio 2 do combate 2.5D: aproximação horizontal no eixo X na mesma pista
func _process_approaching(delta: float) -> void:
	if not _has_token and not _request_token():
		current_state = State.FLANKING
		return

	_chase_timer += delta
	if _chase_timer >= chase_timeout_seconds:
		_chase_timer = 0.0
		_release_combat_resources()
		_attack_timer = 1.0
		current_state = State.FLANKING
		return

	_update_facing(player_target.global_position.x)

	var diff_x: float = player_target.global_position.x - global_position.x
	var diff_y: float = player_target.global_position.y - global_position.y

	# Se o jogador mudou substancialmente de pista Y, realinha a profundidade
	if absf(diff_y) > attack_depth_tolerance * 1.6:
		current_state = State.ALIGNING_DEPTH
		return

	# Chegou ao alcance horizontal de golpe
	if absf(diff_x) <= attack_horizontal_distance:
		velocity = Vector2.ZERO

		# Consulta se a janela de dano ativa está desocupada
		var can_attack: bool = true
		if combat_director != null and is_instance_valid(combat_director):
			can_attack = combat_director.can_start_active_attack(self)

		if can_attack:
			# Inicia a fase de preparação (Telegraph)
			_chase_timer = 0.0
			current_state = State.TELEGRAPH
			_state_timer = attack_windup_seconds
			if visual_root != null:
				# Indicação visual clara de preparação (flash amarelado)
				visual_root.modulate = Color(1.8, 1.6, 0.4, 1.0)
		return

	# Checa se há obstáculo no caminho horizontal até o jogador
	var target_x: float = player_target.global_position.x - facing_direction * attack_horizontal_distance
	var horiz_target := Vector2(target_x, global_position.y)
	if nav_agent != null and _has_obstacle_between(global_position, horiz_target):
		nav_agent.target_position = Vector2(target_x, player_target.global_position.y)
		_follow_agent_path(delta)
	else:
		velocity.x = signf(diff_x) * speed_x
		velocity.y = 0.0


## Estado de preparação do golpe (Telegraph / Wind-up)
func _process_telegraph(delta: float) -> void:
	velocity = Vector2.ZERO
	_play_anim("guard")
	_state_timer -= delta

	# Se o jogador esquivar ou se distanciar bruscamente durante o wind-up, cancela
	var diff_x: float = absf(player_target.global_position.x - global_position.x)
	var diff_y: float = absf(player_target.global_position.y - global_position.y)
	if diff_x > attack_horizontal_distance + 35.0 or diff_y > attack_depth_tolerance * 2.0:
		_reset_visual_modulate()
		current_state = State.ALIGNING_DEPTH
		return

	# Finaliza a preparação e dispara o ataque ativo
	if _state_timer <= 0.0:
		_reset_visual_modulate()
		if combat_director != null and is_instance_valid(combat_director):
			combat_director.notify_attack_started(self)
		_trigger_attack()


## Estado de ataque com hitbox ativa
func _process_attacking(_delta: float) -> void:
	velocity = Vector2.ZERO


## Estado de recuperação (recoil para trás e intervalo pós-golpe)
func _process_recovery(delta: float) -> void:
	# Amortece o recuo gradualmente
	velocity = velocity.move_toward(Vector2.ZERO, 250.0 * delta)
	_state_timer -= delta

	if _state_timer <= 0.0:
		_attack_timer = attack_cooldown
		current_state = State.FLANKING
		_play_anim("idle")


## Estado de dano / atordoamento
func _process_hurt(delta: float) -> void:
	_play_anim("hurt")
	velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	_state_timer -= delta

	if _state_timer <= 0.0:
		_reset_visual_modulate()
		_attack_timer = maxf(_attack_timer, post_hurt_cooldown)
		current_state = State.FLANKING
		_play_anim("idle")


## Estado de queda e projeção no solo (Knockdown)
func _process_fall(delta: float) -> void:
	_play_anim("fall")
	velocity = velocity.move_toward(Vector2.ZERO, 380.0 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		current_state = State.DOWNED
		_state_timer = 0.35
		velocity = Vector2.ZERO
		CombatFeedback.spawn_dust(self, global_position)
		if anim_sprite != null:
			visual_root.rotation_degrees = 0.0
			visual_root.position.y = 0.0
			_play_anim("downed")
		elif visual_root != null:
			visual_root.rotation_degrees = 90.0
			visual_root.position.y = -10.0


## Inimigo caído no chão
func _process_downed(delta: float) -> void:
	velocity = Vector2.ZERO
	_play_anim("downed")
	_state_timer -= delta
	if _state_timer <= 0.0:
		current_state = State.GETUP
		_state_timer = 0.28
		_play_anim("getup")


## Inimigo se levantando do chão
func _process_getup(delta: float) -> void:
	velocity = Vector2.ZERO
	_play_anim("getup")
	_state_timer -= delta
	if visual_root != null:
		if anim_sprite == null:
			var progress: float = clampf(1.0 - (_state_timer / 0.28), 0.0, 1.0)
			visual_root.rotation_degrees = lerpf(90.0, 0.0, progress)
			visual_root.position.y = lerpf(-10.0, 0.0, progress)
		else:
			visual_root.rotation_degrees = 0.0
			visual_root.position.y = 0.0
	if _state_timer <= 0.0:
		if visual_root != null:
			visual_root.rotation_degrees = 0.0
			visual_root.position.y = 0.0
		_reset_visual_modulate()
		_attack_timer = maxf(_attack_timer, post_hurt_cooldown)
		current_state = State.FLANKING
		_play_anim("idle")



func _trigger_attack() -> void:
	if melee_attack == null:
		return
	current_state = State.ATTACKING
	match archetype:
		Archetype.AGGRESSOR, Archetype.FLANKER:
			_play_anim("kick")
		Archetype.TANK:
			_play_anim("heavy")
		_:
			_play_anim("punch")
	melee_attack.execute_attack(facing_direction)


func _on_attack_started() -> void:
	if punch_visual != null:
		punch_visual.visible = true


func _on_attack_ended() -> void:
	if punch_visual != null:
		punch_visual.visible = false

	# Notifica diretor e libera o token
	if combat_director != null and is_instance_valid(combat_director):
		combat_director.notify_attack_ended(self)
		combat_director.release_attack_token(self)
	_has_token = false

	if current_state != State.DEAD and current_state != State.HURT:
		current_state = State.RECOVERY
		_state_timer = recovery_duration
		_play_anim("idle")

		# Recuo seguro no eixo X contrário à direção do golpe
		var recoil_dir: float = -facing_direction
		if player_target != null:
			recoil_dir = signf(global_position.x - player_target.global_position.x)
		velocity = Vector2(recoil_dir * (recoil_distance / maxf(0.1, recovery_duration)), 0.0)


func _on_damaged(_amount: float) -> void:
	if current_state == State.DEAD:
		return

	_release_combat_resources()

	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false

	current_state = State.HURT
	_state_timer = hurt_duration

	# Flash visual vermelho e leve knockback
	if visual_root != null:
		visual_root.modulate = Color(2.0, 0.3, 0.3, 1.0)

	var knockback_dir: float = -facing_direction
	if player_target != null:
		knockback_dir = signf(global_position.x - player_target.global_position.x)
	velocity = Vector2(knockback_dir * 120.0, 0.0)


## Tratamento de dano enriquecido via DamageInfo (FASE COMBATE ARCADE)
func _on_damaged_info(info: RefCounted) -> void:
	if current_state == State.DEAD:
		return

	var can_kd: bool = false
	var knockback: float = 120.0
	if info != null:
		can_kd = bool(info.get("can_knockdown"))
		knockback = float(info.get("knockback_force"))

	# Se for o chefe, resiste à queda comum a menos que seja golpe especial
	var is_boss: bool = (get("is_boss") == true or (get_script() != null and get_script().resource_path.ends_with("boss_alessandro.gd")))
	if is_boss and not (info != null and str(info.get("damage_type")) == "special"):
		can_kd = false

	# Tanque resiste a knockback comum e não cai em golpes normais
	if archetype == Archetype.TANK and not (info != null and str(info.get("damage_type")) == "special"):
		knockback *= 0.5
		can_kd = false

	var knockback_dir: float = -facing_direction
	if info != null and info.get("direction") != null and info.get("direction").x != 0.0:
		knockback_dir = signf(info.get("direction").x)
	elif info != null and info.get("attacker") != null and is_instance_valid(info.get("attacker")):
		knockback_dir = signf(global_position.x - info.get("attacker").global_position.x)
		if knockback_dir == 0.0:
			knockback_dir = -facing_direction
	elif player_target != null:
		knockback_dir = signf(global_position.x - player_target.global_position.x)
		if knockback_dir == 0.0:
			knockback_dir = -facing_direction

	if can_kd:
		_release_combat_resources()
		if melee_attack != null:
			melee_attack.cancel_attack()
		if punch_visual != null:
			punch_visual.visible = false

		current_state = State.FALL
		_state_timer = 0.32
		velocity = Vector2(knockback_dir * maxf(180.0, knockback * 2.2), 0.0)
		_play_anim("fall")
		if visual_root != null:
			visual_root.modulate = Color(2.5, 0.3, 0.3, 1.0)
			if anim_sprite == null:
				visual_root.rotation_degrees = -30.0 * knockback_dir
			else:
				visual_root.rotation_degrees = 0.0
	else:
		velocity = Vector2(knockback_dir * maxf(80.0, knockback), 0.0)
		var custom_stun: float = float(info.get("hitstun_duration")) if info != null else 0.0
		if custom_stun > 0.0:
			_state_timer = custom_stun


## Aplica o shader de palette swap no AnimatedSprite2D com base na variante exportada
func _apply_palette_swap() -> void:
	if anim_sprite == null:
		return

	# Resolve RANDOM para uma variante concreta aleatória (excluindo ORIGINAL e RANDOM)
	var effective_variant: PaletteVariant = palette_variant
	if effective_variant == PaletteVariant.RANDOM:
		var options: Array[int] = [
			PaletteVariant.RED,
			PaletteVariant.GREEN,
			PaletteVariant.PURPLE,
			PaletteVariant.ORANGE,
			PaletteVariant.CYAN,
		]
		effective_variant = options[randi() % options.size()] as PaletteVariant

	# ORIGINAL = sem shader (performance: evita draw call extra)
	if effective_variant == PaletteVariant.ORIGINAL:
		anim_sprite.material = null
		return

	# Cria ShaderMaterial único por instância para permitir variações individuais
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = PaletteSwapShader

	var hue_shift_value: float = PALETTE_HUE_SHIFTS.get(effective_variant, 0.0) as float
	var val_adj: float = PALETTE_VALUE_ADJUSTS.get(effective_variant, 0.0) as float
	var sat_adj: float = PALETTE_SAT_ADJUSTS.get(effective_variant, 0.0) as float
	mat.set_shader_parameter("hue_shift", hue_shift_value)
	mat.set_shader_parameter("target_hue", 220.0)       # Azul do casaco
	mat.set_shader_parameter("hue_tolerance", 45.0)
	mat.set_shader_parameter("min_saturation", 0.08)
	mat.set_shader_parameter("saturation_adjust", sat_adj)
	mat.set_shader_parameter("value_adjust", val_adj)

	anim_sprite.material = mat


## Permite alterar a paleta em runtime (ex: ao ser atingido por magia, buff visual)
func set_palette(new_variant: Variant) -> void:
	if new_variant is int:
		palette_variant = new_variant as PaletteVariant
	elif new_variant is PaletteVariant:
		palette_variant = new_variant
	_apply_palette_swap()


## Alias tipado de set_palette
func set_palette_variant(new_variant: PaletteVariant) -> void:
	palette_variant = new_variant
	_apply_palette_swap()



## Aplica configurações de arquétipo tático sem alterar os valores padrão do GRUNT
func _apply_archetype_configuration() -> void:
	# Define a variante de paleta canônica do arquétipo se nenhuma variante customizada foi definida
	if palette_variant == PaletteVariant.ORIGINAL:
		match archetype:
			Archetype.AGGRESSOR:
				palette_variant = PaletteVariant.RED
			Archetype.TANK:
				palette_variant = PaletteVariant.PURPLE
			Archetype.FLANKER:
				palette_variant = PaletteVariant.GREEN
			Archetype.GRUNT:
				palette_variant = PaletteVariant.ORIGINAL

	match archetype:
		Archetype.AGGRESSOR:
			speed_x = 175.0
			speed_y = 120.0
			attack_windup_seconds = 0.18
			attack_cooldown = 0.60
			chase_timeout_seconds = 2.8
		Archetype.TANK:
			if health_component != null:
				health_component.max_health = 140.0
				health_component.current_health = 140.0
				if health_bar != null:
					health_bar.max_value = 140.0
					health_bar.value = 140.0
			speed_x = 100.0
			speed_y = 75.0
			attack_windup_seconds = 0.35
			recoil_distance = 25.0
			if melee_attack != null:
				melee_attack.damage = 22.0
		Archetype.FLANKER:
			speed_x = 155.0
			speed_y = 110.0
			attack_horizontal_distance = 80.0
		Archetype.GRUNT:
			pass

	if is_inside_tree() and anim_sprite != null:
		_apply_palette_swap()



func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar != null:
		health_bar.max_value = max_val
		health_bar.value = current


func _on_died() -> void:
	if _is_dead_recorded:
		return
	_is_dead_recorded = true

	current_state = State.DEAD
	velocity = Vector2.ZERO
	_hitstop_timer = 0.0
	if anim_sprite != null:
		anim_sprite.speed_scale = 1.0

	_release_combat_resources()

	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false
	if health_bar != null:
		health_bar.visible = false

	# Desativa colisão física para não bloquear a passagem
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)

	# Desativa Hurtbox para não receber golpes adicionais caído
	var hurtbox_node: Area2D = get_node_or_null("Hurtbox") as Area2D
	if hurtbox_node != null:
		hurtbox_node.set_deferred("monitoring", false)
		hurtbox_node.set_deferred("monitorable", false)

	if visual_root != null:
		if anim_sprite != null:
			visual_root.rotation_degrees = 0.0
			visual_root.position.y = 0.0
			_play_anim("death")
			CombatFeedback.spawn_dust(self, global_position)
		else:
			visual_root.rotation_degrees = 90.0
			visual_root.position.y = -10.0
		visual_root.modulate = Color(0.6, 0.6, 0.6, 1.0)

	# Notifica diretor e emite sinal de vitória
	if combat_director != null and is_instance_valid(combat_director):
		combat_director.notify_enemy_defeated(self)

	enemy_defeated.emit()

	# Inicia sequência arcade de piscar e desaparecer
	_start_death_fade_sequence()


## Inicia sequência clássica arcade de piscar e sumir
func _start_death_fade_sequence() -> void:
	if visual_root == null:
		queue_free()
		return

	var tween: Tween = create_tween()
	if tween == null:
		queue_free()
		return

	# Pisca 4 vezes (1.2 segundos no total)
	for i in range(4):
		tween.tween_property(visual_root, "modulate:a", 0.15, 0.15)
		tween.tween_property(visual_root, "modulate:a", 0.75, 0.15)

	# Desaparece e remove o nó do mapa
	tween.tween_property(visual_root, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)


## Solicita token ao diretor de combate com fallback autônomo
func _request_token() -> bool:
	if _has_token:
		return true

	if combat_director != null and is_instance_valid(combat_director):
		var granted: bool = combat_director.request_attack_token(self)
		_has_token = granted
		return granted

	# Sem diretor presente (ex: modo teste unitário básico)
	_has_token = true
	return true


## Libera token e ataque ativo no diretor
func _release_combat_resources() -> void:
	if combat_director != null and is_instance_valid(combat_director):
		combat_director.release_attack_token(self)
		combat_director.notify_attack_ended(self)
	_has_token = false
	_chase_timer = 0.0


## Chamado quando o diretor revoga o token por tempo excedido
func _on_token_revoked() -> void:
	_has_token = false
	_chase_timer = 0.0
	_attack_timer = 1.0
	if current_state in [State.ALIGNING_DEPTH, State.APPROACHING, State.TELEGRAPH]:
		_reset_visual_modulate()
		current_state = State.FLANKING


func _reset_visual_modulate() -> void:
	if visual_root != null:
		visual_root.modulate = Color.WHITE


## Ponto de entrada canônico para recebimento de dano (Damage Contract)
func take_damage(damage_input: Variant) -> bool:
	if health_component != null:
		return health_component.take_damage(damage_input)
	return false
