class_name PlayerController
extends CharacterBody2D

## Controlador Oficial do Jogador Arcade Beat 'em Up 2.5D (Projeto Sakas)
## Gerencia locomoção 2.5D, sistema de combo com um único botão, buffer de entrada,
## reações físicas de impacto (Hurt, Knockback, Fall, Downed, Getup), guarda e
## Golpe Especial global cinematográfico.

## Sinal emitido quando a posição ou movimento do jogador é atualizado (útil para HUD/depuração)
signal player_moved(current_position: Vector2, current_velocity: Vector2)

## Sinal emitido quando o estado visual/ação do jogador muda
signal state_changed(new_state: String)

## Sinal emitido quando a contagem de acertos em combo é atualizada
signal combo_changed(hits: int)

## Sinal emitido quando a barra de golpe especial é atualizada
signal special_changed(current: float, max_special: float)

## Sinal emitido quando o jogador gasta uma ficha e renasce (Drop-in Continue Arcade)
signal player_respawned(continues_left: int)

## Estados de combate do herói
enum CombatState {
	NORMAL,
	ATTACKING,
	HURT,
	FALL,
	DOWNED,
	GETUP,
	SPECIAL,
	DEAD
}

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

const AttackDataClass = preload("res://scripts/combat/attack_data.gd")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")
const SpecialPresentationClass = preload("res://scripts/combat/special_presentation.gd")

## Referências internas
@onready var visual_root: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var melee_attack: MeleeAttack = $MeleeAttack
@onready var punch_visual: Node2D = $Visual/PunchVisual

var facing_direction: float = 1.0
var combat_state: CombatState = CombatState.NORMAL

var _hurt_timer: float = 0.0
var _state_timer: float = 0.0
var _hitstop_timer: float = 0.0
var _is_invulnerable: bool = false
var _input_buffered: bool = false

# Controle do sistema de combos com botão único (Combo 1 -> Combo 2 -> Combo 3 -> Finisher)
var _combo_step: int = 0
var _combo_window_timer: float = 0.0
var _current_attack_anim: StringName = &"punch"
var _combo_attacks: Array[Resource] = []

# Controle do salto vertical 2.5D (Visual se projeta para cima, mantendo os pés na colisão de solo)
var _is_jumping: bool = false
var _jump_v_velocity: float = 0.0

# Controle de guarda
var _is_guarding: bool = false

# Configuração oficial do golpe especial e balanceamento arcade
const SPECIAL_MAX_CHARGE: float = 100.0
const SPECIAL_INITIAL_CHARGE: float = 0.0
const SPECIAL_CHARGE_PER_HIT: float = 2.0

# Sistema de combos e medidor de golpe especial da HUD
var combo_hits: int = 0
var current_special: float = SPECIAL_INITIAL_CHARGE
var max_special: float = SPECIAL_MAX_CHARGE

# Sistema de Continues Arcade (padrão 1 ficha inicial)
var current_continues: int = 1
var _respawn_tween: Tween = null

# Modificadores de atributos
var _str_mult: float = 1.0
var _spd_mult: float = 1.0
var _tec_mult: float = 1.0


func _ready() -> void:
	add_to_group("actors")
	add_to_group("player")
	add_to_group("damageable")
	_ensure_fallback_inputs()

	var session = get_node_or_null("/root/GameSession")
	if session != null and "current_continues" in session:
		current_continues = int(session.current_continues)

	if health_component != null:
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)

	if melee_attack != null:
		melee_attack.attack_started.connect(_on_attack_started)
		melee_attack.attack_ended.connect(_on_attack_ended)
		if not melee_attack.target_hit.is_connected(_on_melee_target_hit):
			melee_attack.target_hit.connect(_on_melee_target_hit)

	if punch_visual != null:
		punch_visual.visible = false

	if anim_sprite != null:
		anim_sprite.play("idle")

	_apply_character_stat_modifiers()
	_build_combo_chain()


