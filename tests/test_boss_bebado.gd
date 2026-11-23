extends SceneTree

const BossBebadoClass = preload("res://scripts/actors/boss_bebado.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_bebado.tscn") as PackedScene
	_assert(boss_scene != null, "BossBebado.tscn deve carregar")
	if boss_scene == null:
		_finish()
		return

	var boss: CharacterBody2D = boss_scene.instantiate() as CharacterBody2D
	_assert(boss != null, "Boss deve instanciar como CharacterBody2D")
	_assert(boss is BossBebadoClass, "Boss deve usar BossBebado")
	_assert(boss.is_in_group("enemies"), "Boss deve permanecer no grupo enemies")

	root.add_child(boss)

	var visual_root: Node2D = boss.get_node_or_null("Visual") as Node2D
	var sprite: AnimatedSprite2D = boss.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_assert(visual_root != null, "Visual root deve existir")
	_assert(sprite != null, "AnimatedSprite2D deve existir")
	_assert(sprite != null and sprite.sprite_frames == preload("res://scenes/actors/enemies/bebado_frames.tres"), "Boss deve reutilizar os frames oficiais")
	_assert(visual_root != null and is_equal_approx(visual_root.scale.x, 1.25), "Boss deve ter presença visual 25% maior")
	_assert(visual_root != null and is_equal_approx(visual_root.scale.y, 1.25), "Escala vertical deve preservar a mesma proporção")
	_assert(boss.get_node_or_null("BossHUD") == null, "Boss não deve criar HUD de vida no topo")

	var boss_typed: BossBebado = boss as BossBebado
	_assert(is_equal_approx(BossBebadoClass.BASE_HEALTH, 540.0), "Vida base do boss deve ser 540")
	_assert(is_equal_approx(BossBebadoClass.DRINK_HEAL_AMOUNT, 65.0), "Recuperação única deve curar 65 HP")
	_assert(is_equal_approx(BossBebadoClass.INTRO_DROP_HEIGHT, 250.0), "Entrada do boss deve partir 250px acima do chão")
	_assert(is_equal_approx(BossBebadoClass.INTRO_FALL_SECONDS, 0.92), "Queda do boss deve ser deliberadamente lenta para leitura visual")
	_assert(is_equal_approx(BossBebadoClass.BOTTLE_HEAL_AMOUNT, 65.0), "Garrafa deve recuperar 65 HP do Bêbado")
	_assert(is_equal_approx(BossBebadoClass.COUNTER_HIT_THRESHOLD, 3), "Contra-ataque deve reagir a 3 golpes rápidos")
	_assert(is_equal_approx(BossBebadoClass.BOSS_VISUAL_SCALE, 1.25), "Constante de escala visual deve ser 1.25")

	var cutscene_script := FileAccess.get_file_as_string("res://scripts/events/map5_bakery_cutscene.gd")
	_assert(cutscene_script.find("func _input") == -1, "Vídeo da padaria não pode possuir caminho de skip por input")
	_assert(cutscene_script.find("PRESSIONE ESPAÇO") == -1, "Vídeo da padaria não deve exibir prompt de pulo")

	var map5_scene: PackedScene = load("res://scenes/levels/map_5.tscn") as PackedScene
	_assert(map5_scene != null, "Map 5 deve carregar")
	if map5_scene != null:
		var map5: Node = map5_scene.instantiate()
		_assert(map5 != null, "Map 5 deve instanciar")
		if map5 != null:
			root.add_child(map5)
			_assert(map5.get("boss_scene") == boss_scene, "Map 5 deve apontar para BossBebado")
			_assert(map5.get_node_or_null("BakeryVideoTrigger") != null, "Trigger da padaria deve existir")
			_assert(str(map5.get("boss_announcement_text")) == "", "Map 5 não deve anunciar o boss por texto")
			var attendant: Node = map5.get_node_or_null("World/Actors/NPCs/Frentista")
			_assert(attendant != null, "Frentista do posto deve existir")
			if attendant != null:
				var interaction_shape: CollisionShape2D = attendant.get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
				_assert(interaction_shape != null, "Frentista deve possuir área de interação")
				if interaction_shape != null and interaction_shape.shape is RectangleShape2D:
					_assert((interaction_shape.shape as RectangleShape2D).size == Vector2(72.0, 40.0), "Área do frentista deve ser de proximidade real")
			map5.queue_free()

	boss.queue_free()
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("[OK] %s" % message)
	else:
		failed += 1
		printerr("[FAIL] %s" % message)


func _finish() -> void:
	print("BOSS BÊBADO TESTS — PASSOU: %d | FALHOU: %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
