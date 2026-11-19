class_name MapStagePoint
extends Control

## Componente de Hotspot / Marcador de Fase no Mapa — Projeto Sakas
## Visual Neo-16-bit com medalhão arcade, seta indicadora pulsante e banner chanfrado.
## Suporta estados: Selecionado, Disponível (Ciano), Concluído (Ouro), Bônus (Presente/Magenta) e Bloqueado (Cadeado).

signal stage_clicked(index: int)

@export var stage_index: int = 0
@export var stage_id: String = "1-1"
@export var stage_title: String = "A LOCADORA"
@export var display_tag: String = "A LOCADORA"
@export var is_unlocked: bool = true
@export var is_completed: bool = false
@export var is_selected: bool = false
@export var is_bonus: bool = false

@onready var arrow_label: Label = %ArrowLabel
@onready var medallion_panel: PanelContainer = %MedallionPanel
@onready var medallion_label: Label = %MedallionLabel
@onready var tag_panel: PanelContainer = %TagPanel
@onready var tag_label: Label = %TagLabel
@onready var hit_button: Button = %HitButton

var _bob_tween: Tween = null
var _pulse_tween: Tween = null


func _ready() -> void:
	if hit_button != null:
		hit_button.pressed.connect(_on_hit_button_pressed)
		hit_button.mouse_entered.connect(_on_mouse_entered)
		hit_button.mouse_exited.connect(_on_mouse_exited)

	update_display()


func setup(idx: int, id_str: String, title_str: String, tag_str: String, unlocked: bool, completed: bool = false, bonus: bool = false) -> void:
	stage_index = idx
	stage_id = id_str
	stage_title = title_str
	display_tag = tag_str if not tag_str.is_empty() else title_str
	is_unlocked = unlocked
	is_completed = completed
	is_bonus = bonus
	update_display()


func set_selected(selected: bool) -> void:
	is_selected = selected
	update_display()
	if is_selected:
		_start_pulse_animation()
	else:
		_stop_pulse_animation()


func update_display() -> void:
	if medallion_label != null:
		if is_unlocked:
			if is_bonus:
				medallion_label.text = "🎁"
			else:
				medallion_label.text = stage_id
		else:
			medallion_label.text = "🔒"

	if tag_label != null:
		tag_label.text = display_tag

	if arrow_label != null:
		arrow_label.visible = false
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


func _start_pulse_animation() -> void:
	_stop_pulse_animation()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse_animation() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	scale = Vector2(1.0, 1.0)


func play_unlock_animation() -> void:
	var vfx_scene := preload("res://scripts/ui/map_unlock_vfx.gd")
	if vfx_scene != null:
		var vfx: Node2D = vfx_scene.new()
		vfx.position = Vector2(size.x * 0.5, 35.0)
		add_child(vfx)
		vfx.play_burst()
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(vfx):
				vfx.queue_free()
		)


