class_name SigaIndicator
extends Control

## Indicador visual piscante "SIGA →" para liberação de avanço no mapa arcade.
## Fica visível e pulsa intensamente na tela quando o encontro de combate for concluído,
## acompanhando o viewport/câmera independente de onde o jogador estiver no mapa.

@export var text: String = "SIGA →"
@export var pulse_duration: float = 0.35
@export var min_alpha: float = 0.25
@export var max_alpha: float = 1.0

@onready var label: Label = get_node_or_null("PanelContainer/Label") as Label if get_node_or_null("PanelContainer/Label") != null else get_node_or_null("Label") as Label
@onready var arrow_rect: TextureRect = get_node_or_null("ArrowRect") as TextureRect

var _pulse_tween: Tween = null
var _bounce_tween: Tween = null
var _is_active: bool = false


func _ready() -> void:
	z_index = 100
	visible = false
	modulate.a = 0.0
	if label != null:
		label.text = text


func _process(_delta: float) -> void:
	if not _is_active:
		return

	# Garante que o indicador fique visível na tela independente de onde o personagem estiver no mapa
	var vp: Viewport = get_viewport()
	if vp != null:
		var cam: Camera2D = vp.get_camera_2d()
		if cam != null:
			var cam_center: Vector2 = cam.get_screen_center_position()
			var vp_size: Vector2 = vp.get_visible_rect().size
			# Posiciona à direita da visão do jogador (estilo clássico arcade GO →)
			var target_pos: Vector2 = Vector2(
				cam_center.x + (vp_size.x * 0.5) - size.x - 36.0,
				cam_center.y - (size.y * 0.5)
			)
			global_position = target_pos


## Ativa a indicação visual piscante "SIGA →"
func activate() -> void:
	if _is_active:
		return
	_is_active = true
	visible = true

	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	# Efeito pulsante de luminosidade arcade neon
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
