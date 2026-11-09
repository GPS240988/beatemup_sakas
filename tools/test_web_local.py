#!/usr/bin/env python3
"""
tools/test_web_local.py
Servidor local especializado para testes da build Web do Godot 4 (Beat 'em Up Sakas).

Fornece automaticamente:
1. Cabeçalhos obrigatórios Cross-Origin (COOP/COEP) para SharedArrayBuffer.
2. Suporte para carregamento dos pacotes modulares (public/packs/).
3. Abertura automática do navegador no endereço correto (http://localhost:8080).
"""

import sys
import os
import webbrowser
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
PUBLIC_DIR = ROOT_DIR / "public"
DEFAULT_PORT = 8080


class GodotWebRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(PUBLIC_DIR), **kwargs)

    def end_headers(self):
        # Cabeçalhos essenciais para WebAssembly multithreading e Godot 4 Web
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def log_message(self, format, *args):
        # Log limpo apenas de requisições de status ou erro
        if len(args) > 1 and str(args[1]) in ("200", "206", "304"):
            return
        sys.stderr.write(f"  [{self.log_date_time_string()}] {args[0]} -> {args[1]}\n")


def main():
    pck_path = PUBLIC_DIR / "index.pck"
    if not pck_path.exists():
        print("\n[AVISO] public/index.pck não foi encontrado!")
        print("Execute primeiro 'tools\\deploy_web.bat' ou 'python tools/deploy_web.py --verify-only' para gerar os arquivos.")
        sys.exit(1)

    port = DEFAULT_PORT
    server = None
    for attempt in range(5):
        try:
            server = HTTPServer(("127.0.0.1", port), GodotWebRequestHandler)
            break
        except OSError:
            port += 1

    if not server:
        print(f"[ERRO] Não foi possível iniciar o servidor local nas portas {DEFAULT_PORT}-{port}.")
        sys.exit(1)

    url = f"http://127.0.0.1:{port}/"
    print("\n" + "=" * 65)
    print(" SAKAS - SERVIDOR LOCAL DE TESTES WEB (GODOT 4 MULTI-PCK)")
    print("=" * 65)
    print(f"  Servindo arquivos de: {PUBLIC_DIR}")
    print(f"  URL Local:            {url}")
    print(f"  COOP / COEP Ativos:   Sim (same-origin / require-corp)")
    print("  Pressione Ctrl+C para encerrar o servidor a qualquer momento.")
    print("=" * 65 + "\n")

    webbrowser.open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[Sakas Web] Servidor local encerrado.")
        server.server_close()


if __name__ == "__main__":
    main()

