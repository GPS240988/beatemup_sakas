extends SceneTree

## Suíte de Testes Automatizada: Dash Evasivo Aprimorado, SFX e Mobilidade de Gabriel
## Validação Integral dos Requisitos:
## 1. Parâmetros aprimorados e dois dashes seguidos com acionamento duplo antes do cooldown
## 2. Atravessar adversário estacionário (phasing)
## 3. Atravessar múltiplos adversários alinhados
## 4. Deslocamento em grupo e resolução segura de sobreposição pós-dash
## 5. Bloqueio obrigatório por paredes sólidas (Layer 2)
## 6. Bloqueio por obstáculos sólidos do cenário
## 7. Deslocamento em direções diagonais 2.5D
## 8. Restauração imediata de colisões e estado normal após o término do Dash
## 9. Proteção contra contato corporal durante atravessamento e ciclo de vida do Afterimage
## 10. Disparo em movimento e cancelamento em Dash
## 11. Validação de controles (Mobile Touch) e Zero Regressão em Guilherme e demais heróis
## 12. Validação dos efeitos sonoros do Gabriel (tiro1, tiro2, coronhaada, dash_gabriel)
## 13. Validação da imagem de apresentação do Especial (especial1_gabriel.webp)

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
		print("  [FALHA] %s" % message)


func _run_all_tests() -> void:
	print("==================================================")
	print("TESTE INTEGRADO: DASH EVASIVO E SFX DO GABRIEL")
	print("==================================================")

	_test_dash_parameters_and_trigger()
	_test_dash_passes_through_stationary_enemy()
	_test_dash_passes_through_multiple_aligned_enemies()
	_test_dash_into_group_and_overlap_resolution()
	_test_dash_blocked_by_wall()
	_test_dash_blocked_by_solid_scene_obstacle()
	_test_dash_in_2_5d_directions()
	_test_normal_collision_restoration_after_dash()
	_test_protection_and_afterimage_lifecycle()
	_test_movement_while_shooting_and_dash_cancel()
	_test_touch_controls_and_character_zero_regression()
	_test_gabriel_audio_integration()
	_test_gabriel_special_presentation_image()

	print("\n==================================================")
	print("RESULTADO: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")

	quit(0 if _failed == 0 else 1)


func _ensure_game_session() -> Node:
	var session = root.get_node_or_null("GameSession")
	if session == null:
		var session_script = load("res://scripts/core/game_session.gd") as GDScript
		session = session_script.new()
		session.name = "GameSession"
		root.add_child(session)
	return session


