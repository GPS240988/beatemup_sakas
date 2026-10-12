class_name PlayerController
extends CharacterBody2D

## Sinal emitido quando a posição ou movimento do jogador é atualizado (útil para HUD/depuração)
signal player_moved(current_position: Vector2, current_velocity: Vector2)

## Sinal emitido quando o estado visual/ação do jogador muda
signal state_changed(new_state: String)

## Velocidade base de deslocamento horizontal (pixels por segundo)
@export var speed_x: float = 260.0

## Velocidade de deslocamento vertical (em profundidade)
@export var speed_y: float = 190.0

## Limites manuais opcionais da área caminhável
@export var enable_manual_bounds: bool = false
@export var walkable_bounds: Rect2 = Rect2(Vector2(60, 360), Vector2(1160, 260))

## Referências internas
@onready var visual_root: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var melee_attack: MeleeAttack = $MeleeAttack
@onready var punch_visual: Node2D = $Visual/PunchVisual

var facing_direction: float = 1.0
var _hurt_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	_ensure_fallback_inputs()

	if health_component != null:
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)

	if melee_attack != null:
		melee_attack.attack_started.connect(_on_attack_started)
		melee_attack.attack_ended.connect(_on_attack_ended)

	if punch_visual != null:
		punch_visual.visible = false

	if anim_sprite != null:
		anim_sprite.play("idle")


func _physics_process(delta: float) -> void:
	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			_restore_visual_modulation()

	# Se estiver derrotado, não processa comandos nem se move
	if health_component != null and health_component.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		player_moved.emit(global_position, velocity)
		return

	# Comando de ataque
	if Input.is_action_just_pressed("attack"):
		_try_attack()

	# Leitura do movimento dos eixos
	var input_vector: Vector2 = _get_movement_input()
	
	if input_vector != Vector2.ZERO:
		velocity.x = input_vector.x * speed_x
		velocity.y = input_vector.y * speed_y
		_update_facing_direction(input_vector.x)
		_update_animation("walk")
	else:
		velocity = Vector2.ZERO
		_update_animation("idle")

	move_and_slide()

	if enable_manual_bounds:
		_clamp_to_bounds()

	player_moved.emit(global_position, velocity)


## Tenta desferir um golpe na direção atual
func _try_attack() -> void:
	if melee_attack == null:
		return
	var started: bool = melee_attack.execute_attack(facing_direction)
	if started:
		state_changed.emit("Atacando")


## Lê e normaliza o vetor de entrada analógico ou digital dos eixos X e Y
func _get_movement_input() -> Vector2:
	var raw_x: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var raw_y: float = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var raw_direction: Vector2 = Vector2(raw_x, raw_y)

	if raw_direction.length_squared() > 1.0:
		return raw_direction.normalized()
	return raw_direction


## Atualiza o lado para o qual o personagem está virado
func _update_facing_direction(horizontal_input: float) -> void:
	if horizontal_input > 0.05:
		facing_direction = 1.0
	elif horizontal_input < -0.05:
		facing_direction = -1.0

	if visual_root != null:
		visual_root.scale.x = facing_direction


## Alterna as animações de sprite conforme o estado de movimento
func _update_animation(anim_name: StringName) -> void:
	if anim_sprite == null:
		return
	if anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)


## Garante que o jogador não ultrapasse a área delimitada manualmente
func _clamp_to_bounds() -> void:
	global_position.x = clampf(global_position.x, walkable_bounds.position.x, walkable_bounds.position.x + walkable_bounds.size.x)
	global_position.y = clampf(global_position.y, walkable_bounds.position.y, walkable_bounds.position.y + walkable_bounds.size.y)


## Feedback visual quando o ataque inicia
func _on_attack_started() -> void:
	if punch_visual != null:
		punch_visual.visible = true


## Feedback visual quando o ataque termina
func _on_attack_ended() -> void:
	if punch_visual != null:
		punch_visual.visible = false
	if health_component != null and not health_component.is_dead:
		state_changed.emit("Normal")


## Feedback visual de dano sofrido
func _on_damaged(_amount: float) -> void:
	_hurt_timer = 0.18
	if visual_root != null:
		visual_root.modulate = Color(2.0, 0.4, 0.4, 1.0)
	state_changed.emit("Sofreu Dano")


## Restaura as cores normais após o efeito de dano
func _restore_visual_modulation() -> void:
	if visual_root != null and (health_component == null or not health_component.is_dead):
		visual_root.modulate = Color.WHITE
		state_changed.emit("Normal")


## Reação ao estado de derrota
func _on_died() -> void:
	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false
	if anim_sprite != null:
		anim_sprite.stop()
	if visual_root != null:
		visual_root.rotation_degrees = 90.0
		visual_root.position.y = -10.0
		visual_root.modulate = Color(0.5, 0.5, 0.5, 0.8)
	state_changed.emit("Derrotado")


## Fallback defensivo para mapeamento de teclas
func _ensure_fallback_inputs() -> void:
	_register_key_if_missing("move_left", KEY_A, KEY_LEFT)
	_register_key_if_missing("move_right", KEY_D, KEY_RIGHT)
	_register_key_if_missing("move_up", KEY_W, KEY_UP)
	_register_key_if_missing("move_down", KEY_S, KEY_DOWN)
	_register_key_if_missing("attack", KEY_J, KEY_SPACE)
	_register_key_if_missing("restart", KEY_R, KEY_NONE)


func _register_key_if_missing(action_name: StringName, primary_key: Key, secondary_key: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		if primary_key != KEY_NONE:
			var event1 := InputEventKey.new()
			event1.physical_keycode = primary_key
			InputMap.action_add_event(action_name, event1)
		if secondary_key != KEY_NONE:
			var event2 := InputEventKey.new()
			event2.physical_keycode = secondary_key
			InputMap.action_add_event(action_name, event2)
