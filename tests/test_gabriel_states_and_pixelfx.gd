extends SceneTree

## Suíte de Testes Automatizada: Estados Visuais e PixelFX do Gabriel
## Valida SpriteFrames de locomoção, reação, defesa e integração de PixelFX (muzzle flash e bullet impact).

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	call_deferred("_run_all_tests")


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		print("  [FALHA] %s" % message)


func _run_all_tests() -> void:
	print("==================================================")
	print("INICIANDO TESTES: ESTADOS VISUAIS E PIXELFX GABRIEL")
	print("==================================================")

	_test_gabriel_state_sprite_frames()
	_test_gabriel_state_animations_playback()
	_test_pixelfx_frames_and_animations()
	_test_pixelfx_spawning_and_feedback()

	print("\n==================================================")
	print("RESULTADO DOS TESTES: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")

	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _ensure_game_session() -> Node:
	var session = root.get_node_or_null("GameSession")
	if session == null:
		var session_script = load("res://scripts/core/game_session.gd") as GDScript
		session = session_script.new()
		session.name = "GameSession"
		root.add_child(session)
	return session


func _test_gabriel_state_sprite_frames() -> void:
	print("\n--- 1. Validando SpriteFrames de Estados de Gabriel ---")
	var sf: SpriteFrames = load("res://resources/characters/gabriel_sprite_frames.tres") as SpriteFrames
	_assert(sf != null, "gabriel_sprite_frames.tres carregado com sucesso")
	
	_assert(sf.has_animation("idle"), "Animação 'idle' configurada")
	_assert(sf.get_frame_count("idle") == 1, "'idle' possui 1 quadro")
	_assert(sf.get_animation_loop("idle") == true, "'idle' está em loop")
	
	_assert(sf.has_animation("walk"), "Animação 'walk' configurada")
	_assert(sf.get_frame_count("walk") == 4, "'walk' possui exatamente 4 quadros (walk_01..04)")
	_assert(sf.get_animation_loop("walk") == true, "'walk' está em loop")
	_assert(is_equal_approx(sf.get_animation_speed("walk"), 8.0), "'walk' speed é 8.0 FPS")
	
	_assert(sf.has_animation("hurt"), "Animação 'hurt' configurada")
	_assert(sf.get_frame_count("hurt") == 2, "'hurt' possui exatamente 2 quadros (hurt_01..02)")
	_assert(sf.get_animation_loop("hurt") == false, "'hurt' loop = false")
	
	_assert(sf.has_animation("fall"), "Animação 'fall' configurada")
	_assert(sf.get_frame_count("fall") == 3, "'fall' possui exatamente 3 quadros (fall_01..03)")
	_assert(sf.get_animation_loop("fall") == false, "'fall' loop = false")
	
	_assert(sf.has_animation("getup"), "Animação 'getup' configurada")
	_assert(sf.get_frame_count("getup") == 2, "'getup' possui exatamente 2 quadros (getup_01..02)")
	_assert(sf.get_animation_loop("getup") == false, "'getup' loop = false")
	
	_assert(sf.has_animation("death"), "Animação 'death' configurada")
	_assert(sf.get_frame_count("death") == 1, "'death' possui 1 quadro (death_01)")
	_assert(sf.get_animation_loop("death") == false, "'death' loop = false")
	
	_assert(sf.has_animation("guard"), "Animação 'guard' configurada")
	_assert(sf.get_frame_count("guard") == 1, "'guard' possui 1 quadro (guard_01)")
	_assert(sf.get_animation_loop("guard") == true, "'guard' está em loop")


