extends "res://scripts/ui/map_transition.gd"

## Especialização da transição pós-Garagem.
## Usa a mesma geometria e as mesmas rotas oficiais do MapMenu.

const STAGE2_INTRO_SCENE: String = "res://scenes/story/story_stage2_intro.tscn"
const MAP_STAGE_POINT_SCENE: PackedScene = preload("res://scenes/ui/components/map_stage_point.tscn")
const MAP_MENU_SCRIPT = preload("res://scripts/ui/map_menu.gd")

const STAGE_POINT_SIZE: Vector2 = Vector2(110.0, 110.0)
const STAGE_ARROW_OFFSET: Vector2 = Vector2(0.0, -(STAGE_POINT_SIZE.y * 0.5 + 6.0))
const OVERVIEW_STAGE_INDICES: Array[int] = [0, 4, 5]

var _stage_point_nodes: Dictionary = {}


func _resolve_target_scene() -> void:
	var session = get_node_or_null("/root/GameSession")
	var pending_mode: int = -1
	var pending_target: String = ""

	if session != null:
		pending_mode = int(session.get("pending_map_transition_mode"))
		pending_target = str(session.get("pending_transition_target"))

	if pending_mode == 1:
		if pending_target.is_empty() or not ResourceLoader.exists(pending_target):
			session.set("pending_transition_target", STAGE2_INTRO_SCENE)

	super._resolve_target_scene()

	if int(transition_mode) == 1:
		if target_scene_path == "res://scenes/ui/credits.tscn":
			target_scene_path = STAGE2_INTRO_SCENE

	if not ResourceLoader.exists(target_scene_path):
		push_error("MapTransitionStage2: destino não encontrado: " + target_scene_path)


func _ready() -> void:
	super._ready()
	_apply_stage_arrow_positions()
	_create_stage_points()


## A rota é lida diretamente do MapMenu para não manter uma segunda versão
## das coordenadas do mapa_base.webp.
func _setup_path() -> void:
	if trail_path == null:
		return

	var route_segments: Array = MAP_MENU_SCRIPT.ROUTE_SEGMENTS
	var segments_to_use: Array[int] = []

	match int(transition_mode):
		0: # POINT1_TO_BONUS
			segments_to_use = [0, 1, 2, 3]
		1: # BONUS_TO_POINT2
			segments_to_use = [4]
		2: # FULL_PREVIEW
			for segment_index in range(route_segments.size()):
				segments_to_use.append(segment_index)

	var points: Array[Vector2] = []
	var start_stage_index: int = 0
	var end_stage_index: int = 5

	if int(transition_mode) == 1:
		start_stage_index = 4
	elif int(transition_mode) == 0:
		end_stage_index = 4

	# A seta parte e chega na mesma posição superior usada pelo MapMenu.
	points.append(_stage_arrow_position(start_stage_index))

	for segment_index in segments_to_use:
		var segment: Array = route_segments[segment_index]
		for raw_point in segment:
			var route_point: Vector2 = raw_point
			if points.is_empty() or points[points.size() - 1] != route_point:
				points.append(route_point)

	points.append(_stage_arrow_position(end_stage_index))

	var curve := Curve2D.new()
	for point in points:
		curve.add_point(point)
	trail_path.curve = curve


func _stage_center(stage_index: int) -> Vector2:
	var configs: Array = MAP_MENU_SCRIPT.STAGE_CONFIGS
	var config: Dictionary = configs[stage_index]
	var ratio: Vector2 = config["pos_ratio"]
	return Vector2(
		ratio.x * float(MAP_MENU_SCRIPT.MAP_WIDTH),
		ratio.y * float(MAP_MENU_SCRIPT.MAP_HEIGHT)
	)


func _stage_arrow_position(stage_index: int) -> Vector2:
	return _stage_center(stage_index) + STAGE_ARROW_OFFSET


func _apply_stage_arrow_positions() -> void:
	if resting_arrow_p1 != null:
		resting_arrow_p1.position = _stage_arrow_position(0)
	if resting_arrow_bonus != null:
		resting_arrow_bonus.position = _stage_arrow_position(4)
	if resting_arrow_p2 != null:
		resting_arrow_p2.position = _stage_arrow_position(5)


func _create_stage_points() -> void:
	if map_container == null:
		push_error("MapTransitionStage2: MapContainer não encontrado.")
		return

	for stage_index in OVERVIEW_STAGE_INDICES:
		var config: Dictionary = MAP_MENU_SCRIPT.STAGE_CONFIGS[stage_index]
		var center: Vector2 = _stage_center(stage_index)
		var point: Control = MAP_STAGE_POINT_SCENE.instantiate() as Control
		if point == null:
			push_error("MapTransitionStage2: falha ao instanciar MapStagePoint.")
			continue

		point.name = "StagePoint_%s" % str(config["id"])
		point.custom_minimum_size = STAGE_POINT_SIZE
		point.size = STAGE_POINT_SIZE
		point.position = center - (STAGE_POINT_SIZE * 0.5)
		point.z_index = 2
		point.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_container.add_child(point)

		var hit_button: Button = point.get_node_or_null("%HitButton") as Button
		if hit_button != null:
			hit_button.disabled = true
			hit_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var stage_id: String = str(config["id"])
		var stage_title: String = str(config["title"])
		var display_tag: String = "ESTÁGIO 01"
		var is_bonus: bool = bool(config.get("is_bonus", false))
		var is_unlocked: bool = true
		var is_completed: bool = stage_index == 0 or stage_index == 4

		if is_bonus:
			display_tag = "★ BÔNUS ★"
		elif stage_index == 5:
			display_tag = "ESTÁGIO 02"

		if stage_index == 0:
			stage_id = "01"
		elif stage_index == 5:
			stage_id = "02"

		point.call(
			"setup",
			stage_index,
			stage_id,
			stage_title,
			display_tag,
			is_unlocked,
			is_completed,
			is_bonus
		)
		point.call("set_selected", false)
		_stage_point_nodes[stage_id] = point

	for arrow in [moving_arrow, resting_arrow_p1, resting_arrow_bonus, resting_arrow_p2]:
		if arrow != null:
			arrow.z_index = 5
	if unlock_vfx != null:
		unlock_vfx.z_index = 6


func _execute_bonus_to_point2() -> void:
	if resting_arrow_bonus != null:
		resting_arrow_bonus.visible = false
	point1_cover.visible = true
	moving_arrow.visible = true
	path_follow.progress_ratio = 0.0

	_play_sound(_sfx_travel)

	var tween_move := create_tween()
	tween_move.tween_property(path_follow, "progress_ratio", 1.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween_move.finished

	moving_arrow.visible = false

	resting_arrow_p2.visible = true
	_start_arrow_bobbing(resting_arrow_p2)
	point2_cover.visible = true
	_play_sound(_sfx_unlock)
	if unlock_vfx != null:
		unlock_vfx.position = _stage_center(5)
		if unlock_vfx.has_method("play_burst"):
			unlock_vfx.play_burst()

	var session = get_node_or_null("/root/GameSession")
	if session != null and session.has_method("unlock_stage_2"):
		session.unlock_stage_2()

	_set_stage2_marker_unlocked()
	await get_tree().create_timer(1.2).timeout


func _set_stage2_marker_unlocked() -> void:
	var point: Control = _stage_point_nodes.get("02") as Control
	if point == null or not is_instance_valid(point):
		return

	var unlocked: bool = true
	var tag: String = "ESTÁGIO 02"
	point.call("setup", 5, "02", "HAPPEN", tag, unlocked, false, false)
	point.call("set_selected", false)
