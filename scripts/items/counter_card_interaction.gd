extends Area2D

## Interação da carta no chão e de itens coletáveis dropados.
## A carta original mantém o comportamento existente; configure_item() permite
## reutilizar a mesma interação PEGAR/inspeção para outros itens do cenário.

const CARD_TEXTURE: Texture2D = preload("res://assets/sprites/Itens/lotus_branco.png")
const LOTUS_TEXTURE: Texture2D = preload("res://assets/sprites/Itens/lotus_branco_gg.webp")
const GABRIEL_PORTRAIT: Texture2D = preload("res://assets/ui/hud/portraits/portrait_gabriel.png")
const DIALOGUE_FRAME: Texture2D = preload("res://assets/ui/hud/dialog_frame_9patch.png")
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")

const DIALOGUE_TEXT: String = "Essa carta não deve valer R$0,05."
const BLINK_SPEED: float = 4.8

@onready var _card_sprite: Sprite2D = get_node_or_null("CardSprite") as Sprite2D
@onready var _interaction_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

var _world_texture: Texture2D = CARD_TEXTURE
var _inspect_texture: Texture2D = LOTUS_TEXTURE
var _display_name: String = "GABRIEL"
var _dialogue_message: String = DIALOGUE_TEXT
var _world_sprite_scale: Vector2 = Vector2(0.42, 0.42)
var _interaction_shape_size: Vector2 = Vector2(220.0, 110.0)
var _configured_as_drop_item: bool = false

var _blink_clock: float = 0.0
var _player_in_range: bool = false
var _already_read: bool = false
var _dialogue_open: bool = false
var _interacting_player: Node = null

var _hint_button: Button
var _nearby_player: Node = null
var _overlay_layer: CanvasLayer
var _expanded_card: TextureRect


## Configura uma instância como item dropado antes de adicioná-la à árvore.
## A inspeção, botão PEGAR, pausa e suporte mobile são os mesmos da carta da fase.
func configure_item(
	world_texture_path: String,
	inspect_texture_path: String,
	item_display_name: String,
	dialogue_message: String = ""
) -> void:
	_configured_as_drop_item = true
	_display_name = item_display_name if not item_display_name.is_empty() else "ITEM"
	_dialogue_message = dialogue_message if not dialogue_message.is_empty() else "Você encontrou: %s." % _display_name
	_world_texture = _load_item_texture(world_texture_path, CARD_TEXTURE, _display_name)
	_inspect_texture = _load_item_texture(inspect_texture_path, LOTUS_TEXTURE, _display_name)

	# Mantém o thumbnail pequeno, sem distorcer a proporção da arte original.
	var source_size: Vector2 = _world_texture.get_size() if _world_texture != null else Vector2.ZERO
	var max_dimension: float = maxf(source_size.x, source_size.y)
	var fitted_scale: float = 0.20
	if max_dimension > 0.0:
		fitted_scale = minf(0.42, 64.0 / max_dimension)
	_world_sprite_scale = Vector2.ONE * fitted_scale
	_interaction_shape_size = Vector2(54.0, 68.0)


func _load_item_texture(resource_path: String, fallback: Texture2D, item_name: String) -> Texture2D:
	if resource_path.is_empty():
		push_warning("Textura de inspeção/thumbnail vazia para '%s'; usando fallback." % item_name)
		return fallback
	if not ResourceLoader.exists(resource_path):
		push_error("Textura do item '%s' não encontrada: %s" % [item_name, resource_path])
		return fallback
	var loaded_texture := load(resource_path) as Texture2D
	if loaded_texture == null:
		push_error("Não foi possível carregar a textura do item '%s': %s" % [item_name, resource_path])
		return fallback
	return loaded_texture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _configured_as_drop_item:
		add_to_group("dropped_items")
	if _card_sprite != null:
		_card_sprite.texture = _world_texture
		_card_sprite.scale = _world_sprite_scale
	if _configured_as_drop_item and _interaction_shape != null and _interaction_shape.shape is RectangleShape2D:
		var unique_shape := (_interaction_shape.shape as RectangleShape2D).duplicate() as RectangleShape2D
		unique_shape.size = _interaction_shape_size
		_interaction_shape.shape = unique_shape
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_interaction_hint()
	_build_dialogue_overlay()


func _process(delta: float) -> void:
	if _already_read or _card_sprite == null:
		return

	_blink_clock += delta
	var pulse: float = (sin(_blink_clock * BLINK_SPEED) + 1.0) * 0.5
	_card_sprite.modulate.a = lerpf(0.48, 1.0, pulse)

	if _hint_button != null and _player_in_range:
		_hint_button.modulate.a = lerpf(0.72, 1.0, pulse)


