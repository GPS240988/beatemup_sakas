class_name TitleScreen
extends Control

## Tela de Abertura / Splash Screen animada (maingif.ogv).
## Exibe a animação dos 4 guerreiros com o banner arcade 'PRESSIONE QUALQUER TECLA' integrado na arte.
## Suporta entrada de teclado, gamepad, clique de mouse e toque mobile.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

@onready var video_player: VideoStreamPlayer = %VideoPlayer
@onready var fallback_bg: TextureRect = %BackgroundFallback
@onready var flash_rect: ColorRect = %FlashRect
@onready var touch_button: Button = %TouchButton

var _is_transitioning: bool = false


func _ready() -> void:
	if flash_rect != null:
		flash_rect.visible = true
		flash_rect.modulate.a = 0.0
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if video_player != null:
		video_player.play()

	if touch_button != null:
		touch_button.pressed.connect(_on_touch_activated)


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		_start_game()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()
	elif event is InputEventJoypadButton and event.pressed:
		_start_game()
	elif event is InputEventScreenTouch and event.pressed:
		_start_game()


func _on_touch_activated() -> void:
	if not _is_transitioning:
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
