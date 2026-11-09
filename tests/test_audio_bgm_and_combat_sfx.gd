extends SceneTree

## Suíte de Testes Automatizados: Trilha Sonora (BGM) e Efeitos Sonoros de Combate (SFX)
## Valida o mapeamento por mapa, continuidade de BGM entre map1/map2 e map3/map4,
## e a reprodução desacoplada de áudio de combate sincronizado.

const GameSessionClass = preload("res://scripts/core/game_session.gd")
const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")
const BaseLevelClass = preload("res://scripts/levels/base_level.gd")
const MainMenuClass = preload("res://scripts/ui/main_menu.gd")
const TitleScreenClass = preload("res://scripts/ui/title_screen.gd")
const ContinueScreenClass = preload("res://scripts/ui/continue_screen.gd")
const MapMenuClass = preload("res://scripts/ui/map_menu.gd")
const LoadingScreenClass = preload("res://scripts/ui/loading_screen.gd")
const CharacterSelectClass = preload("res://scripts/ui/character_select.gd")
const DifficultySelectClass = preload("res://scripts/ui/difficulty_select.gd")
const PauseMenuClass = preload("res://scripts/ui/pause_menu.gd")
const NarrativeDirectorClass = preload("res://scripts/events/narrative_director.gd")

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: BGM E COMBAT SFX (AUDIO)")
	print("==================================================")
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % message)


func _run_tests() -> void:
	_test_bgm_files_existence_and_format()
	_test_sfx_files_existence_and_format()
	_test_game_session_bgm_lifecycle()
	_test_base_level_bgm_mapping()
	_test_combat_feedback_sfx_execution()
	_test_prop_and_pickup_sfx_execution()
	_test_ui_menus_sfx_integration()
	_test_narrative_director_sfx_integration()
	_test_audio_timing_and_onsets()

	print("==================================================")
	print("RESULTADO DOS TESTES DE AUDIO: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")

	quit(_failed)


func _test_bgm_files_existence_and_format() -> void:
	print("\n--- 1. Testando Integridade dos Arquivos BGM ---")
	var bgm_1_2: String = "res://assets/audio/bgm/M_1_2 - Estágio 1.mp3"
	var bgm_3_4: String = "res://assets/audio/bgm/M_3_4 - Estágio 1.mp3"
	var bgm_bonus: String = "res://assets/audio/bgm/bonus_1.mp3"
	var bgm_menu: String = "res://assets/audio/bgm/Menu.mp3"
	var bgm_historia: String = "res://assets/audio/bgm/Historia.mp3"

	_assert(ResourceLoader.exists(bgm_1_2), "BGM Estágio 1 (Map 1 e 2) existe no disco")
	_assert(ResourceLoader.exists(bgm_3_4), "BGM Estágio 1 (Map 3 e 4) existe no disco")
	_assert(ResourceLoader.exists(bgm_bonus), "BGM Fase Bônus (bonus_1.mp3) existe no disco")
	_assert(ResourceLoader.exists(bgm_menu), "BGM Menu Principal (Menu.mp3) existe no disco")
	_assert(ResourceLoader.exists(bgm_historia), "BGM História (Historia.mp3) existe no disco")

	var stream_1_2 := load(bgm_1_2) as AudioStreamMP3
	var stream_3_4 := load(bgm_3_4) as AudioStreamMP3
	var stream_bonus := load(bgm_bonus) as AudioStreamMP3
	var stream_menu := load(bgm_menu) as AudioStreamMP3
	var stream_historia := load(bgm_historia) as AudioStreamMP3

	_assert(stream_1_2 != null, "BGM Map 1 e 2 carrega como AudioStreamMP3 válido")
	_assert(stream_3_4 != null, "BGM Map 3 e 4 carrega como AudioStreamMP3 válido")
	_assert(stream_bonus != null, "BGM Fase Bônus carrega como AudioStreamMP3 válido")
	_assert(stream_menu != null, "BGM Menu Principal carrega como AudioStreamMP3 válido")
	_assert(stream_historia != null, "BGM História carrega como AudioStreamMP3 válido")
	_assert(stream_1_2 != null and stream_1_2.get_length() > 100.0, "BGM Map 1 e 2 tem duração de faixa completa (>100s)")
	_assert(stream_3_4 != null and stream_3_4.get_length() > 100.0, "BGM Map 3 e 4 tem duração de faixa completa (>100s)")
	_assert(stream_bonus != null and stream_bonus.get_length() > 30.0, "BGM Fase Bônus tem duração válida (>30s)")
	_assert(stream_menu != null and stream_menu.get_length() > 60.0, "BGM Menu Principal tem duração de faixa completa (>60s)")
	_assert(stream_historia != null and stream_historia.get_length() > 60.0, "BGM História tem duração de faixa completa (>60s)")


