extends BaseLevel

## Interior do Toalete da HAPPEN (Map 8 / Fase 2-4).
## Implementa a entrada, a conversa ambiental dos três gorduchos e o combate
## contra o líder (escala 2x nítida) e dois gorduchos padrão, encerrando de forma
## silenciosa após a derrota do último inimigo.

const Map8ToiletDialogueClass = preload("res://scripts/events/map8_toilet_dialogue.gd")
const StandardDialogueBoxClass = preload("res://scripts/ui/standard_dialogue_box.gd")
const COCA_PICKUP_SCENE: PackedScene = preload("res://scenes/items/coca_pickup.tscn")
const PIZZA_SLICE_PICKUP_SCRIPT: Script = preload("res://scripts/items/pizza_slice_pickup.gd")

const BACKGROUND_PATH: String = "res://assets/backgrounds/maps/fase2/Fase2_5.webp"
const FART_GAS_SFX: String = "res://assets/audio/sfx/gorducho_pum.wav"
const PEE_SFX: String = "res://assets/audio/sfx/xixi_comanda.wav"
const POISON_CLOUD_SHEET_PATH: String = "res://assets/sprites/Efeitos/pixelfx/poison-cloud.png"
const WATER_JET_SHEET_PATH: String = "res://assets/sprites/Efeitos/pixelfx/water-jet.png"
const COMANDA_SPRITE_PATH: String = "res://assets/sprites/stage2/happen_props/comanda.png"
const GUILHERME_PORTRAIT_PATH: String = "res://assets/ui/hud/portraits/portrait_guilherme.png"
const PLAYER_START: Vector2 = Vector2(185.0, 595.0)
const WALKABLE_TOP: float = 505.0
const WALKABLE_BOTTOM: float = 700.0
const WALKABLE_LEFT: float = 45.0
const WALKABLE_RIGHT: float = 2092.0
const LEADER_VISUAL_SCALE: float = 2.0
const LEADER_MAX_HP: float = 240.0
const GAS_CLOUD_DURATION: float = 2.8
const GAS_CLOUD_RADIUS: float = 460.0
const GAS_PUSH_SPEED: float = 320.0
const GAS_TRIGGER_RANGE: float = 780.0
const URINAL_TRIGGER_POS: Vector2 = Vector2(1945.0, 540.0)
const URINAL_STAND_POS: Vector2 = Vector2(1888.0, 536.0)
const BATHROOM_RETURN_EXIT_POS: Vector2 = Vector2(120.0, 595.0)
const MAP7_SCENE_PATH: String = "res://scenes/levels/map_7.tscn"
const AUTO_RETURN_WALK_SPEED: float = 340.0
const POISON_DAMAGE_PER_SECOND: float = 3.0
const PLAYER_SCENE: PackedScene = preload("res://scenes/actors/player/player.tscn")

var _dialogue_controller: Node = null
var _lider: PizzaBrawler = null
var _gorducho2: PizzaBrawler = null
var _gorducho3: PizzaBrawler = null
var _combat_started: bool = false
var _leader_engaged: bool = false
var _combat_ended: bool = false
var _intro_camera_active: bool = false
var _gas_attack_cooldown: float = 2.6
var _gas_windup_active: bool = false
var _gas_cloud_active: bool = false
var _gas_cloud_timer: float = 0.0
var _gas_cloud_node: Node2D = null
var _gas_cough_shown: bool = false
var _poison_cloud_frames: SpriteFrames = null
var _water_jet_frames: SpriteFrames = null
var _urinal_trigger: Area2D = null
var _urinal_hint: Node2D = null
var _urinal_sequence_started: bool = false
var _urinal_sequence_finished: bool = false
var _urinal_dialogue_layer: CanvasLayer = null
var _auto_return_started: bool = false
var _auto_return_lane_aligned: bool = false
var _return_transition_triggered: bool = false
var _poison_dot_active: bool = false
var _poison_tick_timer: float = 0.0
var _urinal_guilherme_actor: Node2D = null
var _urinal_temp_guilherme: Node2D = null


func _ready() -> void:
	_configure_toilet_map()
	_configure_toilet_enemies()

	var director := get_node_or_null("CombatDirector")
	if director != null and director.get("difficulty_profile") == null:
		director.call("apply_difficulty_profile", EncounterDifficultyProfile.create_for_map(4))

	super._ready()

	if hud != null and hud.label_level_name != null:
		hud.label_level_name.text = "FASE 2-4 · HAPPEN — TOALETE"

	if exit_area != null:
		exit_area.monitoring = false
	if siga_indicator != null:
		siga_indicator.deactivate()

	# Mantém o Líder fora do primeiro embate: entram primeiro os 2 gorduchos normais.
	if combat_director != null and _lider != null and is_instance_valid(_lider):
		combat_director.call_deferred("unregister_enemy", _lider)
		combat_director.add_pending_spawns(1)
		_lider.remove_from_group("enemies")
		if _lider.health_component != null:
			_lider.health_component.max_health = LEADER_MAX_HP
			_lider.health_component.current_health = LEADER_MAX_HP
		var lider_hurtbox := _lider.get_node_or_null("Hurtbox") as Area2D
		if lider_hurtbox != null:
			lider_hurtbox.set_deferred("monitorable", false)
		if not combat_director.enemy_defeated.is_connected(_on_map8_enemy_defeated):
			combat_director.enemy_defeated.connect(_on_map8_enemy_defeated)

	_spawn_greasy_comanda_prop()
	_spawn_trash_pizza_slice_pickup()
	_start_intro_sequence()


