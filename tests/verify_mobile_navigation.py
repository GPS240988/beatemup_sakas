#!/usr/bin/env python3
"""Static regression checks for Sakas mobile navigation and framing."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
def read(path):
    p = ROOT / path
    if not p.is_file():
        raise AssertionError(f"Missing: {path}")
    return p.read_text(encoding="utf-8")
helper = read("scripts/mobile/mobile_screen_action.gd")
menu = read("scripts/ui/main_menu.gd")
menu_scene = read("scenes/ui/main_menu.tscn")
characters = read("scripts/ui/character_select.gd")
map_script = read("scripts/ui/map_menu.gd")
narrative = read("scripts/events/narrative_director.gd")
card = read("scripts/items/counter_card_interaction.gd")
checks = {
    "mobile action height adapts to short landscape screens": "clampf(viewport_size.y * 0.11, 38.0, 52.0)" in helper,
    "inline mobile action reuses arcade styling": "static func add_inline_primary_action(" in helper,
    "shared helper retains optional previous/next support": "static func add_navigation_pair(" in helper and '"previous"' in helper and '"next"' in helper,
    "main menu uses one confirmation action, not previous/next": "MobileScreenAction.add_primary_action(" in menu and "MobileScreenAction.add_navigation_pair(" not in menu,
    "misaligned decorative chevrons are hidden on mobile": "left_chevron.visible = false" in menu and "right_chevron.visible = false" in menu,
    "character selection is enabled in menu": "btn_char_select.disabled = false" in menu and "disabled = true" not in menu_scene.split('[node name="BtnCharSelect"')[1].split("[node", 1)[0],
    "character selector uses tap-to-select and contextual confirm": "MobileScreenAction.add_navigation_pair(" not in characters and "var mobile_label :=" in characters and "hero_name" in characters,
    "character art is no longer duplicated as cropped backdrop": "STRETCH_KEEP_ASPECT_COVERED" not in characters,
    "map fits the full artwork without cropping": "scale_factor = minf(vp_size.x / 1920.0, vp_size.y / 1080.0)" in map_script,
    "map does not create enlarged duplicate backdrop": "MapAmbientBackdrop" not in map_script,
    "mobile landscape narrative art stage fills viewport": "art_bottom = 1.0" in narrative and "dialogue_top = 0.72" in narrative,
    "mobile narrative suppresses zoom crop": "if not mobile_safe_framing:" in narrative,
    "arcade reveal has an explicit touch advance action": 'MobileScreenAction.add_inline_primary_action(' in narrative and '_mobile_revelation_button.visible = _is_mobile_runtime()' in narrative,
    "card dialogue has explicit AVANÇAR button": 'root,\n\t\t\t"AVANÇAR"' in card and "MobileScreenAction.is_mobile_runtime()" in card,
}
for label, ok in checks.items():
    print(("PASS" if ok else "FAIL") + " - " + label)
failed = [label for label, ok in checks.items() if not ok]
print(f"\n{len(checks)-len(failed)}/{len(checks)} checks passed.")
if failed:
    sys.exit(1)
