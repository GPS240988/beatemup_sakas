class_name GasBottleCrate
extends Node2D

## Engradado de refrigerante interativo do posto da Fase 2-1.
## A interação usa o contrato existente de register_interactable/interact do PlayerController:
## primeira pressão pega uma garrafa; a próxima pressão (teclado ou botão touch J) arremessa.

const RED_CRATE_TEXTURE: Texture2D = preload("res://assets/sprites/props/soda_crate_red.png")
const GREEN_CRATE_TEXTURE: Texture2D = preload("res://assets/sprites/props/soda_crate_green.png")
const BOTTLE_PROFILE: HeldItemProfile = preload("res://resources/items/held_item_profiles/soda_glass_bottle.tres")
const BOTTLE_PROJECTILE_SCENE: PackedScene = preload("res://scenes/actors/projectiles/gas_bottle_projectile.tscn")
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

const HOLDING_GROUP: StringName = &"holding_gas_bottle"

@export_enum("Vermelho", "Verde") var crate_style: int = 0
@export_range(1, 12, 1) var bottles_remaining: int = 6
@export_range(24.0, 160.0, 1.0) var pickup_range_x: float = 96.0
@export_range(16.0, 100.0, 1.0) var pickup_depth_tolerance: float = 48.0

@onready var crate_sprite: Sprite2D = $Visual/Sprite2D as Sprite2D
@onready var pickup_area: Area2D = $PickupArea as Area2D

var _nearby_player: Node = null
var _holder: Node = null
var _registered_player: Node = null
var _held_item_component: HeldItemComponent = null
var _hint_button: Button = null


func _ready() -> void:
	y_sort_enabled = true
	add_to_group("gas_bottle_crates")
	_setup_crate_visual()
	_setup_pickup_area()
	_build_interaction_hint()
	set_process(false)


func _setup_crate_visual() -> void:
	if crate_sprite == null:
		return
	crate_sprite.texture = RED_CRATE_TEXTURE if crate_style == 0 else GREEN_CRATE_TEXTURE
	crate_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crate_sprite.region_enabled = false
	crate_sprite.scale = Vector2(0.22, 0.22)
	# Each PNG is tightly cropped with its alpha channel; keep the sprite's feet on the Y-sort anchor.
	var texture_height: float = crate_sprite.texture.get_height()
	crate_sprite.position = Vector2(0.0, -texture_height * crate_sprite.scale.y * 0.5)


func _setup_pickup_area() -> void:
	if pickup_area == null:
		return
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = 1
	pickup_area.monitoring = true
	pickup_area.monitorable = false
	if not pickup_area.body_entered.is_connected(_on_body_entered):
		pickup_area.body_entered.connect(_on_body_entered)
	if not pickup_area.body_exited.is_connected(_on_body_exited):
		pickup_area.body_exited.connect(_on_body_exited)


func _build_interaction_hint() -> void:
	_hint_button = Button.new()
	_hint_button.name = "PickUpHint"
	_hint_button.text = "Pegar"
	_hint_button.custom_minimum_size = Vector2(96.0, 48.0)
	_hint_button.size = Vector2(96.0, 48.0)
	_hint_button.position = Vector2(-48.0, -154.0)
	_hint_button.z_index = 100
	_hint_button.z_as_relative = false
	_hint_button.focus_mode = Control.FOCUS_NONE
	_hint_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint_button.add_theme_font_override("font", ARCADE_FONT)
	_hint_button.add_theme_font_size_override("font_size", 16)
	_hint_button.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62, 1.0))
	_hint_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_hint_button.add_theme_color_override("font_pressed_color", Color(0.72, 1.0, 0.84, 1.0))
	_hint_button.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.04, 1.0))
	_hint_button.add_theme_constant_override("outline_size", 4)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.025, 0.035, 0.055, 0.94)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(0.96, 0.76, 0.25, 0.96)
	normal_style.set_corner_radius_all(6)
	normal_style.content_margin_left = 12.0
	normal_style.content_margin_right = 12.0
	_hint_button.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.06, 0.09, 0.12, 0.98)
	hover_style.border_color = Color(1.0, 0.88, 0.48, 1.0)
	_hint_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.08, 0.15, 0.13, 0.98)
	pressed_style.border_color = Color(0.58, 1.0, 0.78, 1.0)
	_hint_button.add_theme_stylebox_override("pressed", pressed_style)

	_hint_button.pressed.connect(_on_hint_button_pressed)
	_hint_button.visible = false
	add_child(_hint_button)


