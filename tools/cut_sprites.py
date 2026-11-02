"""
Script universal para cortar sprite sheets de qualquer resolucao.
Corta cada frame e redimensiona para 220x300 px (padrao Projeto Sakas).

Uso:
  python cut_sprites.py <arquivo_folha> <nome_acao> <colunas> <linhas>

Exemplos:
  python cut_sprites.py guilhermepal_caminhada8sprite.png walk 4 2
  python cut_sprites.py guilhermepal_punch.png punch 3 1
  python cut_sprites.py guilhermepal_kick.png kick 3 1
"""
import sys
import os
from PIL import Image

TARGET_W = 220
TARGET_H = 300

def cut_and_resize(sheet_path, action_name, cols, rows):
    sheet = Image.open(sheet_path)
    sw, sh = sheet.size
    frame_w = sw // cols
    frame_h = sh // rows
    
    out_dir = os.path.dirname(sheet_path)
    if not out_dir:
        out_dir = "."
    print(f"Folha: {sw}x{sh} | Grid: {cols}x{rows} | Frame bruto: {frame_w}x{frame_h}")
    print(f"Destino: {out_dir}")
    print(f"Redimensionar para: {TARGET_W}x{TARGET_H}")
    print("-" * 50)
    
    frame_num = 1
    for row in range(rows):
        for col in range(cols):
            x1 = col * frame_w
            y1 = row * frame_h
            x2 = x1 + frame_w
            y2 = y1 + frame_h
            
            frame = sheet.crop((x1, y1, x2, y2))
            frame = frame.resize((TARGET_W, TARGET_H), Image.LANCZOS)
            
            filename = f"{action_name}_{frame_num:02d}.png"
            filepath = os.path.join(out_dir, filename)
            frame.save(filepath)
            print(f"  [{frame_num}] {filename}  ({frame_w}x{frame_h} -> {TARGET_W}x{TARGET_H})")
            frame_num += 1
    
    print("-" * 50)
    print(f"OK! {frame_num - 1} frames salvos em {out_dir}")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Uso: python cut_sprites.py <arquivo_folha> <nome_acao> <colunas> <linhas>")
        print("Ex:  python cut_sprites.py pasta/folha.png walk 4 2")
        sys.exit(1)
    
    cut_and_resize(sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]))
