class_name ObjectPool
extends Node

## ObjectPool leve para instanciação e reciclagem de nós/cenas em tempo real.
## Elimina picos de alocação (instantiate) e garbage collection (queue_free) em batalhas intensas no mobile.
## Em conformidade com o padrão oficial de Object Pooling do Godot 4.x.

signal object_spawned(instance: Node)
signal object_despawned(instance: Node)

@export var pooled_scene: PackedScene
@export var initial_size: int = 8
@export var max_size: int = 32
@export var can_grow: bool = true

var _available: Array[Node] = []
var _in_use: Array[Node] = []
var _factory_callable: Callable = Callable()


func _ready() -> void:
	if pooled_scene != null and _available.is_empty():
		_initialize_pool()


func configure_factory(factory: Callable, p_initial_size: int = 8, p_max_size: int = 32) -> void:
	_factory_callable = factory
	initial_size = p_initial_size
	max_size = p_max_size
	_initialize_pool()


func _initialize_pool() -> void:
	for i in range(initial_size):
		var instance := _create_instance()
		if instance != null:
			_available.append(instance)


func _create_instance() -> Node:
	var instance: Node = null
	if _factory_callable.is_valid():
		instance = _factory_callable.call() as Node
	elif pooled_scene != null:
		instance = pooled_scene.instantiate()

	if instance == null:
		return null

	instance.process_mode = Node.PROCESS_MODE_DISABLED
	if instance is CanvasItem:
		(instance as CanvasItem).visible = false
	if instance is Node2D:
		(instance as Node2D).visible = false

	if not instance.is_inside_tree():
		add_child(instance)

	if instance.has_signal("returned_to_pool"):
		var sig: Signal = instance.get("returned_to_pool")
		if not sig.is_connected(release):
			sig.connect(release.bind(instance))

	return instance


func acquire() -> Node:
	var instance: Node = null

	while not _available.is_empty():
		var candidate: Node = _available.pop_back()
		if is_instance_valid(candidate):
			instance = candidate
			break

	if instance == null:
		if can_grow and (_in_use.size() < max_size or max_size <= 0):
			instance = _create_instance()
		else:
			if not _in_use.is_empty():
				instance = _in_use.pop_front()
				if is_instance_valid(instance) and instance.has_method("on_despawn"):
					instance.call("on_despawn")
			else:
				return null

	if instance == null or not is_instance_valid(instance):
		return null

	instance.process_mode = Node.PROCESS_MODE_INHERIT
	if instance is CanvasItem:
		(instance as CanvasItem).visible = true
	if instance is Node2D:
		(instance as Node2D).visible = true

	_in_use.append(instance)

	if instance.has_method("on_spawn"):
		instance.call("on_spawn")

	object_spawned.emit(instance)
	return instance


func release(instance: Node) -> void:
	if instance == null or not is_instance_valid(instance):
		return

	_in_use.erase(instance)

	if instance.has_method("on_despawn"):
		instance.call("on_despawn")

	instance.process_mode = Node.PROCESS_MODE_DISABLED
	if instance is CanvasItem:
		(instance as CanvasItem).visible = false
	if instance is Node2D:
		(instance as Node2D).visible = false

	if not instance in _available:
		_available.append(instance)

	object_despawned.emit(instance)


func release_all() -> void:
	for inst in _in_use.duplicate():
		release(inst)


func get_active_count() -> int:
	return _in_use.size()


func get_available_count() -> int:
	return _available.size()


## Helper estático para obter ou registrar um ObjectPool no nó de contexto informado.
## Retorna Node para evitar erro de auto-referência em static func; o caller faz cast.
static func get_or_create(context: Node, pool_name: String, scene: PackedScene = null, factory: Callable = Callable(), p_size: int = 8) -> Node:
	if context == null or not context.is_inside_tree():
		return null
	var existing: Node = context.get_node_or_null(pool_name)
	if existing != null:
		return existing
	var PoolScript: GDScript = load("res://scripts/core/object_pool.gd") as GDScript
	var pool: Node = PoolScript.new()
	pool.name = pool_name
	pool.set("pooled_scene", scene)
	pool.set("initial_size", p_size)
	if factory.is_valid():
		pool.call("configure_factory", factory, p_size)
	context.add_child(pool)
	return pool

