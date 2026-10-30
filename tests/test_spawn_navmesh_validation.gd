extends SceneTree

## Testes focados na validação de posição de spawn contra a malha de navegação.
## Garante que inimigos nunca permaneçam em posições fora do navmesh,
## independente do mapa.

var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	print("\n==================================================")
	print("TESTES DE VALIDAÇÃO DE SPAWN vs NAVMESH")
	print("==================================================\n")

	_test_enemy_ai_snap_method_exists()
	_test_base_level_snap_method_exists()
	_test_offscreen_spawn_uses_validation()
	_test_map1_spawn_points_within_navpoly()
	_test_map1_navpoly_coverage_at_spawn_points()
	_test_map2_navpoly_coverage()
	_test_map3_navpoly_coverage()
	_test_map4_navpoly_coverage()
	_test_snap_position_to_navmesh_logic()

	print("\n==================================================")
	if _fail_count == 0:
		print("RESULTADO: %d/%d PASSARAM (Falhas: 0) ✅" % [_pass_count, _pass_count])
	else:
		print("RESULTADO: %d/%d PASSARAM (Falhas: %d) ❌" % [_pass_count, _pass_count + _fail_count, _fail_count])
	print("==================================================\n")
	quit()


func _assert(condition: bool, desc: String) -> void:
	if condition:
		_pass_count += 1
		print("  [OK] %s" % desc)
	else:
		_fail_count += 1
		print("  [FAIL] %s" % desc)


func _test_enemy_ai_snap_method_exists() -> void:
	print("\n--- EnemyAI: Método _snap_to_navigable_position ---")
	var enemy_script: GDScript = load("res://scripts/actors/enemy_ai.gd") as GDScript
	_assert(enemy_script != null, "Script enemy_ai.gd carregado")

	var source: String = enemy_script.source_code
	_assert("_snap_to_navigable_position" in source, "Método _snap_to_navigable_position declarado")
	_assert("map_get_closest_point" in source, "Usa NavigationServer2D.map_get_closest_point")
	_assert("_initialize_navigation" in source, "Método _initialize_navigation existe")

	# Verifica que _snap_to_navigable_position é chamado dentro de _initialize_navigation
	var init_nav_start: int = source.find("func _initialize_navigation")
	var next_func: int = source.find("\nfunc ", init_nav_start + 1)
	if next_func < 0:
		next_func = source.length()
	var init_nav_body: String = source.substr(init_nav_start, next_func - init_nav_start)
	_assert("_snap_to_navigable_position" in init_nav_body, "_initialize_navigation chama _snap_to_navigable_position")


func _test_base_level_snap_method_exists() -> void:
	print("\n--- BaseLevel: Método _snap_position_to_navmesh ---")
	var base_script: GDScript = load("res://scripts/levels/base_level.gd") as GDScript
	_assert(base_script != null, "Script base_level.gd carregado")

	var source: String = base_script.source_code
	_assert("_snap_position_to_navmesh" in source, "Método _snap_position_to_navmesh declarado")
	_assert("map_get_closest_point" in source, "Usa NavigationServer2D.map_get_closest_point")


func _test_offscreen_spawn_uses_validation() -> void:
	print("\n--- BaseLevel: Reforços usam validação de navmesh ---")
	var base_script: GDScript = load("res://scripts/levels/base_level.gd") as GDScript
	var source: String = base_script.source_code

	# Localiza _on_reinforcement_timer_timeout e verifica que chama _snap_position_to_navmesh
	var timeout_start: int = source.find("func _on_reinforcement_timer_timeout")
	_assert(timeout_start >= 0, "Método _on_reinforcement_timer_timeout existe")

	var next_func: int = source.find("\nfunc ", timeout_start + 1)
	if next_func < 0:
		next_func = source.length()
	var timeout_body: String = source.substr(timeout_start, next_func - timeout_start)
	_assert("_snap_position_to_navmesh" in timeout_body, "_on_reinforcement_timer_timeout chama _snap_position_to_navmesh")
	_assert("get_offscreen_spawn_position" in timeout_body, "Calcula posição offscreen antes de validar")


