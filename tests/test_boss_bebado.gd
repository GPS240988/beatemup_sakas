extends SceneTree

const BossBebadoClass = preload("res://scripts/actors/boss_bebado.gd")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	var boss_scene := load("res://scenes/actors/enemies/boss_bebado.tscn") as PackedScene
	_assert(boss_scene != null, "Cena boss_bebado.tscn deve carregar")
	if boss_scene == null:
		_finish()
		return

	var boss := boss_scene.instantiate() as CharacterBody2D
	_assert(boss != null, "Boss deve instanciar como CharacterBody2D")
	_assert(boss is BossBebadoClass, "Boss deve estender BossBebado")
	_assert(boss.is_in_group("enemies"), "Boss deve participar do grupo enemies")
	root.add_child(boss)
	await process_frame

	var visual := boss.get_node_or_null("Visual") as Node2D
	var sprite := boss.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	var shadow := boss.get_node_or_null("Shadow") as Polygon2D
	_assert(visual != null and is_equal_approx(visual.scale.x, 1.25), "Visual do boss deve ter escala 1.25")
	_assert(visual != null and is_equal_approx(visual.scale.y, 1.25), "Escala vertical deve preservar proporção")
	_assert(sprite != null and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Boss deve usar filtro NEAREST")
	_assert(sprite != null and sprite.sprite_frames == preload("res://scenes/actors/enemies/bebado_frames.tres"), "Boss deve reutilizar frames oficiais do Bêbado")
	_assert(shadow != null and shadow.get_parent() == boss, "Sombra deve permanecer ancorada no chão fora do Visual")
	_assert(boss.get_node_or_null("BossHUD") == null, "Boss não deve criar HUD próprio sobre a barra de vida")

	var boss_typed := boss as BossBebadoClass
	_assert(is_equal_approx(boss_typed.health_component.max_health, 420.0), "Vida base do boss deve ser 420")
	_assert(is_equal_approx(BossBebadoClass.FIRST_RECOVERY_RATIO, 0.78), "Primeira recuperação deve revelar a mecânica em 78% da vida")
	_assert(is_equal_approx(BossBebadoClass.FIRST_RECOVERY_HEAL, 65.0), "Primeira recuperação deve curar 65 HP")
	_assert(is_equal_approx(BossBebadoClass.PHASE_THREE_RATIO, 0.33), "Terceira fase deve começar em 33% da vida")
	_assert(is_equal_approx(BossBebadoClass.PHASE_THREE_PRESSURE_COOLDOWN, 2.75), "Terceira fase deve acelerar o contra-ataque")
	_assert(is_equal_approx(BossBebadoClass.PHASE_THREE_PRESSURE_RECOVERY, 0.62), "Terceira fase deve manter recuperação punível")
	_assert(is_equal_approx(BossBebadoClass.FIRST_RECOVERY_DURATION, 0.72), "Gole da recuperação obrigatória deve ser mais rápido")
	_assert(is_equal_approx(BossBebadoClass.AERIAL_EVASION_CHANCE, 0.55), "Voadora não deve causar dano garantido")
	_assert(is_equal_approx(BossBebadoClass.AERIAL_EVASION_COOLDOWN, 1.35), "Evasão da voadora deve possuir cooldown próprio")

	var boss_script: String = FileAccess.get_file_as_string("res://scripts/actors/boss_bebado.gd")
	_assert(boss_script.find('_play_anim("walk")') >= 0, "Recuperação deve usar walk durante a ida ao engradado")
	_assert(boss_script.find('damage_type in ["bottle", "bottle_projectile", "gas_bottle"]') >= 0, "Boss deve reconhecer o contrato atual da garrafa")
	_assert(boss_script.find('impact_profile in ["bottle", "glass_shatter"]') >= 0, "Boss deve reconhecer o perfil bottle do projétil")
	_assert(boss_script.find("BossHealFeedback") >= 0, "Recuperação deve exibir feedback visual de vida")
	_assert(boss_script.find('"+%d VIDA"') >= 0, "Feedback de recuperação deve exibir +X VIDA")

	boss_typed._finish_boss_intro()
	_assert(not boss_typed._intro_active, "Finalização da entrada deve liberar o combate")
	_assert(int(boss_typed._boss_mode) == int(BossBebadoClass.BossMode.NORMAL), "Entrada deve terminar no modo normal")

	# Teste da armadilha da garrafa usando o contrato real do projétil: bottle_projectile/bottle.
	var attacker := Node2D.new()
	attacker.name = "TestPlayer"
	attacker.add_to_group("player")
	root.add_child(attacker)
	boss_typed.health_component.current_health = 300.0
	var bottle_info := DamageInfoClass.new(
		26.0, attacker, attacker.global_position, Vector2.RIGHT,
		"bottle_projectile", 92.0, 0.28, true, false, 0.033, "bottle", "upper_torso", boss.global_position
	)
	var bottle_result: bool = boss_typed.take_damage(bottle_info)
	_assert(bottle_result, "Impacto da garrafa deve ser aceito como interação do boss")
	_assert(is_equal_approx(boss_typed.health_component.current_health, 365.0), "Garrafa deve recuperar 65 HP sem causar dano")

	var hit_info := DamageInfoClass.new(
		10.0, attacker, attacker.global_position, Vector2.RIGHT,
		"melee", 30.0, 0.20, true, false, 0.033, "punch", "upper_torso", boss.global_position
	)

	# Primeira recuperação: busca a garrafa e fica invulnerável desde a busca até o gole.
	var crate_near := Node2D.new()
	crate_near.name = "GasBottleCrateNear"
	crate_near.global_position = boss.global_position + Vector2(90.0, 0.0)
	crate_near.add_to_group("gas_bottle_crates")
	root.add_child(crate_near)
	boss_typed._boss_mode = BossBebadoClass.BossMode.NORMAL
	boss_typed._first_recovery_used = false
	boss_typed.health_component.current_health = 420.0
	boss_typed._start_first_recovery()
	_assert(boss_typed._recovery_bottle_target == crate_near, "Boss deve procurar o engradado de garrafas mais próximo")
	_assert(boss_typed._recovery_bottle_point.y > crate_near.global_position.y, "Ponto de bebida deve ficar na pista, abaixo do engradado")
	_assert(int(boss_typed._boss_mode) == int(BossBebadoClass.BossMode.FIRST_RECOVERY), "Busca/gole deve entrar no modo de recuperação")
	var recovery_hp: float = boss_typed.health_component.current_health
	var recovery_hit: bool = boss_typed.take_damage(hit_info)
	_assert(not recovery_hit, "Boss deve ser invulnerável durante busca/gole")
	_assert(is_equal_approx(boss_typed.health_component.current_health, recovery_hp), "Ataque não pode alterar HP durante busca/gole")
	crate_near.queue_free()

	# Teste anti-mash: dois golpes entram; o terceiro rápido é bloqueado e abre o breaker.
	boss_typed._boss_mode = BossBebadoClass.BossMode.NORMAL
	boss_typed._first_recovery_used = true
	boss_typed.dodge_chance = 0.0
	boss_typed.health_component.current_health = 300.0
	var hp_before: float = boss_typed.health_component.current_health
	var hit1: bool = boss_typed.take_damage(hit_info)
	var hit2: bool = boss_typed.take_damage(hit_info)
	var hit3: bool = boss_typed.take_damage(hit_info)
	_assert(hit1 and hit2, "Primeiros dois golpes do padrão rápido devem causar dano")
	_assert(not hit3, "Terceiro golpe rápido deve ser bloqueado para iniciar o contra-ataque")
	_assert(int(boss_typed._boss_mode) == int(BossBebadoClass.BossMode.PRESSURE_TELEGRAPH), "Terceiro golpe deve iniciar o ataque pesado cancelado")
	_assert(boss_typed.health_component.current_health >= hp_before - 25.0, "Anti-mash deve impedir troca cega de dano no terceiro golpe")

	# Terceira fase: a mesma leitura de três golpes permanece, mas a janela de pressão
	# fica mais rápida e a investida usa a posição atual do jogador, inclusive à distância.
	boss_typed._boss_mode = BossBebadoClass.BossMode.NORMAL
	boss_typed._first_recovery_used = true
	boss_typed._pressure_cooldown = 0.0
	boss_typed.health_component.current_health = 170.0
	_assert(boss_typed._is_phase_three(), "Boss deve reconhecer a terceira fase abaixo de 33%")
	boss_typed._pressure_hits = 0
	boss_typed._pressure_window_timer = 0.0
	var phase3_hit1: bool = boss_typed.take_damage(hit_info)
	var phase3_hit2: bool = boss_typed.take_damage(hit_info)
	var phase3_hit3: bool = boss_typed.take_damage(hit_info)
	_assert(phase3_hit1 and phase3_hit2, "Terceira fase ainda permite causar dano com golpes cadenciados")
	_assert(not phase3_hit3, "Terceira fase também bloqueia o terceiro golpe de spam")
	_assert(int(boss_typed._boss_mode) == int(BossBebadoClass.BossMode.PRESSURE_TELEGRAPH), "Terceira fase deve abrir a investida telegrafada")
	boss_typed._process_pressure_breaker(0.40)
	boss_typed._process_pressure_breaker(0.30)
	_assert(boss_typed._pressure_rush_velocity.length() > 0.9, "Investida da terceira fase deve possuir vetor físico definido")

	# Map 5: chefe configurado sem banner textual.
	var map5_scene := load("res://scenes/levels/map_5.tscn") as PackedScene
	_assert(map5_scene != null, "Map 5 deve carregar")
	if map5_scene != null:
		var map5 := map5_scene.instantiate()
		root.add_child(map5)
		await process_frame
		_assert(map5.get("boss_scene") == boss_scene, "Map 5 deve apontar para boss_bebado.tscn")
		_assert(str(map5.get("boss_announcement_text")) == "", "Map 5 não deve exibir mensagem textual do chefe")
		_assert(map5.get_node_or_null("BakeryVideoTrigger") != null, "Trigger da padaria deve existir")
		map5.queue_free()

	# Frentista: faixa curta e validação também dentro do método interact.
	var npc_scene := load("res://scenes/actors/frentista_npc.tscn") as PackedScene
	_assert(npc_scene != null, "Cena do Frentista deve carregar")
	if npc_scene != null:
		var npc := npc_scene.instantiate()
		root.add_child(npc)
		npc.global_position = Vector2(1000.0, 500.0)
		await process_frame
		var interaction_area := npc.get_node_or_null("InteractionArea") as Area2D
		var shape_node := npc.get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
		_assert(interaction_area != null, "Frentista deve ter InteractionArea")
		_assert(shape_node != null and shape_node.shape is RectangleShape2D, "InteractionArea deve usar retângulo")
		if shape_node != null and shape_node.shape is RectangleShape2D:
			var rect := shape_node.shape as RectangleShape2D
			_assert(is_equal_approx(rect.size.x, 116.0), "Faixa X do Frentista deve ser curta")
			_assert(is_equal_approx(rect.size.y, 56.0), "Faixa Y do Frentista deve ser curta")
		npc.queue_free()

	# O script de vídeo não deve possuir qualquer caminho de skip.
	var cutscene_file := FileAccess.open("res://scripts/events/map5_bakery_cutscene.gd", FileAccess.READ)
	_assert(cutscene_file != null, "Script da cutscene obrigatória deve existir")
	if cutscene_file != null:
		var cutscene_source := cutscene_file.get_as_text()
		_assert(not cutscene_source.contains("SkipPrompt"), "Cutscene não deve exibir prompt de skip")
		_assert(not cutscene_source.contains("func _input"), "Cutscene não deve interceptar input para pular")
		_assert(cutscene_source.contains("finished.connect"), "Cutscene deve terminar pelo sinal finished do vídeo")

	boss.queue_free()
	attacker.queue_free()
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % message)
	else:
		failed += 1
		printerr("  [FAIL] %s" % message)


func _finish() -> void:
	print("\nBOSS BÊBADO TESTS — PASSOU: %d | FALHOU: %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
