class_name MapMenu
extends Control

## Tela de Mapa da Vila / Seleção Cinematográfica de Fases — Projeto Sakas
## Arquitetura de Navegação do Overview e dos mapas internos dos Estágios 01 e 02.
## Design System Neo-16-bit Urban Arcade baseado em mapa_base.webp (1920x1080).
## Câmera Virtual suave com Bounding Clamping rígido e Interrupção Retarget.
## Painel Narrativo Fixo com extração canônica de enredo.

enum NavState {
	OVERVIEW,            # Nível A: Visão geral da campanha (panorâmica completa)
	ENTERING_STAGE,      # Transição e aproximação de câmera ao interior do estágio
	STAGE_NAVIGATION,    # Nível B: Navegação interna das localidades do Stage 01
	STAGE2_NAVIGATION,   # Nível B: Navegação interna das localidades do Stage 02
	CAMERA_TRAVEL,       # Deslocamento suave entre localidades (com retarget)
	STARTING_MISSION,    # Disparo e transição de cena
	RETURNING            # Retorno cinematográfico do estágio para a visão geral
}

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const MAP_IMAGE_PATH: String = "res://assets/backgrounds/mapa_base.webp"
const FALLBACK_MAP_IMAGE_PATH: String = "res://assets/backgrounds/sakas-map.webp"

const SFX_MOVE_PATH := "res://assets/audio/sfx/Mover Cursor_sfx_move.mp3"
const SFX_CONFIRM_PATH := "res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3"
const SFX_CANCEL_PATH := "res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3"

const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")
const ArcadeButtonClass = preload("res://scripts/ui/components/arcade_button.gd")
const MapStagePointScene = preload("res://scenes/ui/components/map_stage_point.tscn")
const SettingsPanelClass = preload("res://scripts/ui/components/settings_panel.gd")
const MapArrowRendererClass = preload("res://scripts/ui/map_arrow_renderer.gd")
const MapUnlockVFXClass = preload("res://scripts/ui/map_unlock_vfx.gd")

const MAP_WIDTH: float = 1920.0
const MAP_HEIGHT: float = 1080.0
const BASE_ZOOM: float = 1280.0 / 1920.0 # 0.6666667
const STAGE_ZOOM: float = BASE_ZOOM * 1.42 # ~0.9466667

const STAGE_CONFIGS: Array[Dictionary] = [
	{
		"id": "1-1",
		"map_num": 1,
		"title": "A LOCADORA",
		"tag": "A LOCADORA",
		"pos_ratio": Vector2(0.1250, 0.3222), # (240, 348)
		"scene": "res://scenes/levels/map_1.tscn",
		"loading_scene": "res://scenes/story/story_intro.tscn",
		"subtitle": "Início da Jornada · Rua da Locadora"
	},
	{
		"id": "1-2",
		"map_num": 2,
		"title": "BALCÃO DA LOCADORA",
		"tag": "BALCÃO",
		"pos_ratio": Vector2(0.1667, 0.3935), # (320, 425)
		"scene": "res://scenes/levels/map_2.tscn",
		"loading_scene": "res://scenes/levels/map_2.tscn",
		"subtitle": "Interior da Loja · Primeiros Capangas"
	},
	{
		"id": "1-3",
		"map_num": 3,
		"title": "TRAVESSA DA LOCADORA",
		"tag": "TRAVESSA",
		"pos_ratio": Vector2(0.2161, 0.3889), # (415, 420)
		"scene": "res://scenes/levels/map_3.tscn",
		"loading_scene": "res://scenes/levels/map_3.tscn",
		"subtitle": "Beco Externo · Emboscada e Agressores"
	},
	{
		"id": "1-4",
		"map_num": 4,
		"title": "TORQUATO TASSO",
		"tag": "TORQUATO",
		"pos_ratio": Vector2(0.2604, 0.3380), # (500, 365)
		"scene": "res://scenes/levels/map_4.tscn",
		"loading_scene": "res://scenes/levels/map_4.tscn",
		"subtitle": "Bar da Vila · Clímax & Chefe Alessandro"
	},
	{
		"id": "B",
		"map_num": 0,
		"is_bonus": true,
		"title": "GARAGEM",
		"tag": "★ BÔNUS ★",
		"pos_ratio": Vector2(0.3010, 0.2611), # (578, 282)
		"scene": "res://scenes/levels/bonus_garage.tscn",
		"loading_scene": "res://scenes/levels/bonus_garage.tscn",
		"subtitle": "Garagem Secreta · Destruição Bônus"
	},
	{
		"id": "02",
		"map_num": 5,
		"is_future": true,
		"title": "HAPPEN",
		"tag": "ESTÁGIO 02 (EM BREVE)",
		"pos_ratio": Vector2(0.4531, 0.2454), # (870, 265)
		"scene": "",
		"loading_scene": "",
		"subtitle": "Estágio 02 · Em Desenvolvimento"
	}
]

const STAGE2_MAP_CONFIGS: Array[Dictionary] = [
	{
		"id": "2-1",
		"map_num": 5,
		"title": "RUA DA VILA EMA",
		"tag": "RUA DA VILA EMA",
		"pos_ratio": Vector2(0.4531, 0.2454), # (870, 265)
		"scene": "res://scenes/levels/map_5.tscn",
		"subtitle": "Rua da Vila Ema · Chefe Bêbado e punks",
		"objective": "Derrotar o Bêbado e os punks para abrir caminho até a HAPPEN."
	},
	{
		"id": "2-2",
		"map_num": 6,
		"title": "CONVERSA COM PELÉ",
		"tag": "HAPPEN · PELÉ",
		"pos_ratio": Vector2(0.5052, 0.2870), # (970, 310)
		"scene": "res://scenes/levels/map_6.tscn",
		"subtitle": "Calçada da HAPPEN · Negociação com Pelé",
		"objective": "Concluir a conversa com Pelé e obter acesso ao salão da HAPPEN."
	},
	{
		"id": "2-3",
		"map_num": 7,
		"title": "INTERIOR DA HAPPEN",
		"tag": "SALÃO PRINCIPAL",
		"pos_ratio": Vector2(0.5625, 0.3287), # (1080, 355)
		"scene": "res://scenes/levels/map_7.tscn",
		"subtitle": "Salão principal · Mesas, balcão e capangas",
		"objective": "Avançar pelo salão principal da HAPPEN."
	},
	{
		"id": "2-4",
		"map_num": 8,
		"title": "TOALETE",
		"tag": "TOALETE",
		"pos_ratio": Vector2(0.6198, 0.3704), # (1190, 400)
		"scene": "",
		"subtitle": "HAPPEN · Setor do toalete em desenvolvimento",
		"objective": "Localidade planejada. A cena do Map 8 ainda não existe."
	}
]

