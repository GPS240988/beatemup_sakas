class_name PrototypeHud
extends CanvasLayer

## Gerenciador Geral da HUD Oficial Arcade do Projeto Sakas
## Conecta os módulos PlayerHUD (Superior Esquerdo), CenterHUD (Centro Superior)
## e EnemyHUD (Superior Direito) em estrita conformidade com a referência visual 2.

@onready var player_hud: PlayerHUD = %PlayerHUD
@onready var center_hud: CenterHUD = %CenterHUD
@onready var enemy_hud: EnemyHUD = %EnemyHUD

@onready var banner_panel: PanelContainer = %BannerPanel
@onready var banner_label: Label = %BannerLabel

@onready var touch_controls: TouchControls = $TouchControls

# Nós de compatibilidade herdada
@onready var game_hud: MarginContainer = %GameHUD
@onready var debug_margin: MarginContainer = %MarginContainer
@onready var label_level_name: Label = %LevelNameLabel
@onready var label_controls: Label = %ControlsLabel
@onready var label_debug_pos: Label = %DebugPosLabel
@onready var label_debug_status: Label = %DebugStatusLabel
@onready var player_health_bar: ProgressBar = %PlayerHealthBar
@onready var player_health_label: Label = %PlayerHealthLabel
@onready var enemy_health_bar: ProgressBar = %EnemyHealthBar
@onready var enemy_health_label: Label = %EnemyHealthLabel
@onready var touch_toggle_btn: Button = %TouchToggleBtn

# Game Over overlay
@onready var game_over_layer: CanvasLayer = get_node_or_null("%GameOverLayer") as CanvasLayer
@onready var game_over_rect: TextureRect = get_node_or_null("%GameOverRect") as TextureRect

var _game_over_active: bool = false
var _can_restart: bool = false
var _game_over_tween: Tween = null
var _restart_scene_path: String = ""


func _ready() -> void:
	if label_level_name != null:
		label_level_name.text = "FASE: TEST STREET (Beat 'em Up 2.5D)"
	if label_controls != null:
		label_controls.text = "PC: [WASD] Mover | [J] Soco | [K] Chute | [O] Especial | [Espaço] Voadora | [Esc] Pausa"

	if banner_panel != null:
		banner_panel.visible = false

	# Ao iniciar o jogo / emular com F5, os botões e analógico touch iniciam sempre OCULTOS no Desktop
	set_touch_controls_visible(false)

	if touch_toggle_btn != null:
		touch_toggle_btn.pressed.connect(_on_touch_toggle_pressed)
		_update_toggle_btn_text()

	_update_debug_display(Vector2.ZERO, Vector2.ZERO)

	# Game Over layer inicia oculto
	if game_over_layer != null:
		game_over_layer.visible = false
	if game_over_rect != null:
		game_over_rect.modulate.a = 0.0


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
	if player_hud != null:
		player_hud.set_hp(current, max_val)


## Vincula o nó do Jogador diretamente à HUD
func bind_player(player: Node) -> void:
	if player_hud != null:
		player_hud.bind_player(player)


func set_player_name(value: String) -> void:
	if player_hud != null:
		player_hud.set_player_name(value)


func set_portrait(texture: Texture2D) -> void:
	if player_hud != null:
		player_hud.set_portrait(texture)


func set_level(value: int) -> void:
	if player_hud != null and player_hud.has_method("set_level"):
		player_hud.set_level(value)
	if center_hud != null:
		center_hud.set_stage_index(value)


func set_stage_name(value: String) -> void:
	if center_hud != null:
		center_hud.set_stage_text(value)
	if label_level_name != null:
		label_level_name.text = value


func set_continues(value: int) -> void:
	if player_hud != null:
		player_hud.set_continues(value)


func set_combo_hits(hits: int) -> void:
	if player_hud != null:
		player_hud.set_combo_hits(hits)


func set_special(current: float, max_val: float) -> void:
	if player_hud != null:
		player_hud.set_special(current, max_val)


func toggle_debug_hud() -> void:
	if debug_margin != null:
		debug_margin.visible = not debug_margin.visible


