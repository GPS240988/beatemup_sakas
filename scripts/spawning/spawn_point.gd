class_name SpawnPoint
extends Marker2D

## Ponto de Geração Dinâmica de Entidades (FASE 4).
## Define a coordenada física, tipo de spawn e atributos para instanciação em runtime.

enum SpawnType {
	ENEMY,
	NPC,
	REINFORCEMENT,
	EVENT,
	BOSS
}

signal spawned(entity: Node)

@export var point_id: String = ""
@export var spawn_type: SpawnType = SpawnType.ENEMY
@export var spawn_group: String = "enemies"
@export var default_scene: PackedScene = null
@export var is_active: bool = true


func _ready() -> void:
	add_to_group("spawn_points")
	if point_id.is_empty():
		point_id = name


## Instancia e posiciona uma entidade neste SpawnPoint
func spawn(scene_to_spawn: PackedScene = null, target_parent: Node = null) -> Node:
	if not is_active:
		return null

	var scene: PackedScene = scene_to_spawn if scene_to_spawn != null else default_scene
	if scene == null:
		push_warning("SpawnPoint [%s]: Nenhuma PackedScene fornecida para spawn." % point_id)
		return null

	var instance: Node = scene.instantiate()
	if instance == null:
		return null

	if instance is Node2D:
		(instance as Node2D).global_position = global_position

	if target_parent != null:
		target_parent.add_child(instance)
	elif get_parent() != null:
		get_parent().add_child(instance)

	spawned.emit(instance)
	return instance
