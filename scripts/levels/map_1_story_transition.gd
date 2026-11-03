extends "res://scripts/levels/base_level.gd"

## Intercepta somente a passagem do primeiro mapa da Fase 1 para map_2.
## A lógica original de BaseLevel continua salvando a progressão e limpando
## reforços pendentes; apenas o destino imediato é substituído pela cena narrativa.

const MAP_2_SCENE_PATH: String = "res://scenes/levels/map_2.tscn"
const STORY_INTERLUDE_SCENE_PATH: String = "res://scenes/story/story_intro_fase1_2.tscn"

var _mobile_reinforcement_spawn_positions: Array[Vector2] = []


## Desktop conserva exatamente o cálculo original de entrada fora da câmera.
## No mobile, a câmera pode mostrar quase todo o mapa: o antigo fallback
## acabava prendendo um reforço na borda do retângulo e fora da NavigationPolygon.
func get_offscreen_spawn_position(index: int = 0, total: int = 1) -> Vector2:
	if not _is_mobile_runtime():
		return super.get_offscreen_spawn_position(index, total)

	if index == 0:
		_mobile_reinforcement_spawn_positions.clear()

	var player_node: Node2D = get_player()
	if player_node == null or not is_instance_valid(player_node):
		return super.get_offscreen_spawn_position(index, total)

	var world: World2D = get_world_2d()
	if world == null:
		return player_node.global_position

	var nav_map: RID = world.navigation_map
	if not nav_map.is_valid() or NavigationServer2D.map_get_iteration_id(nav_map) == 0:
		return player_node.global_position

	var player_position: Vector2 = player_node.global_position
	var player_nav_position: Vector2 = NavigationServer2D.map_get_closest_point(
		nav_map, player_position
	)
	if player_nav_position == Vector2.ZERO and player_position.length() > 1.0:
		return player_position

	var camera_x: float = camera.global_position.x if camera != null else player_position.x
	var zoom_x: float = absf(camera.zoom.x) if camera != null else 1.0
	zoom_x = maxf(zoom_x, 0.001)
	var viewport_width: float = get_viewport_rect().size.x
	if viewport_width <= 0.0:
		return player_nav_position
	var half_visible_width: float = viewport_width * 0.5 / zoom_x
	var visible_left: float = camera_x - half_visible_width
	var visible_right: float = camera_x + half_visible_width

	# O reforço entra pelo lado oposto ao jogador. A posição é calculada junto
	# à borda visível, não sorteada em qualquer ponto do mapa (o que o levava
	# repetidamente ao canto inferior esquerdo).
	var preferred_side: int = 1 if player_position.x <= camera_x else -1
	var side_choices: Array[int] = [preferred_side, -preferred_side]
	var lane_center: float = (float(maxi(total, 1) - 1) * 0.5)
	var desired_y: float = player_position.y + (float(index) - lane_center) * 48.0
	var y_adjustments: Array[float] = [0.0, -42.0, 42.0, -84.0, 84.0]
	var x_steps: Array[float] = [0.0, 64.0, 128.0, 192.0, 256.0]
	var minimum_separation: float = 58.0

	for side_value: int in side_choices:
		var side_sign: int = side_value
		var edge_x: float = (
			visible_right + 92.0 if side_sign > 0 else visible_left - 92.0
		)
		var best_position: Vector2 = Vector2.ZERO
		var best_score: float = INF

		# A busca é determinística: percorre somente faixas fora da câmera,
		# encaixa cada amostra na NavigationPolygon e valida o caminho até o herói.
		for x_step: float in x_steps:
			var sample_x: float = edge_x + float(side_sign) * x_step
			for y_adjustment: float in y_adjustments:
				var requested_position := Vector2(
					sample_x,
					clampf(desired_y + y_adjustment, 500.0, 730.0)
				)
				var candidate: Vector2 = NavigationServer2D.map_get_closest_point(
					nav_map, requested_position
				)
				if candidate == Vector2.ZERO:
					continue
				if requested_position.distance_to(candidate) > 88.0:
					continue

				# Não aceita um snap que traga o inimigo para dentro da tela.
				if side_sign > 0 and candidate.x <= visible_right + 18.0:
					continue
				if side_sign < 0 and candidate.x >= visible_left - 18.0:
					continue

				var path: PackedVector2Array = NavigationServer2D.map_get_path(
					nav_map, player_nav_position, candidate, true, 1
				)
				if path.is_empty():
					continue

				var separated: bool = true
				for previous_position: Vector2 in _mobile_reinforcement_spawn_positions:
					if candidate.distance_to(previous_position) < minimum_separation:
						separated = false
						break
				if not separated:
					continue

				var snap_error: float = requested_position.distance_to(candidate)
				var lane_error: float = absf(candidate.y - desired_y)
				var score: float = snap_error * 3.0 + lane_error * 0.35 + x_step * 0.15
				if score < best_score:
					best_score = score
					best_position = candidate

		# Só troca para o outro lado quando não existe ponto navegável válido
		# no lado preferencial. Isso mantém a entrada coerente com a câmera.
		if best_position != Vector2.ZERO:
			_mobile_reinforcement_spawn_positions.append(best_position)
			return best_position

	# Último recurso: ponto alcançável próximo ao jogador. É preferível fazer
	# o reforço aparecer visivelmente perto do combate a deixá-lo preso fora
	# da NavigationPolygon ou retornar ao cálculo antigo que causava o bug.
	var fallback_offsets: Array[Vector2] = [
		Vector2(float(preferred_side) * 150.0, -48.0),
		Vector2(float(preferred_side) * 120.0, 48.0),
		Vector2(float(-preferred_side) * 120.0, 0.0),
		Vector2(0.0, 90.0)
	]
	for fallback_offset: Vector2 in fallback_offsets:
		var fallback_candidate: Vector2 = NavigationServer2D.map_get_closest_point(
			nav_map, player_nav_position + fallback_offset
		)
		if fallback_candidate == Vector2.ZERO:
			continue
		var fallback_path: PackedVector2Array = NavigationServer2D.map_get_path(
			nav_map, player_nav_position, fallback_candidate, true, 1
		)
		if not fallback_path.is_empty():
			_mobile_reinforcement_spawn_positions.append(fallback_candidate)
			return fallback_candidate

	_mobile_reinforcement_spawn_positions.append(player_nav_position)
	return player_nav_position


func _advance_to_next_map() -> void:
	var should_show_interlude: bool = (
		map_group == "fase1"
		and map_index == 1
		and next_map_scene_path == MAP_2_SCENE_PATH
	)

	if not should_show_interlude:
		super._advance_to_next_map()
		return

	if not ResourceLoader.exists(STORY_INTERLUDE_SCENE_PATH):
		push_warning(
			"Cena story_intro_fase1_2.tscn não encontrada. "
			+ "A transição seguirá diretamente para map_2.tscn."
		)
		super._advance_to_next_map()
		return

	# O método original salva vida, especial e fichas antes de trocar a cena.
	# A substituição temporária do destino mantém esse comportamento intacto.
	var original_next_scene: String = next_map_scene_path
	next_map_scene_path = STORY_INTERLUDE_SCENE_PATH
	super._advance_to_next_map()
	next_map_scene_path = original_next_scene
