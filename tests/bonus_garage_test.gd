extends SceneTree

## Suíte de Testes Automatizados Headless: Fase Bônus da Garagem (Fase 4)
## Valida geometria, câmera, colisões, Y-Sort, instâncias dos veículos e transição de campanha.

var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0


func _init() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: FASE BÔNUS DA GARAGEM")
	print("==================================================")

	_run_all_tests()

	print("==================================================")
	print("RESULTADO DOS TESTES: %d/%d PASSARAM (Falhas: %d)" % [_passed_tests, _total_tests, _failed_tests])
	print("==================================================")

	if _failed_tests > 0:
		quit(1)
	else:
		quit(0)


func _assert(condition: bool, test_name: String) -> void:
	_total_tests += 1
	if condition:
		_passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		_failed_tests += 1
		printerr("  [FAIL] %s" % test_name)


func _run_all_tests() -> void:
	_test_assets_exist()
	_test_map4_transition()
	_test_bonus_garage_scene_instantiation()
	_test_navpoly_resource()


func _test_assets_exist() -> void:
	print("\n--- 1. Validando Existência dos Assets Oficiais ---")
	_assert(FileAccess.file_exists("res://assets/backgrounds/maps/bonus1/garagem.webp"), "Cenário limpo garagem.webp existe")
	_assert(FileAccess.file_exists("res://assets/sprites/cars/fiesta_1.webp"), "Sprite do carro hatch laranja (fiesta_1.webp) existe")
	_assert(FileAccess.file_exists("res://assets/sprites/cars/escort_1.webp"), "Sprite do sedan azul (escort_1.webp) existe")
	_assert(FileAccess.file_exists("res://scenes/props/bonus_car_orange.tscn"), "Cena do carro laranja bonus_car_orange.tscn existe")
	_assert(FileAccess.file_exists("res://scenes/props/bonus_car_blue.tscn"), "Cena do carro azul bonus_car_blue.tscn existe")
	_assert(FileAccess.file_exists("res://scenes/levels/bonus_garage.tscn"), "Cena da fase bônus bonus_garage.tscn existe")
	_assert(FileAccess.file_exists("res://scenes/levels/bonus_garage_navpoly.tres"), "Recurso de navegação bonus_garage_navpoly.tres existe")


func _test_map4_transition() -> void:
	print("\n--- 2. Validando Progressão de Campanha (map_4 -> bonus_garage) ---")
	var map4_scene: PackedScene = load("res://scenes/levels/map_4.tscn")
	_assert(map4_scene != null, "Cena map_4.tscn carregada com sucesso")
	var map4 = map4_scene.instantiate()
	_assert(map4 != null, "Instância de map_4 criada com sucesso")
	_assert(map4.get("next_map_scene_path") == "res://scenes/levels/bonus_garage.tscn", "map_4.next_map_scene_path aponta para bonus_garage.tscn")
	_assert(map4.get("is_final_map") == false, "map_4 não é mais mapa final (avança para bônus)")
	map4.free()


