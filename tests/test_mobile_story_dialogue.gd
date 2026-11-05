extends SceneTree

## Suíte de Testes Automatizados — Padronização de Diálogos Story Mobile & Mecânica CENA 05
## Godot Engine 4.7.2 | Project Sakas

const TEST_SEQUENCE_PATH: String = "res://resources/story/story_intro_map1.tres"
const ARCADE_FONT_PATH: String = "res://assets/fonts/arcade_bold.ttf"

var _passed_count: int = 0
var _failed_count: int = 0


func _init() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: STORY MOBILE DIALOGUE & CENA 05")
	print("==================================================")
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	await test_mobile_avatar_standardization()
	await test_mobile_typography_standardization()
	await test_mobile_layout_and_advance_button()
	await test_mobile_cena05_arcade_machine_touch_mechanics()
	await test_desktop_isolation_unaltered()

	print("==================================================")
	print("RESULTADO DOS TESTES STORY MOBILE: %d/%d PASSARAM (Falhas: %d)" % [
		_passed_count,
		_passed_count + _failed_count,
		_failed_count
	])
	print("==================================================")

	if _failed_count > 0:
		quit(1)
	else:
		quit(0)


func assert_test(condition: bool, description: String) -> void:
	if condition:
		_passed_count += 1
		print("  [OK] %s" % description)
	else:
		_failed_count += 1
		printerr("  [FALHA] %s" % description)


func test_mobile_avatar_standardization() -> void:
	print("\n--- 1. Validando Padronização do Avatar Mobile (88x88 px, Pixel Art HD) ---")
	var director_scene: PackedScene = load("res://scenes/ui/narrative_director.tscn")
	var nar = director_scene.instantiate()
	nar.force_mobile_for_test = true
	root.add_child(nar)

	var sequence: Resource = load(TEST_SEQUENCE_PATH)
	nar.current_sequence = sequence
	nar.current_event_index = 1 # CENA 02 - the_four
	nar.current_text_index = 0
	nar.is_playing = true
	nar._is_transitioning = false

	var events: Array = sequence.get("events")
	var ev: Resource = events[1]
	nar._show_current_text_block(ev)

	var portrait: TextureRect = nar.get_node_or_null("%SpeakerPortrait")
	if portrait == null: portrait = nar._speaker_portrait
	assert_test(portrait != null, "SpeakerPortrait existe na cena")
	if portrait != null:
		assert_test(
			portrait.custom_minimum_size == Vector2(88, 88),
			"Avatar mobile possui dimensão canônica 88x88 px (StandardDialogueBox)"
		)
		assert_test(
			portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Avatar mobile utiliza TEXTURE_FILTER_NEAREST para nitidez de Pixel Art HD"
		)
		assert_test(
			portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
			"Avatar mobile utiliza STRETCH_KEEP_ASPECT_CENTERED evitando distorção"
		)
		assert_test(
			portrait.expand_mode == TextureRect.EXPAND_IGNORE_SIZE,
			"Avatar mobile utiliza EXPAND_IGNORE_SIZE para controle estrito de tamanho"
		)

	nar.skip_sequence()
	root.remove_child(nar)
	nar.free()


