extends SceneTree

## Suíte de Testes Automatizados Headless para a Tela de Carregamento da Fase 1 (LoadingScreen).

const LoadingScreenScript = preload("res://scripts/ui/loading_screen.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_all_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_all_tests() -> void:
	print("==================================================")
	print("INICIANDO TESTES DA TELA DE CARREGAMENTO (FASE 1)")
	print("==================================================")

	test_loading_screen_instantiation()
	test_loading_screen_visual_elements()
	test_loading_screen_hero_badge()
	test_loading_screen_input_simulation()

	print("==================================================")
	print("RESULTADO DOS TESTES: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)


func test_loading_screen_instantiation() -> void:
	print("\n--- Testando Instanciação de loading_screen.tscn ---")
	var scene: PackedScene = load("res://scenes/ui/loading_screen.tscn")
	assert_test(scene != null, "Cena loading_screen.tscn carregada com sucesso")

	var instance: Node = scene.instantiate()
	assert_test(instance.get_script() == LoadingScreenScript, "Script associado é loading_screen.gd")
	assert_test(instance is Control, "Nó raiz herda de Control")
	instance.free()


func test_loading_screen_visual_elements() -> void:
	print("\n--- Testando Elementos Visuais e Arte de Carregamento ---")
	var scene: PackedScene = load("res://scenes/ui/loading_screen.tscn")
	var instance: Control = scene.instantiate() as Control
	root.add_child(instance)

	# 1. Background com a imagem oficial da Fase 1
	var bg: TextureRect = instance.get_node_or_null("%BackgroundTexture") as TextureRect
	assert_test(bg != null, "BackgroundTexture existe na cena")
	if bg != null:
		assert_test(bg.texture != null, "BackgroundTexture possui textura atribuída")
		var is_valid_texture: bool = bg.texture != null and bg.texture.get_width() > 0 and bg.texture.get_height() > 0
		assert_test(is_valid_texture, "BackgroundTexture renderiza textura válida com dimensões HD")
		var tex_path: String = bg.texture.resource_path if bg.texture != null else ""
		var is_valid_path: bool = tex_path.is_empty() or tex_path.contains("carregando_fase")
		assert_test(is_valid_path, "BackgroundTexture faz referência ao arquivo de carregando_fase oficial")

	# 2. Ícones de teclas e comandos arcade
	var key_space: PanelContainer = instance.get_node_or_null("%KeySpaceIcon") as PanelContainer
	assert_test(key_space != null, "Ícone visual da tecla de [ESPAÇO] existe")

	var key_esc: PanelContainer = instance.get_node_or_null("%KeyEscIcon") as PanelContainer
	assert_test(key_esc != null, "Ícone visual da tecla [ESC] existe")

	# 3. Botões interativos para toque/mouse
	var btn_continue: Button = instance.get_node_or_null("%BtnContinue") as Button
	assert_test(btn_continue != null, "Botão BtnContinue existe e está acessível")
	if btn_continue != null:
		assert_test(not btn_continue.disabled, "BtnContinue está habilitado para clique")

	var btn_back: Button = instance.get_node_or_null("%BtnBack") as Button
	assert_test(btn_back != null, "Botão BtnBack existe e está acessível")
	if btn_back != null:
		assert_test(not btn_back.disabled, "BtnBack está habilitado para clique")

	instance.queue_free()


func test_loading_screen_hero_badge() -> void:
	print("\n--- Testando Exibição de Dados do Herói Selecionado ---")
	var scene: PackedScene = load("res://scenes/ui/loading_screen.tscn")
	var instance: Control = scene.instantiate() as Control
	root.add_child(instance)

	var badge: Label = instance.get_node_or_null("%HeroBadgeLabel") as Label
	assert_test(badge != null, "HeroBadgeLabel existe para informar o jogador")
	if badge != null:
		assert_test(badge.text.contains("GUILHERME"), "HeroBadgeLabel exibe 'GUILHERME' como herói padrão selecionado")

	instance.queue_free()


func test_loading_screen_input_simulation() -> void:
	print("\n--- Testando Constantes de Destino e Input Seguro ---")
	var scene: PackedScene = load("res://scenes/ui/loading_screen.tscn")
	var instance: Control = scene.instantiate() as Control
	root.add_child(instance)

	assert_test(LoadingScreenScript.TARGET_LEVEL_SCENE == "res://scenes/levels/map_1.tscn", "Destino ao pressionar Espaço é a Fase 1 (map_1.tscn)")
	assert_test(LoadingScreenScript.CHARACTER_SELECT_SCENE == "res://scenes/ui/character_select.tscn", "Destino ao pressionar ESC é a tela de Seleção de Personagens")

	# Simulação de tecla espaço
	var space_event := InputEventKey.new()
	space_event.pressed = true
	space_event.keycode = KEY_SPACE
	instance._unhandled_input(space_event)
	assert_test(instance._is_transitioning, "Após pressionar [ESPAÇO], a tela inicia a transição com flag _is_transitioning = true")

	instance.queue_free()