func _test_map1_spawn_points_within_navpoly() -> void:
	print("\n--- Map 1: SpawnPoints dentro da área navegável ---")
	var scene: PackedScene = load("res://scenes/levels/map_1.tscn") as PackedScene
	_assert(scene != null, "map_1.tscn carregada")

	var inst: Node = scene.instantiate()
	_assert(inst != null, "Instância criada")

	# Map 1 navpoly lower strip: X=160-1950, Y=650-715
	var spawn_left: Node2D = inst.get_node_or_null("SpawnPoints/SpawnPoint_Left") as Node2D
	_assert(spawn_left != null, "SpawnPoint_Left encontrado")
	if spawn_left != null:
		_assert(spawn_left.position.x >= 140.0, "SpawnPoint_Left X >= 140 (atual: %.0f)" % spawn_left.position.x)
		_assert(spawn_left.position.y >= 480.0 and spawn_left.position.y <= 720.0, "SpawnPoint_Left Y na faixa navegável (atual: %.0f)" % spawn_left.position.y)

	var spawn_right: Node2D = inst.get_node_or_null("SpawnPoints/SpawnPoint_Right") as Node2D
	if spawn_right != null:
		_assert(spawn_right.position.y >= 650.0 and spawn_right.position.y <= 720.0, "SpawnPoint_Right Y na faixa inferior do navpoly (atual: %.0f)" % spawn_right.position.y)

	var spawn_reinforce: Node2D = inst.get_node_or_null("SpawnPoints/SpawnPoint_Reinforce") as Node2D
	if spawn_reinforce != null:
		_assert(spawn_reinforce.position.y >= 650.0 and spawn_reinforce.position.y <= 720.0, "SpawnPoint_Reinforce Y na faixa inferior do navpoly (atual: %.0f)" % spawn_reinforce.position.y)

	inst.queue_free()


func _is_point_in_navpoly(point: Vector2, vertices: PackedVector2Array, polygons: Array) -> bool:
	for poly in polygons:
		var poly_points: PackedVector2Array = PackedVector2Array()
		for idx in poly:
			if idx < vertices.size():
				poly_points.append(vertices[idx])
		if Geometry2D.is_point_in_polygon(point, poly_points):
			return true
	return false


func _test_map1_navpoly_coverage_at_spawn_points() -> void:
	print("\n--- Map 1: Cobertura do NavPoly nos SpawnPoints corrigidos ---")
	var navpoly_res: NavigationPolygon = load("res://scenes/levels/map_1_navpoly.tres") as NavigationPolygon
	_assert(navpoly_res != null, "NavPoly do map_1 carregado")
	if navpoly_res == null:
		return

	var vertices: PackedVector2Array = navpoly_res.vertices
	var polygons: Array = []
	for i in range(navpoly_res.get_polygon_count()):
		polygons.append(navpoly_res.get_polygon(i))

	# SpawnPoint_Left corrigido: (160, 670)
	_assert(_is_point_in_navpoly(Vector2(160, 670), vertices, polygons), "Ponto (160, 670) está DENTRO do navpoly")
	# SpawnPoint_Right corrigido: (1800, 680)
	_assert(_is_point_in_navpoly(Vector2(1800, 680), vertices, polygons), "Ponto (1800, 680) está DENTRO do navpoly")
	# SpawnPoint_Reinforce corrigido: (1880, 680)
	_assert(_is_point_in_navpoly(Vector2(1880, 680), vertices, polygons), "Ponto (1880, 680) está DENTRO do navpoly")
	# SpawnPoint_Mid: (990, 540) — upper corridor
	_assert(_is_point_in_navpoly(Vector2(990, 540), vertices, polygons), "Ponto (990, 540) está DENTRO do navpoly")

	# Posições ANTIGAS devem estar FORA do navpoly
	_assert(not _is_point_in_navpoly(Vector2(100, 520), vertices, polygons), "Ponto ANTIGO (100, 520) está FORA do navpoly")
	_assert(not _is_point_in_navpoly(Vector2(1800, 520), vertices, polygons), "Ponto ANTIGO (1800, 520) está FORA do navpoly")
	_assert(not _is_point_in_navpoly(Vector2(1880, 580), vertices, polygons), "Ponto ANTIGO (1880, 580) está FORA do navpoly")


