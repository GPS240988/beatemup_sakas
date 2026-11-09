#!/usr/bin/env python3
"""
tools/deploy_web.py
Script oficial de orquestração de deploy do Beat 'em Up Sakas para a Vercel.

Responsabilidades:
1. Construção automatizada de pacotes modulares (Multi-PCK via tools/pack_builder.gd).
2. Validação de integridade dos arquivos exportados em public/ e public/packs/.
3. Garantia de respeito ao orçamento de segurança (< 45 MB por pacote, longe dos 100 MB da Vercel).
4. Execução da automação PWA (scripts/pwa_post_export.js) para carimbo de versão e Service Worker.
5. Disparo do deploy de produção na Vercel (vercel --prod).
"""

import os
import sys
import subprocess
from pathlib import Path

# Suporte UTF-8 no terminal Windows
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

ROOT_DIR = Path(__file__).resolve().parent.parent
PUBLIC_DIR = ROOT_DIR / "public"
PACKS_DIR = PUBLIC_DIR / "packs"
PACK_BUILDER_SCRIPT = ROOT_DIR / "tools" / "pack_builder.gd"
PWA_SCRIPT = ROOT_DIR / "scripts" / "pwa_post_export.js"

MAX_PACK_MB = 45.0


def print_header(title: str):
    print("\n" + "=" * 70)
    print(f" {title}")
    print("=" * 70)


def ensure_godot_web_export():
    pck_path = PUBLIC_DIR / "index.pck"
    wasm_path = PUBLIC_DIR / "index.wasm"
    preset_path = ROOT_DIR / "export_presets.cfg"
    presets_newer = (
        pck_path.exists()
        and preset_path.exists()
        and preset_path.stat().st_mtime > pck_path.stat().st_mtime
    )
    needs_export = not pck_path.exists() or not wasm_path.exists() or presets_newer or "--force-export" in sys.argv

    if needs_export:
        print_header("0. EXPORTANDO PROJETO BASE GODOT WEB (godot_console --headless)")
        if presets_newer:
            print("  export_presets.cfg foi modificado. Re-exportando index.pck e index.wasm...")
        else:
            print("  index.pck ou index.wasm ausentes/forçados. Disparando exportação automática do Godot...")
        cmd = ["godot_console.exe", "--headless", "--export-release", "Web", "public/index.html"]
        print(f"  Executando: {' '.join(cmd)} ...")
        res = subprocess.run(cmd, cwd=ROOT_DIR)
        if res.returncode != 0:
            print(f"  [ERRO] Falha na exportação Web do Godot (Código {res.returncode})")
            sys.exit(res.returncode)
        print("  [OK] Exportação Web do Godot concluída com sucesso!")


def build_modular_packs():
    print_header("1. CONSTRUINDO PACOTES MODULARES (Multi-PCK via Godot)")
    if not PACK_BUILDER_SCRIPT.exists():
        print(f"  [ERRO] Script empacotador não encontrado: {PACK_BUILDER_SCRIPT}")
        sys.exit(1)

    cmd = ["godot_console.exe", "--headless", "-s", str(PACK_BUILDER_SCRIPT)]
    print(f"  Executando: {' '.join(cmd)} ...")
    res = subprocess.run(cmd, cwd=ROOT_DIR)
    if res.returncode != 0:
        print(f"\n[FALHA] Erro ao construir os pacotes modulares (Código: {res.returncode})")
        sys.exit(res.returncode)


