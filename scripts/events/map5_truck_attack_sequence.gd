class_name Map5TruckAttackSequence
extends Node2D

## Set piece jogável imediatamente após a derrota do Boss Bêbado.
## A rua vira zona de perigo; os jogadores permanecem na calçada, enquanto
## a caminhonete e os três punks ocupam a faixa de rua em uma microsequência arcade.
##
## Contrato:
## - 3 punks / 3 acertos obrigatórios.
## - 6 lançamentos de garrafa no total.
## - 1º alvo ensina; 2 restantes aumentam a pressão; último vira clímax.
## - Sem HUD genérica: comunicação por diálogo canônico + leitura visual.
## - Ao sucesso: derrapagem, queda dos punks e preparação de drops temáticos da Happen.

signal completed(success: bool)

const Map5TruckAttackPunkClass = preload("res://scripts/events/map5_truck_attack_punk.gd")
const Map5TruckAttackStoneClass = preload("res://scripts/events/map5_truck_attack_stone.gd")
const StandardDialogueBoxClass = preload("res://scripts/ui/standard_dialogue_box.gd")
const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")

const TRUCK_SHEET: Texture2D = preload(
	"res://assets/sprites/stage2/truck_attack_sequence/truck/truck_spritesheet.png"
)
const GUILHERME_PORTRAIT: Texture2D = preload(
	"res://assets/ui/hud/portraits/portrait_guilherme.png"
)
const GABRIEL_PORTRAIT: Texture2D = preload(
	"res://assets/ui/hud/portraits/portrait_gabriel.png"
)

const PUNK_COUNT: int = 3
const REQUIRED_HITS: int = 3
const MAX_BOTTLE_THROWS: int = 6

const PUNK_CELL_SIZE := Vector2i(220, 300)
const TRUCK_CELL_SIZE := Vector2i(512, 384)
const TRUCK_VISUAL_OFFSET_Y: float = -172.0
const TRUCK_SCALE: float = 0.80

const SIDEWALK_MAX_Y: float = 538.0
const SIDEWALK_BARRIER_LAYER: int = 16
const TRUCK_ROAD_Y: float = 620.0
const PUNK_BED_Y: float = 550.0
const TRUCK_ENTRY_X: float = 700.0
const TRUCK_STAGE_X: float = 1230.0
const TRUCK_EXIT_X: float = 2240.0

const TRUCK_CRUISE_SPEED: float = 28.0
const TRUCK_EXIT_SPEED: float = 365.0
const TRUCK_EXIT_ACCEL: float = 460.0

const DIALOGUE_LAYER: int = 125

enum SetPiecePhase {
	INTRO,
	ACTIVE,
	SUCCESS_DRIFT,
	FAIL_EXIT,
	EXITING,
	COMPLETED,
}

var phase: SetPiecePhase = SetPiecePhase.INTRO
var _truck: Node2D = null
var _truck_sprite: AnimatedSprite2D = null
var _punks: Array[Map5TruckAttackPunk] = []
var _truck_animation_names: Array[StringName] = [
	&"entrada",
	&"acelerando",
	&"cruzeiro",
	&"freada",
	&"derrapagem",
	&"parada",
	&"saida",
]

var _hits: int = 0
var _throws_used: int = 0
var _tracked_bottle_projectiles: Dictionary = {}
var _bottle_crates_locked: bool = false
var _failure_check_pending: bool = false
var _punk_throwing: Array[bool] = [false, false, false]
var _punk_throw_timers: Array[float] = [0.0, 999.0, 999.0]
var _last_pressure_hits: int = -1

var _sidewalk_barrier: StaticBody2D = null
var _saved_player_masks: Dictionary = {}
var _tree_was_paused: bool = false
var _dialogue_layer: CanvasLayer = null
var _dialogue_root: Control = null
var _dialogue_label: Label = null
var _continue_label: Label = null
var _speaker_label: Label = null
var _portrait: TextureRect = null
var _dialogue_tween: Tween = null
var _dialogues: Array[Dictionary] = []
var _dialogue_index: int = 0
var _dialogue_typing: bool = false
var _dialogue_waiting_for_release: bool = true


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	y_sort_enabled = true


