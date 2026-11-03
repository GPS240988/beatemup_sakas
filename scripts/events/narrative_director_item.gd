extends "res://scripts/events/narrative_director_desktop.gd"

## Variante exclusiva para inspeção de itens coletados (Emmanuele / Playboy).
## Mantém integralmente o fluxo oficial StoryEvent/StorySequence, diálogo,
## retrato, moldura e controles, mas nunca usa COVERED na arte principal.
## A textura inteira fica centralizada dentro do ArtStage, com escala limitada
## automaticamente ao espaço disponível e proporção preservada.


func _apply_desktop_presentation_mode() -> void:
	super._apply_desktop_presentation_mode()
	if _image_rect == null:
		return

	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image_rect.scale = Vector2.ONE
	_image_rect.position = Vector2.ZERO