func _test_dash_parameters_and_trigger() -> void:
	print("\n--- 1. Parâmetros Aprimorados e Acionamento Duplo do Dash ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)

	_assert(player.is_gabriel(), "Gabriel identificado corretamente")
	_assert(is_equal_approx(player.dash_distance, 270.0), "Distância ampliada para 270.0 px (faixa 260-280 px)")
	_assert(is_equal_approx(player.dash_duration, 0.34), "Duração do deslocamento ajustada para 0.34s")
	_assert(is_equal_approx(player.dash_invulnerable_duration, 0.12), "Janela inicial de invulnerabilidade é 0.12s")
	_assert(is_equal_approx(player.dash_cooldown, 0.80), "Tempo de recarga inicial é 0.80s")
	_assert(is_equal_approx(player.dash_recovery_duration, 0.08), "Recuperação do dash é 0.08s")

	# Pulo é substituído pelo Dash (Primeiro Dash)
	player.execute_aerial()
	_assert(player.is_dashing(), "execute_aerial aciona o Dash para Gabriel")
	_assert(player.get("_is_jumping") == false, "Gabriel NÃO realiza pulo convencional")
	_assert(player.get("_is_invulnerable") == true, "Gabriel inicia o dash invulnerável")
	_assert(player.get_dash_count() == 1, "Primeiro dash registrado (dash_count = 1)")

	# Acionamento imediato no mesmo frame é debouncado (<0.05s) para evitar consumo duplo acidental
	var same_frame_dash: bool = player.execute_dash()
	_assert(not same_frame_dash, "Acionamento duplo no mesmo frame (<0.05s) é debouncado")

	# Avança física durante o primeiro dash ou cooldown (ex: 0.10s)
	player._physics_process(0.10)

	# Segundo dash consecutivo antes de terminar o cooldown do primeiro
	var second_dash: bool = player.execute_dash()
	_assert(second_dash, "Segundo dash executado com sucesso em sequência antes do término do cooldown")
	_assert(player.get_dash_count() == 2, "Segundo dash registrado (dash_count = 2)")

	# Terceira tentativa é bloqueada (máximo de 2 dashes seguidos)
	player._physics_process(0.10)
	var third_dash: bool = player.execute_dash()
	_assert(not third_dash, "Terceiro dash rejeitado (limite de 2 dashes seguidos respeitado)")

	# Avança até expirar o cooldown completo (0.80s)
	for _i in range(50):
		player._physics_process(0.02)
	_assert(player.get_dash_count() == 0, "Após o fim da recarga completa, contador de dashes é zerado")

	player.queue_free()


func _test_dash_passes_through_stationary_enemy() -> void:
	print("\n--- 2. Atravessar Adversário Estacionário (Phasing) ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(200.0, 300.0)
	player.facing_direction = 1.0

	# Inimigo exatamente no caminho horizontal (X = 280, Y = 300)
	var enemy := CharacterBody2D.new()
	enemy.add_to_group("enemies")
	enemy.global_position = Vector2(280.0, 300.0)
	root.add_child(enemy)

	player.execute_dash()
	_assert(player.is_dashing(), "Dash acionado em direção ao inimigo")

	# Processa meio trajeto do Dash (~0.17s)
	for _i in range(10):
		player._physics_process(0.017)

	# Gabriel deve ter continuado seu deslocamento e ultrapassado ou estar cruzando o inimigo sem ter velocidade zerada
	_assert(player.global_position.x > 250.0, "Gabriel avançou através do espaço do adversário (X = %.1f)" % player.global_position.x)
	_assert(player.velocity.x > 0.0, "Velocidade horizontal NÃO foi interrompida pelo inimigo")

	enemy.queue_free()
	player.queue_free()


func _test_dash_passes_through_multiple_aligned_enemies() -> void:
	print("\n--- 3. Atravessar Múltiplos Adversários Alinhados ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(100.0, 300.0)
	player.facing_direction = 1.0

	var enemies: Array[CharacterBody2D] = []
	for x_pos in [160.0, 220.0, 280.0]:
		var e := CharacterBody2D.new()
		e.add_to_group("enemies")
		e.global_position = Vector2(x_pos, 300.0)
		root.add_child(e)
		enemies.append(e)

	player.execute_dash()

	# Processa o dash completo (0.34s)
	for _i in range(20):
		player._physics_process(0.017)

	_assert(player.global_position.x > 320.0, "Gabriel atravessou com sucesso todos os 3 adversários alinhados (X final = %.1f)" % player.global_position.x)

	for e in enemies:
		e.queue_free()
	player.queue_free()


func _test_dash_into_group_and_overlap_resolution() -> void:
	print("\n--- 4. Resolução Segura de Sobreposição ao Final do Dash ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(100.0, 300.0)
	player.facing_direction = 1.0

	# Coloca um inimigo exatamente onde o dash terminaria (~370.0 px)
	var enemy := CharacterBody2D.new()
	enemy.add_to_group("enemies")
	enemy.global_position = Vector2(370.0, 300.0)
	root.add_child(enemy)

	player.execute_dash()

	# Processa todo o dash e a recuperação (0.34s + 0.08s)
	for _i in range(25):
		player._physics_process(0.017)

	# A rotina _resolve_dash_finish_overlap deve garantir que Gabriel não fique colado/sobreposto
	var dist_x: float = abs(player.global_position.x - enemy.global_position.x)
	_assert(dist_x >= 24.0 or abs(player.global_position.y - enemy.global_position.y) >= 18.0, "Sobreposição final resolvida com folga segura (dist_x = %.1f)" % dist_x)

	enemy.queue_free()
	player.queue_free()


func _test_dash_blocked_by_wall() -> void:
	print("\n--- 5. Bloqueio Obrigatório por Parede Sólida (Layer 2) ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(100.0, 300.0)
	player.facing_direction = 1.0

	# Cria uma parede estática com colisão na Layer 2 (ambiente/paredes)
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	var col_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(40.0, 200.0)
	col_shape.shape = rect_shape
	wall.add_child(col_shape)
	wall.global_position = Vector2(180.0, 300.0)
	root.add_child(wall)

	player.execute_dash()

	# Processa física
	for _i in range(20):
		player._physics_process(0.017)

	# Gabriel NÃO pode atravessar a parede (deve parar antes de X = 180)
	_assert(player.global_position.x < 175.0, "Gabriel foi devidamente bloqueado pela parede sólida (X = %.1f < 175.0)" % player.global_position.x)

	wall.queue_free()
	player.queue_free()


func _test_dash_blocked_by_solid_scene_obstacle() -> void:
	print("\n--- 6. Bloqueio por Obstáculos Sólidos do Cenário ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(100.0, 300.0)
	player.facing_direction = 1.0

	# Obstáculo sólido no cenário (caixa/barril que usa colisão física sólida na Layer 2)
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = 2
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(50.0, 50.0)
	shape.shape = box
	obstacle.add_child(shape)
	obstacle.global_position = Vector2(220.0, 300.0)
	root.add_child(obstacle)

	player.execute_dash()

	for _i in range(20):
		player._physics_process(0.017)

	_assert(player.global_position.x < 210.0, "Obstáculo sólido bloqueia Gabriel durante o dash (X = %.1f < 210.0)" % player.global_position.x)

	obstacle.queue_free()
	player.queue_free()


func _test_dash_in_2_5d_directions() -> void:
	print("\n--- 7. Deslocamento em Direções Diagonais 2.5D ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(200.0, 300.0)

	# Simula entrada diagonal cima-direita
	Input.action_press("move_right")
	Input.action_press("move_up")

	player.execute_dash()
	_assert(player.is_dashing(), "Dash diagonal iniciado")

	var dir: Vector2 = player.get("_dash_direction")
	_assert(dir.x > 0.0 and dir.y < 0.0, "Direção do dash registrada corretamente na diagonal superior direita (dir = %s)" % str(dir))

	# Processa metade do deslocamento
	for _i in range(10):
		player._physics_process(0.017)

	_assert(player.global_position.x > 200.0 and player.global_position.y < 300.0, "Gabriel deslocou-se no plano 2.5D respeitando os eixos X e Y")

	Input.action_release("move_right")
	Input.action_release("move_up")
	player.queue_free()


func _test_normal_collision_restoration_after_dash() -> void:
	print("\n--- 8. Restauração Imediata das Colisões Pós-Dash ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(100.0, 300.0)

	player.execute_dash()

	# Processa todo o dash e recovery (0.34s + 0.08s = 0.42s)
	for _i in range(30):
		player._physics_process(0.017)

	_assert(player.is_dashing() == false, "Dash finalizado completamente")
	_assert(player.combat_state == PlayerController.CombatState.NORMAL, "Estado do jogador retornou para NORMAL")
	_assert(player.collision_layer == 1, "Collision layer do jogador restaurada para 1")
	_assert(player.collision_mask == 2, "Collision mask do jogador restaurada para 2")

	player.queue_free()


func _test_protection_and_afterimage_lifecycle() -> void:
	print("\n--- 9. Proteção Corporal e Ciclo de Vida do Afterimage ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(200.0, 300.0)

	player.execute_dash()

	# 1. Durante os primeiros 0.12s (invulnerabilidade total)
	player._physics_process(0.05)
	_assert(player.get("_is_invulnerable") == true, "Invulnerabilidade ativa no início do dash")
	var damage_res_iframe: bool = player.take_damage(25.0)
	_assert(not damage_res_iframe, "Dano total bloqueado no período de iframes")

	# 2. Aos 0.20s (iframe expirado, mas durante deslocamento do Dash: 0.20s < 0.34s)
	player._physics_process(0.15)
	_assert(player.get("_is_invulnerable") == false, "Iframe geral de 0.12s expirou")
	_assert(player.is_dashing() == true, "Deslocamento de dash ainda ativo")

	# Contato corporal/melee é protegido durante o atravessamento
	var melee_damage = {"amount": 20.0, "damage_type": "melee"}
	var contact_result: bool = player.take_damage(melee_damage)
	_assert(not contact_result, "Proteção corporal ativa durante o atravessamento do dash (dano melee ignorado)")

	# Projétil inimigo continua aplicando dano se atingir durante a proteção corporal (sem invuln total)
	var projectile_damage = {"amount": 10.0, "damage_type": "projectile"}
	var proj_result: bool = player.take_damage(projectile_damage)
	_assert(proj_result, "Dano de projétil atinge Gabriel após os iframes iniciais")

	# 3. Finaliza o dash e verifica se dano melee volta a surtir efeito normal
	for _i in range(20):
		player._physics_process(0.017)
	_assert(player.is_dashing() == false, "Dash encerrado")
	var post_dash_melee: bool = player.take_damage({"amount": 15.0, "damage_type": "melee"})
	_assert(post_dash_melee, "Após o término do Dash, dano melee é aplicado normalmente")

	player.queue_free()


func _test_movement_while_shooting_and_dash_cancel() -> void:
	print("\n--- 10. Disparo em Movimento e Cancelamento em Dash ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(200.0, 300.0)

	# Simula disparo do Passo 0 (shot_1)
	player._execute_combo_attack(0)
	_assert(player.melee_attack.is_attacking, "Passo 0 (Disparo Rápido) ativo")

	Input.action_press("move_right")
	player._physics_process(0.016)
	_assert(player.velocity.x > 0.0, "Gabriel desloca-se horizontalmente enquanto dispara Passo 0")
	Input.action_release("move_right")

	# Dash cancela o ataque imediatamente
	var dashed: bool = player.execute_dash()
	_assert(dashed, "Dash acionado cancelando a ação anterior")
	_assert(player.is_dashing(), "Estado atualizado para Dash")
	_assert(player.melee_attack.is_attacking == false, "Ataque cancelado pelo Dash")

	player.queue_free()


func _test_touch_controls_and_character_zero_regression() -> void:
	print("\n--- 11. Controles Mobile e Zero Regressão em Outros Heróis ---")
	var session = _ensure_game_session()

	# Mobile Touch
	session.selected_character_id = "gabriel"
	var touch_script: GDScript = load("res://scripts/ui/touch_controls.gd") as GDScript
	var touch: TouchControls = touch_script.new() as TouchControls
	touch.test_mode = true
	root.add_child(touch)
	touch.call("_recalculate_layout")

	_assert(touch.get("TEX_DASH") != null, "Constante TEX_DASH presente em TouchControls")
	_assert(touch.aerial_btn_pos != Vector2.ZERO, "Posição do botão aéreo/dash calculada")
	touch.queue_free()

	# Guilherme preserva pulo convencional e não pode dar Dash
	session.selected_character_id = "guilherme"
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)

	_assert(not player.is_gabriel(), "Identificado como NÃO Gabriel (Guilherme)")
	var dash_result: bool = player.execute_dash()
	_assert(not dash_result, "Guilherme NÃO pode executar Dash (execute_dash retorna false)")

	player._try_jump()
	_assert(player.get("_is_jumping") == true, "Guilherme preserva pulo convencional (_is_jumping == true)")

	player.queue_free()


func _test_gabriel_audio_integration() -> void:
	print("\n--- 12. Validação dos Efeitos Sonoros do Gabriel (SFX) ---")
	var feedback_class = load("res://scripts/combat/combat_feedback.gd")
	_assert(feedback_class != null, "CombatFeedback carregado")

	# 1. Existência e carregamento dos arquivos MP3
	_assert(ResourceLoader.exists(feedback_class.SFX_GABRIEL_TIRO_1), "tiro1.mp3 existe em assets/audio/sfx/")
	_assert(ResourceLoader.exists(feedback_class.SFX_GABRIEL_TIRO_2), "tiro2.mp3 existe em assets/audio/sfx/")
	_assert(ResourceLoader.exists(feedback_class.SFX_GABRIEL_CORONHADA), "coronhaada.mp3 existe em assets/audio/sfx/")
	_assert(ResourceLoader.exists(feedback_class.SFX_GABRIEL_DASH), "dash_gabriel.mp3 existe em assets/audio/sfx/")

	# 2. Métodos dedicados em CombatFeedback
	_assert(feedback_class.has_method("play_gabriel_gunshot"), "Método play_gabriel_gunshot presente")
	_assert(feedback_class.has_method("play_gabriel_dash"), "Método play_gabriel_dash presente")
	_assert(feedback_class.has_method("play_gabriel_handling"), "Método play_gabriel_handling presente")

	# 3. Sons de disparo simples e duplo disparados no momento de criação do projétil
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)

	# Disparo simples (Passo 0) cria projétil com disparo sincronizado
	var bullet_p0: Area2D = player._spawn_single_bullet(player._combo_attacks[0], 14.0, 0)
	_assert(bullet_p0 != null, "Projétil do Passo 0 instanciado")
	bullet_p0.queue_free()

	# Disparo duplo (Passo 1): projétil 0 e projétil 1
	var bullet_p1_a: Area2D = player._spawn_single_bullet(player._combo_attacks[1], 7.0, 0)
	var bullet_p1_b: Area2D = player._spawn_single_bullet(player._combo_attacks[1], 7.0, 1)
	_assert(bullet_p1_a != null and bullet_p1_b != null, "Ambos projéteis da rajada dupla instanciados com índices 0 e 1")
	bullet_p1_a.queue_free()
	bullet_p1_b.queue_free()

	player.queue_free()


func _test_gabriel_special_presentation_image() -> void:
	print("\n--- 13. Validação da Imagem do Especial do Gabriel ---")
	var img_path := "res://assets/sprites/characters/gabriel/especial1_gabriel.webp"
	_assert(ResourceLoader.exists(img_path), "especial1_gabriel.webp existe no caminho oficial")

	var tex: Texture2D = load(img_path) as Texture2D
	_assert(tex != null, "especial1_gabriel.webp carrega com sucesso como Texture2D")

	var gabriel_res: Resource = load("res://resources/heroes/gabriel_data.tres")
	_assert(gabriel_res != null, "gabriel_data.tres carregado")
	var special_tex = gabriel_res.get("special_presentation_texture")
	_assert(special_tex != null, "special_presentation_texture configurado em gabriel_data.tres")

	# Testa resolução automática na classe SpecialPresentation
	var special_class = load("res://scripts/combat/special_presentation.gd")
	var presentation: CanvasLayer = special_class.new()
	presentation.hero_id = "gabriel"
	presentation.hero_data = gabriel_res
	root.add_child(presentation)
	var resolved_tex = presentation.call("_resolve_hero_texture")
	_assert(resolved_tex != null, "SpecialPresentation resolve com sucesso a textura cinematográfica do Gabriel")
	presentation.queue_free()
