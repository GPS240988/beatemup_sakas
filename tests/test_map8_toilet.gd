extends SceneTree

const MAP7_PATH: String = "res://scenes/levels/map_7.tscn"
const MAP8_PATH: String = "res://scenes/levels/map_8.tscn"
const BACKGROUND_PATH: String = "res://assets/backgrounds/maps/fase2/Fase2_5.webp"
const GAME_SESSION_SCRIPT: String = "res://scripts/core/game_session.gd"

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== TESTE MAP 8: HAPPEN — TOALETE ===")

	var session := root.get_node_or_null("GameSession")
	if session == null:
		var gs_script := load(GAME_SESSION_SCRIPT) as Script
		if gs_script != null:
			session = gs_script.new()
			session.name = "GameSession"
			root.add_child(session)
	if session != null:
		session.set("selected_character_id", "gabriel")

	# 1 & 2. Acesso a partir do toalete do Map 7 e preservação de personagem
	var map7_scene := load(MAP7_PATH) as PackedScene
	_check(map7_scene != null, "1. Map 7 carrega")
	if map7_scene != null:
		var map7 := map7_scene.instantiate()
		root.add_child(map7)
		await process_frame
		_check(str(map7.get("next_map_scene_path")) == MAP8_PATH, "1. Map 7 aponta para o Map 8")
		var exit7 := map7.get_node_or_null("ExitArea") as Area2D
		_check(exit7 != null and not exit7.monitoring, "1. ExitArea do toalete do Map 7 inicia desativada")
		_check(exit7 != null and exit7.position.x >= 1920.0 and exit7.position.y <= 470.0, "1. ExitArea posicionada na porta do toalete acima do caixa")
		if map7.has_method("enable_toilet_exit"):
			map7.call("enable_toilet_exit")
		_check(exit7 != null and exit7.monitoring, "1. enable_toilet_exit() habilita a entrada do toalete")
		var blink := map7.get_node_or_null("ToiletBlinkIndicator")
		_check(blink != null and blink.get_node_or_null("DoorLightSpill") != null and blink.get_node_or_null("DiegeticArrow") != null, "1. Sinalização diegética piscante na porta do toalete (sem HUD/ReferenceRect)")
		var table_pizza := map7.get_node_or_null("World/Props/TablePizzaSlicePickup")
		_check(table_pizza != null and is_equal_approx(float(table_pizza.get("heal_amount")), 30.0), "1b. Fatia de pizza (+30 HP) presente na segunda mesa do Map 7")
		var p7 := map7.get_node_or_null("World/Actors/Player") as PlayerController
		if table_pizza != null and p7 != null and p7.health_component != null:
			p7.health_component.current_health = 50.0
			p7.global_position = table_pizza.global_position + Vector2(0.0, 20.0)
			_check(bool(table_pizza.call("try_consume", p7)) and is_equal_approx(p7.health_component.current_health, 80.0), "1b. Fatia de pizza da mesa cura +30 HP")
		if session != null:
			_check(str(session.get("selected_character_id")) == "gabriel", "2. Seleção de personagem preservada para transição")
		map7.queue_free()
		await process_frame

	# 3. Map 8 carrega corretamente
	var map8_scene := load(MAP8_PATH) as PackedScene
	_check(map8_scene != null, "3. Map 8 carrega corretamente")
	if map8_scene == null:
		_finish()
		return

	var map8 := map8_scene.instantiate()
	root.add_child(map8)
	await process_frame
	await process_frame

	var bg := map8.get_node_or_null("Background/Far") as Sprite2D
	_check(bg != null and bg.texture != null and bg.texture.resource_path == BACKGROUND_PATH, "3. Map 8 usa background Fase2_5.webp")
	_check(map8.get_node_or_null("World/Props/StaticProps/GreasyComandaProp") != null, "3. Prop narrativo da comanda engordurada presente")
	var trash_pizza := map8.get_node_or_null("World/Props/TrashPizzaSlicePickup")
	_check(trash_pizza != null and is_equal_approx(float(trash_pizza.get("heal_amount")), 30.0), "5b. Fatia de pizza (+30 HP) presente em cima do lixo no Map 8")
	_check(map8.get_node_or_null("NavigationRegion2D") != null, "3. NavigationRegion2D presente")
	for col_name in ["ToiletTrashCollider", "ToiletSinkCollider", "ToiletStallCollider", "ToiletUrinalCollider"]:
		var col_body := map8.get_node_or_null("World/Props/StaticProps/" + col_name) as StaticBody2D
		_check(col_body != null and col_body.collision_layer == 2 and col_body.collision_mask == 1, "3. Colisor %s presente (layer 2, mask 1)" % col_name)

	var player := map8.get_node_or_null("World/Actors/Player") as PlayerController
	_check(player != null, "3. Player instanciado no Map 8")
	if session != null and player != null and player.hero_data != null:
		_check(str(player.hero_data.hero_id).to_lower() == "gabriel", "2. Personagem selecionado (gabriel) preservado no Map 8")

	# 4. Os três inimigos são instanciados
	var lider := map8.get_node_or_null("World/Actors/Enemies/GorduchoLider") as PizzaBrawler
	var g2 := map8.get_node_or_null("World/Actors/Enemies/Gorducho2") as PizzaBrawler
	var g3 := map8.get_node_or_null("World/Actors/Enemies/Gorducho3") as PizzaBrawler
	_check(lider != null and g2 != null and g3 != null, "4. Três gorduchos instanciados no Map 8")
	if lider != null and g2 != null and g3 != null:
		_check(lider.position.x >= 1700.0 and g2.position.x >= 1700.0 and g3.position.x >= 1700.0, "4. Gorduchos posicionados perto do mictório no final do Map 8")
		_check(lider.facing_direction < 0.0 and g2.facing_direction < 0.0 and g3.facing_direction < 0.0, "4. Gorduchos virados para a esquerda olhando para o jogador")
		_check(lider.visual_root.scale.x < 0.0 and g2.visual_root.scale.x < 0.0 and g3.visual_root.scale.x < 0.0, "4. Visual dos três gorduchos espelhado para a esquerda")

	if lider != null and g2 != null and g3 != null:
		# 5. Somente o líder recebe aumento de escala (inteira 2.0x)
		var scaler := map8.get_node_or_null("YDepthScaler")
		var base_scales: Dictionary = scaler.get("_base_visual_scales") if scaler != null else {}
		var base_lider: Vector2 = base_scales.get(lider.get_instance_id(), Vector2.ZERO)
		var base_g2: Vector2 = base_scales.get(g2.get_instance_id(), Vector2.ZERO)
		var base_g3: Vector2 = base_scales.get(g3.get_instance_id(), Vector2.ZERO)
		_check(is_equal_approx(base_lider.y, 2.0), "5. Líder possui escala base inteira 2.0x")
		_check(is_equal_approx(base_g2.y, 1.0), "5. Gorducho 2 mantém escala base padrão 1.0x")
		_check(is_equal_approx(base_g3.y, 1.0), "5. Gorducho 3 mantém escala base padrão 1.0x")
		var hurt_lider := lider.get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
		_check(hurt_lider != null and hurt_lider.shape is RectangleShape2D and (hurt_lider.shape as RectangleShape2D).size.y > 300.0, "5. Hurtbox do líder ajustada à escala 2.0x")
		var vis_lider := lider.get_node_or_null("Visual") as Node2D
		var vis_g2 := g2.get_node_or_null("Visual") as Node2D
		_check(vis_lider != null and vis_g2 != null and vis_lider.scale.y > vis_g2.scale.y * 1.8, "5. Visual em cena do líder mantém ~2x o tamanho do gorducho padrão")
		_check(lider.health_component.max_health >= 240.0 and lider.melee_attack.damage < 25.0, "5. Líder possui vida aumentada (240 HP) sem inflar dano")

		# 6. Animações dos três inimigos funcionam
		for pair in [["Líder", lider], ["Gorducho 2", g2], ["Gorducho 3", g3]]:
			var label_n: String = pair[0]
			var actor: PizzaBrawler = pair[1]
			var sf := actor.anim_sprite.sprite_frames if actor.anim_sprite != null else null
			_check(sf != null and sf.has_animation("idle") and sf.has_animation("walk") and sf.has_animation("attack") and sf.has_animation("hurt") and sf.has_animation("death"), "6. %s possui animações completas" % label_n)

		# 7. Conversa apresenta falas na ordem correta e bloqueia controles durante o intro
		var dlg = map8.call("get_dialogue_controller")
		_check(dlg != null and dlg.call("is_intro_active"), "7. Conversa ambiental inicia automaticamente")
		_check(player != null and not player.is_physics_processing(), "7. Controles do jogador bloqueados durante a conversa")
		_check(not map8.call("is_combat_started"), "8. Combate ainda não iniciou durante a conversa")

		var expected_lines: Array[Array] = [
			["LÍDER", "Cadê aquela comanda limpa que o cara tá levando?"],
			["GORDUCHO 2", "Vai dar ruim! A nossa virou um pastel de gordura!"],
			["GORDUCHO 3", "Eu falei pra não colocar a pizza em cima do papel!"],
			["LÍDER", "O dono vai olhar aquela porcaria e cobrar até o nosso peso!"],
			["GORDUCHO 2", "Então pega a comanda dele! É só trocar!"],
			["GORDUCHO 3", "Mas eu ainda tô com fome..."],
			["LÍDER", "VOCÊ JÁ COMEU QUATRO PIZZAS, ANIMAL!"],
			["LÍDER", "Chega de conversa! Passa essa comanda!"],
			["GORDUCHO 2", "Não deixa ele sair com o papel!"]
		]
		var actual_lines: Array = dlg.call("get_intro_lines")
		var lines_match: bool = actual_lines.size() == expected_lines.size()
		if lines_match:
			for i in range(expected_lines.size()):
				if str(actual_lines[i]["speaker"]) != expected_lines[i][0] or str(actual_lines[i]["text"]) != expected_lines[i][1]:
					lines_match = false
					break
		_check(lines_match, "7. Todas as 9 falas da conversa e início de combate estão na ordem exata")

		# 8 & 9. Combate começa com os 2 gorduchos normais; Líder aguarda
		dlg.call("skip_intro_dialogue")
		await process_frame
		_check(not dlg.call("is_intro_active"), "8. Conversa encerra após última fala")
		_check(map8.call("is_combat_started"), "8. Combate inicia logo após a conversa")
		_check(player != null and player.is_physics_processing(), "9. Controles do jogador restaurados para o combate")
		_check(g2.is_physics_processing() and g3.is_physics_processing(), "8. Os 2 gorduchos normais entram em combate primeiro")
		_check(not bool(map8.call("is_leader_engaged")) and not lider.is_physics_processing(), "8. Líder aguarda os 2 gorduchos antes de entrar")

		# 10 & 11. Derrota os 2 gorduchos normais -> Líder entra na luta
		g2.health_component.take_damage(999.0)
		await process_frame
		_check(not map8.call("is_combat_ended"), "11. Combate não termina após derrotar o 1º gorducho")
		_check(not bool(map8.call("is_leader_engaged")), "8. Líder ainda aguarda enquanto resta 1 gorducho normal")

		g3.health_component.take_damage(999.0)
		await process_frame
		_check(bool(map8.call("is_leader_engaged")) and lider.is_physics_processing(), "8. Líder entra na luta após os 2 gorduchos normais caírem")
		_check(not map8.call("is_combat_ended"), "11. Combate continua contra o Líder")

		# Verifica que banter após liberar g2/g3 não gera erro de instância liberada
		g2.queue_free()
		g3.queue_free()
		await process_frame
		dlg.call("_trigger_random_combat_banter")
		_check(true, "9c. Banter de combate seguro após liberação dos gorduchos normais")

		# Mecânica de gás do Líder (vira de costas, PixelFX poison-cloud, alcance longo Gabriel) + miss
		_check(lider.attack_windup_seconds >= 0.35, "9b. Líder possui windup suficiente para permitir esquiva/miss")
		_check(FileAccess.file_exists("res://assets/audio/sfx/gorducho_pum.wav"), "9b. SFX temático gorducho_pum.wav existe")
		_check(FileAccess.file_exists("res://assets/sprites/Efeitos/pixelfx/poison-cloud.png"), "9b. Arte PixelFX poison-cloud.png existe")
		player.global_position = lider.global_position + Vector2(-360.0, 0.0)
		var x_before_gas: float = player.global_position.x
		map8.call("trigger_leader_gas_attack", true)
		_check(lider.facing_direction > 0.0, "9b. Líder vira de costas para o jogador ao soltar o pum")
		_check(bool(map8.call("is_gas_cloud_active")), "9b. Ataque de gás do líder ativa nuvem")
		var cloud_node := map8.get_node_or_null("World/Props/LeaderGasCloud")
		_check(cloud_node != null and cloud_node.get_node_or_null("PixelFXPoisonCloud") is AnimatedSprite2D, "9b. Nuvem de gás usa AnimatedSprite2D do PixelFX")
		map8.call("_apply_gas_repulsion", 0.25)
		_check(player.global_position.x < x_before_gas, "9b. Nuvem de gás afasta inclusive Gabriel a distância")
		map8.call("_clear_gas_cloud")
		_check(not bool(map8.call("is_gas_cloud_active")), "9b. Nuvem de gás encerra corretamente")

		lider.health_component.take_damage(999.0)
		await process_frame
		_check(map8.call("is_combat_ended"), "10 & 11. Combate termina somente após derrota do Líder")

		# 12 & 13. Pós-combate: mictório, diálogo padrão no rodapé e animação PixelFX de xixi
		var exit8 := map8.get_node_or_null("ExitArea") as Area2D
		var siga8 := map8.get_node_or_null("SigaIndicator")
		var bubble := dlg.get("_bubble") as Control
		_check(exit8 == null or not exit8.monitoring, "12. ExitArea permanece desativada após o combate")
		_check(siga8 == null or not siga8.visible, "12. SigaIndicator permanece oculto após o combate")
		_check(bubble == null or not bubble.visible, "12. Nenhuma fala de inimigo exibida após o fim do combate")
		_check(map8.get_node_or_null("UrinalCutsceneTrigger") != null, "14. Gatilho do mictório ativado após derrotar o Líder")
		_check(FileAccess.file_exists("res://assets/audio/sfx/xixi_comanda.wav"), "14. SFX xixi_comanda.wav existe")
		_check(FileAccess.file_exists("res://assets/sprites/Efeitos/pixelfx/water-jet.png"), "14. Arte PixelFX water-jet.png existe")
		map8.call("start_urinal_sequence")
		await process_frame
		var dlg_layer := map8.get_node_or_null("UrinalFooterDialogue")
		_check(dlg_layer != null, "14. Caixa de diálogo padrão do rodapé exibida no mictório")
		map8.call("confirm_urinal_dialogue")
		await process_frame
		var comanda_node := player.get_node_or_null("PlayerComandaInHand") as Sprite2D
		_check(comanda_node != null and comanda_node.texture != null, "14. Jogador saca comanda.png antes do xixi")
		await create_timer(0.42).timeout
		var pee_stream := player.get_node_or_null("PixelFXPeeStream") as AnimatedSprite2D
		_check(pee_stream != null and pee_stream.rotation < 0.0, "14. Animação PixelFX em parábola mirando o mictório e a comanda")

	map8.queue_free()
	await process_frame
	_finish()


func _check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("  [OK] " + msg)
	else:
		failed += 1
		push_error("  [FALHA] " + msg)


func _finish() -> void:
	print("RESULTADO TESTE MAP 8: %d passaram, %d falharam" % [passed, failed])
	quit(0 if failed == 0 else 1)
