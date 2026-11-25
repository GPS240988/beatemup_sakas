extends BaseLevel

## Interior da HAPPEN. O background panorâmico é mantido em escala 1:1;
## somente a mesa retangular recebe redução visual para a escala de gameplay.

const BACKGROUND_PATH: String = "res://assets/backgrounds/maps/fase2/Fase2_4.webp"
const PLAYER_START: Vector2 = Vector2(180.0, 585.0)
const WALKABLE_TOP: float = 440.0
const WALKABLE_BOTTOM: float = 680.0

const HAPPEN_ENEMY_PALETTES: Array[int] = [
	EnemyAI.PaletteVariant.RED,
	EnemyAI.PaletteVariant.GREEN,
	EnemyAI.PaletteVariant.PURPLE,
	EnemyAI.PaletteVariant.ORANGE,
	EnemyAI.PaletteVariant.CYAN,
]

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



func _setup_level_bgm() -> void:
	# A trilha exclusiva do interior da HAPPEN ainda não foi aprovada.
	return
