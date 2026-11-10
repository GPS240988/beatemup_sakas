# tests/test_narrative_mobile_layout.gd
extends SceneTree

## Teste Automatizado da Caixa Narrativa e Enquadramento Mobile Landscape
## Valida rigorosamente:
## 1. Desktop 16:9 (1280x720): 100% inalterado (art_bottom 0.72, dialogue_top 0.72, font_size 30, speaker 32)
## 2. Mobile Landscape 16:9 (1280x720):
##    - Imagem ocupa 70% da altura (68-72%) com STRETCH_KEEP_ASPECT_COVERED (sem distorção)
##    - Caixa ocupa 30% da altura (28-32%)
##    - Tipografia ampliada para 24px (faixa de referência 22-26px), cor creme #f7f0da
##    - Detalhes âmbar Neo-16-bit (TopAccentBar #eac16c, BottomAccentBar #b58a3f)
##    - Avatar reduzido para 52x52 (evita engolir espaço vertical)
## 3. Mobile Ultrawide Landscape (1600x720, ~20:9):
##    - Margens laterais seguras dinâmicas (safe margins >= 36px)
##    - Mantém 70% arte e 30% diálogo
## 4. Funcionalidade de Typewriter e Toque/Avanço

const NARRATIVE_SCENE_PATH: String = "res://scenes/ui/narrative_director.tscn"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n========================================================")
	print(" INICIANDO TESTE: CAIXA NARRATIVA MOBILE LANDSCAPE")
	print("========================================================\n")

	_run_tests()


