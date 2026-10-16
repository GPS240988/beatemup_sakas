class_name DifficultySelectMenu
extends Control

## Tela de Seleção de Dificuldade com estética Cyberpunk Neon.
## Opções: Normal ("Desafio equilibrado") e Difícil ("Um desafio maior").
## Ao confirmar, armazena a dificuldade no GameSession e carrega a Fase 1 existente.

const SKIN_SELECT_SCENE: String = "res://scenes/ui/skin_select.tscn"

@onready var card_normal: Button = %Card_normal
@onready var card_dificil: Button = %Card_dificil
@onready var btn_start_game: Button = %BtnStartGame
@onready var btn_back: Button = %BtnBack
@onready var status_label: Label = %StatusNoticeLabel
@onready var select_tag_normal: Label = %SelectTag_normal
@onready var select_tag_dificil: Label = %SelectTag_dificil

var current_difficulty: String = "normal"


func _ready() -> void:
	if btn_start_game != null:
		NeonThemeBuilder.style_neon_button(btn_start_game, NeonThemeBuilder.COLOR_CYAN)
		btn_start_game.pressed.connect(_on_start_pressed)

	if btn_back != null:
		NeonThemeBuilder.style_neon_button(btn_back, NeonThemeBuilder.COLOR_MAGENTA)
		btn_back.pressed.connect(_on_back_pressed)

	if card_normal != null:
		card_normal.pressed.connect(func(): _select_difficulty("normal"))
		card_normal.grab_focus()

	if card_dificil != null:
		card_dificil.pressed.connect(func(): _select_difficulty("dificil"))

	_update_visuals()


func _select_difficulty(diff_id: String) -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var is_valid: bool = false
	if game_session != null:
		is_valid = game_session.is_difficulty_valid(diff_id)
	else:
		is_valid = (diff_id == "normal" or diff_id == "dificil")

	if is_valid:
		current_difficulty = diff_id
		if status_label != null:
			if diff_id == "normal":
				status_label.text = "Dificuldade: Normal — Desafio equilibrado."
				status_label.modulate = NeonThemeBuilder.COLOR_CYAN
			else:
				status_label.text = "Dificuldade: Difícil — Um desafio maior! Inimigos mais agressivos."
				status_label.modulate = NeonThemeBuilder.COLOR_MAGENTA
	_update_visuals()


func _update_visuals() -> void:
	var is_norm_active: bool = (current_difficulty == "normal")
	var is_dif_active: bool = (current_difficulty == "dificil")

	var style_norm := NeonThemeBuilder.create_card_style(is_norm_active, false, NeonThemeBuilder.COLOR_CYAN)
	var style_dif := NeonThemeBuilder.create_card_style(is_dif_active, false, NeonThemeBuilder.COLOR_MAGENTA)

	if card_normal != null:
		card_normal.add_theme_stylebox_override("normal", style_norm)
		card_normal.add_theme_stylebox_override("hover", style_norm)
		card_normal.add_theme_stylebox_override("pressed", style_norm)
		card_normal.add_theme_stylebox_override("focus", style_norm)

	if card_dificil != null:
		card_dificil.add_theme_stylebox_override("normal", style_dif)
		card_dificil.add_theme_stylebox_override("hover", style_dif)
		card_dificil.add_theme_stylebox_override("pressed", style_dif)
		card_dificil.add_theme_stylebox_override("focus", style_dif)

	if select_tag_normal != null:
		select_tag_normal.visible = is_norm_active
	if select_tag_dificil != null:
		select_tag_dificil.visible = is_dif_active

	if btn_start_game != null:
		btn_start_game.disabled = (current_difficulty == "")


func _on_start_pressed() -> void:
	if current_difficulty == "":
		return

	var game_session = get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("select_difficulty_and_start"):
		var ok: bool = game_session.select_difficulty_and_start(current_difficulty)
		if not ok:
			printerr("Erro ao iniciar a Fase 1 pelo GameSession")
	else:
		# Fallback direto caso o Autoload não esteja presente
		var err := get_tree().change_scene_to_file("res://scenes/levels/map_1.tscn")
		if err != OK:
			printerr("Erro ao carregar a Fase 1 existente: ", err)


func _on_back_pressed() -> void:
	var err := get_tree().change_scene_to_file(SKIN_SELECT_SCENE)
	if err != OK:
		printerr("Erro ao retornar à seleção de skin: ", err)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