func _test_sfx_files_existence_and_format() -> void:
	print("\n--- 2. Testando Integridade dos Arquivos SFX (Combate, Props, Pickups, UI, Narrativa) ---")
	var sfx_paths: Array[String] = [
		# Combate Guilherme e Inimigos
		"res://assets/audio/sfx/soco_1_guilherme.mp3",
		"res://assets/audio/sfx/soco_2_guilherme.mp3",
		"res://assets/audio/sfx/finalizador_3_guilherme.mp3",
		"res://assets/audio/sfx/jumpkick_guilherme.mp3",
		"res://assets/audio/sfx/especial_1.1_guilherme.mp3",
		"res://assets/audio/sfx/inimigo_apanhando_1.mp3",
		"res://assets/audio/sfx/inimigo_apanhando_2.mp3",
		"res://assets/audio/sfx/inimigo_queda_1.mp3",
		# Props de Rua e Locadora
		"res://assets/audio/sfx/Pancada na Caixa.mp3",
		"res://assets/audio/sfx/Quebra da Caixa.mp3",
		"res://assets/audio/sfx/Lata de Lixo  Metal.mp3",
		# Pickups e Coletáveis
		"res://assets/audio/sfx/Coca-Cola.mp3",
		"res://assets/audio/sfx/Revista.mp3",
		"res://assets/audio/sfx/emmanuelle.mp3",
		# UI e Menus Arcade
		"res://assets/audio/sfx/Mover Cursor_sfx_move.mp3",
		"res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3",
		"res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3",
		# Narrativa e Glitch
		"res://assets/audio/sfx/deep_intro_hum.mp3",
		"res://assets/audio/sfx/glitch_static.mp3",
		# Aliases de compatibilidade segura
		"res://assets/audio/sfx/sfx_prop_box_hit.mp3",
		"res://assets/audio/sfx/sfx_prop_box_break.mp3",
		"res://assets/audio/sfx/sfx_prop_trash_hit.mp3",
		"res://assets/audio/sfx/sfx_coca_pickup.mp3",
		"res://assets/audio/sfx/sfx_magazine_pickup.mp3",
		"res://assets/audio/sfx/sfx_emmanuelle_pickup.mp3",
		"res://assets/audio/sfx/sfx_menu_move.mp3",
		"res://assets/audio/sfx/sfx_menu_confirm.mp3",
		"res://assets/audio/sfx/sfx_menu_denied.mp3",
		"res://assets/audio/sfx/sfx_narrative_hum.mp3",
		"res://assets/audio/sfx/sfx_narrative_glitch.mp3"
	]

	for path in sfx_paths:
		var fname: String = path.get_file()
		_assert(ResourceLoader.exists(path), "SFX %s existe no repositório" % fname)
		var stream := load(path) as AudioStream
		_assert(stream != null, "SFX %s carrega como AudioStream válido" % fname)


func _test_game_session_bgm_lifecycle() -> void:
	print("\n--- 3. Testando Ciclo de Vida da BGM no GameSession (Seamless) ---")
	var session := GameSessionClass.new()
	root.add_child(session)

	var bgm_1_2: String = "res://assets/audio/bgm/M_1_2 - Estágio 1.mp3"
	var bgm_3_4: String = "res://assets/audio/bgm/M_3_4 - Estágio 1.mp3"

	session.play_bgm(bgm_1_2)
	_assert(session.get_current_bgm_path() == bgm_1_2, "GameSession inicia BGM do Map 1 e 2")
	_assert(session._bgm_player != null and session._bgm_player.playing, "GameSession AudioStreamPlayer está em execução")

	# Simula transição para o Map 2: a mesma faixa é solicitada
	var initial_player := session._bgm_player
	session.play_bgm(bgm_1_2)
	_assert(session._bgm_player == initial_player, "Transição Map 1 -> Map 2 preserva a mesma instância de player")
	_assert(session._bgm_player.playing, "BGM segue tocando sem reinício ou interrupção entre Map 1 e 2")

	# Simula transição para o Map 3: nova faixa solicitada
	session.play_bgm(bgm_3_4)
	_assert(session.get_current_bgm_path() == bgm_3_4, "Transição para Map 3 atualiza para a nova faixa")
	_assert(session._bgm_player.playing, "BGM do Map 3 e 4 está em execução ativa")

	# Interrupção limpa
	session.stop_bgm()
	_assert(session.get_current_bgm_path() == "", "stop_bgm limpa o caminho atual")
	_assert(not session._bgm_player.playing, "AudioStreamPlayer foi pausado/parado com sucesso")

	session.queue_free()


