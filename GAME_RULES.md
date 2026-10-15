# 📜 GAME_RULES.md — DIRETRIZES MESTRAS DO PROJETO SAKAS (BEAT 'EM UP 2.5D)

> **DIRETIVA SUPREMA**: Este documento define as regras obrigatórias e os padrões invioláveis para qualquer modificação, criação ou refatoração no projeto **Beat 'em Up - Sakas**. Todo assistente de IA e desenvolvedor DEVE ler, respeitar e aplicar estas regras antes de cada tarefa.

---

## 🎯 1. PERSONA E PAPEL DO AGENTE (OBRIGATÓRIO EM TODA ALTERAÇÃO)

Em **toda e qualquer alteração no projeto**, o agente DEVE atuar estritamente sob as seguintes personas integradas:

1. **Direção de Arte e Design de Personagens**:
   > *"Act as a senior video game art director, professional character designer, and expert pixel artist specializing in high-quality 2D and 2.5D beat 'em up games."*
   * Responsável por zelar pela identidade visual impecável, anatomia, silhuetas expressivas, fluidez de quadros de animação, paletas de cores refinadas e estética nostálgica de alta qualidade (Pixel Art HD).

2. **Engenharia de Software, Backend e DevOps Sênior**:
   > *"Atue como engenheiro sênior especialista em DevOps, sênior Backend, sênior FrontEnd e arquitetura de motores de jogos (Godot Engine 4.x)."*
   * Responsável por estabilidade, pipelines de automação, testes automatizados headless, integridade de código GDScript fortemente tipado, segurança física/matemática nas colisões 2.5D, performance a 60 FPS e suporte multiplataforma contínuo (PC e Mobile).

---

## 🎨 2. IDENTIDADE VISUAL E ARTE (DARK PREMIUM MEDIEVAL & PIXEL ART HD)

1. **Estilo Visual**:

   Pixel Art HD 2.5D inspirada nos jogos arcade beat ’em up da década de 1990, preservando a nostalgia visual dos clássicos, com acabamento moderno e riqueza de detalhes.

   Identidade visual retrô urbana, inspirada nos fliperamas e jogos de luta de rua dos anos 90, com cenários ambientados em Vila Prudente, São Paulo, incluindo ruas, comércios, locadoras de videogame e elementos da cultura urbana brasileira da época.

   Perspectiva 2.5D clássica: personagens e cenários construídos em Pixel Art 2D, com profundidade de movimentação no eixo Y, planos de fundo em múltiplas camadas, perspectiva lateral e sensação de volume tridimensional simulada por sprites.

   Paleta de cores característica dos anos 90, com cores vibrantes e contrastantes, sombras pixeladas bem definidas, tons urbanos, iluminação de néon, letreiros de fliperama e efeitos luminosos pontuais, sem exagerar nos filtros modernos.

   Iluminação e sombreamento em Pixel Art, com dithering controlado, contornos consistentes, reflexos estilizados e sombras coerentes com a direção da luz, preservando a leitura visual dos personagens durante o combate.

   Direção de arte consistente entre personagens, cenários e interface, inspirada na linguagem visual dos arcades clássicos, com sprites expressivos, silhuetas facilmente reconhecíveis, animações fluidas e cenários ricos em detalhes.

   Acabamento HD Pixel Art: pixels intencionais e bem definidos, agrupamentos de pixels organizados, texturas estilizadas e detalhes cuidadosamente trabalhados, evitando aparência borrada, vetorial, fotorrealista ou de pintura digital convencional.

   Referência estética: beat ’em ups arcade dos anos 90, combinando a composição lateral clássica, a profundidade de movimentação 2.5D e a atmosfera urbana nostálgica com a resolução, a legibilidade e o nível de acabamento de um jogo moderno.

   Regra de consistência: todas as artes devem parecer pertencer ao mesmo jogo, mantendo proporções de personagens, escala dos cenários, perspectiva, iluminação, densidade de pixels e paleta cromática compatíveis com a identidade visual de SAKAS: ÚLTIMA FICHA.