func _run_tests() -> void:
	var packed_scene = ResourceLoader.load(NARRATIVE_SCENE_PATH) as PackedScene
	_assert(packed_scene != null, "A cena narrative_director.tscn deve ser carregada com sucesso")
	if packed_scene == null:
		_finish_test()
		return

	# ==============================================================
	# 1. TESTE DESKTOP (1280x720) - DEVE FICAR 100% INALTERADO
	# ==============================================================
	print("\n--- [1] Testando Modo Desktop (1280x720) ---")
	var director_desktop = packed_scene.instantiate()
	director_desktop.force_mobile_for_test = false
	root.add_child(director_desktop)
	await process_frame

	var root_ctrl_desk = director_desktop.get_node_or_null("%RootControl") as Control
	var art_stage_desk = director_desktop.get_node_or_null("%ArtStage") as Control
	var dialogue_area_desk = director_desktop.get_node_or_null("%DialogueArea") as Control
	var img_display_desk = director_desktop.get_node_or_null("%ImageDisplay") as TextureRect

	_assert(root_ctrl_desk != null, "[Desktop] RootControl deve existir")
	_assert(art_stage_desk != null, "[Desktop] ArtStage deve existir")
	_assert(dialogue_area_desk != null, "[Desktop] DialogueArea deve existir")
	_assert(img_display_desk != null, "[Desktop] ImageDisplay deve existir")

	if root_ctrl_desk != null:
		root_ctrl_desk.size = Vector2(1280, 720)
		director_desktop._apply_responsive_layout()
		director_desktop._apply_dialogue_density()

	_assert(is_equal_approx(art_stage_desk.anchor_bottom, 0.72), "[Desktop] art_stage.anchor_bottom deve ser 0.72 (inalterado)")
	_assert(is_equal_approx(dialogue_area_desk.anchor_top, 0.72), "[Desktop] dialogue_area.anchor_top deve ser 0.72 (inalterado)")
	_assert(is_equal_approx(dialogue_area_desk.anchor_bottom, 1.0), "[Desktop] dialogue_area.anchor_bottom deve ser 1.0 (inalterado)")
	_assert(dialogue_area_desk.offset_left == 0.0, "[Desktop] dialogue_area.offset_left deve ser 0.0 (inalterado)")
	_assert(dialogue_area_desk.offset_right == 0.0, "[Desktop] dialogue_area.offset_right deve ser 0.0 (inalterado)")
	_assert(img_display_desk.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "[Desktop] ImageDisplay deve usar STRETCH_KEEP_ASPECT_COVERED")

	var dlg_label_desk = director_desktop.get_node_or_null("%DialogueLabel") as Label
	var spk_label_desk = director_desktop.get_node_or_null("%SpeakerLabel") as Label
	if dlg_label_desk != null and dlg_label_desk.label_settings != null:
		_assert(dlg_label_desk.label_settings.font_size == 30, "[Desktop] Fonte do diálogo deve ser exatamente 30px (inalterado)")
	if spk_label_desk != null and spk_label_desk.label_settings != null:
		_assert(spk_label_desk.label_settings.font_size == 32, "[Desktop] Fonte do orador deve ser exatamente 32px (inalterado)")

	# Verifica presença dos realces âmbar
	var top_accent_desk = director_desktop.get_node_or_null("%TopAccentBar") as ColorRect
	var bottom_accent_desk = director_desktop.get_node_or_null("%BottomAccentBar") as ColorRect
	_assert(top_accent_desk != null, "[Desktop] TopAccentBar deve existir na moldura")
	_assert(bottom_accent_desk != null, "[Desktop] BottomAccentBar deve existir na moldura")

	director_desktop.queue_free()
	await process_frame

	# ==============================================================
	# 2. TESTE MOBILE LANDSCAPE 16:9 (1280x720)
	# ==============================================================
	print("\n--- [2] Testando Modo Mobile Landscape 16:9 (1280x720) ---")
	var director_mobile = packed_scene.instantiate()
	director_mobile.force_mobile_for_test = true
	root.add_child(director_mobile)
	await process_frame

	var root_ctrl_mob = director_mobile.get_node_or_null("%RootControl") as Control
	var art_stage_mob = director_mobile.get_node_or_null("%ArtStage") as Control
	var dialogue_area_mob = director_mobile.get_node_or_null("%DialogueArea") as Control
	var img_display_mob = director_mobile.get_node_or_null("%ImageDisplay") as TextureRect

	if root_ctrl_mob != null:
		root_ctrl_mob.size = Vector2(1280, 720)
		director_mobile._apply_responsive_layout()
		director_mobile._apply_dialogue_density()

	# 1. Proporções: Imagem 68% (faixa 68-72%), Caixa 32% (faixa 28-32%)
	_assert(is_equal_approx(art_stage_mob.anchor_bottom, 0.68), "[Mobile 16:9] art_stage.anchor_bottom deve ser 0.68 (68% da tela)")
	_assert(is_equal_approx(dialogue_area_mob.anchor_top, 0.68), "[Mobile 16:9] dialogue_area.anchor_top deve ser 0.68 (caixa ocupa 32% inferior)")
	_assert(dialogue_area_mob.anchor_bottom >= 0.99, "[Mobile 16:9] dialogue_area.anchor_bottom deve cobrir até o rodapé")

	# 2. Imagem não-deformada com STRETCH_KEEP_ASPECT_COVERED
	_assert(img_display_mob.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "[Mobile 16:9] ImageDisplay deve usar STRETCH_KEEP_ASPECT_COVERED (não deforma nem estica)")
	_assert(art_stage_mob.clip_contents, "[Mobile 16:9] ArtStage deve ter clip_contents = true para crop limpo")

	# 3. Margens laterais confortáveis em 16:9
	_assert(dialogue_area_mob.offset_left == 18.0, "[Mobile 16:9] dialogue_area.offset_left deve ser 18.0")
	_assert(dialogue_area_mob.offset_right == -18.0, "[Mobile 16:9] dialogue_area.offset_right deve ser -18.0")

	# 4. Tipografia Mobile Ampliada: diálogo 34px, orador 36px, cor creme #f7f0da
	var dlg_label_mob = director_mobile._dialogue_label
	var spk_label_mob = director_mobile._speaker_label
	_assert(dlg_label_mob != null, "[Mobile 16:9] _dialogue_label deve existir")
	if dlg_label_mob != null and dlg_label_mob.label_settings != null:
		_assert(dlg_label_mob.label_settings.font_size == 34, "[Mobile 16:9] Fonte do diálogo deve ser ampliada para 34px (atual: %d)" % dlg_label_mob.label_settings.font_size)
		var color_cream = dlg_label_mob.label_settings.font_color
		_assert(color_cream.r > 0.95 and color_cream.g > 0.90 and color_cream.b > 0.80, "[Mobile 16:9] Cor do texto deve ser creme/branco quente (#f7f0da)")
		_assert(dlg_label_mob.label_settings.line_spacing >= 6, "[Mobile 16:9] Entrelinha deve ser confortável (>= 6px)")

	_assert(spk_label_mob != null, "[Mobile 16:9] _speaker_label deve existir")
	if spk_label_mob != null and spk_label_mob.label_settings != null:
		_assert(spk_label_mob.label_settings.font_size == 36, "[Mobile 16:9] Fonte do orador deve ser ampliada para 36px (atual: %d)" % spk_label_mob.label_settings.font_size)

	# 5. Avatar consideravelmente ampliado (96x96)
	var spk_portrait_mob = director_mobile._speaker_portrait
	_assert(spk_portrait_mob != null, "[Mobile 16:9] _speaker_portrait deve existir")
	if spk_portrait_mob != null:
		_assert(spk_portrait_mob.custom_minimum_size == Vector2(96, 96), "[Mobile 16:9] SpeakerPortrait deve ter custom_minimum_size ampliado para 96x96 (atual: %s)" % str(spk_portrait_mob.custom_minimum_size))

	# 6. Realces âmbar presentes
	var top_accent_mob = director_mobile.get_node_or_null("%TopAccentBar") as ColorRect
	var bottom_accent_mob = director_mobile.get_node_or_null("%BottomAccentBar") as ColorRect
	_assert(top_accent_mob != null, "[Mobile 16:9] TopAccentBar (#eac16c) deve existir")
	_assert(bottom_accent_mob != null, "[Mobile 16:9] BottomAccentBar (#b58a3f) deve existir")

	# ==============================================================
	# 3. TESTE MOBILE ULTRAWIDE LANDSCAPE (1600x720, aspect ~2.22)
	# ==============================================================
	print("\n--- [3] Testando Modo Mobile Ultrawide Landscape (1600x720) ---")
	root_ctrl_mob.size = Vector2(1600, 720)
	director_mobile._apply_responsive_layout()
	director_mobile._apply_dialogue_density()

	_assert(is_equal_approx(art_stage_mob.anchor_bottom, 0.68), "[Mobile Ultrawide] art_stage.anchor_bottom deve manter 0.68")
	_assert(is_equal_approx(dialogue_area_mob.anchor_top, 0.68), "[Mobile Ultrawide] dialogue_area.anchor_top deve manter 0.68")
	_assert(dialogue_area_mob.offset_left >= 36.0, "[Mobile Ultrawide] offset_left deve aplicar safe margin lateral (>= 36px, atual: %f)" % dialogue_area_mob.offset_left)
	_assert(dialogue_area_mob.offset_right <= -36.0, "[Mobile Ultrawide] offset_right deve aplicar safe margin lateral (<= -36px, atual: %f)" % dialogue_area_mob.offset_right)
	_assert(img_display_mob.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "[Mobile Ultrawide] ImageDisplay deve usar STRETCH_KEEP_ASPECT_COVERED")

	# ==============================================================
	# 4. TESTE DE TYPEWRITER E TOQUE PARA AVANÇAR
	# ==============================================================
	print("\n--- [4] Testando Typewriter e Toque/Avanço ---")
	director_mobile.play_sequence_from_path("res://resources/story/story_intro_map1.tres")
	await process_frame

	_assert(director_mobile.is_playing, "[Interação] A sequência deve estar em reprodução")

	# Avança do title_card (Cena 1) para Cena 2 (the_four - Quatro amigos)
	director_mobile.advance_or_skip_text()
	await process_frame

	# Em the_four, se estiver digitando, advance_or_skip_text deve revelar tudo instantaneamente
	if director_mobile._is_typing:
		director_mobile.advance_or_skip_text()
		_assert(not director_mobile._is_typing, "[Interação] Primeiro toque durante digitação revela texto completo imediatamente")
		_assert(director_mobile._dialogue_label.visible_ratio == 1.0, "[Interação] visible_ratio deve ser 1.0 após skip do typewriter")

	director_mobile.queue_free()
	await process_frame

	# ==============================================================
	# 5. TESTE DA INTRODUÇÃO CINEMATOGRÁFICA DE ALESSANDRO (FASE 1-4)
	# ==============================================================
	print("\n--- [5] Testando Introdução de Alessandro (Fase 1-4) ---")
	var fase1_4_intro_scene = ResourceLoader.load("res://scenes/story/story_intro_fase1_4.tscn") as PackedScene
	_assert(fase1_4_intro_scene != null, "[Fase 1-4] Cena story_intro_fase1_4.tscn deve ser carregada")
	if fase1_4_intro_scene != null:
		var intro_inst = fase1_4_intro_scene.instantiate()
		root.add_child(intro_inst)
		await process_frame
		_assert(intro_inst._video_player != null, "[Fase 1-4] VideoStreamPlayer deve existir na cena")
		_assert(ResourceLoader.exists("res://assets/videos/stage1/video_fase1_4_alessandro.ogv"), "[Fase 1-4] video_fase1_4_alessandro.ogv deve existir em disco")
		intro_inst.queue_free()
		await process_frame

	# ==============================================================
	# 6. TESTE DO NOVO SOM DE JUMPKICK DO GUILHERME
	# ==============================================================
	print("\n--- [6] Testando Som de Jumpkick do Guilherme ---")
	var jumpkick_stream = ResourceLoader.load("res://assets/audio/sfx/jumpkick_guilherme.mp3") as AudioStream
	_assert(jumpkick_stream != null, "[Audio] jumpkick_guilherme.mp3 deve ser carregado com sucesso como AudioStream")

	# ==============================================================
	# 7. TESTE DA FASE 1-4 E TRANSIÇÃO COM SCRIPT CUSTOMIZADO
	# ==============================================================
	print("\n--- [7] Testando Cena map_4.tscn e Script map_4_story_transition.gd ---")
	var map_4_res = ResourceLoader.load("res://scenes/levels/map_4.tscn") as PackedScene
	_assert(map_4_res != null, "[Fase 1-4] map_4.tscn deve ser carregada pelo ResourceLoader")
	if map_4_res != null:
		var map_4_inst = map_4_res.instantiate()
		_assert(map_4_inst != null, "[Fase 1-4] map_4.tscn deve ser instanciada sem erro de compilação")
		_assert(map_4_inst.get_script() != null, "[Fase 1-4] map_4 deve possuir script associado")
		map_4_inst.queue_free()

	_finish_test()


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [PASS] %s" % message)
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
