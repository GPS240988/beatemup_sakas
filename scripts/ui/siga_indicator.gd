class_name SigaIndicator
extends Control

## Indicador visual de avanço no mapa arcade:
## Exibe "VAMOS, MALACOS! →" (assets/backgrounds/vamos.webp) no centro superior
## com animação de impacto e pulso contínuo arcade.
## A placa de saída (siga.webp) foi desativada por decisão de design — apenas o banner pulsa.

@export var delay_before_appear: float = 0.35
@export var pulse_duration: float = 0.32

@onready var vamos_control: Control = get_node_or_null("%VamosControl") as Control
@onready var vamos_rect: TextureRect = get_node_or_null("%VamosRect") as TextureRect
@onready var exit_sign_sprite: Sprite2D = get_node_or_null("%ExitSignSprite") as Sprite2D

var _is_active: bool = false
var _impact_tween: Tween = null
var _banner_pulse_tween: Tween = null


func _ready() -> void:
	visible = false
	if vamos_control != null:
		vamos_control.visible = false
		vamos_control.modulate.a = 0.0
	# A placa de saída permanece oculta permanentemente
	if exit_sign_sprite != null:
		exit_sign_sprite.visible = false
		exit_sign_sprite.modulate.a = 0.0


## Ativa a sequência oficial: VAMOS, MALACOS! no topo com pulso arcade
func activate() -> void:
	if _is_active:
		return
	_is_active = true
	visible = true

	# Breve intervalo antes do impacto cinematográfico
	if delay_before_appear > 0.0:
		await get_tree().create_timer(delay_before_appear).timeout
		if not _is_active:
			return

	_start_vamos_impact()
	# Placa de saída desativada por design — não mais piscante


func _start_vamos_impact() -> void:
	if vamos_control == null:
		return

	if _impact_tween != null and _impact_tween.is_valid():
		_impact_tween.kill()
	if _banner_pulse_tween != null and _banner_pulse_tween.is_valid():
		_banner_pulse_tween.kill()

	vamos_control.visible = true
	vamos_control.scale = Vector2(1.45, 1.45)
	vamos_control.modulate.a = 0.0

	# Animação rápida de impacto: slam down com overshoot elástico (TRANS_BACK, EASE_OUT)
	_impact_tween = create_tween().set_parallel(true)
	_impact_tween.tween_property(vamos_control, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_impact_tween.tween_property(vamos_control, "modulate:a", 1.0, 0.08)

	_impact_tween.chain().tween_callback(func():
		if not _is_active:
			return
		# Pulso contínuo arcade após o impacto (escala + alpha pulsante)
		_banner_pulse_tween = create_tween().set_loops()
		_banner_pulse_tween.tween_property(vamos_control, "scale", Vector2(1.05, 1.05), 0.35).set_trans(Tween.TRANS_SINE)
		_banner_pulse_tween.tween_property(vamos_control, "modulate:a", 0.65, 0.35).set_trans(Tween.TRANS_SINE)
		_banner_pulse_tween.tween_property(vamos_control, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
		_banner_pulse_tween.tween_property(vamos_control, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	)


## Desativa e oculta a indicação visual
func deactivate() -> void:
	_is_active = false

	if _impact_tween != null and _impact_tween.is_valid():
		_impact_tween.kill()
	if _banner_pulse_tween != null and _banner_pulse_tween.is_valid():
		_banner_pulse_tween.kill()

	if vamos_control != null:
		vamos_control.visible = false
		vamos_control.modulate.a = 0.0
	if exit_sign_sprite != null:
		exit_sign_sprite.visible = false
		exit_sign_sprite.modulate.a = 0.0

	visible = false


func is_active() -> bool:
	return _is_active