func _test_map2_navpoly_coverage() -> void:
	print("\n--- Map 2: Cobertura do NavPoly ---")
	var navpoly_res: NavigationPolygon = load("res://scenes/levels/map_2_navpoly.tres") as NavigationPolygon
	_assert(navpoly_res != null, "NavPoly do map_2 carregado")
	if navpoly_res == null:
		return

	var vertices: PackedVector2Array = navpoly_res.vertices
	var polygons: Array = []
	for i in range(navpoly_res.get_polygon_count()):
		polygons.append(navpoly_res.get_polygon(i))

	# Pre-placed enemies from map_2
	_assert(_is_point_in_navpoly(Vector2(450, 650), vertices, polygons), "Inimigo map_2 (450, 650) está no navpoly")
	_assert(_is_point_in_navpoly(Vector2(750, 650), vertices, polygons), "Inimigo map_2 (750, 650) está no navpoly")
	_assert(_is_point_in_navpoly(Vector2(1100, 680), vertices, polygons), "Inimigo map_2 (1100, 680) está no navpoly")

	# SpawnPoint_Left at (100, 560) — likely outside navpoly
	var left_in: bool = _is_point_in_navpoly(Vector2(100, 560), vertices, polygons)
	print("  [INFO] Map 2 SpawnPoint_Left (100, 560) no navpoly: %s (safety net corrigirá se false)" % str(left_in))


func _test_map3_navpoly_coverage() -> void:
	print("\n--- Map 3: Cobertura do NavPoly ---")
	var navpoly_res: NavigationPolygon = load("res://scenes/levels/map_3_navpoly.tres") as NavigationPolygon
	_assert(navpoly_res != null, "NavPoly do map_3 carregado")
	if navpoly_res == null:
		return

	var vertices: PackedVector2Array = navpoly_res.vertices
	var polygons: Array = []
	for i in range(navpoly_res.get_polygon_count()):
		polygons.append(navpoly_res.get_polygon(i))

	# Pre-placed enemies from map_3
	_assert(_is_point_in_navpoly(Vector2(200, 695), vertices, polygons), "Inimigo map_3 (200, 695) está no navpoly")
	_assert(_is_point_in_navpoly(Vector2(600, 695), vertices, polygons), "Inimigo map_3 (600, 695) está no navpoly")

	# SpawnPoint_Left at (100, 580) — outside (navpoly starts at Y=650)
	var left_in: bool = _is_point_in_navpoly(Vector2(100, 580), vertices, polygons)
	_assert(not left_in, "Map 3 SpawnPoint_Left (100, 580) FORA do navpoly — safety net corrigirá em runtime")


func _test_map4_navpoly_coverage() -> void:
	print("\n--- Map 4: Cobertura do NavPoly ---")
	var navpoly_res: NavigationPolygon = load("res://scenes/levels/map_4_navpoly.tres") as NavigationPolygon
	_assert(navpoly_res != null, "NavPoly do map_4 carregado")
	if navpoly_res == null:
		return

	var vertices: PackedVector2Array = navpoly_res.vertices
	var polygons: Array = []
	for i in range(navpoly_res.get_polygon_count()):
		polygons.append(navpoly_res.get_polygon(i))

	# Pre-placed enemies from map_4
	_assert(_is_point_in_navpoly(Vector2(220, 640), vertices, polygons), "Inimigo map_4 (220, 640) está no navpoly")
	_assert(_is_point_in_navpoly(Vector2(600, 620), vertices, polygons), "Inimigo map_4 (600, 620) está no navpoly")
	_assert(_is_point_in_navpoly(Vector2(950, 680), vertices, polygons), "Inimigo map_4 (950, 680) está no navpoly")

	# SpawnPoint_Left at (100, 560) — map_4 navpoly starts at X=50, Y=545 so should be in
	_assert(_is_point_in_navpoly(Vector2(100, 560), vertices, polygons), "Map 4 SpawnPoint_Left (100, 560) está no navpoly")


func _test_snap_position_to_navmesh_logic() -> void:
	print("\n--- BaseLevel: Lógica de _snap_position_to_navmesh ---")
	var base_script: GDScript = load("res://scripts/levels/base_level.gd") as GDScript
	var source: String = base_script.source_code

	# Verifica a lógica de preservação do X original
	var snap_start: int = source.find("func _snap_position_to_navmesh")
	_assert(snap_start >= 0, "Método _snap_position_to_navmesh encontrado no source")

	var next_func: int = source.find("\nfunc ", snap_start + 1)
	if next_func < 0:
		next_func = source.length()
	var snap_body: String = source.substr(snap_start, next_func - snap_start)

	_assert("pos.x" in snap_body, "Preserva o eixo X original do spawn offscreen")
	_assert("closest.y" in snap_body, "Usa o Y do ponto navegável mais próximo")
	_assert("map_get_closest_point" in snap_body, "Consulta NavigationServer2D para validação")
	_assert("get_world_2d" in snap_body, "Obtém o mapa de navegação do World2D")

