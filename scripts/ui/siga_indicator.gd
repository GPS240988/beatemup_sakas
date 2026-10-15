class_name SigaIndicator
extends Control

## Indicador visual piscante "SIGA →" para liberação de avanço no mapa arcade.
## Fica visível e pulsa suavemente apenas quando o encontro de combate for concluído.

@export var text: String = "SIGA →"
@export var pulse_duration: float = 0.38
@export var min_alpha: float = 0.2
@export var max_alpha: float = 1.0

@onready var label: Label = get_node_or_null("PanelContainer/Label") as Label if get_node_or_null("PanelContainer/Label") != null else get_node_or_null("Label") as Label
@onready var arrow_rect: TextureRect = get_node_or_null("ArrowRect") as TextureRect

var _pulse_tween: Tween = null
var _is_active: bool = false


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	if label != null:
		label.text = text


## Ativa a indicação visual piscante "SIGA →"
func activate() -> void:
	if _is_active:
		return
	_is_active = true
	visible = true

	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate:a", max_alpha, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "modulate:a", min_alpha, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Desativa e oculta a indicação visual
func deactivate() -> void:
	_is_active = false
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	visible = false
	modulate.a = 0.0


func is_active() -> bool:
	return _is_active
