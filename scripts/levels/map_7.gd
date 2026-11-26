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
const COCA_PICKUP_SCENE: PackedScene = preload("res://scenes/items/coca_pickup.tscn")
const PIZZA_SLICE_PICKUP_SCRIPT: Script = preload("res://scripts/items/pizza_slice_pickup.gd")
const MAP7_HAPPEN_FINALE_SCRIPT: Script = preload("res://scripts/events/map7_happen_finale.gd")
const GARCONETE_FRAMES: SpriteFrames = preload("res://scenes/actors/npc/garconete_frames.tres")
const GABRIEL_SPRITE_FRAMES: SpriteFrames = preload("res://resources/characters/gabriel_sprite_frames.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/actors/player/player.tscn")
const TAPA_SFX: String = "res://assets/audio/sfx/tapa_alessandro.wav"
const AIIIN_SFX: String = "res://assets/audio/sfx/garconete_aiiin.wav"
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

const GARCONETE_COUNTER_POS: Vector2 = Vector2(1690.0, 466.0)
const GARCONETE_COUNTER_EXIT_POS: Vector2 = Vector2(1520.0, 520.0)
const GARCONETE_ALESSANDRO_POS: Vector2 = Vector2(418.0, 566.0)
const BATHROOM_RETURN_START_POS: Vector2 = Vector2(1890.0, 480.0)
const FINALE_GUILHERME_POS: Vector2 = Vector2(1555.0, 520.0)
const FINALE_GABRIEL_POS: Vector2 = Vector2(1460.0, 532.0)

const HAPPEN_ENEMY_PALETTES: Array[int] = [
	EnemyAI.PaletteVariant.RED,
	EnemyAI.PaletteVariant.GREEN,
	EnemyAI.PaletteVariant.PURPLE,
	EnemyAI.PaletteVariant.ORANGE,
	EnemyAI.PaletteVariant.CYAN,
]

var _bathroom_wave_spawned: bool = false
var _seated_ending_triggered: bool = false
var _garconete: Node2D = null
var _garconete_anim: AnimatedSprite2D = null
var _cutscene_camera_active: bool = false
var _garconete_cutscene_active: bool = false
var _garconete_counter_timer: float = 3.8
var _garconete_counter_reacting: bool = false
var _garconete_counter_react_timer: float = 0.0
var _alessandro_bubble_layer: CanvasLayer = null
var _finale_return_mode: bool = false
var _finale_controller: Node = null


func _enter_tree() -> void:
	_configure_happen_enemy_palettes()


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	_finale_return_mode = session != null and session.has_method("consume_map8_return_to_happen_finale") and bool(session.consume_map8_return_to_happen_finale())

	if _finale_return_mode:
		_clear_salon_combat_for_finale_return()

	PizzaBrawler.reset_global_chair_ambush_state()
	_configure_happen_map()
	var director := get_node_or_null("CombatDirector")
	if director != null and director.get("difficulty_profile") == null:
		director.call("apply_difficulty_profile", EncounterDifficultyProfile.create_for_map(4))
	super._ready()
	if hud != null and hud.label_level_name != null:
		hud.label_level_name.text = "FASE 2-3 · HAPPEN — SALÃO PRINCIPAL"

	if _finale_return_mode:
		_setup_finale_return_sequence()
		return

	if combat_director != null:
		combat_director.add_pending_spawns(BATHROOM_WAVE_SPECS.size())
		if not combat_director.enemy_defeated.is_connected(_on_map7_enemy_defeated):
			combat_director.enemy_defeated.connect(_on_map7_enemy_defeated)

	_spawn_garconete_at_counter()
	_spawn_table_pizza_slice_pickup()


func _spawn_table_pizza_slice_pickup() -> void:
	var props_node := get_node_or_null("World/Props")
	if props_node == null or props_node.get_node_or_null("TablePizzaSlicePickup") != null:
		return
	if COCA_PICKUP_SCENE == null or PIZZA_SLICE_PICKUP_SCRIPT == null:
		return
	var pickup := COCA_PICKUP_SCENE.instantiate() as Node2D
	if pickup == null:
		return
	pickup.set_script(PIZZA_SLICE_PICKUP_SCRIPT)
	pickup.name = "TablePizzaSlicePickup"
	# Em cima do tecido da segunda mesa (RoundTable01 em Vector2(1060, 585))
	pickup.position = Vector2(1060.0, 588.0)
	pickup.z_index = 6
	pickup.set("pickup_range_x", 125.0)
	pickup.set("pickup_depth_tolerance", 68.0)
	pickup.set("sprite_offset_y", -224.0)
	props_node.add_child(pickup)


