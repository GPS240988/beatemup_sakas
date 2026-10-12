"""
Script inteligente para cortar sprite sheets com espacamento irregular.
Detecta automaticamente onde cada personagem esta e corta individualmente.
Redimensiona cada frame para 220x300 px (padrao Projeto Sakas).

Uso:
  python cut_sprites_smart.py <arquivo_folha> <nome_acao> <num_frames>

Exemplos:
  python cut_sprites_smart.py folha.png walk 8
  python cut_sprites_smart.py folha.png punch 3
"""
import sys
import os
from PIL import Image

TARGET_W = 220
TARGET_H = 300
MIN_GAP = 2  # minimo de pixels vazios para considerar um gap


def is_column_empty(img, x, threshold=30):
    """Verifica se uma coluna vertical e vazia (transparente ou branca)."""
    for y in range(img.height):
        r, g, b, a = img.getpixel((x, y))
        if a > threshold and not (r > 240 and g > 240 and b > 240):
            return False
    return True


def find_character_zones(img):
    """Encontra as zonas horizontais onde ha conteudo (personagens)."""
    zones = []
    in_content = False
    zone_start = 0

    for x in range(img.width):
        empty = is_column_empty(img, x)

        if not empty and not in_content:
            in_content = True
            zone_start = x
        elif empty and in_content:
            in_content = False
            zones.append((zone_start, x))

    if in_content:
        zones.append((zone_start, img.width))

    return zones


def merge_close_zones(zones, min_gap=MIN_GAP):
    """Junta zonas que estao muito proximas (gap < min_gap)."""
    if not zones:
        return zones

    merged = [zones[0]]
    for start, end in zones[1:]:
        prev_start, prev_end = merged[-1]
        if start - prev_end <= min_gap:
            merged[-1] = (prev_start, end)
        else:
            merged.append((start, end))

    return merged


def split_wide_zone(img, zone_start, zone_end, expected_count):
    """Divide uma zona larga em N personagens usando analise de gaps internos."""
    width = zone_end - zone_start

    # Procurar gaps internos menores dentro da zona
    sub_gaps = []
    in_gap = False
    gap_start = 0

    for x in range(zone_start, zone_end):
        empty = is_column_empty(img, x)
        if empty and not in_gap:
            in_gap = True
            gap_start = x
        elif not empty and in_gap:
            in_gap = False
            sub_gaps.append((gap_start, x, x - gap_start))

    if in_gap:
        sub_gaps.append((gap_start, zone_end, zone_end - gap_start))

    if not sub_gaps:
        # Sem gaps internos - dividir uniformemente
        char_w = width // expected_count
        return [(zone_start + i * char_w, zone_start + (i + 1) * char_w) for i in range(expected_count)]

    # Usar os maiores gaps como pontos de corte
    sub_gaps.sort(key=lambda g: g[2], reverse=True)
    cut_points = sorted([zone_start] + [g[0] + g[2] // 2 for g in sub_gaps[:expected_count - 1]] + [zone_end])

    result = []
    for i in range(len(cut_points) - 1):
        result.append((cut_points[i], cut_points[i + 1]))

    return result


def smart_cut(sheet_path, action_name, num_frames):
    img = Image.open(sheet_path).convert('RGBA')
    w, h = img.size
    out_dir = os.path.dirname(sheet_path) or "."

    print(f"Folha: {w}x{h}")
    print(f"Frames esperados: {num_frames}")
    print("-" * 50)

    # Passo 1: encontrar zonas de conteudo
    raw_zones = find_character_zones(img)
    zones = merge_close_zones(raw_zones, min_gap=MIN_GAP)

    print(f"Zonas brutas detectadas: {len(raw_zones)}")
    print(f"Zonas apos merge: {len(zones)}")

    # Passo 2: se temos menos zonas que frames, subdividir zonas largas
    if len(zones) < num_frames:
        avg_width = sum(e - s for s, e in zones) / len(zones)
        final_chars = []

        for zs, ze in zones:
            zone_width = ze - zs
            estimated_chars = max(1, round(zone_width / avg_width))

            if estimated_chars > 1 and len(final_chars) + estimated_chars <= num_frames:
                sub_chars = split_wide_zone(img, zs, ze, estimated_chars)
                final_chars.extend(sub_chars)
            else:
                final_chars.append((zs, ze))

        # Ajustar para o numero exato de frames
        while len(final_chars) < num_frames:
            # Encontrar a zona mais larga e dividir ao meio
            widths = [(e - s, i) for i, (s, e) in enumerate(final_chars)]
            widths.sort(reverse=True)
            widest_idx = widths[0][1]
            ws, we = final_chars[widest_idx]
            mid = (ws + we) // 2
            final_chars[widest_idx] = (ws, mid)
            final_chars.insert(widest_idx + 1, (mid, we))

        zones = final_chars[:num_frames]
    elif len(zones) > num_frames:
        zones = zones[:num_frames]

    print(f"Zonas finais: {len(zones)}")
    for i, (zs, ze) in enumerate(zones):
        print(f"  Char {i+1}: x={zs}-{ze} ({ze-zs}px)")

    # Passo 3: cortar e redimensionar cada frame
    print("-" * 50)
    for i, (zs, ze) in enumerate(zones):
        # Adicionar margem para centralizar
        char_w = ze - zs

        # Crop com altura total
        frame = img.crop((zs, 0, ze, h))

        # Redimensionar mantendo proporcao, depois encaixar no canvas 220x300
        ratio_w = TARGET_W / char_w
        ratio_h = TARGET_H / h
        ratio = min(ratio_w, ratio_h)

        new_w = int(char_w * ratio)
        new_h = int(h * ratio)

        frame_resized = frame.resize((new_w, new_h), Image.LANCZOS)

        # Criar canvas final centralizado
        canvas = Image.new('RGBA', (TARGET_W, TARGET_H), (0, 0, 0, 0))
        paste_x = (TARGET_W - new_w) // 2
        paste_y = TARGET_H - new_h  # alinhar pelos pes (parte inferior)
        canvas.paste(frame_resized, (paste_x, paste_y))

        filename = f"{action_name}_{i+1:02d}.png"
        filepath = os.path.join(out_dir, filename)
        canvas.save(filepath)
        print(f"  [{i+1}] {filename}  (zona {char_w}px -> {TARGET_W}x{TARGET_H}, centralizado)")

    print("-" * 50)
    print(f"OK! {num_frames} frames salvos em {out_dir}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Uso: python cut_sprites_smart.py <arquivo_folha> <nome_acao> <num_frames>")
        print("Ex:  python cut_sprites_smart.py pasta/folha.png walk 8")
        sys.exit(1)

    smart_cut(sys.argv[1], sys.argv[2], int(sys.argv[3]))