func start() -> void:
	_start_internal(false)


## Entrada de desenvolvimento: inicia a mesma set piece sem precisar derrotar o Boss Bêbado.
## skip_intro=false reproduz a apresentação completa; true posiciona a caminhonete
## diretamente no trecho jogável, preservando a mesma lógica de gameplay.
func start_debug(skip_intro: bool = false) -> void:
	if not OS.is_debug_build():
		return
	_start_internal(skip_intro)


func _start_internal(skip_intro: bool) -> void:
	if phase != SetPiecePhase.INTRO:
		return

	_tree_was_paused = get_tree().paused
	_create_sidewalk_barrier()
	_lock_players_to_sidewalk()
	_lock_bottle_projectiles_snapshot()
	_spawn_truck_and_punks()

	get_tree().paused = true
	_set_truck_state(&"entrada")
	if not skip_intro:
		await _move_truck_to_stage()
	else:
		_truck.global_position = Vector2(TRUCK_STAGE_X, TRUCK_ROAD_Y)

	if not is_inside_tree():
		return

	_set_truck_state(&"cruzeiro")
	if not skip_intro:
		await _show_intro_dialogue()

	if not is_inside_tree():
		return

	get_tree().paused = _tree_was_paused
	phase = SetPiecePhase.ACTIVE
	_refresh_throw_pressure(true)


func _physics_process(delta: float) -> void:
	if _truck != null and is_instance_valid(_truck):
		_update_punk_positions()

	if phase == SetPiecePhase.ACTIVE:
		_update_truck_cruise(delta)
		_update_bottle_quota()
		_update_throw_pressure(delta)
		_clamp_players_to_sidewalk()
		_check_failure_window()
	elif phase == SetPiecePhase.EXITING:
		_update_truck_exit(delta)
		_clamp_players_to_sidewalk()


func _spawn_truck_and_punks() -> void:
	_truck = Node2D.new()
	_truck.name = "Truck"
	_truck.global_position = Vector2(TRUCK_ENTRY_X, TRUCK_ROAD_Y)
	_truck.z_index = -2
	add_child(_truck)

	_truck_sprite = AnimatedSprite2D.new()
	_truck_sprite.name = "AnimatedSprite2D"
	_truck_sprite.sprite_frames = _build_truck_frames()
	_truck_sprite.centered = true
	_truck_sprite.position = Vector2(0.0, TRUCK_VISUAL_OFFSET_Y)
	_truck_sprite.scale = Vector2(TRUCK_SCALE, TRUCK_SCALE)
	_truck_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_truck_sprite.animation = &"entrada"
	_truck_sprite.frame = 0
	_truck.add_child(_truck_sprite)

	var punk_offsets: Array[Vector2] = [
		Vector2(-72.0, PUNK_BED_Y - TRUCK_ROAD_Y),
		Vector2(-10.0, PUNK_BED_Y - TRUCK_ROAD_Y),
		Vector2(48.0, PUNK_BED_Y - TRUCK_ROAD_Y),
	]

	for index in PUNK_COUNT:
		var punk := Map5TruckAttackPunkClass.new()
		punk.name = "TruckAttackPunk%d" % (index + 1)
		punk.punk_index = index
		punk.z_index = -1
		add_child(punk)
		punk.bottle_hit.connect(_on_punk_bottle_hit)
		_punks.append(punk)
		punk.global_position = _truck.global_position + punk_offsets[index]


