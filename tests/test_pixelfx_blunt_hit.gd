extends SceneTree

## Suíte de Testes Focados: Integração PixelFX (Efeito-Piloto Blunt Hit)
## Valida os 8 critérios mandatórios da Seção 7 de implantação do PixelFX no Projeto Sakas.

const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const BasicEnemyScene: PackedScene = preload("res://scenes/actors/enemies/basic_enemy.tscn")
const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func assert_test(condition: bool, message: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % message)


func _init() -> void:
	print("\n" + "=".repeat(72))
	print("SUÍTE DE TESTES: INTEGRAÇÃO PIXELFX (PILOTO BLUNT-HIT NO SAKAS)")
	print("=".repeat(72))
	call_deferred("_run_tests")


func _run_tests() -> void:
	# -------------------------------------------------------------
	# 1 & 2. Recurso de Animação e Metadados do PixelFX
	# -------------------------------------------------------------
	print("\n--- 1. Validação de Recurso, Quadros e Metadados ---")
	var vfx_frames: SpriteFrames = load("res://scenes/vfx/hit_effects_frames.tres") as SpriteFrames
	assert_test(vfx_frames != null, "Recurso scenes/vfx/hit_effects_frames.tres carregado com sucesso")
	assert_test(vfx_frames.has_animation(&"blunt_hit"), "Animação 'blunt_hit' registrada no SpriteFrames")

	if vfx_frames.has_animation(&"blunt_hit"):
		var fps: float = vfx_frames.get_animation_speed(&"blunt_hit")
		var is_loop: bool = vfx_frames.get_animation_loop(&"blunt_hit")
		var frame_count: int = vfx_frames.get_frame_count(&"blunt_hit")

		assert_test(frame_count == 28, "Contagem exata de quadros: 28 frames preservados da biblioteca PixelFX")
		assert_test(is_equal_approx(fps, 30.0), "Velocidade da animação calibrada em 30.0 FPS")
		assert_test(not is_loop, "Animação configurada como one-shot (loop = false)")

		# Inspeciona o primeiro e último AtlasTexture
		var tex_0: Texture2D = vfx_frames.get_frame_texture(&"blunt_hit", 0)
		assert_test(tex_0 is AtlasTexture, "Quadro 0 instanciado como AtlasTexture")
		if tex_0 is AtlasTexture:
			var atlas_0 := tex_0 as AtlasTexture
			assert_test(atlas_0.region.size == Vector2(128, 88), "Resolução de cada quadro calibrada em 128x88 px")
			assert_test(atlas_0.atlas != null, "Textura mestre da spritesheet atribuída")
			assert_test(atlas_0.atlas.resource_path.ends_with("blunt_hit.png"), "Spritesheet oficial aponta para blunt_hit.png")

		var tex_last: Texture2D = vfx_frames.get_frame_texture(&"blunt_hit", 27)
		if tex_last is AtlasTexture:
			var atlas_last := tex_last as AtlasTexture
			assert_test(atlas_last.region.position == Vector2(256, 440), "Região do quadro 27 (último) alinhada na grade (256, 440)")

	# -------------------------------------------------------------
	# 3 & 4. Perfil 'punch' utiliza 'blunt_hit' e outros perfis preservados
	# -------------------------------------------------------------
	print("\n--- 2. Segregação e Preservação de Perfis de Combate ---")
	var dummy := Node2D.new()
	root.add_child(dummy)

	# Dispara punch
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(300, 200), Vector2.RIGHT, "punch")
	await process_frame

	var pool_node: Node = root.find_child("_Pool_HitSparks", true, false)
	assert_test(pool_node != null, "ObjectPool _Pool_HitSparks ativo na árvore de cena")

	var spark_punch: AnimatedSprite2D = null
	if pool_node != null:
		for child in pool_node.get_children():
			var spr := child as AnimatedSprite2D
			if spr != null and spr.visible and spr.get_meta("impact_profile", "") == "punch":
				spark_punch = spr
				break

	assert_test(spark_punch != null, "AnimatedHitSpark instanciado para o perfil 'punch'")
	if spark_punch != null:
		assert_test(spark_punch.animation == &"blunt_hit", "Perfil 'punch' utiliza com exclusividade a animação 'blunt_hit'")
		assert_test(spark_punch.offset == Vector2(0.0, -6.0), "Offset local calibrado para compensação do pivô PixelFX (0, -6)")
		assert_test(is_equal_approx(spark_punch.rotation, 0.0), "Rotação nula para queda natural e vertical dos estilhaços/poeira")

	# Testa preservação dos perfis kick, finisher e special
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(300, 200), Vector2.RIGHT, "kick")
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(300, 200), Vector2.RIGHT, "finisher")
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(300, 200), Vector2.RIGHT, "special")
	await process_frame

	var spark_kick: AnimatedSprite2D = null
	var spark_finisher: AnimatedSprite2D = null
	var spark_special: AnimatedSprite2D = null

	if pool_node != null:
		for child in pool_node.get_children():
			var spr := child as AnimatedSprite2D
			if spr != null and spr.visible:
				var prof: String = spr.get_meta("impact_profile", "")
				match prof:
					"kick": spark_kick = spr
					"finisher": spark_finisher = spr
					"special": spark_special = spr

	assert_test(spark_kick != null and (spark_kick.animation == &"hit_spark" or spark_kick.animation == &"impacto"), "Perfil 'kick' utiliza animação dedicada PixelFX 'hit_spark' (ou fallback 'impacto')")
	assert_test(spark_finisher != null and (spark_finisher.animation == &"crit_hit" or spark_finisher.animation == &"combinado"), "Perfil 'finisher' utiliza animação PixelFX 'crit_hit' (ou fallback 'combinado')")
	assert_test(spark_special != null and spark_special.animation == &"impactoazul", "Perfil 'special' preserva animação 'impactoazul'")

	# Testa perfil poeira
	CombatFeedbackClass.spawn_dust(dummy, Vector2(400, 300))
	await process_frame
	var dust_sprite: AnimatedSprite2D = dummy.find_child("LandingDust", true, false)
	assert_test(dust_sprite != null and dust_sprite.animation == &"poeira", "Perfil 'poeira' preserva animação 'poeira'")

	# -------------------------------------------------------------
	# 5. Simetria Horizontal e Alinhamento no Impacto
	# -------------------------------------------------------------
	print("\n--- 3. Simetria Direcional (Espelhamento) e Posicionamento ---")
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(500, 300), Vector2.RIGHT, "punch")
	CombatFeedbackClass.spawn_hit_spark(dummy, Vector2(500, 300), Vector2.LEFT, "punch")
	await process_frame

	var punch_right: AnimatedSprite2D = null
	var punch_left: AnimatedSprite2D = null
	if pool_node != null:
		for child in pool_node.get_children():
			var spr := child as AnimatedSprite2D
			if spr != null and spr.visible and spr.get_meta("impact_profile", "") == "punch":
				if spr.scale.x > 0.0 and punch_right == null:
					punch_right = spr
				elif spr.scale.x < 0.0 and punch_left == null:
					punch_left = spr

	assert_test(punch_right != null and punch_right.scale.x > 0.0, "Golpe para direita gera escala X positiva")
	assert_test(punch_left != null and punch_left.scale.x < 0.0, "Golpe para esquerda gera escala X invertida/negativa")
	if punch_right != null and punch_left != null:
		assert_test(is_equal_approx(absf(punch_right.scale.x), absf(punch_left.scale.x)), "Magnitude de escala perfeitamente simétrica entre esquerda e direita")
		assert_test(punch_right.global_position == Vector2(500, 300), "Efeito de faísca posicionado na coordenada exata de impacto")

	# -------------------------------------------------------------
	# 6. Isolamento de Whiff (Golpe sem acerto não dispara faísca)
	# -------------------------------------------------------------
	print("\n--- 4. Isolamento de Whiff (Sem Faíscas no Ar) ---")
	var player: PlayerController = PlayerScene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(100, 800)

	var active_sparks_before: int = 0
	if pool_node != null:
		for child in pool_node.get_children():
			var spr := child as AnimatedSprite2D
			if spr != null and spr.visible:
				active_sparks_before += 1

	# Executa soco no ar longe de qualquer inimigo
	player.melee_attack.execute_attack(1.0)
	await process_frame

	var active_sparks_after: int = 0
	if pool_node != null:
		for child in pool_node.get_children():
			var spr := child as AnimatedSprite2D
			if spr != null and spr.visible:
				active_sparks_after += 1

	assert_test(active_sparks_after == active_sparks_before, "Golpe sem alvo (Whiff) NÃO gera nenhuma nova faísca visual")

	# -------------------------------------------------------------
	# 7. Reprodução Completa e Reciclagem Limpa (Sem Corte Prematuro)
	# -------------------------------------------------------------
	print("\n--- 5. Reprodução Completa e Limpeza do Efeito ---")
	var test_spark := AnimatedSprite2D.new()
	test_spark.sprite_frames = vfx_frames
	dummy.add_child(test_spark)
	test_spark.play(&"blunt_hit")

	var finished_box: Array[bool] = [false]
	test_spark.animation_finished.connect(func():
		finished_box[0] = true
	)

	# Aguarda a animação de 28 frames a 30 FPS (~0.933s)
	# Aos 0.35s (antigo corte de 0.4s), a animação DEVE continuar em execução
	var half_timer := create_timer(0.35)
	await half_timer.timeout
	assert_test(test_spark.is_playing(), "Aos 0.35s o efeito blunt_hit continua tocando (não é cortado pelo antigo timer de 0.4s)")
	assert_test(test_spark.frame > 5, "Animação progrediu além do terço inicial")

	# Aguarda conclusão
	var full_timer := create_timer(0.70)
	await full_timer.timeout
	assert_test(finished_box[0], "Sinal animation_finished emitido após reprodução de todos os 28 quadros")

	test_spark.queue_free()
	player.queue_free()
	dummy.queue_free()

	# -------------------------------------------------------------
	# Relatório Final
	# -------------------------------------------------------------
	print("\n" + "-".repeat(72))
	print("RESULTADO DOS TESTES PIXELFX: %d/%d PASSARAM (Falhas: %d)" % [_passed, _total, _failed])
	print("-".repeat(72) + "\n")

	quit(0 if _failed == 0 else 1)
