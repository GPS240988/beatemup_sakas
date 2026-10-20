extends SceneTree

## Suíte de Testes de Integração de Combate e DamageInfo (Godot 4.x) — FASE 6
## Valida formalmente:
## 1. Player -> Enemy (Player ataca Inimigo com DamageInfo e aplica dano)
## 2. Player -> Destructible (Player ataca DestructibleProp com DamageInfo)
## 3. Enemy -> Player (Inimigo ataca Player com DamageInfo)
## 4. Enemy -> Destructible (Inimigo ataca DestructibleProp com DamageInfo)
## 5. NPC -> Não atacar (NPC neutro não ataca Player, Inimigos ou Props)
## 6. Desacoplamento total de classes (DamageInfo universal e receptor decide a reação)

const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const MeleeAttackClass = preload("res://scripts/components/melee_attack.gd")
const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const DestructiblePropClass = preload("res://scripts/props/destructible_prop.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_combat_integration_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_combat_integration_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: INTEGRAÇÃO DE COMBATE (FASE 6)")
	print("==================================================")

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var prop_scene: PackedScene = load("res://scenes/props/destructible_prop.tscn")
	var npc_scene: PackedScene = load("res://scenes/actors/npc.tscn")

	assert_test(player_scene != null, "player.tscn carregada com sucesso")
	assert_test(enemy_scene != null, "basic_enemy.tscn carregada com sucesso")
	assert_test(prop_scene != null, "destructible_prop.tscn carregada com sucesso")
	assert_test(npc_scene != null, "npc.tscn carregada com sucesso")

	# PARTE 1: Player -> Enemy
	print("\n--- 1. Validando Ataque: Player -> Enemy ---")
	var player_node: Node2D = player_scene.instantiate() as Node2D
	var enemy_node: Node2D = enemy_scene.instantiate() as Node2D
	root.add_child(player_node)
	root.add_child(enemy_node)
	player_node.global_position = Vector2(100, 100)
	enemy_node.global_position = Vector2(140, 100)
	await process_frame

	var player_melee: Node = player_node.get_node_or_null("MeleeAttack")
	var enemy_health: Node = enemy_node.get_node_or_null("HealthComponent")
	assert_test(player_melee != null, "Player possui MeleeAttack")
	assert_test(enemy_health != null, "Enemy possui HealthComponent")

	var enemy_initial_hp: float = enemy_health.get("current_health")
	var tracker1 := {"hit": false}
	player_melee.target_hit.connect(func(_t: Node, _d: float) -> void: tracker1["hit"] = true)

	player_melee.execute_attack(1.0)
	player_melee._try_hit_target(enemy_node)

	assert_test(tracker1["hit"], "MeleeAttack do Player emitiu target_hit ao acertar Enemy")
	assert_test(enemy_health.get("current_health") < enemy_initial_hp, "Enemy recebeu dano do Player via DamageInfo")

	root.remove_child(player_node)
	root.remove_child(enemy_node)
	player_node.free()
	enemy_node.free()

	# PARTE 2: Player -> DestructibleProp
	print("\n--- 2. Validando Ataque: Player -> DestructibleProp ---")
	var player2: Node2D = player_scene.instantiate() as Node2D
	var prop2: Node2D = prop_scene.instantiate() as Node2D
	root.add_child(player2)
	root.add_child(prop2)
	player2.global_position = Vector2(200, 200)
	prop2.global_position = Vector2(240, 200)
	await process_frame

	var p2_melee: Node = player2.get_node_or_null("MeleeAttack")
	var prop2_initial_hp: float = prop2.get("current_health")
	var tracker2 := {"hit": false}
	p2_melee.target_hit.connect(func(_t: Node, _d: float) -> void: tracker2["hit"] = true)

	p2_melee.execute_attack(1.0)
	p2_melee._try_hit_target(prop2)

	assert_test(tracker2["hit"], "Player MeleeAttack emitiu target_hit ao acertar DestructibleProp")
	assert_test(prop2.get("current_health") < prop2_initial_hp, "DestructibleProp recebeu dano do Player")
	assert_test(prop2.get("current_state") == DestructiblePropClass.PropState.DAMAGED, "Prop transicionou para DAMAGED")

	root.remove_child(player2)
	root.remove_child(prop2)
	player2.free()
	prop2.free()

	# PARTE 3: Enemy -> Player
	print("\n--- 3. Validando Ataque: Enemy -> Player ---")
	var enemy3: Node2D = enemy_scene.instantiate() as Node2D
	var player3: Node2D = player_scene.instantiate() as Node2D
	root.add_child(enemy3)
	root.add_child(player3)
	enemy3.global_position = Vector2(300, 300)
	player3.global_position = Vector2(340, 300)
	await process_frame

	var enemy3_melee: Node = enemy3.get_node_or_null("MeleeAttack")
	var player3_health: Node = player3.get_node_or_null("HealthComponent")
	assert_test(enemy3_melee != null, "Enemy possui MeleeAttack")
	assert_test(player3_health != null, "Player possui HealthComponent")

	var player3_initial_hp: float = player3_health.get("current_health")
	var tracker3 := {"hit": false}
	enemy3_melee.target_hit.connect(func(_t: Node, _d: float) -> void: tracker3["hit"] = true)

	enemy3_melee.execute_attack(1.0)
	enemy3_melee._try_hit_target(player3)

	assert_test(tracker3["hit"], "Enemy MeleeAttack emitiu target_hit ao acertar Player")
	assert_test(player3_health.get("current_health") < player3_initial_hp, "Player recebeu dano do Inimigo via DamageInfo")

	root.remove_child(enemy3)
	root.remove_child(player3)
	enemy3.free()
	player3.free()

	# PARTE 4: Enemy -> DestructibleProp
	print("\n--- 4. Validando Ataque: Enemy -> DestructibleProp ---")
	var enemy4: Node2D = enemy_scene.instantiate() as Node2D
	var prop4: Node2D = prop_scene.instantiate() as Node2D
	root.add_child(enemy4)
	root.add_child(prop4)
	enemy4.global_position = Vector2(400, 400)
	prop4.global_position = Vector2(440, 400)
	await process_frame

	var enemy4_melee: Node = enemy4.get_node_or_null("MeleeAttack")
	var prop4_initial_hp: float = prop4.get("current_health")
	var tracker4 := {"hit": false}
	enemy4_melee.target_hit.connect(func(_t: Node, _d: float) -> void: tracker4["hit"] = true)

	enemy4_melee.execute_attack(1.0)
	enemy4_melee._try_hit_target(prop4)

	assert_test(tracker4["hit"], "Enemy MeleeAttack acertou DestructibleProp com sucesso")
	assert_test(prop4.get("current_health") < prop4_initial_hp, "DestructibleProp sofreu dano do Inimigo")

	root.remove_child(enemy4)
	root.remove_child(prop4)
	enemy4.free()
	prop4.free()

	# PARTE 5: NPC -> Não atacar
	print("\n--- 5. Validando Comportamento de NPC (Não-Combatente) ---")
	var npc5: Node2D = npc_scene.instantiate() as Node2D
	root.add_child(npc5)
	await process_frame

	assert_test(npc5.is_in_group("npcs"), "NPC pertence ao grupo 'npcs'")
	assert_test(not npc5.is_in_group("enemies"), "NPC NÃO pertence ao grupo 'enemies'")
	assert_test(npc5.get_node_or_null("MeleeAttack") == null, "NPC não possui componente de ataque ativo")
	assert_test(not npc5.has_method("execute_attack"), "NPC não possui método de ataque executável")

	# Recebimento de dano sem contra-ataque
	var npc_initial_hp: float = npc5.get("current_health")
	var took: bool = npc5.take_damage(10.0)
	assert_test(took, "NPC aceita dano através do contrato de dano")
	assert_test(npc5.get("current_health") == npc_initial_hp - 10.0, "Vida do NPC reduzida")
	assert_test(npc5.get("is_fleeing") == true, "NPC reage fugindo ao invés de contra-atacar")

	root.remove_child(npc5)
	npc5.free()

	# PARTE 6: Desacoplamento de Classes e Objeto DamageInfo
	print("\n--- 6. Validando Objeto DamageInfo e Desacoplamento ---")
	var dinfo := DamageInfoClass.new(
		25.0,
		null,
		Vector2(10, 20),
		Vector2.LEFT,
		"special",
		60.0,
		0.3,
		true
	)
	assert_test(dinfo.amount == 25.0, "DamageInfo amount == 25.0")
	assert_test(dinfo.damage_type == "special", "DamageInfo damage_type == 'special'")
	assert_test(dinfo.knockback_force == 60.0, "DamageInfo knockback_force == 60.0")
	assert_test(dinfo.can_destroy_props == true, "DamageInfo can_destroy_props == true")

	# Receptor HealthComponent aceita DamageInfo
	var standalone_hc: HealthComponent = HealthComponentClass.new()
	standalone_hc.max_health = 100.0
	root.add_child(standalone_hc)
	await process_frame

	var accepted_info: bool = standalone_hc.take_damage(dinfo)
	assert_test(accepted_info, "HealthComponent aceitou objeto DamageInfo diretamente")
	assert_test(standalone_hc.current_health == 75.0, "HealthComponent calculou vida restante 75.0")

	root.remove_child(standalone_hc)
	standalone_hc.free()

	_finish()


func _finish() -> void:
	print("==================================================")
	print("RESULTADO DOS TESTES DE INTEGRAÇÃO DE COMBATE: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)
