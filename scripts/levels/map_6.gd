extends "res://scripts/levels/base_level.gd"

## Interlúdio jogável da entrada da HAPPEN.
## Somente o herói selecionado e Pelé são atores vivos no mundo; os demais
## protagonistas aparecem na arte narrativa e nos retratos do diálogo.

const Map6DialogueSequenceClass = preload("res://scripts/events/map6_dialogue_sequence.gd")
const NEXT_MAP_SCENE_PATH: String = "res://scenes/levels/map_7.tscn"
const STORY_BACKGROUND_PATH: String = "res://assets/backgrounds/maps/fase2/story_happen.webp"
const PLAYER_START_POSITION: Vector2 = Vector2(930.0, 730.0)
const PLAYER_WALKABLE_BOUNDS: Rect2 = Rect2(220.0, 682.0, 1270.0, 78.0)

var _pele: Node = null
var _dialogue_sequence: CanvasLayer = null
var _event_active: bool = false
var _negotiation_completed: bool = false
var _player_physics_was_enabled: bool = true
var _actors_layer: CanvasItem = null
var _actors_layer_was_visible: bool = true


func _ready() -> void:
	player = get_player()
	if player == null:
		push_error("Map6: Player não encontrado em World/Actors/Player.")
		super._ready()
		return

	_configure_player()
	_pele = get_node_or_null("World/Actors/Pele")
	if _pele != null:
		if _pele.has_method("set_interaction_enabled"):
			_pele.call("set_interaction_enabled", false)
		if _pele.has_signal("interaction_requested") and not _pele.is_connected("interaction_requested", _on_pele_interaction_requested):
			_pele.connect("interaction_requested", _on_pele_interaction_requested)

	next_map_scene_path = NEXT_MAP_SCENE_PATH
	is_final_map = false
	map_name = "HAPPEN — DOIS NO RODÍZIO"
	map_group = "fase2"
	stage_number = 2
	section_number = 2
	map_index = 2
	camera_min_x = 640.0
	camera_max_x = 1032.0
	camera_fixed_y = 470.0
	camera_follow_speed = 10.0
	super._ready()

	# Somente o diálogo de chegada toca automaticamente. Pelé permanece
	# indisponível até o jogador se aproximar e interagir com ele.
	call_deferred("_begin_arrival_sequence")


func _configure_player() -> void:
	player.position = PLAYER_START_POSITION
	player.enable_manual_bounds = true
	player.walkable_bounds = PLAYER_WALKABLE_BOUNDS
	player.velocity = Vector2.ZERO
	player.facing_direction = 1.0
	if player.visual_root != null:
		player.visual_root.scale.x = absf(player.visual_root.scale.x)


func _on_pele_interaction_requested(_pele_node: Node, interacting_player: Node) -> void:
	if interacting_player != player or _negotiation_completed:
		return
	_begin_negotiation_sequence()


func _begin_arrival_sequence() -> void:
	if _event_active or _negotiation_completed or player == null or not is_instance_valid(player):
		return
	_event_active = true
	_player_physics_was_enabled = player.is_physics_processing()
	_suspend_player_for_dialogue()

	if _pele != null:
		if _pele.has_method("set_interaction_enabled"):
			_pele.call("set_interaction_enabled", false)
		if _pele.has_method("set_dialogue_active"):
			_pele.call("set_dialogue_active", false)

	_dialogue_sequence = _create_dialogue_sequence("arrival")


func _begin_negotiation_sequence() -> void:
	if _event_active or _negotiation_completed or player == null or not is_instance_valid(player):
		return
	_event_active = true
	_player_physics_was_enabled = player.is_physics_processing()
	_suspend_player_for_dialogue()

	if ResourceLoader.exists(STORY_BACKGROUND_PATH):
		_actors_layer = get_node_or_null("World/Actors") as CanvasItem
		if _actors_layer != null:
			_actors_layer_was_visible = _actors_layer.visible
			_actors_layer.visible = false
	else:
		push_error("Map6: arte da negociação da HAPPEN não encontrada: " + STORY_BACKGROUND_PATH)

	if _pele != null and _pele.has_method("set_dialogue_active"):
		_pele.call("set_dialogue_active", true)

	_dialogue_sequence = _create_dialogue_sequence("negotiation")


