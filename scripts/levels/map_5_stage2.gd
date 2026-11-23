extends BaseLevel

## Configuração específica da primeira seção jogável do Estágio 02.
## Geometria, faixa caminhável e limites de câmera acompanham a dimensão real
## da textura local, preservando a proporção da arte panorâmica sem esticá-la.
## A trilha do Stage 02 ainda não foi definida; não reutiliza BGM do Stage 01 ou bônus.

const Map5BakeryCutsceneClass = preload("res://scripts/events/map5_bakery_cutscene.gd")
const Map5TruckAttackSequenceClass = preload("res://scripts/events/map5_truck_attack_sequence.gd")

var _andre_bakery_video_played: bool = false
var _truck_attack_sequence_active: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if _truck_attack_sequence_active:
		return
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_F9 or key_event.physical_keycode == KEY_F9:
		_start_truck_attack_debug(false)
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_F10 or key_event.physical_keycode == KEY_F10:
		_start_truck_attack_debug(true)
		get_viewport().set_input_as_handled()


func _ready() -> void:
	_configure_panorama_from_texture()
	super._ready()
	if hud != null and hud.label_level_name != null:
		hud.label_level_name.text = "FASE 2-1 · RUMO À HAPPEN"
	var bakery_trigger: Area2D = get_node_or_null("BakeryVideoTrigger") as Area2D
	if bakery_trigger != null and not bakery_trigger.body_entered.is_connected(_on_bakery_trigger_body_entered):
		bakery_trigger.body_entered.connect(_on_bakery_trigger_body_entered)


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

	# Corredor expandido para rua, calçada e faixa atrás das bombas.
	var lane_top: float = map_size.y * 0.57
	var lane_bottom: float = map_size.y * 0.94
	# O limite superior mantém os pés fora da parede; a malha respeita o colisor do ator.
	var navigation_top: float = lane_top + 24.0
	var lane_center: float = (lane_top + lane_bottom) * 0.5
	var lane_height: float = lane_bottom - lane_top
	var initial_lane_y: float = lane_bottom - 45.0

	# Pegada física das duas ilhas de bombas, alinhada ao PNG de foreground 2048x704.
	var island_left: float = map_size.x * 0.1962890625
	var island_left_end: float = map_size.x * 0.3330078125
	var island_right: float = map_size.x * 0.3828125
	var island_right_end: float = map_size.x * 0.53662109375
	var island_top: float = map_size.y * 0.6306818182
	var island_bottom: float = map_size.y * 0.6477272727
	var front_lane_top: float = island_bottom + 21.0
	var nav_right: float = map_size.x - 60.0

	# Perspectiva 2.5D: escala visual do fundo ao primeiro plano, ancorada nos pés.
	var depth_scaler: Node = get_node_or_null("YDepthScaler")
	if depth_scaler != null:
		depth_scaler.set("far_lane_y", navigation_top)
		depth_scaler.set("near_lane_y", lane_bottom)

	# A faixa traseira termina no posto. O acesso à calçada acontece pelos vãos
	# à esquerda da primeira ilha e entre as duas ilhas; não há conector após a
	# segunda ilha, evitando rota por trás da padaria.
	var gas_back_lane_end: float = map_size.x * (1140.0 / 2048.0)
	var nav_region: NavigationRegion2D = get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	if nav_region != null and nav_region.navigation_polygon != null:
		var polygon: NavigationPolygon = nav_region.navigation_polygon.duplicate(true) as NavigationPolygon
		polygon.vertices = PackedVector2Array([
			# Corredor atrás das bombas, restrito ao posto.
			Vector2(60.0, navigation_top), Vector2(gas_back_lane_end, navigation_top),
			Vector2(gas_back_lane_end, island_top), Vector2(60.0, island_top),
			# Calçada/rua frontal: segue até o limite lateral do cenário.
			Vector2(60.0, front_lane_top), Vector2(nav_right, front_lane_top),
			Vector2(nav_right, lane_bottom), Vector2(60.0, lane_bottom),
			# Passagem à esquerda da primeira ilha.
			Vector2(60.0, island_top), Vector2(island_left, island_top),
			Vector2(island_left, front_lane_top), Vector2(60.0, front_lane_top),
			# Passagem entre os dois conjuntos de bombas.
			Vector2(island_left_end, island_top), Vector2(island_right, island_top),
			Vector2(island_right, front_lane_top), Vector2(island_left_end, front_lane_top)
		])
		polygon.polygons = [
			PackedInt32Array([0, 1, 2, 3]),
			PackedInt32Array([4, 5, 6, 7]),
			PackedInt32Array([8, 9, 10, 11]),
			PackedInt32Array([12, 13, 14, 15])
		]
		nav_region.navigation_polygon = polygon

	_set_rectangle_shape(
		"StaticWorld/PumpsCollision/LeftIsland",
		Vector2(island_left_end - island_left, island_bottom - island_top),
		Vector2((island_left + island_left_end) * 0.5, (island_top + island_bottom) * 0.5)
	)
	_set_rectangle_shape(
		"StaticWorld/PumpsCollision/RightIsland",
		Vector2(island_right_end - island_right, island_bottom - island_top),
		Vector2((island_right + island_right_end) * 0.5, (island_top + island_bottom) * 0.5)
	)

	# Obstáculos de cenário: colisores representam somente a pegada no chão.
	# Isso bloqueia a passagem sem transformar a silhueta inteira do sprite em parede.
	var art_scale: Vector2 = Vector2(map_size.x / 2048.0, map_size.y / 704.0)
	_set_rectangle_shape(
		"StaticWorld/MapObstacles/TreeTrunk",
		Vector2(44.0, 42.0) * art_scale,
		Vector2(96.0, 447.0) * art_scale
	)
	_set_rectangle_shape(
		"StaticWorld/MapObstacles/LeftStreetlight",
		Vector2(26.0, 38.0) * art_scale,
		Vector2(226.0, 460.0) * art_scale
	)
	_set_rectangle_shape(
		"StaticWorld/MapObstacles/RightStreetlight",
		Vector2(26.0, 38.0) * art_scale,
		Vector2(1744.0, 460.0) * art_scale
	)
	_set_rectangle_shape(
		"StaticWorld/MapObstacles/HappenSignPost",
		Vector2(20.0, 38.0) * art_scale,
		Vector2(1902.0, 460.0) * art_scale
	)
	_set_rectangle_shape(
		"StaticWorld/MapObstacles/BakeryWaterHydrant",
		Vector2(24.0, 24.0) * art_scale,
		Vector2(1183.0, 458.0) * art_scale
	)
	_set_rectangle_shape(
		"StaticWorld/MapObstacles/RightFireHydrant",
		Vector2(22.0, 24.0) * art_scale,
		Vector2(1784.0, 464.0) * art_scale
	)
	_set_rectangle_shape(
		"StaticWorld/MapObstacles/BakerySideSign",
		Vector2(34.0, 24.0) * art_scale,
		Vector2(1553.0, 460.0) * art_scale
	)
	# Barreira física contínua no limite posterior da calçada, do início da padaria
	# até o fim do cenário. Mantém a faixa frontal livre e impede entrar atrás da fachada.
	var sidewalk_back_boundary_y: float = map_size.y * (442.0 / 704.0)
	var sidewalk_back_boundary_half_height: float = 12.0 * art_scale.y
	_set_rectangle_shape(
		"StaticWorld/MapObstacles/BakeryFacadeWall",
		Vector2(nav_right - gas_back_lane_end, sidewalk_back_boundary_half_height * 2.0),
		Vector2((gas_back_lane_end + nav_right) * 0.5, sidewalk_back_boundary_y)
	)

	# O NavigationRegion2D só orienta NavigationAgent2D; o Player usa movimento direto.
	# Esta parede transversal fecha fisicamente o fim do corredor atrás das bombas.
	var rear_gate_top: float = lane_top - 18.0
	var rear_gate_bottom: float = sidewalk_back_boundary_y + sidewalk_back_boundary_half_height
	_set_rectangle_shape(
		"StaticWorld/MapObstacles/RearLaneEndWall",
		Vector2(18.0 * art_scale.x, rear_gate_bottom - rear_gate_top),
		Vector2(gas_back_lane_end, (rear_gate_top + rear_gate_bottom) * 0.5)
	)
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
	_set_rectangle_shape(
		"BakeryVideoTrigger/CollisionShape2D",
		Vector2(64.0 * art_scale.x, lane_height),
		Vector2(1380.0 * art_scale.x, lane_center),
		true
	)

	# A âncora do foreground fica na base física das bombas (pés/solo).
	# O sprite é compensado para manter a arte no pixel original do panorama.
	# Cada conjunto tem seu próprio ponto de chão: primeiro os pilares, depois as bombas.
	var pillars_depth_root: Node2D = get_node_or_null("World/Props/StaticProps/CanopyPillarsForeground") as Node2D
	var pillars_sprite: Sprite2D = get_node_or_null("World/Props/StaticProps/CanopyPillarsForeground/Sprite2D") as Sprite2D
	if pillars_depth_root != null and pillars_sprite != null:
		var pillars_ground_y: float = map_size.y * (456.0 / 704.0)
		pillars_depth_root.position = Vector2(0.0, pillars_ground_y)
		pillars_sprite.position = Vector2(0.0, -pillars_ground_y)

	var pumps_depth_root: Node2D = get_node_or_null("World/Props/StaticProps/PumpsForeground") as Node2D
	var pumps_sprite: Sprite2D = get_node_or_null("World/Props/StaticProps/PumpsForeground/Sprite2D") as Sprite2D
	if pumps_depth_root != null and pumps_sprite != null:
		var pumps_ground_y: float = map_size.y * 0.65625
		pumps_depth_root.position = Vector2(0.0, pumps_ground_y)
		pumps_sprite.position = Vector2(0.0, -pumps_ground_y)

	var player_node: Node2D = get_node_or_null("World/Actors/Player") as Node2D
	if player_node != null:
		player_node.position = Vector2(map_size.x * 0.18, initial_lane_y)

	var spawn_left: Marker2D = get_node_or_null("SpawnPoints/SpawnPoint_Left") as Marker2D
	var spawn_mid: Marker2D = get_node_or_null("SpawnPoints/SpawnPoint_Mid") as Marker2D
	var spawn_right: Marker2D = get_node_or_null("SpawnPoints/SpawnPoint_Right") as Marker2D
	if spawn_left != null:
		spawn_left.position = Vector2(map_size.x * 0.09, initial_lane_y)
	if spawn_mid != null:
		spawn_mid.position = Vector2(map_size.x * 0.5, initial_lane_y)
	if spawn_right != null:
		spawn_right.position = Vector2(map_size.x * 0.91, initial_lane_y)

	# Conteúdo do posto: o frentista fica na calçada, junto à extremidade
	# direita da primeira ilha de bombas. Os engradados permanecem ancorados
	# na linha dos pés e não existem garrafas soltas no chão.
	var attendant: Node2D = get_node_or_null("World/Actors/NPCs/Frentista") as Node2D
	if attendant != null:
		attendant.position = Vector2(map_size.x * (704.0 / 2048.0), map_size.y * (440.0 / 704.0))
		# Interação deliberadamente curta: o J só chega ao frentista quando o player
		# estiver praticamente encostado, evitando atravessar a ilha de bombas com o prompt.
		var interaction_area: Area2D = attendant.get_node_or_null("InteractionArea") as Area2D
		var interaction_shape: CollisionShape2D = attendant.get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
		if interaction_area != null:
			interaction_area.monitoring = true
		if interaction_shape != null:
			var close_shape := interaction_shape.shape as RectangleShape2D
			if close_shape != null:
				close_shape.size = Vector2(72.0, 40.0)

	var crate_red: Node2D = get_node_or_null("World/Props/StaticProps/EngradadoVermelho") as Node2D
	var crate_green: Node2D = get_node_or_null("World/Props/StaticProps/EngradadoVerde") as Node2D
	if crate_red != null:
		crate_red.position = Vector2(map_size.x * (300.0 / 2048.0), map_size.y * (494.0 / 704.0))
	if crate_green != null:
		crate_green.position = Vector2(map_size.x * (1190.0 / 2048.0), map_size.y * (494.0 / 704.0))

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