func _update_camera(delta: float) -> void:
	_update_garconete_counter_idle(delta)
	if _cutscene_camera_active:
		_clamp_camera_to_map_bounds()
		return
	super._update_camera(delta)


func _update_garconete_counter_idle(delta: float) -> void:
	if _finale_return_mode or _garconete_cutscene_active or _garconete_anim == null or not is_instance_valid(_garconete_anim):
		return
	if _garconete_counter_reacting:
		_garconete_counter_react_timer -= delta
		if _garconete_counter_react_timer <= 0.0:
			_garconete_counter_reacting = false
			_garconete_anim.animation = &"idle"
			_garconete_anim.frame = 0
			_garconete_anim.stop()
			_garconete_counter_timer = randf_range(3.5, 6.0)
	else:
		_garconete_counter_timer -= delta
		if _garconete_counter_timer <= 0.0:
			_garconete_counter_reacting = true
			_garconete_counter_react_timer = 1.15
			_garconete_anim.play(&"react")


func _clamp_camera_to_map_bounds() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var map_size: Vector2 = Vector2(2048.0, 720.0)
	var background := get_node_or_null("Background/Far") as Sprite2D
	if background != null and background.texture != null:
		map_size = background.texture.get_size()
	var vp: Vector2 = get_viewport_rect().size
	var zx: float = maxf(absf(camera.zoom.x), 0.001)
	var zy: float = maxf(absf(camera.zoom.y), 0.001)
	var half_w: float = (vp.x * 0.5) / zx
	var half_h: float = (vp.y * 0.5) / zy
	camera.global_position.x = clampf(camera.global_position.x, half_w, maxf(half_w, map_size.x - half_w))
	camera.global_position.y = clampf(camera.global_position.y, half_h, maxf(half_h, map_size.y - half_h))


func _spawn_garconete_at_counter() -> void:
	var npcs_container := get_node_or_null("World/Actors/NPCs")
	if npcs_container == null or npcs_container.get_node_or_null("Garconete") != null:
		return

	_garconete = Node2D.new()
	_garconete.name = "Garconete"
	_garconete.position = GARCONETE_COUNTER_POS
	_garconete.y_sort_enabled = true

	_garconete_anim = AnimatedSprite2D.new()
	_garconete_anim.name = "AnimatedSprite2D"
	_garconete_anim.sprite_frames = GARCONETE_FRAMES
	_garconete_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_garconete_anim.scale = Vector2(-0.80, 0.80)
	_garconete_anim.position = Vector2(0.0, -112.0)
	_garconete_anim.animation = &"idle"
	_garconete_anim.frame = 0
	_garconete_anim.stop()
	_garconete.add_child(_garconete_anim)

	npcs_container.add_child(_garconete)


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
		player_node.position = BATHROOM_RETURN_START_POS if _finale_return_mode else PLAYER_START

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

	if brawler.name == "PizzaBrawler_Bathroom01":
		brawler.enable_chair_ambush = true
		brawler.ambush_prop_mode = "waitress"
		brawler.ambush_speech_text = "SEGURA A GARÇONETE!"
		brawler.qte_duration = 3.0
		brawler.wake_trigger_radius = 230.0

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


func _on_encounter_cleared() -> void:
	if _finale_return_mode:
		return
	if combat_director != null and combat_director.pending_spawns_count > 0:
		return
	# Mantém ExitArea e SigaIndicator desativados: o encerramento do salão é a cena da garçonete
	if exit_area != null:
		exit_area.monitoring = false
	if siga_indicator != null:
		siga_indicator.deactivate()
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

	# Restaura cadeiras ocultadas durante ataques de emboscada para que os heróis não sentem no ar
	var static_props := get_node_or_null("World/Props/StaticProps")
	if static_props != null:
		for chair_name in ["ChairFrontLeft01", "ChairFrontRight01", "ChairFrontLeft02", "ChairFrontRight02"]:
			var chair := static_props.get_node_or_null(chair_name) as CanvasItem
			if chair != null:
				chair.visible = true
				var col := chair.get_node_or_null("Collision/CollisionShape2D") as CollisionShape2D
				if col != null:
					col.set_deferred("disabled", false)

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

	_start_garconete_delivery_cutscene()


