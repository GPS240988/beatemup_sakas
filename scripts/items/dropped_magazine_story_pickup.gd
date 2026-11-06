class_name DroppedMagazineStoryPickup
extends Area2D

## Item de revista dropado pela caixa da Fase 1-1.
## Usa o NarrativeDirector oficial do jogo para imagem, revelação, retrato,
## diálogo do Gabriel, moldura, transições e avanço manual por teclado/toque.

const STORY_EVENT_SCRIPT: Script = preload("res://scripts/events/story_event.gd")
const STORY_SEQUENCE_SCRIPT: Script = preload("res://scripts/events/story_sequence.gd")
const FALLBACK_TEXTURE: Texture2D = preload("res://assets/sprites/Itens/lotus_branco.png")
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const GABRIEL_PORTRAIT: Texture2D = preload("res://assets/ui/hud/portraits/portrait_gabriel.png")
const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")
const StandardDialogueBox = preload("res://scripts/ui/standard_dialogue_box.gd")
const BLINK_SPEED: float = 4.8
const DROPPED_ITEMS_GROUP: StringName = &"dropped_magazine_items"

@onready var _card_sprite: Sprite2D = get_node_or_null("CardSprite") as Sprite2D
@onready var _interaction_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

var _world_texture_path: String = ""
var _inspect_texture_path: String = ""
var _display_name: String = "ITEM"
var _dialogue_message: String = ""
var _world_texture: Texture2D = FALLBACK_TEXTURE
var _inspect_texture: Texture2D = FALLBACK_TEXTURE
var _blink_clock: float = 0.0
var _player_in_range: bool = false
var _dialogue_open: bool = false
var _consumed: bool = false
var _nearby_player: Node = null
var _registered_player: Node = null
var _interacting_player: Node = null
var _hint_button: Button

var _overlay_layer: CanvasLayer = null
var _expanded_card: TextureRect = null
var _speaker_label: Label = null
var _dialogue_label: Label = null
var _portrait_rect: TextureRect = null
var _is_typing: bool = false
var _typewriter_tween: Tween = null


## Chamado pelo GamesBoxDropController antes de a instância entrar na árvore.
func configure_item(
	world_texture_path: String,
	inspect_texture_path: String,
	item_display_name: String,
	dialogue_message: String
) -> void:
	_world_texture_path = world_texture_path
	_inspect_texture_path = inspect_texture_path
	_display_name = item_display_name.strip_edges().to_upper() if not item_display_name.strip_edges().is_empty() else "ITEM"
	_dialogue_message = dialogue_message.strip_edges()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	y_sort_enabled = true
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	add_to_group(DROPPED_ITEMS_GROUP)

	_world_texture = _load_texture(_world_texture_path, _display_name + " thumbnail")
	_inspect_texture = _load_texture(_inspect_texture_path, _display_name + " artwork")

	if _card_sprite != null:
		_card_sprite.texture = _world_texture
		_card_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_card_sprite.scale = _fit_world_sprite(_world_texture)

	if _interaction_shape != null and _interaction_shape.shape is RectangleShape2D:
		var unique_shape := (_interaction_shape.shape as RectangleShape2D).duplicate() as RectangleShape2D
		unique_shape.size = Vector2(54.0, 68.0)
		_interaction_shape.shape = unique_shape

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_interaction_hint()


func _process(delta: float) -> void:
	if _nearby_player != null and is_instance_valid(_nearby_player):
		_refresh_group_for_player(_nearby_player)

	if _consumed or _card_sprite == null:
		return

	_blink_clock += delta
	var pulse: float = (sin(_blink_clock * BLINK_SPEED) + 1.0) * 0.5
	_card_sprite.modulate.a = lerpf(0.58, 1.0, pulse)
	if _hint_button != null and _hint_button.visible:
		_hint_button.modulate.a = lerpf(0.78, 1.0, pulse)


