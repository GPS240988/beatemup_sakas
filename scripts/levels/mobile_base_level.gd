extends "res://scripts/levels/base_level.gd"

## Camada mobile compartilhada pelos mapas 1–4 e pela fase bônus (bonus1).
## Desktop delega integralmente à implementação de BaseLevel.
## Mobile ajusta o zoom a partir do retângulo real do background e restringe
## reforços à NavigationPolygon ativa, com caminho válido até o jogador.

@export_range(1.0, 1.08, 0.005) var mobile_camera_fill_overscan: float = 1.02
@export_range(120.0, 600.0, 10.0) var mobile_spawn_ideal_distance: float = 320.0
@export_range(80.0, 260.0, 10.0) var mobile_spawn_min_player_distance: float = 160.0

var _mobile_authored_camera_zoom: Vector2 = Vector2.ONE
var _mobile_authored_camera_y: float = 360.0
var _mobile_spawn_batch_positions: Array[Vector2] = []


func _ready() -> void:
	# Captura os valores autorais antes de BaseLevel preparar a câmera.
	if camera != null:
		_mobile_authored_camera_zoom = camera.zoom
	_mobile_authored_camera_y = camera_fixed_y
	super._ready()


func _get_mobile_background_world_rect() -> Rect2:
	var far_background := get_node_or_null("Background/Far") as Sprite2D
	if far_background == null or far_background.texture == null:
		return Rect2()

	var local_rect: Rect2 = far_background.get_rect()
	if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
		return Rect2()

	# Converte os quatro cantos para coordenadas globais; respeita posição,
	# escala e transformações do Sprite2D e de seus nós-pais.
	var local_top_left: Vector2 = local_rect.position
	var local_top_right := Vector2(local_rect.end.x, local_rect.position.y)
	var local_bottom_left := Vector2(local_rect.position.x, local_rect.end.y)
	var local_bottom_right: Vector2 = local_rect.end
	var points: Array[Vector2] = [
		far_background.to_global(local_top_left),
		far_background.to_global(local_top_right),
		far_background.to_global(local_bottom_left),
		far_background.to_global(local_bottom_right)
	]

	var left: float = INF
	var top: float = INF
	var right: float = -INF
	var bottom: float = -INF
	for point: Vector2 in points:
		left = minf(left, point.x)
		top = minf(top, point.y)
		right = maxf(right, point.x)
		bottom = maxf(bottom, point.y)

	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _apply_mobile_camera_bounds() -> void:
	if not _is_mobile_runtime():
		super._apply_mobile_camera_bounds()
		return
	if camera == null:
		return

	# Sempre parte dos limites definidos pelo mapa; redimensionamentos repetidos
	# não acumulam clamps nem zooms sucessivos.
	camera_min_x = _configured_camera_min_x
	camera_max_x = _configured_camera_max_x
	camera_fixed_y = _mobile_authored_camera_y

	var viewport_size: Vector2 = get_viewport_rect().size
	var background_rect: Rect2 = _get_mobile_background_world_rect()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or not background_rect.has_area():
		return

	var authored_zoom_x: float = maxf(absf(_mobile_authored_camera_zoom.x), 0.001)
	var authored_zoom_y: float = maxf(absf(_mobile_authored_camera_zoom.y), 0.001)
	var authored_zoom: float = maxf(authored_zoom_x, authored_zoom_y)
	var fit_zoom_x: float = viewport_size.x / background_rect.size.x
	var fit_zoom_y: float = viewport_size.y / background_rect.size.y
	var fill_zoom: float = maxf(fit_zoom_x, fit_zoom_y)
	var final_zoom: float = maxf(authored_zoom, fill_zoom) * mobile_camera_fill_overscan
	camera.zoom = Vector2(final_zoom, final_zoom)

	# O zoom é calculado no mapa real, então todas as quatro artes podem ter
	# dimensões diferentes sem revelar o matte/cinza em qualquer proporção.
	var half_visible_width: float = viewport_size.x * 0.5 / final_zoom
	var half_visible_height: float = viewport_size.y * 0.5 / final_zoom
	camera_min_x = maxf(camera_min_x, background_rect.position.x + half_visible_width)
	camera_max_x = minf(camera_max_x, background_rect.end.x - half_visible_width)

	if camera_min_x > camera_max_x:
		var center_x: float = clampf(
			background_rect.get_center().x,
			_configured_camera_min_x,
			_configured_camera_max_x
		)
		camera_min_x = center_x
		camera_max_x = center_x

	var min_camera_y: float = background_rect.position.y + half_visible_height
	var max_camera_y: float = background_rect.end.y - half_visible_height
	if min_camera_y <= max_camera_y:
		camera_fixed_y = clampf(_mobile_authored_camera_y, min_camera_y, max_camera_y)
	else:
		camera_fixed_y = background_rect.get_center().y


func _on_mobile_viewport_size_changed() -> void:
	if not _is_mobile_runtime():
		super._on_mobile_viewport_size_changed()
		return

	_apply_mobile_camera_bounds()
	if camera != null:
		camera.global_position.x = clampf(camera.global_position.x, camera_min_x, camera_max_x)
		camera.global_position.y = camera_fixed_y