func _spawn_trash_pizza_slice_pickup() -> void:
	var props_node := get_node_or_null("World/Props")
	if props_node == null or props_node.get_node_or_null("TrashPizzaSlicePickup") != null:
		return
	if COCA_PICKUP_SCENE == null or PIZZA_SLICE_PICKUP_SCRIPT == null:
		return
	var pickup := COCA_PICKUP_SCENE.instantiate() as Node2D
	if pickup == null:
		return
	pickup.set_script(PIZZA_SLICE_PICKUP_SCRIPT)
	pickup.name = "TrashPizzaSlicePickup"
	# Em cima do lixo junto dos papéis (ToiletTrashCollider em Vector2(598, 515))
	pickup.position = Vector2(598.0, 520.0)
	pickup.z_index = 6
	pickup.set("pickup_range_x", 105.0)
	pickup.set("pickup_depth_tolerance", 60.0)
	pickup.set("sprite_offset_y", -250.0)
	props_node.add_child(pickup)


func _configure_toilet_map() -> void:
	var background: Sprite2D = get_node_or_null("Background/Far") as Sprite2D
	if background == null or background.texture == null:
		push_error("Map8: background Fase2_5.webp não encontrado.")
		return
	if background.texture.resource_path != BACKGROUND_PATH:
		push_error("Map8: Background/Far deve utilizar Fase2_5.webp.")
		return

	var map_size: Vector2 = background.texture.get_size()
	var half_view_width: float = get_viewport_rect().size.x * 0.5
	camera_min_x = minf(half_view_width, map_size.x * 0.5)
	camera_max_x = maxf(camera_min_x, map_size.x - half_view_width)
	camera_fixed_y = map_size.y * 0.5

	var player_node: Node2D = get_node_or_null("World/Actors/Player") as Node2D
	if player_node != null:
		player_node.position = PLAYER_START
		if "facing_direction" in player_node:
			player_node.set("facing_direction", 1.0)

	var depth_scaler: Node = get_node_or_null("YDepthScaler")
	if depth_scaler != null:
		depth_scaler.set("far_lane_y", WALKABLE_TOP)
		depth_scaler.set("near_lane_y", WALKABLE_BOTTOM)


func _configure_toilet_enemies() -> void:
	_lider = get_node_or_null("World/Actors/Enemies/GorduchoLider") as PizzaBrawler
	_gorducho2 = get_node_or_null("World/Actors/Enemies/Gorducho2") as PizzaBrawler
	_gorducho3 = get_node_or_null("World/Actors/Enemies/Gorducho3") as PizzaBrawler

	for enemy: PizzaBrawler in [_lider, _gorducho2, _gorducho3]:
		if enemy == null:
			continue
		enemy.start_sitting = false
		enemy.initial_routine = PizzaBrawler.IdleRoutine.NONE
		enemy.wake_on_proximity = false
		enemy.enable_chair_ambush = false

	if _lider != null:
		_lider.display_name = "LÍDER"
		_apply_leader_scale(_lider, LEADER_VISUAL_SCALE)
	if _gorducho2 != null:
		_gorducho2.display_name = "GORDUCHO"
	if _gorducho3 != null:
		_gorducho3.display_name = "GORDUCHO"

	_face_enemies_left()


func _face_enemies_left() -> void:
	for enemy: PizzaBrawler in [_lider, _gorducho2, _gorducho3]:
		if enemy == null or not is_instance_valid(enemy):
			continue
		enemy.facing_direction = -1.0
		if enemy.visual_root != null:
			enemy.visual_root.scale.x = -absf(enemy.visual_root.scale.y)