func _input(event: InputEvent) -> void:
	if not _dialogue_open:
		return

	var continue_pressed: bool = false
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		continue_pressed = key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER
		)
	elif event is InputEventScreenTouch:
		continue_pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		continue_pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT

	if continue_pressed or event.is_action_pressed("ui_accept"):
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		_close_dialogue()


func interact(actor: Node) -> bool:
	if _already_read or _dialogue_open or actor == null:
		return false

	if not actor.is_in_group("player"):
		return false

	_interacting_player = actor
	if actor is CharacterBody2D:
		(actor as CharacterBody2D).velocity = Vector2.ZERO

	_dialogue_open = true
	if _hint_button != null:
		_hint_button.visible = false
	if _overlay_layer != null:
		_overlay_layer.visible = true
	_animate_card_reveal()

	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = true
	return true


func _on_body_entered(body: Node2D) -> void:
	if _already_read or not body.is_in_group("player"):
		return

	_player_in_range = true
	_nearby_player = body
	if _hint_button != null:
		_hint_button.visible = true
	if body.has_method("register_interactable"):
		body.call("register_interactable", self)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	_player_in_range = false
	if _nearby_player == body:
		_nearby_player = null
	if _hint_button != null:
		_hint_button.visible = false
	if body.has_method("unregister_interactable"):
		body.call("unregister_interactable", self)


func _close_dialogue() -> void:
	if not _dialogue_open:
		return

	_dialogue_open = false
	_already_read = true

	if _overlay_layer != null:
		_overlay_layer.visible = false
	if _card_sprite != null:
		_card_sprite.visible = false
	if _hint_button != null:
		_hint_button.visible = false

	monitoring = false
	_player_in_range = false

	if _interacting_player != null and is_instance_valid(_interacting_player):
		if _interacting_player.has_method("unregister_interactable"):
			_interacting_player.call("unregister_interactable", self)
	_interacting_player = null

	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false


func _build_interaction_hint() -> void:
	_hint_button = Button.new()
	_hint_button.name = "PickUpHint"
	_hint_button.text = "PEGAR"
	_hint_button.position = Vector2(-76.0, -68.0)
	_hint_button.size = Vector2(152.0, 40.0)
	_hint_button.focus_mode = Control.FOCUS_NONE
	_hint_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint_button.add_theme_font_override("font", ARCADE_FONT)
	_hint_button.add_theme_font_size_override("font_size", 15)
	_hint_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.54, 1.0))
	_hint_button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.76, 1.0))
	_hint_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.32, 1.0))
	_hint_button.add_theme_color_override("font_outline_color", Color(0.025, 0.025, 0.04, 1.0))
	_hint_button.add_theme_constant_override("outline_size", 4)

	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.025, 0.035, 0.055, 0.9)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(0.92, 0.69, 0.25, 0.95)
	normal_style.set_corner_radius_all(5)
	normal_style.content_margin_left = 8.0
	normal_style.content_margin_right = 8.0
	_hint_button.add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.12, 0.095, 0.045, 0.96)
	hover_style.border_color = Color(1.0, 0.84, 0.38, 1.0)
	_hint_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.22, 0.15, 0.055, 0.98)
	_hint_button.add_theme_stylebox_override("pressed", pressed_style)
	_hint_button.pressed.connect(_on_pickup_hint_pressed)
	_hint_button.visible = false
	add_child(_hint_button)


func _on_pickup_hint_pressed() -> void:
	if not _player_in_range or _already_read or _dialogue_open:
		return
	if _nearby_player == null or not is_instance_valid(_nearby_player):
		return
	interact(_nearby_player)


