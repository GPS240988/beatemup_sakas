class_name PrototypeHud
extends CanvasLayer

@onready var label_level_name: Label = %LevelNameLabel
@onready var label_controls: Label = %ControlsLabel
@onready var label_debug_pos: Label = %DebugPosLabel
@onready var label_debug_status: Label = %DebugStatusLabel

@onready var player_health_bar: ProgressBar = %PlayerHealthBar
@onready var player_health_label: Label = %PlayerHealthLabel

@onready var enemy_health_bar: ProgressBar = %EnemyHealthBar
@onready var enemy_health_label: Label = %EnemyHealthLabel

@onready var banner_panel: PanelContainer = %BannerPanel
@onready var banner_label: Label = %BannerLabel

@onready var touch_controls: TouchControls = $TouchControls
@onready var touch_toggle_btn: Button = %TouchToggleBtn


func _ready() -> void:
	if label_level_name != null:
		label_level_name.text = "FASE: TEST STREET (Beat 'em Up 2.5D)"
	if label_controls != null:
		label_controls.text = "PC: [WASD] Mover | [J] Soco | [K] Chute | [L] Especial | [U] Aéreo | [Espaço] Bloqueio | [R] Reiniciar"

	if banner_panel != null:
		banner_panel.visible = false

	# Ao iniciar o jogo / emular com F5, os botões e analógico touch iniciam sempre OCULTOS (tela limpa)
	set_touch_controls_visible(false)

	if touch_toggle_btn != null:
		touch_toggle_btn.pressed.connect(_on_touch_toggle_pressed)
		_update_toggle_btn_text()

	_update_debug_display(Vector2.ZERO, Vector2.ZERO)


## Alterna manualmente a exibição dos controles na tela (para Mobile ou teste no PC)
func set_touch_controls_visible(enable: bool) -> void:
	if touch_controls != null:
		touch_controls.visible = enable
	_update_toggle_btn_text()


func _on_touch_toggle_pressed() -> void:
	if touch_controls != null:
		set_touch_controls_visible(not touch_controls.visible)


func _update_toggle_btn_text() -> void:
	if touch_toggle_btn != null and touch_controls != null:
		touch_toggle_btn.text = "📱 Controles Touch: LIGADO" if touch_controls.visible else "📱 Controles Touch: DESLIGADO"


## Atualiza as métricas de movimento
func on_player_moved(pos: Vector2, vel: Vector2) -> void:
	_update_debug_display(pos, vel)


## Atualiza a vida do jogador na HUD
func update_player_health(current: float, max_val: float) -> void:
	if player_health_bar != null:
		player_health_bar.max_value = max_val
		player_health_bar.value = current
	if player_health_label != null:
		player_health_label.text = "Jogador: %d / %d HP" % [int(current), int(max_val)]


## Atualiza a vida do inimigo na HUD
func update_enemy_health(current: float, max_val: float) -> void:
	if enemy_health_bar != null:
		enemy_health_bar.max_value = max_val
		enemy_health_bar.value = current
	if enemy_health_label != null:
		enemy_health_label.text = "Inimigo: %d / %d HP" % [int(current), int(max_val)]


## Atualiza o estado da ação do jogador
func update_player_state(state_name: String) -> void:
	if label_debug_status != null:
		label_debug_status.text = "Estado: %s" % state_name


## Exibe mensagem de derrota do jogador
func show_game_over() -> void:
	if banner_panel != null and banner_label != null:
		banner_panel.visible = true
		banner_label.text = "☠️ VOCÊ FOI DERROTADO!\nPressione [R] para Reiniciar"
		banner_label.modulate = Color(1.0, 0.35, 0.35)


## Exibe mensagem de vitória sobre o inimigo
func show_victory() -> void:
	if banner_panel != null and banner_label != null:
		banner_panel.visible = true
		banner_label.text = "🏆 INIMIGO DERROTADO!\nPressione [R] para Reiniciar"
		banner_label.modulate = Color(0.4, 1.0, 0.4)


func _update_debug_display(pos: Vector2, vel: Vector2) -> void:
	if label_debug_pos != null:
		label_debug_pos.text = "Posição (Chão): X=%.1f | Y=%.1f" % [pos.x, pos.y]
