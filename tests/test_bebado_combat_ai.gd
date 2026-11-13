extends SceneTree

## Teste de Validação Técnica e de Combate: Inimigo Bêbado (Sakas Beat 'em Up)

const BebadoEnemyClass = preload("res://scripts/actors/bebado_enemy.gd")

var passed: int = 0
var failed: int = 0

func _init() -> void:
	print("\n========================================================")
	print(" TESTE: INIMIGO BÊBADO — COMBATE, IA, ESQUIVA E RASTEJO")
	print("========================================================")

	# 1. Carregamento e instanciação da cena
	var scn = load("res://scenes/actors/enemies/bebado_enemy.tscn") as PackedScene
	_assert(scn != null, "Cena bebado_enemy.tscn deve carregar sem erros")
	if scn == null:
		_finish_test()
		return

	var bebado = scn.instantiate() as CharacterBody2D
	_assert(bebado != null, "A cena deve instanciar como CharacterBody2D")
	_assert(bebado is BebadoEnemyClass, "BebadoEnemy deve estender EnemyAI")
	_assert(bebado.display_name == "O BÊBADO", "display_name deve ser 'O BÊBADO'")

	root.add_child(bebado)

	# 2. Verificação de grupos e contratos de nós
	_assert(bebado.is_in_group("actors"), "Deve estar no grupo 'actors'")
	_assert(bebado.is_in_group("enemies"), "Deve estar no grupo 'enemies'")
	_assert(bebado.is_in_group("damageable"), "Deve estar no grupo 'damageable'")

	var sprite: AnimatedSprite2D = bebado.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_assert(sprite != null, "AnimatedSprite2D deve existir")
	_assert(sprite.sprite_frames != null, "SpriteFrames deve existir")
	_assert(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Filtro deve ser NEAREST (Pixel Art HD)")
	_assert(sprite.position.y == -95.0, "Sprite deve estar posicionado em y=-95 (origem dos pés em y=0)")

	# 3. Verificação de animações obrigatórias (nomes reais do SpriteFrames do Bêbado)
	var required_anims = [
		"idle", "walk", "attack_jab", "attack_hook", "attack_punch",
		"dodge_duck", "dodge_backhop", "guard",
		"crawl_enter", "crawl", "prone",
		"hit_recoil", "knockdown", "getup", "drink", "lunge_pose"
	]
	for a in required_anims:
		_assert(sprite.sprite_frames.has_animation(a), "Animação '%s' deve existir" % a)

	# 4. Teste da Mecânica de Esquiva (DODGE)
	_assert(bebado.get("bebado_state") == 0, "Estado inicial deve ser NONE (0)")
	bebado.start_dodge()
	_assert(bebado.get("bebado_state") == 1, "start_dodge() deve transicionar para DODGING (1)")
	_assert(sprite.animation == &"dodge_duck", "Animação de esquiva deve ser 'dodge_duck'")
	_assert(bebado.velocity.length() > 0.0, "Esquiva deve conferir velocidade de deslocamento")

	# Simula passagem de tempo para encerrar esquiva
	bebado._process_bebado_dodge(0.40)
	_assert(bebado.get("bebado_state") == 0, "Ao término da esquiva, deve retornar para NONE (0)")
	_assert(bebado.get("_dodge_cooldown") > 0.0, "Cooldown de esquiva deve ser aplicado")

	# 5. Teste da Mecânica de Rastejamento (CRAWL)
	var hurtbox_shape = bebado.get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
	var default_h: float = (hurtbox_shape.shape as RectangleShape2D).size.y
	bebado.start_crawl()
	_assert(bebado.get("bebado_state") == 2, "start_crawl() deve transicionar para CRAWLING (2)")
	_assert(sprite.animation == &"crawl_enter", "Animação de rastejamento deve ser 'crawl_enter'")
	var crawl_h: float = (hurtbox_shape.shape as RectangleShape2D).size.y
	_assert(crawl_h < default_h, "Hurtbox deve ser rebaixada durante rastejamento (default=%.1f, crawl=%.1f)" % [default_h, crawl_h])

	# Simula passagem de tempo para encerrar rastejamento
	# Primeiro, finalize crawl_enter (0.35s) para entrar no crawl real
	bebado._process_bebado_crawl(0.36)
	# Agora finalize o crawl (restante do tempo)
	bebado._process_bebado_crawl(2.5)
	_assert(bebado.get("bebado_state") == 0, "Ao término do crawl, deve retornar para NONE (0)")
	var restored_h: float = (hurtbox_shape.shape as RectangleShape2D).size.y
	_assert(restored_h == default_h, "Hurtbox deve ser restaurada à altura original após rastejamento")
	_assert(sprite.animation == &"getup", "Deve tocar animação 'getup' ao se levantar")

	# 6. Teste da Ação de Beber (DRINK)
	bebado._ensure_internal_refs()
	bebado.health_component.current_health = 50.0
	bebado.start_drink()
	_assert(bebado.get("bebado_state") == 3, "start_drink() deve transicionar para DRINKING (3)")
	_assert(sprite.animation == &"drink", "Animação deve ser 'drink'")
	bebado._process_bebado_drink(1.2)
	_assert(bebado.get("bebado_state") == 0, "Ao terminar de beber, deve retornar para NONE (0)")
	_assert(bebado.health_component.current_health > 50.0, "Beber deve recuperar pontos de vida")

	# 7. Teste de Dano e Cancelamento de Estados Especiais
	bebado.start_crawl()
	_assert(bebado.get("bebado_state") == 2, "Em rastejamento ativo")
	bebado._on_damaged(10.0)
	_assert(bebado.get("bebado_state") == 0, "Sofrer dano deve cancelar o rastejamento imediatamente")
	_assert(bebado.current_state == EnemyAI.State.HURT, "Estado de combate deve ser HURT")

	# 8. Teste de Alternância de Ataques (nomes mapeados do Bêbado)
	bebado._attack_variant = 1
	bebado._trigger_attack()
	_assert(sprite.animation == &"attack_punch", "Ataque 2 (soco/garrafada) deve ser 'attack_punch'")
	bebado._trigger_attack()
	_assert(sprite.animation == &"lunge_pose", "Ataque 3 (chute) deve ser 'lunge_pose'")

	# 9. Teste de Integração com SpawnDirector
	var spawn_scn = SpawnDirector.get_enemy_scene("bebado")
	_assert(spawn_scn != null, "SpawnDirector.get_enemy_scene('bebado') deve retornar PackedScene válida")

	var sp_scn = load("res://scenes/spawning/spawn_point.tscn") as PackedScene
	if sp_scn != null:
		var sp = sp_scn.instantiate() as SpawnPoint
		root.add_child(sp)
		sp.enemy_type = "bebado"
		var spawned_entity = sp.spawn()
		_assert(spawned_entity != null, "SpawnPoint deve instanciar inimigo via enemy_type='bebado'")
		_assert(spawned_entity is BebadoEnemyClass, "Entidade instanciada deve ser BebadoEnemy")
		if spawned_entity != null:
			spawned_entity.queue_free()
		sp.queue_free()

	bebado.queue_free()
	_finish_test()


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % message)
	else:
		failed += 1
		printerr("  [FAIL] %s" % message)


func _finish_test() -> void:
	print("\n========================================================")
	print(" RESULTADOS DOS TESTES:")
	print("   Passaram: %d" % passed)
	print("   Falharam: %d" % failed)
	print("========================================================\n")

	if failed == 0:
		print(">> TODOS OS TESTES DO BÊBADO PASSARAM COM SUCESSO! <<\n")
		quit(0)
	else:
		printerr(">> HOUVE FALHAS NOS TESTES DO BÊBADO! <<\n")
		quit(1)