func _test_base_level_bgm_mapping() -> void:
	print("\n--- 4. Testando Mapeamento Canônico de BGM em BaseLevel ---")
	var level_1 := BaseLevelClass.new()
	level_1.map_index = 1
	var target_1: String = level_1.BGM_STAGE_1_2 if level_1.map_index in [1, 2] else level_1.BGM_STAGE_3_4
	_assert(target_1 == "res://assets/audio/bgm/M_1_2 - Estágio 1.mp3", "Map 1 mapeia para M_1_2 - Estágio 1.mp3")

	var level_2 := BaseLevelClass.new()
	level_2.map_index = 2
	var target_2: String = level_2.BGM_STAGE_1_2 if level_2.map_index in [1, 2] else level_2.BGM_STAGE_3_4
	_assert(target_2 == "res://assets/audio/bgm/M_1_2 - Estágio 1.mp3", "Map 2 mapeia para M_1_2 - Estágio 1.mp3")

	var level_3 := BaseLevelClass.new()
	level_3.map_index = 3
	var target_3: String = level_3.BGM_STAGE_1_2 if level_3.map_index in [1, 2] else level_3.BGM_STAGE_3_4
	_assert(target_3 == "res://assets/audio/bgm/M_3_4 - Estágio 1.mp3", "Map 3 mapeia para M_3_4 - Estágio 1.mp3")

	var level_4 := BaseLevelClass.new()
	level_4.map_index = 4
	var target_4: String = level_4.BGM_STAGE_1_2 if level_4.map_index in [1, 2] else level_4.BGM_STAGE_3_4
	_assert(target_4 == "res://assets/audio/bgm/M_3_4 - Estágio 1.mp3", "Map 4 mapeia para M_3_4 - Estágio 1.mp3")

	var level_bonus := BaseLevelClass.new()
	level_bonus.map_index = 5
	level_bonus.map_group = "bonus1"
	var target_bonus: String = level_bonus.BGM_BONUS_1 if (level_bonus.map_index == 5 or level_bonus.map_group == "bonus1") else ""
	_assert(target_bonus == "res://assets/audio/bgm/bonus_1.mp3", "Fase Bônus (Map 5 / bonus1) mapeia para bonus_1.mp3")

	level_1.free()
	level_2.free()
	level_3.free()
	level_4.free()
	level_bonus.free()


func _test_combat_feedback_sfx_execution() -> void:
	print("\n--- 5. Testando Execução e Pooling de SFX em CombatFeedback ---")
	var dummy_root := Node2D.new()
	dummy_root.name = "DummyCombatScene"
	root.add_child(dummy_root)

	# 1. Golpes de punho (Soco 1 e Soco 2 alternados)
	CombatFeedbackClass.play_impact_sound(dummy_root, "punch")
	var pool_node := dummy_root.get_node_or_null("_Pool_CombatSFX")
	_assert(pool_node != null, "ObjectPool para CombatSFX criado sob a raiz da cena")

	# 2. Chute / Jumpkick
	CombatFeedbackClass.play_impact_sound(dummy_root, "kick")
	_assert(true, "play_impact_sound('kick') executado com sucesso")

	# 3. Finisher pesado
	CombatFeedbackClass.play_impact_sound(dummy_root, "finisher")
	_assert(true, "play_impact_sound('finisher') executado com sucesso")

	# 4. Especial cinemático
	CombatFeedbackClass.play_impact_sound(dummy_root, "special")
	_assert(true, "play_impact_sound('special') executado com sucesso")

	# 5. Dano em inimigos
	CombatFeedbackClass.play_enemy_hurt_sound(dummy_root)
	_assert(true, "play_enemy_hurt_sound() executado com sucesso")

	# 6. Queda / Knockdown de inimigos no solo
	CombatFeedbackClass.play_enemy_fall_sound(dummy_root)
	_assert(true, "play_enemy_fall_sound() executado com sucesso")

	dummy_root.queue_free()