const ROUTE_SEGMENTS: Array[Array] = [
	# 1-1 to 1-2
	[Vector2(240, 348), Vector2(255, 375), Vector2(280, 405), Vector2(320, 425)],
	# 1-2 to 1-3
	[Vector2(320, 425), Vector2(370, 430), Vector2(415, 420)],
	# 1-3 to 1-4
	[Vector2(415, 420), Vector2(460, 400), Vector2(500, 365)],
	# 1-4 to B
	[Vector2(500, 365), Vector2(535, 325), Vector2(578, 282)],
	# B to 02
	[Vector2(578, 282), Vector2(635, 335), Vector2(700, 340), Vector2(760, 335), Vector2(815, 320), Vector2(850, 305), Vector2(870, 265)]
]

const STAGE2_ROUTE_SEGMENTS: Array[Array] = [
	[Vector2(870, 265), Vector2(920, 285), Vector2(970, 310)],
	[Vector2(970, 310), Vector2(1020, 333), Vector2(1080, 355)],
	[Vector2(1080, 355), Vector2(1135, 378), Vector2(1190, 400)]
]

const MISSION_NARRATIVES: Dictionary = {
	"1-1": {
		"badge": "MISSÃO 1-1",
		"narrative_title": "A ÚLTIMA FICHA",
		"synopsis": "Quatro velhos amigos descobrem uma máquina misteriosa na sala secreta. O passado e o presente colidem na rua tomada por arruaceiros.",
		"objective": "Sobreviver à emboscada na rua da locadora e abrir caminho até a entrada.",
		"locality": "A LOCADORA"
	},
	"1-2": {
		"badge": "MISSÃO 1-2",
		"narrative_title": "INVASÃO NO FLIPERAMA",
		"synopsis": "Os heróis entram na locadora para proteger o fliperama e investigar a anomalia dimensional que distorce a realidade do bairro.",
		"objective": "Limpar o interior da loja, conter os capangas e defender o balcão.",
		"locality": "BALCÃO DA LOCADORA"
	},
	"1-3": {
		"badge": "MISSÃO 1-3",
		"narrative_title": "EMBOSCADA NA TRAVESSA",
		"synopsis": "André e Juliana deparam-se com hordas de agressores no beco estreito da travessa, cortando a passagem para o bar.",
		"objective": "Romper o bloqueio dos agressores na travessa e alcançar a Torquato Tasso.",
		"locality": "TRAVESSA DA LOCADORA"
	},
	"1-4": {
		"badge": "MISSÃO 1-4",
		"narrative_title": "O BECO FINAL & ALESSANDRO",
		"synopsis": "Em frente ao bar na Torquato Tasso, os heróis encontram Alessandro transtornado e possuído pela influência do jogo.",
		"objective": "Neutralizar e conter o chefe Alessandro para trazê-lo de volta à razão.",
		"locality": "TORQUATO TASSO"
	},
	"B": {
		"badge": "ESTÁGIO BÔNUS",
		"narrative_title": "DESTRUIÇÃO NA GARAGEM",
		"synopsis": "Uma garagem suspeita esconde veículos do submundo da vila. Destrua-os antes que o tempo se esgote.",
		"objective": "Destruir completamente os 2 veículos da oficina dentro do limite de 40 segundos.",
		"locality": "A GARAGEM"
	},
	"02": {
		"badge": "ESTÁGIO 02",
		"narrative_title": "AVENIDA DOS ACONTECIMENTOS",
		"synopsis": "A rota comercial que leva à estação do metrô. Sob controle de sindicatos rivais e barricadas pesadas.",
		"objective": "Em desenvolvimento — Desbloqueado para debug.",
		"locality": "HAPPEN"
	}
}

@onready var map_container: Control = %MapContainer
@onready var background_texture: TextureRect = %BackgroundTexture
@onready var btn_back: Button = %BtnBack
@onready var btn_pause: Button = get_node_or_null("%BtnPause") as Button
@onready var btn_play_stage: Button = %BtnPlayStage
@onready var eyebrow_label: Label = get_node_or_null("%EyebrowLabel") as Label
@onready var title_label: Label = get_node_or_null("%TitleLabel") as Label

@onready var narrative_panel: Control = get_node_or_null("%NarrativePanel") as Control
@onready var narrative_badge: Label = get_node_or_null("%NarrativeBadge") as Label
@onready var narrative_title: Label = get_node_or_null("%NarrativeTitle") as Label
@onready var narrative_synopsis: Label = get_node_or_null("%NarrativeSynopsis") as Label
@onready var narrative_objective: Label = get_node_or_null("%NarrativeObjective") as Label
@onready var narrative_state_badge: Label = get_node_or_null("%NarrativeStateBadge") as Label

@onready var stage_number_label: Label = %StageNumberLabel
@onready var stage_title_label: Label = %StageTitleLabel
@onready var stage_subtitle_label: Label = get_node_or_null("%StageSubtitleLabel") as Label
@onready var map_status_label: Label = %MapStatusLabel
@onready var status_dot: ColorRect = get_node_or_null("%StatusDot") as ColorRect
@onready var hotspots_container: Control = %HotspotsContainer
@onready var route_renderer: Control = get_node_or_null("%RouteRenderer") as Control
@onready var moving_arrow: Node2D = get_node_or_null("%MovingArrow") as Node2D
@onready var unlock_vfx: Node2D = get_node_or_null("%UnlockVFX") as Node2D
@onready var audio_player: AudioStreamPlayer = %AudioPlayer
@onready var settings_panel: Control = get_node_or_null("%SettingsPanel") as Control

var _nav_state: NavState = NavState.OVERVIEW
var _selected_index: int = 0
var _is_transitioning: bool = false
var _is_in_settings: bool = false
var _is_in_section_select: bool = false
var _entry_context: String = ""

var _sfx_move: AudioStream
var _sfx_confirm: AudioStream
var _sfx_cancel: AudioStream

var _hotspot_nodes: Array[Control] = []
var _stage2_hotspot_nodes: Array[Control] = []
var _selected_stage2_index: int = 0
var _camera_tween: Tween = null
var _arrow_tween: Tween = null
var _arrow_bob_tween: Tween = null
var _arrow_blink_tween: Tween = null
var _debug_stage2_force_unlocked: bool = false


func _ready() -> void:
	var session := _get_game_session()
	if session != null:
		if session.has_meta("map_entry_context"):
			_entry_context = str(session.get_meta("map_entry_context"))
		if _entry_context == "continue" and session.has_method("load_campaign_progression"):
			session.load_campaign_progression()

	_init_audio()
	_load_background_image()
	_build_stage_hotspots()
	_build_stage2_hotspots()
	_setup_top_and_footer_buttons()
	_setup_route_renderer()

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

	# Inicializa obrigatoriamente no Nível A (OVERVIEW):
	_nav_state = NavState.OVERVIEW
	_select_stage(0, false, false)

	await get_tree().process_frame
	_update_hotspot_positions()
	_position_arrow(0, false)

	# Fluxo de REPLAY: após seleção de personagem/dificuldade, auto-lança a fase armazenada
	if _entry_context == "replay" and session != null and session.has_meta("replay_stage_index"):
		call_deferred("_auto_launch_replay")



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