3. **Cenários e Profundidade 2.5D**:
   * Clara distinção visual entre planos de fundo, área caminhável (rua/chão) e elementos de primeiro plano.
   * Elementos interativos e decorativos devem ter pontos de âncora claros para ordenação por profundidade.
   * **Escala Padrão dos Atores (0.80)**: O sprite base do herói (300px nativos) utiliza escala `scale = Vector2(0.80, 0.80)` para atingir ~240px de altura final, garantindo proporção anatômica fidedigna com balcões, estantes e pé-direito dos cenários sem necessidade de novos sprites.
   * **Colisores de Mobília e Corredores de Navegação**: Móveis e estantes no solo possuem colisores em `WorldBoundaries` (`collision_layer = 2`), impedindo que atores pisem sobre mesas ou prateleiras e forçando a movimentação através dos corredores reais do cenário.

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

5. **Arquitetura de Combate Arcade (CombatDirector & Tokens 2.5D)**:
   * O combate entre múltiplos inimigos DEVE ser orquestrado centralizadamente via `CombatDirector`.
   * **Tokens Ofensivos**: `max_attack_tokens = 2` e `max_simultaneous_active_enemy_attacks = 1` por encontro, impedindo que múltiplos inimigos atinjam o jogador no mesmo frame.
   * **Movimentação 2.5D em Dois Estágios**:
     * Estágio 1: Alinhamento de profundidade Y (tolerância padrão de 15 px).
     * Estágio 2: Aproximação frontal horizontal X (alcance padrão de 70 px).
   * **Inimigos sem Token (Flanqueamento)**: Devem manter distância de espera (120 a 180 px) e ocupar pistas de profundidade Y alternadas, sem aglomeração (dogpiling) na mesma coordenada.
   * **Ciclo do Golpe**: Telegraph visual (~0.25s sem dano) -> Janela de Impacto Ativa -> Recuo de Recuperação (recoil 40-60 px).

6. **Progressão Sequencial dos Quatro Mapas da Fase 1**:
   * A primeira fase possui exatamente quatro mapas: `Mapa 1 -> Mapa 2 -> Mapa 3 -> Mapa 4 -> Fim da Fase 1`.
   * **Saída Trancada**: A área de saída inicia desabilitada (`monitoring = false`) durante o combate ativo.
   * **Indicador SIGA →**: A indicação visual piscante "SIGA →" aparece junto à saída SOMENTE após a confirmação da derrota de todos os inimigos (`encounter_cleared`).
   * **Avanço Manual**: O avanço ocorre estritamente quando o jogador alcança a área de saída liberada, nunca automaticamente ao matar o último inimigo.
   * **Mapa 4**: É o clímax da Fase 1 e encaminha diretamente para o encerramento/créditos, sendo proibida a criação de um "Mapa 5" fictício.

---

## 🚀 4. PADRÕES DE DEVOPS, QUALIDADE E TESTES

1. **Testes Automatizados Obrigatórios**:
   * Toda nova mecânica de backend/física deve ser acompanhada ou validada por testes headless (`godot_console.exe --headless -s tests/...`).
   * Não declarar que um teste passou sem executá-lo de fato no motor.
2. **Preservação de Funcionalidades**:
   * Antes de alterar qualquer arquivo, verificar o que já funciona e garantir que testes anteriores permaneçam verdes (ex: suites `combat_smoke_test.gd`, `combat_director_test.gd`, `map_progression_test.gd` e `ui_flow_test.gd`).
3. **Multiplataforma Contínua**:
   * O jogo deve compilar e rodar perfeitamente para **PC** (tela limpa por padrão) e **Mobile** (com suporte a controles virtuais sob demanda).

---

## 🚫 5. PADRÕES PROIBIDOS (FORBIDDEN PATTERNS)

