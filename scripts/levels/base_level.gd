class_name BaseLevel
extends Node2D

## Gerenciador e Controlador de Nível Base para Beat 'em Up 2.5D.
## Coordena o Combate via CombatDirector, o indicador "SIGA →",
## os limites da câmera e a progressão segura entre mapas.

const SigaIndicatorClass = preload("res://scripts/ui/siga_indicator.gd")
const CombatDirectorClass = preload("res://scripts/combat/combat_director.gd")
const EncounterDifficultyProfileClass = preload("res://scripts/combat/encounter_difficulty_profile.gd")
const SpawnDirectorClass = preload("res://scripts/spawning/spawn_director.gd")
const SpawnPointClass = preload("res://scripts/spawning/spawn_point.gd")
const PauseMenuScene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const NarrativeDirectorClass = preload("res://scripts/events/narrative_director.gd")

const BGM_STAGE_1_2: String = "res://assets/audio/bgm/M_1_2 - Estágio 1.mp3"
const BGM_STAGE_3_4: String = "res://assets/audio/bgm/M_3_4 - Estágio 1.mp3"
const BGM_BONUS_1: String = "res://assets/audio/bgm/bonus_1.mp3"

# Spawn seguro da onda de reforços do Mapa 1. A faixa Y 650..715 corresponde
# ao corredor inferior contínuo da map_1_navpoly.tres.
const MAP1_MOBILE_SPAWN_MIN_X: float = 300.0
const MAP1_MOBILE_SPAWN_MAX_X: float = 1840.0
const MAP1_MOBILE_SPAWN_MIN_Y: float = 660.0
const MAP1_MOBILE_SPAWN_MAX_Y: float = 700.0
const MAP1_MOBILE_SPAWN_EDGE_MARGIN: float = 88.0
const MAP1_MOBILE_SPAWN_FALLBACK_DISTANCE: float = 300.0
const MAP1_MOBILE_SPAWN_SPACING_X: float = 56.0
const MAP1_MOBILE_SPAWN_SPACING_Y: float = 12.0

@export_group("Configuração do Mapa")
@export var stage_number: int = 1
@export var section_number: int = 1
@export var map_name: String = "Fase 1 - Seção 1"
@export var map_index: int = 1
@export var map_group: String = "fase1"
@export var next_map_scene_path: String = ""
@export var is_final_map: bool = false
@export var victory_scene_path: String = "res://scenes/ui/credits.tscn"

@export_group("Câmera e Limites")
@export var camera_min_x: float = 640.0
@export var camera_max_x: float = 1343.0
@export var camera_fixed_y: float = 360.0
@export var camera_follow_speed: float = 12.0

@export_group("Chefe da Seção")
@export var boss_scene: PackedScene = null
@export var boss_spawn_position: Vector2 = Vector2(1700, 640)
@export var boss_announcement_text: String = "⚠️ ATENÇÃO: CHEFÃO ALESSANDRO APARECEU!\nDERROTE-O PARA AVANÇAR!"

@export_group("Ondas de Reforço (P5)")
@export var reinforcement_waves_enabled: bool = false
@export var reinforcement_enemy_scene: PackedScene = preload("res://scenes/actors/enemies/basic_enemy.tscn")
@export var reinforcement_trigger_enemy_count: int = 1
@export var reinforcement_delay_seconds: float = 2.0
@export var reinforcement_count: int = 2
@export var reinforcement_archetypes: Array[int] = [1, 3] # Aggressor, Flanker (com variedade visual de paleta)

## Referências aos nós da cena
@onready var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var combat_director: CombatDirector = get_node_or_null("CombatDirector") as CombatDirector
@onready var exit_area: Area2D = get_node_or_null("ExitArea") as Area2D
@onready var siga_indicator: SigaIndicator = get_node_or_null("SigaIndicator") as SigaIndicator
@onready var hud: PrototypeHud = get_node_or_null("PrototypeHud") as PrototypeHud
@onready var spawn_director: Node = get_node_or_null("SpawnDirector")

var player: PlayerController = null
var pause_menu: CanvasLayer = null

var _transitioning: bool = false
var _boss_spawned: bool = false
var _boss_instance: CharacterBody2D = null
var _reinforcement_wave_triggered: bool = false
var _reinforcement_timer: SceneTreeTimer = null
var _pending_reinforcements_to_spawn: int = 0

# Preserve os limites autorais do mapa para recalculá-los quando o viewport
# mobile mudar de tamanho, sem acumular ajustes entre redimensionamentos.
var _configured_camera_min_x: float = 640.0
var _configured_camera_max_x: float = 1343.0


func get_player() -> PlayerController:
	if player != null and is_instance_valid(player):
		return player
	# 1. Procura na nova arquitetura padrão
	player = get_node_or_null("World/Actors/Player") as PlayerController
	# 2. Fallback de compatibilidade para arquitetura legada
	if player == null:
		player = get_node_or_null("World/Entities/Player") as PlayerController
	# 3. Fallback de resiliência pelo grupo global
	if player == null and get_tree() != null:
		var found = get_tree().get_first_node_in_group("player")
		if found is PlayerController:
			player = found as PlayerController
	return player


func get_actors_container() -> Node2D:
	var container: Node2D = get_node_or_null("World/Actors/Enemies") as Node2D
	if container == null:
		container = get_node_or_null("World/Actors") as Node2D
	if container == null:
		container = get_node_or_null("World/Entities") as Node2D
	if container == null:
		container = self
	return container


