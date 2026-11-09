extends SceneTree

## Suíte de Testes Automatizados: StoryIntroFase1_2 (Arte CRT da Locadora)
## Valida a integridade da apresentação da arte da locadora e transição para map_2.

const StoryIntroClass = preload("res://scripts/story/story_intro_fase1_2.gd")

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("==================================================")
	print("INICIANDO TESTES: STORY INTRO FASE 1-2 (ARTE CRT LOCADORA)")
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
	_test_instance_creation()

	print("==================================================")
	print("RESULTADO DOS TESTES: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")
	quit(_failed)


func _test_assets_existence() -> void:
	print("\n--- 1. Validando Existência dos Assets de Imagem e Cena ---")
	_assert(ResourceLoader.exists(StoryIntroClass.STORY_IMAGE_PATH), "Arte story_intro_fase1_2.webp existe no repositório")
	_assert(ResourceLoader.exists(StoryIntroClass.MAP_2_SCENE_PATH), "Cena de destino map_2.tscn existe no repositório")
	_assert(ResourceLoader.exists("res://scenes/story/story_intro_fase1_2.tscn"), "Cena story_intro_fase1_2.tscn existe no repositório")


func _test_instance_creation() -> void:
	print("\n--- 2. Validando Instanciação e Componentes da Cena ---")
	var instance := StoryIntroClass.new()
	root.add_child(instance)

	_assert(instance.get_node_or_null("Background") != null, "Nó Background foi instanciado")
	_assert(instance.get_node_or_null("StoryArtwork") != null, "Nó StoryArtwork foi instanciado")
	_assert(instance.get_node_or_null("FadeOverlay") != null, "Nó FadeOverlay foi instanciado")

	instance.queue_free()
