extends SceneTree

const CharacterSelectClass = preload("res://scripts/ui/character_select.gd")

var passed: int = 0
var failed: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n========================================================")
	print(" TESTE: FLUXO DE SELEÇÃO DE PERSONAGEM (GUILHERME & GABRIEL)")
	print("========================================================")

	# 1. Carrega e instancia a cena character_select.tscn
	var scn = load("res://scenes/ui/character_select.tscn") as PackedScene
	_assert(scn != null, "Cena character_select.tscn deve carregar sem erros")
	if scn == null:
		_finish_test()
		return

	var menu = scn.instantiate() as Control
	_assert(menu != null, "Cena deve instanciar com sucesso")
	_assert(menu is CharacterSelectClass, "Instância deve ser do tipo CharacterSelectMenu")
	root.add_child(menu)
	await process_frame

	var session = root.get_node_or_null("GameSession")
	_assert(session != null, "Autoload GameSession deve estar disponível")

	# 2. Validação do estado de novo jogo em GameSession
	_assert(session.is_character_unlocked("guilherme") == true, "Guilherme deve estar DESBLOQUEADO para novo jogo")
	_assert(session.is_character_unlocked("gabriel") == false, "Gabriel deve estar BLOQUEADO para novo jogo")
	_assert(session.is_character_unlocked("andre") == false, "André deve estar BLOQUEADO para novo jogo")
	_assert(session.is_character_unlocked("juliana") == false, "Juliana deve estar BLOQUEADA para novo jogo")

	# 3. Validação do estado inicial do menu (Guilherme selecionado)
	_assert(menu.get("current_index") == 0, "Índice inicial deve ser 0 (Guilherme)")
	_assert(menu.get("current_hover_id") == "guilherme", "Herói focado inicialmente deve ser 'guilherme'")

	var btn_confirm: Button = menu.get("btn_confirm")
	_assert(btn_confirm != null, "Botão btn_confirm deve existir")
	_assert(btn_confirm.disabled == false, "Botão btn_confirm deve estar HABILITADO para Guilherme")
	_assert(btn_confirm.text.contains("GUILHERME"), "Texto do botão deve conter 'GUILHERME' (atual='%s')" % btn_confirm.text)

	var status_label: Label = menu.get("status_label")
	_assert(status_label != null and status_label.text.contains("DISPONÍVEL"), "StatusLabel deve indicar 'DISPONÍVEL' para Guilherme")

	# 4. Testa avanço ao confirmar Guilherme
	session.selected_character_id = "" # Limpa para teste
	menu.call("_on_confirm_pressed")
	_assert(session.selected_character_id == "guilherme", "GameSession deve registrar 'guilherme' como personagem selecionado")
	_assert(menu.get("_is_transitioning_scene") == true, "Menu deve entrar em estado de transição de cena")

	# Reseta transição para testar Gabriel
	menu.set("_is_transitioning_scene", false)

	# 5. Alterna para Gabriel (índice 1)
	menu.call("_select_character_by_index", 1, false, 1)
	_assert(menu.get("current_index") == 1, "Índice deve ser 1 (Gabriel)")
	_assert(menu.get("current_hover_id") == "gabriel", "Herói focado deve ser 'gabriel'")
	_assert(btn_confirm.disabled == true, "Botão btn_confirm deve estar BLOQUEADO/DESABILITADO para Gabriel")
	_assert(btn_confirm.text.contains("BLOQUEADO"), "Texto do botão deve indicar 'BLOQUEADO' para Gabriel (atual='%s')" % btn_confirm.text)
	_assert(status_label.text.contains("BLOQUEADO"), "StatusLabel deve indicar 'BLOQUEADO' para Gabriel")

	# 6. Tenta confirmar Gabriel com Enter ou Clique (deve ser rejeitado)
	session.selected_character_id = ""
	menu.call("_on_confirm_pressed")
	_assert(session.selected_character_id == "", "Confirmação de Gabriel deve ser rejeitada, GameSession não deve selecionar Gabriel")
	_assert(menu.get("_is_transitioning_scene") == false, "Menu NÃO deve avançar de cena ao tentar selecionar Gabriel")

	# 7. Simula evento de Input (Enter) no Gabriel
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_ENTER
	key_event.pressed = true
	menu.call("_unhandled_input", key_event)
	_assert(session.selected_character_id == "", "Tecla Enter em Gabriel bloqueado NÃO deve avançar o jogo")
	_assert(menu.get("_is_transitioning_scene") == false, "Tecla Enter em Gabriel NÃO deve iniciar transição")

	# 8. Retorna para Guilherme (índice 0)
	menu.call("_select_character_by_index", 0, false, -1)
	_assert(menu.get("current_index") == 0, "Índice deve retornar a 0 (Guilherme)")
	_assert(menu.get("current_hover_id") == "guilherme", "Herói focado deve ser 'guilherme'")
	_assert(btn_confirm.disabled == false, "Botão btn_confirm deve estar HABILITADO novamente para Guilherme")

	# 9. Simula evento de Input (Enter) no Guilherme
	menu.call("_unhandled_input", key_event)
	_assert(session.selected_character_id == "guilherme", "Tecla Enter em Guilherme DEVE selecionar Guilherme")
	_assert(menu.get("_is_transitioning_scene") == true, "Tecla Enter em Guilherme DEVE avançar o jogo (transição iniciada)")

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
	print(" RESULTADOS DOS TESTES:")
	print("   Passaram: %d" % passed)
	print("   Falharam: %d" % failed)
	print("========================================================\n")

	if failed == 0:
		print(">> TODOS OS TESTES DE SELEÇÃO PASSARAM COM SUCESSO! <<\n")
		quit(0)
	else:
		printerr(">> HOUVE FALHAS NOS TESTES DE SELEÇÃO! <<\n")
		quit(1)
