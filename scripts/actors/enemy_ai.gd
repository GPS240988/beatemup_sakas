class_name EnemyAI
extends CharacterBody2D

## Estados finitos da IA do inimigo
enum State { IDLE, CHASE, ATTACK, HURT, DEAD }

## Sinal emitido quando o inimigo é derrotado
signal enemy_defeated()

## Velocidades de movimentação
@export var speed_x: float = 140.0
@export var speed_y: float = 100.0

## Distância de ataque e tolerância de alinhamento
@export var attack_horizontal_distance: float = 60.0
@export var attack_depth_tolerance: float = 24.0

## Intervalo entre decisões ou ataques
@export var attack_cooldown: float = 1.0

## Referências internas
@onready var visual_root: Node2D = $Visual
@onready var health_component: HealthComponent = $HealthComponent
@onready var melee_attack: MeleeAttack = $MeleeAttack
@onready var punch_visual: Node2D = $Visual/PunchVisual
@onready var health_bar: ProgressBar = $FloatingHealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var current_state: State = State.IDLE
var player_target: CharacterBody2D
var facing_direction: float = -1.0 # Inimigos costumam iniciar virados para a esquerda

var _state_timer: float = 0.0
var _attack_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemies")

	if health_component != null:
		health_component.damaged.connect(_on_damaged)
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

	# Busca o jogador se não atribuído diretamente
	_find_player_target()
	current_state = State.CHASE


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Garante referência ao jogador
	if player_target == null or not is_instance_valid(player_target):
		_find_player_target()
		if player_target == null:
			current_state = State.IDLE
			velocity = Vector2.ZERO
			move_and_slide()
			return

	# Se o jogador foi derrotado, o inimigo comemora ou fica IDLE
	var player_health: HealthComponent = player_target.get_node_or_null("HealthComponent") as HealthComponent
	if player_health != null and player_health.is_dead:
		if melee_attack != null and melee_attack.is_attacking:
			melee_attack.cancel_attack()
		current_state = State.IDLE
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _attack_timer > 0.0:
		_attack_timer -= delta

	match current_state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase()
		State.ATTACK:
			_process_attack()
		State.HURT:
			_process_hurt(delta)

	move_and_slide()


func _process_idle() -> void:
	velocity = Vector2.ZERO
	# Se o jogador ainda estiver vivo, retoma a perseguição
	var player_health: HealthComponent = player_target.get_node_or_null("HealthComponent") as HealthComponent
	if player_health != null and not player_health.is_dead:
		current_state = State.CHASE


func _process_chase() -> void:
	var diff_x: float = player_target.global_position.x - global_position.x
	var diff_y: float = player_target.global_position.y - global_position.y

	# Atualiza a direção do olhar
	if absf(diff_x) > 10.0:
		facing_direction = 1.0 if diff_x > 0.0 else -1.0
		if visual_root != null:
			visual_root.scale.x = facing_direction

	var in_x_range: bool = absf(diff_x) <= attack_horizontal_distance
	var in_y_range: bool = absf(diff_y) <= attack_depth_tolerance

	# Se estiver na distância e profundidade ideais, ataca
	if in_x_range and in_y_range:
		velocity = Vector2.ZERO
		if _attack_timer <= 0.0:
			_trigger_attack()
		return

	# Movimentação calculada para interceptação suave sem oscilação
	var move_dir: Vector2 = Vector2.ZERO

	if not in_x_range:
		# Aproxima-se lateralmente até a distância de golpe
		move_dir.x = signf(diff_x)

	if not in_y_range:
		# Alinha-se no eixo de profundidade
		move_dir.y = signf(diff_y)

	if move_dir != Vector2.ZERO:
		move_dir = move_dir.normalized()
		velocity.x = move_dir.x * speed_x
		velocity.y = move_dir.y * speed_y
	else:
		velocity = Vector2.ZERO


func _process_attack() -> void:
	# Durante o ataque, o inimigo fica parado finalizando o golpe
	velocity = Vector2.ZERO


func _process_hurt(delta: float) -> void:
	# Decai velocidade de knockback
	velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		if visual_root != null:
			visual_root.modulate = Color.WHITE
		current_state = State.CHASE


func _trigger_attack() -> void:
	if melee_attack == null:
		return
	current_state = State.ATTACK
	_attack_timer = attack_cooldown
	melee_attack.execute_attack(facing_direction)


func _on_attack_started() -> void:
	if punch_visual != null:
		punch_visual.visible = true


func _on_attack_ended() -> void:
	if punch_visual != null:
		punch_visual.visible = false
	if current_state != State.DEAD and current_state != State.HURT:
		current_state = State.CHASE


func _on_damaged(amount: float) -> void:
	if current_state == State.DEAD:
		return

	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false

	current_state = State.HURT
	_state_timer = 0.22

	# Flash visual vermelho e leve knockback para trás
	if visual_root != null:
		visual_root.modulate = Color(2.0, 0.3, 0.3, 1.0)

	var knockback_dir: float = -facing_direction
	if player_target != null:
		knockback_dir = signf(global_position.x - player_target.global_position.x)
	velocity = Vector2(knockback_dir * 120.0, 0.0)


func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar != null:
		health_bar.max_value = max_val
		health_bar.value = current


func _on_died() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO

	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false
	if health_bar != null:
		health_bar.visible = false

	# Desativa colisão física para não bloquear o jogador após derrotado
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)

	if visual_root != null:
		visual_root.rotation_degrees = 90.0
		visual_root.position.y = -10.0
		visual_root.modulate = Color(0.4, 0.4, 0.4, 0.75)

	enemy_defeated.emit()


func _find_player_target() -> void:
	var found: Node = get_tree().get_first_node_in_group("player")
	if found is CharacterBody2D:
		player_target = found as CharacterBody2D
