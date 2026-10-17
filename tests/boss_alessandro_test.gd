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
	test_map1_boss_spawn_and_encounter_clearing()

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


func test_map1_boss_spawn_and_encounter_clearing() -> void:
	print("\n--- Testando Spawn do Chefe no Mapa 1 ---")
	var map_scene: PackedScene = load("res://scenes/levels/map_1.tscn")
	var map = map_scene.instantiate() as BaseLevel
	root.add_child(map)

	assert_test(map.boss_scene != null, "boss_scene está configurada no Mapa 1")
	assert_test(not map._boss_spawned, "Chefe não está spawnado inicialmente")
	assert_test(not map.exit_area.monitoring, "Saída bloqueada no início")

	# Simula derrota dos inimigos iniciais
	var dummy_enemy = CharacterBody2D.new()
	map._on_enemy_defeated(dummy_enemy)

	assert_test(map._boss_spawned, "Chefe Alessandro é invocado após derrota dos capangas")
	assert_test(map._boss_instance != null, "Instância do Chefe criada no mundo")
	assert_test(not map.exit_area.monitoring, "Saída permanece bloqueada enquanto o Chefe estiver vivo")

	# Derrota o chefe
	map._on_encounter_cleared()
	assert_test(map.exit_area.monitoring, "Saída finalmente liberada após vitória total")
	assert_test(map.siga_indicator.visible, "Indicador SIGA → ativado após vitória sobre o Chefe")

	dummy_enemy.free()
	map.free()