func _ready() -> void:
	player = get_player()

	# Instancia o Menu de Pausa In-Game
	if PauseMenuScene != null:
		pause_menu = PauseMenuScene.instantiate() as CanvasLayer
		add_child(pause_menu)

	# Em celulares ultrawide, a viewport fica mais larga que 16:9.
	# Ajusta os limites da câmera aos limites reais da textura do mapa, evitando
	# revelar áreas vazias nas laterais. No desktop os valores originais permanecem.
	_configured_camera_min_x = camera_min_x
	_configured_camera_max_x = camera_max_x
	if _is_mobile_runtime():
		_apply_mobile_camera_bounds()
		if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_mobile_viewport_size_changed):
			get_viewport().size_changed.connect(_on_mobile_viewport_size_changed)

	# Inicializa câmera
	if camera != null:
		camera.enabled = true
		camera.make_current()
		var init_x: float = camera_min_x
		if player != null and is_instance_valid(player):
			init_x = clampf(player.global_position.x, camera_min_x, camera_max_x)
		camera.position = Vector2(init_x, camera_fixed_y)
		camera.global_position = Vector2(init_x, camera_fixed_y)

	# A saída inicia estritamente desabilitada até a derrota de todos os inimigos
	if exit_area != null:
		exit_area.monitoring = false
		if not exit_area.body_entered.is_connected(_on_exit_body_entered):
			exit_area.body_entered.connect(_on_exit_body_entered)

	# O indicador SIGA → inicia oculto e inativo (com fallback seguro caso não instanciado no mapa)
	if siga_indicator == null:
		siga_indicator = SigaIndicatorClass.new()
		siga_indicator.name = "SigaIndicator"
		siga_indicator.visible = false
		add_child(siga_indicator)
	else:
		siga_indicator.deactivate()

	# Configura conexões do Diretor de Combate e Perfil Canônico do Mapa
	if combat_director != null:
		if combat_director.difficulty_profile == null:
			combat_director.apply_difficulty_profile(EncounterDifficultyProfileClass.create_for_map(map_index))
		if boss_scene != null and not _boss_spawned:
			combat_director.add_pending_spawns(1)
		if not combat_director.encounter_cleared.is_connected(_on_encounter_cleared):
			combat_director.encounter_cleared.connect(_on_encounter_cleared)
		if not combat_director.enemy_defeated.is_connected(_on_enemy_defeated):
			combat_director.enemy_defeated.connect(_on_enemy_defeated)

	# Conecta HUD com Jogador
	if player != null and hud != null:
		player.player_moved.connect(hud.on_player_moved)
		player.state_changed.connect(hud.update_player_state)
		if player.health_component != null:
			player.health_component.health_changed.connect(hud.update_player_health)
			player.health_component.died.connect(_on_player_died_for_hud)
			hud.update_player_health(player.health_component.current_health, player.health_component.max_health)
		hud.on_player_moved(player.global_position, Vector2.ZERO)
		
		# Vincula à PlayerHUD arcade oficial
		if hud.has_method("bind_player"):
			hud.bind_player(player)

		# Conecta acertos para rastrear inimigo na EnemyHUD (prioridade máxima para acertos do jogador)
		if player.melee_attack != null and hud.has_method("set_enemy_target"):
			player.melee_attack.target_hit.connect(func(target: Node, _dmg: float):
				if target != null and is_instance_valid(target) and target.is_in_group("enemies"):
					hud.set_enemy_target(target, true)
			)

	if combat_director != null and hud != null and hud.has_method("set_enemy_target"):
		if combat_director.has_signal("enemy_registered"):
			combat_director.enemy_registered.connect(func(enemy: CharacterBody2D):
				if enemy != null and is_instance_valid(enemy):
					hud.set_enemy_target(enemy, false)
			)

	# Atualiza a HUD Arcade com a numeração canônica de Fase e Seção (ex: FASE 1-1, FASE 1-2)
	if hud != null:
		if hud.has_method("set_stage_section"):
			hud.set_stage_section(stage_number, section_number)
		elif hud.center_hud != null:
			hud.center_hud.set_stage_index(stage_number, section_number)

	# Restaura vida e especial do jogador de seções anteriores do mesmo mapa (ex: Fase 1)
	var session = get_node_or_null("/root/GameSession")
	if session != null and player != null:
		# Sincroniza fichas de continue com a sessão
		if "current_continues" in session and "current_continues" in player:
			player.current_continues = session.current_continues
		if hud != null and hud.has_method("bind_player"):
			hud.bind_player(player)

		# Restauração do snapshot de mundo salvo (Save Slot → Continue)
		# Deve ocorrer ANTES de qualquer processamento de gameplay para evitar
		# que inimigos se movam ou o jogador sofra dano antes da restauração.
		if "pending_save_snapshot" in session and session.pending_save_snapshot is Dictionary and not session.pending_save_snapshot.is_empty():
			restore_world_snapshot(session.pending_save_snapshot)
			session.pending_save_snapshot = {}
		else:
			var saved_prog = session.get_preserved_player_progression(map_group)
			if not saved_prog.is_empty():
				if player.health_component != null and saved_prog.has("health") and saved_prog["health"] > 0.0:
					player.health_component.current_health = saved_prog["health"]
					if hud != null:
						hud.update_player_health(player.health_component.current_health, player.health_component.max_health)
				if saved_prog.has("special") and "current_special" in player:
					player.current_special = saved_prog["special"]
					if player.has_signal("special_changed"):
						player.special_changed.emit(player.current_special, player.max_special)

	if hud != null:
		if hud.has_method("set_level"):
			hud.set_level(map_index)
		if hud.label_level_name != null:
			hud.label_level_name.text = "%s (Mapa %d/4)" % [map_name, map_index]

	# Disparo da abertura narrativa cinemática (Novo Jogo -> Mapa 1)
	var narrative_active: bool = _check_and_trigger_opening_narrative()

	# Inicialização da trilha sonora (BGM) correspondente ao mapa (se não houver narrativa ativa)
	if not narrative_active:
		_setup_level_bgm()


var _level_bgm_player: AudioStreamPlayer = null


