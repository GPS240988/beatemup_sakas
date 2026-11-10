class_name BebadoEnemy
extends EnemyAI

## Inimigo Especial: O Bêbado (Beat 'em Up Sakas)
## Personalidade: instável, agressivo e imprevisível.
##
## Comportamentos exclusivos integrados à arquitetura canônica:
## 1. ESQUIVA FREQUENTE E IMPREVISÍVEL (DODGE):
##    Reage ativamente à aproximação e ataques com recuos e deslocamentos diagonais,
##    com cooldown calibrado para evitar invulnerabilidade ou loops infinitos.
## 2. RASTEJAMENTO TÁTICO NO SOLO (CRAWL):
##    Rasteja pelo chão após quedas ou aproximações rasteiras com hurtbox rebaixada,
##    respeitando colisões físicas e levantando-se suavemente com 'getup'.
## 3. BEBER DA GARRAFA (DRINK):
##    Ação contextual em momentos de distância segura para reforçar a estética urbana/arcade.
## 4. GOLPES ALTERNADOS (GARRAFADA & CHUTE):
##    Alternância orgânica entre golpes contundentes de garrafa e chutes cambaleantes.

enum BebadoState {
	NONE,
	DODGING,
	CRAWLING,
	DRINKING
}

## Parâmetros de Esquiva
@export_group("Esquiva (Dodge)")
@export var dodge_cooldown_time: float = 2.8
@export var dodge_chance: float = 0.45
@export var dodge_speed: float = 230.0
@export var dodge_duration: float = 0.35

## Parâmetros de Rastejamento
@export_group("Rastejamento (Crawl)")
@export var crawl_duration: float = 2.0
@export var crawl_speed: float = 85.0
@export var crawl_after_downed_chance: float = 0.55

## Parâmetros Contextuais
@export_group("Comportamento Bêbado")
@export var drink_cooldown_time: float = 10.0
@export var drink_heal_amount: float = 8.0

var bebado_state: BebadoState = BebadoState.NONE

var _dodge_cooldown: float = 1.0
var _dodge_timer: float = 0.0
var _dodge_velocity: Vector2 = Vector2.ZERO

var _crawl_timer: float = 0.0
var _crawl_cooldown: float = 4.0

var _drink_cooldown: float = 5.0
var _drink_timer: float = 0.0

var _attack_variant: int = 0
var _default_hurtbox_size: Vector2 = Vector2(50, 160)
var _default_hurtbox_pos: Vector2 = Vector2(0, -85)

@onready var hurtbox_area: Area2D = get_node_or_null("Hurtbox")
@onready var hurtbox_shape: CollisionShape2D = get_node_or_null("Hurtbox/CollisionShape2D")


func _ready() -> void:
	_ensure_internal_refs()
	display_name = "O BÊBADO"

	# Configurações de atributos de movimento cambaleante
	speed_x = 135.0
	speed_y = 95.0
	attack_horizontal_distance = 75.0
	attack_depth_tolerance = 20.0
	attack_windup_seconds = 0.22
	attack_cooldown = 0.70
	recovery_duration = 0.35
	hurt_duration = 0.20

	super._ready()

	if health_component != null:
		health_component.max_health = 90.0
		health_component.current_health = 90.0

	if melee_attack != null:
		melee_attack.damage = 16.0
		melee_attack.horizontal_range = 80.0
		melee_attack.depth_tolerance = 25.0

	if hurtbox_shape != null and hurtbox_shape.shape is RectangleShape2D:
		hurtbox_shape.shape = (hurtbox_shape.shape as RectangleShape2D).duplicate()
		_default_hurtbox_size = (hurtbox_shape.shape as RectangleShape2D).size
	if hurtbox_area != null:
		_default_hurtbox_pos = hurtbox_area.position


func _ensure_internal_refs() -> void:
	if visual_root == null:
		visual_root = get_node_or_null("Visual") as Node2D
	if anim_sprite == null:
		anim_sprite = get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if health_component == null:
		health_component = get_node_or_null("HealthComponent") as HealthComponent
	if melee_attack == null:
		melee_attack = get_node_or_null("MeleeAttack") as MeleeAttack
	if hurtbox_area == null:
		hurtbox_area = get_node_or_null("Hurtbox") as Area2D
	if hurtbox_shape == null:
		hurtbox_shape = get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D


