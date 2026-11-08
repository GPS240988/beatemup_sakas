#!/usr/bin/env python3
"""
tools/deploy_web.py
Script oficial de orquestração de deploy do Beat 'em Up Sakas para a Vercel.

Responsabilidades:
1. Validação de integridade dos arquivos exportados em public/ (index.html, index.pck, index.wasm).
2. Garantia de que os binários não são ponteiros LFS corrompidos.
3. Execução da automação PWA (scripts/pwa_post_export.js) para carimbo de versão e Service Worker.
4. Disparo do deploy de produção na Vercel (vercel --prod).
"""

import os
import sys
import subprocess
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
PUBLIC_DIR = ROOT_DIR / "public"
PWA_SCRIPT = ROOT_DIR / "scripts" / "pwa_post_export.js"


def print_header(title: str):
    print("\n" + "=" * 65)
    print(f" {title}")
    print("=" * 65)


def check_exported_binaries():
    print_header("1. VERIFICANDO ARQUIVOS EXPORTADOS (public/)")
    
    required_files = {
        "index.html": 1000,          # > 1 KB
        "index.js": 10000,           # > 10 KB
        "index.wasm": 10 * 1024 * 1024, # > 10 MB (evita ponteiro LFS de 130 bytes)
        "index.pck": 20 * 1024 * 1024,  # > 20 MB (evita ponteiro LFS de 130 bytes)
        "index.service.worker.js": 500,
        "mobile_shell.html": 1000,
    }

    all_ok = True
    for fname, min_size in required_files.items():
        fpath = PUBLIC_DIR / fname
        if not fpath.exists():
            print(f"  [ERRO] Arquivo obrigatório ausente: public/{fname}")
            all_ok = False
            continue
            
        size = fpath.stat().st_size
        size_mb = size / (1024 * 1024)
        if size < min_size:
            print(f"  [ERRO] public/{fname} parece corrompido ou é um ponteiro LFS! ({size} bytes < {min_size} bytes)")
            all_ok = False
        else:
            if size_mb >= 1.0:
                print(f"  [OK] public/{fname:<24} -> {size_mb:6.2f} MB")
            else:
                print(f"  [OK] public/{fname:<24} -> {size / 1024:6.2f} KB")

    if not all_ok:
        print("\n[FALHA] A exportação está incompleta. Exporte o projeto Web no Godot antes do deploy.")
        sys.exit(1)


def run_pwa_post_export():
    print_header("2. CARIMBANDO VERSÃO E ATUALIZANDO SERVICE WORKER")
    if not PWA_SCRIPT.exists():
        print(f"  [ERRO] Script não encontrado: {PWA_SCRIPT}")
        sys.exit(1)
        
    res = subprocess.run(["node", str(PWA_SCRIPT)], cwd=ROOT_DIR)
    if res.returncode != 0:
        print("  [ERRO] Falha ao executar scripts/pwa_post_export.js")
        sys.exit(res.returncode)


def deploy_to_vercel():
    print_header("3. PUBLICANDO NA VERCEL (PRODUÇÃO)")
    
    # 1. Checa se o comando vercel existe
    vercel_cmd = "vercel"
    if sys.platform == "win32":
        # Procura vercel.cmd ou vercel.ps1
        res = subprocess.run(["where", "vercel"], capture_output=True, text=True)
        if res.returncode != 0:
            print("  [AVISO] Vercel CLI não encontrado globalmente.")
            print("  Instale via: npm install -g vercel")
            print("  Ou rode: npx vercel --prod")
            vercel_cmd = "npx vercel"

    print("  Disparando: vercel --prod ...")
    cmd = [vercel_cmd, "--prod"] if vercel_cmd != "npx vercel" else ["npx", "vercel", "--prod"]
    
    try:
        res = subprocess.run(cmd, cwd=ROOT_DIR)
        if res.returncode == 0:
            print_header("DEPLOY CONCLUÍDO COM SUCESSO!")
            print("  O jogo Beat 'em Up Sakas está atualizado e no ar na Vercel.")
        else:
            print(f"\n[AVISO] Vercel CLI retornou código {res.returncode}.")
            print("Se for a primeira vez usando a CLI ou seu token expirou, execute no terminal:")
            print("  vercel login")
            print("Depois execute novamente:")
            print("  python tools/deploy_web.py")
    except Exception as e:
        print(f"  [ERRO] Exceção ao executar o Vercel CLI: {e}")


def main():
    check_exported_binaries()
    run_pwa_post_export()
    
    if "--verify-only" in sys.argv:
        print("\n[OK] Verificação de integridade concluída com sucesso (--verify-only).")
        return

    deploy_to_vercel()


if __name__ == "__main__":
    main()

