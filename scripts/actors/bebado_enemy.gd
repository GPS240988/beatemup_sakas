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
@export var dodge_chance: float = 0.50
@export var dodge_speed: float = 230.0
@export var dodge_duration: float = 0.35

## Parâmetros de Rastejamento
@export_group("Rastejamento (Crawl)")
@export_range(0.05, 0.95, 0.05) var crawl_low_health_threshold: float = 0.50
@export var crawl_duration: float = 2.5
@export var crawl_speed: float = 110.0
@export var crawl_contact_damage_cooldown: float = 0.65
@export var crawl_after_downed_chance: float = 0.55
@export var crawl_spontaneous_chance: float = 0.50  # chance por segundo de entrar em crawl espontâneo na batalha
@export var crawl_spontaneous_min_interval: float = 6.0
@export var crawl_spontaneous_max_interval: float = 12.0

## Parâmetros Contextuais
@export_group("Comportamento Bêbado")
@export var drink_cooldown_time: float = 10.0
@export var drink_heal_amount: float = 8.0

## Esquiva - chance de "miss" (mesmo mecanismo de texto do CocaPickup)
@export_group("Esquiva (Miss)")
@export var miss_text: String = "MISS"
@export var miss_font_size: int = 24
@export var miss_color: Color = Color(1.0, 1.0, 0.25, 1.0)  # amarelo arcade
@export var miss_outline_color: Color = Color(0.02, 0.02, 0.02, 1.0)

var bebado_state: BebadoState = BebadoState.NONE

var _dodge_cooldown: float = 1.0
var _dodge_timer: float = 0.0
var _dodge_velocity: Vector2 = Vector2.ZERO

var _crawl_timer: float = 0.0
var _crawl_enter_timer: float = 0.0
var _crawl_cooldown: float = 5.0
var _crawl_damage: float = 12.0
var _crawl_contact_active: bool = false
var _crawl_contact_last_hit_ms: Dictionary = {}
var _next_spontaneous_crawl_time: float = 0.0  # timer para crawl espontâneo
var _spontaneous_crawl_pending: bool = false
var _low_health_crawl_used: bool = false
var _crawl_enter_done: bool = false

var _drink_cooldown: float = 5.0
var _drink_timer: float = 0.0

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

## Mapeamento de nomes padrão da EnemyAI → nomes reais no SpriteFrames do Bêbado.
## As animações do grid-sheet possuem nomenclatura específica; este dicionário traduz
## as chamadas genéricas do EnemyAI (death, fall, hit, etc.) para os nomes corretos.
const _ANIM_MAP: Dictionary = {
	"death": "knockdown",
	"fall": "knockdown",
	"downed": "prone",
	"hit": "hit_recoil",
	"hurt": "hit_recoil",
	"dodge": "dodge_duck",
	"punch": "attack_jab",
	"kick": "lunge_pose",
	"attack": "attack_punch",
	"get_up": "getup",
}


## Sobrescreve _play_anim para traduzir nomes genéricos da EnemyAI
## para as animações reais do spritesheet do Bêbado.
func _play_anim(anim_name: String) -> void:
	var mapped: String = _ANIM_MAP.get(anim_name, anim_name)
	super._play_anim(mapped)

func _notification(what: int) -> void:
	match str(what):
		"NOTIFICATION_EXIT_TREE":
			# Desconecta sinal ao sair da árvore para evitar erros de Lambda
			if hurtbox_area != null and has_method("body_entered"):
				hurtbox_area.body_entered.disconnect(_on_hurtbox_body_entered)





