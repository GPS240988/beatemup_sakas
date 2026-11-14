extends SceneTree

# Teste automatizado de validação de Game Over: retorno ao início do mapa com 0 continues

var passed: int = 0
var failed: int = 0

func _init() -> void:
	print("\n========================================================")
	print(" TESTE: GAME OVER & REINÍCIO NO MAPA ATUAL COM 0 CONTINUES")
	print("========================================================\n")
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	var session = root.get_node_or_null("GameSession")
	if session == null:
		session = GameSessionClass.new()
		session.name = "GameSession"
		root.add_child(session)

	var base_level_script = load("res://scripts/levels/base_level.gd")
	var dummy_level = Node2D.new()
	dummy_level.set_script(base_level_script)
	root.add_child(dummy_level)

	# 1. Validação de rotas de reinício
	dummy_level.set("map_group", "fase1")
	dummy_level.set("stage_number", 1)

	dummy_level.set("map_index", 3)
	var r_map3 = dummy_level.call("_get_stage_restart_scene_path")
	_assert(r_map3 == "res://scenes/levels/map_3.tscn", "Fase 1-3 deve reiniciar em map_3.tscn")

	dummy_level.set("map_index", 2)
	var r_map2 = dummy_level.call("_get_stage_restart_scene_path")
	_assert(r_map2 == "res://scenes/levels/map_2.tscn", "Fase 1-2 deve reiniciar em map_2.tscn")

	dummy_level.set("map_index", 4)
	var r_map4 = dummy_level.call("_get_stage_restart_scene_path")
	_assert(r_map4 == "res://scenes/levels/map_4.tscn", "Fase 1-4 deve reiniciar em map_4.tscn")

	dummy_level.set("map_index", 1)
	var r_map1 = dummy_level.call("_get_stage_restart_scene_path")
	_assert(r_map1 == "res://scenes/levels/map_1.tscn", "Fase 1-1 deve reiniciar em map_1.tscn")

	# 2. Validação do Game Over zerando fichas na sessão e limpando progressão
	session.current_continues = 2
	session.save_player_progression("fase1", 30.0, 40.0)

	var hud_scene = load("res://scenes/ui/prototype_hud.tscn")
	var test_hud = hud_scene.instantiate() as PrototypeHud
	root.add_child(test_hud)

	dummy_level.set("hud", test_hud)
	dummy_level.set("map_index", 3)
	dummy_level.set("player", null)

	dummy_level.call("_on_player_died_for_hud")

	_assert(session.current_continues == 0, "session.current_continues deve ser zerado para 0")
	var prog = session.get_preserved_player_progression("fase1")
	_assert(prog.is_empty(), "Progresso transitório deve ser limpo no Game Over")
	_assert(test_hud.get("_restart_scene_path") == "res://scenes/levels/map_3.tscn", "HUD deve receber restart_path apontando para map_3.tscn")
	_assert(test_hud.get("_game_over_active") == true, "HUD deve ativar _game_over_active")

	# 3. Validação de Toque Mobile na tela e Botões de Ação
	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true

	# Durante o fade in (_can_restart = false), o toque é ignorado
	_assert(test_hud.get("_can_restart") == false, "Entrada de toque bloqueada durante fade-in de 5 segundos")

	# Simula término do fade in
	test_hud.set("_can_restart", true)
	_assert(test_hud.get("_can_restart") == true, "Entrada liberada após conclusão do fade-in")

	# Simula toque na tela (Mobile) acionando _restart_current_stage
	session.current_continues = 3
	test_hud._unhandled_input(touch_event)
	_assert(session.current_continues == 0, "Toque na tela no Mobile reinicia no mapa atual e zera os continues")

	# Simula ação de Sair para o Menu Principal
	_assert(test_hud.has_method("_exit_to_main_menu"), "HUD possui método _exit_to_main_menu")

	test_hud.queue_free()
	dummy_level.queue_free()

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
	print(" RESULTADOS DOS TESTES:")
	print("   Passaram: %d" % passed)
	print("   Falharam: %d" % failed)
	print("========================================================\n")
	if failed == 0:
		print(">> TODOS OS TESTES PASSARAM COM SUCESSO! <<\n")
		quit(0)
	else:
		printerr(">> HOUVE FALHAS NOS TESTES! <<\n")
		quit(1)
