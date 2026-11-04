extends RefCounted

## Camada compartilhada de ações touch para telas de navegação mobile.
## Desktop e Web desktop preservam os botões e a navegação originais.
## No mobile, todas as ações de uma tela são agrupadas em um único dock inferior.

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const OVERLAY_LAYER: int = 110

const COLOR_GOLD_ACCENT := Color(0.96, 0.73, 0.22, 1.0)
const COLOR_GOLD_BG := Color(0.06, 0.08, 0.13, 0.96)
const COLOR_GOLD_TEXT := Color(1.0, 0.95, 0.82, 1.0)

const COLOR_CYAN_ACCENT := Color(0.0, 0.82, 0.88, 1.0)
const COLOR_CYAN_BG := Color(0.05, 0.08, 0.14, 0.96)
const COLOR_CYAN_TEXT := Color(0.88, 0.96, 1.0, 1.0)

const BUTTON_HEIGHT: float = 56.0
const BUTTON_CORNER_RADIUS: int = 10
const BUTTON_FONT_SIZE: int = 16
const DOCK_SIDE_MARGIN_RATIO: float = 0.025


static func is_mobile_runtime() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)


## Ação principal: confirmação contextual; centralizada quando aparece sozinha.
static func add_primary_action(
	owner: Node,
	label: String,
	callback: Callable,
	accent: Color = COLOR_GOLD_ACCENT,
	source_button: Button = null
) -> Button:
	if not is_mobile_runtime() or owner == null:
		return null
	if source_button != null:
		source_button.visible = false
	return _add_dock_button(owner, "primary", label, callback, accent)


## Ação secundária: ciano, usada para voltar e agrupada à confirmação.
static func add_secondary_action(
	owner: Node,
	label: String,
	callback: Callable,
	source_button: Button = null
) -> Button:
	if not is_mobile_runtime() or owner == null:
		return null
	if source_button != null:
		source_button.visible = false
	return _add_dock_button(owner, "back", label, callback, COLOR_CYAN_ACCENT)


## Atualiza rótulo/estado sem alterar a geometria responsiva do dock.
static func set_action_state(button: Button, label: String, disabled: bool = false) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.text = _clean_label(label)
	button.disabled = disabled


## Botão contextual inline. Mantido para controles dentro do jogo/narrativa;
## não é movido para o dock de navegação.
static func add_inline_primary_action(
	parent: Control,
	label: String,
	callback: Callable,
	accent: Color = COLOR_GOLD_ACCENT,
	anchor_left: float = 0.77,
	anchor_top: float = 0.86,
	anchor_right: float = 0.95,
	anchor_bottom: float = 0.96
) -> Button:
	if not is_mobile_runtime() or parent == null:
		return null

	var button := Button.new()
	button.name = "MobileInlinePrimaryAction"
	button.text = _clean_label(label)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.z_index = 20
	button.anchor_left = anchor_left
	button.anchor_top = anchor_top
	button.anchor_right = anchor_right
	button.anchor_bottom = anchor_bottom
	button.offset_left = 0.0
	button.offset_top = 0.0
	button.offset_right = 0.0
	button.offset_bottom = 0.0
	button.custom_minimum_size = Vector2(144.0, BUTTON_HEIGHT)
	button.add_theme_font_override("font", ARCADE_FONT)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", COLOR_GOLD_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.4, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.62, 0.85))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.035, 1.0))
	button.add_theme_stylebox_override("normal", _make_button_style(accent, COLOR_GOLD_BG, 0.0))
	button.add_theme_stylebox_override("hover", _make_button_style(accent.lightened(0.18), COLOR_GOLD_BG.lightened(0.06), 1.0))
	button.add_theme_stylebox_override("pressed", _make_button_style(accent, Color(0.14, 0.18, 0.25, 1.0), 2.0))
	button.add_theme_stylebox_override("focus", _make_button_style(accent.lightened(0.18), COLOR_GOLD_BG.lightened(0.06), 1.0))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.35, 0.38, 0.42, 0.8), Color(0.04, 0.05, 0.07, 0.94), 0.0))
	if callback.is_valid():
		button.pressed.connect(callback)
	parent.add_child(button)
	return button


## Navegação anterior/próxima. Os dois botões compartilham o mesmo dock.
static func add_navigation_pair(
	parent: Control,
	previous_callback: Callable,
	next_callback: Callable,
	previous_label: String = "ANTERIOR",
	next_label: String = "PRÓXIMA"
) -> Array[Button]:
	var buttons: Array[Button] = []
	if not is_mobile_runtime() or parent == null:
		return buttons

	var previous := _add_dock_button(parent, "previous", previous_label, previous_callback, COLOR_CYAN_ACCENT)
	var next := _add_dock_button(parent, "next", next_label, next_callback, COLOR_CYAN_ACCENT)
	if previous != null:
		buttons.append(previous)
	if next != null:
		buttons.append(next)
	return buttons


