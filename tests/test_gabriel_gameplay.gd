extends SceneTree

## Suíte de Testes Automatizada: Gameplay do Gabriel (Etapas 03, 04 e 05)
## Valida o sistema de pistola, combo de 4 movimentos, mobilidade e salto tático.

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	call_deferred("_run_all_tests")


func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] %s" % test_name)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % test_name)


func _run_all_tests() -> void:
	print("\n==================================================")
	print("INICIANDO TESTES: GAMEPLAY GABRIEL (PISTOLA, COMBO, MOBILIDADE)")
	print("==================================================")
	
	_ensure_game_session()
	
	_test_player_bullet_properties_and_scene()
	_test_bullet_depth_filtering()
	_test_bullet_obstacle_collision()
	_test_bullet_single_hit_and_evasion()
	_test_gabriel_combo_chain_structure()
	_test_gabriel_combo_damage_budget()
	_test_gabriel_combo_progression()
	_test_gabriel_mobility_and_aerial()
	_test_guilherme_zero_regression()
	
	print("\n==================================================")
	print("RESULTADO DOS TESTES: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")
	
	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _ensure_game_session() -> Node:
	var session = root.get_node_or_null("GameSession")
	if session == null:
		var session_script = load("res://scripts/core/game_session.gd") as GDScript
		session = session_script.new()
		session.name = "GameSession"
		root.add_child(session)
	return session


func _test_player_bullet_properties_and_scene() -> void:
	print("\n--- 1. Validando Cena e Propriedades do PlayerBullet (Etapa 03) ---")
	var bullet_scene: PackedScene = load("res://scenes/actors/projectiles/player_bullet.tscn")
	_assert(bullet_scene != null, "player_bullet.tscn carregada com sucesso")
	
	var bullet = bullet_scene.instantiate() as Area2D
	_assert(bullet != null, "PlayerBullet instanciado como Area2D")
	_assert(bullet.is_in_group("projectiles"), "PlayerBullet está no grupo 'projectiles'")
	_assert(bullet.is_in_group("player_projectiles"), "PlayerBullet está no grupo 'player_projectiles'")
	_assert(bullet.collision_layer == 8, "PlayerBullet possui collision_layer = 8 (Hitbox)")
	_assert(bullet.collision_mask == 6, "PlayerBullet possui collision_mask = 6 (Layer 2 mundo + Layer 3 hurtbox)")
	_assert(is_equal_approx(bullet.speed, 700.0), "Velocidade padrão do projétil é 700 px/s")
	
	var sprite = bullet.get_node_or_null("Sprite2D") as Sprite2D
	_assert(sprite != null, "Sprite2D visual de PixelFX presente no projétil")
	_assert(sprite.texture != null, "Textura de bullet-tracer vinculada")
	_assert(sprite.hframes == 2 and sprite.vframes == 9, "Grid de 2 colunas e 9 linhas (18 frames) configurado")
	
	bullet.queue_free()


func _test_bullet_depth_filtering() -> void:
	print("\n--- 2. Validando Filtragem de Profundidade 2.5D do Projétil ---")
	var bullet_script = load("res://scripts/actors/projectiles/player_bullet.gd")
	var bullet: Area2D = bullet_script.new() as Area2D
	bullet.projectile_lane_y = 400.0
	bullet.depth_tolerance = 24.0
	bullet.damage = 14.0
	root.add_child(bullet)
	
	# Cria inimigo de teste dentro da profundidade (Y = 415, diferença = 15 <= 24)
	var enemy_in := CharacterBody2D.new()
	enemy_in.add_to_group("enemies")
	enemy_in.global_position = Vector2(200.0, 415.0)
	var health_in = Node.new()
	health_in.name = "HealthComponent"
	var health_script = load("res://scripts/components/health_component.gd")
	health_in.set_script(health_script)
	enemy_in.add_child(health_in)
	root.add_child(enemy_in)
	
	var hit_in: bool = bullet.test_hit_candidate(enemy_in)
	_assert(hit_in, "Alvo dentro da tolerância de profundidade (diff 15 <= 24) é atingido")
	
	# Novo projétil para testar alvo fora da profundidade
	var bullet_out: Area2D = bullet_script.new() as Area2D
	bullet_out.projectile_lane_y = 400.0
	bullet_out.depth_tolerance = 24.0
	bullet_out.damage = 14.0
	root.add_child(bullet_out)
	
	# Cria inimigo de teste fora da profundidade (Y = 435, diferença = 35 > 24)
	var enemy_out := CharacterBody2D.new()
	enemy_out.add_to_group("enemies")
	enemy_out.global_position = Vector2(200.0, 435.0)
	var health_out = Node.new()
	health_out.name = "HealthComponent"
	health_out.set_script(health_script)
	enemy_out.add_child(health_out)
	root.add_child(enemy_out)
	
	var hit_out: bool = bullet_out.test_hit_candidate(enemy_out)
	_assert(not hit_out, "Alvo fora da tolerância de profundidade (diff 35 > 24) não é atingido")
	
	enemy_in.queue_free()
	enemy_out.queue_free()
	bullet_out.queue_free()


