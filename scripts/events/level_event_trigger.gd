class_name LevelEventTrigger
extends Area2D

## Gatilho de Evento de Nível (FASE 8).
## Permite acionar eventos por colisão com jogador, por sinal de destruição de prop,
## por derrota de inimigo ou por chamada programática direta.

signal triggered(trigger_id: String, payload: Dictionary)

@export_group("Configuração do Gatilho")
@export var trigger_id: String = "event_trigger"
@export var trigger_once: bool = true
@export var auto_trigger_on_player_enter: bool = true
@export var event_payload: Dictionary = {}

var is_activated: bool = false


func _ready() -> void:
	add_to_group("level_triggers")
	# Monitora a Layer 1 (Atores / Player)
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false

	if auto_trigger_on_player_enter:
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_activated and trigger_once:
		return

	if body.is_in_group("player"):
		trigger({"activator": body})


## Aciona o gatilho manualmente ou por sinal externo (ex: prop_destroyed)
func trigger(custom_payload: Dictionary = {}) -> void:
	if is_activated and trigger_once:
		return

	is_activated = true
	var merged_payload: Dictionary = event_payload.duplicate()
	for k in custom_payload:
		merged_payload[k] = custom_payload[k]

	triggered.emit(trigger_id, merged_payload)

	if trigger_once:
		set_deferred("monitoring", false)


## Vincula o gatilho à destruição de um objeto destrutível
func bind_to_destructible(prop: Node) -> void:
	if prop != null and prop.has_signal("prop_destroyed"):
		prop.connect("prop_destroyed", func() -> void:
			trigger({"cause": "destructible_broken", "prop": prop})
		)


## Vincula o gatilho à conclusão de combate
func bind_to_combat_cleared(director: Node) -> void:
	if director != null and director.has_signal("encounter_cleared"):
		director.connect("encounter_cleared", func() -> void:
			trigger({"cause": "combat_cleared"})
		)
