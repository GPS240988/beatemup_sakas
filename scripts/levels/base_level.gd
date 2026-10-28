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

	# O indicador SIGA → inicia oculto e inativo
	if siga_indicator != null:
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
	_check_and_trigger_opening_narrative()


func _check_and_trigger_opening_narrative() -> void:
	if stage_number != 1 or section_number != 1 or Engine.is_editor_hint():
		return

	var session = get_node_or_null("/root/GameSession")
	if session != null and "has_played_intro" in session and not session.has_played_intro:
		_trigger_opening_narrative()


func _trigger_opening_narrative() -> void:
	var nar_director: NarrativeDirector = null
	var nar_scene: PackedScene = load("res://scenes/ui/narrative_director.tscn") as PackedScene
	if nar_scene != null:
		nar_director = nar_scene.instantiate() as NarrativeDirector
	else:
		nar_director = NarrativeDirectorClass.new()
	nar_director.name = "NarrativeDirector"
	add_child(nar_director)
	nar_director.play_sequence_from_path("res://resources/story/story_intro_map1.tres")


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


## Instancia os reforços programados fora do retângulo visível da câmera (P5)
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

	for i in range(count_to_spawn):
		var spawn_pos: Vector2 = get_offscreen_spawn_position(i, count_to_spawn)
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


## Calcula uma coordenada no mundo exterior ao retângulo visível da Camera2D dentro dos limites caminháveis (P5)
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
		# Fim do Mapa 4 (Clímax da Fase 1) -> Vitória!
		if hud != null and hud.banner_panel != null and hud.banner_label != null:
			hud.banner_panel.visible = true
			hud.banner_label.text = "🏆 FASE 1 CONCLUÍDA!\nVITÓRIA EM SAKAS: ÚLTIMA FICHA!"
			hud.banner_label.modulate = Color(1.0, 0.85, 0.2)

		await get_tree().create_timer(2.0).timeout
		_safe_change_scene(victory_scene_path)
	else:
		# Transição para o próximo mapa da sequência
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


func _exit_tree() -> void:
	_clear_pending_reinforcements()


## Retorna o caminho da cena de reinício para a fase atual.
## Fase 1 sempre retorna para map_1.tscn. Fases futuras retornarão para o mapa inicial da fase em questão.
func _get_stage_restart_scene_path() -> String:
	# Para a Fase 1 (mapas 1 a 4), o reinício sempre volta para o map_1
	if stage_number == 1:
		return "res://scenes/levels/map_1.tscn"
	# Fases futuras: retorna para o primeiro mapa daquela fase
	# Por enquanto fallback para o próprio scene_file_path
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
