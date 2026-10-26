class_name CombatDirector
extends Node

## Diretor de Combate Arcade para Beat 'em Up 2.5D.
## Centraliza a coordenação dos inimigos ativos, distribui tokens de ataque,
## previne a aglomeração (dogpiling) através de flanqueamento em pistas distintas
## e garante que nenhuma janela de dano inimigo ocorra simultaneamente.

signal encounter_started()
signal encounter_cleared()
signal enemy_registered(enemy: CharacterBody2D)
signal enemy_defeated(enemy: CharacterBody2D)
signal token_granted(enemy: CharacterBody2D)
signal token_released(enemy: CharacterBody2D)
signal active_attack_authorized(enemy: CharacterBody2D)

const EncounterDifficultyProfileClass = preload("res://scripts/combat/encounter_difficulty_profile.gd")

## Perfil de Dificuldade do Encontro (FASE COMBATE ARCADE)
@export var difficulty_profile: Resource = null


## Quantidade máxima de inimigos autorizados a disputar a iniciativa ofensiva (tokens)
@export var max_attack_tokens: int = 2

## Limite de ataques inimigos ativos com janela de dano simultânea (escalonamento justo)
@export var max_simultaneous_active_enemy_attacks: int = 1

## Tempo limite de retenção de token antes de revogação por inatividade (segundos)
@export var token_timeout_seconds: float = 4.0

## Quantidade de inimigos ou reforços pendentes aguardando spawn
@export var pending_spawns_count: int = 0


## Distância horizontal de espera para inimigos sem token (pixels)
@export var wait_distance_x_min: float = 120.0
@export var wait_distance_x_max: float = 180.0

## Tolerância de alinhamento em profundidade (eixo Y) para iniciar golpes
@export var depth_alignment_tolerance_px: float = 15.0

## Alcance horizontal para iniciar o golpe (pixels)
@export var attack_range_x_px: float = 70.0

## Grupo do jogador
@export var player_group: String = "player"

## Grupo dos inimigos
@export var enemy_group: String = "enemies"

## Referência ao jogador ativo
var player_target: CharacterBody2D = null

## Listas de controle de entidades
var registered_enemies: Array[CharacterBody2D] = []
var alive_enemies: Array[CharacterBody2D] = []
var defeated_enemies: Array[CharacterBody2D] = []

## Detentores de tokens de ataque
var token_holders: Array[CharacterBody2D] = []

## Mapeamento de contagem de tempo de token { enemy_id: float }
var _token_timers: Dictionary = {}

## Inimigos executando ataque ativo com hitbox ligada
var active_attackers: Array[CharacterBody2D] = []

## Mapeamento de slots de flanqueamento { enemy_id: Vector2(offset_x, offset_y) }
var _enemy_slots: Dictionary = {}

## Estado atual do encontro
var encounter_state: String = "COMBAT" # "COMBAT", "CLEARING", "COMPLETED"
var is_cleared: bool = false


func _ready() -> void:
	add_to_group("combat_director")
	call_deferred("_setup_director")


func _setup_director() -> void:
	_find_player()
	_register_existing_enemies()
	encounter_started.emit()


func _process(delta: float) -> void:
	_cleanup_invalid_instances()
	if player_target == null or not is_instance_valid(player_target):
		_find_player()
	_update_token_timeouts(delta)


## Localiza o jogador na cena
func _find_player() -> void:
	var found: Node = get_tree().get_first_node_in_group(player_group)
	if found is CharacterBody2D:
		player_target = found as CharacterBody2D


## Registra automaticamente inimigos já presentes no grupo
func _register_existing_enemies() -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(enemy_group)
	for n in nodes:
		if n is CharacterBody2D and not n.is_in_group("npcs") and not n.is_in_group("player") and not registered_enemies.has(n):
			register_enemy(n as CharacterBody2D)


