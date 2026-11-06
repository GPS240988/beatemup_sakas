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
const StandardDialogueBox = preload("res://scripts/ui/standard_dialogue_box.gd")

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
var _registered_player: Node = null

var _hint_button: Button
var _nearby_player: Node = null
var _overlay_layer: CanvasLayer
var _expanded_card: TextureRect
var _speaker_label: Label = null
var _dialogue_label: Label = null
var _portrait_rect: TextureRect = null
var _is_typing: bool = false
var _typewriter_tween: Tween = null


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

	if _speaker_label != null:
		_speaker_label.text = _display_name
	if _dialogue_label != null:
		_dialogue_label.text = _dialogue_message
	if _expanded_card != null:
		_expanded_card.texture = _inspect_texture


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
	# Para os itens dropados, todos disputam um único PEGAR: vence o item
	# elegível mais próximo do jogador. A carta original permanece inalterada.
	if _configured_as_drop_item:
		_refresh_drop_interaction_priority()

	if _already_read or _card_sprite == null:
		return

	_blink_clock += delta
	var pulse: float = (sin(_blink_clock * BLINK_SPEED) + 1.0) * 0.5
	_card_sprite.modulate.a = lerpf(0.48, 1.0, pulse)

	if _hint_button != null and _hint_button.visible:
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
		if _is_typing:
			_skip_typewriter()
			return
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
	if _configured_as_drop_item:
		_set_registered_player(null)
		_refresh_drop_group()
	if _hint_button != null:
		_hint_button.visible = false
	if _overlay_layer != null:
		_overlay_layer.visible = true
	_animate_card_reveal()
	_start_typewriter()

	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = true
	return true


func _on_body_entered(body: Node2D) -> void:
	if _already_read or not body.is_in_group("player"):
		return

	_player_in_range = true
	_nearby_player = body
	if _configured_as_drop_item:
		_refresh_drop_group()
		return

	if _hint_button != null:
		_hint_button.visible = true
	if body.has_method("register_interactable"):
		body.call("register_interactable", self)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if _configured_as_drop_item:
		if _nearby_player == body:
			_player_in_range = false
			_nearby_player = null
		if _registered_player == body:
			_set_registered_player(null)
		_refresh_drop_group()
		return

	_player_in_range = false
	if _nearby_player == body:
		_nearby_player = null
	if _hint_button != null:
		_hint_button.visible = false
	if body.has_method("unregister_interactable"):
		body.call("unregister_interactable", self)


## Retorna true apenas enquanto este item pode receber a interação PEGAR do player.
func can_offer_hint_to(player: Node) -> bool:
	return (
		_configured_as_drop_item
		and not _already_read
		and not _dialogue_open
		and _player_in_range
		and _nearby_player == player
	)


func is_dialogue_open_for_player(player: Node) -> bool:
	return _dialogue_open and _interacting_player == player


## Seleciona apenas um item próximo: menor distância; desempate pelo instance_id.
func _get_preferred_drop_for_player(player: Node) -> Area2D:
	if player == null or not is_instance_valid(player):
		return null

	var drop_nodes: Array[Node] = get_tree().get_nodes_in_group("dropped_items")
	for candidate: Node in drop_nodes:
		if candidate.has_method("is_dialogue_open_for_player") and candidate.call("is_dialogue_open_for_player", player):
			return null

	var preferred: Area2D = null
	var best_distance: float = INF
	for candidate: Node in drop_nodes:
		var candidate_item := candidate as Area2D
		if candidate_item == null or not candidate_item.has_method("can_offer_hint_to"):
			continue
		if not bool(candidate_item.call("can_offer_hint_to", player)):
			continue

		var distance_sq: float = candidate_item.global_position.distance_squared_to(player.global_position)
		if distance_sq < best_distance or (
			is_equal_approx(distance_sq, best_distance)
			and (preferred == null or candidate_item.get_instance_id() < preferred.get_instance_id())
		):
			best_distance = distance_sq
			preferred = candidate_item
	return preferred


func _refresh_drop_interaction_priority() -> void:
	if not _configured_as_drop_item:
		return

	var preferred: Area2D = _get_preferred_drop_for_player(_nearby_player)
	var owns_hint: bool = preferred == self and _nearby_player != null
	if _hint_button != null:
		_hint_button.visible = owns_hint
	_set_registered_player(_nearby_player if owns_hint else null)


## Recalcula os dois itens juntos para não deixar um botão antigo visível por um frame.
func _refresh_drop_group() -> void:
	if get_tree() == null:
		return
	for candidate: Node in get_tree().get_nodes_in_group("dropped_items"):
		if candidate.has_method("_refresh_drop_interaction_priority"):
			candidate.call("_refresh_drop_interaction_priority")


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