func _test_bullet_obstacle_collision() -> void:
	print("\n--- 3. Validando Colisão com Obstáculos Sólidos (Layer 2) ---")
	var bullet_script = load("res://scripts/actors/projectiles/player_bullet.gd")
	var bullet: Area2D = bullet_script.new() as Area2D
	root.add_child(bullet)
	
	# Obstáculo estático do cenário (parede / balcão)
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	root.add_child(wall)
	
	bullet._on_body_entered(wall)
	_assert(bullet.get("_has_hit") == true, "Projétil é consumido ao colidir com corpo estático de cenário na Layer 2")
	
	wall.queue_free()
	bullet.queue_free()


func _test_bullet_single_hit_and_evasion() -> void:
	print("\n--- 4. Validando Consumo Único (Sem Perfuração Infinita) e Evasão Aérea ---")
	var bullet_script = load("res://scripts/actors/projectiles/player_bullet.gd")
	var health_script = load("res://scripts/components/health_component.gd")
	
	# Evasão aérea: Inimigo no ar evita o projétil via deslocamento visual
	var bullet_air: Area2D = bullet_script.new() as Area2D
	bullet_air.projectile_lane_y = 400.0
	bullet_air.depth_tolerance = 24.0
	root.add_child(bullet_air)
	
	var enemy_jumping := CharacterBody2D.new()
	enemy_jumping.add_to_group("enemies")
	enemy_jumping.global_position = Vector2(200.0, 400.0)
	var visual_j := Node2D.new()
	visual_j.name = "Visual"
	visual_j.position.y = -50.0 # Projeção de salto no ar
	enemy_jumping.add_child(visual_j)
	var health_j = Node.new()
	health_j.name = "HealthComponent"
	health_j.set_script(health_script)
	enemy_jumping.add_child(health_j)
	root.add_child(enemy_jumping)
	
	var hit_jumping: bool = bullet_air.test_hit_candidate(enemy_jumping)
	_assert(not hit_jumping, "Inimigo no ar desvia do tiro por baixo (MISS de evasão aérea)")
	
	# Consumo único: Projétil não atinge segundo alvo
	var bullet_single: Area2D = bullet_script.new() as Area2D
	bullet_single.projectile_lane_y = 400.0
	bullet_single.depth_tolerance = 24.0
	bullet_single.damage = 14.0
	root.add_child(bullet_single)
	
	var enemy_1 := CharacterBody2D.new()
	enemy_1.add_to_group("enemies")
	enemy_1.global_position = Vector2(200.0, 400.0)
	var h1 = Node.new()
	h1.name = "HealthComponent"
	h1.set_script(health_script)
	enemy_1.add_child(h1)
	root.add_child(enemy_1)
	
	var enemy_2 := CharacterBody2D.new()
	enemy_2.add_to_group("enemies")
	enemy_2.global_position = Vector2(220.0, 400.0)
	var h2 = Node.new()
	h2.name = "HealthComponent"
	h2.set_script(health_script)
	enemy_2.add_child(h2)
	root.add_child(enemy_2)
	
	var first_hit: bool = bullet_single.test_hit_candidate(enemy_1)
	var second_hit: bool = bullet_single.test_hit_candidate(enemy_2)
	_assert(first_hit == true, "Primeiro inimigo é atingido com sucesso")
	_assert(second_hit == false, "Segundo inimigo NÃO é atingido (tiro único, sem perfuração infinita)")
	
	enemy_jumping.queue_free()
	enemy_1.queue_free()
	enemy_2.queue_free()
	bullet_single.queue_free()


