extends SceneTree

const SOURCE_SHEET_PATH: String = "res://assets/sprites/characters/inimigos/pizza_brawler/spritesheet_gorducho_vf.png"
const FRAMES_DIR: String = "res://assets/sprites/characters/inimigos/pizza_brawler/frames/"
const FRAMES_PATH: String = "res://scenes/actors/enemies/pizza_brawler_frames.tres"
const SCENE_PATH: String = "res://scenes/actors/enemies/pizza_brawler.tscn"
const MAP7_PATH: String = "res://scenes/levels/map_7.tscn"

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [OK] " + msg)
	else:
		_failed += 1
		push_error("  [FAIL] " + msg)


func _run() -> void:
	print("=== TESTE PIZZA BRAWLER (MAP 7 COMPLETO) ===")

	var src_tex := load(SOURCE_SHEET_PATH) as Texture2D
	_check(src_tex != null, "Spritesheet fonte spritesheet_gorducho_vf.png carrega")

	var expected_counts := {
		"sit_idle": 6,
		"counter_eat": 5,
		"getup": 6,
		"idle": 4,
		"walk": 6,
		"attack": 6,
		"heavy": 6,
		"punch": 6,
		"kick": 6,
		"guard": 2,
		"hurt": 4,
		"fall": 4,
		"downed": 1,
		"death": 4,
	}

	var idle1 := load(FRAMES_DIR + "idle_01.png") as Texture2D
	_check(idle1 != null, "Frame recortado idle_01.png carrega")
	if idle1 != null:
		_check(idle1.get_size() == Vector2(240, 220), "Canvas individual padronizado 240x220")
		var img := idle1.get_image()
		_check(img != null and img.detect_alpha() != Image.ALPHA_NONE, "Canal alfa transparente real presente nos frames")
		if img != null:
			_check(img.get_pixel(0, 0).a == 0.0, "Cantos externos transparentes")

	var frames := load(FRAMES_PATH) as SpriteFrames
	_check(frames != null, "SpriteFrames carrega em " + FRAMES_PATH)
	if frames != null:
		for anim_name in expected_counts.keys():
			_check(
				frames.has_animation(anim_name) and frames.get_frame_count(anim_name) == expected_counts[anim_name],
				"Animação '%s' com %d quadros" % [anim_name, expected_counts[anim_name]]
			)

	var brawler_scene := load(SCENE_PATH) as PackedScene
	_check(brawler_scene != null, "Cena pizza_brawler.tscn carrega")
	var map7_scene := load(MAP7_PATH) as PackedScene
	_check(map7_scene != null, "Map 7 carrega com elenco PizzaBrawler completo")

	if map7_scene != null:
		var map7 := map7_scene.instantiate()
		root.add_child(map7)
		await process_frame
		await physics_frame

		var enemies_container := map7.get_node_or_null("World/Actors/Enemies")
		var player := map7.get_node_or_null("World/Actors/Player") as CharacterBody2D
		var director := map7.get_node_or_null("CombatDirector")
		var expected_names := [
			"PizzaBrawler_RectLeft",
			"PizzaBrawler_RectRight",
			"PizzaBrawler_RoundLeft",
			"PizzaBrawler",
			"PizzaBrawler_Counter",
			"PizzaBrawler_CounterSide",
		]
		_check(enemies_container != null and enemies_container.get_child_count() == 6, "Map 7 possui exatamente 6 inimigos: quatro nas laterais das mesas e dois no balcão")
		_check(enemies_container.get_node_or_null("PizzaBrawler_RectBack") == null, "Inimigo central da mesa retangular removido")
		_check(enemies_container.get_node_or_null("PizzaBrawler_RoundBack") == null, "Inimigo central da mesa redonda removido")

		var archetypes_seen := {}
		var palettes_seen := {}
		for ename in expected_names:
			var node := enemies_container.get_node_or_null(ename) if enemies_container != null else null
			_check(node != null, "Instância presente em Enemies: " + ename)
			if node != null:
				archetypes_seen[int(node.archetype)] = true
				palettes_seen[int(node.palette_variant)] = true
				_check(director != null and director.alive_enemies.has(node), ename + " registrado no CombatDirector")

		_check(archetypes_seen.size() >= 3, "Diversidade de arquétipos preservada (%d distintos)" % archetypes_seen.size())
		_check(palettes_seen.size() >= 4, "Diversidade de paletas aplicada (%d distintas)" % palettes_seen.size())

		var brawler := map7.get_node_or_null("World/Actors/Enemies/PizzaBrawler")
		var counter_brawler := map7.get_node_or_null("World/Actors/Enemies/PizzaBrawler_Counter")
		var counter_side := map7.get_node_or_null("World/Actors/Enemies/PizzaBrawler_CounterSide")

		if counter_brawler != null:
			var counter_anim := counter_brawler.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
			_check(counter_brawler.is_counter_eating(), "Inimigo do balcão inicia em COUNTER_EATING")
			_check(counter_anim != null and counter_anim.animation == &"counter_eat", "Executa counter_eat de costas no balcão")
			if counter_anim != null:
				var counter_mat := counter_anim.material as ShaderMaterial
				_check(counter_mat != null, "ShaderMaterial de paleta aplicado ao inimigo do balcão")

		if counter_side != null and counter_brawler != null:
			var side_anim := counter_side.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
			_check(counter_side.has_method("is_in_ambient_standby") and counter_side.is_in_ambient_standby(), "Novo inimigo permanece em espera em pé antes da aproximação")
			_check(side_anim != null and side_anim.animation == &"idle", "Novo inimigo executa idle em pé ao lado do colega")
			_check(counter_side.global_position.distance_to(counter_brawler.global_position) <= 230.0, "Novo inimigo está posicionado junto ao funcionário de costas")

		if brawler != null:
			_check(brawler.is_in_group("actors") and brawler.is_in_group("enemies") and brawler.is_in_group("damageable"), "Grupos actors, enemies e damageable")
			var anim_sprite := brawler.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
			_check(anim_sprite != null and anim_sprite.position.y < 0.0, "Origem física nos pés (0, 0) com visual acima")
			_check(brawler.is_sitting(), "Inimigos laterais das mesas iniciam em SITTING")
			_check(anim_sprite != null and anim_sprite.animation == &"sit_idle", "Executa sit_idle enquanto aguarda sentado")

			var mat := anim_sprite.material as ShaderMaterial
			_check(mat != null, "ShaderMaterial exclusivo aplicado")
			if mat != null:
				_check(is_equal_approx(float(mat.get_shader_parameter("source_hue")), 0.0), "Shader mira camisa vermelha (source_hue = 0.0)")
				_check(float(mat.get_shader_parameter("oil_sheen_strength")) > 0.0, "Efeito de brilho oleoso na pele ativo no shader")

			var grease_drip := brawler.get_node_or_null("Visual/GreaseParticles") as CPUParticles2D
			var grease_burst := brawler.get_node_or_null("Visual/GreaseBurstParticles") as CPUParticles2D
			_check(grease_drip != null and grease_drip.emitting, "GreaseParticles ativo pingando gordura da pele")
			_check(grease_burst != null, "GreaseBurstParticles configurado para impactos e golpes")

			if player != null:
				player.global_position = brawler.global_position + Vector2(90, 0)
				await physics_frame
				await physics_frame
				_check(brawler.is_getting_up(), "Gatilho de aproximação inicia fase GETTING_UP")
				_check(anim_sprite.animation == &"getup", "Executa animação getup ao detectar jogador")

				for i in range(55):
					await physics_frame
				_check(brawler.is_in_combat(), "Transiciona para fase COMBAT (EnemyAI) após getup")
				_check(brawler.get_collision_mask_value(2), "Colisão sólida com Layer 2 reativada ao entrar em combate")

				if counter_brawler != null:
					player.global_position = counter_brawler.global_position + Vector2(0, 75)
					await physics_frame
					await physics_frame
					_check(counter_brawler.is_getting_up(), "Inimigo do balcão reage ao jogador se aproximar")
					for i in range(25):
						await physics_frame
					_check(counter_brawler.is_in_combat(), "Inimigo do balcão entra em COMBAT após virar")

				brawler.take_damage(20.0)
				await physics_frame
				_check(brawler.current_state == EnemyAI.State.HURT, "Recebe dano e entra em HURT")

				var kd_info := DamageInfo.new()
				kd_info.amount = 25.0
				kd_info.damage_type = "special"
				kd_info.can_knockdown = true
				kd_info.knockback_force = 180.0
				brawler.take_damage(kd_info)
				await physics_frame
				_check(brawler.current_state == EnemyAI.State.FALL, "Sofre knockdown e entra em FALL")

				for i in range(45):
					await physics_frame
				_check(
					brawler.current_state in [EnemyAI.State.DOWNED, EnemyAI.State.GETUP, EnemyAI.State.FLANKING],
					"Avança para DOWNED/GETUP após queda"
				)

				brawler.take_damage(999.0)
				await physics_frame
				_check(brawler.current_state == EnemyAI.State.DEAD, "Entra em estado DEAD ao zerar HP")
				_check(not grease_drip.emitting, "Para emissão de gordura após derrota")
				_check(director != null and not director.alive_enemies.has(brawler), "CombatDirector notificado da derrota")

		map7.queue_free()
		await process_frame

	print("RESULTADO PIZZA BRAWLER: %d passaram, %d falharam" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
