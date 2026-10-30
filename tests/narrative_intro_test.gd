extends SceneTree

## Suíte de Testes Automatizados Headless: Sistema Narrativo e Abertura Cinemática (Saka's: A Última Ficha).
## Valida em estrita conformidade com Direcao_de_Arte.md, GAME_RULES.md e PADRAO_CENAS_APRESENTACAO.md:
## 1. Integridade dos recursos declarativos StoryEvent e StorySequence.
## 2. Validação da sequência declarativa res://resources/story/story_intro_map1.tres (CENA 01, 02, 03).
## 3. Presença e integridade dos assets cinematográficos em assets/story/map_1/.
## 4. Funcionamento do NarrativeDirector: avanço de texto, suspensão de combate, pular cena e áudio procedural.
## 5. Regras de Sessão: Novo Jogo reproduz prólogo; Continuar NÃO reproduz prólogo automaticamente.
## 6. Integração do LevelEventDirector com eventos de narrativa.
## 7. Validação da cena story_intro.tscn e transição segura pós-instruções.
## 8. Sistema de Enquadramento: proporção preservada (STRETCH_KEEP_ASPECT_CENTERED), filtro nearest e palco seguro.
## 9. Avanço Manual Estrito: ausência de temporizadores automáticos de avanço de texto.
## 10. Moldura Oficial 9-Patch e Tipografia Arcade: textura oficial e arcade_bold.ttf presentes.
## 11. Proteção e Isolamento de Input para Gameplay: descarte de ações para evitar pulo/golpe acidental.

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
	await test_level_event_director_narrative_integration()
	test_story_intro_scene_and_loading_transition()
	test_safe_framing_and_aspect_ratio()
	await test_manual_advance_and_no_timer_skips()
	test_official_dialogue_frame_and_typography()
	await test_input_isolation_for_gameplay()

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
	assert_test(events.size() == 7, "Sequência possui as 7 cenas canônicas do Roteiro (CENAS 01 a 07)")

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

	# CENA 04 — A Sala Secreta
	var c4: Resource = events[3]
	assert_test(c4.get("id") == "secret_room", "CENA 04 id é 'secret_room'")
	assert_test(str(c4.get("image_path")).contains("secret_room"), "CENA 04 aponta para secret_room.webp")
	var t4: Array = c4.get("texts")
	assert_test(t4.size() >= 2 and t4[0].contains("sala que ninguém conhecia"), "CENA 04 narra descoberta da sala")

	# CENA 05 — A Máquina (Revelação)
	var c5: Resource = events[4]
	assert_test(c5.get("id") == "arcade_machine", "CENA 05 id é 'arcade_machine'")
	assert_test(c5.get("event_type") == "revelation", "CENA 05 classificada como evento de revelação")
	assert_test(str(c5.get("image_path")).contains("arcade_machine"), "CENA 05 aponta para arcade_machine.webp")
	var t5: Array = c5.get("texts")
	assert_test(t5.has("INSERT COIN") and t5.has("4 PLAYERS DETECTED") and t5.has("CONTINUE?"), "CENA 05 exibe mensagens canônicas da máquina")

	# CENA 06 — Passado e Presente (Revelação Central)
	var c6: Resource = events[5]
	assert_test(c6.get("id") == "past_present", "CENA 06 id é 'past_present'")
	assert_test(c6.get("event_type") == "revelation", "CENA 06 classificada como evento de revelação")
	assert_test(str(c6.get("image_path")).contains("past_present"), "CENA 06 aponta para past_present.webp")
	var t6: Array = c6.get("texts")
	assert_test(t6.size() >= 3 and t6[2].contains("mesmo espaço"), "CENA 06 narra sobreposição temporal")

	# CENA 07 — Retorno à Locadora
	var c7: Resource = events[6]
	assert_test(c7.get("id") == "back_to_arcade", "CENA 07 id é 'back_to_arcade'")
	assert_test(str(c7.get("image_path")).contains("street_memory"), "CENA 07 aponta para street_memory.webp")
	var t7: Array = c7.get("texts")
	assert_test(t7.size() >= 2 and t7[1].contains("MAPA 1 — A LOCADORA"), "CENA 07 exibe identificação 'MAPA 1 — A LOCADORA'")


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

	session.reset_session()
	assert_test(session.has_played_intro == false, "Novo Jogo (reset_session) garante has_played_intro = false")

	session.has_played_intro = true
	assert_test(session.has_played_intro == true, "has_played_intro marcado como true após prólogo")

	session.has_played_intro = false
	# Simula carregamento de save
	session.save_game_to_slot(1, "res://scenes/levels/map_1.tscn", 100.0, 0.0)
	session.load_game_from_slot(1)
	assert_test(session.has_played_intro, "Continuar partida (load_game_from_slot) define has_played_intro = true automaticamente")

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

	event_dir.execute_event("narrative_sequence", {
		"sequence_path": "res://resources/story/story_intro_map1.tres"
	})

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

	var loading_script = load("res://scripts/ui/loading_screen.gd")
	assert_test("STORY_INTRO_SCENE" in loading_script and loading_script.STORY_INTRO_SCENE == intro_scene_path, "LoadingScreen possui constante STORY_INTRO_SCENE apontando para story_intro.tscn")


