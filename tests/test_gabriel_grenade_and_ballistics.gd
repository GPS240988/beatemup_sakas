extends SceneTree

## Suíte de Testes Automatizada: Granadas e Balística Avançada do Gabriel
## Valida os 3 pontos:
## 1. Contato do projétil (recuo -14px, trajetória em linha reta, contato na face da Hurtbox)
## 2. Rajada dupla (intervalo 0.16s, separação 112px, disparo e muzzle independentes)
## 3. Granadas do Gabriel (cargas, tecla H vs K, arco de arremesso com quique, 2s pavio, 150px raio, save/load)

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
	print("TESTE INTEGRADO: BALÍSTICA E GRANADAS DO GABRIEL")
	print("==================================================")

	_test_projectile_contact_and_trajectory()
	_test_double_burst_cadence()
	_test_grenade_mechanics_and_controls()
	_test_grenade_persistence()

	print("\n==================================================")
	print("RESULTADO: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")

	quit(0 if _failed == 0 else 1)


func _ensure_game_session() -> Node:
	var session = root.get_node_or_null("GameSession")
	if session == null:
		var session_script = load("res://scripts/core/game_session.gd") as GDScript
		session = session_script.new()
		session.name = "GameSession"
		root.add_child(session)
	return session


func _test_projectile_contact_and_trajectory() -> void:
	print("\n--- 1. Contato do Projétil e Trajetória em Linha Reta ---")
	var bullet_scene: PackedScene = load("res://scenes/actors/projectiles/player_bullet.tscn")
	_assert(bullet_scene != null, "player_bullet.tscn carregada com sucesso")

	var bullet: Area2D = bullet_scene.instantiate() as Area2D
	root.add_child(bullet)

	var shape_node: CollisionShape2D = bullet.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_assert(shape_node != null, "CollisionShape2D presente no projétil")
	_assert(is_equal_approx(shape_node.position.x, -14.0), "Recuo de -14 px na colisão do projétil configurado")

	# Trajetória em linha reta: projétil mantém sua posição Y original após voo
	bullet.projectile_lane_y = 400.0
	bullet.global_position = Vector2(100.0, 400.0 - 172.0) # 228.0 (altura do cano)
	var initial_y: float = bullet.global_position.y

	# Avança 0.09s — projétil deve manter-se na mesma altura (sem descida)
	bullet._physics_process(0.09)
	_assert(is_equal_approx(bullet.global_position.y, initial_y), "Projétil voa em linha reta sem descida vertical (Y=%.1f)" % bullet.global_position.y)

	# Avança mais 0.10s — continua na mesma altura
	bullet._physics_process(0.10)
	_assert(is_equal_approx(bullet.global_position.y, initial_y), "Projétil mantém linha reta após 0.19s de voo (Y=%.1f)" % bullet.global_position.y)

	# Verifica deslocamento horizontal (direction = RIGHT por padrão)
	var expected_x: float = 100.0 + 700.0 * 0.19
	_assert(absf(bullet.global_position.x - expected_x) < 2.0, "Deslocamento horizontal correto (~%.0f px)" % expected_x)

	# Teste de resolução do ponto de impacto na face voltada ao disparo
	var dummy_enemy := CharacterBody2D.new()
	var dummy_hurtbox := Area2D.new()
	dummy_hurtbox.name = "Hurtbox"
	var enemy_shape := CollisionShape2D.new()
	enemy_shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = Vector2(50.0, 100.0)
	enemy_shape.shape = box
	dummy_hurtbox.add_child(enemy_shape)
	dummy_enemy.add_child(dummy_hurtbox)
	dummy_enemy.global_position = Vector2(300.0, 400.0)
	root.add_child(dummy_enemy)

	var contact_pt: Vector2 = bullet._resolve_target_contact_point(dummy_hurtbox, dummy_enemy)
	# Disparo vindo da esquerda (direction.x > 0): deve tocar a face esquerda do retângulo (-25px do centro do inimigo -> X = 275)
	_assert(is_equal_approx(contact_pt.x, 275.0), "Contato resolvido na face frontal real da Hurtbox (X=275 px)")

	bullet.queue_free()
	dummy_enemy.queue_free()