func _apply_leader_scale(leader: PizzaBrawler, factor: float) -> void:
	# Escala inteira (2.0x) somente na instância do líder em Visual, mantendo pés em (0, 0)
	# e ajustando colisores, hurtbox e hitbox sem alterar vida ou dano base.
	var visual := leader.get_node_or_null("Visual") as Node2D
	if visual != null:
		var facing_sign: float = -1.0 if visual.scale.x < 0.0 else 1.0
		visual.scale = Vector2(factor * facing_sign, factor)
		var scaler := get_node_or_null("YDepthScaler")
		if scaler != null and "_base_visual_scales" in scaler:
			var base_scales: Dictionary = scaler.get("_base_visual_scales")
			base_scales[leader.get_instance_id()] = Vector2(factor, factor)

	var feet_col := leader.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if feet_col != null:
		feet_col.position *= factor
		if feet_col.shape is CapsuleShape2D:
			var dup_cap := (feet_col.shape as CapsuleShape2D).duplicate() as CapsuleShape2D
			dup_cap.radius *= factor
			dup_cap.height *= factor
			feet_col.shape = dup_cap

	var hurtbox := leader.get_node_or_null("Hurtbox") as Area2D
	if hurtbox != null:
		hurtbox.position *= factor
		var hurt_col := hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if hurt_col != null and hurt_col.shape is RectangleShape2D:
			var dup_rect := (hurt_col.shape as RectangleShape2D).duplicate() as RectangleShape2D
			dup_rect.size *= factor
			hurt_col.shape = dup_rect

	var melee := leader.get_node_or_null("MeleeAttack") as Node2D
	if melee != null:
		melee.set("horizontal_range", 128.0)
		melee.set("depth_tolerance", 24.0)
		var hitbox := melee.get_node_or_null("HitboxArea") as Area2D
		if hitbox != null:
			hitbox.position = Vector2(92.0, -95.0 * factor)
			var hit_col := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if hit_col != null and hit_col.shape is RectangleShape2D:
				var dup_hit := (hit_col.shape as RectangleShape2D).duplicate() as RectangleShape2D
				dup_hit.size = Vector2(124.0, 110.0)
				hit_col.shape = dup_hit

	leader.attack_horizontal_distance = 105.0
	leader.attack_windup_seconds = 0.36

	var impact_zones := leader.get_node_or_null("ImpactZones")
	if impact_zones != null:
		for marker in impact_zones.get_children():
			if marker is Node2D:
				(marker as Node2D).position *= factor

	var hp_bar := leader.get_node_or_null("FloatingHealthBar") as Control
	if hp_bar != null:
		hp_bar.offset_top *= factor
		hp_bar.offset_bottom *= factor


func _spawn_greasy_comanda_prop() -> void:
	var static_props := get_node_or_null("World/Props/StaticProps")
	if static_props == null or static_props.get_node_or_null("GreasyComandaProp") != null:
		return

	# Elemento narrativo puramente visual no chão: comanda engordurada e ilegível dos três.
	var prop := Node2D.new()
	prop.name = "GreasyComandaProp"
	prop.position = Vector2(1855.0, 600.0)

	var paper := Polygon2D.new()
	paper.name = "Paper"
	paper.color = Color(0.86, 0.78, 0.58, 1.0)
	paper.polygon = PackedVector2Array([-12.0, -7.0, 12.0, -5.0, 10.0, 7.0, -10.0, 6.0])
	prop.add_child(paper)

	var grease_stain := Polygon2D.new()
	grease_stain.name = "GreaseStain"
	grease_stain.color = Color(0.76, 0.56, 0.18, 0.75)
	grease_stain.polygon = PackedVector2Array([-6.0, -4.0, 4.0, -3.0, 6.0, 3.0, -4.0, 4.0])
	prop.add_child(grease_stain)

	var sauce_stain := Polygon2D.new()
	sauce_stain.name = "SauceStain"
	sauce_stain.color = Color(0.78, 0.16, 0.10, 0.80)
	sauce_stain.polygon = PackedVector2Array([1.0, -2.0, 8.0, 0.0, 5.0, 4.0, -1.0, 2.0])
	prop.add_child(sauce_stain)

	static_props.add_child(prop)


