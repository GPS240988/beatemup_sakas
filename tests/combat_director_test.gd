extends SceneTree

## Suíte de Testes Automatizados Headless para o CombatDirector e Sistema de Tokens Arcade 2.5D.

const CombatDirectorClass = preload("res://scripts/combat/combat_director.gd")
const EnemyAIClass = preload("res://scripts/actors/enemy_ai.gd")
const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const MeleeAttackClass = preload("res://scripts/components/melee_attack.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES DO COMBAT DIRECTOR (GODOT 4.x)")
	print("==================================================")

	test_director_token_limit_and_concession()
	test_simultaneous_active_damage_window_limit()
	test_token_release_on_hurt_and_death()
	test_flanking_space_distribution()
	test_defeated_enemy_accounting_and_victory()
	test_telegraph_does_not_damage_prematurely()
	test_token_timeout_and_revocation()

	print("==================================================")
	print("RESULTADO DOS TESTES DO DIRETOR: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _create_dummy_actor(group_name: String, pos: Vector2) -> CharacterBody2D:
	var actor := CharacterBody2D.new()
	actor.add_to_group(group_name)
	actor.global_position = pos

	var health := HealthComponentClass.new()
	health.name = "HealthComponent"
	health.max_health = 100.0
	actor.add_child(health)
	health._ready()

	var attack := MeleeAttackClass.new()
	attack.name = "MeleeAttack"
	attack.damage = 15.0
	attack.horizontal_range = 70.0
	attack.depth_tolerance = 25.0
	attack.target_group = "player" if group_name == "enemies" else "enemies"
	actor.add_child(attack)
	attack._ready()

	return actor


func test_director_token_limit_and_concession() -> void:
	print("\n--- Testando Limite e Concessão de Tokens de Ataque ---")
	var root_node := Node2D.new()
	root.add_child(root_node)

	var director := CombatDirectorClass.new()
	director.max_attack_tokens = 2
	director.max_simultaneous_active_enemy_attacks = 1
	root_node.add_child(director)

	var player := _create_dummy_actor("player", Vector2(300, 500))
	root_node.add_child(player)
	director.player_target = player

	var e1 := _create_dummy_actor("enemies", Vector2(500, 500))
	var e2 := _create_dummy_actor("enemies", Vector2(600, 500))
	var e3 := _create_dummy_actor("enemies", Vector2(700, 500))
	root_node.add_child(e1)
	root_node.add_child(e2)
	root_node.add_child(e3)

	director.register_enemy(e1)
	director.register_enemy(e2)
	director.register_enemy(e3)

	# 1. Primeiro e segundo inimigos conseguem tokens (limite = 2)
	var t1: bool = director.request_attack_token(e1)
	var t2: bool = director.request_attack_token(e2)
	assert_test(t1 and director.token_holders.has(e1), "Inimigo 1 recebe token com sucesso")
	assert_test(t2 and director.token_holders.has(e2), "Inimigo 2 recebe token com sucesso")
	assert_test(director.token_holders.size() == 2, "Quantidade de tokens ocupados é exatamente 2")

	# 2. Terceiro inimigo tem pedido NEGADO (não pode exceder limite)
	var t3: bool = director.request_attack_token(e3)
	assert_test(not t3 and not director.token_holders.has(e3), "Inimigo 3 tem token negado por esgotamento de vagas")

	# 3. Liberação do token do Inimigo 1 permite concessão ao Inimigo 3
	director.release_attack_token(e1)
	assert_test(not director.token_holders.has(e1), "Token do Inimigo 1 liberado com sucesso")
	var t3_retry: bool = director.request_attack_token(e3)
	assert_test(t3_retry and director.token_holders.has(e3), "Inimigo 3 obtém token após liberação de vaga")

	root_node.free()


func test_simultaneous_active_damage_window_limit() -> void:
	print("\n--- Testando Limite de Janelas de Dano Ativo Simultâneas ---")
	var root_node := Node2D.new()
	root.add_child(root_node)

	var director := CombatDirectorClass.new()
	director.max_attack_tokens = 2
	director.max_simultaneous_active_enemy_attacks = 1
	root_node.add_child(director)

	var e1 := _create_dummy_actor("enemies", Vector2(400, 500))
	var e2 := _create_dummy_actor("enemies", Vector2(500, 500))
	root_node.add_child(e1)
	root_node.add_child(e2)

	director.register_enemy(e1)
	director.register_enemy(e2)

	# Ambos obtêm tokens
	director.request_attack_token(e1)
	director.request_attack_token(e2)

	# Inimigo 1 pode iniciar ataque ativo
	assert_test(director.can_start_active_attack(e1), "Inimigo 1 autorizado a iniciar ataque ativo")
	director.notify_attack_started(e1)
	assert_test(director.active_attackers.has(e1), "Inimigo 1 registrado em active_attackers")

	# Inimigo 2 é IMPEDIDO de iniciar dano simultâneo enquanto Inimigo 1 está atacando
	assert_test(not director.can_start_active_attack(e2), "Inimigo 2 bloqueado de iniciar ataque ativo simultâneo")

	# Quando Inimigo 1 encerra, Inimigo 2 é autorizado
	director.notify_attack_ended(e1)
	assert_test(not director.active_attackers.has(e1), "Inimigo 1 encerrou janela ativa")
	assert_test(director.can_start_active_attack(e2), "Inimigo 2 agora autorizado a iniciar ataque ativo")

	root_node.free()


func test_token_release_on_hurt_and_death() -> void:
	print("\n--- Testando Liberação de Recursos em Dano e Derrota ---")
	var root_node := Node2D.new()
	root.add_child(root_node)

	var director := CombatDirectorClass.new()
	root_node.add_child(director)

	var e1 := _create_dummy_actor("enemies", Vector2(400, 500))
	root_node.add_child(e1)
	director.register_enemy(e1)

	director.request_attack_token(e1)
	director.notify_attack_started(e1)
	assert_test(director.token_holders.has(e1) and director.active_attackers.has(e1), "Inimigo possui token e ataque ativo")

	# Em caso de derrota (notificado ao diretor)
	director.notify_enemy_defeated(e1)
	assert_test(not director.token_holders.has(e1), "Token liberado imediatamente após derrota")
	assert_test(not director.active_attackers.has(e1), "Ataque ativo cancelado imediatamente após derrota")
	assert_test(not director.alive_enemies.has(e1), "Inimigo removido de alive_enemies")

	root_node.free()


func test_flanking_space_distribution() -> void:
	print("\n--- Testando Distribuição de Flanqueamento e Pistas Y ---")
	var root_node := Node2D.new()
	root.add_child(root_node)

	var director := CombatDirectorClass.new()
	director.wait_distance_x_min = 120.0
	director.wait_distance_x_max = 180.0
	root_node.add_child(director)

	var player := _create_dummy_actor("player", Vector2(500, 500))
	root_node.add_child(player)
	director.player_target = player

	var e1 := _create_dummy_actor("enemies", Vector2(200, 500))
	var e2 := _create_dummy_actor("enemies", Vector2(800, 500))
	root_node.add_child(e1)
	root_node.add_child(e2)

	director.register_enemy(e1)
	director.register_enemy(e2)

	var flank1: Vector2 = director.get_flank_target_position(e1)
	var flank2: Vector2 = director.get_flank_target_position(e2)

	assert_test(flank1 != flank2, "Inimigos recebem posições de flanqueamento distintas")
	assert_test(flank1.y != flank2.y, "Inimigos recebem pistas de profundidade Y diferentes para evitar sobreposição")
	assert_test(absf(flank1.x - player.global_position.x) >= 120.0, "Distância horizontal de espera respeita o mínimo de 120px")

	root_node.free()


func test_defeated_enemy_accounting_and_victory() -> void:
	print("\n--- Testando Contabilidade de Derrota e Vitória do Encontro ---")
	var root_node := Node2D.new()
	root.add_child(root_node)

	var director := CombatDirectorClass.new()
	root_node.add_child(director)

	var e1 := _create_dummy_actor("enemies", Vector2(400, 500))
	var e2 := _create_dummy_actor("enemies", Vector2(600, 500))
	root_node.add_child(e1)
	root_node.add_child(e2)

	director.register_enemy(e1)
	director.register_enemy(e2)

	assert_test(director.get_remaining_enemies_count() == 2, "Contagem inicial de 2 inimigos vivos")
	assert_test(not director.is_encounter_cleared(), "Encontro NÃO concluído enquanto houver inimigos vivos")

	# Derrota do primeiro inimigo
	director.notify_enemy_defeated(e1)
	assert_test(director.get_remaining_enemies_count() == 1, "Contagem reduzida para 1 inimigo vivo")
	assert_test(not director.is_encounter_cleared(), "Encontro NÃO concluído com 1 inimigo ainda vivo")

	# Notificação duplicada do mesmo inimigo não reduz contagem abaixo de zero
	director.notify_enemy_defeated(e1)
	assert_test(director.get_remaining_enemies_count() == 1, "Morte contabilizada estritamente uma vez")

	# Derrota do segundo inimigo
	director.notify_enemy_defeated(e2)
	assert_test(director.get_remaining_enemies_count() == 0, "Todos os inimigos derrotados")
	assert_test(director.is_encounter_cleared(), "Encontro concluído com vitória declarada pelo diretor")

	root_node.free()


func test_telegraph_does_not_damage_prematurely() -> void:
	print("\n--- Testando que Telegraph Não Aplica Dano Antecipado ---")
	var root_node := Node2D.new()
	root.add_child(root_node)

	var player := _create_dummy_actor("player", Vector2(300, 500))
	root_node.add_child(player)
	var p_health: HealthComponent = player.get_node("HealthComponent") as HealthComponent

	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var enemy = enemy_scene.instantiate() as CharacterBody2D
	enemy.global_position = Vector2(350, 500)
	root_node.add_child(enemy)

	var enemy_ai = enemy as EnemyAI
	enemy_ai.player_target = player
	enemy_ai.current_state = EnemyAI.State.TELEGRAPH
	enemy_ai._state_timer = 0.25

	# Durante o telegraph, a hitbox da MeleeAttack deve permanecer inativa
	assert_test(not enemy_ai.melee_attack.is_attacking, "Hitbox de ataque NÃO está ativa durante o telegraph")
	assert_test(p_health.current_health == 100.0, "Jogador não sofreu dano durante a fase de preparação visual")

	root_node.free()


func test_token_timeout_and_revocation() -> void:
	print("\n--- Testando Timeout de Token e Revogação por Inatividade ---")
	var root_node := Node2D.new()
	root.add_child(root_node)

	var director := CombatDirectorClass.new()
	director.max_attack_tokens = 1
	director.token_timeout_seconds = 2.0
	root_node.add_child(director)

	var e1 := _create_dummy_actor("enemies", Vector2(400, 500))
	var e2 := _create_dummy_actor("enemies", Vector2(500, 500))
	root_node.add_child(e1)
	root_node.add_child(e2)

	director.register_enemy(e1)
	director.register_enemy(e2)

	# Inimigo 1 ganha o único token
	assert_test(director.request_attack_token(e1), "Inimigo 1 obtém token")
	assert_test(not director.request_attack_token(e2), "Inimigo 2 bloqueado por falta de token")

	# Simula passagem de tempo de 1.0s (abaixo do timeout de 2.0s)
	director._update_token_timeouts(1.0)
	assert_test(director.token_holders.has(e1), "Token permanece com Inimigo 1 antes do tempo limite")

	# Simula passagem de mais 1.5s (total 2.5s > 2.0s)
	director._update_token_timeouts(1.5)
	assert_test(not director.token_holders.has(e1), "Token do Inimigo 1 é revogado automaticamente por inatividade")

	# Agora Inimigo 2 consegue obter o token liberado
	assert_test(director.request_attack_token(e2), "Inimigo 2 obtém token após revogação do token ocioso")

	root_node.free()