* ❌ **Singletons / Autoloads Globais desnecessários**: Não adicionar managers globais sem real necessidade arquitetural.
* ❌ **Arte genérica ou descuidada**: Proibido utilizar cores primárias puras ou formas desproporcionais que quebrem a direção de arte sênior. Jamais substituir a arte grunge/street original de `selecao_personagem.jpg` por designs planos, vetoriais ou neon genéricos.
* ❌ **Aglomeração de Inimigos (Dogpiling)**: Proibido fazer todos os inimigos correrem para o mesmo ponto físico simultaneamente. Devem sempre usar o `CombatDirector` para flanqueamento e alternância de pistas Y.
* ❌ **Dano contínuo / Múltiplo dano por frame**: Golpes devem registrar alvos e causar dano exatamente uma vez por execução válida. Proibido ataques simultâneos que violem `max_simultaneous_active_enemy_attacks`.
* ❌ **Avanço prematuro de mapa**: Proibido liberar a saída ou exibir "SIGA →" enquanto houver inimigos vivos ou ondas pendentes.
* ❌ **Dependências externas pesadas**: Não introduzir bibliotecas ou plugins externos que compliquem o build sem autorização explícita.
* ❌ **Quebrar o Y-Sort**: Jamais alterar a convenção de âncora nos pés sem refatorar toda a estrutura geométrica.
* ❌ **Alterar codec de vídeo da tela inicial sem parâmetros intra-frame**: Proibido gerar `maingif.ogv` sem `-pix_fmt yuv420p -g 1`, o que reintroduziria chuvisco e macroblocos no decodificador libtheora da Godot 4.
* ❌ **Chamadas de Viewport desprotegidas em troca de cena**: Jamais chamar `get_viewport().set_input_as_handled()` após `change_scene_to_file()` sem validar se o viewport ainda existe (`if get_viewport() != null:`).

---

## 📦 6. REGRAS DE OTIMIZAÇÃO DE ASSETS, ESCALABILIDADE E PADRÕES VISUAIS OFICIAIS

1. **Vídeo de Abertura (Codec Theora / OGV Sem Chuvisco)**:
   * O motor da Godot Engine 4 utiliza um decodificador embutido da biblioteca `libtheora` que aceita exclusivamente o formato `yuv420p`.
   * Quando o codec utiliza estimativa de movimento padrão sobre pixel art com dithering e 256 cores, ocorrem erros de bitstream (`unpack_block_qpis`), preenchendo a tela com blocos de ruído/chuvisco.
   * **Comando Obrigatório e Padrão**:
     ```bash
     ffmpeg -y -i assets/backgrounds/maingif.gif -c:v libtheora -q:v 6 -pix_fmt yuv420p -g 1 assets/backgrounds/maingif.ogv
     ```
   * O parâmetro `-g 1` força quadros intra (keyframes) contínuos em `yuv420p`, eliminando 100% dos erros de decodificação e mantendo fidelidade de cores Pixel Art HD com tamanho reduzido.

2. **Menu Principal (Estados Oficiais em WebP Transparente menu_state_0 a 5)**:
   * O menu principal utiliza a transição entre os estados de imagem oficiais `menu_state_0.webp` até `menu_state_5.webp` localizados em `res://assets/backgrounds/menu_states/`.
   * Preserva a arte oficial com a pincelada vermelha para cada item selecionado (0: Novo Jogo, 1: Continuar, 2: Seleção de Personagens, 3: Mapa, 4: Configurações, 5: Sair).
   * O formato **WebP (RGBA)** é obrigatório para reduzir o peso de ~17 MB (PNGs brutos) para menos de 3.5 MB totais sem perda de qualidade visual.

