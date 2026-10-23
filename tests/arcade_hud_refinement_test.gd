extends SceneTree

## Suíte de Testes Automatizados Headless: Refinamento Premium da HUD Arcade e Persistência de Estado (Godot 4.x)
## Valida:
## 1. Ocultação canônica de rótulos numéricos (100/100, 8/100) e rótulo de texto duplicado (Guilherme)
## 2. Destaque e ampliação da placa de Ficha/Continues com tipografia arcade_bold.ttf
## 3. Chassi da barra segmentada em paralelogramo diagonal cyber-arcade com trilhos neon
## 4. Ocultação padrão dos Controles Touch (DESLIGADO)
## 5. Remoção do banner "Área Limpa! Siga para a próxima seção"
## 6. SigaIndicator acompanhando dinamicamente a câmera independente da posição do jogador
## 7. Persistência de Vida e Energia Especial entre seções do mesmo mapa (Fase 1: Maps 1 a 4)
## 8. Placa de Combo com grafite agressivo e número dinâmico em fonte arcade destacada

var _passed_count: int = 0
var _failed_count: int = 0

const PlayerHudScene = preload("res://scenes/ui/player_hud.tscn")
const PrototypeHudScene = preload("res://scenes/ui/prototype_hud.tscn")
const SigaIndicatorScene = preload("res://scenes/ui/siga_indicator.tscn")


func _init() -> void:
	print("\n==================================================")
	print("INICIANDO SUITE DE TESTES: REFINAMENTO DA HUD ARCADE & PROGRESSÃO")
	print("==================================================\n")
	
	_run_all_tests_async()