static func _add_dock_button(
	owner: Node,
	slot: String,
	label: String,
	callback: Callable,
	accent: Color
) -> Button:
	var dock := _get_or_create_dock(owner)
	if dock == null:
		return null

	var meta_key := "mobile_action_" + slot
	var existing := dock.get_meta(meta_key, null) as Button
	if existing != null and is_instance_valid(existing):
		existing.text = _clean_label(label)
		return existing

	var button := Button.new()
	button.name = "MobileAction_" + slot.capitalize()
	button.text = _clean_label(label)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.add_theme_font_override("font", ARCADE_FONT)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", COLOR_GOLD_TEXT if slot == "primary" else COLOR_CYAN_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.4, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.62, 0.85))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.035, 1.0))

	var background := COLOR_GOLD_BG if slot == "primary" else COLOR_CYAN_BG
	button.add_theme_stylebox_override("normal", _make_button_style(accent, background, 0.0))
	button.add_theme_stylebox_override("hover", _make_button_style(accent.lightened(0.18), background.lightened(0.06), 1.0))
	button.add_theme_stylebox_override("pressed", _make_button_style(accent, Color(0.14, 0.18, 0.25, 1.0), 2.0))
	button.add_theme_stylebox_override("focus", _make_button_style(accent.lightened(0.18), background.lightened(0.06), 1.0))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.35, 0.38, 0.42, 0.8), Color(0.04, 0.05, 0.07, 0.94), 0.0))
	if callback.is_valid():
		button.pressed.connect(callback)

	dock.set_meta(meta_key, button)
	_layout_dock(owner, dock)
	return button


static func _get_or_create_dock(owner: Node) -> CanvasLayer:
	if owner == null or not is_mobile_runtime():
		return null

	var existing := owner.get_node_or_null("MobileNavigationLayer") as CanvasLayer
	if existing != null:
		return existing

	var overlay := CanvasLayer.new()
	overlay.name = "MobileNavigationLayer"
	overlay.layer = OVERLAY_LAYER
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	owner.add_child(overlay)

	var safe_root := Control.new()
	safe_root.name = "SafeRoot"
	safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(safe_root)

	var panel := PanelContainer.new()
	panel.name = "BottomPanel"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	# A faixa que contém os controles é transparente: só os botões recebem foco.
	# Isso remove a antiga barra dourada e não cria uma superfície opaca sobre a arte.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 10
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.028, 0.048, 0.0)
	panel_style.border_color = Color.TRANSPARENT
	panel_style.set_border_width_all(0)
	panel_style.set_corner_radius_all(0)
	panel_style.shadow_color = Color.TRANSPARENT
	panel_style.shadow_size = 0
	panel_style.content_margin_left = 0.0
	panel_style.content_margin_right = 0.0
	panel_style.content_margin_top = 0.0
	panel_style.content_margin_bottom = 0.0
	panel.add_theme_stylebox_override("panel", panel_style)
	safe_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "DockMargin"
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.name = "DockRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	margin.add_child(rows)

	var wide_row := HBoxContainer.new()
	wide_row.name = "WideRow"
	wide_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wide_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wide_row.add_theme_constant_override("separation", 8)
	rows.add_child(wide_row)

	var navigation_row := HBoxContainer.new()
	navigation_row.name = "NavigationRow"
	navigation_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_row.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation_row.add_theme_constant_override("separation", 8)
	rows.add_child(navigation_row)

	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	rows.add_child(action_row)

	var resize_callback := func() -> void:
		_layout_dock(owner, overlay)
	safe_root.resized.connect(resize_callback)
	_layout_dock(owner, overlay)
	return overlay