func _start_garconete_delivery_cutscene() -> void:
	if _garconete_cutscene_active:
		return
	if _garconete == null or not is_instance_valid(_garconete):
		_spawn_garconete_at_counter()
	if _garconete == null or not is_instance_valid(_garconete):
		return

	_garconete_cutscene_active = true

	if _garconete_anim != null:
		_garconete_anim.scale.x = -0.80
		_garconete_anim.play(&"walk_pizza")

	var tw := create_tween()
	tw.tween_property(_garconete, "position", GARCONETE_COUNTER_EXIT_POS, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_begin_cutscene_camera_zoom_in)
	tw.tween_property(_garconete, "position", GARCONETE_ALESSANDRO_POS, 5.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_garconete_bend_before_slap)
	tw.tween_interval(0.80)
	tw.tween_callback(_on_garconete_arrived_at_alessandro)
	tw.tween_interval(0.55)
	tw.tween_callback(_on_garconete_react_after_slap)
	tw.tween_interval(0.85)
	tw.tween_callback(_spawn_victory_pizza_stack)
	tw.tween_interval(2.3)
	tw.tween_callback(_begin_garconete_return_to_counter)
	tw.tween_property(_garconete, "position", GARCONETE_COUNTER_EXIT_POS, 3.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_garconete, "position", GARCONETE_COUNTER_POS, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_on_garconete_returned_to_counter)


