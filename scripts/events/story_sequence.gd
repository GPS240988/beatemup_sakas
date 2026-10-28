class_name StorySequence
extends Resource

## Recurso declarativo contendo uma sequência ordenada de eventos narrativos (StoryEvent).
## Permite composição de cutscenes declarativas desacopladas da lógica de combate.

const StoryEventClass = preload("res://scripts/events/story_event.gd")

@export var sequence_id: String = ""
@export var events: Array[Resource] = []


func get_event_count() -> int:
	return events.size()


func get_event(index: int) -> Resource:
	if index >= 0 and index < events.size():
		return events[index]
	return null