## Aplica os modificadores de Força, Velocidade e Técnica da sessão
func _apply_character_stat_modifiers() -> void:
	var session = get_node_or_null("/root/GameSession")
	var char_id: String = "guilherme"
	if session != null and "selected_character_id" in session:
		char_id = session.selected_character_id

	_str_mult = 1.0
	_spd_mult = 1.0
	_tec_mult = 1.0

	if session != null and session.has_method("get_strength_multiplier"):
		_str_mult = session.get_strength_multiplier(char_id)
		_spd_mult = session.get_speed_multiplier(char_id)
		_tec_mult = session.get_technique_multiplier(char_id)

	# Aplica modificadores de velocidade de locomoção
	speed_x *= _spd_mult
	speed_y *= _spd_mult

	# Aplica modificadores de combate
	if melee_attack != null:
		melee_attack.damage *= _str_mult
		melee_attack.depth_tolerance *= _tec_mult
		if _tec_mult > 0.0:
			melee_attack.attack_cooldown /= _tec_mult


## Monta a sequência contextual de 4 ataques do combo principal
func _build_combo_chain() -> void:
	_combo_attacks.clear()

	# 1. Combo 1: Jab Rápido (Soco)
	var atk1: Resource = AttackDataClass.new()
	atk1.set("attack_id", "punch_1")
	atk1.set("animation", &"punch")
	atk1.set("startup", 0.04)
	atk1.set("active", 0.12)
	atk1.set("recovery", 0.22 / maxf(0.1, _tec_mult))
	atk1.set("damage", 20.0 * _str_mult)
	atk1.set("horizontal_range", 85.0)
	atk1.set("depth_tolerance", 26.0 * _tec_mult)
	atk1.set("hitstun", 0.22)
	atk1.set("knockback", 40.0)
	atk1.set("hitstop_frames", 3)
	atk1.set("combo_index", 0)
	atk1.set("combo_window", 0.42 * _tec_mult)
	atk1.set("can_knockdown", false)
	atk1.set("impact_profile", "punch")
	_combo_attacks.append(atk1)

	# 2. Combo 2: Cruzado / Segundo Soco (Punch 2)
	var atk2: Resource = AttackDataClass.new()
	atk2.set("attack_id", "punch_2")
	atk2.set("animation", &"punch")
	atk2.set("startup", 0.04)
	atk2.set("active", 0.12)
	atk2.set("recovery", 0.22 / maxf(0.1, _tec_mult))
	atk2.set("damage", 25.0 * _str_mult)
	atk2.set("horizontal_range", 90.0)
	atk2.set("depth_tolerance", 26.0 * _tec_mult)
	atk2.set("hitstun", 0.25)
	atk2.set("knockback", 55.0)
	atk2.set("hitstop_frames", 3)
	atk2.set("combo_index", 1)
	atk2.set("combo_window", 0.45 * _tec_mult)
	atk2.set("can_knockdown", false)
	atk2.set("impact_profile", "punch")
	_combo_attacks.append(atk2)

	# 3. Combo 3: Chute no Tronco (Kick)
	var atk3: Resource = AttackDataClass.new()
	atk3.set("attack_id", "kick_3")
	atk3.set("animation", &"kick")
	atk3.set("startup", 0.05)
	atk3.set("active", 0.15)
	atk3.set("recovery", 0.25 / maxf(0.1, _tec_mult))
	atk3.set("damage", 32.0 * _str_mult)
	atk3.set("horizontal_range", 105.0)
	atk3.set("depth_tolerance", 28.0 * _tec_mult)
	atk3.set("hitstun", 0.30)
	atk3.set("knockback", 85.0)
	atk3.set("hitstop_frames", 4)
	atk3.set("combo_index", 2)
	atk3.set("combo_window", 0.48 * _tec_mult)
	atk3.set("can_knockdown", false)
	atk3.set("impact_profile", "kick")
	_combo_attacks.append(atk3)

	# 4. Combo 4: Finisher / Gancho Pesado (Heavy - Causa Knockdown!)
	var atk4: Resource = AttackDataClass.new()
	atk4.set("attack_id", "finisher_4")
	atk4.set("animation", &"heavy")
	atk4.set("startup", 0.08)
	atk4.set("active", 0.20)
	atk4.set("recovery", 0.38 / maxf(0.1, _tec_mult))
	atk4.set("damage", 48.0 * _str_mult)
	atk4.set("horizontal_range", 115.0)
	atk4.set("depth_tolerance", 30.0 * _tec_mult)
	atk4.set("hitstun", 0.40)
	atk4.set("knockback", 160.0)
	atk4.set("hitstop_frames", 6)
	atk4.set("combo_index", 3)
	atk4.set("combo_window", 0.0)
	atk4.set("can_knockdown", true)
	atk4.set("impact_profile", "finisher")
	_combo_attacks.append(atk4)


