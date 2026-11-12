extends "res://scripts/levels/mobile_base_level.gd"

## Controlador de Fase 1-4 (O Beco Final / Chefe Alessandro).
## A cinemática obrigatória é executada antes da inicialização do mapa.
## Após o vídeo, Juliana e Gabriel falam com o mapa pausado, antes do gameplay.

const STORY_INTRO_FASE1_4_PATH: String = "res://scenes/story/story_intro_fase1_4.tscn"
const Map4OpeningDialogueEventClass = preload(
	"res://scripts/events/map4_opening_dialogue.gd"
)

var _opening_flow_pending: bool = false
var _opening_tree_was_paused: bool = false


func _ready() -> void:
	# A cinemática precisa acontecer ANTES de BaseLevel._ready():
	# BaseLevel chama _check_and_trigger_opening_narrative() e pausa a árvore.
	# Se isso ocorrer antes do vídeo, a pausa pode persistir na troca de cenas
	# e o gameplay continuará congelado mesmo após fechar os diálogos.
	var session: Node = get_node_or_null("/root/GameSession")
	var has_seen: bool = false
	if session != null:
		has_seen = bool(session.get("has_seen_fase1_4_intro"))
	else:
		has_seen = bool(get_tree().root.get_meta("map4_intro_seen", false))

	if not has_seen:
		if ResourceLoader.exists(STORY_INTRO_FASE1_4_PATH):
			if session != null:
				session.set("has_seen_fase1_4_intro", true)
			else:
				get_tree().root.set_meta("map4_intro_seen", true)

			var change_error: Error = get_tree().change_scene_to_file(
				STORY_INTRO_FASE1_4_PATH
			)
			if change_error == OK:
				return

			# Se a troca falhar, permite tentar a cinemática novamente.
			if session != null:
				session.set("has_seen_fase1_4_intro", false)
			else:
				get_tree().root.set_meta("map4_intro_seen", false)
			push_error(
				"Map4: falha ao abrir a cinemática de introdução. Código: %d"
				% change_error
			)
		else:
			push_warning(
				"Map4: cinemática não encontrada; a abertura seguirá sem o vídeo."
			)

	# Só inicializa o gameplay depois da cinemática (ou se ela já foi vista).
	super._ready()


func _check_and_trigger_opening_narrative() -> bool:
	# O mapa 4 sempre exibe os diálogos de abertura antes do gameplay.
	# Retorna true para impedir o BGM antecipado.
	_trigger_opening_narrative()
	return true


func _trigger_opening_narrative() -> void:
	if _opening_flow_pending or not is_inside_tree():
		return

	_opening_flow_pending = true
	var tree: SceneTree = get_tree()
	_opening_tree_was_paused = tree.paused
	tree.paused = true
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

	# A música e o gameplay começam somente após fechar a fala do Gabriel.
	super._setup_level_bgm()