## Finaliza o estado de rastejamento e retorna ao combate normal
func end_crawl() -> void:
	_ensure_internal_refs()
	_activate_crawl_contact_damage(false)
	_set_crawling_hurtbox(false)
	bebado_state = BebadoState.NONE
	velocity = Vector2.ZERO

	current_state = State.GETUP
	_state_timer = 0.32
	_play_anim("getup")

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

	# Conecta sinal de contato da hurtbox para dano por rastejamento
	if hurtbox_area != null:
		hurtbox_area.body_entered.connect(_on_hurtbox_body_entered)

	# Vida base aumentada considerando dificuldade (GameSession: normal=1.0, dificil=2.1)
	var base_health: float = 120.0
	var health_mult: float = 1.0
	var session = get_node_or_null("/root/GameSession") as GameSessionClass
	if session != null:
		var diff_data: Dictionary = session.DIFFICULTIES.get(session.difficulty_id, {})
		health_mult = float(diff_data.get("enemy_health_mult", 1.0))
	if health_component != null:
		health_component.max_health = base_health * health_mult
		health_component.current_health = base_health * health_mult

	# Inicializa timer de crawl espontâneo (primeiro crawl após um intervalo aleatório)
	_next_spontaneous_crawl_time = randf_range(crawl_spontaneous_min_interval, crawl_spontaneous_max_interval)

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

	# Verifica oportunidade contextual de beber
	# O crawl espontaneo nao depende do estado FLANKING nem da distancia.
	if _update_spontaneous_crawl(delta):
		return

	if _can_attempt_drink():
		start_drink()
		return

	# Verifica crawl espontâneo (variante de batalha: não só quando derrubado)
	if false:
		if player_target != null and is_instance_valid(player_target):
			var dist: float = global_position.distance_to(player_target.global_position)
			# Só entra em crawl espontâneo se estiver a uma distância razoável do jogador
			if dist > 120.0 and dist < 400.0:
				_next_spontaneous_crawl_time -= delta
				if _next_spontaneous_crawl_time <= 0.0:
					start_crawl()
					_next_spontaneous_crawl_time = randf_range(crawl_spontaneous_min_interval, crawl_spontaneous_max_interval)
					return

	# Executa IA padrão
	super._physics_process(delta)

	# Intercepta recuperação de DOWNED para possível transição de CRAWL
	if current_state == State.DOWNED and _state_timer <= delta and _crawl_cooldown <= 0.0:
		if randf() < crawl_after_downed_chance:
			start_crawl()


## Verifica se o Bêbado pode tentar esquivar de um golpe recebido.
## A chance é rolada em take_damage(), nunca apenas pela proximidade do jogador.

## Decide o crawl espontaneo durante a batalha, sem interromper acoes criticas.
## Abaixo do limiar de vida, deixa a decisao pendente ate o primeiro estado seguro.
func _update_spontaneous_crawl(delta: float) -> bool:
	if health_component == null or health_component.is_dead or current_state == State.DEAD:
		return false
	if player_target == null or not is_instance_valid(player_target):
		return false

	var player_health := player_target.get_node_or_null("HealthComponent") as HealthComponent
	if player_health != null and player_health.is_dead:
		return false

	var health_ratio: float = health_component.current_health / maxf(health_component.max_health, 1.0)
	var low_health_trigger: bool = (
		health_ratio <= clampf(crawl_low_health_threshold, 0.05, 0.95)
		and not _low_health_crawl_used
	)
	if low_health_trigger:
		_spontaneous_crawl_pending = true

	# Primeira tentativa apos 6-12 s; se falhar, tenta novamente a cada segundo.
	if not _spontaneous_crawl_pending:
		_next_spontaneous_crawl_time -= delta
		if _next_spontaneous_crawl_time <= 0.0:
			if randf() <= clampf(crawl_spontaneous_chance, 0.0, 1.0):
				_spontaneous_crawl_pending = true
			else:
				_next_spontaneous_crawl_time = 1.0

	if not _spontaneous_crawl_pending or _crawl_cooldown > 0.0:
		return false

	# Nao interrompe ataque, preparacao, hitstun, queda ou levantamento.
	if not current_state in [
		State.IDLE,
		State.WAITING,
		State.FLANKING,
		State.ALIGNING_DEPTH,
		State.APPROACHING,
		State.RECOVERY
	]:
		return false

	start_crawl()
	if low_health_trigger:
		_low_health_crawl_used = true
	_spontaneous_crawl_pending = false
	_reset_spontaneous_crawl_timer()
	return true


func _reset_spontaneous_crawl_timer() -> void:
	var minimum_interval: float = maxf(1.0, crawl_spontaneous_min_interval)
	var maximum_interval: float = maxf(minimum_interval, crawl_spontaneous_max_interval)
	_next_spontaneous_crawl_time = randf_range(minimum_interval, maximum_interval)
func _can_attempt_dodge() -> bool:
	if bebado_state != BebadoState.NONE or _dodge_cooldown > 0.0:
		return false
	return not current_state in [
		State.HURT,
		State.FALL,
		State.DOWNED,
		State.GETUP,
		State.DEAD,
		State.ATTACKING
	]


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

	current_state = State.FLANKING
	_attack_timer = 0.35
	_play_anim("idle")


## Inicia o rastejamento no solo (transição crawl_enter -> crawl)
func start_crawl() -> void:
	_ensure_internal_refs()
	if current_state == State.DEAD or (health_component != null and health_component.is_dead):
		return
	bebado_state = BebadoState.CRAWLING
	_crawl_enter_timer = 0.35  # duração da animação de entrada no chão
	_crawl_timer = crawl_duration
	_crawl_cooldown = 5.0

	_release_combat_resources()

	# Rebaixa a hurtbox para rente ao solo
	_set_crawling_hurtbox(true)
	_activate_crawl_contact_damage(false)
	_play_anim("crawl_enter")


