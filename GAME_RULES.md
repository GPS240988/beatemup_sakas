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
   * **Resolução Nativa dos Sprites e Escala Padrão dos Atores**:
     * **Heróis Jogáveis e Inimigos Comuns (Capangas)**: Possuem resolução nativa rigorosamente de **220×300px**. No Godot, o `AnimatedSprite2D` utiliza escala `scale = Vector2(0.80, 0.80)` para atingir ~240px de altura final, garantindo proporção anatômica fidedigna com balcões, estantes e pé-direito dos cenários sem distorção.
     * **Chefes de Fase (Bosses)**: **SOMENTE os chefes terão por padrão a resolução ampliada de 250×330px** (maior que o personagem comum de 220×300px), conferindo imponência hierárquica e destaque visual nos encontros de clímax (como o Chefe Alessandro na Fase 1 - Seção 4). Devem manter a ancoragem espacial estrita na base dos pés em `(0, 0)` e eixo do torso perfeitamente centralizado em `X = 125px` no canvas para garantir fluidez na movimentação e evitar desvios laterais ou marcha manco.
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
   * **Ciclo do Golpe e Calibração de Timers da IA**:
     * **Capangas Comuns**: Telegraph visual `0.25s` (flash amarelado sem causar dano) -> Janela de Impacto Ativa `0.16s` (`attack_started` / hitbox ativa) -> Recuo de Recuperação (`recoil_distance = 50px`, `recovery_duration = 0.40s`) -> Cooldown de re-ataque `attack_cooldown = 0.80s`. Ao sofrer dano: atordoamento `hurt_duration = 0.22s` seguido de `post_hurt_cooldown = 0.40s` impedindo contra-ataques instantâneos.
     * **Chefes (Boss Alessandro)**: Telegraph ágil `0.20s` -> Janela de Impacto Ativa `0.18s` -> Recuo firme (`recoil_distance = 35px`, `recovery_duration = 0.35s`) -> Cooldown `attack_cooldown = 0.65s`. Ao sofrer dano: `hurt_duration = 0.18s` e `post_hurt_cooldown = 0.30s`.
     * **Timeout de Retenção de Token e Perseguição (Prevenção de Starvation)**: `token_timeout_seconds = 4.0s` no `CombatDirector` revoga tokens retidos ociosamente sem ataque ativo. Inimigos possuem `chase_timeout_seconds = 3.5s` (Capangas) e `4.0s` (Chefe); ao expirar a perseguição sem alcançar o golpe, o inimigo libera o token voluntariamente e retorna ao flanqueamento, garantindo rotatividade da iniciativa ofensiva.
   * **Sinais do Diretor**: `encounter_started`, `encounter_cleared`, `token_granted`, `token_released`, `active_attack_authorized`.
   * **Ondas e Conclusão de Encontro**: O encontro só é considerado concluído (`encounter_cleared`) quando a contagem de inimigos vivos for zero **E** não houver nenhuma onda ou spawn de reforço pendente. Jamais abrir `ExitArea` nem acionar o indicador `SIGA →` com reforços em trânsito.

6. **Arquitetura de Navegação 2.5D (NavigationRegion2D & IA Híbrida de Inimigos)**:
   * **Malha de Navegação Obrigatória por Nível**: Todo mapa de combate DEVE possuir um nó `NavigationRegion2D` contendo um `NavigationPolygon` (`.tres`) desenhado especificamente para o chão caminhável daquele cenário, contornando todas as mobílias e obstáculos estáticos.
   * **Geometria de Navmesh Convexa**: O recurso `NavigationPolygon` deve ser construído através de partições de polígonos convexos adjacentes compartilhando vértices limítrofes, evitando o método depreciado `make_polygons_from_outlines()`.
   * **Nó NavigationAgent2D em Todo Inimigo**:
     * Ancorado estritamente na base dos pés `(0, 0)`.
     * `navigation_layers = 1`.
     * `avoidance_enabled = true` com raio proporcional aos pés (`radius = 12.0`, `neighbor_distance = 150.0`).
     * Conectado ao callback `velocity_computed` aplicando `safe_velocity` em `move_and_slide()` para evitar congestionamento em corredores estreitos.
   * **Navegação Híbrida 2.5D (Arcade Direto vs. Pathfinding)**:
     * Antes de avançar em linha reta nos estados `ALIGNING_DEPTH` e `APPROACHING`, o inimigo realiza um _raycast_ no espaço 2D (`PhysicsRayQueryParameters2D.create(start, end, 2, [get_rid()])`) contra a camada de mobílias (Layer 2).
     * **Caminho Desimpedido**: Move-se diretamente no eixo Y ou X, mantendo a resposta clássica, ágil e imediata de beat 'em up arcade.
     * **Caminho Obstruído (Estantes, Gôndolas, Balcões)**: Atribui a coordenada do alvo ao `agent.target_position` e navega contornando os móveis via `_follow_agent_path()`.

