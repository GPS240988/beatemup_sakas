extends SceneTree

## Suíte de Testes: Normalização da Jogabilidade de Gabriel
## 1) Boss Alessandro desvia dos tiros de Gabriel com a mesma taxa (80%) que contra Guilherme.
## 2) Gabriel evade as trufas de Alessandro através do dash (MISS feedback e sem dano).
## 3) Na fase bônus, os tiros de Gabriel causam dano aos carros (reduz HP do veículo).

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
	print("==================================================")
	print("SUÍTE DE TESTES: NORMALIZAÇÃO DE JOGABILIDADE - GABRIEL")
	print("==================================================")

	await _test_alessandro_bullet_evasion()
	await _test_gabriel_dash_evades_trufa()
	await _test_gabriel_bullet_damages_bonus_cars()

	print("\n==================================================")
	print("RESULTADO: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")

	quit(0 if _failed == 0 else 1)


## 1. Alessandro desvia dos tiros de Gabriel com a mesma taxa que contra Guilherme
func _test_alessandro_bullet_evasion() -> void:
	print("\n--- 1. Alessandro Evadindo Tiros de Gabriel (Taxa de 80%) ---")
	var boss_scn = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var player_scn = load("res://scenes/actors/player/player.tscn") as PackedScene
	var damage_info_cls = load("res://scripts/combat/damage_info.gd")

	var boss = boss_scn.instantiate() as CharacterBody2D
	root.add_child(boss)
	boss.global_position = Vector2(500.0, 300.0)

	var player = player_scn.instantiate() as CharacterBody2D
	root.add_child(player)
	player.global_position = Vector2(300.0, 300.0)
	if player.has_method("set_hero"):
		player.call("set_hero", "gabriel")
	elif "selected_hero" in player:
		player.selected_hero = "gabriel"

	await process_frame

	var boss_health: Node = boss.get_node_or_null("HealthComponent")
	_assert(boss_health != null, "Boss possui HealthComponent")
	boss.player_target = player
	_assert(boss.has_method("_is_player_evadable_damage"), "Boss possui método _is_player_evadable_damage")

	var bullet_damage = damage_info_cls.new(
		14.0,
		player,
		player.global_position,
		Vector2.RIGHT,
		"projectile",
		120.0,
		0.25,
		true,
		false,
		0.05,
		"light",
		"upper_torso",
		boss.global_position + Vector2(-15.0, -110.0)
	)

	_assert(boss.call("_is_player_evadable_damage", bullet_damage) == true, "Tiro de Gabriel é reconhecido como evadível por Alessandro")
	_assert(boss.call("_get_evasion_chance") == 0.8, "Taxa de evasão de Alessandro contra tiros é de 80% (0.8)")

	# Evasão executada com sucesso
	boss.set("_evasion_cooldown", 0.0)
	boss.set("_special_behavior", 0) # SpecialBehavior.NONE
	boss.set("current_state", 1) # State.WAITING ou FLANKING
	
	seed(42)
	var evasion_count: int = 0
	var hit_count: int = 0
	var trials: int = 50

	for i in range(trials):
		boss.set("_evasion_cooldown", 0.0)
		boss.set("_special_behavior", 0)
		boss.set("current_state", 1)
		var hp_before = boss_health.current_health
		var took_dmg = boss.take_damage(bullet_damage)
		if not took_dmg:
			evasion_count += 1
		else:
			hit_count += 1
			boss_health.current_health = hp_before # restaura HP

	print("    Evasões contra tiros em %d testes: %d evasões / %d acertos" % [trials, evasion_count, hit_count])
	_assert(evasion_count > 30, "Alessandro evadiu a maioria dos tiros de Gabriel (taxa em torno de 80%%)")
	_assert(hit_count > 0, "Alessandro não é 100%% invulnerável: sofre dano na margem de 20%%")

	# Limpeza
	boss.queue_free()
	player.queue_free()
	await process_frame


## 2. Gabriel evade as trufas de Alessandro através do dash
func _test_gabriel_dash_evades_trufa() -> void:
	print("\n--- 2. Gabriel Evadindo Trufas de Alessandro com Dash ---")
	var trufa_scn = load("res://scenes/actors/projectiles/trufa.tscn") as PackedScene
	var player_scn = load("res://scenes/actors/player/player.tscn") as PackedScene

	var player = player_scn.instantiate() as CharacterBody2D
	root.add_child(player)
	player.global_position = Vector2(400.0, 300.0)
	if player.has_method("set_hero"):
		player.call("set_hero", "gabriel")
	elif "selected_hero" in player:
		player.selected_hero = "gabriel"

	await process_frame

	var health_comp = player.get_node_or_null("HealthComponent")
	var initial_hp: float = health_comp.current_health if health_comp != null else 100.0

	# Caso A: Gabriel sem dash (parado) toma dano da trufa
	var trufa_hit = trufa_scn.instantiate() as RigidBody2D
	root.add_child(trufa_hit)
	trufa_hit.global_position = player.global_position + Vector2(0.0, -90.0)
	var player_hurtbox = player.get_node_or_null("Hurtbox") as Area2D
	_assert(player_hurtbox != null, "Player possui Hurtbox")

	# Simula entrada na hurtbox sem dash
	trufa_hit.call("_on_hitbox_area_entered", player_hurtbox)
	await process_frame

	var hp_after_hit: float = health_comp.current_health if health_comp != null else 0.0
	_assert(hp_after_hit < initial_hp, "Gabriel sem dash sofre dano da trufa de Alessandro (HP: %.1f -> %.1f)" % [initial_hp, hp_after_hit])

	# Caso B: Gabriel executando dash evade a trufa sem sofrer dano e com MISS
	health_comp.current_health = initial_hp
	player.set("_is_dashing", true)
	if player.has_method("is_dashing"):
		_assert(player.is_dashing() == true, "Gabriel reporta is_dashing() == true durante dash")

	var trufa_evaded = trufa_scn.instantiate() as RigidBody2D
	root.add_child(trufa_evaded)
	trufa_evaded.global_position = player.global_position + Vector2(0.0, -90.0)

	trufa_evaded.call("_on_hitbox_area_entered", player_hurtbox)
	await process_frame

	var hp_after_dash: float = health_comp.current_health if health_comp != null else 0.0
	_assert(hp_after_dash == initial_hp, "Gabriel em dash NÃO sofre dano da trufa (HP inalterado: %.1f)" % hp_after_dash)

	# Limpeza
	player.set("_is_dashing", false)
	player.queue_free()
	await process_frame


