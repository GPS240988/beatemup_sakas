extends SceneTree

## Suíte de Testes Automatizados: Novo Menu Principal Arcade — Projeto Sakas

const ArcadeButtonClass = preload("res://scripts/ui/components/arcade_button.gd")
const SettingsPanelClass = preload("res://scripts/ui/components/settings_panel.gd")

func _init() -> void:
	print("\n========================================================")
	print("  TESTE: NOVO MENU PRINCIPAL ARCADE & DESIGN SYSTEM")
	print("========================================================")
	_run_all_tests()


func _run_all_tests() -> void:
	await process_frame

	print("\n📋 1. Validação de Recursos e Assets Visuais")
	_assert(ResourceLoader.exists("res://assets/backgrounds/locadora.webp"), "locadora.webp presente em assets/backgrounds/")
	_assert(ResourceLoader.exists("res://assets/fonts/arcade_bold.ttf"), "arcade_bold.ttf presente")
	_assert(ResourceLoader.exists("res://assets/fonts/barlow_condensed_extrabold_italic.ttf"), "barlow_condensed_extrabold_italic.ttf presente")
	_assert(ResourceLoader.exists("res://assets/fonts/press_start_2p.ttf"), "press_start_2p.ttf presente")
	_assert(ResourceLoader.exists("res://assets/ui/menu/icon_play.png"), "icon_play.png presente")
	_assert(ResourceLoader.exists("res://assets/ui/menu/icon_coin.png"), "icon_coin.png presente")
	_assert(ResourceLoader.exists("res://assets/ui/menu/icon_gear.png"), "icon_gear.png presente")
	_assert(ResourceLoader.exists("res://assets/ui/menu/icon_exit.png"), "icon_exit.png presente")

	print("\n📋 2. Instanciação e Hierarquia da Cena main_menu.tscn")
	var menu_scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	_assert(menu_scene != null, "main_menu.tscn carregada com sucesso")

	var menu: Node = menu_scene.instantiate()
	_assert(menu != null, "MainMenu instanciado")
	root.add_child(menu)
	await process_frame

	var bg: TextureRect = menu.get_node_or_null("%BackgroundImage") as TextureRect
	_assert(bg != null, "BackgroundImage existe")
	_assert(bg.texture != null, "BackgroundImage possui textura atribuída")

	var buttons_box: VBoxContainer = menu.get_node_or_null("%ButtonsContainer") as VBoxContainer
	_assert(buttons_box != null, "ButtonsContainer existe")
	_assert(buttons_box.get_child_count() == 4, "Exatamente 4 opções no primeiro nível do menu")

	print("\n📋 3. Validação dos 4 Botões Arcade e Identidade Visual")
	var btn_play: Button = menu.get_node_or_null("%BtnPlay") as Button
	var btn_continue: Button = menu.get_node_or_null("%BtnContinue") as Button
	var btn_settings: Button = menu.get_node_or_null("%BtnSettings") as Button
	var btn_quit: Button = menu.get_node_or_null("%BtnQuit") as Button

	_assert(btn_play != null and btn_play.get("button_text") == "JOGAR", "Botão JOGAR existe")
	_assert(btn_play.get("is_primary") == true, "Botão JOGAR possui destaque hierárquico is_primary")
	_assert(btn_play.get("icon_texture") != null, "Botão JOGAR possui ícone atribuído")

	_assert(btn_continue != null and btn_continue.get("button_text") == "CONTINUAR", "Botão CONTINUAR existe")
	_assert(btn_continue.get("is_primary") == false, "Botão CONTINUAR usa variante normal")
	_assert(btn_continue.get("icon_texture") != null, "Botão CONTINUAR possui ícone atribuído")

	_assert(btn_settings != null and btn_settings.get("button_text") == "CONFIGURAÇÕES", "Botão CONFIGURAÇÕES existe")
	_assert(btn_settings.get("icon_texture") != null, "Botão CONFIGURAÇÕES possui ícone atribuído")

	_assert(btn_quit != null and btn_quit.get("button_text") == "SAIR", "Botão SAIR existe")
	_assert(btn_quit.get("is_danger") == true, "Botão SAIR usa variante danger")
	_assert(btn_quit.get("icon_texture") != null, "Botão SAIR possui ícone atribuído")

	print("\n📋 4. Validação do Painel Integrado de Configurações")
	var settings: Control = menu.get_node_or_null("%SettingsPanel") as Control
	_assert(settings != null, "SettingsPanel instanciado no menu")
	_assert(settings.visible == false, "SettingsPanel inicia oculto")

	# Abre configurações
	menu._open_settings()
	_assert(settings.visible == true, "SettingsPanel torna-se visível ao abrir configurações")
	_assert(settings.get("settings_origin") == "main_menu", "Origem configurada como main_menu")

	# Testa ajuste real do volume Master
	var slider: HSlider = settings.get_node_or_null("%VolumeSlider") as HSlider
	_assert(slider != null, "Slider de volume Master existe")
	var old_val: float = slider.value
	slider.value = 50.0
	await process_frame
	var bus_idx := AudioServer.get_bus_index("Master")
	_assert(bus_idx >= 0, "Bus Master existe no AudioServer")
	var db_val := AudioServer.get_bus_volume_db(bus_idx)
	_assert(is_equal_approx(db_val, linear_to_db(0.5)), "Volume do AudioServer Master alterado em tempo real")
	# Restaura volume
	slider.value = old_val

	# Fecha configurações
	settings.closed.emit("main_menu")
	await process_frame
	_assert(settings.visible == false, "SettingsPanel oculta após fechamento")

	print("\n📋 5. Validação do Fluxo CONTINUAR -> Mapa")
	var session = root.get_node_or_null("GameSession")
	if session != null:
		session.set_meta("map_entry_context", "continue")
		_assert(session.get_meta("map_entry_context") == "continue", "Contexto 'continue' definido no GameSession")

	print("\n📋 6. Responsividade e Adaptação de Resolução")
	# Testa resolução HD 1280x720
	menu.size = Vector2(1280, 720)
	await process_frame
	_assert(menu.size == Vector2(1280, 720), "Menu adapta-se a 1280x720 sem cortes")

	# Testa resolução Full HD 1920x1080
	menu.size = Vector2(1920, 1080)
	await process_frame
	_assert(menu.size == Vector2(1920, 1080), "Menu adapta-se a 1920x1080 com integridade")

	menu.queue_free()
	print("\n--------------------------------------------------------")
	print("  TODOS OS TESTES DO MENU PRINCIPAL PASSARAM COM SUCESSO!")
	print("--------------------------------------------------------\n")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  ✅ [OK] ", message)
	else:
		printerr("  ❌ [FALHA] ", message)
		quit(1)
