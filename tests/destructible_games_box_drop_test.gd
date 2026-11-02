extends SceneTree

const GamesBoxScene: PackedScene = preload("res://scenes/props/destructible_games_box.tscn")

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
	print("TESTE: DROP DUPLO DA CAIXA DE JOGOS - FASE 1-1")
	print("==================================================")

	var box := GamesBoxScene.instantiate()
	assert_test(box != null, "Cena da caixa foi instanciada")
	root.add_child(box)
	await process_frame

	assert_test(box.drops_item, "Caixa está configurada para dropar itens")
	assert_test(box.drop_item_scene != null, "Cena de interação da carta Magic foi reutilizada")
	assert_test(box.drop_item_texture_paths.size() == 2, "Dois sprites pequenos configurados para o chão")
	assert_test(box.drop_item_inspect_texture_paths.size() == 2, "Duas imagens grandes configuradas para inspeção")
	assert_test(box.drop_item_spacing >= 80.0, "Drops possuem espaçamento horizontal")

	box.destroy_prop()
	await process_frame

	var drops: Array[Node2D] = []
	for child: Node in root.get_children():
		if child is Node2D and child.is_in_group("dropped_items"):
			drops.append(child as Node2D)

	assert_test(drops.size() == 2, "Destruir a caixa cria exatamente dois itens no chão")
	if drops.size() == 2:
		var horizontal_distance: float = absf(drops[0].global_position.x - drops[1].global_position.x)
		assert_test(
			is_equal_approx(horizontal_distance, box.drop_item_spacing),
			"Itens ficam lado a lado com o espaçamento configurado"
		)
		var first_sprite := drops[0].get_node_or_null("CardSprite") as Sprite2D
		var second_sprite := drops[1].get_node_or_null("CardSprite") as Sprite2D
		assert_test(first_sprite != null and first_sprite.texture != null, "Primeiro item possui sprite visível")
		assert_test(second_sprite != null and second_sprite.texture != null, "Segundo item possui sprite visível")

	for drop: Node2D in drops:
		drop.queue_free()
	box.queue_free()
	await process_frame

	print("==================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")
	quit(0 if failed_tests == 0 else 1)
