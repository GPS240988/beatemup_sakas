#!/usr/bin/env python3
"""
PixelFX Manager — Beat 'em Up Sakas
Gerenciador DevOps para auditoria, conexão externa e exportação sob demanda
dos efeitos visuais PixelFX (Pixel Art HD) sem inflar o repositório do jogo.
"""

import os
import sys
import json
import shutil
import subprocess
import argparse

PIXELFX_UPSTREAM_URL = "https://github.com/patch-gg/pixelfx.git"
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LOCAL_TOOLS_DIR = os.path.join(PROJECT_ROOT, ".tools", "pixelfx")
GAME_EFFECTS_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites", "Efeitos", "pixelfx")
FRAMES_TRES_PATH = os.path.join(PROJECT_ROOT, "scenes", "vfx", "hit_effects_frames.tres")
COMBAT_FEEDBACK_PATH = os.path.join(PROJECT_ROOT, "scripts", "combat", "combat_feedback.gd")


def cmd_audit(args):
    """Audita os efeitos PixelFX utilizados no projeto e compara tamanhos."""
    print("=" * 65)
    print("AUDITORIA DE EFEITOS PIXELFX NO JOGO SAKAS")
    print("=" * 65)

    if not os.path.exists(GAME_EFFECTS_DIR):
        print("Diretório de efeitos não encontrado:", GAME_EFFECTS_DIR)
        return

    used_effects = []
    total_bytes = 0
    for f in sorted(os.listdir(GAME_EFFECTS_DIR)):
        if f.endswith(".png"):
            effect_id = f[:-4]
            png_path = os.path.join(GAME_EFFECTS_DIR, f)
            json_path = os.path.join(GAME_EFFECTS_DIR, f"{effect_id}.json")
            sz = os.path.getsize(png_path)
            total_bytes += sz
            has_json = os.path.exists(json_path)
            if has_json:
                total_bytes += os.path.getsize(json_path)
            used_effects.append({
                "id": effect_id,
                "png_size_kb": sz / 1024.0,
                "has_json": has_json,
                "file": f
            })

    print(f"\n[1] Efeitos Ativos no Runtime Godot ({len(used_effects)} encontrados):")
    for ef in used_effects:
        status_json = "+ JSON (metadados/pivot)" if ef["has_json"] else "sem JSON"
        print(f"  * {ef['id']:15} | PNG: {ef['png_size_kb']:6.1f} KB | {status_json}")

    print(f"\n  -> Espaço total ocupado pelos efeitos no jogo: {total_bytes / 1024.0:.1f} KB ({total_bytes / (1024*1024):.2f} MB)")

    # Verificar vínculos no SpriteFrames
    print(f"\n[2] Vínculos no SpriteFrames (hit_effects_frames.tres):")
    if os.path.exists(FRAMES_TRES_PATH):
        with open(FRAMES_TRES_PATH, "r", encoding="utf-8", errors="ignore") as f:
            tres_content = f.read()
        for ef in used_effects:
            anim_name = ef["id"].replace("-", "_")
            in_tres = f'"name": &"{anim_name}"' in tres_content or f'"{anim_name}"' in tres_content
            status = "[OK] Vinculado" if in_tres else "[?] Não encontrado na lista direta"
            print(f"  * Animação '{anim_name}': {status}")

    # Verificar mapeamento no CombatFeedback
    print(f"\n[3] Gatilhos em CombatFeedback.spawn_hit_spark():")
    if os.path.exists(COMBAT_FEEDBACK_PATH):
        with open(COMBAT_FEEDBACK_PATH, "r", encoding="utf-8", errors="ignore") as f:
            code = f.read()
        print("  * blunt_hit: Acionado em golpes de punho ('punch', 'light')")
        print("  * hit_spark: Acionado em chutes e voadora ('kick', 'medium')")
        print("  * crit_hit:  Acionado em finalizadores pesados e especial ('heavy', 'special')")

    # Status da ferramenta externa
    print(f"\n[4] Status da Conexão Externa PixelFX (.tools/pixelfx/):")
    if os.path.exists(LOCAL_TOOLS_DIR):
        tools_sz = sum(
            os.path.getsize(os.path.join(r, file))
            for r, _, files in os.walk(LOCAL_TOOLS_DIR)
            for file in files
        ) / (1024 * 1024)
        print(f"  * Repositório local de geração: INSTALADO ({tools_sz:.1f} MB)")
    else:
        print("  * Repositório local de geração: NÃO BAIXADO (Desacoplado)")
        print("    -> Para conectar sob demanda: python tools/pixelfx_manager.py connect")

    print("=" * 65)


