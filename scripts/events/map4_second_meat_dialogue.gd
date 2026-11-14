class_name Map4SecondMeatDialogue
extends "res://scripts/events/map4_opening_dialogue.gd"

## Primeira fala de Gabriel após o segundo drop: destruir a carne antes do chefe.

const HINT_TEXT: String = "Destrua a carne antes que Alessandro consiga alcançá-la!"


func _ready() -> void:
	_dialogues = [{
		"speaker": "GABRIEL",
		"portrait": GABRIEL_PORTRAIT,
		"text": HINT_TEXT
	}]
	super._ready()
