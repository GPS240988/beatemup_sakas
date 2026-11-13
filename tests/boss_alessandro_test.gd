extends SceneTree

## Suíte de Testes Automatizados Headless para o Chefe Alessandro e os Novos Controles de Combate.

const BossAlessandroClass = preload("res://scripts/actors/boss_alessandro.gd")
const TruffleClass = preload("res://scripts/actors/projectiles/trufa.gd")
const BaseLevelClass = preload("res://scripts/levels/base_level.gd")
const PlayerControllerClass = preload("res://scripts/actors/player_controller.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES DO CHEFE ALESSANDRO E CONTROLES")
	print("==================================================")

	test_boss_alessandro_scene_and_properties()
	test_truffle_projectile_contract()
	test_player_new_attack_controls()
	test_map1_no_boss_and_map4_boss_spawn()

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


func test_boss_alessandro_scene_and_properties() -> void:
	print("\n--- Testando Propriedades do Chefe Alessandro ---")
	var scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn")
	assert_test(scene != null, "Cena boss_alessandro.tscn carregada com sucesso")

	var boss = scene.instantiate() as BossAlessandroClass
	root.add_child(boss)

	assert_test(boss != null, "Instanciação de BossAlessandro válida")
	assert_test(boss.health_component != null and boss.health_component.max_health == 200.0, "Chefe possui 200 HP de vida inicial")
	assert_test(boss.anim_sprite != null, "AnimatedSprite2D do Chefe existe")

	var frames: SpriteFrames = boss.anim_sprite.sprite_frames
	assert_test(frames != null, "SpriteFrames de Alessandro carregado")
	assert_test(frames.has_animation("walk"), "Animação 'walk' presente")
	assert_test(frames.has_animation("punch"), "Animação 'punch' presente")
	assert_test(frames.has_animation("kick"), "Animação 'kick' presente")
	assert_test(frames.has_animation("combo"), "Animação 'combo' presente")
	assert_test(frames.has_animation("jump_atk"), "Animação 'jump_atk' presente")
	assert_test(frames.has_animation("guard"), "Animação 'guard' presente")
	assert_test(frames.has_animation("hurt"), "Animação 'hurt' presente")
	assert_test(frames.has_animation("fall"), "Animação 'fall' presente")
	assert_test(frames.has_animation("getup"), "Animação 'getup' presente")
	assert_test(frames.has_animation("death"), "Animação 'death' presente")

	assert_test(boss.collision_layer == 1, "BossAlessandro corpo físico na Layer 1")
	assert_test(boss.collision_mask == 2, "BossAlessandro colide apenas com o mundo físico")
	var boss_hurtbox: Area2D = boss.get_node_or_null("Hurtbox") as Area2D
	assert_test(boss_hurtbox != null and boss_hurtbox.collision_layer == 4, "Hurtbox do chefe na Layer 3")
	assert_test(boss_hurtbox != null and boss_hurtbox.collision_mask == 0, "Hurtbox do chefe não monitora máscaras ativas")
	var boss_hitbox: Area2D = boss.get_node_or_null("MeleeAttack/HitboxArea") as Area2D
	assert_test(boss_hitbox != null and boss_hitbox.collision_layer == 8, "Hitbox do chefe na Layer 4")
	assert_test(boss_hitbox != null and boss_hitbox.collision_mask == 4, "Hitbox do chefe monitora Hurtboxes na Layer 3")

	assert_test(boss.attack_windup_seconds == 0.20, "Telegraph calibrado em 0.20s")
	assert_test(boss.attack_cooldown == 0.65, "Cooldown de ataque calibrado em 0.65s")
	assert_test(boss.recovery_duration == 0.35, "Recovery calibrada em 0.35s")
	assert_test(boss.recoil_distance == 35.0, "Recuo calibrado em 35px")
	assert_test(boss.hurt_duration == 0.18, "Hit stun calibrado em 0.18s")
	assert_test(boss.post_hurt_cooldown == 0.30, "Cooldown pós-dano calibrado em 0.30s")
	assert_test(boss.chase_timeout_seconds == 4.0, "Timeout de perseguição calibrado em 4.0s")
	assert_test(boss._special_behavior == BossAlessandroClass.SpecialBehavior.NONE, "Chefe inicia sem comportamento especial ativo")
	assert_test(boss._truffles_remaining == 0, "Chefe inicia sem trufas pendentes")

	boss.free()


