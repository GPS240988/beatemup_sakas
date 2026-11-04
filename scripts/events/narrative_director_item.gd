extends "res://scripts/events/narrative_director_desktop.gd"

## Variante exclusiva para inspeção de itens coletados (Emmanuele / Playboy).
## Apresentação cinematográfica fluida e translúcida (sem tela preta),
## idêntica à experiência de inspeção da carta mágica (counter_card_interaction.gd):
## - Fundo translúcido com dim (0.86 de opacidade), mantendo a fase visível.
## - Revelação da arte com animação ágil e fluida (pop-in com TRANS_BACK).
## - Saída suave sem fade to black que corte a imersão do jogador.
## - Caixa de diálogo padronizada e responsiva.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()
	if _fade_overlay != null:
		_fade_overlay.modulate.a = 0.0
		_fade_overlay.visible = false
	if _dark_base != null:
		_dark_base.color = Color(0.012, 0.015, 0.028, 0.86)


func _play_initial_fade_in() -> void:
	_kill_tweens()
	if _fade_overlay != null:
		_fade_overlay.modulate.a = 0.0
		_fade_overlay.visible = false
	if _dark_base != null:
		_dark_base.color = Color(0.012, 0.015, 0.028, 0.86)
		_dark_base.modulate.a = 0.0
	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _dark_base != null:
		_active_tween.tween_property(_dark_base, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_callback(func():
		_is_transitioning = false
		_process_current_event()
	)


func _display_image_event(
	ev: Resource,
	img_path: String,
	entry_eff: String,
	zoom_start: float,
	zoom_end: float,
	glitch_frames: int
) -> void:
	super._display_image_event(ev, img_path, entry_eff, zoom_start, zoom_end, glitch_frames)
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _fade_overlay != null:
		_fade_overlay.modulate.a = 0.0
		_fade_overlay.visible = false
	if _dark_base != null:
		_dark_base.color = Color(0.012, 0.015, 0.028, 0.86)
	if _image_rect != null:
		_image_rect.pivot_offset = _image_rect.size * 0.5
		_image_rect.scale = Vector2(0.08, 0.08)
		var pop_tween := create_tween()
		pop_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		pop_tween.tween_property(_image_rect, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _finish_sequence() -> void:
	if _btn_mobile_advance != null:
		_btn_mobile_advance.disabled = true
	if _mobile_revelation_button != null:
		_mobile_revelation_button.visible = false
	is_playing = false
	_is_transitioning = true
	_kill_tweens()

	var exit_tween := create_tween()
	exit_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _root_control != null:
		exit_tween.tween_property(_root_control, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_SINE)
	exit_tween.tween_callback(func():
		visible = false
		_is_transitioning = false
		var tree := get_tree()
		if tree != null:
			tree.paused = false
		_set_gameplay_suspended(false)
		var seq_id: String = str(current_sequence.get("sequence_id")) if current_sequence != null else ""
		sequence_completed.emit(seq_id)
	)


func _apply_desktop_presentation_mode() -> void:
	super._apply_desktop_presentation_mode()
	if _dark_base != null:
		_dark_base.color = Color(0.012, 0.015, 0.028, 0.86)
	if _fade_overlay != null:
		_fade_overlay.modulate.a = 0.0
		_fade_overlay.visible = false
	if _image_rect == null:
		return

	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image_rect.scale = Vector2.ONE
	_image_rect.position = Vector2.ZERO


## Para inspeção de itens, a imagem e o diálogo ocupam regiões distintas.
## O NarrativeDirector genérico permite sobreposição no mobile landscape;
## isso é adequado para cenas narrativas, mas não para artes de item verticais.
func _apply_responsive_layout() -> void:
	if not _is_mobile_runtime():
		super._apply_responsive_layout()
		return

	if _desktop_layout_update_in_progress:
		return
	if _root_control == null or _art_stage == null or _dialogue_area == null:
		return

	var viewport_size: Vector2 = _root_control.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_desktop_layout_update_in_progress = true

	var is_portrait: bool = viewport_size.x < viewport_size.y
	var art_bottom: float
	var dialogue_top: float
	if is_portrait:
		art_bottom = 0.38
		dialogue_top = 0.405
	elif viewport_size.y < 440.0:
		art_bottom = 0.62
		dialogue_top = 0.645
	else:
		art_bottom = 0.68
		dialogue_top = 0.705

	_art_stage.anchor_left = 0.0
	_art_stage.anchor_top = 0.0
	_art_stage.anchor_right = 1.0
	_art_stage.anchor_bottom = art_bottom
	_art_stage.offset_left = 0.0
	_art_stage.offset_top = 0.0
	_art_stage.offset_right = 0.0
	_art_stage.offset_bottom = 0.0
	_art_stage.clip_contents = true

	_dialogue_area.anchor_left = 0.0
	_dialogue_area.anchor_top = dialogue_top
	_dialogue_area.anchor_right = 1.0
	_dialogue_area.anchor_bottom = 0.99
	_dialogue_area.offset_left = 0.0
	_dialogue_area.offset_top = 0.0
	_dialogue_area.offset_right = 0.0
	_dialogue_area.offset_bottom = -6.0
	_dialogue_area.add_theme_constant_override("margin_left", 0)
	_dialogue_area.add_theme_constant_override("margin_right", 0)

	_apply_desktop_presentation_mode()
	_desktop_layout_update_in_progress = false


## Artes de itens podem ser muito estreitas ou altas. O quadro de fala mantém
## a largura da tela, em vez de herdar a largura reduzida da ilustração.
func _align_dialogue_area_to_image() -> void:
	if not _is_mobile_runtime():
		super._align_dialogue_area_to_image()
		return
	if _dialogue_area == null:
		return

	_dialogue_area.anchor_left = 0.0
	_dialogue_area.anchor_right = 1.0
	_dialogue_area.offset_left = 0.0
	_dialogue_area.offset_right = 0.0
	_dialogue_area.add_theme_constant_override("margin_left", 0)
	_dialogue_area.add_theme_constant_override("margin_right", 0)