func _setup_route_renderer() -> void:
	if route_renderer != null:
		if not route_renderer.draw.is_connected(_on_route_draw):
			route_renderer.draw.connect(_on_route_draw)
		route_renderer.queue_redraw()


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
		var is_done := is_stage_completed(idx)
		var is_bonus := bool(cfg.get("is_bonus", false))

		var point_instance: Control = MapStagePointScene.instantiate()
		point_instance.name = "StagePoint_%s" % cfg["id"]
		hotspots_container.add_child(point_instance)
		_hotspot_nodes.append(point_instance)

		if point_instance.has_method("setup"):
			point_instance.setup(idx, str(cfg["id"]), str(cfg["title"]), str(cfg.get("tag", cfg["title"])), is_unlocked, is_done, is_bonus)

		if point_instance.has_signal("stage_clicked"):
			point_instance.connect("stage_clicked", Callable(self, "_on_hotspot_clicked"))


func _build_stage2_hotspots() -> void:
	if hotspots_container == null:
		return

	_stage2_hotspot_nodes.clear()
	for i in range(STAGE2_MAP_CONFIGS.size()):
		var cfg := STAGE2_MAP_CONFIGS[i]
		var point_instance: Control = MapStagePointScene.instantiate()
		point_instance.name = "StagePoint_%s" % str(cfg["id"]).replace("-", "_")
		point_instance.visible = false
		hotspots_container.add_child(point_instance)
		_stage2_hotspot_nodes.append(point_instance)
		point_instance.setup(
			i,
			str(cfg["id"]),
			str(cfg["title"]),
			str(cfg.get("tag", cfg["title"])),
			is_stage2_map_unlocked(i),
			false,
			false
		)
		if point_instance.has_signal("stage_clicked"):
			point_instance.connect("stage_clicked", Callable(self, "_on_stage2_hotspot_clicked"))


func _update_hotspot_positions() -> void:
	if hotspots_container == null:
		return
	var c_size := hotspots_container.size
	if c_size.x <= 0 or c_size.y <= 0:
		c_size = Vector2(MAP_WIDTH, MAP_HEIGHT)

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

	for i in range(_stage2_hotspot_nodes.size()):
		var node := _stage2_hotspot_nodes[i]
		if node == null or not is_instance_valid(node):
			continue
		var cfg := STAGE2_MAP_CONFIGS[i]
		var ratio: Vector2 = cfg["pos_ratio"]
		var half_size: Vector2 = node.size * 0.5
		if half_size == Vector2.ZERO:
			half_size = Vector2(55, 55)
		node.position = Vector2(ratio.x * c_size.x - half_size.x, ratio.y * c_size.y - half_size.y)

	if route_renderer != null:
		route_renderer.queue_redraw()

	var arrow_index: int = _selected_stage2_index if _nav_state == NavState.STAGE2_NAVIGATION else _selected_index
	_position_arrow(arrow_index, false)


func _on_route_draw() -> void:
	if route_renderer == null:
		return

	if _nav_state == NavState.STAGE2_NAVIGATION:
		for s_idx in range(STAGE2_ROUTE_SEGMENTS.size()):
			var pts: Array = STAGE2_ROUTE_SEGMENTS[s_idx]
			var scaled_pts := PackedVector2Array()
			for pt in pts:
				scaled_pts.append(pt)
			var segment_unlocked := is_stage2_map_unlocked(s_idx) or is_stage2_map_unlocked(s_idx + 1)
			if segment_unlocked:
				route_renderer.draw_polyline(scaled_pts, Color(0.85, 0.15, 0.25, 0.35), 7.0, true)
				route_renderer.draw_polyline(scaled_pts, Color(0.98, 0.25, 0.32, 0.95), 3.0, true)
			else:
				for p_i in range(scaled_pts.size() - 1):
					var p_a: Vector2 = scaled_pts[p_i]
					var p_b: Vector2 = scaled_pts[p_i + 1]
					var dist: float = p_a.distance_to(p_b)
					var steps: int = maxi(int(dist / 14.0), 1)
					for st in range(steps + 1):
						var dot_pt: Vector2 = p_a.lerp(p_b, float(st) / float(steps))
						route_renderer.draw_circle(dot_pt, 2.2, Color(0.42, 0.44, 0.54, 0.40))
	elif _nav_state == NavState.STAGE_NAVIGATION:
		# No Nível B, traça as rotas detalhadas internas do Stage 01
		for s_idx in range(ROUTE_SEGMENTS.size()):
			var pts: Array = ROUTE_SEGMENTS[s_idx]
			if pts.size() < 2:
				continue

			var segment_unlocked := false
			if s_idx < 4:
				segment_unlocked = is_stage_completed(s_idx) or is_stage_unlocked(s_idx + 1)
			elif s_idx == 4:
				segment_unlocked = is_stage_unlocked(5)

			var scaled_pts := PackedVector2Array()
			for pt in pts:
				scaled_pts.append(pt)

			if segment_unlocked:
				route_renderer.draw_polyline(scaled_pts, Color(0.85, 0.15, 0.25, 0.35), 7.0, true)
				route_renderer.draw_polyline(scaled_pts, Color(0.98, 0.25, 0.32, 0.95), 3.0, true)
			else:
				for p_i in range(scaled_pts.size() - 1):
					var p_a: Vector2 = scaled_pts[p_i]
					var p_b: Vector2 = scaled_pts[p_i + 1]
					var dist: float = p_a.distance_to(p_b)
					var steps: int = maxi(int(dist / 14.0), 1)
					for st in range(steps + 1):
						var dot_pt: Vector2 = p_a.lerp(p_b, float(st) / float(steps))
						route_renderer.draw_circle(dot_pt, 2.2, Color(0.42, 0.44, 0.54, 0.40))
	else:
		# No Nível A (Overview), traça a rota macro: Estágio 01 -> Bônus -> Estágio 02
		var pts_bonus: Array = ROUTE_SEGMENTS[3]
		var scaled_bonus := PackedVector2Array()
		for pt in pts_bonus:
			scaled_bonus.append(pt)
		if is_stage_completed(3) or is_stage_unlocked(4):
			route_renderer.draw_polyline(scaled_bonus, Color(0.95, 0.2, 0.5, 0.4), 7.0, true)
			route_renderer.draw_polyline(scaled_bonus, Color(1.0, 0.84, 0.2, 0.95), 3.0, true)
		else:
			for p_i in range(scaled_bonus.size() - 1):
				var p_a: Vector2 = scaled_bonus[p_i]
				var p_b: Vector2 = scaled_bonus[p_i + 1]
				var dist: float = p_a.distance_to(p_b)
				var steps: int = maxi(int(dist / 14.0), 1)
				for st in range(steps + 1):
					var dot_pt: Vector2 = p_a.lerp(p_b, float(st) / float(steps))
					route_renderer.draw_circle(dot_pt, 2.2, Color(0.42, 0.44, 0.54, 0.40))

		var pts_st2: Array = ROUTE_SEGMENTS[4]
		var scaled_st2 := PackedVector2Array()
		for pt in pts_st2:
			scaled_st2.append(pt)
		if is_stage_unlocked(5):
			route_renderer.draw_polyline(scaled_st2, Color(0.85, 0.15, 0.25, 0.35), 7.0, true)
			route_renderer.draw_polyline(scaled_st2, Color(0.98, 0.25, 0.32, 0.95), 3.0, true)
		else:
			for p_i in range(scaled_st2.size() - 1):
				var p_a: Vector2 = scaled_st2[p_i]
				var p_b: Vector2 = scaled_st2[p_i + 1]
				var dist: float = p_a.distance_to(p_b)
				var steps: int = maxi(int(dist / 14.0), 1)
				for st in range(steps + 1):
					var dot_pt: Vector2 = p_a.lerp(p_b, float(st) / float(steps))
					route_renderer.draw_circle(dot_pt, 2.2, Color(0.42, 0.44, 0.54, 0.40))


