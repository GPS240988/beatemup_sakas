extends SceneTree

## Teste Unitário Automatizado: Preparação Técnica e Normalização de Dano do Gabriel (Projeto Sakas)

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	call_deferred("_run_all_tests")

func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % message)

func _run_all_tests() -> void:
	print("\n==================================================")
	print("INICIANDO TESTES: PREPARAÇÃO TÉCNICA E NORMALIZAÇÃO DE DANO (GABRIEL & GUILHERME)")
	print("==================================================")

	_test_game_session_stats_and_multipliers()
	_test_guilherme_damage_normalization()
	_test_gabriel_data_and_damage_budget()
	_test_player_controller_character_loading()
	_test_character_select_unlock_behavior()

	print("\n==================================================")
	print("RESULTADO DOS TESTES: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")

	if _failed > 0:
		quit(1)
	else:
		quit(0)

func _test_game_session_stats_and_multipliers() -> void:
	print("\n--- 1. Validando Estatísticas e Multiplicadores em GameSession ---")
	var session = root.get_node_or_null("GameSession")
	if session == null:
		var session_script = load("res://scripts/core/game_session.gd") as GDScript
		session = session_script.new()
		root.add_child(session)

	_assert(session.CHARACTERS.has("gabriel"), "Gabriel está registrado no GameSession")
	var gabriel_info: Dictionary = session.CHARACTERS["gabriel"]
	_assert(gabriel_info.get("strength") == 1, "Gabriel possui Força 1")
	_assert(gabriel_info.get("speed") == 4, "Gabriel possui Velocidade 4")
	_assert(gabriel_info.get("technique") == 3, "Gabriel possui Técnica 3")
	_assert(gabriel_info.get("title") == "Atirador Veloz", "Título do Gabriel é 'Atirador Veloz'")
	_assert(gabriel_info.get("unlocked") == false, "Gabriel está bloqueado para novo jogo")
	_assert(gabriel_info.get("preview_path") == "res://assets/sprites/characters/gabriel/idle.png", "Preview path de Gabriel está configurado")

	# Teste dos multiplicadores oficiais:
	# Força: 0.70 + (str * 0.10)
	var str_mult_gabriel: float = session.get_strength_multiplier("gabriel")
	var str_mult_guilherme: float = session.get_strength_multiplier("guilherme")
	_assert(is_equal_approx(str_mult_gabriel, 0.80), "Multiplicador de Força do Gabriel é exatamente 0.80x")
	_assert(is_equal_approx(str_mult_guilherme, 1.00), "Multiplicador de Força do Guilherme é exatamente 1.00x")

	# Velocidade: 0.70 + (spd * 0.15)
	var spd_mult_gabriel: float = session.get_speed_multiplier("gabriel")
	_assert(is_equal_approx(spd_mult_gabriel, 1.30), "Multiplicador de Velocidade do Gabriel é 1.30x (0.70 + 4*0.15)")

	# Técnica: 0.70 + (tec * 0.10)
	var tec_mult_gabriel: float = session.get_technique_multiplier("gabriel")
	_assert(is_equal_approx(tec_mult_gabriel, 1.00), "Multiplicador de Técnica do Gabriel é 1.00x (0.70 + 3*0.10)")

func _test_guilherme_damage_normalization() -> void:
	print("\n--- 2. Validando Normalização do Dano-Base do Guilherme ---")
	var guilherme_data = load("res://resources/heroes/guilherme_data.tres") as HeroData
	_assert(guilherme_data != null, "guilherme_data.tres carregado com sucesso")
	_assert(guilherme_data.punch1_damage == 10.0, "Jab do Guilherme é 10.0 base")
	_assert(guilherme_data.punch2_damage == 15.0, "Cross do Guilherme é 15.0 base")
	_assert(guilherme_data.kick3_damage == 20.0, "Kick do Guilherme é 20.0 base")
	_assert(guilherme_data.heavy4_damage == 35.0, "Finisher do Guilherme é 35.0 base")

	var total_base_guilherme: float = guilherme_data.punch1_damage + guilherme_data.punch2_damage + guilherme_data.kick3_damage + guilherme_data.heavy4_damage
	_assert(is_equal_approx(total_base_guilherme, 80.0), "Total de dano base de Guilherme é exatamente 80.0")