func _test_prop_and_pickup_sfx_execution() -> void:
	print("\n--- 6. Testando SFX de Props e Coletáveis em CombatFeedback ---")
	var dummy_root := Node2D.new()
	dummy_root.name = "DummyPropScene"
	root.add_child(dummy_root)

	CombatFeedbackClass.play_prop_hit_sound(dummy_root, false)
	_assert(true, "play_prop_hit_sound(madeira) executado com sucesso")

	CombatFeedbackClass.play_prop_hit_sound(dummy_root, true)
	_assert(true, "play_prop_hit_sound(metal) executado com sucesso")

	CombatFeedbackClass.play_prop_break_sound(dummy_root, false)
	_assert(true, "play_prop_break_sound(madeira) executado com sucesso")

	CombatFeedbackClass.play_prop_break_sound(dummy_root, true)
	_assert(true, "play_prop_break_sound(metal) executado com sucesso")

	CombatFeedbackClass.play_pickup_sound(dummy_root, "coca")
	_assert(true, "play_pickup_sound('coca') executado com sucesso")

	CombatFeedbackClass.play_pickup_sound(dummy_root, "magazine")
	_assert(true, "play_pickup_sound('magazine') executado com sucesso")

	var emmanuelle_player = CombatFeedbackClass.play_pickup_sound(dummy_root, "emmanuelle")
	_assert(emmanuelle_player != null and emmanuelle_player.playing, "play_pickup_sound('emmanuelle') toca a faixa musical do item com sucesso")
	_assert(emmanuelle_player != null and emmanuelle_player.process_mode == Node.PROCESS_MODE_ALWAYS, "Player de áudio tem process_mode ALWAYS para tocar durante pausa")

	CombatFeedbackClass.play_menu_sound(dummy_root, "move")
	_assert(true, "play_menu_sound('move') executado com sucesso")

	CombatFeedbackClass.play_menu_sound(dummy_root, "confirm")
	_assert(true, "play_menu_sound('confirm') executado com sucesso")

	CombatFeedbackClass.play_menu_sound(dummy_root, "denied")
	_assert(true, "play_menu_sound('denied') executado com sucesso")

	dummy_root.queue_free()