func _build_truck_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	for i in _truck_animation_names.size():
		var row: int = i / 4
		var col: int = i % 4
		var atlas := AtlasTexture.new()
		atlas.atlas = TRUCK_SHEET
		atlas.region = Rect2(
			float(col * TRUCK_CELL_SIZE.x),
			float(row * TRUCK_CELL_SIZE.y),
			float(TRUCK_CELL_SIZE.x),
			float(TRUCK_CELL_SIZE.y)
		)
		var animation_name: StringName = _truck_animation_names[i]
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, false)
		frames.set_animation_speed(animation_name, 1.0)
		frames.add_frame(animation_name, atlas)
	return frames


func _move_truck_to_stage() -> void:
	if _truck == null:
		return

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_truck, "global_position:x", TRUCK_ENTRY_X + 120.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_set_truck_state(&"acelerando")
	)
	tween.tween_property(_truck, "global_position:x", TRUCK_STAGE_X, 1.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.08)
	tween.tween_callback(func() -> void:
		_set_truck_state(&"cruzeiro")
	)
	await tween.finished


func _update_truck_cruise(delta: float) -> void:
	if _truck == null:
		return
	_truck.global_position.x += TRUCK_CRUISE_SPEED * delta
	if _truck.global_position.x > 1350.0:
		_truck.global_position.x = 1350.0

	_update_punk_positions()


func _update_truck_exit(delta: float) -> void:
	if _truck == null:
		return

	_truck_exit_speed = minf(
		_truck_exit_speed + TRUCK_EXIT_ACCEL * delta,
		TRUCK_EXIT_SPEED
	)
	_truck.global_position.x += _truck_exit_speed * delta
	_update_punk_positions()

	if _truck.global_position.x >= TRUCK_EXIT_X:
		_finish(true if _hits >= REQUIRED_HITS else false)


var _truck_exit_speed: float = 0.0


func _update_punk_positions() -> void:
	if _truck == null:
		return

	var y_offset: float = PUNK_BED_Y - TRUCK_ROAD_Y
	var offsets: Array[float] = [-72.0, -10.0, 48.0]
	for index in _punks.size():
		var punk := _punks[index]
		if punk == null or not is_instance_valid(punk):
			continue
		punk.global_position = _truck.global_position + Vector2(offsets[index], y_offset)


func _set_truck_state(state_name: StringName) -> void:
	if _truck_sprite == null or not _truck_sprite.sprite_frames.has_animation(state_name):
		return
	_truck_sprite.animation = state_name
	_truck_sprite.frame = 0
	_truck_sprite.stop()


func _on_punk_bottle_hit(punk: Map5TruckAttackPunk) -> void:
	if phase != SetPiecePhase.ACTIVE:
		return
	_hits = mini(_hits + 1, REQUIRED_HITS)

	var hit_position := punk.global_position + Vector2(0.0, -72.0)
	CombatFeedbackClass.flash_node(punk.get_node_or_null("Visual"), Color(2.2, 2.2, 2.2, 1.0), 0.08)
	if _hits < REQUIRED_HITS:
		CombatFeedbackClass.trigger_screen_shake(self, 4.5, 0.12)
	else:
		CombatFeedbackClass.trigger_screen_shake(self, 8.0, 0.24)
		_begin_success_drift()

	_refresh_throw_pressure(false)


func _refresh_throw_pressure(force_reset: bool) -> void:
	if force_reset:
		_last_pressure_hits = -1

	if _hits == _last_pressure_hits and not force_reset:
		return
	_last_pressure_hits = _hits

	for index in PUNK_COUNT:
		var punk := _punks[index]
		if punk == null or not is_instance_valid(punk):
			continue
		if punk.is_defeated():
			_punk_throw_timers[index] = 999.0
			continue

		if _hits == 0:
			_punk_throw_timers[index] = 0.35 if index == 0 else 999.0
		elif _hits == 1:
			_punk_throw_timers[index] = 0.20 + float(index) * 0.28
		else:
			_punk_throw_timers[index] = 0.18 if _first_alive_punk_index() == index else 999.0


