extends SceneTree

## Suíte de Testes Automatizados: Fluxo de Rejogar Fase (Seleção de Personagem e Dificuldade)
## Projeto Sakas — Godot 4.x

const MapMenuClass = preload("res://scripts/ui/map_menu.gd")
const CharacterSelectClass = preload("res://scripts/ui/character_select.gd")
const DifficultySelectClass = preload("res://scripts/ui/difficulty_select.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	call_deferred("_run_all_tests")


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % message)
	else:
		failed += 1
		printerr("  [FALHA] %s" % message)


func _run_all_tests() -> void:
	print("========================================================================")
	print("INICIANDO TESTES: FLUXO DE REJOGAR FASE COM PERSONAGEM E DIFICULDADE")
	print("========================================================================")

	var session = root.get_node_or_null("GameSession")
	_assert(session != null, "Autoload GameSession está disponível")
	if session == null:
		_finish()
		return

	# Prepara estado: Estágio 1 concluído para que as fases exibam 'REJOGAR FASE'
	session.complete_stage(1)
	session.max_unlocked_map = 4
	session.set_meta("map_entry_context", "continue")

	print("\n--- 1. Validação do Botão 'REJOGAR FASE' no MapMenu ---")
	var map_scn = load("res://scenes/ui/map_menu.tscn") as PackedScene
	_assert(map_scn != null, "Cena map_menu.tscn carregada com sucesso")

	var map_menu = map_scn.instantiate() as Control
	root.add_child(map_menu)
	await process_frame

	# No Nível A, entra no Stage 01 para inspecionar os sub-mapas
	map_menu.call("_enter_stage_01", 1) # Seleciona Fase 1-2 (Balcão)
	await process_frame

	_assert(map_menu.call("is_stage_completed", 1) == true, "Fase 1-2 reporta is_stage_completed == true")

	var btn_play: Button = map_menu.get("btn_play_stage")
	_assert(btn_play != null, "Botão %BtnPlayStage existe")
	_assert(btn_play.get("button_text") == "REJOGAR FASE", "Botão exibe texto 'REJOGAR FASE'")

	print("\n--- 2. Validação do Redirecionamento de Replay para CharacterSelect ---")
	# Dispara o clique no botão de rejogar fase
	map_menu.call("_on_play_stage_pressed")

	_assert(session.has_meta("map_entry_context") and session.get_meta("map_entry_context") == "replay", "GameSession registra map_entry_context == 'replay'")
	_assert(session.has_meta("replay_stage_index") and int(session.get_meta("replay_stage_index")) == 1, "GameSession registra replay_stage_index == 1 (Fase 1-2)")
	_assert(session.has_meta("replay_stage_scene") and str(session.get_meta("replay_stage_scene")) == "res://scenes/levels/map_2.tscn", "GameSession registra replay_stage_scene correta (map_2.tscn)")

	map_menu.queue_free()
	await process_frame

	print("\n--- 3. Validação do Cancelamento (Voltar) em CharacterSelect durante Replay ---")
	var char_scn = load("res://scenes/ui/character_select.tscn") as PackedScene
	_assert(char_scn != null, "Cena character_select.tscn carregada com sucesso")

	var char_menu = char_scn.instantiate() as Control
	root.add_child(char_menu)
	await process_frame

	# Testa voltar para o mapa quando em replay
	char_menu.call("_on_back_pressed")
	_assert(session.get_meta("map_entry_context") == "continue", "Ao cancelar seleção no replay, map_entry_context retorna a 'continue'")
	_assert(not session.has_meta("replay_stage_index"), "Metadado replay_stage_index foi limpo ao cancelar")

	char_menu.queue_free()
	await process_frame

	print("\n--- 4. Validação da Seleção de Personagem (Gabriel) durante Replay ---")
	# Reconfigura metadados de replay
	session.set_meta("map_entry_context", "replay")
	session.set_meta("replay_stage_index", 2) # Fase 1-3 (Travessa)
	session.set_meta("replay_stage_scene", "res://scenes/levels/map_3.tscn")
	session.selected_character_id = "guilherme"

	var char_menu2 = char_scn.instantiate() as Control
	root.add_child(char_menu2)
	await process_frame

	# Seleciona Gabriel (índice 1)
	char_menu2.call("_select_character_by_index", 1, false, 1)
	_assert(char_menu2.get("current_hover_id") == "gabriel", "Gabriel selecionado no menu")

	# Confirma seleção de Gabriel
	char_menu2.call("_on_confirm_pressed")
	_assert(session.selected_character_id == "gabriel", "GameSession registra novo personagem: Gabriel")
	_assert(session.get_meta("map_entry_context") == "replay", "Contexto 'replay' é preservado para a próxima tela")

	char_menu2.queue_free()
	await process_frame

	print("\n--- 5. Validação da Seleção de Dificuldade e Disparo Direto da Fase Rejogada ---")
	var diff_scn = load("res://scenes/ui/difficulty_select.tscn") as PackedScene
	_assert(diff_scn != null, "Cena difficulty_select.tscn carregada com sucesso")

	var diff_menu = diff_scn.instantiate() as Control
	root.add_child(diff_menu)
	await process_frame

	# Seleciona Dificuldade 'dificil'
	diff_menu.call("_select_difficulty", "dificil", false)
	_assert(diff_menu.get("current_difficulty") == "dificil", "Dificuldade 'dificil' selecionada no menu")

	# Executa confirmação de início
	diff_menu.call("_on_start_pressed")
	_assert(session.difficulty_id == "dificil", "GameSession registra nova dificuldade: difícil")
	_assert(session.selected_character_id == "gabriel", "GameSession mantém personagem escolhido: Gabriel")

	diff_menu.queue_free()
	await process_frame

	# Limpa metadados e restaura estado padrão
	if session.has_meta("map_entry_context"):
		session.remove_meta("map_entry_context")
	if session.has_meta("replay_stage_index"):
		session.remove_meta("replay_stage_index")
	if session.has_meta("replay_stage_scene"):
		session.remove_meta("replay_stage_scene")

	print("\n========================================================================")
	print("RESULTADO DOS TESTES: %d PASSARAM (Falhas: %d)" % [passed, failed])
	print("========================================================================")

	_finish()


func _finish() -> void:
	if failed == 0:
		print("\n>> SUCESSO: FLUXO DE REJOGAR FASE VALIDADO COM 100% DE APROVAÇÃO! <<\n")
		quit(0)
	else:
		printerr("\n>> ERRO: %d TESTES FALHARAM! <<\n" % failed)
		quit(1)