func _on_body_entered(body: Node2D) -> void:
	if not _can_offer_to(body):
		return
	_nearby_player = body
	_set_registered_player(body)
	_set_hint_visible(true)


func _on_body_exited(body: Node2D) -> void:
	if body != _nearby_player:
		return
	_nearby_player = null
	if _holder != body:
		_set_hint_visible(false)
		_set_registered_player(null)


func _can_offer_to(player: Node) -> bool:
	return (
		player != null
		and is_instance_valid(player)
		and player.is_in_group("player")
		and not player.is_in_group(HOLDING_GROUP)
		and bottles_remaining > 0
		and _holder == null
	)


func _on_hint_button_pressed() -> void:
	if _nearby_player != null and is_instance_valid(_nearby_player):
		interact(_nearby_player)


## Contrato de interação chamado pelo PlayerController ao pressionar J.
func interact(player: Node) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	# Enquanto esta caixa mantém a garrafa registrada, o segundo J lança o item
	# mesmo que o jogador já tenha saído da pequena área física da caixa.
	if _holder == player and is_holding_bottle():
		return _throw_bottle(player)

	if not _can_offer_to(player):
		return false

	var offset: Vector2 = (player as Node2D).global_position - global_position
	if absf(offset.x) > pickup_range_x or absf(offset.y) > pickup_depth_tolerance:
		return false

	return _give_bottle(player)


func _give_bottle(player: Node) -> bool:
	# O componente é compartilhado por qualquer item equipável; não criamos um Sprite2D paralelo.
	_held_item_component = HeldItemComponent.attach_to_player(player)
	if _held_item_component == null:
		return false
	if not _held_item_component.equip_profile(BOTTLE_PROFILE):
		_held_item_component = null
		return false

	_holder = player
	player.add_to_group(HOLDING_GROUP)
	# Estoque ilimitado: o engradado nunca esgota suas garrafas.
	_nearby_player = player
	_set_registered_player(player)
	if _hint_button != null:
		_hint_button.text = "Arremessar"
		_hint_button.reparent(player, false)
		var visual_y: float = 0.0
		var visual_node := player.get_node_or_null("Visual") as Node2D
		if visual_node != null:
			visual_y = visual_node.position.y
		_hint_button.position = Vector2(-48.0, -250.0 + visual_y)
		_hint_button.visible = true
	set_process(true)
	return true


func _throw_bottle(player: Node) -> bool:
	var actor_parent: Node = player.get_parent()
	if actor_parent == null:
		return false

	var facing: float = 1.0
	if "facing_direction" in player:
		facing = -1.0 if float(player.get("facing_direction")) < 0.0 else 1.0

	var aim_direction: Vector2 = _get_throw_aim_direction(facing)
	var projectile := BOTTLE_PROJECTILE_SCENE.instantiate() as GasBottleProjectile
	if projectile == null:
		return false
	actor_parent.add_child(projectile)
	projectile.launch(player, facing, aim_direction)

	if _held_item_component != null and is_instance_valid(_held_item_component):
		_held_item_component.unequip_item(&"soda_glass_bottle")
	_held_item_component = null
	player.remove_from_group(HOLDING_GROUP)
	_holder = null
	set_process(false)

	var still_near: bool = pickup_area != null and pickup_area.overlaps_body(player)
	if _hint_button != null:
		_hint_button.reparent(self, false)
		_hint_button.text = "Pegar"
		_hint_button.position = Vector2(-48.0, -154.0)
	if still_near and bottles_remaining > 0:
		_nearby_player = player
		_set_registered_player(player)
		_set_hint_visible(true)
	else:
		_nearby_player = null
		_set_registered_player(null)
		_set_hint_visible(false)
	return true