## Aplica hitstop local controlado no herói
func apply_hitstop(duration: float) -> void:
	_hitstop_timer = maxf(_hitstop_timer, duration)


func _physics_process(delta: float) -> void:
	# Hitstop do herói: pausa temporária de física sem pausar a árvore
	if _hitstop_timer > 0.0:
		_hitstop_timer -= delta
		return

	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0 and combat_state == CombatState.NORMAL:
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
			if combo_hits > 0:
				combo_hits = 0
				combo_changed.emit(0)

	# Processa reações físicas de impacto no jogador
	match combat_state:
		CombatState.FALL:
			velocity = velocity.move_toward(Vector2.ZERO, 380.0 * delta)
			_state_timer -= delta
			move_and_slide()
			if _state_timer <= 0.0:
				combat_state = CombatState.DOWNED
				_state_timer = 0.32
				velocity = Vector2.ZERO
			player_moved.emit(global_position, velocity)
			return

		CombatState.DOWNED:
			velocity = Vector2.ZERO
			_state_timer -= delta
			move_and_slide()
			if _state_timer <= 0.0:
				combat_state = CombatState.GETUP
				_state_timer = 0.28
				if anim_sprite != null and anim_sprite.sprite_frames.has_animation("getup"):
					anim_sprite.play("getup")
			player_moved.emit(global_position, velocity)
			return

		CombatState.GETUP:
			velocity = Vector2.ZERO
			_state_timer -= delta
			move_and_slide()
			if _state_timer <= 0.0:
				combat_state = CombatState.NORMAL
				_restore_visual_modulation()
				if anim_sprite != null:
					anim_sprite.play("idle")
			player_moved.emit(global_position, velocity)
			return

		CombatState.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, 350.0 * delta)
			_state_timer -= delta
			move_and_slide()
			if _state_timer <= 0.0:
				combat_state = CombatState.NORMAL
				_restore_visual_modulation()
				if anim_sprite != null:
					anim_sprite.play("idle")
			player_moved.emit(global_position, velocity)
			return

		CombatState.SPECIAL:
			velocity = Vector2.ZERO
			move_and_slide()
			player_moved.emit(global_position, velocity)
			return

		_:
			pass

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

	# Leitura de comando de Guarda (fora de ataque e fora de salto aéreo)
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

	# Leitura de comandos de ataque
	if not _is_guarding:
		# Botão Especial Exclusivo
		if Input.is_action_just_pressed("attack_special") or Input.is_action_just_pressed("special"):
			execute_special()
			return

		# Botão Principal de Ataque (Combo Contextual / Encadeável)
		if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("attack_punch") or Input.is_action_just_pressed("ui_accept"):
			_on_attack_button_pressed()
		elif Input.is_action_just_pressed("attack_kick"):
			execute_kick()
		elif Input.is_action_just_pressed("attack_aerial"):
			execute_aerial()
		elif Input.is_action_just_pressed("jump"):
			_try_jump()

	# Se estiver executando ataque no solo, mantém os pés firmes no solo
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


## Processa o pressionamento do botão principal de ataque com suporte a combo e buffer
func _on_attack_button_pressed() -> void:
	if combat_state in [CombatState.FALL, CombatState.DOWNED, CombatState.GETUP, CombatState.SPECIAL, CombatState.DEAD]:
		return

	if melee_attack != null and melee_attack.is_attacking:
		# Se a janela de acerto ativa ainda estiver em curso, armazena no buffer
		if melee_attack.is_active_window:
			_input_buffered = true
			return
		else:
			# Na janela de recuperação: cancela e encadeia o próximo golpe imediatamente
			melee_attack.cancel_attack()

	# Avança no combo se estiver dentro da janela
	if _combo_window_timer > 0.0 and _combo_attacks.size() > 0:
		_combo_step = (_combo_step + 1) % _combo_attacks.size()
	else:
		_combo_step = 0

	_execute_combo_attack(_combo_step)



