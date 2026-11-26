extends SceneTree

const MAP7_PATH: String = "res://scenes/levels/map_7.tscn"
const MAP8_PATH: String = "res://scenes/levels/map_8.tscn"
const COMANDA_ORIG_PATH: String = "res://assets/sprites/stage2/happen_props/comanda.png"
const COMANDA_FURADA_PATH: String = "res://assets/sprites/stage2/happen_props/comanda_furada.png"

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [OK] %s" % msg)
	else:
		_failed += 1
		printerr("  [FAIL] %s" % msg)


func _run_tests() -> void:
	print("=== TESTE ENCERRAMENTO ESTÁGIO 2 (MAP 8 -> MAP 7 FINALE) ===")

	# 1. Asset comanda_furada.png
	var orig_img := Image.load_from_file(ProjectSettings.globalize_path(COMANDA_ORIG_PATH))
	var furada_img := Image.load_from_file(ProjectSettings.globalize_path(COMANDA_FURADA_PATH))
	_check(orig_img != null and furada_img != null, "1. comanda.png e comanda_furada.png existem e carregam")
	if orig_img != null and furada_img != null:
		_check(orig_img.get_size() == furada_img.get_size(), "1. comanda_furada.png preserva dimensões exatas (%s)" % str(orig_img.get_size()))
		_check(furada_img.get_pixel(50, 62).a < 0.05, "1. comanda_furada.png possui furo transparente de bala no centro")

	var session := root.get_node_or_null("GameSession")
	_check(session != null, "2. GameSession autoload disponível")
	if session != null:
		session.set("selected_character_id", "gabriel")
		session.set("stage_2_completed", false)
		session.call("set_pending_map8_return_to_happen_finale", true)
		_check(bool(session.call("consume_map8_return_to_happen_finale")) == true, "2. Estado de retorno de uso único retorna true na 1ª leitura")
		_check(bool(session.call("consume_map8_return_to_happen_finale")) == false, "2. Estado de retorno é consumido (retorna false na 2ª leitura)")

	# 2. Map 8: sequência do mictório -> caminhada automática até a entrada do banheiro
	var map8_scene := load(MAP8_PATH) as PackedScene
	_check(map8_scene != null, "3. Map 8 carrega corretamente")
	if map8_scene != null:
		var map8 := map8_scene.instantiate()
		root.add_child(map8)
		await process_frame
		await process_frame

		var p8 := map8.get_node_or_null("World/Actors/Player") as PlayerController
		if p8 != null:
			p8.global_position = Vector2(1888.0, 536.0)
			if p8.health_component != null:
				var hp_before_poison: float = p8.health_component.current_health
				map8.call("_release_leader_gas_cloud")
				_check(bool(map8.call("is_poison_dot_active")), "3b. Poison DoT ativado quando Líder solta o golpe de gás")
				await create_timer(1.15).timeout
				_check(p8.health_component.current_health < hp_before_poison, "3b. Poison DoT reduz vida por segundo (%s -> %s)" % [hp_before_poison, p8.health_component.current_health])
				map8.call("_on_encounter_cleared")
				_check(not bool(map8.call("is_poison_dot_active")), "3b. Poison DoT cessa ao derrotar o Líder")

		map8.call("start_urinal_sequence")
		await process_frame
		_check(map8.get_node_or_null("World/Actors/NPCs/UrinalCutscene_Guilherme") != null, "3c. Guilherme assume a cena do mictório mesmo jogando com Gabriel")

		map8.call("_finish_urinal_sequence")
		await process_frame
		_check(bool(map8.call("is_urinal_sequence_finished")), "3. Sequência do mictório finaliza corretamente")
		_check(map8.get_node_or_null("World/Actors/NPCs/UrinalCutscene_Guilherme") == null, "3c. Cena retorna para o player ativo após o xixi")
		_check(bool(map8.call("is_auto_return_started")), "3. Caminhada automática de retorno ao Map 7 é iniciada")

		_check(p8 != null and p8.is_qte_locked(), "3. Controles manuais do jogador bloqueados durante retorno automático")
		_check(p8 != null and p8.is_physics_processing(), "3. Física do personagem reativada para caminhada automática")
		var start_x: float = p8.global_position.x if p8 != null else 0.0
		for _i in range(25):
			await physics_frame
		_check(p8 != null and p8.global_position.x < start_x - 20.0, "3. Jogador caminha automaticamente em direção à entrada do banheiro")
		_check(p8 != null and p8.anim_sprite != null and p8.anim_sprite.animation == &"walk", "3. Animação 'walk' do player ativo mantida na volta ao Map 7")
		map8.queue_free()
		await process_frame

	# 3. Map 7 em modo de retorno único (Map 8 -> Map 7 Finale)
	if session != null:
		session.set("selected_character_id", "gabriel")
		session.set("stage_2_completed", false)
		session.call("set_pending_map8_return_to_happen_finale", true)

	var map7_scene := load(MAP7_PATH) as PackedScene
	_check(map7_scene != null, "4. Map 7 carrega corretamente")
	if map7_scene == null:
		_finish()
		return

	var map7 := map7_scene.instantiate()
	root.add_child(map7)
	await process_frame
	await process_frame

	_check(bool(map7.call("is_finale_return_mode")), "4. Map 7 entra em modo de retorno final ao consumir o estado")
	_check(session != null and not bool(session.get("pending_map8_return_to_happen_finale")), "4. Estado de retorno foi consumido (sem loop)")

	var enemies_node := map7.get_node_or_null("World/Actors/Enemies")
	_check(enemies_node != null and enemies_node.get_child_count() == 0, "5. Nenhum inimigo reaparece no Map 7 após retorno")
	_check(map7.get_node_or_null("CounterBanter") == null, "5. CounterBanter não é repetido no retorno")
	_check(not bool(map7.call("is_garconete_cutscene_active")), "5. Cena anterior da garçonete não é repetida")
	_check(not bool(map7.call("is_seated_ending_triggered")), "5. Cena de vitória sentada não é repetida")

	var exit7 := map7.get_node_or_null("ExitArea") as Area2D
	_check(exit7 != null and not exit7.monitoring, "5. ExitArea permanece desativada no encerramento")

	var p7 := map7.get_node_or_null("World/Actors/Player") as PlayerController
	_check(p7 != null and p7.hero_data != null and str(p7.hero_data.hero_id).to_lower() == "gabriel", "4. Personagem ativo (gabriel) preservado no retorno ao Map 7")
	_check(map7.get_node_or_null("World/Actors/NPCs/FinaleCompanion_Gabriel") == null, "5. Gabriel ativo não é duplicado")
	var guilherme_comp := map7.get_node_or_null("World/Actors/NPCs/FinaleCompanion_Guilherme") as Node2D
	_check(guilherme_comp != null, "5. Guilherme companheiro presente próximo ao caixa")
	_check(map7.get_node_or_null("World/Actors/NPCs/Garconete") != null, "5. Garçonete presente no caixa")
	_check(map7.get_node_or_null("World/Actors/NPCs/Seated_Juliana") != null, "5. Juliana presente no salão")
	_check(map7.get_node_or_null("World/Actors/NPCs/Fernando") == null and map7.get_node_or_null("World/Actors/NPCs/Seated_Fernando") == null, "5. Fernando não aparece fisicamente")

	# Avança a caminhada do jogador até o caixa
	var finale := map7.call("get_finale_controller") as Node
	_check(finale != null, "6. Controlador Map7HappenFinale instanciado")
	if finale != null:
		var wait_elapsed: float = 0.0
		while not bool(finale.call("is_dialogue_active")) and wait_elapsed < 3.0:
			await create_timer(0.05).timeout
			wait_elapsed += 0.05
		_check(bool(finale.call("is_dialogue_active")), "6. Diálogo final inicia automaticamente ao chegar ao caixa")
		_check(guilherme_comp != null and p7 != null and guilherme_comp.global_position.x > p7.global_position.x, "6b. Guilherme fica sempre à frente e Gabriel atrás")
		_check(map7.get_node_or_null("World/Props/FinaleComandaProp") != null, "6b. Guilherme segura a comanda desde o início da conversa")
		_check(p7 != null and p7.anim_sprite != null and p7.anim_sprite.animation == &"idle", "6b. Gabriel não saca a arma antes da fala da marca registrada")

		var expected_lines: Array[Dictionary] = [
			{"speaker": "GARÇONETE", "text": "Finalmente! E aí, quem vai pagar essa conta?"},
			{"speaker": "GABRIEL", "text": "Fernando..."},
			{"speaker": "GUILHERME", "text": "Nossa, mijei na comanda a toa, o Fernando morreu."},
			{"speaker": "GARÇONETE", "text": "Tá bom. Só espero que vocês tenham mais cuidado com a comanda da próxima vez."},
			{"speaker": "GABRIEL", "text": "Olha, pelo menos dessa vez ela chegou inteira."},
			{"speaker": "GUILHERME", "text": "Gabriel, o papel está encharcado."},
			{"speaker": "GABRIEL", "text": "Eu disse inteira, não disse seca."},
			{"speaker": "GARÇONETE", "text": "Me entrega logo essa comanda!"},
			{"speaker": "GABRIEL", "text": "Vou deixar uma marca registrada."},
		]

		for idx in range(expected_lines.size()):
			var guard_elapsed: float = 0.0
			var spk_lbl := finale.get_node_or_null("FinaleDialogueLayer/DialogueInputRoot/DialogueArea/DialogueFrame/InnerMargin/DialogueHBox/TextVBox/SpeakerName") as Label
			var txt_lbl := finale.get_node_or_null("FinaleDialogueLayer/DialogueInputRoot/DialogueArea/DialogueFrame/InnerMargin/DialogueHBox/TextVBox/DialogueText") as Label
			while txt_lbl != null and txt_lbl.text == "" and guard_elapsed < 1.5:
				await create_timer(0.05).timeout
				guard_elapsed += 0.05
			# Skip typewriter
			finale.call("confirm_current_step")
			await process_frame
			var exp_spk: String = expected_lines[idx]["speaker"]
			var exp_txt: String = expected_lines[idx]["text"]
			_check(spk_lbl != null and spk_lbl.text == exp_spk and txt_lbl != null and txt_lbl.text == exp_txt, "7. Fala %d (%s) exibida corretamente" % [idx + 1, exp_spk])
			if idx == 8:
				_check(p7 != null and p7.anim_sprite != null and p7.anim_sprite.animation == &"shot_1", "7b. Gabriel saca a arma exatamente na fala da marca registrada")
			# Advance to next line (or trigger gunshot after line 9)
			finale.call("confirm_current_step")
			await process_frame

		# Aguarda conclusão da animação cinematográfica do disparo
		var shot_elapsed: float = 0.0
		while int(finale.call("get_current_line_index")) < 9 and shot_elapsed < 3.0:
			await create_timer(0.05).timeout
			shot_elapsed += 0.05

		_check(bool(finale.call("is_gunshot_executed")), "8. Disparo cinematográfico executado contra a comanda")
		var comanda_prop := map7.get_node_or_null("World/Props/FinaleComandaProp") as Sprite2D
		_check(comanda_prop != null and comanda_prop.texture != null, "9. Comanda furada exibida no lugar da comanda original")
		_check(enemies_node.get_child_count() == 0, "8. Disparo não inicia combate nem transforma garçonete em inimiga")

		# Fala final da Juliana
		finale.call("confirm_current_step") # revela texto completo
		await process_frame
		var spk_final := finale.get_node_or_null("FinaleDialogueLayer/DialogueInputRoot/DialogueArea/DialogueFrame/InnerMargin/DialogueHBox/TextVBox/SpeakerName") as Label
		var txt_final := finale.get_node_or_null("FinaleDialogueLayer/DialogueInputRoot/DialogueArea/DialogueFrame/InnerMargin/DialogueHBox/TextVBox/DialogueText") as Label
		_check(spk_final != null and spk_final.text == "JULIANA" and txt_final != null and txt_final.text == "Tira os 10% de serviço por favor!", "10. Fala final da Juliana exibida corretamente")

		# Confirma última fala -> Tela final "FIM DO ESTÁGIO 2 / Até breve."
		finale.call("confirm_current_step")
		await process_frame
		await process_frame

		_check(bool(finale.call("is_ending_active")), "11. Tela de encerramento do Estágio 2 ativada")
		_check(p7 != null and p7.is_qte_locked() and not p7.is_physics_processing(), "11. Movimentação bloqueada definitivamente no encerramento")
		var end_title := finale.find_child("EndingTitleLabel", true, false) as Label
		var end_sub := finale.find_child("EndingSubtitleLabel", true, false) as Label
		_check(end_title != null and end_title.text == "FIM DO ESTÁGIO 2", "11. Título 'FIM DO ESTÁGIO 2' exibido")
		_check(end_sub != null and end_sub.text == "Até breve.", "11. Subtítulo 'Até breve.' exibido")
		_check(session != null and bool(session.call("is_stage_completed", 2)), "12. Conclusão do Estágio 2 registrada em GameSession")

	map7.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("RESULTADO TESTE FINALE ESTÁGIO 2: %d passaram, %d falharam" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