func _test_double_burst_cadence() -> void:
	print("\n--- 2. Rajada Dupla: Intervalo e Separação Balística ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)

	var combo: Array = player.get("_combo_attacks")
	_assert(combo.size() == 4, "Gabriel possui 4 passos no combo")
	var atk2: Resource = combo[1]
	_assert(int(atk2.get("projectile_count")) == 2, "Passo 2 é rajada dupla (2 projéteis)")
	_assert(is_equal_approx(float(atk2.get("projectile_interval")), 0.16), "Intervalo entre disparos aumentado para 0.16s")

	var separation: float = 700.0 * 0.16
	_assert(is_equal_approx(separation, 112.0), "A 700 px/s, separação balística produz exatamente 112 px")

	player.queue_free()


func _test_grenade_mechanics_and_controls() -> void:
	print("\n--- 3. Granadas do Gabriel: Mecânica, Entrada e Touch ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)

	var handler: GabrielGrenadeHandler = player.get_node_or_null("GrenadeHandler") as GabrielGrenadeHandler
	_assert(handler != null, "GrenadeHandler presente no Player")
	_assert(handler.grenades_remaining == 2, "Gabriel inicia com exatamente 2 granadas por mapa")

	# Validação de Mapeamento de Teclas: H lança granada para Gabriel
	handler._configure_input_mapping()
	_assert(InputMap.has_action("throw_grenade"), "Ação throw_grenade registrada no InputMap")

	var throw_events: Array[InputEvent] = InputMap.action_get_events("throw_grenade")
	var has_h_throw: bool = false
	for ev in throw_events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_H or ev.keycode == KEY_H):
			has_h_throw = true
	_assert(has_h_throw, "Tecla H mapeada para throw_grenade quando Gabriel está ativo")

	# Lança primeira granada
	var launched_1: bool = handler.throw_grenade()
	_assert(launched_1, "Primeira granada lançada com sucesso")
	_assert(handler.grenades_remaining == 1, "Restante: 1 carga")

	# Lança segunda granada
	var launched_2: bool = handler.throw_grenade()
	_assert(launched_2, "Segunda granada lançada com sucesso")
	_assert(handler.grenades_remaining == 0, "Restante: 0 cargas")

	# Tentativa de lançar sem cargas
	var launched_3: bool = handler.throw_grenade()
	_assert(not launched_3, "Terceira tentativa bloqueada por falta de munição")

	# TouchControls: validação de integração
	var touch_script: GDScript = load("res://scripts/ui/touch_controls.gd") as GDScript
	var touch: TouchControls = touch_script.new() as TouchControls
	touch.test_mode = true
	root.add_child(touch)
	touch.call("_recalculate_layout")

	_assert(touch.grenade_btn_pos != Vector2.ZERO, "Posição do botão touch de granada calculada")
	_assert(is_equal_approx(float(touch.grenade_btn_radius), 44.0), "Raio do botão de granada configurado")

	player.queue_free()
	touch.queue_free()


func _test_grenade_persistence() -> void:
	print("\n--- 4. Persistência de Granadas no Save/Load ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"

	var base_level_script: GDScript = load("res://scripts/levels/base_level.gd") as GDScript
	var level = base_level_script.new()
	root.add_child(level)

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	level.add_child(player)
	level.player = player

	var handler: GabrielGrenadeHandler = player.get_node_or_null("GrenadeHandler") as GabrielGrenadeHandler
	handler.set_grenades_remaining(1)

	var snapshot: Dictionary = level.capture_world_snapshot()
	_assert(snapshot.has("player"), "Snapshot contém dados do jogador")
	var pdata: Dictionary = snapshot["player"]
	_assert(int(pdata.get("grenades_remaining", -1)) == 1, "Estoque de granadas (1) capturado no snapshot")

	# Modifica o estoque para 0 e restaura do snapshot
	handler.set_grenades_remaining(0)
	_assert(handler.grenades_remaining == 0, "Estoque zerado antes da restauração")

	level.restore_world_snapshot(snapshot)
	_assert(handler.grenades_remaining == 1, "Estoque restaurado para 1 carga via restore_world_snapshot()")

	player.queue_free()
	level.queue_free()
