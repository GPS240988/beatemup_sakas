extends "res://scripts/story/story_intro_fase1_3.gd"

## Variante obrigatória da cinemática Map 2 -> Map 3.
## Os vídeos avançam exclusivamente pelo sinal finished de cada VideoStreamPlayer.
## Após o vídeo da Juliana, transiciona diretamente para map_3.tscn.
## O diálogo de dica do Mestre com o Gabriel é exibido dentro do map_3.tscn
## (mapa carregado pausado), antes de liberar o gameplay.

@export_range(0.0, 5.0, 0.1) var post_video_hold_duration: float = 1.2


func _input(_event: InputEvent) -> void:
	# Consome teclado, gamepad, mouse e toque antes que GUI/unhandled_input
	# do script-base consiga avançar ou encerrar a cinemática.
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _show_prompt() -> void:
	# Não há prompt de avanço manual em uma apresentação obrigatória.
	var prompt_label: Label = _dialogue_ui.get("prompt_label") as Label
	if prompt_label != null:
		prompt_label.visible = false


func _on_video_finished() -> void:
	if _transition_started or _phase == Phase.TRANSITIONING:
		return

	_complete_dialogue_for_video_end()
	await _wait_after_video()
	if not is_inside_tree() or _transition_started:
		return

	match _phase:
		Phase.VIDEO_ANDRE:
			_start_juliana_phase()
		Phase.VIDEO_JULIANA:
			_release_pending_gameplay_inputs()
			_transition_to_map_3()
		_:
			return


func _complete_dialogue_for_video_end() -> void:
	var dialogue_label: Label = _dialogue_ui.get("dialogue_label") as Label
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	if dialogue_label != null:
		dialogue_label.visible_characters = dialogue_label.text.length()
	_is_typing = false


func _wait_after_video() -> void:
	if post_video_hold_duration > 0.0:
		await get_tree().create_timer(post_video_hold_duration, true).timeout


func _release_pending_gameplay_inputs() -> void:
	for action: String in [
		"move_left", "move_right", "move_up", "move_down",
		"attack", "attack_punch", "attack_special", "special",
		"attack_aerial", "jump", "guard", "restart",
		"ui_accept", "ui_cancel"
	]:
		Input.action_release(action)