## Atualiza a vida do inimigo na HUD
func update_enemy_health(current: float, max_val: float) -> void:
	if enemy_health_bar != null:
		enemy_health_bar.max_value = max_val
		enemy_health_bar.value = current
	if enemy_health_label != null:
		enemy_health_label.text = "Inimigo: %d / %d HP" % [int(current), int(max_val)]
	if enemy_hud != null:
		enemy_hud.set_enemy_health(current, max_val)


func set_stage_section(stage: int, section: int = 1) -> void:
	if center_hud != null:
		center_hud.set_stage_index(stage, section)


func set_stage(stage_num: int, section_num: int = 1) -> void:
	if center_hud != null:
		center_hud.set_stage_index(stage_num, section_num)


func set_enemy_target(enemy_node: Node, from_player_hit: bool = false) -> void:
	if enemy_hud != null:
		enemy_hud.target_enemy(enemy_node, from_player_hit)


func set_enemy_name(value: String) -> void:
	if enemy_hud != null:
		enemy_hud.set_enemy_name(value)


func set_enemy_portrait(tex: Texture2D) -> void:
	if enemy_hud != null:
		enemy_hud.set_enemy_portrait(tex)


## Atualiza o estado da ação do jogador
func update_player_state(state_name: String) -> void:
	if label_debug_status != null:
		label_debug_status.text = "Estado: %s" % state_name


## Exibe a tela de Game Over com fade-in da imagem game_over.webp por ~5 segundos.
## Somente após a conclusão da animação o jogador tem permissão para pressionar [R] e reiniciar.
## O caminho da cena a reiniciar é definido por set_restart_scene().
func show_game_over() -> void:
	if _game_over_active:
		return
	_game_over_active = true
	_can_restart = false

	# Oculta banners antigos se visíveis
	if banner_panel != null:
		banner_panel.visible = false

	if game_over_layer == null or game_over_rect == null:
		# Fallback: usa o banner legado se o layer não existir
		if banner_panel != null and banner_label != null:
			banner_panel.visible = true
			banner_label.text = "☠️ GAME OVER"
			banner_label.modulate = Color(1.0, 0.35, 0.35)
		_can_restart = true
		return

	# Exibe a camada
	game_over_layer.visible = true
	game_over_rect.modulate.a = 0.0

	if _game_over_tween != null and _game_over_tween.is_valid():
		_game_over_tween.kill()

	# Fade in da imagem de Game Over por aproximadamente 5 segundos
	_game_over_tween = create_tween()
	_game_over_tween.tween_property(game_over_rect, "modulate:a", 1.0, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Somente após o término completo do fade in (5s), libera a ação de reiniciar
	_game_over_tween.tween_callback(func():
		_can_restart = true
	)


## Define o caminho da cena a ser carregada quando R é pressionado no Game Over
func set_restart_scene(scene_path: String) -> void:
	_restart_scene_path = scene_path


## Processa entrada de reiniciar durante o Game Over apenas após o término do fade in (5s)
func _unhandled_input(event: InputEvent) -> void:
	if not _game_over_active or not _can_restart:
		return

	if event.is_action_pressed("restart"):
		_restart_current_stage()


## Reinicia a fase correspondente ao mapa atual com continues zerado
func _restart_current_stage() -> void:
	if not _game_over_active or not _can_restart:
		return

	# Reseta progresso da fase e define continues como 0 (zerado após Game Over, e não 1)
	var session: Node = get_node_or_null("/root/GameSession")
	if session != null:
		if "current_continues" in session:
			session.current_continues = 0
		if session.has_method("clear_player_progression"):
			session.clear_player_progression()

	if not _restart_scene_path.is_empty():
		get_tree().change_scene_to_file(_restart_scene_path)
	else:
		# Fallback: recarrega a cena atual
		get_tree().reload_current_scene()


## Exibe mensagem de vitória sobre o inimigo
func show_victory() -> void:
	if banner_panel != null and banner_label != null:
		banner_panel.visible = true
		banner_label.text = "🏆 INIMIGO DERROTADO!\nPressione [R] para Reiniciar"
		banner_label.modulate = Color(0.4, 1.0, 0.4)


func _update_debug_display(pos: Vector2, vel: Vector2) -> void:
	if label_debug_pos != null:
		label_debug_pos.text = "Posição (Chão): X=%.1f | Y=%.1f" % [pos.x, pos.y]
