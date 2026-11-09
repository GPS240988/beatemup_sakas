extends SceneTree

## Suíte de Testes Automatizados: StoryIntroFase1_3 (Cinemáticas e Diálogos de Vídeo OGV)
## Valida a integridade dos vídeos do André e Juliana, retratos, diálogos, enquadramento e transição para map_3.

const StoryIntroClass = preload("res://scripts/story/story_intro_fase1_3.gd")

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("==================================================")
	print("INICIANDO TESTES: STORY INTRO FASE 1-3 (VIDEOS E DIÁLOGOS)")
	print("==================================================")
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % message)


func _run_tests() -> void:
	_test_assets_existence()
	_test_scene_structure_and_constants()
	_test_state_machine_flow()

	print("==================================================")
	print("RESULTADO DOS TESTES: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")
	quit(_failed)


func _test_assets_existence() -> void:
	print("\n--- 1. Validando Existência dos Assets de Vídeo e Imagem ---")
	_assert(ResourceLoader.exists(StoryIntroClass.VIDEO_ANDRE_PATH), "Vídeo do André (video_fase1_3_andre.ogv) existe no repositório")
	_assert(ResourceLoader.exists(StoryIntroClass.VIDEO_JULIANA_PATH), "Vídeo da Juliana (video_fase1_3_juliana.ogv) existe no repositório")
	_assert(ResourceLoader.exists(StoryIntroClass.PORTRAIT_ANDRE_PATH), "Retrato do André existe no repositório")
	_assert(ResourceLoader.exists(StoryIntroClass.PORTRAIT_JULIANA_PATH), "Retrato da Juliana existe no repositório")
	_assert(ResourceLoader.exists(StoryIntroClass.MAP_3_SCENE_PATH), "Cena de destino map_3.tscn existe no repositório")
	_assert(ResourceLoader.exists("res://scenes/story/story_intro_fase1_3.tscn"), "Cena story_intro_fase1_3.tscn existe no repositório")
	_assert(ResourceLoader.exists("res://scripts/levels/map_2_story_transition.gd"), "Script de transição map_2_story_transition.gd existe")

	var stream_andre := load(StoryIntroClass.VIDEO_ANDRE_PATH) as VideoStream
	var stream_juliana := load(StoryIntroClass.VIDEO_JULIANA_PATH) as VideoStream
	_assert(stream_andre != null, "Vídeo do André carrega como VideoStream válido")
	_assert(stream_juliana != null, "Vídeo da Juliana carrega como VideoStream válido")


func _test_scene_structure_and_constants() -> void:
	print("\n--- 2. Validando Diretrizes de Diálogos e Tipografia ---")
	_assert(StoryIntroClass.TEXT_ANDRE == "Filhas da puta, não era pra ter tantos bêbados aqui", "Texto do diálogo do André confere exatamente com a diretriz")
	_assert(StoryIntroClass.TEXT_JULIANA == "Ótima hora para decepar algumas cabeças", "Texto do diálogo da Juliana confere exatamente com a diretriz")


func _test_state_machine_flow() -> void:
	print("\n--- 3. Validando Instanciação e Layout do Vídeo ---")
	var instance := StoryIntroClass.new()
	root.add_child(instance)

	_assert(instance.get_node_or_null("Background") != null, "Nó Background foi instanciado")
	_assert(instance.get_node_or_null("VideoStage") != null, "Nó VideoStage (palco superior) foi instanciado")
	_assert(instance.get_node_or_null("VideoStage/VideoWrapper") != null, "Nó VideoWrapper foi instanciado")
	_assert(instance.get_node_or_null("VideoStage/VideoWrapper/VideoStreamPlayer") != null, "Nó VideoStreamPlayer foi instanciado")
	_assert(instance.get_node_or_null("FadeOverlay") != null, "Nó FadeOverlay foi instanciado")

	var video_stage: MarginContainer = instance.get_node_or_null("VideoStage") as MarginContainer
	_assert(video_stage != null and video_stage.anchor_bottom <= 0.72, "Palco do vídeo está contido na área superior (anchor_bottom <= 0.72) acima do diálogo")

	var dialogue_area: Control = instance.get_node_or_null("DialogueArea") as Control
	_assert(dialogue_area != null, "Nó DialogueArea (StandardDialogueBox) foi instanciado")
	if dialogue_area != null:
		_assert(dialogue_area.anchor_top >= 0.67, "Caixa de diálogo está contida na área inferior (anchor_top >= 0.67) sem sobrepor o vídeo")

	instance.queue_free()

