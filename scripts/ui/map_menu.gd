class_name MapMenu
extends Control

## Tela de Menu de Mapa com arte oficial 16:9 HD (assets/backgrounds/Mapa.webp).
## Exibe a rota e o cadeado desbloqueado conforme a progressão salva no GameSession.
## Integração com fluxo de campanha (DifficultySelect -> MapMenu -> LoadingScreen/Instruções -> Fase 1)
## e acesso direto via Menu Principal com suporte a mouse, teclado e touch mobile.
## Em estrita conformidade com GAME_RULES.md.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const DIFFICULTY_SELECT_SCENE: String = "res://scenes/ui/difficulty_select.tscn"
const INSTRUCTIONS_SCENE: String = "res://scenes/ui/loading_screen.tscn"

const MAP_IMAGE_PATH: String = "res://assets/backgrounds/Mapa.webp"
const FALLBACK_MAP_IMAGE_PATH: String = "res://assets/backgrounds/mapa.webp"

const POINT_1_PATCH_RECT := Rect2i(223, 334, 34, 31)
const POINT_2_PADLOCK_RECT := Rect2i(856, 255, 29, 44)

@onready var map_container: Control = get_node_or_null("%MapContainer") as Control
@onready var background_texture: TextureRect = %BackgroundTexture
@onready var point1_cover: TextureRect = get_node_or_null("%Point1Cover") as TextureRect
@onready var point2_cover: TextureRect = get_node_or_null("%Point2Cover") as TextureRect
@onready var arrow_p1: Node2D = get_node_or_null("%ArrowP1") as Node2D
@onready var arrow_bonus: Node2D = get_node_or_null("%ArrowBonus") as Node2D
@onready var arrow_p2: Node2D = get_node_or_null("%ArrowP2") as Node2D
@onready var btn_back: Button = %BtnBack
@onready var btn_confirm: Button = %BtnConfirm
@onready var notice_label: Label = %NoticeLabel
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var _is_transitioning: bool = false
var _sfx_confirm: AudioStreamWAV
var _sfx_cancel: AudioStreamWAV
var _bob_tween: Tween


func _ready() -> void:
	_generate_audio_effects()
	_setup_scaling()
	_load_background_image()
	_setup_progression_display()
	_setup_buttons()

	# Oculta aviso em tempo de execução para manter a arte do mapa limpa e imersiva
	if notice_label != null:
		notice_label.visible = false

	get_tree().root.size_changed.connect(_setup_scaling)


func _setup_scaling() -> void:
	if map_container == null:
		return

	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1280.0, 720.0)

	var scale_factor: float = minf(vp_size.x / 1920.0, vp_size.y / 1080.0)
	if scale_factor <= 0.0:
		scale_factor = 1.0

	map_container.custom_minimum_size = Vector2(1920.0, 1080.0)
	map_container.size = Vector2(1920.0, 1080.0)
	map_container.scale = Vector2(scale_factor, scale_factor)

	var scaled_width: float = 1920.0 * scale_factor
	var scaled_height: float = 1080.0 * scale_factor
	map_container.position = Vector2(
		(vp_size.x - scaled_width) * 0.5,
		(vp_size.y - scaled_height) * 0.5
	)


func _load_background_image() -> void:
	if background_texture == null:
		return

	var tex: Texture2D = null
	if ResourceLoader.exists(MAP_IMAGE_PATH):
		tex = load(MAP_IMAGE_PATH) as Texture2D
	elif ResourceLoader.exists(FALLBACK_MAP_IMAGE_PATH):
		tex = load(FALLBACK_MAP_IMAGE_PATH) as Texture2D

	var map_img: Image = null
	if tex != null:
		map_img = tex.get_image()
	else:
		for path_to_try in [MAP_IMAGE_PATH, FALLBACK_MAP_IMAGE_PATH]:
			var global_p := ProjectSettings.globalize_path(path_to_try)
			if FileAccess.file_exists(global_p):
				map_img = Image.load_from_file(global_p)
				if map_img != null:
					tex = ImageTexture.create_from_image(map_img)
					tex.resource_path = path_to_try
					break

	if tex != null:
		background_texture.texture = tex

	if map_img != null:
		if point1_cover != null:
			point1_cover.texture = _generate_patch_texture(map_img, POINT_1_PATCH_RECT)
		if point2_cover != null:
			point2_cover.texture = _generate_patch_texture(map_img, POINT_2_PADLOCK_RECT)


