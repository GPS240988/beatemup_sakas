extends "res://scripts/levels/mobile_base_level.gd"

## Controlador de Fase 1-4 (O Beco Final / Chefe Alessandro).
## Garante que o vídeo de introdução do Chefe Alessandro seja apresentado assim
## que a fase começar, mesmo se carregada diretamente.
## Após o vídeo, o mapa carrega pausado e exibe os diálogos de abertura
## (Juliana e Gabriel) antes de liberar o gameplay.

const STORY_INTRO_FASE1_4_PATH: String = "res://scenes/story/story_intro_fase1_4.tscn"
const Map4OpeningDialogueEventClass = preload(
	"res://scripts/events/map4_opening_dialogue.gd"
)

var _opening_flow_pending: bool = false
var _opening_tree_was_paused: bool = false


func _ready() -> void:
	# Garante a inicialização completa do BaseLevel (câmera, combate, spawn, etc.)
	super._ready()

	var session = get_node_or_null("/root/GameSession")
	var has_seen: bool = false
	if session != null:
		if "has_seen_fase1_4_intro" in session:
			has_seen = bool(session.has_seen_fase1_4_intro)
		elif session.get("has_seen_fase1_4_intro") != null:
			has_seen = bool(session.get("has_seen_fase1_4_intro"))

	if not has_seen:
		if session != null:
			if "has_seen_fase1_4_intro" in session:
				session.has_seen_fase1_4_intro = true
			else:
				session.set("has_seen_fase1_4_intro", true)
		if ResourceLoader.exists(STORY_INTRO_FASE1_4_PATH):
			get_tree().change_scene_to_file(STORY_INTRO_FASE1_4_PATH)
			return
	# Se já viu o intro ou a cena não existe, dispara o diálogo de abertura direto no mapa
	# Usa call_deferred para evitar problemas de inicialização durante o _ready()
	call_deferred("_trigger_opening_narrative")


func _check_and_trigger_opening_narrative() -> bool:
	# O mapa 4 sempre exibe os diálogos de abertura (Juliana e Gabriel) antes do gameplay.
	# Retorna true para que BaseLevel não inicie o BGM antecipadamente;
	# o BGM é iniciado em _release_opening_flow() após fechar a fala.
	_trigger_opening_narrative()
	return true


func _trigger_opening_narrative() -> void:
	if _opening_flow_pending or not is_inside_tree():
		return

	_opening_flow_pending = true
	var tree: SceneTree = get_tree()
	_opening_tree_was_paused = tree.paused
	tree.paused = true

	# Exibe os diálogos de abertura (Juliana e Gabriel) com a árvore pausada.
	_show_opening_dialogue()


func _show_opening_dialogue() -> void:
	if not _opening_flow_pending or not is_inside_tree():
		return

	var dialogue_event := (
		Map4OpeningDialogueEventClass.new() as Map4OpeningDialogueEvent
	)
	if dialogue_event == null:
		push_warning("Map4: não foi possível instanciar o diálogo de abertura.")
		_release_opening_flow()
		return

	dialogue_event.process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_event.dialogue_closed.connect(_on_opening_dialogue_closed)
	add_child(dialogue_event)


func _on_opening_dialogue_closed() -> void:
	_release_opening_flow()


func _release_opening_flow() -> void:
	_opening_flow_pending = false
	if get_tree() != null:
		get_tree().paused = _opening_tree_was_paused

	# A música e o processamento do mapa começam somente após fechar a fala.
	super._setup_level_bgm()
