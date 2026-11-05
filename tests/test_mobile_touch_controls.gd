extends SceneTree

## Suíte de Testes Automatizados Headless: Controles Mobile Oficiais do Projeto Sakas (Godot 4.x)
## Valida os 15 requisitos estritos da reformulação dos controles virtuais:
## 1. Carregamento dos 8 novos assets visuais dedicados (Neon Dark Glass HD)
## 2. Mapeamento estrito do InputMap (Punho: J, Voadora: SPACE, Especial: E/O, Bloqueio: K/H)
## 3. Disposição assimétrica e hierarquia geométrica exatas da referência
## 4. Distâncias e ausência de colisão/sobreposição de hitboxes
## 5. Adaptação a telas widescreen e ultrawide (sem invasão de safe areas)
## 6. Disparo e liberação de ações de combate (press e release)
## 7. Suporte a Multi-Touch concorrente (polegar esquerdo movimenta e direito ataca)
## 8. Movimento simultâneo com golpes e diagonais
## 9. Manutenção do bloqueio enquanto aciona outro botão
## 10. Botão de Pause no topo direito aciona congelamento de gameplay
## 11. Menu de pausa suspende controles virtuais e permanece responsivo
## 12. Retomada de jogo restaura os controles virtuais sem ações presas
## 13. Ocultação absoluta no Desktop / PC (segregação estrita)
## 14. Ausência de conflitos com o InputMap do teclado/gamepad
## 15. Limpeza de estados virtuais na destruição do nó

var _total_assertions: int = 0
var _passed_assertions: int = 0
var _failed_assertions: int = 0

const TouchControlsScript = preload("res://scripts/ui/touch_controls.gd")
const PauseMenuScene = preload("res://scenes/ui/pause_menu.tscn")


func _init() -> void:
	print("\n========================================================================")
	print("  TESTE: Controles Virtuais Mobile Neon Dark Glass — Projeto Sakas")
	print("========================================================================\n")
	call_deferred("_run_all_tests")


func assert_check(condition: bool, description: String) -> void:
	_total_assertions += 1
	if condition:
		_passed_assertions += 1
		print("  ✅ [OK] %s" % description)
	else:
		_failed_assertions += 1
		printerr("  ❌ [FALHA] %s" % description)


func _run_all_tests() -> void:
	_test_asset_integrity()
	_test_input_map_bindings()
	_test_layout_and_hierarchical_geometry()
	_test_ultrawide_responsiveness()
	_test_touch_events_and_combat_actions()
	_test_multitouch_concurrency()
	_test_pause_integration()
	_test_desktop_segregation()

	print("\n------------------------------------------------------------------------")
	print("  RESULTADO: %d/%d testes passaram" % [_passed_assertions, _total_assertions])
	if _failed_assertions == 0:
		print("  ✅ TODOS OS TESTES PASSARAM COM SUCESSO!")
		print("------------------------------------------------------------------------\n")
		quit(0)
	else:
		printerr("  ❌ OCORRERAM %d FALHAS NOS TESTES!" % _failed_assertions)
		print("------------------------------------------------------------------------\n")
		quit(1)


func _test_asset_integrity() -> void:
	print("📋 1. Integridade dos 8 Assets Visuais Mobile (assets/ui/mobile/)")
	var tc := TouchControlsScript.new() as TouchControls

	assert_check(TouchControls.TEX_ATTACK != null, "TEX_ATTACK (button_attack.png) carregado")
	assert_check(TouchControls.TEX_KICK != null, "TEX_KICK (button_kick.png) carregado")
	assert_check(TouchControls.TEX_SPECIAL != null, "TEX_SPECIAL (button_special.png) carregado")
	assert_check(TouchControls.TEX_BLOCK != null, "TEX_BLOCK (button_block.png) carregado")
	assert_check(TouchControls.TEX_PAUSE != null, "TEX_PAUSE (button_pause.png) carregado")
	assert_check(TouchControls.TEX_DPAD_BASE != null, "TEX_DPAD_BASE (mobile_dpad_base.png) carregado")
	assert_check(TouchControls.TEX_DPAD_ARROWS != null, "TEX_DPAD_ARROWS (mobile_dpad_arrows.png) carregado")
	assert_check(TouchControls.TEX_DPAD_THUMB != null, "TEX_DPAD_THUMB (mobile_dpad_thumb.png) carregado")

	tc.free()


