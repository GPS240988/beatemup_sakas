extends BaseLevel

## Interior da HAPPEN. O background panorâmico é mantido em escala 1:1;
## somente a mesa retangular recebe redução visual para a escala de gameplay.

const BACKGROUND_PATH: String = "res://assets/backgrounds/maps/fase2/Fase2_4.webp"
const PLAYER_START: Vector2 = Vector2(180.0, 585.0)
const WALKABLE_TOP: float = 440.0
const WALKABLE_BOTTOM: float = 680.0

const PIZZA_BRAWLER_SCENE: PackedScene = preload("res://scenes/actors/enemies/pizza_brawler.tscn")
const BATHROOM_DOOR_POS: Vector2 = Vector2(1935.0, 444.0)

const BATHROOM_WAVE_SPECS: Array[Dictionary] = [
	{
		"name": "PizzaBrawler_Bathroom01",
		"archetype": EnemyAI.Archetype.AGGRESSOR,
		"palette": EnemyAI.PaletteVariant.GREEN,
		"entry_pos": Vector2(1795.0, 505.0),
		"delay": 0.0
	},
	{
		"name": "PizzaBrawler_Bathroom02",
		"archetype": EnemyAI.Archetype.FLANKER,
		"palette": EnemyAI.PaletteVariant.PURPLE,
		"entry_pos": Vector2(1745.0, 565.0),
		"delay": 0.55
	},
	{
		"name": "PizzaBrawler_Bathroom03",
		"archetype": EnemyAI.Archetype.TANK,
		"palette": EnemyAI.PaletteVariant.CYAN,
		"entry_pos": Vector2(1810.0, 620.0),
		"delay": 1.10
	},
]

const SEATED_VICTORY_CAST: Array[Dictionary] = [
	{
		"hero_id": "alessandro",
		"name": "Seated_Alessandro",
		"texture": "res://assets/sprites/stage2/happen_seated/alessandro_seated.png",
		"position": Vector2(342.0, 563.0)
	},
	{
		"hero_id": "guilherme",
		"name": "Seated_Guilherme",
		"texture": "res://assets/sprites/stage2/happen_seated/guilherme_seated.png",
		"position": Vector2(500.0, 528.0)
	},
	{
		"hero_id": "gabriel",
		"name": "Seated_Gabriel",
		"texture": "res://assets/sprites/stage2/happen_seated/gabriel_seated.png",
		"position": Vector2(658.0, 563.0)
	},
	{
		"hero_id": "andre",
		"name": "Seated_Andre",
		"texture": "res://assets/sprites/stage2/happen_seated/andre_seated.png",
		"position": Vector2(970.0, 593.0)
	},
	{
		"hero_id": "juliana",
		"name": "Seated_Juliana",
		"texture": "res://assets/sprites/stage2/happen_seated/juliana_seated.png",
		"position": Vector2(1150.0, 593.0)
	},
]

const PIZZA_PROP_TEXTURE: Texture2D = preload("res://assets/sprites/props/happen/pizza.png")

const HAPPEN_ENEMY_PALETTES: Array[int] = [
	EnemyAI.PaletteVariant.RED,
	EnemyAI.PaletteVariant.GREEN,
	EnemyAI.PaletteVariant.PURPLE,
	EnemyAI.PaletteVariant.ORANGE,
	EnemyAI.PaletteVariant.CYAN,
]

var _bathroom_wave_spawned: bool = false
var _seated_ending_triggered: bool = false


func _enter_tree() -> void:
	_configure_happen_enemy_palettes()


func _ready() -> void:
	_configure_happen_map()
	var director := get_node_or_null("CombatDirector")
	if director != null and director.get("difficulty_profile") == null:
		director.call("apply_difficulty_profile", EncounterDifficultyProfile.create_for_map(4))
	super._ready()
	if hud != null and hud.label_level_name != null:
		hud.label_level_name.text = "FASE 2-3 · HAPPEN — SALÃO PRINCIPAL"

	if combat_director != null:
		combat_director.add_pending_spawns(BATHROOM_WAVE_SPECS.size())
		if not combat_director.enemy_defeated.is_connected(_on_map7_enemy_defeated):
			combat_director.enemy_defeated.connect(_on_map7_enemy_defeated)
		if not combat_director.encounter_cleared.is_connected(_on_map7_encounter_cleared):
			combat_director.encounter_cleared.connect(_on_map7_encounter_cleared)


