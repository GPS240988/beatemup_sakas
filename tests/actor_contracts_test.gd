extends SceneTree

## Suíte de Testes dos Contratos de Atores, NPCs e Inimigos (Godot 4.x) — FASE 3
## Valida formalmente:
## 1. Separação semântica dos grupos: actors, player, enemies, npcs, damageable, destructibles.
## 2. CombatDirector controla estritamente 'enemies' e rejeita 'npcs', 'player' e 'props'.
## 3. Preservação da jogabilidade do Player.
## 4. Conceito 'damageable': alvos recebem dano sem necessidade de pertencer a 'enemies'.

const PlayerControllerClass = preload("res://scripts/actors/player_controller.gd")
const EnemyAIClass = preload("res://scripts/actors/enemy_ai.gd")
const BossAlessandroClass = preload("res://scripts/actors/boss_alessandro.gd")
const BaseNPCClass = preload("res://scripts/actors/npc.gd")
const DestructiblePropClass = preload("res://scripts/props/destructible_prop.gd")
const CombatDirectorClass = preload("res://scripts/combat/combat_director.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_actor_contract_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_actor_contract_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: ATORES, NPCS E INIMIGOS (FASE 3)")
	print("==================================================")

	test_group_normalization()
	test_combat_director_isolation()
	test_player_playability()
	test_damageable_without_enemy_group()

	print("==================================================")
	print("RESULTADO DOS TESTES DE ATORES E NPCS: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)


## 1. Validação de Normalização de Grupos
func test_group_normalization() -> void:
	print("\n--- 1. Testando Normalização de Grupos ---")

	# A) Player
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	assert_test(player_scene != null, "player.tscn carrega com sucesso")
	if player_scene != null:
		var p: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
		root.add_child(p)
		assert_test(p.is_in_group("actors"), "Player pertence ao grupo 'actors'")
		assert_test(p.is_in_group("player"), "Player pertence ao grupo 'player'")
		assert_test(p.is_in_group("damageable"), "Player pertence ao grupo 'damageable'")
		assert_test(not p.is_in_group("enemies"), "Player NÃO pertence ao grupo 'enemies'")
		assert_test(not p.is_in_group("npcs"), "Player NÃO pertence ao grupo 'npcs'")
		assert_test(not p.is_in_group("props"), "Player NÃO pertence ao grupo 'props'")
		assert_test(not p.is_in_group("destructibles"), "Player NÃO pertence ao grupo 'destructibles'")
		root.remove_child(p)
		p.free()

	# B) BasicEnemy
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	assert_test(enemy_scene != null, "basic_enemy.tscn carrega com sucesso")
	if enemy_scene != null:
		var e: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
		root.add_child(e)
		assert_test(e.is_in_group("actors"), "BasicEnemy pertence ao grupo 'actors'")
		assert_test(e.is_in_group("enemies"), "BasicEnemy pertence ao grupo 'enemies'")
		assert_test(e.is_in_group("damageable"), "BasicEnemy pertence ao grupo 'damageable'")
		assert_test(not e.is_in_group("player"), "BasicEnemy NÃO pertence ao grupo 'player'")
		assert_test(not e.is_in_group("npcs"), "BasicEnemy NÃO pertence ao grupo 'npcs'")
		assert_test(not e.is_in_group("props"), "BasicEnemy NÃO pertence ao grupo 'props'")
		assert_test(not e.is_in_group("destructibles"), "BasicEnemy NÃO pertence ao grupo 'destructibles'")
		root.remove_child(e)
		e.free()

	# C) BossAlessandro
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn")
	assert_test(boss_scene != null, "boss_alessandro.tscn carrega com sucesso")
	if boss_scene != null:
		var b: CharacterBody2D = boss_scene.instantiate() as CharacterBody2D
		root.add_child(b)
		assert_test(b.is_in_group("actors"), "BossAlessandro pertence ao grupo 'actors'")
		assert_test(b.is_in_group("enemies"), "BossAlessandro pertence ao grupo 'enemies'")
		assert_test(b.is_in_group("damageable"), "BossAlessandro pertence ao grupo 'damageable'")
		assert_test(not b.is_in_group("player"), "BossAlessandro NÃO pertence ao grupo 'player'")
		assert_test(not b.is_in_group("npcs"), "BossAlessandro NÃO pertence ao grupo 'npcs'")
		assert_test(not b.is_in_group("props"), "BossAlessandro NÃO pertence ao grupo 'props'")
		assert_test(not b.is_in_group("destructibles"), "BossAlessandro NÃO pertence ao grupo 'destructibles'")
		root.remove_child(b)
		b.free()

	# D) BaseNPC
	var npc_scene: PackedScene = load("res://scenes/actors/npc.tscn")
	assert_test(npc_scene != null, "npc.tscn carrega com sucesso")
	if npc_scene != null:
		var n: CharacterBody2D = npc_scene.instantiate() as CharacterBody2D
		root.add_child(n)
		assert_test(n.is_in_group("actors"), "BaseNPC pertence ao grupo 'actors'")
		assert_test(n.is_in_group("npcs"), "BaseNPC pertence ao grupo 'npcs'")
		assert_test(n.is_in_group("damageable"), "BaseNPC pertence ao grupo 'damageable'")
		assert_test(not n.is_in_group("enemies"), "BaseNPC NÃO pertence ao grupo 'enemies'")
		assert_test(not n.is_in_group("player"), "BaseNPC NÃO pertence ao grupo 'player'")
		assert_test(not n.is_in_group("props"), "BaseNPC NÃO pertence ao grupo 'props'")
		assert_test(not n.is_in_group("destructibles"), "BaseNPC NÃO pertence ao grupo 'destructibles'")
		root.remove_child(n)
		n.free()

	# E) DestructibleProp
	var prop_scene: PackedScene = load("res://scenes/props/destructible_prop.tscn")
	assert_test(prop_scene != null, "destructible_prop.tscn carrega com sucesso")
	if prop_scene != null:
		var dp: StaticBody2D = prop_scene.instantiate() as StaticBody2D
		root.add_child(dp)
		assert_test(dp.is_in_group("props"), "DestructibleProp pertence ao grupo 'props'")
		assert_test(dp.is_in_group("destructibles"), "DestructibleProp pertence ao grupo 'destructibles'")
		assert_test(dp.is_in_group("damageable"), "DestructibleProp pertence ao grupo 'damageable'")
		assert_test(not dp.is_in_group("actors"), "DestructibleProp NÃO pertence ao grupo 'actors'")
		assert_test(not dp.is_in_group("enemies"), "DestructibleProp NÃO pertence ao grupo 'enemies'")
		assert_test(not dp.is_in_group("player"), "DestructibleProp NÃO pertence ao grupo 'player'")
		assert_test(not dp.is_in_group("npcs"), "DestructibleProp NÃO pertence ao grupo 'npcs'")
		root.remove_child(dp)
		dp.free()


## 2. Validação do Isolamento do CombatDirector
func test_combat_director_isolation() -> void:
	print("\n--- 2. Testando Isolamento do CombatDirector ---")
	var director := CombatDirectorClass.new()
	root.add_child(director)

	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var npc_scene: PackedScene = load("res://scenes/actors/npc.tscn")
	var prop_scene: PackedScene = load("res://scenes/props/destructible_prop.tscn")

	var enemy: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
	var npc: CharacterBody2D = npc_scene.instantiate() as CharacterBody2D
	var prop: Node = prop_scene.instantiate()

	root.add_child(enemy)
	root.add_child(npc)
	root.add_child(prop)

	# 1. Registro de inimigo deve ser aceito
	director.register_enemy(enemy)
	assert_test(director.registered_enemies.has(enemy), "CombatDirector aceita e registra Enemy")
	assert_test(director.alive_enemies.has(enemy), "Enemy está presente em alive_enemies")

	# 2. Registro de NPC deve ser rejeitado
	director.register_enemy(npc)
	assert_test(not director.registered_enemies.has(npc), "CombatDirector REJEITA registro de NPC civil")
	assert_test(not director.alive_enemies.has(npc), "NPC civil NÃO entra em alive_enemies")

	# 3. Registro de Prop deve ser rejeitado
	director.register_enemy(prop as CharacterBody2D)
	assert_test(director.registered_enemies.size() == 1 and director.registered_enemies[0] == enemy, "CombatDirector REJEITA registro de Props")

	# 4. NPC civil com HealthComponent não impede encerramento do combate
	assert_test(director.alive_enemies.size() == 1, "Apenas o inimigo genuíno é contado no combate")
	director.notify_enemy_defeated(enemy)
	assert_test(director.is_cleared, "Combate é encerrado vitorioso mesmo com NPC civil vivo no mapa")

	root.remove_child(director)
	root.remove_child(enemy)
	root.remove_child(npc)
	root.remove_child(prop)
	director.free()
	enemy.free()
	npc.free()
	prop.free()


## 3. Preservação da Jogabilidade do Player
func test_player_playability() -> void:
	print("\n--- 3. Testando Preservação da Jogabilidade do Player ---")
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var p: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	root.add_child(p)

	assert_test(p.has_method("execute_punch"), "Player possui execute_punch")
	assert_test(p.has_method("execute_kick"), "Player possui execute_kick")
	assert_test(p.has_method("execute_heavy"), "Player possui execute_heavy")
	assert_test(p.has_method("execute_aerial"), "Player possui execute_aerial")

	var melee: MeleeAttack = p.get_node_or_null("MeleeAttack") as MeleeAttack
	var anim_sprite: AnimatedSprite2D = p.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D

	# Executa ataques e verifica animações
	p.execute_punch()
	assert_test(anim_sprite != null and anim_sprite.animation == &"punch", "Player executa soco corretamente")
	if melee != null:
		melee.cancel_attack()

	p.execute_kick()
	assert_test(anim_sprite != null and anim_sprite.animation == &"kick", "Player executa chute corretamente")
	if melee != null:
		melee.cancel_attack()

	p.execute_heavy()
	assert_test(anim_sprite != null and anim_sprite.animation == &"heavy", "Player executa ataque especial corretamente")
	if melee != null:
		melee.cancel_attack()

	root.remove_child(p)
	p.free()


## 4. Conceito Damageable Sem Dependência de Enemies
func test_damageable_without_enemy_group() -> void:
	print("\n--- 4. Testando Damageable sem Dependência de 'enemies' ---")

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var prop_scene: PackedScene = load("res://scenes/props/destructible_prop.tscn")
	var npc_scene: PackedScene = load("res://scenes/actors/npc.tscn")

	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	var prop: StaticBody2D = prop_scene.instantiate() as StaticBody2D
	var npc: CharacterBody2D = npc_scene.instantiate() as CharacterBody2D

	player.position = Vector2(100, 100)
	prop.position = Vector2(140, 100) # À frente do player
	npc.position = Vector2(200, 100)

	root.add_child(player)
	root.add_child(prop)
	root.add_child(npc)

	# A) Player atacando prop destrutível (sem que o prop seja 'enemy')
	assert_test(not prop.is_in_group("enemies"), "Prop NÃO pertence a 'enemies'")
	assert_test(prop.is_in_group("damageable"), "Prop pertence a 'damageable'")
	var initial_prop_health: float = prop.get("current_health")

	var melee: MeleeAttack = player.get_node_or_null("MeleeAttack") as MeleeAttack
	assert_test(melee != null, "Player possui MeleeAttack")

	var signal_received := {"hit": false}
	melee.target_hit.connect(func(_target: Node, _dmg: float) -> void: signal_received["hit"] = true)

	melee.execute_attack(1.0)
	# Processa colisão com o prop
	melee._try_hit_target(prop)

	assert_test(signal_received["hit"], "MeleeAttack acertou com sucesso o DestructibleProp")
	assert_test(prop.get("current_health") < initial_prop_health, "DestructibleProp sofreu dano do Player sem pertencer a 'enemies'")

	# B) Ataque com target_group='damageable' atingindo NPC civil
	assert_test(not npc.is_in_group("enemies"), "NPC NÃO pertence a 'enemies'")
	assert_test(npc.is_in_group("damageable"), "NPC pertence a 'damageable'")
	var initial_npc_hp: float = npc.get("current_health")

	# Simula dano direto no NPC através do contrato de damageable
	npc.take_damage(10.0)
	assert_test(npc.get("current_health") == initial_npc_hp - 10.0, "NPC civil recebe dano pelo contrato 'damageable'")
	assert_test(npc.get("is_fleeing") == true, "NPC civil reage e foge após dano")

	root.remove_child(player)
	root.remove_child(prop)
	root.remove_child(npc)
	player.free()
	prop.free()
	npc.free()