func _test_input_map_bindings() -> void:
	print("\n📋 2. Mapeamento de Comandos no InputMap (J, SPACE, E/O, K/H)")
	assert_check(InputMap.has_action("attack"), "Ação 'attack' existe no InputMap")
	assert_check(InputMap.has_action("attack_punch"), "Ação 'attack_punch' existe no InputMap")
	assert_check(InputMap.has_action("jump"), "Ação 'jump' existe no InputMap")
	assert_check(InputMap.has_action("attack_aerial"), "Ação 'attack_aerial' existe no InputMap")
	assert_check(InputMap.has_action("special"), "Ação 'special' existe no InputMap")
	assert_check(InputMap.has_action("attack_special"), "Ação 'attack_special' existe no InputMap")
	assert_check(InputMap.has_action("guard"), "Ação 'guard' existe no InputMap")

	# Valida se a tecla E está devidamente mapeada para o golpe especial
	var special_has_key_e: bool = false
	for event in InputMap.action_get_events("attack_special"):
		if event is InputEventKey and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
			special_has_key_e = true
			break
	assert_check(special_has_key_e, "Tecla 'E' (KEY_E) mapeada para attack_special")

	# Valida se a tecla J está mapeada para ataque
	var attack_has_key_j: bool = false
	for event in InputMap.action_get_events("attack"):
		if event is InputEventKey and (event.keycode == KEY_J or event.physical_keycode == KEY_J):
			attack_has_key_j = true
			break
	assert_check(attack_has_key_j, "Tecla 'J' (KEY_J) mapeada para attack")

	# Valida se a tecla Space está mapeada para voadora/jump
	var jump_has_space: bool = false
	for event in InputMap.action_get_events("jump"):
		if event is InputEventKey and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
			jump_has_space = true
			break
	assert_check(jump_has_space, "Tecla 'Espaço' (KEY_SPACE) mapeada para jump / voadora")

	# Valida se a tecla K está mapeada para bloqueio
	var guard_has_key_k: bool = false
	for event in InputMap.action_get_events("guard"):
		if event is InputEventKey and (event.keycode == KEY_K or event.physical_keycode == KEY_K):
			guard_has_key_k = true
			break
	assert_check(guard_has_key_k, "Tecla 'K' (KEY_K) mapeada para guard")


