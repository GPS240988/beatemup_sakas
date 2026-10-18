extends SceneTree

## Suíte de Testes Automatizados Headless para o Chefe Alessandro e os Novos Controles de Combate.

const BossAlessandroClass = preload("res://scripts/actors/boss_alessandro.gd")
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

	var boss = scene.instantiate() as BossAlessandro
	root.add_child(boss)

	assert_test(boss != null, "Instanciação de BossAlessandro válida")
	assert_test(boss.health_component != null and boss.health_component.max_health == 200.0, "Chefe possui 200 HP de vida inicial")
	assert_test(boss.anim_sprite != null, "AnimatedSprite2D do Chefe existe")
	
	# Validação das animações dos 24 frames
	var frames: SpriteFrames = boss.anim_sprite.sprite_frames
	assert_test(frames != null, "SpriteFrames de Alessandro carregado")
	assert_test(frames.has_animation("walk"), "Animação 'walk' (4 frames) presente")
	assert_test(frames.has_animation("punch"), "Animação 'punch' (3 frames) presente")
	assert_test(frames.has_animation("kick"), "Animação 'kick' (3 frames) presente")
	assert_test(frames.has_animation("combo"), "Animação 'combo' (3 frames) presente")
	assert_test(frames.has_animation("jump_atk"), "Animação 'jump_atk' (2 frames) presente")
	assert_test(frames.has_animation("guard"), "Animação 'guard' (1 frame) presente")
	assert_test(frames.has_animation("hurt"), "Animação 'hurt' (2 frames) presente")
	assert_test(frames.has_animation("fall"), "Animação 'fall' (3 frames) presente")
	assert_test(frames.has_animation("getup"), "Animação 'getup' (2 frames) presente")
	assert_test(frames.has_animation("death"), "Animação 'death' (1 frame) presente")

	assert_test(boss.collision_layer == 1, "BossAlessandro corpo físico na Layer 1 (bitmask 1)")
	assert_test(boss.collision_mask == 2, "BossAlessandro colide apenas com o mundo físico na Layer 2 (bitmask 2)")

	var boss_hurtbox: Area2D = boss.get_node_or_null("Hurtbox") as Area2D
	assert_test(boss_hurtbox != null and boss_hurtbox.collision_layer == 4, "BossAlessandro Hurtbox na Layer 3 (bitmask 4)")
	assert_test(boss_hurtbox != null and boss_hurtbox.collision_mask == 0, "BossAlessandro Hurtbox não monitora máscaras ativas (mask 0)")

	var boss_hitbox: Area2D = boss.get_node_or_null("MeleeAttack/HitboxArea") as Area2D
	assert_test(boss_hitbox != null and boss_hitbox.collision_layer == 8, "BossAlessandro HitboxArea na Layer 4 (bitmask 8)")
	assert_test(boss_hitbox != null and boss_hitbox.collision_mask == 4, "BossAlessandro HitboxArea monitora Hurtboxes na Layer 3 (bitmask 4)")

	assert_test(boss.attack_windup_seconds == 0.20, "BossAlessandro possui telegraph calibrado em 0.20s")
	assert_test(boss.attack_cooldown == 0.65, "BossAlessandro possui attack_cooldown calibrado em 0.65s")
	assert_test(boss.recovery_duration == 0.35, "BossAlessandro possui recovery_duration calibrada em 0.35s")
	assert_test(boss.recoil_distance == 35.0, "BossAlessandro possui recoil_distance de 35.0px")
	assert_test(boss.hurt_duration == 0.18, "BossAlessandro possui hurt_duration calibrada em 0.18s")
	assert_test(boss.post_hurt_cooldown == 0.30, "BossAlessandro possui post_hurt_cooldown de 0.30s")
	assert_test(boss.chase_timeout_seconds == 4.0, "BossAlessandro possui chase_timeout_seconds de 4.0s")

	boss.free()


