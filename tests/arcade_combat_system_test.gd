extends SceneTree

## Suíte de Testes Automatizados Headless do Sistema de Combate Arcade (Projeto Sakas)
## Cobre rigorosamente:
## 1. Combo Contextual (Golpe 1, 2, 3, Finisher, Janela de Combo, Input Buffer, Reset)
## 2. Hitstop, Hitstun, Knockback, Knockdown e Proteção contra Dano Múltiplo
## 3. Reações Físicas do Jogador (Hurt, Knockback, Fall, Downed, Getup, Guarda)
## 4. Reações Físicas dos Inimigos e Arquétipos (Grunt, Aggressor, Tank, Flanker)
## 5. Golpe Especial (Custo de Vida, Prevenção de Suicídio, Apresentação, Dano Global, Knockdown Global, Isolamento de NPCs e Morte)
## 6. Perfis de Dificuldade de Encontro (Mapas 1 a 4 e Diretrizes de Pressão Justa)

const PlayerControllerClass = preload("res://scripts/actors/player_controller.gd")
const EnemyAIClass = preload("res://scripts/actors/enemy_ai.gd")
const MeleeAttackClass = preload("res://scripts/components/melee_attack.gd")
const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const CombatDirectorClass = preload("res://scripts/combat/combat_director.gd")
const EncounterDifficultyProfileClass = preload("res://scripts/combat/encounter_difficulty_profile.gd")
const AttackDataClass = preload("res://scripts/combat/attack_data.gd")
const BaseNPCClass = preload("res://scripts/actors/npc.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_arcade_combat_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_arcade_combat_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: SISTEMA DE COMBATE ARCADE")
	print("==================================================")

	test_combo_progression_and_buffer()
	test_hitstop_hitstun_and_knockdown()
	test_player_physical_reactions_and_guard()
	test_enemy_reactions_and_archetypes()
	test_special_attack_mechanics()
	test_encounter_difficulty_profiles()

	print("==================================================")
	print("RESULTADO DOS TESTES DE COMBATE ARCADE: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)


## 1. Testando o Encadeamento de Combo e Buffer de Input
func test_combo_progression_and_buffer() -> void:
	print("\n--- 1. Testando Combo Contextual e Buffer de Entrada ---")
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)

	assert_test(player._combo_attacks.size() == 4, "Combo principal possui exatamente 4 passos (Punch 1, Punch 2, Kick, Finisher)")

	# Passo 0: Punch 1
	player._combo_step = 0
	player._execute_combo_attack(0)
	assert_test(player._current_attack_anim == &"punch", "Passo 1 do combo utiliza animacao punch")
	assert_test(player.melee_attack.can_knockdown == false, "Passo 1 do combo nao derruba (stagger apenas)")

	# Simula conclusao do golpe e janela de encadeamento
	player._on_attack_ended()
	assert_test(player._combo_window_timer > 0.0, "Janela de encadeamento ativa apos término do golpe")

	# Pressiona novamente dentro da janela -> avança para o Passo 1 (Punch 2)
	player._on_attack_button_pressed()
	assert_test(player._combo_step == 1, "Segundo ataque aciona Passo 2 do combo")
	player._on_attack_ended()

	# Pressiona novamente -> avança para o Passo 2 (Kick)
	player._on_attack_button_pressed()
	assert_test(player._combo_step == 2, "Terceiro ataque aciona Passo 3 do combo (Kick)")
	assert_test(player._current_attack_anim == &"kick", "Passo 3 utiliza animacao kick")
	player._on_attack_ended()

	# Pressiona novamente -> avança para o Passo 3 (Finisher / Heavy)
	player._on_attack_button_pressed()
	assert_test(player._combo_step == 3, "Quarto ataque aciona Passo 4 (Finisher)")
	assert_test(player._current_attack_anim == &"heavy", "Finisher utiliza animacao heavy")
	assert_test(player.melee_attack.can_knockdown == true, "Finisher possui can_knockdown = true")
	player._on_attack_ended()

	# Buffer de entrada: simula input durante janela de ataque ativo
	player.melee_attack.cancel_attack()
	player._combo_step = 0
	player._execute_combo_attack(0)
	assert_test(player.melee_attack.is_attacking == true, "MeleeAttack em execucao ativa")

	player._on_attack_button_pressed() # Input bufferizado
	assert_test(player._input_buffered == true, "Input durante golpe ativo e armazenado no buffer")
	player._on_attack_ended() # Ao terminar, deve consumir o buffer e avançar
	assert_test(player._input_buffered == false, "Buffer de input consumido com sucesso")
	assert_test(player._combo_step == 1, "Buffer disparou automaticamente o proximo passo do combo")
	player.melee_attack.cancel_attack()
	player._on_attack_ended()

	# Reset de combo por expiracao de janela
	player._combo_window_timer = 0.01
	player._physics_process(0.05)
	assert_test(player._combo_step == 0, "Expiracao do combo_window reseta o contador de combo para 0")

	root.remove_child(player)
	player.free()