func _update_throw_pressure(delta: float) -> void:
	if _hits >= REQUIRED_HITS:
		return

	var interval_multiplier: float = _get_throw_interval_multiplier()

	for index in PUNK_COUNT:
		var punk := _punks[index]
		if punk == null or not is_instance_valid(punk) or punk.is_defeated():
			continue
		if _punk_throwing[index]:
			continue

		_punk_throw_timers[index] -= delta
		if _punk_throw_timers[index] > 0.0:
			continue

		_punk_throwing[index] = true
		_punk_throw_timers[index] = _get_throw_interval() * interval_multiplier
		_launch_punk_throw(index)


func _launch_punk_throw(index: int) -> void:
	if index < 0 or index >= _punks.size():
		return
	var punk := _punks[index]
	if punk == null or not is_instance_valid(punk) or punk.is_defeated():
		_punk_throwing[index] = false
		return

	var target := _get_stone_target()
	var spawn_position: Vector2 = await punk.play_stone_throw()
	_punk_throwing[index] = false

	if phase != SetPiecePhase.ACTIVE or spawn_position == Vector2.ZERO:
		return

	var stone := Map5TruckAttackStoneClass.new()
	add_child(stone)
	var damage: float = 8.0 * _get_difficulty_damage_multiplier()
	stone.launch(punk, spawn_position, target, damage)


func _get_stone_target() -> Vector2:
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node is Node2D:
		var player_position: Vector2 = (player_node as Node2D).global_position
		return Vector2(
			clampf(player_position.x + 60.0, 780.0, 1940.0),
			clampf(player_position.y - 4.0, 455.0, SIDEWALK_MAX_Y)
		)
	return Vector2(1300.0, 520.0)


func _get_throw_interval() -> float:
	if _hits == 0:
		return 1.25
	if _hits == 1:
		return 0.92
	return 0.58


func _get_throw_interval_multiplier() -> float:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not ("difficulty_id" in session):
		return 1.0

	var difficulty_id: String = str(session.difficulty_id).to_lower()
	if difficulty_id == "dificil":
		return 0.84
	if difficulty_id == "facil":
		return 1.18
	return 1.0


func _get_difficulty_damage_multiplier() -> float:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return 1.0

	var difficulty_id: String = str(session.difficulty_id).to_lower()
	if difficulty_id == "dificil":
		return 1.95
	if difficulty_id == "facil":
		return 0.65
	return 1.0


func _first_alive_punk_index() -> int:
	for index in PUNK_COUNT:
		var punk := _punks[index]
		if punk != null and is_instance_valid(punk) and not punk.is_defeated():
			return index
	return -1


func _update_bottle_quota() -> void:
	if _bottle_crates_locked:
		return

	var current_ids: Dictionary = {}
	var bottles := get_tree().get_nodes_in_group("gas_bottle_projectile")
	for node in bottles:
		if node == null or not is_instance_valid(node):
			continue
		var instance_id: int = node.get_instance_id()
		current_ids[instance_id] = true
		if not _tracked_bottle_projectiles.has(instance_id):
			_tracked_bottle_projectiles[instance_id] = true
			_throws_used += 1

	if _throws_used >= MAX_BOTTLE_THROWS:
		_lock_bottle_crates()


func _lock_bottle_projectiles_snapshot() -> void:
	_tracked_bottle_projectiles.clear()
	var bottles := get_tree().get_nodes_in_group("gas_bottle_projectile")
	for node in bottles:
		if node != null and is_instance_valid(node):
			_tracked_bottle_projectiles[node.get_instance_id()] = true


func _lock_bottle_crates() -> void:
	if _bottle_crates_locked:
		return
	_bottle_crates_locked = true

	for crate in get_tree().get_nodes_in_group("gas_bottle_crates"):
		if crate == null or not is_instance_valid(crate):
			continue
		var pickup_area := crate.get_node_or_null("PickupArea") as Area2D
		if pickup_area != null:
			pickup_area.set_deferred("monitoring", false)
		for player in get_tree().get_nodes_in_group("player"):
			if player != null and is_instance_valid(player) and player.has_method("unregister_interactable"):
				player.call("unregister_interactable", crate)
		var hint := crate.get_node_or_null("PickUpHint") as Control
		if hint != null:
			hint.visible = false