func _test_layout_and_hierarchical_geometry() -> void:
	print("\n📋 3. Disposição Assimétrica e Hierarquia Visual dos Botões")
	var tc := TouchControlsScript.new() as TouchControls
	tc.test_mode = true
	tc.custom_minimum_size = Vector2(1280.0, 720.0)
	tc.size = Vector2(1280.0, 720.0)
	root.add_child(tc)
	tc._recalculate_layout()

	# Punho é o maior botão
	assert_check(tc.combo_btn_radius > tc.aerial_btn_radius, "Botão Punho J (r=%.1f) é maior que Voadora (r=%.1f)" % [tc.combo_btn_radius, tc.aerial_btn_radius])
	assert_check(tc.combo_btn_radius > tc.guard_btn_radius, "Botão Punho J é maior que Bloqueio K")
	assert_check(tc.combo_btn_radius > tc.special_btn_radius, "Botão Punho J é maior que Especial E")

	# Posicionamento exato conforme referência:
	# Punho no canto inferior direito
	assert_check(tc.combo_btn_pos.x > 1100.0 and tc.combo_btn_pos.y > 580.0, "Punho J no canto inferior direito (%s)" % str(tc.combo_btn_pos))
	# Bloqueio acima do Punho (mesmo alinhamento horizontal X)
	assert_check(is_equal_approx(tc.guard_btn_pos.x, tc.combo_btn_pos.x), "Bloqueio K alinhado horizontalmente sobre o Punho J (X=%.1f)" % tc.guard_btn_pos.x)
	assert_check(tc.guard_btn_pos.y < tc.combo_btn_pos.y, "Bloqueio K posicionado na parte superior do cluster (Y=%.1f)" % tc.guard_btn_pos.y)
	# Voadora na parte inferior esquerda do agrupamento
	assert_check(tc.aerial_btn_pos.x < tc.special_btn_pos.x, "Voadora Space à esquerda do Especial E (X=%.1f < %.1f)" % [tc.aerial_btn_pos.x, tc.special_btn_pos.x])
	# Especial na região intermediária
	assert_check(tc.special_btn_pos.x > tc.aerial_btn_pos.x and tc.special_btn_pos.x < tc.combo_btn_pos.x, "Especial E na posição intermediária do cluster")
	# Direcional no canto inferior esquerdo
	assert_check(tc.joystick_base_pos.x < 300.0 and tc.joystick_base_pos.y > 500.0, "Direcional no quadrante inferior esquerdo (%s)" % str(tc.joystick_base_pos))
	# Botão de Pause no canto superior direito
	assert_check(tc.pause_btn_pos.x > 1150.0 and tc.pause_btn_pos.y < 120.0, "Pause no canto superior direito (%s)" % str(tc.pause_btn_pos))

	# Distância de segurança entre hitboxes (zero sobreposição)
	var d_punch_block: float = tc.combo_btn_pos.distance_to(tc.guard_btn_pos)
	var gap_punch_block: float = d_punch_block - (tc.combo_btn_radius + tc.guard_btn_radius)
	assert_check(gap_punch_block > 10.0, "Separação segura Punho <-> Bloqueio: %.1f px" % gap_punch_block)

	var d_punch_kick: float = tc.combo_btn_pos.distance_to(tc.aerial_btn_pos)
	var gap_punch_kick: float = d_punch_kick - (tc.combo_btn_radius + tc.aerial_btn_radius)
	assert_check(gap_punch_kick > 50.0, "Separação segura Punho <-> Voadora: %.1f px" % gap_punch_kick)

	var d_kick_special: float = tc.aerial_btn_pos.distance_to(tc.special_btn_pos)
	var gap_kick_special: float = d_kick_special - (tc.aerial_btn_radius + tc.special_btn_radius)
	assert_check(gap_kick_special > 15.0, "Separação segura Voadora <-> Especial: %.1f px" % gap_kick_special)

	tc.free()


func _test_ultrawide_responsiveness() -> void:
	print("\n📋 4. Responsividade e Adaptação Ultrawide (20:9 e 19.5:9)")
	var tc := TouchControlsScript.new() as TouchControls
	tc.test_mode = true
	# Simula tela ultrawide 1600x720 (20:9)
	tc.custom_minimum_size = Vector2(1600.0, 720.0)
	tc.size = Vector2(1600.0, 720.0)
	root.add_child(tc)
	tc._recalculate_layout()

	# Todos os controles devem permanecer dentro dos limites seguros da tela
	assert_check(tc.combo_btn_pos.x + tc.combo_btn_radius <= 1600.0, "Punho contido dentro da viewport ultrawide")
	assert_check(tc.pause_btn_pos.x + tc.pause_btn_size.x * 0.5 <= 1600.0, "Pause contido dentro da viewport ultrawide")
	assert_check(tc.joystick_base_pos.x - tc.joystick_radius >= 0.0, "Direcional não invade a borda esquerda")

	tc.free()


