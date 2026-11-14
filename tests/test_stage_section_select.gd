extends SceneTree

func _init() -> void:
	print("--- TESTE UNITÁRIO & INTEGRAÇÃO: SELEÇÃO DE MAPAS DO ESTÁGIO 1 ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var passed := 0
	var total := 0

	# 1. Carregamento do GameSession
	var gs_scene := load("res://scripts/core/game_session.gd")
	if gs_scene == null:
		printerr("FALHA: Script GameSession não encontrado")
		quit(1)
		return

	var gs = gs_scene.new()
	gs.name = "GameSession"
	root.add_child(gs)

	total += 1
	if gs.has_method("is_stage_completed") and gs.has_method("complete_stage"):
		print("[PASS] GameSession possui métodos is_stage_completed e complete_stage")
		passed += 1
	else:
		printerr("[FAIL] GameSession não possui os métodos necessários")

	# Teste de estado inicial e conclusão
	total += 1
	gs.stage_1_completed = false
	gs.bonus_stage_unlocked = false
	gs.stage_2_unlocked = false
	gs.max_unlocked_stage = 1
	if not gs.is_stage_completed(1):
		print("[PASS] is_stage_completed(1) retorna false quando estágio não foi concluído")
		passed += 1
	else:
		printerr("[FAIL] is_stage_completed(1) deveria ser false")

	total += 1
	gs.complete_stage(1)
	if gs.is_stage_completed(1):
		print("[PASS] complete_stage(1) ativa is_stage_completed(1)")
		passed += 1
	else:
		printerr("[FAIL] complete_stage(1) não ativou is_stage_completed(1)")

	# Teste retrocompatibilidade: bonus_stage_unlocked ativa is_stage_completed(1)
	total += 1
	gs.stage_1_completed = false
	gs.bonus_stage_unlocked = true
	if gs.is_stage_completed(1):
		print("[PASS] bonus_stage_unlocked ativa retroativamente is_stage_completed(1)")
		passed += 1
	else:
		printerr("[FAIL] bonus_stage_unlocked deveria indicar estágio 1 concluído")

	# Teste de persistência e restauração
	total += 1
	gs.stage_1_completed = true
	gs._save_campaign_progression()
	gs.stage_1_completed = false
	gs.bonus_stage_unlocked = false
	gs._load_campaign_progression()
	if gs.is_stage_completed(1):
		print("[PASS] Persistência em disco: _save e _load mantêm stage_1_completed = true")
		passed += 1
	else:
		printerr("[FAIL] Persistência em disco falhou ao restaurar stage_1_completed")

	# 2. Teste do componente StageSectionSelect
	total += 1
	var sec_select_res := load("res://scenes/ui/components/stage_section_select.tscn")
	var sec_select = sec_select_res.instantiate()
	root.add_child(sec_select)

	var selected_path := ""
	sec_select.section_selected.connect(func(path: String, _name: String):
		selected_path = path
	)

	# Valida botões das 4 seções
	var expected_maps := [
		"res://scenes/levels/map_1.tscn",
		"res://scenes/levels/map_2.tscn",
		"res://scenes/levels/map_3.tscn",
		"res://scenes/levels/map_4.tscn"
	]
	var btn_vbox: VBoxContainer = sec_select.get_node_or_null("%ButtonsVBox")
	if btn_vbox != null and btn_vbox.get_child_count() == 4:
		print("[PASS] StageSectionSelect contém exatamente 4 opções de mapas (1-1, 1-2, 1-3, 1-4)")
		passed += 1
	else:
		printerr("[FAIL] StageSectionSelect deveria conter 4 botões de seção")

	# Testa acionamento de cada um dos 4 botões
	for i in range(expected_maps.size()):
		total += 1
		var btn = btn_vbox.get_child(i) as Button
		btn.emit_signal("pressed")
		if selected_path == expected_maps[i]:
			print("[PASS] Botão %d acionou corretamente o mapa: %s" % [i + 1, expected_maps[i]])
			passed += 1
		else:
			printerr("[FAIL] Esperado mapa '%s', mas obteve '%s'" % [expected_maps[i], selected_path])

	sec_select.queue_free()

	# 3. Teste de integração no MapMenu: comportamento dinâmico
	var map_menu_res := load("res://scenes/ui/map_menu.tscn")
	var map_menu = map_menu_res.instantiate()
	root.add_child(map_menu)

	var stage_sec = map_menu.get_node_or_null("%StageSectionSelect")

	# Cenário A: Estágio 1 NÃO completado -> clicar no estágio 1 NÃO abre o seletor de mapas
	total += 1
	gs.stage_1_completed = false
	gs.bonus_stage_unlocked = false
	map_menu._is_in_section_select = false
	if stage_sec != null:
		stage_sec.visible = false
	map_menu._on_hotspot_clicked(0)
	if stage_sec != null and not stage_sec.visible:
		print("[PASS] Cenário A: Com estágio incompleto, clicar no Estágio 1 NÃO abre seletor")
		passed += 1
	else:
		printerr("[FAIL] Cenário A: Seletor não deveria ter sido aberto")

	# Cenário B: Estágio 1 JÁ COMPLETADO -> clicar no estágio 1 ABRE o seletor de mapas
	total += 1
	gs.stage_1_completed = true
	map_menu._on_hotspot_clicked(0)
	if stage_sec != null and stage_sec.visible:
		print("[PASS] Cenário B: Com estágio concluído, clicar no Estágio 1 ABRE o seletor de 4 mapas")
		passed += 1
	else:
		printerr("[FAIL] Cenário B: Seletor DEVERIA ter sido aberto ao clicar no Estágio 1")

	# Cenário C: Botão JOGAR FASE / ESCOLHER SEÇÃO também abre o seletor quando concluído
	total += 1
	stage_sec.visible = false
	map_menu._is_in_section_select = false
	map_menu._selected_index = 0
	map_menu._on_play_stage_pressed()
	if stage_sec != null and stage_sec.visible:
		print("[PASS] Cenário C: Botão de ação com Estágio 1 selecionado abre o seletor")
		passed += 1
	else:
		printerr("[FAIL] Cenário C: Botão de ação deveria abrir o seletor")

	map_menu.queue_free()
	gs.queue_free()

	print("========================================")
	print("RESULTADO FINAL: %d/%d TESTES PASSARAM COM SUCESSO!" % [passed, total])
	print("========================================")

	quit(0 if passed == total else 1)
