extends SceneTree

## Suíte de Testes Automatizados: Integração Expandida PixelFX no Sakas (Soco, Chute e Finalizador)
## Valida o conjunto completo de efeitos PixelFX (blunt_hit, hit_spark, crit_hit) e a preservação de impactoazul.

const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")
const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const BasicEnemyScene: PackedScene = preload("res://scenes/actors/enemies/basic_enemy.tscn")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func assert_test(cond: bool, msg: String) -> void:
	_total += 1
	if cond:
		_passed += 1
		print("  [OK] %s" % msg)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % msg)


func _init() -> void:
	print("\n" + "=".repeat(75))
	print("SUÍTE DE TESTES: CONJUNTO EXPANDIDO PIXELFX NO COMBATE SAKAS")
	print("=".repeat(75))
	call_deferred("_run_suite")


func _run_suite() -> void:
	# -------------------------------------------------------------
	# 1. Validação dos Recursos SpriteFrames
	# -------------------------------------------------------------
	print("\n--- 1. Validação de Registro dos Recursos PixelFX ---")
	var vfx_frames: SpriteFrames = load("res://scenes/vfx/hit_effects_frames.tres") as SpriteFrames
	assert_test(vfx_frames != null, "Recurso scenes/vfx/hit_effects_frames.tres carregado")

	# blunt_hit (punch)
	assert_test(vfx_frames.has_animation(&"blunt_hit"), "Animação 'blunt_hit' (soco) registrada")
	assert_test(vfx_frames.get_frame_count(&"blunt_hit") == 28, "blunt_hit possui 28 frames")
	assert_test(is_equal_approx(vfx_frames.get_animation_speed(&"blunt_hit"), 30.0), "blunt_hit calibrado a 30.0 FPS")

	# hit_spark (kick)
	assert_test(vfx_frames.has_animation(&"hit_spark"), "Animação 'hit_spark' (chute) registrada")
	assert_test(vfx_frames.get_frame_count(&"hit_spark") == 16, "hit_spark possui 16 frames")
	assert_test(is_equal_approx(vfx_frames.get_animation_speed(&"hit_spark"), 30.0), "hit_spark calibrado a 30.0 FPS")

	# crit_hit (finisher / heavy)
	assert_test(vfx_frames.has_animation(&"crit_hit"), "Animação 'crit_hit' (finalizador) registrada")
	assert_test(vfx_frames.get_frame_count(&"crit_hit") == 28, "crit_hit possui 28 frames")
	assert_test(is_equal_approx(vfx_frames.get_animation_speed(&"crit_hit"), 30.0), "crit_hit calibrado a 30.0 FPS")

	# special (impactoazul)
	assert_test(vfx_frames.has_animation(&"impactoazul"), "Animação 'impactoazul' (especial) preservada")

	# -------------------------------------------------------------
	# 2. Instanciação Dinâmica via ObjectPool por Perfil de Combate
	# -------------------------------------------------------------
	print("\n--- 2. Instanciação e Associação por Perfil de Combate ---")
	var dummy := Node2D.new()
	root.add_child(dummy)

	# Punch -> blunt_hit
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(100, 200), Vector2.RIGHT, "punch")
	# Kick -> hit_spark
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(200, 200), Vector2.RIGHT, "kick")
	# Finisher -> crit_hit
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(300, 200), Vector2.RIGHT, "finisher")
	# Special -> impactoazul
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(400, 200), Vector2.RIGHT, "special")
	await process_frame

	var pool_node: Node = root.find_child("_Pool_HitSparks", true, false)
	assert_test(pool_node != null, "ObjectPool _Pool_HitSparks ativo na cena")

	var found_punch: AnimatedSprite2D = null
	var found_kick: AnimatedSprite2D = null
	var found_finisher: AnimatedSprite2D = null
	var found_special: AnimatedSprite2D = null

	if pool_node != null:
		for child in pool_node.get_children():
			var spr := child as AnimatedSprite2D
			if spr != null and spr.visible:
				match spr.get_meta("impact_profile", ""):
					"punch": found_punch = spr
					"kick": found_kick = spr
					"finisher": found_finisher = spr
					"special": found_special = spr

	assert_test(found_punch != null and found_punch.animation == &"blunt_hit", "Perfil 'punch' executa PixelFX 'blunt_hit'")
	assert_test(found_kick != null and found_kick.animation == &"hit_spark", "Perfil 'kick' executa PixelFX 'hit_spark'")
	assert_test(found_finisher != null and found_finisher.animation == &"crit_hit", "Perfil 'finisher' executa PixelFX 'crit_hit'")
	assert_test(found_special != null and found_special.animation == &"impactoazul", "Perfil 'special' executa 'impactoazul' preservado")

	# -------------------------------------------------------------
	# 3. Simetria e Alinhamento Perfeito de Pivô (Zero Offset Drift)
	# -------------------------------------------------------------
	print("\n--- 3. Simetria e Alinhamento de Pivô (Offset Zero) ---")
	if found_kick != null:
		assert_test(found_kick.offset == Vector2.ZERO, "hit_spark possui offset Vector2.ZERO (centro geométrico exato [68, 40])")
		assert_test(is_equal_approx(found_kick.scale.x, 1.05), "hit_spark escala calibrada em 1.05x")

	if found_finisher != null:
		assert_test(found_finisher.offset == Vector2.ZERO, "crit_hit possui offset Vector2.ZERO (centro geométrico exato [108, 68])")
		assert_test(is_equal_approx(found_finisher.scale.x, 0.95), "crit_hit escala calibrada em 0.95x")

	# Testa espelhamento invertido para golpe à esquerda
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(500, 200), Vector2.LEFT, "kick")
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(600, 200), Vector2.LEFT, "finisher")
	await process_frame

	var kick_left: AnimatedSprite2D = null
	var fin_left: AnimatedSprite2D = null
	if pool_node != null:
		for child in pool_node.get_children():
			var spr := child as AnimatedSprite2D
			if spr != null and spr.visible:
				if spr.get_meta("impact_profile", "") == "kick" and spr.scale.x < 0.0:
					kick_left = spr
				elif spr.get_meta("impact_profile", "") == "finisher" and spr.scale.x < 0.0:
					fin_left = spr

	assert_test(kick_left != null and kick_left.scale.x < 0.0, "hit_spark espelhado com escala X negativa para golpe à esquerda")
	assert_test(fin_left != null and fin_left.scale.x < 0.0, "crit_hit espelhado com escala X negativa para golpe à esquerda")
	if kick_left != null:
		assert_test(kick_left.offset == Vector2.ZERO, "hit_spark mantém offset zero sem desvio no espelhamento")
	if fin_left != null:
		assert_test(fin_left.offset == Vector2.ZERO, "crit_hit mantém offset zero sem desvio no espelhamento")

	dummy.queue_free()

	print("\n" + "=".repeat(75))
	print("RESULTADO DOS TESTES PIXELFX EXPANDIDOS: %d/%d PASSARAM (Falhas: %d)" % [_passed, _total, _failed])
	print("=".repeat(75) + "\n")

	quit(0 if _failed == 0 else 1)

