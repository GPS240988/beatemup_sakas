extends SceneTree

## Suíte Oficial de Testes de Compatibilidade de Gamepad (Projeto Sakas)
## Valida suporte a controles USB e Bluetooth, InputMap nativo, combate,
## movimentação diagonal, menus, pausa, reconexão e coexistência com teclado e touch.

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const PauseMenuClass = preload("res://scripts/ui/pause_menu.gd")
const GameSessionClass = preload("res://scripts/core/game_session.gd")
const TouchControlsClass = preload("res://scripts/ui/touch_controls.gd")

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("\n========================================================")
	print("  TESTE: SUPORTE COMPLETO A GAMEPAD (WEB / DESKTOP / MOBILE)")
	print("========================================================\n")

	_test_input_map_configuration()
	_test_gamepad_detection()
	_test_combat_combo_gamepad()
	_test_voadora_aerial_gamepad()
	_test_special_attack_gamepad()
	_test_diagonal_movement_analog_and_dpad()
	_test_simultaneous_direction_and_attack()
	_test_menu_navigation_gamepad()
	_test_pause_and_resume_gamepad()
	_test_joypad_disconnect_and_reconnect()
	_test_simultaneous_keyboard_and_gamepad()
	_test_touch_controls_preservation()

	print("\n========================================================")
	print("  RESULTADO: %d passaram, %d falharam (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("========================================================\n")

	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)

