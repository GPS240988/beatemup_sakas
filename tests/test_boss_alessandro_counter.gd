extends SceneTree

## Teste unitário de validação do contra-ataque do Chefe Alessandro (Mapa 4)
## Requisitos:
## 1. Preservação do ataque de trufas e fluxos já implantados.
## 2. Quando o jogador encaixa mais de 4 golpes consecutivos nele, tem 60% de chance de dar soco ou chute.
## 3. Quando o jogador chega na voadora, tem 60% de chance de dar soco ou chute.

const BossAlessandroEnhancedClass = preload("res://scripts/actors/boss_alessandro_enhanced.gd")
const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const BossScene: PackedScene = preload("res://scenes/actors/enemies/boss_alessandro.tscn")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const EnemyAIClass = preload("res://scripts/actors/enemy_ai.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _assert(condition: bool, description: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] ", description)
	else:
		failed_tests += 1
		printerr("  [FALHA] ", description)

func _run_tests() -> void:
	print("\n========================================================")
	print("TESTE: CONTRA-ATAQUE DE ALESSANDRO (MAPA 4)")
	print("========================================================")

	var world := Node2D.new()
	world.name = "TestArena"
	root.add_child(world)

	var player: CharacterBody2D = PlayerScene.instantiate() as CharacterBody2D
	world.add_child(player)
	player.global_position = Vector2(500.0, 640.0)

	var boss: BossAlessandroEnhancedClass = BossScene.instantiate() as BossAlessandroEnhancedClass
	world.add_child(boss)
	boss.global_position = Vector2(580.0, 640.0)
	boss.player_target = player

	# Forçar cooldown de esquiva para não esquivar por padrão nos testes
	boss._evasion_cooldown = 10.0

	print("\n--- Teste 1: Configurações e Constantes Oficiais ---")
	_assert(is_equal_approx(boss.COUNTER_ATTACK_CHANCE, 0.60), "Probabilidade de contra-ataque é exatamente 60%")
	_assert(boss.CONSECUTIVE_HITS_THRESHOLD == 4, "Limite de golpes consecutivos antes do contra-ataque é 4")
	_assert(boss.has_signal("counter_attack_performed"), "Sinal counter_attack_performed existe para auditoria e feedback")

	print("\n--- Teste 2: Detecção de Voadora (Ataque Aéreo) ---")
	player._current_attack_anim = &"jump_atk"
	player._is_jumping = true
	var jumpkick_info: RefCounted = DamageInfoClass.new(
		35.0, player, player.global_position, Vector2(1.0, 0.0),
		"melee", 80.0, 0.22, true, false, 0.05, "kick", "upper_torso",
		boss.global_position + Vector2(0.0, -110.0)
	)
	_assert(boss._is_flying_kick(jumpkick_info), "Ataque com estado de salto e anim jump_atk é identificado como voadora")

	player._current_attack_anim = &"punch"
	player._is_jumping = false
	var punch_info: RefCounted = DamageInfoClass.new(
		15.0, player, player.global_position, Vector2(1.0, 0.0),
		"melee", 40.0, 0.2, false, false, 0.05, "punch", "upper_torso",
		boss.global_position + Vector2(0.0, -110.0)
	)
	_assert(not boss._is_flying_kick(punch_info), "Soco em terra não é classificado como voadora")

	print("\n--- Teste 3: Contra-Ataque Imediato ao Chegar na Voadora (60% Chance) ---")
	# Configurar chance em 1.0 (100%) para validar o ramo de ativação
	boss.counter_attack_chance = 1.0
	boss.current_state = EnemyAIClass.State.IDLE
	var counter_data := {"attack": ""}
	var on_counter := func(atk: String) -> void:
		counter_data["attack"] = atk
	boss.counter_attack_performed.connect(on_counter)

	player._current_attack_anim = &"jump_atk"
	player._is_jumping = true
	var hp_before_voadora: float = boss.health_component.current_health
	var voadora_accepted: bool = boss.take_damage(jumpkick_info)

	_assert(voadora_accepted, "Alessandro aceita o impacto da voadora")
	_assert(boss.health_component.current_health < hp_before_voadora, "Alessandro computa o dano da voadora")
	_assert(boss.current_state == EnemyAIClass.State.ATTACKING, "Alessandro entra imediatamente no estado ATTACKING para contra-atacar")
	_assert(boss.melee_attack != null and boss.melee_attack.is_attacking, "MeleeAttack de Alessandro está em execução ativa")
	_assert(counter_data["attack"] in ["punch", "kick"], "Golpe desferido no contra-ataque é soco ('punch') ou chute ('kick'): %s" % counter_data["attack"])

	# Validar ramo onde os 40% não ativam contra-ataque
	boss.melee_attack.cancel_attack()
	boss.current_state = EnemyAIClass.State.IDLE
	boss.counter_attack_chance = 0.0
	counter_data["attack"] = ""
	boss._evasion_cooldown = 10.0 # Sem esquiva
	boss.take_damage(jumpkick_info)
	_assert(counter_data["attack"] == "", "Com 40% (chance 0), Alessandro reage normalmente sem disparar contra-ataque")

	print("\n--- Teste 4: Mais de 4 Golpes Encaixados Dispara Contra-Ataque (60% Chance) ---")
	boss.counter_attack_chance = 1.0
	boss.melee_attack.cancel_attack()
	boss.current_state = EnemyAIClass.State.IDLE
	boss._player_consecutive_hits = 0
	boss._player_combo_hit_timer = 0.0
	counter_data["attack"] = ""

	player._current_attack_anim = &"punch"
	player._is_jumping = false

	# Encaixar golpes 1 a 4 (nenhum deve disparar contra-ataque)
	for i in range(1, 5):
		boss.take_damage(punch_info)
		_assert(boss._player_consecutive_hits == i, "Golpe %d encaixado registrado no contador consecutivo" % i)
		_assert(counter_data["attack"] == "", "Golpe %d não dispara contra-ataque (limite é > 4)" % i)

	# 5º golpe encaixado (mais que 4 golpes): DEVE disparar o contra-ataque!
	boss.take_damage(punch_info)
	_assert(counter_data["attack"] in ["punch", "kick"], "5º golpe (> 4) disparou contra-ataque com soco ou chute: %s" % counter_data["attack"])
	_assert(boss.current_state == EnemyAIClass.State.ATTACKING, "Alessandro transitou para ATTACKING no 5º golpe")
	_assert(boss._player_consecutive_hits == 0, "Contador consecutivo foi resetado após o contra-ataque")

	print("\n--- Teste 5: Timeout da Janela de Combo Reseta Contador ---")
	boss.melee_attack.cancel_attack()
	boss.current_state = EnemyAIClass.State.IDLE
	boss.take_damage(punch_info)
	boss.take_damage(punch_info)
	_assert(boss._player_consecutive_hits == 2, "Dois golpes registrados")
	# Simular passagem de tempo superior a CONSECUTIVE_HITS_WINDOW (1.8s)
	boss._update_player_combo_hit_window(2.0)
	_assert(boss._player_consecutive_hits == 0, "Contador zera quando o jogador interrompe o combo após 2 segundos")

	print("\n--- Teste 6: Preservação de Estados Especiais (Sem Contra-Ataque Indevido) ---")
	# Alessandro tonto por Loro não contra-ataca
	boss.counter_attack_chance = 1.0
	boss._loro_stun_timer = 3.0
	counter_data["attack"] = ""
	boss._player_consecutive_hits = 4
	boss.take_damage(punch_info)
	_assert(counter_data["attack"] == "", "Alessandro atordoado pelo Loro NÃO dispara contra-ataque")
	boss._loro_stun_timer = 0.0

	# Alessandro em queda (FALL) não contra-ataca
	boss.current_state = EnemyAIClass.State.FALL
	counter_data["attack"] = ""
	boss._player_consecutive_hits = 4
	boss.take_damage(punch_info)
	_assert(counter_data["attack"] == "", "Alessandro no chão/queda (FALL) NÃO dispara contra-ataque")

	# Alessandro morto não contra-ataca
	boss.current_state = EnemyAIClass.State.DEAD
	counter_data["attack"] = ""
	boss.take_damage(punch_info)
	_assert(counter_data["attack"] == "", "Alessandro morto NÃO dispara contra-ataque")

	# Restaurar estado padrão
	boss.counter_attack_chance = boss.COUNTER_ATTACK_CHANCE

	world.free()

	print("\n========================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("========================================================")
	quit(0 if failed_tests == 0 else 1)