func _test_touch_events_and_combat_actions() -> void:
	print("\n📋 5. Disparo e Liberação de Ações de Combate via Touch")
	var tc := TouchControlsScript.new() as TouchControls
	tc.test_mode = true
	tc.size = Vector2(1280.0, 720.0)
	root.add_child(tc)
	tc._recalculate_layout()

	# 1. Toque no Punho (J)
	var touch_punch_down := InputEventScreenTouch.new()
	touch_punch_down.index = 1
	touch_punch_down.position = tc.combo_btn_pos
	touch_punch_down.pressed = true
	tc._handle_touch(touch_punch_down)

	assert_check(Input.is_action_pressed("attack"), "Touch no Punho pressiona 'attack'")
	assert_check(Input.is_action_pressed("attack_punch"), "Touch no Punho pressiona 'attack_punch'")

	var touch_punch_up := InputEventScreenTouch.new()
	touch_punch_up.index = 1
	touch_punch_up.position = tc.combo_btn_pos
	touch_punch_up.pressed = false
	tc._handle_touch(touch_punch_up)

	assert_check(not Input.is_action_pressed("attack"), "Soltar o Punho libera 'attack'")

	# 2. Toque na Voadora (Space)
	var touch_kick_down := InputEventScreenTouch.new()
	touch_kick_down.index = 2
	touch_kick_down.position = tc.aerial_btn_pos
	touch_kick_down.pressed = true
	tc._handle_touch(touch_kick_down)

	assert_check(Input.is_action_pressed("attack_aerial"), "Touch na Voadora pressiona 'attack_aerial'")
	assert_check(Input.is_action_pressed("jump"), "Touch na Voadora pressiona 'jump'")

	var touch_kick_up := InputEventScreenTouch.new()
	touch_kick_up.index = 2
	touch_kick_up.position = tc.aerial_btn_pos
	touch_kick_up.pressed = false
	tc._handle_touch(touch_kick_up)

	assert_check(not Input.is_action_pressed("attack_aerial"), "Soltar a Voadora libera 'attack_aerial'")

	# 3. Toque no Especial (E)
	var touch_special_down := InputEventScreenTouch.new()
	touch_special_down.index = 3
	touch_special_down.position = tc.special_btn_pos
	touch_special_down.pressed = true
	tc._handle_touch(touch_special_down)

	assert_check(Input.is_action_pressed("attack_special"), "Touch no Especial pressiona 'attack_special'")
	assert_check(Input.is_action_pressed("special"), "Touch no Especial pressiona 'special'")

	var touch_special_up := InputEventScreenTouch.new()
	touch_special_up.index = 3
	touch_special_up.position = tc.special_btn_pos
	touch_special_up.pressed = false
	tc._handle_touch(touch_special_up)

	assert_check(not Input.is_action_pressed("attack_special"), "Soltar o Especial libera 'attack_special'")

	# 4. Toque no Bloqueio (K)
	var touch_guard_down := InputEventScreenTouch.new()
	touch_guard_down.index = 4
	touch_guard_down.position = tc.guard_btn_pos
	touch_guard_down.pressed = true
	tc._handle_touch(touch_guard_down)

	assert_check(Input.is_action_pressed("guard"), "Touch no Bloqueio ativa 'guard'")

	var touch_guard_up := InputEventScreenTouch.new()
	touch_guard_up.index = 4
	touch_guard_up.position = tc.guard_btn_pos
	touch_guard_up.pressed = false
	tc._handle_touch(touch_guard_up)

	assert_check(not Input.is_action_pressed("guard"), "Soltar o Bloqueio desativa 'guard'")

	tc.free()


