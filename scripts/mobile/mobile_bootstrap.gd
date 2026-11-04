extends Node

## Configuração global de apresentação para dispositivos móveis.
## Desktop e notebooks com touchscreen não são classificados como mobile.
## Mantém a altura lógica do jogo e preenche 100% da viewport em telas ultrawide (~20:9)
## sem barras pretas laterais e sem cortar nenhuma parte da arte original.

var _scene_with_mobile_fills: Node = null


func _ready() -> void:
	if not _is_mobile_runtime():
		return

	# Orientação horizontal com altura lógica constante.
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT

	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)

	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)

	# Também cobre a primeira cena
	call_deferred("_apply_current_scene")


func _on_viewport_resized() -> void:
	if not _is_mobile_runtime():
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_apply_mobile_fullscreen(current_scene)


func _apply_current_scene() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_on_scene_changed(current_scene)


func _on_scene_changed(scene_root: Node) -> void:
	if not _is_mobile_runtime() or scene_root == null:
		return
	if _scene_with_mobile_fills == scene_root:
		return

	_scene_with_mobile_fills = scene_root
	call_deferred("_apply_mobile_fullscreen", scene_root)


func _apply_mobile_fullscreen(scene_root: Node) -> void:
	# Aguarda resolução de tamanhos e anchors
	await get_tree().process_frame
	await get_tree().process_frame

	if not _is_mobile_runtime():
		return
	if not is_instance_valid(scene_root) or get_tree().current_scene != scene_root:
		return
	if not (scene_root is Control):
		return

	var root_control: Control = scene_root as Control
	var vp_size: Vector2 = root_control.get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	# ── 1. DarkBase: cor escura limpa ──
	var dark_base: ColorRect = root_control.get_node_or_null("DarkBase") as ColorRect
	if dark_base != null:
		dark_base.color = Color(0.025, 0.035, 0.07, 1.0)

	# ── 2. AspectRatioContainer → ratio acompanha viewport no mobile ──
	# Ajusta o aspect ratio do container para preencher 100% da tela sem cortes
	var aspect_wrapper: AspectRatioContainer = root_control.get_node_or_null("AspectWrapper") as AspectRatioContainer
	if aspect_wrapper == null:
		aspect_wrapper = root_control.get_node_or_null("%AspectWrapper") as AspectRatioContainer
	if aspect_wrapper != null and vp_size.y > 0.0:
		aspect_wrapper.ratio = vp_size.x / vp_size.y
		aspect_wrapper.stretch_mode = AspectRatioContainer.STRETCH_FIT
		aspect_wrapper.offset_left = 0.0
		aspect_wrapper.offset_top = 0.0
		aspect_wrapper.offset_right = 0.0
		aspect_wrapper.offset_bottom = 0.0

	# ── 3. TextureRects de Background → STRETCH_SCALE preenchendo full screen ──
	# Preenche 100% da viewport ultrawide mantendo a arte inteira visível sem barras pretas
	var direct_backgrounds: Array[TextureRect] = _find_background_sources(root_control)
	for bg: TextureRect in direct_backgrounds:
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.offset_left = 0.0
		bg.offset_top = 0.0
		bg.offset_right = 0.0
		bg.offset_bottom = 0.0


func _find_background_sources(root: Node) -> Array[TextureRect]:
	var sources: Array[TextureRect] = []
	var pending: Array[Node] = [root]

	while not pending.is_empty():
		var current: Node = pending.pop_front()
		if current is TextureRect:
			var candidate: TextureRect = current as TextureRect
			if _background_candidate_score(candidate.name) > 0:
				sources.append(candidate)

		for child in current.get_children():
			pending.append(child)

	return sources


func _background_candidate_score(node_name: StringName) -> int:
	var normalized: String = String(node_name).to_lower()
	if normalized == "imagedisplay":
		return 130
	if normalized == "storyartwork":
		return 125
	if normalized == "backgroundimage":
		return 120
	if normalized == "backgroundtexture":
		return 115
	if normalized == "backgroundslot":
		return 110
	if normalized == "incomingslot":
		return 108
	if normalized == "backgroundnormal":
		return 105
	if normalized == "backgrounddificil":
		return 104
	if normalized == "ambientbackground":
		return 95
	if normalized.begins_with("background"):
		return 90
	return 0


func _is_mobile_runtime() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)
