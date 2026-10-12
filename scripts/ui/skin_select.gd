class_name SkinSelectMenu
extends Control

## Tela de Seleção de Skins com estética Cyberpunk Neon.
## Opções: Palmeirense (desbloqueada) e Pelado (bloqueada).

const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const DIFFICULTY_SELECT_SCENE: String = "res://scenes/ui/difficulty_select.tscn"

@onready var card_palmeirense: Button = %Card_palmeirense
@onready var card_pelado: Button = %Card_pelado
@onready var btn_confirm: Button = %BtnConfirm
@onready var btn_back: Button = %BtnBack
@onready var status_label: Label = %StatusNoticeLabel
@onready var select_tag_palmeirense: Label = %SelectTag_palmeirense
@onready var select_tag_pelado: Label = %SelectTag_pelado

var current_skin_id: String = "palmeirense"


func _ready() -> void:
	if btn_confirm != null:
		NeonThemeBuilder.style_neon_button(btn_confirm, NeonThemeBuilder.COLOR_CYAN)
		btn_confirm.pressed.connect(_on_confirm_pressed)

	if btn_back != null:
		NeonThemeBuilder.style_neon_button(btn_back, NeonThemeBuilder.COLOR_MAGENTA)
		btn_back.pressed.connect(_on_back_pressed)

	if card_palmeirense != null:
		card_palmeirense.pressed.connect(func(): _select_skin("palmeirense"))
		card_palmeirense.grab_focus()

	if card_pelado != null:
		card_pelado.pressed.connect(func(): _try_select_locked_skin("pelado"))

	_update_visuals()


func _select_skin(skin_id: String) -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var is_unlocked: bool = false
	if game_session != null:
		is_unlocked = game_session.is_skin_unlocked(skin_id)
	else:
		is_unlocked = (skin_id == "palmeirense")

	if is_unlocked:
		current_skin_id = skin_id
		if status_label != null:
			status_label.text = "Skin selecionada: Palmeirense (Padrão Oficial)"
			status_label.modulate = NeonThemeBuilder.COLOR_CYAN
	_update_visuals()


func _try_select_locked_skin(skin_id: String) -> void:
	# Não permite alterar a skin da sessão
	if status_label != null:
		status_label.text = "🔒 A skin 'Pelado' está BLOQUEADA no momento!"
		status_label.modulate = NeonThemeBuilder.COLOR_MAGENTA
	_update_visuals()


func _update_visuals() -> void:
	# Atualiza estilos dos cartões
	var is_palm_active: bool = (current_skin_id == "palmeirense")
	var style_palm := NeonThemeBuilder.create_card_style(is_palm_active, false, NeonThemeBuilder.COLOR_LIME)
	var style_pelado := NeonThemeBuilder.create_card_style(false, true, NeonThemeBuilder.COLOR_MAGENTA)

	if card_palmeirense != null:
		card_palmeirense.add_theme_stylebox_override("normal", style_palm)
		card_palmeirense.add_theme_stylebox_override("hover", style_palm)
		card_palmeirense.add_theme_stylebox_override("pressed", style_palm)
		card_palmeirense.add_theme_stylebox_override("focus", style_palm)

	if card_pelado != null:
		card_pelado.add_theme_stylebox_override("normal", style_pelado)
		card_pelado.add_theme_stylebox_override("hover", style_pelado)
		card_pelado.add_theme_stylebox_override("pressed", style_pelado)
		card_pelado.add_theme_stylebox_override("focus", style_pelado)

	if select_tag_palmeirense != null:
		select_tag_palmeirense.visible = is_palm_active
	if select_tag_pelado != null:
		select_tag_pelado.visible = false

	if btn_confirm != null:
		btn_confirm.disabled = (current_skin_id != "palmeirense")


func _on_confirm_pressed() -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var success: bool = false
	if game_session != null:
		success = game_session.select_skin(current_skin_id)
	else:
		success = (current_skin_id == "palmeirense")

	if success:
		var err := get_tree().change_scene_to_file(DIFFICULTY_SELECT_SCENE)
		if err != OK:
			printerr("Erro ao abrir seleção de dificuldade: ", err)


func _on_back_pressed() -> void:
	var err := get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
	if err != OK:
		printerr("Erro ao retornar para seleção de personagem: ", err)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