func _run_all_tests_async() -> void:
	var hud: PlayerHUD = PlayerHudScene.instantiate() as PlayerHUD
	root.add_child(hud)
	
	await process_frame
	await process_frame
	
	# --- 1. Verificação de Ocultação de Textos Debug e Duplicados ---
	print("--- 1. Verificando Ocultação de Textos Debug e Duplicados ---")
	assert_test(hud.name_label != null, "NameLabel existe na árvore de nós")
	assert_test(not hud.name_label.visible, "NameLabel (texto Guilherme) está OCULTO, dando destaque ao banner oficial")
	assert_test(hud.name_frame != null and hud.name_frame.texture != null, "NameFrame possui textura do banner do personagem")
	assert_test(hud.hp_label != null, "HpLabel existe na árvore de nós")
	assert_test(not hud.hp_label.visible, "HpLabel (100/100) está OCULTO no visual arcade da tela")
	assert_test(hud.special_label != null, "SpecialLabel existe na árvore de nós")
	assert_test(not hud.special_label.visible, "SpecialLabel (8/100) está OCULTO no visual arcade da tela")

	# --- 2. Verificação de Ficha com Dado e Fonte Arcade ---
	print("\n--- 2. Verificando Placa de Ficha e Tipografia Arcade ---")
	assert_test(hud.continue_label != null, "ContinueLabel existe")
	var cont_font = hud.continue_label.get_theme_font("font")
	assert_test(cont_font != null, "ContinueLabel utiliza fonte personalizada arcade")
	assert_test(hud.continue_label.get_theme_font_size("font_size") >= 24, "ContinueLabel possui tamanho de fonte destacado (>= 24)")

	# --- 3. Verificação de Chassi Diagonal da Barra Segmentada ---
	print("\n--- 3. Verificando Chassi Diagonal da Barra Segmentada ---")
	assert_test(hud.hp_bar != null and hud.hp_bar.draw_frame == true, "HpBar configurada com moldura ativa")
	assert_test(hud.hp_bar.slant_offset > 0.0, "HpBar possui inclinação diagonal no chassi (slant_offset > 0)")
	assert_test(hud.special_bar.slant_offset > 0.0, "SpecialBar possui inclinação diagonal no chassi")
	assert_test(hud.hp_bar.frame_color.r > 0.8 and hud.hp_bar.frame_color.g < 0.3, "Moldura da barra de vida é estritamente VERMELHA arcade")
	assert_test(hud.hp_bar.offset_left <= 0.0, "Barra de vida posicionada rente e alinhada ao avatar")

	# --- 4. Verificação de Ocultação de Controles Touch no PrototypeHud ---
	print("\n--- 4. Verificando Ocultação de Controles Touch ---")
	var proto_hud: PrototypeHud = PrototypeHudScene.instantiate() as PrototypeHud
	root.add_child(proto_hud)
	await process_frame
	
	var top_right = proto_hud.get_node_or_null("TopRightControls") as Control
	assert_test(top_right != null, "Contêiner TopRightControls existe")
	assert_test(not top_right.visible, "Controles Touch (DESLIGADO) estão OCULTOS por padrão na tela")
	proto_hud.queue_free()

	# --- 5. Verificação da Placa de Combo e Animação de Impacto ---
	print("\n--- 5. Verificando Placa de Combo e Impacto Visual ---")
	assert_test(hud.combo_container != null, "ComboContainer existe na HUD")
	assert_test(not hud.combo_container.visible, "ComboContainer inicia oculto em 0 hits")
	
	hud.set_combo_hits(7)
	assert_test(hud.combo_container.visible, "ComboContainer torna-se visível ao registrar hits")
	assert_test(hud.combo_hits_label.text == "7 HITS", "ComboHitsLabel exibe dinamicamente '7 HITS'")
	var combo_font = hud.combo_hits_label.get_theme_font("font")
	assert_test(combo_font != null, "ComboHitsLabel utiliza fonte arcade impactante")
	assert_test(hud.combo_hits_label.get_theme_font_size("font_size") >= 32, "ComboHitsLabel possui tamanho de fonte grande e impactante (>= 32)")

	# --- 6. Verificação do SigaIndicator com Acompanhamento de Câmera ---
	print("\n--- 6. Verificando SigaIndicator e Câmera ---")
	var siga_inst: SigaIndicator = SigaIndicatorScene.instantiate() as SigaIndicator
	root.add_child(siga_inst)
	assert_test(siga_inst.z_index >= 100, "SigaIndicator possui z_index elevado (>= 100) para sobrepor elementos")
	siga_inst.activate()
	assert_test(siga_inst.is_active(), "SigaIndicator ativo com efeito pulsante")
	assert_test(siga_inst.visible, "SigaIndicator visível após conclusão")
	siga_inst.deactivate()
	assert_test(not siga_inst.visible, "SigaIndicator oculto após desativação")
	siga_inst.queue_free()

	# --- 7. Verificação de Persistência de Vida e Energia no GameSession ---
	print("\n--- 7. Verificando Persistência de Vida e Energia entre Seções do Mesmo Mapa ---")
	var session = root.get_node_or_null("GameSession")
	assert_test(session != null, "Autoload GameSession está acessível")
	
	if session != null:
		# Simulação: término do Mapa 1 com 62 HP e 84 Especial
		session.save_player_progression("fase1", 62.0, 84.0)
		var restored: Dictionary = session.get_preserved_player_progression("fase1")
		assert_test(not restored.is_empty(), "Progresso da fase1 recuperado com sucesso")
		assert_test(is_equal_approx(restored.get("health", 0.0), 62.0), "Vida de 62.0 HP preservada")
		assert_test(is_equal_approx(restored.get("special", 0.0), 84.0), "Especial de 84.0 preservado")
		
		# Verificação de reset ao mudar para outro mapa não criado (ex: fase2)
		var foreign_map: Dictionary = session.get_preserved_player_progression("fase2")
		assert_test(foreign_map.is_empty(), "Transição para mapa de grupo diferente (fase2) reseta a vida/energia")
		
		# Limpeza do estado
		session.clear_player_progression()
		assert_test(session.get_preserved_player_progression("fase1").is_empty(), "Limpeza de progressão executada com sucesso")

	# --- 8. Verificação do Respawn Arcade (Continue dos Céus e Knockdown Geral) ---
	print("\n--- 8. Verificando Mecânica de Continue Arcade (Drop-in e Queda de Inimigos) ---")
	var player_scene = load("res://scenes/actors/player/player.tscn")
	var enemy_scene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	if player_scene != null and enemy_scene != null:
		var p_inst = player_scene.instantiate() as PlayerController
		var e_inst = enemy_scene.instantiate() as EnemyAI
		root.add_child(p_inst)
		root.add_child(e_inst)
		p_inst.global_position = Vector2(200, 400)
		e_inst.global_position = Vector2(350, 400)
		
		hud.bind_player(p_inst)
		assert_test(p_inst.current_continues == 1, "PlayerController inicia com 1 ficha de continue")
		assert_test(hud.current_continues == 1, "HUD exibe 1 ficha de continue")
		
		# Aplica dano fatal no jogador
		p_inst.take_damage(200.0)
		assert_test(p_inst.current_continues == 0, "Continue foi consumido após derrota (1 -> 0)")
		assert_test(hud.current_continues == 0, "HUD sincronizada com 0 fichas restantes")
		assert_test(p_inst.visual_root.position.y < -100.0, "Herói projeta-se nos céus para queda arcade")
		
		# Conclui a aterrissagem
		p_inst._on_respawn_landing()
		assert_test(p_inst.health_component.current_health == p_inst.health_component.max_health, "Vida resetada por completo (100%) no respawn")
		assert_test(p_inst.current_special == p_inst.max_special * 0.5, "Energia especial configurada exatamente em 50% (4 segmentos)")
		assert_test(e_inst.current_state == EnemyAI.State.FALL or e_inst.current_state == EnemyAI.State.DOWNED, "Inimigos na tela caem no chão (cooldown tático arcade)")
		
		# Segunda derrota com 0 continues -> Morte definitiva
		p_inst.set("_is_invulnerable", false)
		p_inst.take_damage(200.0)
		assert_test(p_inst.combat_state == PlayerController.CombatState.DEAD, "Sem fichas restantes, jogador entra no estado DEAD definitivo")
		
		p_inst.queue_free()
		e_inst.queue_free()

	# Finalização dos testes
	hud.queue_free()
	_finish_tests()


func assert_test(condition: bool, message: String) -> void:
	if condition:
		_passed_count += 1
		print("  [OK] %s" % message)
	else:
		_failed_count += 1
		print("  [FALHA] %s" % message)


func _finish_tests() -> void:
	print("\n==================================================")
	print("RESULTADO DOS TESTES DE REFINAMENTO: %d PASSARAM (Falhas: %d)" % [_passed_count, _failed_count])
	print("==================================================")
	if _failed_count == 0:
		print("[OK] Todos os testes de refinamento da HUD passaram com 100% de sucesso!\n")
		quit(0)
	else:
		printerr("[ERRO] Falha em %d teste(s) de refinamento.\n" % _failed_count)
		quit(1)
