#!/usr/bin/env python3
"""Static checks for the shared mobile navigation dock."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/mobile/mobile_screen_action.gd"
source = HELPER.read_text(encoding="utf-8")

checks = {
    "mobile runtime is explicitly detected": 'OS.has_feature("web_android")' in source and 'OS.has_feature("web_ios")' in source,
    "desktop/non-mobile calls return without creating a dock": "if not is_mobile_runtime() or owner == null:" in source,
    "all navigation actions reuse one named CanvasLayer": 'owner.get_node_or_null("MobileNavigationLayer")' in source,
    "primary confirmation is exposed": '"primary"' in source and "add_primary_action" in source,
    "back action is exposed": '"back"' in source and "add_secondary_action" in source,
    "previous/next are exposed": '"previous"' in source and '"next"' in source,
    "responsive two-row layout is present": "var split_rows := compact and has_navigation and has_actions" in source,
    "viewport resize recalculates the dock": "safe_root.resized.connect(resize_callback)" in source,
    "buttons retain explicit callbacks": "button.pressed.connect(callback)" in source,
    "contextual inline controls remain supported": "static func add_inline_primary_action(" in source,
    "action state only changes text and availability": "static func set_action_state(" in source and "button.disabled = disabled" in source,
    "touch buttons retain at least 52px height": "clampf(viewport_size.y * 0.085, 52.0, 64.0)" in source,
}

for label, passed in checks.items():
    print(("PASS" if passed else "FAIL") + " - " + label)

failed = [label for label, passed in checks.items() if not passed]
print(f"\n{len(checks) - len(failed)}/{len(checks)} checks passed.")
raise SystemExit(1 if failed else 0)
