extends "res://scripts/items/ovo_pickup.gd"
class_name PizzaSlicePickup

## Fatia de pizza (HAPPEN) com cura fixa (+30 HP), usando o contrato canônico
## de interação, botão "Pegar" / tecla J e feedback flutuante +30 HP.

const PIZZA_SLICE_TEXTURE_PATH: String = "res://assets/sprites/stage2/happen_props/fatia_pizza.png"

@export var sprite_offset_y: float = -24.0
@export var sprite_scale_factor: float = 0.72
@export var enable_floating_anim: bool = false


func _ready() -> void:
	heal_amount = 30.0
	item_texture_path = PIZZA_SLICE_TEXTURE_PATH
	scale = Vector2(0.5, 0.5)
	if pickup_range_x < 96.0:
		pickup_range_x = 96.0
	if pickup_depth_tolerance < 56.0:
		pickup_depth_tolerance = 56.0
	super._ready()
	if item_sprite != null:
		item_sprite.scale = Vector2(sprite_scale_factor, sprite_scale_factor)
		item_sprite.position.y = sprite_offset_y
	if _hint_button != null:
		_hint_button.position.y = sprite_offset_y - 115.0


func _setup_visuals() -> void:
	if visual_root == null:
		return
	_visuals = DroppedItemVisualsScript.new()
	_visuals.name = "DroppedItemVisuals"
	add_child(_visuals)
	var show_ground_aura: bool = sprite_offset_y >= -100.0
	_visuals.call("setup", visual_root, show_ground_aura, Vector2(46.0, 14.0), Vector2(42.0, 12.0), enable_floating_anim)


func _load_item_texture() -> void:
	if item_sprite == null:
		return
	var tex: Texture2D = null
	if ResourceLoader.exists(PIZZA_SLICE_TEXTURE_PATH):
		tex = load(PIZZA_SLICE_TEXTURE_PATH) as Texture2D
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(PIZZA_SLICE_TEXTURE_PATH)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	if tex != null:
		item_sprite.texture = tex
		item_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		item_sprite.visible = true
		if fallback_visual != null:
			fallback_visual.visible = false
