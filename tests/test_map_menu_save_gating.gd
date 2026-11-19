extends SceneTree

# Teste automatizado de validação de gating do Menu de Mapa e Desbloqueio Progressivo de Fases

var passed: int = 0
var failed: int = 0

func _init() -> void:
	print("\n========================================================")
	print(" TESTE: GATING DO MENU DE MAPA & DESBLOQUEIO PROGRESSIVO")
	print("========================================================\n")
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	var session = root.get_node_or_null("GameSession")
	if session == null:
		session = GameSessionClass.new()
		session.name = "GameSession"
		root.add_child(session)

	# 1. Teste de Sessão Inicial sem save
	session.reset_session()
	session.max_unlocked_map = 0
	session.stage_1_completed = false
	session.bonus_stage_unlocked = false
	session.stage_2_unlocked = false
	session.max_unlocked_stage = 1

	var m1 = session.is_map_unlocked(1)
	var m2 = session.is_map_unlocked(2)
	var m3 = session.is_map_unlocked(3)
	var m4 = session.is_map_unlocked(4)

	_assert(not m1 and not m2 and not m3 and not m4, "Sem save: Mapas 1 a 4 devem estar bloqueados em is_map_unlocked")

	# 2. Teste de StageSectionSelect com 0 maps passados
	var section_select_scene = load("res://scenes/ui/components/stage_section_select.tscn") as PackedScene
	_assert(section_select_scene != null, "stage_section_select.tscn deve carregar")
	var section_select = section_select_scene.instantiate() as StageSectionSelect
	root.add_child(section_select)
	section_select.open()

	var btns = section_select._section_buttons
	_assert(btns.size() == 4, "Devem existir 4 botões de mapas")
	_assert(btns[0].disabled and btns[1].disabled and btns[2].disabled and btns[3].disabled, "Sem save: Todos os 4 botões de mapa devem estar desabilitados (disabled = true)")

	# 3. Teste quando o jogador passou o Map 1 (chegou no Map 2)
	session.max_unlocked_map = 1
	# Mock de has_any_save
	session.set_meta("test_has_save", true)
	section_select._update_section_lock_states()
	_assert(not btns[0].disabled, "Passou Map 1: Botão 1-1 deve estar habilitado")
	_assert(btns[1].disabled and btns[2].disabled and btns[3].disabled, "Passou Map 1: Botões 1-2, 1-3 e 1-4 devem continuar desabilitados")

	# 4. Teste quando o jogador passou o Map 2 (chegou no Map 3)
	session.max_unlocked_map = 2
	section_select._update_section_lock_states()
	_assert(not btns[0].disabled and not btns[1].disabled, "Passou Map 2: Botões 1-1 e 1-2 devem estar habilitados")
	_assert(btns[2].disabled and btns[3].disabled, "Passou Map 2: Botões 1-3 e 1-4 devem continuar desabilitados")

	# 5. Teste quando o jogador passou o Map 3 (chegou no Map 4)
	session.max_unlocked_map = 3
	section_select._update_section_lock_states()
	_assert(not btns[0].disabled and not btns[1].disabled and not btns[2].disabled, "Passou Map 3: Botões 1-1, 1-2 e 1-3 devem estar habilitados")
	_assert(btns[3].disabled, "Passou Map 3: Botão 1-4 deve continuar desabilitado")

	# 6. Teste quando o jogador completou o Map 4 (derrotou Alessandro)
	session.max_unlocked_map = 4
	session.stage_1_completed = true
	section_select._update_section_lock_states()
	_assert(not btns[0].disabled and not btns[1].disabled and not btns[2].disabled and not btns[3].disabled, "Completou Map 4: Todos os 4 botões devem estar habilitados")

	section_select.queue_free()

	# 7. Teste de MapMenu
	var map_menu_scene = load("res://scenes/ui/map_menu.tscn") as PackedScene
	_assert(map_menu_scene != null, "map_menu.tscn deve carregar")
	var map_menu = map_menu_scene.instantiate() as MapMenu
	root.add_child(map_menu)

	# No modo Novo Jogo (campaign), stage 0 está liberado para iniciar história
	map_menu.set("_entry_context", "campaign")
	_assert(map_menu.is_stage_unlocked(0) == true, "Modo campaign: Stage 0 (1-1) é desbloqueado para iniciar história")

	# No modo Continuar (continue), valida o gating direto de cada localidade no mapa mestre
	map_menu.set("_entry_context", "continue")
	session.max_unlocked_map = 2
	_assert(map_menu.is_stage_unlocked(0) == true, "Modo continue com max_unlocked_map=2: 1-1 está desbloqueado diretamente no mapa")
	_assert(map_menu.is_stage_unlocked(1) == true, "Modo continue com max_unlocked_map=2: 1-2 está desbloqueado diretamente no mapa")
	_assert(map_menu.is_stage_unlocked(2) == false, "Modo continue com max_unlocked_map=2: 1-3 permanece bloqueado no mapa")
	_assert(map_menu.is_stage_unlocked(3) == false, "Modo continue com max_unlocked_map=2: 1-4 permanece bloqueado no mapa")

	map_menu.queue_free()

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
