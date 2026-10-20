class_name BaseNPC
extends CharacterBody2D

## Contrato Arquitetural de NPC e Máquina de Estados Móvel (FASE 7).
## Representa atores não-jogáveis (civis, comerciantes, pedestres, aliados, NPCs de evento).
## Pertence estritamente aos grupos: 'actors', 'npcs' e opcionalmente 'damageable'.
## NUNCA pertence ao grupo 'enemies' e NUNCA é controlado pelo CombatDirector.
##
## MÁQUINA DE ESTADOS DO NPC:
## IDLE     -> Parado, aguardando interações ou transição.
## WANDER   -> Perambula suavemente em torno do ponto de origem sem spam de rota.
## MOVE_TO  -> Desloca-se até coordenada específica (waypoint/evento).
## WAIT     -> Aguarda por tempo determinado antes de retomar estado anterior.
## FLEE     -> Foge em disparada para longe de ameaças ou em direção à saída.
## EVENT    -> Controlado externamente por triggers de cena, scripts de fase ou diálogos.
## DISABLED -> Inerte, física e processamento pausados.

enum NPCState {
	IDLE,
	WANDER,
	MOVE_TO,
	WAIT,
	FLEE,
	EVENT,
	DISABLED
}

signal state_changed(new_state: NPCState)
signal destination_reached()
signal npc_interacted()
signal npc_damaged(amount: float, current_health: float)
signal npc_fled()

@export_group("Atributos do NPC")
@export var npc_name: String = "Cidadão"
@export var is_damageable: bool = true
@export var max_health: float = 20.0

@export_group("Locomoção e IA")
@export var default_state: NPCState = NPCState.IDLE
@export var walk_speed: float = 90.0
@export var run_speed: float = 180.0
@export var wander_radius: float = 120.0
@export var wander_interval: float = 3.0
@export var flee_distance: float = 400.0

var current_state: NPCState = NPCState.IDLE
var current_health: float = 20.0
var is_fleeing: bool = false
var facing_direction: float = 1.0

var target_position: Vector2 = Vector2.ZERO
var home_position: Vector2 = Vector2.ZERO
var follow_target: Node2D = null

var _state_timer: float = 0.0
var _pathfind_cooldown: float = 0.0
const PATHFIND_MIN_INTERVAL: float = 0.25 # Previne spam de cálculo de rota

@onready var visual_root: Node2D = get_node_or_null("Visual") as Node2D
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
@onready var health_component: Node = get_node_or_null("HealthComponent")
@onready var nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D


func _ready() -> void:
	add_to_group("actors")
	add_to_group("npcs")
	if is_damageable:
		add_to_group("damageable")

	y_sort_enabled = true
	current_health = max_health
	home_position = global_position
	target_position = global_position

	# Camada física padrão: Layer 1 (Atores), Mask 2 (Mundo sólido / Mobílias)
	collision_layer = 1
	collision_mask = 2
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	if hurtbox != null:
		hurtbox.collision_layer = 4 # Layer 3 (Hurtbox)
		hurtbox.collision_mask = 0
		hurtbox.monitoring = false
		hurtbox.monitorable = is_damageable

	if health_component != null:
		health_component.set("max_health", max_health)
		health_component.set("current_health", max_health)
		if health_component.has_signal("damaged"):
			health_component.connect("damaged", _on_health_component_damaged)
		if health_component.has_signal("died"):
			health_component.connect("died", _on_health_component_died)

	change_state(default_state)


func _physics_process(delta: float) -> void:
	if current_state == NPCState.DISABLED:
		velocity = Vector2.ZERO
		return

	if _pathfind_cooldown > 0.0:
		_pathfind_cooldown -= delta

	match current_state:
		NPCState.IDLE:
			velocity = Vector2.ZERO

		NPCState.WAIT:
			velocity = Vector2.ZERO
			_state_timer -= delta
			if _state_timer <= 0.0:
				change_state(NPCState.IDLE)

		NPCState.WANDER:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_pick_new_wander_target()
			_process_movement(walk_speed, delta)

		NPCState.MOVE_TO:
			_process_movement(walk_speed, delta)
			if global_position.distance_to(target_position) <= 10.0:
				velocity = Vector2.ZERO
				destination_reached.emit()
				change_state(NPCState.IDLE)

		NPCState.FLEE:
			_process_movement(run_speed, delta)
			if global_position.distance_to(target_position) <= 15.0:
				velocity = Vector2.ZERO
				change_state(NPCState.IDLE)

		NPCState.EVENT:
			# Movimentação ou comportamento delegado a script de evento externo
			pass

	move_and_slide()
	_update_facing_direction()


