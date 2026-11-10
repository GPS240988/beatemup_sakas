class_name MainMenu
extends Control

## Menu Principal Arcade — Beat 'em Up Sakas
## Design System Neo-16-bit Urban Arcade (Vila Prudente Temporal).
## 4 Opções Canônicas: JOGAR (Novo Jogo), CONTINUAR (Mapa direto), CONFIGURAÇÕES e SAIR.
## Utiliza o cenário cinematográfico da locadora (locadora.webp) e botões ArcadeButton customizados.

const TITLE_SCREEN_SCENE: String = "res://scenes/ui/title_screen.tscn"
const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const MAP_MENU_SCENE: String = "res://scenes/ui/map_menu.tscn"
const BGM_MENU: String = "res://assets/audio/bgm/Menu.mp3"

const SFX_MOVE_PATH := "res://assets/audio/sfx/Mover Cursor_sfx_move.mp3"
const SFX_CONFIRM_PATH := "res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3"
const SFX_DENIED_PATH := "res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3"

const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")
const ArcadeButtonClass = preload("res://scripts/ui/components/arcade_button.gd")
const SettingsPanelClass = preload("res://scripts/ui/components/settings_panel.gd")

@onready var background_image: TextureRect = %BackgroundImage
@onready var buttons_container: VBoxContainer = %ButtonsContainer
@onready var btn_play: Button = %BtnPlay
@onready var btn_continue: Button = %BtnContinue
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit
@onready var settings_panel: Control = %SettingsPanel
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var _buttons: Array[Button] = []
var _current_index: int = 0
var _is_transitioning: bool = false
var _is_in_settings: bool = false
var _accept_input: bool = false

var _sfx_move: AudioStream
var _sfx_confirm: AudioStream
var _sfx_denied: AudioStream


func _ready() -> void:
	_init_audio()
	_setup_buttons()

	if settings_panel != null:
		settings_panel.visible = false
		settings_panel.settings_origin = "main_menu"
		settings_panel.closed.connect(_on_settings_closed)

	# Assegura a reprodução contínua da BGM do Menu
	var session = get_node_or_null("/root/GameSession")
	if session != null and session.has_method("play_bgm"):
		session.play_bgm(BGM_MENU, -4.0, 1.0)

	if _is_mobile_runtime():
		_apply_mobile_fullscreen()

	# Aguarda frame para resolução correta de layout e atribuição de foco inicial
	await get_tree().process_frame
	if not _is_mobile_runtime() and _buttons.size() > 0:
		_focus_button(0, false)

	# Debounce de entrada para evitar que a tecla Enter da tela de abertura vaze
	# e acione imediatamente a primeira opção do menu
	await get_tree().create_timer(0.2).timeout
	_accept_input = true


func _init_audio() -> void:
	if ResourceLoader.exists(SFX_MOVE_PATH):
		_sfx_move = load(SFX_MOVE_PATH) as AudioStream
	if ResourceLoader.exists(SFX_CONFIRM_PATH):
		_sfx_confirm = load(SFX_CONFIRM_PATH) as AudioStream
	if ResourceLoader.exists(SFX_DENIED_PATH):
		_sfx_denied = load(SFX_DENIED_PATH) as AudioStream


func _setup_buttons() -> void:
	_buttons = [btn_play, btn_continue, btn_settings, btn_quit]

	for i in range(_buttons.size()):
		var btn := _buttons[i]
		if btn == null:
			continue
		var idx := i
		btn.mouse_entered.connect(func(): _on_button_hovered(idx))
		btn.focus_entered.connect(func(): _on_button_focus_entered(idx))
		btn.pressed.connect(func(): _on_button_pressed(idx))


func _is_mobile_runtime() -> bool:
	return MobileScreenAction.is_mobile_runtime()


func _apply_mobile_fullscreen() -> void:
	if background_image != null:
		background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _focus_button(index: int, play_sound: bool = true) -> void:
	if index < 0 or index >= _buttons.size():
		return
	_current_index = index
	var target_btn := _buttons[_current_index]
	if target_btn != null and not target_btn.has_focus():
		target_btn.grab_focus()
	if play_sound:
		_play_sfx(_sfx_move)


