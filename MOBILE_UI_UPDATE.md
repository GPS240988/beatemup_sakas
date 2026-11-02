# Sakas — Mobile UI update

Base repository: GPS240988/beatemup_sakas
Base branch: main
Base commit: 3f522e26749b1f13c9fdb2a47f95644b4c584b3e
Working branch: feat/mobile-character-selection-ui-2026-11-02

## Changed files
- scripts/mobile/mobile_screen_action.gd
- scripts/ui/main_menu.gd
- scenes/ui/main_menu.tscn
- scripts/ui/character_select.gd
- scripts/ui/map_menu.gd
- scripts/events/narrative_director.gd
- scenes/ui/narrative_director.tscn
- scripts/items/counter_card_interaction.gd
- tests/ui_flow_test.gd
- tests/verify_mobile_navigation.py

## Intended behavior
- Consistent mobile actions: 52px touch target height, 180px secondary button, safe-area anchoring.
- Explicit previous/next touch navigation in main menu and character selection.
- Character selection is reachable from the main menu; existing GameSession unlock rules remain authoritative.
- Map uses uniform contain scaling on all viewport aspect ratios.
- Character selection no longer adds a second cropped copy of the current character art.
- Mobile narrative in landscape uses the full viewport as its artwork stage and disables zooms that would crop important image content.
- Arcade machine revelation and the card dialogue have a visible AVANÇAR touch action.
- No source image dimensions or file extensions were changed.

## Validation
Run:
- python tests/verify_mobile_navigation.py
- godot --headless --path . -s tests/ui_flow_test.gd
- godot --headless --path . -s tests/narrative_intro_test.gd

The GitHub remote environment does not provide a complete local Godot workspace or the full binary asset payload, so engine execution must be confirmed in a local Godot workspace.
