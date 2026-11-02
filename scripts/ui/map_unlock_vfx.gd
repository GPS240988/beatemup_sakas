class_name MapUnlockVFX
extends Node2D

## Efeito visual de desbloqueio arcade (anel dourado em expansão, brilho radial e feixes de luz).

var _ring_radius: float = 0.0
var _ring_alpha: float = 0.0
var _glow_alpha: float = 0.0
var _sparkle_len: float = 0.0
var _is_active: bool = false


func play_burst() -> void:
	_is_active = true
	_ring_radius = 5.0
	_ring_alpha = 1.0
	_glow_alpha = 0.9
	_sparkle_len = 8.0
	queue_redraw()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "_ring_radius", 65.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_ring_alpha", 0.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "_glow_alpha", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "_sparkle_len", 45.0, 0.70).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		_is_active = false
		queue_redraw()
	)


func _process(_delta: float) -> void:
	if _is_active:
		queue_redraw()


func _draw() -> void:
	if not _is_active:
		return

	# 1. Aura de brilho central dourada
	if _glow_alpha > 0.01:
		var glow_col := Color(1.0, 0.85, 0.25, _glow_alpha * 0.45)
		draw_circle(Vector2.ZERO, 38.0, glow_col)
		var core_col := Color(1.0, 1.0, 0.8, _glow_alpha * 0.70)
		draw_circle(Vector2.ZERO, 18.0, core_col)

	# 2. Anel de energia em expansão
	if _ring_alpha > 0.01 and _ring_radius > 1.0:
		var ring_col := Color(1.0, 0.82, 0.18, _ring_alpha)
		draw_arc(Vector2.ZERO, _ring_radius, 0.0, TAU, 36, ring_col, 3.0, true)

	# 3. 8 feixes de brilho radial (raios de faíscas arcade)
	if _sparkle_len > 1.0 and _ring_alpha > 0.01:
		var ray_col := Color(1.0, 0.92, 0.45, _ring_alpha * 0.85)
		for i in range(8):
			var angle: float = (float(i) / 8.0) * TAU + 0.392
			var dir := Vector2(cos(angle), sin(angle))
			var start_pt := dir * (_ring_radius * 0.5)
			var end_pt := dir * (_ring_radius * 0.5 + _sparkle_len)
			draw_line(start_pt, end_pt, ray_col, 2.0)

