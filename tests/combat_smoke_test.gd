extends SceneTree

const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const MeleeAttackClass = preload("res://scripts/components/melee_attack.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES AUTOMATIZADOS DE COMBATE")
	print("==================================================")

	test_health_component_rules()
	test_2d_depth_and_range_attack_rules()
	await test_obstacle_blocks_melee_attack()
	test_single_damage_per_attack_execution()
	test_defeated_target_cannot_take_further_damage()
	test_defeated_actor_cannot_attack()
	test_player_scene_integration()
	test_enemy_scene_integration()

	print("==================================================")
	print("RESULTADO DOS TESTES: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func test_health_component_rules() -> void:
	print("\n--- Testando HealthComponent ---")
	var health = HealthComponentClass.new()
	health.max_health = 100.0
	health._ready()

	assert_test(health.current_health == 100.0, "Vida inicial igual a max_health")
	
	var damaged: bool = health.take_damage(30.0)
	assert_test(damaged and health.current_health == 70.0, "Aplicação de dano reduz vida corretamente")

	health.take_damage(999.0)
	assert_test(health.current_health == 0.0, "Vida não desce abaixo de zero")
	assert_test(health.is_dead == true, "is_dead é verdadeiro ao atingir 0 de vida")

	var further_damage: bool = health.take_damage(20.0)
	assert_test(not further_damage, "Alvo derrotado não recebe dano adicional")

	health.reset()
	assert_test(health.current_health == 100.0 and not health.is_dead, "Reset restaura vida e estado is_dead")
	health.free()


func test_2d_depth_and_range_attack_rules() -> void:
	print("\n--- Testando Regras de Alcance e Profundidade 2.5D (MeleeAttack) ---")
	
	var root_node := Node2D.new()
	root.add_child(root_node)

	var attacker := CharacterBody2D.new()
	attacker.add_to_group("player")
	attacker.global_position = Vector2(200, 500)
	root_node.add_child(attacker)

	var atk_health = HealthComponentClass.new()
	attacker.add_child(atk_health)
	atk_health._ready()

	var attack = MeleeAttackClass.new()
	attack.damage = 25.0
	attack.horizontal_range = 70.0
	attack.depth_tolerance = 25.0
	attack.target_group = "enemies"
	attacker.add_child(attack)
	attack._ready()

	var target := CharacterBody2D.new()
	target.add_to_group("enemies")
	root_node.add_child(target)

	var target_health = HealthComponentClass.new()
	target.add_child(target_health)
	target_health._ready()

	# Cenário 1: Alvo à frente na mesma profundidade -> DEVE ACERTAR
	target.global_position = Vector2(240, 500)
	attack.execute_attack(1.0)
	assert_test(target_health.current_health == 75.0, "Cenário 1: Ataque acerta à frente na mesma profundidade")

	# Reseta
	target_health.reset()
	attack.cancel_attack()

	# Cenário 2: Alvo fora do alcance horizontal (> 70px) -> DEVE ERRAR
	target.global_position = Vector2(300, 500)
	attack.execute_attack(1.0)
	assert_test(target_health.current_health == 100.0, "Cenário 2: Ataque erra quando fora do alcance horizontal")

	# Reseta
	target_health.reset()
	attack.cancel_attack()

	# Cenário 3: Alvo fora da tolerância de profundidade (> 25px no eixo Y) -> DEVE ERRAR
	target.global_position = Vector2(240, 535)
	attack.execute_attack(1.0)
	assert_test(target_health.current_health == 100.0, "Cenário 3: Ataque erra quando fora da tolerância de profundidade Y")

	# Reseta
	target_health.reset()
	attack.cancel_attack()

	# Cenário 4: Alvo atrás do atacante (dx < 0 virado para a direita) -> DEVE ERRAR
	target.global_position = Vector2(160, 500)
	attack.execute_attack(1.0)
	assert_test(target_health.current_health == 100.0, "Cenário 4: Ataque não acerta alvo nas costas")

	root_node.free()


func test_obstacle_blocks_melee_attack() -> void:
	print("\n--- Testando Linha de Visão e Bloqueio por Obstáculos (Layer 2) ---")
	var root_node := Node2D.new()
	root.add_child(root_node)

	var attacker := CharacterBody2D.new()
	attacker.add_to_group("player")
	attacker.global_position = Vector2(200, 500)
	root_node.add_child(attacker)

	var atk_health = HealthComponentClass.new()
	attacker.add_child(atk_health)
	atk_health._ready()

	var attack = MeleeAttackClass.new()
	attack.damage = 25.0
	attack.horizontal_range = 70.0
	attack.depth_tolerance = 25.0
	attack.target_group = "enemies"
	attack.check_obstacles = true
	attack.obstacle_collision_mask = 2
	attacker.add_child(attack)
	attack._ready()

	var target := CharacterBody2D.new()
	target.add_to_group("enemies")
	target.global_position = Vector2(240, 500)
	root_node.add_child(target)

	var target_health = HealthComponentClass.new()
	target.add_child(target_health)
	target_health._ready()

	# Cria obstáculo sólido (Layer 2) entre o atacante e o alvo (em X = 220)
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	wall.collision_mask = 0
	wall.global_position = Vector2(220, 500)
	var wall_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 80)
	wall_shape.shape = rect
	wall.add_child(wall_shape)
	root_node.add_child(wall)

	# Aguarda sincronização do PhysicsServer2D
	await physics_frame
	await physics_frame

	# Cenário A: Com obstáculo entre os dois atores, golpe DEVE SER BLOQUEADO
	attack.execute_attack(1.0)
	assert_test(target_health.current_health == 100.0, "Cenário 4B: Ataque é bloqueado por obstáculo sólido na Layer 2")

	# Remove o obstáculo
	wall.free()
	target_health.reset()
	attack.cancel_attack()

	# Aguarda liberação da física
	await physics_frame
	await physics_frame

	# Cenário B: Sem obstáculo, golpe DEVE ACERTAR
	attack.execute_attack(1.0)
	assert_test(target_health.current_health == 75.0, "Cenário 4C: Ataque atinge o alvo com sucesso quando caminho está desobstruído")

	attack.cancel_attack()
	root_node.free()


