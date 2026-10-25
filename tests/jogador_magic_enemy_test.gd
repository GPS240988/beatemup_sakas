extends SceneTree

const BasicEnemyScene: PackedScene = preload("res://scenes/actors/enemies/basic_enemy.tscn")
const HitEffectsFrames: SpriteFrames = preload("res://scenes/vfx/hit_effects_frames.tres")

var passed: int = 0
var failed: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n==================================================")
	print("INICIANDO SUITE DE TESTES: INIMIGO JOGADOR DE MAGIC & VFX ARCADE")
	print("==================================================")

	# 1. Validação da Cena e SpriteFrames do Inimigo
	print("\n--- 1. Validando SpriteFrames e Visual do Jogador de Magic ---")
	var enemy := BasicEnemyScene.instantiate() as EnemyAI
	root.add_child(enemy)
	if enemy != null:
		print("  [OK] basic_enemy.tscn instanciada com sucesso")
		passed += 1
	else:
		printerr("  [FALHA] Falha ao instanciar basic_enemy.tscn")
		failed += 1
		quit(1)
		return

	var visual: Node2D = enemy.get_node_or_null("Visual")
	if visual != null:
		print("  [OK] Nó Visual existe")
		passed += 1
	else:
		printerr("  [FALHA] Nó Visual ausente")
		failed += 1

	var anim_sprite: AnimatedSprite2D = visual.get_node_or_null("AnimatedSprite2D")
	if anim_sprite != null and anim_sprite.sprite_frames != null:
		print("  [OK] AnimatedSprite2D com SpriteFrames configurado")
		passed += 1

		var required_anims := ["idle", "walk", "punch", "kick", "heavy", "guard", "hurt", "fall", "downed", "getup", "death", "jump_atk"]
		for anim: String in required_anims:
			if anim_sprite.sprite_frames.has_animation(anim):
				var frame_count: int = anim_sprite.sprite_frames.get_frame_count(anim)
				if frame_count > 0:
					print("  [OK] Animação '%s' existe (%d quadros)" % [anim, frame_count])
					passed += 1
				else:
					printerr("  [FALHA] Animação '%s' possui 0 quadros" % anim)
					failed += 1
			else:
				printerr("  [FALHA] Animação '%s' não encontrada no SpriteFrames" % anim)
				failed += 1
	else:
		printerr("  [FALHA] AnimatedSprite2D ausente ou sem sprite_frames")
		failed += 1

	# 2. Validação Anatômica e Física 2.5D (Pés no Y=0 e Colisões)
	print("\n--- 2. Validando Ancoragem 2.5D e Áreas de Colisão ---")
	if anim_sprite != null:
		var sprite_y: float = anim_sprite.position.y
		if sprite_y <= -80.0 and sprite_y >= -110.0:
			print("  [OK] Ancoragem vertical do sprite correta (pos_y = %.1f, pés assentados em Y=0)" % sprite_y)
			passed += 1
		else:
			printerr("  [FALHA] Ancoragem vertical suspeita: %.1f" % sprite_y)
			failed += 1

	var feet_col: CollisionShape2D = enemy.get_node_or_null("CollisionShape2D")
	if feet_col != null and feet_col.shape is CapsuleShape2D:
		print("  [OK] Colisão dos pés (cápsula 2.5D) configurada na base")
		passed += 1
	else:
		printerr("  [FALHA] Colisão dos pés inválida ou não é cápsula")
		failed += 1

	var hurtbox: Area2D = enemy.get_node_or_null("Hurtbox")
	if hurtbox != null and hurtbox.collision_layer == 4:
		print("  [OK] Hurtbox na camada correta (Layer 3 = bitmask 4)")
		passed += 1
	else:
		printerr("  [FALHA] Hurtbox não configurada ou camada incorreta")
		failed += 1

	var melee: MeleeAttack = enemy.get_node_or_null("MeleeAttack")
	if melee != null and melee.damage > 0.0:
		print("  [OK] MeleeAttack configurado com dano ofensivo: %.1f" % melee.damage)
		passed += 1
	else:
		printerr("  [FALHA] MeleeAttack ausente ou sem dano configurado")
		failed += 1

	# 3. Validação dos Efeitos de Impacto (VFX em Pixel Art HD)
	print("\n--- 3. Validando SpriteFrames de Efeitos de Impacto (assets/sprites/Efeitos) ---")
	if HitEffectsFrames != null:
		print("  [OK] hit_effects_frames.tres carregado com sucesso")
		passed += 1

		var vfx_list := {
			"impacto": 9,
			"impactoazul": 9,
			"combinado": 7,
			"estrelas": 7,
			"poeira": 6
		}
		for vfx_name: String in vfx_list.keys():
			var expected_count: int = vfx_list[vfx_name]
			if HitEffectsFrames.has_animation(vfx_name):
				var count: int = HitEffectsFrames.get_frame_count(vfx_name)
				if count == expected_count:
					print("  [OK] Efeito '%s' verificado com %d quadros" % [vfx_name, count])
					passed += 1
				else:
					printerr("  [FALHA] Efeito '%s' tem %d quadros (esperado: %d)" % [vfx_name, count, expected_count])
					failed += 1
			else:
				printerr("  [FALHA] Efeito '%s' não encontrado em hit_effects_frames.tres" % vfx_name)
				failed += 1
	else:
		printerr("  [FALHA] Não foi possível carregar hit_effects_frames.tres")
		failed += 1

	# 4. Teste de Execução de Feedback e Poeira
	print("\n--- 4. Testando Emissão de VFX (CombatFeedback) ---")
	var initial_children: int = enemy.get_child_count()
	CombatFeedback.spawn_hit_spark(enemy, Vector2(100, 100), Vector2.RIGHT, "punch")
	CombatFeedback.spawn_hit_spark(enemy, Vector2(150, 100), Vector2.RIGHT, "heavy")
	CombatFeedback.spawn_hit_spark(enemy, Vector2(200, 100), Vector2.RIGHT, "special")
	CombatFeedback.spawn_dust(enemy, Vector2(100, 150))

	var added_children: int = enemy.get_child_count() - initial_children
	if added_children >= 4:
		print("  [OK] CombatFeedback instanciou spriteshits e poeira com sucesso (nós adicionados=%d)" % added_children)
		passed += 1
	else:
		printerr("  [FALHA] Falha na emissão de VFX (filhos criados: %d)" % added_children)
		failed += 1

	# 5. Validação do Sistema de Palette Swap (Shader Hue Shift)
	print("\n--- 5. Validando Sistema de Palette Swap (Variantes Visuais) ---")
	var palette_enemy := BasicEnemyScene.instantiate() as EnemyAI
	palette_enemy.palette_variant = EnemyAI.PaletteVariant.RED
	root.add_child(palette_enemy)

	var p_sprite: AnimatedSprite2D = palette_enemy.get_node_or_null("Visual/AnimatedSprite2D")
	if p_sprite != null and p_sprite.material is ShaderMaterial:
		var p_mat := p_sprite.material as ShaderMaterial
		var shift_val: float = p_mat.get_shader_parameter("hue_shift")
		if is_equal_approx(shift_val, 140.0):
			print("  [OK] Variante RED aplicou ShaderMaterial com hue_shift = 140.0°")
			passed += 1
		else:
			printerr("  [FALHA] Variante RED com hue_shift incorreto: %.1f" % shift_val)
			failed += 1
	else:
		printerr("  [FALHA] Variante RED não aplicou ShaderMaterial")
		failed += 1

	# Teste de troca em runtime
	palette_enemy.set_palette(EnemyAI.PaletteVariant.GREEN)
	if p_sprite != null and p_sprite.material is ShaderMaterial:
		var g_mat := p_sprite.material as ShaderMaterial
		var g_shift: float = g_mat.get_shader_parameter("hue_shift")
		if is_equal_approx(g_shift, 260.0):
			print("  [OK] set_palette(GREEN) atualizou hue_shift para 260.0° em runtime")
			passed += 1
		else:
			printerr("  [FALHA] set_palette(GREEN) com hue_shift incorreto: %.1f" % g_shift)
			failed += 1
	else:
		printerr("  [FALHA] Material ausente após set_palette(GREEN)")
		failed += 1

	# Teste de retorno a ORIGINAL (sem shader / zero overhead)
	palette_enemy.set_palette(EnemyAI.PaletteVariant.ORIGINAL)
	if p_sprite != null and p_sprite.material == null:
		print("  [OK] set_palette(ORIGINAL) removeu material com sucesso (zero overhead)")
		passed += 1
	else:
		printerr("  [FALHA] set_palette(ORIGINAL) não resetou o material para null")
		failed += 1

	palette_enemy.queue_free()
	enemy.queue_free()

	print("\n==================================================")
	print("RESULTADO DOS TESTES: %d PASSARAM (Falhas: %d)" % [passed, failed])
	print("==================================================")

	if failed > 0:
		quit(1)
	else:
		quit(0)
