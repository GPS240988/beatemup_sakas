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

import json
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

VERCEL_FILE_LIMIT_MB = 100.0
MAX_CORE_PCK_MB = 85.0
MAX_WASM_MB = 85.0
MAX_PACK_MB = 45.0


def print_header(title: str):
    print("\n" + "=" * 70)
    print(f" {title}")
    print("=" * 70)


def ensure_godot_web_export():
    pck_path = PUBLIC_DIR / "index.pck"
    wasm_path = PUBLIC_DIR / "index.wasm"
    preset_path = ROOT_DIR / "export_presets.cfg"
    project_path = ROOT_DIR / "project.godot"

    presets_newer = (
        pck_path.exists()
        and preset_path.exists()
        and preset_path.stat().st_mtime > pck_path.stat().st_mtime
    )
    project_newer = (
        pck_path.exists()
        and project_path.exists()
        and project_path.stat().st_mtime > pck_path.stat().st_mtime
    )

    sources_newer = False
    if pck_path.exists():
        pck_mtime = pck_path.stat().st_mtime
        for check_dir in [ROOT_DIR / "scenes", ROOT_DIR / "scripts", ROOT_DIR / "resources", ROOT_DIR / "assets"]:
            if check_dir.exists():
                for root, _, files in os.walk(check_dir):
                    for f in files:
                        fp = Path(root) / f
                        if fp.suffix in ('.tscn', '.gd', '.tres') and fp.stat().st_mtime > pck_mtime:
                            sources_newer = True
                            break
                    if sources_newer:
                        break
            if sources_newer:
                break

    needs_export = (
        not pck_path.exists()
        or not wasm_path.exists()
        or presets_newer
        or project_newer
        or sources_newer
        or "--force-export" in sys.argv
    )

    if needs_export:
        print_header("0. EXPORTANDO PROJETO BASE GODOT WEB (godot_console --headless)")
        if presets_newer:
            print("  export_presets.cfg foi modificado. Re-exportando index.pck e index.wasm...")
        elif project_newer:
            print("  project.godot foi modificado. Re-exportando index.pck e index.wasm...")
        elif sources_newer:
            print("  Arquivos fonte (.tscn / .gd / .tres) mais recentes que o pacote Web. Re-exportando...")
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
        "index.html": (1000, 10.0),              # > 1 KB, < 10 MB
        "index.js": (10000, 10.0),               # > 10 KB, < 10 MB
        "index.wasm": (10 * 1024 * 1024, MAX_WASM_MB),
        "index.pck": (10 * 1024 * 1024, MAX_CORE_PCK_MB),
        "index.service.worker.js": (500, 10.0),
        "mobile_shell.html": (1000, 10.0),
    }

    all_ok = True
    for fname, (min_size, max_mb) in required_base_files.items():
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
        elif size_mb > max_mb:
            print(f"  [ERRO CRÍTICO] public/{fname} excedeu o teto de {max_mb:.1f} MB (Vercel 100 MB)! ({size_mb:.2f} MB)")
            all_ok = False
        else:
            if size_mb >= 1.0:
                margin_vercel = VERCEL_FILE_LIMIT_MB - size_mb
                print(f"  [OK] public/{fname:<24} -> {size_mb:6.2f} MB (Teto: < {max_mb:.0f} MB | Folga Vercel: {margin_vercel:.2f} MB)")
            else:
                print(f"  [OK] public/{fname:<24} -> {size / 1024:6.2f} KB")

    print("\n  -- Pacotes Modulares Adicionais (public/packs/) --")
    manifest_path = PACKS_DIR / "manifest.json"
    if not manifest_path.exists():
        print("  [ERRO] Pacote modular ausente: public/packs/manifest.json")
        all_ok = False
    else:
        try:
            manifest_data = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest_packs = manifest_data.get("packs", {})
        except Exception as exc:
            print(f"  [ERRO] Falha ao ler public/packs/manifest.json: {exc}")
            manifest_packs = {}
            all_ok = False

        # Valida dinamicamente todos os pacotes declarados no manifesto + quaisquer .pck extras em public/packs/
        expected_pack_files = {info["file_name"] for info in manifest_packs.values() if "file_name" in info}
        actual_pack_files = {p.name for p in PACKS_DIR.glob("*.pck")}
        all_pack_names = sorted(expected_pack_files | actual_pack_files)

        if not all_pack_names:
            print("  [ERRO] Nenhum pacote .pck encontrado em public/packs/")
            all_ok = False

        for pname in all_pack_names:
            ppath = PACKS_DIR / pname
            if not ppath.exists():
                print(f"  [ERRO] Pacote declarado no manifesto ausente: public/packs/{pname}")
                all_ok = False
                continue

            size = ppath.stat().st_size
            size_mb = size / (1024 * 1024)
            if size_mb > MAX_PACK_MB:
                print(f"  [ALERTA] public/packs/{pname} excedeu o teto de {MAX_PACK_MB} MB! ({size_mb:.2f} MB)")
                all_ok = False
            else:
                margin = MAX_PACK_MB - size_mb
                print(f"  [OK] public/packs/{pname:<24} -> {size_mb:6.2f} MB (Teto: < {MAX_PACK_MB:.0f} MB | Margem: {margin:.2f} MB)")

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
            print(f"\n[AVISO CRÍTICO] Vercel CLI retornou código de erro {res.returncode}.")
            print("Sua sessão da Vercel expirou ou precisa de autenticação.")
            print("Para autenticar, abra o terminal e execute:")
            print("  vercel login")
            print("Depois execute novamente:")
            print("  tools\\deploy_web.bat\n")
            sys.exit(res.returncode)
    except Exception as e:
        print(f"  [ERRO] Exceção ao executar o Vercel CLI: {e}")
        sys.exit(1)


def ensure_pwa_icons():
    print_header("1.5. GARANTINDO ÍCONES OFICIAIS 'S' DO PWA")
    icons_script = ROOT_DIR / "tools" / "generate_pwa_icons.py"
    if icons_script.exists():
        res = subprocess.run([sys.executable, str(icons_script)], cwd=ROOT_DIR)
        if res.returncode != 0:
            print(f"  [AVISO] Erro ao gerar ícones PWA: {res.returncode}")


def main():
    ensure_godot_web_export()
    ensure_pwa_icons()
    build_modular_packs()
    check_exported_binaries()
    run_pwa_post_export()

    if "--verify-only" in sys.argv:
        print("\n[OK] Verificação de integridade concluída com sucesso (--verify-only).")
        return

    deploy_to_vercel()


if __name__ == "__main__":
    main()