7. **Convenção de Camadas Físicas de Colisão (Collision Layers & Masks Sem Ambiguidade)**:
   * Em Godot, `collision_layer` e `collision_mask` são inteiros atuando como **bitmasks**. A numeração nominal de camada corresponde ao bit de deslocamento (`bit = camada - 1`).
   * **Tabela de Mapeamento Alvo**:
     | Camada Lógica | Uso de Jogo | Valor Típico do Bitmask |
     |:---:|---|:---:|
     | **1** | Corpos físicos de atores (`CharacterBody2D`) | `1` (`1 << 0`) |
     | **2** | Mundo sólido / mobílias / limites perimetrais | `2` (`1 << 1`) |
     | **3** | Hurtboxes receptoras de dano | `4` (`1 << 2`) |
     | **4** | Hitboxes ofensivas de ataque | `8` (`1 << 3`) |
     | **5** | Gatilhos de fase e zonas de saída (`ExitArea`) | `16` (`1 << 4`) |
   * **Fonte de Verdade do Hit Registration e Teste de Obstrução**:
     * Cada execução de ataque pode atingir cada alvo elegível no máximo uma vez por golpe (`hit_targets`).
     * O componente `MeleeAttack` valida: alvo vivo, equipe/grupo oposto, atacante diferente do alvo, direção para a frente, alcance horizontal X e tolerância de profundidade Y.
     * **Validação de Linha de Visão (Sem Ataque Através de Paredes/Móveis)**: Golpes físicos NÃO podem atravessar paredes ou mobílias sólidas. Antes de causar dano, o ataque executa um raycast no espaço 2D contra a Layer 2 (Mundo/Mobília); caso haja obstáculo sólido entre o atacante e o alvo, o golpe é bloqueado.

8. **Estrutura Padrão de Nós de Cena de Nível (MapX.tscn)**:
   * Toda cena de fase deve respeitar rigorosamente a seguinte árvore hierárquica:
     ```
     MapX (Node2D, script: base_level.gd)
     ├── Camera2D (com limites camera_min_x e camera_max_x configurados)
     ├── Background (Sprite2D, z_index = -10, centered = false)
     ├── NavigationRegion2D (com recurso map_X_navpoly.tres)
     ├── WorldBoundaries (StaticBody2D, collision_layer = 2, collision_mask = 1)
     │   ├── TopWall, BottomWall, LeftWall, RightWall (limites da tela)
     │   └── [Colisores de Mobílias e Obstáculos com CollisionShape2D]
     ├── World (Node2D, y_sort_enabled = true)
     │   └── Entities (Node2D, y_sort_enabled = true)
     │       ├── Player (instância de player.tscn, posicionado no ponto inicial)
     │       └── Inimigos (instâncias de basic_enemy.tscn e suas variantes)
     ├── CombatDirector (Node, script: combat_director.gd, no grupo "combat_director")
     ├── ExitArea (Area2D, collision_layer = 0, collision_mask = 1, monitoring = false)
     │   └── CollisionShape2D (na extremidade direita ou porta de saída)
     ├── SigaIndicator (instância de siga_indicator.tscn, posicionado na saída)
     └── PrototypeHud (instância de prototype_hud.tscn)
     ```

