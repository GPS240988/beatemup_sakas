extends "res://scripts/events/narrative_director_desktop.gd"

## Especialização do diretor narrativo para a abertura do Estágio 02.
## O evento stage2_machine_silent apresenta somente a arte, sem caixa de diálogo,
## retrato, prompt ou texto sobreposto. A imagem permanece por duration_per_text.

const SILENT_MACHINE_EVENT_ID: String = "stage2_machine_silent"


func _display_image_event(
	 ev: Resource,
	 img_path: String,
	 entry_eff: String,
	 zoom_start: float,
	 zoom_end: float,
	 glitch_frames: int
) -> void:
	if str(ev.get("id")) != SILENT_MACHINE_EVENT_ID:
		super._display_image_event(ev, img_path, entry_eff, zoom_start, zoom_end, glitch_frames)
		return

	_arcade_fullscreen_mode = true
	_apply_responsive_layout()

	if _title_container != null:
		_title_container.visible = false
	if _dialogue_area != null:
		_dialogue_area.visible = false
	if _btn_mobile_advance != null:
		_btn_mobile_advance.visible = false
	if _mobile_revelation_button != null:
		_mobile_revelation_button.visible = false
	if _advance_prompt_box != null:
		_advance_prompt_box.visible = false
	if _crt_overlay != null:
		_crt_overlay.visible = false
	if _cena4_crt_overlay != null:
		_cena4_crt_overlay.visible = false
	if _glitch_bars != null:
		_glitch_bars.visible = false

	_load_texture_to_rect(img_path)
	if _image_rect == null:
		push_error("NarrativeDirectorStage2: ImageDisplay não foi inicializado.")
		return

	_image_rect.visible = true
	_image_rect.position = Vector2.ZERO
	_image_rect.scale = Vector2.ONE
	_image_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _image_rect.size.x > 0.0 and _image_rect.size.y > 0.0:
		_image_rect.pivot_offset = _image_rect.size * 0.5

	_is_transitioning = true
	_kill_tweens()
	_active_tween = create_tween()
	_active_tween.tween_property(
		_image_rect,
		"modulate:a",
		1.0,
		maxf(float(ev.get("transition_duration")), 0.1)
	).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_callback(func() -> void:
		if not is_inside_tree() or not is_playing:
			return
		_is_transitioning = false
		_show_current_text_block(ev)
	)


func _show_current_text_block(ev: Resource) -> void:
	if str(ev.get("id")) != SILENT_MACHINE_EVENT_ID:
		super._show_current_text_block(ev)
		return

	if _dialogue_area != null:
		_dialogue_area.visible = false
	if _btn_mobile_advance != null:
		_btn_mobile_advance.visible = false
	if _mobile_revelation_button != null:
		_mobile_revelation_button.visible = false
	if _advance_prompt_box != null:
		_advance_prompt_box.visible = false
	if _crt_overlay != null:
		_crt_overlay.visible = false

	_is_transitioning = true
	event_started.emit(SILENT_MACHINE_EVENT_ID, current_text_index)
	_hold_silent_machine_image(
		SILENT_MACHINE_EVENT_ID,
		maxf(float(ev.get("duration_per_text")), 0.1)
	)


func _hold_silent_machine_image(event_id: String, duration: float) -> void:
	await get_tree().create_timer(duration, true).timeout

	if not is_inside_tree() or not is_playing or current_sequence == null:
		return

	var events: Array = current_sequence.get("events")
	if current_event_index < 0 or current_event_index >= events.size():
		return

	var active_event: Resource = events[current_event_index] as Resource
	if active_event == null or str(active_event.get("id")) != event_id:
		return

	_is_transitioning = false
	_advance_to_next_event()