func _test_bonus_garage_scene_instantiation() -> void:
	print("\n--- 3. Validando Cena e Arquitetura da Garagem Bônus ---")
	var garage_scene: PackedScene = load("res://scenes/levels/bonus_garage.tscn")
	_assert(garage_scene != null, "Cena bonus_garage.tscn carregada com sucesso")

	var garage = garage_scene.instantiate()
	_assert(garage != null, "Instância de bonus_garage criada com sucesso")
	_assert(garage is BaseLevel, "bonus_garage herda de BaseLevel")
	_assert(garage.stage_number == 1, "stage_number é 1")
	_assert(garage.map_group == "bonus1", "map_group é bonus1")
	_assert(garage.is_final_map == true, "bonus_garage é o mapa final da Fase 1")

	# Câmera e Limites
	var camera: Camera2D = garage.get_node_or_null("Camera2D") as Camera2D
	_assert(camera != null, "Nó Camera2D presente na cena")
	if camera != null:
		_assert(camera.limit_left == 0, "camera.limit_left é 0")
		_assert(camera.limit_top == 0, "camera.limit_top é 0")
		_assert(camera.limit_right == 1672, "camera.limit_right é 1672 (largura total da garagem)")
		_assert(camera.limit_bottom == 941, "camera.limit_bottom é 941 (altura total da garagem)")

	# Cenário Fundo Limpo
	var bg_sprite: Sprite2D = garage.get_node_or_null("Background/Far") as Sprite2D
	_assert(bg_sprite != null, "Sprite de fundo limpo presente em Background/Far")
	if bg_sprite != null and bg_sprite.texture != null:
		_assert("garagem.webp" in bg_sprite.texture.resource_path, "Fundo utiliza a imagem limpa garagem.webp")
		_assert(not "polygon" in bg_sprite.texture.resource_path, "Guia de polígonos NÃO é utilizado no fundo em execução")

	# Limites Físicos (StaticWorld / WorldBoundaries)
	var static_body: StaticBody2D = garage.get_node_or_null("StaticWorld/WorldBoundaries") as StaticBody2D
	_assert(static_body != null, "Nó StaticWorld/WorldBoundaries existe")
	if static_body != null:
		_assert((static_body.collision_layer & 2) != 0, "Colisão das paredes configurada no layer 2 (ambiente)")
		_assert(static_body.get_node_or_null("WallTop") != null, "WallTop existe")
		_assert(static_body.get_node_or_null("WallBottom") != null, "WallBottom existe")
		_assert(static_body.get_node_or_null("WallLeft") != null, "WallLeft existe")
		_assert(static_body.get_node_or_null("WallRight") != null, "WallRight existe")

	# Navegação
	var nav_region: NavigationRegion2D = garage.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	_assert(nav_region != null, "NavigationRegion2D presente na cena")
	if nav_region != null:
		_assert(nav_region.navigation_polygon != null, "navigation_polygon atribuído à NavigationRegion2D")

	# Y-Sort Hierarchy
	var world: Node2D = garage.get_node_or_null("World") as Node2D
	_assert(world != null and world.y_sort_enabled, "World existe e tem y_sort_enabled = true")
	var props: Node2D = garage.get_node_or_null("World/Props") as Node2D
	_assert(props != null and props.y_sort_enabled, "World/Props existe e tem y_sort_enabled = true")
	var vehicles: Node2D = garage.get_node_or_null("World/Props/Vehicles") as Node2D
	_assert(vehicles != null and vehicles.y_sort_enabled, "World/Props/Vehicles existe e tem y_sort_enabled = true")
	var actors: Node2D = garage.get_node_or_null("World/Actors") as Node2D
	_assert(actors != null and actors.y_sort_enabled, "World/Actors existe e tem y_sort_enabled = true")

	# Veículos (Carros)
	var car_orange = garage.get_node_or_null("World/Props/Vehicles/CarOrange")
	_assert(car_orange != null, "CarOrange presente na cena")
	if car_orange != null:
		_assert(car_orange.is_in_group("destructibles"), "CarOrange está no grupo destructibles")
		_assert(car_orange.is_in_group("props"), "CarOrange está no grupo props")
		_assert(car_orange.is_in_group("vehicles"), "CarOrange está no grupo vehicles")
		_assert((car_orange.collision_layer & 2) != 0, "CarOrange colide no layer 2 (sólido)")
		_assert(car_orange.position.x < 700, "CarOrange posicionado na baia esquerda (x < 700)")

	var car_blue = garage.get_node_or_null("World/Props/Vehicles/CarBlue")
	_assert(car_blue != null, "CarBlue presente na cena")
	if car_blue != null:
		_assert(car_blue.is_in_group("destructibles"), "CarBlue está no grupo destructibles")
		_assert(car_blue.is_in_group("props"), "CarBlue está no grupo props")
		_assert(car_blue.is_in_group("vehicles"), "CarBlue está no grupo vehicles")
		_assert((car_blue.collision_layer & 2) != 0, "CarBlue colide no layer 2 (sólido)")
		_assert(car_blue.position.x > 900, "CarBlue posicionado na baia direita (x > 900)")

	# Jogador
	var player = garage.get_node_or_null("World/Actors/Player")
	_assert(player != null, "Player presente em World/Actors/Player")
	if player != null:
		_assert(player is PlayerController, "Player é instância de PlayerController")
		# Jogador no vão frontal livre entre os carros
		_assert(player.position.x > 700 and player.position.x < 950, "Player posicionado no vão frontal aberto (700 < x < 950)")
		_assert(player.position.y > 650, "Player posicionado na área frontal livre (y > 650)")

	garage.free()


func _test_navpoly_resource() -> void:
	print("\n--- 4. Validando Recurso de Navegação ---")
	var navpoly: NavigationPolygon = load("res://scenes/levels/bonus_garage_navpoly.tres")
	_assert(navpoly != null, "Recurso bonus_garage_navpoly.tres carregado com sucesso")
	if navpoly != null:
		_assert(navpoly.get_polygon_count() > 0, "NavigationPolygon possui polígonos de navegação definidos")
		_assert(navpoly.vertices.size() >= 4, "NavigationPolygon possui vértices cobrindo a área da garagem")