func _physics_process(delta: float) -> void:
	# Atualiza timers de recarga
	if _dodge_cooldown > 0.0:
		_dodge_cooldown -= delta
	if _crawl_cooldown > 0.0:
		_crawl_cooldown -= delta
	if _drink_cooldown > 0.0:
		_drink_cooldown -= delta

	# Processa estados exclusivos do Bêbado
	match bebado_state:
		BebadoState.DODGING:
			_process_bebado_dodge(delta)
			return
		BebadoState.CRAWLING:
			_process_bebado_crawl(delta)
			return
		BebadoState.DRINKING:
			_process_bebado_drink(delta)
			return
		BebadoState.NONE:
			pass

	# Verifica se há oportunidade ou necessidade de esquiva antes da IA padrão
	if _can_attempt_dodge():
		if _evaluate_dodge_reaction():
			start_dodge()
			return

	# Verifica oportunidade contextual de beber
	if _can_attempt_drink():
		start_drink()
		return

	# Executa IA padrão
	super._physics_process(delta)

	# Intercepta recuperação de DOWNED para possível transição de CRAWL
	if current_state == State.DOWNED and _state_timer <= delta and _crawl_cooldown <= 0.0:
		if randf() < crawl_after_downed_chance:
			start_crawl()


## Avalia se o Bêbado pode tentar esquivar
func _can_attempt_dodge() -> bool:
	if bebado_state != BebadoState.NONE:
		return false
	if current_state in [State.HURT, State.FALL, State.DOWNED, State.GETUP, State.DEAD, State.ATTACKING]:
		return false
	if _dodge_cooldown > 0.0:
		return false
	if player_target == null or not is_instance_valid(player_target):
		return false
	return true


## Avalia se a situação tática motiva uma esquiva (proximidade / ataque iminente)
func _evaluate_dodge_reaction() -> bool:
	var dist: float = global_position.distance_to(player_target.global_position)
	var diff_x: float = absf(player_target.global_position.x - global_position.x)
	var diff_y: float = absf(player_target.global_position.y - global_position.y)

	# Se o jogador estiver muito próximo na mesma pista horizontal
	if diff_x < attack_horizontal_distance * 1.5 and diff_y < attack_depth_tolerance * 1.5:
		# Checa se o jogador está atacando
		var player_attacking: bool = false
		if player_target.get("is_attacking") == true or player_target.get("current_state") == 2: # ATTACKING
			player_attacking = true

		if player_attacking:
			return true # Esquiva imediata em reação ao ataque
		elif randf() < dodge_chance:
			return true

	return false


## Inicia a manobra de esquiva imprevisível
func start_dodge() -> void:
	_ensure_internal_refs()
	bebado_state = BebadoState.DODGING
	_dodge_timer = dodge_duration
	_dodge_cooldown = dodge_cooldown_time + randf_range(-0.4, 0.6)

	_release_combat_resources()
	if player_target != null and is_instance_valid(player_target):
		_update_facing(player_target.global_position.x)

	# Direção imprevisível: recuo no eixo X longe do jogador + desvio lateral Y
	var dir_x: float = -facing_direction
	if player_target != null and is_instance_valid(player_target):
		var side: float = signf(global_position.x - player_target.global_position.x)
		if side != 0.0:
			dir_x = side

	var dir_y: float = 1.0 if (randf() > 0.5) else -1.0
	if randf() < 0.25:
		dir_y = 0.0

	_dodge_velocity = Vector2(dir_x * 0.85, dir_y * 0.52).normalized() * dodge_speed
	velocity = _dodge_velocity

	_play_anim("dodge")
	CombatFeedback.spawn_dust(self, global_position)

	# I-Frames rápidos durante a esquiva (desativa hurtbox no primeiro terço)
	if hurtbox_area != null:
		hurtbox_area.set_deferred("monitoring", false)
		hurtbox_area.set_deferred("monitorable", false)


func _process_bebado_dodge(delta: float) -> void:
	_dodge_timer -= delta
	velocity = _dodge_velocity

	move_and_slide()

	# Amortece gradualmente a velocidade no final da esquiva
	_dodge_velocity = _dodge_velocity.move_toward(Vector2.ZERO, 350.0 * delta)

	if _dodge_timer <= 0.0:
		_end_dodge()


func _end_dodge() -> void:
	_ensure_internal_refs()
	bebado_state = BebadoState.NONE
	velocity = Vector2.ZERO

	# Restaura a Hurtbox
	if hurtbox_area != null:
		hurtbox_area.set_deferred("monitoring", true)
		hurtbox_area.set_deferred("monitorable", true)

	current_state = State.FLANKING
	_attack_timer = 0.35
	_play_anim("idle")


## Inicia o rastejamento no solo
func start_crawl() -> void:
	_ensure_internal_refs()
	bebado_state = BebadoState.CRAWLING
	_crawl_timer = crawl_duration
	_crawl_cooldown = 5.0

	_release_combat_resources()

	# Rebaixa a hurtbox para rente ao solo
	_set_crawling_hurtbox(true)
	_play_anim("crawl")