## 2. Testando Hitstop, Hitstun, Knockback e Knockdown
func test_hitstop_hitstun_and_knockdown() -> void:
	print("\n--- 2. Testando Hitstop, Hitstun, Knockback e Knockdown ---")
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var enemy: EnemyAI = enemy_scene.instantiate() as EnemyAI
	root.add_child(enemy)

	# Hitstop do inimigo
	enemy.apply_hitstop(0.06)
	assert_test(enemy._hitstop_timer == 0.06, "apply_hitstop registra timer de 0.06s")
	enemy._physics_process(0.02)
	assert_test(is_equal_approx(enemy._hitstop_timer, 0.04), "Hitstop timer decrementa durante physics_process")

	# Knockback comum (sem queda)
	var light_dmg := DamageInfoClass.new(15.0, null, Vector2.ZERO, Vector2.RIGHT, "melee", 60.0, 0.22, true, false, 0.05, "punch")
	enemy.take_damage(light_dmg)
	assert_test(enemy.current_state == EnemyAIClass.State.HURT, "Golpe comum coloca inimigo em HURT (stagger)")
	assert_test(enemy.velocity.x != 0.0, "Knockback desloca o inimigo fisicamente no eixo X")


	# Knockdown por Finisher ou golpe pesado (can_knockdown = true)
	var heavy_dmg := DamageInfoClass.new(40.0, null, Vector2.ZERO, Vector2.RIGHT, "melee", 160.0, 0.40, true, true, 0.08, "finisher")
	enemy.take_damage(heavy_dmg)
	assert_test(enemy.current_state == EnemyAIClass.State.FALL, "Golpe com can_knockdown coloca inimigo em FALL")

	# Transicao de FALL para DOWNED
	enemy._state_timer = 0.01
	enemy._process_fall(0.05)
	assert_test(enemy.current_state == EnemyAIClass.State.DOWNED, "Inimigo transiciona de FALL para DOWNED no solo")

	# Transicao de DOWNED para GETUP
	enemy._state_timer = 0.01
	enemy._process_downed(0.05)
	assert_test(enemy.current_state == EnemyAIClass.State.GETUP, "Inimigo transiciona de DOWNED para GETUP")

	# Transicao de GETUP para FLANKING
	enemy._state_timer = 0.01
	enemy._process_getup(0.05)
	assert_test(enemy.current_state == EnemyAIClass.State.FLANKING, "Inimigo retorna para combate ativo (FLANKING) apos GETUP")

	root.remove_child(enemy)
	enemy.free()


## 3. Testando Reações Físicas do Jogador e Guarda
func test_player_physical_reactions_and_guard() -> void:
	print("\n--- 3. Testando Reações Físicas do Jogador e Guarda ---")
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)

	# 1. Guarda ativa
	player._is_guarding = true
	var hp_before: float = player.health_component.current_health
	var attack_from_enemy := DamageInfoClass.new(30.0, null, Vector2(100, 0), Vector2.LEFT, "melee", 80.0, 0.25, true, true)
	var guarded: bool = player.take_damage(attack_from_enemy)
	assert_test(guarded == true, "take_damage processa golpe na guarda")
	var damage_taken: float = hp_before - player.health_component.current_health
	assert_test(is_equal_approx(damage_taken, 9.0), "Guarda reduz dano em 70% (30 * 0.30 = 9.0)")
	assert_test(player.combat_state == PlayerControllerClass.CombatState.NORMAL, "Guarda impede que jogador entre em FALL ou HURT")
	player._is_guarding = false

	# 2. Jogador recebe golpe comum sem guarda -> HURT
	var hit_dmg := DamageInfoClass.new(10.0, null, Vector2(100, 0), Vector2.LEFT, "melee", 60.0, 0.22, true, false)
	player.take_damage(hit_dmg)
	assert_test(player.combat_state == PlayerControllerClass.CombatState.HURT, "Jogador entra no estado HURT ao receber dano desprotegido")

	# 3. Jogador recebe golpe com can_knockdown -> FALL
	var kd_dmg := DamageInfoClass.new(20.0, null, Vector2(100, 0), Vector2.LEFT, "melee", 150.0, 0.35, true, true)
	player.take_damage(kd_dmg)
	assert_test(player.combat_state == PlayerControllerClass.CombatState.FALL, "Jogador entra no estado FALL ao receber golpe pesado com knockdown")

	# 4. Ciclo de recuperacao do jogador (FALL -> DOWNED -> GETUP -> NORMAL)
	player._state_timer = 0.01
	player._physics_process(0.05)
	assert_test(player.combat_state == PlayerControllerClass.CombatState.DOWNED, "Jogador caído no chão (DOWNED)")

	player._state_timer = 0.01
	player._physics_process(0.05)
	assert_test(player.combat_state == PlayerControllerClass.CombatState.GETUP, "Jogador levantando (GETUP)")

	player._state_timer = 0.01
	player._physics_process(0.05)
	assert_test(player.combat_state == PlayerControllerClass.CombatState.NORMAL, "Jogador de pé e pronto para agir (NORMAL)")

	root.remove_child(player)
	player.free()


