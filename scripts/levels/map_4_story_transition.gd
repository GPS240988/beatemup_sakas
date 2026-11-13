extends "res://scripts/levels/mobile_base_level.gd"

## Controlador de Fase 1-4 (O Beco Final / Chefe Alessandro).
## A cinemática obrigatória é executada antes da inicialização do mapa.
## Após o vídeo, Juliana e Gabriel falam com o mapa pausado, antes do gameplay.

const STORY_INTRO_FASE1_4_PATH: String = "res://scenes/story/story_intro_fase1_4.tscn"
const Map4OpeningDialogueEventClass = preload(
	"res://scripts/events/map4_opening_dialogue.gd"
)
const MAP4_BEBADO_SCENE: PackedScene = preload("res://scenes/actors/enemies/bebado_enemy.tscn")

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


## Coordena a onda de reforços e o surgimento do chefe sem confundir a
## reserva de spawn do Alessandro com reforços ainda não instanciados.
func _on_enemy_defeated(_enemy: CharacterBody2D) -> void:
	if reinforcement_waves_enabled and not _reinforcement_wave_triggered:
		if combat_director != null and combat_director.alive_enemies.size() <= reinforcement_trigger_enemy_count:
			_trigger_reinforcement_wave()

	_try_spawn_boss_after_reinforcements()


## O CombatDirector mantém uma pendência reservada para o próprio boss desde
## BaseLevel._ready(). Por isso, pending_spawns_count nunca será zero antes
## de instanciar o Alessandro. A condição correta é não haver inimigos vivos
## nem reforços ainda aguardando instanciação.
func _try_spawn_boss_after_reinforcements() -> void:
	if boss_scene == null or _boss_spawned or combat_director == null:
		return
	if not combat_director.alive_enemies.is_empty():
		return
	if _pending_reinforcements_to_spawn > 0:
		return
	if reinforcement_waves_enabled and not _reinforcement_wave_triggered:
		return

	_spawn_boss()


## No Mapa 4, a onda de respawn contém um Tank e um Bêbado Grunt.
## O BaseLevel instancia o Tank configurado na cena e registra sua pendência;
## aqui adicionamos o Bêbado como segundo combatente do mesmo reforço.
func _on_reinforcement_timer_timeout() -> void:
	super._on_reinforcement_timer_timeout()
	if not is_inside_tree() or _transitioning or _pending_reinforcements_to_spawn > 0:
		return
	var actors_container: Node2D = get_actors_container()
	var drunk := MAP4_BEBADO_SCENE.instantiate() as CharacterBody2D
	if drunk == null:
		push_warning("Map4: não foi possível instanciar o Bêbado Grunt do respawn.")
		return
	var spawn_position: Vector2 = get_offscreen_spawn_position(1, 2)
	drunk.global_position = spawn_position
	actors_container.add_child(drunk)
	if combat_director != null:
		combat_director.register_enemy(drunk)

	# Também cobre o caso de a instanciação de um reforço falhar: quando a
	# onda termina sem inimigos vivos, o boss pode entrar sem ficar travado.
	_try_spawn_boss_after_reinforcements()