## Registra um novo inimigo no encontro
func register_enemy(enemy: CharacterBody2D) -> void:
	if enemy == null or registered_enemies.has(enemy):
		return

	# Garantia FASE 3: Apenas entidades do grupo 'enemies' (e nunca 'npcs', 'player' ou 'props') participam do combate
	if not enemy.is_in_group(enemy_group) or enemy.is_in_group("npcs") or enemy.is_in_group("player") or enemy.is_in_group("props"):
		return

	registered_enemies.append(enemy)
	if not alive_enemies.has(enemy):
		alive_enemies.append(enemy)

	# Atribui slot de flanqueamento com profundidade alternada
	_assign_flank_slot(enemy)

	if difficulty_profile != null:
		_apply_profile_to_enemy(enemy)

	# Conecta com a remoção de cena para evitar vazamento de referências
	if not enemy.tree_exiting.is_connected(_on_enemy_tree_exiting.bind(enemy)):
		enemy.tree_exiting.connect(_on_enemy_tree_exiting.bind(enemy))

	enemy_registered.emit(enemy)


## Aplica um perfil de dificuldade dinâmico ao encontro (FASE COMBATE ARCADE)
func apply_difficulty_profile(profile: Resource) -> void:
	if profile == null:
		return

	difficulty_profile = profile
	max_attack_tokens = profile.max_attack_tokens
	max_simultaneous_active_enemy_attacks = profile.max_simultaneous_active_enemy_attacks
	token_timeout_seconds = profile.token_timeout_seconds

	var session = get_node_or_null("/root/GameSession")
	if session != null and "difficulty_id" in session and str(session.difficulty_id).to_lower() == "dificil":
		token_timeout_seconds = profile.token_timeout_seconds * 0.85

	for enemy in registered_enemies:
		_apply_profile_to_enemy(enemy)


func _apply_profile_to_enemy(enemy: CharacterBody2D) -> void:
	if enemy == null or difficulty_profile == null:
		return

	# Validação e aplicação das flags de composição de arquétipos do perfil
	if enemy.get("archetype") != null and enemy.has_method("_apply_archetype_configuration"):
		var arch: int = int(enemy.get("archetype"))
		var arch_changed: bool = false
		if arch == 2 and not difficulty_profile.allow_tanks: # TANK
			enemy.set("archetype", 0) # Rebaixa para GRUNT
			arch_changed = true
		elif arch == 1 and not difficulty_profile.allow_aggressors: # AGGRESSOR
			enemy.set("archetype", 0) # Rebaixa para GRUNT
			arch_changed = true
		elif arch == 3 and not difficulty_profile.allow_flankers: # FLANKER
			enemy.set("archetype", 0) # Rebaixa para GRUNT
			arch_changed = true
		if arch_changed:
			enemy._apply_archetype_configuration()

	# Preservação imutável dos valores-base para evitar acúmulo em re-aplicações
	if not enemy.has_meta("base_attack_windup") and enemy.get("attack_windup_seconds") != null:
		enemy.set_meta("base_attack_windup", float(enemy.attack_windup_seconds))
	if not enemy.has_meta("base_attack_cooldown") and enemy.get("attack_cooldown") != null:
		enemy.set_meta("base_attack_cooldown", float(enemy.attack_cooldown))

	var base_windup: float = float(enemy.get_meta("base_attack_windup", enemy.get("attack_windup_seconds")))
	var base_cooldown: float = float(enemy.get_meta("base_attack_cooldown", enemy.get("attack_cooldown")))

	# Integração do Modo de Dificuldade Global (GameSession: Normal vs Difícil)
	var global_hp_mult: float = 1.0
	var global_dmg_mult: float = 1.0
	var global_aggression_mult: float = 1.0
	var session = get_node_or_null("/root/GameSession")
	if session != null and "difficulty_id" in session:
		var diff_id: String = str(session.difficulty_id).to_lower()
		if session.DIFFICULTIES.has(diff_id):
			var diff_data: Dictionary = session.DIFFICULTIES[diff_id]
			global_hp_mult = float(diff_data.get("enemy_health_mult", 1.0))
			global_dmg_mult = float(diff_data.get("enemy_damage_mult", 1.0))
			if diff_id == "dificil":
				global_aggression_mult = 1.25

	if enemy.get("attack_windup_seconds") != null:
		var windup_speed: float = 1.15 if global_aggression_mult > 1.0 else 1.0
		enemy.attack_windup_seconds = (base_windup * difficulty_profile.telegraph_duration_multiplier) / windup_speed
	if enemy.get("attack_cooldown") != null:
		enemy.attack_cooldown = base_cooldown / maxf(0.1, difficulty_profile.attack_frequency_multiplier * global_aggression_mult)

	if enemy.get("health_component") != null:
		var hc: HealthComponent = enemy.health_component
		if hc != null:
			if not enemy.has_meta("base_max_health"):
				enemy.set_meta("base_max_health", float(hc.max_health))
			var base_hp: float = float(enemy.get_meta("base_max_health"))
			if base_hp > 0.0:
				var new_max: float = base_hp * difficulty_profile.health_multiplier * global_hp_mult
				var health_ratio: float = (hc.current_health / hc.max_health) if hc.max_health > 0.0 else 1.0
				hc.max_health = new_max
				hc.current_health = new_max * health_ratio

	if enemy.get("melee_attack") != null:
		var ma: MeleeAttack = enemy.melee_attack
		if ma != null:
			if not enemy.has_meta("base_melee_damage"):
				enemy.set_meta("base_melee_damage", float(ma.damage))
			var base_dmg: float = float(enemy.get_meta("base_melee_damage"))
			ma.damage = base_dmg * difficulty_profile.damage_multiplier * global_dmg_mult


