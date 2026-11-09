class_name MapMenu
extends Control

## Tela de Mapa da Vila / Seleção de Fases — Projeto Sakas
## Design System Neo-16-bit Urban Arcade baseado em sakas-map.webp e no protótipo oficial.
## Recursos:
## - Topbar com botão Voltar ao Menu Principal e Botão de Pausa/Configurações
## - Hotspots interativos com medalhões arcade e indicador de seleção pulsante
## - Card inferior esquerdo com número da fase em ouro e título selecionado
## - Botão "JOGAR FASE" (ArcadeButton primário) no canto inferior direito
## - Suporte a Mouse, Touch, Teclado e Gamepad

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const MAP_IMAGE_PATH: String = "res://assets/backgrounds/sakas-map.webp"
const FALLBACK_MAP_IMAGE_PATH: String = "res://assets/backgrounds/Mapa.webp"

const SFX_MOVE_PATH := "res://assets/audio/sfx/Mover Cursor_sfx_move.mp3"
const SFX_CONFIRM_PATH := "res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3"
const SFX_CANCEL_PATH := "res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3"

const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")
const ArcadeButtonClass = preload("res://scripts/ui/components/arcade_button.gd")
const MapStagePointScene = preload("res://scenes/ui/components/map_stage_point.tscn")
const SettingsPanelClass = preload("res://scripts/ui/components/settings_panel.gd")

const STAGE_CONFIGS: Array[Dictionary] = [
	{
		"id": "01",
		"title": "O REENCONTRO",
		"tag": "O REENCONTRO",
		"pos_ratio": Vector2(0.13, 0.38),
		"scene": "res://scenes/levels/map_1.tscn",
		"loading_scene": "res://scenes/ui/loading_screen.tscn"
	},
	{
		"id": "B",
		"title": "GARAGEM",
		"tag": "BÔNUS",
		"pos_ratio": Vector2(0.30, 0.31),
		"scene": "res://scenes/levels/bonus_garage.tscn",
		"loading_scene": "res://scenes/levels/bonus_garage.tscn"
	},
	{
		"id": "02",
		"title": "HAPPEN",
		"tag": "HAPPEN",
		"pos_ratio": Vector2(0.46, 0.29),
		"scene": "res://scenes/levels/map_2.tscn",
		"loading_scene": "res://scenes/levels/map_2.tscn"
	},
	{
		"id": "03",
		"title": "METRÔ",
		"tag": "METRÔ",
		"pos_ratio": Vector2(0.655, 0.35),
		"scene": "res://scenes/levels/map_3.tscn",
		"loading_scene": "res://scenes/levels/map_3.tscn"
	}
]

@onready var background_texture: TextureRect = %BackgroundTexture
@onready var btn_back: Button = %BtnBack
@onready var btn_pause: Button = get_node_or_null("%BtnPause") as Button
@onready var btn_play_stage: Button = %BtnPlayStage
@onready var stage_number_label: Label = %StageNumberLabel
@onready var stage_title_label: Label = %StageTitleLabel
@onready var map_status_label: Label = %MapStatusLabel
@onready var hotspots_container: Control = %HotspotsContainer
@onready var audio_player: AudioStreamPlayer = %AudioPlayer
@onready var settings_panel: Control = get_node_or_null("%SettingsPanel") as Control

var _selected_index: int = 0
var _is_transitioning: bool = false
var _is_in_settings: bool = false
var _entry_context: String = ""

var _sfx_move: AudioStream
var _sfx_confirm: AudioStream
var _sfx_cancel: AudioStream

var _hotspot_nodes: Array[Control] = []


func _ready() -> void:
	var session := _get_game_session()
	if session != null and session.has_meta("map_entry_context"):
		_entry_context = str(session.get_meta("map_entry_context"))

	_init_audio()
	_load_background_image()
	_build_stage_hotspots()
	_setup_top_and_footer_buttons()

	if hotspots_container != null:
		hotspots_container.resized.connect(_update_hotspot_positions)

	var pack_mgr = get_node_or_null("/root/PackManager")
	if pack_mgr != null and pack_mgr.has_signal("pack_progress"):
		pack_mgr.pack_progress.connect(_on_pack_progress)

	if settings_panel != null:
		settings_panel.visible = false
		settings_panel.set("settings_origin", "map_menu")
		if settings_panel.has_signal("closed"):
			settings_panel.connect("closed", Callable(self, "_on_settings_closed"))

	# Seleciona inicialmente a Fase 1
	_select_stage(0, false)

	# Atualiza o layout responsivo no próximo frame
	await get_tree().process_frame
	_update_hotspot_positions()


