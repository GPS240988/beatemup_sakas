extends SceneTree

# Visual verification script for Sakas Arcade HUD
func _init() -> void:
	_run()

func _run() -> void:
	# Carrega a cena Map1
	var scene = load("res://scenes/levels/map_1.tscn")
	if scene == null:
		printerr("Falha ao carregar map_1.tscn")
		quit(1)
		return
	
	var map = scene.instantiate()
	root.add_child(map)
	
	# Aguarda frames de renderização para setup completo
	for i in range(15):
		await process_frame
	
	# Simula um alvo no EnemyHUD e um combo para verificação completa
	if map.hud != null:
		map.hud.set_combo_hits(8)
		# Encontra um inimigo e define como alvo
		var enemies = get_nodes_in_group("enemies")
		if enemies.size() > 0:
			map.hud.set_enemy_target(enemies[0], true)
			map.hud.update_enemy_health(50.0, 80.0)
	
	# Aguarda mais alguns frames para atualizar a tela
	for i in range(10):
		await process_frame
	
	# Captura o viewport
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png("scratch/hud_ingame_screenshot.png")
		print("Screenshot salva com sucesso em scratch/hud_ingame_screenshot.png")
	else:
		printerr("Erro ao capturar imagem do viewport")
	
	quit(0)
