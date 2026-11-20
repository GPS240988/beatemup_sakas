extends SceneTree

## Suíte de Testes Automatizada: Gabriel vs Chefe Alessandro (Balística e Granadas)
## Valida que os projéteis (PlayerBullet) e granadas (PlayerGrenade) de Gabriel
## atingem fisicamente e causam dano no Chefe Alessandro em conformidade com GAME_RULES.md.

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
	print("TESTE INTEGRADO: GABRIEL VS CHEFE ALESSANDRO")
	print("==================================================")

	await _test_bullet_physical_hit_on_alessandro()
	await _test_bullet_depth_tolerance_against_alessandro()
	await _test_boss_poise_on_finisher_bullet()
	await _test_grenade_direct_impact_on_alessandro()
	await _test_grenade_fuse_detonation()
	await _test_meat_seeking_invulnerability()

	print("\n==================================================")
	print("RESULTADO: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")

	quit(0 if _failed == 0 else 1)


func _test_bullet_physical_hit_on_alessandro() -> void:
	print("\n--- 1. Colisão Física do Projétil de Gabriel no Chefe Alessandro ---")
	var boss_scn = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var player_scn = load("res://scenes/actors/player/player.tscn") as PackedScene
	var bullet_scn = load("res://scenes/actors/projectiles/player_bullet.tscn") as PackedScene

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
	await process_frame

	var health: Node = boss.get_node("HealthComponent")
	var hp_before: float = health.current_health
	_assert(hp_before == 900.0, "Alessandro inicia com 900 HP")

	# Dispara projétil do jogador em direção ao chefe
	var bullet = bullet_scn.instantiate() as Area2D
	bullet.attacker = player
	bullet.projectile_lane_y = player.global_position.y
	bullet.direction = Vector2.RIGHT
	bullet.damage = 14.0
	bullet.max_range = 350.0
	bullet.depth_tolerance = 24.0
	bullet.global_position = player.call("_get_muzzle_global_position")
	root.add_child(bullet)

	# Aguarda frames de física até o projétil cruzar a distância de 200px (a 700 px/s, leva ~0.3s = ~18 frames)
	for i in range(35):
		await physics_frame
		if health.current_health < hp_before:
			break

	var hp_after: float = health.current_health
	_assert(hp_after < hp_before, "Projétil de Gabriel atingiu fisicamente Alessandro (HP: %.1f -> %.1f)" % [hp_before, hp_after])
	_assert(is_equal_approx(hp_after, hp_before - 14.0), "Dano de 14.0 do projétil subtraído com precisão")

	boss.queue_free()
	player.queue_free()
	if is_instance_valid(bullet):
		bullet.queue_free()
	await process_frame


func _test_bullet_depth_tolerance_against_alessandro() -> void:
	print("\n--- 2. Tolerância de Profundidade 2.5D do Projétil Contra Alessandro ---")
	var boss_scn = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var player_scn = load("res://scenes/actors/player/player.tscn") as PackedScene
	var bullet_scn = load("res://scenes/actors/projectiles/player_bullet.tscn") as PackedScene

	# Teste A: Alessandro deslocado em +15 px Y (dentro da tolerância de 24 px)
	var boss = boss_scn.instantiate() as CharacterBody2D
	root.add_child(boss)
	boss.global_position = Vector2(500.0, 315.0)

	var player = player_scn.instantiate() as CharacterBody2D
	root.add_child(player)
	player.global_position = Vector2(300.0, 300.0)
	if player.has_method("set_hero"):
		player.call("set_hero", "gabriel")

	await process_frame
	await process_frame

	var health: Node = boss.get_node("HealthComponent")
	var hp_before: float = health.current_health

	var bullet = bullet_scn.instantiate() as Area2D
	bullet.attacker = player
	bullet.projectile_lane_y = player.global_position.y
	bullet.direction = Vector2.RIGHT
	bullet.damage = 14.0
	bullet.max_range = 350.0
	bullet.depth_tolerance = 24.0
	bullet.global_position = player.call("_get_muzzle_global_position")
	root.add_child(bullet)

	for i in range(35):
		await physics_frame
		if health.current_health < hp_before:
			break

	_assert(health.current_health < hp_before, "Projétil atinge Alessandro com offset de profundidade de +15 px")

	boss.queue_free()
	player.queue_free()
	if is_instance_valid(bullet):
		bullet.queue_free()
	await process_frame


func _test_boss_poise_on_finisher_bullet() -> void:
	print("\n--- 3. Poise Arcade do Chefe Alessandro contra Knockdown de Projétil ---")
	var boss_scn = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var player_scn = load("res://scenes/actors/player/player.tscn") as PackedScene
	var bullet_scn = load("res://scenes/actors/projectiles/player_bullet.tscn") as PackedScene

	var boss = boss_scn.instantiate() as CharacterBody2D
	root.add_child(boss)
	boss.global_position = Vector2(500.0, 300.0)

	var player = player_scn.instantiate() as CharacterBody2D
	root.add_child(player)
	player.global_position = Vector2(300.0, 300.0)
	if player.has_method("set_hero"):
		player.call("set_hero", "gabriel")

	await process_frame
	await process_frame

	# Dispara projétil finalizador do Passo 4 (can_knockdown = true)
	var bullet = bullet_scn.instantiate() as Area2D
	bullet.attacker = player
	bullet.projectile_lane_y = player.global_position.y
	bullet.direction = Vector2.RIGHT
	bullet.damage = 24.0
	bullet.can_knockdown = true
	bullet.impact_profile = "finisher"
	bullet.max_range = 350.0
	bullet.depth_tolerance = 30.0
	bullet.global_position = player.call("_get_muzzle_global_position")
	root.add_child(bullet)

	var health: Node = boss.get_node("HealthComponent")
	var hp_before: float = health.current_health

	for i in range(35):
		await physics_frame
		if health.current_health < hp_before:
			break

	_assert(health.current_health < hp_before, "Projétil finalizador atingiu Alessandro com sucesso")
	# Chefe tem poise arcade: não entra no estado FALL por golpe comum
	_assert(boss.current_state != 6, "Alessandro preserva poise arcade (não cai ao solo em projétil finalizador)")

	boss.queue_free()
	player.queue_free()
	if is_instance_valid(bullet):
		bullet.queue_free()
	await process_frame