func _test_gabriel_state_animations_playback() -> void:
	print("\n--- 2. Validando Transições de Estados do Jogador ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"
	
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	
	var anim_sprite: AnimatedSprite2D = player.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_assert(anim_sprite != null, "AnimatedSprite2D presente")
	_assert(anim_sprite.sprite_frames != null, "SpriteFrames atribuído ao AnimatedSprite2D")
	
	# Estado Idle inicial
	_assert(anim_sprite.animation == &"idle", "Estado inicial toca 'idle'")
	
	# Transição Walk
	player._update_animation(&"walk")
	_assert(anim_sprite.animation == &"walk", "Transição para 'walk' bem-sucedida")
	
	# Transição Guard
	player._is_guarding = true
	player._update_animation(&"guard")
	_assert(anim_sprite.animation == &"guard", "Transição para 'guard' bem-sucedida")
	player._is_guarding = false
	player._update_animation(&"idle")
	_assert(anim_sprite.animation == &"idle", "Retorno de guard para 'idle'")
	
	# Transição Dano (Hurt)
	var dmg_info = load("res://scripts/combat/damage_info.gd").new(10.0, null, Vector2.ZERO, Vector2.RIGHT, "punch", 20.0, 0.20, false, false, 0.03)
	player.take_damage(dmg_info)
	_assert(anim_sprite.animation == &"hurt", "take_damage comum ativa animação 'hurt'")
	
	# Transição Queda (Fall / Knockdown)
	var kd_info = load("res://scripts/combat/damage_info.gd").new(20.0, null, Vector2.ZERO, Vector2.RIGHT, "heavy", 100.0, 0.40, false, true, 0.05)
	player.take_damage(kd_info)
	_assert(anim_sprite.animation == &"fall", "take_damage com knockdown ativa animação 'fall'")
	
	# Transição Getup
	player.combat_state = PlayerController.CombatState.DOWNED
	player._state_timer = 0.0
	player._physics_process(0.1)
	_assert(player.combat_state == PlayerController.CombatState.GETUP, "Transição de DOWNED para GETUP")
	_assert(anim_sprite.animation == &"getup", "Estado GETUP toca animação 'getup'")
	
	player.queue_free()


func _test_pixelfx_frames_and_animations() -> void:
	print("\n--- 3. Validando Recursos PixelFX em hit_effects_frames.tres ---")
	var vfx_frames: SpriteFrames = load("res://scenes/vfx/hit_effects_frames.tres") as SpriteFrames
	_assert(vfx_frames != null, "hit_effects_frames.tres carregado com sucesso")
	
	# Muzzle Pistol
	_assert(vfx_frames.has_animation("muzzle_pistol"), "Animação 'muzzle_pistol' presente no VFX SpriteFrames")
	_assert(vfx_frames.get_frame_count("muzzle_pistol") == 55, "'muzzle_pistol' possui todos os 55 quadros da sequência PixelFX")
	_assert(vfx_frames.get_animation_loop("muzzle_pistol") == false, "'muzzle_pistol' loop = false (disparo único)")
	_assert(is_equal_approx(vfx_frames.get_animation_speed("muzzle_pistol"), 30.0), "'muzzle_pistol' velocidade é 30 FPS")
	
	# Bullet Impact
	_assert(vfx_frames.has_animation("bullet_impact"), "Animação 'bullet_impact' presente no VFX SpriteFrames")
	_assert(vfx_frames.get_frame_count("bullet_impact") == 43, "'bullet_impact' possui todos os 43 quadros de impacto")
	_assert(vfx_frames.get_animation_loop("bullet_impact") == false, "'bullet_impact' loop = false")
	_assert(is_equal_approx(vfx_frames.get_animation_speed("bullet_impact"), 30.0), "'bullet_impact' velocidade é 30 FPS")


func _test_pixelfx_spawning_and_feedback() -> void:
	print("\n--- 4. Validando Emissão e Feedback de PixelFX ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"
	
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(300.0, 300.0)
	
	# Dispara muzzle flash
	var feedback = load("res://scripts/combat/combat_feedback.gd")
	var muzzle_spr: AnimatedSprite2D = feedback.spawn_muzzle_flash(player, player.global_position, Vector2.RIGHT)
	_assert(muzzle_spr != null, "Muzzle flash spawnado com sucesso na SceneTree")
	if muzzle_spr != null:
		_assert(muzzle_spr.animation == &"muzzle_pistol", "Muzzle flash está executando 'muzzle_pistol'")
		_assert(muzzle_spr.z_index == 55, "Muzzle flash possui z_index = 55 (em primeiro plano)")
	
	# Dispara bullet impact via spawn_hit_spark
	var spark_spr: AnimatedSprite2D = feedback.spawn_hit_spark(player, Vector2(350.0, 300.0), Vector2.RIGHT, "projectile", "upper_torso")
	_assert(spark_spr != null, "Hit spark de projétil spawnado com sucesso")
	if spark_spr != null:
		_assert(spark_spr.animation == &"bullet_impact", "Hit spark de projétil toca 'bullet_impact'")
	
	player.queue_free()
