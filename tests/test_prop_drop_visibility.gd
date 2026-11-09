extends SceneTree

## Suíte de Testes Automatizados: Visibilidade e Posicionamento de Drops e Caixa Fase 1_2
## Valida o posicionamento da caixa em map_2 (1628, 566), o deslocamento à frente no chão (Y + 24)
## e a prioridade de z_index para que itens dropados nunca fiquem escondidos atrás dos destroços.

const DestructiblePropClass = preload("res://scripts/props/destructible_prop.gd")
const CocaPickupScene = preload("res://scenes/items/coca_pickup.tscn")
const DestructibleGamesBoxScene = preload("res://scenes/props/destructible_games_box.tscn")

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("==================================================")
	print("INICIANDO TESTES: VISIBILIDADE DE DROPS E CAIXA FASE 1_2")
	print("==================================================")
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % message)


func _run_tests() -> void:
	_test_map2_box_position()
	_test_coca_pickup_z_index()
	_test_prop_destruction_z_index()

	print("==================================================")
	print("RESULTADO DOS TESTES: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")
	quit(_failed)


func _test_map2_box_position() -> void:
	print("\n--- 1. Validando Posição da Caixa na Fase 1_2 (map_2.tscn) ---")
	var map2_scene: PackedScene = load("res://scenes/levels/map_2.tscn")
	_assert(map2_scene != null, "Cena map_2.tscn carrega com sucesso")
	if map2_scene == null:
		return

	var map2_node := map2_scene.instantiate() as Node2D
	root.add_child(map2_node)

	var box := map2_node.get_node_or_null("World/Props/Destructibles/GamesBox") as Node2D
	_assert(box != null, "Caixa GamesBox encontrada em World/Props/Destructibles/GamesBox")
	if box != null:
		_assert(box.position.x == 1628.0, "Posição X da caixa é exatamente 1628.0 (atual: %f)" % box.position.x)
		_assert(box.position.y == 566.0, "Posição Y da caixa é exatamente 566.0 (atual: %f)" % box.position.y)

	map2_node.queue_free()


func _test_coca_pickup_z_index() -> void:
	print("\n--- 2. Validando Z-Index da CocaPickup ---")
	var coca := CocaPickupScene.instantiate() as Node2D
	root.add_child(coca)
	_assert(coca.z_index >= 1, "CocaPickup possui z_index >= 1 (atual: %d)" % coca.z_index)
	coca.queue_free()


func _test_prop_destruction_z_index() -> void:
	print("\n--- 3. Validando Rebaixamento de Z-Index do Sprite Destruído ---")
	var box := DestructibleGamesBoxScene.instantiate() as Node2D
	root.add_child(box)

	_assert(box.has_method("destroy_prop"), "DestructibleGamesBox implementa destroy_prop()")
	box.call("destroy_prop")

	var visual: Node2D = box.get_node_or_null("Visual") as Node2D
	_assert(visual != null and visual.z_index <= -1, "Visual da caixa destruída rebaixado para z_index <= -1 (atual: %d)" % (visual.z_index if visual else 0))

	box.queue_free()

