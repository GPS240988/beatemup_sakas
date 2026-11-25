extends BaseLevel

## Interior da HAPPEN. O background panorâmico é mantido em escala 1:1;
## somente a mesa retangular recebe redução visual para a escala de gameplay.

const BACKGROUND_PATH: String = "res://assets/backgrounds/maps/fase2/Fase2_4.webp"
const PLAYER_START: Vector2 = Vector2(180.0, 585.0)
const WALKABLE_TOP: float = 440.0
const WALKABLE_BOTTOM: float = 680.0


func _ready() -> void:
	_configure_happen_map()
	var director := get_node_or_null("CombatDirector")
	if director != null and director.get("difficulty_profile") == null:
		director.call("apply_difficulty_profile", EncounterDifficultyProfile.create_for_map(4))
	super._ready()
	if hud != null and hud.label_level_name != null:
		hud.label_level_name.text = "FASE 2-3 · HAPPEN — SALÃO PRINCIPAL"


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


func _setup_level_bgm() -> void:
	# A trilha exclusiva do interior da HAPPEN ainda não foi aprovada.
	return
