extends SceneTree

const GamesBoxScene: PackedScene = preload("res://scenes/props/destructible_games_box.tscn")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _assert_test(condition: bool, description: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("[OK] %s" % description)
	else:
		failed_tests += 1
		printerr("[FALHA] %s" % description)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("\n=== TESTE: DROP DOS ITENS DA CAIXA — FASE 1-1 ===")

	var box := GamesBoxScene.instantiate()
	_assert_test(box != null, "Cena da caixa foi instanciada")
	if box == null:
		quit(1)
		return

	root.add_child(box)
	await process_frame

	var controller := box.get_node_or_null("GamesBoxDropController")
	_assert_test(controller != null, "GamesBoxDropController presente na cena")
	_assert_test(box.has_signal("prop_destroyed"), "A caixa expõe o sinal canônico prop_destroyed")

	# Aciona a mesma transição usada pela destruição real.
	box.take_damage(999.0)
	await process_frame
	await process_frame

	_assert_test(box.is_prop_destroyed(), "A caixa chegou ao estado DESTROYED")

	var drops: Array[Node] = []
	var drop_parent := box.get_parent()
	if drop_parent != null:
		for child in drop_parent.get_children():
			if child.is_in_group("dropped_items"):
				drops.append(child)

	_assert_test(drops.size() == 2, "Exatamente dois itens foram instanciados")

	if drops.size() == 2:
		var emmanuele := drop_parent.get_node_or_null("Drop_EMMANUELE") as Area2D
		var playboy := drop_parent.get_node_or_null("Drop_PLAYBOY") as Area2D
		_assert_test(emmanuele != null, "Drop EMMANUELE encontrado no mundo")
		_assert_test(playboy != null, "Drop PLAYBOY encontrado no mundo")

		if emmanuele != null and playboy != null:
			_assert_test(is_equal_approx(emmanuele.global_position.y, playboy.global_position.y), "Os dois itens ficam na mesma linha de chão")
			_assert_test(emmanuele.global_position.x < playboy.global_position.x, "Os itens ficam lado a lado, em ordem horizontal")

			var emmanuele_sprite := emmanuele.get_node_or_null("CardSprite") as Sprite2D
			var playboy_sprite := playboy.get_node_or_null("CardSprite") as Sprite2D
			_assert_test(emmanuele_sprite != null and emmanuele_sprite.texture != null and emmanuele_sprite.texture.resource_path.ends_with("emmanuele.jpg"), "Thumbnail EMMANUELE carregado")
			_assert_test(playboy_sprite != null and playboy_sprite.texture != null and playboy_sprite.texture.resource_path.ends_with("playboy.jpg"), "Thumbnail PLAYBOY carregado")

			var emmanuele_dialogue := emmanuele.get_node_or_null("CardInspectionOverlay/OverlayRoot")
			var playboy_dialogue := playboy.get_node_or_null("CardInspectionOverlay/OverlayRoot")
			_assert_test(emmanuele_dialogue != null and emmanuele_dialogue.get_node_or_null("EnlargedCard") != null, "Painel de inspeção EMMANUELE construído")
			_assert_test(playboy_dialogue != null and playboy_dialogue.get_node_or_null("EnlargedCard") != null, "Painel de inspeção PLAYBOY construído")

	print("=== RESULTADO: %d/%d aprovados; %d falhas ===" % [passed_tests, total_tests, failed_tests])
	box.queue_free()
	quit(0 if failed_tests == 0 else 1)
