extends SceneTree

func _init() -> void:
	print("\n========================================================")
	print(" TESTE: INIMIGO BÊBADO — INSTANCIAÇÃO E ANIMAÇÕES")
	print("========================================================")

	var scn = load("res://scenes/actors/enemies/bebado_enemy.tscn") as PackedScene
	assert(scn != null, "A cena bebado_enemy.tscn deve carregar sem erros")
	print("  [OK] Cena bebado_enemy.tscn carregada")

	var enemy = scn.instantiate() as CharacterBody2D
	assert(enemy != null, "A cena deve instanciar com sucesso")
	print("  [OK] Instanciado com sucesso")

	assert(enemy.display_name == "O BÊBADO", "Nome exibido deve ser 'O BÊBADO'")
	print("  [OK] Nome: ", enemy.display_name)

	var sprite = enemy.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	assert(sprite != null, "AnimatedSprite2D deve existir")
	assert(sprite.sprite_frames != null, "SpriteFrames deve estar associado")
	print("  [OK] AnimatedSprite2D e SpriteFrames validados")

	var required_anims = [
		"idle", "walk", "punch", "attack", "kick", "dodge", "guard",
		"crawl", "hit", "hurt", "fall", "knockdown", "downed", "getup", "get_up", "drink", "death"
	]
	for a in required_anims:
		assert(sprite.sprite_frames.has_animation(a), "Animação '" + a + "' deve existir no SpriteFrames")
		print("  [OK] Animação presente: ", a, " (frames=", sprite.sprite_frames.get_frame_count(a), ")")

	# Testa posição Y do sprite para comprovar alinhamento com a linha do solo (Y=0)
	assert(sprite.position.y == -95.0, "Sprite deve estar ancorado em y=-95 para manter os pés em y=0")
	print("  [OK] Posição vertical do sprite calibrada: ", sprite.position.y)

	enemy.queue_free()
	print("\n>> TESTE DE INSTANCIAÇÃO PASSOU COM SUCESSO! <<\n")
	quit(0)

