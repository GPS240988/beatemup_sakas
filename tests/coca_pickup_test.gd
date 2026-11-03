extends SceneTree

## Testes focados do consumível Coca-Cola, feedback flutuante e drop do map_2.

const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const CocaPickupScene: PackedScene = preload("res://scenes/items/coca_pickup.tscn")
const Map2Scene: PackedScene = preload("res://scenes/levels/map_2.tscn")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_tests() -> void:
	print("\n==================================================")
	print("INICIANDO TESTES: COCA PICKUP / MAP_2")
	print("==================================================")

	await _test_health_component_healing()
	await _test_pickup_behavior()
	_test_map_2_drop_configuration()
	await _test_runtime_drop()

	print("==================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")
	quit(0 if failed_tests == 0 else 1)


func _test_health_component_healing() -> void:
	var health: HealthComponent = HealthComponentClass.new() as HealthComponent
	root.add_child(health)
	assert_test(health != null, "HealthComponent pode ser instanciado")
	if health == null:
		return

	await process_frame
	health.take_damage(40.0)
	var recovered: float = health.heal(25.0)
	assert_test(is_equal_approx(recovered, 25.0), "heal() retorna o valor efetivamente recuperado")
	assert_test(is_equal_approx(health.current_health, 85.0), "heal() recupera a quantidade solicitada")

	var capped_recovery: float = health.heal(50.0)
	assert_test(is_equal_approx(capped_recovery, 15.0), "heal() limita a recuperação à vida máxima")
	assert_test(is_equal_approx(health.current_health, health.max_health), "vida nunca ultrapassa max_health")

	health.take_damage(health.max_health)
	var dead_recovery: float = health.heal(25.0)
	assert_test(is_equal_approx(dead_recovery, 0.0), "heal() não ressuscita personagem derrotado")
	assert_test(health.is_dead and is_equal_approx(health.current_health, 0.0), "estado de derrota permanece intacto")
	health.queue_free()


func _test_pickup_behavior() -> void:
	var player: Node2D = PlayerScene.instantiate() as Node2D
	root.add_child(player)
	await process_frame
	player.global_position = Vector2(300.0, 300.0)
	var health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	assert_test(health != null, "Player mantém HealthComponent no caminho contratual")
	if health == null:
		player.queue_free()
		return

	health.take_damage(50.0)
	var pickup: Node2D = CocaPickupScene.instantiate() as Node2D
	root.add_child(pickup)
	pickup.global_position = Vector2(330.0, 312.0)
	await process_frame

	var tree_was_paused: bool = paused
	assert_test(not tree_was_paused, "árvore de cena inicia sem pausa antes da coleta")
	player.call("_on_attack_button_pressed")
	var melee_attack: MeleeAttack = player.get_node("MeleeAttack") as MeleeAttack
	assert_test(is_equal_approx(health.current_health, 75.0), "J consome a Coca e recupera 25% da vida máxima")
	assert_test(melee_attack != null and not melee_attack.is_attacking, "coleta tem prioridade e não inicia o ataque")
	assert_test(not paused, "coletar a Coca não pausa o jogo")
	assert_test(not bool(pickup.call("try_consume", player)), "mesmo item não pode ser consumido duas vezes")
	assert_test(not pickup.is_in_group("health_pickups"), "item consumido sai imediatamente do grupo de coleta")

	var feedback: Label2D = player.get_node_or_null("HealPickupFeedback") as Label2D
	assert_test(feedback != null, "coleta cria texto flutuante sobre o personagem")
	if feedback != null:
		assert_test(feedback.text == "+25% Vida", "texto de cura mostra exatamente '+25% Vida'")
		assert_test(feedback.process_mode == Node.PROCESS_MODE_ALWAYS, "texto flutuante não depende de pausa da árvore")
	await create_timer(0.8).timeout
	assert_test(not is_instance_valid(pickup), "item pisca, encolhe e desaparece do chão")

	# Com a vida cheia, o item não é gasto e J mantém o ataque normal.
	health.reset()
	var full_health_pickup: Node2D = CocaPickupScene.instantiate() as Node2D
	root.add_child(full_health_pickup)
	full_health_pickup.global_position = Vector2(330.0, 312.0)
	await process_frame
	player.call("_on_attack_button_pressed")
	assert_test(is_equal_approx(health.current_health, health.max_health), "Coca não é consumida quando a vida está cheia")
	assert_test(full_health_pickup.is_in_group("health_pickups"), "Coca permanece disponível quando não há vida a recuperar")
	assert_test(melee_attack.is_attacking, "J continua executando o combo quando não pode curar")
	melee_attack.cancel_attack()
	full_health_pickup.queue_free()

	# Item fora do alcance permanece disponível.
	var distant_pickup: Node2D = CocaPickupScene.instantiate() as Node2D
	root.add_child(distant_pickup)
	distant_pickup.global_position = Vector2(500.0, 500.0)
	await process_frame
	assert_test(not bool(distant_pickup.call("try_consume", player)), "item fora do alcance não é consumido")
	assert_test(is_instance_valid(distant_pickup) and distant_pickup.is_in_group("health_pickups"), "item distante permanece no chão")
	distant_pickup.queue_free()
	player.queue_free()


func _test_map_2_drop_configuration() -> void:
	var map_instance: Node = Map2Scene.instantiate()
	var games_box: Node = map_instance.get_node_or_null("World/Props/Destructibles/GamesBox")
	assert_test(games_box != null, "map_2 contém GameBox no contêiner canônico Destructibles")
	if games_box != null:
		assert_test(bool(games_box.get("drops_item")), "GameBox do map_2 está configurada para dropar item")
		var drop_scene: PackedScene = games_box.get("drop_item_scene") as PackedScene
		assert_test(drop_scene != null, "GameBox possui uma cena de drop configurada")
		if drop_scene != null:
			assert_test(drop_scene.resource_path == "res://scenes/items/coca_pickup.tscn", "drop aponta para a cena CocaPickup")
	map_instance.free()


func _test_runtime_drop() -> void:
	var container: Node2D = Node2D.new()
	root.add_child(container)
	var box_scene: PackedScene = load("res://scenes/props/destructible_games_box.tscn") as PackedScene
	var box: Node = box_scene.instantiate()
	container.add_child(box)
	await process_frame
	box.set("drops_item", true)
	box.set("drop_item_scene", CocaPickupScene)
	box.call("take_damage", float(box.get("max_health")))
	await process_frame
	await process_frame
	var dropped_items: Array[Node] = get_nodes_in_group("health_pickups")
	assert_test(dropped_items.size() == 1, "destruição completa da GameBox instancia exatamente uma Coca")
	container.queue_free()
	await process_frame
