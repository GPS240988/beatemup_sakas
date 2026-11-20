extends SceneTree

const SEQUENCE_PATH: String = "res://resources/story/story_intro_stage2.tres"
const INTRO_SCENE_PATH: String = "res://scenes/story/story_stage2_intro.tscn"
const LEVEL_SCENE_PATH: String = "res://scenes/levels/map_5.tscn"
const BBQ_IMAGE_PATH: String = "res://assets/backgrounds/maps/fase2/story_churrasco_fase2_1.webp"
const MACHINE_IMAGE_PATH: String = "res://assets/backgrounds/maps/fase2/story_happen_fase2_1.webp"
const LEVEL_IMAGE_PATH: String = "res://assets/backgrounds/maps/fase2/Fase2_3.webp"


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var sequence: Resource = load(SEQUENCE_PATH)
	_assert(sequence != null, "Recurso da sequência do Estágio 02 carrega")
	if sequence == null:
		quit(1)
		return

	var events: Array = sequence.get("events")
	_assert(events.size() == 3, "A abertura contém ligação, imagem silenciosa e decisão")
	if events.size() == 3:
		var call_event: Resource = events[0] as Resource
		var machine_event: Resource = events[1] as Resource
		var decision_event: Resource = events[2] as Resource
		_assert(str(call_event.get("image_path")) == BBQ_IMAGE_PATH, "A ligação usa a arte do churrasco")
		_assert(str(decision_event.get("image_path")) == BBQ_IMAGE_PATH, "A conversa retorna à mesma arte do churrasco")
		_assert(str(machine_event.get("image_path")) == MACHINE_IMAGE_PATH, "A cena intermediária aponta para a arte da máquina")
		_assert((machine_event.get("texts") as Array).is_empty(), "A imagem da máquina não possui diálogos")
		_assert(machine_event.get("duration_per_text") >= 4.0, "A imagem silenciosa possui tempo mínimo de apresentação")

	_assert(ResourceLoader.exists(INTRO_SCENE_PATH), "Cena de introdução do Estágio 02 existe")
	_assert(ResourceLoader.exists(LEVEL_SCENE_PATH), "Cena de entrada da Fase 2-1 existe")
	_assert(ResourceLoader.exists(LEVEL_IMAGE_PATH), "Arte panorâmica da Fase 2-1 existe localmente")
	_assert(ResourceLoader.exists(BBQ_IMAGE_PATH), "Arte do churrasco existe localmente")
	_assert(ResourceLoader.exists(MACHINE_IMAGE_PATH), "Arte da máquina existe localmente")

	print("TESTES DA ABERTURA DO ESTÁGIO 02 CONCLUÍDOS")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[OK] %s" % message)
	else:
		push_error("[FALHA] %s" % message)