## Executa o ataque indexado do combo
func _execute_combo_attack(step: int) -> bool:
	if melee_attack == null or _combo_attacks.is_empty():
		return false

	if step < 0 or step >= _combo_attacks.size():
		step = 0
	_combo_step = step

	var atk: Resource = _combo_attacks[_combo_step]
	_current_attack_anim = atk.get("animation")
	melee_attack.apply_attack_data(atk)

	if melee_attack.execute_attack(facing_direction):
		combat_state = CombatState.ATTACKING
		var titles: Array[String] = ["Soco", "Cruzado", "Chute", "Finisher"]
		state_changed.emit(titles[_combo_step] if _combo_step < titles.size() else "Ataque")
		return true
	return false


## Disparo do Golpe Especial de Área (Cinematográfico, Global, Consome 100% do medidor de Especial)
func execute_special() -> bool:
	if health_component == null or health_component.is_dead:
		return false
	if combat_state in [CombatState.FALL, CombatState.DOWNED, CombatState.GETUP, CombatState.SPECIAL, CombatState.DEAD]:
		return false

	# Validação estrita: O jogador só pode executar o especial quando o medidor estiver 100% carregado
	if current_special < max_special:
		return false

	# Consome a carga completa uma única vez (substitui o custo antigo de 15% de vida)
	current_special = 0.0
	special_changed.emit(current_special, max_special)

	combat_state = CombatState.SPECIAL
	_is_invulnerable = true
	velocity = Vector2.ZERO

	if melee_attack != null:
		melee_attack.cancel_attack()
	_input_buffered = false

	# Identificação do herói atual para apresentação
	var session = get_node_or_null("/root/GameSession")
	var char_id: String = "guilherme"
	if session != null and "selected_character_id" in session:
		char_id = str(session.selected_character_id).to_lower()

	# Extrai textura existente do herói
	var hero_tex: Texture2D = null
	if anim_sprite != null and anim_sprite.sprite_frames != null:
		if anim_sprite.sprite_frames.has_animation("heavy"):
			hero_tex = anim_sprite.sprite_frames.get_frame_texture("heavy", 0)
		elif anim_sprite.sprite_frames.has_animation("punch"):
			hero_tex = anim_sprite.sprite_frames.get_frame_texture("punch", 0)

	var presentation := SpecialPresentationClass.new(char_id, hero_tex)
	var scene_root := get_tree().root
	if scene_root != null:
		scene_root.add_child(presentation)

	presentation.impact_reached.connect(func():
		_apply_global_special_impact()
	)

	presentation.finished.connect(func():
		_is_invulnerable = false
		if combat_state == CombatState.SPECIAL:
			combat_state = CombatState.NORMAL
		if anim_sprite != null and not health_component.is_dead:
			anim_sprite.play("idle")
		state_changed.emit("Normal")
	)

	state_changed.emit("Golpe Especial")
	return true


