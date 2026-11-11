extends "res://scripts/levels/mobile_base_level.gd"

## Intercepta a entrada do Mapa 3 (Fase 1 - Seção 3).
## A árvore é pausada antes do primeiro frame de gameplay: jogador, inimigos,
## NPCs, diretores e demais atores não processam enquanto o diálogo do Gabriel
## está em tela. O Map3OpeningDialogueEvent recebe PROCESS_MODE_ALWAYS para
## continuar a cinemática mesmo com a árvore pausada.
## O gameplay (incluindo BGM) só é liberado após o jogador fechar a fala.

const Map3OpeningDialogueEventClass = preload(
	"res://scripts/events/map3_opening_dialogue.gd"
)

var _opening_flow_pending: bool = false
var _opening_tree_was_paused: bool = false


func _check_and_trigger_opening_narrative() -> bool:
	# O mapa 3 sempre exibe o diálogo de abertura do Gabriel antes do gameplay.
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

	# Exibe diretamente o diálogo do Gabriel (não há sequência narrativa
	# completa para o mapa 3: os vídeos OGV já rodaram no interlúdio anterior).
	_show_opening_dialogue()


func _show_opening_dialogue() -> void:
	if not _opening_flow_pending or not is_inside_tree():
		return

	var dialogue_event := (
		Map3OpeningDialogueEventClass.new() as Map3OpeningDialogueEvent
	)
	if dialogue_event == null:
		push_warning("Map3: não foi possível instanciar o diálogo do Gabriel.")
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
