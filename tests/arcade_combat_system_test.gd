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
const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")
const BaseLevelClass = preload("res://scripts/levels/base_level.gd")
const SigaIndicatorClass = preload("res://scripts/ui/siga_indicator.gd")

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
	test_attack_phases_and_temporal_synchronization()
	test_reinforcement_waves_and_offscreen_spawning()

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

	# Pressiona novamente -> avança para o Passo 3 (Finisher / Heavy) — 20% de chance
	# Loop até o heavy ser acionado para validar suas propriedades
	var heavy_triggered: bool = false
	for _attempt in range(50):
		player.melee_attack.cancel_attack()
		player._combo_step = 2
		player._combo_window_timer = 1.0
		player._on_attack_button_pressed()
		if player._combo_step == 3:
			heavy_triggered = true
			break
		# Se voltou para 0 (80%), tenta de novo
		player._on_attack_ended()
	assert_test(heavy_triggered, "Quarto ataque aciona Passo 4 (Finisher)")
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

	# Hitstop do inimigo e congelamento de animação (P2)
	enemy.apply_hitstop(0.06)
	assert_test(enemy._hitstop_timer == 0.06, "apply_hitstop registra timer de 0.06s")
	assert_test(enemy.is_in_hitstop() == true, "is_in_hitstop retorna true no inimigo")
	assert_test(enemy.anim_sprite != null and enemy.anim_sprite.speed_scale == 0.0, "anim_sprite.speed_scale congelado em 0.0 durante hitstop")
	assert_test(enemy.melee_attack != null and enemy.melee_attack.is_in_hitstop(), "melee_attack do inimigo recebe hitstop sincronizado")

	# Dois hits próximos/sobrepostos: não deixam ator travado nem sobrescrevem escala salva
	enemy.apply_hitstop(0.08)
	assert_test(enemy._hitstop_timer == 0.08, "Hits sobrepostos estendem timer sem reset indevido")
	assert_test(enemy.anim_sprite.speed_scale == 0.0, "anim_sprite continua congelado em hitstop sobreposto")

	# Decremento de física durante hitstop
	enemy._physics_process(0.04)
	assert_test(is_equal_approx(enemy._hitstop_timer, 0.04), "Hitstop timer decrementa durante physics_process")

	# Término do hitstop: restaura física e animação normalmente
	enemy._physics_process(0.05)
	assert_test(enemy._hitstop_timer == 0.0, "Hitstop expira limpo em 0.0")
	assert_test(enemy.is_in_hitstop() == false, "Inimigo sai do estado de hitstop")
	assert_test(enemy.anim_sprite.speed_scale == 1.0, "anim_sprite.speed_scale restaurado para 1.0 ao final do hitstop")
	assert_test(paused == false, "SceneTree permanece ativa (sem congelamento global get_tree().paused)")

	# Preservação da janela ativa do MeleeAttack durante hitstop
	var p_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var p_test: PlayerControllerClass = p_scene.instantiate() as PlayerControllerClass
	p_test.position = Vector2(1000, 1000) # Isola o jogador de teste para não colidir com o inimigo
	root.add_child(p_test)
	p_test._combo_step = 0
	p_test._execute_combo_attack(0)
	p_test.melee_attack._physics_process(0.05) # entra em ACTIVE com active_duration = 0.12
	assert_test(p_test.melee_attack.current_phase == MeleeAttackClass.Phase.ACTIVE, "MeleeAttack em ACTIVE antes do hitstop")
	var phase_timer_before: float = p_test.melee_attack._phase_timer

	# Aplica hitstop no jogador
	p_test.apply_hitstop(0.06)
	assert_test(p_test.anim_sprite.speed_scale == 0.0, "anim_sprite do jogador congelado em 0.0 durante hitstop")
	p_test.melee_attack._physics_process(0.03)
	assert_test(p_test.melee_attack.is_active_window == true, "Janela ativa NÃO é consumida durante hitstop")
	assert_test(is_equal_approx(p_test.melee_attack._phase_timer, phase_timer_before), "Timer de fase do ataque permanece congelado durante hitstop")

	# Ao expirar hitstop do jogador, retoma
	p_test.melee_attack._physics_process(0.04)
	p_test._physics_process(0.07)
	assert_test(p_test.anim_sprite.speed_scale == 1.0, "anim_sprite do jogador retoma velocidade normal pós-hitstop")
	root.remove_child(p_test)
	p_test.free()

	enemy.health_component.reset()

	# Knockback comum direcional (P3: baseado no golpe/atacante)
	var light_dmg_r := DamageInfoClass.new(15.0, null, Vector2.ZERO, Vector2.RIGHT, "melee", 60.0, 0.22, true, false, 0.05, "punch")
	enemy.take_damage(light_dmg_r)
	assert_test(enemy.current_state == EnemyAIClass.State.HURT, "Golpe comum coloca inimigo em HURT (stagger)")
	assert_test(enemy.velocity.x > 0.0, "Knockback com direção RIGHT projeta o inimigo para a direita (velocity.x > 0)")

	var light_dmg_l := DamageInfoClass.new(15.0, null, Vector2.ZERO, Vector2.LEFT, "melee", 60.0, 0.22, true, false, 0.05, "punch")
	enemy.take_damage(light_dmg_l)
	assert_test(enemy.velocity.x < 0.0, "Knockback com direção LEFT projeta o inimigo para a esquerda (velocity.x < 0)")

	# Teste de Screen Shake (P3: concorrência amortecida sem offset residual)
	var test_cam := Camera2D.new()
	root.add_child(test_cam)
	test_cam.offset = Vector2.ZERO
	CombatFeedbackClass.trigger_screen_shake(test_cam, 8.0, 0.2)
	assert_test(test_cam.has_meta(&"_shake_tween"), "Screen shake registra tween ativo no Camera2D")
	# Segundo tremor concorrente imediato
	CombatFeedbackClass.trigger_screen_shake(test_cam, 14.0, 0.3)
	assert_test(test_cam.get_meta(&"_base_camera_offset") == Vector2.ZERO, "Base offset mantido estritamente em Vector2.ZERO sob concorrência")
	root.remove_child(test_cam)
	test_cam.free()


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
	assert_test(grunt.palette_variant == EnemyAIClass.PaletteVariant.ORIGINAL, "Grunt preserva paleta azul clássica (ORIGINAL)")
	root.remove_child(grunt)
	grunt.free()

	# B) Tank
	var tank: EnemyAI = enemy_scene.instantiate() as EnemyAI
	tank.archetype = EnemyAIClass.Archetype.TANK
	root.add_child(tank)
	assert_test(tank.health_component.max_health == 140.0, "Tank possui vida superior (140.0 HP)")
	assert_test(tank.speed_x == 100.0, "Tank possui velocidade reduzida de blindagem (100.0)")
	assert_test(tank.palette_variant == EnemyAIClass.PaletteVariant.PURPLE, "Tank recebe paleta púrpura distinta (PURPLE)")
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
	assert_test(aggressor.palette_variant == EnemyAIClass.PaletteVariant.RED, "Aggressor recebe paleta vermelha de alta ameaça (RED)")
	root.remove_child(aggressor)
	aggressor.free()

	# D) Flanker
	var flanker: EnemyAI = enemy_scene.instantiate() as EnemyAI
	flanker.archetype = EnemyAIClass.Archetype.FLANKER
	root.add_child(flanker)
	assert_test(flanker.palette_variant == EnemyAIClass.PaletteVariant.GREEN, "Flanker recebe paleta verde tática (GREEN)")
	root.remove_child(flanker)
	flanker.free()

	# E) Harmonização Visual do NPC Sérgio (P4)
	var sergio_scene: PackedScene = load("res://scenes/actors/sergio_npc.tscn")
	var sergio: CharacterBody2D = sergio_scene.instantiate() as CharacterBody2D
	root.add_child(sergio)
	var sergio_anim := sergio.get_node("Visual/AnimatedSprite2D") as AnimatedSprite2D
	assert_test(sergio_anim != null and sergio_anim.scale == Vector2(0.28, 0.28), "Sérgio NPC calibrado na escala 0.28 proporcional ao herói (GAME_RULES)")
	assert_test(sergio_anim != null and sergio_anim.position == Vector2(0, -107), "Sérgio NPC alinhado com linha de base Y=0 no solo")
	root.remove_child(sergio)
	sergio.free()


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

	# P0: Teste de Idempotência (Não acúmulo multiplicativo em reaplicações sucessivas)
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var test_enemy: EnemyAI = enemy_scene.instantiate() as EnemyAI
	root.add_child(test_enemy)
	director.register_enemy(test_enemy)

	# Aplica perfil 3 (HP multiplier = 1.30 -> 80 * 1.30 = 104.0)
	director.apply_difficulty_profile(p3)
	var hp_once: float = test_enemy.health_component.max_health
	assert_test(is_equal_approx(hp_once, 104.0), "Primeira aplicacao deriva HP correto (80 * 1.30 = 104.0)")

	# Re-aplica 3 vezes seguidas: deve permanecer estritamente 104.0 (sem acumular para 135.2 ou 175.76)
	director.apply_difficulty_profile(p3)
	director.apply_difficulty_profile(p3)
	var hp_repeated: float = test_enemy.health_component.max_health
	assert_test(is_equal_approx(hp_repeated, 104.0), "Reaplicacoes sucessivas nao acumulam multiplicadores (idempotencia garantida)")

	# P0: Teste de Enforce de Arquétipos (Mapa 1 desautoriza Tanks e rebaixa para Grunt)
	var tank_enemy: EnemyAI = enemy_scene.instantiate() as EnemyAI
	tank_enemy.archetype = EnemyAIClass.Archetype.TANK
	root.add_child(tank_enemy)
	director.apply_difficulty_profile(p1) # allow_tanks = false
	director.register_enemy(tank_enemy)
	assert_test(tank_enemy.archetype == EnemyAIClass.Archetype.GRUNT, "Perfil restritivo rebaixa arquétipo desautorizado (Tank -> Grunt no Mapa 1)")

	root.remove_child(test_enemy)
	test_enemy.free()
	root.remove_child(tank_enemy)
	tank_enemy.free()
	root.remove_child(director)
	director.free()