func _test_gabriel_combo_chain_structure() -> void:
	print("\n--- 5. Validando Estrutura do Combo de 4 Movimentos (Etapa 04) ---")
	var session = _ensure_game_session()
	session.select_character("gabriel")
	
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	
	_assert(player.is_gabriel(), "PlayerController identifica hero_id como Gabriel")
	
	var attacks: Array = player.get("_combo_attacks")
	_assert(attacks.size() == 4, "Combo possui exatamente 4 passos configurados")
	
	# Passo 1
	var atk1 = attacks[0]
	_assert(atk1.get("is_projectile") == true, "Passo 1 é baseado em projétil")
	_assert(atk1.get("projectile_count") == 1, "Passo 1 dispara 1 projétil")
	_assert(is_equal_approx(atk1.get("horizontal_range"), 280.0), "Passo 1 alcance horizontal é 280 px")
	_assert(is_equal_approx(atk1.get("depth_tolerance"), 24.0), "Passo 1 tolerância de profundidade é 24 px")
	_assert(is_equal_approx(atk1.get("startup"), 0.03), "Passo 1 startup é 0.03s")
	_assert(is_equal_approx(atk1.get("active"), 0.08), "Passo 1 active é 0.08s")
	_assert(is_equal_approx(atk1.get("recovery"), 0.12), "Passo 1 recovery é 0.12s")
	_assert(atk1.get("can_knockdown") == false, "Passo 1 NÃO causa knockdown")
	
	# Passo 2
	var atk2 = attacks[1]
	_assert(atk2.get("is_projectile") == true, "Passo 2 é baseado em projétil")
	_assert(atk2.get("projectile_count") == 2, "Passo 2 dispara 2 projéteis (rajada dupla)")
	_assert(is_equal_approx(atk2.get("projectile_interval"), 0.06), "Passo 2 intervalo entre disparos é 0.06s")
	_assert(is_equal_approx(atk2.get("horizontal_range"), 300.0), "Passo 2 alcance horizontal é 300 px")
	_assert(is_equal_approx(atk2.get("depth_tolerance"), 26.0), "Passo 2 tolerância de profundidade é 26 px")
	_assert(is_equal_approx(atk2.get("startup"), 0.04), "Passo 2 startup é 0.04s")
	_assert(is_equal_approx(atk2.get("active"), 0.10), "Passo 2 active é 0.10s")
	_assert(is_equal_approx(atk2.get("recovery"), 0.15), "Passo 2 recovery é 0.15s")
	_assert(atk2.get("can_knockdown") == false, "Passo 2 NÃO causa knockdown")
	
	# Passo 3
	var atk3 = attacks[2]
	_assert(atk3.get("is_projectile") == false, "Passo 3 é ataque corpo a corpo físico (coronhada / pistolada)")
	_assert(is_equal_approx(atk3.get("horizontal_range"), 75.0), "Passo 3 alcance horizontal curto é 75 px")
	_assert(is_equal_approx(atk3.get("depth_tolerance"), 28.0), "Passo 3 tolerância de profundidade é 28 px")
	_assert(is_equal_approx(atk3.get("startup"), 0.03), "Passo 3 startup é 0.03s")
	_assert(is_equal_approx(atk3.get("active"), 0.10), "Passo 3 active é 0.10s")
	_assert(is_equal_approx(atk3.get("recovery"), 0.16), "Passo 3 recovery é 0.16s")
	_assert(atk3.get("can_knockdown") == false, "Passo 3 NÃO causa knockdown")
	
	# Passo 4
	var atk4 = attacks[3]
	_assert(atk4.get("is_projectile") == true, "Passo 4 é baseado em projétil (rajada final)")
	_assert(atk4.get("projectile_count") == 1, "Passo 4 dispara 1 projétil final")
	_assert(is_equal_approx(atk4.get("horizontal_range"), 320.0), "Passo 4 alcance horizontal é 320 px")
	_assert(is_equal_approx(atk4.get("depth_tolerance"), 30.0), "Passo 4 tolerância de profundidade é 30 px")
	_assert(is_equal_approx(atk4.get("startup"), 0.05), "Passo 4 startup é 0.05s")
	_assert(is_equal_approx(atk4.get("active"), 0.12), "Passo 4 active é 0.12s")
	_assert(is_equal_approx(atk4.get("recovery"), 0.32), "Passo 4 recovery é 0.32s")
	_assert(atk4.get("can_knockdown") == true, "Passo 4 CAUSA knockdown no alvo")
	
	player.queue_free()


func _test_gabriel_combo_damage_budget() -> void:
	print("\n--- 6. Validando Orçamento de Dano Efetivo do Combo (64.0 Total) ---")
	var session = _ensure_game_session()
	session.select_character("gabriel")
	
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	
	var attacks: Array = player.get("_combo_attacks")
	var d1: float = attacks[0].damage
	var d2: float = attacks[1].damage
	var d3: float = attacks[2].damage
	var d4: float = attacks[3].damage
	
	_assert(is_equal_approx(d1, 14.0), "Dano efetivo do Passo 1 é 14.0")
	_assert(is_equal_approx(d2, 14.0), "Dano efetivo total do Passo 2 é 14.0 (2x 7.0)")
	_assert(is_equal_approx(d3, 12.0), "Dano efetivo do Passo 3 é 12.0")
	_assert(is_equal_approx(d4, 24.0), "Dano efetivo do Passo 4 é 24.0")
	
	var total_damage: float = d1 + d2 + d3 + d4
	_assert(is_equal_approx(total_damage, 64.0), "Dano total do combo do Gabriel é exatamente 64.0")
	
	player.queue_free()


