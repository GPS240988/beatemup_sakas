extends SceneTree

## Suíte focada do Chefe Alessandro, projétil de trufa e controles do jogador.

const BossAlessandroClass = preload("res://scripts/actors/boss_alessandro.gd")
const TruffleClass = preload("res://scripts/actors/projectiles/trufa.gd")
const BaseLevelClass = preload("res://scripts/levels/base_level.gd")
const PlayerControllerClass = preload("res://scripts/actors/player_controller.gd")
const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const BebadoEnemyClass = preload("res://scripts/actors/bebado_enemy.gd")
const EnemyAIClass = preload("res://scripts/actors/enemy_ai.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("==================================================")
	print("INICIANDO TESTES DO CHEFE ALESSANDRO")
	print("==================================================")

	test_boss_alessandro_scene_and_properties()
	test_truffle_projectile_contract()
	test_truffle_damage_is_single_hit()
	test_truffle_can_be_avoided_by_jump()
	test_boss_evasion_phase_one_probability_and_dialogue()
	test_boss_evasion_phase_two()
	test_healing_meat_contract_and_single_drop_logic()
	test_special_attack_knocks_down_alessandro()
	test_meat_chase_dialogue()
	test_truffle_barrage_spawns_three_projectiles()
	test_player_new_attack_controls()
	test_map1_no_boss_and_map4_boss_spawn()

	print("==================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")
	quit(0 if failed_tests == 0 else 1)


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _create_test_player(position: Vector2 = Vector2.ZERO, with_hurtbox: bool = false) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	player.name = "TestPlayer"
	player.add_to_group("player")
	player.collision_layer = 1
	player.collision_mask = 2
	player.global_position = position

	var health := HealthComponentClass.new() as HealthComponent
	health.name = "HealthComponent"
	health.max_health = 100.0
	player.add_child(health)

	if with_hurtbox:
		var hurtbox := Area2D.new()
		hurtbox.name = "Hurtbox"
		hurtbox.collision_layer = 4
		hurtbox.collision_mask = 0
		hurtbox.monitoring = false
		hurtbox.monitorable = true
		player.add_child(hurtbox)

	root.add_child(player)
	return player


func test_boss_alessandro_scene_and_properties() -> void:
	print("\n--- Propriedades do chefe ---")
	var scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	assert_test(scene != null, "Cena boss_alessandro.tscn carregada")
	if scene == null:
		return

	var boss := scene.instantiate() as BossAlessandroClass
	root.add_child(boss)
	assert_test(boss != null, "Instância BossAlessandro válida")
	assert_test(boss.health_component != null and is_equal_approx(boss.health_component.max_health, 900.0), "Chefe possui 900 HP")
	assert_test(boss.health_component != null and is_equal_approx(boss.health_component.current_health, 900.0), "Vida inicial também é configurada em 900 HP")
	assert_test(is_equal_approx(boss.TRUFFLE_COOLDOWN_PHASE_ONE, 4.25) and is_equal_approx(boss.TRUFFLE_COOLDOWN_PHASE_TWO, 4.25) and is_equal_approx(boss.TRUFFLE_INITIAL_COOLDOWN, 4.25), "Salvas de trufas respeitam cooldown de 4,25 segundos nas duas fases")
	assert_test(is_equal_approx(boss.EVADE_CHANCE_PHASE_ONE, 0.80) and is_equal_approx(boss.EVADE_CHANCE_PHASE_TWO, 0.50), "Chance de esquiva cai de 80% para 50% na segunda fase")
	assert_test(boss.anim_sprite != null, "AnimatedSprite2D do chefe existe")
	assert_test(boss.anim_sprite != null and boss.anim_sprite.material == null and boss.anim_sprite.modulate == Color.WHITE, "Alessandro preserva os sprites originais sem shader de paleta")

	var frames: SpriteFrames = boss.anim_sprite.sprite_frames if boss.anim_sprite != null else null
	assert_test(frames != null and frames.has_animation("walk"), "Animação walk presente")
	assert_test(frames != null and frames.has_animation("punch"), "Animação punch presente")
	assert_test(frames != null and frames.has_animation("kick"), "Animação kick presente")
	assert_test(frames != null and frames.has_animation("combo"), "Animação combo presente")
	assert_test(frames != null and frames.has_animation("jump_atk"), "Animação jump_atk presente")
	assert_test(frames != null and frames.has_animation("guard"), "Animação guard presente")
	assert_test(frames != null and frames.has_animation("hurt"), "Animação hurt presente")
	assert_test(frames != null and frames.has_animation("death"), "Animação death presente")

	assert_test(boss.collision_layer == 1, "Corpo físico do boss na Layer 1")
	assert_test(boss.collision_mask == 2, "Corpo físico do boss colide com Layer 2")
	var boss_hurtbox := boss.get_node_or_null("Hurtbox") as Area2D
	assert_test(boss_hurtbox != null and boss_hurtbox.collision_layer == 4, "Hurtbox do boss na Layer 3")
	assert_test(boss_hurtbox != null and boss_hurtbox.collision_mask == 0, "Hurtbox do boss com Mask 0")

	var boss_hitbox := boss.get_node_or_null("MeleeAttack/HitboxArea") as Area2D
	assert_test(boss_hitbox != null and boss_hitbox.collision_layer == 8, "Hitbox melee do boss na Layer 4")
	assert_test(boss_hitbox != null and boss_hitbox.collision_mask == 4, "Hitbox melee monitora Layer 3")
	assert_test(boss._special_behavior == BossAlessandroClass.SpecialBehavior.NONE, "Boss começa sem comportamento especial ativo")
	boss.free()


func test_truffle_projectile_contract() -> void:
	print("\n--- Cena e contrato da trufa ---")
	var scene: PackedScene = load("res://scenes/actors/projectiles/trufa.tscn") as PackedScene
	assert_test(scene != null, "Cena trufa.tscn carregada")
	if scene == null:
		return

	var truffle := scene.instantiate() as TruffleClass
	root.add_child(truffle)
	assert_test(truffle != null, "Instância AlessandroTruffle válida")
	assert_test(truffle.collision_layer == 0 and truffle.collision_mask == 2, "Corpo físico da trufa só interage com o mundo")
	assert_test(is_zero_approx(truffle.gravity_scale), "Trufa não sofre gravidade")
	assert_test(truffle.physics_material_override != null and is_equal_approx(truffle.physics_material_override.bounce, 0.9), "Material físico permite ricochete")
	assert_test(truffle.hitbox != null and truffle.hitbox.collision_layer == 8, "Hitbox da trufa usa Layer 4")
	assert_test(truffle.hitbox != null and truffle.hitbox.collision_mask == 4, "Hitbox da trufa detecta Hurtboxes na Layer 3")
	assert_test(truffle.hitbox != null and is_equal_approx(truffle.hitbox.position.y, -102.0), "Hitbox elevada acompanha o centro visual da trufa")
	assert_test(truffle.lifetime_timer != null and is_equal_approx(truffle.lifetime_timer.wait_time, 4.0), "Projétil expira após quatro segundos")
	var sprite := truffle.get_node_or_null("Sprite2D") as Sprite2D
	assert_test(sprite != null and sprite.texture != null and sprite.texture.resource_path.ends_with("trufa_alessandro.png"), "Sprite enviado está integrado à cena")
	truffle.free()


func test_truffle_damage_is_single_hit() -> void:
	print("\n--- Dano único da trufa ---")
	var player := _create_test_player(Vector2(200.0, 0.0), true)
	var truffle_scene: PackedScene = load("res://scenes/actors/projectiles/trufa.tscn") as PackedScene
	var truffle := truffle_scene.instantiate() as TruffleClass
	root.add_child(truffle)

	var health := player.get_node("HealthComponent") as HealthComponent
	var hurtbox := player.get_node("Hurtbox") as Area2D
	truffle._on_hitbox_area_entered(hurtbox)
	assert_test(is_equal_approx(health.current_health, 90.0), "Trufa aplica 10 de dano pelo DamageInfo")
	assert_test(truffle._has_hit, "Trufa marca o primeiro acerto")
	truffle._on_hitbox_area_entered(hurtbox)
	assert_test(is_equal_approx(health.current_health, 90.0), "Contato repetido não duplica dano")

	truffle.free()
	player.free()


func test_truffle_can_be_avoided_by_jump() -> void:
	print("\n--- Pulo evita trufa e exibe MISS ---")
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as PlayerControllerClass
	root.add_child(player)
	player._is_jumping = true
	var player_visual: Node2D = player.get_node_or_null("Visual") as Node2D
	if player_visual != null:
		player_visual.scale.x = -absf(player_visual.scale.x)
	var health: HealthComponent = player.get_node("HealthComponent") as HealthComponent
	var truffle_scene: PackedScene = load("res://scenes/actors/projectiles/trufa.tscn") as PackedScene
	var truffle := truffle_scene.instantiate() as TruffleClass
	root.add_child(truffle)
	var hurtbox: Area2D = player.get_node("Hurtbox") as Area2D
	truffle._on_hitbox_area_entered(hurtbox)
	assert_test(is_equal_approx(health.current_health, health.max_health), "Pulo no momento do contato evita todo o dano")
	assert_test(truffle._has_hit, "Trufa é consumida após a esquiva")
	var miss_feedback: Node2D = player.get_parent().get_node_or_null("TruffleMissFeedback") as Node2D
	var miss_label: Label = miss_feedback.get_node_or_null("Text") as Label if miss_feedback != null else null
	assert_test(miss_feedback != null and miss_feedback.top_level, "MISS usa camada Node2D independente da transformação dos atores")
	assert_test(miss_label != null and miss_label.text == "MISS", "Texto MISS aparece sobre o jogador ao escapar da trufa")
	assert_test(miss_feedback != null and miss_feedback.z_index >= 200, "MISS fica acima dos atores e dos efeitos de combate")
	truffle.free()
	if miss_feedback != null:
		miss_feedback.free()
	player.free()


func test_boss_evasion_phase_one_probability_and_dialogue() -> void:
	print("\n--- Esquiva da primeira fase e balão ---")
	var player := _create_test_player(Vector2(52.0, 6.0))
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var boss := boss_scene.instantiate() as BossAlessandroClass
	root.add_child(boss)
	boss.player_target = player
	assert_test(not boss._is_phase_two(), "Primeira fase permanece acima de 50% da vida")
	assert_test(is_equal_approx(boss._get_evasion_chance(), 0.80), "Primeira fase usa exatamente 80% de chance de esquiva")
	boss._start_evasion()
	assert_test(boss._evasion_direction.x < 0.0 and boss.facing_direction > 0.0, "Fuga recua e mantém o rosto voltado ao jogador")
	var bubble := boss.get_node_or_null("UruguayanMeatSpeechBubble") as PanelContainer
	var label := bubble.get_child(0) as Label if bubble != null else null
	assert_test(label != null and label.text == "Baila com el Uruga", "Balão apresenta a fala de esquiva")
	assert_test(bubble != null and bubble.position.y <= -330.0, "Balão fica acima da cabeça do Alessandro")
	boss.free()
	player.free()


func test_boss_evasion_phase_two() -> void:
	print("\n--- Esquiva e segunda fase ---")
	var player := _create_test_player(Vector2(52.0, 6.0))
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var boss := boss_scene.instantiate() as BossAlessandroClass
	root.add_child(boss)
	boss.player_target = player
	boss._evasion_cooldown = 0.0
	boss.health_component.current_health = 400.0

	assert_test(boss._is_phase_two(), "Segunda fase ativa abaixo de 50% da vida")
	assert_test(is_equal_approx(boss._get_evasion_chance(), 0.50), "Segunda fase usa 50% de chance de esquiva")
	assert_test(boss._can_start_evasion(), "Boss reconhece jogador no raio de esquiva")
	boss._start_evasion()
	assert_test(boss._special_behavior == BossAlessandroClass.SpecialBehavior.EVADING, "Boss entra no comportamento de fuga")
	assert_test(boss._evasion_direction.x < 0.0 and boss.facing_direction > 0.0, "Alessandro recua mas continua olhando para o jogador")
	var evasion_bubble := boss.get_node_or_null("UruguayanMeatSpeechBubble") as PanelContainer
	var evasion_label := evasion_bubble.get_child(0) as Label if evasion_bubble != null else null
	assert_test(evasion_label != null and evasion_label.text == "Baila com el Uruga", "Balão da esquiva apresenta a frase solicitada")
	assert_test(evasion_bubble != null and evasion_bubble.position.y <= -330.0, "Balão da esquiva fica acima da cabeça do chefe")
	boss._process_special_behavior(0.02)
	assert_test(absf(boss.velocity.x) >= 400.0, "Esquiva da segunda fase usa arrancada rápida")
	boss._process_special_behavior(1.0)
	assert_test(boss._special_behavior == BossAlessandroClass.SpecialBehavior.TRUFFLE_WINDUP, "Esquiva dispara imediatamente a preparação da salva de trufas")

	boss.free()
	player.free()


func test_healing_meat_contract_and_single_drop_logic() -> void:
	print("\n--- Carne uruguaia: drop único, perseguição e cura ---")
	var meat_scene: PackedScene = load("res://scenes/props/alessandro_meat.tscn") as PackedScene
	assert_test(meat_scene != null, "Cena da carne uruguaia carregada")
	if meat_scene == null:
		return
	var meat := meat_scene.instantiate() as DestructibleProp
	root.add_child(meat)
	assert_test(is_equal_approx(meat.max_health, 150.0), "Carne mantém 150 HP de resistência")
	assert_test(meat.get_script().resource_path.ends_with("alessandro_meat.gd"), "Carne usa script de drop piscante")
	var meat_sprite: Sprite2D = meat.get_node_or_null("Visual/Sprite2D") as Sprite2D
	assert_test(meat_sprite != null and meat_sprite.texture != null and is_equal_approx(meat_sprite.position.y, -meat_sprite.texture.get_size().y * absf(meat_sprite.scale.y) * 0.5), "Base do sprite da carne fica ancorada em Y=0")
	meat.free()

	var player := _create_test_player(Vector2(1100.0, 640.0))
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var boss := boss_scene.instantiate() as BossAlessandroClass
	root.add_child(boss)
	boss.player_target = player
	boss.global_position = Vector2(1500.0, 640.0)
	boss.health_component.current_health = 450.0
	boss._activate_healing_meat()
	assert_test(boss._meat_instances.size() == 1, "Fase de cura cria somente uma carne")
	if boss._meat_instances.size() == 1:
		var target: DestructibleProp = boss._meat_instances[0]
		assert_test(is_equal_approx(target.global_position.y, boss.global_position.y), "Origem da carne é posicionada no plano do chão do boss")
		var health_before_chase_hit: float = boss.health_component.current_health
		var chase_hit_accepted: bool = boss.take_damage(35.0)
		assert_test(not chase_hit_accepted, "Alessandro rejeita dano comum enquanto persegue a carne")
		var chase_special: RefCounted = DamageInfoClass.new(70.0, player, player.global_position, Vector2(-1.0, 0.0), "special", 180.0, 0.5, true, true, 0.08, "special", "upper_torso", boss.global_position + Vector2(0.0, -110.0))
		assert_test(not boss.take_damage(chase_special), "Alessandro também rejeita o Especial durante a perseguição")
		assert_test(is_equal_approx(boss.health_component.current_health, health_before_chase_hit), "Invulnerabilidade preserva o HP durante a perseguição")
		assert_test(boss._special_behavior == BossAlessandroClass.SpecialBehavior.MEAT_SEEKING, "Ataques não interrompem o estado de perseguição")
		boss.global_position = target.global_position + Vector2(220.0, 0.0)
		boss._process_meat_seeking(0.016)
		assert_test(boss.velocity.x < 0.0 or boss.velocity.x > 0.0, "Alessandro calcula movimento em direção à carne")
		boss.global_position = target.global_position + Vector2(100.0, 0.0)
		boss._process_meat_seeking(0.016)
		assert_test(boss._special_behavior == BossAlessandroClass.SpecialBehavior.MEAT_EATING, "Contato com a área física da carne inicia o consumo")
		assert_test(is_equal_approx(boss.health_component.current_health, 450.0), "A cura ainda não ocorre durante os 2,5s de consumo")
		boss._process_special_behavior(2.5)
		assert_test(target.is_queued_for_deletion(), "Carne desaparece depois dos 2,5s")
		assert_test(boss._speech_bubble != null and is_instance_valid(boss._speech_bubble), "Após a carne sumir, exibe balão com a fala uruguaia")
		if boss._speech_bubble != null:
			var speech_label: Label = boss._speech_bubble.get_child(0) as Label
			assert_test(speech_label != null and speech_label.text == "La verdadera picaña es la uruguaya", "Balão contém a frase correta")
		assert_test(is_equal_approx(boss.health_component.current_health, 450.0), "Cura aguarda a fala terminar")
		boss._process_special_behavior(2.8)
		assert_test(is_equal_approx(boss.health_component.current_health, 750.0), "Após a fala, Alessandro recupera 300 HP")
		assert_test(boss._special_behavior == BossAlessandroClass.SpecialBehavior.NONE, "Após comer, retorna ao combate padrão")
	boss.free()
	player.free()


func test_special_attack_knocks_down_alessandro() -> void:
	print("\n--- Especial derruba Alessandro e ele se levanta ---")
	var player := _create_test_player(Vector2(100.0, 640.0))
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var boss := boss_scene.instantiate() as BossAlessandroClass
	root.add_child(boss)
	boss.player_target = player

	var special_info: RefCounted = DamageInfoClass.new(70.0, player, player.global_position, Vector2(1.0, 0.0), "special", 180.0, 0.5, true, true, 0.08, "special", "upper_torso", boss.global_position + Vector2(0.0, -110.0))
	var accepted: bool = boss.take_damage(special_info)
	assert_test(accepted, "Especial consegue atingir Alessandro fora da perseguição da carne")
	assert_test(boss.current_state == EnemyAIClass.State.FALL, "Especial coloca Alessandro no estado FALL")
	assert_test(boss.anim_sprite != null and boss.anim_sprite.animation == &"fall", "Chefe reproduz a sequência de queda")
	assert_test(boss.visual_root != null and is_zero_approx(boss.visual_root.rotation_degrees) and is_zero_approx(boss.visual_root.position.y), "Queda mantém o visual alinhado ao chão")

	boss._process_fall(0.33)
	assert_test(boss.current_state == EnemyAIClass.State.DOWNED, "Após a projeção, Alessandro permanece caído")
	assert_test(boss.visual_root != null and is_zero_approx(boss.visual_root.rotation_degrees) and is_zero_approx(boss.visual_root.position.y), "Pose caída permanece alinhada ao chão")
	assert_test(boss.anim_sprite != null and boss.anim_sprite.animation == &"fall" and not boss.anim_sprite.is_playing(), "Pose deitado usa o último quadro da animação fall")
	boss._process_downed(0.36)
	assert_test(boss.current_state == EnemyAIClass.State.GETUP, "Após o tempo no chão, inicia GETUP")
	assert_test(boss.anim_sprite != null and boss.anim_sprite.animation == &"getup", "Alessandro reproduz a animação oficial de levantar")
	boss._process_getup(0.30)
	assert_test(boss.current_state == EnemyAIClass.State.FLANKING, "Depois de levantar, retorna à IA de combate")
	boss.free()
	player.free()


func test_truffle_barrage_spawns_three_projectiles() -> void:
	print("\n--- Salva de três trufas ---")
	var player := _create_test_player(Vector2(350.0, 0.0))
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var boss := boss_scene.instantiate() as BossAlessandroClass
	root.add_child(boss)
	boss.player_target = player

	boss._start_truffle_barrage()
	assert_test(boss._truffles_remaining == 3, "Preparação agenda três trufas")
	assert_test(is_equal_approx(boss.TRUFFLE_SPREAD_ANGLE, 0.58), "Trufas usam dispersão angular ampla")
	assert_test(is_equal_approx(TruffleClass.DAMAGE, 10.0), "Cada trufa causa 10 HP")
	assert_test(boss._special_behavior == BossAlessandroClass.SpecialBehavior.TRUFFLE_WINDUP, "Salva começa com telegraph")
	boss._process_special_behavior(0.42)
	boss._process_special_behavior(0.01)
	boss._process_special_behavior(0.18)
	boss._process_special_behavior(0.18)

	var spawned := get_nodes_in_group("alessandro_truffles")
	assert_test(spawned.size() == 3, "Três projéteis são instanciados na salva")
	assert_test(boss._special_behavior == BossAlessandroClass.SpecialBehavior.NONE, "Boss retorna à IA após a salva")

	for projectile: Node in spawned:
		if is_instance_valid(projectile):
			projectile.free()
	boss.free()
	player.free()



func test_meat_chase_dialogue() -> void:
	print("\n--- Fala durante perseguição da carne ---")
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	var boss := boss_scene.instantiate() as BossAlessandroClass
	root.add_child(boss)
	boss._show_meat_chase_dialogue()
	var bubble := boss.get_node_or_null("UruguayanMeatSpeechBubble") as PanelContainer
	var speech := bubble.get_child(0) as Label if bubble != null else null
	assert_test(speech != null and speech.text == "¡Uy, salió la carne jugosa!", "Alessandro fala a frase da carne durante a perseguição")
	boss.free()


func test_player_new_attack_controls() -> void:
	print("\n--- Controles de ataque do herói ---")
	var scene: PackedScene = load("res://scenes/actors/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerControllerClass
	root.add_child(player)

	assert_test(player != null, "Instância do Player válida")
	player._try_punch()
	assert_test(player.melee_attack.is_attacking, "Soco executado")
	assert_test(player._current_attack_anim == &"punch", "Animação de soco selecionada")
	player.melee_attack.cancel_attack()

	player._try_kick()
	assert_test(player.melee_attack.is_attacking, "Chute executado")
	assert_test(player._current_attack_anim == &"kick", "Animação de chute selecionada")
	player.melee_attack.cancel_attack()

	player._try_special()
	assert_test(player.melee_attack.is_attacking, "Especial executado")
	assert_test(player._current_attack_anim == &"heavy", "Animação do especial selecionada")
	player.melee_attack.cancel_attack()

	player._try_aerial_attack()
	assert_test(player._is_jumping, "Ataque aéreo ativa estado de salto")
	assert_test(player._current_attack_anim == &"jump_atk", "Animação de voadora selecionada")
	player.melee_attack.cancel_attack()
	player.free()


func test_map1_no_boss_and_map4_boss_spawn() -> void:
	print("\n--- Spawn do chefe no mapa 4 ---")
	var map1_scene: PackedScene = load("res://scenes/levels/map_1.tscn") as PackedScene
	var map1 := map1_scene.instantiate() as BaseLevelClass
	root.add_child(map1)
	assert_test(map1.boss_scene == null, "Mapa 1 não configura chefe")
	map1.free()

	var map4_scene: PackedScene = load("res://scenes/levels/map_4.tscn") as PackedScene
	var map4 := map4_scene.instantiate() as BaseLevelClass
	root.add_child(map4)
	var map_enemies: Node = map4.get_node("World/Actors/Enemies")
	var initial_enemies: Array[Node] = map_enemies.get_children()
	assert_test(initial_enemies.size() == 2, "Mapa 4 inicia somente com dois capangas")
	var tank_found: bool = false
	var drunk_found: bool = false
	for enemy: Node in initial_enemies:
		if enemy is EnemyAIClass and int((enemy as EnemyAIClass).archetype) == 2:
			tank_found = true
		if enemy is BebadoEnemyClass:
			drunk_found = true
	assert_test(tank_found, "Mapa 4 contém exatamente o perfil Tank")
	assert_test(drunk_found, "Mapa 4 contém um Bêbado Grunt")
	assert_test(not map4.reinforcement_waves_enabled, "Mapa 4 não agenda reforços extras")
	assert_test(map4.boss_scene != null, "Mapa 4 configura Alessandro como chefe")
	assert_test(not map4._boss_spawned, "Chefe não nasce antes da derrota dos capangas")
	assert_test(not map4.exit_area.monitoring, "Saída permanece bloqueada antes da luta")
	assert_test(map4.combat_director != null and map4.combat_director.pending_spawns_count == 1, "Chefe é registrado como spawn pendente")

	map4._on_encounter_cleared()
	assert_test(not map4.exit_area.monitoring, "Limpeza prematura do encontro é rejeitada")
	assert_test(not map4.siga_indicator.visible, "Indicador SIGA permanece oculto antes da vitória")

	map4.reinforcement_waves_enabled = false
	var dummy_enemy := CharacterBody2D.new()
	map4._on_enemy_defeated(dummy_enemy)
	assert_test(map4._boss_spawned, "Alessandro surge após derrota dos capangas")
	assert_test(map4._boss_instance != null, "Instância do chefe é criada")
	assert_test(map4.combat_director.pending_spawns_count == 0, "Contador de spawns pendentes é zerado")
	assert_test(not map4.exit_area.monitoring, "Saída segue bloqueada durante a luta")

	var map_player := map4.player
	if map_player != null:
		map_player.global_position.x = 1600.0
		map4._update_camera(1.0)
		assert_test(map4.camera.global_position.x >= 1340.0, "Câmera acompanha o jogador perto do boss")

	map4._on_encounter_cleared()
	assert_test(map4.exit_area.monitoring, "Saída é liberada após vitória")
	assert_test(map4.siga_indicator.visible, "Indicador SIGA aparece após vitória")
	dummy_enemy.free()
	map4.free()