static func _layout_dock(owner: Node, dock: CanvasLayer) -> void:
	if owner == null or dock == null or not is_instance_valid(dock):
		return
	if not owner.is_inside_tree():
		return

	var viewport_size := owner.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var panel := dock.get_node_or_null("SafeRoot/BottomPanel") as PanelContainer
	var margin := dock.get_node_or_null("SafeRoot/BottomPanel/DockMargin") as MarginContainer
	var wide_row := dock.get_node_or_null("SafeRoot/BottomPanel/DockMargin/DockRows/WideRow") as HBoxContainer
	var navigation_row := dock.get_node_or_null("SafeRoot/BottomPanel/DockMargin/DockRows/NavigationRow") as HBoxContainer
	var action_row := dock.get_node_or_null("SafeRoot/BottomPanel/DockMargin/DockRows/ActionRow") as HBoxContainer
	if panel == null or margin == null or wide_row == null or navigation_row == null or action_row == null:
		return

	var slots: Dictionary = {
		"back": dock.get_meta("mobile_action_back", null),
		"previous": dock.get_meta("mobile_action_previous", null),
		"next": dock.get_meta("mobile_action_next", null),
		"primary": dock.get_meta("mobile_action_primary", null)
	}
	var has_back := slots["back"] is Button and is_instance_valid(slots["back"])
	var has_previous := slots["previous"] is Button and is_instance_valid(slots["previous"])
	var has_next := slots["next"] is Button and is_instance_valid(slots["next"])
	var has_primary := slots["primary"] is Button and is_instance_valid(slots["primary"])
	var has_navigation := has_previous or has_next
	var has_actions := has_back or has_primary
	var compact := viewport_size.x < 980.0 or viewport_size.y < 520.0
	var split_rows := compact and has_navigation and has_actions

	wide_row.visible = not split_rows
	navigation_row.visible = split_rows
	action_row.visible = split_rows
	if not split_rows:
		navigation_row.visible = false
		action_row.visible = false

	var font_size := 16
	if viewport_size.x < 520.0:
		font_size = 11
	elif viewport_size.x < 760.0:
		font_size = 13
	elif viewport_size.x < 1100.0:
		font_size = 14

	# A altura acompanha a altura útil do telefone, sem forçar 52px em telas baixas.
	# Isso mantém a faixa de ação na moldura inferior em vez de atravessar a arte.
	var button_height := clampf(viewport_size.y * 0.11, 38.0, 52.0)
	var side_margin := clampf(viewport_size.x * DOCK_SIDE_MARGIN_RATIO, 10.0, 18.0)
	var bottom_safe := clampf(viewport_size.y * 0.02, 8.0, 14.0)
	var top_margin := 2.0
	var vertical_rows := 2 if split_rows else 1
	var row_gap := 4.0 if split_rows else 0.0
	var panel_height := (button_height * vertical_rows) + row_gap + top_margin + 4.0
	var available_width := maxf(160.0, viewport_size.x - (side_margin * 2.0))
	var action_only := has_primary and not has_back and not has_navigation
	var action_pair := has_primary and has_back and not has_navigation

	margin.add_theme_constant_override("margin_left", int(side_margin))
	margin.add_theme_constant_override("margin_right", int(side_margin))
	margin.add_theme_constant_override("margin_top", int(top_margin))
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = -panel_height - bottom_safe
	panel.offset_bottom = -bottom_safe
	_reserve_mobile_content_area(owner, panel_height + bottom_safe)

	# Ordem de leitura fixa: voltar, anterior, próxima, confirmar.
	for slot in ["back", "previous", "next", "primary"]:
		var button := slots[slot] as Button
		if button == null or not is_instance_valid(button):
			continue

		var target_row := wide_row
		if split_rows:
			if slot == "previous" or slot == "next":
				target_row = navigation_row
			else:
				target_row = action_row

		if button.get_parent() != target_row:
			var old_parent := button.get_parent()
			if old_parent != null:
				old_parent.remove_child(button)
			target_row.add_child(button)
		else:
			target_row.move_child(button, target_row.get_child_count() - 1)

		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if action_only:
			# Confirmação isolada (menu principal): largura limitada e centralizada.
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.custom_minimum_size = Vector2(minf(360.0, maxf(160.0, available_width * 0.58)), button_height)
		elif action_pair:
			# Voltar + confirmar formam um grupo central; não ficam presos às bordas.
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var back_width := minf(168.0, maxf(96.0, available_width * 0.30))
			var primary_width := minf(360.0, maxf(148.0, available_width - back_width - 8.0))
			button.custom_minimum_size = Vector2(back_width if slot == "back" else primary_width, button_height)
		else:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(0.0, button_height)
		button.add_theme_font_size_override("font_size", font_size)


static func _reserve_mobile_content_area(_owner: Node, _reserve_height: float) -> void:
	# Com o novo sistema fullscreen (STRETCH_COVER / STRETCH_KEEP_ASPECT_COVERED),
	# o background preenche toda a viewport nativamente. O dock de ações é
	# transparente e fica sobre a arte, sem comprimir o conteúdo.
	# Nenhuma reserva de espaço é necessária.
	pass


static func _clean_label(raw: String) -> String:
	var label := raw.strip_edges()
	for unsupported in ["▶", "❯", "⚡", "★", "⬅", "➔", "->"]:
		label = label.replace(unsupported, "")
	return label.strip_edges().to_upper()


static func _make_button_style(accent: Color, background: Color, pressed_depth: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(BUTTON_CORNER_RADIUS)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
	style.shadow_size = 5 if pressed_depth == 0.0 else 2
	style.shadow_offset = Vector2(0.0, 2.0 - pressed_depth)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