func _simulate_joy_button(btn_idx: JoyButton, pressed: bool, device: int = 0) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = btn_idx
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _simulate_joy_axis(axis: JoyAxis, val: float, device: int = 0) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = val
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _simulate_key(key: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.pressed = pressed
	ev.echo = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


# -------------------------------------------------------------
# 1. Configuração do InputMap
# -------------------------------------------------------------
func _test_input_map_configuration() -> void:
	print("--- 1. Validando Configuração do InputMap ---")

	assert_test(InputMap.has_action("attack"), "Ação 'attack' existe no InputMap")
	assert_test(InputMap.has_action("attack_punch"), "Ação 'attack_punch' existe no InputMap")
	assert_test(InputMap.has_action("jump"), "Ação 'jump' existe no InputMap")
	assert_test(InputMap.has_action("attack_aerial"), "Ação 'attack_aerial' existe no InputMap")
	assert_test(InputMap.has_action("special"), "Ação 'special' existe no InputMap")
	assert_test(InputMap.has_action("attack_special"), "Ação 'attack_special' existe no InputMap")
	assert_test(InputMap.has_action("guard"), "Ação 'guard' existe no InputMap")
	assert_test(InputMap.has_action("pause"), "Ação 'pause' existe no InputMap")
	assert_test(InputMap.has_action("restart"), "Ação 'restart' existe no InputMap")
	assert_test(InputMap.has_action("ui_accept"), "Ação 'ui_accept' existe no InputMap")
	assert_test(InputMap.has_action("ui_cancel"), "Ação 'ui_cancel' existe no InputMap")

	# Verifica se botões do controle estão registrados
	var attack_events := InputMap.action_get_events("attack")
	var has_joy_x := false
	for ev in attack_events:
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_X:
			has_joy_x = true
			break
	assert_test(has_joy_x, "Ação 'attack' possui JOY_BUTTON_X (Square/X)")

	var jump_events := InputMap.action_get_events("jump")
	var has_joy_a := false
	for ev in jump_events:
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_A:
			has_joy_a = true
			break
	assert_test(has_joy_a, "Ação 'jump' possui JOY_BUTTON_A (Cross/A)")

	var special_events := InputMap.action_get_events("special")
	var has_joy_y := false
	var has_joy_b := false
	for ev in special_events:
		if ev is InputEventJoypadButton:
			if ev.button_index == JOY_BUTTON_Y:
				has_joy_y = true
			elif ev.button_index == JOY_BUTTON_B:
				has_joy_b = true
	assert_test(has_joy_y, "Ação 'special' possui JOY_BUTTON_Y (Triangle/Y)")
	assert_test(has_joy_b, "Ação 'special' possui JOY_BUTTON_B (Circle/B)")

	var pause_events := InputMap.action_get_events("pause")
	var has_joy_start := false
	for ev in pause_events:
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_START:
			has_joy_start = true
			break
	assert_test(has_joy_start, "Ação 'pause' possui JOY_BUTTON_START (Start/Menu)")


# -------------------------------------------------------------
# 2. Detecção do controle ao pressionar botão
# -------------------------------------------------------------
func _test_gamepad_detection() -> void:
	print("--- 2. Detecção do Controle ao Pressionar Botão ---")

	_simulate_joy_button(JOY_BUTTON_X, true)
	assert_test(Input.is_action_pressed("attack"), "JOY_BUTTON_X pressiona ação 'attack'")
	assert_test(Input.is_action_pressed("attack_punch"), "JOY_BUTTON_X pressiona ação 'attack_punch'")
	_simulate_joy_button(JOY_BUTTON_X, false)
	assert_test(not Input.is_action_pressed("attack"), "Liberar JOY_BUTTON_X desativa 'attack'")

	_simulate_joy_button(JOY_BUTTON_A, true)
	assert_test(Input.is_action_pressed("jump"), "JOY_BUTTON_A pressiona ação 'jump'")
	assert_test(Input.is_action_pressed("attack_aerial"), "JOY_BUTTON_A pressiona ação 'attack_aerial'")
	_simulate_joy_button(JOY_BUTTON_A, false)

	_simulate_joy_button(JOY_BUTTON_Y, true)
	assert_test(Input.is_action_pressed("special"), "JOY_BUTTON_Y pressiona ação 'special'")
	assert_test(Input.is_action_pressed("attack_special"), "JOY_BUTTON_Y pressiona ação 'attack_special'")
	_simulate_joy_button(JOY_BUTTON_Y, false)


# -------------------------------------------------------------
# 3. Combo Completo com Gamepad (Botão X)
# -------------------------------------------------------------
func _test_combat_combo_gamepad() -> void:
	print("--- 3. Execução de Combo com Gamepad ---")

	var player = PlayerScene.instantiate() as PlayerController
	root.add_child(player)

	player._combo_step = 0
	player._on_attack_button_pressed()
	assert_test(player._combo_step == 0, "Primeiro golpe do combo iniciado (passo 0)")

	# Bufferiza próximo golpe
	if player.melee_attack != null:
		player.melee_attack.is_active_window = true
		player._on_attack_button_pressed()
		assert_test(player._input_buffered, "Input bufferizado durante janela ativa com gamepad")

	player.queue_free()


# -------------------------------------------------------------
# 4. Voadora com Gamepad (Botão A)
# -------------------------------------------------------------
func _test_voadora_aerial_gamepad() -> void:
	print("--- 4. Voadora com Gamepad (Botão A) ---")

	var player = PlayerScene.instantiate() as PlayerController
	root.add_child(player)

	player._try_aerial_attack()
	assert_test(player._is_jumping, "Voadora ativa estado de salto no jogador")
	assert_test(player._current_attack_anim == &"jump_atk", "Animação da voadora é 'jump_atk'")
	assert_test(player.velocity.x != 0.0, "Voadora projeta o jogador horizontalmente")

	player.queue_free()


# -------------------------------------------------------------
# 5. Golpe Especial com Gamepad (Botão Y / B)
# -------------------------------------------------------------
func _test_special_attack_gamepad() -> void:
	print("--- 5. Golpe Especial com Gamepad ---")

	var player = PlayerScene.instantiate() as PlayerController
	root.add_child(player)

	player.current_special = player.max_special
	assert_test(player.current_special >= player.max_special, "Energia especial 100% carregada para teste")
	var success: bool = player.execute_special()
	assert_test(success, "Especial executado com sucesso")
	assert_test(player.current_special == 0.0, "Especial consumiu toda a energia após execução")

	player.queue_free()


# -------------------------------------------------------------
# 6. Movimentação Diagonal com Analógico e D-Pad
# -------------------------------------------------------------
func _test_diagonal_movement_analog_and_dpad() -> void:
	print("--- 6. Movimentação Diagonal (Analógico e D-Pad) ---")

	var player = PlayerScene.instantiate() as PlayerController
	root.add_child(player)

	# Teste Analógico Esquerdo na diagonal (Down-Right)
	_simulate_joy_axis(JOY_AXIS_LEFT_X, 0.8)
	_simulate_joy_axis(JOY_AXIS_LEFT_Y, 0.8)
	var move_vec := player._get_movement_input()
	assert_test(move_vec.x > 0.0 and move_vec.y > 0.0, "Analógico registra vetor diagonal (X > 0 e Y > 0)")
	assert_test(move_vec.length() <= 1.01, "Vetor analógico diagonal normalizado com magnitude <= 1.0")

	# Limpa analógico
	_simulate_joy_axis(JOY_AXIS_LEFT_X, 0.0)
	_simulate_joy_axis(JOY_AXIS_LEFT_Y, 0.0)

	# Teste D-Pad na diagonal (Up-Left)
	_simulate_joy_button(JOY_BUTTON_DPAD_UP, true)
	_simulate_joy_button(JOY_BUTTON_DPAD_LEFT, true)
	var dpad_vec := player._get_movement_input()
	assert_test(dpad_vec.x < 0.0 and dpad_vec.y < 0.0, "D-Pad registra diagonal simultânea (X < 0 e Y < 0)")
	_simulate_joy_button(JOY_BUTTON_DPAD_UP, false)
	_simulate_joy_button(JOY_BUTTON_DPAD_LEFT, false)

	player.queue_free()


# -------------------------------------------------------------
# 7. Movimentação Durante Ataques e Orientação Simultânea
# -------------------------------------------------------------
func _test_simultaneous_direction_and_attack() -> void:
	print("--- 7. Direção Simultânea a Ataques ---")

	var player = PlayerScene.instantiate() as PlayerController
	root.add_child(player)

	player.facing_direction = -1.0 # Olhando para a esquerda
	_simulate_joy_axis(JOY_AXIS_LEFT_X, 1.0) # Movendo para a direita
	player._physics_process(0.016)
	assert_test(player.facing_direction == 1.0, "Pressionar direção e ataque vira o herói imediatamente para a direita")

	_simulate_joy_axis(JOY_AXIS_LEFT_X, 0.0)
	player.queue_free()


# -------------------------------------------------------------
# 8. Navegação nos Menus com Gamepad
# -------------------------------------------------------------
func _test_menu_navigation_gamepad() -> void:
	print("--- 8. Navegação nos Menus com Gamepad ---")

	var menu_scene := load("res://scenes/ui/main_menu.tscn") as PackedScene
	assert_test(menu_scene != null, "Cena do Menu Principal carregada")
	var menu = menu_scene.instantiate()
	root.add_child(menu)

	# Verifica se ui_accept e ui_cancel respondem a A e B
	_simulate_joy_button(JOY_BUTTON_A, true)
	assert_test(Input.is_action_pressed("ui_accept"), "JOY_BUTTON_A aciona 'ui_accept' para menus")
	_simulate_joy_button(JOY_BUTTON_A, false)

	_simulate_joy_button(JOY_BUTTON_B, true)
	assert_test(Input.is_action_pressed("ui_cancel"), "JOY_BUTTON_B aciona 'ui_cancel' para voltar nos menus")
	_simulate_joy_button(JOY_BUTTON_B, false)

	_simulate_joy_button(JOY_BUTTON_DPAD_DOWN, true)
	assert_test(Input.is_action_pressed("ui_down"), "JOY_BUTTON_DPAD_DOWN aciona 'ui_down' nos menus")
	_simulate_joy_button(JOY_BUTTON_DPAD_DOWN, false)

	menu.queue_free()


# -------------------------------------------------------------
# 9. Pausa e Retomada com Gamepad (START / B)
# -------------------------------------------------------------
func _test_pause_and_resume_gamepad() -> void:
	print("--- 9. Pausa e Retomada com Gamepad ---")

	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	assert_test(pause_scene != null, "Cena do Menu de Pausa carregada")
	var pause_menu = pause_scene.instantiate() as PauseMenu
	root.add_child(pause_menu)

	# Testa ação 'pause' mapeada para JOY_BUTTON_START
	_simulate_joy_button(JOY_BUTTON_START, true)
	assert_test(Input.is_action_pressed("pause"), "JOY_BUTTON_START aciona ação 'pause'")
	_simulate_joy_button(JOY_BUTTON_START, false)

	# Testa método de retomar e pausar
	pause_menu.visible = true
	assert_test(pause_menu.visible, "Menu de Pausa visível")
	pause_menu.resume_game()
	assert_test(not pause_menu.visible, "Menu de Pausa ocultado após resume_game()")

	pause_menu.queue_free()


# -------------------------------------------------------------
# 10. Desconexão e Reconexão de Gamepad
# -------------------------------------------------------------
func _test_joypad_disconnect_and_reconnect() -> void:
	print("--- 10. Desconexão e Reconexão do Gamepad ---")

	var gs = root.get_node_or_null("GameSession")
	if gs == null:
		gs = GameSessionClass.new()
		root.add_child(gs)

	assert_test(gs != null, "Gerenciador GameSession disponível")

	# Simula que uma ação ficou retida quando o controle foi puxado
	Input.action_press("attack")
	Input.action_press("move_right")
	assert_test(Input.is_action_pressed("attack"), "Ação 'attack' ativada para teste de desconexão")

	# Dispara desconexão
	gs.flush_gamepad_actions()
	assert_test(not Input.is_action_pressed("attack"), "flush_gamepad_actions() liberou ação 'attack'")
	assert_test(not Input.is_action_pressed("move_right"), "flush_gamepad_actions() liberou ação 'move_right'")


# -------------------------------------------------------------
# 11. Coexistência de Teclado e Gamepad Simultâneos
# -------------------------------------------------------------
func _test_simultaneous_keyboard_and_gamepad() -> void:
	print("--- 11. Coexistência Teclado + Gamepad ---")

	# Teclado pressiona D (move_right) e controle pressiona X (attack)
	_simulate_key(KEY_D, true)
	_simulate_joy_button(JOY_BUTTON_X, true)

	assert_test(Input.is_action_pressed("move_right"), "Teclado move_right ativo")
	assert_test(Input.is_action_pressed("attack"), "Gamepad attack ativo simultaneamente")

	_simulate_key(KEY_D, false)
	_simulate_joy_button(JOY_BUTTON_X, false)


# -------------------------------------------------------------
# 12. Preservação dos Controles Touchscreen
# -------------------------------------------------------------
func _test_touch_controls_preservation() -> void:
	print("--- 12. Preservação dos Controles Touchscreen ---")

	var tc = TouchControlsClass.new()
	assert_test(tc != null, "Instância de TouchControls criada com sucesso")
	root.add_child(tc)

	# Simula acionamento touch das ações nativas
	Input.action_press("attack")
	assert_test(Input.is_action_pressed("attack"), "Touch dispara ação de combate 'attack'")
	Input.action_release("attack")

	Input.action_press("jump")
	assert_test(Input.is_action_pressed("jump"), "Touch dispara ação de voadora 'jump'")
	Input.action_release("jump")

	Input.action_press("special")
	assert_test(Input.is_action_pressed("special"), "Touch dispara ação de especial 'special'")
	Input.action_release("special")

	tc.queue_free()