func _load_texture(resource_path: String, resource_label: String) -> Texture2D:
	if resource_path.is_empty():
		return FALLBACK_TEXTURE
	if not ResourceLoader.exists(resource_path):
		push_error("Textura do drop '%s' não encontrada: %s" % [resource_label, resource_path])
		return FALLBACK_TEXTURE
	var texture := load(resource_path) as Texture2D
	if texture == null:
		push_error("Falha ao carregar a textura do drop '%s': %s" % [resource_label, resource_path])
		return FALLBACK_TEXTURE
	return texture


func _fit_world_sprite(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE * 0.20
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2.ONE * 0.20
	# Arte pequena no chão, mantendo proporção e sem deformar a capa.
	var fitted_scale: float = minf(58.0 / source_size.x, 64.0 / source_size.y)
	return Vector2.ONE * minf(fitted_scale, 0.42)


func _build_interaction_hint() -> void:
	_hint_button = Button.new()
	_hint_button.name = "PickUpHint"
	_hint_button.text = "PEGAR"
	_hint_button.position = Vector2(-76.0, -68.0)
	_hint_button.size = Vector2(152.0, 40.0)
	# O indicador precisa ficar na camada visual dianteira da caixa destruída.
	# Z absoluto impede que o Y-sort do chão o desenhe atrás do sprite do prop.
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

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.025, 0.035, 0.055, 0.92)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(0.92, 0.69, 0.25, 0.95)
	normal_style.set_corner_radius_all(5)
	normal_style.content_margin_left = 8.0
	normal_style.content_margin_right = 8.0
	_hint_button.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.12, 0.095, 0.045, 0.96)
	hover_style.border_color = Color(1.0, 0.84, 0.38, 1.0)
	_hint_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.22, 0.15, 0.055, 0.98)
	_hint_button.add_theme_stylebox_override("pressed", pressed_style)
	_hint_button.pressed.connect(_on_pickup_hint_pressed)
	_hint_button.visible = false
	add_child(_hint_button)


func _on_body_entered(body: Node2D) -> void:
	if _consumed or not body.is_in_group("player"):
		return
	_player_in_range = true
	_nearby_player = body
	_refresh_group_for_player(body)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _nearby_player == body:
		_player_in_range = false
		_nearby_player = null
	if _registered_player == body:
		_set_registered_player(null)
	_refresh_group_for_player(body)


func can_offer_hint_to(player: Node) -> bool:
	return (
		not _consumed
		and not _dialogue_open
		and _player_in_range
		and _nearby_player == player
	)


func is_dialogue_open_for_player(player: Node) -> bool:
	return _dialogue_open and _interacting_player == player


## Resolve um único PEGAR entre todos os drops próximos do mesmo jogador.
## A menor distância vence; instance_id desempata distâncias idênticas.
func _refresh_group_for_player(player: Node) -> void:
	if get_tree() == null or player == null or not is_instance_valid(player):
		return

	var items: Array[Node] = get_tree().get_nodes_in_group(DROPPED_ITEMS_GROUP)
	var dialogue_already_open: bool = false
	for candidate: Node in items:
		if candidate.has_method("is_dialogue_open_for_player") and candidate.call("is_dialogue_open_for_player", player):
			dialogue_already_open = true
			break

	if not (player is Node2D):
		return
	var player_2d := player as Node2D
	var preferred: DroppedMagazineStoryPickup = null
	var best_distance: float = INF
	if not dialogue_already_open:
		for candidate: Node in items:
			var item := candidate as DroppedMagazineStoryPickup
			if item == null or not item.can_offer_hint_to(player):
				continue
			var distance_sq: float = item.global_position.distance_squared_to(player_2d.global_position)
			if distance_sq < best_distance or (
				is_equal_approx(distance_sq, best_distance)
				and (preferred == null or item.get_instance_id() < preferred.get_instance_id())
			):
				best_distance = distance_sq
				preferred = item

	for candidate: Node in items:
		var item := candidate as DroppedMagazineStoryPickup
		if item == null:
			continue
		var selected: bool = item == preferred
		item._set_hint_visible(selected)
		item._set_registered_player(player if selected else null)