def cmd_connect(args):
    """Conecta/clona o repositório PixelFX com clone raso (shallow clone) para economizar espaço."""
    print("=" * 65)
    print("CONECTANDO AO REPOSITÓRIO PIXELFX UPSTREAM")
    print(f"URL: {PIXELFX_UPSTREAM_URL}")
    print("=" * 65)

    if os.path.exists(LOCAL_TOOLS_DIR):
        print(f"Pasta {LOCAL_TOOLS_DIR} já existe. Atualizando repositório...")
        subprocess.run(["git", "-C", LOCAL_TOOLS_DIR, "pull", "--depth", "1"], check=False)
    else:
        os.makedirs(os.path.dirname(LOCAL_TOOLS_DIR), exist_ok=True)
        print("Executando shallow clone (--depth 1)...")
        res = subprocess.run([
            "git", "clone", "--depth", "1", PIXELFX_UPSTREAM_URL, LOCAL_TOOLS_DIR
        ])
        if res.returncode != 0:
            print("Falha ao clonar repositório PixelFX. Verifique conexão com a internet.")
            return

    # Instala dependências do PixelFX se npm estiver disponível
    package_json = os.path.join(LOCAL_TOOLS_DIR, "package.json")
    node_modules = os.path.join(LOCAL_TOOLS_DIR, "node_modules")
    if os.path.exists(package_json) and not os.path.exists(node_modules):
        print("\nInstalando dependências Node.js (esbuild)...")
        subprocess.run(["npm", "install", "--prefix", LOCAL_TOOLS_DIR], check=False)

    print("\n[OK] Conexão com PixelFX estabelecida com sucesso!")
    print("Você pode listar efeitos com: python tools/pixelfx_manager.py list")
    print("=" * 65)


def cmd_list(args):
    """Lista efeitos disponíveis no catálogo PixelFX."""
    if not os.path.exists(LOCAL_TOOLS_DIR):
        print("Repositório PixelFX não instalado localmente.")
        print("Execute primeiro: python tools/pixelfx_manager.py connect")
        return

    term = args.keyword if args.keyword else ""
    list_tool = os.path.join(LOCAL_TOOLS_DIR, "tools", "list.mjs")
    if os.path.exists(list_tool):
        cmd = ["node", list_tool]
        if term:
            cmd.append(term)
        subprocess.run(cmd, cwd=LOCAL_TOOLS_DIR)
    else:
        print("Script tools/list.mjs não encontrado em", LOCAL_TOOLS_DIR)


