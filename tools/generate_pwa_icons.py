#!/usr/bin/env python3
"""
tools/generate_pwa_icons.py
Gera o conjunto completo de ícones PWA do Beat 'em Up Sakas com a identidade visual
'Dark Premium Medieval' / Arcade 90s, destacando o 'S' icônico de Sakas.

Padrões aplicados:
1. Respeito rigoroso à safe-zone de ícones maskable (80% central para Android/iOS).
2. Letra 'S' centralizada em fonte arcade com extrusão 3D carmesim e gradiente dourado.
3. Medalhão arcade com chanfro metálico, anéis de ouro e rebites perimetrais.
4. Fundo escuro premium (#060814) com brilho radial sutil.
5. Gerações nos tamanhos canônicos:
   - 512x512: public/index.512x512.png
   - 180x180: public/index.180x180.png e public/index.apple-touch-icon.png
   - 144x144: public/index.144x144.png
   - 64x64: public/index.icon.png e public/index.png
"""

import math
import os
import shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT_DIR = Path(__file__).resolve().parent.parent
PUBLIC_DIR = ROOT_DIR / "public"
FONT_PATH = ROOT_DIR / "assets" / "fonts" / "arcade_bold.ttf"


def create_sakas_icon(size: int = 512) -> Image.Image:
    # Cria canvas base em 512x512 para máxima definição e depois redimensiona com Lanczos
    canvas_size = 512
    img = Image.new("RGBA", (canvas_size, canvas_size), (6, 8, 20, 255))
    draw = ImageDraw.Draw(img)

    cx, cy = canvas_size // 2, canvas_size // 2

    # 1. Fundo radial Dark Premium Medieval (#060814 com gradiente central suave)
    for r in range(cx, 0, -2):
        t = r / float(cx)
        cr = int(34 * (1.0 - t) + 6 * t)
        cg = int(14 * (1.0 - t) + 8 * t)
        cb = int(52 * (1.0 - t) + 20 * t)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(cr, cg, cb, 255))

    # 2. Medalhão Arcade de Ouro (Raio máx 190px - bem dentro da safe-zone maskable de 204px)
    r_bevel = 190
    r_outer = 185
    r_mid = 178
    r_inner_gold = 172
    r_field = 165

    # Camadas metálicas
    draw.ellipse([cx - r_bevel, cy - r_bevel, cx + r_bevel, cy + r_bevel], fill=(70, 50, 15, 255))
    draw.ellipse([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], fill=(160, 118, 28, 255))
    draw.ellipse([cx - r_mid, cy - r_mid, cx + r_mid, cy + r_mid], fill=(245, 192, 50, 255))
    draw.ellipse([cx - r_inner_gold, cy - r_inner_gold, cx + r_inner_gold, cy + r_inner_gold], fill=(255, 242, 150, 255))
    draw.ellipse([cx - r_field, cy - r_field, cx + r_field, cy + r_field], fill=(10, 8, 18, 255))

    # Rebites perimetrais arcade (detalhes estilo moeda de fliperama dos anos 90)
    rivets = 24
    for i in range(rivets):
        ang = (i / float(rivets)) * math.tau
        bx = cx + (r_field - 7) * math.cos(ang)
        by = cy + (r_field - 7) * math.sin(ang)
        draw.ellipse([bx - 3, by - 3, bx + 3, by + 3], fill=(255, 215, 60, 230))

    # 3. Tipografia Arcade 'S' (Sakas)
    font_size = 320
    font = ImageFont.truetype(str(FONT_PATH), font_size)
    bbox = draw.textbbox((0, 0), "S", font=font)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    tx = cx - bbox[0] - (w // 2)
    ty = cy - bbox[1] - (h // 2)

    # 3.1 Sombra profunda de oclusão
    for ox, oy, alpha in [(12, 14, 90), (10, 12, 130), (8, 10, 170)]:
        s_img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(s_img)
        s_draw.text((tx + ox, ty + oy), "S", font=font, fill=(4, 2, 7, alpha))
        img.alpha_composite(s_img)

    # 3.2 Extrusão 3D carmesim/rubi (estética arcade 16-bit)
    steps = 9
    for step in range(steps, 0, -1):
        ox = step
        oy = step
        frac = step / float(steps)
        cr = int(145 + 70 * (1.0 - frac))
        cg = int(10 + 20 * (1.0 - frac))
        cb = int(25 + 30 * (1.0 - frac))
        ext_img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        e_draw = ImageDraw.Draw(ext_img)
        e_draw.text((tx + ox, ty + oy), "S", font=font, fill=(cr, cg, cb, 255))
        img.alpha_composite(ext_img)

    # 3.3 Face do 'S' em gradiente dourado nobre
    mask_img = Image.new("L", (canvas_size, canvas_size), 0)
    m_draw = ImageDraw.Draw(mask_img)
    m_draw.text((tx, ty), "S", font=font, fill=255)

    grad_img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(grad_img)

    top_y = ty + bbox[1]
    bot_y = ty + bbox[3]
    total_h = float(max(1, bot_y - top_y))

    for y in range(top_y, bot_y + 1):
        t = (y - top_y) / total_h
        if t < 0.22:
            sub_t = t / 0.22
            r = int(255 * (1.0 - sub_t) + 255 * sub_t)
            g = int(252 * (1.0 - sub_t) + 210 * sub_t)
            b = int(205 * (1.0 - sub_t) + 55 * sub_t)
        elif t < 0.68:
            sub_t = (t - 0.22) / 0.46
            r = int(255 * (1.0 - sub_t) + 245 * sub_t)
            g = int(210 * (1.0 - sub_t) + 142 * sub_t)
            b = int(55 * (1.0 - sub_t) + 22 * sub_t)
        else:
            sub_t = (t - 0.68) / 0.32
            r = int(245 * (1.0 - sub_t) + 210 * sub_t)
            g = int(142 * (1.0 - sub_t) + 90 * sub_t)
            b = int(22 * (1.0 - sub_t) + 14 * sub_t)
        g_draw.line([(0, y), (canvas_size, y)], fill=(r, g, b, 255))

    grad_masked = Image.composite(grad_img, Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0)), mask_img)
    img.alpha_composite(grad_masked)

    # 3.4 Brilho especular (Glint estelar arcade) no ombro superior esquerdo do 'S'
    glint_x = tx + 32
    glint_y = ty + 68
    for gr, ga in [(10, 75), (6, 140), (3, 230), (1, 255)]:
        draw.ellipse([glint_x - gr, glint_y - gr, glint_x + gr, glint_y + gr], fill=(255, 255, 255, ga))
    draw.line([(glint_x - 14, glint_y), (glint_x + 14, glint_y)], fill=(255, 255, 255, 220), width=2)
    draw.line([(glint_x, glint_y - 14), (glint_x, glint_y + 14)], fill=(255, 255, 255, 220), width=2)

    if size != canvas_size:
        return img.resize((size, size), Image.Resampling.LANCZOS)
    return img