func _configure_happen_map() -> void:
	var background: Sprite2D = get_node_or_null("Background/Far") as Sprite2D
	if background == null or background.texture == null:
		push_error("Map7: background Fase2_4.webp não encontrado.")
		return

	if background.texture.resource_path != BACKGROUND_PATH:
		push_error("Map7: Background/Far deve utilizar Fase2_4.webp.")
		return

	var map_size: Vector2 = background.texture.get_size()
	var half_view_width: float = get_viewport_rect().size.x * 0.5
	camera_min_x = minf(half_view_width, map_size.x * 0.5)
	camera_max_x = maxf(camera_min_x, map_size.x - half_view_width)
	camera_fixed_y = map_size.y * 0.5

	var player_node: Node2D = get_node_or_null("World/Actors/Player") as Node2D
	if player_node != null:
		player_node.position = PLAYER_START

	var depth_scaler: Node = get_node_or_null("YDepthScaler")
	if depth_scaler != null:
		depth_scaler.set("far_lane_y", WALKABLE_TOP)
		depth_scaler.set("near_lane_y", WALKABLE_BOTTOM)


## Define as variantes antes do _ready() dos atores, preservando todos os efeitos do material.
func _configure_happen_enemy_palettes() -> void:
	var enemies: Node = get_node_or_null("World/Actors/Enemies")
	if enemies == null:
		return

	var palette_pool: Array[int] = HAPPEN_ENEMY_PALETTES.duplicate()
	palette_pool.shuffle()
	var palette_index: int = 0

	for child in enemies.get_children():
		var enemy: EnemyAI = child as EnemyAI
		if enemy == null:
			continue

		var selected_palette: int = palette_pool[palette_index % palette_pool.size()]
		enemy.palette_variant = selected_palette as EnemyAI.PaletteVariant
		palette_index += 1


func _on_map7_enemy_defeated(_enemy: Node) -> void:
	if _bathroom_wave_spawned or combat_director == null:
		return
	if combat_director.alive_enemies.is_empty():
		trigger_bathroom_respawn_wave()


func trigger_bathroom_respawn_wave() -> void:
	if _bathroom_wave_spawned:
		return
	_bathroom_wave_spawned = true

	var enemies_container := get_node_or_null("World/Actors/Enemies")
	if enemies_container == null:
		return

	for spec in BATHROOM_WAVE_SPECS:
		var delay_sec: float = float(spec.get("delay", 0.0))
		if delay_sec <= 0.0:
			_spawn_single_bathroom_enemy(spec, enemies_container)
		else:
			var t := get_tree().create_timer(delay_sec)
			t.timeout.connect(_spawn_single_bathroom_enemy.bind(spec, enemies_container), CONNECT_ONE_SHOT)


func _spawn_single_bathroom_enemy(spec: Dictionary, enemies_container: Node) -> void:
	if not is_instance_valid(enemies_container) or PIZZA_BRAWLER_SCENE == null:
		return

	var brawler := PIZZA_BRAWLER_SCENE.instantiate() as PizzaBrawler
	if brawler == null:
		return

	brawler.name = str(spec.get("name", "PizzaBrawler_Bathroom"))
	brawler.initial_routine = PizzaBrawler.IdleRoutine.NONE
	brawler.start_sitting = false
	brawler.wake_on_proximity = false
	brawler.peaceful_until_attacked = false
	brawler.archetype = int(spec.get("archetype", EnemyAI.Archetype.AGGRESSOR)) as EnemyAI.Archetype
	brawler.palette_variant = int(spec.get("palette", EnemyAI.PaletteVariant.GREEN)) as EnemyAI.PaletteVariant
	brawler.position = BATHROOM_DOOR_POS
	brawler.initial_facing = -1.0

	enemies_container.add_child(brawler)
	if combat_director != null and is_instance_valid(combat_director):
		combat_director.notify_spawn_completed(brawler)

	# Caminha para fora da porta do banheiro antes de reativar colisão sólida com Layer 2
	brawler.set_collision_mask_value(2, false)
	var entry_pos: Vector2 = spec.get("entry_pos", Vector2(1780.0, 540.0))
	var tw := brawler.create_tween()
	tw.tween_property(brawler, "position", entry_pos, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_enable_brawler_world_collision.bind(brawler))