func _on_bakery_trigger_body_entered(body: Node) -> void:
	if _andre_bakery_video_played:
		return
	if body == null or not body.is_in_group("player"):
		return
	_andre_bakery_video_played = true
	_play_andre_bakery_cutscene()


func _play_andre_bakery_cutscene() -> void:
	var cutscene: CanvasLayer = Map5BakeryCutsceneClass.new() as CanvasLayer
	if cutscene == null:
		return
	cutscene.name = "Map5BakeryCutscene"
	if not cutscene.cutscene_finished.is_connected(_on_bakery_cutscene_finished):
		cutscene.cutscene_finished.connect(_on_bakery_cutscene_finished, CONNECT_ONE_SHOT)
	add_child(cutscene)


func _on_bakery_cutscene_finished() -> void:
	# O vídeo é a transição narrativa; ao devolver o controle ao jogador,
	# o chefe entra imediatamente no fluxo canônico de BaseLevel.
	call_deferred("_spawn_bakery_boss")


func _spawn_bakery_boss() -> void:
	if _boss_spawned or boss_scene == null:
		return

	var active_player: PlayerController = get_player()
	if active_player != null and is_instance_valid(active_player):
		# Mantém a entrada do boss coerente com a posição física do momento final
		# do vídeo. A apresentação visual depois faz a queda a partir desta âncora.
		boss_spawn_position = Vector2(
			clampf(active_player.global_position.x + 112.0, 96.0, 1960.0),
			active_player.global_position.y
		)

	# Não há anúncio textual nesta apresentação: o impacto, a queda e o próprio
	# personagem comunicam a chegada do chefe.
	boss_announcement_text = ""
	_spawn_boss()
	if hud != null and hud.banner_panel != null:
		hud.banner_panel.visible = false
		hud.banner_panel.modulate.a = 1.0