## Incrementa a contagem de reforços ou inimigos de ondas pendentes
func add_pending_spawns(count: int = 1) -> void:
	pending_spawns_count += count



## Notifica a conclusão da instanciação de um inimigo pendente no mundo
func notify_spawn_completed(enemy: CharacterBody2D = null) -> void:
	pending_spawns_count = maxi(0, pending_spawns_count - 1)
	if enemy != null:
		register_enemy(enemy)


## Remove um inimigo do encontro (despawn ou exclusão de cena)
func unregister_enemy(enemy: CharacterBody2D) -> void:
	if enemy == null:
		return

	release_attack_token(enemy)
	registered_enemies.erase(enemy)
	alive_enemies.erase(enemy)
	defeated_enemies.erase(enemy)
	_enemy_slots.erase(enemy.get_instance_id())
	_check_victory_condition()


## Solicita um token de ataque para o inimigo
func request_attack_token(enemy: CharacterBody2D) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false

	if not alive_enemies.has(enemy):
		return false

	# Se já possui o token, confirma autorização
	if token_holders.has(enemy):
		return true

	_cleanup_invalid_instances()

	# Concede token apenas se houver vagas configuradas
	if token_holders.size() < max_attack_tokens:
		token_holders.append(enemy)
		_token_timers[enemy.get_instance_id()] = 0.0
		token_granted.emit(enemy)
		return true

	return false


## Libera o token de ataque detido pelo inimigo
func release_attack_token(enemy: CharacterBody2D) -> void:
	if enemy == null:
		return

	if active_attackers.has(enemy):
		active_attackers.erase(enemy)

	if token_holders.has(enemy):
		token_holders.erase(enemy)
		_token_timers.erase(enemy.get_instance_id())
		token_released.emit(enemy)


## Verifica se o inimigo pode iniciar a janela de impacto ativo
func can_start_active_attack(enemy: CharacterBody2D) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false

	# Deve obrigatoriamente possuir um token
	if not token_holders.has(enemy):
		return false

	_cleanup_invalid_instances()

	# Garante que nenhuma outra janela de dano inimigo esteja ativa simultaneamente
	if active_attackers.size() < max_simultaneous_active_enemy_attacks or active_attackers.has(enemy):
		return true

	return false