func _enable_brawler_world_collision(brawler: PizzaBrawler) -> void:
	if is_instance_valid(brawler) and brawler.current_state != EnemyAI.State.DEAD:
		brawler.set_collision_mask_value(2, true)


func _on_map7_encounter_cleared() -> void:
	trigger_seated_victory_flash()


func trigger_seated_victory_flash() -> void:
	if _seated_ending_triggered:
		return
	_seated_ending_triggered = true

	var flash_layer := CanvasLayer.new()
	flash_layer.name = "VictoryFlashLayer"
	flash_layer.layer = 95
	add_child(flash_layer)

	var flash_rect := ColorRect.new()
	flash_rect.name = "FlashRect"
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.96, 0.85, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(flash_rect)

	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.88, 0.10)
	tw.tween_property(flash_rect, "color:a", 0.12, 0.10)
	tw.tween_property(flash_rect, "color:a", 0.96, 0.12)
	tw.tween_callback(_spawn_seated_victory_heroes)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.35)
	tw.tween_callback(flash_layer.queue_free)


func _get_active_player_hero_id() -> String:
	var session := get_node_or_null("/root/GameSession")
	if session != null and "selected_character_id" in session:
		var selected: String = str(session.get("selected_character_id")).strip_edges().to_lower()
		if selected != "":
			return selected
	if player != null and is_instance_valid(player):
		var hero_data = player.get("hero_data")
		if hero_data != null and "hero_id" in hero_data:
			var hid: String = str(hero_data.hero_id).strip_edges().to_lower()
			if hid != "":
				return hid
	return ""


func _spawn_seated_victory_heroes() -> void:
	var npcs_container := get_node_or_null("World/Actors/NPCs")
	if npcs_container == null:
		return

	var active_hero_id: String = _get_active_player_hero_id()

	for hero_spec in SEATED_VICTORY_CAST:
		if active_hero_id != "" and str(hero_spec.get("hero_id", "")).to_lower() == active_hero_id:
			continue
		var node_name: String = str(hero_spec["name"])
		if npcs_container.get_node_or_null(node_name) != null:
			continue
		var tex_path: String = str(hero_spec["texture"])
		if not ResourceLoader.exists(tex_path):
			continue
		var tex := load(tex_path) as Texture2D
		if tex == null:
			continue

		var holder := Node2D.new()
		holder.name = node_name
		holder.position = hero_spec["position"]
		holder.y_sort_enabled = true

		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(0.80, 0.80)
		sprite.position = Vector2(0.0, -96.0)
		holder.add_child(sprite)

		npcs_container.add_child(holder)

	_spawn_victory_pizza_stack()


func _spawn_victory_pizza_stack() -> void:
	var npcs_container := get_node_or_null("World/Actors/NPCs")
	if npcs_container == null:
		return
	if npcs_container.get_node_or_null("VictoryPizzaStack") != null:
		return

	# Alessandro sentado fica em Vector2(342.0, 563.0)
	# Posicionada bem à frente dele, no pé / solo (Y=563.0) ligeiramente à frente (Y=567.0, X=342.0)
	var pizza_holder := Node2D.new()
	pizza_holder.name = "VictoryPizzaStack"
	pizza_holder.position = Vector2(342.0, 567.0)
	pizza_holder.y_sort_enabled = true

	var pizza_sprite := Sprite2D.new()
	pizza_sprite.name = "Sprite2D"
	pizza_sprite.texture = PIZZA_PROP_TEXTURE
	pizza_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pizza_sprite.scale = Vector2(0.40, 0.40)
	# Base da pilha pousando exatamente no solo (altura 300 * 0.40 = 120px, offset vertical -60px)
	pizza_sprite.position = Vector2(0.0, -60.0)
	pizza_holder.add_child(pizza_sprite)

	npcs_container.add_child(pizza_holder)


func is_bathroom_wave_spawned() -> bool:
	return _bathroom_wave_spawned


func is_seated_ending_triggered() -> bool:
	return _seated_ending_triggered


func _setup_level_bgm() -> void:
	# A trilha exclusiva do interior da HAPPEN ainda não foi aprovada.
	return