## 7. Testando Sincronização de Fases Temporais do Ataque (P1: Startup, Active, Recovery)
func test_attack_phases_and_temporal_synchronization() -> void:
	print("\n--- 7. Testando Fases de Ataque (Startup, Active, Recovery) e Sincronização ---")
	var root_node := Node2D.new()
	root.add_child(root_node)

	var attack := MeleeAttackClass.new()
	attack.target_group = "enemies"
	attack.damage = 25.0
	attack.horizontal_range = 90.0
	attack.depth_tolerance = 25.0
	attack.startup_duration = 0.08
	attack.active_duration = 0.12
	attack.recovery_duration = 0.20
	attack.attack_cooldown = 0.20
	root_node.add_child(attack)

	var target := CharacterBody2D.new()
	target.add_to_group("enemies")
	target.global_position = Vector2(50.0, 0.0)
	root_node.add_child(target)

	var target_health := HealthComponentClass.new()
	target_health.max_health = 100.0
	target.add_child(target_health)
	target_health._ready()

	var signal_tracker := {
		"started": 0,
		"ended": 0,
		"hits": 0
	}
	var phases_recorded: Array[int] = []

	attack.attack_started.connect(func(): signal_tracker["started"] += 1)
	attack.attack_ended.connect(func(): signal_tracker["ended"] += 1)
	attack.target_hit.connect(func(_t, _d): signal_tracker["hits"] += 1)
	attack.attack_phase_changed.connect(func(p: int): phases_recorded.append(p))

	# 1. Executa ataque com startup explícito
	var success := attack.execute_attack(1.0)
	assert_test(success, "Ataque iniciado com sucesso")
	assert_test(attack.is_attacking == true, "is_attacking é true durante startup")
	assert_test(attack.current_phase == MeleeAttackClass.Phase.STARTUP, "Fase inicial é estritamente STARTUP")
	assert_test(attack.is_active_window == false, "Hitbox NÃO está ativa durante a fase de startup")
	assert_test(signal_tracker["started"] == 1, "Sinal attack_started emitido estritamente uma vez no início")

	# 2. Processa frame durante startup (0.04s < 0.08s) -> Não pode causar dano
	attack._physics_process(0.04)
	assert_test(attack.current_phase == MeleeAttackClass.Phase.STARTUP, "Permanece em STARTUP antes de expirar a duração")
	assert_test(target_health.current_health == 100.0, "Nenhum dano aplicado antes do término do startup")
	assert_test(signal_tracker["hits"] == 0, "Nenhum target_hit disparado no startup")

	# 3. Processa até cruzar o startup (mais 0.05s -> total 0.09s > 0.08s) -> Transiciona para ACTIVE
	attack._physics_process(0.05)
	assert_test(attack.current_phase == MeleeAttackClass.Phase.ACTIVE, "Transiciona para ACTIVE exatamente após o startup")
	assert_test(attack.is_active_window == true, "Hitbox ativa na janela ACTIVE")
	assert_test(target_health.current_health == 75.0, "Alvo recebe dano na abertura da janela ativa")
	assert_test(signal_tracker["hits"] == 1, "target_hit disparado no momento correto")

	# 4. Alvo repetido dentro da mesma janela ativa -> Não sofre dano duplo
	attack._physics_process(0.02)
	assert_test(target_health.current_health == 75.0, "Mesmo alvo NÃO recebe dano duplicado na mesma janela ativa")
	assert_test(signal_tracker["hits"] == 1, "Sem múltiplos acertos indevidos no mesmo alvo")

	# 5. Processa até encerrar a janela ativa (mais 0.11s -> active total consumido) -> Transiciona para RECOVERY
	attack._physics_process(0.11)
	assert_test(attack.current_phase == MeleeAttackClass.Phase.RECOVERY, "Transiciona para RECOVERY ao término do active")
	assert_test(attack.is_active_window == false, "Hitbox desativada imediatamente ao entrar em recovery")

	# 6. Novo alvo entra na área durante recovery -> Não recebe dano
	var target2 := CharacterBody2D.new()
	target2.add_to_group("enemies")
	target2.global_position = Vector2(40.0, 0.0)
	root_node.add_child(target2)
	var target2_health := HealthComponentClass.new()
	target2.add_child(target2_health)
	target2_health._ready()

	attack._physics_process(0.05)
	assert_test(target2_health.current_health == 100.0, "Novo alvo que entra durante recovery NÃO sofre dano")

	# 7. Conclusão do recovery -> Transição para INACTIVE e emissão única de attack_ended
	attack._physics_process(0.16)
	assert_test(attack.current_phase == MeleeAttackClass.Phase.INACTIVE, "Ataque retorna a INACTIVE após recovery")
	assert_test(attack.is_attacking == false, "is_attacking retorna a false")
	assert_test(signal_tracker["ended"] == 1, "Sinal attack_ended emitido estritamente uma vez ao final do ciclo")

	# 8. Teste de Interrupção / Cancelamento limpo
	target_health.reset()
	attack.execute_attack(1.0)
	attack._physics_process(0.09) # entra em active
	assert_test(attack.current_phase == MeleeAttackClass.Phase.ACTIVE, "Segundo ataque entra em active")
	attack.cancel_attack()
	assert_test(attack.current_phase == MeleeAttackClass.Phase.INACTIVE, "cancel_attack redefine imediatamente para INACTIVE")
	assert_test(attack.is_active_window == false, "cancel_attack desativa a janela ativa imediatamente")
	assert_test(attack.is_attacking == false, "cancel_attack redefine is_attacking para false")
	assert_test(signal_tracker["ended"] == 1, "cancel_attack NÃO emite sinal indevido de attack_ended")

	# Limpa alvos anteriores para isolar o teste do jogador de colisões não intencionais
	root_node.remove_child(target)
	target.free()
	root_node.remove_child(target2)
	target2.free()

	# 9. Teste do combo buffer no PlayerController respeitando as fases
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerControllerClass = player_scene.instantiate() as PlayerControllerClass
	root_node.add_child(player)

	player._combo_step = 0
	player._execute_combo_attack(0) # Inicia Jab
	assert_test(player.melee_attack.current_phase == MeleeAttackClass.Phase.STARTUP, "Jab do Jogador inicia na fase STARTUP")
	assert_test(player.melee_attack.is_active_window == false, "Jab do Jogador não possui janela ativa no startup")

	# Pressiona ataque durante o startup -> Armazena no buffer
	player._on_attack_button_pressed()
	assert_test(player._input_buffered == true, "Input durante startup do jogador é armazenado no buffer")

	# Avança até active
	player.melee_attack._physics_process(0.05) # 0.05s > 0.04s startup
	assert_test(player.melee_attack.current_phase == MeleeAttackClass.Phase.ACTIVE, "Jab avança para ACTIVE")

	# Avança active até recovery
	player.melee_attack._physics_process(0.13) # active expirado
	assert_test(player.melee_attack.current_phase == MeleeAttackClass.Phase.RECOVERY, "Jab avança para RECOVERY")

	# Ao finalizar recovery, consome buffer e encadeia próximo golpe
	player.melee_attack._physics_process(0.25) # recovery expirado
	player._on_attack_ended()
	assert_test(player._input_buffered == false, "Buffer consumido ao final do ciclo")
	assert_test(player._combo_step == 1, "Buffer disparou automaticamente o Passo 2 do combo")

	# 10. Teste do Ataque do Inimigo: Telegraph seguido de ciclo de ataque sincronizado
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var enemy: EnemyAIClass = enemy_scene.instantiate() as EnemyAIClass
	root_node.add_child(enemy)
	enemy.player_target = player

	enemy.current_state = EnemyAIClass.State.TELEGRAPH
	enemy._state_timer = 0.25
	assert_test(not enemy.melee_attack.is_attacking, "Inimigo em TELEGRAPH não tem MeleeAttack ativo")

	enemy._process_telegraph(0.26) # Conclui telegraph e dispara _trigger_attack
	assert_test(enemy.current_state == EnemyAIClass.State.ATTACKING, "Inimigo transiciona para ATTACKING")
	assert_test(enemy.melee_attack.is_attacking, "MeleeAttack do inimigo em execução")
	assert_test(enemy.melee_attack.current_phase == MeleeAttackClass.Phase.ACTIVE, "MeleeAttack padrão do inimigo entra em ACTIVE")

	root.remove_child(root_node)
	root_node.free()


