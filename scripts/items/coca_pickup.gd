extends Node2D
class_name CocaPickup

## Consumível de cura dropado pela GameBox do map_2.
## A coleta é solicitada pelo Player ao pressionar J e exige proximidade 2.5D.

@export_range(0.05, 1.0, 0.05) var heal_ratio: float = 0.25
@export_range(8.0, 160.0, 1.0) var pickup_range_x: float = 64.0
@export_range(4.0, 96.0, 1.0) var pickup_depth_tolerance: float = 28.0
@export_file("*.png") var item_texture_path: String = "res://assets/sprites/Itens/item_coca.png"

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
	_play_consumed_animation()
	return true


## Pisca três vezes e encolhe antes de desaparecer do chão.
func _play_consumed_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	for blink_index: int in range(3):
		tween.tween_property(visual_root, "modulate:a", 0.12, 0.09)
		tween.tween_property(visual_root, "modulate:a", 1.0, 0.09)
	tween.tween_property(visual_root, "scale", Vector2.ZERO, 0.12)
	tween.tween_callback(queue_free)
