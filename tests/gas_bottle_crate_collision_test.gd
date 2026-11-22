extends SceneTree

const CrateScene: PackedScene = preload("res://scenes/items/gas_bottle_crate.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var crate := CrateScene.instantiate() as Node2D
	root.add_child(crate)
	await process_frame
	var body := crate.get_node_or_null("SolidBody") as StaticBody2D
	assert(body != null, "Engradado tem corpo físico independente")
	assert(body.collision_layer == 2 and body.collision_mask == 1, "Colisor usa World Solid Layer 2 e Actor Mask 1")
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert(shape_node != null and shape_node.shape is RectangleShape2D, "Colisor sólido retangular")
	assert((shape_node.shape as RectangleShape2D).size == Vector2(76, 52), "Dimensão do colisor validada")
	assert(shape_node.position == Vector2(0, -26), "Colisor centrado no volume inferior sem alterar a âncora Y-Sort")
	var pickup := crate.get_node_or_null("PickupArea") as Area2D
	assert(pickup != null and pickup.collision_layer == 0 and pickup.collision_mask == 1, "Área de coleta continua separada do corpo sólido")
	crate.queue_free()
	await process_frame
	print("GasBottleCrateCollision: OK")
	quit(0)
