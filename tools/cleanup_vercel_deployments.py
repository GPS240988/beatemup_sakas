#!/usr/bin/env python3
"""
tools/cleanup_vercel_deployments.py
Script para listar e limpar em lote os deploys antigos acumulados na Vercel,
liberando gigabytes de Deployment Storage.
"""

import sys
import subprocess
import re

# Força codificação UTF-8 no console Windows
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

PROJECT_NAME = "beatemup-sakas"


def run_vercel_cmd(cmd_str: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd_str,
        shell=True,
        capture_output=True,
        encoding="utf-8",
        errors="replace"
    )


def get_current_production():
    res = run_vercel_cmd("vercel inspect https://beatemup-sakas.vercel.app")
    out = (res.stdout or "") + (res.stderr or "")
    m = re.search(r'https://beatemup-sakas-[a-z0-9]+-previatog\.vercel\.app', out)
    if m:
        return m.group(0)
    return "https://beatemup-sakas-30f0saui1-previatog.vercel.app"


def list_all_deployments():
    all_deps = []
    token = None
    for page in range(1, 15):
        cmd = f"vercel ls {PROJECT_NAME}"
        if token:
            cmd += f" --next {token}"
        res = run_vercel_cmd(cmd)
        out = (res.stdout or "") + (res.stderr or "")
        page_urls = []
        for line in out.splitlines():
            line = line.strip()
            if line.startswith(f"https://{PROJECT_NAME}-") and line.endswith(".vercel.app"):
                if line not in all_deps:
                    all_deps.append(line)
                    page_urls.append(line)
        if not page_urls:
            break
        m = re.search(r'--next\s+(\d+)', out)
        if m:
            token = m.group(1)
        else:
            break
    return all_deps


def main():
    print(f"Buscando deploys de {PROJECT_NAME}...")
    current_prod = get_current_production()
    print(f"Deploy atual de Produção (PROTEGIDO): {current_prod}\n")
    
    deps = list_all_deployments()
    print(f"Total de deploys encontrados: {len(deps)}")
    
    to_delete = [d for d in deps if d != current_prod]
    print(f"Deploys antigos que podem ser removidos: {len(to_delete)}")
    
    if len(to_delete) == 0:
        print("Nenhum deploy antigo para remover.")
        return

    # Estima o espaço a ser liberado (~140 MB por deploy)
    estimated_mb = len(to_delete) * 140
    print(f"Espaço estimado a ser liberado: ~{estimated_mb / 1024:.2f} GB!")
    
    if "--execute" not in sys.argv:
        print("\nPara executar a limpeza em lote com segurança, rode:")
        print("  python tools/cleanup_vercel_deployments.py --execute")
        print("\nExemplo dos 10 deploys mais antigos:")
        for d in to_delete[-10:]:
            print(f"  - {d}")
        return

    print("\nIniciando remoção segura em lote...")
    success_count = 0
    for i, url in enumerate(to_delete):
        print(f"[{i+1}/{len(to_delete)}] Removendo {url} ...", end=" ", flush=True)
        r = run_vercel_cmd(f"vercel remove {url} --yes")
        if r.returncode == 0:
            print("OK")
            success_count += 1
        else:
            print("PULADO/ERRO")
            
    print(f"\nLimpeza finalizada! {success_count} deploys removidos com sucesso.")
    print("Seu Deployment Storage na Vercel cairá para perto de zero!")


if __name__ == "__main__":
    main()