## 8. Validação Formal de Ondas de Reforço e Spawns Fora da Tela (FASE P5)
func test_reinforcement_waves_and_offscreen_spawning() -> void:
	print("\n--- Testando 8. Ondas de Reforço Fora da Tela e Ciclo de Vida (P5) ---")
	var root_node := Node2D.new()
	root.add_child(root_node)

	# 1. Validação de Parâmetros Exportados no Mapa 2
	var map2_scene: PackedScene = load("res://scenes/levels/map_2.tscn")
	assert_test(map2_scene != null, "Cena do Mapa 2 carregada com sucesso")
	var map2_inst = map2_scene.instantiate()
	root_node.add_child(map2_inst)

	assert_test(map2_inst.get("reinforcement_waves_enabled") == true, "Mapa 2 possui ondas de reforço ativadas")
	assert_test(map2_inst.get("reinforcement_trigger_enemy_count") == 1, "Mapa 2 dispara reforço quando restar 1 inimigo vivo")
	assert_test(map2_inst.get("reinforcement_delay_seconds") == 2.0, "Mapa 2 configura delay de reforço em 2.0s")
	assert_test(map2_inst.get("reinforcement_count") == 3, "Mapa 2 agenda cota de 3 reforços (+50%)")

	# 2. Validação da Geometria de Spawn Fora da Tela (Camera2D World Rect)
	# Câmera no início da fase (X = 640.0) -> Tela visível [0.0, 1280.0]
	map2_inst.camera.global_position = Vector2(640.0, 360.0)
	var pos0: Vector2 = map2_inst.get_offscreen_spawn_position(0, 2)
	var pos1: Vector2 = map2_inst.get_offscreen_spawn_position(1, 2)

	assert_test(pos0.x > 1280.0 or pos0.x < 0.0, "Posição de reforço 0 surge estritamente FORA do retângulo visível da câmera")
	assert_test(pos1.x > 1280.0 or pos1.x < 0.0, "Posição de reforço 1 surge estritamente FORA do retângulo visível da câmera")
	assert_test(pos0 != pos1, "Múltiplos reforços possuem coordenadas distintas (sem sobreposição imediata)")
	assert_test(pos0.x >= 160.0 and pos0.x <= 1880.0, "Posição de reforço 0 está contida nos limites caminháveis horizontais")
	assert_test(pos0.y >= 580.0 and pos0.y <= 710.0, "Posição de reforço 0 está contida nos limites caminháveis verticais")

	# Câmera no final da fase (X = 1343.0) -> Tela visível [703.0, 1983.0]
	# O lado direito ultrapassa a parede direita (1880), logo deve inverter para o lado ESQUERDO fora da tela
	map2_inst.camera.global_position = Vector2(1343.0, 360.0)
	var pos_left: Vector2 = map2_inst.get_offscreen_spawn_position(0, 1)
	assert_test(pos_left.x < 703.0, "Com câmera encostada na direita, spawn inverte dinamicamente para fora da tela à esquerda")
	assert_test(pos_left.x >= 160.0, "Spawn invertido respeita o limite mínimo caminhável do mapa")

	root_node.remove_child(map2_inst)
	map2_inst.free()

	# 3. Teste Isolado do Ciclo de Vida: Agendamento, Blindagem de Saída e Notificação
	var test_level := BaseLevelClass.new()
	root_node.add_child(test_level)
	test_level.reinforcement_waves_enabled = true
	test_level.reinforcement_trigger_enemy_count = 1
	test_level.reinforcement_delay_seconds = 2.0
	test_level.reinforcement_count = 2

	var director := CombatDirectorClass.new()
	test_level.add_child(director)
	test_level.combat_director = director
	director.enemy_defeated.connect(test_level._on_enemy_defeated)
	director.encounter_cleared.connect(test_level._on_encounter_cleared)

	var exit := Area2D.new()
	test_level.add_child(exit)
	test_level.exit_area = exit
	exit.monitoring = false

	var siga := SigaIndicatorClass.new()
	test_level.add_child(siga)
	test_level.siga_indicator = siga
	siga.deactivate()

	var cam := Camera2D.new()
	test_level.add_child(cam)
	test_level.camera = cam
	cam.global_position = Vector2(640, 360)

	var enemy_a := CharacterBody2D.new()
	enemy_a.add_to_group("enemies")
	test_level.add_child(enemy_a)
	director.register_enemy(enemy_a)

	var enemy_b := CharacterBody2D.new()
	enemy_b.add_to_group("enemies")
	test_level.add_child(enemy_b)
	director.register_enemy(enemy_b)

	assert_test(director.alive_enemies.size() == 2, "Encontro inicial possui 2 inimigos vivos")
	assert_test(director.pending_spawns_count == 0, "Zero spawns pendentes antes do gatilho")

	# Derrota o primeiro inimigo: Resta 1 (<= 1) -> Dispara gatilho da onda
	director.notify_enemy_defeated(enemy_a)

	assert_test(director.alive_enemies.size() == 1, "Resta 1 inimigo vivo")
	assert_test(director.pending_spawns_count == 2, "Diretor registrou imediatamente cota de 2 reforços pendentes antes do fim do timer")
	assert_test(exit.monitoring == false, "ExitArea permanece estritamente bloqueada durante o delay do reforço")
	assert_test(siga.is_active() == false, "SIGA permanece estritamente desativado durante o delay do reforço")

	# Derrota o segundo inimigo antes de o timer de reforço expirar
	director.notify_enemy_defeated(enemy_b)

	assert_test(director.alive_enemies.is_empty(), "Inimigos iniciais foram todos eliminados")
	assert_test(director.is_encounter_cleared() == false, "Encontro NÃO é dado como vencido com reforços pendentes")
	assert_test(exit.monitoring == false, "ExitArea continua bloqueada mesmo com inimigos iniciais zerados")
	assert_test(siga.is_active() == false, "SIGA continua bloqueado mesmo com inimigos iniciais zerados")

	# Validação de Idempotência: chamadas subsequentes não duplicam cota de spawns pendentes
	test_level._trigger_reinforcement_wave()
	assert_test(director.pending_spawns_count == 2, "Idempotência garantida: disparos múltiplos não duplicam a cota de reforços")

	# Executa a conclusão do timer de reforço (instanciação dos reforços)
	test_level._on_reinforcement_timer_timeout()

	assert_test(director.pending_spawns_count == 0, "Spawns pendentes zerados após conclusão da instanciação")
	assert_test(director.alive_enemies.size() == 2, "2 novos reforços registrados como inimigos ativos no CombatDirector")

	# Inimigos de reforço devem iniciar em FLANKING para entrada legível caminhando
	var spawned_reinf = director.alive_enemies[0]
	assert_test(spawned_reinf.get("current_state") == EnemyAIClass.State.FLANKING, "Reforço inicia em FLANKING (caminha legivelmente para o combate)")

	# Derrota o primeiro reforço
	director.notify_enemy_defeated(spawned_reinf)
	assert_test(director.is_encounter_cleared() == false, "Encontro segue ativo enquanto houver reforço vivo")
	assert_test(exit.monitoring == false, "ExitArea continua inativa com 1 reforço restante")

	# Derrota o último reforço
	var last_reinf = director.alive_enemies[0]
	director.notify_enemy_defeated(last_reinf)

	assert_test(director.alive_enemies.is_empty(), "Todos os reforços foram derrotados")
	assert_test(director.is_encounter_cleared() == true, "CombatDirector declara encontro vencido (CLEARED)")
	assert_test(exit.monitoring == true, "ExitArea habilitada com sucesso após vitória total da onda")
	assert_test(siga.is_active() == true, "SIGA ativado piscando na tela após vitória total da onda")

	root.remove_child(root_node)
	root_node.free()


