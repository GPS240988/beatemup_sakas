class_name Map4MeatHintDialogue
extends "res://scripts/events/map4_opening_dialogue.gd"

## Reutiliza a moldura, avatar, tipografia e typewriter oficiais do Mapa 4.
## A dica é não bloqueante e fecha sozinha após permanecer legível na tela.

const HINT_TEXT: String = "Dica do mestre: Destrua a carne antes que o Alessandro se alimente."
const AUTO_CLOSE_SECONDS: float = 5.5


func _ready() -> void:
	_dialogues = [{
		"speaker": "GABRIEL",
		"portrait": GABRIEL_PORTRAIT,
		"text": HINT_TEXT
	}]
	super._ready()
	if is_inside_tree():
		get_tree().create_timer(AUTO_CLOSE_SECONDS, true).timeout.connect(_close_dialogue)
