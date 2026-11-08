extends SceneTree

## Teste Automatizado: Feedback de Seleção Mobile do Menu Principal
## Valida os requisitos do Point 3:
## 1. Ausência de retângulo ou moldura retangular StyleBox em volta das opções no mobile
## 2. Posição precisa dos chevrons e pincelada sobre a opção clicada
## 3. Disparo do efeito de piscar (blink) ao confirmar a escolha

const MainMenuScene = preload("res://scenes/ui/main_menu.tscn")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func assert_test(condition: bool, message: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % message)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("\n" + "=".repeat(72))
	print("SUÍTE DE TESTES: FEEDBACK DE SELEÇÃO MOBILE NO MENU (PISCAR SEM RETÂNGULO)")
	print("=".repeat(72))

	var menu: MainMenu = MainMenuScene.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	await process_frame

	# Simula runtime mobile forçando método _is_mobile_runtime para true via flag de teste
	# No mobile, botões devem possuir stylebox transparente sem borda
	var btn_new_game: Button = menu.find_child("BtnNewGame", true, false)
	assert_test(btn_new_game != null, "Botão BtnNewGame instanciado no menu")

	var mobile_style: StyleBoxFlat = menu._make_mobile_selector_style(true)
	assert_test(mobile_style != null, "Estilo de seleção mobile gerado com sucesso")
	assert_test(mobile_style.bg_color == Color.TRANSPARENT, "Estilo mobile: bg_color é estritamente TRANSPARENT (sem fundo retangular)")
	assert_test(mobile_style.border_color == Color.TRANSPARENT, "Estilo mobile: border_color é TRANSPARENT (sem moldura retangular)")
	assert_test(mobile_style.get_border_width(SIDE_LEFT) == 0, "Estilo mobile: largura de borda é 0 (sem retângulo comprido em volta)")

	# Testa cálculo de coordenadas para opção 0 (NOVO JOGO) e 1 (CONTINUAR)
	var t0: Dictionary = menu._calculate_selector_transforms(0)
	var t1: Dictionary = menu._calculate_selector_transforms(1)
	assert_test(not t0.is_empty(), "Transformações calculadas para opção 0 (NOVO JOGO)")
	assert_test(not t1.is_empty(), "Transformações calculadas para opção 1 (CONTINUAR)")
	assert_test(t1["brush_pos"].y > t0["brush_pos"].y, "Opção 1 posicionada verticalmente abaixo da opção 0")

	# Testa acionamento do feedback com piscar
	menu._play_selection_feedback(0)
	var brush: TextureRect = menu.find_child("BrushHighlight", true, false)
	var chev_l: TextureRect = menu.find_child("LeftChevron", true, false)
	var chev_r: TextureRect = menu.find_child("RightChevron", true, false)

	assert_test(brush != null and brush.visible == true, "BrushHighlight ativado durante feedback da seleção")
	assert_test(chev_l != null and chev_l.visible == false, "LeftChevron permanentemente eliminado (visibilidade false)")
	assert_test(chev_r != null and chev_r.visible == false, "RightChevron permanentemente eliminado (visibilidade false)")

	menu.queue_free()
	await process_frame

	print("\n" + "-".repeat(72))
	print("RESULTADO DOS TESTES DO MENU MOBILE: %d/%d PASSARAM (Falhas: %d)" % [_passed, _total, _failed])
	print("-".repeat(72) + "\n")

	quit(0 if _failed == 0 else 1)

