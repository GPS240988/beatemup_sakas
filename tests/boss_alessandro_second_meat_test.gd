extends SceneTree

## Regressão focada: segundo drop do Alessandro, dica do Gabriel e identificação
## da voadora como ataque elegível para esquiva.

const BossAlessandroEnhancedClass = preload("res://scripts/actors/boss_alessandro_enhanced.gd")
const PlayerControllerClass = preload("res://scripts/actors/player_controller.gd")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const EnemyAIClass = preload("res://scripts/actors/enemy_ai.gd")
const MeatScene: PackedScene = preload("res://scenes/props/alessandro_meat.tscn")

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

	var loro_anchor := Node2D.new()
	loro_anchor.name = "LoroAnchor"
	loro_anchor.position = Vector2(982.0, 421.0)
	test_world.add_child(loro_anchor)
	var loro_sprite := AnimatedSprite2D.new()
	loro_sprite.name = "loro"
	loro_anchor.add_child(loro_sprite)

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
	_assert(not boss._meat_instances.is_empty() and boss.global_position.distance_to(boss._meat_instances[0].global_position) >= 1000.0, "Segunda carne surge no extremo oposto, longe de Alessandro")
	_assert(boss._loro_intro_hold and get_tree().paused, "A fase pausa assim que a segunda carne cai, mantendo Alessandro parado")
	_assert(test_world.get_node_or_null("Map4LoroTarget") != null, "Alvo de combate invisível do Loro é criado no Mapa 4")
	var loro_target := test_world.get_node_or_null("Map4LoroTarget") as Map4LoroTarget
	_assert(loro_target != null and not loro_target.is_in_group("enemies"), "Loro permanece fora do grupo de inimigos do encontro")
	_assert(loro_target != null and loro_target.is_in_group("map4_loro_target"), "Loro usa grupo exclusivo para evento de combate")
	if loro_target != null:
		loro_target._connect_player_attacks()
		var loro_attack_callback := Callable(loro_target, "_on_player_attack_phase_changed").bind(player)
		_assert(player.melee_attack.is_connected("attack_phase_changed", loro_attack_callback), "Alvo do Loro escuta a janela ativa do ataque do jogador")
	boss._process_loro_timers(2.99)
	_assert(loro_target != null and not loro_target.is_shouting(), "Loro ainda não grita antes de 3 segundos")
	boss._process_loro_timers(0.02)
	_assert(loro_target != null and loro_target.is_shouting(), "Loro começa a gritar ao completar 3 segundos")
	_assert(loro_target != null and loro_target._speech_bubble != null and loro_target._speech_bubble.text.contains("MULHERES PELADAS"), "Grito do Loro exibe o texto solicitado")
	boss._process_loro_timers(2.99)
	_assert(test_world.get_node_or_null("Map4MeatHintDialogue") == null, "Dica do Gabriel não aparece antes de 6 segundos")
	boss._process_loro_timers(0.02)
	var hint := test_world.get_node_or_null("Map4MeatHintDialogue") as CanvasLayer
	_assert(hint != null, "Dica é exibida pela caixa oficial de diálogo do Mapa 4 aos 6 segundos")
	if hint != null:
		var messages: Array = hint.get("_dialogues")
		_assert(messages.size() == 1, "Dica contém uma única fala")
		if messages.size() == 1:
			_assert(messages[0].get("speaker", "") == "GABRIEL", "Gabriel é identificado como orador")
			_assert(messages[0].get("text", "") == "Dica de mestre: Fale com o Loro.", "Texto da dica corresponde ao solicitado")
			var hint_portrait: Texture2D = messages[0].get("portrait") as Texture2D
			_assert(hint_portrait != null and hint_portrait.resource_path.ends_with("portrait_gabriel.png"), "Dica reutiliza o retrato herdado de Gabriel")
			_assert(bool(hint.get("_waiting_for_release")), "Dica aguarda confirmação/soltura do comando do jogador")
	_assert(get_tree().paused, "A fase fica pausada enquanto Gabriel apresenta a dica")
	_assert(boss._special_behavior == BossAlessandroEnhancedClass.SpecialBehavior.NONE, "Alessandro não inicia a perseguição enquanto o diálogo está aberto")
	_assert(boss.velocity.is_zero_approx(), "Alessandro permanece imóvel durante a pausa")

	# A confirmação fecha o diálogo, despausa a fase e só então inicia a busca.
	if hint != null:
		hint.call("_close_dialogue")
	_assert(not get_tree().paused, "Confirmar o diálogo despausa a fase")
	_assert(boss._special_behavior == BossAlessandroEnhancedClass.SpecialBehavior.MEAT_SEEKING, "Alessandro só começa a perseguir depois da confirmação")
	_assert(boss._meat_target == boss._meat_instances[0], "A segunda carne é selecionada como alvo após a confirmação")

	# A segunda refeição percorre o mesmo consumo e aplica novamente +300 HP.
	var second_meat: DestructibleProp = boss._meat_target
	boss.health_component.current_health = 500.0
	boss._begin_meat_eating()
	_assert(boss._special_behavior == BossAlessandroEnhancedClass.SpecialBehavior.MEAT_EATING, "Alessandro entra no estado de consumo da carne")
	_assert(boss._speech_bubble != null and boss._speech_bubble.get_child_count() > 0 and boss._speech_bubble.get_child(0) is Label and (boss._speech_bubble.get_child(0) as Label).text == "Comendo...", "Balão Comendo aparece durante a refeição")
	var health_before_eating_hit: float = boss.health_component.current_health
	var eating_damage: RefCounted = DamageInfoClass.new(
		20.0, player, player.global_position, Vector2(-1.0, 0.0),
		"melee", 0.0, 0.1, false, false, 0.0,
		"punch", "upper_torso", boss.global_position + Vector2(0.0, -110.0)
	)
	_assert(not boss.take_damage(eating_damage), "Alessandro rejeita dano enquanto consome a carne")
	_assert(is_equal_approx(boss.health_component.current_health, health_before_eating_hit), "Vida de Alessandro permanece intacta durante o consumo")
	_assert(is_equal_approx(boss._truffle_cooldown, 2.5), "Cadência das trufas é acelerada para intervalo de 2,5 segundos")
	boss._process_special_behavior(2.5)
	_assert(second_meat.is_queued_for_deletion(), "Segunda carne desaparece ao concluir o consumo")
	boss._process_special_behavior(2.8)
	_assert(is_equal_approx(boss.health_component.current_health, 800.0), "Segunda refeição recupera mais 300 HP")
	_assert(boss._special_behavior == BossAlessandroEnhancedClass.SpecialBehavior.NONE, "Após consumir a segunda carne, Alessandro retorna ao combate")
	_assert(boss.current_state == EnemyAIClass.State.FLANKING, "Após o consumo, estado de batalha volta a FLANKING")

	# Acertar o Loro durante o grito provoca chuva de corações e cinco segundos de tontura.
	player.global_position = loro_target.global_position + Vector2(-50.0, 0.0)
	player.melee_attack.facing_direction = 1.0
	player.melee_attack.attack_phase_changed.emit(2)
	_assert(not loro_target.is_shouting(), "Loro recebe o golpe corpo a corpo do jogador enquanto está gritando")
	_assert(is_equal_approx(boss._loro_stun_timer, 5.0), "Acertar o Loro deixa Alessandro tonto por 5 segundos")
	var heart_count: int = 0
	for child: Node in test_world.get_children():
		if child is Label and (child as Label).text == "♥":
			heart_count += 1
	_assert(heart_count == 12, "Doze corações caem sobre Alessandro")
	boss._process_loro_stun(5.0)
	_assert(boss._loro_stun_timer <= 0.0 and boss.current_state == EnemyAIClass.State.FLANKING, "Após 5 segundos Alessandro volta ao combate")
	_assert(is_equal_approx(boss._loro_repeat_timer, 10.0), "Novo grito é agendado para 10 segundos após a recuperação")
	boss._process_loro_timers(9.99)
	_assert(not loro_target.is_shouting(), "Loro não repete o grito antes de 10 segundos")
	boss._process_loro_timers(0.02)
	_assert(loro_target.is_shouting(), "Loro volta a gritar após 10 segundos sem repetir a dica do Gabriel")
	_assert(test_world.get_node_or_null("Map4MeatHintDialogue") == null, "A dica de Gabriel não se repete nos ciclos seguintes")
	player.melee_attack.attack_phase_changed.emit(2)
	_assert(not loro_target.is_shouting(), "Loro pode ser atingido novamente no segundo grito")
	_assert(is_equal_approx(boss._loro_stun_timer, 5.0), "Segundo golpe no Loro repete a tontura de 5 segundos")
	boss.apply_hitstop(0.05)
	boss._process_loro_stun(0.05)
	_assert(not boss.is_in_hitstop() and is_equal_approx(boss._loro_stun_timer, 5.0), "Hitstop local não congela permanentemente o temporizador da tontura")
	boss._process_loro_stun(5.0)

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

	# Destruir a última carne também encerra a rotina de busca e restaura a IA.
	var destroyed_meat: DestructibleProp = MeatScene.instantiate() as DestructibleProp
	destructibles.add_child(destroyed_meat)
	destroyed_meat.global_position = Vector2(300.0, 640.0)
	boss._meat_instances.append(destroyed_meat)
	boss._meat_target = destroyed_meat
	boss._special_behavior = BossAlessandroEnhancedClass.SpecialBehavior.MEAT_SEEKING
	boss.current_state = EnemyAIClass.State.FLANKING
	boss._on_healing_meat_destroyed(destroyed_meat)
	_assert(boss._special_behavior == BossAlessandroEnhancedClass.SpecialBehavior.NONE, "Destruir a última carne encerra MEAT_SEEKING")
	_assert(boss.current_state == EnemyAIClass.State.FLANKING, "Destruir a última carne restaura o estado de combate")

	# Encurralado na parede esquerda, permite quatro acertos e foge após o combo.
	boss.global_position = Vector2(100.0, 640.0)
	player.global_position = Vector2(145.0, 640.0)
	boss._special_behavior = BossAlessandroEnhancedClass.SpecialBehavior.NONE
	boss._cornered_combo_hits = 0
	boss._cornered_combo_timer = 0.0
	boss._cornered_evasion_pending = false
	var cornered_info: RefCounted = DamageInfoClass.new(
		10.0, player, player.global_position, Vector2(1.0, 0.0),
		"melee", 0.0, 0.1, false, false, 0.0,
		"punch", "upper_torso", boss.global_position + Vector2(0.0, -110.0)
	)
	_assert(boss._is_cornered_by_player(), "Alessandro identifica quando está pressionado contra a parede")
	for hit_index: int in range(4):
		_assert(boss.take_damage(cornered_info), "Acerto %d do único combo é permitido" % (hit_index + 1))
	_assert(boss._cornered_evasion_pending, "Quarto acerto agenda a evasão automática")
	_assert(not boss.take_damage(cornered_info), "Quinto acerto é bloqueado enquanto a evasão automática acontece")
	boss._process_hurt(1.0)
	_assert(boss._special_behavior == BossAlessandroEnhancedClass.SpecialBehavior.EVADING, "Após um combo completo, Alessandro inicia a esquiva")
	_assert(boss._evasion_direction.x > 0.0, "Na parede esquerda, Alessandro desliza para o interior da arena")

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