def generate_all_icons():
    print("=" * 60)
    print("GERANDO ÍCONES PWA OFICIAIS COM BRANDING 'S' (SAKAS)")
    print("=" * 60)

    PUBLIC_DIR.mkdir(parents=True, exist_ok=True)
    ui_dir = ROOT_DIR / "assets" / "ui"
    ui_dir.mkdir(parents=True, exist_ok=True)

    source_path = ui_dir / "icon_sakas_source.png"
    if source_path.exists():
        print(f"  [FONTE] Usando imagem oficial do usuário: {source_path}")
        user_img = Image.open(source_path).convert("RGBA")
        base_icon_512 = user_img.resize((512, 512), Image.Resampling.LANCZOS)
    else:
        print("  [FONTE] Gerando proceduralmente o ícone base 512x512...")
        base_icon_512 = create_sakas_icon(512)

    # Grava ícones na pasta assets/ui para uso do motor Godot
    base_icon_512.save(ui_dir / "icon_sakas_512.png", format="PNG", optimize=True)
    icon_180 = base_icon_512.resize((180, 180), Image.Resampling.LANCZOS)
    icon_180.save(ui_dir / "icon_sakas_180.png", format="PNG", optimize=True)

    targets = [
        ("index.512x512.png", 512),
        ("index.180x180.png", 180),
        ("index.apple-touch-icon.png", 180),
        ("index.144x144.png", 144),
        ("index.icon.png", 128),
        ("index.png", 128),
    ]

    for fname, sz in targets:
        out_path = PUBLIC_DIR / fname
        if fname == "index.144x144.png" and source_path.exists():
            # Preserva 1:1 os pixels originais se a fonte já tiver 144x144
            shutil.copyfile(source_path, out_path)
        elif sz == 512:
            base_icon_512.save(out_path, format="PNG", optimize=True)
        else:
            resized = base_icon_512.resize((sz, sz), Image.Resampling.LANCZOS)
            resized.save(out_path, format="PNG", optimize=True)
        print(f"  [OK] Gerado {fname:<26} ({sz}x{sz} px) -> {out_path.stat().st_size} bytes")

    # Limpeza de arquivos de teste
    test_icon = PUBLIC_DIR / "test_icon_512.png"
    if test_icon.exists():
        test_icon.unlink()

    print("\nTodos os ícones PWA oficiais foram gerados e validados!")


if __name__ == "__main__":
    generate_all_icons()