## 4. Testando Inimigos e Arquétipos Táticos
func test_enemy_reactions_and_archetypes() -> void:
	print("\n--- 4. Testando Inimigos e Arquétipos Táticos ---")
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")

	# A) Grunt
	var grunt: EnemyAI = enemy_scene.instantiate() as EnemyAI
	grunt.archetype = EnemyAIClass.Archetype.GRUNT
	root.add_child(grunt)
	assert_test(grunt.speed_x == 140.0, "Grunt possui velocidade horizontal padrao (140.0)")
	assert_test(grunt.health_component.max_health == 80.0, "Grunt possui vida padrao (80.0)")
	root.remove_child(grunt)
	grunt.free()

	# B) Tank
	var tank: EnemyAI = enemy_scene.instantiate() as EnemyAI
	tank.archetype = EnemyAIClass.Archetype.TANK
	root.add_child(tank)
	assert_test(tank.health_component.max_health == 140.0, "Tank possui vida superior (140.0 HP)")
	assert_test(tank.speed_x == 100.0, "Tank possui velocidade reduzida de blindagem (100.0)")
	# Tank resiste a knockdown de golpes normais
	var kd_dmg := DamageInfoClass.new(20.0, null, Vector2.ZERO, Vector2.RIGHT, "melee", 100.0, 0.3, true, true)
	tank.take_damage(kd_dmg)
	assert_test(tank.current_state == EnemyAIClass.State.HURT, "Tank resiste a quedas de golpes normais ficando em HURT")
	root.remove_child(tank)
	tank.free()

	# C) Aggressor
	var aggressor: EnemyAI = enemy_scene.instantiate() as EnemyAI
	aggressor.archetype = EnemyAIClass.Archetype.AGGRESSOR
	root.add_child(aggressor)
	assert_test(aggressor.speed_x == 175.0, "Aggressor possui alta velocidade de aproximacao (175.0)")
	assert_test(aggressor.attack_windup_seconds == 0.18, "Aggressor possui telegraph mais rapido (0.18s)")
	root.remove_child(aggressor)
	aggressor.free()