## Resolve a mira a partir do mesmo InputMap usado pelo movimento do jogador.
## Sem eixo horizontal explícito, conserva o facing; W/S permitem lançar em diagonal
## para as pistas de profundidade. O mesmo contrato funciona com teclado, controle e touch.
func _get_throw_aim_direction(facing: float) -> Vector2:
	var horizontal: float = 0.0
	var vertical: float = 0.0
	if InputMap.has_action(&"move_right"):
		horizontal += Input.get_action_strength(&"move_right")
	if InputMap.has_action(&"move_left"):
		horizontal -= Input.get_action_strength(&"move_left")
	if InputMap.has_action(&"move_down"):
		vertical += Input.get_action_strength(&"move_down")
	if InputMap.has_action(&"move_up"):
		vertical -= Input.get_action_strength(&"move_up")

	if absf(horizontal) < 0.15:
		horizontal = -1.0 if facing < 0.0 else 1.0
	if absf(vertical) < 0.15:
		vertical = 0.0

	var direction := Vector2(horizontal, vertical)
	if direction.length_squared() < 0.01:
		direction = Vector2(-1.0 if facing < 0.0 else 1.0, 0.0)
	return direction.normalized()


func is_holding_bottle() -> bool:
	return (
		_holder != null
		and is_instance_valid(_holder)
		and _held_item_component != null
		and is_instance_valid(_held_item_component)
		and _held_item_component.is_holding_item(&"soda_glass_bottle")
	)


func get_bottles_remaining() -> int:
	return bottles_remaining


func _set_registered_player(player: Node) -> void:
	if _registered_player == player:
		return
	if _registered_player != null and is_instance_valid(_registered_player):
		if _registered_player.has_method("unregister_interactable"):
			_registered_player.call("unregister_interactable", self)
	_registered_player = null

	if player != null and is_instance_valid(player):
		_registered_player = player
		if _registered_player.has_method("register_interactable"):
			_registered_player.call("register_interactable", self)


func _set_hint_visible(should_be_visible: bool) -> void:
	if _hint_button == null:
		return
	if _holder != null and is_instance_valid(_holder):
		_hint_button.visible = true
		_hint_button.text = "Arremessar"
		return
	_hint_button.visible = should_be_visible and bottles_remaining > 0
	_hint_button.text = "Pegar"


func _process(_delta: float) -> void:
	if _holder == null or not is_instance_valid(_holder):
		return
	if _held_item_component != null and is_instance_valid(_held_item_component) and not _held_item_component.is_holding_item(&"soda_glass_bottle"):
		_holder.remove_from_group(HOLDING_GROUP)
		if _hint_button != null and is_instance_valid(_hint_button):
			_hint_button.reparent(self, false)
			_hint_button.text = "Pegar"
			_hint_button.position = Vector2(-48.0, -154.0)
			_hint_button.visible = false
		_holder = null
		_held_item_component = null
		set_process(false)
		return
	if _holder.has_method("register_interactable"):
		_holder.call("register_interactable", self)
	if _hint_button != null and is_instance_valid(_hint_button) and _hint_button.get_parent() == _holder:
		var visual_y: float = 0.0
		var visual_node := _holder.get_node_or_null("Visual") as Node2D
		if visual_node != null:
			visual_y = visual_node.position.y
		_hint_button.position = Vector2(-48.0, -250.0 + visual_y)


func _exit_tree() -> void:
	if _holder != null and is_instance_valid(_holder):
		_holder.remove_from_group(HOLDING_GROUP)
	if _held_item_component != null and is_instance_valid(_held_item_component):
		_held_item_component.unequip_item(&"soda_glass_bottle")
	if _hint_button != null and is_instance_valid(_hint_button):
		_hint_button.queue_free()
	_set_registered_player(null)
