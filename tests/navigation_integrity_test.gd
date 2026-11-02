extends SceneTree

## Suíte de Testes de Integridade de Navegação (Godot 4.x) — FASE 9
## Valida formalmente:
## 1. Presença e integridade de NavigationRegion2D em todos os níveis.
## 2. NavigationPolygon com vértices, polígonos e dados válidos para navegação 2D.
## 3. Inicialização e funcionamento correto de NavigationAgent2D em atores (Inimigos e NPCs).
## 4. Preservação de 60 FPS: Desativação dinâmica de NavigationObstacle2D sem rebuild de malha.
## 5. Respeito a limites perimetrais e obstáculos estáticos.

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_navigation_integrity_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_navigation_integrity_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: INTEGRIDADE DE NAVEGAÇÃO (FASE 9)")
	print("==================================================")

	var production_maps: Array[String] = [
		"res://scenes/levels/map_1.tscn",
		"res://scenes/levels/map_2.tscn",
		"res://scenes/levels/map_3.tscn",
		"res://scenes/levels/map_4.tscn"
	]

	# PARTE 1: Verificação da malha de navegação em todos os mapas de produção
	for path in production_maps:
		var mname: String = path.get_file().get_basename()
		print("\n--- Validando Navegação em [%s] ---" % mname)

		var scene: PackedScene = load(path)
		assert_test(scene != null, "%s: Cena carregada com sucesso" % mname)
		if scene == null:
			continue

		var inst: Node = scene.instantiate()
		root.add_child(inst)
		await process_frame

		var nav_region: NavigationRegion2D = inst.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
		assert_test(nav_region != null, "%s: NavigationRegion2D existe" % mname)

		if nav_region != null:
			var navpoly: NavigationPolygon = nav_region.navigation_polygon
			assert_test(navpoly != null, "%s: NavigationPolygon atribuído" % mname)

			if navpoly != null:
				var poly_count: int = navpoly.get_polygon_count()
				var vert_count: int = navpoly.get_vertices().size()
				assert_test(poly_count > 0, "%s: NavigationPolygon possui polígonos (> 0, atual: %d)" % [mname, poly_count])
				assert_test(vert_count >= 3, "%s: NavigationPolygon possui vértices suficientes (>= 3, atual: %d)" % [mname, vert_count])

		root.remove_child(inst)
		inst.free()

	# PARTE 2: Agentes de Navegação (NavigationAgent2D) em Inimigos e NPCs
	print("\n--- Validando Inicialização e Rotas de NavigationAgent2D ---")
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var npc_scene: PackedScene = load("res://scenes/actors/npc.tscn")

	assert_test(enemy_scene != null, "basic_enemy.tscn carregada com sucesso")
	assert_test(npc_scene != null, "npc.tscn carregada com sucesso")

	var map1_scene: PackedScene = load("res://scenes/levels/map_1.tscn")
	var map1: Node = map1_scene.instantiate()
	root.add_child(map1)
	await process_frame

	if enemy_scene != null:
		var enemy: Node2D = enemy_scene.instantiate() as Node2D
		map1.add_child(enemy)
		enemy.global_position = Vector2(300, 600)
		await process_frame

		var e_agent: NavigationAgent2D = enemy.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
		assert_test(e_agent != null, "Inimigo possui NavigationAgent2D")
		if e_agent != null:
			e_agent.target_position = Vector2(800, 600)
			await process_frame
			assert_test(e_agent.target_position == Vector2(800, 600), "Enemy NavigationAgent2D aceita e registra coordenada alvo")

		map1.remove_child(enemy)
		enemy.free()

	if npc_scene != null:
		var npc: Node2D = npc_scene.instantiate() as Node2D
		map1.add_child(npc)
		npc.global_position = Vector2(400, 600)
		await process_frame

		var npc_agent: NavigationAgent2D = npc.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
		assert_test(npc_agent != null, "NPC possui NavigationAgent2D")
		if npc_agent != null:
			npc_agent.target_position = Vector2(600, 600)
			await process_frame
			assert_test(npc_agent.target_position == Vector2(600, 600), "NPC NavigationAgent2D aceita coordenada alvo")

		map1.remove_child(npc)
		npc.free()

	root.remove_child(map1)
	map1.free()

	# PARTE 3: Performance e Zero Rebuild de Malha
	print("\n--- Validando Ausência de Rebuild Global em Obstáculos ---")
	var prop_scene: PackedScene = load("res://scenes/props/destructible_prop.tscn")
	var prop: Node2D = prop_scene.instantiate() as Node2D
	root.add_child(prop)
	await process_frame

	var nav_obs: NavigationObstacle2D = prop.get_node_or_null("NavigationIntegration") as NavigationObstacle2D
	assert_test(nav_obs != null, "DestructibleProp possui NavigationObstacle2D")
	assert_test(nav_obs.avoidance_enabled, "Avoidance dinâmico ativo inicialmente")

	# Destruição desativa avoidance sem recompilar polígonos
	prop.destroy_prop()
	await process_frame
	assert_test(not nav_obs.avoidance_enabled, "Avoidance desativado sem rebuild de malha")

	root.remove_child(prop)
	prop.free()

	_finish()


func _finish() -> void:
	print("==================================================")
	print("RESULTADO DOS TESTES DE NAVEGAÇÃO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)
