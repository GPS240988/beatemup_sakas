extends SceneTree

## Suíte de Testes dos Contratos de Static World e Dynamic Props (Godot 4.x) — FASE 2
## Valida formalmente:
## 1. Separação semântica e física: StaticWorld ≠ Props, Props ≠ Actors.
## 2. Integridade dos Atores: Player e Inimigos nunca pertencem a Props.
## 3. Isolamento de Geometria: CollisionShape2D de paredes não são props interativos.
## 4. Contrato Estrutural de DestructibleProp (nós, camadas, sinais, transição de dano/destruição).
## 5. Compatibilidade regressiva com props estáticos existentes.

const DestructiblePropClass = preload("res://scripts/props/destructible_prop.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_prop_contract_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_prop_contract_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: STATIC WORLD / DYNAMIC PROPS (FASE 2)")
	print("==================================================")

	var map_paths: Array[String] = [
		"res://scenes/levels/map_1.tscn",
		"res://scenes/levels/map_2.tscn",
		"res://scenes/levels/map_3.tscn",
		"res://scenes/levels/map_4.tscn",
		"res://scenes/levels/test_street.tscn"
	]

	# PARTE 1: Verificação da separação em todos os mapas
	for path in map_paths:
		var map_name: String = path.get_file().get_basename()
		print("\n--- Validando Separação StaticWorld / Props / Actors em [%s] ---" % map_name)

		var scene: PackedScene = load(path)
		assert_test(scene != null, "%s: Cena carregada com sucesso" % map_name)
		if scene == null:
			continue

		var inst: Node = scene.instantiate()
		assert_test(inst != null, "%s: Instância gerada" % map_name)
		if inst == null:
			continue

		var static_world: Node = inst.get_node_or_null("StaticWorld")
		var world_node: Node = inst.get_node_or_null("World")
		var props_node: Node = inst.get_node_or_null("World/Props")
		var actors_node: Node = inst.get_node_or_null("World/Actors")

		# Regra: StaticWorld existe e é independente de Props
		assert_test(static_world != null, "%s: StaticWorld existe" % map_name)
		assert_test(props_node != null, "%s: World/Props existe" % map_name)
		assert_test(actors_node != null, "%s: World/Actors existe" % map_name)

		if static_world != null and props_node != null:
			assert_test(static_world != props_node, "%s: StaticWorld != Props (nós distintos)" % map_name)
			assert_test(not static_world.is_ancestor_of(props_node), "%s: Props NÃO é filho de StaticWorld" % map_name)
			assert_test(not props_node.is_ancestor_of(static_world), "%s: StaticWorld NÃO é filho de Props" % map_name)

		if props_node != null and actors_node != null:
			assert_test(props_node != actors_node, "%s: Props != Actors (nós distintos)" % map_name)
			assert_test(not props_node.is_ancestor_of(actors_node), "%s: Actors NÃO é filho de Props" % map_name)
			assert_test(not actors_node.is_ancestor_of(props_node), "%s: Props NÃO é filho de Actors" % map_name)

			# O player NÃO deve ser filho de Props
			var player: Node = inst.get_node_or_null("World/Actors/Player")
			if player != null:
				assert_test(not props_node.is_ancestor_of(player), "%s: Player NÃO é filho de Props" % map_name)
				assert_test(actors_node.is_ancestor_of(player), "%s: Player pertence estritamente a Actors" % map_name)

			# Inimigos NÃO devem ser filhos de Props
			var enemies: Node = inst.get_node_or_null("World/Actors/Enemies")
			if enemies != null:
				assert_test(not props_node.is_ancestor_of(enemies), "%s: Enemies NÃO é filho de Props" % map_name)
				assert_test(actors_node.is_ancestor_of(enemies), "%s: Enemies pertence estritamente a Actors" % map_name)

		# Limites perimetrais (WorldBoundaries) estão estritamente em StaticWorld
		var boundaries: StaticBody2D = inst.get_node_or_null("StaticWorld/WorldBoundaries") as StaticBody2D
		assert_test(boundaries != null, "%s: WorldBoundaries está em StaticWorld" % map_name)
		if boundaries != null:
			assert_test(not boundaries.is_in_group("props"), "%s: WorldBoundaries NÃO está no grupo 'props'" % map_name)
			assert_test(not boundaries.is_in_group("destructible_props"), "%s: WorldBoundaries NÃO é 'destructible_props'" % map_name)

		inst.free()

	# PARTE 2: Contrato Estrutural de DestructibleProp
	print("\n--- Validando Contrato Estrutural de DestructibleProp ---")
	var prop_scene: PackedScene = load("res://scenes/props/destructible_prop.tscn")
	assert_test(prop_scene != null, "DestructibleProp.tscn carrega com sucesso")

	if prop_scene != null:
		var prop_inst: Node = prop_scene.instantiate()
		assert_test(prop_inst != null, "DestructibleProp instanciado com sucesso")
		assert_test(prop_inst is DestructiblePropClass, "DestructibleProp possui classe fortemente tipada DestructibleProp")
		assert_test(prop_inst is StaticBody2D, "DestructibleProp é um StaticBody2D")

		# Grupos
		assert_test(prop_inst.is_in_group("props"), "DestructibleProp está no grupo 'props'")
		assert_test(prop_inst.is_in_group("destructible_props"), "DestructibleProp está no grupo 'destructible_props'")

		# Camadas de colisão física
		var body: StaticBody2D = prop_inst as StaticBody2D
		assert_test(body.collision_layer == 2, "DestructibleProp: collision_layer == 2 (Layer 2, Mundo Físico)")
		assert_test(body.collision_mask == 1, "DestructibleProp: collision_mask == 1 (Layer 1, Atores)")

		# Hierarquia de nós obrigatória:
		# DestructibleProp
		# ├── Visual
		# ├── CollisionShape2D
		# ├── Hurtbox
		# ├── Effects
		# └── NavigationIntegration
		var visual: Node2D = prop_inst.get_node_or_null("Visual") as Node2D
		var col_shape: CollisionShape2D = prop_inst.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var hurtbox: Area2D = prop_inst.get_node_or_null("Hurtbox") as Area2D
		var effects: Node2D = prop_inst.get_node_or_null("Effects") as Node2D
		var nav_int: NavigationObstacle2D = prop_inst.get_node_or_null("NavigationIntegration") as NavigationObstacle2D

		assert_test(visual != null, "Nó obrigatório 'Visual' existe")
		assert_test(col_shape != null, "Nó obrigatório 'CollisionShape2D' existe")
		assert_test(hurtbox != null, "Nó obrigatório 'Hurtbox' (Area2D) existe")
		assert_test(effects != null, "Nó obrigatório 'Effects' existe")
		assert_test(nav_int != null, "Nó obrigatório 'NavigationIntegration' (NavigationObstacle2D) existe")

		# Contrato de Hurtbox
		if hurtbox != null:
			assert_test(hurtbox.collision_layer == 4, "Hurtbox está na Layer 3 (bitmask 4)")
			assert_test(hurtbox.collision_mask == 0, "Hurtbox collision_mask == 0 (apenas receptora)")
			assert_test(hurtbox.monitoring == false, "Hurtbox.monitoring == false")
			assert_test(hurtbox.monitorable == true, "Hurtbox.monitorable == true")
			assert_test(hurtbox.get_node_or_null("CollisionShape2D") != null, "Hurtbox possui CollisionShape2D interno")

		# Contrato de NavigationObstacle2D
		if nav_int != null:
			assert_test(nav_int.avoidance_enabled == true, "NavigationIntegration possui avoidance_enabled ativado")

		root.add_child(prop_inst)

		# Simulação de Dano Estrutural
		var prop: Node = prop_inst
		var initial_health: float = prop.current_health
		assert_test(initial_health > 0.0, "Vida inicial do prop é positiva (%f)" % initial_health)

		var signal_tracker := {"damaged": false, "destroyed": false}
		prop.prop_damaged.connect(func(_amt: float, _hp: float) -> void: signal_tracker["damaged"] = true)
		prop.take_damage(10.0)

		assert_test(signal_tracker["damaged"], "Sinal 'prop_damaged' disparado ao receber dano")
		assert_test(prop.current_health == initial_health - 10.0, "Vida reduzida corretamente após dano")
		assert_test(not prop.is_broken, "Prop não quebra com dano sub-letal")

		# Simulação de Destruição
		prop.prop_destroyed.connect(func() -> void: signal_tracker["destroyed"] = true)
		prop.take_damage(prop.current_health)

		assert_test(signal_tracker["destroyed"], "Sinal 'prop_destroyed' disparado ao atingir vida 0")
		assert_test(prop.is_broken, "Prop marcado como quebrado (is_broken == true)")
		assert_test(not visual.visible, "Visual desativado após quebra")
		if nav_int != null:
			assert_test(not nav_int.avoidance_enabled, "NavigationObstacle2D desativado após destruição")

		root.remove_child(prop_inst)
		prop_inst.free()

	# PARTE 3: Compatibilidade regressiva com props existentes
	print("\n--- Validando Compatibilidade com Props Estáticos Existentes ---")
	var dummy_scene: PackedScene = load("res://scenes/actors/props/sorting_dummy.tscn")
	assert_test(dummy_scene != null, "SortingDummy existente carrega normalmente")
	if dummy_scene != null:
		var dummy_inst: Node = dummy_scene.instantiate()
		assert_test(dummy_inst is StaticBody2D, "SortingDummy é StaticBody2D")
		var dummy_body: StaticBody2D = dummy_inst as StaticBody2D
		assert_test(dummy_body.collision_layer == 2, "SortingDummy permanece na Layer 2")
		assert_test(dummy_body.collision_mask == 1, "SortingDummy permanece com Mask 1")
		dummy_inst.free()

	print("==================================================")
	print("RESULTADO DOS TESTES DE CONTRATO DE PROPS: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)