func _process_bebado_crawl(delta: float) -> void:
	# Fase de entrada (crawl_enter) antes de começar a rastejar
	if _crawl_enter_timer > 0.0:
		_crawl_enter_timer -= delta
		velocity = Vector2.ZERO
		if _crawl_enter_timer <= 0.0:
			_play_anim("crawl")
			_activate_crawl_contact_damage(true)
		return

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
	_activate_crawl_contact_damage(false)
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


## Sobrescreve gatilho de ataque para alternar entre Jab, Hook e Soco (variação de socos do Bêbado)
func _trigger_attack() -> void:
	if melee_attack == null:
		return

	current_state = State.ATTACKING
	_attack_variant = (_attack_variant + 1) % 4

	match _attack_variant:
		0: # Jab: soco reto rápido, baixo dano
			_play_anim("attack_jab")
			melee_attack.damage = 12.0
			melee_attack.impact_profile = "punch"
			melee_attack.preferred_regions = ["head", "upper_torso"]
			melee_attack.hitbox_offset_y = -100.0
		1: # Hook: golpe curvo, dano médio
			_play_anim("attack_hook")
			melee_attack.damage = 16.0
			melee_attack.impact_profile = "punch"
			melee_attack.preferred_regions = ["upper_torso", "head"]
			melee_attack.hitbox_offset_y = -95.0
		2: # Soco estendido (garrafada), dano médio-alto
			_play_anim("attack_punch")
			melee_attack.damage = 18.0
			melee_attack.impact_profile = "punch"
			melee_attack.preferred_regions = ["head", "upper_torso"]
			melee_attack.hitbox_offset_y = -90.0
		3: # Chute cambaleante ocasional, dano alto
			_play_anim("kick")
			melee_attack.damage = 22.0
			melee_attack.impact_profile = "kick"
			melee_attack.preferred_regions = ["lower_torso", "legs"]
			melee_attack.hitbox_offset_y = -70.0

	melee_attack.execute_attack(facing_direction)


## Ao sofrer dano, cancela estados específicos do Bêbado imediatamente
func _on_damaged(amount: float) -> void:
	if bebado_state != BebadoState.NONE:
		bebado_state = BebadoState.NONE
		_activate_crawl_contact_damage(false)
		_set_crawling_hurtbox(false)

	super._on_damaged(amount)


func _on_damaged_info(info: RefCounted) -> void:
	if bebado_state != BebadoState.NONE:
		bebado_state = BebadoState.NONE
		_activate_crawl_contact_damage(false)
		_set_crawling_hurtbox(false)

	super._on_damaged_info(info)


## Ativa/desativa dano por contato durante o rastejamento (Bêbado rastejando causa dano ao encostar)
func _activate_crawl_contact_damage(active: bool) -> void:
	_crawl_contact_active = active
	if hurtbox_area != null:
		# Layer 4 permanece monitorável para receber golpes do jogador.
		# Mask bit 1 detecta o CharacterBody2D do jogador (layer 1) somente durante crawl.
		hurtbox_area.set_deferred("monitoring", active)
		if active:
			hurtbox_area.set_collision_mask_value(1, true)
		else:
			hurtbox_area.set_collision_mask_value(1, false)


## Identifica golpes originados pelo jogador usando o contrato DamageInfo.
func _is_player_attack(damage_input: Variant) -> bool:
	if not (damage_input is RefCounted):
		return false

	var attacker: Node = damage_input.get("attacker") as Node
	return attacker != null and is_instance_valid(attacker) and attacker.is_in_group("player")


## Recebe dano respeitando os estados exclusivos do Bêbado.
## - Crawl: ignora golpes comuns; aceita especiais.
## - Dodge: evita integralmente golpes do jogador durante a esquiva.
## - Fora desses estados: 50% de chance de esquivar de cada golpe elegível,
##   com MISS exibido apenas quando o dano é efetivamente recusado.
func take_damage(damage_input: Variant) -> bool:
	if bebado_state == BebadoState.CRAWLING:
		var is_special_attack: bool = false
		if damage_input is RefCounted:
			is_special_attack = (
				str(damage_input.get("damage_type")) == "special"
				or str(damage_input.get("impact_profile")) == "special"
			)
		if not is_special_attack:
			return false
		return super.take_damage(damage_input)

	var from_player: bool = _is_player_attack(damage_input)
	if from_player and bebado_state == BebadoState.DODGING:
		_spawn_miss_text()
		return false

	if from_player and _can_attempt_dodge() and randf() < clampf(dodge_chance, 0.0, 1.0):
		start_dodge()
		_spawn_miss_text()
		return false

	return super.take_damage(damage_input)