func test_truffle_projectile_contract() -> void:
	print("\n--- Testando Projétil de Trufa ---")
	var scene: PackedScene = load("res://scenes/actors/projectiles/trufa.tscn")
	assert_test(scene != null, "Cena trufa.tscn carregada com sucesso")
	if scene == null:
		return

	var truffle := scene.instantiate() as TruffleClass
	root.add_child(truffle)
	assert_test(truffle != null, "Instância de AlessandroTruffle válida")
	assert_test(truffle.collision_mask == 2, "Corpo físico da trufa colide com o cenário na Layer 2")
	assert_test(truffle.gravity_scale == 0.0, "Trufa não sofre gravidade")
	assert_test(truffle.hitbox != null and truffle.hitbox.collision_layer == 8, "Hitbox da trufa usa Layer 4")
	assert_test(truffle.hitbox != null and truffle.hitbox.collision_mask == 4, "Hitbox da trufa detecta Hurtboxes na Layer 3")
	assert_test(truffle.lifetime_timer != null and is_equal_approx(truffle.lifetime_timer.wait_time, 4.0), "Trufa possui tempo de vida limitado a 4 segundos")
	truffle.free()


func test_player_new_attack_controls() -> void:
	print("\n--- Testando Novos Controles de Combate do Herói ---")
	var scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player = scene.instantiate() as PlayerControllerClass
	root.add_child(player)

	assert_test(player != null, "Instanciação do Player válida")
	player._try_punch()
	assert_test(player.melee_attack.is_attacking, "Golpe de Soco executado")
	assert_test(player._current_attack_anim == &"punch", "Animação de Soco selecionada")
	player.melee_attack.cancel_attack()

	player._try_kick()
	assert_test(player.melee_attack.is_attacking, "Golpe de Chute executado")
	assert_test(player._current_attack_anim == &"kick", "Animação de Chute selecionada")
	player.melee_attack.cancel_attack()

	player._try_special()
	assert_test(player.melee_attack.is_attacking, "Golpe Especial executado")
	assert_test(player._current_attack_anim == &"heavy", "Animação de Especial selecionada")
	player.melee_attack.cancel_attack()

	player._try_aerial_attack()
	assert_test(player._is_jumping, "Ataque Aéreo ativa estado de projeção aérea")
	assert_test(player._current_attack_anim == &"jump_atk", "Animação de Ataque Aéreo selecionada")
	player.melee_attack.cancel_attack()
	player.free()


func test_map1_no_boss_and_map4_boss_spawn() -> void:
	print("\n--- Testando Ausência de Chefe no Mapa 1 e Presença no Mapa 4 ---")
	var map1_scene: PackedScene = load("res://scenes/levels/map_1.tscn")
	var map1 = map1_scene.instantiate() as BaseLevelClass
	root.add_child(map1)
	assert_test(map1.boss_scene == null, "boss_scene é null no Mapa 1")
	map1.free()

	var map4_scene: PackedScene = load("res://scenes/levels/map_4.tscn")
	var map4 = map4_scene.instantiate() as BaseLevelClass
	root.add_child(map4)
	assert_test(map4.boss_scene != null, "boss_scene está configurada no Mapa 4")
	assert_test(not map4._boss_spawned, "Chefe não está spawnado inicialmente")
	assert_test(not map4.exit_area.monitoring, "Saída bloqueada no início do combate")
	assert_test(map4.combat_director != null and map4.combat_director.pending_spawns_count == 1, "Chefe registrado como spawn pendente")

	map4._on_encounter_cleared()
	assert_test(not map4.exit_area.monitoring, "Saída permanece bloqueada antes da derrota do chefe")
	assert_test(not map4.siga_indicator.visible, "Indicador SIGA permanece oculto antes da vitória")

	map4.reinforcement_waves_enabled = false
	var dummy_enemy := CharacterBody2D.new()
	map4._on_enemy_defeated(dummy_enemy)
	assert_test(map4._boss_spawned, "Chefe invocado após derrota dos capangas")
	assert_test(map4._boss_instance != null, "Instância de Alessandro criada no Mapa 4")
	assert_test(map4.combat_director.pending_spawns_count == 0, "Spawns pendentes zerados após invocação")
	assert_test(not map4.exit_area.monitoring, "Saída permanece bloqueada durante a luta")

	var player = map4.player
	if player != null:
		player.global_position.x = 1600.0
		map4._update_camera(1.0)
		assert_test(map4.camera.global_position.x >= 1340.0, "Câmera acompanha o jogador próximo ao chefe")

	map4._on_encounter_cleared()
	assert_test(map4.exit_area.monitoring, "Saída liberada após derrota do chefe")
	assert_test(map4.siga_indicator.visible, "Indicador SIGA ativado após vitória")
	dummy_enemy.free()
	map4.free()
