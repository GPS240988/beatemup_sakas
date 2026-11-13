extends DestructibleProp

## Carne de cura do Alessandro: drop no chão com brilho pulsante para chamar atenção.

var _drop_blink_tween: Tween


func _ready() -> void:
	super._ready()
	var sprite: Sprite2D = get_node_or_null("Visual/Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# A origem do StaticBody2D é o ponto de contato com o chão (0, 0).
		# Com Sprite2D centralizado, desloca metade da altura renderizada para cima.
		var texture_height: float = sprite.texture.get_size().y if sprite.texture != null else 0.0
		sprite.position = Vector2(0.0, -texture_height * absf(sprite.scale.y) * 0.5)
	var shadow: Polygon2D = get_node_or_null("Visual/Shadow") as Polygon2D
	if shadow != null:
		shadow.position.y = 0.0
	_drop_blink_tween = create_tween().set_loops()
	_drop_blink_tween.tween_property(self, "modulate:a", 0.42, 0.28)
	_drop_blink_tween.tween_property(self, "modulate:a", 1.0, 0.28)


func _exit_tree() -> void:
	if _drop_blink_tween != null and _drop_blink_tween.is_running():
		_drop_blink_tween.kill()
