extends SceneTree

const MAP7_PATH: String = "res://scenes/levels/map_7.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var scene := load(MAP7_PATH) as PackedScene
	if scene == null:
		push_error("Map 7 não pôde ser carregado.")
		quit(1)
		return

	var map7 := scene.instantiate()
	root.add_child(map7)
	await process_frame

	var enemies := map7.get_node_or_null("World/Actors/Enemies")
	if enemies == null:
		failures.append("Contêiner de inimigos ausente.")
	else:
		if enemies.get_child_count() != 6:
			failures.append("Map 7 deve possuir seis inimigos após a reorganização.")
		if enemies.get_node_or_null("PizzaBrawler_RectBack") != null:
			failures.append("PizzaBrawler_RectBack ainda ocupa o centro da mesa retangular.")
		if enemies.get_node_or_null("PizzaBrawler_RoundBack") != null:
			failures.append("PizzaBrawler_RoundBack ainda ocupa o centro da mesa redonda.")
		var counter := enemies.get_node_or_null("PizzaBrawler_Counter") as Node2D
		var side := enemies.get_node_or_null("PizzaBrawler_CounterSide") as Node2D
		if counter == null or side == null:
			failures.append("Dupla de inimigos do balcão incompleta.")
		elif counter.global_position.distance_to(side.global_position) > 230.0:
			failures.append("Novo inimigo não está ao lado do funcionário de costas.")
		elif not side.has_method("is_in_ambient_standby") or not side.is_in_ambient_standby():
			failures.append("Novo inimigo não permanece em pé aguardando a aproximação.")

	var banter := map7.get_node_or_null("CounterBanter")
	if banter == null:
		failures.append("Controlador de conversa ambiental ausente.")
	else:
		if banter.get_dialogue_line_count() != 6:
			failures.append("A conversa ambiental deve conter seis falas curtas.")
		var combined_text := ""
		for index in range(banter.get_dialogue_line_count()):
			combined_text += str(banter.get_dialogue_line(index).get("text", "")).to_lower() + " "
		for keyword in ["azeda", "barata", "rato", "despensa", "pentelhos", "orégano"]:
			if not combined_text.contains(keyword):
				failures.append("A conversa não menciona o detalhe ambiental esperado: " + keyword)
		if banter.get_node_or_null("TriggerArea") == null:
			failures.append("Gatilho de proximidade da conversa não foi criado.")

	map7.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: elenco do Map 7 e conversa ambiental do balcão validados.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