## Notifica que o inimigo entrou na janela ativa de ataque
func notify_attack_started(enemy: CharacterBody2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return

	if not active_attackers.has(enemy):
		active_attackers.append(enemy)
		active_attack_authorized.emit(enemy)


## Notifica que o ataque do inimigo foi concluído ou cancelado
func notify_attack_ended(enemy: CharacterBody2D) -> void:
	if enemy == null:
		return

	active_attackers.erase(enemy)


## Notifica a derrota de um inimigo (contabiliza estritamente 1 vez)
func notify_enemy_defeated(enemy: CharacterBody2D) -> void:
	if enemy == null:
		return

	release_attack_token(enemy)

	if alive_enemies.has(enemy):
		alive_enemies.erase(enemy)
		if not defeated_enemies.has(enemy):
			defeated_enemies.append(enemy)
		enemy_defeated.emit(enemy)

	_check_victory_condition()


## Retorna a posição ideal de flanqueamento e controle de espaço para um inimigo sem token
func get_flank_target_position(enemy: CharacterBody2D) -> Vector2:
	if player_target == null or not is_instance_valid(player_target):
		return enemy.global_position if enemy != null else Vector2.ZERO

	var p_pos: Vector2 = player_target.global_position
	var id: int = enemy.get_instance_id() if enemy != null else 0

	var offset: Vector2 = _enemy_slots.get(id, Vector2.ZERO)
	if offset == Vector2.ZERO:
		_assign_flank_slot(enemy)
		offset = _enemy_slots.get(id, Vector2(140.0, 0.0))

	return p_pos + offset


## Atribui um slot de flanqueamento com variação controlada de profundidade (eixo Y)
func _assign_flank_slot(enemy: CharacterBody2D) -> void:
	if enemy == null:
		return

	var idx: int = registered_enemies.find(enemy)
	if idx < 0:
		idx = registered_enemies.size()

	# Alterna lado esquerdo / direito ao redor do jogador
	var side_sign: float = -1.0 if (idx % 2 == 0) else 1.0

	# Distância horizontal escalonada na faixa de espera (120px a 180px)
	var dist_x: float = wait_distance_x_min + (float(idx % 3) * 20.0)

	# Variação de profundidade Y para ocupar pistas diferentes (+-25px a +-55px)
	var lane_offsets: Array[float] = [-35.0, 35.0, -55.0, 55.0, 0.0]
	var dist_y: float = lane_offsets[idx % lane_offsets.size()]

	_enemy_slots[enemy.get_instance_id()] = Vector2(side_sign * dist_x, dist_y)


## Verifica se todos os inimigos foram derrotados e conclui o encontro
func _check_victory_condition() -> void:
	if is_cleared:
		return

	_cleanup_invalid_instances()

	# O encontro só é concluído se todos os inimigos foram derrotados E não houver reforços pendentes
	if registered_enemies.size() > 0 and alive_enemies.is_empty() and pending_spawns_count == 0:
		is_cleared = true
		encounter_state = "COMPLETED"
		encounter_cleared.emit()


## Limpeza de nós que possam ter sido liberados da memória pelo motor
func _cleanup_invalid_instances() -> void:
	var to_remove_tokens: Array[CharacterBody2D] = []
	for e in token_holders:
		if e == null or not is_instance_valid(e):
			to_remove_tokens.append(e)
	for e in to_remove_tokens:
		token_holders.erase(e)
		if e != null:
			_token_timers.erase(e.get_instance_id())

	var to_remove_attackers: Array[CharacterBody2D] = []
	for e in active_attackers:
		if e == null or not is_instance_valid(e):
			to_remove_attackers.append(e)
	for e in to_remove_attackers:
		active_attackers.erase(e)

	var to_remove_alive: Array[CharacterBody2D] = []
	for e in alive_enemies:
		if e == null or not is_instance_valid(e):
			to_remove_alive.append(e)
	for e in to_remove_alive:
		alive_enemies.erase(e)


## Atualiza tempos de retenção de token e revoga tokens que excederam o tempo limite
func _update_token_timeouts(delta: float) -> void:
	if token_holders.is_empty():
		return

	var to_revoke: Array[CharacterBody2D] = []
	for enemy in token_holders:
		if enemy == null or not is_instance_valid(enemy):
			continue
		# Inimigo em janela ativa de dano tem ciclo próprio de encerramento
		if active_attackers.has(enemy):
			_token_timers[enemy.get_instance_id()] = 0.0
			continue

		var eid: int = enemy.get_instance_id()
		var elapsed: float = _token_timers.get(eid, 0.0) + delta
		_token_timers[eid] = elapsed

		if elapsed >= token_timeout_seconds:
			to_revoke.append(enemy)

	for enemy in to_revoke:
		release_attack_token(enemy)
		if enemy.has_method("_on_token_revoked"):
			enemy._on_token_revoked()


func _on_enemy_tree_exiting(enemy: CharacterBody2D) -> void:
	unregister_enemy(enemy)


## Retorna o total de inimigos restantes
func get_remaining_enemies_count() -> int:
	return alive_enemies.size()


## Retorna se o encontro foi vencido
func is_encounter_cleared() -> bool:
	return is_cleared