func test_player_new_attack_controls() -> void:
	print("\n--- Testando Novos Controles de Combate do Herói ---")
	var scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player = scene.instantiate() as PlayerController
	root.add_child(player)

	assert_test(player != null, "Instanciação do Player válida")
	
	# Testa execução de Soco
	player._try_punch()
	assert_test(player.melee_attack.is_attacking, "Golpe de Soco executado")
	assert_test(player._current_attack_anim == &"punch", "Animação de Soco selecionada")
	player.melee_attack.cancel_attack()

	# Testa execução de Chute
	player._try_kick()
	assert_test(player.melee_attack.is_attacking, "Golpe de Chute executado")
	assert_test(player._current_attack_anim == &"kick", "Animação de Chute selecionada")
	player.melee_attack.cancel_attack()

	# Testa execução de Golpe Especial
	player._try_special()
	assert_test(player.melee_attack.is_attacking, "Golpe Especial executado")
	assert_test(player._current_attack_anim == &"heavy", "Animação de Especial (heavy) selecionada")
	player.melee_attack.cancel_attack()

	# Testa execução de Ataque Aéreo (voadora sem comando de pulo livre)
	player._try_aerial_attack()
	assert_test(player._is_jumping, "Ataque Aéreo ativa estado de projeção aérea")
	assert_test(player._current_attack_anim == &"jump_atk", "Animação de Ataque Aéreo selecionada")
	player.melee_attack.cancel_attack()

	player.free()


func test_map1_no_boss_and_map4_boss_spawn() -> void:
	print("\n--- Testando Ausência de Chefe no Mapa 1 e Presença no Mapa 4 ---")
	# 1. Verifica Mapa 1 (não deve ter chefe)
	var map1_scene: PackedScene = load("res://scenes/levels/map_1.tscn")
	var map1 = map1_scene.instantiate() as BaseLevel
	root.add_child(map1)

	assert_test(map1.boss_scene == null, "boss_scene é null no Mapa 1 (sem chefe na Seção 1)")
	map1.free()

	# 2. Verifica Mapa 4 (O Beco Final - Clímax com Chefe Alessandro)
	var map4_scene: PackedScene = load("res://scenes/levels/map_4.tscn")
	var map4 = map4_scene.instantiate() as BaseLevel
	root.add_child(map4)

	assert_test(map4.boss_scene != null, "boss_scene está configurada no Mapa 4 (O Beco Final)")
	assert_test(not map4._boss_spawned, "Chefe não está spawnado inicialmente no Mapa 4")
	assert_test(not map4.exit_area.monitoring, "Saída bloqueada no início do combate no Mapa 4")

	# Simula derrota de inimigos para invocar o Chefe no Mapa 4
	var dummy_enemy = CharacterBody2D.new()
	map4._on_enemy_defeated(dummy_enemy)

	assert_test(map4._boss_spawned, "Chefe Alessandro é invocado no Mapa 4 após derrota dos capangas")
	assert_test(map4._boss_instance != null, "Instância de Alessandro criada no mundo do Mapa 4")
	assert_test(not map4.exit_area.monitoring, "Saída do Mapa 4 permanece bloqueada durante luta contra o Chefe")

	# Testa acompanhamento da câmera até a área do boss
	var player = map4.player
	if player != null:
		player.global_position.x = 1600.0 # Jogador caminha até o Boss
		map4._update_camera(1.0)
		assert_test(map4.camera.global_position.x >= 1340.0, "Câmera acompanha o jogador até o limite máximo do mapa próximo ao Chefe")

	# Derrota o chefe e limpa o encontro
	map4._on_encounter_cleared()
	assert_test(map4.exit_area.monitoring, "Saída liberada após derrota do Chefe no Mapa 4")
	assert_test(map4.siga_indicator.visible, "Indicador SIGA → ativado no Mapa 4 após vitória sobre Alessandro")

	dummy_enemy.free()
	map4.free()
