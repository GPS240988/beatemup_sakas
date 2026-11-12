class_name Map4OpeningDialogueEvent
extends CanvasLayer

## Evento narrativo bloqueante da entrada do Mapa 4.
## Exibe os diálogos de abertura da Juliana e do Gabriel após o vídeo OGV
## da transição Map 3 -> Map 4, antes de liberar o gameplay.
signal dialogue_closed

const StandardDialogueBoxClass = preload("res://scripts/ui/standard_dialogue_box.gd")
const JULIANA_PORTRAIT: Texture2D = preload(
	"res://assets/ui/hud/portraits/portrait_juliana.png"
)
const GABRIEL_PORTRAIT: Texture2D = preload(
	"res://assets/ui/hud/portraits/portrait_gabriel.png"
)
const ALESSANDRO_PORTRAIT: Texture2D = preload(
	"res://assets/ui/hud/portraits/portrait_guilherme.png"
)

## Lista de diálogos a serem exibidos em sequência
## A ordem é: Alessandro → Juliana → Gabriel
var _dialogues: Array[Dictionary] = [
	{
		"speaker": "ALESSANDRO",
		"portrait": ALESSANDRO_PORTRAIT,
		"text": "Vem aqui docinho, tenho uma trufa para você."
	},
	{
		"speaker": "JULIANA",
		"portrait": JULIANA_PORTRAIT,
		"text": "Segundo a Dona Ana, o Alessandro estava correndo atrás das meninas da rua, jogou uma trufa na janela dela e agiu de um jeito bem estranho."
	},
	{
		"speaker": "GABRIEL",
		"portrait": GABRIEL_PORTRAIT,
		"text": "Há mais jogadores de magic aqui na rua, mas esses são os green deck TANK da SKY."
	}
]

var _current_dialogue_index: int = 0
var _dialogue_label: Label = null
var _continue_label: Label = null
var _portrait: TextureRect = null
var _speaker_label: Label = null
var _typewriter_tween: Tween = null
var _is_typing: bool = false
var _waiting_for_release: bool = true


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125


func _ready() -> void:
	var root := Control.new()
	root.name = "DialogueRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	var is_mobile: bool = (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)
	var ui: Dictionary = StandardDialogueBoxClass.build_dialogue_ui(
		root, is_mobile
	)

	_portrait = ui["portrait"] as TextureRect
	_speaker_label = ui["speaker_label"] as Label
	_dialogue_label = ui["dialogue_label"] as Label
	_continue_label = ui["continue_label"] as Label

	if _portrait == null or _speaker_label == null or _dialogue_label == null or _continue_label == null:
		push_warning("Map4: diálogo não pôde ser montado - nós ausentes.")
		_close_dialogue()
		return

	_show_current_dialogue()


func _show_current_dialogue() -> void:
	if _current_dialogue_index >= _dialogues.size():
		_close_dialogue()
		return

	var dialogue: Dictionary = _dialogues[_current_dialogue_index]
	var speaker: String = dialogue.get("speaker", "")
	var portrait_tex: Texture2D = dialogue.get("portrait", null)
	var text: String = dialogue.get("text", "")

	_portrait.texture = portrait_tex
	_speaker_label.text = speaker
	_dialogue_label.text = text
	_dialogue_label.visible_characters = 0
	_continue_label.visible = false

	_start_typewriter()


func _process(_delta: float) -> void:
	if _waiting_for_release and not _is_advance_input_held():
		_waiting_for_release = false


func _is_advance_input_held() -> bool:
	if (
		Input.is_key_pressed(KEY_ENTER)
		or Input.is_key_pressed(KEY_KP_ENTER)
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_ESCAPE)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	):
		return true

	for device_id: int in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device_id, JOY_BUTTON_A):
			return true

	return false


func _input(event: InputEvent) -> void:
	if _waiting_for_release:
		return
	if not _is_advance_event(event):
		return

	get_viewport().set_input_as_handled()
	if _is_typing:
		_finish_typewriter()
	else:
		_advance_or_close()


func _advance_or_close() -> void:
	_current_dialogue_index += 1
	if _current_dialogue_index < _dialogues.size():
		_show_current_dialogue()
	else:
		_close_dialogue()


func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return (
			key_event.pressed
			and not key_event.echo
			and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		)

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
		)

	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed

	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		return joy_event.pressed and joy_event.button_index == JOY_BUTTON_A

	return false


func _start_typewriter() -> void:
	if _dialogue_label == null:
		return

	_is_typing = true
	_dialogue_label.visible_characters = 0
	var duration: float = (
		float(_dialogue_label.text.length())
		/ maxf(StandardDialogueBoxClass.TYPEWRITER_SPEED_CPS, 1.0)
	)

	_typewriter_tween = create_tween()
	_typewriter_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_typewriter_tween.tween_property(
		_dialogue_label,
		"visible_characters",
		_dialogue_label.text.length(),
		duration
	).set_trans(Tween.TRANS_LINEAR)
	_typewriter_tween.finished.connect(_on_typewriter_finished)


func _on_typewriter_finished() -> void:
	_is_typing = false
	if _dialogue_label != null:
		_dialogue_label.visible_characters = -1
	if _continue_label != null:
		_continue_label.visible = true


func _finish_typewriter() -> void:
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()

	_is_typing = false
	if _dialogue_label != null:
		_dialogue_label.visible_characters = -1
	if _continue_label != null:
		_continue_label.visible = true


func _close_dialogue() -> void:
	set_process_input(false)
	set_process(false)
	dialogue_closed.emit()
	queue_free()
