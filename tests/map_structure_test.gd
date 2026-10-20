extends SceneTree

## Suíte de Testes Estruturais das Fases (Godot 4.x) — FASE 1
## Valida o contrato arquitetural obrigatório de separação física e semântica:
## StaticWorld, World/Props, World/Actors, Foreground, SpawnPoints, Navegação e Limites.

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_structural_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_structural_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES ESTRUTURAIS DAS FASES (GODOT 4.x)")
	print("==================================================")

	var official_maps: Array[String] = [
		"res://scenes/levels/map_1.tscn",
		"res://scenes/levels/map_2.tscn",
		"res://scenes/levels/map_3.tscn",
		"res://scenes/levels/map_4.tscn"
	]

	for i in range(official_maps.size()):
		var path: String = official_maps[i]
		var map_num: int = i + 1
		print("\n--- Testando Contrato Estrutural do Mapa %d (%s) ---" % [map_num, path.get_file()])

		# 1. Fase carrega
		var scene: PackedScene = load(path)
		assert_test(scene != null, "Mapa %d: Cena carrega com sucesso" % map_num)
		if scene == null:
			continue

		var inst: Node = scene.instantiate()
		assert_test(inst != null and inst is BaseLevel, "Mapa %d: Instância é um BaseLevel válido" % map_num)
		if inst == null:
			continue

		# 2. Background modular
		var bg_node: Node = inst.get_node_or_null("Background")
		assert_test(bg_node != null, "Mapa %d: Background existe" % map_num)
		if bg_node != null:
			assert_test(bg_node.get_node_or_null("Far") != null, "Mapa %d: Background/Far existe" % map_num)
			assert_test(bg_node.get_node_or_null("Mid") != null, "Mapa %d: Background/Mid existe" % map_num)
			assert_test(bg_node.get_node_or_null("BackProps") != null, "Mapa %d: Background/BackProps existe" % map_num)

		# 3. StaticWorld e WorldBoundaries
		var static_world: Node = inst.get_node_or_null("StaticWorld")
		assert_test(static_world != null, "Mapa %d: StaticWorld existe" % map_num)
		var boundaries: StaticBody2D = inst.get_node_or_null("StaticWorld/WorldBoundaries") as StaticBody2D
		assert_test(boundaries != null, "Mapa %d: WorldBoundaries existe dentro de StaticWorld" % map_num)
		if boundaries != null:
			assert_test(boundaries.collision_layer == 2, "Mapa %d: WorldBoundaries está na Layer 2" % map_num)
			assert_test(boundaries.get_node_or_null("TopWall") != null, "Mapa %d: TopWall existe" % map_num)
			assert_test(boundaries.get_node_or_null("BottomWall") != null, "Mapa %d: BottomWall existe" % map_num)
			assert_test(boundaries.get_node_or_null("LeftWall") != null, "Mapa %d: LeftWall existe" % map_num)
			assert_test(boundaries.get_node_or_null("RightWall") != null, "Mapa %d: RightWall existe" % map_num)

		# 4. World, Props e Actors
		var world_node: Node = inst.get_node_or_null("World")
		assert_test(world_node != null, "Mapa %d: World existe" % map_num)
		var props_node: Node = inst.get_node_or_null("World/Props")
		assert_test(props_node != null, "Mapa %d: Props existe dentro de World" % map_num)
		if props_node != null:
			assert_test(props_node.get_node_or_null("StaticProps") != null, "Mapa %d: StaticProps existe" % map_num)
			assert_test(props_node.get_node_or_null("Destructibles") != null, "Mapa %d: Destructibles existe" % map_num)

		var actors_node: Node = inst.get_node_or_null("World/Actors")
		assert_test(actors_node != null, "Mapa %d: Actors existe dentro de World" % map_num)
		if actors_node != null:
			assert_test(actors_node.get_node_or_null("Enemies") != null, "Mapa %d: Enemies container existe em Actors" % map_num)
			assert_test(actors_node.get_node_or_null("NPCs") != null, "Mapa %d: NPCs container existe em Actors" % map_num)

		# 5. Player
		var player_node: Node = inst.get_node_or_null("World/Actors/Player")
		assert_test(player_node != null, "Mapa %d: Player existe dentro de World/Actors" % map_num)
		if inst is BaseLevel:
			assert_test(inst.get_player() != null, "Mapa %d: BaseLevel.get_player() resolve o Player corretamente" % map_num)

		# 6. NavigationRegion2D e validação de polígonos
		var nav_region: NavigationRegion2D = inst.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
		assert_test(nav_region != null, "Mapa %d: NavigationRegion2D existe" % map_num)
		if nav_region != null:
			assert_test(nav_region.navigation_polygon != null, "Mapa %d: NavigationPolygon está configurado" % map_num)
			assert_test(nav_region.navigation_polygon != null and nav_region.navigation_polygon.get_polygon_count() > 0, "Mapa %d: navegação possui dados válidos (polígonos > 0)" % map_num)

		# 7. Foreground e SpawnPoints
		assert_test(inst.get_node_or_null("Foreground") != null, "Mapa %d: Foreground existe" % map_num)
		assert_test(inst.get_node_or_null("SpawnPoints") != null, "Mapa %d: SpawnPoints existe" % map_num)

		# 8. Orquestração (CombatDirector, ExitArea, SigaIndicator, PrototypeHud)
		assert_test(inst.get_node_or_null("CombatDirector") != null, "Mapa %d: CombatDirector existe" % map_num)
		assert_test(inst.get_node_or_null("ExitArea") != null, "Mapa %d: ExitArea existe" % map_num)
		assert_test(inst.get_node_or_null("SigaIndicator") != null, "Mapa %d: SigaIndicator existe" % map_num)
		assert_test(inst.get_node_or_null("PrototypeHud") != null, "Mapa %d: PrototypeHud existe" % map_num)

		inst.free()

	# Teste do Cenário Auxiliar TestStreet
	print("\n--- Testando Contrato Estrutural do Cenário TestStreet ---")
	var street_scene: PackedScene = load("res://scenes/levels/test_street.tscn")
	assert_test(street_scene != null, "TestStreet: Cena carrega com sucesso")
	if street_scene != null:
		var street_inst: Node = street_scene.instantiate()
		assert_test(street_inst != null, "TestStreet: Instância válida")
		assert_test(street_inst.get_node_or_null("World") != null, "TestStreet: World existe")
		assert_test(street_inst.get_node_or_null("World/Props") != null, "TestStreet: Props existe")
		assert_test(street_inst.get_node_or_null("World/Actors") != null, "TestStreet: Actors existe")
		assert_test(street_inst.get_node_or_null("World/Actors/Player") != null, "TestStreet: Player existe em World/Actors")
		assert_test(street_inst.get_node_or_null("StaticWorld/WorldBoundaries") != null, "TestStreet: WorldBoundaries existe em StaticWorld")
		assert_test(street_inst.get_node_or_null("CombatDirector") != null, "TestStreet: CombatDirector existe")
		assert_test(street_inst.get_node_or_null("ExitArea") != null, "TestStreet: ExitArea existe")
		street_inst.free()

	print("==================================================")
	print("RESULTADO DOS TESTES ESTRUTURAIS: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)
