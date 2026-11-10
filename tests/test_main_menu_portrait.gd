extends SceneTree

# Teste Automatizado do Personagem Guilherme (idle.png) sendo Desenhado no Menu Principal
# Beat 'em Up Sakas

var passed: int = 0
var failed: int = 0

func _init() -> void:
	print("\n========================================================")
	print(" TESTE: GUILHERME (IDLE) SENDO DESENHADO NO MENU PRINCIPAL")
	print("========================================================\n")
	_run_tests()


func _run_tests() -> void:
	var menu_scene = ResourceLoader.load("res://scenes/ui/main_menu.tscn") as PackedScene
	_assert(menu_scene != null, "A cena main_menu.tscn deve ser carregada com sucesso")
	if menu_scene == null:
		_finish_test()
		return

	var menu = menu_scene.instantiate() as Control
	_assert(menu != null, "A cena main_menu.tscn deve ser instanciada sem erro")
	if menu == null:
		_finish_test()
		return

	root.add_child(menu)

	# 1. Verificação da inexistência de quadros ou textos antigos
	var old_card = menu.get_node_or_null("%HeroPortraitCard")
	_assert(old_card == null, "HeroPortraitCard antigo (com quadro) não deve existir")

	# 2. Verificação do sprite do personagem Guilherme (idle.png)
	var guilherme_char = menu.get_node_or_null("%GuilhermeDrawingCharacter") as TextureRect
	_assert(guilherme_char != null, "GuilhermeDrawingCharacter (%GuilhermeDrawingCharacter) deve existir no menu")
	if guilherme_char != null:
		_assert(guilherme_char.texture != null, "GuilhermeDrawingCharacter deve possuir textura associada")
		if guilherme_char.texture != null:
			var path = guilherme_char.texture.resource_path
			_assert("characters/guilherme/idle.png" in path, "Textura deve ser idle.png (atual: %s)" % path)
		_assert(guilherme_char.material != null, "GuilhermeDrawingCharacter deve possuir material associado")
		if guilherme_char.material is ShaderMaterial:
			var shader_mat = guilherme_char.material as ShaderMaterial
			_assert(shader_mat.shader != null, "Material deve conter o shader de desenho")
			var prog = shader_mat.get_shader_parameter("draw_progress")
			_assert(prog != null, "Shader parameter 'draw_progress' deve existir")
			print("  [INFO] draw_progress inicial: %s" % str(prog))

	# 3. Verificação de posicionamento: GuilhermeDrawingCharacter deve estar dentro de BrandColumn
	var brand_col = menu.get_node_or_null("MainLayout/ContentHBox/BrandColumn")
	_assert(brand_col != null, "BrandColumn deve existir no lado esquerdo do menu")
	if brand_col != null and guilherme_char != null:
		_assert(brand_col.is_ancestor_of(guilherme_char), "GuilhermeDrawingCharacter deve estar dentro de BrandColumn (lado esquerdo)")

	# 4. Verificação de botões e integridade funcional
	var btn_play = menu.get_node_or_null("%BtnPlay")
	var btn_continue = menu.get_node_or_null("%BtnContinue")
	var btn_settings = menu.get_node_or_null("%BtnSettings")
	var btn_quit = menu.get_node_or_null("%BtnQuit")
	_assert(btn_play != null, "Botão JOGAR deve existir")
	_assert(btn_continue != null, "Botão CONTINUAR deve existir")
	_assert(btn_settings != null, "Botão CONFIGURAÇÕES deve existir")
	_assert(btn_quit != null, "Botão SAIR deve existir")

	menu.queue_free()
	_finish_test()


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % message)
	else:
		failed += 1
		printerr("  [FAIL] %s" % message)


func _finish_test() -> void:
	print("\n========================================================")
	print(" RESULTADOS DOS TESTES:")
	print("   Passaram: %d" % passed)
	print("   Falharam: %d" % failed)
	print("========================================================\n")

	if failed == 0:
		print(">> TODOS OS TESTES PASSARAM COM SUCESSO! <<\n")
		quit(0)
	else:
		printerr(">> HOUVE FALHAS NOS TESTES! <<\n")
		quit(1)