## Cálculo de Câmera Virtual e Clamping estrito (sem margens pretas)
func _calculate_camera_position(world_target: Vector2, zoom: float) -> Vector2:
	var vp_size := get_viewport_rect().size
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(1280, 720)

	var desired_screen_center := Vector2(vp_size.x * 0.5, vp_size.y * 0.38)
	var raw_pos := desired_screen_center - (world_target * zoom)

	var min_x := vp_size.x - (MAP_WIDTH * zoom)
	var max_x := 0.0
	var min_y := vp_size.y - (MAP_HEIGHT * zoom)
	var max_y := 0.0

	if min_x > max_x:
		min_x = (vp_size.x - MAP_WIDTH * zoom) * 0.5
		max_x = min_x
	if min_y > max_y:
		min_y = (vp_size.y - MAP_HEIGHT * zoom) * 0.5
		max_y = min_y

	return Vector2(clampf(raw_pos.x, min_x, max_x), clampf(raw_pos.y, min_y, max_y))


## Interpolação de Câmera com Suporte a Retarget Fluido
func _pan_camera_to(target_pos: Vector2, target_zoom: float, duration: float = 0.45, animate: bool = true) -> void:
	if map_container == null:
		return

	if not animate or duration <= 0.0:
		if _camera_tween != null and _camera_tween.is_valid():
			_camera_tween.kill()
			_camera_tween = null
		map_container.scale = Vector2(target_zoom, target_zoom)
		map_container.position = target_pos
		return

	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()

	_camera_tween = create_tween().set_parallel(true)
	_camera_tween.tween_property(map_container, "position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(map_container, "scale", Vector2(target_zoom, target_zoom), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _position_arrow(index: int, animate: bool = true) -> void:
	if moving_arrow == null:
		return
	var arrow_nodes: Array[Control] = _stage2_hotspot_nodes if _nav_state == NavState.STAGE2_NAVIGATION else _hotspot_nodes
	if index < 0 or index >= arrow_nodes.size():
		return

	var target_node := arrow_nodes[index]
	if target_node == null or not is_instance_valid(target_node):
		return

	moving_arrow.visible = true
	var target_pos := target_node.position + Vector2(target_node.size.x * 0.5, -6.0)

	if _arrow_bob_tween != null and _arrow_bob_tween.is_valid():
		_arrow_bob_tween.kill()
		_arrow_bob_tween = null
	if _arrow_blink_tween != null and _arrow_blink_tween.is_valid():
		_arrow_blink_tween.kill()
		_arrow_blink_tween = null

	moving_arrow.modulate.a = 1.0

	if animate:
		if _arrow_tween != null and _arrow_tween.is_valid():
			_arrow_tween.kill()
		_arrow_tween = create_tween()
		_arrow_tween.tween_property(moving_arrow, "position", target_pos, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_arrow_tween.finished.connect(_start_arrow_bobbing)
	else:
		moving_arrow.position = target_pos
		_start_arrow_bobbing()


func _start_arrow_bobbing() -> void:
	if moving_arrow == null:
		return
	if _arrow_bob_tween != null and _arrow_bob_tween.is_valid():
		_arrow_bob_tween.kill()
	if _arrow_blink_tween != null and _arrow_blink_tween.is_valid():
		_arrow_blink_tween.kill()

	var base_y := moving_arrow.position.y

	# Movimento vertical suave
	_arrow_bob_tween = create_tween().set_loops()
	_arrow_bob_tween.tween_property(moving_arrow, "position:y", base_y - 6.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_arrow_bob_tween.tween_property(moving_arrow, "position:y", base_y, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Efeito piscante arcade suave em ritmo equilibrado e calmo
	_arrow_blink_tween = create_tween().set_loops()
	_arrow_blink_tween.tween_property(moving_arrow, "modulate:a", 0.25, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrow_blink_tween.tween_property(moving_arrow, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func is_stage_unlocked(index: int) -> bool:
	var session := _get_game_session()
	if index < 0 or index >= STAGE_CONFIGS.size():
		return false

	var cfg := STAGE_CONFIGS[index]
	var map_num: int = int(cfg.get("map_num", 0))

	# Estágio 02 (índice 5):
	# No deploy, estritamente bloqueado (em desenvolvimento).
	# Nos testes de cena através do Godot (build de debug), permite liberar se:
	# 1. GameSession tiver stage_2_unlocked ativo (após vencer garagem ou desbloqueio de teste), OU
	# 2. Contexto de debug 'continue', OU
	# 3. Flag de debug manual _debug_stage2_force_unlocked (F9/F10).
	if index == 5:
		if not OS.is_debug_build():
			return false
		if _debug_stage2_force_unlocked:
			return true
		if _entry_context == "continue":
			return true
		if session != null and session.has_method("is_stage_2_unlocked"):
			return session.is_stage_2_unlocked()
		return false

	# No fluxo CONTINUAR, liberar todos os pontos existentes no mapa para debug.
	# Esta exceção é apenas visual/de navegação: não grava progresso nem conclusão.
	if _entry_context == "continue":
		return true

	if index == 0:
		if _entry_context == "campaign":
			return true
		if session != null:
			if session.has_method("is_map_unlocked"):
				return session.is_map_unlocked(1)
			if session.has_method("has_any_save"):
				return session.has_any_save()
		return true

	if map_num >= 2 and map_num <= 4:
		if session != null and session.has_method("is_map_unlocked"):
			return session.is_map_unlocked(map_num)
		return false

	if bool(cfg.get("is_bonus", false)):
		if session != null and session.has_method("is_bonus_unlocked"):
			return session.is_bonus_unlocked()
		return false

	if bool(cfg.get("is_future", false)):
		# Estágios futuros que ainda não foram desenvolvidos permanecem estritamente inabilitados
		return false

	return false


func is_stage2_map_unlocked(index: int) -> bool:
	if index < 0 or index >= STAGE2_MAP_CONFIGS.size():
		return false
	return OS.is_debug_build() and is_stage_unlocked(5)


func is_stage2_map_playable(index: int) -> bool:
	if not is_stage2_map_unlocked(index):
		return false
	var scene_path: String = str(STAGE2_MAP_CONFIGS[index].get("scene", ""))
	return not scene_path.is_empty() and ResourceLoader.exists(scene_path)


func is_stage2_navigation_active() -> bool:
	return _nav_state == NavState.STAGE2_NAVIGATION


func is_stage_completed(index: int) -> bool:
	var session := _get_game_session()
	if session == null or index < 0 or index >= STAGE_CONFIGS.size():
		return false

	var cfg := STAGE_CONFIGS[index]
	var map_num: int = int(cfg.get("map_num", 0))
	var st1_done: bool = false
	if session.has_method("is_stage_completed"):
		st1_done = session.is_stage_completed(1)
	elif "stage_1_completed" in session:
		st1_done = bool(session.stage_1_completed)

	var max_m: int = int(session.get("max_unlocked_map")) if "max_unlocked_map" in session else 0

	if map_num >= 1 and map_num <= 3:
		return st1_done or (max_m > map_num)
	elif map_num == 4:
		return st1_done
	elif bool(cfg.get("is_bonus", false)):
		return bool(session.get("stage_2_unlocked"))

	return false


func _on_hotspot_clicked(index: int) -> void:
	if _is_transitioning or _is_in_settings:
		return

	if _nav_state == NavState.OVERVIEW:
		if index <= 3:
			# No Nível A, clicar no Estágio 01 expande os 4 mapas via zoom!
			_enter_stage_01(0)
			return
		elif index == 4:
			if is_stage_unlocked(4):
				if _selected_index == 4:
					_on_play_stage_pressed()
				else:
					_select_stage(4, true, true)
			else:
				_play_sfx(_sfx_cancel)
			return
		elif index == 5:
			# HAPPEN abre a navegação interna somente nas builds locais de debug.
			if is_stage_unlocked(5):
				_enter_stage_02(0)
			else:
				_play_sfx(_sfx_cancel)
				_select_stage(5, false, true)
			return

	if index == _selected_index:
		if is_stage_unlocked(index):
			_on_play_stage_pressed()
		else:
			_play_sfx(_sfx_cancel)
	else:
		_select_stage(index, true, true)


func _select_stage(index: int, play_sound: bool = true, animate_camera: bool = true) -> void:
	if index < 0 or index >= STAGE_CONFIGS.size():
		return
	_selected_index = index
	var cfg := STAGE_CONFIGS[_selected_index]
	var is_unlocked := is_stage_unlocked(_selected_index)
	var is_done := is_stage_completed(_selected_index)
	var is_bonus := bool(cfg.get("is_bonus", false))

	# Se selecionou diretamente fases internas 1-2, 1-3 ou 1-4, transiciona para STAGE_NAVIGATION
	if _selected_index >= 1 and _selected_index <= 3:
		_nav_state = NavState.STAGE_NAVIGATION

	var target_zoom := STAGE_ZOOM
	var world_pt := Vector2(cfg["pos_ratio"].x * MAP_WIDTH, cfg["pos_ratio"].y * MAP_HEIGHT)

	if _nav_state == NavState.OVERVIEW:
		target_zoom = BASE_ZOOM
		world_pt = Vector2(MAP_WIDTH * 0.5, MAP_HEIGHT * 0.5)

	var camera_target := _calculate_camera_position(world_pt, target_zoom)
	_pan_camera_to(camera_target, target_zoom, 0.42, animate_camera)

	# Atualiza visibilidade dos marcadores conforme o nível atual
	_update_hotspots_visibility()

	# Atualiza cabeçalhos e mantém a dificuldade visível durante o Novo Jogo.
	if eyebrow_label != null:
		if _nav_state == NavState.STAGE_NAVIGATION:
			eyebrow_label.text = "ESTÁGIO 01 — A VILA"
		elif _nav_state == NavState.STAGE2_NAVIGATION:
			eyebrow_label.text = "ESTÁGIO 02 — HAPPEN"
		else:
			eyebrow_label.text = "CAMPANHA SAKAS"
		var difficulty_label: String = _get_campaign_difficulty_label()
		if not difficulty_label.is_empty():
			eyebrow_label.text += "  ·  DIFICULDADE: " + difficulty_label

	# Atualiza dados no Painel Narrativo Fixo
	var stage_id: String = str(cfg["id"])
	var narr: Dictionary = MISSION_NARRATIVES.get(stage_id, {})

	if narrative_badge != null:
		if _nav_state == NavState.OVERVIEW and _selected_index == 0:
			narrative_badge.text = "ESTÁGIO 01"
		else:
			narrative_badge.text = str(narr.get("badge", "MISSÃO %s" % stage_id))
	if narrative_title != null:
		narrative_title.text = str(narr.get("narrative_title", cfg["title"]))
	if narrative_synopsis != null:
		narrative_synopsis.text = str(narr.get("synopsis", cfg.get("subtitle", "")))
	if narrative_objective != null:
		narrative_objective.text = "OBJETIVO: " + str(narr.get("objective", "Avançar para o próximo setor."))
	if narrative_state_badge != null:
		if not is_unlocked:
			narrative_state_badge.text = "BLOQUEADO"
			narrative_state_badge.modulate = Color(1.0, 0.35, 0.35, 1.0)
		elif is_done:
			narrative_state_badge.text = "CONCLUÍDO"
			narrative_state_badge.modulate = Color(1.0, 0.85, 0.25, 1.0)
		else:
			narrative_state_badge.text = "DISPONÍVEL"
			narrative_state_badge.modulate = Color(0.0, 0.94, 1.0, 1.0)

	# Atualiza card de seleção e rodapé
	if stage_number_label != null:
		stage_number_label.text = str(cfg["id"])
	if stage_title_label != null:
		stage_title_label.text = str(cfg["title"])
	if stage_subtitle_label != null:
		stage_subtitle_label.text = str(cfg.get("subtitle", ""))

	_update_footer_status(is_unlocked, is_done, is_bonus, str(cfg["title"]))

	# Compatibilidade com suítes de teste legadas
	var arrow_p1 = get_node_or_null("%ArrowP1")
	if arrow_p1 != null:
		arrow_p1.visible = (_selected_index == 0)
	var arrow_p2 = get_node_or_null("%ArrowP2")
	if arrow_p2 != null:
		arrow_p2.visible = (_selected_index == 5)
	var point2_cover = get_node_or_null("%Point2Cover")
	if point2_cover != null:
		var session := _get_game_session()
		point2_cover.visible = (session != null and session.has_method("is_stage_2_unlocked") and session.is_stage_2_unlocked())

	_position_arrow(_selected_index, animate_camera)

	if play_sound:
		_play_sfx(_sfx_move if is_unlocked else _sfx_cancel)


func _get_campaign_difficulty_label() -> String:
	if _entry_context != "campaign":
		return ""
	var session := _get_game_session()
	if session == null or not ("difficulty_id" in session):
		return ""
	match str(session.get("difficulty_id")).to_lower():
		"facil":
			return "FÁCIL"
		"normal":
			return "NORMAL"
		"dificil":
			return "DIFÍCIL"
	return ""


func _update_hotspots_visibility() -> void:
	var in_stage_01 := (_nav_state == NavState.STAGE_NAVIGATION)
	var in_stage_02 := (_nav_state == NavState.STAGE2_NAVIGATION)

	for i in range(_hotspot_nodes.size()):
		var node := _hotspot_nodes[i]
		if node == null or not is_instance_valid(node):
			continue
		if in_stage_02:
			node.visible = false
			continue

		var cfg := STAGE_CONFIGS[i]
		var is_unlocked := is_stage_unlocked(i)
		var is_done := is_stage_completed(i)

		if i == 0:
			# Estágio 01: sempre visível
			node.visible = true
			if in_stage_01:
				node.setup(0, "1-1", "A LOCADORA", "A LOCADORA", is_unlocked, is_done, false)
			else:
				node.setup(0, "01", "A LOCADORA", "ESTÁGIO 01", is_unlocked, is_done, false)
			node.set_selected(i == _selected_index)

		elif i >= 1 and i <= 3:
			# Fases 1-2, 1-3, 1-4: visíveis APENAS no Nível B (STAGE_NAVIGATION)
			node.visible = in_stage_01
			if in_stage_01:
				node.setup(i, str(cfg["id"]), str(cfg["title"]), str(cfg.get("tag", cfg["title"])), is_unlocked, is_done, false)
				node.set_selected(i == _selected_index)

		elif i == 4:
			# Garagem Bônus: sempre visível com arte especial diferenciada
			node.visible = true
			node.setup(4, "B", "GARAGEM", "★ BÔNUS ★", is_unlocked, is_done, true)
			node.set_selected(i == _selected_index)

		elif i == 5:
			# Estágio 02: visível no Overview. Liberado em debug/testes; bloqueado no deploy.
			node.visible = true
			var tag_text: String = str(cfg.get("tag", "ESTÁGIO 02")) if OS.is_debug_build() else "ESTÁGIO 02 (EM BREVE)"
			node.setup(5, "02", str(cfg["title"]), tag_text, is_unlocked, is_done, false)
			node.set_selected(i == _selected_index)

	for i in range(_stage2_hotspot_nodes.size()):
		var node := _stage2_hotspot_nodes[i]
		if node == null or not is_instance_valid(node):
			continue
		var cfg := STAGE2_MAP_CONFIGS[i]
		node.visible = in_stage_02
		node.setup(
			i,
			str(cfg["id"]),
			str(cfg["title"]),
			str(cfg.get("tag", cfg["title"])),
			is_stage2_map_unlocked(i),
			false,
			false
		)
		node.set_selected(in_stage_02 and i == _selected_stage2_index)

	if route_renderer != null:
		route_renderer.queue_redraw()


func _update_footer_status(unlocked: bool, done: bool, bonus: bool, title: String) -> void:
	if map_status_label == null:
		return

	if _entry_context == "browse":
		map_status_label.text = "%s · MODO VISUALIZAÇÃO" % title
		map_status_label.modulate = Color(0.75, 0.75, 0.85, 1.0)
		if status_dot != null:
			status_dot.color = Color(0.75, 0.75, 0.85, 1.0)
		if btn_play_stage != null:
			btn_play_stage.set("disabled", true)
			btn_play_stage.set("button_text", "VISUALIZAR")
		return

	if unlocked:
		if _selected_index == 0 and _entry_context == "campaign" and not done:
			map_status_label.text = "INICIAR HISTÓRIA · NOVO JOGO"
			map_status_label.modulate = Color(0.0, 0.94, 1.0, 1.0)
			if status_dot != null:
				status_dot.color = Color(0.0, 0.94, 1.0, 1.0)
			if btn_play_stage != null:
				btn_play_stage.set("disabled", false)
				btn_play_stage.set("button_text", "INICIAR HISTÓRIA")
		elif _selected_index == 5 and _nav_state == NavState.OVERVIEW:
			map_status_label.text = "HAPPEN · DISPONÍVEL · 4 MAPAS"
			map_status_label.modulate = Color(0.0, 0.94, 1.0, 1.0)
			if status_dot != null:
				status_dot.color = Color(0.0, 0.94, 1.0, 1.0)
			if btn_play_stage != null:
				btn_play_stage.set("disabled", false)
				btn_play_stage.set("button_text", "VER MAPAS")
		elif done:
			map_status_label.text = "%s · CONCLUÍDO" % title
			map_status_label.modulate = Color(1.0, 0.85, 0.25, 1.0)
			if status_dot != null:
				status_dot.color = Color(1.0, 0.85, 0.25, 1.0)
			if btn_play_stage != null:
				btn_play_stage.set("disabled", false)
				btn_play_stage.set("button_text", "REJOGAR FASE")
		elif bonus:
			map_status_label.text = "GARAGEM · BÔNUS DISPONÍVEL"
			map_status_label.modulate = Color(1.0, 0.82, 0.18, 1.0)
			if status_dot != null:
				status_dot.color = Color(1.0, 0.35, 0.70, 1.0)
			if btn_play_stage != null:
				btn_play_stage.set("disabled", false)
				btn_play_stage.set("button_text", "JOGAR BÔNUS")
		else:
			map_status_label.text = "%s · DISPONÍVEL" % title
			map_status_label.modulate = Color(0.0, 0.94, 1.0, 1.0)
			if status_dot != null:
				status_dot.color = Color(0.0, 0.94, 1.0, 1.0)
			if btn_play_stage != null:
				btn_play_stage.set("disabled", false)
				btn_play_stage.set("button_text", "JOGAR FASE")
	else:
		map_status_label.text = "%s · BLOQUEADO" % title
		map_status_label.modulate = Color(1.0, 0.45, 0.45, 0.9)
		if status_dot != null:
			status_dot.color = Color(1.0, 0.45, 0.45, 0.9)
		if btn_play_stage != null:
			btn_play_stage.set("disabled", true)
			btn_play_stage.set("button_text", "BLOQUEADO")


func _enter_stage_01(target_mission_idx: int = 0) -> void:
	_nav_state = NavState.STAGE_NAVIGATION
	_select_stage(clampi(target_mission_idx, 0, 3), true, true)


func _enter_stage_02(target_map_idx: int = 0) -> void:
	if not is_stage_unlocked(5):
		_play_sfx(_sfx_cancel)
		return
	_nav_state = NavState.STAGE2_NAVIGATION
	_selected_index = 5
	_select_stage2_map(clampi(target_map_idx, 0, STAGE2_MAP_CONFIGS.size() - 1), true, true)


func _select_stage2_map(index: int, play_sound: bool = true, animate_camera: bool = true) -> void:
	if index < 0 or index >= STAGE2_MAP_CONFIGS.size() or not is_stage_unlocked(5):
		return

	_nav_state = NavState.STAGE2_NAVIGATION
	_selected_index = 5
	_selected_stage2_index = index
	var cfg: Dictionary = STAGE2_MAP_CONFIGS[index]
	var playable: bool = is_stage2_map_playable(index)
	var world_pt: Vector2 = Vector2(cfg["pos_ratio"].x * MAP_WIDTH, cfg["pos_ratio"].y * MAP_HEIGHT)
	var camera_target := _calculate_camera_position(world_pt, STAGE_ZOOM)
	_pan_camera_to(camera_target, STAGE_ZOOM, 0.42, animate_camera)
	_update_hotspots_visibility()

	if eyebrow_label != null:
		eyebrow_label.text = "ESTÁGIO 02 — HAPPEN"
	if narrative_badge != null:
		narrative_badge.text = "MISSÃO " + str(cfg["id"])
	if narrative_title != null:
		narrative_title.text = str(cfg["title"])
	if narrative_synopsis != null:
		narrative_synopsis.text = str(cfg.get("subtitle", ""))
	if narrative_objective != null:
		narrative_objective.text = "OBJETIVO: " + str(cfg.get("objective", "Avançar para o próximo setor."))
	if narrative_state_badge != null:
		if not is_stage2_map_unlocked(index):
			narrative_state_badge.text = "BLOQUEADO"
			narrative_state_badge.modulate = Color(1.0, 0.35, 0.35, 1.0)
		elif not playable:
			narrative_state_badge.text = "EM DESENVOLVIMENTO"
			narrative_state_badge.modulate = Color(1.0, 0.65, 0.25, 1.0)
		else:
			narrative_state_badge.text = "DISPONÍVEL"
			narrative_state_badge.modulate = Color(0.0, 0.94, 1.0, 1.0)

	if stage_number_label != null:
		stage_number_label.text = str(cfg["id"])
	if stage_title_label != null:
		stage_title_label.text = str(cfg["title"])
	if stage_subtitle_label != null:
		stage_subtitle_label.text = str(cfg.get("subtitle", ""))

	if map_status_label != null:
		map_status_label.text = "%s · %s" % [str(cfg["id"]), "DISPONÍVEL" if playable else "EM DESENVOLVIMENTO"]
		map_status_label.modulate = Color(0.0, 0.94, 1.0, 1.0) if playable else Color(1.0, 0.65, 0.25, 1.0)
	if status_dot != null:
		status_dot.color = Color(0.0, 0.94, 1.0, 1.0) if playable else Color(1.0, 0.65, 0.25, 1.0)
	if btn_play_stage != null:
		btn_play_stage.set("disabled", not playable)
		btn_play_stage.set("button_text", "JOGAR FASE" if playable else "EM DESENVOLVIMENTO")

	_position_arrow(index, animate_camera)
	if play_sound:
		_play_sfx(_sfx_move if playable else _sfx_cancel)


func _on_stage2_hotspot_clicked(index: int) -> void:
	if _nav_state != NavState.STAGE2_NAVIGATION or _is_transitioning or _is_in_settings:
		return
	if index < 0 or index >= STAGE2_MAP_CONFIGS.size():
		return
	if index == _selected_stage2_index:
		if is_stage2_map_playable(index):
			_on_play_stage_pressed()
		else:
			_play_sfx(_sfx_cancel)
	else:
		_select_stage2_map(index, true, true)


func _return_to_overview() -> void:
	_nav_state = NavState.OVERVIEW
	_play_sfx(_sfx_cancel)
	_select_stage(0, false, true)


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

	if _entry_context == "browse":
		_play_sfx(_sfx_cancel)
		return

	if _nav_state == NavState.OVERVIEW and _selected_index == 5:
		_enter_stage_02(0)
		return

	var is_stage2_map: bool = _nav_state == NavState.STAGE2_NAVIGATION
	if is_stage2_map and not is_stage2_map_playable(_selected_stage2_index):
		_play_sfx(_sfx_cancel)
		_select_stage2_map(_selected_stage2_index, false, false)
		return
	if not is_stage2_map and not is_stage_unlocked(_selected_index):
		_play_sfx(_sfx_cancel)
		return

	var cfg: Dictionary = STAGE2_MAP_CONFIGS[_selected_stage2_index] if is_stage2_map else STAGE_CONFIGS[_selected_index]
	var target_scene: String = str(cfg.get("scene", ""))

	if target_scene.is_empty():
		_play_sfx(_sfx_cancel)
		if map_status_label != null:
			map_status_label.text = "%s · EM DESENVOLVIMENTO" % str(cfg["title"])
			map_status_label.modulate = Color(1.0, 0.45, 0.45, 1.0)
		return

	# --- Fluxo de REPLAY: fases concluídas redirecionam para seleção de personagem/dificuldade ---
	var is_replay: bool = not is_stage2_map and is_stage_completed(_selected_index)
	if is_replay and _entry_context != "replay":
		_is_transitioning = true
		_play_sfx(_sfx_confirm)

		var session := _get_game_session()
		if session != null:
			session.set_meta("replay_stage_index", _selected_index)
			session.set_meta("replay_stage_scene", target_scene)
			session.set_meta("map_entry_context", "replay")
			if session.has_method("clear_player_progression"):
				session.clear_player_progression()

		await get_tree().create_timer(0.2).timeout
		var err := get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
		if err != OK:
			_is_transitioning = false
			printerr("Erro ao redirecionar para seleção de personagem: ", err)
		return

	_is_transitioning = true
	_play_sfx(_sfx_confirm)

	var session := _get_game_session()
	if session != null:
		session.set_meta("selected_stage_index", _selected_index)
		if is_stage2_map:
			session.set_meta("selected_stage2_map_index", _selected_stage2_index)
		if not ("selected_character_id" in session) or str(session.selected_character_id).is_empty():
			session.selected_character_id = "guilherme"
		if not ("difficulty_id" in session) or str(session.difficulty_id).is_empty():
			session.difficulty_id = "normal"
		if _selected_index != 0 or _entry_context != "campaign":
			if session.has_method("clear_player_progression"):
				session.clear_player_progression()

	var pack_mgr = get_node_or_null("/root/PackManager")
	if pack_mgr != null and pack_mgr.has_method("ensure_pack_loaded_async"):
		var stage_pack: String = "stage2" if is_stage2_map else "stage1"
		if not pack_mgr.is_pack_mounted(stage_pack) or not pack_mgr.is_pack_mounted("audio_bgm"):
			if map_status_label != null:
				map_status_label.text = "CARREGANDO RECURSOS DA FASE..."
				map_status_label.modulate = Color(0, 0.94, 1, 1)
			var ok_stage = await pack_mgr.ensure_pack_loaded_async(stage_pack)
			var ok_bgm = await pack_mgr.ensure_pack_loaded_async("audio_bgm")
			if not ok_stage or not ok_bgm:
				_is_transitioning = false
				if map_status_label != null:
					map_status_label.text = "FALHA NA CONEXÃO. TOQUE PARA REPETIR."
					map_status_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
				return

	if _selected_index == 0 and _entry_context == "campaign":
		target_scene = "res://scenes/story/story_intro.tscn"
		if not ResourceLoader.exists(target_scene):
			target_scene = "res://scenes/ui/loading_screen.tscn"
	elif is_stage2_map and _selected_stage2_index == 0 and _entry_context == "campaign":
		if session == null or not bool(session.get("has_seen_stage_2_transition")):
			var intro_scene: String = "res://scenes/story/story_stage2_intro.tscn"
			if ResourceLoader.exists(intro_scene):
				target_scene = intro_scene

	await get_tree().create_timer(0.2).timeout
	for action in ["jump", "attack_aerial", "attack", "attack_punch", "attack_special", "special", "guard", "ui_accept", "ui_select"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		_is_transitioning = false
		printerr("Erro ao transicionar para a fase selecionada: ", err)


## Auto-lança a fase armazenada após retorno do fluxo de seleção de personagem/dificuldade (REPLAY)
func _auto_launch_replay() -> void:
	var session := _get_game_session()
	if session == null:
		return

	var replay_idx: int = int(session.get_meta("replay_stage_index", 0))
	var replay_scene: String = str(session.get_meta("replay_stage_scene", ""))

	# Limpa os metadados de replay para evitar loop
	session.remove_meta("replay_stage_index")
	session.remove_meta("replay_stage_scene")

	if replay_scene.is_empty() or replay_idx < 0 or replay_idx >= STAGE_CONFIGS.size():
		return

	# Seleciona visualmente a fase de replay e entra no Stage 01 se necessário
	if replay_idx >= 0 and replay_idx <= 3:
		_nav_state = NavState.STAGE_NAVIGATION
		_select_stage(replay_idx, false, false)
		_update_hotspots_visibility()
	else:
		_select_stage(replay_idx, false, false)

	await get_tree().process_frame

	# Lança a fase diretamente
	_is_transitioning = true
	_play_sfx(_sfx_confirm)

	session.set_meta("selected_stage_index", replay_idx)
	if session.has_method("clear_player_progression"):
		session.clear_player_progression()

	# Carrega pacotes necessários
	var pack_mgr = get_node_or_null("/root/PackManager")
	if pack_mgr != null and pack_mgr.has_method("ensure_pack_loaded_async"):
		var stage_pack: String = "stage2" if replay_idx == 5 else "stage1"
		if not pack_mgr.is_pack_mounted(stage_pack) or not pack_mgr.is_pack_mounted("audio_bgm"):
			if map_status_label != null:
				map_status_label.text = "CARREGANDO RECURSOS DA FASE..."
				map_status_label.modulate = Color(0, 0.94, 1, 1)
			var ok_stage = await pack_mgr.ensure_pack_loaded_async(stage_pack)
			var ok_bgm = await pack_mgr.ensure_pack_loaded_async("audio_bgm")
			if not ok_stage or not ok_bgm:
				_is_transitioning = false
				if map_status_label != null:
					map_status_label.text = "FALHA NA CONEXÃO. TOQUE PARA REPETIR."
					map_status_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
				return

	await get_tree().create_timer(0.3).timeout
	for action in ["jump", "attack_aerial", "attack", "attack_punch", "attack_special", "special", "guard", "ui_accept", "ui_select"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
	var err := get_tree().change_scene_to_file(replay_scene)
	if err != OK:
		_is_transitioning = false
		printerr("Erro ao auto-lançar fase de replay: ", err)


## Compatibilidade para rotinas de teste e atalhos de transição
func select_point(point_index: int) -> void:
	if point_index == 1:
		_select_stage(0, false, false)
	elif point_index == 2:
		_select_stage(5, false, false)
	elif point_index == 3:
		_select_stage(4, false, false)
	elif point_index >= 0 and point_index < STAGE_CONFIGS.size():
		_select_stage(point_index, false, false)


func is_opened_from_menu() -> bool:
	return _entry_context == "browse"


func _on_confirm_pressed() -> void:
	if _entry_context == "browse":
		_on_back_pressed()
	else:
		_on_play_stage_pressed()


func _handle_point_click(_click_pos: Vector2) -> void:
	if _entry_context == "browse":
		_on_back_pressed()
	else:
		_on_play_stage_pressed()


func _select_point(idx: int) -> void:
	_select_stage(idx, false, false)


func _on_back_pressed() -> void:
	if _is_transitioning or _is_in_settings:
		return

	if _entry_context == "browse":
		_is_transitioning = true
		_play_sfx(_sfx_cancel)
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return

	# No Nível B, retorna ao Nível A (Overview) via zoom out
	if _nav_state == NavState.STAGE_NAVIGATION or _nav_state == NavState.STAGE2_NAVIGATION:
		_return_to_overview()
	else:
		# No Nível A, retorna ao menu principal
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
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F9 or event.keycode == KEY_F10):
		_safe_handle_input()
		_debug_stage2_force_unlocked = not _debug_stage2_force_unlocked
		var session := _get_game_session()
		if session != null and session.has_method("unlock_stage_2"):
			session.unlock_stage_2()
		_update_hotspots_visibility()
		if _nav_state == NavState.STAGE2_NAVIGATION:
			_select_stage2_map(_selected_stage2_index, false, false)
		else:
			_select_stage(_selected_index, false, false)
		if route_renderer != null:
			route_renderer.queue_redraw()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_RIGHT or event.keycode == KEY_D)):
		_safe_handle_input()
		_navigate_stages(1)
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_LEFT or event.keycode == KEY_A)):
		_safe_handle_input()
		_navigate_stages(-1)
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		if _nav_state == NavState.OVERVIEW:
			if _selected_index == 0:
				_enter_stage_01(0)
			elif _selected_index == 4 and is_stage_unlocked(4):
				_on_play_stage_pressed()
			elif _selected_index == 5 and is_stage_unlocked(5):
				_enter_stage_02(0)
			else:
				_play_sfx(_sfx_cancel)
		else:
			_on_play_stage_pressed()
	elif event is InputEventScreenTouch and event.pressed:
		_safe_handle_input()
		if _nav_state == NavState.STAGE2_NAVIGATION:
			if is_stage2_map_playable(_selected_stage2_index):
				_on_play_stage_pressed()
		elif is_stage_unlocked(_selected_index):
			_on_play_stage_pressed()


func _navigate_stages(delta: int) -> void:
	if _nav_state == NavState.STAGE2_NAVIGATION:
		var next_stage2_idx := clampi(_selected_stage2_index + delta, 0, STAGE2_MAP_CONFIGS.size() - 1)
		if next_stage2_idx != _selected_stage2_index:
			_select_stage2_map(next_stage2_idx, true, true)
	elif _nav_state == NavState.STAGE_NAVIGATION:
		# Navegação interna sequencial do Stage 01 (1-1 <-> 1-2 <-> 1-3 <-> 1-4)
		var next_idx := clampi(_selected_index + delta, 0, 3)
		if next_idx != _selected_index:
			_select_stage(next_idx, true, true)
	else:
		# Navegação geral no Overview: Estágio 01 (0), Bônus (4), Estágio 02 (5)
		var overview_indices: Array[int] = [0, 4, 5]
		var cur_pos := overview_indices.find(_selected_index)
		if cur_pos == -1:
			cur_pos = 0
		var next_pos := (cur_pos + delta) % overview_indices.size()
		if next_pos < 0:
			next_pos += overview_indices.size()
		_select_stage(overview_indices[next_pos], true, true)


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
