class_name MapStagePoint
extends Control

## Componente de Hotspot / Marcador de Fase no Mapa
## Visual Neo-16-bit com medalhão arcade, seta indicadora pulsante e banner chanfrado.

signal stage_clicked(index: int)

@export var stage_index: int = 0
@export var stage_id: String = "01"
@export var stage_title: String = "O REENCONTRO"
@export var display_tag: String = "O REENCONTRO"
@export var is_unlocked: bool = true
@export var is_selected: bool = false

@onready var arrow_label: Label = %ArrowLabel
@onready var medallion_panel: PanelContainer = %MedallionPanel
@onready var medallion_label: Label = %MedallionLabel
@onready var tag_panel: PanelContainer = %TagPanel
@onready var tag_label: Label = %TagLabel
@onready var hit_button: Button = %HitButton

var _bob_tween: Tween = null


func _ready() -> void:
	if hit_button != null:
		hit_button.pressed.connect(_on_hit_button_pressed)
		hit_button.mouse_entered.connect(_on_mouse_entered)
		hit_button.mouse_exited.connect(_on_mouse_exited)

	update_display()


func setup(idx: int, id_str: String, title_str: String, tag_str: String, unlocked: bool) -> void:
	stage_index = idx
	stage_id = id_str
	stage_title = title_str
	display_tag = tag_str if not tag_str.is_empty() else title_str
	is_unlocked = unlocked
	update_display()


func set_selected(selected: bool) -> void:
	is_selected = selected
	update_display()


func update_display() -> void:
	if medallion_label != null:
		medallion_label.text = stage_id if is_unlocked else "🔒"

	if tag_label != null:
		tag_label.text = display_tag

	if arrow_label != null:
		arrow_label.visible = is_selected
		if is_selected:
			_start_arrow_animation()
		else:
			_stop_arrow_animation()

	_apply_visual_styles()


func _start_arrow_animation() -> void:
	_stop_arrow_animation()
	if arrow_label == null:
		return
	arrow_label.position.y = -32.0
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(arrow_label, "position:y", -38.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bob_tween.tween_property(arrow_label, "position:y", -28.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _stop_arrow_animation() -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
		_bob_tween = null
	if arrow_label != null:
		arrow_label.position.y = -30.0


func _apply_visual_styles() -> void:
	if medallion_panel == null or tag_panel == null:
		return

	var med_style := StyleBoxFlat.new()
	med_style.set_corner_radius_all(27)

	var tag_style := StyleBoxFlat.new()
	tag_style.set_corner_radius_all(3)
	tag_style.set_content_margin_all(4)

	if is_selected:
		# Destaque de fase selecionada: Vermelho arcade brilhante com anel branco e glow magenta
		med_style.bg_color = Color(0.98, 0.21, 0.24, 1.0)
		med_style.border_width_left = 4
		med_style.border_width_top = 4
		med_style.border_width_right = 4
		med_style.border_width_bottom = 4
		med_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
		med_style.shadow_color = Color(1.0, 0.12, 0.36, 0.85)
		med_style.shadow_size = 14

		tag_style.bg_color = Color(0.81, 0.08, 0.18, 1.0)
		tag_style.border_width_left = 2
		tag_style.border_width_top = 1
		tag_style.border_width_right = 2
		tag_style.border_width_bottom = 1
		tag_style.border_color = Color(1.0, 0.5, 0.6, 0.7)

		if medallion_label != null:
			medallion_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	elif is_unlocked:
		# Fase desbloqueada (não selecionada): Fundo escuro com borda dourada/marfim
		med_style.bg_color = Color(0.043, 0.039, 0.067, 0.95)
		med_style.border_width_left = 3
		med_style.border_width_top = 3
		med_style.border_width_right = 3
		med_style.border_width_bottom = 3
		med_style.border_color = Color(1.0, 0.965, 0.863, 1.0)
		med_style.shadow_color = Color(0, 0, 0, 0.5)
		med_style.shadow_size = 6

		tag_style.bg_color = Color(0.027, 0.024, 0.063, 0.92)
		tag_style.border_width_left = 1
		tag_style.border_width_top = 1
		tag_style.border_width_right = 1
		tag_style.border_width_bottom = 1
		tag_style.border_color = Color(0.3, 0.3, 0.45, 0.6)

		if medallion_label != null:
			medallion_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1))
	else:
		# Fase bloqueada: Desbotada com cadeado
		med_style.bg_color = Color(0.04, 0.04, 0.07, 0.75)
		med_style.border_width_left = 2
		med_style.border_width_top = 2
		med_style.border_width_right = 2
		med_style.border_width_bottom = 2
		med_style.border_color = Color(0.4, 0.4, 0.5, 0.5)
		med_style.shadow_size = 2

		tag_style.bg_color = Color(0.02, 0.02, 0.04, 0.75)
		tag_style.border_width_left = 1
		tag_style.border_width_top = 1
		tag_style.border_width_right = 1
		tag_style.border_width_bottom = 1
		tag_style.border_color = Color(0.25, 0.25, 0.35, 0.4)

		if medallion_label != null:
			medallion_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.7))

	medallion_panel.add_theme_stylebox_override("panel", med_style)
	tag_panel.add_theme_stylebox_override("panel", tag_style)


func _on_hit_button_pressed() -> void:
	stage_clicked.emit(stage_index)


func _on_mouse_entered() -> void:
	if not is_selected:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_SINE)


func _on_mouse_exited() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE)