func _on_garconete_bend_before_slap() -> void:
	if _garconete_anim != null and is_instance_valid(_garconete_anim):
		_garconete_anim.scale.x = 0.80
		_garconete_anim.play(&"bend")
	if camera != null and is_instance_valid(camera):
		_cutscene_camera_active = true
		var close_tw := create_tween().set_parallel(true)
		close_tw.tween_property(camera, "zoom", Vector2(1.70, 1.70), 0.70).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		close_tw.tween_property(camera, "global_position", Vector2(400.0, 465.0), 0.70).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _begin_cutscene_camera_zoom_in() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	_cutscene_camera_active = true
	var cam_tw := create_tween().set_parallel(true)
	cam_tw.tween_property(camera, "zoom", Vector2(1.45, 1.45), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	cam_tw.tween_property(camera, "global_position", Vector2(455.0, 468.0), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _on_garconete_arrived_at_alessandro() -> void:
	# Mantém a posição bend_01 por mais um momento durante o tapa antes de virar para reagir
	_show_alessandro_speech_bubble("Da essa porra ai vai")
	# Tapinha do Alessandro na região das nádegas da garçonete (posicionado ao lado do quadril para não cobrir a fala)
	CombatFeedback.play_sound(self, TAPA_SFX, 2.0, 0.04)
	_spawn_persistent_tapa_text(GARCONETE_ALESSANDRO_POS + Vector2(38.0, -78.0))
	var sfx_tw := create_tween()
	sfx_tw.tween_interval(0.12)
	sfx_tw.tween_callback(_play_garconete_aiiin)


func _on_garconete_react_after_slap() -> void:
	if _garconete_anim != null and is_instance_valid(_garconete_anim):
		_garconete_anim.scale.x = -0.80
		_garconete_anim.play(&"react")


func _play_garconete_aiiin() -> void:
	CombatFeedback.play_sound(self, AIIIN_SFX, 2.5, 0.03)
	CombatFeedback.spawn_floating_text(self, GARCONETE_ALESSANDRO_POS + Vector2(10.0, -205.0), "Aiiin!", Color(1.0, 0.65, 0.82, 1.0), 22)


func _spawn_persistent_tapa_text(world_pos: Vector2) -> void:
	var label := Label.new()
	label.name = "FloatingText_TAPA"
	label.text = "*TAPA!*"
	label.top_level = true
	label.z_index = 100
	var settings := LabelSettings.new()
	settings.font = ARCADE_FONT
	settings.font_size = 24
	settings.font_color = Color(1.0, 0.35, 0.35, 1.0)
	settings.outline_size = 4
	settings.outline_color = Color(0.05, 0.05, 0.08, 1.0)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	settings.shadow_offset = Vector2(1.0, 1.0)
	label.label_settings = settings
	label.global_position = world_pos - Vector2(45.0, 14.0)
	add_child(label)

	var tw := label.create_tween()
	tw.tween_property(label, "global_position:y", label.global_position.y - 18.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.65)
	tw.tween_property(label, "modulate:a", 0.0, 0.45)
	tw.tween_callback(label.queue_free)


func _begin_garconete_return_to_counter() -> void:
	_hide_alessandro_speech_bubble()
	if _garconete_anim != null and is_instance_valid(_garconete_anim):
		_garconete_anim.scale.x = 0.80
		_garconete_anim.play(&"walk")

	if camera != null and is_instance_valid(camera):
		var cam_tw := create_tween().set_parallel(true)
		cam_tw.tween_property(camera, "zoom", Vector2.ONE, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		cam_tw.tween_property(camera, "global_position:y", camera_fixed_y, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _on_garconete_returned_to_counter() -> void:
	_cutscene_camera_active = false
	_garconete_cutscene_active = false
	if _garconete_anim != null and is_instance_valid(_garconete_anim):
		_garconete_anim.scale.x = -0.80
		_garconete_anim.animation = &"idle"
		_garconete_anim.frame = 0
		_garconete_anim.stop()
	enable_toilet_exit()


func enable_toilet_exit() -> void:
	if exit_area != null and is_instance_valid(exit_area):
		exit_area.monitoring = true
	if siga_indicator != null and is_instance_valid(siga_indicator):
		siga_indicator.activate()
	_spawn_blinking_toilet_indicator()


func _spawn_blinking_toilet_indicator() -> void:
	if get_node_or_null("ToiletBlinkIndicator") != null:
		return
	# Sinalização diegética integrada ao cenário (sem UI/HUD do Godot):
	# brilho pulsante da luz do toalete na soleira e na porta + seta arcade discreta.
	var indicator := Node2D.new()
	indicator.name = "ToiletBlinkIndicator"
	indicator.position = BATHROOM_DOOR_POS
	indicator.z_index = 4

	var door_glow := Polygon2D.new()
	door_glow.name = "DoorLightSpill"
	door_glow.color = Color(0.32, 0.82, 1.0, 0.24)
	door_glow.polygon = PackedVector2Array([-38, -142, 38, -142, 38, 4, -38, 4])
	indicator.add_child(door_glow)

	var mat_glow := Polygon2D.new()
	mat_glow.name = "ThresholdHighlight"
	mat_glow.color = Color(1.0, 0.88, 0.30, 0.42)
	mat_glow.polygon = PackedVector2Array([-44, 0, 44, 0, 52, 22, -52, 22])
	indicator.add_child(mat_glow)

	var arrow := Polygon2D.new()
	arrow.name = "DiegeticArrow"
	arrow.position = Vector2(0.0, -162.0)
	arrow.color = Color(1.0, 0.88, 0.28, 0.95)
	arrow.polygon = PackedVector2Array([-12, -10, 12, -10, 12, 0, 22, 0, 0, 18, -22, 0, -12, 0])
	indicator.add_child(arrow)

	add_child(indicator)
	var tw := indicator.create_tween().set_loops()
	tw.tween_property(indicator, "modulate:a", 0.22, 0.36).set_trans(Tween.TRANS_SINE)
	tw.tween_property(indicator, "modulate:a", 1.0, 0.36).set_trans(Tween.TRANS_SINE)
	var arrow_tw := arrow.create_tween().set_loops()
	arrow_tw.tween_property(arrow, "position:y", -152.0, 0.36).set_trans(Tween.TRANS_SINE)
	arrow_tw.tween_property(arrow, "position:y", -166.0, 0.36).set_trans(Tween.TRANS_SINE)


func _show_alessandro_speech_bubble(text: String) -> void:
	_hide_alessandro_speech_bubble()
	_alessandro_bubble_layer = CanvasLayer.new()
	_alessandro_bubble_layer.name = "AlessandroSpeechLayer"
	_alessandro_bubble_layer.layer = 26
	add_child(_alessandro_bubble_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alessandro_bubble_layer.add_child(root)

	var bubble := PanelContainer.new()
	bubble.name = "SpeechBubble"
	bubble.custom_minimum_size = Vector2(380.0, 0.0)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.030, 0.050, 0.96)
	style.border_color = Color(0.94, 0.75, 0.39, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16.0
	style.content_margin_top = 10.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	bubble.add_theme_stylebox_override("panel", style)
	root.add_child(bubble)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	bubble.add_child(vbox)

	var speaker := Label.new()
	speaker.text = "ALESSANDRO"
	speaker.add_theme_font_override("font", ARCADE_FONT)
	speaker.add_theme_font_size_override("font_size", 19)
	speaker.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28, 1.0))
	vbox.add_child(speaker)

	var body := Label.new()
	body.text = text
	body.add_theme_font_override("font", ARCADE_FONT)
	body.add_theme_font_size_override("font_size", 26)
	body.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90, 1.0))
	vbox.add_child(body)

	bubble.reset_size()
	var bsize := bubble.get_combined_minimum_size()
	bsize.x = maxf(bsize.x, 380.0)
	bubble.size = bsize

	var anchor := Vector2(342.0, 563.0)
	var alessandro_node := get_node_or_null("World/Actors/NPCs/Seated_Alessandro") as Node2D
	if alessandro_node != null:
		anchor = alessandro_node.get_global_transform_with_canvas().origin
	var vp := get_viewport().get_visible_rect().size
	var max_bubble_x: float = vp.x - bsize.x - 14.0
	if _garconete != null and is_instance_valid(_garconete):
		var waitress_screen_x: float = _garconete.get_global_transform_with_canvas().origin.x
		max_bubble_x = minf(max_bubble_x, maxf(14.0, waitress_screen_x - bsize.x - 28.0))
	bubble.position = Vector2(
		clampf(anchor.x - bsize.x * 0.72, 14.0, maxf(14.0, max_bubble_x)),
		clampf(anchor.y - 235.0 - bsize.y, 18.0, maxf(18.0, vp.y - bsize.y - 24.0))
	)

	var tail := Polygon2D.new()
	tail.name = "SpeechTail"
	tail.color = Color(0.94, 0.75, 0.39, 1.0)
	tail.polygon = PackedVector2Array([-9.0, 0.0, 9.0, 0.0, 0.0, 13.0])
	tail.position = Vector2(clampf(anchor.x, bubble.position.x + 24.0, bubble.position.x + bsize.x - 24.0), bubble.position.y + bsize.y - 1.0)
	root.add_child(tail)


func _hide_alessandro_speech_bubble() -> void:
	if _alessandro_bubble_layer != null and is_instance_valid(_alessandro_bubble_layer):
		_alessandro_bubble_layer.queue_free()
	_alessandro_bubble_layer = null


func is_garconete_cutscene_active() -> bool:
	return _garconete_cutscene_active


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


func is_finale_return_mode() -> bool:
	return _finale_return_mode


func get_finale_controller() -> Node:
	return _finale_controller


func _clear_salon_combat_for_finale_return() -> void:
	var enemies_container := get_node_or_null("World/Actors/Enemies")
	if enemies_container != null:
		for child in enemies_container.get_children():
			enemies_container.remove_child(child)
			child.queue_free()

	var banter := get_node_or_null("CounterBanter")
	if banter != null:
		banter.queue_free()

	var blink_indicator := get_node_or_null("ToiletBlinkIndicator")
	if blink_indicator != null:
		blink_indicator.queue_free()


func _setup_finale_return_sequence() -> void:
	if exit_area != null and is_instance_valid(exit_area):
		exit_area.monitoring = false
	if siga_indicator != null and is_instance_valid(siga_indicator):
		siga_indicator.deactivate()
	if combat_director != null:
		combat_director.is_cleared = true
		combat_director.encounter_state = "COMPLETED"

	_spawn_garconete_at_counter()

	# Preserva continuidade visual do salão sem duplicar nenhum herói nem iniciar cena anterior
	var npcs_container := get_node_or_null("World/Actors/NPCs")
	var active_hero_id: String = _get_active_player_hero_id()
	if npcs_container != null:
		for hero_spec in SEATED_VICTORY_CAST:
			var hid: String = str(hero_spec.get("hero_id", "")).to_lower()
			if hid == "gabriel" or hid == "guilherme" or (active_hero_id != "" and hid == active_hero_id):
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

	if player != null and is_instance_valid(player):
		player.position = BATHROOM_RETURN_START_POS
		player.velocity = Vector2.ZERO
		player.facing_direction = -1.0
		if player.visual_root != null:
			player.visual_root.scale.x = -absf(player.visual_root.scale.y)
		if player.has_method("set_qte_locked"):
			player.call("set_qte_locked", true)
		player.set_physics_process(false)

	var gabriel_actor: Node2D = null
	var guilherme_actor: Node2D = null
	var player_walk_target: Vector2 = FINALE_GUILHERME_POS
	if active_hero_id == "gabriel":
		gabriel_actor = player
		player_walk_target = FINALE_GABRIEL_POS
		guilherme_actor = _spawn_finale_companion("guilherme", "FinaleCompanion_Guilherme", FINALE_GUILHERME_POS, _get_guilherme_sprite_frames())
	elif active_hero_id == "guilherme":
		guilherme_actor = player
		player_walk_target = FINALE_GUILHERME_POS
		gabriel_actor = _spawn_finale_companion("gabriel", "FinaleCompanion_Gabriel", FINALE_GABRIEL_POS, GABRIEL_SPRITE_FRAMES)
	else:
		player_walk_target = FINALE_GABRIEL_POS + Vector2(-55.0, 10.0)
		guilherme_actor = _spawn_finale_companion("guilherme", "FinaleCompanion_Guilherme", FINALE_GUILHERME_POS, _get_guilherme_sprite_frames())
		gabriel_actor = _spawn_finale_companion("gabriel", "FinaleCompanion_Gabriel", FINALE_GABRIEL_POS, GABRIEL_SPRITE_FRAMES)

	var juliana_node := get_node_or_null("World/Actors/NPCs/Seated_Juliana") as Node2D

	_finale_controller = MAP7_HAPPEN_FINALE_SCRIPT.new()
	_finale_controller.name = "Map7HappenFinale"
	add_child(_finale_controller)
	_finale_controller.setup(self, player, gabriel_actor, guilherme_actor, _garconete, juliana_node, camera)
	_finale_controller.start_finale(player_walk_target)


func _spawn_finale_companion(hero_id: String, node_name: String, spawn_pos: Vector2, frames: SpriteFrames) -> Node2D:
	var npcs_container := get_node_or_null("World/Actors/NPCs")
	if npcs_container == null:
		return null
	var existing := npcs_container.get_node_or_null(node_name) as Node2D
	if existing != null:
		return existing

	var companion := Node2D.new()
	companion.name = node_name
	companion.position = spawn_pos
	companion.y_sort_enabled = true
	companion.set_meta("hero_id", hero_id)

	var visual := Node2D.new()
	visual.name = "Visual"
	companion.add_child(visual)

	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.color = Color(0.08, 0.08, 0.12, 0.5)
	shadow.polygon = PackedVector2Array([-42, 0, -30, -10, 0, -14, 30, -10, 42, 0, 30, 10, 0, 14, -30, 10])
	visual.add_child(shadow)

	var anim := AnimatedSprite2D.new()
	anim.name = "AnimatedSprite2D"
	anim.position = Vector2(0.0, -118.0)
	anim.scale = Vector2(0.80, 0.80)
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim.sprite_frames = frames
	if frames != null and frames.has_animation(&"idle"):
		anim.play(&"idle")
	visual.add_child(anim)

	var muzzle := Marker2D.new()
	muzzle.name = "MuzzleMarker"
	muzzle.position = Vector2(74.0, -172.0)
	visual.add_child(muzzle)

	npcs_container.add_child(companion)
	return companion


func _get_guilherme_sprite_frames() -> SpriteFrames:
	if player != null and is_instance_valid(player) and player.anim_sprite != null and player.hero_data != null and str(player.hero_data.hero_id).to_lower() == "guilherme":
		return player.anim_sprite.sprite_frames
	if PLAYER_SCENE != null:
		var temp_player := PLAYER_SCENE.instantiate()
		if temp_player != null:
			var anim := temp_player.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
			var frames: SpriteFrames = anim.sprite_frames if anim != null else null
			temp_player.queue_free()
			return frames
	return null


func _setup_level_bgm() -> void:
	# A trilha exclusiva do interior da HAPPEN ainda não foi aprovada.
	return
