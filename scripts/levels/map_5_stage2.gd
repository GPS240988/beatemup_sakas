extends BaseLevel

## Configuração específica da primeira seção jogável do Estágio 02.
## Geometria, faixa caminhável e limites de câmera acompanham a dimensão real
## da textura local, preservando a proporção da arte panorâmica sem esticá-la.
## A trilha do Stage 02 ainda não foi definida; não reutiliza BGM do Stage 01 ou bônus.


func _ready() -> void:
	_configure_panorama_from_texture()
	super._ready()
	if hud != null and hud.label_level_name != null:
		hud.label_level_name.text = "FASE 2-1 · RUMO À HAPPEN"


func _configure_panorama_from_texture() -> void:
	var far_background: Sprite2D = get_node_or_null("Background/Far") as Sprite2D
	if far_background == null or far_background.texture == null:
		push_error("Map5Stage2: textura panorâmica Fase2_3.webp não encontrada.")
		return

	var map_size: Vector2 = far_background.texture.get_size()
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		push_error("Map5Stage2: dimensão inválida na textura panorâmica.")
		return

	var half_view_width: float = get_viewport_rect().size.x * 0.5
	camera_min_x = minf(half_view_width, map_size.x * 0.5)
	camera_max_x = maxf(camera_min_x, map_size.x - half_view_width)
	camera_fixed_y = map_size.y * 0.5

	# O corredor 2.5D acompanha proporcionalmente a faixa de asfalto do panorama.
	var lane_top: float = map_size.y * 0.71
	var lane_bottom: float = map_size.y * 0.94
	var lane_center: float = (lane_top + lane_bottom) * 0.5
	var lane_height: float = lane_bottom - lane_top

	var nav_region: NavigationRegion2D = get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	if nav_region != null and nav_region.navigation_polygon != null:
		var polygon: NavigationPolygon = nav_region.navigation_polygon.duplicate(true) as NavigationPolygon
		polygon.vertices = PackedVector2Array([
			Vector2(60.0, lane_top),
			Vector2(map_size.x - 60.0, lane_top),
			Vector2(map_size.x - 60.0, lane_bottom),
			Vector2(60.0, lane_bottom)
		])
		polygon.polygons = [PackedInt32Array([0, 1, 2, 3])]
		nav_region.navigation_polygon = polygon

	_set_rectangle_shape(
		"StaticWorld/WorldBoundaries/TopWall",
		Vector2(map_size.x, 36.0),
		Vector2(map_size.x * 0.5, lane_top - 18.0)
	)
	_set_rectangle_shape(
		"StaticWorld/WorldBoundaries/BottomWall",
		Vector2(map_size.x, 36.0),
		Vector2(map_size.x * 0.5, lane_bottom + 18.0)
	)
	_set_rectangle_shape(
		"StaticWorld/WorldBoundaries/LeftWall",
		Vector2(36.0, lane_height + 72.0),
		Vector2(18.0, lane_center)
	)
	_set_rectangle_shape(
		"StaticWorld/WorldBoundaries/RightWall",
		Vector2(36.0, lane_height + 72.0),
		Vector2(map_size.x - 18.0, lane_center)
	)
	_set_rectangle_shape(
		"ExitArea/CollisionShape2D",
		Vector2(72.0, lane_height),
		Vector2(map_size.x - 78.0, lane_center),
		true
	)

	var player_node: Node2D = get_node_or_null("World/Actors/Player") as Node2D
	if player_node != null:
		player_node.position = Vector2(map_size.x * 0.18, lane_center)

	var spawn_left: Marker2D = get_node_or_null("SpawnPoints/SpawnPoint_Left") as Marker2D
	var spawn_mid: Marker2D = get_node_or_null("SpawnPoints/SpawnPoint_Mid") as Marker2D
	var spawn_right: Marker2D = get_node_or_null("SpawnPoints/SpawnPoint_Right") as Marker2D
	if spawn_left != null:
		spawn_left.position = Vector2(map_size.x * 0.09, lane_center)
	if spawn_mid != null:
		spawn_mid.position = Vector2(map_size.x * 0.5, lane_center)
	if spawn_right != null:
		spawn_right.position = Vector2(map_size.x * 0.91, lane_center)


func _set_rectangle_shape(
	node_path: NodePath,
	shape_size: Vector2,
	shape_position: Vector2,
	is_area_shape: bool = false
) -> void:
	var collision_node: CollisionShape2D = get_node_or_null(node_path) as CollisionShape2D
	if collision_node == null:
		return

	var rectangle: RectangleShape2D = collision_node.shape.duplicate(true) as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
	rectangle.size = shape_size
	collision_node.shape = rectangle
	if is_area_shape:
		var parent_node: Node2D = collision_node.get_parent() as Node2D
		if parent_node != null:
			parent_node.position = shape_position
	else:
		collision_node.position = shape_position


func _setup_level_bgm() -> void:
	# A trilha própria do Estágio 02 será vinculada quando for aprovada.
	return
