class_name TitleScreen
extends Control

## Tela de Abertura / Splash Screen com a nova arte estática main.webp (1920x1080).
## Efeito progressivo cinematográfico de carregamento / fade-in ao inicializar.
## Pressione qualquer tecla ou toque para prosseguir ao Menu Principal.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

@onready var background_image: TextureRect = %BackgroundImage
@onready var flash_rect: ColorRect = %FlashRect
@onready var touch_button: Button = %TouchButton

var _is_transitioning: bool = false
var _is_loaded: bool = false
var _fade_tween: Tween


func _ready() -> void:
	if flash_rect != null:
		flash_rect.visible = true
		flash_rect.modulate.a = 0.0
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if touch_button != null:
		touch_button.pressed.connect(_on_touch_activated)

	_start_cinematic_fadein()


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
	# Se pressionar durante o carregamento/fade-in, completa imediatamente
	if not _is_loaded and _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
		if background_image != null:
			background_image.modulate.a = 1.0
		_is_loaded = true
		return

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
