extends SceneTree

const StandardDialogueBox = preload("res://scripts/ui/standard_dialogue_box.gd")
const CardInteractionScene = preload("res://scenes/items/counter_card_interaction.tscn")
const DropItemScene = preload("res://scenes/items/dropped_magazine_interaction.tscn")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _assert(condition: bool, description: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("  ✅ [OK] %s" % description)
	else:
		_failed += 1
		printerr("  ❌ [FALHA] %s" % description)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("\n" + "=".repeat(72))
	print("  TESTE: Padrão Oficial de Caixa de Diálogo e Inspeção — Projeto Sakas")
	print("=".repeat(72) + "\n")

	_test_factory_methods()
	_test_container_hierarchy()
	_test_counter_card_overlay()
	_test_dropped_magazine_overlay()

	print("\n" + "-".repeat(72))
	print("  RESULTADO: %d/%d testes passaram" % [_passed, _total])
	if _failed > 0:
		print("  ⚠️ %d FALHA(S) DETECTADA(S)" % _failed)
	else:
		print("  ✅ TODOS OS TESTES PASSARAM COM SUCESSO!")
	print("-".repeat(72) + "\n")
	quit(0 if _failed == 0 else 1)


func _test_factory_methods() -> void:
	print("📋 1. Métodos Factory de StandardDialogueBox")

	var style: StyleBoxTexture = StandardDialogueBox.create_dialogue_stylebox()
	_assert(style != null, "StyleBoxTexture criado com sucesso")
	_assert(style.texture != null, "StyleBoxTexture possui textura atribuída")
	_assert(
		style.texture.resource_path == "res://assets/ui/hud/dialog_frame_9patch.png",
		"Textura oficial é dialog_frame_9patch.png"
	)
	_assert(is_equal_approx(style.texture_margin_left, 14.0), "Margem esquerda do StyleBox é 14px")
	_assert(is_equal_approx(style.texture_margin_top, 14.0), "Margem superior do StyleBox é 14px")
	_assert(is_equal_approx(style.texture_margin_right, 14.0), "Margem direita do StyleBox é 14px")
	_assert(is_equal_approx(style.texture_margin_bottom, 14.0), "Margem inferior do StyleBox é 14px")

	var speaker_desktop: LabelSettings = StandardDialogueBox.create_speaker_settings(false)
	_assert(speaker_desktop.font_size == 32, "Tamanho da fonte do orador no desktop é 32px")
	_assert(speaker_desktop.outline_size == 4, "Contorno do orador no desktop é 4px")
	_assert(speaker_desktop.shadow_size == 2, "Sombra do orador é 2px")

	var speaker_mobile: LabelSettings = StandardDialogueBox.create_speaker_settings(true)
	_assert(speaker_mobile.font_size == 32, "Tamanho da fonte do orador no mobile é 32px")

	var dialogue_desktop: LabelSettings = StandardDialogueBox.create_dialogue_settings(false)
	_assert(dialogue_desktop.font_size == 30, "Tamanho da fonte do diálogo no desktop é 30px")
	_assert(dialogue_desktop.outline_size == 3, "Contorno do diálogo no desktop é 3px")
	_assert(dialogue_desktop.line_spacing == 8, "Entrelinha do diálogo é 8px")

	var dialogue_mobile: LabelSettings = StandardDialogueBox.create_dialogue_settings(true)
	_assert(dialogue_mobile.font_size == 30, "Tamanho da fonte do diálogo no mobile é 30px")


func _test_container_hierarchy() -> void:
	print("\n📋 2. Hierarquia de Containers e Avatar Pixel Art HD")

	var root_ctrl := Control.new()
	root.add_child(root_ctrl)

	var ui := StandardDialogueBox.build_dialogue_ui(root_ctrl, false)
	_assert(ui.has("dialogue_area"), "Retornou dialogue_area")
	_assert(ui["dialogue_area"] is MarginContainer, "dialogue_area é MarginContainer")

	_assert(ui.has("dialogue_panel"), "Retornou dialogue_panel")
	_assert(ui["dialogue_panel"] is PanelContainer, "dialogue_panel é PanelContainer")

	var panel := ui["dialogue_panel"] as PanelContainer
	var panel_style := panel.get_theme_stylebox("panel")
	_assert(panel_style is StyleBoxTexture, "Painel utiliza StyleBoxTexture")

	var portrait := ui["portrait"] as TextureRect
	_assert(portrait != null, "Portrait existe na estrutura")
	_assert(portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Avatar usa TEXTURE_FILTER_NEAREST (Pixel Art HD)")
	_assert(portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Avatar mantém proporção aspect-centered")

	var speaker := ui["speaker_label"] as Label
	_assert(speaker != null and speaker.label_settings != null, "Orador usa LabelSettings")

	var dialogue := ui["dialogue_label"] as Label
	_assert(dialogue != null and dialogue.label_settings != null, "Texto de fala usa LabelSettings")
	_assert(dialogue.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Texto de fala possui quebra de linha inteligente")

	root_ctrl.queue_free()


func _test_counter_card_overlay() -> void:
	print("\n📋 3. Overlay do Card de Interação (counter_card_interaction.gd)")

	var card := CardInteractionScene.instantiate()
	root.add_child(card)

	var overlay := card.get_node_or_null("CardInspectionOverlay") as CanvasLayer
	_assert(overlay != null, "CardInspectionOverlay (CanvasLayer) instanciado")
	_assert(overlay.layer == 125, "CanvasLayer está no Layer 125 (à frente do cenário 2.5D)")

	var dim := overlay.get_node_or_null("OverlayRoot/DimBackground") as ColorRect
	_assert(dim != null, "DimBackground existe")
	_assert(is_equal_approx(dim.color.a, 0.86), "Fundo é translúcido (alfa 0.86, sem tela preta)")

	var enlarged := overlay.get_node_or_null("OverlayRoot/EnlargedCard") as TextureRect
	_assert(enlarged != null, "EnlargedCard existe")
	_assert(enlarged.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "EnlargedCard usa Nearest filter")

	var frame := overlay.get_node_or_null("OverlayRoot/DialogueArea/DialogueFrame") as PanelContainer
	_assert(frame != null, "DialogueFrame é PanelContainer")
	_assert(frame.get_theme_stylebox("panel") is StyleBoxTexture, "DialogueFrame usa StyleBoxTexture")

	var portrait := overlay.get_node_or_null("OverlayRoot/DialogueArea/DialogueFrame/InnerMargin/DialogueHBox/Portrait") as TextureRect
	_assert(portrait != null, "Portrait posicionado no DialogueHBox")
	_assert(portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Portrait configurado como TEXTURE_FILTER_NEAREST")

	var player := CharacterBody2D.new()
	player.add_to_group("player")
	root.add_child(player)

	# Testa acionamento de interação e máquina de escrever
	card.call("interact", player)
	_assert(bool(card.get("_dialogue_open")), "Diálogo aberto com sucesso")
	_assert(bool(card.get("_is_typing")), "Efeito Typewriter ativo no início")

	# Testa skip da digitação
	card.call("_skip_typewriter")
	_assert(not bool(card.get("_is_typing")), "Skip desativa _is_typing")
	var dialogue_lbl := card.get("_dialogue_label") as Label
	_assert(dialogue_lbl != null and dialogue_lbl.visible_characters == -1, "Skip exibe todos os caracteres (visible_characters = -1)")

	card.call("_close_dialogue")
	_assert(not bool(card.get("_dialogue_open")), "Diálogo fechado após confirmação")

	player.queue_free()
	card.queue_free()


func _test_dropped_magazine_overlay() -> void:
	print("\n📋 4. Overlay de Itens Dropados (dropped_magazine_story_pickup.gd)")

	var drop := DropItemScene.instantiate() as DroppedMagazineStoryPickup
	drop.configure_item(
		"res://assets/sprites/Itens/playboy.jpg",
		"res://assets/sprites/Itens/playboy_gg.jpg",
		"PLAYBOY",
		"Japonês safado, larga essas coisas aqui."
	)
	root.add_child(drop)

	var player := CharacterBody2D.new()
	player.add_to_group("player")
	root.add_child(player)

	# Simula aproximação do player
	drop.call("_on_body_entered", player)
	_assert(drop.can_offer_hint_to(player), "Item pode oferecer interação ao player próximo")

	# Aciona interação PEGAR
	drop.interact(player)
	_assert(bool(drop.get("_dialogue_open")), "Diálogo do drop aberto com sucesso")

	var overlay := drop.get_node_or_null("DroppedItemInspectionOverlay") as CanvasLayer
	_assert(overlay != null, "DroppedItemInspectionOverlay instanciado")
	_assert(overlay.layer == 125, "Layer 125 no item dropado")

	var dim := overlay.get_node_or_null("OverlayRoot/DimBackground") as ColorRect
	_assert(dim != null and is_equal_approx(dim.color.a, 0.86), "Drop usa fundo translúcido idêntico ao card (alfa 0.86)")

	var frame := overlay.get_node_or_null("OverlayRoot/DialogueArea/DialogueFrame") as PanelContainer
	_assert(frame != null and frame.get_theme_stylebox("panel") is StyleBoxTexture, "Drop usa PanelContainer com StyleBoxTexture oficial")

	var portrait := overlay.get_node_or_null("OverlayRoot/DialogueArea/DialogueFrame/InnerMargin/DialogueHBox/Portrait") as TextureRect
	_assert(portrait != null and portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Avatar do Gabriel em Pixel Art HD")

	var speaker_lbl := overlay.get_node_or_null("OverlayRoot/DialogueArea/DialogueFrame/InnerMargin/DialogueHBox/TextVBox/SpeakerName") as Label
	_assert(speaker_lbl != null and speaker_lbl.text == "GABRIEL", "Nome do orador exibido: GABRIEL")

	var dialogue_lbl := overlay.get_node_or_null("OverlayRoot/DialogueArea/DialogueFrame/InnerMargin/DialogueHBox/TextVBox/DialogueText") as Label
	_assert(dialogue_lbl != null and dialogue_lbl.text == "Japonês safado, larga essas coisas aqui.", "Mensagem da fala confere")

	_assert(bool(drop.get("_is_typing")), "Typewriter ativo no item dropado")
	drop.call("_skip_typewriter")
	_assert(not bool(drop.get("_is_typing")), "Skip do typewriter funciona no item dropado")

	player.queue_free()
	drop.queue_free()