func test_single_damage_per_attack_execution() -> void:
	print("\n--- Testando Dano Único por Execução de Ataque ---")
	
	var root_node := Node2D.new()
	root.add_child(root_node)

	var attacker := CharacterBody2D.new()
	attacker.global_position = Vector2(200, 500)
	attacker.add_to_group("player")
	root_node.add_child(attacker)

	var atk_health = HealthComponentClass.new()
	attacker.add_child(atk_health)
	atk_health._ready()

	var attack = MeleeAttackClass.new()
	attack.damage = 20.0
	attack.horizontal_range = 70.0
	attack.depth_tolerance = 25.0
	attack.target_group = "enemies"
	attacker.add_child(attack)
	attack._ready()

	var target := CharacterBody2D.new()
	target.global_position = Vector2(230, 500)
	target.add_to_group("enemies")
	root_node.add_child(target)

	var target_health = HealthComponentClass.new()
	target.add_child(target_health)
	target_health._ready()

	# Dispara ataque
	attack.execute_attack(1.0)
	# Tenta atingir o mesmo alvo novamente dentro da mesma execução
	attack._try_hit_target(target)
	attack._try_hit_target(target)

	assert_test(target_health.current_health == 80.0, "Cenário 5: Alvo sobreposto recebe dano exatamente 1 vez por golpe")

	# Cenário 6: Novo ataque após intervalo pode causar novo dano
	attack.cancel_attack()
	attack.execute_attack(1.0)
	assert_test(target_health.current_health == 60.0, "Cenário 6: Novo ataque válido causa novo dano após intervalo")

	root_node.free()


func test_defeated_target_cannot_take_further_damage() -> void:
	print("\n--- Testando Inimigo Derrotado ---")
	
	var root_node := Node2D.new()
	root.add_child(root_node)

	var attacker := CharacterBody2D.new()
	attacker.global_position = Vector2(200, 500)
	root_node.add_child(attacker)

	var attack = MeleeAttackClass.new()
	attack.damage = 100.0
	attack.horizontal_range = 70.0
	attack.depth_tolerance = 25.0
	attack.target_group = "enemies"
	attacker.add_child(attack)
	attack._ready()

	var target := CharacterBody2D.new()
	target.global_position = Vector2(230, 500)
	target.add_to_group("enemies")
	root_node.add_child(target)

	var target_health = HealthComponentClass.new()
	target.add_child(target_health)
	target_health._ready()

	# Primeiro golpe derrota o inimigo
	attack.execute_attack(1.0)
	assert_test(target_health.is_dead, "Inimigo atinge estado de derrota")

	# Segundo golpe não deve causar nada nem alterar a vida
	attack.cancel_attack()
	attack.execute_attack(1.0)
	assert_test(target_health.current_health == 0.0, "Cenário 7: Inimigo derrotado não sofre dano subsequente")

	root_node.free()


