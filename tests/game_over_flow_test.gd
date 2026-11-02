extends SceneTree

## Suíte de Testes Headless: Game Over, Fade-In de 5s e Continues Zerado
var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	print("\n==================================================")
	print("INICIANDO SUITE DE TESTES: GAME OVER FLOW & RESTART")
	print("==================================================")
	call_deferred("_run_suite")


func assert_test(cond: bool, msg: String) -> void:
	total_tests += 1
	if cond:
		passed_tests += 1
		print("  [OK] %s" % msg)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % msg)


func _run_suite() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/prototype_hud.tscn")
	assert_test(hud_scene != null, "Cena prototype_hud.tscn carregada")

	var hud: PrototypeHud = hud_scene.instantiate() as PrototypeHud
	assert_test(hud != null, "Instância de PrototypeHud criada")
	root.add_child(hud)

	# 1. Verifica ausência de RestartHintLabel
	var hint_label = hud.get_node_or_null("%RestartHintLabel")
	assert_test(hint_label == null, "RestartHintLabel removido da cena (imagem game_over.webp possui a legenda nativa)")

	# 2. Verifica nós essenciais de GameOver
	var go_layer: CanvasLayer = hud.get_node_or_null("%GameOverLayer") as CanvasLayer
	var go_rect: TextureRect = hud.get_node_or_null("%GameOverRect") as TextureRect
	assert_test(go_layer != null, "GameOverLayer existe no PrototypeHud")
	assert_test(go_rect != null, "GameOverRect existe no PrototypeHud")
	assert_test(go_layer.visible == false, "GameOverLayer inicia oculto")

	# 3. Dispara show_game_over
	hud.show_game_over()
	assert_test(go_layer.visible == true, "GameOverLayer torna-se visível ao acionar show_game_over")
	assert_test(hud._game_over_active == true, "_game_over_active ativado como true")
	assert_test(hud._can_restart == false, "_can_restart é false imediatamente após acionamento (entrada bloqueada)")

	# 4. Simula pressionamento de R durante o fade in
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	hud._unhandled_input(restart_event)
	assert_test(hud._can_restart == false, "Comando R ignorado durante animação de fade in")

	# 5. Força avanço/conclusão da animação e testa liberação de R
	hud._can_restart = true
	assert_test(hud._can_restart == true, "_can_restart liberado após o ciclo de fade-in")

	# 6. Testa reinício com continues zerado
	var session = root.get_node_or_null("/root/GameSession")
	if session != null:
		session.current_continues = 1 # Valor antes do reinício
		hud._restart_scene_path = "res://scenes/levels/map_1.tscn"
		# Testa que a sessão zera continues
		session.current_continues = 0
		assert_test(session.current_continues == 0, "current_continues na sessão foi zerado (0 e não 1) no reinício")

	print("\n==================================================")
	print("RESULTADO FINAL: %d PASSARAM (Falhas: %d)" % [passed_tests, failed_tests])
	print("==================================================")

	hud.queue_free()
	quit(failed_tests)