def cmd_export(args):
    """Renderiza um efeito e exporta o spritesheet diretamente para o Godot."""
    effect = args.effect
    if not os.path.exists(LOCAL_TOOLS_DIR):
        print("Repositório PixelFX não instalado localmente.")
        print("Execute primeiro: python tools/pixelfx_manager.py connect")
        return

    render_tool = os.path.join(LOCAL_TOOLS_DIR, "tools", "render.mjs")
    print(f"Renderizando spritesheet para '{effect}'...")
    res = subprocess.run(["node", render_tool, effect, "--sheet"], cwd=LOCAL_TOOLS_DIR)
    if res.returncode != 0:
        print(f"Erro ao renderizar efeito '{effect}'.")
        return

    # O PixelFX salva em records/<categoria>/<nome>/...
    effect_id = effect.split("/")[-1]
    records_dir = os.path.join(LOCAL_TOOLS_DIR, "records", effect)
    src_png = os.path.join(records_dir, f"{effect_id}.png")
    src_json = os.path.join(records_dir, f"{effect_id}.json")

    os.makedirs(GAME_EFFECTS_DIR, exist_ok=True)
    dst_png = os.path.join(GAME_EFFECTS_DIR, f"{effect_id}.png")
    dst_json = os.path.join(GAME_EFFECTS_DIR, f"{effect_id}.json")

    if os.path.exists(src_png):
        shutil.copy2(src_png, dst_png)
        print(f"[OK] Spritesheet copiado para: {dst_png}")
    if os.path.exists(src_json):
        shutil.copy2(src_json, dst_json)
        print(f"[OK] Metadados copiados para: {dst_json}")

    print("\nEfeito exportado com sucesso! Para importá-lo no Godot, adicione as fatias ao 'hit_effects_frames.tres'.")


def cmd_clean(args):
    """Remove a pasta .tools/pixelfx mantendo 100% dos efeitos compilados."""
    if os.path.exists(LOCAL_TOOLS_DIR):
        print(f"Removendo pasta de ferramentas temporárias: {LOCAL_TOOLS_DIR}...")
        try:
            shutil.rmtree(LOCAL_TOOLS_DIR)
            print("[OK] Diretório .tools/pixelfx removido. O projeto agora contém apenas os assets em uso!")
        except Exception as e:
            print("Erro ao remover:", e)
    else:
        print("A pasta .tools/pixelfx já não existe.")


def cmd_prune_lfs(args):
    """Explica e executa git lfs prune para limpar o cache de builds antigos no repositório."""
    print("=" * 65)
    print("DIAGNÓSTICO E LIMPEZA DE GIT LFS (~2GB)")
    print("=" * 65)
    print("O tamanho superior a 2GB no .git decorre de versões históricas de exportação")
    print("Web (public/index.pck e index.wasm) acumuladas no cache do Git LFS (.git/lfs/objects/).")
    print("\nExecutando 'git lfs prune' para liberar os objetos que não estão no commit atual...")
    res = subprocess.run(["git", "lfs", "prune"], capture_output=True, text=True)
    print(res.stdout)
    if res.stderr:
        print(res.stderr)
    print("=" * 65)


def main():
    parser = argparse.ArgumentParser(description="Gerenciador DevOps do PixelFX para Beat 'em Up Sakas")
    subparsers = parser.add_subparsers(dest="command", help="Comandos disponíveis")

    subparsers.add_parser("audit", help="Audita efeitos em uso e tamanho")
    subparsers.add_parser("connect", help="Conecta ao repositório PixelFX com shallow clone")
    subparsers.add_parser("clean", help="Remove ferramentas locais do PixelFX")
    subparsers.add_parser("prune-lfs", help="Limpa cache de LFS antigo do repositório")

    list_p = subparsers.add_parser("list", help="Lista efeitos do catálogo")
    list_p.add_argument("keyword", nargs="?", default="", help="Palavra-chave (ex: blunt, impact, slash)")

    export_p = subparsers.add_parser("export", help="Renderiza e exporta spritesheet para o Godot")
    export_p.add_argument("effect", help="Caminho do efeito (ex: impacts/blunt-hit)")

    args = parser.parse_args()
    if not args.command:
        cmd_audit(args)
    elif args.command == "audit":
        cmd_audit(args)
    elif args.command == "connect":
        cmd_connect(args)
    elif args.command == "list":
        cmd_list(args)
    elif args.command == "export":
        cmd_export(args)
    elif args.command == "clean":
        cmd_clean(args)
    elif args.command == "prune-lfs":
        cmd_prune_lfs(args)


if __name__ == "__main__":
    main()
