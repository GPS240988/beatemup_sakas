extends SceneTree

var _map: Node = null
var _frame_count: int = 0

func _init() -> void:
	var scene = load("res://scenes/levels/map_4.tscn")
	if scene == null:
		print("ERRO: map_4.tscn nao carregou")
		quit(1)
		return
	_map = scene.instantiate()
	if _map == null:
		print("ERRO: map_4 nao instanciou")
		quit(1)
		return
	root.add_child(_map)

func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 3:
		return false  # continuar processando

	var enemies_node = _map.get_node_or_null("World/Actors/Enemies")
	if enemies_node == null:
		print("ERRO: nó Enemies não encontrado")
		_map.queue_free()
		quit(1)
		return true

	var all_ok := true
	for child in enemies_node.get_children():
		var arch: int = int(child.get("archetype"))
		var pal: int = int(child.get("palette_variant"))
		var sprite := child.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
		var has_mat: bool = sprite != null and sprite.material != null
		var palette_color_str := "N/A"
		var brightness := 0.0
		if has_mat and sprite.material is ShaderMaterial:
			var mat := sprite.material as ShaderMaterial
			var pc: Variant = mat.get_shader_parameter("palette_color")
			if pc != null:
				palette_color_str = str(pc)
			var ba: Variant = mat.get_shader_parameter("brightness_adjust")
			if ba != null:
				brightness = float(ba)
		print("%s  arch=%d  pal=%d  shader=%s  color=%s  bright=%.2f" % [
			child.name, arch, pal, str(has_mat), palette_color_str, brightness
		])
		if not has_mat:
			all_ok = false

	if all_ok:
		print("\n>> TODAS AS PALETAS APLICADAS COM SUCESSO <<")
	else:
		printerr("\n>> ALERTA: Nem todas as paletas foram aplicadas <<")
	_map.queue_free()
	quit(0 if all_ok else 1)
	return true
