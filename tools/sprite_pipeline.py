"""
tools/sprite_pipeline.py - Pipeline Definitivo de Processamento e Normalização de Sprites (Project Sakas)

Objetivo:
Eliminar a necessidade de recortar e redimensionar sprites manualmente em sites de terceiros.
Recebe folhas de sprites brutas geradas por IA, remove fundos, fatia a grade, aplica escala anatômica
uniforme e alinha os pés na linha de contato do solo (Y = 290) de forma 100% automatizada.
"""

import argparse
import os
import sys
from PIL import Image


def remove_background(img: Image.Image, tolerance: int = 30) -> Image.Image:
    """Converte fundo sólido (branco ou cor de canto) em canal alfa transparente."""
    rgba = img.convert("RGBA")
    corner_color = rgba.getpixel((0, 0))
    # Se o canto já for transparente, não precisa chroma-key
    if corner_color[3] < 20:
        return rgba

    data = rgba.getdata()
    new_data = []
    cr, cg, cb, _ = corner_color
    for item in data:
        r, g, b, a = item
        if abs(r - cr) < tolerance and abs(g - cg) < tolerance and abs(b - cb) < tolerance:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append((r, g, b, 255))
    rgba.putdata(new_data)
    return rgba


def get_bounding_box(img: Image.Image, alpha_threshold: int = 30):
    """Calcula a bounding box precisa da silhueta do personagem."""
    alpha = img.split()[-1]
    w, h = img.size
    points = []
    for y in range(h):
        for x in range(w):
            if alpha.getpixel((x, y)) > alpha_threshold:
                points.append((x, y))
    if not points:
        return None
    min_x = min(p[0] for p in points)
    max_x = max(p[0] for p in points)
    min_y = min(p[1] for p in points)
    max_y = max(p[1] for p in points)
    return (min_x, min_y, max_x + 1, max_y + 1)


def process_sheet(
    sheet_path: str,
    output_dir: str,
    cols: int = 7,
    rows: int = 3,
    canvas_w: int = 280,
    canvas_h: int = 300,
    ground_y: int = 289,
    ref_standing_height: int = 275,
    names: list = None
):
    """Processa uma folha completa aplicando escala uniforme e baseline Y=290."""
    if not os.path.exists(sheet_path):
        print(f"[ERRO] Arquivo não encontrado: {sheet_path}")
        return False

    os.makedirs(output_dir, exist_ok=True)
    sheet = Image.open(sheet_path)
    sheet_rgba = remove_background(sheet)
    sw, sh = sheet_rgba.size

    cell_w = sw // cols
    cell_h = sh // rows
    print(f"--- Processando Folha: {sheet_path} ---")
    print(f"Dimensões: {sw}x{sh} | Grid: {cols} colunas x {rows} linhas | Célula: {cell_w}x{cell_h}px")

    # Passo 1: Detectar altura do personagem de referência (em pé na linha 1, coluna 1)
    c1 = sheet_rgba.crop((0, 0, cell_w, cell_h))
    bb1 = get_bounding_box(c1)
    if bb1:
        base_h = bb1[3] - bb1[1]
        uniform_scale = float(ref_standing_height) / float(base_h)
        print(f"Altura de referência detectada: {base_h}px -> Fator de escala uniforme travado: {uniform_scale:.3f}x")
    else:
        uniform_scale = 1.85
        print(f"Referência não detectada. Usando escala padrão: {uniform_scale:.3f}x")

    # Mapeamento padrão se nenhum nome for passado
    default_names = [
        # Linha 1: Stance & Ataques básicos
        "idle", "punch_01", "punch_02", "punch_03", "kick_01", "kick_02", "kick_03",
        # Linha 2: Ataques pesados e reações
        "heavy_01", "heavy_02", "heavy_03", "guard", "hurt_01", "hurt_02", "fall_01",
        # Linha 3: Queda, levantar, corrida e pulo
        "fall_02", "fall_03", "getup_01", "getup_02", "death", "jump_01", "jump_02"
    ]

    export_names = names if names and len(names) == cols * rows else default_names

    index = 0
    for r in range(rows):
        for c in range(cols):
            x1 = c * cell_w
            y1 = r * cell_h
            x2 = x1 + cell_w
            y2 = y1 + cell_h
            cell = sheet_rgba.crop((x1, y1, x2, y2))
            bb = get_bounding_box(cell)

            name = export_names[index] if index < len(export_names) else f"frame_{r+1}_{c+1}"
            out_filename = f"{name}.png"
            out_path = os.path.join(output_dir, out_filename)

            if not bb:
                print(f"  [AVISO] Célula R{r+1}C{c+1} vazia, ignorando...")
                index += 1
                continue

            char_crop = cell.crop(bb)
            cw, ch = char_crop.size

            # Aplica o MESMO fator de escala anatômico uniforme para todas as poses
            nw = max(1, int(cw * uniform_scale))
            nh = max(1, int(ch * uniform_scale))
            scaled_char = char_crop.resize((nw, nh), Image.Resampling.LANCZOS)

            # Canvas de destino
            target_w = max(canvas_w, nw + 10)
            target_canvas = Image.new("RGBA", (target_w, canvas_h), (0, 0, 0, 0))

            pos_x = (target_w - nw) // 2
            pos_y = ground_y - nh

            # Clamping defensivo
            if pos_y < 0:
                pos_y = 0

            target_canvas.paste(scaled_char, (pos_x, pos_y), scaled_char)
            target_canvas.save(out_path)
            print(f"  [OK] Exportado: {out_filename:<15s} | Char: {nw}x{nh}px | Canvas: {target_w}x{canvas_h}px | Chão: Y={ground_y}")
            index += 1

    print(f"\n[SUCESSO] Todos os frames exportados em: {output_dir}")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Pipeline Definitivo de Sprites do Project Sakas")
    parser.add_argument("--input", required=True, help="Caminho da folha de sprites bruta (PNG/JPG)")
    parser.add_argument("--out", required=True, help="Diretório de saída (ex: assets/sprites/characters/nome/)")
    parser.add_argument("--cols", type=int, default=7, help="Número de colunas (padrão: 7)")
    parser.add_argument("--rows", type=int, default=3, help="Número de linhas (padrão: 3)")
    parser.add_argument("--canvas_w", type=int, default=280, help="Largura do canvas (padrão: 280)")
    parser.add_argument("--canvas_h", type=int, default=300, help="Altura do canvas (padrão: 300)")
    parser.add_argument("--ground_y", type=int, default=289, help="Linha de contato do solo (padrão: 289)")
    parser.add_argument("--ref_h", type=int, default=275, help="Altura do personagem em pé (padrão: 275)")

    args = parser.parse_args()
    process_sheet(
        sheet_path=args.input,
        output_dir=args.out,
        cols=args.cols,
        rows=args.rows,
        canvas_w=args.canvas_w,
        canvas_h=args.canvas_h,
        ground_y=args.ground_y,
        ref_standing_height=args.ref_h
    )