func _unlock_bottle_crates() -> void:
	for crate in get_tree().get_nodes_in_group("gas_bottle_crates"):
		if crate == null or not is_instance_valid(crate):
			continue
		var pickup_area := crate.get_node_or_null("PickupArea") as Area2D
		if pickup_area != null:
			pickup_area.set_deferred("monitoring", true)


func _check_failure_window() -> void:
	if _throws_used < MAX_BOTTLE_THROWS or _hits >= REQUIRED_HITS or _failure_check_pending:
		return

	_failure_check_pending = true
	await get_tree().create_timer(0.72, true).timeout
	_failure_check_pending = false
	if phase != SetPiecePhase.ACTIVE:
		return
	if _hits >= REQUIRED_HITS:
		return

	_begin_failure_exit()


func _begin_success_drift() -> void:
	if phase != SetPiecePhase.ACTIVE:
		return
	phase = SetPiecePhase.SUCCESS_DRIFT
	_lock_bottle_crates()

	_set_truck_state(&"freada")
	CombatFeedbackClass.spawn_dust(self, _truck.global_position + Vector2(-96.0, 0.0), 1.15)
	CombatFeedbackClass.spawn_dust(self, _truck.global_position + Vector2(-18.0, 2.0), 0.78)
	CombatFeedbackClass.trigger_screen_shake(self, 9.0, 0.28)

	await get_tree().create_timer(0.10, true).timeout
	_set_truck_state(&"derrapagem")

	var drift_tween := create_tween()
	drift_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	drift_tween.set_parallel(true)
	drift_tween.tween_property(_truck, "global_position:x", _truck.global_position.x + 58.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drift_tween.tween_property(_truck, "rotation_degrees", -4.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drift_tween.chain().tween_property(_truck, "rotation_degrees", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await drift_tween.finished

	if not is_inside_tree():
		return

	_set_truck_state(&"parada")
	_spawn_happen_drops_if_available()

	_begin_exit_sequence()


func _begin_failure_exit() -> void:
	if phase != SetPiecePhase.ACTIVE:
		return
	phase = SetPiecePhase.FAIL_EXIT
	_lock_bottle_crates()
	_set_truck_state(&"freada")
	CombatFeedbackClass.spawn_dust(self, _truck.global_position + Vector2(-96.0, 0.0), 0.80)
	CombatFeedbackClass.trigger_screen_shake(self, 5.0, 0.18)
	await get_tree().create_timer(0.35, true).timeout
	if is_inside_tree():
		_begin_exit_sequence()


func _begin_exit_sequence() -> void:
	if phase == SetPiecePhase.COMPLETED:
		return
	phase = SetPiecePhase.EXITING
	_truck_exit_speed = 70.0
	_set_truck_state(&"saida")


func _spawn_happen_drops_if_available() -> void:
	# Os assets finais dos três itens da Happen ainda não fazem parte deste pacote.
	# Quando chegarem, o código procura suas cenas canônicas sem criar placeholders.
	var drop_paths: Array[String] = [
		"res://scenes/items/happen_pizza_cutter_pickup.tscn",
		"res://scenes/items/happen_rolling_pin_pickup.tscn",
		"res://scenes/items/happen_pizza_spatula_pickup.tscn",
	]
	var drop_offsets: Array[Vector2] = [
		Vector2(-104.0, -16.0),
		Vector2(-38.0, -14.0),
		Vector2(30.0, -12.0),
	]

	var actor_parent: Node = get_parent()
	for index in drop_paths.size():
		if not ResourceLoader.exists(drop_paths[index]):
			continue
		var scene := load(drop_paths[index]) as PackedScene
		if scene == null:
			continue
		var instance := scene.instantiate()
		if instance is Node2D:
			(actor_parent as Node).add_child(instance)
			(instance as Node2D).global_position = _truck.global_position + drop_offsets[index]


func _finish(success: bool) -> void:
	if phase == SetPiecePhase.COMPLETED:
		return

	phase = SetPiecePhase.COMPLETED
	_unlock_bottle_crates()
	_remove_sidewalk_barrier()
	get_tree().paused = _tree_was_paused
	completed.emit(success)
	queue_free()


func _create_sidewalk_barrier() -> void:
	if _sidewalk_barrier != null and is_instance_valid(_sidewalk_barrier):
		return

	_sidewalk_barrier = StaticBody2D.new()
	_sidewalk_barrier.name = "TruckAttackSidewalkBarrier"
	_sidewalk_barrier.collision_layer = 0
	_sidewalk_barrier.set_collision_layer_value(SIDEWALK_BARRIER_LAYER, true)
	_sidewalk_barrier.collision_mask = 0
	_sidewalk_barrier.z_index = -100
	add_child(_sidewalk_barrier)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	var map_width: float = 2048.0
	var bg := get_node_or_null("../../../../Background/Far") as Sprite2D
	if bg != null and bg.texture != null:
		map_width = bg.texture.get_width()
	rectangle.size = Vector2(map_width, 16.0)
	shape.shape = rectangle
	shape.position = Vector2(map_width * 0.5, SIDEWALK_MAX_Y + 7.0)
	_sidewalk_barrier.add_child(shape)


func _lock_players_to_sidewalk() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if player == null or not is_instance_valid(player):
			continue
		if "collision_mask" in player:
			_saved_player_masks[player.get_instance_id()] = int(player.collision_mask)
		if player.has_method("set_collision_mask_value"):
			player.call("set_collision_mask_value", SIDEWALK_BARRIER_LAYER, true)
		if "velocity" in player:
			player.set("velocity", Vector2.ZERO)
		var player_2d := player as Node2D
		if player_2d != null and player_2d.global_position.y > SIDEWALK_MAX_Y - 10.0:
			player_2d.global_position.y = SIDEWALK_MAX_Y - 18.0


func _clamp_players_to_sidewalk() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if player == null or not is_instance_valid(player):
			continue
		var player_2d := player as Node2D
		if player_2d != null and player_2d.global_position.y > SIDEWALK_MAX_Y - 6.0:
			player_2d.global_position.y = SIDEWALK_MAX_Y - 6.0


func _remove_sidewalk_barrier() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if player == null or not is_instance_valid(player):
			continue
		var player_id: int = player.get_instance_id()
		if _saved_player_masks.has(player_id):
			player.set("collision_mask", _saved_player_masks[player_id])
	_saved_player_masks.clear()

	if _sidewalk_barrier != null and is_instance_valid(_sidewalk_barrier):
		_sidewalk_barrier.queue_free()
	_sidewalk_barrier = null


func _build_dialogue_messages() -> void:
	var speaker: String = "GUILHERME"
	var portrait: Texture2D = GUILHERME_PORTRAIT

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("is_gabriel") and bool(player.call("is_gabriel")):
		speaker = "GABRIEL"
		portrait = GABRIEL_PORTRAIT

	_dialogues = [
		{
			"speaker": speaker,
			"portrait": portrait,
			"text": "Olha aqueles caras! Estão atacando o posto!"
		},
		{
			"speaker": speaker,
			"portrait": portrait,
			"text": "As garrafas! Joga neles!"
		},
	]


func _show_intro_dialogue() -> void:
	_build_dialogue_messages()
	_dialogue_index = 0
	_dialogue_waiting_for_release = not _is_advance_input_held()
	_dialogue_layer = CanvasLayer.new()
	_dialogue_layer.name = "TruckAttackDialogue"
	_dialogue_layer.layer = DIALOGUE_LAYER
	_dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dialogue_layer)

	_dialogue_root = Control.new()
	_dialogue_root.name = "DialogueRoot"
	_dialogue_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_dialogue_layer.add_child(_dialogue_root)

	var is_mobile: bool = (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)
	var ui: Dictionary = StandardDialogueBoxClass.build_dialogue_ui(_dialogue_root, is_mobile)
	_portrait = ui["portrait"] as TextureRect
	_speaker_label = ui["speaker_label"] as Label
	_dialogue_label = ui["dialogue_label"] as Label
	_continue_label = ui["continue_label"] as Label

	_show_current_dialogue()

	while _dialogue_layer != null and is_instance_valid(_dialogue_layer):
		await get_tree().create_timer(0.03, true).timeout


func _show_current_dialogue() -> void:
	if _dialogue_index >= _dialogues.size():
		_close_dialogue()
		return

	var current: Dictionary = _dialogues[_dialogue_index]
	if _portrait != null:
		_portrait.texture = current.get("portrait", GUILHERME_PORTRAIT)
	if _speaker_label != null:
		_speaker_label.text = str(current.get("speaker", ""))
	if _dialogue_label != null:
		_dialogue_label.text = str(current.get("text", ""))
		_dialogue_label.visible_characters = 0
	if _continue_label != null:
		_continue_label.visible = false

	_start_typewriter()


func _start_typewriter() -> void:
	_dialogue_typing = true
	if _dialogue_tween != null and _dialogue_tween.is_valid():
		_dialogue_tween.kill()

	if _dialogue_label == null:
		_dialogue_typing = false
		return

	var duration: float = float(_dialogue_label.text.length()) / maxf(
		StandardDialogueBoxClass.TYPEWRITER_SPEED_CPS,
		1.0
	)
	_dialogue_tween = create_tween()
	_dialogue_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_dialogue_tween.tween_property(
		_dialogue_label,
		"visible_characters",
		_dialogue_label.text.length(),
		duration
	).set_trans(Tween.TRANS_LINEAR)
	_dialogue_tween.finished.connect(_on_typewriter_finished)


func _on_typewriter_finished() -> void:
	_dialogue_typing = false
	if _dialogue_label != null:
		_dialogue_label.visible_characters = -1
	if _continue_label != null:
		_continue_label.visible = true


func _input(event: InputEvent) -> void:
	if _dialogue_layer == null or not is_instance_valid(_dialogue_layer):
		return

	if _dialogue_waiting_for_release:
		if not _is_advance_input_held():
			_dialogue_waiting_for_release = false
		return

	if not _is_advance_event(event):
		return

	get_viewport().set_input_as_handled()
	if _dialogue_typing:
		_finish_typewriter()
	else:
		_dialogue_index += 1
		if _dialogue_index < _dialogues.size():
			_show_current_dialogue()
		else:
			_close_dialogue()


func _finish_typewriter() -> void:
	if _dialogue_tween != null and _dialogue_tween.is_valid():
		_dialogue_tween.kill()
	_dialogue_tween = null
	_dialogue_typing = false
	if _dialogue_label != null:
		_dialogue_label.visible_characters = -1
	if _continue_label != null:
		_continue_label.visible = true


func _close_dialogue() -> void:
	if _dialogue_layer == null:
		return
	if _dialogue_tween != null and _dialogue_tween.is_valid():
		_dialogue_tween.kill()
	_dialogue_tween = null
	_dialogue_typing = false
	_dialogue_layer.queue_free()
	_dialogue_layer = null
	_dialogue_root = null


func _is_advance_input_held() -> bool:
	return (
		Input.is_key_pressed(KEY_ENTER)
		or Input.is_key_pressed(KEY_KP_ENTER)
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_action_pressed("ui_accept")
	)


func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return (
			key_event.pressed
			and not key_event.echo
			and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		return joy_event.pressed and joy_event.button_index == JOY_BUTTON_A
	return false


func _exit_tree() -> void:
	if _dialogue_layer != null and is_instance_valid(_dialogue_layer):
		_dialogue_layer.queue_free()
	_dialogue_layer = null
	_remove_sidewalk_barrier()
	_unlock_bottle_crates()