func _start_intro_sequence() -> void:
	_combat_started = false
	_combat_ended = false

	if player != null and is_instance_valid(player):
		player.velocity = Vector2.ZERO
		if player.anim_sprite != null and player.anim_sprite.sprite_frames != null and player.anim_sprite.sprite_frames.has_animation("idle"):
			player.anim_sprite.play("idle")
		player.set_physics_process(false)

	for enemy: PizzaBrawler in [_lider, _gorducho2, _gorducho3]:
		if enemy != null and is_instance_valid(enemy):
			enemy.velocity = Vector2.ZERO
			enemy.set_physics_process(false)
			if enemy.anim_sprite != null and enemy.anim_sprite.sprite_frames != null and enemy.anim_sprite.sprite_frames.has_animation("idle"):
				enemy.anim_sprite.play("idle")

	_dialogue_controller = Map8ToiletDialogueClass.new()
	_dialogue_controller.name = "Map8ToiletDialogue"
	add_child(_dialogue_controller)
	_dialogue_controller.setup(_lider, _gorducho2, _gorducho3, player)
	_dialogue_controller.intro_dialogue_finished.connect(_on_intro_dialogue_finished, CONNECT_ONE_SHOT)
	_dialogue_controller.start_intro_dialogue()

	if camera != null and is_instance_valid(camera):
		_intro_camera_active = true
		var cam_tw := create_tween()
		cam_tw.tween_property(camera, "global_position:x", camera_max_x, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_camera(delta: float) -> void:
	if _intro_camera_active:
		return
	super._update_camera(delta)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_leader_gas_mechanic(delta)
	_update_leader_poison_dot(delta)
	_update_auto_return_walk(delta)


func _on_intro_dialogue_finished() -> void:
	if _combat_started:
		return
	_combat_started = true
	_intro_camera_active = false

	if player != null and is_instance_valid(player):
		player.set_physics_process(true)

	# Primeiro entram na luta os 2 gorduchos normais; o Líder aguarda atrás.
	for enemy in [_gorducho2, _gorducho3]:
		if enemy != null and is_instance_valid(enemy):
			enemy.set_physics_process(true)
			enemy.current_state = EnemyAI.State.FLANKING

	if _dialogue_controller != null and is_instance_valid(_dialogue_controller):
		_dialogue_controller.start_combat_banter()


func _on_map8_enemy_defeated(_enemy: Node) -> void:
	if _leader_engaged or combat_director == null or not is_instance_valid(combat_director):
		return
	if combat_director.alive_enemies.is_empty():
		engage_leader()


func engage_leader() -> void:
	if _leader_engaged or _combat_ended:
		return
	_leader_engaged = true
	if _lider == null or not is_instance_valid(_lider):
		return

	if not _lider.is_in_group("enemies"):
		_lider.add_to_group("enemies")
	var lider_hurtbox := _lider.get_node_or_null("Hurtbox") as Area2D
	if lider_hurtbox != null:
		lider_hurtbox.set_deferred("monitorable", true)
	if combat_director != null and is_instance_valid(combat_director):
		combat_director.notify_spawn_completed(_lider)

	if _lider.health_component != null:
		_lider.health_component.max_health = LEADER_MAX_HP
		_lider.health_component.current_health = LEADER_MAX_HP
		_lider.health_component.health_changed.emit(LEADER_MAX_HP, LEADER_MAX_HP)
	_lider.attack_windup_seconds = 0.36
	_lider.set_physics_process(true)
	_lider.current_state = EnemyAI.State.FLANKING
	if player != null and is_instance_valid(player) and _lider.has_method("_update_facing"):
		_lider.call("_update_facing", player.global_position.x)
	CombatFeedback.spawn_floating_text(self, _lider.global_position + Vector2(0.0, -340.0), "AGORA É COMIGO!", Color(1.0, 0.84, 0.28, 1.0), 22)


func is_leader_engaged() -> bool:
	return _leader_engaged


func _update_leader_gas_mechanic(delta: float) -> void:
	if not _combat_started or not _leader_engaged or _combat_ended:
		return

	if _gas_windup_active:
		return

	if _gas_cloud_active:
		_gas_cloud_timer -= delta
		_apply_gas_repulsion(delta)
		if _gas_cloud_timer <= 0.0:
			_clear_gas_cloud()
		return

	if _lider == null or not is_instance_valid(_lider) or _lider.current_state == EnemyAI.State.DEAD:
		return
	if _lider.health_component != null and _lider.health_component.is_dead:
		return
	if player == null or not is_instance_valid(player):
		return

	_gas_attack_cooldown -= delta
	if _gas_attack_cooldown <= 0.0:
		if _lider.global_position.distance_to(player.global_position) <= GAS_TRIGGER_RANGE and not _lider.current_state in [EnemyAI.State.HURT, EnemyAI.State.FALL, EnemyAI.State.DOWNED]:
			trigger_leader_gas_attack()
		else:
			_gas_attack_cooldown = 0.8


func trigger_leader_gas_attack(immediate: bool = false) -> void:
	if _lider == null or not is_instance_valid(_lider) or _gas_cloud_active or _gas_windup_active or _combat_ended:
		return

	# Vira de costas para o jogador antes de soltar o pum
	var away_dir: float = -1.0
	if player != null and is_instance_valid(player):
		away_dir = -1.0 if player.global_position.x >= _lider.global_position.x else 1.0
	_lider.facing_direction = away_dir
	if _lider.visual_root != null:
		_lider.visual_root.scale.x = absf(_lider.visual_root.scale.y) * away_dir

	if immediate:
		_release_leader_gas_cloud()
		return

	_gas_windup_active = true
	_lider.velocity = Vector2.ZERO
	var tw := create_tween()
	tw.tween_interval(0.22)
	tw.tween_callback(_release_leader_gas_cloud)


func _release_leader_gas_cloud() -> void:
	_gas_windup_active = false
	if _lider == null or not is_instance_valid(_lider) or _combat_ended or _lider.current_state == EnemyAI.State.DEAD:
		return
	_gas_cloud_active = true
	_gas_cloud_timer = GAS_CLOUD_DURATION
	_gas_attack_cooldown = randf_range(3.8, 5.2)
	_gas_cough_shown = false
	if not _poison_dot_active:
		_poison_dot_active = true
		_poison_tick_timer = 1.0

	CombatFeedback.play_sound(self, FART_GAS_SFX, 3.0, 0.05)
	CombatFeedback.spawn_floating_text(self, _lider.global_position + Vector2(0.0, -340.0), "*PRRFFFT!*", Color(0.68, 0.96, 0.28, 1.0), 24)
	# Nuvem sai das costas do líder em direção ao player
	var back_offset_x: float = -48.0 * _lider.facing_direction
	_spawn_gas_cloud(_lider.global_position + Vector2(back_offset_x, -95.0))


func _get_poison_cloud_frames() -> SpriteFrames:
	if _poison_cloud_frames != null:
		return _poison_cloud_frames
	var sheet: Texture2D = null
	if ResourceLoader.exists(POISON_CLOUD_SHEET_PATH):
		sheet = load(POISON_CLOUD_SHEET_PATH) as Texture2D
	if sheet == null:
		var abs_path: String = ProjectSettings.globalize_path(POISON_CLOUD_SHEET_PATH)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				sheet = ImageTexture.create_from_image(img)
	if sheet == null:
		return null

	var frames := SpriteFrames.new()
	frames.add_animation(&"poison_cloud")
	frames.set_animation_loop(&"poison_cloud", true)
	frames.set_animation_speed(&"poison_cloud", 30.0)
	var frame_w: int = 256
	var frame_h: int = 100
	var cols: int = 7
	for idx: int in range(120):
		var col: int = idx % cols
		var row: int = idx / cols
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
		atlas.filter_clip = true
		frames.add_frame(&"poison_cloud", atlas)
	_poison_cloud_frames = frames
	return _poison_cloud_frames


func _spawn_gas_cloud(world_pos: Vector2) -> void:
	_clear_gas_cloud_visual_only()
	var actors_world := get_node_or_null("World/Props")
	if actors_world == null:
		actors_world = self

	var cloud := Node2D.new()
	cloud.name = "LeaderGasCloud"
	cloud.position = world_pos
	cloud.z_index = 4

	var frames := _get_poison_cloud_frames()
	if frames != null:
		var anim := AnimatedSprite2D.new()
		anim.name = "PixelFXPoisonCloud"
		anim.sprite_frames = frames
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		anim.scale = Vector2(2.0, 2.0)
		anim.position = Vector2(0.0, 18.0)
		anim.play(&"poison_cloud")
		cloud.add_child(anim)

	actors_world.add_child(cloud)
	_gas_cloud_node = cloud


func _apply_gas_repulsion(delta: float) -> void:
	if player == null or not is_instance_valid(player) or _gas_cloud_node == null or not is_instance_valid(_gas_cloud_node):
		return
	var diff: Vector2 = player.global_position - _gas_cloud_node.global_position
	var dist: float = diff.length()
	if dist > GAS_CLOUD_RADIUS:
		return

	var push_dir: Vector2 = diff.normalized() if dist > 1.0 else Vector2(-1.0, 0.0)
	player.global_position += push_dir * GAS_PUSH_SPEED * delta
	player.global_position.x = clampf(player.global_position.x, WALKABLE_LEFT, WALKABLE_RIGHT)
	player.global_position.y = clampf(player.global_position.y, WALKABLE_TOP, WALKABLE_BOTTOM)

	if not _gas_cough_shown:
		_gas_cough_shown = true
		CombatFeedback.spawn_floating_text(self, player.global_position + Vector2(0.0, -195.0), "*COF! COF!*", Color(0.75, 0.98, 0.42, 1.0), 18)


func _clear_gas_cloud() -> void:
	_gas_cloud_active = false
	_gas_cloud_timer = 0.0
	_clear_gas_cloud_visual_only()


func _clear_gas_cloud_visual_only() -> void:
	if _gas_cloud_node != null and is_instance_valid(_gas_cloud_node):
		_gas_cloud_node.queue_free()
	_gas_cloud_node = null


func _update_leader_poison_dot(delta: float) -> void:
	if not _poison_dot_active:
		return
	if _combat_ended or _lider == null or not is_instance_valid(_lider) or _lider.current_state == EnemyAI.State.DEAD:
		_clear_leader_poison_dot()
		return
	if player == null or not is_instance_valid(player) or player.health_component == null or player.health_component.is_dead:
		return

	_poison_tick_timer -= delta
	if _poison_tick_timer <= 0.0:
		_poison_tick_timer = 1.0
		player.health_component.take_damage(POISON_DAMAGE_PER_SECOND)
		if player.visual_root != null:
			var tint_tw := create_tween()
			tint_tw.tween_property(player.visual_root, "modulate", Color(0.68, 1.0, 0.52, 1.0), 0.12)
			tint_tw.tween_property(player.visual_root, "modulate", Color.WHITE, 0.25)
		CombatFeedback.spawn_floating_text(self, player.global_position + Vector2(0.0, -185.0), "-%d" % int(POISON_DAMAGE_PER_SECOND), Color(0.58, 0.96, 0.34, 1.0), 18)


func _clear_leader_poison_dot() -> void:
	_poison_dot_active = false
	_poison_tick_timer = 0.0
	if player != null and is_instance_valid(player) and player.visual_root != null:
		player.visual_root.modulate = Color.WHITE


func is_poison_dot_active() -> bool:
	return _poison_dot_active


func is_gas_cloud_active() -> bool:
	return _gas_cloud_active


func _on_encounter_cleared() -> void:
	_combat_ended = true
	_gas_windup_active = false
	_clear_gas_cloud()
	_clear_leader_poison_dot()
	if _dialogue_controller != null and is_instance_valid(_dialogue_controller):
		_dialogue_controller.stop_combat_banter()
	if exit_area != null and is_instance_valid(exit_area):
		exit_area.monitoring = false
	if siga_indicator != null and is_instance_valid(siga_indicator):
		siga_indicator.deactivate()
	_enable_urinal_cutscene_trigger()


func _enable_urinal_cutscene_trigger() -> void:
	if _urinal_sequence_started or _urinal_trigger != null:
		return
	_urinal_trigger = Area2D.new()
	_urinal_trigger.name = "UrinalCutsceneTrigger"
	_urinal_trigger.position = URINAL_TRIGGER_POS
	_urinal_trigger.collision_layer = 0
	_urinal_trigger.collision_mask = 1
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(140.0, 120.0)
	col.shape = rect
	_urinal_trigger.add_child(col)
	_urinal_trigger.body_entered.connect(_on_urinal_trigger_body_entered)
	add_child(_urinal_trigger)

	_urinal_hint = Node2D.new()
	_urinal_hint.name = "UrinalHint"
	_urinal_hint.position = Vector2(1945.0, 392.0)
	_urinal_hint.z_index = 20
	var hint_lbl := Label.new()
	hint_lbl.text = "MICTÓRIO ↓"
	hint_lbl.position = Vector2(-72.0, 0.0)
	hint_lbl.custom_minimum_size = Vector2(144.0, 30.0)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font = preload("res://assets/fonts/arcade_bold.ttf")
	ls.font_size = 18
	ls.font_color = Color(1.0, 0.88, 0.24, 1.0)
	ls.outline_size = 4
	ls.outline_color = Color(0.04, 0.04, 0.06, 1.0)
	hint_lbl.label_settings = ls
	_urinal_hint.add_child(hint_lbl)
	add_child(_urinal_hint)
	var tw := _urinal_hint.create_tween().set_loops()
	tw.tween_property(_urinal_hint, "modulate:a", 0.25, 0.4)
	tw.tween_property(_urinal_hint, "modulate:a", 1.0, 0.4)


func _on_urinal_trigger_body_entered(body: Node) -> void:
	if _urinal_sequence_started or body == null or not body.is_in_group("player"):
		return
	start_urinal_sequence()


func start_urinal_sequence() -> void:
	if _urinal_sequence_started:
		return
	_urinal_sequence_started = true
	if _urinal_trigger != null and is_instance_valid(_urinal_trigger):
		_urinal_trigger.set_deferred("monitoring", false)
	if _urinal_hint != null and is_instance_valid(_urinal_hint):
		_urinal_hint.queue_free()
		_urinal_hint = null

	var is_guilherme_player: bool = _is_active_player_guilherme()
	if player != null and is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.global_position = URINAL_STAND_POS if is_guilherme_player else (URINAL_STAND_POS + Vector2(-95.0, 28.0))
		player.facing_direction = 1.0
		if player.visual_root != null:
			player.visual_root.scale.x = absf(player.visual_root.scale.y)
		if player.anim_sprite != null and player.anim_sprite.sprite_frames != null and player.anim_sprite.sprite_frames.has_animation("idle"):
			player.anim_sprite.play("idle")
		player.set_physics_process(false)

	if is_guilherme_player:
		_urinal_guilherme_actor = player
	else:
		_urinal_guilherme_actor = _spawn_urinal_guilherme_actor()

	_show_urinal_footer_dialogue()


func _is_active_player_guilherme() -> bool:
	var session := get_node_or_null("/root/GameSession")
	if session != null and "selected_character_id" in session:
		var sel: String = str(session.get("selected_character_id")).strip_edges().to_lower()
		if sel != "":
			return sel == "guilherme"
	if player != null and is_instance_valid(player) and player.hero_data != null:
		return str(player.hero_data.hero_id).strip_edges().to_lower() == "guilherme"
	return true


func _spawn_urinal_guilherme_actor() -> Node2D:
	var npcs := get_node_or_null("World/Actors/NPCs")
	var parent_node: Node = npcs if npcs != null else get_node_or_null("World/Actors")
	if parent_node == null:
		parent_node = self

	var actor := Node2D.new()
	actor.name = "UrinalCutscene_Guilherme"
	actor.position = URINAL_STAND_POS
	actor.y_sort_enabled = true

	var visual := Node2D.new()
	visual.name = "Visual"
	actor.add_child(visual)

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
	if PLAYER_SCENE != null:
		var temp_p := PLAYER_SCENE.instantiate()
		if temp_p != null:
			var p_anim := temp_p.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
			if p_anim != null and p_anim.sprite_frames != null:
				anim.sprite_frames = p_anim.sprite_frames
			temp_p.queue_free()
	if anim.sprite_frames != null and anim.sprite_frames.has_animation(&"idle"):
		anim.play(&"idle")
	visual.add_child(anim)

	parent_node.add_child(actor)
	_urinal_temp_guilherme = actor
	return actor


func _show_urinal_footer_dialogue() -> void:
	_urinal_dialogue_layer = CanvasLayer.new()
	_urinal_dialogue_layer.name = "UrinalFooterDialogue"
	_urinal_dialogue_layer.layer = 125
	_urinal_dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_urinal_dialogue_layer)

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_urinal_dialogue_layer.add_child(root_ctrl)

	var is_mobile: bool = _is_mobile_runtime()
	var ui: Dictionary = StandardDialogueBoxClass.build_dialogue_ui(root_ctrl, is_mobile)
	var portrait := ui["portrait"] as TextureRect
	var speaker_lbl := ui["speaker_label"] as Label
	var body_lbl := ui["dialogue_label"] as Label
	var cont_lbl := ui["continue_label"] as Label

	if ResourceLoader.exists(GUILHERME_PORTRAIT_PATH):
		portrait.texture = load(GUILHERME_PORTRAIT_PATH) as Texture2D
	speaker_lbl.text = "GUILHERME"
	body_lbl.text = "Realmente nossa comanda estava muito limpa, vou mijar um pouco e entregar para o Fernando."
	body_lbl.visible_characters = -1
	cont_lbl.visible = true

	root_ctrl.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			confirm_urinal_dialogue()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			confirm_urinal_dialogue()
	)