## Configura a trilha sonora (BGM) do nível conforme o mapa atual:
## Map 1 e Map 2 -> M_1_2 - Estágio 1
## Map 3 e Map 4 -> M_3_4 - Estágio 1
## Bonus Stage (Map 5 / bonus1) -> bonus_1.mp3 (fade-in gradual)
func _setup_level_bgm() -> void:
	var target_bgm: String = ""
	var fade_in: float = 0.0
	if map_index in [1, 2]:
		target_bgm = BGM_STAGE_1_2
	elif map_index in [3, 4]:
		target_bgm = BGM_STAGE_3_4
	elif map_index == 5 or map_group == "bonus1" or map_name.to_lower().contains("bonus") or map_name.to_lower().contains("garagem"):
		target_bgm = BGM_BONUS_1
		fade_in = 3.5

	if target_bgm.is_empty():
		return

	# Tenta delegar ao GameSession (Autoload) para que a música não reinicie entre map_1 e map_2
	var gs: Node = get_node_or_null("/root/GameSession")
	if gs != null and gs.has_method("play_bgm"):
		gs.call("play_bgm", target_bgm, -4.0, fade_in)
		return

	# Fallback autônomo (testes isolados de cena sem autoload carregado)
	if _level_bgm_player == null:
		_level_bgm_player = AudioStreamPlayer.new()
		_level_bgm_player.name = "LevelBGMPlayer"
		_level_bgm_player.bus = &"Master"
		add_child(_level_bgm_player)

	if ResourceLoader.exists(target_bgm):
		var stream: AudioStream = load(target_bgm) as AudioStream
		if stream != null:
			if stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = true
			_level_bgm_player.stream = stream
			if fade_in > 0.0:
				_level_bgm_player.volume_db = -40.0
				_level_bgm_player.play()
				var tw: Tween = create_tween()
				tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				tw.tween_property(_level_bgm_player, "volume_db", -4.0, fade_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				_level_bgm_player.volume_db = -4.0
				_level_bgm_player.play()


func _check_and_trigger_opening_narrative() -> bool:
	if stage_number != 1 or section_number != 1 or Engine.is_editor_hint():
		return false

	var session = get_node_or_null("/root/GameSession")
	if session != null and "has_played_intro" in session and not session.has_played_intro:
		_trigger_opening_narrative()
		return true
	return false


func _trigger_opening_narrative() -> void:
	var nar_director: NarrativeDirector = null
	var nar_scene: PackedScene = load("res://scenes/ui/narrative_director.tscn") as PackedScene
	if nar_scene != null:
		nar_director = nar_scene.instantiate() as NarrativeDirector
	else:
		nar_director = NarrativeDirectorClass.new()
	nar_director.name = "NarrativeDirector"
	add_child(nar_director)
	nar_director.sequence_completed.connect(func(_id): _setup_level_bgm())
	nar_director.sequence_skipped.connect(func(_id): _setup_level_bgm())
	nar_director.play_sequence_from_path("res://resources/story/story_intro_map1.tres")


func _is_mobile_runtime() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)


func _apply_mobile_camera_bounds() -> void:
	# Restaura sempre os limites definidos pelo mapa antes de recalcular.
	camera_min_x = _configured_camera_min_x
	camera_max_x = _configured_camera_max_x

	if not _is_mobile_runtime() or camera == null:
		return

	var viewport_width: float = get_viewport_rect().size.x
	if viewport_width <= 0.0:
		return

	var zoom_x: float = maxf(absf(camera.zoom.x), 0.001)
	var half_visible_world_width: float = (viewport_width * 0.5) / zoom_x
	var far_background: Sprite2D = get_node_or_null("Background/Far") as Sprite2D
	if far_background == null or far_background.texture == null:
		return

	# Sprite2D.get_rect() respeita centered/region e a transformação do recurso.
	var background_rect: Rect2 = far_background.get_rect()
	var edge_a: Vector2 = far_background.to_global(background_rect.position)
	var edge_b: Vector2 = far_background.to_global(
		background_rect.position + Vector2(background_rect.size.x, 0.0)
	)
	var background_left: float = minf(edge_a.x, edge_b.x)
	var background_right: float = maxf(edge_a.x, edge_b.x)

	# A câmera não pode mostrar além da borda da arte que já existe no mapa.
	camera_min_x = maxf(camera_min_x, background_left + half_visible_world_width)
	camera_max_x = minf(camera_max_x, background_right - half_visible_world_width)

	# Em fases estreitas, fixa a câmera no centro seguro em vez de expor o vazio.
	if camera_min_x > camera_max_x:
		var safe_center: float = (background_left + background_right) * 0.5
		camera_min_x = safe_center
		camera_max_x = safe_center


func _on_mobile_viewport_size_changed() -> void:
	if not _is_mobile_runtime():
		return
	_apply_mobile_camera_bounds()
	if camera != null:
		camera.global_position.x = clampf(camera.global_position.x, camera_min_x, camera_max_x)


func _physics_process(delta: float) -> void:
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	if camera == null:
		return

	if player == null or not is_instance_valid(player):
		player = get_player()
		if player == null:
			return

	# A câmera acompanha o jogador suavemente respeitando os limites físicos da arte do mapa (evita fundo cinza)
	var target_x: float = clampf(player.global_position.x, camera_min_x, camera_max_x)
	camera.global_position.x = move_toward(camera.global_position.x, target_x, camera_follow_speed * 100.0 * delta)
	camera.global_position.y = camera_fixed_y


## Disparado quando um inimigo é derrotado
func _on_enemy_defeated(_enemy: CharacterBody2D) -> void:
	# Verificação e agendamento de onda de reforços (P5)
	if reinforcement_waves_enabled and not _reinforcement_wave_triggered:
		if combat_director != null and combat_director.alive_enemies.size() <= reinforcement_trigger_enemy_count:
			_trigger_reinforcement_wave()

	if boss_scene != null and not _boss_spawned:
		if combat_director != null and combat_director.alive_enemies.is_empty():
			_spawn_boss()