## Movimentação com uso seguro de NavigationAgent2D ou vetor direto
func _process_movement(speed: float, _delta: float) -> void:
	var dest: Vector2 = target_position
	if follow_target != null and is_instance_valid(follow_target):
		dest = follow_target.global_position

	var move_dir: Vector2 = Vector2.ZERO

	if nav_agent != null and is_inside_tree() and _pathfind_cooldown <= 0.0:
		nav_agent.target_position = dest
		_pathfind_cooldown = PATHFIND_MIN_INTERVAL
		var next_path_pos: Vector2 = nav_agent.get_next_path_position()
		move_dir = (next_path_pos - global_position).normalized()
	else:
		move_dir = (dest - global_position).normalized()

	if global_position.distance_to(dest) > 8.0:
		velocity = move_dir * speed
	else:
		velocity = Vector2.ZERO


func _update_facing_direction() -> void:
	if absf(velocity.x) > 5.0:
		facing_direction = 1.0 if velocity.x > 0.0 else -1.0
		if visual_root != null:
			visual_root.scale.x = absf(visual_root.scale.x) * facing_direction


## Transição limpa de máquina de estados
func change_state(new_state: NPCState) -> void:
	current_state = new_state
	_state_timer = 0.0

	match current_state:
		NPCState.IDLE:
			velocity = Vector2.ZERO
		NPCState.WANDER:
			_pick_new_wander_target()
		NPCState.FLEE:
			is_fleeing = true
			npc_fled.emit()
		NPCState.DISABLED:
			velocity = Vector2.ZERO

	state_changed.emit(current_state)


## Escolhe ponto aleatório no raio de perambulação
func _pick_new_wander_target() -> void:
	_state_timer = wander_interval
	var angle: float = randf() * TAU
	var dist: float = randf_range(20.0, wander_radius)
	target_position = home_position + Vector2(cos(angle), sin(angle) * 0.5) * dist


## Comandos de Alto Nível para Scripts de Fase e Eventos
func move_to(target_pos: Vector2) -> void:
	target_position = target_pos
	change_state(NPCState.MOVE_TO)


func wait(duration: float) -> void:
	change_state(NPCState.WAIT)
	_state_timer = duration


func wander() -> void:
	change_state(NPCState.WANDER)


func stop() -> void:
	velocity = Vector2.ZERO
	change_state(NPCState.IDLE)


func follow(target_node: Node2D) -> void:
	follow_target = target_node
	change_state(NPCState.MOVE_TO)


func flee_from(threat_position: Vector2) -> void:
	var flee_dir: Vector2 = (global_position - threat_position).normalized()
	if flee_dir == Vector2.ZERO:
		flee_dir = Vector2.RIGHT
	target_position = global_position + flee_dir * flee_distance
	change_state(NPCState.FLEE)


func flee() -> void:
	flee_from(global_position + Vector2(-100, 0))


func enter_event() -> void:
	velocity = Vector2.ZERO
	change_state(NPCState.EVENT)


func disable_npc() -> void:
	change_state(NPCState.DISABLED)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)


func enable_npc() -> void:
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", is_damageable)
	change_state(NPCState.IDLE)


func is_moving() -> bool:
	return velocity.length_squared() > 10.0


func get_current_state() -> NPCState:
	return current_state


## Recebimento de Dano (Damage Contract)
func take_damage(damage_input: Variant) -> bool:
	if not is_damageable or current_state == NPCState.DISABLED:
		return false

	if health_component != null:
		return health_component.take_damage(damage_input)

	var amount: float = 0.0
	if damage_input is float or damage_input is int:
		amount = float(damage_input)
	elif damage_input != null and damage_input.get("amount") != null:
		amount = float(damage_input.get("amount"))

	if amount <= 0.0:
		return false

	current_health = maxf(0.0, current_health - amount)
	npc_damaged.emit(amount, current_health)
	flee()
	return true


func _on_health_component_damaged(amount: float) -> void:
	if health_component != null:
		current_health = health_component.get("current_health")
	npc_damaged.emit(amount, current_health)
	flee()


func _on_health_component_died() -> void:
	flee()