## Intercepta a vitória do chefe para iniciar a set piece antes de liberar a saída.
func _on_enemy_defeated(enemy: CharacterBody2D) -> void:
	if _truck_attack_sequence_active:
		return
	if enemy == null or not is_instance_valid(enemy):
		super._on_enemy_defeated(enemy)
		return
	if _boss_instance != null and enemy == _boss_instance:
		# A morte do chefe já foi contabilizada pelo CombatDirector. O fluxo
		# específico do Map 5 substitui a janela de pós-combate do BaseLevel.
		_start_truck_attack_sequence()
		return

	super._on_enemy_defeated(enemy)


## Enquanto a set piece estiver ativa, o CombatDirector não libera a saída.
func _on_encounter_cleared() -> void:
	if _truck_attack_sequence_active:
		return
	super._on_encounter_cleared()


func _start_truck_attack_debug(skip_intro: bool) -> void:
	if _truck_attack_sequence_active:
		return
	if not is_inside_tree():
		return

	_truck_attack_sequence_active = true

	var actors_container: Node2D = get_actors_container()
	if actors_container == null:
		_truck_attack_sequence_active = false
		return

	var sequence := Map5TruckAttackSequenceClass.new()
	sequence.name = "Map5TruckAttackSequenceDebug"
	actors_container.add_child(sequence)

	if not sequence.completed.is_connected(_on_truck_attack_sequence_completed):
		sequence.completed.connect(_on_truck_attack_sequence_completed, CONNECT_ONE_SHOT)

	sequence.call_deferred("start_debug", skip_intro)


func _start_truck_attack_sequence() -> void:
	if _truck_attack_sequence_active:
		return
	if not is_inside_tree():
		return

	_truck_attack_sequence_active = true

	var actors_container: Node2D = get_actors_container()
	if actors_container == null:
		_truck_attack_sequence_active = false
		return

	var sequence := Map5TruckAttackSequenceClass.new()
	sequence.name = "Map5TruckAttackSequence"
	actors_container.add_child(sequence)

	if not sequence.completed.is_connected(_on_truck_attack_sequence_completed):
		sequence.completed.connect(_on_truck_attack_sequence_completed, CONNECT_ONE_SHOT)

	sequence.call_deferred("start")


func _on_truck_attack_sequence_completed(success: bool) -> void:
	_truck_attack_sequence_active = false

	# A saída só é liberada depois da conclusão visual da sequência.
	# No caminho de sucesso, os três punks derrubados já ficaram na caminhonete;
	# no caminho de falha, a caminhonete simplesmente escapa sem recompensa.
	if not success:
		# Sem penalidade artificial: a fase continua, mas o drop de Happen não é concedido.
		pass

	super._on_encounter_cleared()
