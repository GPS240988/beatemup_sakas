class_name LevelEventDirector
extends Node

## Diretor Central de Eventos e Interações de Fase (FASE 8).
## Orquestra sequências narrativas, mecânicas e transições dinâmicas de cenário:
## (Destruição de barricada -> Abertura de passagem -> Entrada de NPC -> Diálogo -> Ondas de Inimigos -> Combate -> Liberação de Saída).
## Desacopla toda a narrativa e lógica de eventos do BaseLevel.gd.

const DialogueDirectorClass = preload("res://scripts/events/dialogue_director.gd")
const LevelEventTriggerClass = preload("res://scripts/events/level_event_trigger.gd")

signal event_started(event_name: String)
signal event_completed(event_name: String)
signal stage_sequence_completed(sequence_name: String)

@export var auto_discover_nodes: bool = true

var active_events: Array[String] = []
var completed_events: Array[String] = []

@onready var spawn_director: Node = get_node_or_null("../SpawnDirector")
@onready var combat_director: Node = get_node_or_null("../CombatDirector")
@onready var dialogue_director: Node = get_node_or_null("DialogueDirector")
@onready var triggers_container: Node = get_node_or_null("Triggers")


func _ready() -> void:
	add_to_group("level_event_director")
	if auto_discover_nodes:
		_discover_directors()
	_bind_child_triggers()


func _discover_directors() -> void:
	if spawn_director == null and is_inside_tree():
		spawn_director = get_tree().get_first_node_in_group("spawn_director")
	if combat_director == null and is_inside_tree():
		combat_director = get_tree().get_first_node_in_group("combat_director")
	if dialogue_director == null:
		dialogue_director = get_node_or_null("DialogueDirector")
		if dialogue_director == null and is_inside_tree():
			dialogue_director = get_tree().get_first_node_in_group("dialogue_director")
		if dialogue_director == null:
			dialogue_director = DialogueDirectorClass.new()
			dialogue_director.name = "DialogueDirector"
			add_child(dialogue_director)


func _bind_child_triggers() -> void:
	if triggers_container != null:
		for child in triggers_container.get_children():
			if child is LevelEventTriggerClass:
				child.triggered.connect(_on_trigger_activated)


func _on_trigger_activated(trigger_id: String, payload: Dictionary) -> void:
	execute_event(trigger_id, payload)


## Ponto central para execução de evento de fase
func execute_event(event_name: String, params: Dictionary = {}) -> void:
	if active_events.has(event_name):
		return

	active_events.append(event_name)
	event_started.emit(event_name)

	match event_name:
		"dialogue":
			var speaker: String = params.get("speaker", "Narrador")
			var text: String = params.get("text", "")
			var duration: float = params.get("duration", 3.0)
			if dialogue_director != null and dialogue_director.has_method("show_message"):
				dialogue_director.show_message(speaker, text, duration)
			complete_event(event_name)

		"spawn_wave":
			var point_id: String = params.get("point_id", "")
			var scene: PackedScene = params.get("scene", null)
			var parent: Node = params.get("parent", null)
			if spawn_director != null and spawn_director.has_method("spawn_at_point"):
				spawn_director.spawn_at_point(point_id, scene, parent)
			complete_event(event_name)

		"unlock_exit":
			var exit: Area2D = params.get("exit_area", null)
			if exit == null and is_inside_tree():
				exit = get_tree().get_first_node_in_group("exit_area") as Area2D
			if exit != null:
				exit.set_deferred("monitoring", true)
			complete_event(event_name)

		_:
			# Evento customizado
			complete_event(event_name)


func complete_event(event_name: String) -> void:
	if active_events.has(event_name):
		active_events.erase(event_name)
	if not completed_events.has(event_name):
		completed_events.append(event_name)
	event_completed.emit(event_name)


## Executa uma sequência encadeada completa
func execute_story_sequence(sequence_name: String, steps: Array[Dictionary]) -> void:
	for step in steps:
		var ev_name: String = step.get("event", "")
		var ev_params: Dictionary = step.get("params", {})
		execute_event(ev_name, ev_params)
	stage_sequence_completed.emit(sequence_name)