func _init_audio() -> void:
	if ResourceLoader.exists(SFX_MOVE_PATH):
		_sfx_move = load(SFX_MOVE_PATH) as AudioStream
	if ResourceLoader.exists(SFX_CONFIRM_PATH):
		_sfx_confirm = load(SFX_CONFIRM_PATH) as AudioStream
	if ResourceLoader.exists(SFX_CANCEL_PATH):
		_sfx_cancel = load(SFX_CANCEL_PATH) as AudioStream


func _load_background_image() -> void:
	if background_texture == null:
		return
	if ResourceLoader.exists(MAP_IMAGE_PATH):
		background_texture.texture = load(MAP_IMAGE_PATH) as Texture2D
	elif ResourceLoader.exists(FALLBACK_MAP_IMAGE_PATH):
		background_texture.texture = load(FALLBACK_MAP_IMAGE_PATH) as Texture2D


func _setup_top_and_footer_buttons() -> void:
	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_pause != null:
		btn_pause.pressed.connect(_on_pause_pressed)
	if btn_play_stage != null:
		btn_play_stage.pressed.connect(_on_play_stage_pressed)


func _build_stage_hotspots() -> void:
	if hotspots_container == null:
		return

	for child in hotspots_container.get_children():
		child.queue_free()
	_hotspot_nodes.clear()

	for i in range(STAGE_CONFIGS.size()):
		var cfg := STAGE_CONFIGS[i]
		var idx := i
		var is_unlocked := is_stage_unlocked(idx)

		var point_instance: Control = MapStagePointScene.instantiate()
		point_instance.name = "StagePoint_%s" % cfg["id"]
		hotspots_container.add_child(point_instance)
		_hotspot_nodes.append(point_instance)

		if point_instance.has_method("setup"):
			point_instance.setup(idx, str(cfg["id"]), str(cfg["title"]), str(cfg.get("tag", cfg["title"])), is_unlocked)

		if point_instance.has_signal("stage_clicked"):
			point_instance.connect("stage_clicked", Callable(self, "_on_hotspot_clicked"))


func _update_hotspot_positions() -> void:
	if hotspots_container == null:
		return
	var c_size := hotspots_container.size
	if c_size.x <= 0 or c_size.y <= 0:
		c_size = Vector2(1280, 720)

	for i in range(_hotspot_nodes.size()):
		var node := _hotspot_nodes[i]
		if node == null or not is_instance_valid(node):
			continue
		var cfg := STAGE_CONFIGS[i]
		var ratio: Vector2 = cfg["pos_ratio"]
		var half_size: Vector2 = node.size * 0.5
		if half_size == Vector2.ZERO:
			half_size = Vector2(55, 55)
		node.position = Vector2(ratio.x * c_size.x - half_size.x, ratio.y * c_size.y - half_size.y)


func _on_hotspot_clicked(index: int) -> void:
	if _is_transitioning or _is_in_settings:
		return

	if index == _selected_index:
		# Se já está selecionada e clica nela novamente, inicia a fase
		_on_play_stage_pressed()
	else:
		_select_stage(index, true)


func _select_stage(index: int, play_sound: bool = true) -> void:
	if index < 0 or index >= STAGE_CONFIGS.size():
		return
	_selected_index = index
	var cfg := STAGE_CONFIGS[_selected_index]
	var is_unlocked := is_stage_unlocked(_selected_index)

	# Atualiza os marcadores no mapa
	for i in range(_hotspot_nodes.size()):
		var node := _hotspot_nodes[i]
		if node != null and node.has_method("set_selected"):
			node.set_selected(i == _selected_index)

	# Atualiza card de seleção no rodapé
	if stage_number_label != null:
		stage_number_label.text = str(cfg["id"])
	if stage_title_label != null:
		stage_title_label.text = str(cfg["title"])

	# Atualiza status
	if map_status_label != null:
		if is_unlocked:
			map_status_label.text = "%s · SELECIONADA" % str(cfg["title"])
			map_status_label.modulate = Color(0.0, 0.94, 1.0, 1.0)
		else:
			map_status_label.text = "%s · AINDA BLOQUEADA" % str(cfg["title"])
			map_status_label.modulate = Color(1.0, 0.45, 0.45, 0.9)

	# Configura botão JOGAR FASE
	if btn_play_stage != null:
		btn_play_stage.set("disabled", not is_unlocked)

	if play_sound:
		_play_sfx(_sfx_move if is_unlocked else _sfx_cancel)


func is_stage_unlocked(index: int) -> bool:
	if index == 0:
		return true # Fase 1: O Reencontro (sempre desbloqueada)
	if index == 1:
		return true # B: Garagem (Bônus 1 disponível inicialmente para teste)

	var session := _get_game_session()
	if session == null:
		return false

	match index:
		2: # FASE 2 (HAPPEN)
			return session.has_method("is_stage_2_unlocked") and session.is_stage_2_unlocked()
		3: # FASE 3 (METRÔ)
			var max_stage: int = session.max_unlocked_stage if "max_unlocked_stage" in session else 1
			return max_stage >= 3
		_:
			return false


