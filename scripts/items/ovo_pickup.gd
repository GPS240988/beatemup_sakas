extends "res://scripts/items/coca_pickup.gd"
class_name OvoPickup

## Consumível de cura fixa (+50 HP), usando integralmente o contrato canônico
## de interação e os visuais de CocaPickup.

@export_range(1.0, 500.0, 1.0) var heal_amount: float = 50.0

const OVO_TEXTURE_PATH: String = "res://assets/sprites/Itens/ovo.png"
const MIN_WALKABLE_GROUND_Y: float = 545.0
const SAFE_PICKUP_GROUND_Y: float = 580.0

var _health_before_consume: float = 0.0


func _ready() -> void:
	pickup_depth_tolerance = 42.0
	pickup_range_x = 72.0
	# O ponto original ficava atrás da parede superior do Mapa 4 (Y=525),
	# fora da faixa caminhável [545, 735] e do alcance 2.5D do jogador.
	if global_position.y < MIN_WALKABLE_GROUND_Y:
		global_position.y = SAFE_PICKUP_GROUND_Y
	item_texture_path = OVO_TEXTURE_PATH
	super._ready()
	# Posiciona o botão "Pegar" logo acima da coroa do ovo sem cobri-lo
	if _hint_button != null:
		_hint_button.position.y = -190.0


func _setup_visuals() -> void:
	if visual_root == null:
		return
	_visuals = DroppedItemVisualsScript.new()
	_visuals.name = "DroppedItemVisuals"
	add_child(_visuals)
	# Assentado firmemente no solo (enable_floating = false), sombra elíptica proporcional
	# à largura do ovo (raio 72x18 local, 36x9 real sob a base de 88px) para ancoragem 2.5D perfeita.
	_visuals.call("setup", visual_root, true, Vector2(72.0, 18.0), Vector2(56.0, 14.0), false)


func try_consume(player: Node) -> bool:
	var health_component: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent if is_instance_valid(player) else null
	if health_component == null or health_component.max_health <= 0.0:
		return false
	_health_before_consume = health_component.current_health
	var previous_heal_ratio: float = heal_ratio
	heal_ratio = clampf(heal_amount / health_component.max_health, 0.0, 1.0)
	var consumed: bool = super.try_consume(player)
	heal_ratio = previous_heal_ratio
	return consumed


func _spawn_heal_feedback(player_node: Node2D) -> void:
	if player_node == null or not is_instance_valid(player_node):
		return
	var health_component: HealthComponent = player_node.get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null:
		return
	var recovered: int = int(round(health_component.current_health - _health_before_consume))
	var feedback := Label.new()
	feedback.name = "EggHealPickupFeedback"
	feedback.text = "+%d HP" % recovered
	feedback.add_theme_font_override("font", ARCADE_FONT)
	feedback.add_theme_font_size_override("font_size", 21)
	feedback.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	feedback.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 1.0))
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

func _load_item_texture() -> void:
	super._load_item_texture()
	if item_sprite == null or item_sprite.texture == null:
		return
	# Alinha pixel-perfect a base inferior opaca do ovo ao chão (Y = 0)
	item_sprite.position.y = -56.5