func _process_bebado_crawl(delta: float) -> void:
	_crawl_timer -= delta

	if player_target != null and is_instance_valid(player_target):
		_update_facing(player_target.global_position.x)
		var diff := player_target.global_position - global_position
		var dir := diff.normalized()
		velocity.x = dir.x * crawl_speed
		velocity.y = dir.y * (crawl_speed * 0.6)
	else:
		velocity = Vector2(facing_direction * crawl_speed, 0.0)

	move_and_slide()

	if _crawl_timer <= 0.0:
		_end_crawl()


func _end_crawl() -> void:
	_ensure_internal_refs()
	_set_crawling_hurtbox(false)
	bebado_state = BebadoState.NONE
	velocity = Vector2.ZERO

	current_state = State.GETUP
	_state_timer = 0.32
	_play_anim("getup")


func _set_crawling_hurtbox(crawling: bool) -> void:
	_ensure_internal_refs()
	if hurtbox_shape != null and hurtbox_shape.shape is RectangleShape2D:
		var rect := hurtbox_shape.shape as RectangleShape2D
		if crawling:
			rect.size = Vector2(_default_hurtbox_size.x * 1.3, 40.0)
			if hurtbox_area != null:
				hurtbox_area.position = Vector2(0, -22)
		else:
			rect.size = _default_hurtbox_size
			if hurtbox_area != null:
				hurtbox_area.position = _default_hurtbox_pos


## Avalia se pode beber
func _can_attempt_drink() -> bool:
	if bebado_state != BebadoState.NONE:
		return false
	if current_state != State.FLANKING and current_state != State.WAITING:
		return false
	if _drink_cooldown > 0.0:
		return false
	if player_target == null:
		return false
	# Só bebe a distância segura
	var dist: float = global_position.distance_to(player_target.global_position)
	return dist > 210.0


func start_drink() -> void:
	_ensure_internal_refs()
	bebado_state = BebadoState.DRINKING
	_drink_timer = 1.1
	_drink_cooldown = drink_cooldown_time + randf_range(-1.5, 2.5)
	velocity = Vector2.ZERO
	_play_anim("drink")


func _process_bebado_drink(delta: float) -> void:
	velocity = Vector2.ZERO
	_drink_timer -= delta

	# Se o jogador se aproximar agressivamente durante o gole, cancela
	if player_target != null:
		var dist: float = global_position.distance_to(player_target.global_position)
		if dist < 140.0:
			_end_drink()
			return

	if _drink_timer <= 0.0:
		if health_component != null and not health_component.is_dead:
			health_component.heal(drink_heal_amount)
		_end_drink()


func _end_drink() -> void:
	bebado_state = BebadoState.NONE
	_play_anim("idle")
	current_state = State.FLANKING


## Sobrescreve gatilho de ataque para alternar entre Garrafada e Chute
func _trigger_attack() -> void:
	if melee_attack == null:
		return

	current_state = State.ATTACKING
	_attack_variant = (_attack_variant + 1) % 2

	match _attack_variant:
		0: # Garrafada contundente (soco frontal)
			_play_anim("punch")
			melee_attack.damage = 16.0
			melee_attack.impact_profile = "punch"
			melee_attack.preferred_regions = ["head", "upper_torso"]
			melee_attack.hitbox_offset_y = -95.0
		1: # Chute cambaleante
			_play_anim("kick")
			melee_attack.damage = 20.0
			melee_attack.impact_profile = "kick"
			melee_attack.preferred_regions = ["lower_torso", "legs"]
			melee_attack.hitbox_offset_y = -70.0

	melee_attack.execute_attack(facing_direction)


## Ao sofrer dano, cancela estados específicos do Bêbado imediatamente
func _on_damaged(amount: float) -> void:
	if bebado_state != BebadoState.NONE:
		bebado_state = BebadoState.NONE
		_set_crawling_hurtbox(false)
		if hurtbox_area != null:
			hurtbox_area.set_deferred("monitoring", true)
			hurtbox_area.set_deferred("monitorable", true)

	super._on_damaged(amount)


func _on_damaged_info(info: RefCounted) -> void:
	if bebado_state != BebadoState.NONE:
		bebado_state = BebadoState.NONE
		_set_crawling_hurtbox(false)
		if hurtbox_area != null:
			hurtbox_area.set_deferred("monitoring", true)
			hurtbox_area.set_deferred("monitorable", true)

	super._on_damaged_info(info)
