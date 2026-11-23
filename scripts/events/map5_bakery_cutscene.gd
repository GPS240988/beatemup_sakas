class_name Map5BakeryCutscene
extends CanvasLayer

## Cutscene em vídeo de André na padaria (Fase 2-1).
## O vídeo é obrigatório e termina somente quando o arquivo chega ao fim.
## Nenhuma entrada de teclado, mouse, touch ou gamepad pode interromper a apresentação.

signal cutscene_finished

const VIDEO_PATH_ROOT: String = "res://assets/videos/video_fase2_1_andre.ogv"
const VIDEO_PATH_STAGE2: String = "res://assets/videos/stage2/video_fase2_1_andre.ogv"

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