## Agenda a onda de reforços, registrando pendências no CombatDirector antes do timer (P5)
func _trigger_reinforcement_wave() -> void:
	if _reinforcement_wave_triggered:
		return
	_reinforcement_wave_triggered = true
	_pending_reinforcements_to_spawn = reinforcement_count

	# Registra imediatamente no diretor de combate para blindar saída e SIGA
	if combat_director != null:
		combat_director.add_pending_spawns(_pending_reinforcements_to_spawn)

	if get_tree() != null:
		_reinforcement_timer = get_tree().create_timer(reinforcement_delay_seconds)
		_reinforcement_timer.timeout.connect(_on_reinforcement_timer_timeout)


## Instancia os reforços programados. No Mapa 1 mobile, a posição é validada
## no corredor inferior do navmesh para não cair no clamp extremo (x=160, y<650).
func _on_reinforcement_timer_timeout() -> void:
	if not is_inside_tree() or _transitioning:
		return

	# Não spawna reforços se o jogador estiver morto definitivamente
	if player != null and is_instance_valid(player) and player.health_component != null and player.health_component.is_dead:
		if not ("current_continues" in player and player.current_continues > 0):
			return

	var count_to_spawn: int = _pending_reinforcements_to_spawn
	_pending_reinforcements_to_spawn = 0

	var actors_container: Node2D = get_actors_container()
	var mobile_map1_positions: Array[Vector2] = []

	for i in range(count_to_spawn):
		var spawn_pos: Vector2
		if _is_mobile_runtime() and map_index == 1:
			spawn_pos = _get_map1_mobile_reinforcement_spawn_position(i, count_to_spawn, mobile_map1_positions)
		else:
			# Desktop e os demais mapas mantêm o cálculo original.
			spawn_pos = get_offscreen_spawn_position(i, count_to_spawn)

		var enemy: CharacterBody2D = null
		if reinforcement_enemy_scene != null:
			var instance = reinforcement_enemy_scene.instantiate()
			if instance is CharacterBody2D:
				enemy = instance as CharacterBody2D
				# Configura arquétipo antes de add_child para aplicar stats e paleta visual (P0/P4)
				if i < reinforcement_archetypes.size():
					enemy.set("archetype", reinforcement_archetypes[i])
				enemy.global_position = spawn_pos
				# Entrada legível: inicia em FLANKING (caminha para posição de flanco sem ataque surpresa)
				enemy.set("current_state", 2) # State.FLANKING
				actors_container.add_child(enemy)

		if enemy != null:
			if combat_director != null:
				combat_director.notify_spawn_completed(enemy)
		else:
			# Resiliência: decrementa pendência caso instanciação falhe
			if combat_director != null:
				combat_director.notify_spawn_completed(null)


func _get_map1_mobile_reinforcement_spawn_position(
	index: int,
	total: int,
	used_positions: Array[Vector2]
) -> Vector2:
	var active_player: Node2D = get_player() as Node2D
	if active_player == null or not is_instance_valid(active_player):
		return Vector2(991.5, 680.0 + float(index) * MAP1_MOBILE_SPAWN_SPACING_Y)

	var player_position: Vector2 = active_player.global_position
	var camera_x: float = camera.global_position.x if camera != null else player_position.x
	var zoom_x: float = absf(camera.zoom.x) if camera != null else 1.0
	zoom_x = maxf(zoom_x, 0.001)
	var viewport_width: float = get_viewport_rect().size.x
	var half_visible_width: float = viewport_width * 0.5 / zoom_x

	# Reforços entram pelo lado oposto ao jogador, na borda da câmera quando
	# houver espaço; se o celular mostrar praticamente todo o mapa, entram
	# perto do combate em vez de serem clampados para o canto x=160.
	var direction: float = 1.0 if player_position.x <= camera_x else -1.0
	var visible_edge_x: float = camera_x + direction * half_visible_width
	var requested_x: float = visible_edge_x + direction * MAP1_MOBILE_SPAWN_EDGE_MARGIN
	if requested_x < MAP1_MOBILE_SPAWN_MIN_X or requested_x > MAP1_MOBILE_SPAWN_MAX_X:
		requested_x = player_position.x + direction * MAP1_MOBILE_SPAWN_FALLBACK_DISTANCE

	var centered_index: float = float(index) - (float(maxi(total, 1) - 1) * 0.5)
	var requested_y: float = clampf(
		player_position.y + 28.0 + centered_index * MAP1_MOBILE_SPAWN_SPACING_Y,
		MAP1_MOBILE_SPAWN_MIN_Y,
		MAP1_MOBILE_SPAWN_MAX_Y
	)

	var nav_map: RID = get_world_2d().navigation_map if get_world_2d() != null else RID()
	var player_nav_position: Vector2 = player_position
	var navigation_ready: bool = nav_map.is_valid() and NavigationServer2D.map_get_iteration_id(nav_map) > 0
	if navigation_ready:
		player_nav_position = NavigationServer2D.map_get_closest_point(nav_map, player_position)

	var x_adjustments: Array[float] = [0.0, 48.0, -48.0, 96.0, -96.0, 144.0, -144.0]
	var y_adjustments: Array[float] = [0.0, -12.0, 12.0, -24.0, 24.0]
	var best_position: Vector2 = Vector2.ZERO
	var best_score: float = INF

	for x_adjustment: float in x_adjustments:
		var sample_x: float = clampf(
			requested_x + direction * x_adjustment,
			MAP1_MOBILE_SPAWN_MIN_X,
			MAP1_MOBILE_SPAWN_MAX_X
		)
		for y_adjustment: float in y_adjustments:
			var sample_position := Vector2(
				sample_x,
				clampf(requested_y + y_adjustment, MAP1_MOBILE_SPAWN_MIN_Y, MAP1_MOBILE_SPAWN_MAX_Y)
			)
			var candidate: Vector2 = sample_position
			if navigation_ready:
				candidate = NavigationServer2D.map_get_closest_point(nav_map, sample_position)
				if candidate == Vector2.ZERO:
					continue
				if sample_position.distance_to(candidate) > 42.0:
					continue
				var path: PackedVector2Array = NavigationServer2D.map_get_path(
					nav_map, player_nav_position, candidate, true, 1
				)
				if path.is_empty():
					continue

			var separated: bool = true
			for previous_position: Vector2 in used_positions:
				if candidate.distance_to(previous_position) < 48.0:
					separated = false
					break
			if not separated:
				continue

			var score: float = sample_position.distance_to(candidate) * 3.0
			score += absf(candidate.x - requested_x) * 0.35
			score += absf(candidate.y - requested_y) * 0.5
			if score < best_score:
				best_score = score
				best_position = candidate

	if best_position != Vector2.ZERO:
		used_positions.append(best_position)
		return best_position

	# Fallback seguro exclusivo do Mapa 1 mobile: permanece dentro da faixa
	# inferior caminhável e nunca retorna ao clamp da borda esquerda (x=160).
	var fallback_x: float = clampf(
		player_position.x + direction * (MAP1_MOBILE_SPAWN_FALLBACK_DISTANCE + index * MAP1_MOBILE_SPAWN_SPACING_X),
		MAP1_MOBILE_SPAWN_MIN_X,
		MAP1_MOBILE_SPAWN_MAX_X
	)
	var fallback_position := Vector2(fallback_x, requested_y)
	if navigation_ready:
		var snapped_fallback: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, fallback_position)
		if snapped_fallback != Vector2.ZERO:
			var fallback_path: PackedVector2Array = NavigationServer2D.map_get_path(
				nav_map, player_nav_position, snapped_fallback, true, 1
			)
			if not fallback_path.is_empty():
				fallback_position = snapped_fallback
	used_positions.append(fallback_position)
	return fallback_position