func _test_gabriel_combo_progression() -> void:
	print("\n--- 7. Validando Progressão Confiável do Combo 4 Passos e Prioridade de Pickup ---")
	var session = _ensure_game_session()
	session.select_character("gabriel")
	
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	
	player.set("_combo_step", 0)
	var step1: int = player._advance_combo_step()
	_assert(step1 == 1, "Avanço de 0 para 1 é consistente")
	
	player.set("_combo_step", 1)
	var step2: int = player._advance_combo_step()
	_assert(step2 == 2, "Avanço de 1 para 2 é consistente")
	
	player.set("_combo_step", 2)
	var step3: int = player._advance_combo_step()
	_assert(step3 == 3, "Gabriel avança para o passo 3 (Heavy/Final) com 100% de garantia sem queda aleatória")
	
	player.set("_combo_step", 3)
	var step4: int = player._advance_combo_step()
	_assert(step4 == 0, "Avanço no final do combo reinicia no passo 0")
	
	# Validação de prioridade de coleta
	var pickup_scene: PackedScene = load("res://scenes/items/coca_pickup.tscn")
	var pickup = pickup_scene.instantiate()
	root.add_child(pickup)
	
	_assert(player.has_method("_try_consume_nearby_pickup"), "Método de prioridade de coleta _try_consume_nearby_pickup está presente")
	
	pickup.queue_free()
	player.queue_free()


func _test_gabriel_mobility_and_aerial() -> void:
	print("\n--- 8. Validando Mobilidade e Salto Tático (Etapa 05) ---")
	var session = _ensure_game_session()
	session.select_character("gabriel")
	
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	
	# Velocidade com multiplicador Speed 4 (1.30x)
	_assert(is_equal_approx(player.speed_x, 338.0), "Velocidade horizontal com 1.30x é 338.0 px/s (260 * 1.3)")
	_assert(is_equal_approx(player.speed_y, 247.0), "Velocidade vertical com 1.30x é 247.0 px/s (190 * 1.3)")
	
	# Executa Salto Tático
	player._try_aerial_attack()
	_assert(player.get("_is_jumping") == true, "Salto Tático ativa estado aéreo (_is_jumping = true)")
	_assert(is_equal_approx(player.get("_jump_v_velocity"), -320.0), "Impulso vertical de salto é -320.0")
	_assert(is_equal_approx(absf(player.velocity.x), 200.0), "Impulso horizontal frontal é 200.0 px/s")
	
	# Validação de bloqueio de novo salto enquanto no ar
	var prev_vel: float = player.get("_jump_v_velocity")
	player._try_aerial_attack()
	_assert(is_equal_approx(player.get("_jump_v_velocity"), prev_vel), "Não permite segundo salto enquanto já estiver no ar")
	
	# Validação do MuzzleMarker
	var visual: Node2D = player.get_node_or_null("Visual") as Node2D
	_assert(visual != null, "Nó Visual presente")
	var muzzle: Node2D = visual.get_node_or_null("MuzzleMarker") as Node2D
	_assert(muzzle != null, "MuzzleMarker presente sob Visual")
	_assert(is_equal_approx(muzzle.position.x, 45.0) and is_equal_approx(muzzle.position.y, -115.0), "MuzzleMarker posicionado na coordenada correta do cano da pistola")
	
	# Validação do cálculo de posição global de tiro considerando projeção visual
	var muzzle_gpos: Vector2 = player._get_muzzle_global_position()
	_assert(muzzle_gpos != Vector2.ZERO, "Posição global do muzzle resolvida corretamente")
	
	player.queue_free()


func _test_guilherme_zero_regression() -> void:
	print("\n--- 9. Validando Zero Regressão em Guilherme ---")
	var session = _ensure_game_session()
	session.select_character("guilherme")
	
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	
	_assert(not player.is_gabriel(), "PlayerController identifica que Guilherme NÃO é Gabriel")
	
	var attacks: Array = player.get("_combo_attacks")
	_assert(attacks.size() == 4, "Guilherme possui 4 ataques no combo")
	_assert(attacks[0].get("is_projectile") == false, "Passo 1 do Guilherme é corpo a corpo físico")
	_assert(attacks[1].get("is_projectile") == false, "Passo 2 do Guilherme é corpo a corpo físico")
	_assert(attacks[2].get("is_projectile") == false, "Passo 3 do Guilherme é corpo a corpo físico")
	_assert(attacks[3].get("is_projectile") == false, "Passo 4 do Guilherme é corpo a corpo físico")
	
	var total_g: float = attacks[0].damage + attacks[1].damage + attacks[2].damage + attacks[3].damage
	_assert(is_equal_approx(total_g, 80.0), "Combo canônico de Guilherme permanece em 80.0 de dano base")
	
	player.queue_free()
