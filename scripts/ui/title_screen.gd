class_name TitleScreen
extends Control

## Tela de Abertura / Splash Screen com a nova arte estática main.webp (1920x1080).
## Efeito progressivo cinematográfico de carregamento / fade-in ao inicializar.
## Pressione qualquer tecla ou toque para prosseguir ao Menu Principal.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const BGM_MENU: String = "res://assets/audio/bgm/Menu.mp3"
const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")

@onready var background_image: TextureRect = %BackgroundImage
@onready var flash_rect: ColorRect = %FlashRect
@onready var touch_button: Button = %TouchButton

var _is_transitioning: bool = false
var _is_loaded: bool = false
var _fade_tween: Tween
var _mobile_action_button: Button


func _ready() -> void:
	if MobileScreenAction.is_mobile_runtime():
		_apply_mobile_fullscreen()

	if flash_rect != null:
		flash_rect.visible = true
		flash_rect.modulate.a = 0.0
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if touch_button != null:
		touch_button.pressed.connect(_on_touch_activated)

	# Reproduz a música do Menu logo na abertura do jogo
	var session = get_node_or_null("/root/GameSession")
	if session != null and session.has_method("play_bgm"):
		session.play_bgm(BGM_MENU, -4.0, 1.2)

	_start_cinematic_fadein()


func _apply_mobile_fullscreen() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1280.0, 720.0)

	var dark_base := get_node_or_null("DarkBase") as ColorRect
	if dark_base != null:
		dark_base.color = Color(0.025, 0.035, 0.07, 1.0)

	var aspect_wrapper: AspectRatioContainer = get_node_or_null("AspectWrapper") as AspectRatioContainer
	if aspect_wrapper == null:
		aspect_wrapper = get_node_or_null("%AspectWrapper") as AspectRatioContainer
	if aspect_wrapper != null and vp_size.y > 0.0:
		aspect_wrapper.ratio = vp_size.x / vp_size.y
		aspect_wrapper.stretch_mode = AspectRatioContainer.STRETCH_FIT
		aspect_wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		aspect_wrapper.offset_left = 0.0
		aspect_wrapper.offset_top = 0.0
		aspect_wrapper.offset_right = 0.0
		aspect_wrapper.offset_bottom = 0.0

	if background_image != null:
		background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background_image.stretch_mode = TextureRect.STRETCH_SCALE
		background_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background_image.offset_left = 0.0
		background_image.offset_top = 0.0
		background_image.offset_right = 0.0
		background_image.offset_bottom = 0.0

	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_mobile_fullscreen):
		get_viewport().size_changed.connect(_apply_mobile_fullscreen)


func _start_cinematic_fadein() -> void:
	if background_image == null:
		_is_loaded = true
		return

	# Inicia escura e vai sendo revelada suavemente como se estivesse carregando
	background_image.modulate.a = 0.0

	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(background_image, "modulate:a", 1.0, 2.2)
	_fade_tween.tween_callback(func():
		_is_loaded = true
	)


func _input(event: InputEvent) -> void:
	# Captura o toque antes dos controles filhos. Assim, qualquer ponto da arte
	# inicial avança para o menu, mesmo quando o dispositivo não emula mouse.
	if not MobileScreenAction.is_mobile_runtime() or _is_transitioning:
		return
	if event is InputEventScreenTouch and event.pressed and event.index == 0:
		_handle_activation()
		if get_viewport() != null:
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		_handle_activation()
	elif event is InputEventMouseButton and event.pressed:
		_handle_activation()
	elif event is InputEventJoypadButton and event.pressed:
		_handle_activation()
	elif event is InputEventScreenTouch and event.pressed:
		_handle_activation()


func _on_touch_activated() -> void:
	if not _is_transitioning:
		_handle_activation()


func _handle_activation() -> void:
	if _is_transitioning:
		return

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if background_image != null:
		background_image.modulate.a = 1.0
	_is_loaded = true

	# Assegura a continuidade da música do Menu caso tenha ocorrido bloqueio de autoplay no browser
	var session = get_node_or_null("/root/GameSession")
	if session != null and session.has_method("play_bgm"):
		session.play_bgm(BGM_MENU, -4.0, 0.5)

	_start_game()


func _start_game() -> void:
	_is_transitioning = true

	var tween: Tween = create_tween()
	if flash_rect != null:
		tween.tween_property(flash_rect, "modulate:a", 0.35, 0.1)
		tween.tween_property(flash_rect, "modulate:a", 0.0, 0.12)

	tween.tween_callback(func():
		var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		if err != OK:
			printerr("Erro ao carregar menu principal: ", err)
	)