## Calcula uma coordenada em coordenadas de mundo fora do retângulo visível da Camera2D dentro dos limites caminháveis (P5)
func get_offscreen_spawn_position(index: int = 0, total: int = 1) -> Vector2:
	var viewport_size: Vector2 = Vector2(1280, 720)
	if get_viewport() != null:
		viewport_size = get_viewport_rect().size

	var cam_x: float = camera.global_position.x if camera != null else 640.0
	var cam_left: float = cam_x - (viewport_size.x * 0.5)
	var cam_right: float = cam_x + (viewport_size.x * 0.5)

	# Margem de segurança fora do campo de visão da câmera (70px a 150px)
	var margin: float = 70.0 + float(index * 40.0)

	# Limites de mundo caminháveis para o mapa atual (com folga das paredes)
	var min_walkable_x: float = 160.0
	var max_walkable_x: float = 1880.0
	var min_walkable_y: float = 580.0
	var max_walkable_y: float = 710.0

	match map_index:
		1:
			min_walkable_y = 540.0
			max_walkable_y = 710.0
		2:
			min_walkable_y = 520.0
			max_walkable_y = 730.0
		3:
			min_walkable_y = 645.0
			max_walkable_y = 730.0
		4:
			min_walkable_y = 560.0
			max_walkable_y = 720.0

	var p := get_player()
	var p_x: float = p.global_position.x if p != null and is_instance_valid(p) else cam_x

	var right_candidate_x: float = cam_right + margin
	var left_candidate_x: float = cam_left - margin

	var right_valid: bool = (right_candidate_x <= max_walkable_x)
	var left_valid: bool = (left_candidate_x >= min_walkable_x)

	var spawn_on_right: bool = true
	if right_valid and left_valid:
		# Escolhe o lado oposto ao jogador em relação ao centro da câmera
		spawn_on_right = (p_x <= cam_x)
	elif right_valid:
		spawn_on_right = true
	elif left_valid:
		spawn_on_right = false
	else:
		# Fallback se a câmera abranger o mapa todo: posiciona no extremo mais distante do jogador
		spawn_on_right = (p_x <= (min_walkable_x + max_walkable_x) * 0.5)

	var spawn_x: float = right_candidate_x if spawn_on_right else left_candidate_x
	spawn_x = clampf(spawn_x, min_walkable_x, max_walkable_x)

	# Variação no eixo Y para múltiplos reforços não sobreporem
	var y_offset: float = 0.0
	if total > 1:
		var y_spread: float = minf(70.0, (max_walkable_y - min_walkable_y) / float(total))
		y_offset = (float(index) - float(total - 1) * 0.5) * y_spread

	var target_base_y: float = 640.0
	if p != null and is_instance_valid(p):
		target_base_y = p.global_position.y
	var spawn_y: float = clampf(target_base_y + y_offset, min_walkable_y, max_walkable_y)

	return Vector2(spawn_x, spawn_y)


## Disparado pelo CombatDirector quando todos os inimigos forem derrotados
func _on_encounter_cleared() -> void:
	# Blindagem absoluta: jamais abre saída se houver chefe configurado que ainda não deu spawn
	if boss_scene != null and not _boss_spawned:
		return

	# Blindagem: jamais abre saída se houver reforços pendentes registrados no diretor
	if combat_director != null and combat_director.pending_spawns_count > 0:
		return

	# 1. Habilita a detecção na área de saída
	if exit_area != null:
		exit_area.monitoring = true

	# 2. Ativa o indicador visual piscante SIGA → (piscando na tela independente da posição do personagem)
	if siga_indicator != null:
		siga_indicator.activate()


