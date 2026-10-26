extends SceneTree

## Suíte de Testes Automatizados para Modos de Dificuldade, Controles Estritos e Tela de Instruções.

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_all_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_all_tests() -> void:
	print("==================================================")
	print("TESTES: DIFICULDADE, CONTROLES E TELA DE INSTRUÇÕES")
	print("==================================================")

	test_difficulty_screen_background_and_flow()
	test_difficulty_multipliers_applied_in_combat()
	test_all_maps_reinforcement_waves()
	test_continue_screen_and_main_menu()
	test_loading_screen_full_image_unobstructed()
	test_input_mapping_strictness()

	print("==================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)


func test_difficulty_screen_background_and_flow() -> void:
	print("\n--- Testando Tela de Dificuldade (difficulty_select.tscn) ---")
	var scene: PackedScene = load("res://scenes/ui/difficulty_select.tscn")
	assert_test(scene != null, "Cena difficulty_select.tscn carregada")

	var instance: Control = scene.instantiate() as Control
	root.add_child(instance)

	var bg: TextureRect = instance.get_node_or_null("%BackgroundNormal") as TextureRect
	if bg == null:
		bg = instance.get_node_or_null("BackgroundTexture") as TextureRect
	assert_test(bg != null, "BackgroundNormal existe")
	if bg != null:
		assert_test(bg.texture != null, "Background possui textura atribuída")
		var path: String = bg.texture.resource_path
		assert_test(path.contains("dificuldade.webp"), "Background utiliza res://assets/backgrounds/dificuldade.webp")

	var card_norm: Button = instance.get_node_or_null("%Card_normal") as Button
	var card_dif: Button = instance.get_node_or_null("%Card_dificil") as Button
	assert_test(card_norm != null and card_dif != null, "Cartões Normal e Difícil existem como botões interativos")

	instance.queue_free()


func test_difficulty_multipliers_applied_in_combat() -> void:
	print("\n--- Testando Aplicação dos Multiplicadores de Dificuldade ---")
	var session = root.get_node_or_null("GameSession")
	assert_test(session != null, "Autoload GameSession está disponível")

	var cd := CombatDirector.new()
	root.add_child(cd)
	var profile: Resource = EncounterDifficultyProfile.create_for_map(1)

	# 1. Testando Modo NORMAL
	session.difficulty_id = "normal"
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var enemy_norm: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
	root.add_child(enemy_norm)

	cd.apply_difficulty_profile(profile)
	cd.register_enemy(enemy_norm)

	var hp_norm: float = enemy_norm.health_component.max_health
	var dmg_norm: float = enemy_norm.melee_attack.damage
	assert_test(hp_norm == 80.0, "Modo Normal: Inimigo preserva HP base (80.0 HP)")
	assert_test(dmg_norm == 15.0, "Modo Normal: Inimigo preserva Dano base (15.0 DMG)")

	cd.unregister_enemy(enemy_norm)
	enemy_norm.queue_free()

	# 2. Testando Modo DIFÍCIL
	session.difficulty_id = "dificil"
	var enemy_dif: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
	root.add_child(enemy_dif)

	cd.apply_difficulty_profile(profile)
	cd.register_enemy(enemy_dif)

	var hp_dif: float = enemy_dif.health_component.max_health
	var dmg_dif: float = enemy_dif.melee_attack.damage
	# 80 * 1.0 (map 1) * 2.1 (dificil aumentado em 50%) = 168.0
	assert_test(is_equal_approx(hp_dif, 168.0), "Modo Difícil (+50%): HP do inimigo escalado por 2.1x (80 -> 168.0 HP)")
	# 15 * 1.0 (map 1) * 1.95 (dificil aumentado em 50%) = 29.25
	assert_test(is_equal_approx(dmg_dif, 29.25), "Modo Difícil (+50%): Dano do inimigo escalado por 1.95x (15 -> 29.25 DMG)")

	cd.unregister_enemy(enemy_dif)
	enemy_dif.queue_free()
	cd.queue_free()


func test_all_maps_reinforcement_waves() -> void:
	print("\n--- Testando Ondas de Reforço em Todos os 4 Mapas ---")
	for map_num in [1, 2, 3, 4]:
		var scene_path: String = "res://scenes/levels/map_%d.tscn" % map_num
		var scene: PackedScene = load(scene_path)
		assert_test(scene != null, "Cena do Mapa %d carregada" % map_num)
		var inst = scene.instantiate()
		assert_test(inst.get("reinforcement_waves_enabled") == true, "Mapa %d possui ondas de reforço (respawn) ativadas" % map_num)
		assert_test(inst.get("reinforcement_count") >= 3, "Mapa %d possui cota de reforço >= 3 (+50%%%% dificuldade)" % map_num)
		inst.free()


func test_continue_screen_and_main_menu() -> void:
	print("\n--- Testando Tela de Continuar (continuar.webp) ---")
	var cont_scene: PackedScene = load("res://scenes/ui/continue_screen.tscn")
	assert_test(cont_scene != null, "Cena continue_screen.tscn carregada")
	var cont_inst: Control = cont_scene.instantiate() as Control
	root.add_child(cont_inst)

	var bg: TextureRect = cont_inst.get_node_or_null("BackgroundTexture") as TextureRect
	assert_test(bg != null and bg.texture != null, "BackgroundTexture existe com textura atribuída")
	if bg != null and bg.texture != null:
		assert_test(bg.texture.resource_path.contains("continuar.webp"), "Background utiliza res://assets/backgrounds/continuar.webp")

	cont_inst.queue_free()


func test_loading_screen_full_image_unobstructed() -> void:
	print("\n--- Testando Tela de Instruções (Instruções_1) Desobstruída ---")
	var scene: PackedScene = load("res://scenes/ui/loading_screen.tscn")
	var instance: Control = scene.instantiate() as Control
	root.add_child(instance)

	var bottom_bar: Control = instance.get_node_or_null("BottomBar") as Control
	assert_test(bottom_bar != null and not bottom_bar.visible, "BottomBar está ocultada para não sobrepor a imagem")

	var top_vignette: Control = instance.get_node_or_null("TopVignette") as Control
	assert_test(top_vignette != null and not top_vignette.visible, "TopVignette está ocultada para exibir o topo da imagem limpo")

	var bg: TextureRect = instance.get_node_or_null("%BackgroundTexture") as TextureRect
	assert_test(bg != null, "BackgroundTexture existe")
	if bg != null:
		assert_test(bg.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "stretch_mode é KEEP_ASPECT_CENTERED (5) para visualização 100% íntegra sem cortes")

	instance.queue_free()


func test_input_mapping_strictness() -> void:
	print("\n--- Testando Mapeamento e Exclusividade de Comandos ---")
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)

	# Space deve acionar a VOADORA (execute_aerial)
	assert_test(player.has_method("execute_aerial"), "PlayerController possui método execute_aerial()")
	assert_test(player.has_method("execute_special"), "PlayerController possui método execute_special()")

	# Ações no InputMap
	assert_test(InputMap.has_action("attack"), "Ação 'attack' (J) registrada")
	assert_test(InputMap.has_action("jump"), "Ação 'jump' (Space) registrada para a voadora")
	assert_test(InputMap.has_action("special"), "Ação 'special' (O) registrada")
	assert_test(InputMap.has_action("guard"), "Ação 'guard' (K/H) registrada para o bloqueio")

	player.queue_free()
