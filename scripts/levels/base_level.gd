class_name BaseLevel
extends Node2D

## Gerenciador e Controlador de Nível Base para Beat 'em Up 2.5D.
## Coordena o Combate via CombatDirector, o indicador "SIGA →",
## os limites da câmera e a progressão segura entre mapas.

const SigaIndicatorClass = preload("res://scripts/ui/siga_indicator.gd")
const CombatDirectorClass = preload("res://scripts/combat/combat_director.gd")
const SpawnDirectorClass = preload("res://scripts/spawning/spawn_director.gd")
const SpawnPointClass = preload("res://scripts/spawning/spawn_point.gd")

@export_group("Configuração do Mapa")
@export var map_name: String = "Fase 1 - Seção 1"
@export var map_index: int = 1
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

## Referências aos nós da cena
@onready var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var combat_director: CombatDirector = get_node_or_null("CombatDirector") as CombatDirector
@onready var exit_area: Area2D = get_node_or_null("ExitArea") as Area2D
@onready var siga_indicator: SigaIndicator = get_node_or_null("SigaIndicator") as SigaIndicator
@onready var hud: PrototypeHud = get_node_or_null("PrototypeHud") as PrototypeHud
@onready var spawn_director: Node = get_node_or_null("SpawnDirector")

var player: PlayerController = null

var _transitioning: bool = false
var _boss_spawned: bool = false
var _boss_instance: CharacterBody2D = null


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

	# Configura conexões do Diretor de Combate
	if combat_director != null:
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
			player.health_component.died.connect(hud.show_game_over)
			hud.update_player_health(player.health_component.current_health, player.health_component.max_health)
		hud.on_player_moved(player.global_position, Vector2.ZERO)

	if hud != null and hud.label_level_name != null:
		hud.label_level_name.text = "%s (Mapa %d/4)" % [map_name, map_index]


func _physics_process(delta: float) -> void:
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	if camera == null:
		return

	if player == null or not is_instance_valid(player):
		player = get_player()
		if player == null:
			return

	var target_x: float = clampf(player.global_position.x, camera_min_x, camera_max_x)
	camera.global_position.x = move_toward(camera.global_position.x, target_x, camera_follow_speed * 100.0 * delta)
	camera.global_position.y = camera_fixed_y


## Disparado quando um inimigo é derrotado
func _on_enemy_defeated(_enemy: CharacterBody2D) -> void:
	if boss_scene != null and not _boss_spawned:
		if combat_director != null and combat_director.alive_enemies.is_empty():
			_spawn_boss()


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

	# 2. Ativa o indicador visual piscante SIGA →
	if siga_indicator != null:
		siga_indicator.activate()

	# 3. Notifica a HUD
	if hud != null and hud.banner_panel != null and hud.banner_label != null:
		hud.banner_panel.visible = true
		if _boss_spawned:
			hud.banner_label.text = "⚔️ ÁREA LIMPA! CHEFÃO DERROTADO!\nSIGA → PARA A PRÓXIMA SEÇÃO"
		else:
			hud.banner_label.text = "⚔️ ÁREA LIMPA!\nSIGA → PARA A PRÓXIMA SEÇÃO"
		hud.banner_label.modulate = Color(0.3, 1.0, 0.4)


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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
