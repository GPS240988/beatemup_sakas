extends RefCounted

## Camada reutilizável de ações explícitas para navegação touch no mobile.
## Padroniza botões primários (dourado arcade) e secundários (ciano neon) em todo o jogo.
## Desktop permanece 100% inalterado utilizando os controles originais (mouse/teclado/gamepad).

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const OVERLAY_LAYER: int = 110

const COLOR_GOLD_ACCENT := Color(0.96, 0.73, 0.22, 1.0)
const COLOR_GOLD_BG := Color(0.06, 0.08, 0.13, 0.94)
const COLOR_GOLD_TEXT := Color(1.0, 0.95, 0.82, 1.0)

const COLOR_CYAN_ACCENT := Color(0.0, 0.82, 0.88, 1.0)
const COLOR_CYAN_BG := Color(0.05, 0.08, 0.14, 0.94)
const COLOR_CYAN_TEXT := Color(0.88, 0.96, 1.0, 1.0)

const BUTTON_HEIGHT: float = 64.0
const BUTTON_CORNER_RADIUS: int = 10
const BUTTON_FONT_SIZE: int = 18


static func is_mobile_runtime() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
		or DisplayServer.is_touchscreen_available()
	)


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

	var button := Button.new()
	button.name = "MobilePrimaryAction"
	button.text = _clean_label(label)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.z_index = 10

	var width := clampf(owner.get_viewport().get_visible_rect().size.x * 0.23, 168.0, 260.0)
	button.custom_minimum_size = Vector2(width, BUTTON_HEIGHT)
	button.anchor_left = 0.95
	button.anchor_right = 0.95
	button.anchor_top = 0.95
	button.anchor_bottom = 0.95
	button.offset_left = -width
	button.offset_right = 0.0
	button.offset_top = -BUTTON_HEIGHT
	button.offset_bottom = 0.0

	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", COLOR_GOLD_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.4, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.62, 0.85))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.035, 1.0))

	var normal := _make_button_style(accent, COLOR_GOLD_BG, 0.0)
	var hover := _make_button_style(accent.lightened(0.18), COLOR_GOLD_BG.lightened(0.06), 1.0)
	var pressed := _make_button_style(accent, Color(0.14, 0.18, 0.25, 1.0), 2.0)
	var disabled := _make_button_style(Color(0.35, 0.38, 0.42, 0.8), Color(0.04, 0.05, 0.07, 0.94), 0.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)

	if callback.is_valid():
		button.pressed.connect(callback)
	safe_root.add_child(button)
	return button


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

	var overlay := CanvasLayer.new()
	overlay.name = "MobileBackActionLayer"
	overlay.layer = OVERLAY_LAYER + 1
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	owner.add_child(overlay)

	var safe_root := Control.new()
	safe_root.name = "SafeRoot"
	safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(safe_root)

	var button := Button.new()
	button.name = "MobileBackAction"
	button.text = _clean_label(label)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.z_index = 10

	var width := clampf(owner.get_viewport().get_visible_rect().size.x * 0.20, 150.0, 230.0)
	button.custom_minimum_size = Vector2(width, BUTTON_HEIGHT)
	button.anchor_left = 0.05
	button.anchor_right = 0.05
	button.anchor_top = 0.95
	button.anchor_bottom = 0.95
	button.offset_left = 0.0
	button.offset_right = width
	button.offset_top = -BUTTON_HEIGHT
	button.offset_bottom = 0.0

	button.add_theme_font_override("font", ARCADE_FONT)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", COLOR_CYAN_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.5, 0.9, 1.0, 1.0))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.035, 1.0))

	button.add_theme_stylebox_override("normal", _make_button_style(COLOR_CYAN_ACCENT, COLOR_CYAN_BG, 0.0))
	button.add_theme_stylebox_override("hover", _make_button_style(COLOR_CYAN_ACCENT.lightened(0.18), COLOR_CYAN_BG.lightened(0.06), 1.0))
	button.add_theme_stylebox_override("pressed", _make_button_style(COLOR_CYAN_ACCENT, Color(0.10, 0.16, 0.24, 1.0), 2.0))
	button.add_theme_stylebox_override("focus", _make_button_style(COLOR_CYAN_ACCENT, COLOR_CYAN_BG.lightened(0.06), 1.0))

	if callback.is_valid():
		button.pressed.connect(callback)
	safe_root.add_child(button)
	return button


static func set_action_state(button: Button, label: String, disabled: bool = false) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.text = _clean_label(label)
	var button_width := clampf(float(button.text.length()) * 12.0 + 44.0, 150.0, 210.0)
	button.custom_minimum_size.x = button_width
	button.offset_left = -button_width
	button.offset_right = 0.0
	button.disabled = disabled

## Ação inline para interfaces que já possuem uma camada visual própria.
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


## Navegação explícita por toque, sem setas decorativas.
static func add_navigation_pair(
	parent: Control,
	previous_callback: Callable,
	next_callback: Callable
) -> Array[Button]:
	var buttons: Array[Button] = []
	if not is_mobile_runtime() or parent == null:
		return buttons
	var previous := add_inline_primary_action(
		parent, "ANTERIOR", previous_callback, COLOR_CYAN_ACCENT,
		0.30, 0.86, 0.47, 0.96
	)
	var next := add_inline_primary_action(
		parent, "PRÓXIMA", next_callback, COLOR_CYAN_ACCENT,
		0.49, 0.86, 0.66, 0.96
	)
	if previous != null:
		previous.name = "MobilePreviousAction"
		buttons.append(previous)
	if next != null:
		next.name = "MobileNextAction"
		buttons.append(next)
	return buttons


static func _clean_label(raw: String) -> String:
	var s := raw.strip_edges()
	for bad in ["▶", "❯", "⚡", "★", "⬅", "➔", "->"]:
		s = s.replace(bad, "")
	return s.strip_edges().to_upper()


static func _make_button_style(accent: Color, background: Color, pressed_depth: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(BUTTON_CORNER_RADIUS)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
	style.shadow_size = 5 if pressed_depth == 0.0 else 2
	style.shadow_offset = Vector2(0.0, 2.0 - pressed_depth)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
