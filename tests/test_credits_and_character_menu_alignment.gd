extends SceneTree

const MainMenuScene: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const CreditsScene: PackedScene = preload("res://scenes/ui/credits.tscn")
const BonusGarageScene: PackedScene = preload("res://scenes/levels/bonus_garage.tscn")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _assert(cond: bool, msg: String) -> void:
	_total += 1
	if cond:
		_passed += 1
		print("  [OK] %s" % msg)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % msg)


func _init() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	print("\n========================================================")
	print("TESTE: ALINHAMENTO DO SHOWCASE E CRÉDITOS PÓS-BÔNUS")
	print("========================================================")

	# --- TESTE 1: Posicionamento dos Personagens Mais à Direita no Menu ---
	print("\n--- Teste 1: Posicionamento dos Personagens (*_menu.png) no Menu ---")
	var menu: Control = MainMenuScene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	await process_frame

	var showcase: Control = menu.find_child("CharacterShowcase", true, false) as Control
	_assert(showcase != null, "CharacterShowcase encontrado no menu principal")

	var sprite_container: Control = showcase.get_node_or_null("SpriteContainer") as Control if showcase != null else null
	_assert(sprite_container != null, "SpriteContainer existe dentro do showcase")

	if sprite_container != null and showcase != null:
		# Aguarda a animação de entrada concluir para que o nó alcance a posição base final
		await create_timer(0.6).timeout
		var local_sprite_x: float = sprite_container.position.x
		var local_center_x: float = local_sprite_x + (sprite_container.size.x * 0.5)
		_assert(local_sprite_x >= 200.0, "Sprite posicionado mais à direita dentro do showcase (offset X: %.1f >= 200.0)" % local_sprite_x)
		_assert(local_center_x >= 350.0, "Centro do lutador posicionado entre a borda e o menu de botões (X: %.1f)" % local_center_x)

		# Verifica alinhamento de solo (VFXContainer) com os pés do personagem
		var vfx: Control = showcase.get_node_or_null("VFXContainer") as Control
		_assert(vfx != null, "VFXContainer existe")
		if vfx != null:
			_assert(is_equal_approx(vfx.position.x, local_center_x), "Sombra e aura de solo acompanham perfeitamente o centro dos pés (VFX X: %.1f == %.1f)" % [vfx.position.x, local_center_x])

		# Verifica alinhamento da plaqueta com o nome do personagem
		var name_badge: Control = showcase.get_node_or_null("NameBadge") as Control
		_assert(name_badge != null, "NameBadge existe")
		if name_badge != null:
			var badge_center_x: float = name_badge.position.x + (name_badge.size.x * 0.5)
			_assert(is_equal_approx(badge_center_x, local_center_x), "Nome do lutador centralizado sobre o personagem (Badge Center: %.1f == %.1f)" % [badge_center_x, local_center_x])

	menu.queue_free()
	await process_frame

	# --- TESTE 2: Tela de Créditos com Vídeo (video_creditos_demo.ogv) e Fallback ---
	print("\n--- Teste 2: Tela de Créditos com Vídeo e Fallback ---")
	_assert(ResourceLoader.exists("res://assets/backgrounds/creditos.webp"), "Arquivo assets/backgrounds/creditos.webp existe como fallback")
	_assert(ResourceLoader.exists("res://assets/videos/creditos/video_creditos_demo.ogv"), "Arquivo assets/videos/creditos/video_creditos_demo.ogv existe")

	var credits: Control = CreditsScene.instantiate() as Control
	_assert(credits != null, "Cena credits.tscn instanciada com sucesso")
	root.add_child(credits)
	await process_frame

	var bg_rect: TextureRect = credits.get_node_or_null("%BackgroundImage") as TextureRect
	_assert(bg_rect != null, "BackgroundImage existe na tela de créditos como base visual")
	if bg_rect != null:
		_assert(bg_rect.texture != null, "BackgroundImage possui textura atribuída")
		if bg_rect.texture != null:
			var path: String = bg_rect.texture.resource_path
			_assert(path.ends_with("creditos.webp"), "BackgroundImage carrega especificamente 'creditos.webp' (caminho: %s)" % path)

	var video_node: VideoStreamPlayer = credits.get_node_or_null("%VideoPlayer") as VideoStreamPlayer
	_assert(video_node != null, "VideoPlayer (VideoStreamPlayer) existe na tela de créditos")
	if video_node != null:
		_assert(video_node.visible, "VideoPlayer está visível em tela cheia")
		_assert(video_node.expand, "VideoPlayer configurado com expand = true")
		_assert(video_node.loop, "VideoPlayer configurado com loop contínuo")
		_assert(video_node.stream != null, "VideoPlayer possui stream de vídeo atribuído")
		if video_node.stream != null:
			_assert(video_node.stream.resource_path.ends_with("video_creditos_demo.ogv"), "VideoPlayer carrega 'video_creditos_demo.ogv' (caminho: %s)" % video_node.stream.resource_path)

	var btn_back: Button = credits.get_node_or_null("%BtnBack") as Button
	_assert(btn_back != null, "Botão BtnBack existe para retorno ao menu")
	if btn_back != null:
		_assert(btn_back.text.contains("VOLTAR AO MENU"), "Texto do botão orienta retorno ao menu principal: '%s'" % btn_back.text)

	var fade: ColorRect = credits.get_node_or_null("%FadeOverlay") as ColorRect
	_assert(fade != null, "FadeOverlay presente para transição suave")

	credits.queue_free()
	await process_frame

	# --- TESTE 3: Configuração da Fase Bônus para Encaminhar aos Créditos ---
	print("\n--- Teste 3: Encaminhamento da Fase Bônus aos Créditos ---")
	var garage: Node2D = BonusGarageScene.instantiate() as Node2D
	_assert(garage != null, "Cena bonus_garage.tscn instanciada com sucesso")
	if garage != null:
		_assert(garage.get("is_final_map") == true, "Fase Bônus configurada como mapa final da sequência da Fase 1")
		var target_victory: String = String(garage.get("victory_scene_path"))
		_assert(target_victory.ends_with("credits.tscn"), "victory_scene_path aponta para credits.tscn (caminho: %s)" % target_victory)
		garage.queue_free()

	await process_frame

	print("\n========================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [_passed, _total, _failed])
	print("========================================================")

	quit(0 if _failed == 0 else 1)
