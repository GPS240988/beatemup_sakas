extends SceneTree

func _init() -> void:
	var packed = load("res://scenes/ui/character_select.tscn")
	if packed == null:
		print("FAILED to load character_select.tscn")
		quit(1)
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_capture()

func _run_capture() -> void:
	await process_frame
	await process_frame
	await process_frame
	var img = root.get_viewport().get_texture().get_image()
	img.save_png("scratch/char_select_rendered.png")
	print("SUCCESS: Rendered character_select to scratch/char_select_rendered.png")
	quit(0)
