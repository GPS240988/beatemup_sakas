class_name FrentistaDialogue
extends "res://scripts/events/map4_opening_dialogue.gd"

## Diálogo do Frentista do Posto Ipiranga (Mapa 5, Estágio 2).
## Exibe duas caixas de diálogo sequenciais com o padrão oficial de entrada de fase,
## moldura 9-patch canônica, retrato Pixel Art HD, pausa de cena e bloqueio de movimento.

const ATTENDANT_TEXTURE: Texture2D = preload("res://assets/sprites/actors/gas_station_attendant.png")
const FRENTISTA_TEXT_1: String = "Aqui é o posto Ipiranga, não sei informar onde fica a HAPPEN."
const FRENTISTA_TEXT_2: String = "Mas cuidado! Sábado a noite tem muitos baderneiros nessa rua."

var _tree_was_paused: bool = false


func _ready() -> void:
	var portrait := AtlasTexture.new()
	portrait.atlas = ATTENDANT_TEXTURE
	portrait.region = Rect2(40, 2, 200, 200)

	_dialogues = [
		{
			"speaker": "FRENTISTA",
			"portrait": portrait,
			"text": FRENTISTA_TEXT_1
		},
		{
			"speaker": "FRENTISTA",
			"portrait": portrait,
			"text": FRENTISTA_TEXT_2
		}
	]
	var tree: SceneTree = get_tree()
	if tree != null:
		_tree_was_paused = tree.paused
		tree.paused = true
	super._ready()


func _advance_or_close() -> void:
	_current_dialogue_index += 1
	if _current_dialogue_index < _dialogues.size():
		_waiting_for_release = true
		_show_current_dialogue()
	else:
		_close_dialogue()


func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J] or key_event.physical_keycode == KEY_J:
				return true
	return super._is_advance_event(event)


func _is_advance_input_held() -> bool:
	if Input.is_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_J):
		return true
	return super._is_advance_input_held()


func _close_dialogue() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
	for action: String in ["attack", "attack_punch", "ui_accept"]:
		if InputMap.has_action(action):
			Input.action_release(action)
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = _tree_was_paused
	super._close_dialogue()
