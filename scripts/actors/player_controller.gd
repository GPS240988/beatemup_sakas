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

## Parâmetros físicos do salto 2.5D
@export var jump_force: float = 460.0
@export var jump_gravity: float = 1350.0

## Referências internas
@onready var visual_root: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var melee_attack: MeleeAttack = $MeleeAttack
@onready var punch_visual: Node2D = $Visual/PunchVisual

var facing_direction: float = 1.0
var _hurt_timer: float = 0.0

# Controle do sistema de combos (punch -> kick -> heavy)
var _combo_step: int = 0
var _combo_window_timer: float = 0.0
var _current_attack_anim: StringName = &"punch"

# Controle do salto vertical 2.5D (Visual se projeta para cima, mantendo os pés na colisão de solo)
var _is_jumping: bool = false
var _jump_v_velocity: float = 0.0

# Controle de guarda
var _is_guarding: bool = false


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

	_apply_character_stat_modifiers()


## Aplica os modificadores de Força, Velocidade e Técnica da sessão
func _apply_character_stat_modifiers() -> void:
	var session = get_node_or_null("/root/GameSession")
	var char_id: String = "guilherme"
	if session != null and "selected_character_id" in session:
		char_id = session.selected_character_id

	var str_mult: float = 1.0
	var spd_mult: float = 1.0
	var tec_mult: float = 1.0

	if session != null and session.has_method("get_strength_multiplier"):
		str_mult = session.get_strength_multiplier(char_id)
		spd_mult = session.get_speed_multiplier(char_id)
		tec_mult = session.get_technique_multiplier(char_id)

	# Aplica modificadores de velocidade de locomoção
	speed_x *= spd_mult
	speed_y *= spd_mult

	# Aplica modificadores de combate
	if melee_attack != null:
		melee_attack.damage *= str_mult
		melee_attack.depth_tolerance *= tec_mult
		if tec_mult > 0.0:
			melee_attack.attack_cooldown /= tec_mult


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

	# Decrementa a janela de encadeamento de combo
	if _combo_window_timer > 0.0:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0 and (melee_attack == null or not melee_attack.is_attacking):
			_combo_step = 0

	# Processa física de salto 2.5D no nó Visual
	if _is_jumping:
		_jump_v_velocity += jump_gravity * delta
		if visual_root != null:
			visual_root.position.y += _jump_v_velocity * delta
			if visual_root.position.y >= 0.0:
				visual_root.position.y = 0.0
				_is_jumping = false
				_jump_v_velocity = 0.0
				if melee_attack != null and not melee_attack.is_attacking:
					_update_animation("idle")

	# Leitura de comando de Guarda (apenas no chão e fora de ataque)
	if not _is_jumping and (melee_attack == null or not melee_attack.is_attacking):
		if Input.is_action_pressed("guard"):
			_is_guarding = true
			velocity = Vector2.ZERO
			_update_animation("guard")
			move_and_slide()
			if enable_manual_bounds:
				_clamp_to_bounds()
			player_moved.emit(global_position, velocity)
			return
		else:
			_is_guarding = false

	# Leitura de comando de Salto
	if Input.is_action_just_pressed("jump") and not _is_jumping and (melee_attack == null or not melee_attack.is_attacking):
		_start_jump()

	# Comando de ataque (ataque aéreo ou combo no solo)
	if Input.is_action_just_pressed("attack"):
		_try_attack()

	# Se estiver executando o ataque no solo, mantém os pés firmes no solo e não sobrescreve a animação
	if melee_attack != null and melee_attack.is_attacking and not _is_jumping:
		velocity = Vector2.ZERO
		move_and_slide()
		if enable_manual_bounds:
			_clamp_to_bounds()
		player_moved.emit(global_position, velocity)
		return

	# Leitura do movimento dos eixos
	var input_vector: Vector2 = _get_movement_input()
	
	if input_vector != Vector2.ZERO:
		velocity.x = input_vector.x * speed_x
		velocity.y = input_vector.y * speed_y
		_update_facing_direction(input_vector.x)
		if not _is_jumping and (melee_attack == null or not melee_attack.is_attacking) and _hurt_timer <= 0.0:
			_update_animation("walk")
	else:
		velocity = Vector2.ZERO
		if not _is_jumping and (melee_attack == null or not melee_attack.is_attacking) and _hurt_timer <= 0.0:
			_update_animation("idle")

	move_and_slide()

	if enable_manual_bounds:
		_clamp_to_bounds()

	player_moved.emit(global_position, velocity)