## Invoca o Chefe no mapa com aviso na HUD e registro no CombatDirector
func _spawn_boss() -> void:
	_boss_spawned = true
	var actors_container: Node2D = get_actors_container()

	var boss: CharacterBody2D = null
	if spawn_director != null and spawn_director.get_spawn_point("spawn_boss") != null:
		boss = spawn_director.spawn_at_point("spawn_boss", boss_scene, actors_container) as CharacterBody2D
	elif boss_scene != null:
		boss = boss_scene.instantiate() as CharacterBody2D
		if boss != null:
			boss.global_position = boss_spawn_position
			actors_container.add_child(boss)

	if boss != null:
		_boss_instance = boss
		if combat_director != null:
			combat_director.is_cleared = false
			combat_director.encounter_state = "COMBAT"
			combat_director.notify_spawn_completed(boss)
		if hud != null and hud.has_method("set_enemy_target"):
			hud.set_enemy_target(boss)

	# Notificação de Boss na HUD
	if hud != null and hud.banner_panel != null and hud.banner_label != null:
		hud.banner_panel.visible = true
		hud.banner_label.text = boss_announcement_text
		hud.banner_label.modulate = Color(1.0, 0.25, 0.2)

		var t = create_tween()
		t.tween_interval(3.0)
		t.tween_property(hud.banner_panel, "modulate:a", 0.0, 0.5)
		t.tween_callback(func():
			if hud != null and hud.banner_panel != null:
				hud.banner_panel.visible = false
				hud.banner_panel.modulate.a = 1.0
		)


## Disparado quando um corpo físico entra na área de saída
func _on_exit_body_entered(body: Node2D) -> void:
	if _transitioning:
		return

	if body != null and body.is_in_group("player"):
		_transitioning = true
		_advance_to_next_map()


## Executa a transição segura para o próximo mapa ou encerramento da fase
func _advance_to_next_map() -> void:
	if siga_indicator != null:
		siga_indicator.deactivate()

	# Cancela pendências de reforços agendados
	_clear_pending_reinforcements()

	# Salva a vida e energia especial para a próxima seção do mesmo mapa
	var session = get_node_or_null("/root/GameSession")
	if session != null and player != null:
		# Sincroniza fichas de continue com a sessão para a nova seção
		if "current_continues" in session and "current_continues" in player:
			session.current_continues = player.current_continues
		var cur_hp: float = player.health_component.current_health if player.health_component != null else 100.0
		var cur_sp: float = player.current_special if "current_special" in player else 0.0
		if not is_final_map and not next_map_scene_path.is_empty():
			session.save_player_progression(map_group, cur_hp, cur_sp)
		else:
			session.clear_player_progression()

	if is_final_map or next_map_scene_path.is_empty():
		# Se for a fase bônus da garagem, dispara a transição cinemática do Bônus 1 ao Ponto 2 (desbloqueando a Fase 2)
		if map_group == "bonus1" or section_number == 5:
			if session != null:
				session.has_seen_stage_2_transition = true
				session.pending_map_transition_mode = 1 # BONUS_TO_POINT2
				session.pending_transition_target = victory_scene_path if not victory_scene_path.is_empty() else "res://scenes/ui/credits.tscn"
			_safe_change_scene("res://scenes/ui/map_transition.tscn")
			return

		# Fim do Mapa 4 (Clímax da Fase 1) -> Vitória!
		if hud != null and hud.banner_panel != null and hud.banner_label != null:
			hud.banner_panel.visible = true
			hud.banner_label.text = "🏆 FASE 1 CONCLUÍDA!\nVITÓRIA EM SAKAS: ÚLTIMA FICHA!"
			hud.banner_label.modulate = Color(1.0, 0.85, 0.2)

		await get_tree().create_timer(2.0).timeout
		_safe_change_scene(victory_scene_path)
	else:
		# Transição para o próximo mapa da sequência (com suporte à transição cinemática do mapa após 1-4)
		if (map_group == "fase1" and map_index == 4) or (stage_number == 1 and section_number == 4):
			if session != null:
				session.has_seen_bonus_transition = true
				session.pending_map_transition_mode = 0 # POINT1_TO_BONUS
				session.pending_transition_target = next_map_scene_path if not next_map_scene_path.is_empty() else "res://scenes/levels/bonus_garage.tscn"
			_safe_change_scene("res://scenes/ui/map_transition.tscn")
		else:
			_safe_change_scene(next_map_scene_path)


func _safe_change_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return

	if get_viewport() != null:
		get_viewport().set_input_as_handled()

	var err: Error = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		printerr("Erro ao transicionar para o mapa '%s': %d" % [scene_path, err])


func _on_player_died_for_hud() -> void:
	if player != null and ("is_respawning" in player and player.is_respawning):
		# O jogador está no processo de ressurgir dos céus (Mecânica Arcade Continue)
		return
	if player != null and "current_continues" in player and player.current_continues > 0:
		# O jogador consumirá a ficha e ressurgirá dos céus (Mecânica Arcade Continue)
		return
	_clear_pending_reinforcements()
	if hud != null and hud.has_method("show_game_over"):
		# Define a cena de reinício como o primeiro mapa da fase atual (Fase 1 → map_1.tscn)
		var restart_path: String = _get_stage_restart_scene_path()
		if hud.has_method("set_restart_scene"):
			hud.set_restart_scene(restart_path)
		hud.show_game_over()


func _clear_pending_reinforcements() -> void:
	if _pending_reinforcements_to_spawn > 0:
		if combat_director != null:
			combat_director.pending_spawns_count = maxi(0, combat_director.pending_spawns_count - _pending_reinforcements_to_spawn)
		_pending_reinforcements_to_spawn = 0


# ============================================================
# SISTEMA DE SNAPSHOT DO MUNDO (Save/Continue fiel)
# ============================================================