func test_safe_framing_and_aspect_ratio() -> void:
	print("\n--- 8. Validando Sistema de Enquadramento e Área Segura ---")
	var director_scene: PackedScene = load("res://scenes/ui/narrative_director.tscn")
	var nar = director_scene.instantiate()
	root.add_child(nar)

	var art_stage: Control = nar.get_node_or_null("%ArtStage")
	assert_test(art_stage != null, "ArtStage (palco dedicado de arte) existe na cena")
	if art_stage != null:
		assert_test(art_stage.anchor_bottom <= 0.76, "ArtStage termina acima de 76% da tela (garante que caixa inferior não encobre a arte)")

	var img_disp: TextureRect = nar.get_node_or_null("%ImageDisplay")
	assert_test(img_disp != null, "ImageDisplay existe no palco")
	if img_disp != null:
		assert_test(img_disp.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "ImageDisplay utiliza STRETCH_KEEP_ASPECT_CENTERED (sem corte de bordas)")
		assert_test(img_disp.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "ImageDisplay preserva nitidez de pixel art com filtro NEAREST")

	var amb_bg: TextureRect = nar.get_node_or_null("%AmbientBackground")
	assert_test(amb_bg != null, "AmbientBackground existe para preenchimento de aspectos fora de 16:9")

	root.remove_child(nar)
	nar.free()


func test_manual_advance_and_no_timer_skips() -> void:
	print("\n--- 9. Validando Avanço Estritamente Manual (Sem Temporizadores) ---")
	var director_scene: PackedScene = load("res://scenes/ui/narrative_director.tscn")
	var nar = director_scene.instantiate()
	root.add_child(nar)

	nar.play_sequence_from_path("res://resources/story/story_intro_map1.tres")
	# Aguarda conclusão do fade inicial (~0.35s)
	await create_timer(0.40).timeout

	# Avança CENA 01 (Title Card) para CENA 02 (The Four)
	nar.advance_or_skip_text()
	# Aguarda transição da imagem da CENA 02 (~0.35s)
	await create_timer(0.40).timeout

	var initial_text_index = nar.current_text_index
	var initial_event_index = nar.current_event_index

	# Aguarda 0.6s sem nenhuma interação: a fala NÃO pode mudar sozinha
	await create_timer(0.60).timeout

	assert_test(nar.current_event_index == initial_event_index, "Evento narrativo não avançou automaticamente sem input")
	assert_test(nar.current_text_index == initial_text_index, "Texto do diálogo permaneceu na tela sem avançar por timer")

	# Avanço manual via confirmação explícita
	nar.advance_or_skip_text()
	assert_test(nar.current_text_index == initial_text_index + 1, "Avanço manual avançou com sucesso para o próximo bloco")

	nar.skip_sequence()
	root.remove_child(nar)
	nar.free()


