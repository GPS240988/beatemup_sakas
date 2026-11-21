extends SceneTree

## Teste Automatizado Headless: Diálogos de Entrada da Fase 2-1 (Estágio 02)
## Valida padronização do story_phase2_1_entry.tres, resolução de retratos,
## e proteção contra repetição no GameSession e Map5Stage2.

const SEQUENCE_PATH: String = "res://resources/story/story_phase2_1_entry.tres"
const DIRECTOR_SCENE_PATH: String = "res://scenes/ui/narrative_director_stage2_happen.tscn"
const LEVEL_SCENE_PATH: String = "res://scenes/levels/map_5.tscn"
const LEVEL_IMAGE_PATH: String = "res://assets/backgrounds/maps/fase2/Fase2_3.webp"

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % message)


func _run_tests() -> void:
	print("==================================================")
	print("TESTE: DIÁLOGOS DE ENTRADA DA FASE 2-1 (ESTÁGIO 02)")
	print("==================================================")

	# 1. Validação do recurso story_phase2_1_entry.tres
	print("\n--- 1. Validação da Sequência Narrativa Padronizada ---")
	var seq: Resource = load(SEQUENCE_PATH)
	_assert(seq != null, "Recurso story_phase2_1_entry.tres carrega com sucesso")
	_assert(seq.get("sequence_id") == "story_phase2_1_entry", "sequence_id é 'story_phase2_1_entry'")

	var events: Array = seq.get("events") if seq != null else []
	_assert(events.size() == 1, "A sequência contém exatamente 1 evento de diálogo unificado")

	if not events.is_empty():
		var ev: Resource = events[0] as Resource
		_assert(str(ev.get("image_path")) == LEVEL_IMAGE_PATH, "A imagem de fundo aponta para a arte panorâmica da Fase 2-1")
		var texts: Array = ev.get("texts") as Array
		var speakers: Array = ev.get("speakers") as Array
		_assert(texts.size() == 4, "Contém exatamente 4 falas do grupo")
		_assert(speakers.size() == 4, "Contém exatamente 4 oradores configurados")
		if speakers.size() == 4:
			_assert(speakers[0] == "ALESSANDRO", "Fala 1 é de ALESSANDRO")
			_assert(speakers[1] == "GUILHERME", "Fala 2 é de GUILHERME")
			_assert(speakers[2] == "ANDRÉ", "Fala 3 é de ANDRÉ")
			_assert(speakers[3] == "GABRIEL", "Fala 4 é de GABRIEL")

	# 2. Resolução de Retratos no Diretor Especializado
	print("\n--- 2. Resolução de Retratos (Alessandro, Guilherme, André, Gabriel) ---")
	_assert(ResourceLoader.exists(DIRECTOR_SCENE_PATH), "Cena narrative_director_stage2_happen.tscn existe")
	var director_scn: PackedScene = load(DIRECTOR_SCENE_PATH) as PackedScene
	_assert(director_scn != null, "Cena do diretor especializada carrega")

	var director = director_scn.instantiate()
	root.add_child(director)

	var dummy_ev: Resource = events[0] if not events.is_empty() else null
	var port_alessandro = director.call("_resolve_speaker_portrait", "ALESSANDRO", dummy_ev)
	var port_guilherme = director.call("_resolve_speaker_portrait", "GUILHERME", dummy_ev)
	var port_andre = director.call("_resolve_speaker_portrait", "ANDRÉ", dummy_ev)
	var port_gabriel = director.call("_resolve_speaker_portrait", "GABRIEL", dummy_ev)

	_assert(port_alessandro != null, "Retrato de ALESSANDRO resolvido com sucesso")
	_assert(port_guilherme != null, "Retrato de GUILHERME resolvido com sucesso")
	_assert(port_andre != null, "Retrato de ANDRÉ resolvido com sucesso")
	_assert(port_gabriel != null, "Retrato de GABRIEL resolvido com sucesso")

	director.queue_free()

	# 3. Validação da Sessão e Proteção de Não-Repetição
	print("\n--- 3. Proteção de Não-Repetição no GameSession e Map5 ---")
	var session = root.get_node_or_null("GameSession")
	if session != null:
		session.has_seen_phase2_1_intro = false
		_assert(session.has_seen_phase2_1_intro == false, "has_seen_phase2_1_intro inicia como false")

		session.reset_session()
		_assert(session.has_seen_phase2_1_intro == false, "reset_session() zera has_seen_phase2_1_intro")

	var level_scn: PackedScene = load(LEVEL_SCENE_PATH) as PackedScene
	_assert(level_scn != null, "Cena map_5.tscn carrega com sucesso")

	# Garante flag zerada antes da primeira entrada no mapa
	if session != null:
		session.has_seen_phase2_1_intro = false

	var level1 = level_scn.instantiate()
	root.add_child(level1)
	await process_frame

	if session != null:
		_assert(session.has_seen_phase2_1_intro == true, "Ao entrar pela primeira vez, has_seen_phase2_1_intro passa para true")

	# Simula reinício de mapa (ex: Tecla R ou morte) instanciando novo Map5
	var level2 = level_scn.instantiate()
	root.add_child(level2)
	await process_frame

	var should_trigger_restart: bool = level2.call("_check_and_trigger_opening_narrative")
	_assert(should_trigger_restart == false, "Com has_seen_phase2_1_intro = true, diálogo NÃO se repete no reinício")

	level1.queue_free()
	level2.queue_free()
	await process_frame

	print("\n==================================================")
	print("RESULTADO: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")

	quit(0 if _failed == 0 else 1)