func test_mobile_typography_standardization() -> void:
	print("\n--- 2. Validando Tipografia Canônica Arcade Mobile ---")
	var director_scene: PackedScene = load("res://scenes/ui/narrative_director.tscn")
	var nar = director_scene.instantiate()
	nar.force_mobile_for_test = true
	root.add_child(nar)

	var sequence: Resource = load(TEST_SEQUENCE_PATH)
	nar.current_sequence = sequence
	nar.current_event_index = 1 # CENA 02
	nar.current_text_index = 0
	nar.is_playing = true
	nar._is_transitioning = false

	var events: Array = sequence.get("events")
	var ev: Resource = events[1]
	nar._show_current_text_block(ev)

	var spk_label: Label = nar.get_node_or_null("%SpeakerLabel")
	if spk_label == null: spk_label = nar._speaker_label
	assert_test(spk_label != null, "SpeakerLabel existe na cena")
	if spk_label != null:
		var s_settings: LabelSettings = spk_label.label_settings
		assert_test(s_settings != null, "SpeakerLabel possui LabelSettings aplicado")
		if s_settings != null:
			assert_test(s_settings.font_size == 36, "Nome do personagem possui tamanho 36px no mobile")
			assert_test(
				s_settings.font_color.is_equal_approx(Color(0.94, 0.75, 0.39, 1.0)),
				"Nome do personagem possui cor dourada oficial (#EFBF63)"
			)
			assert_test(s_settings.outline_size == 4, "Nome do personagem possui contorno de 4px")
			assert_test(s_settings.shadow_size == 2, "Nome do personagem possui sombra de 2px")

	var dlg_label: Label = nar.get_node_or_null("%DialogueLabel")
	if dlg_label == null: dlg_label = nar._dialogue_label
	assert_test(dlg_label != null, "DialogueLabel existe na cena")
	if dlg_label != null:
		var d_settings: LabelSettings = dlg_label.label_settings
		assert_test(d_settings != null, "DialogueLabel possui LabelSettings aplicado")
		if d_settings != null:
			assert_test(d_settings.font_size == 34, "Texto de diálogo possui tamanho 34px no mobile")
			assert_test(
				d_settings.font_color.is_equal_approx(Color(0.96, 0.95, 0.90, 1.0)),
				"Texto de diálogo possui cor creme oficial (#F5F2E6)"
			)
			assert_test(d_settings.outline_size == 3, "Texto de diálogo possui contorno de 3px")
			assert_test(d_settings.shadow_size == 2, "Texto de diálogo possui sombra de 2px")
			assert_test(d_settings.line_spacing == 8, "Texto de diálogo possui espaçamento entre linhas de 8px")
		assert_test(
			dlg_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
			"DialogueLabel utiliza quebra de linha inteligente AUTOWRAP_WORD_SMART"
		)

	nar.skip_sequence()
	root.remove_child(nar)
	nar.free()


func test_mobile_layout_and_advance_button() -> void:
	print("\n--- 3. Validando Layout, Enquadramento e Botão Avançar Mobile ---")
	var director_scene: PackedScene = load("res://scenes/ui/narrative_director.tscn")
	var nar = director_scene.instantiate()
	nar.force_mobile_for_test = true
	root.add_child(nar)

	var sequence: Resource = load(TEST_SEQUENCE_PATH)
	nar.current_sequence = sequence
	nar.current_event_index = 1 # CENA 02
	nar.current_text_index = 0
	nar.is_playing = true
	nar._is_transitioning = false

	var events: Array = sequence.get("events")
	var ev: Resource = events[1]
	nar._show_current_text_block(ev)
	nar._apply_responsive_layout()

	var dialogue_area: MarginContainer = nar.get_node_or_null("%DialogueArea")
	assert_test(dialogue_area != null, "DialogueArea existe")
	if dialogue_area != null:
		assert_test(dialogue_area.anchor_top <= 0.65, "Painel mobile possui anchor_top generoso (<= 0.65)")
		assert_test(dialogue_area.anchor_bottom >= 0.98, "Painel mobile está ancorado próximo ao fundo (>= 0.98)")

	var btn_adv: Button = nar.get_node_or_null("%BtnMobileAdvance")
	if btn_adv == null: btn_adv = nar._btn_mobile_advance
	assert_test(btn_adv != null, "BtnMobileAdvance existe")
	if btn_adv != null:
		assert_test(btn_adv.visible == true, "BtnMobileAdvance está visível no modo mobile")
		assert_test(btn_adv.text == "AVANÇAR", "BtnMobileAdvance exibe texto 'AVANÇAR'")
		assert_test(
			btn_adv.custom_minimum_size.x >= 140.0 and btn_adv.custom_minimum_size.y >= 38.0,
			"BtnMobileAdvance possui touch target adequado para toque (>= 140x38 px)"
		)

	var desktop_prompt: HBoxContainer = nar.get_node_or_null("%AdvancePromptBox")
	if desktop_prompt != null:
		assert_test(
			desktop_prompt.visible == false,
			"Caixa de tecla ENTER de desktop está oculta no modo mobile"
		)

	nar.skip_sequence()
	root.remove_child(nar)
	nar.free()