func _unhandled_input(event: InputEvent) -> void:
	if _urinal_dialogue_layer == null or not is_instance_valid(_urinal_dialogue_layer):
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J]:
			get_viewport().set_input_as_handled()
			confirm_urinal_dialogue()
	elif event is InputEventJoypadButton:
		var je := event as InputEventJoypadButton
		if je.pressed and je.button_index == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			confirm_urinal_dialogue()


func confirm_urinal_dialogue() -> void:
	if _urinal_dialogue_layer != null and is_instance_valid(_urinal_dialogue_layer):
		_urinal_dialogue_layer.queue_free()
	_urinal_dialogue_layer = null
	_play_urinal_pee_animation()


func _get_water_jet_frames() -> SpriteFrames:
	if _water_jet_frames != null:
		return _water_jet_frames
	var sheet: Texture2D = null
	if ResourceLoader.exists(WATER_JET_SHEET_PATH):
		sheet = load(WATER_JET_SHEET_PATH) as Texture2D
	if sheet == null:
		var abs_path: String = ProjectSettings.globalize_path(WATER_JET_SHEET_PATH)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				sheet = ImageTexture.create_from_image(img)
	if sheet == null:
		return null

	var frames := SpriteFrames.new()
	frames.add_animation(&"water_jet")
	frames.set_animation_loop(&"water_jet", true)
	frames.set_animation_speed(&"water_jet", 30.0)
	for idx: int in range(30):
		var col: int = idx % 4
		var row: int = idx / 4
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * 188, row * 80, 188, 80)
		atlas.filter_clip = true
		frames.add_frame(&"water_jet", atlas)
	_water_jet_frames = frames
	return _water_jet_frames


