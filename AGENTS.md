# AGENTS.md — Project Sakas (Beat 'em Up 2.5D)

Guia essencial para assistentes de IA neste repositório.

## 1. Projeto Principal: Beat 'em Up - Sakas (Godot 4.x)
- A arquitetura oficial, contratos de nós, física 2.5D e UI estão em [GAME_RULES.md](file:///c:/Users/bobor/Documents/beat%20em%20up%20-%20sakas/GAME_RULES.md).
- **Diretriz de Testes em Conversação Natural**: Para iterações pontuais via chat, execute apenas a suíte focada no módulo que foi alterado (`godot_console.exe --headless -s tests/<teste_especifico>.gd`). A bateria completa de regressão (`tests/run_all_tests.ps1`) deve ser executada apenas para fechamento de marcos, CI ou quando solicitado explicitamente.

## 2. Servidor MCP / Plugin Godot-AI
- Para desenvolvimento do servidor MCP Python (`src/godot_ai/`) e plugin do editor (`plugin/addons/godot_ai/`), consulte o manual técnico completo em [docs/AGENTS_GODOT_AI.md](file:///c:/Users/bobor/Documents/beat%20em%20up%20-%20sakas/docs/AGENTS_GODOT_AI.md).
