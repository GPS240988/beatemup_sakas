extends SceneTree

const FRAMES_DIR: String = "res://assets/sprites/characters/inimigos/pizza_brawler/frames/"
const FRAMES_PATH: String = "res://scenes/actors/enemies/pizza_brawler_frames.tres"
const SCENE_PATH: String = "res://scenes/actors/enemies/pizza_brawler.tscn"
const MAP7_PATH: String = "res://scenes/levels/map_7.tscn"

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [OK] " + msg)
	else:
		_failed += 1
		push_error("  [FAIL] " + msg)


func _run() -> void:
	print("=== TESTE PIZZA BRAWLER + BANHEIRO + FINAL SENTADO (MAP 7) ===")

	# 1. Quadros individuais recortados e transparência
	var expected_counts := {
		"sit_idle": 6,
		"counter_eat": 5,
		"getup": 6,
		"idle": 4,
		"walk": 6,
		"attack": 6,
		"heavy": 6,
		"punch": 6,
		"kick": 6,
		"guard": 2,
		"hurt": 4,
		"fall": 4,
		"downed": 1,
		"death": 4,
	}

	var idle1 := load(FRAMES_DIR + "idle_01.png") as Texture2D
	_check(idle1 != null, "Frame recortado idle_01.png carrega")
	if idle1 != null:
		_check(idle1.get_size() == Vector2(240, 220), "Canvas individual padronizado 240x220")
		var img := idle1.get_image()
		_check(img != null and img.detect_alpha() != Image.ALPHA_NONE, "Canal alfa transparente real presente nos frames")

	# 2. SpriteFrames e contagem de quadros
	var frames := load(FRAMES_PATH) as SpriteFrames
	_check(frames != null, "SpriteFrames carrega em " + FRAMES_PATH)
	if frames != null:
		for anim_name in expected_counts.keys():
			_check(
				frames.has_animation(anim_name) and frames.get_frame_count(anim_name) == expected_counts[anim_name],
				"Animação '%s' com %d quadros" % [anim_name, expected_counts[anim_name]]
			)

	# 3. Instanciação do Map 7: 6 sentados nas cadeiras + 2 pacíficos no balcão
	var map7_scene := load(MAP7_PATH) as PackedScene
	_check(map7_scene != null, "Map 7 carrega")

	if map7_scene != null:
		var map7 := map7_scene.instantiate()
		root.add_child(map7)
		await process_frame
		await physics_frame

		var enemies_container := map7.get_node_or_null("World/Actors/Enemies")
		var npcs_container := map7.get_node_or_null("World/Actors/NPCs")
		var player := map7.get_node_or_null("World/Actors/Player") as CharacterBody2D
		var director := map7.get_node_or_null("CombatDirector")
		var banter := map7.get_node_or_null("CounterBanter")

		var seated_names := [
			"PizzaBrawler_RectLeft",
			"PizzaBrawler_RectRight",
			"PizzaBrawler_RoundLeft",
			"PizzaBrawler",
		]
		_check(enemies_container != null and enemies_container.get_child_count() == 6, "Map 7 inicia com 6 PizzaBrawlers (4 cadeiras + 2 no balcão)")

		var archetypes_seen := {}
		var palettes_seen := {}
		for ename in seated_names:
			var node := enemies_container.get_node_or_null(ename) if enemies_container != null else null
			_check(node != null, "Inimigo sentado presente: " + ename)
			if node != null:
				archetypes_seen[int(node.archetype)] = true
				palettes_seen[int(node.palette_variant)] = true
				_check(director != null and director.alive_enemies.has(node), ename + " registrado como combatente no CombatDirector")

		_check(archetypes_seen.size() >= 2, "Diversidade de arquétipos nas cadeiras (%d distintos)" % archetypes_seen.size())
		_check(palettes_seen.size() >= 3, "Diversidade de paletas aplicada (%d distintas)" % palettes_seen.size())

		var counter_brawler := enemies_container.get_node_or_null("PizzaBrawler_Counter")
		var counter_side := enemies_container.get_node_or_null("PizzaBrawler_CounterSide")
		_check(counter_brawler != null and counter_side != null, "Dois colegas do balcão presentes")
		if counter_brawler != null and counter_side != null:
			_check(director != null and not director.alive_enemies.has(counter_brawler) and not director.alive_enemies.has(counter_side), "Colegas do balcão não bloqueiam CombatDirector enquanto pacíficos")
			_check(counter_brawler.position.x >= 750.0 and counter_side.position.x <= 1100.0, "Colegas posicionados próximos à bancada de comida")
			_check(absf(counter_side.position.x - counter_brawler.position.x) <= 110.0 and counter_brawler.initial_facing > 0.0 and counter_side.initial_facing < 0.0, "Colegas posicionados frente a frente conversando")

		var rect_left_enemy := enemies_container.get_node_or_null("PizzaBrawler_RectLeft")
		_check(rect_left_enemy != null and rect_left_enemy.wake_trigger_radius <= 85.0, "Primeiro inimigo (RectLeft) com raio de ativação reduzido (não levanta no spawn do player)")

		var pizza_stack_initial := map7.get_node_or_null("World/Actors/NPCs/VictoryPizzaStack")
		_check(pizza_stack_initial == null, "Pilha de pizzas NÃO aparece no início do mapa (só após os heróis sentarem)")

		# 4. Aproximar dos dois do balcão: dispara balão de conversa e NÃO os torna inimigos
		if player != null and counter_brawler != null and counter_side != null:
			player.global_position = counter_side.global_position + Vector2(0.0, 55.0)
			for i in range(6):
				await physics_frame
			_check(counter_brawler.peaceful_until_attacked and counter_brawler.current_state == EnemyAI.State.WAITING, "PizzaBrawler_Counter permanece pacífico em pé ao se aproximar")
			_check(counter_side.is_in_ambient_standby(), "PizzaBrawler_CounterSide permanece pacífico em pé ao se aproximar")
			_check(not counter_brawler.is_in_group("enemies") and not counter_side.is_in_group("enemies"), "Colegas do balcão não entram no grupo enemies ao chegar perto")

			if banter != null:
				var bubble := banter.get_node_or_null("CounterBanterLayer/CounterBanterRoot/SpeechBubble") as Control
				var tail := banter.get_node_or_null("CounterBanterLayer/CounterBanterRoot/SpeechTail") as Polygon2D
				_check(bubble != null and bubble.visible, "Balão de conversa do balcão exibido ao se aproximar")
				_check(tail != null and tail.visible, "Seta/ponteiro do balão aponta para o orador")
				_check(int(banter.repeat_count) == 2 and int(banter._remaining_repeats) == 2, "Diálogo configurado para repetir mais 2x após terminar")

		# 5. Derrotar os 6 sentados -> respawn de 3 inimigos saindo do banheiro
		for ename in seated_names:
			var n := enemies_container.get_node_or_null(ename)
			if n != null:
				n.take_damage(999.0)
				await physics_frame

		for i in range(80):
			await physics_frame

		_check(map7.is_bathroom_wave_spawned(), "Onda de respawn do banheiro disparada após derrotar os 6 das cadeiras")
		var b1 := enemies_container.get_node_or_null("PizzaBrawler_Bathroom01")
		var b2 := enemies_container.get_node_or_null("PizzaBrawler_Bathroom02")
		var b3 := enemies_container.get_node_or_null("PizzaBrawler_Bathroom03")
		_check(b1 != null and b2 != null and b3 != null, "3 inimigos adicionais instanciados a partir do banheiro")

		# 6. Derrotar os 3 inimigos do banheiro -> piscar tela e exibir os 5 personagens sentados
		for b in [b1, b2, b3]:
			if b != null:
				b.take_damage(999.0)
				await physics_frame

		for i in range(45):
			await physics_frame

		_check(map7.is_seated_ending_triggered(), "Final com flash de tela disparado ao concluir todos os inimigos")
		_check(player != null and player.visible and player.is_physics_processing(), "Player ativo permanece visível e jogável após o flash")
		var active_hero_id: String = map7._get_active_player_hero_id()
		var expected_nodes := {
			"juliana": "Seated_Juliana",
			"guilherme": "Seated_Guilherme",
			"gabriel": "Seated_Gabriel",
			"andre": "Seated_Andre",
			"alessandro": "Seated_Alessandro"
		}
		for hid in expected_nodes.keys():
			var hero_node: String = expected_nodes[hid]
			var spawned := npcs_container != null and npcs_container.get_node_or_null(hero_node) != null
			if hid == active_hero_id:
				_check(not spawned, "Player ativo (%s) NÃO aparece sentado na mesa" % hid)
			else:
				_check(spawned, "Personagem sentado exibido na cadeira: " + hero_node)

		var pizza_stack_after := map7.get_node_or_null("World/Actors/NPCs/VictoryPizzaStack")
		_check(pizza_stack_after != null, "Pilha de pizzas aparece bem à frente / no pé do Alessandro quando os Sakas sentam")
		if pizza_stack_after != null:
			var sprite := pizza_stack_after.get_node_or_null("Sprite2D") as Sprite2D
			_check(sprite != null and sprite.texture != null and sprite.texture.resource_path == "res://assets/sprites/props/happen/pizza.png", "Sprite da pilha de pizzas utiliza assets/sprites/props/happen/pizza.png")
			_check(is_equal_approx(pizza_stack_after.position.x, 342.0), "Pilha de pizzas alinhada em X com Alessandro")

		var alessandro_node := npcs_container.get_node_or_null("Seated_Alessandro") as Node2D
		if alessandro_node != null:
			_check(alessandro_node.position.x < 400.0, "Alessandro sentado na cadeira da esquerda (X < 400)")

		map7.queue_free()
		await process_frame

	print("RESULTADO PIZZA BRAWLER + MAP 7: %d passaram, %d falharam" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