func _on_button_focus_entered(index: int) -> void:
	if _is_mobile_runtime() or _is_in_settings or _is_transitioning:
		return
	if _current_index != index:
		_current_index = index
		_play_sfx(_sfx_move)


func _on_button_hovered(index: int) -> void:
	if _is_mobile_runtime() or _is_in_settings or _is_transitioning:
		return
	if _current_index != index:
		_focus_button(index, true)


func _on_button_pressed(index: int) -> void:
	if _is_transitioning or _is_in_settings:
		return
	_current_index = index
	_activate_option(index)


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning or _is_in_settings or not _accept_input:
		return

	if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_S or event.keycode == KEY_DOWN)):
		_safe_handle_input()
		_navigate_selection(1)
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_W or event.keycode == KEY_UP)):
		_safe_handle_input()
		_navigate_selection(-1)
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		var active_idx := _current_index
		var focused_ctrl = get_viewport().gui_get_focus_owner()
		for i in range(_buttons.size()):
			if _buttons[i] == focused_ctrl:
				active_idx = i
				break
		_activate_option(active_idx)
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_return_to_title_screen()


func _navigate_selection(delta: int) -> void:
	if _buttons.is_empty():
		return
	var next_idx := (_current_index + delta) % _buttons.size()
	if next_idx < 0:
		next_idx += _buttons.size()
	_focus_button(next_idx, true)


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _activate_option(index: int) -> void:
	if _is_transitioning:
		return

	match index:
		0: # JOGAR — Inicia nova campanha com reset apropriado
			_is_transitioning = true
			_play_sfx(_sfx_confirm)
			var session = get_node_or_null("/root/GameSession")
			if session != null and session.has_method("reset_session"):
				session.reset_session()
			# Dispara prefetch/stream da história em segundo plano durante a seleção de personagem
			var pack_mgr = get_node_or_null("/root/PackManager")
			if pack_mgr != null and pack_mgr.has_method("ensure_pack_loaded_async"):
				pack_mgr.ensure_pack_loaded_async("story_cinematics")
			await get_tree().create_timer(0.25).timeout
			get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

		1: # CONTINUAR — Abre diretamente o mapa com a progressão atual
			_is_transitioning = true
			_play_sfx(_sfx_confirm)
			var session = get_node_or_null("/root/GameSession")
			if session != null:
				session.set_meta("map_entry_context", "continue")
				if session.has_method("load_campaign_progression"):
					session.load_campaign_progression()
			await get_tree().create_timer(0.25).timeout
			get_tree().change_scene_to_file(MAP_MENU_SCENE)

		2: # CONFIGURAÇÕES — Abre o painel integrado funcional
			_play_sfx(_sfx_confirm)
			_open_settings()

		3: # SAIR — Encerra o jogo no Desktop ou invoca saída Web
			_is_transitioning = true
			_play_sfx(_sfx_confirm)
			await get_tree().create_timer(0.2).timeout
			_quit_game()


func _open_settings() -> void:
	_is_in_settings = true
	if settings_panel != null:
		settings_panel.visible = true
		settings_panel.set("settings_origin", "main_menu")
		var back_btn: Button = settings_panel.get_node_or_null("%BtnBack") as Button
		if back_btn != null:
			back_btn.grab_focus()


func _on_settings_closed(_origin: String) -> void:
	_is_in_settings = false
	if settings_panel != null:
		settings_panel.visible = false
	# Devolve o foco ao botão de Configurações
	if btn_settings != null and not _is_mobile_runtime():
		btn_settings.grab_focus()


func _return_to_title_screen() -> void:
	_is_transitioning = true
	_play_sfx(_sfx_denied)
	get_tree().change_scene_to_file(TITLE_SCREEN_SCENE)


func _quit_game() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (typeof window.sakasQuitGame === 'function') { window.sakasQuitGame(); }")
	get_tree().quit()


func _play_sfx(stream: AudioStream) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()
