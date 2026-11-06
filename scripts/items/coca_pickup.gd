extends Node2D
class_name CocaPickup

## Consumível de cura dropado pela GameBox do map_2.
## A coleta é solicitada pelo Player ao pressionar J e exige proximidade 2.5D.

@export_range(0.05, 1.0, 0.05) var heal_ratio: float = 0.25
@export_range(8.0, 160.0, 1.0) var pickup_range_x: float = 64.0
@export_range(4.0, 96.0, 1.0) var pickup_depth_tolerance: float = 28.0
@export_file("*.png") var item_texture_path: String = "res://assets/sprites/Itens/item_coca.png"

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

var _consumed: bool = false

@onready var visual_root: Node2D = $Visual
@onready var item_sprite: Sprite2D = $Visual/Sprite
@onready var fallback_visual: Node2D = $Visual/Fallback


func _ready() -> void:
	y_sort_enabled = true
	add_to_group("health_pickups")
	_load_item_texture()


## Carrega o sprite original quando ele existe no projeto do usuário.
## O visual vetorial/pixelado da cena permanece como fallback quando o PNG não está presente.
func _load_item_texture() -> void:
	if item_texture_path.is_empty() or not ResourceLoader.exists(item_texture_path):
		return

	var loaded_texture: Texture2D = load(item_texture_path) as Texture2D
	if loaded_texture == null:
		return

	item_sprite.texture = loaded_texture
	fallback_visual.visible = false


## Consome o item se o jogador estiver perto e tiver vida para recuperar.
## Retorna false sem remover o item quando estiver fora de alcance ou com vida cheia.
func try_consume(player: Node) -> bool:
	if _consumed or not is_instance_valid(player) or not (player is Node2D):
		return false

	var player_node: Node2D = player as Node2D
	var offset: Vector2 = player_node.global_position - global_position
	if absf(offset.x) > pickup_range_x or absf(offset.y) > pickup_depth_tolerance:
		return false

	var health_component: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null or health_component.is_dead:
		return false
	if health_component.max_health <= 0.0 or health_component.current_health >= health_component.max_health:
		return false

	var amount_to_heal: float = health_component.max_health * heal_ratio
	var recovered: float = health_component.heal(amount_to_heal)
	if recovered <= 0.0:
		return false

	_consumed = true
	remove_from_group("health_pickups")
	_spawn_heal_feedback(player_node)
	_play_consumed_animation()
	return true


## Mostra o ganho de vida sobre a cabeça do jogador sem pausar a árvore do jogo.
func _spawn_heal_feedback(player_node: Node2D) -> void:
	if player_node == null or not is_instance_valid(player_node):
		return

	# Godot 4 não possui Label2D. Use Label (Control) com tamanho e posição
	# explícitos como filho do Node2D do jogador para obter o mesmo efeito 2D.
	var feedback := Label.new()
	feedback.name = "HealPickupFeedback"
	feedback.text = "+25% Vida"
	feedback.add_theme_font_override("font", ARCADE_FONT)
	feedback.add_theme_font_size_override("font_size", 21)
	feedback.add_theme_color_override("font_color", Color(0.48, 1.0, 0.52, 1.0))
	feedback.add_theme_color_override("font_outline_color", Color(0.025, 0.075, 0.035, 1.0))
	feedback.add_theme_constant_override("outline_size", 6)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	feedback.size = Vector2(240.0, 42.0)
	feedback.modulate = Color(1.0, 1.0, 1.0, 0.0)
	feedback.z_index = 100
	feedback.z_as_relative = false
	feedback.process_mode = Node.PROCESS_MODE_ALWAYS
	feedback.add_to_group("pickup_feedback_labels")

	# Usa o marcador Head oficial do Player, com fallback para rigs compatíveis.
	var spawn_position := Vector2(0.0, -220.0)
	var head_marker := player_node.get_node_or_null("ImpactZones/Head") as Node2D
	if head_marker != null:
		spawn_position = player_node.to_local(head_marker.global_position) + Vector2(0.0, -28.0)
	feedback.position = spawn_position - Vector2(feedback.size.x * 0.5, feedback.size.y * 0.5)
	player_node.add_child(feedback)
	var feedback_start_y: float = feedback.position.y

	var tween := feedback.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(feedback, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(feedback, "position:y", feedback_start_y - 42.0, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.28)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.22)
	tween.tween_callback(feedback.queue_free)


## Pisca três vezes e encolhe antes de desaparecer do chão.
func _play_consumed_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	for blink_index: int in range(3):
		tween.tween_property(visual_root, "modulate:a", 0.12, 0.09)
		tween.tween_property(visual_root, "modulate:a", 1.0, 0.09)
	# Escala para valor mínimo (nunca zero) para evitar affine_invert det==0
	tween.tween_property(visual_root, "scale", Vector2(0.01, 0.01), 0.12)
	tween.tween_callback(queue_free)
