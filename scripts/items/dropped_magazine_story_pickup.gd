class_name DroppedMagazineStoryPickup
extends Area2D

## Item de revista dropado pela caixa da Fase 1-1.
## Usa o NarrativeDirector oficial do jogo para imagem, revelação, retrato,
## diálogo do Gabriel, moldura, transições e avanço manual por teclado/toque.

const NARRATIVE_DIRECTOR_SCENE: PackedScene = preload("res://scenes/ui/narrative_director.tscn")
const ITEM_NARRATIVE_DIRECTOR_SCRIPT: Script = preload("res://scripts/events/narrative_director_item.gd")
const STORY_EVENT_SCRIPT: Script = preload("res://scripts/events/story_event.gd")
const STORY_SEQUENCE_SCRIPT: Script = preload("res://scripts/events/story_sequence.gd")
const FALLBACK_TEXTURE: Texture2D = preload("res://assets/sprites/Itens/lotus_branco.png")
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
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
var _active_narrative_director: Node = null
var _session_flag_captured: bool = false
var _session_had_played_intro: bool = false
var _hint_button: Button


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
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
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

	return _start_story_dialogue()


func _on_pickup_hint_pressed() -> void:
	if _nearby_player == null or not is_instance_valid(_nearby_player):
		return
	interact(_nearby_player)


## Constrói um evento declarativo compatível com o sistema oficial de história.
## O NarrativeDirector cuida da revelação da arte, retrato, moldura e fala manual.
func build_dialogue_sequence() -> Resource:
	var dialogue_event: Resource = STORY_EVENT_SCRIPT.new()
	dialogue_event.set("id", "drop_%s" % _display_name.to_lower())
	dialogue_event.set("event_type", "dialogue")
	dialogue_event.set("image_path", _inspect_texture_path)
	# Use arrays tipados por declaração; evite construtores Array[String](...).
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


func _start_story_dialogue() -> bool:
	if NARRATIVE_DIRECTOR_SCENE == null:
		push_error("Cena res://scenes/ui/narrative_director.tscn não encontrada.")
		_dialogue_open = false
		_interacting_player = null
		_refresh_group_for_player(_nearby_player)
		return false

	var tree := get_tree()
	if tree == null:
		_dialogue_open = false
		_interacting_player = null
		return false

	_capture_intro_session_flag()
	_active_narrative_director = NARRATIVE_DIRECTOR_SCENE.instantiate()
	if _active_narrative_director == null:
		push_error("Não foi possível instanciar o NarrativeDirector.")
		_dialogue_open = false
		_interacting_player = null
		_restore_intro_session_flag()
		return false

	# A apresentação de revistas usa o NarrativeDirector oficial, mas substitui
	# somente o modo de enquadramento da arte: centralizado e sem crop/zoom.
	_active_narrative_director.set_script(ITEM_NARRATIVE_DIRECTOR_SCRIPT)
	_active_narrative_director.process_mode = Node.PROCESS_MODE_ALWAYS
	_active_narrative_director.connect(
		"sequence_completed", _on_narrative_sequence_finished, CONNECT_ONE_SHOT
	)
	tree.root.add_child(_active_narrative_director)
	tree.paused = true
	_active_narrative_director.call("play_sequence", build_dialogue_sequence())
	return true


func _capture_intro_session_flag() -> void:
	_session_flag_captured = false
	var session := get_node_or_null("/root/GameSession")
	if session != null and "has_played_intro" in session:
		_session_had_played_intro = bool(session.get("has_played_intro"))
		_session_flag_captured = true


func _restore_intro_session_flag() -> void:
	if not _session_flag_captured:
		return
	var session := get_node_or_null("/root/GameSession")
	if session != null and "has_played_intro" in session:
		session.set("has_played_intro", _session_had_played_intro)
	_session_flag_captured = false


func _on_narrative_sequence_finished(_sequence_id: String) -> void:
	_restore_intro_session_flag()
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	_dialogue_open = false
	_consumed = true
	_set_hint_visible(false)
	_set_registered_player(null)
	remove_from_group(DROPPED_ITEMS_GROUP)
	monitoring = false

	if _active_narrative_director != null and is_instance_valid(_active_narrative_director):
		_active_narrative_director.queue_free()
	_active_narrative_director = null

	var player := _interacting_player
	_interacting_player = null
	if player != null and is_instance_valid(player):
		if player.has_method("unregister_interactable"):
			player.call("unregister_interactable", self)
		_refresh_group_for_player(player)
	queue_free()


func _exit_tree() -> void:
	_restore_intro_session_flag()
	_set_registered_player(null)
	if _dialogue_open:
		var tree := get_tree()
		if tree != null:
			tree.paused = false
	if _active_narrative_director != null and is_instance_valid(_active_narrative_director):
		_active_narrative_director.queue_free()
