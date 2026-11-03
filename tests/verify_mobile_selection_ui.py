#!/usr/bin/env python3
"""Verificação estática do fluxo mobile menu/personagem/dificuldade Sakas."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        raise AssertionError(f"Arquivo ausente: {relative}")
    return path.read_text(encoding="utf-8")

helper = read("scripts/mobile/mobile_screen_action.gd")
menu = read("scripts/ui/main_menu.gd")
characters = read("scripts/ui/character_select.gd")
difficulty = read("scripts/ui/difficulty_select.gd")

checks = {
    "a barra inferior não desenha faixa opaca/dourada": "panel_style.bg_color = Color(0.018, 0.028, 0.048, 0.0)" in helper and "panel_style.border_color = Color.TRANSPARENT" in helper,
    "a altura dos botões responde a telas landscape baixas": "clampf(viewport_size.y * 0.11, 38.0, 52.0)" in helper,
    "uma única ação principal fica centralizada": "action_only := has_primary and not has_back and not has_navigation" in helper and "Control.SIZE_SHRINK_CENTER" in helper,
    "o dock usa largura total com padding interno para não exceder telas estreitas": "panel.anchor_left = 0.0" in helper and "panel.anchor_right = 1.0" in helper and "margin.add_theme_constant_override(\"margin_left\", int(side_margin))" in helper,
    "voltar e confirmar ficam agrupados no centro": "action_pair := has_primary and has_back and not has_navigation" in helper and "wide_row.alignment = BoxContainer.ALIGNMENT_CENTER" in helper,
    "o menu mobile não cria anterior/próxima": "MobileScreenAction.add_navigation_pair(" not in menu,
    "tocar no menu seleciona sem navegar imediatamente": "if not _is_mobile_runtime():\n\t\t_activate_option(index)" in menu,
    "rótulos do menu refletem a opção ativa": '"INICIAR NOVO JOGO"' in menu and '"CONTINUAR JOGO"' in menu and '"SELECIONAR PERSONAGEM"' in menu,
    "realce selecionado não usa a antiga cor amarela": "Color(1.0, 0.72, 0.20, 0.18)" not in menu and "Color(0.0, 0.82, 0.88, 0.12)" in menu,
    "a seleção de personagem não cria anterior/próxima": "MobileScreenAction.add_navigation_pair(" not in characters,
    "a ação do personagem exibe o nome e respeita bloqueio": 'var mobile_label := "CONFIRMAR " + hero_name' in characters and "current_hover_id != \"guilherme\"" in characters,
    "a dificuldade não avança ao tocar no cartão em mobile": 'if MobileScreenAction.is_mobile_runtime():\n\t\t\t\t_select_difficulty("normal", true)' in difficulty,
    "personagem e dificuldade usam o mesmo par voltar/confirmar": all(token in characters for token in ["MobileScreenAction.add_primary_action(", "MobileScreenAction.add_secondary_action("]) and all(token in difficulty for token in ["MobileScreenAction.add_primary_action(", "MobileScreenAction.add_secondary_action("]),
    "a dificuldade segue seleção + confirmação explícita": '"CONFIRMAR DIFÍCIL"' in difficulty and '"CONFIRMAR NORMAL"' in difficulty,
    "o helper reserva espaço real abaixo da arte": "static func _reserve_mobile_content_area(" in helper and "aspect_wrapper.offset_bottom = -reserve_height" in helper and "click_zones.offset_bottom = -reserve_height" in helper,
    "o helper preserva modo não-mobile": 'if not is_mobile_runtime() or owner == null:' in helper,
}

for label, passed in checks.items():
    print(("PASS" if passed else "FAIL") + " - " + label)
failed = [label for label, passed in checks.items() if not passed]
print(f"\n{len(checks) - len(failed)}/{len(checks)} verificações passaram.")
if failed:
    sys.exit(1)