## Captura um snapshot serializado e completo do estado atual do mundo.
## Retorna um Dictionary puro (sem referências a Nodes), pronto para JSON.
func capture_world_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}

	# --- JOGADOR ---
	var p: PlayerController = get_player()
	if p != null and is_instance_valid(p):
		var player_data: Dictionary = {
			"pos_x": p.global_position.x,
			"pos_y": p.global_position.y,
			"facing": p.facing_direction,
		}
		if p.health_component != null:
			player_data["hp"] = p.health_component.current_health
			player_data["max_hp"] = p.health_component.max_health
		if "current_special" in p:
			player_data["sp"] = p.current_special
		if "max_special" in p:
			player_data["max_sp"] = p.max_special
		if "combat_state" in p:
			player_data["combat_state"] = int(p.combat_state)
		if "current_continues" in p:
			player_data["continues"] = p.current_continues
		snapshot["player"] = player_data

	# --- INIMIGOS VIVOS ---
	var enemies_alive: Array = []
	var defeated_ids: Array = []
	var actors_container: Node2D = get_actors_container()
	var all_enemies: Array[Node] = get_tree().get_nodes_in_group("enemies") if get_tree() != null else []

	for enemy_node in all_enemies:
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not (enemy_node is CharacterBody2D):
			continue
		var enemy: CharacterBody2D = enemy_node as CharacterBody2D

		# Gera um ID estável baseado no nome do nó + posição inicial
		var enemy_id: String = enemy.name

		# Verifica se o inimigo está morto
		var is_dead: bool = false
		if "current_state" in enemy and int(enemy.current_state) == 12: # State.DEAD
			is_dead = true
		if "health_component" in enemy and enemy.health_component != null:
			if enemy.health_component.is_dead:
				is_dead = true

		if is_dead:
			defeated_ids.append(enemy_id)
			continue

		# Serializa inimigo vivo
		var enemy_data: Dictionary = {
			"id": enemy_id,
			"scene_path": enemy.scene_file_path if not enemy.scene_file_path.is_empty() else "res://scenes/actors/enemies/basic_enemy.tscn",
			"pos_x": enemy.global_position.x,
			"pos_y": enemy.global_position.y,
			"facing": enemy.facing_direction if "facing_direction" in enemy else -1.0,
		}

		if "health_component" in enemy and enemy.health_component != null:
			enemy_data["hp"] = enemy.health_component.current_health
			enemy_data["max_hp"] = enemy.health_component.max_health
		if "current_state" in enemy:
			enemy_data["state"] = int(enemy.current_state)
		if "archetype" in enemy:
			enemy_data["archetype"] = int(enemy.archetype)
		if "palette_variant" in enemy:
			enemy_data["palette"] = int(enemy.palette_variant)
		if "display_name" in enemy:
			enemy_data["display_name"] = str(enemy.display_name)

		enemies_alive.append(enemy_data)

	snapshot["enemies_alive"] = enemies_alive
	snapshot["defeated_enemies"] = defeated_ids

	# --- ESTADO DE COMBATE E ONDAS ---
	snapshot["reinforcement_wave_triggered"] = _reinforcement_wave_triggered
	snapshot["boss_spawned"] = _boss_spawned

	if combat_director != null:
		snapshot["combat_is_cleared"] = combat_director.is_cleared
		snapshot["combat_pending_spawns"] = combat_director.pending_spawns_count

	return snapshot