## Aplica o dano global e queda em todos os inimigos válidos do encontro
func _apply_global_special_impact() -> void:
	CombatFeedbackClass.trigger_screen_shake(self, 14.0, 0.4)

	var tree := get_tree()
	if tree == null:
		return

	var all_enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	for enemy_node in all_enemies:
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if enemy_node == self or enemy_node.is_in_group("npcs") or enemy_node.is_in_group("player"):
			continue

		var enemy_health := _find_health_component(enemy_node)
		if enemy_health != null and enemy_health.is_dead:
			continue

		var enemy_node2d := enemy_node as Node2D
		var enemy_pos := enemy_node2d.global_position if enemy_node2d != null else global_position
		var hit_dir_x: float = signf(enemy_pos.x - global_position.x)
		if hit_dir_x == 0.0:
			hit_dir_x = facing_direction

		var spec_info := DamageInfoClass.new(
			60.0 * _str_mult,
			self,
			global_position,
			Vector2(hit_dir_x, 0.0),
			"special",
			180.0,
			0.50,
			true,
			true, # can_knockdown = true!
			0.08,
			"special"
		)

		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage(spec_info)
		elif enemy_health != null:
			enemy_health.take_damage(spec_info)

		CombatFeedbackClass.spawn_hit_spark(self, enemy_pos + Vector2(0, -40), Vector2(hit_dir_x, 0), "special")

	# Props destrutíveis no cenário também sofrem o impacto do Especial
	var all_props: Array[Node] = tree.get_nodes_in_group("destructibles")
	for prop in all_props:
		if prop != null and is_instance_valid(prop) and prop.has_method("take_damage"):
			var prop_info := DamageInfoClass.new(50.0 * _str_mult, self, global_position, Vector2(facing_direction, 0), "special", 50.0, 0.2, true)
			prop.take_damage(prop_info)


## Executa o pulo padrão do herói
func _try_jump() -> void:
	if _is_jumping or (melee_attack != null and melee_attack.is_attacking):
		return
	_is_jumping = true
	_jump_v_velocity = -jump_force
	_update_animation("jump")


## Executa o Ataque Aéreo (voadora em salto frontal)
func _try_aerial_attack() -> void:
	if melee_attack == null:
		return
	_is_jumping = true
	_jump_v_velocity = -340.0
	_current_attack_anim = &"jump_atk"
	melee_attack.damage = 35.0 * _str_mult
	melee_attack.horizontal_range = 110.0
	melee_attack.active_duration = 0.22
	melee_attack.attack_cooldown = 0.45 / maxf(0.1, _tec_mult)
	velocity.x = facing_direction * 240.0
	if melee_attack.execute_attack(facing_direction):
		if anim_sprite != null:
			anim_sprite.play("jump_atk")
		state_changed.emit("Ataque Aéreo")


## Desfere o golpe rápido de Soco
func _try_punch() -> void:
	_execute_combo_attack(0)


## Desfere o golpe de Chute
func _try_kick() -> void:
	_execute_combo_attack(2)


## Desfere o Golpe Especial / Pesado
func _try_special() -> void:
	_execute_combo_attack(3)


## Métodos públicos desacoplados para acionamento de ataques
func execute_punch() -> void:
	_try_punch()


func execute_kick() -> void:
	_try_kick()


func execute_heavy() -> void:
	_try_special()


func execute_aerial() -> void:
	_try_aerial_attack()


func _try_attack() -> void:
	_on_attack_button_pressed()


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


## Feedback visual e encadeamento de buffer quando o ataque termina
func _on_attack_ended() -> void:
	if punch_visual != null:
		punch_visual.visible = false
	if health_component != null and health_component.is_dead:
		return

	# Se houver input bufferizado na janela, encadeia o próximo golpe imediatamente
	if _input_buffered:
		_input_buffered = false
		if _combo_attacks.size() > 0:
			if melee_attack != null:
				melee_attack.cancel_attack()
			_combo_step = (_combo_step + 1) % _combo_attacks.size()
			_execute_combo_attack(_combo_step)
			return


	if melee_attack != null:
		melee_attack.is_attacking = false

	combat_state = CombatState.NORMAL
	state_changed.emit("Normal")

	if _combo_step < _combo_attacks.size():
		_combo_window_timer = float(_combo_attacks[_combo_step].get("combo_window"))
	else:
		_combo_window_timer = 0.0

	if anim_sprite != null and (anim_sprite.animation in [&"punch", &"kick", &"heavy"]):
		if not _is_jumping and not _is_guarding:
			anim_sprite.play("idle")


