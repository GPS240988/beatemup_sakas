extends SceneTree

func _init() -> void:
	_run()

func _run() -> void:
	var hud_scene = load("res://scenes/ui/prototype_hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	print("HpBar custom_minimum_size: ", hud.player_hud.hp_bar.custom_minimum_size)
	print("SpecialBar custom_minimum_size: ", hud.player_hud.special_bar.custom_minimum_size)
	print("HpBar size: ", hud.player_hud.hp_bar.size)
	print("SpecialBar size: ", hud.player_hud.special_bar.size)
	quit()