3. **Tela de Seleção de Personagens (Padrão Oficial selecao_personagem.jpg em WebP)**:
   * **Banner de Título**: Exibe a faixa inclinada oficial com o texto completo "SELEÇÃO DE PERSONAGEM" (`res://assets/ui/character_select/title_banner.png`), preservando a palavra "SELEÇÃO" integralmente sem cortes.
   * **Quadro de Status Oficial**: O painel de atributos (`StatsPanel`) DEVE seguir rigorosamente a estética de `selecao_personagem.jpg` (base `stats_panel_raw.webp`), com fundo urbano desgastado, títulos "FORÇA", "VELOCIDADE", "TÉCNICA" e blocos paralelogramos inclinados: vermelhos vibrantes para atributos ativos e azul-acinzentados para atributos inativos.
   * **Imagens em WebP (RGBA Transparente)**: Os arquivos oficiais são `stats_guilherme.webp`, `stats_gabriel.webp`, `stats_andre.webp` e `stats_juliana.webp` em `res://assets/ui/character_select/`, pesando apenas ~39 KB cada (em vez de PNGs de alta carga).
   * **Distribuição Equilibrada de Status (Exatamente 8 Pontos Totais)**:
     * **Guilherme**: Força 3, Velocidade 2, Técnica 3 (Total = 8)
     * **Gabriel**: Força 1, Velocidade 4, Técnica 3 (Total = 8)
     * **André**: Força 4, Velocidade 2, Técnica 2 (Total = 8)
     * **Juliana**: Força 1, Velocidade 3, Técnica 4 (Total = 8)

4. **Formatos Oficiais de Imagem e Compressão (Padrão WebP Transparente)**:
   * **Padrão Obrigatório de UI**: Imagens de interface, painéis de status e estados de tela devem ser exportadas prioritariamente em **WebP (RGBA com suporte a canal alfa)**, garantindo transparência nativa e corte drástico no consumo de memória RAM/VRAM e largura de banda web.
   * **Fundos, Iluminações e Telas de Abertura**: Devem ser salvos prioritariamente em **WebP** (qualidade 85% a 92%) mantendo arquivos leves sem perda perceptível de nitidez.
   * **Pixel Art HD, Spritesheets e UI de Alta Definição**: Devem utilizar **WebP Lossless** ou WebP Q95 RGBA, preservando integridade pixel-perfect de contornos e transparências.
   * **Proibido**: Deixar imagens estáticas pesadas em PNG (1 MB+) para elementos de UI quando o formato WebP atinge fidelidade idêntica com menos de 10% do tamanho.

5. **Segurança de Input e Navegação de Cenas**:
   * Sempre consumir eventos de entrada (`_safe_handle_input()` ou `accept_event()`) **antes** de invocar `get_tree().change_scene_to_file()`.
   * Verificar condicionalmente `if get_viewport() != null:` para prevenir erros de ponteiro nulo (`Cannot call method 'set_input_as_handled' on a null value`).

6. **Performance de Distribuição Web (Vercel / HTML5)**:
   * Manter `vercel.json` configurado com `Cross-Origin-Opener-Policy: same-origin` e `Cross-Origin-Embedder-Policy: require-corp` para permitir aceleração WebAssembly e threads seguras.
   * Configurar cache HTTP imutável/persistente (`stale-while-revalidate`) para os binários estáticos (`.wasm`, `.pck`, imagens) para eliminar tempos de carregamento repetidos para o jogador no navegador e mobile.

7. **Tela de Apresentação e Carregamento da Fase 1 (LoadingScreen)**:
   * Após a confirmação da seleção de personagem, o jogo DEVE transicionar para a tela de apresentação (`res://scenes/ui/loading_screen.tscn`).
   * **Arte Oficial**: Utiliza a imagem oficial `res://assets/backgrounds/maps/carregar/carregando_fase1.webp` ("FASE 1 /// A LOCADORA: ONDE TUDO COMEÇOU").
   * **Comandos Arcade Visuais**: Exibe os ícones de comando estilizados:
     * `[ ␣ ESPAÇO ]`: Continuar / Iniciar Fase 1 (atalho `KEY_SPACE`, `KEY_ENTER`, `ui_accept` ou botão `BtnContinue`).
     * `[ ESC ]`: Voltar para a Seleção de Personagens (`res://scenes/ui/character_select.tscn`).
   * **Preservação de Herói e Dados da Sessão**: O personagem selecionado em `GameSession.selected_character_id` é o personagem carregado e instanciado na fase, com seus atributos de combate e velocidade aplicados pelo `PlayerController`.
   * **Destino Oficial da Fase 1**: O avanço a partir da tela de carregamento transiciona estritamente para `res://scenes/levels/map_1.tscn` (cujo fundo é `res://assets/backgrounds/maps/fase1/Fase1_1.webp`).


