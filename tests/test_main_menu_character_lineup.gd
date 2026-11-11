extends SceneTree

## Valida a formação escalonada, as quatro texturas e a âncora de chão do menu.

var passed: int = 0
var failed: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var scene: PackedScene = load("res://scenes/ui/main_menu.tscn") as PackedScene
	_assert(scene != null, "main_menu.tscn carrega")
	if scene == null:
		_finish_test()
		return

	var menu := scene.instantiate() as Control
	_assert(menu != null, "MainMenu instancia")
	if menu == null:
		_finish_test()
		return

	root.add_child(menu)
	await process_frame
	await process_frame

	var lineup := menu.get_node_or_null("%CharactersLineup") as Control
	_assert(lineup != null, "CharactersLineup usa layout livre para formação")

	var expected := [
		{"node": "SlotGuilherme", "id": "guilherme", "path": "characters/guilherme/idle.png"},
		{"node": "SlotGabriel", "id": "gabriel", "path": "characters/gabriel/idle.png"},
		{"node": "SlotAndre", "id": "andre", "path": "characters/andre/idle.png"},
		{"node": "SlotJuliana", "id": "juliana", "path": "characters/juliana/idle.png"}
	]
	var measured_positions: Array[Vector2] = []

	for entry in expected:
		var slot := menu.get_node_or_null("%" + String(entry["node"])) as Control
		_assert(slot != null, "%s existe" % String(entry["node"]))
		if slot == null:
			continue

		_assert(slot.visible, "%s está visível" % String(entry["node"]))
		var data = slot.get("character_data")
		_assert(data != null, "%s recebeu dados" % String(entry["node"]))
		if data != null:
			_assert(data.get("id") == entry["id"], "%s usa dados do personagem correto" % String(entry["node"]))

		var texture := slot.get("character_texture") as TextureRect
		_assert(texture != null and texture.texture != null, "%s carregou idle.png" % String(entry["node"]))
		if texture != null and texture.texture != null:
			_assert(String(texture.texture.resource_path).ends_with(String(entry["path"])), "%s aponta para o idle correto" % String(entry["node"]))
			_assert(texture.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s preserva filtro nearest" % String(entry["node"]))

		var visual := slot.get("sprite_container") as Control
		_assert(visual != null, "%s tem SpriteContainer" % String(entry["node"]))
		if visual != null:
			_assert(is_equal_approx(visual.pivot_offset.y, visual.size.y), "%s tem pivô na linha dos pés" % String(entry["node"]))
			_assert(visual.position == Vector2.ZERO, "%s não usa deslocamento vertical para respirar" % String(entry["node"]))

		measured_positions.append(slot.position)

	_assert(measured_positions.size() == 4, "quatro posições de personagem foram calculadas")
	if measured_positions.size() == 4:
		var has_depth_stagger: bool = false
		for i in range(1, measured_positions.size()):
			if not is_equal_approx(measured_positions[i].y, measured_positions[0].y):
				has_depth_stagger = true
		_assert(has_depth_stagger, "formação usa profundidade em vez de uma fila nivelada")

	var btn_play := menu.get_node_or_null("%BtnPlay")
	var btn_continue := menu.get_node_or_null("%BtnContinue")
	var btn_settings := menu.get_node_or_null("%BtnSettings")
	var btn_quit := menu.get_node_or_null("%BtnQuit")
	_assert(btn_play != null and btn_play.visible, "JOGAR permanece visível")
	_assert(btn_continue != null and btn_continue.visible, "CONTINUAR permanece visível")
	_assert(btn_settings != null and btn_settings.visible, "CONFIGURAÇÕES permanece visível")
	_assert(btn_quit != null and btn_quit.visible, "SAIR permanece visível")

	menu.queue_free()
	_finish_test()


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % message)
	else:
		failed += 1
		printerr("  [FAIL] %s" % message)


func _finish_test() -> void:
	print("\n========================================================")
	print(" LINEUP: %d passaram | %d falharam" % [passed, failed])
	print("========================================================\n")
	quit(0 if failed == 0 else 1)