func _set_hint_visible(should_be_visible: bool) -> void:
	if _hint_button != null:
		_hint_button.visible = should_be_visible and not _dialogue_open and not _consumed


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
	if _consumed or _dialogue_open or actor == null or not actor.is_in_group("player"):
		return false
	if not can_offer_hint_to(actor):
		return false

	_dialogue_open = true
	_interacting_player = actor
	if actor is CharacterBody2D:
		(actor as CharacterBody2D).velocity = Vector2.ZERO
	_set_registered_player(null)
	_refresh_group_for_player(actor)

	_show_inspection_overlay()
	return true


func _on_pickup_hint_pressed() -> void:
	if _nearby_player == null or not is_instance_valid(_nearby_player):
		return
	interact(_nearby_player)


func _show_inspection_overlay() -> void:
	if _overlay_layer == null:
		_build_dialogue_overlay()
	_overlay_layer.visible = true
	_animate_card_reveal()
	_start_typewriter()

	var tree := get_tree()
	if tree != null:
		tree.paused = true


func _build_dialogue_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "DroppedItemInspectionOverlay"
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
	_expanded_card.name = "EnlargedItem"
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

	_speaker_label.text = "GABRIEL"
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


func _close_dialogue() -> void:
	if not _dialogue_open:
		return

	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	_is_typing = false
	_dialogue_open = false
	_consumed = true

	if _overlay_layer != null:
		_overlay_layer.visible = false
	if _card_sprite != null:
		_card_sprite.visible = false
	if _hint_button != null:
		_hint_button.visible = false

	monitoring = false
	_player_in_range = false

	var tree := get_tree()
	if tree != null:
		tree.paused = false

	_set_hint_visible(false)
	_set_registered_player(null)
	remove_from_group(DROPPED_ITEMS_GROUP)

	var player := _interacting_player
	_interacting_player = null
	if player != null and is_instance_valid(player):
		if player.has_method("unregister_interactable"):
			player.call("unregister_interactable", self)
		_refresh_group_for_player(player)

	queue_free()


## Constrói um evento declarativo compatível com o sistema oficial de história.
## Mantido para interoperabilidade com o runner de testes e contratos existentes.
func build_dialogue_sequence() -> Resource:
	var dialogue_event: Resource = STORY_EVENT_SCRIPT.new()
	dialogue_event.set("id", "drop_%s" % _display_name.to_lower())
	dialogue_event.set("event_type", "dialogue")
	dialogue_event.set("image_path", _inspect_texture_path)
	var event_texts: Array[String] = [_dialogue_message]
	var event_speakers: Array[String] = ["GABRIEL"]
	dialogue_event.set("texts", event_texts)
	dialogue_event.set("speaker", "GABRIEL")
	dialogue_event.set("speakers", event_speakers)
	dialogue_event.set("duration_per_text", 4.0)
	dialogue_event.set("entry_effect", "fade_in")
	dialogue_event.set("exit_effect", "fade_out")
	dialogue_event.set("transition_duration", 0.32)
	dialogue_event.set("pause_after", 0.4)
	dialogue_event.set("safe_framing", true)
	dialogue_event.set("hide_panel_initially", false)

	var events: Array[Resource] = [dialogue_event]
	var sequence: Resource = STORY_SEQUENCE_SCRIPT.new()
	sequence.set("sequence_id", "drop_item_%s" % _display_name.to_lower())
	sequence.set("events", events)
	return sequence


func _exit_tree() -> void:
	_set_registered_player(null)
	if _dialogue_open:
		var tree := get_tree()
		if tree != null:
			tree.paused = false
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		_overlay_layer.queue_free()
