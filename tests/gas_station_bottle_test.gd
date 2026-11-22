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
	_assert(int(crate.call("get_bottles_remaining")) == initial_count, "Estoque do engradado permanece ilimitado")
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
		_assert(int(projectile.get("collision_mask")) == 14, "Projétil detecta hurtboxes dos props e inimigos e colisões sólidas do mapa")
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
		_assert(float(projectile.get("flight_arc_height")) <= 48.0, "Arremesso usa parábola realista e veloz de combate")
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
	var frentista_map := map.get_node_or_null("World/Actors/NPCs/Frentista")
	_assert(frentista_map != null, "Map 5 instancia o frentista")
	_assert(frentista_map != null and frentista_map.has_method("interact"), "Frentista possui contrato de interação (interact)")
	_assert(frentista_map != null and frentista_map.get_node_or_null("InteractionArea") != null, "Frentista possui área de detecção de proximidade")
	_assert(frentista_map != null and frentista_map.get_node_or_null("Visual/ExclamationIcon") != null, "Frentista exibe ícone de exclamação sobre a cabeça")
	var excl_icon := frentista_map.get_node_or_null("Visual/ExclamationIcon") as Label if frentista_map != null else null
	_assert(excl_icon != null and excl_icon.text == "!", "Ícone de exclamação exibe o caractere '!'")
	_assert(excl_icon != null and excl_icon.position.y < -240.0, "Ícone de exclamação posicionado acima da cabeça (Y < -240)")

	# Validação do diálogo e da pausa da cena
	if frentista_map != null and frentista_map.has_method("interact"):
		_assert(bool(frentista_map.call("interact", player)), "Interação com Frentista abre o diálogo com sucesso")
		var dialogue_node: Node = root.get_node_or_null("FrentistaDialogue")
		_assert(dialogue_node != null, "Nó FrentistaDialogue adicionado à raiz da cena")
		_assert(root.get_tree().paused, "Cena fica pausada durante o diálogo do frentista")
		var dialogues: Array = dialogue_node.get("_dialogues") if dialogue_node != null else []
		_assert(dialogues.size() == 2, "Diálogo configurado com exatamente 2 caixas sequenciais")
		if dialogues.size() == 2:
			_assert(dialogues[0].get("text") == "Aqui é o posto Ipiranga, não sei informar onde fica a HAPPEN.", "Texto da 1ª caixa de diálogo correto")
			_assert(dialogues[1].get("text") == "Mas cuidado! Sábado a noite tem muitos baderneiros nessa rua.", "Texto da 2ª caixa de diálogo correto")
		if dialogue_node != null and dialogue_node.has_method("_close_dialogue"):
			dialogue_node.call("_close_dialogue")
			await process_frame
			_assert(not root.get_tree().paused, "Cena é despausada ao fechar o diálogo do frentista")

	_assert(map.get_node_or_null("World/Props/StaticProps/EngradadoVermelho") != null, "Map 5 contém engradado vermelho")
	_assert(map.get_node_or_null("World/Props/StaticProps/EngradadoVerde") != null, "Map 5 contém engradado verde")
	var green_crate_sprite := map.get_node_or_null("World/Props/StaticProps/EngradadoVerde/Visual/Sprite2D") as Sprite2D
	_assert(green_crate_sprite != null and green_crate_sprite.texture.resource_path.ends_with("soda_crate_green.png"), "Engradado verde usa PNG individual")
	_assert(map.get_node_or_null("World/Props/DroppedItems") == null, "Map 5 não deixa garrafas soltas no chão")

	# Validação do trigger e cutscene do vídeo da padaria (André)
	var bakery_trigger := map.get_node_or_null("BakeryVideoTrigger") as Area2D
	_assert(bakery_trigger != null, "Map 5 instancia BakeryVideoTrigger")
	_assert(bakery_trigger != null and (bakery_trigger.collision_mask & 1) != 0, "BakeryVideoTrigger detecta a camada do player (layer 1)")
	_assert(bakery_trigger != null and bakery_trigger.monitoring, "BakeryVideoTrigger possui monitoramento ativo")
	var bakery_col := bakery_trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D if bakery_trigger != null else null
	_assert(bakery_col != null and bakery_col.shape is RectangleShape2D, "BakeryVideoTrigger possui CollisionShape2D retangular")
	if bakery_col != null and bakery_col.shape is RectangleShape2D:
		var rect_shape := bakery_col.shape as RectangleShape2D
		_assert(rect_shape.size.y >= 200.0, "Trigger da padaria cobre a distância vertical da calçada/rua")
		_assert(absf(bakery_trigger.position.x - 1380.0) < 50.0, "Trigger da padaria alinhado em frente à porta (X ~1380)")

	# Validação da reprodução do vídeo 1x única
	_assert(not bool(map.get("_andre_bakery_video_played")), "Flag _andre_bakery_video_played começa como false")
	map.call("_on_bakery_trigger_body_entered", player)
	_assert(bool(map.get("_andre_bakery_video_played")), "Disparo do trigger marca _andre_bakery_video_played como true")
	var cutscene := map.get_node_or_null("Map5BakeryCutscene")
	_assert(cutscene != null, "Cutscene instanciada na cena Map 5")
	_assert(root.get_tree().paused, "Cena fica pausada durante a cutscene do vídeo de André")
	if cutscene != null:
		var video_player := cutscene.get_node_or_null("CutsceneRoot/VideoAspect/VideoStreamPlayer") as VideoStreamPlayer
		_assert(video_player != null, "Cutscene possui VideoStreamPlayer configurado")
		_assert(video_player != null and not video_player.loop, "VideoStreamPlayer não fica em loop infinito")
		if cutscene.has_method("_close_cutscene"):
			cutscene.call("_close_cutscene")
			await process_frame
			_assert(not root.get_tree().paused, "Cena despausa após encerramento da cutscene")

	# Testar 2ª passagem: não deve tocar novamente (acionado apenas 1x)
	var prev_cutscene_count: int = 0
	for child in map.get_children():
		if child.name == "Map5BakeryCutscene":
			prev_cutscene_count += 1
	map.call("_on_bakery_trigger_body_entered", player)
	var new_cutscene_count: int = 0
	for child in map.get_children():
		if child.name == "Map5BakeryCutscene":
			new_cutscene_count += 1
	_assert(new_cutscene_count == prev_cutscene_count, "Segunda passagem pelo trigger não reexecuta o vídeo (acionado apenas 1x)")

	print("\nResultado: %d/%d aprovados; %d falhas." % [_passed, _total, _failed])
	world.queue_free()
	map.queue_free()
	quit(0 if _failed == 0 else 1)
