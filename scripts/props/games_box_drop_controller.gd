extends Node

## Controlador de drop exclusivo da caixa de jogos da Fase 1-1.
## Usa o sinal canônico prop_destroyed do DestructibleProp; não altera a lógica
## global das outras caixas/props do jogo.

const DROP_ITEM_SCENE: PackedScene = preload("res://scenes/items/dropped_magazine_interaction.tscn")

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


func _ready() -> void:
	var box := get_parent() as Node
	if box == null or not box.has_signal("prop_destroyed"):
		push_error("GamesBoxDropController precisa ser filho de um DestructibleProp com o sinal prop_destroyed.")
		return

	box.connect("prop_destroyed", _on_box_destroyed, CONNECT_ONE_SHOT)


func _on_box_destroyed() -> void:
	if _drops_spawned:
		return
	_drops_spawned = true
	# A destruição pode ocorrer durante uma consulta física; adia a criação dos Areas.
	_spawn_drops.call_deferred()


func _spawn_drops() -> void:
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

		# Os dois itens compartilham a linha de chão e ficam próximos, lado a lado.
		var world_position: Vector2 = box.global_position + config.get("offset", Vector2.ZERO)
		drop_parent.add_child(drop)
		drop.global_position = world_position
