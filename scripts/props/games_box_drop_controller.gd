extends Node

## Controlador de drop exclusivo da caixa da Fase 1-1.
## A cena da caixa também é reutilizada na Fase 1-2; por isso, este controlador
## só conecta prop_destroyed quando a cena atual é map_1.tscn. Em map_2.tscn,
## o DestructibleProp continua responsável exclusivamente pelo drop CocaPickup.

const DROP_ITEM_SCENE: PackedScene = preload("res://scenes/items/dropped_magazine_interaction.tscn")
const TARGET_LEVEL_FILE: String = "map_1.tscn"

const DROP_ITEMS: Array[Dictionary] = [
	{
		"name": "EMMANUELE",
		"world_texture": "res://assets/sprites/Itens/emmanuele.jpg",
		"inspect_texture": "res://assets/sprites/Itens/emmanuele_gg.jpg",
		"dialogue": "Sei todas as falas, faltava esse pra minha coleção.",
		"offset": Vector2(-40.0, 0.0)
	},
	{
		"name": "PLAYBOY",
		"world_texture": "res://assets/sprites/Itens/playboy.jpg",
		"inspect_texture": "res://assets/sprites/Itens/playboy_gg.jpg",
		"dialogue": "Japonês safado, larga essas coisas aqui.",
		"offset": Vector2(40.0, 0.0)
	}
]

var _drops_spawned: bool = false
var _enabled_for_current_scene: bool = false


static func is_enabled_for_scene_path(scene_path: String, scene_name: String = "") -> bool:
	if not scene_path.is_empty():
		return scene_path.get_file().to_lower() == TARGET_LEVEL_FILE
	# Fallback para execução encapsulada/teste onde scene_file_path não foi propagado.
	return scene_name.strip_edges().to_lower() == "map1"


func _ready() -> void:
	# Avalia a current_scene depois de a mudança de cena completar o ciclo de _ready.
	call_deferred("_connect_for_active_level")


func _connect_for_active_level() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var current_scene: Node = get_tree().current_scene
	var scene_path: String = current_scene.scene_file_path if current_scene != null else ""
	var scene_name: String = current_scene.name if current_scene != null else ""
	_enabled_for_current_scene = is_enabled_for_scene_path(scene_path, scene_name)
	if not _enabled_for_current_scene:
		set_process(false)
		set_physics_process(false)
		return

	var box := get_parent() as Node
	if box == null or not box.has_signal("prop_destroyed"):
		push_error("GamesBoxDropController precisa ser filho de um DestructibleProp com o sinal prop_destroyed.")
		return
	if not box.is_connected("prop_destroyed", _on_box_destroyed):
		box.connect("prop_destroyed", _on_box_destroyed, CONNECT_ONE_SHOT)


func _on_box_destroyed() -> void:
	if not _enabled_for_current_scene or _drops_spawned:
		return
	_drops_spawned = true
	# Adia a criação dos Areas para fora da consulta física da destruição.
	_spawn_drops.call_deferred()


func _spawn_drops() -> void:
	if not _enabled_for_current_scene:
		return
	var box := get_parent() as Node2D
	if box == null or not is_instance_valid(box):
		return

	var drop_parent := box.get_parent()
	if drop_parent == null:
		push_error("A caixa destruída não possui um pai para receber os itens dropados.")
		return

	for config: Dictionary in DROP_ITEMS:
		var drop := DROP_ITEM_SCENE.instantiate() as Area2D
		if drop == null:
			push_error("Não foi possível instanciar dropped_magazine_interaction.tscn.")
			continue
		if not drop.has_method("configure_item"):
			push_error("A cena dropped_magazine_interaction.tscn não implementa configure_item().")
			drop.free()
			continue

		drop.name = "Drop_%s" % String(config.get("name", "ITEM"))
		drop.call(
			"configure_item",
			String(config.get("world_texture", "")),
			String(config.get("inspect_texture", "")),
			String(config.get("name", "ITEM")),
			String(config.get("dialogue", ""))
		)

		# Os dois itens ficam no mesmo plano do chão, próximos e lado a lado.
		var world_position: Vector2 = box.global_position + config.get("offset", Vector2.ZERO)
		drop_parent.add_child(drop)
		drop.global_position = world_position