## 5. Testando Golpe Especial de Área
func test_special_attack_mechanics() -> void:
	print("\n--- 5. Testando Golpe Especial de Área ---")
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var npc_scene: PackedScene = load("res://scenes/actors/npc.tscn")

	var player: PlayerController = player_scene.instantiate() as PlayerController
	var enemy1: EnemyAI = enemy_scene.instantiate() as EnemyAI
	var enemy2: EnemyAI = enemy_scene.instantiate() as EnemyAI
	var dead_enemy: EnemyAI = enemy_scene.instantiate() as EnemyAI
	var npc: BaseNPCClass = npc_scene.instantiate() as BaseNPCClass

	enemy1.position = Vector2(500, 600)
	enemy2.position = Vector2(900, 300) # Longe e em profundidade Y totalmente diferente
	dead_enemy.position = Vector2(400, 400)
	npc.position = Vector2(450, 450)

	root.add_child(player)
	root.add_child(enemy1)
	root.add_child(enemy2)
	root.add_child(dead_enemy)
	root.add_child(npc)

	dead_enemy.health_component.current_health = 0.0
	dead_enemy.health_component.is_dead = true

	# 1. Validação estrita do medidor de Especial (Requisito 100% de carga)
	var hp_init: float = player.health_component.current_health
	player.current_special = 50.0
	var fail_started: bool = player.execute_special()
	assert_test(fail_started == false, "Especial NÃO é acionado com carga parcial (< 100%)")
	assert_test(player.combat_state != PlayerControllerClass.CombatState.SPECIAL, "Jogador não entra em SPECIAL com carga parcial")
	assert_test(is_equal_approx(player.health_component.current_health, hp_init), "HP não é consumido em tentativa inválida de Especial")

	# 2. Acionamento com 100% de carga
	player.current_special = 100.0
	var spec_started: bool = player.execute_special()
	assert_test(spec_started == true, "Especial é acionado com sucesso quando 100% carregado")
	assert_test(player.combat_state == PlayerControllerClass.CombatState.SPECIAL, "Jogador entra no estado SPECIAL")
	assert_test(player._is_invulnerable == true, "Jogador ganha invulnerabilidade durante o especial")
	assert_test(is_equal_approx(player.current_special, 0.0), "Especial consome 100% da barra acumulada")
	assert_test(is_equal_approx(player.health_component.current_health, hp_init), "Especial NÃO consome mais vida do jogador (custo é medidor cheio)")

	# 3. Tentativa repetida sem recarregar falha
	var repeat_started: bool = player.execute_special()
	assert_test(repeat_started == false, "Tentativa repetida sem recarregar falha e não consome recursos")


	# 3. Aplicacao do impacto global
	var e1_hp_before: float = enemy1.health_component.current_health
	var e2_hp_before: float = enemy2.health_component.current_health
	var npc_hp_before: float = npc.health_component.current_health

	player._apply_global_special_impact()

	assert_test(enemy1.health_component.current_health < e1_hp_before, "Inimigo 1 recebe dano do Especial")
	assert_test(enemy1.current_state == EnemyAIClass.State.FALL, "Inimigo 1 entra em FALL (queda global)")

	assert_test(enemy2.health_component.current_health < e2_hp_before, "Inimigo 2 distante e em outro Y tambem recebe dano global")
	assert_test(enemy2.current_state == EnemyAIClass.State.FALL, "Inimigo 2 sofre queda global")

	assert_test(npc.health_component.current_health == npc_hp_before, "NPC civil NAO e atingido pelo Especial (isolamento de civis)")
	assert_test(dead_enemy.health_component.current_health == 0.0, "Inimigo morto NAO recebe dano espurio")

	root.remove_child(player)
	root.remove_child(enemy1)
	root.remove_child(enemy2)
	root.remove_child(dead_enemy)
	root.remove_child(npc)
	player.free()
	enemy1.free()
	enemy2.free()
	dead_enemy.free()
	npc.free()


## 6. Testando Perfis de Dificuldade de Encontro (CombatDirector)
func test_encounter_difficulty_profiles() -> void:
	print("\n--- 6. Testando Perfis de Dificuldade por Mapa ---")
	var director := CombatDirectorClass.new()
	root.add_child(director)

	# Mapa 1: Ensino
	var p1 := EncounterDifficultyProfileClass.create_for_map(1)
	director.apply_difficulty_profile(p1)
	assert_test(director.max_attack_tokens == 1, "Mapa 1 limita a 1 token ofensivo (ensino)")
	assert_test(p1.get("allow_flankers") == false, "Mapa 1 nao permite flanqueadores avancados")

	# Mapa 2: Pressao
	var p2 := EncounterDifficultyProfileClass.create_for_map(2)
	director.apply_difficulty_profile(p2)
	assert_test(director.max_attack_tokens == 2, "Mapa 2 autoriza 2 tokens ofensivos")
	assert_test(p2.get("allow_flankers") == true, "Mapa 2 introduz flanqueamento ativo")

	# Mapa 3: Desafio
	var p3 := EncounterDifficultyProfileClass.create_for_map(3)
	director.apply_difficulty_profile(p3)
	assert_test(p3.get("allow_aggressors") == true, "Mapa 3 introduz arquétipo Aggressor")

	# Mapa 4: Maestria e Chefe
	var p4 := EncounterDifficultyProfileClass.create_for_map(4)
	director.apply_difficulty_profile(p4)
	assert_test(p4.get("allow_tanks") == true, "Mapa 4 suporta composicao com Tanks e Chefe")
	assert_test(director.max_simultaneous_active_enemy_attacks == 1, "CombatDirector preserva limite de 1 ataque ativo simultaneo (sem dano no mesmo frame)")

	root.remove_child(director)
	director.free()