## Processa acertos de golpe: incrementa combo e carrega a barra de Special
func _on_melee_target_hit(target: Node, _dmg: float) -> void:
	combo_hits += 1
	combo_changed.emit(combo_hits)

	# Proteções estritas do medidor de Golpe Especial:
	# 1. Não carrega durante o próprio Especial
	if combat_state == CombatState.SPECIAL:
		return

	# 2. Ignora alvos nulos ou inválidos
	if target == null or not is_instance_valid(target):
		return

	# 3. O próprio jogador não gera carga
	if target == self:
		return

	# 4. NPCs civis não geram carga
	if target.is_in_group("npcs") or target.is_in_group("civilians"):
		return

	# 5. Apenas inimigos vivos geram carga
	if not target.is_in_group("enemies"):
		return

	var health: Node = null
	if target.has_node("HealthComponent"):
		health = target.get_node("HealthComponent")
	elif "health_component" in target:
		health = target.health_component

	if health != null and "is_dead" in health and health.is_dead:
		return

	current_special = clampf(current_special + SPECIAL_CHARGE_PER_HIT, 0.0, max_special)
	special_changed.emit(current_special, max_special)


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
		if anim_sprite != null and anim_sprite.animation in [&"hurt", &"fall", &"getup"]:
			anim_sprite.play("idle")


## Reação ao estado de derrota ou ativação de Continue Arcade
func _on_died() -> void:
	if current_continues > 0:
		_trigger_arcade_respawn()
		return

	combat_state = CombatState.DEAD
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


