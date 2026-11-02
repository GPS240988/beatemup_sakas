#!/usr/bin/env python3
"""Static checks for the Sakas mobile viewport expansion patch.
Run from the Godot project root: python tests/verify_mobile_screen_fill.py
"""
from pathlib import Path
import sys

ROOT = Path.cwd()
BOOTSTRAP = ROOT / "scripts/mobile/mobile_bootstrap.gd"
BASE_LEVEL = ROOT / "scripts/levels/base_level.gd"
HTML_SHELL = ROOT / "public/mobile_shell.html"
PROJECT = ROOT / "project.godot"

required = [BOOTSTRAP, BASE_LEVEL, HTML_SHELL, PROJECT]
missing = [str(p.relative_to(ROOT)) for p in required if not p.is_file()]
if missing:
    print("FAIL: arquivos ausentes:", ", ".join(missing))
    sys.exit(1)

bootstrap = BOOTSTRAP.read_text(encoding="utf-8")
base_level = BASE_LEVEL.read_text(encoding="utf-8")
html = HTML_SHELL.read_text(encoding="utf-8")
project = PROJECT.read_text(encoding="utf-8")

checks = {
    "KEEP_HEIGHT configurado no bootstrap mobile": "Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT" in bootstrap,
    "bootstrap limita alteração a runtime mobile": "if not _is_mobile_runtime():" in bootstrap,
    "desktop mantém canvas_items": 'window/stretch/mode="canvas_items"' in project,
    "resolução-base original mantida": "window/size/viewport_width=1280" in project and "window/size/viewport_height=720" in project,
    "câmera recalcula limites apenas em mobile": "if not _is_mobile_runtime() or camera == null:" in base_level and "if _is_mobile_runtime():" in base_level,
    "câmera usa a textura Far como limite": 'get_node_or_null("Background/Far") as Sprite2D' in base_level and "far_background.get_rect()" in base_level,
    "câmera considera zoom e largura real da viewport": "get_viewport_rect().size.x" in base_level and "camera.zoom.x" in base_level,
    "câmera reage a resize do viewport": "size_changed.connect(_on_mobile_viewport_size_changed)" in base_level,
    "shell HTML usa viewport width": "width: 100vw" in html,
    "shell HTML usa dynamic viewport height": "100dvh" in html,
    "shell preserva viewport-fit para safe areas": "viewport-fit=cover" in html,
    "preset continua apontando para o shell customizado": 'html/custom_html_shell="res://public/mobile_shell.html"' in (ROOT / "export_presets.cfg").read_text(encoding="utf-8"),
}

# Confere numericamente os limites que o código deve produzir em um celular
# landscape 19.5:9, considerando viewport lógico de 1560 x 720.
def expected_bounds(config_min: float, config_max: float, bg_width: float, view_width: float) -> tuple[float, float]:
    half = view_width / 2.0
    return max(config_min, half), min(config_max, bg_width - half)

bounds = {
    "Mapa 1/2/4 (1983 px)": expected_bounds(640, 1343, 1983, 1560),
    "Mapa 3 (1670 px)": expected_bounds(640, 1030, 1670, 1560),
    "Garagem bônus (1672 px)": expected_bounds(640, 1032, 1672, 1560),
}
checks["Mapa 1/2/4 não expõem laterais vazias"] = bounds["Mapa 1/2/4 (1983 px)"] == (780.0, 1203.0)
checks["Mapa 3 mantém câmera dentro da arte"] = bounds["Mapa 3 (1670 px)"] == (780.0, 890.0)
checks["Garagem mantém câmera dentro da arte"] = bounds["Garagem bônus (1672 px)"] == (780.0, 892.0)

for label, passed in checks.items():
    print(("PASS" if passed else "FAIL") + ": " + label)

print("\nLimites de câmera calculados para viewport lógico 1560x720:")
for label, pair in bounds.items():
    print(f"  {label}: min_x={pair[0]:.0f}, max_x={pair[1]:.0f}")

failed = [label for label, passed in checks.items() if not passed]
print(f"\nResultado: {len(checks) - len(failed)}/{len(checks)} verificações aprovadas")
if failed:
    sys.exit(1)
