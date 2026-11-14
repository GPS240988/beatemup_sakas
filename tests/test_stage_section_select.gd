extends SceneTree

var _step: int = 0
var _passed: int = 0
var _total: int = 0
var _gs: Node = null
var _sec_select: Control = null
var _map_menu: Control = null
var _selected_path: String = ""

func _init() -> void:
	print("--- TESTE UNITÁRIO & INTEGRAÇÃO: SELEÇÃO DE MAPAS DO ESTÁGIO 1 ---")

func _process(_delta: float) -> bool:
	_step += 1
	match _step:
		1:
			_test_game_session()
		2:
			_test_stage_section_select()
		3:
			_test_map_menu_integration()
		4:
			_finish_tests()
			return true
	return false

func _test_game_session() -> void:
	_gs = root.get_node_or_null("GameSession")
	if _gs == null:
		var gs_scene := load("res://scripts/core/game_session.gd")
		if gs_scene == null:
			printerr("FALHA: Script GameSession não encontrado")
			quit(1)
			return
		_gs = gs_scene.new()
		_gs.name = "GameSession"
		root.add_child(_gs)

	_total += 1
	if _gs.has_method("is_stage_completed") and _gs.has_method("complete_stage"):
		print("[PASS] GameSession possui métodos is_stage_completed e complete_stage")
		_passed += 1
	else:
		printerr("[FAIL] GameSession não possui os métodos necessários")

	# Teste de estado inicial e conclusão
	_total += 1
	_gs.stage_1_completed = false
	_gs.bonus_stage_unlocked = false
	_gs.stage_2_unlocked = false
	_gs.max_unlocked_stage = 1
	if not _gs.is_stage_completed(1):
		print("[PASS] is_stage_completed(1) retorna false quando estágio não foi concluído")
		_passed += 1
	else:
		printerr("[FAIL] is_stage_completed(1) deveria ser false")

	_total += 1
	_gs.complete_stage(1)
	if _gs.is_stage_completed(1):
		print("[PASS] complete_stage(1) ativa is_stage_completed(1)")
		_passed += 1
	else:
		printerr("[FAIL] complete_stage(1) não ativou is_stage_completed(1)")

	# Teste retrocompatibilidade: bonus_stage_unlocked ativa is_stage_completed(1)
	_total += 1
	_gs.stage_1_completed = false
	_gs.bonus_stage_unlocked = true
	if _gs.is_stage_completed(1):
		print("[PASS] bonus_stage_unlocked ativa retroativamente is_stage_completed(1)")
		_passed += 1
	else:
		printerr("[FAIL] bonus_stage_unlocked deveria indicar estágio 1 concluído")

	# Teste de persistência e restauração
	_total += 1
	_gs.stage_1_completed = true
	_gs.bonus_stage_unlocked = false
	_gs.stage_2_unlocked = false
	_gs.max_unlocked_stage = 1
	_gs._save_campaign_progression()
	_gs.stage_1_completed = false
	_gs._load_campaign_progression()
	if _gs.is_stage_completed(1):
		print("[PASS] Persistência em disco: _save e _load mantêm stage_1_completed = true")
		_passed += 1
	else:
		printerr("[FAIL] Persistência em disco falhou ao restaurar stage_1_completed")

func _test_stage_section_select() -> void:
	var sec_select_res := load("res://scenes/ui/components/stage_section_select.tscn")
	_sec_select = sec_select_res.instantiate()
	root.add_child(_sec_select)

	_sec_select.section_selected.connect(func(path: String, _name: String):
		_selected_path = path
	)

	_total += 1
	if _sec_select._section_buttons.size() == 4:
		print("[PASS] StageSectionSelect contém exatamente 4 botões de mapas (1-1, 1-2, 1-3, 1-4)")
		_passed += 1
	else:
		printerr("[FAIL] StageSectionSelect deveria conter 4 botões de seção, encontrou: ", _sec_select._section_buttons.size())

	var expected_maps := [
		"res://scenes/levels/map_1.tscn",
		"res://scenes/levels/map_2.tscn",
		"res://scenes/levels/map_3.tscn",
		"res://scenes/levels/map_4.tscn"
	]

	for i in range(mini(_sec_select._section_buttons.size(), expected_maps.size())):
		_total += 1
		var btn: Button = _sec_select._section_buttons[i]
		btn.pressed.emit()
		if _selected_path == expected_maps[i]:
			print("[PASS] Botão %d acionou corretamente o mapa: %s" % [i + 1, expected_maps[i]])
			_passed += 1
		else:
			printerr("[FAIL] Esperado mapa '%s', mas obteve '%s'" % [expected_maps[i], _selected_path])

	_sec_select.queue_free()

func _test_map_menu_integration() -> void:
	var map_menu_res := load("res://scenes/ui/map_menu.tscn")
	_map_menu = map_menu_res.instantiate()
	root.add_child(_map_menu)

	var stage_sec = _map_menu.get_node_or_null("%StageSectionSelect")
	if stage_sec == null:
		stage_sec = _map_menu.get_node_or_null("StageSectionSelect")

	# Cenário A: Estágio 1 NÃO completado
	# Partindo do estágio B (index 1), clicar no Estágio 1 (index 0) apenas seleciona sem abrir o modal
	_total += 1
	_gs.stage_1_completed = false
	_gs.bonus_stage_unlocked = false
	_gs.stage_2_unlocked = false
	_gs.max_unlocked_stage = 1
	_gs._save_campaign_progression()
	_map_menu._selected_index = 1
	_map_menu._is_transitioning = false
	_map_menu._is_in_section_select = false
	if stage_sec != null:
		stage_sec.visible = false

	_map_menu._on_hotspot_clicked(0)
	if _map_menu._selected_index == 0 and stage_sec != null and not stage_sec.visible:
		print("[PASS] Cenário A: Com estágio incompleto, clicar no Estágio 1 seleciona sem abrir o seletor")
		_passed += 1
	else:
		printerr("[FAIL] Cenário A: Seletor não deveria ter sido aberto")

	# Cenário B: Estágio 1 JÁ COMPLETADO
	# Clicar no Estágio 1 (index 0) DEVE abrir o seletor de mapas
	_total += 1
	_gs.stage_1_completed = true
	_map_menu._is_transitioning = false
	_map_menu._is_in_section_select = false
	if stage_sec != null:
		stage_sec.visible = false

	_map_menu._on_hotspot_clicked(0)
	if stage_sec != null and stage_sec.visible:
		print("[PASS] Cenário B: Com estágio concluído, clicar no Estágio 1 ABRE o seletor de 4 mapas")
		_passed += 1
	else:
		printerr("[FAIL] Cenário B: Seletor DEVERIA ter sido aberto ao clicar no Estágio 1")

	# Cenário C: Botão de ação (JOGAR FASE / ESCOLHER SEÇÃO) com Estágio 1 selecionado abre o seletor
	_total += 1
	stage_sec.visible = false
	_map_menu._is_transitioning = false
	_map_menu._is_in_section_select = false
	_map_menu._selected_index = 0
	_map_menu._on_play_stage_pressed()
	if stage_sec != null and stage_sec.visible:
		print("[PASS] Cenário C: Botão de ação com Estágio 1 selecionado abre o seletor")
		_passed += 1
	else:
		printerr("[FAIL] Cenário C: Botão de ação deveria abrir o seletor")

	_map_menu.queue_free()

func _finish_tests() -> void:
	print("========================================")
	print("RESULTADO FINAL: %d/%d TESTES PASSARAM COM SUCESSO!" % [_passed, _total])
	print("========================================")
	quit(0 if _passed == _total else 1)