def check_exported_binaries():
    print_header("2. AUDITORIA DE INTEGRIDADE DOS BINÁRIOS (public/)")

    required_base_files = {
        "index.html": 1000,              # > 1 KB
        "index.js": 10000,               # > 10 KB
        "index.wasm": 10 * 1024 * 1024,  # > 10 MB
        "index.pck": 10 * 1024 * 1024,   # > 10 MB
        "index.service.worker.js": 500,
        "mobile_shell.html": 1000,
    }

    all_ok = True
    for fname, min_size in required_base_files.items():
        fpath = PUBLIC_DIR / fname
        if not fpath.exists():
            print(f"  [ERRO] Arquivo base obrigatório ausente: public/{fname}")
            all_ok = False
            continue

        size = fpath.stat().st_size
        size_mb = size / (1024 * 1024)
        if size < min_size:
            print(f"  [ERRO] public/{fname} parece corrompido ou ponteiro LFS! ({size} bytes < {min_size} bytes)")
            all_ok = False
        else:
            if size_mb >= 1.0:
                print(f"  [OK] public/{fname:<24} -> {size_mb:6.2f} MB")
            else:
                print(f"  [OK] public/{fname:<24} -> {size / 1024:6.2f} KB")

    print("\n  -- Pacotes Modulares Adicionais (public/packs/) --")
    required_packs = [
        "pack_audio_bgm.pck",
        "pack_story_cinematics.pck",
        "pack_stage1.pck",
        "manifest.json"
    ]

    for pname in required_packs:
        ppath = PACKS_DIR / pname
        if not ppath.exists():
            print(f"  [ERRO] Pacote modular ausente: public/packs/{pname}")
            all_ok = False
            continue

        size = ppath.stat().st_size
        size_mb = size / (1024 * 1024)
        if pname.endswith(".pck") and size_mb > MAX_PACK_MB:
            print(f"  [ALERTA] public/packs/{pname} excedeu o teto de {MAX_PACK_MB} MB! ({size_mb:.2f} MB)")
            all_ok = False
        else:
            if size_mb >= 1.0:
                print(f"  [OK] public/packs/{pname:<20} -> {size_mb:6.2f} MB (Teto: < {MAX_PACK_MB} MB)")
            else:
                print(f"  [OK] public/packs/{pname:<20} -> {size / 1024:6.2f} KB")

    if not all_ok:
        print("\n[FALHA] Validação dos binários falhou. Corrija os erros antes do deploy.")
        sys.exit(1)


def run_pwa_post_export():
    print_header("3. CARIMBANDO VERSÃO E ATUALIZANDO SERVICE WORKER")
    if not PWA_SCRIPT.exists():
        print(f"  [ERRO] Script não encontrado: {PWA_SCRIPT}")
        sys.exit(1)

    res = subprocess.run(["node", str(PWA_SCRIPT)], cwd=ROOT_DIR)
    if res.returncode != 0:
        print("  [ERRO] Falha ao executar scripts/pwa_post_export.js")
        sys.exit(res.returncode)


def deploy_to_vercel():
    print_header("4. PUBLICANDO NA VERCEL (PRODUÇÃO)")

    cmd_str = "vercel --prod --yes"
    print(f"  Disparando: {cmd_str} ...")

    try:
        res = subprocess.run(cmd_str, shell=True, cwd=ROOT_DIR)
        if res.returncode == 0:
            print_header("DEPLOY MULTI-PCK CONCLUÍDO COM SUCESSO!")
            print("  O jogo Beat 'em Up Sakas está atualizado e no ar na Vercel.")
            print("  Todos os pacotes modulares foram publicados e validados com folga.")
        else:
            print(f"\n[AVISO] Vercel CLI retornou código {res.returncode}.")
            print("Se for a primeira vez usando a CLI ou seu token expirou, execute no terminal:")
            print("  vercel login")
            print("Depois execute novamente:")
            print("  python tools/deploy_web.py")
    except Exception as e:
        print(f"  [ERRO] Exceção ao executar o Vercel CLI: {e}")


def main():
    ensure_godot_web_export()
    build_modular_packs()
    check_exported_binaries()
    run_pwa_post_export()

    if "--verify-only" in sys.argv:
        print("\n[OK] Verificação de integridade concluída com sucesso (--verify-only).")
        return

    deploy_to_vercel()


if __name__ == "__main__":
    main()
