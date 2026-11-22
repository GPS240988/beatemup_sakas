extends SceneTree

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	root.add_child(player)
	await process_frame
	var visual := player.get_node("Visual") as Node2D
	var shadow := player.get_node("Visual/Shadow") as CanvasItem
	var priority := player.get_node("AerialVisualPriorityComponent") as AerialVisualPriorityComponent
	var root_position: Vector2 = player.global_position
	player.set("_is_jumping", true)
	priority._physics_process(0.016)
	assert(visual.z_index == 1 and visual.z_as_relative, "Visual sobe para Z relativo 1 durante a voadora")
	assert(shadow.z_index == -1 and shadow.z_as_relative, "Sombra mantém Z efetivo de chão")
	assert(player.global_position == root_position, "Raiz física e pés permanecem imóveis")
	player.set("_is_jumping", false)
	priority._physics_process(0.016)
	assert(visual.z_index == 0 and shadow.z_index == 0, "Visual e sombra restauram Z de chão ao pousar")
	player.queue_free()
	await process_frame
	print("AerialVisualPriority: OK")
	quit(0)
