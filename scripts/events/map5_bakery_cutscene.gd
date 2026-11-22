class_name Map5BakeryCutscene
extends CanvasLayer

## Cutscene em vídeo de André na padaria (Fase 2-1).
## Exibe assets/videos/video_fase2_1_andre.ogv em tela cheia (16:9) com pausa de cena.
## Executa uma única vez quando o jogador passa em frente à porta da padaria.

signal cutscene_finished

const VIDEO_PATH_ROOT: String = "res://assets/videos/video_fase2_1_andre.ogv"
const VIDEO_PATH_STAGE2: String = "res://assets/videos/stage2/video_fase2_1_andre.ogv"
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

var _tree_was_paused: bool = false
var _video_player: VideoStreamPlayer = null
var _finished: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126


func _ready() -> void:
	var tree := get_tree()
	if tree != null:
		_tree_was_paused = tree.paused
		tree.paused = true

	var root_control := Control.new()
	root_control.name = "CutsceneRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.02, 0.02, 0.04, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(bg)

	var aspect := AspectRatioContainer.new()
	aspect.name = "VideoAspect"
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(aspect)

	_video_player = VideoStreamPlayer.new()
	_video_player.name = "VideoStreamPlayer"
	_video_player.expand = true
	_video_player.loop = false
	_video_player.bus = &"Master"
	_video_player.finished.connect(_on_video_finished)
	aspect.add_child(_video_player)

	var skip_label := Label.new()
	skip_label.name = "SkipPrompt"
	skip_label.text = "PRESSIONE ESPAÇO / ENTER / J PARA PULAR"
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	skip_label.anchor_left = 0.5
	skip_label.anchor_top = 0.92
	skip_label.anchor_right = 0.96
	skip_label.anchor_bottom = 0.97
	var skip_settings := LabelSettings.new()
	skip_settings.font = ARCADE_FONT
	skip_settings.font_size = 14
	skip_settings.font_color = Color(0.7, 0.7, 0.75, 0.75)
	skip_label.label_settings = skip_settings
	root_control.add_child(skip_label)

	_start_video()


func _start_video() -> void:
	var stream: VideoStream = _resolve_video_stream()
	if stream != null and _video_player != null:
		_video_player.stream = stream
		_video_player.play()
	else:
		push_warning("Map5BakeryCutscene: não foi possível carregar vídeo de André na padaria.")
		call_deferred("_close_cutscene")


func _resolve_video_stream() -> VideoStream:
	for path in [VIDEO_PATH_ROOT, VIDEO_PATH_STAGE2]:
		if ResourceLoader.exists(path):
			var res = ResourceLoader.load(path)
			if res is VideoStream:
				return res as VideoStream
		if FileAccess.file_exists(path):
			var theora := VideoStreamTheora.new()
			theora.file = path
			return theora
	return null


func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and (k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_J] or k.physical_keycode == KEY_J):
			get_viewport().set_input_as_handled()
			_on_video_finished()
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_on_video_finished()
	elif event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			get_viewport().set_input_as_handled()
			_on_video_finished()
	elif event is InputEventJoypadButton:
		var j := event as InputEventJoypadButton
		if j.pressed and j.button_index in [JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_X]:
			get_viewport().set_input_as_handled()
			_on_video_finished()


func _on_video_finished() -> void:
	if _finished:
		return
	_finished = true
	_close_cutscene()


func _close_cutscene() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
	for action in ["attack", "attack_punch", "jump", "ui_accept", "ui_cancel"]:
		if InputMap.has_action(action):
			Input.action_release(action)
	var tree := get_tree()
	if tree != null:
		tree.paused = _tree_was_paused
	cutscene_finished.emit()
	queue_free()
