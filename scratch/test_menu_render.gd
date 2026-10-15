extends SceneTree

func _init() -> void:
	var scene = load("res://scenes/ui/main_menu.tscn")
	var instance = scene.instantiate()
	root.add_child(instance)
	
	# Aguardar renderização de um frame
	await process_frame
	await process_frame
	
	# Capturar imagem da viewport
	var img = root.get_texture().get_image()
	img.save_png("scratch/test_main_menu_viewport.png")
	print("Captured main menu viewport successfully!")
	quit(0)
