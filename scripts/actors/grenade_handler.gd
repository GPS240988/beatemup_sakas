class_name GabrielGrenadeHandler
extends Node

## Habilidade contextual de granada de Gabriel.
## Duas cargas são concedidas ao instanciar o jogador em cada mapa.
## A tecla H é remapeada de guarda para granada somente quando Gabriel está ativo.

signal grenades_changed(remaining: int, maximum: int)

const GRENADE_SCENE: PackedScene = preload("res://scenes/actors/projectiles/player_grenade.tscn")
const MAX_GRENADES: int = 2

var grenades_remaining: int = MAX_GRENADES
var _player: Node2D = null


func _ready() -> void:
	_player = get_parent() as Node2D
	set_process(true)
	# O PlayerController registra os atalhos no próprio _ready().
	# Adiar a configuração garante que o H não seja recolocado em guard depois da troca.
	call_deferred("_configure_input_mapping")
	grenades_changed.emit(grenades_remaining, MAX_GRENADES)


func _process(_delta: float) -> void:
	if not _is_gabriel():
		return
	if InputMap.has_action("throw_grenade") and Input.is_action_just_pressed("throw_grenade"):
		throw_grenade()


func _is_gabriel() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	return _player.has_method("is_gabriel") and bool(_player.call("is_gabriel"))


func set_grenades_remaining(value: int) -> void:
	grenades_remaining = clampi(value, 0, MAX_GRENADES)
	grenades_changed.emit(grenades_remaining, MAX_GRENADES)


func _configure_input_mapping() -> void:
	if not InputMap.has_action("throw_grenade"):
		InputMap.add_action("throw_grenade")

	if _is_gabriel():
		_remove_physical_key("guard", KEY_H)
		_add_physical_key("throw_grenade", KEY_H)
	else:
		_remove_physical_key("throw_grenade", KEY_H)
		# Outros heróis preservam o comportamento legado: H continua sendo guarda.
		_add_physical_key("guard", KEY_H)


func _remove_physical_key(action_name: StringName, key: Key) -> void:
	if not InputMap.has_action(action_name):
		return
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.physical_keycode == key or key_event.keycode == key:
				InputMap.action_erase_event(action_name, event)


func _add_physical_key(action_name: StringName, key: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.physical_keycode == key or key_event.keycode == key:
				return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action_name, key_event)


func throw_grenade() -> bool:
	if not _is_gabriel() or grenades_remaining <= 0:
		return false
	if _player.has_node("HealthComponent"):
		var health: Node = _player.get_node("HealthComponent")
		if "is_dead" in health and bool(health.get("is_dead")):
			return false
	if GRENADE_SCENE == null:
		push_error("PlayerGrenade: cena da granada não foi carregada.")
		return false

	var parent_node: Node = _player.get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene
	if parent_node == null:
		return false

	var grenade: Node2D = GRENADE_SCENE.instantiate() as Node2D
	if grenade == null:
		return false
	parent_node.add_child(grenade)
	if not grenade.has_method("launch"):
		grenade.queue_free()
		return false

	grenades_remaining = maxi(0, grenades_remaining - 1)
	grenades_changed.emit(grenades_remaining, MAX_GRENADES)
	var facing: float = 1.0
	if "facing_direction" in _player:
		facing = signf(float(_player.get("facing_direction")))
	if facing == 0.0:
		facing = 1.0
	grenade.call("launch", _player, facing)
	return true
