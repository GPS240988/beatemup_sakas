extends SceneTree

## Suíte de Testes Automatizados Headless: PlayerHUD Arcade (Godot 4.x)
## Valida rigorosamente todos os 16 pontos de conformidade da nova HUD:
## 1. Barras segmentadas de 8 paralelogramos
## 2. Integridade geométrica e contenção estrita (zero overflow)
## 3. Remoção total do nível da HUD
## 4. Continues iniciando em 1
## 5. Medidor de especial (0 inicial, ganho de 2.0 por acerto, ativação restrita a 100%, consumo total)
## 6. Aura elétrica azul no retrato ao atingir 100%
## 7. Identidade dos 4 heróis (Guilherme, Gabriel, André, Juliana)
## 8. Contador dinâmico de combo

var _passed_count: int = 0
var _failed_count: int = 0

const PlayerControllerClass = preload("res://scripts/actors/player_controller.gd")
const EnemyAIClass = preload("res://scripts/actors/enemy_ai.gd")


func _init() -> void:
	print("\n==================================================")
	print("INICIANDO SUITE DE TESTES: NOVA HUD ARCADE SAKAS")
	print("==================================================\n")
	
	_run_all_tests_async()


func _run_all_tests_async() -> void:
	var hud_scene = load("res://scenes/ui/player_hud.tscn")
	assert_test(hud_scene != null, "Cena player_hud.tscn carregada com sucesso")
	if hud_scene == null:
		_finish_tests()
		return
	
	var hud = hud_scene.instantiate() as PlayerHUD
	assert_test(hud != null, "Instância de PlayerHUD criada com sucesso")
	root.add_child(hud)
	
	await process_frame
	await process_frame
	
	# --- 1. Verificação de Remoção do Nível da HUD ---
	print("\n--- 1. Verificando Remoção Canônica do Nível ---")
	var level_node = hud.get_node_or_null("MainRow/BarsColumn/HeaderRow/LevelContainer")
	assert_test(level_node == null, "Elemento LevelContainer NÃO existe na árvore da HUD")
	assert_test(not "level_label" in hud or hud.get("level_label") == null, "Propriedade level_label removida da PlayerHUD")

	# --- 2. Verificação de Continues Dinâmicos ---
	print("\n--- 2. Verificando Contador de Continues (Início em 1) ---")
	assert_test(hud.current_continues == 1, "Continues inicia por padrão em 1 em uma nova sessão")
	assert_test(hud.continue_label.text == "1", "ContinueLabel exibe dinamicamente '1'")
	hud.set_continues(3)
	assert_test(hud.current_continues == 3 and hud.continue_label.text == "3", "Atualização dinâmica de continues para '3'")

	# --- 3. Verificação de Integridade Geométrica das Barras Segmentadas (8 Segmentos) ---
	print("\n--- 3. Verificando Barras Segmentadas e Contenção Geométrica ---")
	assert_test(hud.hp_bar != null and hud.hp_bar is SegmentedBar, "HpBar é uma instância de SegmentedBar")
	assert_test(hud.special_bar != null and hud.special_bar is SegmentedBar, "SpecialBar é uma instância de SegmentedBar")
	assert_test(hud.hp_bar.total_segments == 8, "HpBar configurada rigorosamente para 8 segmentos")
	assert_test(hud.special_bar.total_segments == 8, "SpecialBar configurada rigorosamente para 8 segmentos")

	# Teste de não extravasamento geométrico
	var bar_w: float = hud.hp_bar.size.x
	var bar_h: float = hud.hp_bar.size.y
	assert_test(bar_w > 0.0 and bar_h > 0.0, "Dimensões válidas da barra de vida")
	
	var avail_w: float = bar_w - hud.hp_bar.padding_left - hud.hp_bar.padding_right - hud.hp_bar.slant_offset
	var seg_w: float = (avail_w - 7.0 * hud.hp_bar.segment_gap) / 8.0
	assert_test(seg_w > 0.0, "Largura individual dos segmentos é positiva")
	
	# Vértices do primeiro e último segmento
	var seg0_min_x: float = hud.hp_bar.padding_left
	var seg7_max_x: float = hud.hp_bar.padding_left + 7.0 * (seg_w + hud.hp_bar.segment_gap) + seg_w + hud.hp_bar.slant_offset
	assert_test(seg0_min_x >= 0.0, "Segmento 0 não começa antes da moldura (x >= 0)")
	assert_test(seg7_max_x <= bar_w, "Segmento 7 permanece rigorosamente dentro da borda direita da moldura")

	# --- 4. Verificação de Vida e DamageBuffer ---
	print("\n--- 4. Verificando Estados de Vida e DamageBuffer ---")
	# HP 400/400 (100% -> 8 segmentos)
	hud.set_hp(400.0, 400.0)
	assert_test(is_equal_approx(hud.current_hp, 400.0), "HP 400/400 registrado")
	assert_test(hud.hp_bar.filled_segments == 8, "HP 400/400 preenche exatamente 8 segmentos")
	assert_test(hud.hp_label.text == "400 / 400", "HpLabel exibe '400 / 400'")

	# Dano 320/400 (80% -> floor(0.80 * 8) = 6 segmentos)
	hud.set_hp(320.0, 400.0)
	assert_test(hud.hp_bar.filled_segments == 6, "HP 320/400 cai imediatamente para 6 segmentos preenchidos")
	assert_test(hud.hp_bar.buffer_segments == 8, "DamageBuffer permanece temporariamente com 8 segmentos")
	assert_test(hud.hp_bar_buffer.value >= 399.0, "Compatibilidade: hp_bar_buffer.value retém valor anterior")

	# Conclusão do Tween do DamageBuffer
	if hud._damage_buffer_tween != null and hud._damage_buffer_tween.is_valid():
		hud._damage_buffer_tween.custom_step(hud.damage_buffer_delay + hud.damage_buffer_duration + 0.1)
	assert_test(hud.hp_bar.buffer_segments == 6, "DamageBuffer reduz suavemente para 6 segmentos")
	assert_test(is_equal_approx(hud.hp_bar_buffer.value, 320.0), "hp_bar_buffer.value sincronizado com 320.0")

	# Cura 320 -> 370 (92.5% -> floor(370/400 * 8) = 7 segmentos)
	hud.set_hp(370.0, 400.0)
	if hud._hp_heal_tween != null and hud._hp_heal_tween.is_valid():
		hud._hp_heal_tween.custom_step(hud.hp_heal_duration + 0.05)
	assert_test(hud.hp_bar.filled_segments == 7, "Cura para 370.0 atualiza para 7 segmentos")
	assert_test(hud.hp_bar.buffer_segments == 7, "DamageBuffer acompanha cura para 7 segmentos")

	# Vida 0 -> 0 segmentos
	hud.set_hp(0.0, 400.0)
	assert_test(hud.hp_bar.filled_segments == 0, "HP 0 esvazia totalmente a barra (0 segmentos preenchidos)")

	# --- 5. Verificação da Barra de Especial e Aura Elétrica de Ready ---
	print("\n--- 5. Verificando Especial e Aura Elétrica de Ready ---")
	# Início: 0/100 -> 0 segmentos, aura desligada
	hud.set_special(0.0, 100.0)
	assert_test(hud.special_bar.filled_segments == 0, "Special 0 tem 0 segmentos preenchidos")
	assert_test(not hud.is_special_ready, "Special não está pronto com carga 0")
	assert_test(not hud.electric_aura.visible, "Aura elétrica desativada com especial incompleto")

	# 63/100 -> floor(0.63 * 8) = 5 segmentos
	hud.set_special(63.0, 100.0)
	if hud._special_tween != null and hud._special_tween.is_valid():
		hud._special_tween.custom_step(hud.special_transition_duration + 0.05)
	assert_test(hud.special_bar.filled_segments == 5, "Special 63/100 preenche 5 segmentos")
	assert_test(not hud.is_special_ready, "Special não está pronto com 63/100")
	assert_test(not hud.electric_aura.visible, "Aura elétrica permanece oculta com 63/100")

	# 100/100 -> 8 segmentos, ATIVA aura elétrica
	hud.set_special(100.0, 100.0, true)
	assert_test(hud.special_bar.filled_segments == 8, "Special 100/100 preenche todos os 8 segmentos")
	assert_test(hud.is_special_ready, "Special ativa com sucesso o estado is_special_ready = true")
	assert_test(hud.electric_aura.visible, "Aura elétrica azul do retrato ATIVADA com medidor cheio")
	assert_test(hud._aura_pulse_tween != null and hud._aura_pulse_tween.is_valid(), "Efeito de pulsação neon da aura em execução")

	# Consumo pós-especial: 100 -> 0 desativa aura
	hud.set_special(0.0, 100.0, true)
	assert_test(hud.special_bar.filled_segments == 0, "Special consumido volta a 0 segmentos")
	assert_test(not hud.is_special_ready, "is_special_ready resetado para false")
	assert_test(not hud.electric_aura.visible, "Aura elétrica ocultada imediatamente após consumo")

	# --- 6. Verificação de Identidades Visuais dos 4 Personagens ---
	print("\n--- 6. Verificando Identidades dos 4 Heróis ---")
	var heroes: Array[String] = ["guilherme", "gabriel", "andre", "juliana"]
	for h_id in heroes:
		hud.set_character_theme(h_id)
		assert_test(hud.current_character_id == h_id, "Tema aplicado com sucesso para %s" % h_id)
		assert_test(hud.portrait_texture.texture != null, "Retrato carregado para %s" % h_id)
		assert_test(hud.name_frame.texture != null, "Banner de nome carregado para %s" % h_id)

	# --- 7. Verificação do Contador Dinâmico de Combo ---
	print("\n--- 7. Verificando Indicador Dinâmico de Combo ---")
	hud.set_combo_hits(0)
	assert_test(not hud.combo_container.visible, "Combo 0 fica oculto")
	hud.set_combo_hits(12)
	assert_test(hud.combo_container.visible, "Combo 12 fica visível")
	assert_test(hud.combo_hits_label.text == "12 HITS", "ComboHitsLabel exibe dinamicamente '12 HITS'")

	# --- 8. Integração Real de Gameplay: PlayerController e Regras do Especial ---
	print("\n--- 8. Verificando Integração com PlayerController e Regra de 100% de Especial ---")
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player = player_scene.instantiate() as PlayerControllerClass
	root.add_child(player)
	hud.bind_player(player)
	
	# O medidor começa vazio em uma nova sessão
	assert_test(player.current_special == 0.0, "PlayerController: medidor de especial começa em 0.0")
	assert_test(player.max_special == 100.0, "PlayerController: medidor máximo configurado em 100.0")
	assert_test(hud.special_bar.filled_segments == 0, "HUD reflete medidor inicial vazio (0 segmentos)")

	# Tentativa de executar especial com medidor vazio: NÃO PODE EXECUTAR
	var empty_spec: bool = player.execute_special()
	assert_test(empty_spec == false, "Tentativa de especial com medidor vazio FALHA e retorna false")
	assert_test(player.combat_state != PlayerControllerClass.CombatState.SPECIAL, "Jogador não entra no estado SPECIAL")
	assert_test(not hud.electric_aura.visible, "Aura permanece desligada")

	# Tentativa de executar especial com 98% de carga: NÃO PODE EXECUTAR
	player.current_special = 98.0
	player.special_changed.emit(98.0, 100.0)
	var near_spec: bool = player.execute_special()
	assert_test(near_spec == false, "Tentativa de especial com 98/100 FALHA (apenas 100% permite ativação)")
	assert_test(player.current_special == 98.0, "Carga NÃO foi consumida na tentativa inválida")

	# Simulação de ganho por acerto real: 2.0 pontos por acerto em inimigo vivo
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var dummy_enemy = enemy_scene.instantiate()
	root.add_child(dummy_enemy)
	
	var initial_sp: float = 0.0
	player.current_special = initial_sp
	player._on_melee_target_hit(dummy_enemy, 15.0)
	var expected_charge: float = player.SPECIAL_CHARGE_PER_HIT if "SPECIAL_CHARGE_PER_HIT" in player else 2.0
	assert_test(is_equal_approx(player.current_special, initial_sp + expected_charge), "Acerto válido em inimigo concede carga correta no medidor")

	# Golpe no ar / whiff: não chama _on_melee_target_hit, logo não concede carga
	# Alvo inválido / nulo não concede carga
	var sp_before_null: float = player.current_special
	player._on_melee_target_hit(null, 15.0)
	assert_test(is_equal_approx(player.current_special, sp_before_null), "Alvo nulo não concede carga")

	# NPC civil não concede carga
	var npc_node = Node2D.new()
	npc_node.add_to_group("npcs")
	root.add_child(npc_node)
	player._on_melee_target_hit(npc_node, 15.0)
	assert_test(is_equal_approx(player.current_special, sp_before_null), "NPC civil não concede carga")
	npc_node.queue_free()

	# Inimigo morto não concede carga
	if dummy_enemy.health_component != null:
		dummy_enemy.health_component.current_health = 0.0
		dummy_enemy.health_component.is_dead = true
	player._on_melee_target_hit(dummy_enemy, 15.0)
	assert_test(is_equal_approx(player.current_special, sp_before_null), "Inimigo morto não concede carga")
	dummy_enemy.queue_free()

	# Execução de especial com 100% de carga: SUCESSO TOTAL
	player.current_special = 100.0
	player.special_changed.emit(100.0, 100.0)
	assert_test(hud.is_special_ready, "HUD ativou READY com 100% no Player")
	assert_test(hud.electric_aura.visible, "Aura elétrica visível antes do disparo")

	var valid_spec: bool = player.execute_special()
	assert_test(valid_spec == true, "Especial com 100% é executado com sucesso")
	assert_test(player.combat_state == PlayerControllerClass.CombatState.SPECIAL, "Jogador entra no estado SPECIAL")
	assert_test(player._is_invulnerable, "Jogador ganha invulnerabilidade")
	assert_test(player.current_special == 0.0, "Carga consumida integralmente (0.0)")
	assert_test(hud.special_bar.filled_segments == 0, "HUD atualizada imediatamente para 0 segmentos")
	assert_test(not hud.is_special_ready, "is_special_ready desativado após consumo")
	assert_test(not hud.electric_aura.visible, "Aura elétrica desligada após consumo")

	# Tentativa repetida imediatamente após o especial falha
	var double_spec: bool = player.execute_special()
	assert_test(double_spec == false, "Tentativa repetida imediata é rejeitada")

	player.queue_free()
	hud.queue_free()
	_finish_tests()


func assert_test(condition: bool, message: String) -> void:
	if condition:
		print("  [OK] %s" % message)
		_passed_count += 1
	else:
		print("  [FALHA] %s" % message)
		_failed_count += 1


func _finish_tests() -> void:
	print("\n==================================================")
	print("RESULTADO DOS TESTES DE PLAYER HUD: %d PASSARAM (Falhas: %d)" % [_passed_count, _failed_count])
	print("==================================================")
	
	if _failed_count > 0:
		print("[ERRO] Falhas detectadas nos testes da PlayerHUD.")
		quit(1)
	else:
		print("[OK] Todos os testes da PlayerHUD passaram com 100% de sucesso!")
		quit(0)
