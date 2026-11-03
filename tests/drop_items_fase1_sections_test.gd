extends SceneTree

const DropScene: PackedScene = preload("res://scenes/items/dropped_magazine_interaction.tscn")
const Map2Scene: PackedScene = preload("res://scenes/levels/map_2.tscn")
const DropControllerScript = preload("res://scripts/props/games_box_drop_controller.gd")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _assert(condition: bool, description: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("[OK] %s" % description)
	else:
		_failed += 1
		printerr("[FALHA] %s" % description)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== TESTE: DROPS FASE 1-1 / FASE 1-2 ===")

	_assert(
		DropControllerScript.is_enabled_for_scene_path("res://scenes/levels/map_1.tscn"),
		"Drop de revistas habilitado na Fase 1-1"
	)
	_assert(
		not DropControllerScript.is_enabled_for_scene_path("res://scenes/levels/map_2.tscn"),
		"Drop de revistas bloqueado na Fase 1-2"
	)
	_assert(
		DropControllerScript.is_enabled_for_scene_path("", "Map1"),
		"Fallback por nome mantém o drop ativo na cena Map1"
	)
	_assert(
		not DropControllerScript.is_enabled_for_scene_path("", "Map2"),
		"Fallback por nome mantém o drop de revistas inativo na Map2"
	)

	var map2 := Map2Scene.instantiate()
	var map2_box := map2.get_node_or_null("World/Props/Destructibles/GamesBox")
	_assert(map2_box != null, "Caixa da Fase 1-2 encontrada na cena map_2")
	if map2_box != null:
		_assert(bool(map2_box.get("drops_item")), "Caixa da Fase 1-2 mantém drops_item habilitado")
		var coca_scene: PackedScene = map2_box.get("drop_item_scene") as PackedScene
		_assert(
			coca_scene != null and coca_scene.resource_path == "res://scenes/items/coca_pickup.tscn",
			"O único drop genérico configurado na Fase 1-2 é CocaPickup"
		)

	var world := Node2D.new()
	root.add_child(world)

	var emmanuele := DropScene.instantiate() as DroppedMagazineStoryPickup
	var playboy := DropScene.instantiate() as DroppedMagazineStoryPickup
	_assert(emmanuele != null and playboy != null, "Duas cenas individuais de revista instanciadas")
	if emmanuele == null or playboy == null:
		quit(1)
		return

	emmanuele.configure_item(
		"res://assets/sprites/Itens/emmanuele.jpg",
		"res://assets/sprites/Itens/emmanuele_gg.jpg",
		"EMMANUELE",
		"Sei todas as falas, faltava esse pra minha coleção."
	)
	playboy.configure_item(
		"res://assets/sprites/Itens/playboy.jpg",
		"res://assets/sprites/Itens/playboy_gg.jpg",
		"PLAYBOY",
		"Japonês safado, larga essas coisas aqui."
	)
	world.add_child(emmanuele)
	world.add_child(playboy)
	playboy.position = Vector2(80.0, 0.0)

	await process_frame

	var emmanuele_sequence: Resource = emmanuele.build_dialogue_sequence()
	var playboy_sequence: Resource = playboy.build_dialogue_sequence()
	var emmanuele_event: Resource = emmanuele_sequence.get("events")[0]
	var playboy_event: Resource = playboy_sequence.get("events")[0]
	_assert(emmanuele_event.get("event_type") == "dialogue", "Emmanuele usa StoryEvent do tipo dialogue")
	_assert(playboy_event.get("event_type") == "dialogue", "Playboy usa StoryEvent do tipo dialogue")
	_assert(emmanuele_event.get("speaker") == "GABRIEL", "Gabriel é o orador da Emmanuele")
	_assert(playboy_event.get("speaker") == "GABRIEL", "Gabriel é o orador da Playboy")
	_assert(
		String(emmanuele_event.get("texts")[0]) == "Sei todas as falas, faltava esse pra minha coleção.",
		"Fala da Emmanuele confere"
	)
	_assert(
		String(playboy_event.get("texts")[0]) == "Japonês safado, larga essas coisas aqui.",
		"Fala da Playboy confere"
	)
	_assert(
		String(emmanuele_event.get("image_path")) == "res://assets/sprites/Itens/emmanuele_gg.jpg",
		"Revelação da Emmanuele usa a arte ampliada correta"
	)
	_assert(
		String(playboy_event.get("image_path")) == "res://assets/sprites/Itens/playboy_gg.jpg",
		"Revelação da Playboy usa a arte ampliada correta"
	)

	var player := CharacterBody2D.new()
	player.name = "DropPriorityTestPlayer"
	player.add_to_group("player")
	world.add_child(player)
	player.global_position = Vector2(40.0, 0.0)
	emmanuele.call("_on_body_entered", player)
	playboy.call("_on_body_entered", player)
	await process_frame

	var emmanuele_button := emmanuele.get_node_or_null("PickUpHint") as Button
	var playboy_button := playboy.get_node_or_null("PickUpHint") as Button
	_assert(
		emmanuele_button != null and playboy_button != null and (emmanuele_button.visible != playboy_button.visible),
		"Apenas um botão PEGAR fica visível quando os dois itens estão ao alcance"
	)
	_assert(
		emmanuele_button != null and emmanuele_button.z_index == 100 and not emmanuele_button.z_as_relative,
		"O botão PEGAR usa camada absoluta à frente do sprite da caixa"
	)

	player.global_position = emmanuele.global_position
	await process_frame
	_assert(
		emmanuele_button != null and emmanuele_button.visible and playboy_button != null and not playboy_button.visible,
		"O botão PEGAR prioriza o item mais próximo"
	)

	print("=== RESULTADO: %d/%d aprovados; %d falhas ===" % [_passed, _total, _failed])
	world.queue_free()
	map2.queue_free()
	quit(0 if _failed == 0 else 1)
