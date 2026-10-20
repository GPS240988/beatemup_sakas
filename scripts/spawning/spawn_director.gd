class_name SpawnDirector
extends Node

## Orquestrador Central de Spawns em Runtime (FASE 4).
## Gerencia pontos de spawn, instanciação por posição, grupo, evento, tempo e reforço,
## coordenando com o CombatDirector para registro automático de combatentes.

const SpawnPointClass = preload("res://scripts/spawning/spawn_point.gd")

signal entity_spawned(entity: Node, point_id: String, spawn_type: int)
signal reinforcement_spawned(enemy: CharacterBody2D, point_id: String)
signal npc_spawned(npc: CharacterBody2D, point_id: String)

@export var auto_discover_points: bool = true
@export var combat_director_path: NodePath = ^"../CombatDirector"

var _points_by_id: Dictionary = {} # { String: SpawnPoint }
var combat_director: CombatDirector = null


func _ready() -> void:
	add_to_group("spawn_director")
	if auto_discover_points:
		call_deferred("discover_spawn_points")
	_resolve_combat_director()


func _resolve_combat_director() -> void:
	if not combat_director_path.is_empty() and has_node(combat_director_path):
		combat_director = get_node_or_null(combat_director_path) as CombatDirector
	if combat_director == null and is_inside_tree():
		combat_director = get_tree().get_first_node_in_group("combat_director") as CombatDirector


## Varre a cena em busca de nós SpawnPoint
func discover_spawn_points() -> void:
	_points_by_id.clear()
	if not is_inside_tree():
		return
	var nodes: Array[Node] = get_tree().get_nodes_in_group("spawn_points")
	for n in nodes:
		if n is SpawnPointClass:
			register_spawn_point(n)


## Registra um ponto de spawn no dicionário indexado
func register_spawn_point(point: Node) -> void:
	if point == null:
		return
	var id: String = point.get("point_id") if point.get("point_id") != null and not str(point.get("point_id")).is_empty() else point.name
	_points_by_id[id] = point


## Retorna um ponto de spawn pelo ID
func get_spawn_point(point_id: String) -> Node:
	if _points_by_id.has(point_id):
		return _points_by_id[point_id] as Node
	return null


## Retorna todos os pontos cadastrados
func get_all_points() -> Array[Node]:
	var result: Array[Node] = []
	for p in _points_by_id.values():
		if p is Node:
			result.append(p as Node)
	return result


## Retorna pontos de spawn filtrados por tipo
func get_points_by_type(type: int) -> Array[Node]:
	var filtered: Array[Node] = []
	for p in get_all_points():
		if p.get("spawn_type") == type:
			filtered.append(p)
	return filtered


## Retorna pontos de spawn filtrados por grupo
func get_points_by_group(group_name: String) -> Array[Node]:
	var filtered: Array[Node] = []
	for p in get_all_points():
		if p.get("spawn_group") == group_name:
			filtered.append(p)
	return filtered


## Spawna uma entidade em um SpawnPoint específico por ID
func spawn_at_point(point_id: String, scene_to_spawn: PackedScene = null, target_parent: Node = null) -> Node:
	var point := get_spawn_point(point_id)
	if point == null:
		push_warning("SpawnDirector: SpawnPoint [%s] não encontrado." % point_id)
		return null

	var entity: Node = null
	if point.has_method("spawn"):
		entity = point.call("spawn", scene_to_spawn, target_parent)
	if entity != null:
		var stype: int = point.get("spawn_type") if point.get("spawn_type") != null else 0
		_on_entity_created(entity, point_id, stype)
	return entity


## Spawna uma entidade em uma coordenada física livre
func spawn_at_position(pos: Vector2, scene_to_spawn: PackedScene, target_parent: Node = null, spawn_type: int = 0) -> Node:
	if scene_to_spawn == null:
		return null

	var entity: Node = scene_to_spawn.instantiate()
	if entity == null:
		return null

	if entity is Node2D:
		(entity as Node2D).global_position = pos

	if target_parent != null:
		target_parent.add_child(entity)
	elif is_inside_tree():
		var root_scene := get_tree().current_scene
		if root_scene != null:
			root_scene.add_child(entity)

	_on_entity_created(entity, "pos_spawn", spawn_type)
	return entity


## Spawna um reforço e o registra no CombatDirector
func spawn_reinforcement(point_id: String, scene_to_spawn: PackedScene = null, target_parent: Node = null) -> CharacterBody2D:
	var entity := spawn_at_point(point_id, scene_to_spawn, target_parent)
	var enemy := entity as CharacterBody2D
	if enemy != null:
		reinforcement_spawned.emit(enemy, point_id)
		if combat_director != null:
			combat_director.notify_spawn_completed(enemy)
	return enemy


## Spawna um NPC civil
func spawn_npc(point_id: String, scene_to_spawn: PackedScene = null, target_parent: Node = null) -> CharacterBody2D:
	var entity := spawn_at_point(point_id, scene_to_spawn, target_parent)
	var npc := entity as CharacterBody2D
	if npc != null:
		npc_spawned.emit(npc, point_id)
	return npc


func _on_entity_created(entity: Node, point_id: String, spawn_type: int) -> void:
	entity_spawned.emit(entity, point_id, spawn_type)

	# Se for inimigo ou reforço, registra no CombatDirector se disponível
	var is_hostile: bool = (spawn_type == SpawnPointClass.SpawnType.ENEMY or spawn_type == SpawnPointClass.SpawnType.REINFORCEMENT or spawn_type == SpawnPointClass.SpawnType.BOSS)
	if is_hostile:
		var enemy := entity as CharacterBody2D
		if enemy != null and combat_director != null:
			combat_director.register_enemy(enemy)
