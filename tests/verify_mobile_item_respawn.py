#!/usr/bin/env python3
"""Static regression checks for mobile drop-item framing and map-1 reinforcements."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        raise AssertionError(f"Missing: {relative}")
    return path.read_text(encoding="utf-8")

item = read("scripts/events/narrative_director_item.gd")
map1 = read("scripts/levels/map_1_story_transition.gd")
addendum = read("docs/GAME_RULES_MOBILE_ADDENDUM.md")

checks = {
    "item presentation keeps the full texture aspect ratio": "TextureRect.STRETCH_KEEP_ASPECT_CENTERED" in item,
    "mobile landscape artwork is capped above dialogue": "art_bottom = 0.68" in item and "dialogue_top = 0.705" in item,
    "mobile portrait artwork is capped above dialogue": "art_bottom = 0.38" in item and "dialogue_top = 0.405" in item,
    "dialogue layout remains full-width on mobile": "_dialogue_area.anchor_right = 1.0" in item,
    "desktop item layout delegates to original behavior": "super._apply_responsive_layout()" in item and "super._align_dialogue_area_to_image()" in item,
    "desktop reinforcement placement delegates to BaseLevel": "return super.get_offscreen_spawn_position(index, total)" in map1,
    "mobile reinforcement positions come from active navigation polygons": "NavigationServer2D.map_get_random_point(nav_map, 1, false)" in map1,
    "mobile reinforcement path starts from a point snapped onto the navmesh": "map_get_closest_point(" in map1 and "player_navigation_position" in map1,
    "mobile reinforcement points must be reachable from the player": "NavigationServer2D.map_get_path(" in map1 and "if reachable_path.is_empty():" in map1,
    "multiple mobile reinforcements keep spacing": "nearest_spawn_distance < 115.0" in map1,
    "the design rule covers all future item drops": "não apenas ao item de referência" in addendum,
    "the design rule documents navigation-safe mobile spawning": "map_get_random_point()" in addendum and "map_get_path()" in addendum,
}

for label, passed in checks.items():
    print(("PASS" if passed else "FAIL") + " - " + label)

failed = [label for label, passed in checks.items() if not passed]
print(f"\n{len(checks) - len(failed)}/{len(checks)} static checks passed.")
if failed:
    sys.exit(1)
