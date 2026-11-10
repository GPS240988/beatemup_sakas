extends SceneTree

# Teste de Transição da TitleScreen para MainMenu

var passed: int = 0
var failed: int = 0

func _init() -> void:
	print("\n========================================================")
	print(" TESTE: TRANSIÇÃO TITLE_SCREEN -> MAIN_MENU")
	print("========================================================\n")
	_run_tests()


func _run_tests() -> void:
	var title_scene = ResourceLoader.load("res://scenes/ui/title_screen.tscn") as PackedScene
	_assert(title_scene != null, "A cena title_screen.tscn deve carregar com sucesso")
	if title_scene == null:
		_finish_test()
		return

	var title_inst = title_scene.instantiate() as Control
	_assert(title_inst != null, "A cena title_screen.tscn deve instanciar com sucesso")
	root.add_child(title_inst)

	var menu_scene = ResourceLoader.load("res://scenes/ui/main_menu.tscn") as PackedScene
	_assert(menu_scene != null, "A cena main_menu.tscn referenciada pela TitleScreen deve carregar sem erros")
	if menu_scene != null:
		var menu_inst = menu_scene.instantiate() as Control
		_assert(menu_inst != null, "A cena main_menu.tscn deve instanciar perfeitamente")
		var guilherme = menu_inst.get_node_or_null("%GuilhermeDrawingCharacter")
		_assert(guilherme != null, "GuilhermeDrawingCharacter deve estar presente")
		menu_inst.queue_free()

	title_inst.queue_free()
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