## Dispara o respawn arcade dos céus consumindo 1 ficha
func _trigger_arcade_respawn() -> void:
	current_continues -= 1
	var session = get_node_or_null("/root/GameSession")
	if session != null and "current_continues" in session:
		session.current_continues = current_continues

	player_respawned.emit(current_continues)

	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false

	# Pausa movimento do solo e projeta o herói nos céus
	combat_state = CombatState.NORMAL
	velocity = Vector2.ZERO
	_is_invulnerable = true
	_is_jumping = false
	_jump_v_velocity = 0.0

	if visual_root != null:
		visual_root.rotation_degrees = 0.0
		visual_root.modulate = Color.WHITE
		visual_root.position.y = -500.0

	if anim_sprite != null:
		if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("fall"):
			anim_sprite.play("fall")
		elif anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("jump"):
			anim_sprite.play("jump")
		else:
			anim_sprite.play("idle")

	if _respawn_tween != null and _respawn_tween.is_valid():
		_respawn_tween.kill()

	_respawn_tween = create_tween()
	if visual_root != null:
		_respawn_tween.tween_property(visual_root, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_respawn_tween.tween_callback(_on_respawn_landing)


## Aterrissagem com tremor de terra, queda de todos os inimigos na tela e restauração de vida/especial
func _on_respawn_landing() -> void:
	if visual_root != null:
		visual_root.position.y = 0.0
		visual_root.rotation_degrees = 0.0
		visual_root.modulate = Color.WHITE

	# 1. Restaura vida por completo (100%)
	if health_component != null:
		health_component.reset()

	# 2. Define a energia especial pela metade (50% = 4 segmentos)
	current_special = max_special * 0.5
	special_changed.emit(current_special, max_special)

	# 3. Tremor de tela de impacto arcade
	CombatFeedbackClass.trigger_screen_shake(self, 12.0, 0.40)

	# 4. Derruba todos os inimigos vivos na tela (cooldown tático para o jogador se reorganizar)
	var tree: SceneTree = get_tree()
	if tree != null:
		var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
		for enemy in enemies:
			if enemy == null or not is_instance_valid(enemy):
				continue
			var e_health = _find_health_component(enemy)
			if e_health != null and e_health.is_dead:
				continue

			var shock_dir: float = signf(enemy.global_position.x - global_position.x)
			if shock_dir == 0.0:
				shock_dir = -facing_direction

			var shockwave_info = DamageInfoClass.new(
				0.0,
				self,
				global_position,
				Vector2(shock_dir, 0.0),
				"special",
				180.0,
				0.4,
				false,
				true,
				0.0,
				"special"
			)
			if enemy.has_method("_on_damaged_info"):
				enemy._on_damaged_info(shockwave_info)
			elif enemy.has_method("take_damage"):
				enemy.take_damage(shockwave_info)

	if anim_sprite != null:
		anim_sprite.play("idle")

	state_changed.emit("Normal")
	_apply_respawn_invulnerability(2.0)


## Concede 2 segundos de invulnerabilidade com piscar visual característico dos beat 'em ups
func _apply_respawn_invulnerability(duration: float) -> void:
	_is_invulnerable = true
	var blink_tween := create_tween()
	var steps: int = int(duration / 0.12)
	for i in range(steps):
		var alpha: float = 0.35 if (i % 2 == 0) else 1.0
		if visual_root != null:
			blink_tween.tween_property(visual_root, "modulate:a", alpha, 0.06)
	if visual_root != null:
		blink_tween.tween_property(visual_root, "modulate", Color.WHITE, 0.05)
	blink_tween.tween_callback(func(): _is_invulnerable = false)


## Ponto de entrada canônico para recebimento de dano (Damage Contract)
func take_damage(damage_input: Variant) -> bool:
	if health_component == null or health_component.is_dead:
		return false
	if _is_invulnerable or combat_state == CombatState.SPECIAL:
		return false

	var amount: float = 0.0
	var can_kd: bool = false
	var knockback: float = 80.0
	var hit_dir: Vector2 = Vector2(-facing_direction, 0.0)

	if damage_input is float or damage_input is int:
		amount = float(damage_input)
	elif damage_input != null:
		amount = float(damage_input.get("amount"))
		can_kd = bool(damage_input.get("can_knockdown"))
		knockback = float(damage_input.get("knockback_force"))
		if damage_input.get("direction") != null:
			hit_dir = damage_input.get("direction")

	# Se estiver em guarda, reduz 70% do dano e anula knockback
	if _is_guarding:
		amount *= 0.30
		CombatFeedbackClass.spawn_hit_spark(self, global_position + Vector2(facing_direction * 20.0, -40.0), hit_dir, "light")
		return health_component.take_damage(amount)

	var applied: bool = health_component.take_damage(amount)
	if not applied:
		return false

	if health_component.is_dead:
		return true

	# Cancela ataque ativo ao receber dano
	if melee_attack != null:
		melee_attack.cancel_attack()
	_input_buffered = false

	var knock_sign: float = hit_dir.x if hit_dir.x != 0.0 else -facing_direction

	if can_kd:
		combat_state = CombatState.FALL
		_state_timer = 0.35
		velocity = Vector2(knock_sign * maxf(180.0, knockback * 2.0), 0.0)
		if anim_sprite != null and anim_sprite.sprite_frames.has_animation("fall"):
			anim_sprite.play("fall")
		if visual_root != null:
			visual_root.modulate = Color(2.5, 0.4, 0.4, 1.0)
	else:
		combat_state = CombatState.HURT
		_state_timer = 0.22
		_hurt_timer = 0.22
		velocity = Vector2(knock_sign * maxf(90.0, knockback), 0.0)
		if anim_sprite != null and anim_sprite.sprite_frames.has_animation("hurt"):
			anim_sprite.play("hurt")
		if visual_root != null:
			visual_root.modulate = Color(2.0, 0.4, 0.4, 1.0)

	state_changed.emit("Sofreu Dano")
	return true


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


## Fallback defensivo para mapeamento de teclas
func _ensure_fallback_inputs() -> void:
	_register_key_if_missing("move_left", KEY_A, KEY_LEFT)
	_register_key_if_missing("move_right", KEY_D, KEY_RIGHT)
	_register_key_if_missing("move_up", KEY_W, KEY_UP)
	_register_key_if_missing("move_down", KEY_S, KEY_DOWN)
	_register_key_if_missing("attack_punch", KEY_J, KEY_NONE)
	_register_key_if_missing("attack_kick", KEY_K, KEY_NONE)
	_register_key_if_missing("attack_special", KEY_L, KEY_NONE)
	_register_key_if_missing("special", KEY_L, KEY_O)
	_register_key_if_missing("attack_aerial", KEY_U, KEY_NONE)
	_register_key_if_missing("jump", KEY_SPACE, KEY_NONE)
	_register_key_if_missing("guard", KEY_H, KEY_NONE)
	_register_key_if_missing("attack", KEY_J, KEY_Z)
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
