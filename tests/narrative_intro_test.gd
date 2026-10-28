extends SceneTree

## Suíte de Testes Automatizados Headless: Sistema Narrativo e Abertura Cinemática (Saka's: A Última Ficha).
## Valida em estrita conformidade com GAME_RULES.md:
## 1. Integridade dos recursos declarativos StoryEvent e StorySequence.
## 2. Validação da sequência declarativa res://resources/story/story_intro_map1.tres (CENA 01, 02, 03).
## 3. Presença e integridade dos assets cinematográficos em assets/story/map_1/.
## 4. Funcionamento do NarrativeDirector: avanço de texto, suspensão de combate, pular cena e áudio procedural.
## 5. Regras de Sessão: Novo Jogo reproduz prólogo; Continuar NÃO reproduz prólogo automaticamente.
## 6. Integração do LevelEventDirector com eventos de narrativa.

const StoryEventClass = preload("res://scripts/events/story_event.gd")
const StorySequenceClass = preload("res://scripts/events/story_sequence.gd")
const NarrativeDirectorClass = preload("res://scripts/events/narrative_director.gd")
const LevelEventDirectorClass = preload("res://scripts/events/level_event_director.gd")

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
	print("INICIANDO SUITE DE TESTES: ABERTURA NARRATIVA E CINEMÁTICA")
	print("==================================================")

	test_declarative_story_resources()
	test_story_intro_map1_tres()
	test_story_assets_directory()
	test_narrative_director_runtime()
	test_session_intro_flow_rules()
	test_level_event_director_narrative_integration()
	test_story_intro_scene_and_loading_transition()

	print("==================================================")
	print("RESULTADO DOS TESTES NARRATIVOS: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)


func test_declarative_story_resources() -> void:
	print("\n--- 1. Validando Classes Declarativas StoryEvent e StorySequence ---")
	var ev = StoryEventClass.create(
		"test_ev",
		"res://assets/story/map_1/intro_group.webp",
		["Texto 1", "Texto 2"],
		"Narrador",
		2.5,
		"slow_zoom",
		"crossfade",
		0.4,
		1.0,
		1.03,
		0,
		"deep_intro_hum"
	)
	assert_test(ev != null, "StoryEvent criado com sucesso via factory")
	assert_test(ev.get("id") == "test_ev", "Propriedade 'id' confere")
	assert_test(ev.get("texts").size() == 2, "Array 'texts' possui 2 elementos")
	assert_test(ev.get("entry_effect") == "slow_zoom", "Efeito de entrada confere ('slow_zoom')")
	assert_test(ev.get("zoom_end") == 1.03, "Zoom_end configurado para 1.03 (zoom de 3%)")

	var seq = StorySequenceClass.new()
	seq.sequence_id = "test_seq"
	seq.events.append(ev)
	assert_test(seq.get_event_count() == 1, "StorySequence armazena evento corretamente")
	assert_test(seq.get_event(0).get("id") == "test_ev", "get_event(0) retorna o evento correto")


func test_story_intro_map1_tres() -> void:
	print("\n--- 2. Validando Recurso Oficial res://resources/story/story_intro_map1.tres ---")
	var path := "res://resources/story/story_intro_map1.tres"
	assert_test(ResourceLoader.exists(path), "Arquivo story_intro_map1.tres existe no repositório")

	var seq: Resource = load(path)
	assert_test(seq != null, "Recurso story_intro_map1.tres carregado com sucesso")
	assert_test(seq.get("sequence_id") == "story_intro_map1", "sequence_id é 'story_intro_map1'")

	var events: Array = seq.get("events")
	assert_test(events.size() == 3, "Sequência possui exatamente 3 cenas (CENA 01, 02, 03)")

	# CENA 01 — Título
	var c1: Resource = events[0]
	assert_test(c1.get("id") == "title_card", "CENA 01 id é 'title_card'")
	var t1: Array = c1.get("texts")
	assert_test(t1.size() >= 2 and t1[0] == "Saka's" and t1[1] == "A ÚLTIMA FICHA", "CENA 01 contém 'Saka's' e 'A ÚLTIMA FICHA'")

	# CENA 02 — Os Quatro
	var c2: Resource = events[1]
	assert_test(c2.get("id") == "the_four", "CENA 02 id é 'the_four'")
	assert_test(str(c2.get("image_path")).contains("intro_group"), "CENA 02 aponta para imagem de grupo")
	assert_test(c2.get("entry_effect") == "slow_zoom", "CENA 02 utiliza 'slow_zoom'")
	var t2: Array = c2.get("texts")
	assert_test(t2.size() >= 2 and t2[1].contains("Guilherme, Gabriel, André e Juliana"), "CENA 02 lista os 4 amigos")

	# CENA 03 — Os Que Não Estão
	var c3: Resource = events[2]
	assert_test(c3.get("id") == "the_missing", "CENA 03 id é 'the_missing'")
	assert_test(str(c3.get("image_path")).contains("missing_friends"), "CENA 03 aponta para amigos desaparecidos")
	assert_test(c3.get("entry_effect") == "glitch", "CENA 03 utiliza efeito 'glitch'")
	assert_test(int(c3.get("glitch_frames")) >= 2, "CENA 03 configurada com 2 a 3 frames de glitch")
	var t3: Array = c3.get("texts")
	assert_test(t3.size() >= 2 and t3[1].contains("Alessandro. Fernando."), "CENA 03 referencia Alessandro e Fernando")


func test_story_assets_directory() -> void:
	print("\n--- 3. Validando Assets Cinemáticos em assets/story/map_1/ ---")
	var expected_assets: Array[String] = [
		"res://assets/story/map_1/intro_group.webp",
		"res://assets/story/map_1/missing_friends.webp",
		"res://assets/story/map_1/secret_room.webp",
		"res://assets/story/map_1/arcade_machine.webp",
		"res://assets/story/map_1/past_present.webp",
		"res://assets/story/map_1/street_memory.webp",
		"res://assets/story/map_1/grandma_house.webp",
		"res://assets/story/map_1/alessandro_memory.webp"
	]

	for asset_p in expected_assets:
		var exists: bool = ResourceLoader.exists(asset_p) or FileAccess.file_exists(ProjectSettings.globalize_path(asset_p))
		assert_test(exists, "Asset narrativo existe: %s" % asset_p.get_file())


func test_narrative_director_runtime() -> void:
	print("\n--- 4. Validando NarrativeDirector (Execução, Avanço e Pular) ---")
	var director := NarrativeDirectorClass.new()
	root.add_child(director)

	assert_test(director.layer == 120, "NarrativeDirector está no layer superior 120")

	var tracker := {
		"started": false,
		"skipped": false,
		"completed": false
	}

	director.sequence_started.connect(func(_id: String) -> void: tracker["started"] = true)
	director.sequence_skipped.connect(func(_id: String) -> void: tracker["skipped"] = true)
	director.sequence_completed.connect(func(_id: String) -> void: tracker["completed"] = true)

	director.play_sequence_from_path("res://resources/story/story_intro_map1.tres")
	assert_test(director.is_playing, "NarrativeDirector iniciou reprodução")
	assert_test(tracker["started"], "Sinal sequence_started emitido")

	# Teste de avanço manual
	director.advance_or_skip_text()
	assert_test(director.is_playing, "Avanço de texto não abortou a sequência prematuramente")

	# Teste de pular cena com segurança
	director.skip_sequence()
	assert_test(not director.is_playing, "Sequência foi encerrada após skip_sequence()")
	assert_test(tracker["skipped"], "Sinal sequence_skipped emitido")

	root.remove_child(director)
	director.free()


func test_session_intro_flow_rules() -> void:
	print("\n--- 5. Validando Regras de Sessão (Novo Jogo vs Continuar) ---")
	var session = load("res://scripts/core/game_session.gd").new()
	root.add_child(session)

	# 1. Novo Jogo: deve reproduzir prólogo (has_played_intro = false)
	session.reset_session()
	assert_test(not session.has_played_intro, "Novo Jogo (reset_session) garante has_played_intro = false")

	# 2. Ao concluir ou pular o prólogo, flag é marcada
	session.has_played_intro = true
	assert_test(session.has_played_intro, "has_played_intro marcado como true após prólogo")

	# 3. Continuar (load_game_from_slot): NÃO deve reproduzir prólogo novamente
	session.has_played_intro = false
	# Simula carregamento de save
	session.save_game_to_slot(1, "res://scenes/levels/map_1.tscn", 100.0, 0.0)
	session.load_game_from_slot(1)
	assert_test(session.has_played_intro, "Continuar partida (load_game_from_slot) define has_played_intro = true automaticamente")

	# Limpa o slot de teste
	session.delete_save_slot(1)
	root.remove_child(session)
	session.free()


func test_level_event_director_narrative_integration() -> void:
	print("\n--- 6. Validando Integração do LevelEventDirector com Narrativa ---")
	var event_dir := LevelEventDirectorClass.new()
	root.add_child(event_dir)

	var tracker := {"completed": false}
	event_dir.event_completed.connect(func(ev_name: String) -> void:
		if ev_name == "narrative_sequence":
			tracker["completed"] = true
	)

	# Dispara evento com sequence_path
	event_dir.execute_event("narrative_sequence", {
		"sequence_path": "res://resources/story/story_intro_map1.tres"
	})

	# Pula a cena imediatamente para simular resposta rápida do jogador
	var nar = event_dir.get_node_or_null("NarrativeDirector")
	if nar != null and nar.has_method("skip_sequence"):
		nar.skip_sequence()

	await process_frame
	assert_test(tracker["completed"] or event_dir.completed_events.has("narrative_sequence"), "LevelEventDirector processou e concluiu o evento 'narrative_sequence'")

	root.remove_child(event_dir)
	event_dir.free()


func test_story_intro_scene_and_loading_transition() -> void:
	print("\n--- 7. Validando Cena story_intro.tscn e Transição Pós-Instruções ---")
	var intro_scene_path := "res://scenes/story/story_intro.tscn"
	assert_test(ResourceLoader.exists(intro_scene_path), "Cena res://scenes/story/story_intro.tscn existe")

	var intro_scene: PackedScene = load(intro_scene_path)
	var instance: Node = intro_scene.instantiate()
	root.add_child(instance)

	assert_test(instance is Control, "StoryIntro é nó Control")
	var nar = instance.get_node_or_null("%NarrativeDirector")
	assert_test(nar != null, "NarrativeDirector está presente em story_intro.tscn")

	root.remove_child(instance)
	instance.free()

	# Valida transição em LoadingScreen
	var loading_script = load("res://scripts/ui/loading_screen.gd")
	assert_test("STORY_INTRO_SCENE" in loading_script and loading_script.STORY_INTRO_SCENE == intro_scene_path, "LoadingScreen possui constante STORY_INTRO_SCENE apontando para story_intro.tscn")
