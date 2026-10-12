class_name CharacterSelectMenu
extends Control

## Tela de Seleção de Personagens com estética Cyberpunk Neon.
## Permite selecionar Guilherme e exibe os outros 5 personagens bloqueados.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const SKIN_SELECT_SCENE: String = "res://scenes/ui/skin_select.tscn"

@onready var grid_container: GridContainer = %GridCharacters
@onready var btn_confirm: Button = %BtnConfirm
@onready var btn_back: Button = %BtnBack
@onready var status_label: Label = %StatusNoticeLabel
@onready var selected_info_label: Label = %SelectedInfoLabel

var current_hover_id: String = "guilherme"
var card_nodes: Dictionary = {}


func _ready() -> void:
	if btn_confirm != null:
		NeonThemeBuilder.style_neon_button(btn_confirm, NeonThemeBuilder.COLOR_CYAN)
		btn_confirm.pressed.connect(_on_confirm_pressed)

	if btn_back != null:
		NeonThemeBuilder.style_neon_button(btn_back, NeonThemeBuilder.COLOR_MAGENTA)
		btn_back.pressed.connect(_on_back_pressed)

	_setup_character_cards()
	_update_selection_visuals("guilherme")


func _setup_character_cards() -> void:
	card_nodes.clear()
	var game_session = get_node_or_null("/root/GameSession")
	var characters_dict: Dictionary = GameSessionClass.CHARACTERS if game_session == null else game_session.CHARACTERS

	for char_id in characters_dict.keys():
		var card_btn: Button = grid_container.get_node_or_null("Card_" + char_id) as Button
		if card_btn != null:
			card_nodes[char_id] = card_btn
			card_btn.pressed.connect(func(): _on_card_clicked(char_id))
			card_btn.focus_entered.connect(func(): _on_card_focused(char_id))

	# Foca no primeiro cartão (Guilherme)
	if card_nodes.has("guilherme"):
		card_nodes["guilherme"].grab_focus()


func _on_card_clicked(char_id: String) -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var is_unlocked: bool = false
	if game_session != null:
		is_unlocked = game_session.is_character_unlocked(char_id)
	else:
		is_unlocked = (char_id == "guilherme")

	if is_unlocked:
		current_hover_id = char_id
		_update_selection_visuals(char_id)
		if status_label != null:
			status_label.text = "Personagem selecionado: " + char_id.capitalize()
			status_label.modulate = NeonThemeBuilder.COLOR_CYAN
	else:
		# Não permite confirmar nem selecionar personagem bloqueado
		_update_selection_visuals(current_hover_id)
		if status_label != null:
			status_label.text = "⚠️ " + char_id.capitalize() + " está BLOQUEADO. Selecione um guerreiro disponível."
			status_label.modulate = NeonThemeBuilder.COLOR_MAGENTA


func _on_card_focused(char_id: String) -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var is_unlocked: bool = (char_id == "guilherme")
	if game_session != null:
		is_unlocked = game_session.is_character_unlocked(char_id)

	if is_unlocked:
		current_hover_id = char_id
		_update_selection_visuals(char_id)


func _update_selection_visuals(active_id: String) -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var characters_dict: Dictionary = GameSessionClass.CHARACTERS if game_session == null else game_session.CHARACTERS

	for char_id in card_nodes.keys():
		var btn: Button = card_nodes[char_id]
		var is_selected: bool = (char_id == active_id)
		var is_unlocked: bool = characters_dict[char_id].get("unlocked", false)

		var style := NeonThemeBuilder.create_card_style(is_selected, not is_unlocked, NeonThemeBuilder.COLOR_CYAN)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)

		# Atualiza rótulo de seleção dentro do cartão
		var sel_tag: Label = btn.get_node_or_null("%SelectTag_" + char_id) as Label
		if sel_tag != null:
			sel_tag.visible = is_selected

	# Atualiza informações do painel inferior
	if selected_info_label != null and characters_dict.has(active_id):
		var char_data: Dictionary = characters_dict[active_id]
		selected_info_label.text = "HERÓI: %s // STATUS: %s" % [
			char_data.get("name", active_id),
			"DESBLOQUEADO (PRONTO PARA BATALHA)" if char_data.get("unlocked", false) else "BLOQUEADO"
		]

	# Habilita o botão de confirmação apenas se o personagem estiver desbloqueado
	if btn_confirm != null:
		btn_confirm.disabled = (active_id != "guilherme")


func _on_confirm_pressed() -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var success: bool = false
	if game_session != null:
		success = game_session.select_character(current_hover_id)
	else:
		success = (current_hover_id == "guilherme")

	if success:
		var err := get_tree().change_scene_to_file(SKIN_SELECT_SCENE)
		if err != OK:
			printerr("Erro ao carregar tela de skins: ", err)
	else:
		if status_label != null:
			status_label.text = "Não é possível confirmar um personagem bloqueado!"
			status_label.modulate = NeonThemeBuilder.COLOR_MAGENTA


func _on_back_pressed() -> void:
	var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if err != OK:
		printerr("Erro ao retornar ao menu: ", err)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
