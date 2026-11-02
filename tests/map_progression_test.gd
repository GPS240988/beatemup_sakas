extends SceneTree

## Suíte de Testes Automatizados Headless para a Progressão entre os Quatro Mapas e Indicador "SIGA →".

const BaseLevelClass = preload("res://scripts/levels/base_level.gd")
const SigaIndicatorClass = preload("res://scripts/ui/siga_indicator.gd")
const CombatDirectorClass = preload("res://scripts/combat/combat_director.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES DE PROGRESSÃO DE MAPAS (GODOT 4.x)")
	print("==================================================")

	test_siga_indicator_component()
	test_map_exit_locked_during_combat()
	test_map_exit_unlocked_and_siga_activated_after_combat()
	test_map_sequence_configuration()
	test_all_map_scenes_instantiation()

	print("==================================================")
	print("RESULTADO DOS TESTES DE PROGRESSÃO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
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


func test_siga_indicator_component() -> void:
	print("\n--- Testando Componente SigaIndicator ---")
	var scene: PackedScene = load("res://scenes/ui/siga_indicator.tscn")
	assert_test(scene != null, "Cena siga_indicator.tscn carregada com sucesso")

	var instance: SigaIndicator = scene.instantiate() as SigaIndicator
	root.add_child(instance)

	assert_test(instance.text == "SIGA →", "Texto padrão do indicador é rigorosamente 'SIGA →'")
	assert_test(not instance.visible and not instance.is_active(), "Indicador inicia oculto e inativo")

	instance.activate()
	assert_test(instance.visible and instance.is_active(), "Indicador torna-se visível e ativo após chamada activate()")

	instance.deactivate()
	assert_test(not instance.visible and not instance.is_active(), "Indicador é desativado e ocultado com sucesso")

	instance.free()


func test_map_exit_locked_during_combat() -> void:
	print("\n--- Testando Saída Bloqueada Durante Combate Ativo ---")
	var map_scene: PackedScene = load("res://scenes/levels/map_1.tscn")
	assert_test(map_scene != null, "Cena map_1.tscn carregada com sucesso")

	var map = map_scene.instantiate() as BaseLevel
	root.add_child(map)

	# 1. Verifica estado inicial
	assert_test(map.exit_area != null, "Área de saída (ExitArea) existe no mapa")
	assert_test(map.exit_area.monitoring == false, "Saída está DESABILITADA (monitoring = false) durante o combate")
	assert_test(map.siga_indicator != null, "Nó SigaIndicator existe no mapa")
	assert_test(map.siga_indicator.visible == false, "Indicador SIGA → está OCULTO enquanto houver combate ativo")

	map.free()


func test_map_exit_unlocked_and_siga_activated_after_combat() -> void:
	print("\n--- Testando Liberação da Saída e Ativação do SIGA → ---")
	var map_scene: PackedScene = load("res://scenes/levels/map_1.tscn")
	var map = map_scene.instantiate() as BaseLevel
	root.add_child(map)

	# Simula encerramento do combate via CombatDirector
	assert_test(map.combat_director != null, "CombatDirector existe no mapa")
	map._on_encounter_cleared()

	# 1. Saída deve ser habilitada
	assert_test(map.exit_area.monitoring == true, "Área de saída HABILITADA após conclusão do encontro")

	# 2. Indicador SIGA → deve ser ativado
	assert_test(map.siga_indicator.visible == true, "Indicador SIGA → VISÍVEL após conclusão do encontro")
	assert_test(map.siga_indicator.is_active() == true, "Indicador SIGA → ATIVO com efeito pulsante")

	map.free()


func test_map_sequence_configuration() -> void:
	print("\n--- Testando Cadeia Sequencial dos Quatro Mapas ---")

	# Mapa 1 -> Mapa 2
	var m1 = load("res://scenes/levels/map_1.tscn").instantiate() as BaseLevel
	assert_test(m1.map_index == 1, "Mapa 1 possui índice 1")
	assert_test(m1.next_map_scene_path == "res://scenes/levels/map_2.tscn", "Mapa 1 transiciona para map_2.tscn")
	assert_test(not m1.is_final_map, "Mapa 1 não é o mapa final")
	m1.free()

	# Mapa 2 -> Mapa 3
	var m2 = load("res://scenes/levels/map_2.tscn").instantiate() as BaseLevel
	assert_test(m2.map_index == 2, "Mapa 2 possui índice 2")
	assert_test(m2.next_map_scene_path == "res://scenes/levels/map_3.tscn", "Mapa 2 transiciona para map_3.tscn")
	assert_test(not m2.is_final_map, "Mapa 2 não é o mapa final")
	m2.free()

	# Mapa 3 -> Mapa 4
	var m3 = load("res://scenes/levels/map_3.tscn").instantiate() as BaseLevel
	assert_test(m3.map_index == 3, "Mapa 3 possui índice 3")
	assert_test(m3.next_map_scene_path == "res://scenes/levels/map_4.tscn", "Mapa 3 transiciona para map_4.tscn")
	assert_test(not m3.is_final_map, "Mapa 3 não é o mapa final")
	m3.free()

	# Mapa 4 -> Fim da Fase 1 (Vitória / Créditos)
	var m4 = load("res://scenes/levels/map_4.tscn").instantiate() as BaseLevel
	assert_test(m4.map_index == 4, "Mapa 4 possui índice 4")
	assert_test(m4.next_map_scene_path == "", "Mapa 4 não possui próximo mapa fictício (map_5 proibido)")
	assert_test(m4.is_final_map == true, "Mapa 4 é configurado como o mapa final da Fase 1")
	assert_test(m4.victory_scene_path == "res://scenes/ui/credits.tscn", "Mapa 4 encaminha para tela de vitória/créditos")
	m4.free()


func test_all_map_scenes_instantiation() -> void:
	print("\n--- Testando Integridade de Instanciação dos Quatro Mapas ---")
	var map_paths = [
		"res://scenes/levels/map_1.tscn",
		"res://scenes/levels/map_2.tscn",
		"res://scenes/levels/map_3.tscn",
		"res://scenes/levels/map_4.tscn"
	]

	for i in range(map_paths.size()):
		var path = map_paths[i]
		var scene: PackedScene = load(path)
		assert_test(scene != null, "Cena '%s' carregada com sucesso" % path)

		var inst = scene.instantiate() as BaseLevel
		assert_test(inst != null, "Instância do Mapa %d é um BaseLevel válido" % (i + 1))
		var player_node = inst.get_node_or_null("World/Actors/Player")
		if player_node == null:
			player_node = inst.get_node_or_null("World/Entities/Player")
		assert_test(player_node != null, "Mapa %d possui Player instanciado" % (i + 1))
		assert_test(inst.get_node_or_null("CombatDirector") != null, "Mapa %d possui CombatDirector" % (i + 1))
		assert_test(inst.get_node_or_null("ExitArea") != null, "Mapa %d possui ExitArea" % (i + 1))
		assert_test(inst.get_node_or_null("SigaIndicator") != null, "Mapa %d possui SigaIndicator" % (i + 1))
		
		# Verificações de Navegação e Arquitetura 2.5D (GAME_RULES.md Seção 3.6 e 3.8)
		var nav_region = inst.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
		assert_test(nav_region != null, "Mapa %d possui NavigationRegion2D" % (i + 1))
		assert_test(nav_region != null and nav_region.navigation_polygon != null, "Mapa %d possui NavigationPolygon configurado" % (i + 1))
		assert_test(nav_region != null and nav_region.navigation_polygon != null and nav_region.navigation_polygon.get_polygon_count() > 0, "Mapa %d possui polígonos de navegação válidos (> 0)" % (i + 1))
		
		var world_boundaries = inst.get_node_or_null("StaticWorld/WorldBoundaries") as StaticBody2D
		if world_boundaries == null:
			world_boundaries = inst.get_node_or_null("WorldBoundaries") as StaticBody2D
		assert_test(world_boundaries != null, "Mapa %d possui WorldBoundaries" % (i + 1))
		assert_test(world_boundaries != null and world_boundaries.collision_layer == 2, "Mapa %d possui WorldBoundaries na Layer 2" % (i + 1))
		inst.free()