func _test_gabriel_data_and_damage_budget() -> void:
	print("\n--- 3. Validando gabriel_data.tres e Orçamento de Dano (64 Efetivo) ---")
	_assert(ResourceLoader.exists("res://resources/heroes/gabriel_data.tres"), "gabriel_data.tres existe no diretório oficial")
	var gabriel_data = load("res://resources/heroes/gabriel_data.tres") as HeroData
	_assert(gabriel_data != null, "gabriel_data.tres carregado como HeroData")
	_assert(gabriel_data.hero_id == "gabriel", "hero_id é 'gabriel'")
	_assert(gabriel_data.display_name == "Gabriel", "display_name é 'Gabriel'")

	# Dano base no recurso:
	_assert(is_equal_approx(gabriel_data.punch1_damage, 17.50), "Passo 1 (Disparo rápido) possui base 17.50")
	_assert(is_equal_approx(gabriel_data.punch2_damage, 17.50), "Passo 2 (Rajada dupla) possui base 17.50")
	_assert(is_equal_approx(gabriel_data.kick3_damage, 15.00), "Passo 3 (Pistolada) possui base 15.00")
	_assert(is_equal_approx(gabriel_data.heavy4_damage, 30.00), "Passo 4 (Rajada final) possui base 30.00")

	# Cálculo de Dano Efetivo (com Força 1 = 0.80x):
	var mult: float = 0.80
	var eff1: float = gabriel_data.punch1_damage * mult
	var eff2: float = gabriel_data.punch2_damage * mult
	var eff3: float = gabriel_data.kick3_damage * mult
	var eff4: float = gabriel_data.heavy4_damage * mult

	_assert(is_equal_approx(eff1, 14.0), "Passo 1 resulta em 14.0 de dano efetivo")
	_assert(is_equal_approx(eff2, 14.0), "Passo 2 resulta em 14.0 de dano efetivo (7.0 + 7.0)")
	_assert(is_equal_approx(eff3, 12.0), "Passo 3 resulta em 12.0 de dano efetivo")
	_assert(is_equal_approx(eff4, 24.0), "Passo 4 resulta em 24.0 de dano efetivo")

	var total_eff: float = eff1 + eff2 + eff3 + eff4
	_assert(is_equal_approx(total_eff, 64.0), "Total do combo de Gabriel resulta exatamente em 64.0 de dano efetivo")

	# Parâmetros de locomoção e atributos:
	_assert(gabriel_data.speed_x == 260.0, "Gabriel speed_x base é 260.0")
	_assert(gabriel_data.speed_y == 190.0, "Gabriel speed_y base é 190.0")
	_assert(gabriel_data.punch1_range == 280.0, "Alcance do Passo 1 da pistola é 280.0 px")
	_assert(gabriel_data.punch2_range == 300.0, "Alcance do Passo 2 da pistola é 300.0 px")
	_assert(gabriel_data.kick3_range == 75.0, "Alcance do Passo 3 (curta distância) é 75.0 px")
	_assert(gabriel_data.heavy4_range == 320.0, "Alcance do Passo 4 da pistola é 320.0 px")

