extends SceneTree

const GabrielGunVFXClass = preload("res://scripts/combat/gabriel_gun_vfx.gd")
const PlayerBulletScene: PackedScene = preload("res://scenes/actors/projectiles/player_bullet.tscn")
const VFXFrames: SpriteFrames = preload("res://scenes/vfx/gabriel_gun_vfx_frames.tres")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("==================================================")
	print("GABRIEL — TESTE DE INTEGRACAO DOS VFX BALISTICOS")
	print("==================================================")

	_test_animation_resources()
	await _test_projectile_visual_and_collision_contract()
	await _test_muzzle_and_impact_spawning()

	print("==================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")
	quit(0 if failed_tests == 0 else 1)


func _assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _test_animation_resources() -> void:
	_assert_test(VFXFrames.has_animation(&"muzzle_core"), "Animação muzzle_core disponível")
	_assert_test(VFXFrames.has_animation(&"bullet_impact"), "Animação bullet_impact disponível")
	_assert_test(VFXFrames.get_frame_count(&"muzzle_core") == 4, "Núcleo de disparo contém 4 quadros")
	_assert_test(VFXFrames.get_frame_count(&"bullet_impact") == 8, "Impacto balístico contém 8 quadros")
	_assert_test(is_equal_approx(VFXFrames.get_animation_speed(&"muzzle_core"), 30.0), "Núcleo de disparo roda a 30 FPS")
	_assert_test(is_equal_approx(VFXFrames.get_animation_speed(&"bullet_impact"), 30.0), "Impacto roda a 30 FPS")

	var muzzle_frame: Texture2D = VFXFrames.get_frame_texture(&"muzzle_core", 0)
	var impact_frame: Texture2D = VFXFrames.get_frame_texture(&"bullet_impact", 0)
	_assert_test(muzzle_frame != null and muzzle_frame.get_width() == 48 and muzzle_frame.get_height() == 48, "Atlas do clarão usa células 48×48")
	_assert_test(impact_frame != null and impact_frame.get_width() == 96 and impact_frame.get_height() == 96, "Atlas do impacto usa células 96×96")


func _test_projectile_visual_and_collision_contract() -> void:
	var bullet: PlayerBullet = PlayerBulletScene.instantiate() as PlayerBullet
	_assert_test(bullet != null, "Cena PlayerBullet instancia sem erro")
	if bullet == null:
		return

	bullet.direction = Vector2.LEFT
	root.add_child(bullet)
	await process_frame

	var sprite: Sprite2D = bullet.get_node_or_null("Sprite2D") as Sprite2D
	_assert_test(sprite != null, "Sprite de projétil presente")
	if sprite != null:
		_assert_test(sprite.hframes == 4 and sprite.vframes == 1, "Projétil usa spritesheet horizontal 4×1")
		_assert_test(sprite.texture != null and sprite.texture.get_width() == 320 and sprite.texture.get_height() == 32, "Projétil usa textura 320×32")
		_assert_test(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Projétil preserva filtro nearest")
		_assert_test(is_equal_approx(sprite.offset.x, -30.0), "Ponta luminosa fica alinhada ao centro de colisão")

	var shape: CollisionShape2D = bullet.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rect: RectangleShape2D = shape.shape as RectangleShape2D if shape != null else null
	_assert_test(rect != null and rect.size == Vector2(28.0, 16.0), "Hitbox física original de 28×16 permanece intacta")
	_assert_test(bullet.collision_layer == 8 and bullet.collision_mask == 6, "Layers de colisão originais permanecem intactas")
	_assert_test(is_equal_approx(bullet.speed, 700.0) and is_equal_approx(bullet.max_range, 280.0), "Velocidade e alcance balístico permanecem intactos")

	bullet.queue_free()
	await process_frame
	await create_timer(0.20, true, false, true).timeout


func _test_muzzle_and_impact_spawning() -> void:
	var bullet: PlayerBullet = PlayerBulletScene.instantiate() as PlayerBullet
	if bullet == null:
		_assert_test(false, "Projétil disponível para teste de VFX")
		return

	bullet.direction = Vector2.LEFT
	root.add_child(bullet)
	await process_frame

	var muzzle: AnimatedSprite2D = root.find_child("GabrielMuzzleCore", true, false) as AnimatedSprite2D
	_assert_test(muzzle != null, "Núcleo do clarão nasce no disparo")
	if muzzle != null:
		_assert_test(muzzle.animation == &"muzzle_core", "Clarão executa a animação dedicada")
		_assert_test(muzzle.flip_h, "Clarão espelha corretamente para disparos à esquerda")

	var impact: AnimatedSprite2D = GabrielGunVFXClass.spawn_bullet_impact(
		bullet,
		Vector2(320.0, 240.0),
		Vector2.LEFT,
		true
	)
	_assert_test(impact != null, "Impacto dedicado instancia sem erro")
	if impact != null:
		_assert_test(impact.animation == &"bullet_impact", "Impacto executa a animação balística dedicada")
		_assert_test(impact.flip_h, "Impacto espelha corretamente para disparos à esquerda")
		_assert_test(is_equal_approx(impact.scale.x, 1.10), "Impacto pesado recebe escala reforçada")

	bullet.queue_free()
	await process_frame