func _generate_patch_texture(source_img: Image, rect: Rect2i) -> ImageTexture:
	var w: int = rect.size.x
	var h: int = rect.size.y
	var patch := Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		var src_y: int = clampi(rect.position.y + y, 0, source_img.get_height() - 1)
		var left_x: int = clampi(rect.position.x - 1, 0, source_img.get_width() - 1)
		var right_x: int = clampi(rect.position.x + w, 0, source_img.get_width() - 1)
		var c_left: Color = source_img.get_pixel(left_x, src_y)
		var c_right: Color = source_img.get_pixel(right_x, src_y)

		for x in range(w):
			var t: float = float(x) / float(maxi(1, w - 1))
			var col: Color = c_left.lerp(c_right, t)
			patch.set_pixel(x, y, col)

	return ImageTexture.create_from_image(patch)


func _setup_progression_display() -> void:
	var session = get_node_or_null("/root/GameSession")
	var is_stage_2: bool = false
	var is_bonus: bool = false
	if session != null:
		if session.has_method("is_stage_2_unlocked"):
			is_stage_2 = session.is_stage_2_unlocked()
		if session.has_method("is_bonus_unlocked"):
			is_bonus = session.is_bonus_unlocked()

	if is_stage_2:
		# Fase 2 desbloqueada: seta sobre Ponto 2 e cadeado removido
		if point1_cover != null:
			point1_cover.visible = true
		if point2_cover != null:
			point2_cover.visible = true
		if arrow_p1 != null:
			arrow_p1.visible = false
		if arrow_bonus != null:
			arrow_bonus.visible = false
		if arrow_p2 != null:
			arrow_p2.visible = true
			_start_arrow_bobbing(arrow_p2)
	elif is_bonus:
		# Fase Bônus desbloqueada: seta sobre Bônus 1 e cadeado do Ponto 2 visível
		if point1_cover != null:
			point1_cover.visible = true
		if point2_cover != null:
			point2_cover.visible = false
		if arrow_p1 != null:
			arrow_p1.visible = false
		if arrow_bonus != null:
			arrow_bonus.visible = true
			_start_arrow_bobbing(arrow_bonus)
		if arrow_p2 != null:
			arrow_p2.visible = false
	else:
		# Início do jogo: estado inicial (seta sobre Ponto 1 e cadeado no Ponto 2)
		if point1_cover != null:
			point1_cover.visible = false
		if point2_cover != null:
			point2_cover.visible = false
		if arrow_p1 != null:
			arrow_p1.visible = true
			_start_arrow_bobbing(arrow_p1)
		if arrow_bonus != null:
			arrow_bonus.visible = false
		if arrow_p2 != null:
			arrow_p2.visible = false


func _start_arrow_bobbing(arrow_node: Node2D) -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()

	var base_y: float = arrow_node.position.y
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(arrow_node, "position:y", base_y - 4.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bob_tween.tween_property(arrow_node, "position:y", base_y + 2.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _setup_buttons() -> void:
	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)
		btn_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if btn_confirm != null:
		btn_confirm.pressed.connect(_on_confirm_pressed)
		btn_confirm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_safe_handle_input()
		_on_confirm_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_on_back_pressed()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_safe_handle_input()
		_on_confirm_pressed()


func _on_back_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sound(_sfx_cancel)
	_safe_handle_input()

	var session = get_node_or_null("/root/GameSession")
	var is_in_game_flow: bool = (session != null and "difficulty_id" in session and session.difficulty_id != "")
	var target_scene := DIFFICULTY_SELECT_SCENE if is_in_game_flow else MAIN_MENU_SCENE

	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		err = get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		if err != OK:
			_is_transitioning = false
			printerr("Erro ao retornar do mapa: ", err)


func _on_confirm_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sound(_sfx_confirm)
	_safe_handle_input()

	var session = get_node_or_null("/root/GameSession")
	if session != null:
		if not ("selected_character_id" in session) or session.selected_character_id == "":
			session.selected_character_id = "guilherme"
		if not ("difficulty_id" in session) or session.difficulty_id == "":
			session.difficulty_id = "normal"

	var err := get_tree().change_scene_to_file(INSTRUCTIONS_SCENE)
	if err != OK:
		_is_transitioning = false
		printerr("Erro ao transicionar para instruções da fase: ", err)


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _play_sound(stream: AudioStreamWAV) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()


func _generate_audio_effects() -> void:
	_sfx_confirm = _create_wav(1040.0, 0.12, 0.40)
	_sfx_cancel = _create_wav(160.0, 0.14, 0.40)


func _create_wav(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var sample_count: int = int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t: float = float(i) / 22050.0
		var envelope: float = 1.0 - (float(i) / float(sample_count))
		var sample: float = sin(t * freq * TAU) * volume * envelope
		var byte_val: int = clampi(int(sample * 127.0 + 128.0), 0, 255)
		data[i] = byte_val
	wav.data = data
	return wav