func _test_player_controller_character_loading() -> void:
	print("\n--- 4. Validando Carregamento Dinâmico no PlayerController ---")
	var session = root.get_node_or_null("GameSession")
	var player_scene = load("res://scenes/actors/player/player.tscn") as PackedScene

	# A. Instanciando como Gabriel
	session.selected_character_id = "gabriel"
	var player_gabriel = player_scene.instantiate() as PlayerController
	root.add_child(player_gabriel)

	_assert(player_gabriel.hero_data != null, "hero_data de Gabriel não é nulo")
	_assert(player_gabriel.hero_data.hero_id == "gabriel", "PlayerController carregou gabriel_data.tres")
	_assert(is_equal_approx(player_gabriel.speed_x, 260.0 * 1.30), "speed_x de Gabriel com multiplicador de velocidade 1.3x é 338.0")

	# Validando combo de Gabriel no PlayerController (multiplicador de força 0.8x aplicado uma única vez)
	var combo_gabriel = player_gabriel.get("_combo_attacks") as Array
	_assert(combo_gabriel.size() == 4, "Gabriel possui 4 ataques no combo")
	_assert(is_equal_approx(combo_gabriel[0].damage, 14.0), "Dano do Passo 1 no PlayerController é 14.0")
	_assert(is_equal_approx(combo_gabriel[1].damage, 14.0), "Dano do Passo 2 no PlayerController é 14.0")
	_assert(is_equal_approx(combo_gabriel[2].damage, 12.0), "Dano do Passo 3 no PlayerController é 12.0")
	_assert(is_equal_approx(combo_gabriel[3].damage, 24.0), "Dano do Passo 4 no PlayerController é 24.0")

	# Validando SpriteFrames de Gabriel
	var anim_sprite_gabriel = player_gabriel.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_assert(anim_sprite_gabriel != null, "AnimatedSprite2D presente")
	_assert(anim_sprite_gabriel.sprite_frames.has_animation("idle"), "SpriteFrames de Gabriel possui 'idle'")
	_assert(anim_sprite_gabriel.sprite_frames.has_animation("punch"), "SpriteFrames de Gabriel possui 'punch'")
	_assert(anim_sprite_gabriel.sprite_frames.has_animation("walk"), "SpriteFrames de Gabriel possui 'walk'")

	player_gabriel.queue_free()

	# B. Instanciando como Guilherme (Garantir Zero Regressão)
	session.selected_character_id = "guilherme"
	var player_guilherme = player_scene.instantiate() as PlayerController
	root.add_child(player_guilherme)

	_assert(player_guilherme.hero_data != null, "hero_data de Guilherme não é nulo")
	_assert(player_guilherme.hero_data.hero_id == "guilherme", "PlayerController carregou guilherme_data.tres")

	var combo_guilherme = player_guilherme.get("_combo_attacks") as Array
	_assert(is_equal_approx(combo_guilherme[0].damage, 10.0), "Dano do Passo 1 de Guilherme é 10.0")
	_assert(is_equal_approx(combo_guilherme[1].damage, 15.0), "Dano do Passo 2 de Guilherme é 15.0")
	_assert(is_equal_approx(combo_guilherme[2].damage, 20.0), "Dano do Passo 3 de Guilherme é 20.0")
	_assert(is_equal_approx(combo_guilherme[3].damage, 35.0), "Dano do Passo 4 de Guilherme é 35.0")

	var anim_sprite_guilherme = player_guilherme.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_assert(anim_sprite_guilherme.sprite_frames.get_frame_count("punch") == 3, "SpriteFrames de Guilherme preserva 3 frames de punch")

	player_guilherme.queue_free()

func _test_character_select_unlock_behavior() -> void:
	print("\n--- 5. Validando Bloqueio de Gabriel em Novo Jogo e Desbloqueio de Guilherme ---")
	var session = root.get_node_or_null("GameSession")
	_assert(session.is_character_unlocked("guilherme") == true, "GameSession confirma Guilherme desbloqueado para novo jogo")
	_assert(session.is_character_unlocked("gabriel") == false, "GameSession confirma Gabriel bloqueado para novo jogo")
	_assert(session.is_character_unlocked("andre") == false, "GameSession confirma André bloqueado")
	_assert(session.is_character_unlocked("juliana") == false, "GameSession confirma Juliana bloqueada")

	var can_select_gabriel: bool = session.select_character("gabriel")
	_assert(can_select_gabriel == false, "session.select_character('gabriel') é rejeitado em novo jogo (bloqueado)")

	var can_select_guilherme: bool = session.select_character("guilherme")
	_assert(can_select_guilherme == true, "session.select_character('guilherme') é aceito com sucesso")
	_assert(session.selected_character_id == "guilherme", "selected_character_id agora é 'guilherme'")

	var can_select_andre: bool = session.select_character("andre")
	_assert(can_select_andre == false, "session.select_character('andre') é rejeitado (bloqueado)")
	_assert(session.selected_character_id == "guilherme", "selected_character_id permanece inalterado em 'guilherme'")