## Mostra o texto "miss" sobre a cabeça do Bêbado quando ele esquiva de um golpe
## (mesmo mecanismo de fonte e animação usado pelo CocaPickup._spawn_heal_feedback)
func _spawn_miss_text() -> void:
	var head_marker := get_node_or_null("ImpactZones/Head") as Node2D
	var spawn_pos: Vector2 = Vector2(0.0, -220.0)
	if head_marker != null:
		spawn_pos = to_local(head_marker.global_position) + Vector2(0.0, -28.0)

	var feedback := Label.new()
	feedback.name = "MissFeedback"
	feedback.text = miss_text
	feedback.add_theme_font_override("font", ARCADE_FONT)
	feedback.add_theme_font_size_override("font_size", miss_font_size)
	feedback.add_theme_color_override("font_color", miss_color)
	feedback.add_theme_color_override("font_outline_color", miss_outline_color)
	feedback.add_theme_constant_override("outline_size", 6)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	feedback.size = Vector2(200.0, 42.0)
	feedback.modulate = Color(1.0, 1.0, 1.0, 0.0)
	feedback.z_index = 100
	feedback.z_as_relative = false
	feedback.process_mode = Node.PROCESS_MODE_ALWAYS
	feedback.add_to_group("pickup_feedback_labels")

	var spawn_position := spawn_pos - Vector2(feedback.size.x * 0.5, feedback.size.y * 0.5)
	feedback.position = spawn_position
	add_child(feedback)
	var feedback_start_y: float = feedback.position.y

	var tween := feedback.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(feedback, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(feedback, "position:y", feedback_start_y - 42.0, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.28)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.22)
	tween.tween_callback(feedback.queue_free)


## Dano de contato durante o rastejamento.
## O cooldown impede dano repetido por reentrada contínua na área.
func _on_hurtbox_body_entered(body: Node) -> void:
	if not _crawl_contact_active or body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("player") or not body.has_method("take_damage"):
		return

	var now_ms: int = Time.get_ticks_msec()
	var player_id: int = body.get_instance_id()
	var previous_hit_ms: int = int(_crawl_contact_last_hit_ms.get(player_id, -1000000))
	var cooldown_ms: int = maxi(0, roundi(crawl_contact_damage_cooldown * 1000.0))
	if now_ms - previous_hit_ms < cooldown_ms:
		return

	_crawl_contact_last_hit_ms[player_id] = now_ms
	var damage_applied: bool = bool(body.call("take_damage", _crawl_damage))
	if not damage_applied:
		return

	# Empurra levemente o jogador na direção oposta ao Bêbado.
	var push_dir: Vector2 = (body.global_position - global_position).normalized()
	if push_dir == Vector2.ZERO:
		push_dir = Vector2(facing_direction, 0.0)
	if body.has_method("take_knockback"):
		body.call("take_knockback", push_dir * 120.0, 0.15)


## A morte do Bêbado deve concluir a queda e permanecer no chão antes do fade arcade.
## O EnemyAI já dispara "death" (mapeado para "knockdown"); aqui apenas aguardamos a sequência.
func _start_death_fade_sequence() -> void:
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		super._start_death_fade_sequence()
		return

	await _play_death_animation_to_completion(&"knockdown")
	if not is_inside_tree():
		return

	# Mantém a leitura visual da queda: termina a sequência de knockdown e assenta em prone.
	if anim_sprite.sprite_frames.has_animation("prone"):
		await _play_death_animation_to_completion(&"prone")
	if not is_inside_tree():
		return

	super._start_death_fade_sequence()


func _play_death_animation_to_completion(animation_name: StringName) -> void:
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = anim_sprite.sprite_frames
	if not frames.has_animation(animation_name) or frames.get_frame_count(animation_name) <= 0:
		return

	if anim_sprite.animation != animation_name or not anim_sprite.is_playing():
		anim_sprite.play(animation_name)

	if frames.get_animation_loop(animation_name):
		var speed: float = maxf(frames.get_animation_speed(animation_name) * anim_sprite.speed_scale, 0.1)
		var duration: float = float(frames.get_frame_count(animation_name)) / speed
		var tree: SceneTree = get_tree()
		if tree != null:
			await tree.create_timer(duration).timeout
	else:
		await anim_sprite.animation_finished
