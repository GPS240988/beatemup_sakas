extends SceneTree

const MenuCharacterDataClass = preload("res://scripts/ui/menu_character_data.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var packed: PackedScene = load("res://scenes/ui/components/menu_character_slot.tscn") as PackedScene
	_assert(packed != null, "menu_character_slot.tscn carrega")
	if packed == null:
		_finish_test()
		return

	var slot := packed.instantiate() as Control
	_assert(slot != null, "MenuCharacterSlot instancia")
	if slot == null:
		_finish_test()
		return
	root.add_child(slot)
	await process_frame

	var characters := [
		{"data": MenuCharacterDataClass.create_guilherme(), "id": "guilherme", "path": "characters/guilherme/idle.png"},
		{"data": MenuCharacterDataClass.create_gabriel(), "id": "gabriel", "path": "characters/gabriel/idle.png"},
		{"data": MenuCharacterDataClass.create_andre(), "id": "andre", "path": "characters/andre/idle.png"},
		{"data": MenuCharacterDataClass.create_juliana(), "id": "juliana", "path": "characters/juliana/idle.png"}
	]

	for entry in characters:
		var data = entry["data"]
		_assert(data.get("is_active") == true, "%s está ativo" % String(entry["id"]))
		slot.call("apply_character_data", data)
		var texture := slot.get("character_texture") as TextureRect
		_assert(slot.visible, "%s pode ser exibido" % String(entry["id"]))
		_assert(texture != null and texture.texture != null, "%s carrega a textura" % String(entry["id"]))
		if texture != null and texture.texture != null:
			_assert(String(texture.texture.resource_path).ends_with(String(entry["path"])), "%s aponta para o idle correto" % String(entry["id"]))

		var visual := slot.get("sprite_container") as Control
		_assert(visual != null, "%s tem visual" % String(entry["id"]))
		if visual != null:
			_assert(is_equal_approx(visual.pivot_offset.y, visual.size.y), "%s ancora os pés no pivô inferior" % String(entry["id"]))
			slot.call("start_idle_loop")
			await create_timer(0.12).timeout
			_assert(visual.position == Vector2.ZERO, "%s respira sem subir/descer os pés" % String(entry["id"]))
			_assert(slot.get("_is_looping_idle") == true, "%s mantém o loop idle" % String(entry["id"]))

	slot.queue_free()
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
	print(" SLOT: %d passaram | %d falharam" % [passed, failed])
	print("========================================================\n")
	quit(0 if failed == 0 else 1)
