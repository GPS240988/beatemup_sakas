class_name Map4MeatHintDialogue
extends "res://scripts/events/map4_opening_dialogue.gd"

## Reutiliza a moldura, avatar, tipografia e typewriter oficiais do Mapa 4.
## A dica permanece visível até o jogador confirmar a leitura.

const HINT_TEXT: String = "Dica de mestre: Fale com o Loro."


func _ready() -> void:
	# GABRIEL_PORTRAIT é herdado de Map4OpeningDialogueEvent; não redeclarar.
	_dialogues = [{
		"speaker": "GABRIEL",
		"portrait": GABRIEL_PORTRAIT,
		"text": HINT_TEXT
	}]
	super._ready()