func _build_dialogue_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "CardInspectionOverlay"
	_overlay_layer.layer = 125
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_layer.visible = false
	add_child(_overlay_layer)

	var root: Control = Control.new()
	root.name = "OverlayRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.name = "DimBackground"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.012, 0.015, 0.028, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_expanded_card = TextureRect.new()
	_expanded_card.name = "EnlargedCard"
	_expanded_card.texture = _inspect_texture
	_expanded_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_expanded_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_expanded_card.anchor_left = 0.5
	_expanded_card.anchor_top = 0.5
	_expanded_card.anchor_right = 0.5
	_expanded_card.anchor_bottom = 0.5
	_expanded_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_expanded_card)
	_layout_expanded_card()
	get_viewport().size_changed.connect(_layout_expanded_card)

	var dialogue_frame: NinePatchRect = NinePatchRect.new()
	dialogue_frame.name = "GabrielDialogueFrame"
	dialogue_frame.texture = DIALOGUE_FRAME
	dialogue_frame.patch_margin_left = 14
	dialogue_frame.patch_margin_top = 14
	dialogue_frame.patch_margin_right = 14
	dialogue_frame.patch_margin_bottom = 14
	dialogue_frame.anchor_left = 0.055
	dialogue_frame.anchor_top = 0.70
	dialogue_frame.anchor_right = 0.945
	dialogue_frame.anchor_bottom = 0.97
	dialogue_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dialogue_frame)

	var portrait: TextureRect = TextureRect.new()
	portrait.name = "GabrielPortrait"
	portrait.texture = GABRIEL_PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.anchor_left = 0.075
	portrait.anchor_top = 0.715
	portrait.anchor_right = 0.18
	portrait.anchor_bottom = 0.955
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(portrait)

	var speaker_label: Label = Label.new()
	speaker_label.name = "SpeakerName"
	speaker_label.text = _display_name
	speaker_label.anchor_left = 0.205
	speaker_label.anchor_top = 0.72
	speaker_label.anchor_right = 0.91
	speaker_label.anchor_bottom = 0.785
	speaker_label.add_theme_font_override("font", ARCADE_FONT)
	speaker_label.add_theme_font_size_override("font_size", 18)
	speaker_label.add_theme_color_override("font_color", Color(0.94, 0.75, 0.39, 1.0))
	speaker_label.add_theme_color_override("font_outline_color", Color(0.04, 0.035, 0.045, 1.0))
	speaker_label.add_theme_constant_override("outline_size", 4)
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(speaker_label)

	var dialogue_label: Label = Label.new()
	dialogue_label.name = "DialogueText"
	dialogue_label.text = _dialogue_message
	dialogue_label.anchor_left = 0.205
	dialogue_label.anchor_top = 0.785
	dialogue_label.anchor_right = 0.91 if not MobileScreenAction.is_mobile_runtime() else 0.74
	dialogue_label.anchor_bottom = 0.905 if not MobileScreenAction.is_mobile_runtime() else 0.875
	dialogue_label.add_theme_font_override("font", ARCADE_FONT)
	dialogue_label.add_theme_font_size_override("font_size", 22)
	dialogue_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90, 1.0))
	dialogue_label.add_theme_color_override("font_outline_color", Color(0.035, 0.035, 0.045, 1.0))
	dialogue_label.add_theme_constant_override("outline_size", 3)
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dialogue_label)

	var continue_label: Label = Label.new()
	continue_label.name = "ContinuePrompt"
	continue_label.text = "TOQUE OU PRESSIONE ENTER PARA CONTINUAR"
	continue_label.anchor_left = 0.205
	continue_label.anchor_top = 0.905
	continue_label.anchor_right = 0.91
	continue_label.anchor_bottom = 0.96
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_override("font", ARCADE_FONT)
	continue_label.add_theme_font_size_override("font_size", 11)
	continue_label.add_theme_color_override("font_color", Color(0.78, 0.81, 0.87, 1.0))
	continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(continue_label)
	if MobileScreenAction.is_mobile_runtime():
		continue_label.visible = false
		MobileScreenAction.add_inline_primary_action(
			root,
			"AVANÇAR",
			Callable(self, "_close_dialogue"),
			Color(0.96, 0.73, 0.22, 1.0),
			0.77, 0.87, 0.95, 0.97
		)


func _layout_expanded_card() -> void:
	if _expanded_card == null or _inspect_texture == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var item_size: Vector2 = _inspect_texture.get_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or item_size.x <= 0.0 or item_size.y <= 0.0:
		return

	# Mantém a carta/arte inteiramente na área superior, sem invadir o diálogo.
	var top_margin: float = viewport_size.y * 0.035
	var dialogue_top: float = viewport_size.y * 0.70
	var dialogue_gap: float = maxf(12.0, viewport_size.y * 0.025)
	var available_height: float = maxf(1.0, dialogue_top - top_margin - dialogue_gap)
	var max_display_size: Vector2 = Vector2(viewport_size.x * 0.42, available_height)
	var fit_scale: float = minf(max_display_size.x / item_size.x, max_display_size.y / item_size.y)
	var display_size: Vector2 = item_size * fit_scale

	var display_center_y: float = top_margin + available_height * 0.5
	var center_offset_y: float = display_center_y - viewport_size.y * 0.5
	_expanded_card.offset_left = -display_size.x * 0.5
	_expanded_card.offset_top = center_offset_y - display_size.y * 0.5
	_expanded_card.offset_right = display_size.x * 0.5
	_expanded_card.offset_bottom = center_offset_y + display_size.y * 0.5
	_expanded_card.pivot_offset = display_size * 0.5


func _animate_card_reveal() -> void:
	if _expanded_card == null:
		return

	_expanded_card.scale = Vector2(0.08, 0.08)
	var reveal_tween: Tween = create_tween()
	reveal_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal_tween.tween_property(_expanded_card, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	if _dialogue_open:
		var tree: SceneTree = get_tree()
		if tree != null:
			tree.paused = false
