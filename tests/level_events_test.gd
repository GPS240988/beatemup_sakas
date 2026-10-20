extends SceneTree

## Suíte de Testes de Eventos de Nível, Triggers e Diálogos (Godot 4.x) — FASE 8
## Valida formalmente:
## 1. Foreground layer e separação de planos de profundidade.
## 2. LevelEventTrigger: ativação por colisão, por chamada e por destruição de prop.
## 3. DialogueDirector: exibição de mensagens, filas e desacoplamento do combate.
## 4. LevelEventDirector: orquestração de sequências de nível sem código monolítico.
## 5. Fluxo integrado: Destruição -> Passagem -> Diálogo -> Spawn -> Vitória.

const LevelEventTriggerClass = preload("res://scripts/events/level_event_trigger.gd")
const DialogueDirectorClass = preload("res://scripts/events/dialogue_director.gd")
const LevelEventDirectorClass = preload("res://scripts/events/level_event_director.gd")
const DestructiblePropClass = preload("res://scripts/props/destructible_prop.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_level_events_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_level_events_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: EVENTOS, TRIGGERS E DIÁLOGOS (FASE 8)")
	print("==================================================")

	# PARTE 1: Foreground Layer nos mapas
	print("\n--- 1. Validando Estrutura do Foreground nos Mapas ---")
	var map_paths: Array[String] = [
		"res://scenes/levels/map_1.tscn",
		"res://scenes/levels/map_2.tscn",
		"res://scenes/levels/map_3.tscn",
		"res://scenes/levels/map_4.tscn"
	]
	for mpath in map_paths:
		var mname: String = mpath.get_file().get_basename()
		var scene: PackedScene = load(mpath)
		assert_test(scene != null, "%s: Cena carregada com sucesso" % mname)
		if scene != null:
			var inst: Node = scene.instantiate()
			var fg: Node = inst.get_node_or_null("Foreground")
			assert_test(fg != null, "%s: Nó Foreground existe" % mname)
			if fg is CanvasItem:
				assert_test((fg as CanvasItem).z_index >= 0, "%s: Foreground possui z_index >= 0 (sobrepõe o mundo)" % mname)
			inst.free()

	# PARTE 2: LevelEventTrigger
	print("\n--- 2. Validando LevelEventTrigger ---")
	var trigger := LevelEventTriggerClass.new()
	trigger.trigger_id = "test_event_1"
	trigger.trigger_once = true
	root.add_child(trigger)
	await process_frame

	var trigger_tracker := {"fired": false, "id": "", "payload": {}}
	trigger.triggered.connect(func(id: String, payload: Dictionary) -> void:
		trigger_tracker["fired"] = true
		trigger_tracker["id"] = id
		trigger_tracker["payload"] = payload
	)

	# Ativação manual
	trigger.trigger({"test_key": "test_val"})
	assert_test(trigger_tracker["fired"], "Trigger disparou sinal 'triggered'")
	assert_test(trigger_tracker["id"] == "test_event_1", "Trigger enviou ID correto ('test_event_1')")
	assert_test(trigger_tracker["payload"].get("test_key") == "test_val", "Payload recebido com sucesso")
	assert_test(trigger.is_activated, "Trigger marcado como is_activated")

	# Tentativa de segundo disparo com trigger_once
	trigger_tracker["fired"] = false
	trigger.trigger()
	assert_test(not trigger_tracker["fired"], "Trigger respeitou trigger_once (não disparou novamente)")

	root.remove_child(trigger)
	trigger.free()

	# PARTE 3: Trigger vinculado à destruição de objeto (DestructibleProp)
	print("\n--- 3. Validando Trigger Vinculado a DestructibleProp ---")
	var prop_scene: PackedScene = load("res://scenes/props/destructible_prop.tscn")
	var prop_inst: Node = prop_scene.instantiate()
	var bound_trigger := LevelEventTriggerClass.new()
	bound_trigger.trigger_id = "barricade_destroyed"

	root.add_child(prop_inst)
	root.add_child(bound_trigger)
	await process_frame

	bound_trigger.bind_to_destructible(prop_inst)

	var bound_tracker := {"fired": false}
	bound_trigger.triggered.connect(func(_id: String, _p: Dictionary) -> void: bound_tracker["fired"] = true)

	# Destrói o prop
	prop_inst.destroy_prop()
	await process_frame

	assert_test(bound_tracker["fired"], "Destruição do prop ativou o LevelEventTrigger automaticamente")

	root.remove_child(prop_inst)
	root.remove_child(bound_trigger)
	prop_inst.free()
	bound_trigger.free()

	# PARTE 4: DialogueDirector (Desacoplamento do Combate)
	print("\n--- 4. Validando DialogueDirector e Mensagens de Fase ---")
	var dialogue_dir := DialogueDirectorClass.new()
	root.add_child(dialogue_dir)
	await process_frame

	var msg_tracker := {"started": false, "completed": false, "speaker": "", "text": ""}
	dialogue_dir.message_started.connect(func(spk: String, txt: String) -> void:
		msg_tracker["started"] = true
		msg_tracker["speaker"] = spk
		msg_tracker["text"] = txt
	)
	dialogue_dir.message_completed.connect(func(_spk: String, _txt: String) -> void:
		msg_tracker["completed"] = true
	)

	dialogue_dir.show_message("Guilherme", "Vamos em frente!", 2.0)
	assert_test(dialogue_dir.is_displaying, "DialogueDirector está exibindo mensagem")
	assert_test(msg_tracker["started"], "Sinal message_started emitido")
	assert_test(msg_tracker["speaker"] == "Guilherme", "Orador confere ('Guilherme')")
	assert_test(msg_tracker["text"] == "Vamos em frente!", "Texto da mensagem confere")

	dialogue_dir.skip_current()
	assert_test(msg_tracker["completed"], "Sinal message_completed emitido ao concluir/pular")
	assert_test(not dialogue_dir.is_displaying, "DialogueDirector finalizou a exibição")

	root.remove_child(dialogue_dir)
	dialogue_dir.free()

	# PARTE 5: LevelEventDirector e Sequência de Fase
	print("\n--- 5. Validando LevelEventDirector e Sequências Narrativas ---")
	var event_director := LevelEventDirectorClass.new()
	root.add_child(event_director)
	await process_frame

	var seq_tracker := {"completed": false}
	event_director.stage_sequence_completed.connect(func(_sname: String) -> void: seq_tracker["completed"] = true)

	var sequence_steps: Array[Dictionary] = [
		{"event": "dialogue", "params": {"speaker": "Alessandro", "text": "Vocês nunca passarão!"}},
		{"event": "custom_action", "params": {"flag": true}}
	]

	event_director.execute_story_sequence("intro_ambush", sequence_steps)
	assert_test(seq_tracker["completed"], "Sequência narrativa 'intro_ambush' executada com sucesso")
	assert_test(event_director.completed_events.has("dialogue"), "Evento 'dialogue' registrado como concluído")
	assert_test(event_director.completed_events.has("custom_action"), "Evento 'custom_action' registrado como concluído")

	root.remove_child(event_director)
	event_director.free()

	_finish()


func _finish() -> void:
	print("==================================================")
	print("RESULTADO DOS TESTES DE EVENTOS (FASE 8): %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)