9. **Estrutura Padrão de Nós de Inimigos**:
   * Todo ator inimigo deve conter os seguintes componentes desacoplados:
     ```
     Enemy (CharacterBody2D, y_sort_enabled = true, grupo "enemies")
     ├── CollisionShape2D (CapsuleShape2D na base dos pés, layer 1, mask 2)
     ├── NavigationAgent2D (posicionado em (0, 0), avoidance habilitado)
     ├── Visual (Node2D, Y < 0, contém AnimatedSprite2D e efeitos)
     ├── MeleeAttack (Node2D com HitboxArea Area2D: collision_layer = 8, collision_mask = 4)
     ├── Hurtbox (Area2D receptora de dano: collision_layer = 4, collision_mask = 0, monitoring = false)
     ├── HealthComponent (Node de gerenciamento de pontos de vida e morte)
     └── FloatingHealthBar (ProgressBar flutuante sobre a cabeça)
     ```

10. **Progressão Sequencial dos Quatro Mapas da Fase 1**:
    * A primeira fase possui exatamente quatro mapas (`1983×793px` em Pixel Art HD):
      * **Mapa 1**: `scenes/levels/map_1.tscn` (Fundo: `assets/backgrounds/maps/fase1/Fase1_1.webp`, Navmesh: `map_1_navpoly.tres`) -> Entrada/Interior da Locadora.
      * **Mapa 2**: `scenes/levels/map_2.tscn` (Fundo: `assets/backgrounds/maps/fase1/Fase1_2.webp`, Navmesh: `map_2_navpoly.tres`) -> Comércio e Bares.
      * **Mapa 3**: `scenes/levels/map_3.tscn` (Fundo: `assets/backgrounds/maps/fase1/Fase1_3.webp`, Navmesh: `map_3_navpoly.tres`) -> Travessa da Locadora.
      * **Mapa 4**: `scenes/levels/map_4.tscn` (Fundo: `assets/backgrounds/maps/fase1/Fase1_4.webp`, Navmesh: `map_4_navpoly.tres`) -> O Beco Final (Clímax da Fase 1).
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
* ❌ **Usar vídeo OGV/GIF na tela de abertura**: A tela de abertura utiliza exclusivamente a imagem estática `main.webp` via `TextureRect`. Proibido reintroduzir `VideoStreamPlayer`, `.ogv` ou `.gif` como abertura, pois a resolução e a decodificação Theora da Godot 4 degradam a qualidade do Pixel Art HD.
* ❌ **Chamadas de Viewport desprotegidas em troca de cena**: Jamais chamar `get_viewport().set_input_as_handled()` após `change_scene_to_file()` sem validar se o viewport ainda existe (`if get_viewport() != null:`).
* ❌ **Inimigos sem NavigationAgent2D ou sem Avoidance RVO**: Proibido criar ou instanciar inimigos sem o nó `NavigationAgent2D` com `avoidance_enabled = true`, sob pena de congelamento contra mobílias ou travamento mútuo em corredores estreitos.
* ❌ **Cenas de fase sem NavigationRegion2D**: Proibido estruturar novas fases sem `NavigationRegion2D` mapeando o piso caminhável e sem colisores de mobília em `WorldBoundaries` na camada 2.
* ❌ **Violação das Camadas Físicas de Colisão (Layers 1 a 5)**: Proibido misturar camadas de física ou colocar hitboxes/hurtboxes nas mesmas camadas dos limites do cenário ou dos corpos físicos dos atores.

---

## 📦 6. REGRAS DE OTIMIZAÇÃO DE ASSETS, ESCALABILIDADE E PADRÕES VISUAIS OFICIAIS

1. **Tela de Abertura (Imagem Estática main.webp)**:
   * A tela de abertura (`title_screen.tscn`) utiliza exclusivamente a imagem estática `res://assets/backgrounds/main.webp` exibida em um `TextureRect` dentro de um `AspectRatioContainer`.
   * Formato WebP garante resolução nativa da arte Pixel Art HD sem degradação de codec de vídeo, com peso reduzido (~559 KB) e carregamento instantâneo.
   * **Proibido usar VideoStreamPlayer, `.ogv` ou `.gif`**: O decodificador `libtheora` da Godot Engine 4 introduz artefatos de compressão (macroblocos, chuvisco) em pixel art com dithering e paletas reduzidas, tornando o vídeo inferior à imagem estática em qualidade visual.

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