func _test_grenade_direct_impact_on_alessandro() -> void:
	print("\n--- 4. Impacto Direto da Granada de Gabriel no Chefe Alessandro ---")
	var boss_scn = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var player_scn = load("res://scenes/actors/player/player.tscn") as PackedScene
	var grenade_scn = load("res://scenes/actors/projectiles/player_grenade.tscn") as PackedScene

	var boss = boss_scn.instantiate() as CharacterBody2D
	root.add_child(boss)
	boss.global_position = Vector2(420.0, 300.0)

	var player = player_scn.instantiate() as CharacterBody2D
	root.add_child(player)
	player.global_position = Vector2(300.0, 300.0)
	if player.has_method("set_hero"):
		player.call("set_hero", "gabriel")

	await process_frame
	await process_frame

	var health: Node = boss.get_node("HealthComponent")
	var hp_before: float = health.current_health

	var grenade = grenade_scn.instantiate() as Node2D
	root.add_child(grenade)
	grenade.call("launch", player, 1.0)

	# A granada foi lançada em direção ao chefe (a 120px). Deve detonar por impacto direto rapidamente (em < 0.4s)
	var detonated_frame: int = -1
	for frame in range(60):
		await physics_frame
		if health.current_health < hp_before:
			detonated_frame = frame
			break

	_assert(detonated_frame >= 0, "Granada atingiu Alessandro por impacto direto (frame: %d)" % detonated_frame)
	_assert(detonated_frame < 45, "Detonação ocorreu imediatamente no contato, sem aguardar os 2s do pavio")
	_assert(health.current_health < hp_before, "Alessandro recebeu o dano de impacto da granada (HP: %.1f -> %.1f)" % [hp_before, health.current_health])

	boss.queue_free()
	player.queue_free()
	if is_instance_valid(grenade):
		grenade.queue_free()
	await process_frame


func _test_grenade_fuse_detonation() -> void:
	print("\n--- 5. Detonação Natural por Pavio (2 Segundos) em Terreno Vazio ---")
	var player_scn = load("res://scenes/actors/player/player.tscn") as PackedScene
	var grenade_scn = load("res://scenes/actors/projectiles/player_grenade.tscn") as PackedScene

	var player = player_scn.instantiate() as CharacterBody2D
	root.add_child(player)
	player.global_position = Vector2(100.0, 300.0)

	var grenade = grenade_scn.instantiate() as Node2D
	root.add_child(grenade)
	grenade.call("launch", player, 1.0)

	# Em terreno vazio sem inimigos, aguarda o pavio de 2.0s
	var detonated: bool = false
	for frame in range(140): # ~2.3s a 60 fps
		await physics_frame
		if grenade.get("_detonated") == true:
			detonated = true
			break

	_assert(detonated, "Granada em terreno aberto detona naturalmente ao expirar o pavio de 2.0s")

	player.queue_free()
	if is_instance_valid(grenade):
		grenade.queue_free()
	await process_frame


func _test_meat_seeking_invulnerability() -> void:
	print("\n--- 6. Invulnerabilidade da Perseguição à Carne (GAME_RULES.md) ---")
	for _c in range(5):
		await process_frame

	var boss_scn = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var player_scn = load("res://scenes/actors/player/player.tscn") as PackedScene
	var bullet_scn = load("res://scenes/actors/projectiles/player_bullet.tscn") as PackedScene

	var player = player_scn.instantiate() as CharacterBody2D
	root.add_child(player)
	player.global_position = Vector2(100.0, 800.0)

	var boss = boss_scn.instantiate() as CharacterBody2D
	root.add_child(boss)
	boss.global_position = Vector2(500.0, 800.0)
	boss.player_target = player

	await process_frame
	await process_frame

	boss.set("_special_behavior", 4) # SpecialBehavior.MEAT_SEEKING
	boss.set_physics_process(false) # Pausa a IA para manter o estado MEAT_SEEKING sem carne no mapa

	var health: Node = boss.get_node("HealthComponent")
	_assert(is_equal_approx(health.current_health, 900.0), "Boss MEAT_SEEKING inicia com 900 HP antes do projétil")
	var hp_before: float = health.current_health

	# Dispara projétil de Gabriel em direção ao boss
	var bullet = bullet_scn.instantiate() as Area2D
	bullet.attacker = player
	bullet.projectile_lane_y = 800.0
	bullet.direction = Vector2.RIGHT
	bullet.damage = 14.0
	bullet.max_range = 350.0
	bullet.depth_tolerance = 24.0
	bullet.global_position = Vector2(400.0, 800.0 - 172.0)
	root.add_child(bullet)

	for i in range(35):
		await physics_frame

	var hp_after: float = health.current_health
	_assert(is_equal_approx(hp_after, hp_before), "Alessandro rejeita dano de projétil durante perseguição da carne (HP: %.1f -> %.1f)" % [hp_before, hp_after])

	boss.queue_free()
	player.queue_free()
	if is_instance_valid(bullet):
		bullet.queue_free()
	await process_frame