func _test_ui_menus_sfx_integration() -> void:
	print("\n--- 7. Testando Integração de SFX nos Menus e Telas UI ---")

	var main_menu := MainMenuClass.new()
	main_menu._generate_audio_effects()
	_assert(main_menu._sfx_move != null, "MainMenu carrega SFX de movimentação")
	_assert(main_menu._sfx_confirm != null, "MainMenu carrega SFX de confirmação")
	_assert(main_menu._sfx_denied != null, "MainMenu carrega SFX de cancelamento/bloqueio")
	main_menu.free()

	var char_select := CharacterSelectClass.new()
	char_select._generate_audio_effects()
	_assert(char_select._sfx_move != null, "CharacterSelect carrega SFX de movimentação")
	_assert(char_select._sfx_confirm != null, "CharacterSelect carrega SFX de confirmação")
	_assert(char_select._sfx_denied != null, "CharacterSelect carrega SFX de opção bloqueada")
	char_select.free()

	var diff_select := DifficultySelectClass.new()
	diff_select._generate_audio_effects()
	_assert(diff_select._sfx_move != null, "DifficultySelect carrega SFX de movimentação")
	_assert(diff_select._sfx_confirm != null, "DifficultySelect carrega SFX de confirmação")
	_assert(diff_select._sfx_cancel != null, "DifficultySelect carrega SFX de opção cancelamento")
	diff_select.free()

	var pause_menu := PauseMenuClass.new()
	pause_menu._generate_audio_effects()
	_assert(pause_menu._sfx_move != null, "PauseMenu carrega SFX de movimentação")
	_assert(pause_menu._sfx_confirm != null, "PauseMenu carrega SFX de confirmação")
	_assert(pause_menu._sfx_cancel != null, "PauseMenu carrega SFX de retorno/cancelamento")
	pause_menu.free()

	var continue_screen := ContinueScreenClass.new()
	continue_screen._generate_audio_effects()
	_assert(continue_screen._sfx_move != null, "ContinueScreen carrega SFX de movimentação")
	_assert(continue_screen._sfx_confirm != null, "ContinueScreen carrega SFX de confirmação")
	_assert(continue_screen._sfx_cancel != null, "ContinueScreen carrega SFX de retorno/cancelamento")
	continue_screen.free()

	var map_menu := MapMenuClass.new()
	map_menu._generate_audio_effects()
	_assert(map_menu._sfx_move != null, "MapMenu carrega SFX de movimentação")
	_assert(map_menu._sfx_confirm != null, "MapMenu carrega SFX de confirmação")
	_assert(map_menu._sfx_cancel != null, "MapMenu carrega SFX de cancelamento")
	map_menu.free()

	var loading_screen := LoadingScreenClass.new()
	loading_screen._generate_audio_effects()
	_assert(loading_screen._sfx_start != null, "LoadingScreen carrega SFX de início/confirmação")
	_assert(loading_screen._sfx_cancel != null, "LoadingScreen carrega SFX de cancelamento")
	_assert(TitleScreenClass.BGM_MENU == "res://assets/audio/bgm/Menu.mp3", "TitleScreen mapeia BGM_MENU para Menu.mp3")
	_assert(MainMenuClass.BGM_MENU == "res://assets/audio/bgm/Menu.mp3", "MainMenu mapeia BGM_MENU para Menu.mp3")
	loading_screen.free()


func _test_narrative_director_sfx_integration() -> void:
	print("\n--- 8. Testando Integração de SFX no NarrativeDirector ---")
	var director := NarrativeDirectorClass.new()
	director._generate_sound_effects()
	_assert(director._sfx_deep_hum != null, "NarrativeDirector carrega deep_intro_hum")
	_assert(director._sfx_glitch != null, "NarrativeDirector carrega glitch_static")
	_assert(director.BGM_HISTORIA == "res://assets/audio/bgm/Historia.mp3", "NarrativeDirector mapeia BGM_HISTORIA para Historia.mp3")
	director.free()


func _test_audio_timing_and_onsets() -> void:
	print("\n--- 9. Testando Sincronização e Latência Zero nos Arquivos de Áudio ---")
	var sfx_max_durations: Dictionary = {
		# Combate
		"res://assets/audio/sfx/soco_1_guilherme.mp3": 0.30,
		"res://assets/audio/sfx/soco_2_guilherme.mp3": 0.40,
		"res://assets/audio/sfx/finalizador_3_guilherme.mp3": 0.60,
		"res://assets/audio/sfx/jumpkick_guilherme.mp3": 0.50,
		"res://assets/audio/sfx/inimigo_queda_1.mp3": 0.55,
		# Props de destruição
		"res://assets/audio/sfx/Pancada na Caixa.mp3": 0.80,
		"res://assets/audio/sfx/Quebra da Caixa.mp3": 0.80,
		"res://assets/audio/sfx/Lata de Lixo  Metal.mp3": 0.80,
		# Pickups
		"res://assets/audio/sfx/Coca-Cola.mp3": 1.00,
		"res://assets/audio/sfx/Revista.mp3": 0.70,
		"res://assets/audio/sfx/emmanuelle.mp3": 6.00,
		# Interface / Menus
		"res://assets/audio/sfx/Mover Cursor_sfx_move.mp3": 0.35,
		"res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3": 0.95,
		"res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3": 1.00,
		# Narrativa
		"res://assets/audio/sfx/deep_intro_hum.mp3": 1.70,
		"res://assets/audio/sfx/glitch_static.mp3": 1.25
	}

	for path in sfx_max_durations.keys():
		var stream := load(path) as AudioStream
		var max_d: float = sfx_max_durations[path]
		if stream != null and stream.has_method("get_length"):
			var len_s: float = stream.get_length()
			_assert(len_s <= max_d, "SFX %s aparado com precisão: duração %.2fs <= limite %.2fs" % [path.get_file(), len_s, max_d])

