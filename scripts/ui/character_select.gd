class_name CharacterSelectMenu
extends Control

## Tela de Seleção de Personagem com arte de fundo selecao_personagem.jpg.
## Apresenta Guilherme desbloqueado com atributos (Força 3, Velocidade 2, Técnica 3),
## e os demais heróis bloqueados. Ao confirmar, inicia a Fase 1.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const FIRST_LEVEL_SCENE: String = "res://scenes/levels/test_street.tscn"

@onready var background_slot: TextureRect = %BackgroundSlot
@onready var grid_container: Control = %GridCharacters
@onready var btn_confirm: Button = %BtnConfirm
@onready var btn_back: Button = %BtnBack
@onready var status_label: Label = %StatusNoticeLabel
@onready var stat_forca_label: Label = %StatForcaLabel
@onready var stat_vel_label: Label = %StatVelLabel
@onready var stat_tec_label: Label = %StatTecLabel

var current_hover_id: String = "guilherme"
var card_nodes: Dictionary = {}


func _ready() -> void:
	if background_slot != null and background_slot.texture == null:
		var bg_tex = load("res://assets/backgrounds/selecao_personagem.jpg")
		if bg_tex != null:
			background_slot.texture = bg_tex
		background_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if btn_confirm != null:
		NeonThemeBuilder.style_neon_button(btn_confirm, Color(0.9, 0.1, 0.25, 1.0))
		btn_confirm.pressed.connect(_on_confirm_pressed)

	if btn_back != null:
		NeonThemeBuilder.style_neon_button(btn_back, Color(0.2, 0.3, 0.45, 1.0))
		btn_back.pressed.connect(_on_back_pressed)

	_setup_character_cards()
	_update_stats_display("guilherme")


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

	if card_nodes.has("guilherme"):
		card_nodes["guilherme"].grab_focus()


func _on_card_clicked(char_id: String) -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var is_unlocked: bool = (char_id == "guilherme")
	if game_session != null:
		is_unlocked = game_session.is_character_unlocked(char_id)

	if is_unlocked:
		current_hover_id = char_id
		_update_stats_display(char_id)
		if status_label != null:
			status_label.text = "Guerreiro Selecionado: Guilherme (Disponível)"
			status_label.modulate = Color(1.0, 0.84, 0.0, 1.0)
	else:
		if status_label != null:
			status_label.text = "⚠️ %s está BLOQUEADO no momento. Apenas Guilherme está disponível." % char_id.capitalize()
			status_label.modulate = Color(0.9, 0.2, 0.3, 1.0)


func _on_card_focused(char_id: String) -> void:
	_on_card_clicked(char_id)


func _update_stats_display(char_id: String) -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var stats: Dictionary = {"strength": 3, "speed": 2, "technique": 3}
	if game_session != null and game_session.has_method("get_character_stats"):
		stats = game_session.get_character_stats(char_id)

	var forca: int = int(stats.get("strength", 3))
	var vel: int = int(stats.get("speed", 2))
	var tec: int = int(stats.get("technique", 3))

	if stat_forca_label != null:
		stat_forca_label.text = "FORÇA:      " + _generate_bar_string(forca)
	if stat_vel_label != null:
		stat_vel_label.text = "VELOCIDADE: " + _generate_bar_string(vel)
	if stat_tec_label != null:
		stat_tec_label.text = "TÉCNICA:    " + _generate_bar_string(tec)

	if btn_confirm != null:
		btn_confirm.disabled = (char_id != "guilherme")
		btn_confirm.text = "⚡ ESCOLHER GUILHERME — INICIAR FASE 1" if char_id == "guilherme" else "BLOQUEADO"


func _generate_bar_string(val: int) -> String:
	var result: String = ""
	for i in range(5):
		if i < val:
			result += "■ "
		else:
			result += "□ "
	return result.strip_edges()


func _on_confirm_pressed() -> void:
	if current_hover_id != "guilherme":
		return

	var game_session = get_node_or_null("/root/GameSession")
	if game_session != null:
		game_session.select_character("guilherme")

	# Direciona imediatamente para a primeira fase
	var err := get_tree().change_scene_to_file(FIRST_LEVEL_SCENE)
	if err != OK:
		printerr("Erro ao carregar a Fase 1: ", err)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
