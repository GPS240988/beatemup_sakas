extends SceneTree

const MAP6_PATH: String = "res://scenes/levels/map_6.tscn"
const MAP7_PATH: String = "res://scenes/levels/map_7.tscn"
const BACKGROUND_PATH: String = "res://assets/backgrounds/maps/fase2/Fase2_4.webp"
const TABLE_SCENE_PATH: String = "res://scenes/props/happen/dining_table_rectangular.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []

	if not ResourceLoader.exists(MAP7_PATH):
		failures.append("Map 7 não existe no caminho esperado.")
	if not ResourceLoader.exists(BACKGROUND_PATH):
		failures.append("Background Fase2_4.webp ausente.")
	if not ResourceLoader.exists(TABLE_SCENE_PATH):
		failures.append("Cena modular da mesa retangular ausente.")

	var map6_scene := load(MAP6_PATH) as PackedScene
	if map6_scene == null:
		failures.append("Map 6 não pôde ser carregado.")
	else:
		var map6 := map6_scene.instantiate()
		if str(map6.get("next_map_scene_path")) != MAP7_PATH:
			failures.append("Map 6 não aponta para o Map 7.")
		map6.free()

	var map7_scene := load(MAP7_PATH) as PackedScene
	if map7_scene == null:
		failures.append("Map 7 não pôde ser carregado.")
	else:
		var map7 := map7_scene.instantiate()
		var background := map7.get_node_or_null("Background/Far") as Sprite2D
		if background == null or background.texture == null:
			failures.append("Background/Far não possui textura.")
		elif background.texture.resource_path != BACKGROUND_PATH:
			failures.append("Map 7 não utiliza Fase2_4.webp.")

		if map7.get_node_or_null("World/Actors/Player") == null:
			failures.append("Player ausente em World/Actors/Player.")
		if map7.get_node_or_null("World/Props/StaticProps/RectangularTable01") == null:
			failures.append("Mesa retangular não integrada em StaticProps.")
		if map7.get_node_or_null("World/Props/StaticProps/CashierCounter") == null:
			failures.append("Balcão do caixa não integrado em StaticProps.")
		if map7.get_node_or_null("World/Actors/Enemies") == null:
			failures.append("Contêiner Enemies ausente.")
		if map7.get_node_or_null("World/Actors/NPCs/CashierSpawnPoint") == null:
			failures.append("Ponto de referência do caixa ausente.")
		for seat_id in ["happen_seat_01", "happen_seat_02", "happen_seat_03"]:
			var seat_found := false
			for marker in map7.get_node("SpawnPoints").get_children():
				if marker.get("point_id") == seat_id:
					seat_found = true
			if not seat_found:
				failures.append("Ponto de assento ausente: " + seat_id)
		if map7.get_node_or_null("CombatDirector") == null:
			failures.append("CombatDirector ausente.")
		var exit_area := map7.get_node_or_null("ExitArea") as Area2D
		if exit_area == null or exit_area.monitoring:
			failures.append("ExitArea deve existir e iniciar desativada até o encontro ser implementado.")

		var cashier := map7.get_node_or_null("World/Props/StaticProps/CashierCounter") as Node2D
		var cashier_spawn := map7.get_node_or_null("World/Actors/NPCs/CashierSpawnPoint") as Node2D
		if cashier != null and cashier_spawn != null:
			if cashier.position.y > 510.0:
				failures.append("CashierCounter deve ficar próximo à parede superior (Y <= 510).")
			if cashier_spawn.position.y < 455.0 or cashier_spawn.position.y >= cashier.position.y:
				failures.append("CashierSpawnPoint deve ficar atrás do CashierCounter com folga da parede superior.")
			if cashier.get_node_or_null("CounterSprite/RegisterSprite") == null:
				failures.append("RegisterSprite deve ser filho de CounterSprite para não brigar no Y-Sort.")

		var static_props := map7.get_node_or_null("World/Props/StaticProps")
		if static_props != null:
			for prop in static_props.get_children():
				if prop is Node2D:
					var prop_y: float = (prop as Node2D).position.y
					if prop_y < 440.0 or prop_y > 680.0:
						failures.append("Prop fora da área caminhável Y [440..680]: " + prop.name)
				var body := prop.get_node_or_null("Collision") as StaticBody2D
				if body == null or body.collision_layer != 2 or body.collision_mask != 1:
					failures.append("Prop sem Collision StaticBody2D (layer 2, mask 1): " + prop.name)

		var nav_region := map7.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
		if nav_region == null or nav_region.navigation_polygon == null:
			failures.append("NavigationRegion2D ou navigation_polygon ausente.")
		elif nav_region.navigation_polygon.get_polygon_count() < 10:
			failures.append("NavPoly do Map 7 deve conter recortes convexos (>= 10 polígonos) ao redor das mobílias.")

		var scaler := map7.get_node_or_null("YDepthScaler")
		if scaler == null or not is_equal_approx(float(scaler.get("far_lane_y")), 440.0) or not is_equal_approx(float(scaler.get("near_lane_y")), 680.0):
			failures.append("YDepthScaler deve estar calibrado para far_lane_y=440.0 e near_lane_y=680.0.")

		map7.free()

	var table_scene := load(TABLE_SCENE_PATH) as PackedScene
	if table_scene != null:
		var table := table_scene.instantiate()
		var sprite := table.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null:
			failures.append("Sprite da mesa retangular ausente.")
		else:
			var expected_scale := Vector2(0.2, 0.2)
			if not sprite.scale.is_equal_approx(expected_scale):
				failures.append("Escala da mesa retangular diverge de 0.20.")
			if sprite.texture == null or not Vector2(sprite.texture.get_size()).is_equal_approx(Vector2(1377, 648)):
				failures.append("Textura original da mesa retangular foi alterada.")
		table.free()

	if failures.is_empty():
		print("PASS: Map 6 → Map 7, background, props, âncoras e escala da mesa validados.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
