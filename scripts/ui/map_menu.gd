class_name MapMenu
extends Control

## Tela de Menu de Mapa com arte oficial 16:9 HD (assets/backgrounds/Mapa.webp).
## Exibe a rota e o cadeado desbloqueado conforme a progressão salva no GameSession.
## Integração com fluxo de campanha e acesso direto via Menu Principal.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const DIFFICULTY_SELECT_SCENE: String = "res://scenes/ui/difficulty_select.tscn"
const INSTRUCTIONS_SCENE: String = "res://scenes/ui/loading_screen.tscn"
const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")

const MAP_IMAGE_PATH: String = "res://assets/backgrounds/Mapa.webp"
const FALLBACK_MAP_IMAGE_PATH: String = "res://assets/backgrounds/mapa.webp"

const POINT_1_PATCH_RECT := Rect2i(223, 334, 34, 31)
const POINT_2_PADLOCK_RECT := Rect2i(856, 255, 29, 44)
const POINT_3_PADLOCK_RECT := Rect2i(1248, 298, 29, 44)

const STAGE_POINTS: Array[Dictionary] = [
	{
		"id": "point_1",
		"name": "FASE 1: O REENCONTRO",
		"position": Vector2(240, 348),
		"click_rect": Rect2(180, 290, 130, 130),
		"scene": "res://scenes/ui/loading_screen.tscn"
	},
	{
		"id": "bonus",
		"name": "FASE BÔNUS: GARAGEM",
		"position": Vector2(578, 282),
		"click_rect": Rect2(520, 230, 130, 130),
		"scene": "res://scenes/levels/bonus_garage.tscn"
	},
	{
		"id": "point_2",
		"name": "FASE 2: HAPPEN",
		"position": Vector2(870, 265),
		"click_rect": Rect2(810, 210, 130, 130),
		"scene": "res://scenes/levels/map_2.tscn"
	},
	{
		"id": "point_3",
		"name": "FASE 3: METRÔ",
		"position": Vector2(1262, 335),
		"click_rect": Rect2(1200, 280, 130, 130),
		"scene": "res://scenes/levels/map_3.tscn"
	}
]

@onready var map_container: Control = get_node_or_null("%MapContainer") as Control
@onready var background_texture: TextureRect = %BackgroundTexture
@onready var point1_cover: TextureRect = get_node_or_null("%Point1Cover") as TextureRect
@onready var point2_cover: TextureRect = get_node_or_null("%Point2Cover") as TextureRect
@onready var point3_cover: TextureRect = get_node_or_null("%Point3Cover") as TextureRect
@onready var arrow_p1: Node2D = get_node_or_null("%ArrowP1") as Node2D
@onready var arrow_bonus: Node2D = get_node_or_null("%ArrowBonus") as Node2D
@onready var arrow_p2: Node2D = get_node_or_null("%ArrowP2") as Node2D
@onready var arrow_p3: Node2D = get_node_or_null("%ArrowP3") as Node2D
@onready var btn_back: Button = %BtnBack
@onready var btn_confirm: Button = %BtnConfirm
@onready var notice_label: Label = %NoticeLabel
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var _selected_point_index: int = 0
var _is_transitioning: bool = false
var _sfx_confirm: AudioStreamWAV
var _sfx_cancel: AudioStreamWAV
var _sfx_move: AudioStreamWAV
var _bob_tween: Tween
var _mobile_action_button: Button


func _ready() -> void:
	_generate_audio_effects()
	_setup_scaling()
	_load_background_image()
	_setup_progression_display()
	_setup_buttons()

	# O ponteiro deve estar SEMPRE no 1 ao abrir o mapa
	_select_point(0)

	if MobileScreenAction.is_mobile_runtime():
		_mobile_action_button = MobileScreenAction.add_primary_action(
			self, "AVANÇAR", Callable(self, "_on_confirm_pressed"), Color(0.90, 0.67, 0.25, 1.0), btn_confirm
		)
		MobileScreenAction.add_secondary_action(
			self, "VOLTAR", Callable(self, "_on_back_pressed"), btn_back
		)

	if notice_label != null:
		notice_label.visible = false

	get_tree().root.size_changed.connect(_setup_scaling)


func _setup_scaling() -> void:
	if map_container == null:
		return

	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1280.0, 720.0)

	var scale_factor: float
	scale_factor = minf(vp_size.x / 1920.0, vp_size.y / 1080.0)
	if MobileScreenAction.is_mobile_runtime():
		var dark_base := get_node_or_null("DarkBase") as ColorRect
		if dark_base != null:
			dark_base.color = Color(0.035, 0.05, 0.09, 1.0)

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
		if point3_cover != null:
			point3_cover.texture = _generate_patch_texture(map_img, POINT_3_PADLOCK_RECT)


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


func _get_game_session() -> Node:
	if is_inside_tree():
		var gs = get_node_or_null("/root/GameSession")
		if gs != null:
			return gs
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null("GameSession")
	return null


func _setup_progression_display() -> void:
	var session = _get_game_session()
	var is_stage_2: bool = false
	var is_stage_3: bool = false
	if session != null:
		if session.has_method("is_stage_2_unlocked"):
			is_stage_2 = session.is_stage_2_unlocked()
		var max_stage: int = session.max_unlocked_stage if "max_unlocked_stage" in session else 1
		is_stage_3 = max_stage >= 3

	# Padlock da Fase 2 é removido/coberto se Fase 2 estiver desbloqueada
	if point2_cover != null:
		point2_cover.visible = is_stage_2

	# Padlock da Fase 3 é removido/coberto se Fase 3 estiver desbloqueada
	if point3_cover != null:
		point3_cover.visible = is_stage_3


