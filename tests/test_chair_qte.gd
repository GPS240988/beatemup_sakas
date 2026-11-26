extends SceneTree

const QTE_SCENE: PackedScene = preload("res://scenes/ui/qte_prompt_overlay.tscn")
const MAP7_PATH: String = "res://scenes/levels/map_7.tscn"
const PLAYER_SCENE: PackedScene = preload("res://scenes/actors/player/player.tscn")
const BRAWLER_SCENE: PackedScene = preload("res://scenes/actors/enemies/pizza_brawler.tscn")

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
	print("=== TESTE QTE DA CADEIRADA (MAP 7 - PRIMEIRO GORDUCHO) ===")

	# 1. QTEPromptOverlay isolado - Sucesso com S, W, D, A, J
	var qte_ok := QTE_SCENE.instantiate() as CanvasLayer
	root.add_child(qte_ok)
	await process_frame

	var ok_state := {"succeeded": false, "failed": false}
	qte_ok.connect("qte_succeeded", func(): ok_state["succeeded"] = true)
	qte_ok.connect("qte_failed", func(_r: String): ok_state["failed"] = true)
	qte_ok.call("start_qte", [] as Array[StringName], 1.5)
	_check(qte_ok.call("is_qte_active"), "QTE inicia ativo")
	_check(qte_ok.get("sequence") == [&"move_down", &"move_up", &"move_right", &"move_left", &"attack"], "Sequência padrão é S, W, D, A, J (attack)")

	for act in [&"move_down", &"move_up", &"move_right", &"move_left", &"attack"]:
		qte_ok.call("simulate_action_input", act)
	_check(ok_state["succeeded"] and not ok_state["failed"], "QTE emite sucesso ao digitar S, W, D, A, J na ordem")
	_check(not qte_ok.call("is_qte_active"), "QTE encerra após sucesso")
	qte_ok.queue_free()

	# 2. QTEPromptOverlay isolado - Erro de botão fora de ordem
	var qte_err := QTE_SCENE.instantiate() as CanvasLayer
	root.add_child(qte_err)
	await process_frame

	var err_reason := {"reason": ""}
	qte_err.connect("qte_failed", func(r: String): err_reason["reason"] = r)
	qte_err.call("start_qte", [] as Array[StringName], 1.5)
	qte_err.call("simulate_action_input", &"move_down")
	qte_err.call("simulate_action_input", &"move_left") # Errado (esperava move_up)
	_check(err_reason["reason"] == "wrong_input", "QTE falha imediatamente ao errar sequência")
	qte_err.queue_free()

	# 3. QTEPromptOverlay isolado - Timeout após 1.5s
	var qte_to := QTE_SCENE.instantiate() as CanvasLayer
	root.add_child(qte_to)
	await process_frame

	var to_reason := {"reason": ""}
	qte_to.connect("qte_failed", func(r: String): to_reason["reason"] = r)
	qte_to.call("start_qte", [] as Array[StringName], 0.25)
	await create_timer(0.35).timeout
	_check(to_reason["reason"] == "timeout", "QTE falha por timeout quando tempo expira")
	qte_to.queue_free()

	# 4. Integração no Map 7: somente os 2 últimos gorduchos têm enable_chair_ambush = true
	var map7_scene := load(MAP7_PATH) as PackedScene
	_check(map7_scene != null, "Map 7 carrega")
	if map7_scene != null:
		var map7 := map7_scene.instantiate()
		root.add_child(map7)
		await process_frame
		await physics_frame

		var enemies := map7.get_node_or_null("World/Actors/Enemies")
		var first_brawler := enemies.get_node_or_null("PizzaBrawler_RectLeft") as PizzaBrawler
		var second_brawler := enemies.get_node_or_null("PizzaBrawler_RectRight") as PizzaBrawler
		var round_left := enemies.get_node_or_null("PizzaBrawler_RoundLeft") as PizzaBrawler
		var last_brawler := enemies.get_node_or_null("PizzaBrawler") as PizzaBrawler
		var chair_round_left := map7.get_node_or_null("World/Props/StaticProps/ChairFrontLeft02") as Node2D
		var player := map7.get_node_or_null("World/Actors/Player") as PlayerController

		_check(first_brawler != null and first_brawler.display_name == "GORDUCHO", "Nome do personagem atualizado para GORDUCHO")
		_check(first_brawler != null and first_brawler.enable_chair_ambush == false, "Primeiro gorducho (PizzaBrawler_RectLeft) NÃO possui emboscada QTE")
		_check(second_brawler != null and second_brawler.enable_chair_ambush == false, "Segundo gorducho (PizzaBrawler_RectRight) NÃO possui emboscada QTE")
		_check(round_left != null and round_left.enable_chair_ambush == true, "Penúltimo gorducho (PizzaBrawler_RoundLeft) tem enable_chair_ambush = true")
		_check(last_brawler != null and last_brawler.enable_chair_ambush == true, "Último gorducho (PizzaBrawler) tem enable_chair_ambush = true")
		_check(last_brawler != null and is_equal_approx(last_brawler.qte_duration, 3.0) and last_brawler.qte_reverse_sequence == true, "4º gorducho tem timer de 3.0s e sequência invertida")
		_check(round_left != null and is_equal_approx(round_left.qte_duration, 4.0), "Duração do QTE do 3º gorducho configurada para 4.0 segundos")
		var counter1 := enemies.get_node_or_null("PizzaBrawler_Counter") as PizzaBrawler
		var counter2 := enemies.get_node_or_null("PizzaBrawler_CounterSide") as PizzaBrawler
		_check(counter1 != null and counter1.use_waitress_visual and counter2 != null and counter2.use_waitress_visual, "Fundo substituído por 2 garçonetes")
		var c1_anim := counter1.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D if counter1 != null else null
		var c2_anim := counter2.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D if counter2 != null else null
		_check(c1_anim != null and c1_anim.material == null and c2_anim != null and c2_anim.material == null, "As 2 garçonetes do fundo mantêm a cor normal original do asset")
		_check(chair_round_left != null and chair_round_left.visible, "ChairFrontLeft02 inicia visível")
		_check(player != null, "Player presente no Map 7")

		if round_left != null and player != null:
			var hp_before: float = player.health_component.current_health
			# Move player para o raio do penúltimo gorducho e acorda
			player.global_position = round_left.global_position + Vector2(-45.0, 0.0)
			round_left.trigger_wake_up()
			# Aguarda o getup terminar e iniciar CHAIR_AMBUSH (fala primeiro!)
			for _i in range(60):
				await physics_frame
				if round_left.is_in_chair_ambush():
					break
			_check(round_left.is_in_chair_ambush(), "Gorducho entra em CHAIR_AMBUSH ao acordar")
			_check(chair_round_left == null or not chair_round_left.visible, "Cadeira do chão foi ocultada ao ser pega pelo gorducho")
			_check(player.is_qte_locked(), "Player fica travado durante fala + QTE")
			_check(round_left.is_ambush_speech_visible(), "Balão de fala exibido ANTES de iniciar o QTE")
			_check(round_left.get_active_qte_overlay() == null, "QTE ainda aguarda a fala terminar antes de abrir")

			# Aguarda a fala terminar e o QTE abrir
			for _i in range(90):
				await physics_frame
				if round_left.get_active_qte_overlay() != null:
					break

			var overlay := round_left.get_active_qte_overlay()
			_check(overlay != null and overlay.call("is_qte_active"), "QTEPromptOverlay aberto após a fala com 4.0s")
			_check(overlay != null and is_equal_approx(float(overlay.get("duration")), 4.0), "Overlay recebe exatamente 4.0s de duração")

			# Tenta acordar o 4º gorducho enquanto o 3º ainda está em CHAIR_AMBUSH -> deve ser bloqueado (1 por vez)
			if last_brawler != null:
				last_brawler.trigger_wake_up()
				await physics_frame
				_check(not last_brawler.is_in_chair_ambush(), "4º gorducho NÃO engatilha junto com o 3º (1 ataque por vez)")

			if overlay != null:
				for act in [&"move_down", &"move_up", &"move_right", &"move_left", &"attack"]:
					overlay.call("simulate_action_input", act)
				await process_frame
				_check(not player.is_qte_locked(), "Player destrava após esquivar com sucesso")
				_check(is_equal_approx(player.health_component.current_health, hp_before), "Player não toma dano ao acertar o QTE")
				_check(round_left.is_in_combat(), "Gorducho entra em COMBAT após resolução do QTE")

		# Aguarda um pouco para o 4º gorducho ser testado após o 3º finalizar
		if last_brawler != null and player != null:
			_check(last_brawler.auto_ambush_after_previous == true and is_equal_approx(last_brawler.auto_ambush_delay_seconds, 5.0), "4º gorducho configurado com auto_ambush após 5.0s")
			player.global_position = last_brawler.global_position + Vector2(-45.0, 0.0)
			last_brawler.trigger_wake_up()
			for _i in range(140):
				await physics_frame
				if last_brawler.get_active_qte_overlay() != null:
					break
			_check(last_brawler.is_in_chair_ambush(), "4º gorducho engatilha após o 3º terminar ao entrar no raio")
			var ov4 := last_brawler.get_active_qte_overlay()
			_check(ov4 != null and is_equal_approx(float(ov4.get("duration")), 3.0), "4º gorducho abre QTE com 3.0s")
			_check(ov4 != null and ov4.get("sequence") == [&"attack", &"move_left", &"move_right", &"move_up", &"move_down"], "4º gorducho usa sequência invertida (J, A, D, W, S)")
			if ov4 != null:
				for act in [&"attack", &"move_left", &"move_right", &"move_up", &"move_down"]:
					ov4.call("simulate_action_input", act)
				await process_frame
				_check(not player.is_qte_locked(), "Player destrava após 2º QTE também")

		# Testa respawn do banheiro: 1º gorducho vem com garçonete deitada
		map7.call("trigger_bathroom_respawn_wave")
		await physics_frame
		var b_respawn := enemies.get_node_or_null("PizzaBrawler_Bathroom01") as PizzaBrawler
		_check(b_respawn != null and b_respawn.enable_chair_ambush and b_respawn.ambush_prop_mode == "waitress", "1º gorducho do respawn configurado para arremessar garçonete deitada")
		_check(b_respawn != null and b_respawn.get_node_or_null("Visual/HeldAmbushProp") != null, "1º gorducho do respawn já chega carregando a garçonete logo ao spawnar")

		# Testa respawn das cadeiras quando o grupo senta no final
		var chair_round_right := map7.get_node_or_null("World/Props/StaticProps/ChairFrontRight02") as CanvasItem
		if chair_round_left != null:
			chair_round_left.visible = false
		if chair_round_right != null:
			chair_round_right.visible = false
		map7.call("_spawn_seated_victory_heroes")
		_check(chair_round_left != null and chair_round_left.visible and chair_round_right != null and chair_round_right.visible, "Cadeiras da segunda mesa reaparecem quando o grupo senta")

		map7.queue_free()
		await process_frame

	# 5. Cenário de falha: erro no QTE dispara trajetória até o player, som de madeira, dano e Knockdown
	_check(FileAccess.file_exists("res://assets/audio/sfx/chair_wood_hit.wav"), "Som de madeira atingindo chão/personagem existe em chair_wood_hit.wav")
	PizzaBrawler.reset_global_chair_ambush_state()
	var arena := Node2D.new()
	root.add_child(arena)
	var p := PLAYER_SCENE.instantiate() as PlayerController
	p.position = Vector2(300.0, 520.0)
	arena.add_child(p)
	var b := BRAWLER_SCENE.instantiate() as PizzaBrawler
	b.position = Vector2(360.0, 520.0)
	b.enable_chair_ambush = true
	b.getup_fallback_duration = 0.05
	b.ambush_speech_duration = 0.0
	arena.add_child(b)
	await process_frame
	await physics_frame

	var initial_hp: float = p.health_component.current_health
	b.trigger_wake_up()
	for _i in range(30):
		await physics_frame
		if b.is_in_chair_ambush():
			break

	var fail_overlay := b.get_active_qte_overlay()
	_check(fail_overlay != null, "Overlay QTE criado na instância isolada")
	if fail_overlay != null:
		fail_overlay.call("simulate_action_input", &"attack") # Errou logo de cara
		await create_timer(0.24).timeout # Aguarda a trajetória da cadeira atingir o jogador
		_check(p.health_component.current_health < initial_hp, "Player toma dano da cadeirada quando erra o QTE")
		_check(p.combat_state == PlayerController.CombatState.FALL, "Player entra em CombatState.FALL (Knockdown) ao errar o QTE")

	arena.queue_free()
	await process_frame

	print("Resultado: %d passou, %d falhou" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
