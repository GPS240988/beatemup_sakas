class_name Map4MeatHintDialogue
extends "res://scripts/events/map4_opening_dialogue.gd"

## Segunda fala de Gabriel: orienta o jogador a atingir o Loro durante o grito.

const HINT_TEXT: String = "Dica de mestre: Toque no Loro enquanto ele grita."


func _ready() -> void:
	_dialogues = [{
		"speaker": "GABRIEL",
		"portrait": GABRIEL_PORTRAIT,
		"text": HINT_TEXT
	}]
	super._ready()