func _on_pack_progress(_pack_id: String, loaded: int, total: int, pct: float) -> void:
	if map_status_label != null and _is_transitioning:
		var mb_loaded := float(loaded) / (1024.0 * 1024.0)
		var mb_total := float(total) / (1024.0 * 1024.0)
		if mb_total > 0.0:
			map_status_label.text = "BAIXANDO FASE... %.1f MB / %.1f MB (%d%%)" % [mb_loaded, mb_total, int(pct)]
		else:
			map_status_label.text = "BAIXANDO RECURSOS... %d%%" % int(pct)


func _on_play_stage_pressed() -> void:
	if _is_transitioning or _is_in_settings:
		return
	if not is_stage_unlocked(_selected_index):
		_play_sfx(_sfx_cancel)
		return

	_is_transitioning = true
	_play_sfx(_sfx_confirm)

	var session := _get_game_session()
	if session != null:
		session.set_meta("selected_stage_index", _selected_index)
		if not ("selected_character_id" in session) or str(session.selected_character_id).is_empty():
			session.selected_character_id = "guilherme"
		if not ("difficulty_id" in session) or str(session.difficulty_id).is_empty():
			session.difficulty_id = "normal"

	# Streaming inteligente sob demanda: assegura os pacotes necessários
	var pack_mgr = get_node_or_null("/root/PackManager")
	if pack_mgr != null and pack_mgr.has_method("ensure_pack_loaded_async"):
		if _selected_index == 0:
			if not pack_mgr.is_pack_mounted("stage1") or not pack_mgr.is_pack_mounted("audio_bgm"):
				if map_status_label != null:
					map_status_label.text = "CARREGANDO RECURSOS DA FASE 1..."
					map_status_label.modulate = Color(0, 0.94, 1, 1)
				var ok_stage1 = await pack_mgr.ensure_pack_loaded_async("stage1")
				var ok_bgm = await pack_mgr.ensure_pack_loaded_async("audio_bgm")
				if not ok_stage1 or not ok_bgm:
					_is_transitioning = false
					if map_status_label != null:
						map_status_label.text = "FALHA NA CONEXÃO. TOQUE PARA REPETIR."
						map_status_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
					return
		elif _selected_index == 1:
			if not pack_mgr.is_pack_mounted("audio_bgm"):
				await pack_mgr.ensure_pack_loaded_async("audio_bgm")

	var cfg := STAGE_CONFIGS[_selected_index]
	var target_scene: String = str(cfg.get("scene", ""))

	# Para a fase 1, direciona para o primeiro mapa (ou loading se novo)
	if _selected_index == 0:
		if session != null and "has_played_intro" in session and not session.has_played_intro and _entry_context != "continue":
			target_scene = "res://scenes/ui/loading_screen.tscn"
		else:
			target_scene = "res://scenes/levels/map_1.tscn"
	elif _selected_index == 1:
		# BÔNUS: Vai diretamente para a garagem bonus1
		target_scene = "res://scenes/levels/bonus_garage.tscn"

	await get_tree().create_timer(0.2).timeout
	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		_is_transitioning = false
		printerr("Erro ao transicionar para a fase selecionada: ", err)


func _on_back_pressed() -> void:
	if _is_transitioning or _is_in_settings:
		return
	_is_transitioning = true
	_play_sfx(_sfx_cancel)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_pause_pressed() -> void:
	if _is_transitioning or _is_in_settings:
		return
	_play_sfx(_sfx_confirm)
	_open_settings()


func _open_settings() -> void:
	_is_in_settings = true
	if settings_panel != null:
		settings_panel.visible = true
		settings_panel.set("settings_origin", "map_menu")


func _on_settings_closed(_origin: String) -> void:
	_is_in_settings = false
	if settings_panel != null:
		settings_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning or _is_in_settings:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_on_back_pressed()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_RIGHT or event.keycode == KEY_D)):
		_safe_handle_input()
		_navigate_stages(1)
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_LEFT or event.keycode == KEY_A)):
		_safe_handle_input()
		_navigate_stages(-1)
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		_on_play_stage_pressed()


func _navigate_stages(delta: int) -> void:
	var next_idx := (_selected_index + delta) % STAGE_CONFIGS.size()
	if next_idx < 0:
		next_idx += STAGE_CONFIGS.size()
	_select_stage(next_idx, true)


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _get_game_session() -> Node:
	if is_inside_tree():
		var gs = get_node_or_null("/root/GameSession")
		if gs != null:
			return gs
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null("GameSession")
	return null


func _play_sfx(stream: AudioStream) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()
