extends SceneTree

## Regressão focada: segundo drop do Alessandro, dica do Gabriel e identificação
## da voadora como ataque elegível para esquiva.

const BossAlessandroEnhancedClass = preload("res://scripts/actors/boss_alessandro_enhanced.gd")
const PlayerControllerClass = preload("res://scripts/actors/player_controller.gd")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")

var total_tests: int = 0
var failed_tests: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var test_world := Node2D.new()
	test_world.name = "TestMap4"
	root.add_child(test_world)
	current_scene = test_world

	var destructibles := Node2D.new()
	destructibles.name = "Destructibles"
	test_world.add_child(destructibles)

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn") as PackedScene
	var boss_scene: PackedScene = load("res://scenes/actors/enemies/boss_alessandro.tscn") as PackedScene
	_assert(player_scene != null and boss_scene != null, "Cenas do jogador e do Alessandro carregadas")
	if player_scene == null or boss_scene == null:
		quit(1)
		return

	var player := player_scene.instantiate() as PlayerControllerClass
	player.name = "TestPlayer"
	player.global_position = Vector2(1100.0, 640.0)
	test_world.add_child(player)

	var boss := boss_scene.instantiate() as BossAlessandroEnhancedClass
	boss.name = "BossAlessandroTest"
	boss.global_position = Vector2(1500.0, 640.0)
	boss.player_target = player
	test_world.add_child(boss)

	boss._activate_healing_meat()
	_assert(boss._meat_instances.size() == 1, "Primeiro evento gera uma única carne")
	_assert(boss._second_meat_timer < 0.0, "Temporizador da segunda carne ainda não inicia no drop")

	# O cronômetro só começa quando Alessandro conclui o consumo da primeira.
	var first_meat: DestructibleProp = boss._meat_instances[0]
	boss._meat_instances.erase(first_meat)
	first_meat.queue_free()
	boss._special_behavior = BossAlessandroEnhancedClass.SpecialBehavior.MEAT_EATING
	boss._show_meat_dialogue()
	_assert(is_equal_approx(boss._second_meat_timer, 8.0), "Contagem de 8 segundos começa quando a primeira carne é consumida")
	boss._finish_special_behavior()

	boss._process_second_meat_timer(7.99)
	_assert(boss._meat_instances.is_empty(), "Segunda carne não aparece antes de 8 segundos")
	boss._process_second_meat_timer(0.02)
	_assert(boss._meat_instances.size() == 1, "Segunda carne aparece ao completar 8 segundos")
	_assert(boss._second_meat_dropped, "O segundo drop ocorre somente uma vez")

	var hint := test_world.get_node_or_null("Map4MeatHintDialogue") as CanvasLayer
	_assert(hint != null, "Dica é exibida pela caixa oficial de diálogo do Mapa 4")
	if hint != null:
		var messages: Array = hint.get("_dialogues")
		_assert(messages.size() == 1, "Dica contém uma única fala")
		if messages.size() == 1:
			_assert(messages[0].get("speaker", "") == "GABRIEL", "Gabriel é identificado como orador")
			_assert(messages[0].get("text", "") == "Dica do mestre: Destrua a carne antes que o Alessandro se alimente.", "Texto da dica corresponde ao solicitado")
			var hint_portrait: Texture2D = messages[0].get("portrait") as Texture2D
			_assert(hint_portrait != null and hint_portrait.resource_path.ends_with("portrait_gabriel.png"), "Dica reutiliza o retrato herdado de Gabriel")
		_assert(bool(hint.get("_waiting_for_release")), "Dica aguarda confirmação/soltura do comando do jogador")

	# A IA deve selecionar a segunda carne após o drop.
	_assert(boss._special_behavior == BossAlessandroEnhancedClass.SpecialBehavior.MEAT_SEEKING, "Após o segundo drop, Alessandro persegue a carne")
	_assert(boss._meat_target == boss._meat_instances[0], "A segunda carne é selecionada como alvo")

	# A segunda refeição percorre o mesmo consumo e aplica novamente +300 HP.
	var second_meat: DestructibleProp = boss._meat_target
	boss.health_component.current_health = 500.0
	boss._begin_meat_eating()
	boss._process_special_behavior(2.5)
	_assert(second_meat.is_queued_for_deletion(), "Segunda carne desaparece ao concluir o consumo")
	boss._process_special_behavior(2.8)
	_assert(is_equal_approx(boss.health_component.current_health, 800.0), "Segunda refeição recupera mais 300 HP")

	# A voadora é reconhecida pela animação e pelo estado de salto do atacante.
	player._current_attack_anim = &"jump_atk"
	player._is_jumping = true
	var jumpkick_info: RefCounted = DamageInfoClass.new(
		35.0, player, player.global_position, Vector2(-1.0, 0.0),
		"melee", 70.0, 0.25, true, false, 0.05,
		"kick", "upper_torso", boss.global_position + Vector2(0.0, -110.0)
	)
	_assert(boss._is_player_melee_damage(jumpkick_info), "Voadora do jogador é reconhecida como ataque corpo a corpo")
	_assert(is_equal_approx(boss.PLAYER_MELEE_EVADE_CHANCE, 0.70), "Ataques corpo a corpo têm 70% de chance de esquiva")
	player._current_attack_anim = &"kick"
	_assert(boss._is_player_melee_damage(jumpkick_info), "Chute comum também é classificado como ataque corpo a corpo")

	boss._post_evasion_counter_timer = 0.75
	player.global_position = boss.global_position + Vector2(-80.0, 0.0)
	player.velocity = Vector2(260.0, 0.0)
	_assert(boss._is_fast_player_approach(), "Avanço rápido do jogador é identificado para o contra-ataque garantido")
	boss._evasion_cooldown = 0.0
	var health_before_counter: float = boss.health_component.current_health
	boss.take_damage(jumpkick_info)
	_assert(boss.health_component.current_health < health_before_counter, "Golpe rápido durante a janela pós-esquiva acerta sem nova evasão")
	boss._evasion_direction = Vector2(1.0, 0.0)
	boss.global_position.x = 1915.0
	boss._process_evasion(0.01)
	_assert(boss._evasion_direction.x < 0.0, "Esquiva inverte a direção ao alcançar o limite direito do mapa")

	boss.free()
	player.free()
	test_world.free()
	print("RESULTADO: %d testes, %d falhas" % [total_tests, failed_tests])
	quit(0 if failed_tests == 0 else 1)


func _assert(condition: bool, description: String) -> void:
	total_tests += 1
	if condition:
		print("[OK] ", description)
	else:
		failed_tests += 1
		printerr("[FALHA] ", description)
