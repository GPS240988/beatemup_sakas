class_name DialogueDirector
extends Node

## Diretor e Sistema de Diálogos e Mensagens de Nível (FASE 8).
## Totalmente desacoplado da lógica de combate.
## Responsável por exibir mensagens contextuais, balões de texto, diálogos entre personagens e anúncios de fase.

signal message_started(speaker: String, text: String)
signal message_completed(speaker: String, text: String)
signal sequence_started()
signal sequence_completed()

@export var default_message_duration: float = 3.0

var is_displaying: bool = false
var current_speaker: String = ""
var current_text: String = ""

var _message_queue: Array[Dictionary] = []
var _timer: float = 0.0


func _ready() -> void:
	add_to_group("dialogue_director")


func _process(delta: float) -> void:
	if not is_displaying:
		return

	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_advance_queue()


## Exibe mensagem única na tela
func show_message(speaker: String, text: String, duration: float = -1.0) -> void:
	var msg_duration: float = duration if duration > 0.0 else default_message_duration
	_message_queue.clear()
	_message_queue.append({
		"speaker": speaker,
		"text": text,
		"duration": msg_duration
	})
	_play_next_message()


## Enfileira e reproduz uma sequência de diálogos/mensagens
func play_sequence(messages: Array[Dictionary]) -> void:
	_message_queue.clear()
	for m in messages:
		_message_queue.append(m)
	sequence_started.emit()
	_play_next_message()


func _play_next_message() -> void:
	if _message_queue.is_empty():
		is_displaying = false
		current_speaker = ""
		current_text = ""
		sequence_completed.emit()
		return

	var current: Dictionary = _message_queue.pop_front()
	current_speaker = current.get("speaker", "")
	current_text = current.get("text", "")
	_timer = current.get("duration", default_message_duration)
	is_displaying = true

	message_started.emit(current_speaker, current_text)


func _advance_queue() -> void:
	message_completed.emit(current_speaker, current_text)
	_play_next_message()


## Pula ou conclui imediatamente a mensagem atual
func skip_current() -> void:
	if not is_displaying:
		return
	_advance_queue()


## Cancela e limpa todas as mensagens pendentes
func cancel_all() -> void:
	_message_queue.clear()
	is_displaying = false
	current_speaker = ""
	current_text = ""
