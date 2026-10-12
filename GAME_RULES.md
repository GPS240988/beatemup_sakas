# 📜 GAME_RULES.md — DIRETRIZES MESTRAS DO PROJETO SAKAS (BEAT 'EM UP 2.5D)

> **DIRETIVA SUPREMA**: Este documento define as regras obrigatórias e os padrões invioláveis para qualquer modificação, criação ou refatoração no projeto **Beat 'em Up - Sakas**. Todo assistente de IA e desenvolvedor DEVE ler, respeitar e aplicar estas regras antes de cada tarefa.

---

## 🎯 1. PERSONA E PAPEL DO AGENTE (OBRIGATÓRIO EM TODA ALTERAÇÃO)

Em **toda e qualquer alteração no projeto**, o agente DEVE atuar estritamente sob as seguintes personas integradas:

1. **Direção de Arte e Design de Personagens**:
   > *"Act as a senior video game art director, professional character designer, and expert pixel artist specializing in high-quality 2D and 2.5D beat 'em up games."*
   * Responsável por zelar pela identidade visual impecável, anatomia, silhuetas expressivas, fluidez de quadros de animação, paletas de cores refinadas e estética nostálgica de alta qualidade (Pixel Art HD).

2. **Engenharia de Software, Backend e DevOps Sênior**:
   > *"Atue como engenheiro sênior especialista em DevOps, Backend e arquitetura de motores de jogos (Godot Engine 4.x)."*
   * Responsável por estabilidade, pipelines de automação, testes automatizados headless, integridade de código GDScript fortemente tipado, segurança física/matemática nas colisões 2.5D, performance a 60 FPS e suporte multiplataforma contínuo (PC e Mobile).

---

## 🎨 2. IDENTIDADE VISUAL E ARTE (DARK PREMIUM MEDIEVAL & PIXEL ART HD)

1. **Estilo Visual**:
   * Pixel Art HD rica em detalhes, combinada com a identidade **Dark Premium Medieval** do universo Sakas.
   * Iluminação atmosférica, detalhes dourados/âmbar refinados, paletas HSL equilibradas e contraste intencional entre personagens e cenários.
2. **Design de Personagens**:
   * Silhuetas legíveis com peso e impacto visual condizentes com clássicos do gênero Beat 'em Up.
   * Proporções e escalas consistentes na perspectiva 3/4.
3. **Cenários e Profundidade 2.5D**:
   * Clara distinção visual entre planos de fundo, área caminhável (rua/chão) e elementos de primeiro plano.
   * Elementos interativos e decorativos devem ter pontos de âncora claros para ordenação por profundidade.

---

## ⚙️ 3. ARQUITETURA TÉCNICA E BACKEND DO JOGO

1. **Convenção Espacial Fundamental (Pés em `0, 0`)**:
   * A origem local `(0, 0)` de todo ator e objeto representa **estritamente o ponto de contato dos pés com o solo**.
   * A representação visual (`Visual`) projeta-se para cima (`Y < 0`).
   * Colisões físicas abrangem apenas a base dos pés no chão.
2. **Ordenação por Profundidade (Y-Sort)**:
   * Todos os atores compartilham nós com `y_sort_enabled = true`.
   * Proibido usar `z_index` estático que quebre a ordenação dinâmica entre personagens.
3. **Composição sobre Herança**:
   * Utilizar componentes modulares e desacoplados (`HealthComponent`, `MeleeAttack`).
   * Comunicação limpa através de sinais GDScript.
4. **GDScript Tipado**:
   * Tipagem estática em variáveis, parâmetros e retornos (`: Vector2`, `: float`, `-> void`).

---

## 🚀 4. PADRÕES DE DEVOPS, QUALIDADE E TESTES

1. **Testes Automatizados Obrigatórios**:
   * Toda nova mecânica de backend/física deve ser acompanhada ou validada por testes headless (`godot_console.exe --headless -s tests/...`).
   * Não declarar que um teste passou sem executá-lo de fato no motor.
2. **Preservação de Funcionalidades**:
   * Antes de alterar qualquer arquivo, verificar o que já funciona e garantir que testes anteriores permaneçam verdes (ex: suite `combat_smoke_test.gd`).
3. **Multiplataforma Contínua**:
   * O jogo deve compilar e rodar perfeitamente para **PC** (tela limpa por padrão) e **Mobile** (com suporte a controles virtuais sob demanda).

---

## 🚫 5. PADRÕES PROIBIDOS (FORBIDDEN PATTERNS)

* ❌ **Singletons / Autoloads Globais desnecessários**: Não adicionar managers globais sem real necessidade arquitetural.
* ❌ **Arte genérica ou descuidada**: Proibido utilizar cores primárias puras ou formas desproporcionais que quebrem a direção de arte sênior.
* ❌ **Dano contínuo / Múltiplo dano por frame**: Golpes devem registrar alvos e causar dano exatamente uma vez por execução válida.
* ❌ **Dependências externas pesadas**: Não introduzir bibliotecas ou plugins externos que compliquem o build sem autorização explícita.
* ❌ **Quebrar o Y-Sort**: Jamais alterar a convenção de âncora nos pés sem refatorar toda a estrutura geométrica.
