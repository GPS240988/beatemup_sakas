extends SceneTree

## Teste de Validação da Nova Arquitetura de Lineup de Personagens e Animação Idle (Guilherme + 4 Slots)

const MenuCharacterSlotClass = preload("res://scripts/ui/components/menu_character_slot.gd")

var passed: int = 0
var failed: int = 0

func _init() -> void:
	print("\n========================================================")
	print(" TESTE: LINEUP DE PERSONAGENS E IDLE ANIMADO DO MENU")
	print("========================================================")

	var scn = load("res://scenes/ui/main_menu.tscn") as PackedScene
	_assert(scn != null, "Cena main_menu.tscn deve carregar sem erros")
	if scn == null:
		_finish_test()
		return

	var menu = scn.instantiate() as Control
	_assert(menu != null, "main_menu.tscn deve instanciar com sucesso")
	if menu == null:
		_finish_test()
		return

	root.add_child(menu)
	if not menu.is_node_ready():
		menu._ready()

	# 1. Verifica container de lineup
	var lineup = menu.get_node_or_null("%CharactersLineup") as HBoxContainer
	_assert(lineup != null, "CharactersLineup (%CharactersLineup) deve existir no menu")

	# 2. Verifica Slot do Guilherme
	var slot_guilherme = menu.get_node_or_null("%SlotGuilherme") as Control
	_assert(slot_guilherme != null, "SlotGuilherme (%SlotGuilherme) deve existir")
	if slot_guilherme != null:
		_assert(slot_guilherme.visible == true, "SlotGuilherme deve estar visível")
		_assert(slot_guilherme.get("character_data") != null, "SlotGuilherme deve ter character_data associado")
		_assert(slot_guilherme.get("character_data").get("id") == "guilherme", "ID do personagem deve ser 'guilherme'")
		_assert(slot_guilherme.get("character_shadow") != null, "SlotGuilherme deve possuir sombra de contato")
		_assert(slot_guilherme.get("character_aura") != null, "SlotGuilherme deve possuir aura sutil")
		_assert(slot_guilherme.get("character_texture") != null, "SlotGuilherme deve possuir textura do personagem")
		_assert((slot_guilherme.get("character_texture") as CanvasItem).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Filtro da textura deve ser NEAREST (pixel art nítida)")

	# 3. Verifica os outros 3 slots (preparados para expansão futura, mas inativos/ocultos)
	var slot_gabriel = menu.get_node_or_null("%SlotGabriel") as Control
	var slot_andre = menu.get_node_or_null("%SlotAndre") as Control
	var slot_juliana = menu.get_node_or_null("%SlotJuliana") as Control

	_assert(slot_gabriel != null, "SlotGabriel deve existir para expansão futura")
	_assert(slot_andre != null, "SlotAndre deve existir para expansão futura")
	_assert(slot_juliana != null, "SlotJuliana deve existir para expansão futura")

	if slot_gabriel != null:
		_assert(slot_gabriel.visible == false, "SlotGabriel deve estar invisível nesta fase (sem placeholders)")
	if slot_andre != null:
		_assert(slot_andre.visible == false, "SlotAndre deve estar invisível nesta fase (sem placeholders)")
	if slot_juliana != null:
		_assert(slot_juliana.visible == false, "SlotJuliana deve estar invisível nesta fase (sem placeholders)")

	# 4. Verifica animação de idle no SlotGuilherme
	if slot_guilherme != null:
		slot_guilherme.start_idle_loop()
		_assert(slot_guilherme.get("_is_looping_idle") == true, "SlotGuilherme deve estar em loop de respiração idle")

	# 5. Verifica botões canônicos
	var btn_play = menu.get_node_or_null("%BtnPlay")
	var btn_continue = menu.get_node_or_null("%BtnContinue")
	var btn_settings = menu.get_node_or_null("%BtnSettings")
	var btn_quit = menu.get_node_or_null("%BtnQuit")
	_assert(btn_play != null and btn_play.visible, "Botão JOGAR deve existir e estar visível")
	_assert(btn_continue != null and btn_continue.visible, "Botão CONTINUAR deve existir e estar visível")
	_assert(btn_settings != null and btn_settings.visible, "Botão CONFIGURAÇÕES deve existir e estar visível")
	_assert(btn_quit != null and btn_quit.visible, "Botão SAIR deve existir e estar visível")

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
		print(">> TODOS OS TESTES DO LINEUP PASSARAM COM SUCESSO! <<\n")
		quit(0)
	else:
		printerr(">> HOUVE FALHAS NOS TESTES DO LINEUP! <<\n")
		quit(1)