## Restaura o estado do mundo a partir de um snapshot previamente capturado.
## Reposiciona o jogador, reconcilia inimigos (remove derrotados, atualiza vivos,
## reinstancia ausentes) e restaura flags de progressão da fase.
func restore_world_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return

	var p: PlayerController = get_player()

	# --- RESTAURA JOGADOR ---
	if snapshot.has("player") and p != null and is_instance_valid(p):
		var pd: Dictionary = snapshot["player"] as Dictionary
		var restore_x: float = float(pd.get("pos_x", p.global_position.x))
		var restore_y: float = float(pd.get("pos_y", p.global_position.y))
		p.global_position = Vector2(restore_x, restore_y)

		var restore_facing: float = float(pd.get("facing", p.facing_direction))
		p.facing_direction = restore_facing
		if p.visual_root != null:
			p.visual_root.scale.x = absf(p.visual_root.scale.x) * signf(restore_facing) if restore_facing != 0.0 else absf(p.visual_root.scale.x)

		if p.health_component != null and pd.has("hp"):
			p.health_component.current_health = float(pd["hp"])
			if hud != null:
				hud.update_player_health(p.health_component.current_health, p.health_component.max_health)

		if "current_special" in p and pd.has("sp"):
			p.current_special = float(pd["sp"])
			if p.has_signal("special_changed") and "max_special" in p:
				p.special_changed.emit(p.current_special, p.max_special)

		if "current_continues" in p and pd.has("continues"):
			p.current_continues = int(pd["continues"])
			var session = get_node_or_null("/root/GameSession")
			if session != null and "current_continues" in session:
				session.current_continues = p.current_continues

		# Atualiza câmera imediatamente para a posição restaurada do jogador
		if camera != null:
			var cam_x: float = clampf(restore_x, camera_min_x, camera_max_x)
			camera.global_position = Vector2(cam_x, camera_fixed_y)
			camera.position = Vector2(cam_x, camera_fixed_y)

	# --- RECONCILIA INIMIGOS ---
	var defeated_ids: Array = snapshot.get("defeated_enemies", []) as Array
	var saved_enemies: Array = snapshot.get("enemies_alive", []) as Array

	# Mapa de inimigos existentes na cena pelo nome do nó
	var existing_enemies: Dictionary = {} # { String: CharacterBody2D }
	var all_enemy_nodes: Array[Node] = get_tree().get_nodes_in_group("enemies") if get_tree() != null else []
	for en in all_enemy_nodes:
		if en != null and is_instance_valid(en) and en is CharacterBody2D:
			existing_enemies[en.name] = en

	# 1. Remove inimigos que já foram derrotados antes do save
	for defeated_id in defeated_ids:
		var def_str: String = str(defeated_id)
		if existing_enemies.has(def_str):
			var dead_enemy: CharacterBody2D = existing_enemies[def_str]
			if combat_director != null and combat_director.has_method("unregister_enemy"):
				combat_director.unregister_enemy(dead_enemy)
			dead_enemy.queue_free()
			existing_enemies.erase(def_str)

	# 2. Atualiza inimigos vivos com posição, HP, facing e estado salvos
	var restored_ids: Dictionary = {} # Rastreia quais IDs do save foram restaurados
	for enemy_data in saved_enemies:
		var ed: Dictionary = enemy_data as Dictionary
		var enemy_id: String = str(ed.get("id", ""))
		if enemy_id.is_empty():
			continue

		if existing_enemies.has(enemy_id):
			# Inimigo existe na cena: atualiza estado
			var enemy: CharacterBody2D = existing_enemies[enemy_id]
			enemy.global_position = Vector2(float(ed.get("pos_x", enemy.global_position.x)), float(ed.get("pos_y", enemy.global_position.y)))

			if "facing_direction" in enemy:
				enemy.facing_direction = float(ed.get("facing", enemy.facing_direction))
				if "visual_root" in enemy and enemy.visual_root != null:
					var fdir: float = enemy.facing_direction
					enemy.visual_root.scale.x = absf(enemy.visual_root.scale.x) * signf(fdir) if fdir != 0.0 else absf(enemy.visual_root.scale.x)

			if "health_component" in enemy and enemy.health_component != null and ed.has("hp"):
				enemy.health_component.current_health = float(ed["hp"])

			if "current_state" in enemy and ed.has("state"):
				var saved_state: int = int(ed["state"])
				# Não restaura estados transitórios (HURT, FALL, GETUP); coloca em FLANKING para retomar IA
				if saved_state in [8, 9, 10, 11]: # HURT, FALL, DOWNED, GETUP
					enemy.current_state = 2 # FLANKING
				else:
					enemy.current_state = saved_state

			restored_ids[enemy_id] = true
		else:
			# Inimigo não existe na cena (spawn dinâmico): reinstancia
			var scene_path: String = str(ed.get("scene_path", "res://scenes/actors/enemies/basic_enemy.tscn"))
			if not ResourceLoader.exists(scene_path):
				continue
			var enemy_scene: PackedScene = load(scene_path) as PackedScene
			if enemy_scene == null:
				continue

			var new_enemy: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
			if new_enemy == null:
				continue

			new_enemy.name = enemy_id
			new_enemy.global_position = Vector2(float(ed.get("pos_x", 800.0)), float(ed.get("pos_y", 640.0)))

			if "archetype" in new_enemy and ed.has("archetype"):
				new_enemy.set("archetype", int(ed["archetype"]))
			if "palette_variant" in new_enemy and ed.has("palette"):
				new_enemy.set("palette_variant", int(ed["palette"]))
			if "display_name" in new_enemy and ed.has("display_name"):
				new_enemy.set("display_name", str(ed["display_name"]))
			if "facing_direction" in new_enemy:
				new_enemy.facing_direction = float(ed.get("facing", -1.0))
			if "current_state" in new_enemy:
				new_enemy.current_state = 2 # FLANKING (estado seguro para retomada)

			var actors_container: Node2D = get_actors_container()
			actors_container.add_child(new_enemy)

			# Restaura HP após add_child (health_component é @onready)
			if "health_component" in new_enemy and new_enemy.health_component != null and ed.has("hp"):
				new_enemy.health_component.current_health = float(ed["hp"])

			if combat_director != null:
				combat_director.register_enemy(new_enemy)

			restored_ids[enemy_id] = true

	# 3. Remove inimigos extras que não estão no save (evita duplicação)
	for existing_id in existing_enemies.keys():
		if not restored_ids.has(existing_id) and not defeated_ids.has(existing_id):
			# Inimigo que existia na cena pré-montada mas não estava no save
			# (provavelmente um spawn que não deveria existir nesta posição de progresso)
			# Mantém por segurança — não remove inimigos pré-posicionados do editor
			pass

	# --- RESTAURA FLAGS DE PROGRESSÃO ---
	_reinforcement_wave_triggered = bool(snapshot.get("reinforcement_wave_triggered", false))
	_boss_spawned = bool(snapshot.get("boss_spawned", false))

	if combat_director != null:
		if snapshot.has("combat_is_cleared"):
			combat_director.is_cleared = bool(snapshot["combat_is_cleared"])
		if snapshot.has("combat_pending_spawns"):
			combat_director.pending_spawns_count = int(snapshot["combat_pending_spawns"])

	# Se o encounter já estava limpo, reabilita saída e indicador SIGA
	if combat_director != null and combat_director.is_cleared:
		if exit_area != null:
			exit_area.monitoring = true
		if siga_indicator != null:
			siga_indicator.activate()


func _exit_tree() -> void:
	_clear_pending_reinforcements()


## Retorna o caminho da cena de reinício para a fase atual.
## Fase 1 sempre retorna para map_1.tscn. Fases futuras retornarão para o mapa inicial da fase em questão.
func _get_stage_restart_scene_path() -> String:
	# Para a Fase 1 (mapas 1 a 4), o reinício sempre volta para o map_1
	if stage_number == 1:
		return "res://scenes/levels/map_1.tscn"
	# Fases futuras: fallback para o próprio scene_file_path
	return scene_file_path if not scene_file_path.is_empty() else "res://scenes/levels/map_1.tscn"


func _unhandled_input(event: InputEvent) -> void:
	# Durante o Game Over, o PrototypeHud gerencia a entrada R para reiniciar a fase
	if hud != null and "_game_over_active" in hud and hud._game_over_active:
		return

	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if pause_menu != null:
			if pause_menu.visible:
				pause_menu.resume_game()
			else:
				pause_menu.open_pause(scene_file_path)
		else:
			var err := get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
			if err != OK:
				printerr("Erro ao retornar ao menu principal: ", err)
