extends SceneTree

const BossAlessandroClass = preload("res://scripts/actors/boss_alessandro.gd")
const BossAlessandroEnhancedClass = preload("res://scripts/actors/boss_alessandro_enhanced.gd")
const DestructiblePropClass = preload("res://scripts/props/destructible_prop.gd")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const EnemyAIClass = preload("res://scripts/actors/enemy_ai.gd")

var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("========================================================")
	print("TESTE: AJUSTES DA LUTA CONTRA ALESSANDRO (MAPA 4)")
	print("========================================================")

	var world := Node2D.new()
	world.name = "TestWorld"
	root.add_child(world)
	current_scene = world

	var destructibles_container := Node2D.new()
	destructibles_container.name = "Destructibles"
	world.add_child(destructibles_container)

	test_1_first_meat_cannot_be_destroyed(world, destructibles_container)
	test_2_evasion_chance_remains_80_percent(world)
	test_3_truffles_frequency_increased(world)
	test_4_speech_bubble_and_font_enlarged(world)

	world.queue_free()

	print("========================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [_pass_count, _pass_count + _fail_count, _fail_count])
	print("========================================================")

	if _fail_count > 0:
		quit(1)
	else:
		quit(0)


func _assert(condition: bool, description: String) -> void:
	if condition:
		_pass_count += 1
		print("  [OK] %s" % description)
	else:
		_fail_count += 1
		printerr("  [FALHA] %s" % description)


func test_1_first_meat_cannot_be_destroyed(world: Node2D, destructibles: Node2D) -> void:
	print("\n--- Teste 1: Primeira Carne Indestrutível e Consumo Desimpedido ---")
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn")
	var boss: BossAlessandroClass = boss_scene.instantiate() as BossAlessandroClass
	world.add_child(boss)
	boss.global_position = Vector2(800.0, 600.0)

	# Dispara o primeiro drop de carne
	boss._activate_healing_meat()
	_assert(boss._meat_instances.size() == 1, "Primeiro evento de cura instancia uma carne")

	var first_meat: DestructibleProp = boss._meat_instances[0]
	_assert(first_meat != null and is_instance_valid(first_meat), "Instância da primeira carne é válida")
	_assert(not first_meat.is_destructible, "Primeira carne possui is_destructible = false")
	_assert(not first_meat.is_in_group("destructibles"), "Primeira carne removida do grupo destructibles")
	_assert(not first_meat.is_in_group("damageable"), "Primeira carne removida do grupo damageable")

	if first_meat.hurtbox != null:
		_assert(not first_meat.hurtbox.monitorable, "Hurtbox da primeira carne tem monitorable desabilitado")
		_assert(first_meat.hurtbox.collision_layer == 0, "Hurtbox da primeira carne tem collision_layer zerada")

	# Tenta causar dano direto à carne
	var damage_accepted: bool = first_meat.take_damage(100.0)
	_assert(not damage_accepted, "Primeira carne rejeita qualquer chamada de dano direto")
	_assert(not first_meat.is_prop_destroyed(), "Primeira carne não pode ser destruída por dano comum")

	# Tenta causar dano através de DamageInfo (Especial / Melee)
	var special_damage: RefCounted = DamageInfoClass.new(
		150.0, null, Vector2.ZERO, Vector2.RIGHT, "special", 50.0, 0.2, true
	)
	var special_accepted: bool = first_meat.take_damage(special_damage)
	_assert(not special_accepted, "Primeira carne rejeita dano de golpe Especial")
	_assert(not first_meat.is_prop_destroyed(), "Primeira carne permanece intacta contra golpe Especial")

	# Simula Alessandro andando até a carne e consumindo-a
	_assert(boss._special_behavior == BossAlessandroClass.SpecialBehavior.MEAT_SEEKING, "Alessandro entra em MEAT_SEEKING")
	_assert(not boss.take_damage(50.0), "Alessandro é invulnerável durante a perseguição à carne")

	# Posiciona Alessandro sobre a carne para testar chegada
	boss.global_position = first_meat.global_position
	boss._process_meat_seeking(0.016)
	_assert(boss._special_behavior == BossAlessandroClass.SpecialBehavior.MEAT_EATING, "Alessandro inicia o consumo da carne ao alcançá-la")

	# Durante o consumo, a primeira carne não pode ser destruída
	boss._process_meat_eating(0.5)
	_assert(boss._special_behavior == BossAlessandroClass.SpecialBehavior.MEAT_EATING, "Alessandro continua comendo desimpedido")

	# Conclui consumo (2.5s)
	boss._process_meat_eating(2.0)
	_assert(first_meat.is_queued_for_deletion(), "Carne é liberada após conclusão dos 2,5s de consumo")
	_assert(boss._meat_dialogue_started, "Fala uruguaia é iniciada após o consumo")

	# Limpa instâncias
	boss.queue_free()


func test_2_evasion_chance_remains_80_percent(world: Node2D) -> void:
	print("\n--- Teste 2: Probabilidade de Esquiva Continua em 80% com Menos de 50% de HP ---")
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn")
	var boss: BossAlessandroClass = boss_scene.instantiate() as BossAlessandroClass
	world.add_child(boss)

	# Constantes base
	_assert(is_equal_approx(boss.EVADE_CHANCE_PHASE_ONE, 0.80), "Constante EVADE_CHANCE_PHASE_ONE é 0.80 (80%)")
	_assert(is_equal_approx(boss.EVADE_CHANCE_PHASE_TWO, 0.80), "Constante EVADE_CHANCE_PHASE_TWO é 0.80 (80%)")

	# Fase 1: HP cheio (900 HP)
	boss.health_component.current_health = 900.0
	_assert(not boss._is_phase_two(), "Alessandro está na Fase 1 com HP > 50%")
	_assert(is_equal_approx(boss._get_evasion_chance(), 0.80), "Chance de esquiva na Fase 1 é 80%")

	# Fase 2: HP menor que 50% (ex: 350 HP)
	boss.health_component.current_health = 350.0
	_assert(boss._is_phase_two(), "Alessandro está na Fase 2 com HP <= 50%")
	_assert(is_equal_approx(boss._get_evasion_chance(), 0.80), "Chance de esquiva na Fase 2 CONTINUA em 80%")

	# Verificação na classe enhanced
	if boss is BossAlessandroEnhancedClass:
		_assert(is_equal_approx(boss.PLAYER_MELEE_EVADE_CHANCE, 0.80), "PLAYER_MELEE_EVADE_CHANCE na classe enhanced é 80%")

	boss.queue_free()


func test_3_truffles_frequency_increased(world: Node2D) -> void:
	print("\n--- Teste 3: Frequência Aumentada de Disparo de Trufas ---")
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn")
	var boss: BossAlessandroClass = boss_scene.instantiate() as BossAlessandroClass
	world.add_child(boss)

	# Cooldowns reduzidos
	_assert(boss.TRUFFLE_INITIAL_COOLDOWN <= 2.0, "Cooldown inicial de trufas reduzido para <= 2.0s")
	_assert(boss.TRUFFLE_COOLDOWN_PHASE_ONE <= 2.0, "Cooldown de trufas na Fase 1 reduzido para <= 2.0s")
	_assert(boss.TRUFFLE_COOLDOWN_PHASE_TWO <= 1.8, "Cooldown de trufas na Fase 2 reduzido para <= 1.8s")
	_assert(boss.CLOSE_TRUFFLE_CHANCE >= 0.65, "Probabilidade de disparo a curta distância aumentada para >= 65%")

	# Simula disparo e recarga acelerada
	boss._special_behavior = BossAlessandroClass.SpecialBehavior.NONE
	boss._truffle_cooldown = 0.0
	_assert(boss._truffle_cooldown <= 0.0, "Trufas prontas para disparo com cooldown zerado")

	# Finalização de salva recarrega com cooldown reduzido
	boss._special_behavior = BossAlessandroClass.SpecialBehavior.THROWING_TRUFFLES
	boss._finish_special_behavior()
	_assert(boss._truffle_cooldown <= 2.0, "Após salva, cooldown de trufas é <= 2.0s")

	boss.queue_free()


func test_4_speech_bubble_and_font_enlarged(world: Node2D) -> void:
	print("\n--- Teste 4: Balão de Fala e Fonte Maiores para Melhor Visualização ---")
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn")
	var boss: BossAlessandroClass = boss_scene.instantiate() as BossAlessandroClass
	world.add_child(boss)

	# Exibe balão de fala
	var test_text: String = "La verdadera picaña es la uruguaya"
	boss._show_speech_bubble(test_text, 5.0)

	var bubble := boss.get_node_or_null("UruguayanMeatSpeechBubble") as PanelContainer
	_assert(bubble != null and is_instance_valid(bubble), "Painel do balão de fala instanciado")

	if bubble != null:
		# Tamanho do balão ampliado
		_assert(bubble.custom_minimum_size.x >= 500.0, "Largura mínima do balão ampliada para >= 500px: %.1f" % bubble.custom_minimum_size.x)
		_assert(bubble.custom_minimum_size.y >= 80.0, "Altura mínima do balão ampliada para >= 80px: %.1f" % bubble.custom_minimum_size.y)
		_assert(bubble.position.y <= -350.0, "Balão elevado confortavelmente acima da cabeça: %.1f" % bubble.position.y)

		# Margens internas
		var panel_style: StyleBoxFlat = bubble.get_theme_stylebox("panel") as StyleBoxFlat
		_assert(panel_style != null, "StyleBoxFlat do balão configurado")
		if panel_style != null:
			_assert(panel_style.content_margin_left >= 20.0, "Margem interna horizontal ampliada (>= 20px): %.1f" % panel_style.content_margin_left)
			_assert(panel_style.content_margin_top >= 10.0, "Margem interna vertical ampliada (>= 10px): %.1f" % panel_style.content_margin_top)
			_assert(panel_style.border_width_left >= 4, "Borda do balão bem definida para estilo arcade")

		# Label e Fonte
		var label: Label = bubble.get_child(0) as Label
		_assert(label != null, "Label com o texto do diálogo existe")
		if label != null:
			_assert(label.text == test_text, "Texto do diálogo confere: '%s'" % label.text)
			var font_size: int = label.get_theme_font_size("font_size")
			_assert(font_size >= 20, "Tamanho da fonte arcade ampliado para >= 20px: %dpx" % font_size)

	boss.queue_free()
