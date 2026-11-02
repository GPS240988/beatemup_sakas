extends SceneTree

const GamesBoxScene: PackedScene = preload("res://scenes/props/destructible_games_box.tscn")
const DestructiblePropClass = preload("res://scripts/props/destructible_prop.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s" % test_name)

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n==================================================")
	print("INICIANDO SUITE DE TESTES: DESTRUCTIBLE GAMES BOX")
	print("==================================================")

	var box: DestructibleProp = GamesBoxScene.instantiate() as DestructibleProp
	assert_test(box != null, "Cena destructible_games_box.tscn instanciada com sucesso")
	assert_test(box is DestructiblePropClass, "Instância é da classe DestructibleProp")
	assert_test(box.is_in_group("destructibles"), "Objeto está no grupo 'destructibles'")
	assert_test(box.is_in_group("destructible_props"), "Objeto está no grupo 'destructible_props'")
	assert_test(box.is_in_group("damageable"), "Objeto está no grupo 'damageable'")
	assert_test(box.collision_layer == 2, "Collision layer == 2 (Mundo sólido)")
	assert_test(box.collision_mask == 1, "Collision mask == 1 (Atores)")

	root.add_child(box)
	await process_frame

	var sprite: Sprite2D = box.get_node_or_null("Visual/Sprite2D") as Sprite2D
	assert_test(sprite != null, "Nó Visual/Sprite2D existe")
	assert_test(box.damage_stage_textures.size() == 4, "Configurado com exatamente 4 estágios de sprites")

	# Estágio 0: Intacto (games1)
	assert_test(sprite.texture.resource_path.ends_with("games1.webp"), "Estágio 0 Inicial: textura é games1.webp")
	assert_test(box.is_active(), "Estado inicial é ACTIVE")
	assert_test(box.current_health == 30.0, "Vida inicial é 30.0")

	# Golpe 1: 10 de dano -> Estágio 1 (games2)
	var dmg1: bool = box.take_damage(10.0)
	assert_test(dmg1, "Golpe 1 (10 de dano) aceito com sucesso")
	assert_test(box.current_health == 20.0, "Vida após golpe 1 é 20.0")
	assert_test(box.is_damaged(), "Estado agora é DAMAGED")
	assert_test(sprite.texture.resource_path.ends_with("games2.webp"), "Estágio 1 após 1 golpe: textura é games2.webp")

	# Golpe 2: 10 de dano -> Estágio 2 (games3)
	var dmg2: bool = box.take_damage(10.0)
	assert_test(dmg2, "Golpe 2 (10 de dano) aceito com sucesso")
	assert_test(box.current_health == 10.0, "Vida após golpe 2 é 10.0")
	assert_test(sprite.texture.resource_path.ends_with("games3.webp"), "Estágio 2 após 2 golpes: textura é games3.webp")

	# Golpe 3: 10 de dano -> Letal -> Estágio 3 (games4)
	var dmg3: bool = box.take_damage(10.0)
	assert_test(dmg3, "Golpe 3 (10 de dano letal) aceito com sucesso")
	assert_test(box.current_health == 0.0, "Vida após golpe 3 é 0.0")
	assert_test(box.is_prop_destroyed(), "Estado final é DESTROYED")
	assert_test(box.is_broken, "is_broken é true")
	assert_test(sprite.texture.resource_path.ends_with("games4.webp"), "Estágio 3 após destruição: textura é games4.webp (escombros)")

	await process_frame

	# Colisão e navegação devem estar desativadas para passagem livre
	var col: CollisionShape2D = box.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_test(col.disabled, "CollisionShape2D desabilitado (atores podem passar por cima dos escombros)")
	var nav: NavigationObstacle2D = box.get_node_or_null("NavigationIntegration") as NavigationObstacle2D
	assert_test(not nav.avoidance_enabled, "NavigationObstacle2D desabilitado")

	# Reset do prop restaura estágio 0
	box.reset_prop()
	assert_test(box.current_health == 30.0, "Após reset_prop(), vida volta a 30.0")
	assert_test(box.is_active(), "Após reset_prop(), estado volta a ACTIVE")
	assert_test(sprite.texture.resource_path.ends_with("games1.webp"), "Após reset_prop(), textura volta a games1.webp")

	box.queue_free()

	print("==================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")
	quit(0 if failed_tests == 0 else 1)
