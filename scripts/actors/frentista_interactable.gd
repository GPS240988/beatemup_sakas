extends "res://scripts/actors/npc.gd"

## Frentista NPC interativo do Posto Ipiranga (Mapa 5, Estágio 2).
## Exibe um ícone de exclamação (!) oscilante sobre a cabeça para indicar interação.
## Ao pressionar J quando próximo, abre o diálogo canônico com StandardDialogueBox.
## Registra-se como interactable usando o contrato register/unregister do PlayerController.

const FrentistaDialogueClass = preload("res://scripts/events/frentista_dialogue.gd")
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

## Raio curto de detecção: o jogador precisa se aproximar da posição do frentista.
const INTERACTION_RANGE_X: float = 28.0
## Tolerância de profundidade 2.5D.
const INTERACTION_DEPTH_Y: float = 16.0

## Cor dourada canônica do Projeto Sakas (identidade Dark Premium Medieval).
const EXCLAMATION_GOLD: Color = Color(0.94, 0.75, 0.39, 1.0)
const EXCLAMATION_OUTLINE: Color = Color(0.04, 0.035, 0.045, 1.0)

var _exclamation_label: Label = null
var _interaction_area: Area2D = null
var _interaction_player: Node = null
var _dialogue_active: bool = false
var _interaction_enabled: bool = true
var _bob_tween: Tween = null
var _interaction_cooldown: float = 0.0


func _ready() -> void:
	super._ready()
	_create_exclamation_icon()
	_create_interaction_area()
	set_process(false)


func _create_exclamation_icon() -> void:
	if visual_root == null:
		return
	_exclamation_label = Label.new()
	_exclamation_label.name = "ExclamationIcon"
	_exclamation_label.text = "!"
	_exclamation_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_exclamation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exclamation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Posição acima da cabeça do NPC (sprite 615px * 0.38 scale, centrado em -116.85)
	_exclamation_label.position = Vector2(-18.0, -268.0)
	_exclamation_label.size = Vector2(36.0, 48.0)

	var settings := LabelSettings.new()
	settings.font = ARCADE_FONT
	settings.font_size = 44
	settings.font_color = EXCLAMATION_GOLD
	settings.outline_size = 4
	settings.outline_color = EXCLAMATION_OUTLINE
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.90)
	settings.shadow_offset = Vector2(2, 2)
	_exclamation_label.label_settings = settings

	visual_root.add_child(_exclamation_label)
	_start_bob_animation()


func _start_bob_animation() -> void:
	if _exclamation_label == null:
		return
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	var base_y: float = _exclamation_label.position.y
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(
		_exclamation_label, "position:y",
		base_y - 10.0, 0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(
		_exclamation_label, "position:y",
		base_y, 0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _create_interaction_area() -> void:
	_interaction_area = Area2D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 1
	_interaction_area.monitoring = true
	_interaction_area.monitorable = false

	var shape_node := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(INTERACTION_RANGE_X * 2.0, INTERACTION_DEPTH_Y * 2.0)
	shape_node.shape = rect_shape
	_interaction_area.add_child(shape_node)
	add_child(_interaction_area)

	_interaction_area.body_entered.connect(_on_interaction_body_entered)
	_interaction_area.body_exited.connect(_on_interaction_body_exited)


## Bloqueia/desbloqueia J sem deixar um registro antigo no PlayerController.
func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if _interaction_area != null:
		_interaction_area.set_deferred("monitoring", enabled)
	if _exclamation_label != null:
		_exclamation_label.visible = enabled

	if not enabled:
		if _interaction_player != null and is_instance_valid(_interaction_player):
			if _interaction_player.has_method("unregister_interactable"):
				_interaction_player.call("unregister_interactable", self)
		_interaction_player = null
		set_process(false)


func _on_interaction_body_entered(body: Node) -> void:
	if not _interaction_enabled:
		return
	if body.is_in_group("player"):
		_interaction_player = body
		set_process(true)


func _on_interaction_body_exited(body: Node) -> void:
	if body == _interaction_player:
		if body.has_method("unregister_interactable"):
			body.call("unregister_interactable", self)
		_interaction_player = null
		set_process(false)


func _process(delta: float) -> void:
	if not _interaction_enabled:
		set_process(false)
		return
	if _interaction_cooldown > 0.0:
		_interaction_cooldown -= delta
		return
	if _interaction_player == null or not is_instance_valid(_interaction_player):
		_interaction_player = null
		set_process(false)
		return
	if not _dialogue_active and _interaction_player.has_method("register_interactable"):
		_interaction_player.call("register_interactable", self)


## Contrato de interação chamado pelo PlayerController ao pressionar J.
func interact(player: Node) -> bool:
	if not _interaction_enabled or _dialogue_active or _interaction_cooldown > 0.0:
		return false
	if player == null or not is_instance_valid(player):
		return false
	_open_dialogue()
	return true


func _open_dialogue() -> void:
	_dialogue_active = true
	enter_event()
	var dialogue: CanvasLayer = FrentistaDialogueClass.new() as CanvasLayer
	if dialogue == null:
		_dialogue_active = false
		change_state(default_state)
		return
	dialogue.name = "FrentistaDialogue"
	dialogue.connect("dialogue_closed", _on_dialogue_closed, CONNECT_ONE_SHOT)
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		tree.root.add_child(dialogue)
	else:
		_dialogue_active = false
		change_state(default_state)
		dialogue.queue_free()


func _on_dialogue_closed() -> void:
	_dialogue_active = false
	_interaction_cooldown = 0.5 # Previne reabertura em loop com o mesmo J que fechou o diálogo
	if _interaction_player != null and is_instance_valid(_interaction_player):
		if _interaction_player.has_method("unregister_interactable"):
			_interaction_player.call("unregister_interactable", self)
	change_state(default_state)
	if _interaction_enabled:
		set_process(true)


func get_exclamation_icon() -> Label:
	return _exclamation_label


func is_dialogue_active() -> bool:
	return _dialogue_active
