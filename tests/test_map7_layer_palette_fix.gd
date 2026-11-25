extends SceneTree

const MAP7_PATH: String = "res://scenes/levels/map_7.tscn"
const RECT_TABLE_PATH: String = "res://scenes/props/happen/dining_table_rectangular.tscn"
const ROUND_TABLE_PATH: String = "res://scenes/props/happen/dining_table_round.tscn"
const EnemyAIClass = preload("res://scripts/actors/enemy_ai.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var map_scene := load(MAP7_PATH) as PackedScene
	if map_scene == null:
		push_error("Map 7 não pôde ser carregado.")
		quit(1)
		return

	var map := map_scene.instantiate()
	root.add_child(map)
	await process_frame

	var enemies := map.get_node_or_null("World/Actors/Enemies") as Node2D
	if enemies == null:
		failures.append("Contêiner de inimigos do Map 7 ausente.")
	else:
		if enemies.get_child_count() != 6:
			failures.append("Map 7 deve possuir seis inimigos após a reorganização.")
		if enemies.get_node_or_null("PizzaBrawler_RectBack") != null or enemies.get_node_or_null("PizzaBrawler_RoundBack") != null:
			failures.append("Os dois inimigos centrais das mesas ainda estão presentes.")

		var selected_palettes: Dictionary = {}
		for child in enemies.get_children():
			var enemy := child as EnemyAIClass
			if enemy == null:
				continue
			var palette: int = int(enemy.palette_variant)
			if palette == EnemyAIClass.PaletteVariant.AUTO or palette == EnemyAIClass.PaletteVariant.RANDOM:
				failures.append("Inimigo sem variante de paleta aplicada: " + enemy.name)
			selected_palettes[palette] = true
		if selected_palettes.size() < 5:
			failures.append("Map 7 deve distribuir as cinco paletas distintas antes de repetir.")

		var counter := enemies.get_node_or_null("PizzaBrawler_Counter") as Node2D
		var counter_side := enemies.get_node_or_null("PizzaBrawler_CounterSide") as Node2D
		if counter == null or counter_side == null:
			failures.append("Dupla de inimigos do balcão incompleta.")
		elif counter.global_position.distance_to(counter_side.global_position) > 230.0:
			failures.append("Novo inimigo não está posicionado ao lado do funcionário de costas.")
		elif not counter_side.has_method("is_in_ambient_standby") or not counter_side.is_in_ambient_standby():
			failures.append("Novo inimigo não inicia em pé aguardando a aproximação.")

	_validate_original_table(RECT_TABLE_PATH, 1377, 648, failures)
	_validate_original_table(ROUND_TABLE_PATH, 169, 144, failures)
	map.queue_free()

	if failures.is_empty():
		print("PASS: Map 7 remove os inimigos centrais, mantém as mesas originais e preserva as paletas.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _validate_original_table(path: String, expected_width: int, expected_height: int, failures: Array[String]) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		failures.append("Cena de mesa não pôde ser carregada: " + path)
		return

	var table := packed.instantiate()
	var sprite := table.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		failures.append("Mesa deve voltar a usar um único Sprite2D: " + path)
	else:
		if sprite.region_enabled:
			failures.append("Mesa não deve manter recortes artificiais da textura: " + path)
		if sprite.texture == null or sprite.texture.get_width() != expected_width or sprite.texture.get_height() != expected_height:
			failures.append("Dimensão/textura original da mesa foi alterada: " + path)
	if table.get_node_or_null("Collision/CollisionShape2D") == null:
		failures.append("Colisão da mesa foi removida: " + path)
	if table.get_node_or_null("TableBackLayer") != null or table.get_node_or_null("TableFrontLayer") != null:
		failures.append("Camadas extras de oclusão não devem ser necessárias com os assentos centrais vazios: " + path)
	table.free()
