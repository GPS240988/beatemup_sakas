extends Node

## Configuração global de apresentação para dispositivos móveis.
## Desktop e notebooks com touchscreen não são classificados como mobile.
## Mantém a altura lógica do jogo e amplia a largura disponível em cada proporção.

const AMBIENT_FILL_NAME: String = "MobileAspectFillBackdrop"
const AMBIENT_FILL_TINT: Color = Color(0.28, 0.30, 0.36, 1.0)

var _tracked_background_sources: Array[TextureRect] = []
var _tracked_background_fills: Array[TextureRect] = []
var _scene_with_mobile_fills: Node = null


func _ready() -> void:
	if not _is_mobile_runtime():
		return

	# Orientação horizontal com altura lógica constante. A largura lógica passa
	# a acompanhar o aspecto real do aparelho sem esticar os elementos da UI.
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT

	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)

	# Também cobre a primeira cena, que pode já estar montada quando o AutoLoad
	# termina seu _ready().
	call_deferred("_apply_current_scene")


func _process(_delta: float) -> void:
	if not _is_mobile_runtime():
		return

	for index in range(_tracked_background_sources.size() - 1, -1, -1):
		var source: TextureRect = _tracked_background_sources[index]
		var fill: TextureRect = _tracked_background_fills[index]
		if not is_instance_valid(source) or not is_instance_valid(fill):
			_tracked_background_sources.remove_at(index)
			_tracked_background_fills.remove_at(index)
			continue

		# Algumas telas trocam a arte em runtime (seleção de personagem) ou fazem
		# crossfade entre duas imagens (dificuldade). Cada preenchimento acompanha
		# a textura e a opacidade da sua camada original.
		var active_texture: Texture2D = source.texture
		if fill.texture != active_texture:
			fill.texture = active_texture
		fill.modulate = Color(
			AMBIENT_FILL_TINT.r,
			AMBIENT_FILL_TINT.g,
			AMBIENT_FILL_TINT.b,
			AMBIENT_FILL_TINT.a * source.modulate.a
		)
		fill.visible = (
			active_texture != null
			and source.is_visible_in_tree()
			and source.modulate.a > 0.001
		)


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
	_tracked_background_sources.clear()
	_tracked_background_fills.clear()
	call_deferred("_apply_mobile_aspect_fill", scene_root)


func _apply_mobile_aspect_fill(scene_root: Node) -> void:
	# Aguarda o _ready() das telas e os primeiros cálculos de anchors/tamanhos.
	await get_tree().process_frame
	await get_tree().process_frame

	if not _is_mobile_runtime():
		return
	if not is_instance_valid(scene_root) or get_tree().current_scene != scene_root:
		return
	if not (scene_root is Control):
		return

	var sources: Array[TextureRect] = _find_background_sources(scene_root)
	if sources.is_empty():
		return

	var root_control: Control = scene_root as Control
	var root_insertion_index: int = _get_root_background_insertion_index(root_control)

	for source: TextureRect in sources:
		var fill_container: Control = null
		var insertion_index: int = 0
		if String(source.name).to_lower() == "imagedisplay":
			# A narrativa vive em um CanvasLayer filho do mapa. O preenchimento
			# pertence ao ArtStage para acompanhar a imagem sem cobrir o diálogo.
			fill_container = source.get_parent() as Control
			insertion_index = source.get_index()
		else:
			fill_container = root_control
			insertion_index = root_insertion_index
			root_insertion_index += 1

		if fill_container == null:
			continue

		var backdrop := TextureRect.new()
		backdrop.name = AMBIENT_FILL_NAME + "_" + str(_tracked_background_fills.size())
		backdrop.texture = source.texture
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		backdrop.modulate = Color(
			AMBIENT_FILL_TINT.r,
			AMBIENT_FILL_TINT.g,
			AMBIENT_FILL_TINT.b,
			AMBIENT_FILL_TINT.a * source.modulate.a
		)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.focus_mode = Control.FOCUS_NONE
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.offset_left = 0.0
		backdrop.offset_top = 0.0
		backdrop.offset_right = 0.0
		backdrop.offset_bottom = 0.0
		backdrop.visible = source.texture != null and source.is_visible_in_tree() and source.modulate.a > 0.001

		fill_container.add_child(backdrop)
		fill_container.move_child(backdrop, insertion_index)
		_tracked_background_sources.append(source)
		_tracked_background_fills.append(backdrop)


func _get_root_background_insertion_index(root_control: Control) -> int:
	if root_control == null:
		return 0
	for base_name in ["DarkBase", "Background"]:
		var base_node: Control = root_control.get_node_or_null(base_name) as Control
		if base_node != null:
			return base_node.get_index() + 1
	return 0


func _find_background_sources(root: Node) -> Array[TextureRect]:
	var sources: Array[TextureRect] = []
	var pending: Array[Node] = [root]

	while not pending.is_empty():
		var current: Node = pending.pop_front()
		if current is TextureRect:
			var candidate: TextureRect = current as TextureRect
			if _background_candidate_score(candidate.name) > 0:
				# Inclui camadas inicialmente ocultas (ex.: imagem difícil ou
				# IncomingSlot). O _process acompanha visibilidade e crossfade.
				sources.append(candidate)

		for child in current.get_children():
			pending.append(child)

	# A busca em largura mantém a ordem dos irmãos da cena. Os preenchimentos
	# são inseridos na mesma ordem para respeitar crossfades e camadas visuais.
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
	if normalized.begins_with("background"):
		return 90
	return 0


func _is_mobile_runtime() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)