func is_point_unlocked(point_idx: int) -> bool:
	if point_idx == 0:
		return true
	var session = _get_game_session()
	if session == null:
		return false
	match point_idx:
		1: # Bônus
			var bonus_ok: bool = session.has_method("is_bonus_unlocked") and session.is_bonus_unlocked()
			var stage2_ok: bool = session.has_method("is_stage_2_unlocked") and session.is_stage_2_unlocked()
			return bonus_ok or stage2_ok
		2: # Ponto 2
			var stage2_ok: bool = session.has_method("is_stage_2_unlocked") and session.is_stage_2_unlocked()
			return stage2_ok
		3: # Ponto 3
			var max_stage: int = session.max_unlocked_stage if "max_unlocked_stage" in session else 1
			return max_stage >= 3
		_:
			return false


func advance_trail() -> bool:
	return _try_navigate(1)


func retreat_trail() -> bool:
	return _try_navigate(-1)


func _try_navigate(step: int) -> bool:
	var target_idx = _selected_point_index + step
	if target_idx < 0 or target_idx >= STAGE_POINTS.size():
		return false

	if not is_point_unlocked(target_idx):
		_play_sound(_sfx_cancel)
		return false

	_select_point(target_idx)
	_play_sound(_sfx_move)
	return true


func select_point(idx: int) -> bool:
	if idx < 0 or idx >= STAGE_POINTS.size():
		return false
	if not is_point_unlocked(idx):
		_play_sound(_sfx_cancel)
		return false
	_select_point(idx)
	return true


func _select_point(idx: int) -> void:
	_selected_point_index = clampi(idx, 0, STAGE_POINTS.size() - 1)

	# Se for ponto 0 (Ponto 1), a seta original de P1 permanece visível (não coberta)
	if point1_cover != null:
		point1_cover.visible = (_selected_point_index != 0)

	if arrow_p1 != null:
		arrow_p1.visible = (_selected_point_index == 0)
	if arrow_bonus != null:
		arrow_bonus.visible = (_selected_point_index == 1)
	if arrow_p2 != null:
		arrow_p2.visible = (_selected_point_index == 2)
	if arrow_p3 != null:
		arrow_p3.visible = (_selected_point_index == 3)

	var active_arrow: Node2D = null
	match _selected_point_index:
		0: active_arrow = arrow_p1
		1: active_arrow = arrow_bonus
		2: active_arrow = arrow_p2
		3: active_arrow = arrow_p3

	if active_arrow != null:
		_start_arrow_bobbing(active_arrow)

	if _mobile_action_button != null and _selected_point_index < STAGE_POINTS.size():
		var pt_name: String = str(STAGE_POINTS[_selected_point_index]["name"])
		MobileScreenAction.set_action_state(_mobile_action_button, "AVANÇAR - " + pt_name, false)


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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = _get_map_coordinates(event.position)
		_handle_point_click(local_pos)


func _get_map_coordinates(screen_pos: Vector2) -> Vector2:
	if map_container == null:
		return screen_pos
	return (screen_pos - map_container.position) / map_container.scale


func _handle_point_click(pos: Vector2) -> void:
	for i in range(STAGE_POINTS.size()):
		var rect: Rect2 = STAGE_POINTS[i]["click_rect"]
		if rect.has_point(pos):
			if is_point_unlocked(i):
				if _selected_point_index == i:
					_on_confirm_pressed()
				else:
					_select_point(i)
					_play_sound(_sfx_move)
			else:
				_play_sound(_sfx_cancel)
			return


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_on_back_pressed()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_RIGHT or event.keycode == KEY_D or event.keycode == KEY_DOWN or event.keycode == KEY_S)):
		_safe_handle_input()
		advance_trail()
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_LEFT or event.keycode == KEY_A or event.keycode == KEY_UP or event.keycode == KEY_W)):
		_safe_handle_input()
		retreat_trail()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		_on_confirm_pressed()


func _on_back_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sound(_sfx_cancel)
	_safe_handle_input()

	var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if err != OK:
		_is_transitioning = false
		printerr("Erro ao retornar do mapa para o menu principal: ", err)


func _on_confirm_pressed() -> void:
	if _is_transitioning:
		return
	if not is_point_unlocked(_selected_point_index):
		_play_sound(_sfx_cancel)
		return
	_is_transitioning = true
	_play_sound(_sfx_confirm)
	_safe_handle_input()

	var session = _get_game_session()
	if session != null:
		if not ("selected_character_id" in session) or session.selected_character_id == "":
			session.selected_character_id = "guilherme"
		if not ("difficulty_id" in session) or session.difficulty_id == "":
			session.difficulty_id = "normal"
		session.set_meta("selected_stage_index", _selected_point_index)

	var target_scene: String = str(STAGE_POINTS[_selected_point_index]["scene"])
	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		_is_transitioning = false
		printerr("Erro ao transicionar para a fase: ", err)


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
	_sfx_move = _create_wav(720.0, 0.05, 0.35)


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
