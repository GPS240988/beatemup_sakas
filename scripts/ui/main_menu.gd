class_name MainMenu
extends Control

## Tela do Menu Principal com estética Cyberpunk Neon.
## Permite iniciar Novo Jogo, visualizar Créditos ou sair.
## Possui o nó BackgroundSlot reservado para o futuro fundo de tela.

const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const CREDITS_SCENE: String = "res://scenes/ui/credits.tscn"

@onready var background_slot: TextureRect = %BackgroundSlot
@onready var btn_new_game: Button = %BtnNewGame
@onready var btn_continue: Button = %BtnContinue
@onready var btn_credits: Button = %BtnCredits
@onready var version_label: Label = %VersionLabel


func _ready() -> void:
	# Aplica temas e cores neon da paleta Cyberpunk
	_apply_neon_styles()
	
	# Conexão de sinais dos botões
	if btn_new_game != null:
		btn_new_game.pressed.connect(_on_new_game_pressed)
		btn_new_game.grab_focus()

	if btn_credits != null:
		btn_credits.pressed.connect(_on_credits_pressed)
	
	if btn_continue != null:
		# Botão Continuar permanece estritamente desabilitado
		btn_continue.disabled = true
		btn_continue.focus_mode = Control.FOCUS_NONE

	# Verifica estado de integridade do BackgroundSlot
	_validate_background_slot()


func _apply_neon_styles() -> void:
	# Estilização com a paleta neon
	if btn_new_game != null:
		NeonThemeBuilder.style_neon_button(btn_new_game, NeonThemeBuilder.COLOR_CYAN)
	if btn_continue != null:
		NeonThemeBuilder.style_neon_button(btn_continue, NeonThemeBuilder.COLOR_DISABLED)
	if btn_credits != null:
		NeonThemeBuilder.style_neon_button(btn_credits, NeonThemeBuilder.COLOR_ELECTRIC_PURPLE)


func _validate_background_slot() -> void:
	if background_slot != null:
		# Garante que o slot não intercepte cliques do mouse
		background_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_new_game_pressed() -> void:
	# Reinicia o estado da sessão de jogo e abre a seleção de personagens
	var game_session = get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("reset_session"):
		game_session.reset_session()
	
	var err := get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
	if err != OK:
		printerr("Falha ao abrir seleção de personagens: ", err)


func _on_credits_pressed() -> void:
	var err := get_tree().change_scene_to_file(CREDITS_SCENE)
	if err != OK:
		printerr("Falha ao abrir tela de créditos: ", err)