## BaseLevel chama este método ao criar reforços nos Mapas 2, 3 e 4.
## Em mobile não usamos limites retangulares estimados: cada posição é um ponto
## real da NavigationPolygon e precisa ter caminho até o jogador.
func get_offscreen_spawn_position(index: int = 0, total: int = 1) -> Vector2:
	if not _is_mobile_runtime():
		return super.get_offscreen_spawn_position(index, total)

	if index == 0:
		_mobile_spawn_batch_positions.clear()

	var world: World2D = get_world_2d()
	if world == null:
		return _get_player_safe_position()

	var nav_map: RID = world.navigation_map
	if not nav_map.is_valid() or NavigationServer2D.map_get_iteration_id(nav_map) == 0:
		return _get_player_safe_position()

	var active_player: Node2D = get_player() as Node2D
	if active_player == null or not is_instance_valid(active_player):
		return _get_safe_random_navigation_point(nav_map)

	var player_position: Vector2 = active_player.global_position
	var player_nav_position: Vector2 = NavigationServer2D.map_get_closest_point(
		nav_map, player_position
	)
	if player_nav_position == Vector2.ZERO and player_position.length() > 1.0:
		return player_position

	var viewport_size: Vector2 = get_viewport_rect().size
	var camera_x: float = camera.global_position.x if camera != null else player_nav_position.x
	var zoom_x: float = maxf(absf(camera.zoom.x), 0.001) if camera != null else 1.0
	var half_visible_width: float = viewport_size.x * 0.5 / zoom_x
	var visible_left: float = camera_x - half_visible_width
	var visible_right: float = camera_x + half_visible_width
	var preferred_direction: float = 1.0 if player_nav_position.x <= camera_x else -1.0
	var background_rect: Rect2 = _get_mobile_background_world_rect()

	var best_position: Vector2 = Vector2.ZERO
	var best_score: float = INF
	for attempt: int in range(72):
		var candidate: Vector2 = NavigationServer2D.map_get_random_point(nav_map, 1, false)
		if candidate == Vector2.ZERO:
			continue
		if background_rect.has_area() and not background_rect.has_point(candidate):
			continue

		var path: PackedVector2Array = NavigationServer2D.map_get_path(
			nav_map, player_nav_position, candidate, true, 1
		)
		if path.is_empty():
			continue

		var player_distance: float = player_nav_position.distance_to(candidate)
		if player_distance < mobile_spawn_min_player_distance:
			continue

		var separated: bool = true
		for previous_position: Vector2 in _mobile_spawn_batch_positions:
			if candidate.distance_to(previous_position) < 88.0:
				separated = false
				break
		if not separated:
			continue

		# Quando há área navegável fora da câmera, prioriza a entrada pelo lado
		# oposto ao jogador. Se o telefone exibir o mapa inteiro, escolhe uma
		# posição alcançável próxima ao combate em vez de forçar um spawn externo.
		var outside_preferred: bool = (
			candidate.x > visible_right + 36.0
			if preferred_direction > 0.0
			else candidate.x < visible_left - 36.0
		)
		var outside_other: bool = (
			candidate.x < visible_left - 36.0
			if preferred_direction > 0.0
			else candidate.x > visible_right + 36.0
		)
		var score: float = absf(player_distance - mobile_spawn_ideal_distance)
		if outside_preferred:
			score -= 180.0
		elif outside_other:
			score -= 90.0
		else:
			score += 55.0

		if background_rect.has_area():
			var edge_clearance: float = minf(
				candidate.x - background_rect.position.x,
				background_rect.end.x - candidate.x
			)
			score += maxf(0.0, 96.0 - edge_clearance) * 2.0
		score += maxf(0.0, absf(candidate.y - player_nav_position.y) - 150.0) * 0.25
		if score < best_score:
			best_score = score
			best_position = candidate

	if best_position != Vector2.ZERO:
		_mobile_spawn_batch_positions.append(best_position)
		return best_position

	# Fallback curto e igualmente validado pela malha. Nunca retorna um X/Y
	# calculado por retângulo nem aceita o snap para o extremo cinza do mapa.
	var fallback_offsets: Array[Vector2] = [
		Vector2(preferred_direction * 260.0, 0.0),
		Vector2(preferred_direction * 210.0, -42.0),
		Vector2(preferred_direction * 210.0, 42.0),
		Vector2(-preferred_direction * 220.0, 0.0),
		Vector2(0.0, -110.0),
		Vector2(0.0, 110.0)
	]
	for offset: Vector2 in fallback_offsets:
		var requested: Vector2 = player_nav_position + offset
		var candidate: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, requested)
		if candidate == Vector2.ZERO or requested.distance_to(candidate) > 100.0:
			continue
		if background_rect.has_area() and not background_rect.has_point(candidate):
			continue
		if player_nav_position.distance_to(candidate) < 110.0:
			continue
		var path: PackedVector2Array = NavigationServer2D.map_get_path(
			nav_map, player_nav_position, candidate, true, 1
		)
		if path.is_empty():
			continue
		var separated: bool = true
		for previous_position: Vector2 in _mobile_spawn_batch_positions:
			if candidate.distance_to(previous_position) < 88.0:
				separated = false
				break
		if separated:
			_mobile_spawn_batch_positions.append(candidate)
			return candidate

	# Última contenção: um ponto dentro da malha sob o jogador é preferível a
	# deixar o inimigo preso fora da NavigationPolygon ou em um canto sem caminho.
	_mobile_spawn_batch_positions.append(player_nav_position)
	return player_nav_position


func _get_player_safe_position() -> Vector2:
	var active_player: Node2D = get_player() as Node2D
	if active_player != null and is_instance_valid(active_player):
		return active_player.global_position
	return Vector2.ZERO


func _get_safe_random_navigation_point(nav_map: RID) -> Vector2:
	for attempt: int in range(24):
		var candidate: Vector2 = NavigationServer2D.map_get_random_point(nav_map, 1, false)
		if candidate != Vector2.ZERO:
			return candidate
	return Vector2.ZERO
