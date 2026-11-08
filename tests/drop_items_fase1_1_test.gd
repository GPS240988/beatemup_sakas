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

	var map_root := Node2D.new()
	map_root.name = "Map1"
	root.add_child(map_root)
	current_scene = map_root

	var box := GamesBoxScene.instantiate()
	_assert_test(box != null, "Cena da caixa foi instanciada")
	if box == null:
		quit(1)
		return

	map_root.add_child(box)
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

			var emmanuele_seq: Resource = emmanuele.call("build_dialogue_sequence")
			var playboy_seq: Resource = playboy.call("build_dialogue_sequence")
			var emmanuele_evt: Resource = emmanuele_seq.get("events")[0] if emmanuele_seq != null else null
			var playboy_evt: Resource = playboy_seq.get("events")[0] if playboy_seq != null else null
			_assert_test(emmanuele_evt != null and String(emmanuele_evt.get("image_path")).ends_with("emmanuele_gg.jpg"), "Painel de inspeção EMMANUELE construído")
			_assert_test(playboy_evt != null and String(playboy_evt.get("image_path")).ends_with("playboy_gg.jpg"), "Painel de inspeção PLAYBOY construído")

			var emmanuele_speaker: String = String(emmanuele_evt.get("speaker")) if emmanuele_evt != null else ""
			var playboy_speaker: String = String(playboy_evt.get("speaker")) if playboy_evt != null else ""
			var emmanuele_text: String = String(emmanuele_evt.get("texts")[0]) if emmanuele_evt != null and emmanuele_evt.get("texts").size() > 0 else ""
			var playboy_text: String = String(playboy_evt.get("texts")[0]) if playboy_evt != null and playboy_evt.get("texts").size() > 0 else ""
			_assert_test(emmanuele_speaker == "GABRIEL", "Emmanuele usa Gabriel como interlocutor")
			_assert_test(playboy_speaker == "GABRIEL", "Playboy usa Gabriel como interlocutor")
			_assert_test(emmanuele_text == "Sei todas as falas, faltava esse pra minha coleção.", "Fala de Gabriel para Emmanuele confere")
			_assert_test(playboy_text == "Japonês safado, larga essas coisas aqui.", "Fala de Gabriel para Playboy confere")

			# Simula o jogador dentro das duas áreas ao mesmo tempo. Só o drop
			# mais próximo pode exibir PEGAR e registrar a interação.
			var test_player := CharacterBody2D.new()
			test_player.name = "DropHintTestPlayer"
			test_player.add_to_group("player")
			drop_parent.add_child(test_player)
			test_player.global_position = (emmanuele.global_position + playboy.global_position) * 0.5
			emmanuele.call("_on_body_entered", test_player)
			playboy.call("_on_body_entered", test_player)
			await process_frame
			var emmanuele_hint := emmanuele.get_node_or_null("PickUpHint") as Button
			var playboy_hint := playboy.get_node_or_null("PickUpHint") as Button
			_assert_test(emmanuele_hint != null and playboy_hint != null and (emmanuele_hint.visible != playboy_hint.visible), "Apenas um botão PEGAR fica visível entre os dois itens")

			test_player.global_position = emmanuele.global_position
			await process_frame
			_assert_test(emmanuele_hint != null and emmanuele_hint.visible and playboy_hint != null and not playboy_hint.visible, "PEGAR prioriza o item mais próximo do jogador")
			test_player.queue_free()

	print("=== RESULTADO: %d/%d aprovados; %d falhas ===" % [passed_tests, total_tests, failed_tests])
	map_root.queue_free()
	quit(0 if failed_tests == 0 else 1)
