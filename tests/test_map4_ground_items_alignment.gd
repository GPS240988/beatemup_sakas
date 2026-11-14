extends SceneTree

const Map4Scene: PackedScene = preload("res://scenes/levels/map_4.tscn")
const OvoPickupScript: Script = preload("res://scripts/items/ovo_pickup.gd")
const DadoContinuePickupScript: Script = preload("res://scripts/items/dado_continue_pickup.gd")
const DroppedItemVisualsScript: Script = preload("res://scripts/items/dropped_item_visuals.gd")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _assert(cond: bool, msg: String) -> void:
	_total += 1
	if cond:
		_passed += 1
		print("  [OK] %s" % msg)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % msg)


func _init() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	print("\n==================================================")
	print("TESTE: ALINHAMENTO DE CHÃO E PROFUNDIDADE (MAP_4)")
	print("==================================================")

	var map_instance: Node2D = Map4Scene.instantiate() as Node2D
	root.add_child(map_instance)
	await process_frame

	print("\n--- Teste 1: Localização e Coordenadas no map_4 ---")
	var ovo: OvoPickup = map_instance.find_child("OvoPickup", true, false) as OvoPickup
	var dado: DadoContinuePickup = map_instance.find_child("DadoContinuePickup", true, false) as DadoContinuePickup

	_assert(ovo != null, "OvoPickup encontrado no map_4")
	_assert(dado != null, "DadoContinuePickup encontrado no map_4")

	if ovo != null:
		_assert(ovo.position.x >= 400.0 and ovo.position.x <= 500.0, "Ovo posicionado em frente à casa (X: %.1f)" % ovo.position.x)
		_assert(ovo.position.y >= 545.0 and ovo.position.y <= 735.0, "Ovo posicionado em solo caminhável (Y: %.1f)" % ovo.position.y)

	if dado != null:
		_assert(is_equal_approx(dado.position.x, 982.0), "Dado alinhado no eixo X diretamente sob o Loro (X: %.1f)" % dado.position.x)
		_assert(dado.position.y >= 545.0 and dado.position.y <= 735.0, "Dado posicionado em solo caminhável (Y: %.1f)" % dado.position.y)

	print("\n--- Teste 2: Aterramento Pixel-Perfect (Sem Flutuação) ---")
	if ovo != null:
		var ovo_sprite: Sprite2D = ovo.get_node_or_null("Visual/Sprite") as Sprite2D
		_assert(ovo_sprite != null, "Ovo possui Sprite2D")
		if ovo_sprite != null:
			_assert(is_equal_approx(ovo_sprite.position.y, -56.5), "Base opaca do Ovo assenta com perfeição em Y=0 (offset: %.1f)" % ovo_sprite.position.y)

		var ovo_visuals: DroppedItemVisuals = ovo.get_node_or_null("DroppedItemVisuals") as DroppedItemVisuals
		_assert(ovo_visuals != null, "Ovo possui DroppedItemVisuals")
		if ovo_visuals != null:
			_assert(not ovo_visuals.enable_floating or is_zero_approx(ovo_visuals.float_amplitude), "Flutuação do Ovo desativada (item firme no solo)")
			var ovo_shadow: Polygon2D = ovo_visuals.get_node_or_null("GroundAnchor/GroundShadow") as Polygon2D
			_assert(ovo_shadow != null, "Ovo possui GroundShadow de solo")
			if ovo_shadow != null:
				_assert(ovo_visuals.shadow_radius.x >= 60.0, "Sombra do Ovo cobre a base adequadamente (raio X: %.1f)" % ovo_visuals.shadow_radius.x)

	if dado != null:
		var dado_sprite: Sprite2D = dado.get_node_or_null("Visual/Sprite") as Sprite2D
		_assert(dado_sprite != null, "Dado possui Sprite2D")
		if dado_sprite != null:
			_assert(is_equal_approx(dado_sprite.position.y, -68.0), "Base opaca do Dado assenta com perfeição em Y=0 (offset: %.1f)" % dado_sprite.position.y)

		var dado_visuals: DroppedItemVisuals = dado.get_node_or_null("DroppedItemVisuals") as DroppedItemVisuals
		_assert(dado_visuals != null, "Dado possui DroppedItemVisuals")
		if dado_visuals != null:
			_assert(not dado_visuals.enable_floating or is_zero_approx(dado_visuals.float_amplitude), "Flutuação do Dado desativada (item firme no solo)")
			var dado_shadow: Polygon2D = dado_visuals.get_node_or_null("GroundAnchor/GroundShadow") as Polygon2D
			_assert(dado_shadow != null, "Dado possui GroundShadow de solo")
			if dado_shadow != null:
				_assert(dado_visuals.shadow_radius.x >= 50.0, "Sombra do Dado cobre a base adequadamente (raio X: %.1f)" % dado_visuals.shadow_radius.x)

	print("\n--- Teste 3: Tolerância de Profundidade 2.5D ---")
	if ovo != null:
		_assert(ovo.pickup_depth_tolerance >= 40.0, "Ovo possui tolerância de profundidade confortável (>= 40.0: %.1f)" % ovo.pickup_depth_tolerance)
		_assert(ovo.pickup_range_x >= 68.0, "Ovo possui alcance X confortável (>= 68.0: %.1f)" % ovo.pickup_range_x)

	if dado != null:
		_assert(dado.pickup_depth_tolerance >= 40.0, "Dado possui tolerância de profundidade confortável (>= 40.0: %.1f)" % dado.pickup_depth_tolerance)
		_assert(dado.pickup_range_x >= 68.0, "Dado possui alcance X confortável (>= 68.0: %.1f)" % dado.pickup_range_x)

	print("\n==================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [_passed, _total, _failed])
	print("==================================================")

	map_instance.queue_free()
	await process_frame
	quit(0 if _failed == 0 else 1)
