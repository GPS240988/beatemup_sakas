class_name CreditsMenu
extends Control

## Tela de Créditos com estética Cyberpunk Neon.
## Apresenta informações técnicas do projeto e botão de retorno.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")

@onready var btn_back: Button = %BtnBack


func _ready() -> void:
	if btn_back != null:
		NeonThemeBuilder.style_neon_button(btn_back, NeonThemeBuilder.COLOR_MAGENTA)
		btn_back.pressed.connect(_on_back_pressed)
		btn_back.grab_focus()
	MobileScreenAction.add_primary_action(
		self, "VOLTAR AO MENU", Callable(self, "_on_back_pressed"), Color(0.85, 0.27, 0.67, 1.0), btn_back
	)


func _on_back_pressed() -> void:
	var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if err != OK:
		printerr("Falha ao retornar ao Menu Principal: ", err)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