func _create_dialogue_sequence(start_mode: String) -> CanvasLayer:
	var sequence: CanvasLayer = Map6DialogueSequenceClass.new() as CanvasLayer
	sequence.name = "Map6HappenDialogue"
	sequence.set("start_mode", start_mode)
	sequence.connect("speaker_line", Callable(self, "_on_dialogue_speaker_line"))
	if start_mode == "negotiation":
		sequence.connect("sequence_finished", Callable(self, "_on_dialogue_sequence_finished"), CONNECT_ONE_SHOT)
	else:
		sequence.connect("arrival_finished", Callable(self, "_on_arrival_sequence_finished"), CONNECT_ONE_SHOT)
	add_child(sequence)
	return sequence


func _suspend_player_for_dialogue() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.velocity = Vector2.ZERO
	if player.anim_sprite != null and player.anim_sprite.sprite_frames != null and player.anim_sprite.sprite_frames.has_animation("idle"):
		player.anim_sprite.play("idle")
	player.set_physics_process(false)


func _on_arrival_sequence_finished() -> void:
	_dialogue_sequence = null
	_event_active = false
	if player != null and is_instance_valid(player) and _player_physics_was_enabled:
		player.set_physics_process(true)
	if _pele != null and is_instance_valid(_pele):
		if _pele.has_method("set_dialogue_active"):
			_pele.call("set_dialogue_active", false)
		if _pele.has_method("set_interaction_enabled"):
			_pele.call("set_interaction_enabled", true)


func _on_dialogue_speaker_line(speaker: String, action: String) -> void:
	if speaker.strip_edges().to_upper() != "PELÉ" or _pele == null:
		return
	if not _pele.has_method("play_animation") or action.is_empty():
		return

	var animation_name: String = action
	match action:
		"skeptical":
			animation_name = "reaction_skeptical"
		"amused":
			animation_name = "reaction_amused"
		"idle_neutral", "idle_attentive", "reaction_skeptical", "reaction_amused", "gesture_stop", "gesture_allow_entry":
			pass
	_pele.call("play_animation", animation_name)


func _on_dialogue_sequence_finished() -> void:
	if not _event_active:
		return
	_dialogue_sequence = null
	_negotiation_completed = true
	if _pele != null and is_instance_valid(_pele):
		if _pele.has_method("set_dialogue_active"):
			_pele.call("set_dialogue_active", false)
		if _pele.has_method("set_interaction_enabled"):
			_pele.call("set_interaction_enabled", false)

	# A sequência já executou o push-in pela porta e o fade para preto.
	if ResourceLoader.exists(NEXT_MAP_SCENE_PATH):
		_event_active = false
		_advance_to_next_map()
		return

	# Fallback temporário até o interior da HAPPEN (Map 7) ser implementado.
	push_warning("Map6 concluído. res://scenes/levels/map_7.tscn ainda não existe; aguardando implementação do interior da HAPPEN.")
	await _restore_map6_after_missing_map7()


func _restore_map6_after_missing_map7() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "Map6FallbackFade"
	fade_layer.layer = 126
	fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fade_layer)

	var overlay := ColorRect.new()
	overlay.name = "BlackOverlay"
	overlay.color = Color.BLACK
	overlay.modulate.a = 1.0
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(overlay)

	if _actors_layer != null and is_instance_valid(_actors_layer):
		_actors_layer.visible = _actors_layer_was_visible
	if player != null and is_instance_valid(player) and _player_physics_was_enabled:
		player.set_physics_process(true)
	_event_active = false

	var fade_tween := create_tween()
	fade_tween.tween_property(overlay, "modulate:a", 0.0, 0.68).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_tween.finished
	fade_layer.queue_free()


func _setup_level_bgm() -> void:
	super._setup_level_bgm()
