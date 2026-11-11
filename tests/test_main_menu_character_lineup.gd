extends SceneTree

## Valida os quatro protagonistas, a formação assimétrica e a hierarquia de profundidade.

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

	var slots: Dictionary = {}
	for entry in expected:
		var node_name: String = String(entry["node"])
		var slot := menu.get_node_or_null("%" + node_name) as Control
		_assert(slot != null, "%s existe" % node_name)
		if slot == null:
			continue

		slots[node_name] = slot
		_assert(slot.visible, "%s está visível" % node_name)
		var data = slot.get("character_data")
		_assert(data != null, "%s recebeu dados" % node_name)
		if data != null:
			_assert(data.get("id") == entry["id"], "%s usa dados do personagem correto" % node_name)

		var texture := slot.get("character_texture") as TextureRect
		_assert(texture != null and texture.texture != null, "%s carregou idle.png" % node_name)
		if texture != null and texture.texture != null:
			_assert(String(texture.texture.resource_path).ends_with(String(entry["path"])), "%s aponta para o idle correto" % node_name)
			_assert(texture.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s preserva filtro nearest" % node_name)

		var visual := slot.get("sprite_container") as Control
		_assert(visual != null, "%s tem SpriteContainer" % node_name)
		if visual != null:
			_assert(is_equal_approx(visual.pivot_offset.y, visual.size.y), "%s tem pivô na linha dos pés" % node_name)
			_assert(visual.position == Vector2.ZERO, "%s não usa deslocamento vertical para respirar" % node_name)

	_assert(slots.size() == 4, "quatro slots independentes foram configurados")
	if slots.size() == 4:
		var andre: Control = slots["SlotAndre"]
		var guilherme: Control = slots["SlotGuilherme"]
		var juliana: Control = slots["SlotJuliana"]
		var gabriel: Control = slots["SlotGabriel"]

		_assert(andre.position.x < guilherme.position.x, "André ocupa o flanco esquerdo")
		_assert(guilherme.position.x < juliana.position.x, "Juliana fica no flanco direito intermediário")
		_assert(juliana.position.x < gabriel.position.x, "Gabriel ocupa o flanco posterior direito")
		_assert(andre.z_index < juliana.z_index, "André permanece no plano posterior")
		_assert(gabriel.z_index < juliana.z_index, "Gabriel permanece atrás de Juliana")
		_assert(juliana.z_index < guilherme.z_index, "Guilherme é desenhado no primeiro plano")
		var andre_ground_y: float = andre.position.y + (andre.size.y * andre.scale.y)
		var juliana_ground_y: float = juliana.position.y + (juliana.size.y * juliana.scale.y)
		var guilherme_ground_y: float = guilherme.position.y + (guilherme.size.y * guilherme.scale.y)
		_assert(andre_ground_y < juliana_ground_y, "André tem linha de chão posterior")
		_assert(juliana_ground_y < guilherme_ground_y, "Guilherme tem linha de chão frontal")

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