## 3. Na fase bônus, os tiros de Gabriel causam dano aos carros
func _test_gabriel_bullet_damages_bonus_cars() -> void:
	print("\n--- 3. Projéteis de Gabriel Causando Dano aos Carros da Fase Bônus ---")
	var orange_scn = load("res://scenes/props/bonus_car_orange.tscn") as PackedScene
	var blue_scn = load("res://scenes/props/bonus_car_blue.tscn") as PackedScene
	var bullet_scn = load("res://scenes/actors/projectiles/player_bullet.tscn") as PackedScene
	var player_scn = load("res://scenes/actors/player/player.tscn") as PackedScene

	var player = player_scn.instantiate() as CharacterBody2D
	root.add_child(player)
	player.global_position = Vector2(200.0, 660.0)
	if player.has_method("set_hero"):
		player.call("set_hero", "gabriel")
	elif "selected_hero" in player:
		player.selected_hero = "gabriel"

	# Instancia Carro Laranja na posição canônica da garagem
	var car_orange = orange_scn.instantiate() as Node2D
	root.add_child(car_orange)
	car_orange.global_position = Vector2(480.0, 660.0)

	await process_frame

	var car_initial_hp: float = car_orange.current_health
	_assert(car_orange.is_in_group("destructible_props"), "Carro laranja está no grupo destructible_props")
	_assert(car_orange.is_in_group("vehicles"), "Carro laranja está no grupo vehicles")

	# Dispara projétil de Gabriel em direção ao carro laranja
	var bullet_orange = bullet_scn.instantiate() as Area2D
	bullet_orange.attacker = player
	bullet_orange.damage = 14.0
	bullet_orange.knockback_force = 120.0
	bullet_orange.hitstun_duration = 0.25
	bullet_orange.hitstop_duration = 0.05
	bullet_orange.can_knockdown = false
	bullet_orange.impact_profile = "light"
	bullet_orange.projectile_lane_y = 660.0
	bullet_orange.direction = Vector2.RIGHT
	bullet_orange.global_position = player.global_position + Vector2(74.0, -172.0)
	root.add_child(bullet_orange)

	# Simula contato do tiro com o carro
	var hit_applied: bool = bullet_orange.test_hit_candidate(car_orange)
	_assert(hit_applied == true, "Tiro de Gabriel acertou o Carro Laranja com sucesso")
	_assert(car_orange.current_health < car_initial_hp, "Carro Laranja perdeu HP após o tiro (HP: %.1f -> %.1f)" % [car_initial_hp, car_orange.current_health])

	# Testa também com o Carro Azul
	var car_blue = blue_scn.instantiate() as Node2D
	root.add_child(car_blue)
	car_blue.global_position = Vector2(1160.0, 680.0)
	player.global_position = Vector2(900.0, 680.0)

	await process_frame

	var blue_initial_hp: float = car_blue.current_health
	var bullet_blue = bullet_scn.instantiate() as Area2D
	bullet_blue.attacker = player
	bullet_blue.damage = 14.0
	bullet_blue.knockback_force = 120.0
	bullet_blue.hitstun_duration = 0.25
	bullet_blue.hitstop_duration = 0.05
	bullet_blue.can_knockdown = false
	bullet_blue.impact_profile = "light"
	bullet_blue.projectile_lane_y = 680.0
	bullet_blue.direction = Vector2.RIGHT
	bullet_blue.global_position = player.global_position + Vector2(74.0, -172.0)
	root.add_child(bullet_blue)

	var blue_hit_applied: bool = bullet_blue.test_hit_candidate(car_blue)
	_assert(blue_hit_applied == true, "Tiro de Gabriel acertou o Carro Azul com sucesso")
	_assert(car_blue.current_health < blue_initial_hp, "Carro Azul perdeu HP após o tiro (HP: %.1f -> %.1f)" % [blue_initial_hp, car_blue.current_health])

	# Limpeza
	player.queue_free()
	car_orange.queue_free()
	car_blue.queue_free()
	await process_frame
