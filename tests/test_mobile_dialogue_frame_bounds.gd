extends SceneTree

## Regressão focada: diálogo narrativo mobile com quebras de linha e safe area inferior.

const NARRATIVE_SCENE_PATH: String = "res://scenes/ui/narrative_director.tscn"

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] %s" % description)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % description)


func _run_tests() -> void:
	var packed_scene: PackedScene = load(NARRATIVE_SCENE_PATH) as PackedScene
	_assert(packed_scene != null, "Cena NarrativeDirector carrega")
	if packed_scene == null:
		_finish()
		return

	# Controle de não-regressão: o perfil Desktop permanece com o layout original.
	var desktop_director: NarrativeDirector = packed_scene.instantiate() as NarrativeDirector
	_assert(desktop_director != null, "Instância Desktop criada")
	if desktop_director == null:
		_finish()
		return
	desktop_director.force_mobile_for_test = false
	root.add_child(desktop_director)
	await process_frame
	var desktop_root: Control = desktop_director.get_node_or_null("%RootControl") as Control
	var desktop_art: Control = desktop_director.get_node_or_null("%ArtStage") as Control
	var desktop_area: MarginContainer = desktop_director.get_node_or_null("%DialogueArea") as MarginContainer
	var desktop_speaker: Label = desktop_director.get_node_or_null("%SpeakerLabel") as Label
	var desktop_dialogue: Label = desktop_director.get_node_or_null("%DialogueLabel") as Label
	_assert(desktop_root != null and desktop_art != null and desktop_area != null, "Controles de layout Desktop estão presentes")
	if desktop_root != null and desktop_art != null and desktop_area != null:
		desktop_root.size = Vector2(1280.0, 720.0)
		desktop_director._apply_responsive_layout()
		desktop_director._apply_dialogue_density()
		_assert(is_equal_approx(desktop_art.anchor_bottom, 0.72), "Desktop mantém o palco em 72%")
		_assert(is_equal_approx(desktop_area.anchor_top, 0.72), "Desktop mantém o início do diálogo em 72%")
		_assert(is_equal_approx(desktop_area.anchor_bottom, 1.0), "Desktop mantém o rodapé original")
	if desktop_speaker != null and desktop_speaker.label_settings != null:
		_assert(desktop_speaker.label_settings.font_size == 32, "Desktop mantém fonte de 32px no speaker")
	if desktop_dialogue != null and desktop_dialogue.label_settings != null:
		_assert(desktop_dialogue.label_settings.font_size == 30, "Desktop mantém fonte de 30px no diálogo")
	desktop_director.queue_free()
	await process_frame

	var director: NarrativeDirector = packed_scene.instantiate() as NarrativeDirector
	_assert(director != null, "Instância NarrativeDirector criada")
	if director == null:
		_finish()
		return
	director.force_mobile_for_test = true
	root.add_child(director)
	await process_frame

	var root_control: Control = director.get_node_or_null("%RootControl") as Control
	var dialogue_area: MarginContainer = director.get_node_or_null("%DialogueArea") as MarginContainer
	var dialogue_frame: PanelContainer = director.get_node_or_null("%DialogueFrame") as PanelContainer
	var speaker_label: Label = director.get_node_or_null("%SpeakerLabel") as Label
	var dialogue_label: Label = director.get_node_or_null("%DialogueLabel") as Label
	var portrait: TextureRect = director.get_node_or_null("%SpeakerPortrait") as TextureRect
	var divider: HSeparator = director.get_node_or_null("%HeaderDivider") as HSeparator
	var bottom_accent: ColorRect = director.get_node_or_null("%BottomAccentBar") as ColorRect

	_assert(root_control != null, "RootControl está presente")
	_assert(dialogue_area != null and dialogue_frame != null, "Moldura externa está presente")
	_assert(speaker_label != null and dialogue_label != null and divider != null, "Speaker, divisor e texto estão presentes")
	_assert(portrait != null, "Retrato do orador está presente")
	_assert(bottom_accent != null, "Realce inferior da moldura está presente")
	if root_control == null or dialogue_area == null or dialogue_frame == null or speaker_label == null or dialogue_label == null or divider == null or portrait == null or bottom_accent == null:
		director.queue_free()
		await process_frame
		_finish()
		return

	# Resolução de referência widescreen e caminho real de montagem do diálogo.
	root_control.size = Vector2(1280.0, 720.0)
	var sequence: Resource = load("res://resources/story/story_intro_map1.tres") as Resource
	var events: Array = sequence.get("events") if sequence != null else []
	_assert(events.size() > 6, "Sequência narrativa de referência carrega os eventos")
	if events.size() <= 6:
		director.queue_free()
		await process_frame
		_finish()
		return
	director.current_sequence = sequence
	director.current_event_index = 6
	director.current_text_index = 1
	director.is_playing = true
	director._is_transitioning = false
	director._show_current_text_block(events[6] as Resource)
	dialogue_label.text = "Primeira linha da fala.\nSegunda linha com mais texto.\nTerceira linha para validar a altura.\nQuarta linha para testar a quebra."
	director._skip_typewriter()
	director._apply_responsive_layout()
	await process_frame

	_assert(is_equal_approx(dialogue_area.anchor_top, 0.54), "Painel mobile 16:9 inicia em 54% da altura")
	_assert(is_equal_approx(director._art_stage.anchor_bottom, dialogue_area.anchor_top), "Palco e painel compartilham o limite sem sobreposição")
	_assert(is_equal_approx(dialogue_area.anchor_bottom, 1.0), "Painel mobile usa âncora inferior absoluta")
	_assert(dialogue_area.offset_bottom <= -20.0, "Painel mantém recuo inferior físico de 20px para a safe area")
	_assert(dialogue_area.get_theme_constant("margin_bottom") == 0, "Margem externa inferior não comprime nem recorta a moldura")
	_assert(speaker_label.label_settings.font_size == 28, "Speaker mobile usa 28px")
	_assert(is_equal_approx(speaker_label.custom_minimum_size.y, 44.0), "Cabeçalho do speaker tem altura independente do retrato")
	_assert(dialogue_label.label_settings.font_size == 26, "Fala mobile usa 26px")
	_assert(portrait.custom_minimum_size == Vector2(88.0, 88.0), "Retrato mobile usa 88x88px")

	var speaker_rect: Rect2 = speaker_label.get_global_rect()
	var divider_rect: Rect2 = divider.get_global_rect()
	_assert(speaker_rect.end.y <= divider_rect.position.y + 1.0, "Nome do speaker permanece acima do divisor colorido")

	var root_rect: Rect2 = root_control.get_global_rect()
	var frame_rect: Rect2 = dialogue_frame.get_global_rect()
	_assert(frame_rect.end.y <= root_rect.end.y - 15.0, "Borda inferior da moldura permanece dentro da safe area mobile")
	var accent_rect: Rect2 = bottom_accent.get_global_rect()
	_assert(accent_rect.size.y >= 2.0 and accent_rect.end.y <= frame_rect.end.y, "Realce inferior não é cortado pelo limite da moldura")
	_assert(bottom_accent.z_index >= 2, "Realce inferior é desenhado acima do conteúdo interno")
	_assert(dialogue_label.get_global_rect().end.y <= frame_rect.end.y, "Texto com quatro linhas não ultrapassa a moldura")

	# Ultrawide mobile mantém as margens laterais e a borda inferior.
	root_control.size = Vector2(1600.0, 720.0)
	director._apply_responsive_layout()
	director._apply_dialogue_density()
	await process_frame
	_assert(dialogue_area.offset_left >= 36.0, "Ultrawide preserva margem lateral segura esquerda")
	_assert(dialogue_area.offset_right <= -36.0, "Ultrawide preserva margem lateral segura direita")
	_assert(dialogue_area.offset_bottom <= -20.0, "Ultrawide preserva recuo inferior em pixels")
	_assert(dialogue_frame.get_global_rect().end.y <= root_control.get_global_rect().end.y - 15.0, "Ultrawide mantém a borda inferior visível na área segura")

	# Landscape baixo aplica tipografia compacta sem comprimir o speaker.
	root_control.size = Vector2(844.0, 390.0)
	director._apply_responsive_layout()
	director._apply_dialogue_density()
	await process_frame
	_assert(is_equal_approx(dialogue_area.anchor_top, 0.38), "Landscape compacto reserva altura real para o painel")
	_assert(is_equal_approx(director._art_stage.anchor_bottom, dialogue_area.anchor_top), "Landscape compacto não sobrepõe arte e moldura")
	_assert(speaker_label.label_settings.font_size == 22, "Landscape compacto reduz somente a tipografia do speaker")
	_assert(dialogue_label.label_settings.font_size == 18, "Landscape compacto reduz tipografia da fala")
	_assert(portrait.custom_minimum_size == Vector2(40.0, 40.0), "Landscape compacto reduz o retrato proporcionalmente")
	_assert(dialogue_frame.get_global_rect().end.y <= root_control.get_global_rect().end.y - 14.0, "Landscape compacto mantém a moldura afastada do limite inferior")

	director.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("\nRESULTADO: %d passaram / %d falharam" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
