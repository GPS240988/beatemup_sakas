extends SceneTree

## Teste unitário para validação do diálogo de derrota de Alessandro no Mapa 4
## e da transição da trilha sonora para a música de abertura da história.

const Map4Scene: PackedScene = preload("res://scenes/levels/map_4.tscn")
const Map4DefeatDialogueEventClass = preload("res://scripts/events/map4_defeat_dialogue.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, description: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] ", description)
	else:
		failed_tests += 1
		printerr("  [FALHA] ", description)


func _run_tests() -> void:
	print("\n========================================================")
	print("TESTE: DIÁLOGO DE DERROTA DE ALESSANDRO E BGM (MAPA 4)")
	print("========================================================")

	print("\n--- Teste 1: Contrato do Diálogo Map4DefeatDialogueEvent ---")
	var dialogue_event := Map4DefeatDialogueEventClass.new()
	_assert(dialogue_event != null, "Map4DefeatDialogueEvent instanciado com sucesso")
	_assert(dialogue_event.layer == 125, "CanvasLayer com prioridade canônica layer = 125")
	_assert(dialogue_event.process_mode == Node.PROCESS_MODE_ALWAYS, "Process mode configurado como ALWAYS para rodar pausado")

	var dialogues: Array[Dictionary] = dialogue_event.get_dialogues()
	_assert(dialogues.size() == 7, "Apresenta exatamente as 7 falas solicitadas")

	# Fala 0: Alessandro
	_assert(dialogues[0]["speaker"] == "ALESSANDRO", "Fala 1 é de ALESSANDRO")
	_assert(dialogues[0]["text"].begins_with("Argh... minha cabeça..."), "Fala 1 inicia com 'Argh... minha cabeça...'")
	_assert(dialogues[0]["portrait"] != null and dialogues[0]["portrait"].resource_path.ends_with("portrait_alessandro.png"), "Retrato de Alessandro associado à fala 1")

	# Fala 1: Guilherme
	_assert(dialogues[1]["speaker"] == "GUILHERME", "Fala 2 é de GUILHERME")
	_assert(dialogues[1]["text"].begins_with("Você surtou no meio da rua"), "Fala 2 repreende o surto de Alessandro")
	_assert(dialogues[1]["portrait"] != null and dialogues[1]["portrait"].resource_path.ends_with("portrait_guilherme.png"), "Retrato de Guilherme associado à fala 2")

	# Fala 2: Alessandro
	_assert(dialogues[2]["speaker"] == "ALESSANDRO", "Fala 3 é de ALESSANDRO")
	_assert(dialogues[2]["text"].contains("Estação Vila Prudente"), "Fala 3 menciona encontro com Fernando na Estação Vila Prudente")

	# Fala 3: Alessandro
	_assert(dialogues[3]["speaker"] == "ALESSANDRO", "Fala 4 é de ALESSANDRO")
	_assert(dialogues[3]["text"].contains("luzes do metrô começaram a piscar") and dialogues[3]["text"].contains("Fernando caído, morto"), "Fala 4 descreve o clarão e Fernando caído no metrô")

	# Fala 4: André
	_assert(dialogues[4]["speaker"] == "ANDRÉ", "Fala 5 é de ANDRÉ")
	_assert(dialogues[4]["text"].contains("Morto?! Não faz sentido") and dialogues[4]["text"].contains("anos 90 misturadas com hoje"), "Fala 5 de André questiona a quebra temporal da Vila Prudente")
	_assert(dialogues[4]["portrait"] != null and dialogues[4]["portrait"].resource_path.ends_with("portrait_andre.png"), "Retrato de André associado à fala 5")

	# Fala 5: Alessandro
	_assert(dialogues[5]["speaker"] == "ALESSANDRO", "Fala 6 é de ALESSANDRO")
	_assert(dialogues[5]["text"].contains("O tempo rachou ali dentro!"), "Fala 6 de Alessandro alerta sobre a fenda temporal")

	# Fala 6: Gabriel
	_assert(dialogues[6]["speaker"] == "GABRIEL", "Fala 7 é de GABRIEL")
	_assert(dialogues[6]["text"].contains("Vamos até a casa do Alessandro descansar e comer um churrasco."), "Fala 7 de Gabriel convida para churrasco na casa de Alessandro")
	_assert(dialogues[6]["portrait"] != null and dialogues[6]["portrait"].resource_path.ends_with("portrait_gabriel.png"), "Retrato de Gabriel associado à fala 7")

	dialogue_event.free()

	print("\n--- Teste 2: Trilha Sonora de Abertura da História ---")
	_assert(ResourceLoader.exists("res://assets/audio/bgm/Historia.mp3"), "Trilha oficial Historia.mp3 existe no projeto")

	print("\n--- Teste 3: Disparo do Diálogo e Troca de BGM no Mapa 4 ---")
	# Marcar intro como vista para que map4 entre diretamente no mundo de teste
	root.set_meta("map4_intro_seen", true)
	var map4 = Map4Scene.instantiate()
	root.add_child(map4)

	# Simular derrota do encontro do boss
	map4._boss_spawned = true
	map4.combat_director.pending_spawns_count = 0
	map4.reinforcement_waves_enabled = false

	# Chamar encerramento do encontro
	map4._on_encounter_cleared()

	_assert(map4._defeat_dialogue_seen, "Flag de diálogo de derrota foi marcada como executada")
	_assert(paused, "A fase foi pausada enquanto o diálogo de vitória está na tela")

	var active_dialogue: CanvasLayer = map4.find_child("Map4DefeatDialogueEvent", true, false) as CanvasLayer
	if active_dialogue == null:
		# Procurar pelo tipo
		for child in map4.get_children():
			if child is Map4DefeatDialogueEventClass:
				active_dialogue = child
				break
	_assert(active_dialogue != null, "Nó Map4DefeatDialogueEvent adicionado à árvore do mapa")

	# Validar se a música foi alterada para Historia.mp3
	var session = root.get_node_or_null("/root/GameSession")
	var bgm_ok: bool = false
	if session != null and session.has_method("get_current_bgm_path"):
		bgm_ok = (session.get_current_bgm_path() == "res://assets/audio/bgm/Historia.mp3")
	elif map4._level_bgm_player != null and map4._level_bgm_player.stream != null:
		bgm_ok = map4._level_bgm_player.stream.resource_path.ends_with("Historia.mp3")
	_assert(bgm_ok, "BGM foi alterado para a mesma música de abertura da história (Historia.mp3)")

	# Validar fechamento do diálogo
	if active_dialogue != null:
		active_dialogue.call("_close_dialogue")

	_assert(not paused, "A árvore de cena é despausada após fechar o diálogo de vitória")
	_assert(map4.exit_area != null and map4.exit_area.monitoring, "Área de saída do mapa 4 liberada para avançar")
	_assert(map4.siga_indicator != null and map4.siga_indicator.visible, "Indicador SIGA ativado para guiar até o bônus")

	map4.free()

	print("\n========================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("========================================================")
	quit(0 if failed_tests == 0 else 1)