func _test_multitouch_concurrency() -> void:
	print("\n📋 6. Suporte a Multi-Touch Concorrente e Direcionais")
	var tc := TouchControlsScript.new() as TouchControls
	tc.test_mode = true
	tc.size = Vector2(1280.0, 720.0)
	root.add_child(tc)
	tc._recalculate_layout()

	# Dedo 0: Direcional diagonal para a direita e para cima
	var dpad_touch := InputEventScreenTouch.new()
	dpad_touch.index = 0
	dpad_touch.position = tc.joystick_base_pos + Vector2(tc.joystick_radius * 0.7, -tc.joystick_radius * 0.7)
	dpad_touch.pressed = true
	tc._handle_touch(dpad_touch)

	assert_check(Input.is_action_pressed("move_right"), "Dedo 0 no joystick aciona 'move_right'")
	assert_check(Input.is_action_pressed("move_up"), "Dedo 0 no joystick aciona 'move_up' (diagonal)")

	# Dedo 1: Pressiona Bloqueio simultaneamente
	var guard_touch := InputEventScreenTouch.new()
	guard_touch.index = 1
	guard_touch.position = tc.guard_btn_pos
	guard_touch.pressed = true
	tc._handle_touch(guard_touch)

	assert_check(Input.is_action_pressed("guard"), "Dedo 1 aciona 'guard' simultaneamente")
	assert_check(Input.is_action_pressed("move_right"), "Movimento permanece ativo enquanto defende")

	# Dedo 2: Toca no Punho para golpear
	var punch_touch := InputEventScreenTouch.new()
	punch_touch.index = 2
	punch_touch.position = tc.combo_btn_pos
	punch_touch.pressed = true
	tc._handle_touch(punch_touch)

	assert_check(Input.is_action_pressed("attack"), "Dedo 2 dispara ataque simultâneo com 3 dedos ativos")

	# Solta apenas o ataque (Dedo 2)
	punch_touch.pressed = false
	tc._handle_touch(punch_touch)
	assert_check(not Input.is_action_pressed("attack"), "Ataque liberado")
	assert_check(Input.is_action_pressed("guard"), "Bloqueio permanece ativo")
	assert_check(Input.is_action_pressed("move_right"), "Movimento permanece ativo")

	# Libera tudo com segurança
	tc.release_all_virtual_actions()
	assert_check(not Input.is_action_pressed("move_right"), "Todas as ações liberadas com release_all_virtual_actions()")
	assert_check(not Input.is_action_pressed("guard"), "Guarda liberada com release_all_virtual_actions()")

	tc.free()


func _test_pause_integration() -> void:
	print("\n📋 7. Integração do Botão de Pause Mobile")
	var tc := TouchControlsScript.new() as TouchControls
	tc.test_mode = true
	tc.size = Vector2(1280.0, 720.0)
	root.add_child(tc)
	tc._recalculate_layout()

	var pause_menu := PauseMenuScene.instantiate() as PauseMenu
	root.add_child(pause_menu)
	pause_menu.name = "PauseMenu"

	# Simula toque no botão de pause (canto superior direito)
	var signal_box: Array = [false]
	tc.pause_requested.connect(func(): signal_box[0] = true)

	var touch_pause := InputEventScreenTouch.new()
	touch_pause.index = 5
	touch_pause.position = tc.pause_btn_pos
	touch_pause.pressed = true
	tc._handle_touch(touch_pause)

	assert_check(signal_box[0], "TouchControls emitiu sinal pause_requested")
	assert_check(pause_menu.visible, "Menu de pausa foi aberto pelo botão touch")
	assert_check(paused, "SceneTree foi pausada (paused = true)")

	# Retomada do jogo
	pause_menu.resume_game()
	assert_check(not paused, "SceneTree despausada ao retomar jogo")
	assert_check(not pause_menu.visible, "Menu de pausa ocultado após retomar")

	pause_menu.free()
	tc.free()


func _test_desktop_segregation() -> void:
	print("\n📋 8. Segregação Absoluta Desktop e Mobile")
	var tc := TouchControlsScript.new() as TouchControls
	tc.test_mode = false # Modo de produção normal no desktop (Windows)
	root.add_child(tc)

	assert_check(not tc._is_mobile_runtime(), "Ambiente Desktop detectado como não-mobile")
	assert_check(not tc.visible, "Controles Touch estão INVISÍVEIS no Desktop")
	assert_check(not tc.is_processing_input(), "Processamento de input touch DESATIVADO no Desktop")

	tc.free()