func _apply_visual_styles() -> void:
	if medallion_panel == null or tag_panel == null:
		return

	var med_style := StyleBoxFlat.new()
	med_style.set_corner_radius_all(27)

	var tag_style := StyleBoxFlat.new()
	tag_style.set_corner_radius_all(3)
	tag_style.set_content_margin_all(4)

	if is_bonus:
		# Arte diferenciada exclusiva para fases Bônus: Joia Chanfrada Ouro & Rubi
		med_style.corner_radius_top_left = 8
		med_style.corner_radius_bottom_right = 8
		med_style.corner_radius_top_right = 26
		med_style.corner_radius_bottom_left = 26
		med_style.border_width_left = 4
		med_style.border_width_top = 4
		med_style.border_width_right = 4
		med_style.border_width_bottom = 4

		tag_style.corner_radius_top_left = 4
		tag_style.corner_radius_top_right = 4
		tag_style.corner_radius_bottom_right = 4
		tag_style.corner_radius_bottom_left = 4
		tag_style.border_width_left = 2
		tag_style.border_width_top = 1
		tag_style.border_width_right = 2
		tag_style.border_width_bottom = 1

		if is_selected:
			med_style.bg_color = Color(0.92, 0.12, 0.38, 1.0)
			med_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
			med_style.shadow_color = Color(1.0, 0.84, 0.15, 0.95)
			med_style.shadow_size = 18

			tag_style.bg_color = Color(0.75, 0.08, 0.28, 1.0)
			tag_style.border_color = Color(1.0, 0.90, 0.40, 1.0)

			if medallion_label != null:
				medallion_label.text = "★" if is_unlocked else "🔒"
				medallion_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			if tag_label != null:
				tag_label.text = "★ BÔNUS ★"
				tag_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))

		elif is_unlocked:
			med_style.bg_color = Color(0.24, 0.03, 0.16, 0.98)
			med_style.border_color = Color(1.0, 0.84, 0.20, 1.0)
			med_style.shadow_color = Color(0.95, 0.15, 0.55, 0.75)
			med_style.shadow_size = 12

			tag_style.bg_color = Color(0.18, 0.02, 0.12, 0.95)
			tag_style.border_color = Color(1.0, 0.84, 0.20, 0.9)

			if medallion_label != null:
				medallion_label.text = "★"
				medallion_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.3, 1.0))
			if tag_label != null:
				tag_label.text = "★ BÔNUS ★"
				tag_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.6, 1.0))

		else:
			med_style.bg_color = Color(0.08, 0.02, 0.06, 0.75)
			med_style.border_color = Color(0.55, 0.45, 0.25, 0.5)
			med_style.shadow_size = 2

			tag_style.bg_color = Color(0.05, 0.01, 0.04, 0.70)
			tag_style.border_color = Color(0.4, 0.3, 0.2, 0.4)

			if medallion_label != null:
				medallion_label.text = "🔒"
				medallion_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.6, 0.6))
			if tag_label != null:
				tag_label.text = "★ BÔNUS ★"
				tag_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.6, 0.6))

	elif is_selected:
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
		if tag_label != null:
			tag_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	elif is_completed:
		# Fase concluída: Dourado Premium Medieval com ouro nobre e brilho suave
		med_style.bg_color = Color(0.08, 0.06, 0.02, 0.95)
		med_style.border_width_left = 3
		med_style.border_width_top = 3
		med_style.border_width_right = 3
		med_style.border_width_bottom = 3
		med_style.border_color = Color(1.0, 0.85, 0.25, 1.0)
		med_style.shadow_color = Color(0.85, 0.65, 0.10, 0.5)
		med_style.shadow_size = 8

		tag_style.bg_color = Color(0.06, 0.04, 0.02, 0.92)
		tag_style.border_width_left = 1
		tag_style.border_width_top = 1
		tag_style.border_width_right = 1
		tag_style.border_width_bottom = 1
		tag_style.border_color = Color(0.85, 0.70, 0.20, 0.75)

		if medallion_label != null:
			medallion_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.40, 1.0))
		if tag_label != null:
			tag_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))

	elif is_bonus and is_unlocked:
		# Fase de Bônus desbloqueada: Identidade própria magenta/dourada arcade
		med_style.bg_color = Color(0.12, 0.02, 0.08, 0.95)
		med_style.border_width_left = 3
		med_style.border_width_top = 3
		med_style.border_width_right = 3
		med_style.border_width_bottom = 3
		med_style.border_color = Color(1.0, 0.35, 0.70, 1.0)
		med_style.shadow_color = Color(0.85, 0.15, 0.50, 0.6)
		med_style.shadow_size = 8

		tag_style.bg_color = Color(0.06, 0.01, 0.05, 0.92)
		tag_style.border_width_left = 1
		tag_style.border_width_top = 1
		tag_style.border_width_right = 1
		tag_style.border_width_bottom = 1
		tag_style.border_color = Color(0.9, 0.3, 0.6, 0.7)

		if medallion_label != null:
			medallion_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		if tag_label != null:
			tag_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.95, 1.0))

	elif is_unlocked:
		# Fase desbloqueada / disponível (não concluída): Brilho ciano vibrante
		med_style.bg_color = Color(0.02, 0.04, 0.08, 0.95)
		med_style.border_width_left = 3
		med_style.border_width_top = 3
		med_style.border_width_right = 3
		med_style.border_width_bottom = 3
		med_style.border_color = Color(0.0, 0.94, 1.0, 1.0)
		med_style.shadow_color = Color(0.0, 0.80, 0.95, 0.55)
		med_style.shadow_size = 8

		tag_style.bg_color = Color(0.02, 0.03, 0.06, 0.92)
		tag_style.border_width_left = 1
		tag_style.border_width_top = 1
		tag_style.border_width_right = 1
		tag_style.border_width_bottom = 1
		tag_style.border_color = Color(0.0, 0.85, 1.0, 0.7)

		if medallion_label != null:
			medallion_label.add_theme_color_override("font_color", Color(0.85, 0.98, 1.0, 1.0))
		if tag_label != null:
			tag_label.add_theme_color_override("font_color", Color(0.85, 0.98, 1.0, 1.0))

	else:
		# Fase bloqueada: Escurecida com cadeado
		med_style.bg_color = Color(0.03, 0.03, 0.05, 0.75)
		med_style.border_width_left = 2
		med_style.border_width_top = 2
		med_style.border_width_right = 2
		med_style.border_width_bottom = 2
		med_style.border_color = Color(0.35, 0.35, 0.45, 0.45)
		med_style.shadow_size = 2

		tag_style.bg_color = Color(0.02, 0.02, 0.03, 0.70)
		tag_style.border_width_left = 1
		tag_style.border_width_top = 1
		tag_style.border_width_right = 1
		tag_style.border_width_bottom = 1
		tag_style.border_color = Color(0.25, 0.25, 0.35, 0.35)

		if medallion_label != null:
			medallion_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.6))
		if tag_label != null:
			tag_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55, 0.6))

	medallion_panel.add_theme_stylebox_override("panel", med_style)
	tag_panel.add_theme_stylebox_override("panel", tag_style)


func _on_hit_button_pressed() -> void:
	stage_clicked.emit(stage_index)


func _on_mouse_entered() -> void:
	if not is_selected:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_SINE)


func _on_mouse_exited() -> void:
	if not is_selected:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE)
