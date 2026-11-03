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