func test_mobile_cena05_arcade_machine_touch_mechanics() -> void:
	print("\n--- 4. Validando CENA 05 (A Máquina CRT): Toque Exclusivo no Monitor ---")
	var director_scene: PackedScene = load("res://scenes/ui/narrative_director.tscn")
	var nar = director_scene.instantiate()
	nar.force_mobile_for_test = true
	root.add_child(nar)

	var sequence: Resource = load(TEST_SEQUENCE_PATH)
	nar.current_sequence = sequence
	nar.current_event_index = 4 # CENA 05 - arcade_machine
	nar.current_text_index = 0
	nar.is_playing = true
	nar._is_transitioning = false

	var events: Array = sequence.get("events")
	var ev_c5: Resource = events[4]
	nar._show_current_text_block(ev_c5)

	# 1. Botões genéricos DEVEM estar ocultos na CENA 05 mobile
	var btn_adv: Button = nar.get_node_or_null("%BtnMobileAdvance")
	if btn_adv == null: btn_adv = nar._btn_mobile_advance
	if btn_adv != null:
		assert_test(btn_adv.visible == false, "BtnMobileAdvance está oculto na CENA 05")

	var mob_rev_btn: Button = nar.get_node_or_null("MobileScreenAction_AVANÇAR")
	if mob_rev_btn != null:
		assert_test(mob_rev_btn.visible == false, "Botão genérico MobileScreenAction está oculto na CENA 05")

	var dialogue_area: MarginContainer = nar.get_node_or_null("%DialogueArea")
	if dialogue_area != null:
		assert_test(dialogue_area.visible == false, "Moldura de diálogo externa está oculta na CENA 05")

	# 2. Botão CRT CONTINUE deve existir
	var crt_btn: Button = nar.get_node_or_null("CRTContinueButton")
	if crt_btn == null:
		crt_btn = nar.find_child("CRTContinueButton", true, false) as Button
	assert_test(crt_btn != null, "Botão interativo CRTContinueButton existe na árvore CRT")

	if crt_btn != null:
		crt_btn.visible = true
		crt_btn.disabled = false
		assert_test(crt_btn.text == "CONTINUE?", "Botão CRT exibe texto 'CONTINUE?'")

		# 3. Toques gerais na tela NÃO avançam a CENA 05
		var initial_event = nar.current_event_index
		var dummy_touch := InputEventScreenTouch.new()
		dummy_touch.pressed = true
		dummy_touch.position = Vector2(100, 100)
		nar._on_root_gui_input(dummy_touch)
		nar._unhandled_input(dummy_touch)

		assert_test(
			nar.current_event_index == initial_event,
			"Toque geral fora do monitor CRT NÃO avançou a CENA 05"
		)

		# 4. Toque no botão CRT avança para a CENA 06
		nar._on_crt_continue_button_pressed()
		assert_test(
			nar.current_event_index == initial_event + 1,
			"Toque no botão CRT CONTINUE avançou para a CENA 06 com sucesso"
		)

		# 5. Proteção contra duplo clique: nova chamada imediata não duplica transição
		nar._on_crt_continue_button_pressed()
		assert_test(
			nar.current_event_index == initial_event + 1,
			"Proteção contra duplo clique/multitoque ativa e funcionando"
		)

	nar.skip_sequence()
	root.remove_child(nar)
	nar.free()


func test_desktop_isolation_unaltered() -> void:
	print("\n--- 5. Validando Isolamento Desktop (100% Inalterado) ---")
	var director_scene: PackedScene = load("res://scenes/ui/narrative_director.tscn")
	var nar = director_scene.instantiate()
	nar.force_mobile_for_test = false
	root.add_child(nar)

	assert_test(nar._is_mobile_runtime() == false, "_is_mobile_runtime() é false para execução desktop padrão")

	var sequence: Resource = load(TEST_SEQUENCE_PATH)
	nar.current_sequence = sequence
	nar.current_event_index = 1 # CENA 02
	nar.current_text_index = 0
	nar.is_playing = true
	nar._is_transitioning = false

	var events: Array = sequence.get("events")
	var ev: Resource = events[1]
	nar._show_current_text_block(ev)

	var btn_adv: Button = nar.get_node_or_null("%BtnMobileAdvance")
	if btn_adv == null: btn_adv = nar._btn_mobile_advance
	if btn_adv != null:
		assert_test(btn_adv.visible == false, "BtnMobileAdvance permanece oculto no Desktop")

	var desktop_prompt: HBoxContainer = nar.get_node_or_null("%AdvancePromptBox")
	if desktop_prompt != null:
		assert_test(desktop_prompt.visible == true, "Prompt de ENTER de desktop permanece visível no Desktop")

	var crt_btn: Button = nar.find_child("CRTContinueButton", true, false) as Button
	if crt_btn != null:
		assert_test(crt_btn.visible == false, "Botão touch CRT permanece invisível no Desktop")

	nar.skip_sequence()
	root.remove_child(nar)
	nar.free()