func _load_texture_safe(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var tex := load(res_path) as Texture2D
		if tex != null:
			return tex
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _play_urinal_pee_animation() -> void:
	var pee_actor: Node2D = _urinal_guilherme_actor if (_urinal_guilherme_actor != null and is_instance_valid(_urinal_guilherme_actor)) else player
	if pee_actor == null or not is_instance_valid(pee_actor):
		_finish_urinal_sequence()
		return

	# 1. Guilherme saca a comanda oficial (comanda.png) antes de iniciar o jato
	var comanda := Sprite2D.new()
	comanda.name = "PlayerComandaInHand"
	comanda.texture = _load_texture_safe(COMANDA_SPRITE_PATH)
	comanda.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	comanda.position = Vector2(20.0, -70.0)
	comanda.scale = Vector2(0.05, 0.05)
	comanda.z_index = 6
	pee_actor.add_child(comanda)

	var draw_tw := create_tween().set_parallel(true)
	draw_tw.tween_property(comanda, "position", Vector2(46.0, -108.0), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	draw_tw.tween_property(comanda, "scale", Vector2(0.38, 0.38), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	draw_tw.chain().tween_callback(func() -> void:
		if not is_instance_valid(pee_actor) or not is_instance_valid(comanda):
			_finish_urinal_sequence()
			return
		# 2. Jato PixelFX em parábola saindo da cintura do Guilherme, subindo em arco até cair no mictório
		# e atingindo parte da comanda segurada à frente
		var jet_anim: AnimatedSprite2D = null
		var frames := _get_water_jet_frames()
		if frames != null:
			jet_anim = AnimatedSprite2D.new()
			jet_anim.name = "PixelFXPeeStream"
			jet_anim.sprite_frames = frames
			jet_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			jet_anim.modulate = Color(1.0, 0.92, 0.26, 0.95)
			jet_anim.position = Vector2(48.0, -112.0)
			jet_anim.scale = Vector2(0.56, 0.56)
			jet_anim.rotation = -0.34
			jet_anim.z_index = 7
			jet_anim.play(&"water_jet")
			pee_actor.add_child(jet_anim)

		CombatFeedback.play_sound(self, PEE_SFX, 2.0, 0.03)

		var pee_tw := create_tween()
		pee_tw.tween_property(comanda, "modulate", Color(0.95, 0.84, 0.28, 1.0), 1.8)
		pee_tw.tween_interval(0.6)
		pee_tw.tween_callback(func() -> void:
			if is_instance_valid(jet_anim):
				jet_anim.queue_free()
			if is_instance_valid(comanda):
				comanda.queue_free()
			_finish_urinal_sequence()
		)
	)


func _finish_urinal_sequence() -> void:
	_urinal_sequence_finished = true
	if _urinal_temp_guilherme != null and is_instance_valid(_urinal_temp_guilherme):
		_urinal_temp_guilherme.queue_free()
	_urinal_temp_guilherme = null
	_urinal_guilherme_actor = null
	if player != null and is_instance_valid(player):
		player.velocity = Vector2.ZERO
		if player.has_method("set_qte_locked"):
			player.call("set_qte_locked", true)
		if player.has_method("set_cutscene_walk_override"):
			player.call("set_cutscene_walk_override", true)
		player.set_physics_process(true)
	_start_auto_return_to_map7()


func _start_auto_return_to_map7() -> void:
	if _auto_return_started or _return_transition_triggered:
		return
	_auto_return_started = true
	_auto_return_lane_aligned = false
	if player != null and is_instance_valid(player):
		if player.has_method("set_cutscene_walk_override"):
			player.call("set_cutscene_walk_override", true)
		player.facing_direction = -1.0
		if player.visual_root != null:
			player.visual_root.scale.x = -absf(player.visual_root.scale.y)
		if player.anim_sprite != null and player.anim_sprite.sprite_frames != null and player.anim_sprite.sprite_frames.has_animation("walk"):
			player.anim_sprite.play("walk")


func _update_auto_return_walk(delta: float) -> void:
	if not _auto_return_started or _return_transition_triggered:
		return
	if player == null or not is_instance_valid(player):
		_trigger_return_to_map7()
		return

	if player.anim_sprite != null and player.anim_sprite.sprite_frames != null and player.anim_sprite.sprite_frames.has_animation("walk"):
		if player.anim_sprite.animation != &"walk" or not player.anim_sprite.is_playing():
			player.anim_sprite.play("walk")

	player.facing_direction = -1.0
	if player.visual_root != null:
		player.visual_root.scale.x = -absf(player.visual_root.scale.y)

	var target: Vector2 = Vector2(player.global_position.x, BATHROOM_RETURN_EXIT_POS.y) if not _auto_return_lane_aligned else BATHROOM_RETURN_EXIT_POS
	var step: float = AUTO_RETURN_WALK_SPEED * delta
	player.global_position = player.global_position.move_toward(target, step)
	player.global_position.x = clampf(player.global_position.x, WALKABLE_LEFT, WALKABLE_RIGHT)
	player.global_position.y = clampf(player.global_position.y, WALKABLE_TOP, WALKABLE_BOTTOM)

	if not _auto_return_lane_aligned:
		if absf(player.global_position.y - BATHROOM_RETURN_EXIT_POS.y) <= 4.0:
			_auto_return_lane_aligned = true
		return

	if player.global_position.x <= BATHROOM_RETURN_EXIT_POS.x + 8.0:
		_trigger_return_to_map7()


func _trigger_return_to_map7() -> void:
	if _return_transition_triggered or _transitioning:
		return
	_return_transition_triggered = true
	_transitioning = true

	if player != null and is_instance_valid(player):
		player.velocity = Vector2.ZERO
		if player.anim_sprite != null and player.anim_sprite.sprite_frames != null and player.anim_sprite.sprite_frames.has_animation("idle"):
			player.anim_sprite.play("idle")

	var session := get_node_or_null("/root/GameSession")
	if session != null:
		if player != null and is_instance_valid(player):
			if "current_continues" in player and "current_continues" in session:
				session.current_continues = player.current_continues
			var cur_hp: float = player.health_component.current_health if player.health_component != null else 100.0
			var cur_sp: float = player.current_special if "current_special" in player else 0.0
			if session.has_method("save_player_progression"):
				session.save_player_progression(map_group, cur_hp, cur_sp)
		if session.has_method("set_pending_map8_return_to_happen_finale"):
			session.set_pending_map8_return_to_happen_finale(true)

	_safe_change_scene(MAP7_SCENE_PATH)


func is_auto_return_started() -> bool:
	return _auto_return_started


func is_return_transition_triggered() -> bool:
	return _return_transition_triggered


func is_urinal_sequence_started() -> bool:
	return _urinal_sequence_started


func is_urinal_sequence_finished() -> bool:
	return _urinal_sequence_finished


func is_combat_started() -> bool:
	return _combat_started


func is_combat_ended() -> bool:
	return _combat_ended


func get_dialogue_controller() -> Node:
	return _dialogue_controller


func _setup_level_bgm() -> void:
	super._setup_level_bgm()
