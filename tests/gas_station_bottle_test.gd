extends SceneTree

## Testes focados do posto: frentista na calçada, caixas interativas e ciclo pegar/arremessar.
const FrentistaScene: PackedScene = preload("res://scenes/actors/frentista_npc.tscn")
const CrateScene: PackedScene = preload("res://scenes/items/gas_bottle_crate.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/actors/projectiles/gas_bottle_projectile.tscn")
const Map5Scene: PackedScene = preload("res://scenes/levels/map_5.tscn")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _assert(condition: bool, message: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Gas station / bottle interaction tests ===")

	var frentista: Node = FrentistaScene.instantiate()
	_assert(frentista is CharacterBody2D, "Frentista usa CharacterBody2D")
	_assert(frentista.is_in_group("actors") and frentista.is_in_group("npcs"), "Frentista pertence aos grupos de ator civil")
	_assert(not frentista.is_in_group("enemies"), "Frentista nunca entra no grupo enemies")
	var attendant_sprite := frentista.get_node_or_null("Visual/Sprite2D") as Sprite2D
	_assert(attendant_sprite != null and attendant_sprite.texture != null, "Frentista usa sprite PNG individual")
	_assert(attendant_sprite != null and attendant_sprite.texture.resource_path.ends_with("gas_station_attendant.png"), "Frentista não depende do atlas compartilhado")
	frentista.free()

	var world := Node2D.new()
	world.name = "World"
	var actors := Node2D.new()
	actors.name = "Actors"
	world.add_child(actors)
	root.add_child(world)

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.add_to_group("player")
	player.add_to_group("actors")
	var visual := Node2D.new()
	visual.name = "Visual"
	player.add_child(visual)
	var dummy_frames := SpriteFrames.new()
	dummy_frames.add_animation(&"idle")
	var dummy_image := Image.create(220, 300, false, Image.FORMAT_RGBA8)
	dummy_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	dummy_image.fill_rect(Rect2i(128, 148, 76, 94), Color(0.9, 0.6, 0.3, 1.0))
	var dummy_texture := ImageTexture.create_from_image(dummy_image)
	dummy_frames.add_frame(&"idle", dummy_texture)
	var dummy_animated_sprite := AnimatedSprite2D.new()
	dummy_animated_sprite.name = "AnimatedSprite2D"
	dummy_animated_sprite.position = Vector2(0.0, -118.0)
	dummy_animated_sprite.scale = Vector2(0.8, 0.8)
	dummy_animated_sprite.sprite_frames = dummy_frames
	visual.add_child(dummy_animated_sprite)
	actors.add_child(player)
	dummy_animated_sprite.play(&"idle")

	var crate := CrateScene.instantiate()
	actors.add_child(crate)
	crate.global_position = player.global_position
	await process_frame

	_assert(crate.is_in_group("gas_bottle_crates"), "Engradado integra o grupo de props interativos")
	_assert(crate.get_node_or_null("PickUpHint") != null, "Engradado apresenta prompt contextual")
	var crate_sprite := crate.get_node_or_null("Visual/Sprite2D") as Sprite2D
	_assert(crate_sprite != null and crate_sprite.texture.resource_path.ends_with("soda_crate_red.png"), "Engradado usa PNG vermelho independente")
	_assert(crate_sprite != null and is_equal_approx(crate_sprite.scale.x, 0.22), "Engradados usam escala reduzida e proporcional de 0.22")
	var default_aim: Vector2 = Vector2(crate.call("_get_throw_aim_direction", 1.0))
	_assert(default_aim.is_equal_approx(Vector2.RIGHT), "Sem direcional, a garrafa segue o facing padrão")
	Input.action_press("move_down")
	var lower_lane_aim: Vector2 = Vector2(crate.call("_get_throw_aim_direction", 1.0))
	_assert(lower_lane_aim.x > 0.0 and lower_lane_aim.y > 0.0, "S direciona o arremesso para a pista inferior")
	Input.action_release("move_down")
	Input.action_press("move_left")
	var reverse_aim: Vector2 = Vector2(crate.call("_get_throw_aim_direction", 1.0))
	_assert(reverse_aim.x < 0.0 and is_zero_approx(reverse_aim.y), "A permite arremessar para trás")
	Input.action_release("move_left")
	var initial_count: int = int(crate.call("get_bottles_remaining"))
	_assert(bool(crate.call("interact", player)), "Primeiro J recolhe a garrafa diretamente do engradado")
	_assert(bool(crate.call("is_holding_bottle")), "Garrafa aparece no estado segurado")
	_assert(player.is_in_group("holding_gas_bottle"), "Jogador recebe estado holding_gas_bottle")
	var held_component := visual.get_node_or_null("HeldItemComponent") as HeldItemComponent
	_assert(held_component != null, "Pickup cria o componente reutilizável HeldItemComponent")
	var held_bottle: Sprite2D = held_component.get_item_sprite() if held_component != null else null
	_assert(held_bottle != null, "Componente exibe a garrafa na âncora de mão do personagem")
	_assert(held_bottle != null and is_zero_approx(held_bottle.rotation), "Garrafa permanece em pé enquanto é segurada")
	_assert(held_bottle != null and held_bottle.z_index == 0 and held_bottle.z_as_relative, "Garrafa herda a profundidade Y-Sort do Player, sem camada Z arbitrária")
	var grip_overlay := held_component.get_hand_overlay_sprite() if held_component != null else null
	_assert(grip_overlay != null and grip_overlay.visible, "Mão/antebraço do frame atual sobrepõe o gargalo da garrafa")
	_assert(grip_overlay != null and grip_overlay.z_index == 0 and grip_overlay.z_as_relative, "Recorte de mão não rompe o Y-Sort do ator")
	_assert(held_bottle != null and held_bottle.texture.resource_path.ends_with("soda_glass_bottle.png"), "Garrafa usa PNG separado com alpha")
	_assert(int(crate.call("get_bottles_remaining")) == initial_count - 1, "Estoque do engradado diminui uma unidade")
	var throw_hint := player.get_node_or_null("PickUpHint") as Button
	_assert(throw_hint != null and throw_hint.text == "Arremessar", "Touch muda prompt para Arremessar")

	Input.action_press("move_up")
	_assert(bool(crate.call("interact", player)), "Segundo J arremessa a garrafa")
	Input.action_release("move_up")
	_assert(not bool(crate.call("is_holding_bottle")), "Engradado libera o estado de garrafa segurada")
	_assert(not player.is_in_group("holding_gas_bottle"), "Jogador sai do estado holding_gas_bottle")
	var projectiles: Array[Node] = get_nodes_in_group("player_projectiles")
	_assert(not projectiles.is_empty(), "Arremesso instancia projétil no contêiner de atores")
	for projectile: Node in projectiles:
		_assert(projectile is Area2D, "Garrafa arremessada usa Area2D para colisões")
		_assert(int(projectile.get("collision_mask")) == 12, "Projétil detecta hurtboxes dos props e inimigos, sem Layer 2 do cenário")
		_assert(int(projectile.get("z_index")) == 5 and not bool(projectile.get("z_as_relative")), "Garrafa renderiza acima dos props comuns e abaixo do Foreground Z 10")
		var aim_direction: Vector2 = Vector2(projectile.get("_aim_direction"))
		_assert(aim_direction.x > 0.0 and aim_direction.y < 0.0, "W + J direciona a garrafa para frente e para a pista superior")
		var initial_projectile_y: float = projectile.global_position.y
		var projectile_sprite := projectile.get_node_or_null("BottleSprite") as Sprite2D
		var baseline_sprite_y: float = projectile_sprite.position.y if projectile_sprite != null else 0.0
		projectile.call("_physics_process", 0.05)
		_assert(projectile.global_position.y < initial_projectile_y, "Arremesso direcional desloca o projétil para a pista escolhida")
		_assert(projectile_sprite != null and projectile_sprite.texture.resource_path.ends_with("soda_glass_bottle.png"), "Projétil usa o mesmo asset individual da garrafa")
		_assert(projectile_sprite != null and absf(projectile_sprite.rotation_degrees) > 20.0, "Projétil inclina conforme a tangente da trajetória")
		_assert(float(projectile.get("flight_arc_height")) >= 90.0, "Arremesso usa arco alto e legível")
		var flight_duration: float = float(projectile.get("_flight_duration"))
		var apex_time: float = float(projectile.get("_flight_apex_time"))
		projectile.call("_update_flight_pose", apex_time)
		_assert(projectile_sprite != null and is_equal_approx(projectile_sprite.position.y, baseline_sprite_y - float(projectile.get("flight_arc_height"))), "Projétil atinge a altura configurada no ápice da parábola")
		projectile.call("_update_flight_pose", flight_duration)
		_assert(projectile_sprite != null and is_equal_approx(projectile_sprite.position.y, baseline_sprite_y + float(projectile.get("landing_drop"))), "Projétil desce até perto do chão no fim do arco")
		projectile.queue_free()

	var map: Node = Map5Scene.instantiate()
	root.add_child(map)
	await process_frame
	_assert(map.get_node_or_null("World/Actors/NPCs/Frentista") != null, "Map 5 instancia o frentista")
	_assert(map.get_node_or_null("World/Props/StaticProps/EngradadoVermelho") != null, "Map 5 contém engradado vermelho")
	_assert(map.get_node_or_null("World/Props/StaticProps/EngradadoVerde") != null, "Map 5 contém engradado verde")
	var green_crate_sprite := map.get_node_or_null("World/Props/StaticProps/EngradadoVerde/Visual/Sprite2D") as Sprite2D
	_assert(green_crate_sprite != null and green_crate_sprite.texture.resource_path.ends_with("soda_crate_green.png"), "Engradado verde usa PNG individual")
	_assert(map.get_node_or_null("World/Props/DroppedItems") == null, "Map 5 não deixa garrafas soltas no chão")

	print("\nResultado: %d/%d aprovados; %d falhas." % [_passed, _total, _failed])
	world.queue_free()
	map.queue_free()
	quit(0 if _failed == 0 else 1)