func _close_dialogue() -> void:
	if not _dialogue_open:
		return

	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	_is_typing = false
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

	if _configured_as_drop_item:
		_set_registered_player(null)
	if _interacting_player != null and is_instance_valid(_interacting_player):
		if _interacting_player.has_method("unregister_interactable"):
			_interacting_player.call("unregister_interactable", self)
	_interacting_player = null

	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false
	if _configured_as_drop_item:
		_refresh_drop_group()


func _start_typewriter() -> void:
	if _dialogue_label == null:
		return
	var text_len: int = _dialogue_label.text.length()
	if text_len == 0:
		_is_typing = false
		return
	_dialogue_label.visible_characters = 0
	_is_typing = true
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	_typewriter_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var duration: float = float(text_len) / StandardDialogueBox.TYPEWRITER_SPEED_CPS
	_typewriter_tween.tween_property(_dialogue_label, "visible_characters", text_len, duration)
	_typewriter_tween.tween_callback(func():
		_is_typing = false
	)


func _skip_typewriter() -> void:
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	if _dialogue_label != null:
		_dialogue_label.visible_characters = -1
	_is_typing = false


func _on_mobile_advance_pressed() -> void:
	if _is_typing:
		_skip_typewriter()
		return
	_close_dialogue()


## Touch-anywhere no diálogo para avançar (padrão mobile)
func _on_mobile_dialogue_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_mobile_advance_pressed()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_mobile_advance_pressed()


func _build_interaction_hint() -> void:
	_hint_button = Button.new()
	_hint_button.name = "PickUpHint"
	_hint_button.text = "PEGAR"
	_hint_button.position = Vector2(-76.0, -68.0)
	_hint_button.size = Vector2(152.0, 40.0)
	_hint_button.z_index = 100
	_hint_button.z_as_relative = false
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
	dim.color = StandardDialogueBox.DIM_BACKGROUND_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_expanded_card = TextureRect.new()
	_expanded_card.name = "EnlargedCard"
	_expanded_card.texture = _inspect_texture
	_expanded_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_expanded_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_expanded_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_expanded_card.anchor_left = 0.5
	_expanded_card.anchor_top = 0.5
	_expanded_card.anchor_right = 0.5
	_expanded_card.anchor_bottom = 0.5
	_expanded_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_expanded_card)
	_layout_expanded_card()
	get_viewport().size_changed.connect(_layout_expanded_card)

	var is_mobile: bool = MobileScreenAction.is_mobile_runtime()
	var ui_nodes: Dictionary = StandardDialogueBox.build_dialogue_ui(root, is_mobile)
	_portrait_rect = ui_nodes["portrait"] as TextureRect
	_speaker_label = ui_nodes["speaker_label"] as Label
	_dialogue_label = ui_nodes["dialogue_label"] as Label

	_speaker_label.text = _display_name
	_dialogue_label.text = _dialogue_message

	var continue_prompt := ui_nodes["continue_label"] as Label
	if is_mobile:
		continue_prompt.visible = true
		# Touch-anywhere-to-advance: toque em qualquer parte do diálogo avança o texto
		var dialogue_area_ctrl := ui_nodes["dialogue_area"] as Control
		if dialogue_area_ctrl != null:
			dialogue_area_ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
			if not dialogue_area_ctrl.is_connected("gui_input", Callable(self, "_on_mobile_dialogue_touch")):
				dialogue_area_ctrl.connect("gui_input", Callable(self, "_on_mobile_dialogue_touch"))


func _layout_expanded_card() -> void:
	if _expanded_card == null or _inspect_texture == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var item_size: Vector2 = _inspect_texture.get_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or item_size.x <= 0.0 or item_size.y <= 0.0:
		return

	# Mantém a carta/arte inteiramente na área superior, sem invadir o diálogo.
	var is_mobile: bool = MobileScreenAction.is_mobile_runtime()
	var top_margin: float = viewport_size.y * (0.02 if is_mobile else 0.035)
	var dialogue_top: float = viewport_size.y * (0.78 if is_mobile else 0.70)
	var dialogue_gap: float = maxf(8.0 if is_mobile else 12.0, viewport_size.y * 0.02)
	var available_height: float = maxf(1.0, dialogue_top - top_margin - dialogue_gap)
	var max_display_size: Vector2 = Vector2(viewport_size.x * (0.55 if is_mobile else 0.42), available_height)
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
	if _registered_player != null and is_instance_valid(_registered_player):
		if _registered_player.has_method("unregister_interactable"):
			_registered_player.call("unregister_interactable", self)
	_registered_player = null
	if _dialogue_open:
		var tree: SceneTree = get_tree()
		if tree != null:
			tree.paused = false
