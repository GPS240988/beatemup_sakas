from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / "project.godot").read_text(encoding="utf-8")
preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
touch = (ROOT / "scripts/ui/touch_controls.gd").read_text(encoding="utf-8")
hud = (ROOT / "scripts/ui/prototype_hud.gd").read_text(encoding="utf-8")
player = (ROOT / "scripts/actors/player_controller.gd").read_text(encoding="utf-8")
bootstrap = (ROOT / "scripts/mobile/mobile_bootstrap.gd").read_text(encoding="utf-8")
shell = (ROOT / "public/mobile_shell.html").read_text(encoding="utf-8")
scene = (ROOT / "scenes/ui/prototype_hud.tscn").read_text(encoding="utf-8")

checks = {
    "mobile bootstrap registered": 'MobileBootstrap="*res://scripts/mobile/mobile_bootstrap.gd"' in project,
    "native landscape orientation preserved": "window/handheld/orientation=0" in project,
    "desktop touch controls hidden in scene by default": bool(re.search(r'\[node name="TouchControls" type="Control" parent="\."\]\s*visible = false', scene)),
    "touch overlay ignores desktop mouse GUI input": 'mouse_filter = 2' in scene,
    "HUD enables virtual controls only on mobile runtime": "set_touch_controls_visible(_is_mobile_runtime())" in hud and "enable and _is_mobile_runtime()" in hud,
    "HUD refuses desktop touch-control toggling": "if not _is_mobile_runtime() or touch_controls == null:" in hud,
    "TouchControls independently gates input by mobile runtime": "if not visible or not _is_mobile_runtime():" in touch,
    "touch overlay does not receive mouse emulation": "InputEventMouseButton" not in touch and "InputEventMouseMotion" not in touch,
    "single combo button maps to the existing desktop attack action": 'Input.action_press("attack")' in touch and 'Input.action_release("attack")' in touch,
    "jump attack button maps to the existing aerial action": 'Input.action_press("attack_aerial")' in touch and 'Input.action_release("attack_aerial")' in touch,
    "special and guard remain available as distinct desktop-equivalent actions": all(x in touch for x in ['Input.action_press("attack_special")', 'Input.action_press("guard")']),
    "obsolete separate punch and kick touch buttons removed": all(x not in touch for x in ["punch_btn", "kick_btn", 'Input.action_press("attack_kick")', 'Input.action_press("attack_punch")']),
    "obsolete attack_kick InputMap action removed": "attack_kick={" not in project,
    "desktop player controller restored unchanged": 'Input.is_action_just_pressed("attack_kick")' not in player and '_register_key_if_missing("attack_kick"' not in player,
    "touch controls recalculate after viewport resize": "resized.connect(_recalculate_layout)" in touch and "func _recalculate_layout()" in touch,
    "multitouch touch and drag handlers retained": "InputEventScreenTouch" in touch and "InputEventScreenDrag" in touch,
    "mobile bootstrap does not double-scale map": "MOBILE_MAP_SCALE" not in bootstrap and "MapContainer" not in bootstrap,
    "web export uses durable custom shell": 'html/custom_html_shell="res://public/mobile_shell.html"' in preset,
    "PWA enabled with landscape orientation": "progressive_web_app/enabled=true" in preset and "progressive_web_app/orientation=1" in preset,
    "web shell has Godot export placeholders": "$GODOT_URL" in shell and "$GODOT_CONFIG" in shell,
    "portrait orientation overlay retained": "GIRE O CELULAR" in shell and "orientation: portrait" in shell,
}

for label, ok in checks.items():
    print(("PASS" if ok else "FAIL") + " - " + label)

if not all(checks.values()):
    raise SystemExit(1)
print(f"\n{len(checks)} static checks passed.")