func test_official_dialogue_frame_and_typography() -> void:
	print("\n--- 10. Validando Moldura Oficial e Tipografia Arcade ---")
	var key_badge_tex_path := "res://assets/story/ui/enter_key_badge.png"
	var font_path := "res://assets/fonts/arcade_bold.ttf"

	assert_test(ResourceLoader.exists(key_badge_tex_path) or FileAccess.file_exists(ProjectSettings.globalize_path(key_badge_tex_path)), "Textura enter_key_badge.png existe no repositório")
	assert_test(ResourceLoader.exists(font_path) or FileAccess.file_exists(ProjectSettings.globalize_path(font_path)), "Fonte arcade_bold.ttf existe no repositório")

	var director_scene: PackedScene = load("res://scenes/ui/narrative_director.tscn")
	var nar = director_scene.instantiate()
	root.add_child(nar)

	var frame: Control = nar.get_node_or_null("%DialogueFrame")
	assert_test(frame != null, "DialogueFrame é um nó de moldura narrativa")
	if frame is PanelContainer:
		var style: StyleBox = frame.get_theme_stylebox("panel")
		assert_test(style != null, "DialogueFrame possui StyleBoxFlat estilizado")

	var speaker_badge: Control = nar.get_node_or_null("%SpeakerBadge")
	assert_test(speaker_badge != null, "SpeakerBadge existe na estrutura da moldura")

	var dial_lbl: Label = nar.get_node_or_null("%DialogueLabel")
	assert_test(dial_lbl != null, "DialogueLabel existe")
	if dial_lbl != null:
		assert_test(dial_lbl.autowrap_mode != TextServer.AUTOWRAP_OFF, "DialogueLabel possui autowrap ativado")
		assert_test(dial_lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "DialogueLabel possui alinhamento centralizado de impacto beat 'em up")
		assert_test(dial_lbl.get_theme_font_size("font_size") >= 22, "DialogueLabel possui tamanho de fonte destacado (>= 22px)")

	var key_badge: TextureRect = nar.get_node_or_null("%KeyBadge")
	assert_test(key_badge != null, "KeyBadge (ícone da tecla ENTER) existe no painel")

	var key_lbl: Label = nar.get_node_or_null("%KeyBadgeLabel")
	assert_test(key_lbl != null and key_lbl.text == "ENTER", "KeyBadge exibe 'ENTER' com estilo arcade")

	var prompt_lbl: Label = nar.get_node_or_null("%PromptLabel")
	assert_test(prompt_lbl != null and prompt_lbl.text.contains("PARA AVANÇAR"), "PromptLabel informa 'PARA AVANÇAR ❯'")

	root.remove_child(nar)
	nar.free()


func test_input_isolation_for_gameplay() -> void:
	print("\n--- 11. Validando Isolamento de Input para Gameplay ---")
	var intro_scene_path := "res://scenes/story/story_intro.tscn"
	var intro_scene: PackedScene = load(intro_scene_path)
	var instance: StoryIntroScene = intro_scene.instantiate() as StoryIntroScene
	root.add_child(instance)

	# Simula ação de pulo e ataque antes da transição
	Input.action_press("jump")
	Input.action_press("attack")

	# Dispara avanço e verifica se StoryIntroScene limpa os estados das ações
	instance._advance_to_game()

	assert_test(not Input.is_action_pressed("jump"), "Ação 'jump' liberada na saída da narrativa")
	assert_test(not Input.is_action_pressed("attack"), "Ação 'attack' liberada na saída da narrativa")

	root.remove_child(instance)
	instance.free()