## Inicia o salto 2.5D
func _start_jump() -> void:
	_is_jumping = true
	_jump_v_velocity = -jump_force
	_update_animation("jump")
	state_changed.emit("Pulando")


## Tenta desferir um golpe na direção atual (suporta combo no solo e voadora aérea)
func _try_attack() -> void:
	if melee_attack == null:
		return

	if _is_jumping:
		# Ataque aéreo (voadora / jump kick)
		var aerial_started: bool = melee_attack.execute_attack(facing_direction)
		if aerial_started:
			_current_attack_anim = &"jump_atk"
			if anim_sprite != null:
				anim_sprite.play("jump_atk")
			state_changed.emit("Ataque Aéreo")
		return

	# Ataque no solo: combo encadeado de 3 fases (Soco -> Chute -> Ataque Pesado)
	var chosen_anim: StringName = &"punch"
	if _combo_step == 0:
		chosen_anim = &"punch"
	elif _combo_step == 1:
		chosen_anim = &"kick"
	else:
		chosen_anim = &"heavy"

	_current_attack_anim = chosen_anim
	var started: bool = melee_attack.execute_attack(facing_direction)
	if started:
		state_changed.emit("Atacando (%s)" % chosen_anim)
		_combo_step = (_combo_step + 1) % 3
		_combo_window_timer = 0.55


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
	if anim_sprite != null:
		anim_sprite.play(_current_attack_anim)
		anim_sprite.frame = 0
	if punch_visual != null:
		punch_visual.visible = false


## Feedback visual quando o ataque termina
func _on_attack_ended() -> void:
	if punch_visual != null:
		punch_visual.visible = false
	if health_component != null and not health_component.is_dead:
		state_changed.emit("Normal")
		if anim_sprite != null and (anim_sprite.animation in [&"punch", &"kick", &"heavy"]):
			if not _is_jumping and not _is_guarding:
				anim_sprite.play("idle")


## Feedback visual de dano sofrido
func _on_damaged(_amount: float) -> void:
	_hurt_timer = 0.22
	if visual_root != null:
		visual_root.modulate = Color(2.0, 0.4, 0.4, 1.0)
	if anim_sprite != null and not (health_component != null and health_component.is_dead):
		anim_sprite.play("hurt")
		anim_sprite.frame = 0
	state_changed.emit("Sofreu Dano")


## Restaura as cores normais após o efeito de dano
func _restore_visual_modulation() -> void:
	if visual_root != null and (health_component == null or not health_component.is_dead):
		visual_root.modulate = Color.WHITE
		state_changed.emit("Normal")
		if anim_sprite != null and anim_sprite.animation == &"hurt":
			anim_sprite.play("idle")


## Reação ao estado de derrota
func _on_died() -> void:
	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false
	if visual_root != null:
		visual_root.rotation_degrees = 0.0
		visual_root.position.y = 0.0
		visual_root.modulate = Color(0.85, 0.85, 0.9, 0.9)
	if anim_sprite != null:
		anim_sprite.play("death")
	state_changed.emit("Derrotado")


## Fallback defensivo para mapeamento de teclas
func _ensure_fallback_inputs() -> void:
	_register_key_if_missing("move_left", KEY_A, KEY_LEFT)
	_register_key_if_missing("move_right", KEY_D, KEY_RIGHT)
	_register_key_if_missing("move_up", KEY_W, KEY_UP)
	_register_key_if_missing("move_down", KEY_S, KEY_DOWN)
	_register_key_if_missing("attack", KEY_J, KEY_Z)
	_register_key_if_missing("jump", KEY_K, KEY_SPACE)
	_register_key_if_missing("guard", KEY_L, KEY_SHIFT)
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