func test_defeated_actor_cannot_attack() -> void:
	print("\n--- Testando Ator Derrotado Impedido de Atacar ---")
	
	var actor := CharacterBody2D.new()
	var health = HealthComponentClass.new()
	health.max_health = 50.0
	actor.add_child(health)
	health._ready()

	var attack = MeleeAttackClass.new()
	actor.add_child(attack)
	attack._ready()

	# Derrota o ator
	health.take_damage(100.0)
	assert_test(health.is_dead, "Ator está marcado como derrotado")

	# Tenta atacar
	var started: bool = attack.execute_attack(1.0)
	assert_test(not started and not attack.is_attacking, "Cenário 12: Ator derrotado não consegue iniciar ataques")

	actor.free()


func test_player_scene_integration() -> void:
	print("\n--- Testando Integração da Cena do Jogador (player.tscn) ---")
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	assert_test(player_scene != null, "player.tscn carregada com sucesso")

	var player_instance: Node = player_scene.instantiate()
	assert_test(player_instance is CharacterBody2D, "Player é um CharacterBody2D")
	assert_test(player_instance.get_node_or_null("HealthComponent") != null, "Player possui HealthComponent")
	var anim_sprite: AnimatedSprite2D = player_instance.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	assert_test(anim_sprite != null, "Player possui AnimatedSprite2D no nó Visual")
	if anim_sprite != null and anim_sprite.sprite_frames != null:
		var has_punch: bool = anim_sprite.sprite_frames.has_animation(&"punch")
		assert_test(has_punch, "Player possui animacao 'punch' no SpriteFrames")
		if has_punch:
			var frame_count: int = anim_sprite.sprite_frames.get_frame_count(&"punch")
			assert_test(frame_count == 3, "Animacao 'punch' possui exatamente 3 frames (punch_01, 02, 03)")
			assert_test(not anim_sprite.sprite_frames.get_animation_loop(&"punch"), "Animacao 'punch' nao deve repetir em loop")

		assert_test(anim_sprite.sprite_frames.has_animation(&"kick"), "Player possui animacao 'kick' no SpriteFrames")
		assert_test(anim_sprite.sprite_frames.get_frame_count(&"kick") == 3, "Animacao 'kick' possui 3 frames")

		assert_test(anim_sprite.sprite_frames.has_animation(&"heavy"), "Player possui animacao 'heavy' no SpriteFrames")
		assert_test(anim_sprite.sprite_frames.get_frame_count(&"heavy") == 3, "Animacao 'heavy' possui 3 frames")

		assert_test(anim_sprite.sprite_frames.has_animation(&"guard"), "Player possui animacao 'guard' no SpriteFrames")
		assert_test(anim_sprite.sprite_frames.has_animation(&"hurt"), "Player possui animacao 'hurt' no SpriteFrames")
		assert_test(anim_sprite.sprite_frames.get_frame_count(&"hurt") == 2, "Animacao 'hurt' possui 2 frames")

		assert_test(anim_sprite.sprite_frames.has_animation(&"fall"), "Player possui animacao 'fall' no SpriteFrames")
		assert_test(anim_sprite.sprite_frames.get_frame_count(&"fall") == 3, "Animacao 'fall' possui 3 frames")

		assert_test(anim_sprite.sprite_frames.has_animation(&"getup"), "Player possui animacao 'getup' no SpriteFrames")
		assert_test(anim_sprite.sprite_frames.has_animation(&"death"), "Player possui animacao 'death' no SpriteFrames")

		assert_test(anim_sprite.sprite_frames.has_animation(&"jump"), "Player possui animacao 'jump' no SpriteFrames")
		assert_test(anim_sprite.sprite_frames.get_frame_count(&"jump") == 3, "Animacao 'jump' possui 3 frames")

		assert_test(anim_sprite.sprite_frames.has_animation(&"jump_atk"), "Player possui animacao 'jump_atk' no SpriteFrames")
		assert_test(anim_sprite.sprite_frames.get_frame_count(&"jump_atk") == 2, "Animacao 'jump_atk' possui 2 frames")
	player_instance.free()


func test_enemy_scene_integration() -> void:
	print("\n--- Testando Integração da Cena do Inimigo (basic_enemy.tscn) ---")
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	assert_test(enemy_scene != null, "basic_enemy.tscn carregada com sucesso")

	var enemy_instance: Node = enemy_scene.instantiate()
	assert_test(enemy_instance is CharacterBody2D, "BasicEnemy é um CharacterBody2D")
	assert_test(enemy_instance.get_node_or_null("HealthComponent") != null, "BasicEnemy possui HealthComponent")
	assert_test(enemy_instance.get_node_or_null("MeleeAttack") != null, "BasicEnemy possui MeleeAttack")
	assert_test(enemy_instance.get_node_or_null("FloatingHealthBar") != null, "BasicEnemy possui barra de vida flutuante")
	enemy_instance.free()
