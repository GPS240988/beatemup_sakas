# 📜 GAME_RULES.md — DIRETRIZES MESTRAS DO PROJETO SAKAS (BEAT 'EM UP 2.5D)

Act as a senior video game art director, professional character designer, and expert pixel artist specializing in high-quality 2D and 2.5D beat 'em up games."*
Atue como diretor técnico de arte, devops senior, desenvolvedor, frontend especialista  e engenheiro sênior Godot 4.x.
   * Responsável por zelar pela identidade visual impecável, anatomia, silhuetas expressivas, fluidez de quadros de animação, paletas de cores refinadas e estética nostálgica de alta qualidade (Pixel Art HD).

Atue como engenheiro sênior especialista em DevOps, sênior Backend, sênior FrontEnd e arquitetura de motores de jogos (Godot Engine 4.x)."*
   * Responsável por estabilidade, pipelines de automação, testes automatizados headless, integridade de código GDScript fortemente tipado, segurança física/matemática nas colisões 2.5D, performance a 60 FPS e suporte multiplataforma contínuo (PC e Mobile)

> **DIRETIVA SUPREMA**: Este documento é a fonte oficial, soberana e canônica da arquitetura, convenções, contratos e regras invioláveis do projeto **Beat 'em Up - Sakas** (Godot Engine 4.x). Todo assistente de IA, desenvolvedor e pipeline de CI/CD DEVE validar qualquer alteração contra este documento.
>
> **REGRA DE REGISTRO**: Nenhuma funcionalidade pode ser documentada como existente sem implementação e validação real por testes. Toda seção deve declarar explicitamente:
> - `STATUS: IMPLEMENTED`
> - `STATUS: IMPLEMENTED WITH LIMITATION`
> - `STATUS: PLANNED`

---

## 1. ARCHITECTURE OVERVIEW
`STATUS: IMPLEMENTED`

### 1.1. Propósito e Gênero
Beat 'em up 2.5D arcade clássico inspirado nos títulos dos anos 90, ambientado em Vila Prudente, São Paulo. A década de 1990 é a identidade visual de origem dos protagonistas; a narrativa estabelece que passado e presente podem ocupar os mesmos espaços após o despertar da máquina arcade. Essa coexistência temporal deve ser representada sem apagar a geografia reconhecível do bairro nem transformar a ambientação em cyberpunk genérico. O jogo mantém estética Pixel Art HD, profundidade no eixo Y e física determinística em Godot Engine 4.x (`4.7.2.stable`).

### 1.2. Personas Integradas de Desenvolvimento
1. **Direção de Arte e Design de Personagens**:
   - Preservar rigorosamente a identidade visual retro urbana, paletas ricas, dithering controlado, iluminação de neon pontual e silhuetas expressivas.
   - **Contrato Visual Canônico de Sprites de Atores**:
     - Sprites nativos de heróis e capangas em canvas fixo de **220×300px**, fundo transparente (canal alfa RGBA), renderizados em escala de importação `Vector2(0.80, 0.80)` atingindo ~240px de altura útil final; chefes em **250×330px** com pés estritamente em `(0, 0)`.
     - Linha de base vertical consistente com pés de apoio alinhados ao solo em $Y = 0$ (base do canvas em $Y = 300$, com tolerância máxima de até 20px para passadas/saltos).
     - Poses de chão deitadas (`death`, `fall_03`) admitem largura horizontal estendida de até 260px tangenciando a borda inferior.
     - Acabamento rasterizado nítido Pixel Art HD sem interpolações borradas, visualmente homogêneo e compatível com os mapas urbanos 1 a 4.
2. **Engenharia de Software e DevOps Sênior**:
   - GDScript fortemente tipado, desacoplamento por composição e componentes modulares.
   - Garantia de 60 FPS contínuos em Desktop e Mobile, ausência de vazamento de memória e suíte automatizada de testes headless (`godot_console.exe --headless -s tests/...`).

### 1.2.1. Contrato de Direção de Arte — Vila Prudente Temporal
`STATUS: PLANNED`

- **Documento visual de referência:** `Direcao_de_Arte.md`.
- **Hierarquia narrativa:** a Vila Prudente de meados dos anos 1990 é a base visual; elementos contemporâneos são interferências temporais pontuais, introduzidas conforme o roteiro e a geografia de cada cenário.
- **Coexistência de épocas:** passado e presente podem dividir o mesmo espaço físico. Manter pontos de referência reconhecíveis e usar justaposição, sobreposição parcial e glitches localizados, sem transformar toda a cidade em cenário futurista ou cyberpunk.
- **Linguagem unificada:** todos os elementos, antigos ou atuais, devem compartilhar a estética artesanal Neo-16-bit/Pixel Art HD, com clusters deliberados, contornos coerentes, paletas controladas e filtro `nearest`.
- **Controle de composição:** cenário, NPCs, letreiros e efeitos temporais não podem competir com os atores, itens ou faixa caminhável de combate.
- **Identidade dos atores:** referências, anatomia, roupas, proporções e canvas dos protagonistas/inimigos permanecem subordinados ao contrato de sprites deste documento. Ilustrações conceituais não autorizam substituir os designs oficiais.
- **Separação de responsabilidades:** `Direcao_de_Arte.md` define conceito e critérios visuais; este `GAME_RULES.md` continua soberano para dimensões, origem física, Y-Sort, colisões, estrutura de cena, importação, performance e testes.
- **Status:** a premissa temporal já está presente na abertura narrativa; a aplicação visual em novos ou revisados assets de gameplay deve ser validada no Godot antes de ser registrada como `IMPLEMENTED`.

### 1.3. Pipeline Arquitetural do Mundo
```text
MAPA
 ↓
STATIC WORLD (Limites Perimetrais e Geometria Permanente)
 ↓
DYNAMIC PROPS (Mobílias Sólidas e Objetos Destrutíveis)
 ↓
ACTORS (Player, Enemies e NPCs Móveis)
 ↓
COMBAT / NPC / EVENTS (CombatDirector, DialogueDirector, LevelEventDirector)
 ↓
PROGRESSION (ExitArea, SigaIndicator, LoadingScreen, Troca de Níveis)
```

### 1.4. Fluxo Canônico de Interface e Contrato de Comandos
`STATUS: IMPLEMENTED`

1. **Sequência Canônica de Transição de Telas**:
   ```text
   TitleScreen (title_screen.tscn)
     ↓ [Toque / Espaço / Enter]
   MainMenu (main_menu.tscn) — Botão 'Selecionar Personagens' DESABILITADO
     ↓ [Novo Jogo / Iniciar]
   CharacterSelect (character_select.tscn)
     ↓ [Confirmar Herói Guilherme]
   DifficultySelect (difficulty_select.tscn) — com assets/backgrounds/dificuldade.webp
     ↓ [Confirmar Normal ou Difícil]
   MapMenu (map_menu.tscn) — com assets/backgrounds/Mapa.webp (também acessível pelo Menu Principal)
     ↓ [Qualquer Tecla / Clique / Toque para Avançar]
   LoadingScreen / Instruções (loading_screen.tscn) — com assets/backgrounds/Instruções_1.webp
     ↓ [Qualquer Tecla / Clique para Continuar]
   Abertura Narrativa Cinemática (NarrativeDirector — Saka's: A Última Ficha)
     ↓ [Avanço Automático / [Espaço] / [ESC] Pular]
   Fase 1 (scenes/levels/map_1.tscn)
   ```
   *Nota de Navegação Inversa e Abertura Narrativa*:
   - Ao iniciar um **NOVO JOGO**, a abertura narrativa é disparada logo após as instruções ao transicionar para a Fase 1.
   - Ao **CONTINUAR** partida salva (save slot), a flag `GameSession.has_played_intro = true` impede estritamente a reprodução automática do prólogo.
   - Na tela de instruções (`loading_screen.tscn`), [ESC] ou 'Voltar' retorna ao Mapa (`map_menu.tscn`).
   - Na tela de Mapa (`map_menu.tscn`), se acessada durante a campanha (após seleção de dificuldade), [ESC] retorna a `difficulty_select.tscn`. Se acessada diretamente pelo Menu Principal, retorna a `main_menu.tscn`.
   - Na tela de Mapa, qualquer toque/clique na tela ou confirmação arcade [Enter]/[Espaço] avança para `loading_screen.tscn` (Instruções_1).

   *Sequência Canônica de Transição Cinemática do Mapa e Desbloqueio da Fase 2*:
   ```text
   Fase 1-4: O Bar da Vila (map_4.tscn)
     ↓ [Conclusão da seção / ExitArea / Intercepção em BaseLevel._advance_to_next_map()]
   Transição Cinemática do Mapa — Etapa 1: Ponto 1 -> Bônus 1 (scenes/ui/map_transition.tscn mode=0)
     ├── Fade In suave do mapa em tela cheia (16:9, Mapa.webp, 0.8s)
     ├── Seta arcade parte do Ponto 1 (cobridor procedural oculta a seta impressa original)
     ├── Movimento fluido via Tween + Path2D pelo traçado vermelho até o Bônus 1 (1.8s)
     ├── Chegada ao Bônus 1 (574, 338): destaque visual (MapUnlockVFX), bobbing sobre a caixa de presente
     ├── Cadeado do Ponto 2 permanece fechado / bloqueado
     ├── Registro em GameSession (bonus_stage_unlocked = true)
     ├── Fade Out suave (0.6s)
     ↓
   Fase Bônus 1: A Garagem (scenes/levels/bonus_garage.tscn)
     ↓ [Destruição dos 2 veículos ou término do tempo de 40s / BaseLevel._advance_to_next_map()]
   Transição Cinemática do Mapa — Etapa 2: Bônus 1 -> Ponto 2 (scenes/ui/map_transition.tscn mode=1)
     ├── Fade In suave do mapa
     ├── Seta arcade parte do Bônus 1 pelo trajeto vermelho até o Ponto 2 (1.8s)
     ├── Chegada ao Ponto 2 (870, 265): remoção/cobertura do cadeado, feedback visual dourado (MapUnlockVFX) e áudio de desbloqueio
     ├── Registro em GameSession (stage_2_unlocked = true) com persistência em user://campaign_progression.json
     ├── Bobbing suave contínuo da seta sobre o Ponto 2
     ├── Fade Out suave (0.6s)
     ↓
   Créditos / Vitória (scenes/ui/credits.tscn)
   ```
   *Visualização Dinâmica no Menu de Mapa (`map_menu.tscn`)*:
   - Ao acessar "Mapa" no Menu Principal, o estado reflete fielmente o progresso salvo:
     - No início de um novo jogo: seta sobre o Ponto 1 e cadeado no Ponto 2 visível.
     - Se o Bônus 1 foi alcançado: seta sobre o Bônus 1 e cadeado no Ponto 2 visível.
     - Se a Fase 2 foi desbloqueada: seta sobre o Ponto 2 e cadeado removido.
2. **Contrato de Comandos Restritos de Jogabilidade**:
   - `W / A / S / D` e `Setas Direcionais`: Movimentação 2.5D do personagem nos eixos X e Y.
   - `J`: Golpe básico / Combo de pancadaria (Jab -> Cross -> Kick -> Finisher). O encadeamento é contínuo e consistente tanto parado quanto em movimento via cancelamento de recuperação e buffer de entrada.
   - `Espaço`: Voadora do personagem (`jump_kick` / `execute_aerial`).
   - `O`: Golpe Especial de área (`execute_special`).
   - `K` e `H`: Bloqueio defensivo / Guarda (`guard`).
   - `Esc`: Pausar a partida abrindo o Menu de Pausa Transparente (`scenes/ui/pause_menu.tscn`).
3. **Menu de Pausa In-Game e Salvamento Persistente**:
   - `pause_menu.tscn`: Renderizado em camada superior (`CanvasLayer` layer = 100) com fundo translúcido escuro (`Color(0.015, 0.02, 0.04, 0.78)`), preservando o cenário e os atores pausados ao fundo.
   - Opções interativas:
     - **Salvar**: Grava o progresso atual (fase, HP, Especial, vidas e dificuldade) no slot persistente (`user://save_slot_X.json`) via `GameSession.save_game_to_slot()`.
     - **Continuar**: Despausa o jogo (`get_tree().paused = false`) e fecha o menu.
     - **Configurações**: Abre subpainel de áudio in-game com ajuste de Volume Master (0% a 100%).
     - **Sair**: Despausa e retorna com segurança ao Menu Principal (`scenes/ui/main_menu.tscn`).
4. **Paletas de Inimigos e Luminosidade**:
   - Inimigos com a paleta vermelha (`PaletteVariant.RED`) utilizam `value_adjust = 0.32` e `saturation_adjust = 0.12` no shader, garantindo leitura visual clara e nítida sem escurecer nos mapas urbanos noturnos.
5. **Contrato e Arquitetura da HUD Arcade Oficial (referência 2.webp)**:
   - `PlayerHUD` (`scenes/ui/player_hud.tscn`): Canto superior esquerdo compacto (340×78px). Retrato com moldura azul arcade neon, nome do herói em fonte arcade nítida, contador de fichas/continues com ícone de moeda de ouro (`hud_coin_icon.png`), barra de vida segmentada amarela/dourada com animação fluida de damage buffer e barra de especial azul elétrico (com aura pulsante de 100%).
   - `CenterHUD` (`scenes/ui/center_hud.tscn`): Centro superior em placa azul-marinho com borda neon (140×56px). Exibe identificador de fase dinâmico ('FASE 1-1') e cronômetro digital arcade em contagem decrescente ('02:37').
   - `EnemyHUD` (`scenes/ui/enemy_hud.tscn`): Canto superior direito compacto espelhado (340×78px). Nome do alvo alinhado à direita, barra de vida vermelha segmentada com damage buffer e retrato do inimigo/boss com moldura azul arcade.
   - `Arcade Combo Counter`: Placa dinâmica recortada em azul escuro (`hud_combo_plate_arcade.png`) com contador de acertos em escala de impacto (punch scale tween).
   - `SigaIndicator` (`scenes/ui/siga_indicator.tscn`): Indicador de avanço arcade exibindo o banner `vamos.webp` com pulso de impacto no centro superior (offset_top = 90.0, desobstruindo o CenterHUD). A placa legada de saída ("Siga") fica permanentemente oculta.
   - `GameOverLayer`: Camada arcade (`CanvasLayer` layer = 90) com imagem de fim de jogo `game_over.webp`. Fade in cinematográfico de aproximadamente 5.0 segundos com bloqueio estrito de reinício (`_can_restart = false`). Comando `[R]` liberado apenas após o término do fade in, reiniciando o primeiro mapa da fase correspondente com quantidade de continues ZERADA (`current_continues = 0`) e sem labels de instrução redundantes (legenda nativa na imagem).
   - Suíte de validação: `tests/arcade_hud_migration_test.gd`, `tests/player_hud_test.gd` e `tests/game_over_flow_test.gd`.

### 1.5. Arquitetura Modular Multi-PCK, Fast Boot e Streaming sob Demanda
STATUS: IMPLEMENTED

1. **Princípio Arquitetural e Orçamento Rígido**:
   - Para permitir escalabilidade contínua de fases, músicas e cinemáticas sem ultrapassar as travas das CDNs (Vercel Hobby 100 MB por arquivo) e eliminar consumo de Git LFS no GitHub, o jogo adota a arquitetura modular **Multi-PCK com Streaming sob Demanda** no Godot Engine 4.7.2 Web (WebAssembly/Emscripten).
   - **Teto Orçamentário Mandatório**: Nenhum arquivo `.pck` individual pode ultrapassar **45.0 MB** (>55% de margem contra a trava de 100 MB).
   - Todos os pacotes pesados adicionais (`public/packs/*.pck`) e binários web são estritamente ignorados pelo `.gitignore`, consumindo **0 bytes de Git LFS**.
2. **Catálogo Canônico de Pacotes**:
   - `index.pck` (Core Base): Motor, scripts essenciais, UI principal, shaders, SFX e atores base (~58.7 MB).
   - `packs/pack_audio_bgm.pck`: Faixas de áudio BGM de alta fidelidade (~37.7 MB).
   - `packs/pack_story_cinematics.pck`: Cinemáticas e telas de diálogo ilustradas em Full HD (~36.2 MB).
   - `packs/pack_stage1.pck`: Mapas 1 a 4, Garagem Bônus e backgrounds do Estágio 1 (~23.0 MB).
3. **Fast Boot e Desacoplamento da Inicialização Web**:
   - No carregamento inicial do navegador (`public/index.html`), o motor carrega **estritamente** o núcleo base (`index.wasm` + `index.pck`), somando ~96 MB de transferência inicial (redução de ~38% em relação aos ~155 MB anteriores).
   - O jogador atinge a tela inicial e o Menu Principal em poucos segundos, sem download antecipado das fases subsequentes ou de toda a trilha sonora.
4. **Autoload PackManager (`scripts/core/pack_manager.gd`)**:
   - Inicializado antes dos demais sistemas no `project.godot`.
   - **Máquina de Estados de Ciclo de Vida do Pacote**:
     - `UNLOADED`: Pacote não carregado nem baixado.
     - `QUEUED`: Enfileirado para download.
     - `DOWNLOADING`: Download de chunks em andamento via rede.
     - `VERIFYING`: Dados recebidos, validação de integridade.
     - `MOUNTED`: Pacote montado com sucesso na árvore virtual `res://`.
     - `ERROR`: Falha de download ou montagem (permite repetição/retry).
   - **Sinais de Telemetria e Progresso**:
     - `pack_mounted(pack_id)`: Disparado ao concluir a montagem.
     - `pack_progress(pack_id, loaded, total, pct)`: Informa bytes transferidos, tamanho total e porcentagem em tempo real.
     - `pack_error(pack_id, reason)`: Disparado em caso de erro na transferência ou montagem.
     - `all_critical_packs_ready`: Sinaliza a prontidão de todos os pacotes marcados como críticos.
   - **Ponte de Streaming Web (JavaScript <-> Emscripten Virtual FS)**:
     - No ambiente Web, `ensure_pack_loaded_async(pack_id)` aciona `window.sakasStreamPack(packId, fileName)`.
     - A rotina em JS utiliza `fetch()` com `ReadableStream` para descarregar o `.pck` em chunks progressivos.
     - Ao concluir o download, o buffer é gravado diretamente no sistema de arquivos virtual do Emscripten (MEMFS) via `window.godotEngine.copyToFS('packs/' + fileName, buffer)`.
     - O GDScript então monta o arquivo na árvore do motor via `ProjectSettings.load_resource_pack("packs/" + fileName, true)`.
     - Transparência total: o código existente continua consumindo caminhos canônicos (`res://...`) sem qualquer alteração.
   - **Execução Desktop e Editor**:
     - No editor Godot ou builds desktop, `ensure_pack_loaded_async()` resolve imediatamente sem rede, verificando a presença local do arquivo ou montando diretamente via filesystem.
5. **Gatilhos de Carregamento Contextual na UI**:
   - `MainMenu` (`scripts/ui/main_menu.gd`): Ao acionar a opção "JOGAR", dispara o streaming em segundo plano de `story_cinematics`.
   - `LoadingScreen` (`scripts/ui/loading_screen.gd`): Assegura `stage1`, `audio_bgm` e `story_cinematics` antes de permitir o avanço para a fase.
   - `MapMenu` (`scripts/ui/map_menu.gd`): Ao clicar em "JOGAR FASE", verifica se `stage1` e `audio_bgm` estão montados. Caso não estejam, bloqueia a transição, exibe o progresso em MB/porcentagem no `MapStatusLabel` e permite nova tentativa se houver falha de rede.
6. **Pipeline DevOps e Automação de Build**:
   - `tools/pack_builder.gd`: Construtor headless automatizado via `PCKPacker` C++ nativo. Empacota fontes brutos, arquivos `.import` e seus derivados importados (`.ctex`, `.mp3str`), gera `public/packs/manifest.json` e falha preventivamente se qualquer pacote exceder 45 MB.
   - `scripts/pwa_post_export.js`: Automação Node.js executada pós-exportação que sincroniza o hash de versão do commit Git (`CACHE_VERSION`), injeta metadados PWA em `index.manifest.json` e atualiza os tamanhos em `fileSizes` no `index.html`.
   - `tools/deploy_web.py`: Script de orquestração que empacota os módulos, valida a integridade binária, carimba versão no Service Worker e dispara o deploy seguro para a Vercel.
7. **Suítes de Validação Automatizadas**:
   - `tests/test_pack_manager_lifecycle.gd`: Validação do ciclo de vida, sinais e métodos de `PackManager` (18/18 testes passando).
   - `tests/test_runtime_pck_mount.gd`: Validação de montagem em tempo de execução e acessibilidade de recursos `res://`.
   - `tests/test_arcade_map_menu.gd`: Validação do fluxo de seleção de fase, UI arcade e streaming do mapa (27/27 testes passando).

---

## 2. LEVEL SCENE CONTRACT
`STATUS: IMPLEMENTED`

Toda cena de nível (mapa jogável) deve estender `BaseLevel` (`scripts/levels/base_level.gd`) e seguir rigorosamente a hierarquia física e semântica de nós:

```text
MapX (Node2D, script: base_level.gd)
├── Camera2D (limites camera_min_x e camera_max_x, Y fixo em 360px, amortecimento suave)
├── Background (Node2D, z_index = -10)
│   ├── Far (Sprite2D / ColorRect — arte distante de horizonte)
│   ├── Mid (Node2D — camadas intermediárias de cenário)
│   └── BackProps (Node2D — detalhes estáticos do fundo)
├── NavigationRegion2D (contendo recurso map_X_navpoly.tres com malha convexa)
├── StaticWorld (Node2D)
│   └── WorldBoundaries (StaticBody2D, layer 2, mask 1)
│       ├── TopWall (CollisionShape2D — limite superior do chão caminhável)
│       ├── BottomWall (CollisionShape2D — limite inferior do chão caminhável)
│       ├── LeftWall (CollisionShape2D — limite perimetral esquerdo)
│       └── RightWall (CollisionShape2D — limite perimetral direito)
├── World (Node2D, y_sort_enabled = true)
│   ├── Props (Node2D, y_sort_enabled = true)
│   │   ├── StaticProps (Node2D, y_sort_enabled = true — estantes, balcões fixos)
│   │   └── Destructibles (Node2D, y_sort_enabled = true — caixas, barris, barricadas)
│   └── Actors (Node2D, y_sort_enabled = true)
│       ├── Player (instância de player.tscn, em World/Actors/Player)
│       ├── Enemies (Node2D, y_sort_enabled = true — capangas e chefes)
│       └── NPCs (Node2D, y_sort_enabled = true — civis e transeuntes)
├── Foreground (Node2D, z_index = 10 — elementos visuais de primeiro plano que cobrem atores)
├── SpawnPoints (Node2D — marcadores Marker2D gerenciados pelo SpawnDirector)
├── CombatDirector (Node, script: combat_director.gd, no grupo "combat_director")
├── ExitArea (Area2D, collision_layer = 0, collision_mask = 1, monitoring = false)
│   └── CollisionShape2D (gatilho de transição no final do mapa)
├── SigaIndicator (instância de siga_indicator.tscn, ativado ao vencer o encontro)
└── PrototypeHud (instância de prototype_hud.tscn, CanvasLayer layer = 1)
```

**Resolução Desacoplada no BaseLevel**:
- É terminantemente proibido o uso de caminhos rígidos como `$World/Entities/Player`.
- `BaseLevel` resolve referências dinamicamente através de grupos (`get_tree().get_first_node_in_group("player")`) e métodos utilitários (`get_player()`, `get_actors_container()`, `get_props_container()`).

---

## 3. SCENE NAMING CONVENTION
`STATUS: IMPLEMENTED`

- **Diretórios e Arquivos**: Nomes estritamente em `snake_case` minúsculo.
  - Cenas de fases: `scenes/levels/map_1.tscn`, `map_2.tscn`, `map_3.tscn`, `map_4.tscn`, `scenes/levels/bonus_garage.tscn`.
  - Cenas de atores: `scenes/actors/player/player.tscn`, `scenes/actors/enemies/basic_enemy.tscn`, `scenes/actors/enemies/boss_alessandro.tscn`, `scenes/actors/npc.tscn`.
  - Cenas de props: `scenes/props/destructible_prop.tscn`, `scenes/props/destructible_games_box.tscn`, `scenes/props/bonus_car_orange.tscn`, `scenes/props/bonus_car_blue.tscn`.
  - Cenas de UI: `scenes/ui/title_screen.tscn`, `main_menu.tscn`, `character_select.tscn`, `loading_screen.tscn`, `prototype_hud.tscn`, `map_transition.tscn`.
  - Recursos de navegação: `scenes/levels/map_1_navpoly.tres` a `map_4_navpoly.tres`, `scenes/levels/bonus_garage_navpoly.tres`.
  - Scripts: `scripts/<dominio>/<nome_componente>.gd`.
- **Classes GDScript**: Declaração explícita de `class_name` apenas para tipos centrais ou tipagem estática (ex: `class_name DamageInfo`, `class_name BaseLevel`, `class_name BaseNPC`).

---

## 4. STATIC WORLD CONTRACT
`STATUS: IMPLEMENTED`

- **Definição**: Geometria física permanente e imutável que delimita o espaço caminhável do mapa (paredes perimetrais e limites do nível).
- **Localização Canônica**: Estritamente em `StaticWorld/WorldBoundaries` como corpos `StaticBody2D`.
- **Camadas Físicas**: `collision_layer = 2` (Mundo Sólido), `collision_mask = 1` (Atores).
- **Regras de Não-Interferência**:
  - `StaticWorld` é semanticamente e fisicamente separado de `Props` e de `Actors`.
  - Paredes e limites perimetrais NUNCA devem pertencer aos grupos `"props"` ou `"destructibles"`.
  - As mobílias internas e balcões são instanciados sob `World/Props/StaticProps`, nunca sob `StaticWorld/WorldBoundaries`.

---

## 5. DYNAMIC PROPS CONTRACT
`STATUS: IMPLEMENTED`

- **Definição**: Elementos de cenário que possuem presença física no mundo, podem receber dano, sofrer transições de estado, soltar itens ou quebrar (caixas, barris, lixeiras, barricadas, portas, máquinas de arcade).
- **Regra de Modelagem**: Qualquer elemento que mude de estado ou receba impacto NÃO pode ser modelado apenas como um colisor solto. Deve ser uma cena modular herdando de `DestructibleProp` (`scripts/props/destructible_prop.gd`).
- **Hierarquia Canônica de Nós**:
  ```text
  DestructibleProp (StaticBody2D, Layer 2, Mask 1, y_sort_enabled = true, grupos: "props", "destructibles", "destructible_props", "damageable")
  ├── Visual (Node2D, Y < 0 — suporta nós Intact e Broken)
  ├── CollisionShape2D (Base de colisão sólida no solo, Layer 2)
  ├── Hurtbox (Area2D receptora de dano: Layer 3 [bitmask 4], Mask 0, monitorable = true)
  │   ├── CollisionShape2D_Center (região central)
  │   ├── CollisionShape2D_Front (região frontal, opcional para veículos/props volumosos)
  │   └── CollisionShape2D_Rear (região traseira, opcional para veículos/props volumosos)
  ├── HealthComponent (Node desacoplado para HP e sinais de dano)
  ├── Effects (Node2D contendo nós CPUParticles2D e AudioStreamPlayer2D)
  │   ├── ImpactParticles (CPUParticles2D para faíscas/lascas no ponto atingido)
  │   ├── BreakParticles (CPUParticles2D para explosão/estilhaços iniciais)
  │   ├── SmokeParticles (CPUParticles2D procedural com GradientTexture2D radial)
  │   ├── ImpactSound (AudioStreamPlayer2D com pitch aleatório 0.92..1.08)
  │   └── BreakSound (AudioStreamPlayer2D para explosão/quebra arcade)
  └── NavigationIntegration (NavigationObstacle2D para desvio dinâmico sem rebake)
  ```
- **Localização de Impacto Espacial (Veículos e Props Grandes)**:
  - Implementa `get_impact_point(hitbox_global_pos: Vector2, attacker_facing: float) -> Vector2`.
  - Calcula a coordenada de contato na superfície exterior da forma geométrica mais próxima atingida (frente, traseira, teto ou saia lateral).
  - `DestructibleProp._play_impact_effect(impact_pos)` reposiciona dinamicamente `ImpactParticles` e `ImpactSound` nas coordenadas locais exatas do golpe.
  - O sistema de combate (`CombatFeedback.spawn_hit_spark`) instancia a faísca animada em pixel art HD e faíscas direcionais no mesmo ponto exato.
- **Sequência Canônica de Destruição e Fumaça**:
  - Disparada no evento em que a vida do prop atinge 0.
  - O visual comuta para a última textura de avaria (`damage_stage_textures[last]`).
  - Colisão sólida (`CollisionShape2D`) e formas de detecção (`Hurtbox`) são desativadas imediatamente e em modo deferred, liberando trânsito de atores.
  - Áudio de quebra/explosão (`BreakSound`) e estouro inicial (`BreakParticles`) são executados exatamente uma vez.
  - A fumaça procedural ascendente (`SmokeParticles`) é ativada continuamente sobre a carcaça.
  - A carcaça permanece visível no cenário indefinidamente, recusando novos golpes e novos sons.
- **Isolamento de Entidades**: Atores (`Player`, `Enemies`, `NPCs`) NUNCA podem ser instanciados dentro de contêineres de `Props`.

---

## 6. ACTOR CONTRACT
`STATUS: IMPLEMENTED`

- **Definição**: Toda entidade viva, móvel e animada que habita o mundo do jogo.
- **Estrutura Base**: Herdam de `CharacterBody2D`, com `y_sort_enabled = true`.
- **Ancoragem Espacial Obrigatória (Pés em `0, 0`)**:
  - A origem local `(0, 0)` representa o ponto exato de contato dos pés com o chão.
  - A representação gráfica (`Visual`) projeta-se estritamente para cima (`Y < 0`).
  - **Alinhamento de Chão para Poses Deitadas**: Sprites deitados (`death`, `fall_03`, `getup`) devem ter os pixels de contato tangenciando a base do canvas sem vazios verticais inferiores, assegurando que o corpo descanse diretamente sobre a linha $Y = 0$ e a sombra projetada.
  - O colisor físico de pés (`CollisionShape2D`) abrange apenas a base de contato no solo.
- **Camadas Físicas**: `collision_layer = 1` (Atores) e `collision_mask = 2` (Mundo Sólido e Mobílias). Atores não colidem fisicamente entre si para evitar travamento mútuo em corredores estreitos.
- **Localização Canônica**: Devem residir obrigatoriamente dentro de `World/Actors/` (`Player`, `Enemies` ou `NPCs`).

---

## 7. PLAYER CONTRACT
`STATUS: IMPLEMENTED`

- **Identidade e Cena**: `scenes/actors/player/player.tscn` (script: `scripts/actors/player_controller.gd`).
- **Grupos Canônicos**: Pertence estritamente aos grupos `"player"`, `"actors"` e `"damageable"`. Jamais pertence ao grupo `"enemies"`.
- **Atributos de Heróis (Distribuição Oficial = 8 Pontos)**:
  - **Guilherme**: Força 3, Velocidade 2, Técnica 3 (Equilibrado).
  - **Gabriel**: Força 1, Velocidade 4, Técnica 3 (Ágil e veloz, recuperação rápida).
  - **André**: Força 4, Velocidade 2, Técnica 2 (Tanque de alto impacto e forte knockback).
  - **Juliana**: Força 1, Velocidade 3, Técnica 4 (Especialista técnica, janela ampla de combos e cancelamentos).
- **Controles de Combate Arcade com Botão Único Principal**:
  - **Botão de Ataque Principal** (`attack` / `attack_punch` / `ui_accept`):
    - Executa a sequência contextual de 4 golpes contínuos:
      `Passo 1 (Jab / Punch 1)` → `Passo 2 (Cruzado / Punch 2)` → `Passo 3 (Chute no Tronco / Kick)` → `Passo 4 (Finisher / Heavy)`.
    - O Finisher desfere impacto máximo e derruba o inimigo (`can_knockdown = true`). Utiliza animação `heavy` em 6 quadros (`heavy_01` a `heavy_06.png`) a 10.0 FPS, recovery calibrado em 0.58s e transição imediata para `idle` conectada via sinais `attack_ended` e `animation_finished`, impedindo travamento no último quadro.
    - Ciclo temporal formal de ataque no `MeleeAttack` (`Phase`): `STARTUP` (preparação visual sem hitbox ativa nem dano), `ACTIVE` (hitbox ativa com dano único estrito por alvo) e `RECOVERY` (hitbox desativada imediatamente). Sinais `attack_started` e `attack_ended` são emitidos estritamente uma única vez no início e na conclusão completa do ciclo.
    - Possui janela real de encadeamento (`combo_window`) escalonada pelo atributo Técnica e buffer de entrada (`_input_buffered`) durante startup/active que permite encadear golpes no início do recovery ou cancelando o recovery remanescente.
  - **Botão Exclusivo de Especial** (`attack_special` / `special`):
    - Dispara evento global de combate consumindo 100% da barra de Especial (sem subtrair vida do jogador, exigindo medidor completamente cheio).
    - Concede invulnerabilidade temporária durante a apresentação.
    - Exibe apresentação visual cinematográfica oficial de 2,50 segundos (`SpecialPresentation`, layer 120) orientada por dados (`HeroData`), cobrindo integralmente a viewport em qualquer proporção (`STRETCH_KEEP_ASPECT_COVERED`) com proporção preservada e sem poluição de texto na tela. A sequência possui 6 etapas rigorosamente sincronizadas (Abertura 0,35s, Construção de Energia 0,55s, Hold do Clímax 0,40s, Flash de Impacto 0,20s, Respiro 0,50s, Saída 0,50s), emitindo o sinal `impact_reached` estritamente aos 1,30s e `finished` aos 2,50s de forma idempotente.
    - Aplica dano global e queda obrigatória em todos os inimigos vivos do encontro exatamente aos 1,30s no sinal `impact_reached`, preservando NPCs civis.
  - **Botão de Salto** (`jump`):
    - Projeta o nó `Visual` no eixo Y (`Y < 0`). Ataque no ar dispara o golpe aéreo (`jump_atk`).
  - **Botão de Guarda** (`guard`):
    - Reduz 70% do dano recebido, anula knockback e cancela transições de queda.
  - **Métodos Públicos Legados Preservados**: `execute_punch()`, `execute_kick()`, `execute_heavy()`, `execute_aerial()`.
- **Reações Físicas do Jogador**:
  - `HURT`: Stagger com recuo físico e animação `hurt` ao receber golpes comuns.
  - `FALL`: Projeção ao solo e animação `fall` ao sofrer golpes pesados ou finalizadores.
  - `DOWNED`: Imobilização breve no chão com imunidade momentânea.
  - `GETUP`: Animação de levantamento `getup` e restauração de controle.
  - `DEAD`: Animação `death` ao atingir 0 de vida.

---

## 8. ENEMY CONTRACT
`STATUS: IMPLEMENTED`

- **Identidade e Cenas**: `basic_enemy.tscn` (Capangas comuns) e `boss_alessandro.tscn` (Chefe de Fase).
- **Grupos Canônicos**: Pertencem estritamente aos grupos `"enemies"`, `"actors"` e `"damageable"`.
- **Arquétipos Táticos de Inimigos (`Archetype`)**:
  - `GRUNT`: Capanga comum, aproximação padrão e resistência equilibrada.
  - `AGGRESSOR`: Avanço veloz (speed 175px/s), telegraph reduzido (0.18s) e alta pressão.
  - `TANK`: HP elevado (140 HP), resistência a knockback comum e imunidade a quedas normais.
  - `FLANKER`: Movimentação em raios abertos, ataques em pistas laterais e busca de brechas.
- **Máquina de Estados de IA (`EnemyAI`)**:
  - `IDLE` / `WAITING`: Aguarda oportunidade tática observando o jogador.
  - `FLANKING`: Move-se para o slot lateral atribuído pelo `CombatDirector`.
  - `ALIGNING_DEPTH`: Estágio 1 do combate 2.5D — alinha a profundidade Y com tolerância de 15 px.
  - `APPROACHING`: Estágio 2 do combate 2.5D — avança horizontalmente no eixo X até 70 px.
  - `TELEGRAPH`: Preparação visual do golpe (flash amarelado) com duração de 0.25s (0.20s no Chefe).
  - `ATTACKING`: Janela ativa de dano com hitbox monitorando a hurtbox do jogador.
  - `RECOVERY`: Recuo pós-golpe (50 px em 0.40s nos capangas; 35 px em 0.35s no chefe).
  - `HURT`: Atordoamento ao receber dano (0.22s nos capangas; 0.18s no chefe) seguido de cooldown protetivo (`post_hurt_cooldown = 0.40s`).
  - `FALL`: Projeção ao solo impulsionada por knockback ao receber finalizadores ou golpes especiais.
  - `DOWNED`: Caído no chão temporariamente imobilizado (0.35s).
  - `GETUP`: Retorno gradual ao solo e levantamento (0.28s) antes de voltar para `FLANKING`.
  - `DEAD`: Derrota com desligamento imediato de colisores físicos e Hurtbox, aviso ao `CombatDirector`, emissão de poeira (`CombatFeedback.spawn_dust`) e sequência canônica arcade de piscar (`modulate:a`) por 1.2s antes de sumir com `queue_free()`, preparando o fluxo limpo de respawn.
- **Resistência de Chefes**:
  - `BossAlessandro` possui poise arcade: não sofre queda em golpes normais, apenas em Golpes Especiais globais.
- **Prevenção de Starvation e Retenção**: `chase_timeout_seconds` (3.5s em capangas; 4.0s no chefe) força o inimigo a liberar o token caso não consiga desferir o golpe a tempo.

---

## 9. NPC CONTRACT
`STATUS: IMPLEMENTED`

- **Identidade e Cena**: `scenes/actors/npc.tscn` (script: `scripts/actors/npc.gd`).
- **Grupos Canônicos**: Pertence a `"actors"`, `"npcs"` e `"damageable"`. Jamais pertence a `"enemies"`.
- **Isolamento Absoluto de Combate**:
  - O `CombatDirector` REJEITA categoricamente qualquer registro de nós no grupo `"npcs"`.
  - A presença ou sobrevivência de civis na cena não interfere na contabilidade de vitória de encontros.
  - Não possuem `MeleeAttack` ativo nem executam ataques contra o jogador ou inimigos.
  - São imunes aos danos globais do Golpe Especial do jogador.
- **Máquina de Estados de NPCs (`NPCState`)**:
  - `IDLE`: Parado observando o ambiente.
  - `WANDER`: Perambulação suave ao redor do ponto de origem.
  - `MOVE_TO`: Deslocamento até coordenada específica via `move_to(target_pos)`.
  - `WAIT`: Pausa temporizada via `wait(duration)`.
  - `FLEE`: Fuga em alta velocidade para longe de ameaças (`flee_from(threat_pos)`).
  - `EVENT`: Comportamento delegado a scripts narrativos externos.
  - `DISABLED`: Física e processamento desativados sem remover o nó da árvore.
- **Throttling de Pathfinding**: Navegação via `NavigationAgent2D` com intervalo mínimo obrigatório de `PATHFIND_MIN_INTERVAL = 0.25s`, prevenindo sobrecarga de CPU por spam de rotas.
- **NPC Especial Sérgio (`SergioNPC` — Fase 1-1 / `map_1.tscn`)**:
  - **Identidade e Cena**: `scenes/actors/sergio_npc.tscn` (script: `scripts/actors/sergio_npc.gd`).
  - **Sprite e Animação de Caminhada**: `AnimatedSprite2D` em `Visual` animado em 4 quadros (`assets/sprites/characters/sergio/walk_sergio.webp` via `scenes/actors/sergio_walk_frames.tres`, `scale = Vector2(0.28, 0.28)` com pés estritamente em `(0, 0)`, sombra e colisor na base).
  - **Patrulha Acelerada**: Percorre ativamente todos os setores da malha navegável (`NavigationRegion2D` / `map_1_navpoly.tres`) com `run_speed = 230.0 px/s` e circuito contínuo de 9 waypoints.
  - **Balões de Conversa Dinâmicos (`assets/ui/hud/molduras_conversa/`)**: Falas dentro de balões adaptados proporcionalmente ao comprimento da frase (`balao1.png` a `balao8.png`), com fundo sólido, contorno preto e tipografia arcade (`arcade_bold.ttf`).
  - **Ciclo de Frases Alternadas**: Alterna ciclicamente enquanto corre pelo mapa:
    1. *"Socorro, minha locadora foi invadida. Me ajudem"* (`balao3.png`)
    2. *"Minha mulher está grávida, nos ajude"* (`balao7.png`)
    3. *"Minha veia está entupida, acho que vou infartar"* (`balao3.png`)
    - Reação a dano: *"SOCORRO!! NÃO ME BATA, MINHA LOCADORA FOI INVASÃO!"* (`balao4.png`).
  - **Orientação de Leitura**: Orientação visual travada (`speech_bubble.scale.x = 1.0`), garantindo zero espelhamento do texto ou do balão quando o ator vira para a esquerda.

---

## 10. COMBAT CONTRACT
`STATUS: IMPLEMENTED`

- **Orquestrador Central**: `CombatDirector` (`scripts/combat/combat_director.gd`), nó único no grupo `"combat_director"`.
- **Regulamento de Tokens Ofensivos 2.5D**:
  - `max_attack_tokens = 2`: No máximo 2 inimigos podem perseguir o jogador simultaneamente com intenção ofensiva.
  - `max_simultaneous_active_enemy_attacks = 1`: No máximo 1 janela ativa de impacto pode atingir o jogador no mesmo instante, eliminando dano sobreposto injusto.
  - `token_timeout_seconds = 4.0s`: Revoga tokens detidos ociosamente sem ataque desferido.
- **Perfis de Dificuldade por Mapa (`EncounterDifficultyProfile`)**:
  - **Mapa 1 (Ensino)**: 1 token ofensivo, ritmo compassado, telegraph integral, composição 100% Grunts.
  - **Mapa 2 (Pressão)**: 2 tokens ofensivos, introdução de Flankers e pistas laterais Y.
  - **Mapa 3 (Desafio)**: 2 tokens ofensivos, telegraph mais rápido, introdução de Aggressors e reforços dinâmicos.
  - **Mapa 4 (Maestria)**: 2 tokens ofensivos, composição complexa (Tanks + Aggressors + Flankers) e clímax com o Chefe Alessandro.
- **Sistema Reutilizável de Feedback Audiovisual (`CombatFeedback`)**:
  - **Hitstop Local Consistente**:
    - Pausa estritamente local de física e visual aplicada aos atores envolvidos no impacto (`attacker` e `victim`) via `CombatFeedback.apply_hitstop(attacker, victim, duration)`.
    - **Proibição Absoluta de `get_tree().paused`**: É vedado congelar a árvore global de nós (`SceneTree`), assegurando que timers globais, HUD, fluxo de interface e entrada de comandos continuem 100% responsivos.
    - **Congelamento Visual Preciso**: O `AnimatedSprite2D` dos combatentes afetados tem sua velocidade travada em `speed_scale = 0.0` no frame exato de contato, retomando seu valor original pré-hitstop (geralmente `1.0`) assim que o timer local do ator zera.
    - **Preservação da Janela Ativa (`MeleeAttack`)**: Durante o hitstop do atacante (`_hitstop_timer > 0.0`), a contagem regressiva da fase (`_phase_timer`) é congelada, impedindo o consumo prematuro da janela de dano enquanto o sprite está parado.
    - **Resiliência a Golpes Sobrepostos**: Acertos rápidos sucessivos estendem o timer (`max(_hitstop_timer, new_duration)`) sem resetar prematuramente a animação nem deixar atores permanentemente travados.
    - **Tratamento de Morte e Cancelamento**: Caso o ator seja derrotado (`_on_died()`) ou o ataque seja cancelado (`cancel_attack()`), o timer de hitstop é zerado imediatamente e o `speed_scale` é restaurado para evitar congelamentos pós-morte.
  - **Screen Shake Concorrente Amortecido**:
    - Tremor de câmera acionado estritamente em golpes pesados (`heavy`), finalizadores (`finisher`), especiais (`special`) e respawn arcade.
    - **Imunidade a Conflito de Tweens**: O offset de repouso original é cacheado de forma canônica (`_base_camera_offset`). Tremores concorrentes interrompem o tween anterior sem acumular desvios nem deixar offset residual na câmera.
  - **Sequência Audiovisual Coerente**:
    - Após um acerto confirmado, a leitura visual obedece estritamente ao encadeamento: `pose de contato → hitstop local → faísca/partículas no ponto de impacto → reação do alvo/knockback → recuperação`.
    - **Isolamento de Whiff**: Golpes desferidos sem atingir alvos válidos jamais emitem faíscas nem acionam tremor de câmera.
    - **Knockback Direcional Consistente**: A direção da força de recuo/queda deriva primariamente do vetor de impacto do golpe (`DamageInfo.direction`) e da posição do atacante, garantindo que o alvo seja projetado no sentido do golpe desferido.
  - **Regra Definitiva de Posicionamento e Região de Impacto**:
    - O efeito visual de impacto (faíscas `AnimatedHitSpark` e partículas `CPUParticles2D`) DEVE corresponder à região anatômica efetivamente atingida pelo golpe. O tronco não é a posição canônica universal; é apenas uma das regiões possíveis.
    - **Diferença entre Validação de Dano e Localização Visual**:
      - `Hurtbox` (Area2D na Layer 3, Mask 0): autoridade física receptora de dano. Valida o recebimento do ataque junto ao `HealthComponent`.
      - `ImpactZones`: componente e marcadores espaciais que identificam a região anatômica (`head`, `upper_torso`, `lower_torso`, `legs`) e fornecem a referência espacial exata para os efeitos visuais, sem duplicar a aplicação de dano.
    - **Hierarquia de Prioridade para a Posição do Impacto**:
      1. Ponto de contato real (centro da interseção geométrica entre a hitbox do ataque e a região atingida).
      2. Marcador espacial dedicado da região (`Head`, `UpperTorso`, `LowerTorso`, `Legs`).
      3. Centro espacial calibrado da região anatômica identificada.
      4. Centro da `Hurtbox` geral (apenas fallback).
      5. Posição proporcional baseada nas dimensões reais do personagem (último recurso). Deslocamentos fixos como `Vector2(0, -85)` possuem caráter estrito de fallback e foram removidos como método universal.
    - **Tratamento Específico do Jogador de Magic (`BasicEnemy`)**: Dimensões, proporções e escala nativa de execução (`scale = Vector2(0.42, 0.42)`, `position = Vector2(0, -91)`, altura total ~165px) permanecem estritamente preservadas. As 4 zonas são calibradas para seu sprite real: `head` ([-170, -125]), `upper_torso` ([-125, -85]), `lower_torso` ([-85, -45]), `legs` ([-45, 0]).
    - **Padronização dos Demais Inimigos (220×300)**: Heróis e capangas em canvas 220×300 utilizam escala 0.80 e altura ~200-210px: `head` ([-210, -155]), `upper_torso` ([-155, -105]), `lower_torso` ([-105, -55]), `legs` ([-55, 0]). Chefe Alessandro (250×330): `head` ([-195, -145]), `upper_torso` ([-145, -95]), `lower_torso` ([-95, -45]), `legs` ([-45, 0]).
    - **Mapeamento Anatômico dos Golpes**:
      - Jab (`punch_1`): Cabeça e tórax superior (`head`, `upper_torso`).
      - Cross (`punch_2`): Tórax superior e cabeça (`upper_torso`, `head`).
      - Kick (`kick_3`): Tronco inferior e cintura (`lower_torso`).
      - Finisher (`finisher_4`): Tórax superior e cabeça (`upper_torso`, `head`), golpe pesado com knockdown.
      - Jump kick: Cabeça e tórax superior (`head`, `upper_torso`).
      - Especial: Área global resolvendo a região anatômica de cada alvo atingido.
    - **Simetria Horizontal e Calibração de Offset de VFX de Impacto**:
      - **Cálculo de Contato Bidirecional Relativo**: A coordenada horizontal `pos_x` do impacto é calculada avaliando a posição geométrica real do atacante em relação à vítima (`attacker_pos.x < target_pos.x`), garantindo que o impacto apareça invariavelmente na face de contato da vítima voltada para o atacante (`base_x - inset` se atacante à esquerda, `base_x + inset` se atacante à direita), funcionando com total simetria nos dois sentidos (Jogador -> Inimigo e Inimigo -> Jogador).
      - **Compensação Dinâmica de Espelhamento de Offset**: Em `CombatFeedback.gd`, o offset local é rigorosamente multiplicado pela direção horizontal (`visual_offset = Vector2(visual_offset.x * facing_sign, visual_offset.y)`), eliminando o desvio espúrio que projetava efeitos para fora do alvo ou próximos ao personagem atacante quando `scale.x` era negativo.
      - **Parametrização Anatômica dos Golpes Inimigos**: Tanto inimigos comuns (`enemy_ai.gd`) quanto o Chefe Alessandro (`boss_alessandro.gd`) configuram dinamicamente `impact_profile`, `preferred_regions` e `hitbox_offset_y` em cada tipo de golpe (`punch` alto [-125px / -135px], `kick` baixo [-70px / -75px], `heavy`/`combo` [-120px / -130px] e `jump_atk` [-150px]), garantindo que golpes recebidos pelo herói respeitem com exatidão anatômica a região atingida.
      - **Efeito Piloto PixelFX (`punch`)**: O perfil de impacto `punch` utiliza o efeito oficial PixelFX `blunt_hit` (`scenes/vfx/hit_effects_frames.tres` com spritesheet `assets/sprites/Efeitos/pixelfx/blunt_hit.png`, 28 frames em 30 FPS, canvas 128×88). Possui compensação local de offset em `Vector2(0.0, -6.0)` (alinhamento preciso do centro da explosão com `pos`), escala 1.05x, rotação nula para queda vertical natural dos estilhaços e ciclo de vida gerenciado via `animation_finished` com safety timer dinâmico.
      - **Adoção e Integração de Novos Efeitos PixelFX para Golpes Complementares**:
        - `kick` (chute e voadora): Integrado oficialmente o efeito PixelFX `hit_spark` (`scenes/vfx/hit_effects_frames.tres` com spritesheet `assets/sprites/Efeitos/pixelfx/hit-spark.png`, 16 frames em 30 FPS, canvas 136×80, duração 0,53s). Núcleo central perfeitamente simétrico `(68, 40)` com `visual_offset = Vector2.ZERO`, entregando flare em cruz afiado e cone direcional de estilhaços no sentido da perna.
        - `finisher`/`heavy` (golpe pesado e knockdown): Integrado oficialmente o efeito PixelFX `crit_hit` (`scenes/vfx/hit_effects_frames.tres` com spritesheet `assets/sprites/Efeitos/pixelfx/crit-hit.png`, 28 frames em 30 FPS, canvas 216×136, duração 0,93s). Núcleo central simétrico `(108, 68)` com `visual_offset = Vector2.ZERO`, entregando explosão estelar angular de alto impacto ("jagged starburst") com anéis de choque expansivos e chuva de fragmentos em cascata que maximizam o feedback tátil de derrubada.
        - `special` (golpe especial): Preservado `impactoazul` (`assets/sprites/Efeitos/impactoazul*.png`, escala 0.95x, offset compensado `Vector2(46 * facing_sign, 27)`), pois sua assinatura visual retrô azul mística é superior e indispensável à narrativa visual do Herói Guilherme (efeitos PixelFX de energia possuem leitura sci-fi/arcana destoante).
    - **Garantia de Dano Único e Isolamento de Whiff**: Um ataque que intersecta múltiplas regiões do mesmo alvo aplica dano estritamente uma única vez (`hit_targets.append(target_actor)`). Ataques desferidos no ar sem interceptação de alvo (Whiff) não instanciam faíscas ou partículas.
    - **Suíte de Validação**: `tests/test_combat_impact_positioning.gd` (9 cenários mandatórios de posicionamento, bidirecionalidade e zonas) e `tests/anatomical_combat_impact_test.gd` (52 cenários anatômicos e de combate).
  - **Ponto de Integração de Áudio de Combate**: Método desacoplado `CombatFeedback.play_impact_sound()` pronto para rotear efeitos sonoros conforme perfis (`punch`, `kick`, `finisher`, `special`) quando os recursos de áudio forem adicionados ao repositório.
- **Vitória do Encontro (`encounter_cleared`)**:
  - Ocorre estritamente quando `alive_enemies.is_empty()` **E** `pending_spawns_count == 0` **E** não houver chefe configurado pendente de spawn.

- **Balanceamento Arcade e Economia de Combate (FASE P6)**:
  - **Economia do Especial**: Taxa de carregamento calibrada em 3.5% por acerto (`SPECIAL_CHARGE_PER_HIT`), permitindo ao jogador carregar 1 barra de especial completa a cada ~28 acertos, perfeitamente compatível com a densidade de inimigos de cada seção. O especial consome 100% da barra sem consumir vida do herói.
  - **Cadência e Dano de Combo do Herói**: O combo canônico de 4 golpes causa 80.0 de dano base acumulado (Jab: 10, Cross: 15, Hook: 20, Finisher: 35 com knockdown), eliminando 1 Grunt padrão no Mapa 1 com 1 combo limpo.
  - **Curva de Dificuldade dos Mapas (1 a 4)**:
    - *Mapa 1 (A Locadora)*: 1 token ofensivo, Grunts (80 HP, 10 DMG). Ensino de mecânicas e leitura limpa.
    - *Mapa 2 (Balcão da Locadora)*: 2 tokens ofensivos, Flankers ativos e 1 onda de reforço fora da tela (1.15 HP, 1.10 DMG).
    - *Mapa 3 (O Beco de Entrada)*: 2 tokens ofensivos, Aggressors velozes (1.30 HP, 1.25 DMG).
    - *Mapa 4 (O Beco Final)*: 2 tokens ofensivos, Tanks com super armor e Chefe Alessandro (1.40 HP, 1.25 DMG, com telegraph mantido acima de 0.20s para reação humana justa).
  - **Mecânica Universal de Continue / Respawn Arcade & Game Over**:
    - Nova partida inicia com 1 ficha de continue (`current_continues = 1`).
    - Respawn com queda arcade dos céus, 100% HP restaurado, 50% de especial inicial, tremor de tela, queda de inimigos ao solo e 2.0s de invulnerabilidade com piscar visual.
    - Blindagem contra acionamento indevido de Game Over durante o respawn via flag atômica `is_respawning`.
    - Ao esgotar as fichas e ocorrer a morte definitiva, a tela de Game Over exibe a imagem `game_over.webp` com efeito suave de fade in por ~5 segundos.
    - O comando `[R]` para reiniciar a fase é estritamente bloqueado durante o fade in, sendo liberado apenas após os 5 segundos completos de transição.
    - Ao reiniciar pelo Game Over, o jogador retorna ao início da fase (Fase 1 retorna para `map_1.tscn`) com a contagem de continues ZERADA (`current_continues = 0`), e não 1 como padrão. A imagem de fundo já contém a legenda nativa ('aperte o r para reiniciar'), dispensando textos de instrução redundantes sobrepostos.
  - **Sequência de Morte e Fade dos Inimigos**: O shader de `palette_swap` modula canal alpha e cor (`tex_color.a * COLOR.a` e `tex_color * COLOR`), assegurando que em todos os mapas e para todas as paletas de cores, os inimigos derrotados apresentem a sequência de piscar 4 vezes e desaparecer suavemente do cenário antes do despawn.

---

## 11. DAMAGE CONTRACT
`STATUS: IMPLEMENTED`

- **Fluxo Universal de Dano**:
  ```text
  Atacante (Player, Inimigo, Perigo Ambiental)
          ↓
     DamageInfo (amount, attacker, direction, damage_type, knockback_force, hitstun, can_destroy_props, can_knockdown, hitstop_duration, impact_profile)
          ↓
     Damageable (Grupo "damageable")
          ↓
     Receptor (HealthComponent / Actor / DestructibleProp)
  ```
- **Divisão de Responsabilidade**:
  - **Atacante**: Constrói e emite o payload imutável `DamageInfo`. Desconhece a classe concreta do alvo.
  - **Receptor**: Autoridade soberana. Decide se aceita o dano, se aplica guarda/mitigação, se consome vida via `HealthComponent`, se toca animação de ferimento, se cai ao solo (`can_knockdown`), se quebra ou se ignora.
- **Contrato de Interface**: Toda entidade receptora deve implementar:
  ```gdscript
  func take_damage(damage_input: Variant) -> bool
  ```
  aceitando tanto `float` numérico quanto objeto estruturado `DamageInfo`.


---

## 12. DESTRUCTIBLE CONTRACT
`STATUS: IMPLEMENTED`

- **Ciclo de Vida Tipado (`PropState`)**:
  | Estado | Colisor Físico | Hurtbox | Avoidance | Visual | Comportamento de Dano |
  |---|---|---|---|---|---|
  | `ACTIVE` | Ativo (Layer 2) | Monitorable | Ativo | Íntegro | Aceita dano normalmente |
  | `DAMAGED` | Ativo (Layer 2) | Monitorable | Ativo | Avaria / Flash | Aceita novos danos |
  | `DESTROYING` | Transição | Transição | Desativado | Inicia quebra / som | Recusa novos danos |
  | `DESTROYED` | Disabled (`deferred`) | `monitorable = false` | Inativo | Quebrado / Oculto | Recusa qualquer dano (`take_damage` retorna false) |
- **Performance de Navegação (Sem Rebuild Global)**:
  - É expressamente proibido chamar `NavigationRegion2D.bake_navigation_polygon()` ao destruir props.
  - A liberação de passagem é instantânea via `nav_obstacle.avoidance_enabled = false` e `collision_shape.set_deferred("disabled", true)`.
- **Idempotência**: Chamadas repetidas a `destroy_prop()` são seguras e não duplicam drops nem emitem sinais espúrios.
- **Padronização Obrigatória de Drops**: Qualquer prop destrutível que instancie itens ao ser quebrado (`drops_item = true`) DEVE instanciar pickups compatíveis com a arquitetura canônica da **Seção 35 (Arquitetura Canônica de Itens Dropados e Pickups 2.5D)**.

---

## 13. NAVIGATION CONTRACT
`STATUS: IMPLEMENTED`

- **Malha Canônica Convexa**: Cada mapa possui um recurso `map_X_navpoly.tres` associado a um nó `NavigationRegion2D`, contornado pelas mobílias estáticas.
- **Navegação Híbrida 2.5D**:
  - Antes de acionar pathfinding, os atores verificam linha de visada direta via raycast contra a Layer 2 (`_has_obstacle_between()`).
  - **Sem Obstrução**: Movimentação direta vetorial (resposta ágil de fliperama).
  - **Com Obstrução**: Rota calculada via `NavigationAgent2D.get_next_path_position()`.
- **Avoidance RVO Local**: `avoidance_enabled = true` em todos os agentes, com processamento via `velocity_computed` para evitar congestionamentos.

---

## 14. SPAWN CONTRACT
`STATUS: IMPLEMENTED`

- **Separação Semântica**: Distinção clara entre entidades pré-posicionadas e entidades instanciadas dinamicamente durante a partida.
- **Componentes**:
  - `SpawnPoint` (`Marker2D`, script: `spawn_point.gd`, grupo `"spawn_points"`): Define coordenadas físicas válidas no chão, ID único e enum `SpawnType` (`ENEMY`, `NPC`, `REINFORCEMENT`, `EVENT`, `BOSS`).
  - `SpawnDirector` (`Node`, script: `spawn_director.gd`, grupo `"spawn_director"`): Gerencia pontos e instancia entidades em runtime.
- **Integração com CombatDirector**:
  - Tipos `ENEMY`, `REINFORCEMENT` e `BOSS` registram-se automaticamente no `CombatDirector` e atualizam `pending_spawns_count`.
  - Tipos `NPC` são direcionados para o contêiner `World/Actors/NPCs` com isolamento total de combate.

- **Regras de Ondas de Reforço e Spawns Fora da Tela (FASE P5)**:
  - **Gatilho de Onda**: Disparado em `BaseLevel._on_enemy_defeated()` sob condição testável (`alive_enemies.size() <= reinforcement_trigger_enemy_count`).
  - **Contagem e Blindagem Imediata de Saída**: Antes de iniciar o timer do encontro (`reinforcement_delay_seconds`), o `BaseLevel` invoca imediatamente `combat_director.add_pending_spawns(reinforcement_count)`. A saída (`ExitArea`) e o indicador `SIGA →` permanecem rigorosamente travados enquanto `pending_spawns_count > 0`, mesmo que todos os inimigos da onda inicial tenham sido derrotados durante o delay.
  - **Geometria de Entrada Fora da Tela (World Rect)**: As coordenadas dos reforços são calculadas dinamicamente em coordenadas de mundo fora do retângulo visível da `Camera2D` (`get_offscreen_spawn_position()`) com margem de segurança (70px a 150px) e restritas aos limites caminháveis do cenário. Se a câmera estiver encostada no limite direito do mapa, a posição inverte automaticamente para fora da tela à esquerda. Múltiplos reforços recebem separação no eixo $Y$ para evitar sobreposição imediata.
  - **Entrada Legível e Abordagem Justa**: Reforços entram obrigatoriamente no estado `FLANKING` (caminhando em aproximação), garantindo que nenhum inimigo golpeie o jogador instantaneamente ao cruzar a borda da tela sem preparação prévia.
  - **Variedade Visual por Arquétipos**: Através de `reinforcement_archetypes`, cada reforço recebe seu perfil tático (ex: `AGGRESSOR`, `FLANKER`), herdando a variação automática de paleta de cores (vermelho, verde, roxo) estabelecida na FASE 4.
  - **Idempotência e Resiliência de Ciclo de Vida**:
    - Disparos múltiplos de eventos de derrota jamais duplicam a cota agendada da onda.
    - Em caso de transição de mapa, morte definitiva do herói ou limpeza da árvore (`_exit_tree()`), timers e contadores pendentes são cancelados e zerados com segurança via `_clear_pending_reinforcements()`.

- **Guia de Replicação para o Mapa 3 (O Beco de Entrada)**:
  - **Passo 1**: Abrir a cena `scenes/levels/map_3.tscn` no editor ou inspecionar suas propriedades de nó raiz.
  - **Passo 2**: No nó raiz `Map3`, configurar as propriedades do grupo `Ondas de Reforço (P5)`:
    - `reinforcement_waves_enabled = true`
    - `reinforcement_trigger_enemy_count = 1`
    - `reinforcement_delay_seconds = 2.0`
    - `reinforcement_count = 2`
    - `reinforcement_archetypes = [1, 3]` (Garante entrada de 1 Aggressor vermelho e 1 Flanker verde)
  - **Passo 3**: O Mapa 3 já possui contêiner `SpawnPoints` (com `SpawnPoint_Reinforce` em $X=1580, Y=640$), nó `SpawnDirector`, câmera e limites caminháveis calibrados. O `BaseLevel` orquestrará a onda automaticamente sem exigir scripts ou nós adicionais.

---

## 15. EVENT CONTRACT
`STATUS: IMPLEMENTED`

- **Foreground Isolado**: Camada `Foreground` (`z_index = 10`) sobrepõe visualmente atores e cenário sem interferir em colisões ou navegação.
- **Triggers Desacoplados (`LevelEventTrigger`)**:
  - Monitora entrada de corpos (`body_entered` na Layer 1), acionamentos manuais ou sinais de objetos (ex: destruição de prop via `bind_to_destructible()`).
- **Orquestrador de Sequências (`LevelEventDirector`)**:
  - Encadeia eventos complexos (ex: entrada de NPC, tranca de portas, spawn de ondas) sem poluir `BaseLevel.gd`.

---

## 16. DIALOGUE/TEXT CONTRACT
`STATUS: IMPLEMENTED`

- **Diretor de Diálogos (`DialogueDirector`)**:
  - Gerencia filas de mensagens assíncronas com sinais `message_started(speaker, text)` e `message_completed()`.
  - Suporta avanço automático por timer ou avanço manual pelo jogador (`advance_message()`).
  - Totalmente desacoplado do combate: anúncios, falas de chefes ou avisos narrativos não interrompem o loop de física do jogo.

- **Padrão Canônico de Caixa de Diálogo e Inspeção de Itens (`StandardDialogueBox`)**:
  `STATUS: IMPLEMENTED`
  - *Arquitetura de Containers e Moldura Oficial*: Toda caixa de diálogo in-game, balão de fala ou janela de inspeção de itens coletados do chão DEVE utilizar a estrutura `MarginContainer` e `PanelContainer` com `StyleBoxTexture` baseado na textura oficial `res://assets/ui/hud/dialog_frame_9patch.png`, com margens 9-patch de 14px em todos os quatro cantos (`texture_margin_left/top/right/bottom = 14`).
  - *Avatar em Pixel Art HD*: Exibição de face do orador (`portrait_gabriel.png` ou ícone do item) através de `TextureRect` com `texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST` e `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`, preservando rigorosamente a nitidez e a resolução nativa do Pixel Art HD sem anti-aliasing borrado. Dimensões: 110×110px no Desktop e 72×72px no Mobile.
  - *Tipografia e LabelSettings Unificados*: Proibido criar formatação avulsa em Labels. Todas as caixas devem instanciar `LabelSettings` canônicos com a fonte `res://assets/fonts/arcade_bold.ttf`:
    - **Orador (Speaker)**: 32px no desktop / 26px no mobile, cor Ouro Arcade `Color(0.94, 0.75, 0.39, 1.0)`, contorno de 4px no desktop / 3px no mobile `Color(0.04, 0.035, 0.045, 1.0)`, sombra projetada preta com offset `Vector2(2, 2)`. Proibido uso de `clip_text = true` que cause colapso de altura para 0px em containers VBox.
    - **Fala / Conteúdo (Dialogue)**: 30px no desktop / 24px no mobile, cor Creme `Color(0.96, 0.95, 0.90, 1.0)`, contorno de 3px no desktop / 2px no mobile `Color(0.035, 0.035, 0.045, 1.0)`, sombra preta com offset `Vector2(2, 2)`, entrelinha fixa de 8px (desktop) / 6px (mobile) e quebra automática de linha inteligente (`AUTOWRAP_WORD_SMART`). Nunca utilizar `clip_text = true` no texto de fala para não ocultar frases por medição preliminar de layout.
    - **Avisos / Rodapé (Prompt)**:
      - *Desktop*: 20px, texto `"TOQUE OU PRESSIONE ENTER PARA CONTINUAR"`, cor prateada/azulada `Color(0.78, 0.81, 0.87, 1.0)`.
      - *Mobile*: Flecha indicativa arcade `"►"` (`#FFEAB0`, 22px) posicionada no canto inferior direito, sem moldura retangular pesada, sinalizando intuitivamente avanço por toque em qualquer ponto da tela/diálogo (*Touch-Anywhere-to-Advance* via `mouse_filter = MOUSE_FILTER_PASS`).
  - *Margens de Segurança Anti-Estouro das Cantoneiras Douradas (┌, └, ┐, ┘)*:
    - *Desktop*: Margens de 18px laterais, 12px superior e 10px inferior.
    - *Mobile*: Margens ampliadas de 22px laterais, 10px superior e 8px inferior, garantindo recuo seguro para que o nome do orador e o corpo da fala nunca sobreponham as cantoneiras desenhadas na textura 9-patch.
  - *Efeito Máquina de Escrever (Typewriter Effect)*: Toda fala deve exibir o texto progressivamente a uma velocidade uniforme de 40 caracteres por segundo (`StandardDialogueBox.TYPEWRITER_SPEED_CPS`).
    - *Skip Imediato*: Se o jogador pressionar qualquer tecla de confirmação ([Enter], [Espaço], [A] do Gamepad) ou tocar na tela durante a digitação, o efeito é cancelado instantaneamente (`visible_characters = -1`), revelando a frase inteira de uma só vez.
    - *Avanço / Fechamento*: O próximo comando de confirmação após o término da digitação fecha o diálogo ou avança para o próximo bloco de texto.
  - *Camada Z-Index e CanvasLayer*: As interfaces de diálogo e inspeção devem residir em `CanvasLayer` com `layer = 125` (ou z-index 100+ no mundo), garantindo prioridade visual absoluta sobre o Y-sort e todos os atores/props 2.5D do cenário de Vila Prudente.
  - *Inspeção Sem Tela Preta (Dimming Translúcido)*: Coleta de cartas mágicas ou itens dropados de caixas destroçadas congelam a partida com `get_tree().paused = true`, utilizam fundo translúcido `Color(0.012, 0.015, 0.028, 0.86)` mantendo o cenário e iluminação visíveis ao fundo, e exibem a arte ampliada central com pop-in fluído (`scale` de 0.08 a 1.0 via `TRANS_BACK`). Proibido fade para tela preta durante inspeção in-game.
  - *Área Segura e Desobstrução da Arte*:
    - *Desktop*: Caixa de diálogo ocupa a base inferior a partir de 67% (`anchor_top = 0.67`).
    - *Mobile*: Caixa de diálogo compacta posicionada a partir de 78% (`anchor_top = 0.78`), liberando aproximadamente 78% da tela para visualização nítida do cenário e das artes/cartas ampliadas, evitando sobreposição destrutiva com a ilustração.
  - *Diretriz de Geração de Imagens*: É terminantemente proibido ficar gerando imagens avulsas por IA desnecessariamente. Deve-se reaproveitar rigorosamente a biblioteca oficial de assets Pixel Art HD existente em `assets/sprites/` e `assets/ui/`.

- **Sistema Declarativo de Narrativa Cinemática (`StoryEvent`, `StorySequence`, `NarrativeDirector`)**:
  - **Padrão Oficial de Apresentação Arcade (Neo-16-bit Urbano)**:
    - *Referência Visual Obrigatória*: Baseado na composição canônica de `assets/backgrounds/referencia_introducao.webp`.
    - *Enquadramento e Área Segura*: O palco de arte (`ArtStage`) ocupa os 74% superiores da tela com modo `STRETCH_KEEP_ASPECT_CENTERED` e `TEXTURE_FILTER_NEAREST`. As imagens mantêm 100% da proporção original sem corte de personagens nas bordas. Camada de fundo ambiente (`AmbientBackground`) preenche aspectos de tela variáveis sem barras vazias. A moldura inferior nunca encobre rostos, mãos, pés ou silhuetas essenciais.
    - *Moldura Oficial Arcade Cinematográfica*: Painel em azul-marinho profundo/violeta `#0C0C18` (94% opacidade) com borda rosa/magenta `#FF2A6D` (3px), cantoneiras em ciano `#05D9E8` e magenta, identificação do orador e sombra projetada discreta. Não exibir barra de status de transmissão, indicador fictício de conexão ou rótulo técnico decorativo.
    - *Tipografia e Quebra de Linha Estrita*: Emprego de `assets/fonts/arcade_bold.ttf` com autowrap inteligente (`AUTOWRAP_WORD_SMART`), margens internas seguras (32px laterais, 16px no container de texto) e entrelinha formatada, garantindo que qualquer texto atual ou futuro quebre de linha antes de tocar ou ultrapassar os limites da moldura. Textos em 24px com sombra sólida preta e alto contraste.
    - *Avanço Estritamente Manual*: Nenhuma fala desaparece ou avança por temporizador automático. A narrativa permanece em tela até confirmação deliberada do jogador ([Enter], [Espaço], Gamepad A, toque no botão `AVANÇAR ❯` ou toque de tela).
    - *Proteção e Isolamento de Input*: Transições sóbrias (~0.32s) com flag `_is_transitioning` impedem múltiplos saltos por repetição de tecla (`echo`). Ao concluir a sequência, ações pendentes (`jump`, `attack`, `attack_punch`, `ui_accept`) são liberadas via `Input.action_release()` antes da carga de `map_1.tscn`, eliminando sangramento de comandos para o primeiro frame de gameplay.
  - **Recursos Declarativos e Modelo Narração vs. Revelação**:
    - `StoryEvent` (`scripts/events/story_event.gd`): Especifica `id`, `event_type` (`narration`, `revelation`, `dialogue`), `image_path`, blocos de `texts`, `speaker`, `entry_effect` (`fade_in`, `slow_zoom`, `crossfade`, `glitch`), `exit_effect`, `transition_duration` (0.32s), `safe_framing`, `zoom_start`, `zoom_end`, `glitch_frames` e identificador de áudio.
    - `StorySequence` (`scripts/events/story_sequence.gd`): Agrupa eventos de forma sequencial desacoplada de código monolítico.
    - `res://resources/story/story_intro_map1.tres`: Recurso oficial da Abertura Narrativa do Mapa 1 composto pelas 7 cenas canônicas do roteiro:
      1. *CENA 01 (Título)*: Fundo preto, silêncio inicial, texto central dourado "Saka's", subtítulo marfim "A ÚLTIMA FICHA", som de hum profundo.
      2. *CENA 02 (Os Quatro)*: Imagem `assets/story/map_1/intro_group.webp` em palco seguro com `slow_zoom` (100% para 103%), texto de apresentação dos 4 amigos (Guilherme, Gabriel, André e Juliana).
      3. *CENA 03 (Os Que Não Estão)*: Imagem `assets/story/map_1/missing_friends.webp` com efeito analógico de `glitch` (3 frames) e revelação dos desaparecidos (Alessandro e Fernando).
      4. *CENA 04 (A Sala Secreta)*: Imagem `assets/story/map_1/secret_room.webp`, descoberta da sala secreta atrás da estante e da máquina de arcade.
      5. *CENA 05 (A Máquina - Revelação)*: Imagem `assets/story/map_1/arcade_machine.webp`, close da máquina acendendo, revelação das mensagens de tela arcade ("INSERT COIN" → "4 PLAYERS DETECTED" → "CONTINUE?").
      6. *CENA 06 (Passado e Presente - Revelação Central)*: Imagem `assets/story/map_1/past_present.webp`, mostrando lugares conhecidos com passado e presente ocupando o mesmo espaço físico. A geografia deve continuar reconhecível; a década de 1990 funciona como base, enquanto elementos atuais aparecem por justaposição ou sobreposição parcial, com glitch curto e localizado. Não introduzir portal, arquitetura futurista genérica ou explicação visual que não esteja no roteiro.
      7. *CENA 07 (Retorno à Locadora)*: Imagem `assets/story/map_1/street_memory.webp`, transição com a identificação "MAPA 1 — A LOCADORA" e entrada suave no gameplay de `map_1.tscn`. A locadora permanece como âncora visual; sinais de mudança temporal devem ser coerentes com a cena e não antecipar indiscriminadamente elementos de fases futuras.
  - **Diretor de Apresentação (`NarrativeDirector`)**:
    - Instanciado em `CanvasLayer` superior (layer = 120), preservando a cena de gameplay intacta ao fundo.
    - Suporte integral a Teclado, Gamepad, Mouse e Toque Mobile (`InputEventScreenTouch`).
    - Botão visual "PULAR ⏩" no canto superior e comando [ESC] para pular a sequência completa a qualquer momento.
    - Efeitos sonoros procedurais autônomos (`_create_wav`, `_create_noise_wav`): zumbido analógico grave, chime de nostalgia e estática de glitch.
  - **Integração de Sessão e Salvamento**:
    - Novo Jogo inicia com `GameSession.has_played_intro = false`, garantindo a exibição na transição pós-instruções.
    - Ao concluir ou pular, `has_played_intro` é definido como `true`.
    - Ao carregar jogo salvo (CONTINUAR via `load_game_from_slot`), `has_played_intro = true` é ativado de imediato, garantindo que o prólogo **NÃO** seja reproduzido novamente.
  - **Padronização Visual e Interativa no Story Mobile (`StandardDialogueBox` Pattern)**:
    - *Isolamento Estrito Desktop vs Mobile*: Desktop/PC preserva integralmente sua composição widescreen, proporções e avanço por [ENTER]/[Espaço].
    - *Avatar Mobile Canônico*: Exibido na coluna esquerda da moldura com tamanho canônico de **88 × 88 px** (em vez do antigo 44px), `TEXTURE_FILTER_NEAREST`, `STRETCH_KEEP_ASPECT_CENTERED` e `EXPAND_IGNORE_SIZE`, sem distorção ou perda de nitidez de Pixel Art HD.
    - *Tipografia Canônica Mobile*:
      - Nome do Orador: 28px no mobile, Ouro Arcade `Color(0.94, 0.75, 0.39, 1.0)`, contorno de 4px, sombra de 2px `Vector2(2, 2)`.
      - Texto de Diálogo: 26px no mobile, Creme Oficial `Color(0.96, 0.95, 0.90, 1.0)`, contorno de 3px, sombra de 2px `Vector2(2, 2)`, espaçamento entre linhas de 8px e `AUTOWRAP_WORD_SMART`.
    - *Estrutura de Layout em Duas Colunas*: Coluna esquerda com Avatar (88x88 px) e coluna direita com VBox (Cabeçalho com nome e contador, divisor dourado, texto com entrelinha confortável e rodapé com botão `AVANÇAR`).
    - *Contenção e Sem Vazamento*: Altura do painel de diálogo no mobile de 35% a 36% do viewport (`anchor_top = 0.64`, `anchor_bottom = 0.985`), impedindo estritamente colisões com o texto ou vazamento do botão sobre as bordas da moldura.
    - *Botão Mobile AVANÇAR*: Botão arcade em estilo vidro escuro com aro dourado, dimensão de 148 × 40 px (touch target confortável $\ge 48\text{ dp}$), posicionado no canto inferior direito do rodapé interno.
    - *Mecânica Canônica da CENA 05 (A Máquina CRT)*:
      - O botão genérico `AVANÇAR` é estritamente removido/ocultado no mobile.
      - O prompt "CONTINUE?" renderizado no monitor CRT torna-se o único alvo tátil interativo para avançar a cena.
      - Toques gerais fora do monitor CRT na tela são ignorados e não avançam a cena.
      - Avanço estritamente manual: sem avanço automático por timer ou término da animação.
      - Proteção contra duplo clique / toques múltiplos para evitar pular acidentalmente para a cena subsequente.

---

## 17. COLLISION LAYERS AND MASKS
`STATUS: IMPLEMENTED`

| Camada Lógica | Nome do Uso | Bitmask Int | Finalidade Física |
|:---:|---|:---:|---|
| **1** | Atores | `1` (`1 << 0`) | Corpos físicos de `Player`, `Enemies`, `NPCs`. Não colidem entre si. |
| **2** | Mundo / Mobílias | `2` (`1 << 1`) | Limites perimetrais, paredes, estantes e caixas destrutíveis. |
| **3** | Hurtboxes | `4` (`1 << 2`) | Áreas receptoras de dano de atores e props. `monitoring = false`, `monitorable = true`. |
| **4** | Hitboxes | `8` (`1 << 3`) | Áreas ofensivas de ataque (`MeleeAttack`). `monitoring = true`, monitora Layer 3. |
| **5** | Gatilhos / Saída | `16` (`1 << 4`) | Zonas de transição (`ExitArea`) e gatilhos narrativos (`LevelEventTrigger`). |

---

## 18. GROUPS
`STATUS: IMPLEMENTED`

| Grupo | Finalidade Canônica | Membros Autorizados |
|---|---|---|
| `actors` | Toda entidade animada viva | `Player`, `BasicEnemy`, `BossAlessandro`, `BaseNPC` |
| `player` | Herói jogável | Exclusivamente instâncias de `player.tscn` |
| `enemies` | Inimigos combatentes | `BasicEnemy`, `BossAlessandro` |
| `npcs` | Não-combatentes e civis | Instâncias de `BaseNPC` / `npc.tscn` |
| `damageable` | Qualquer entidade que recebe dano | `Player`, `Enemies`, `NPCs`, `DestructibleProp` |
| `destructibles` | Objetos de cenário quebráveis | Instâncias de `DestructibleProp` |
| `props` | Elementos de cenário interativos | Props destrutíveis e estáticos |
| `spawn_points` | Pontos de surgimento de runtime | Instâncias de `SpawnPoint` (`Marker2D`) |
| `spawn_director` | Gerenciador de spawning | Instância única de `SpawnDirector` |
| `combat_director` | Orquestrador de combate 2.5D | Instância única de `CombatDirector` |

---

## 19. Y-SORT RULES
`STATUS: IMPLEMENTED`

1. **Âncora Rigorosa nos Pés**: A origem local `(0, 0)` de todo ator e prop deve coincidir estritamente com a base de contato dos pés ou base do objeto no chão.
2. **Ativação Obrigatória de Y-Sort**: Todos os contêineres ancestrais do mundo (`World`, `Props`, `StaticProps`, `Destructibles`, `Actors`, `Enemies`, `NPCs`) devem possuir `y_sort_enabled = true`.
3. **Proibição de Deslocamento Z Arbitrário**: Jamais aplicar `z_index` customizado em atores que quebre a ordenação por profundidade Y.

---

## 20. Z-INDEX RULES
`STATUS: IMPLEMENTED`

| Camada Estrutural | Nó da Cena | Valor de `z_index` | Comportamento |
|---|---|:---:|---|
| Planos Distantes | `Background` | `-10` | Renderizado atrás de todo o mundo de jogo. |
| Mundo Caminhável | `World` (Props e Atores) | `0` | Ordenado dinamicamente pelo Y-Sort dos pés. |
| Primeiro Plano | `Foreground` | `10` | Cobre atores e elementos caminháveis (postes, marquises, fiação). |
| Interface de Usuário | `CanvasLayer` (HUD / Telas) | `Layer 1` | Renderizado na tela do usuário, independente da câmera. |

---

## 21. PERFORMANCE RULES (PERFORMANCE CONTRACT — 60 FPS)
`STATUS: IMPLEMENTED`

1. **Sem Varreduras Contínuas de Grupo por Frame**:
   - É proibido chamar `get_nodes_in_group()` repetitivamente dentro de `_process()` ou `_physics_process()`.
   - `MeleeAttack`: Varre grupos de alvos apenas no disparo inicial do golpe (`execute_attack`). Nos frames subsequentes da janela ativa, delega a detecção aos métodos espaciais de baixo custo `get_overlapping_areas()` e `get_overlapping_bodies()` do servidor de física, eliminando alocações contínuas de arrays a 60 FPS.
2. **Prevenção de Rebuild Global de Navegação**:
   - Destruição ou alteração de props destrutíveis NUNCA dispara `bake_navigation_polygon()`. O desvio dinâmico é atualizado instantaneamente via `NavigationObstacle2D` avoidance no servidor.
3. **Throttling de Pathfinding em Atores**:
   - `NavigationAgent2D` em NPCs e inimigos obedece a um intervalo mínimo de atualização (`PATHFIND_MIN_INTERVAL >= 0.20s`), evitando requisições redundantes de rotas a cada frame.
4. **Partículas Amigáveis a Mobile (CPUParticles2D)**:
   - Efeitos de impacto, poeira e quebra utilizam exclusivamente `CPUParticles2D`. O uso de `GPUParticles2D` é proibido para evitar travamentos por compilação assíncrona de shaders em dispositivos mobile de entrada.
5. **Limpeza Segura de Ciclo de Vida**:
   - Todos os nós que saem da árvore (`tree_exiting`) desconectam seus sinais e são desregistrados do `CombatDirector` e `SpawnDirector`, prevenindo vazamento de referências e checagens sobre nós órfãos.

---

## 22. GDSCRIPT TYPING RULES
`STATUS: IMPLEMENTED`

1. **Tipagem Estática Obrigatória**: Toda variável, parâmetro e retorno de função deve conter anotação de tipo explícita (`var speed: float = 120.0`, `func move_to(pos: Vector2) -> void:`).
2. **Proibição de Variáveis Dinâmicas Implícitas**: Evitar o uso de `var` sem tipo quando o tipo for inferível ou determinável.
3. **Casting Seguro**: Utilizar a sintaxe `as Tipo` acompanhada de validação de nulidade (`var actor := node as CharacterBody2D; if actor != null:`).
4. **Resolução de Tipos em Modo Headless**: Não referenciar nomes de classes customizadas que não pertençam ao cache global em assinaturas de sinais exportados; utilizar referências pré-carregadas (`const`) ou tipos base do motor (`RefCounted`, `Node`).

---

## 23. TESTING RULES
`STATUS: IMPLEMENTED`

1. **Obrigatoriedade de Testes**: Toda funcionalidade nova ou refatoração estrutural deve ser acompanhada de uma suíte automatizada de testes headless.
2. **Proibição de Declaração sem Execução**: Nenhum teste pode ser considerado válido sem a execução efetiva do comando no motor e validação do código de saída (`exit code 0`).
3. **Sem Retornos Silenciosos**: Testes não podem conter cláusulas `return` prematuras que encerrem a rotina sem contabilizar asserções (`assert_test()`).
4. **Estratégia de Otimização de Tokens (Testes Focados vs. Regressão Global)**:
   - Em iterações pontuais via conversa natural, execute **exclusivamente a suíte focada no componente alterado** (ex.: `player_hud_test.gd` para UI de HUD, `sergio_npc_test.gd` para NPC, etc.). Isso evita despejo de milhares de linhas de log no contexto e reduz o consumo de tokens em mais de 90%.
   - A bateria completa de 21 suítes (`tests/run_all_tests.ps1`) é reservada para entregas de marcos arquiteturais, pipelines de CI ou quando expressamente solicitada pelo usuário.

---

## 24. HEADLESS TEST RULES
`STATUS: IMPLEMENTED`

1. **Execução Headless Oficial Focada**: Os testes individuais são executados diretamente através do binário de console do Godot Engine:
   ```powershell
   godot_console.exe --headless -s tests/<nome_do_teste>.gd
   ```
2. **Isolamento de Janela e Árvore**: Os scripts de teste herdam de `SceneTree` e limpam todos os nós instanciados no encerramento (`queue_free()`), saindo com `quit(0)` em caso de sucesso ou `quit(1)` em falhas.

---

## 25. CI/CD RULES
`STATUS: IMPLEMENTED`

1. **Bateria Completa de Regressão**: A integridade global do projeto é auditada pelo runner automatizado `tests/run_all_tests.ps1`, abrangendo atualmente **21 suítes completas**:
   - `tests/map_structure_test.gd`
   - `tests/prop_contracts_test.gd`
   - `tests/actor_contracts_test.gd`
   - `tests/actor_contract_test.gd`
   - `tests/spawn_points_test.gd`
   - `tests/destructible_prop_test.gd`
   - `tests/combat_director_test.gd`
   - `tests/combat_smoke_test.gd`
   - `tests/boss_alessandro_test.gd`
   - `tests/map_progression_test.gd`
   - `tests/loading_screen_test.gd`
   - `tests/ui_flow_test.gd`
   - `tests/combat_integration_test.gd`
   - `tests/npc_test.gd`
   - `tests/level_events_test.gd`
   - `tests/narrative_intro_test.gd`
   - `tests/navigation_integrity_test.gd`
   - `tests/performance_audit_test.gd`
   - `tests/arcade_combat_system_test.gd`
   - `tests/player_hud_test.gd`
   - `tests/arcade_hud_refinement_test.gd`
   - `tests/sergio_npc_test.gd`
2. **Critério de Bloqueio**: O pipeline de CI e fechamentos de versão exigem **100% de aprovação (0 falhas)** nas 21 suítes.
3. **Política de Git**: Commits atômicos e padronizados por categoria (`arch:`, `test:`, `perf:`, `docs:`).


---

## 26. MOBILE CONSTRAINTS & MULTIPLATFORM SPEC
`STATUS: IMPLEMENTED`

1. **Segregação Absoluta Desktop vs Mobile**:
   - Controles touch virtuais (`TouchControls`, D-Pad analógico, botões de ataque/pulo/especial) são **exclusivos de runtime mobile** (`OS.has_feature("mobile")`, `web_android`, `web_ios`).
   - No Desktop/PC, nenhum botão virtual ou dock touch aparece na tela. Atalhos de teclado (WASD, Setas, Enter, Espaço, ESC) e navegação com mouse permanecem 100% nativos e intocados.
   - Botões de depuração como `TouchToggleBtn` são permanentemente ocultados no runtime final.
   - O Menu Principal no mobile não exibe botão dock inferior — as opções do menu são tocáveis diretamente via hitboxes invisíveis sobre a arte. Ao tocar/clicar em qualquer opção, a pincelada dourada arcade pisca sobre a opção para confirmar a escolha, sem chevrons (`<<` e `>>`) e sem inserir retângulo ou moldura retangular comprida em volta do botão.
   - Hints de teclado (`ControlsLabel`) e seletores fixos de repouso são ocultados no mobile até o toque de confirmação.

2. **Display, Orientação e Preenchimento Fullscreen Nativo (Sem Cortes)**:
   - `project.godot`: `window/handheld/orientation=0` (`landscape`) garante abertura imediata em modo paisagem.
   - `mobile_bootstrap.gd` (AutoLoad) aplica `CONTENT_SCALE_ASPECT_KEEP_HEIGHT` no runtime mobile e escuta redimensionamento de viewport.
   - **Preenchimento total unificado sem barras pretas e sem ocultar partes da arte**:
     - `AspectRatioContainer` (telas com wrapper: Título, Menu Principal, Seleção de Personagem) tem sua propriedade `ratio` ajustada dinamicamente para a proporção real da viewport mobile (`vp_size.x / vp_size.y`), mantendo `STRETCH_FIT`. A arte preenche 100% da tela ultrawide (~20:9) sem zoom excessivo e sem cortar elementos de topo ou rodapé.
     - `MapContainer` (`map_menu.gd` e `map_transition.gd`) escala dinamicamente para `Vector2(vp_size.x / 1920.0, vp_size.y / 1080.0)`, eliminando margens pretas e mantendo o traçado e pontos perfeitamente alinhados à arte do mapa.
     - Backgrounds diretos e de narrativa (`loading_screen.gd`/`Instruções_1`, `difficulty_select.gd`/`dificuldade`, `narrative_director.gd`/cenas `intro_xxx`, `continue_screen.gd`/`continuar`, `story_intro_fase1_2.gd`) são promovidos a `STRETCH_SCALE` com `PRESET_FULL_RECT` em mobile, exibindo 100% da ilustração sem cortes e sem letterbox.
   - **Desktop preservado**: No desktop, a proporção 16:9 clássica (`ratio = 1.777778`, `STRETCH_KEEP_ASPECT_CENTERED`, `scale_factor = minf(...)`) é mantida estritamente inalterada.
   - Nos mapas da Fase 1, `mobile_base_level.gd` realiza clamp dinâmico de câmera e cálculo de zoom adaptativo (`_apply_mobile_camera_bounds`), impedindo vazamento de margens cinzas além da arte do mapa em qualquer proporção de tela.

3. **UX & Seleção de Dificuldade Desobstruída ("Dark Premium Medieval")**:
   - As cartas de dificuldade possuem hitboxes responsivas calculadas em runtime via `_get_background_rendered_rect()`.
   - **Arte Limpa sem Textos Centralizados Sobrepostos**: Rótulos e badges redundantes no meio da tela foram completamente removidos (`btn_start_game.text = ""` e `_selection_badge.visible = false`). A arte cinematográfica oficial (`dificuldade.webp` vs `dificuldade_dificil.webp`) comunica o modo ativo de forma visualmente nobre através de crossfade suave e responsivo.
   - Atualização dinâmica da ação contextual mobile no dock inferior (`INICIAR NO MODO NORMAL` vs `INICIAR NO MODO DIFÍCIL`), garantindo resposta tátil imediata em cliques e toques.

3.1. **Regras de Navegação e Menu Principal (Desktop e Mobile)**:
   - **Opção 'Personagens' (`BtnCharSelect`)**: Desabilitada permanentemente tanto no modo Desktop quanto no Mobile (`disabled = true`). Clicar ou ativar a opção não executa ação nem transição.
   - **Opção 'Configurações' (`BtnSettings`)**: Habilitada na apresentação visual mobile e desktop, comportando-se a princípio como no-op ao ser clicada (sem travamento, sem ruído de recusa e sem alterar o estado do jogo, idêntica ao desktop).
   - **Menu de Mapa (`MapMenu`)**:
     - *Acesso via Menu Principal (Browse)*: Ao ser acessado através da opção "MAPA" do Menu Principal (`map_entry_context = "browse"`), o mapa atua em modo de consulta/visualização e o acionamento de qualquer botão, tecla ou toque na tela retorna diretamente ao Menu Principal (`res://scenes/ui/main_menu.tscn`).
     - *Acesso por Campanha / Outros Fluxos (Novo Jogo, Continuar, Próximo Mapa)*: Segue o fluxo canônico de jogo — permite navegar pela trilha com setas/cliques nas fases desbloqueadas, confirmação ([Enter], [Espaço] ou clique na fase) avança para a fase correspondente (`loading_screen.tscn` / `map_X.tscn`), e cancelar/voltar ([ESC] ou botão Voltar) retorna à tela de seleção de dificuldade (`difficulty_select.tscn`).
   - **Reinício Seguro de Fase (`Tecla [R]`)**: O recarregamento de cena (`reload_current_scene()`) é estritamente blindado contra erros de ciclo de vida. `EnemyHUD`, `EnemyAI`, `CombatDirector` e `CombatFeedback` possuem proteções de `is_inside_tree()`, garantindo que reiniciar uma fase com inimigos ainda vivos não gere erros de nós órfãos ou ponteiros nulos no console.

4. **Safe Area & Molduras de Diálogo**:
   - Molduras de diálogo (`NarrativeDirector`, `counter_card_interaction.gd`) utilizam âncoras relativas proporcionais e `AUTOWRAP_WORD_SMART`, impedindo quebras ou sobreposições com retratos e botões em telas ultrawide.
   - Botões interativos touch possuem tamanho mínimo de toque de **48 × 48 dp**.
   - Assets exportados em formato **WebP** transparente ou Q90 RGB, limitando o peso por tela a **< 1 MB**.

5. **Controles Mobile Oficiais Arcade Neon Dark Glass (`TouchControls`)**:
   - *Referência Visual Canônica*: Disposição, estética e acabamento baseados na composição oficial *Neon na Chuva*.
   - *Assets Dedicados em `assets/ui/mobile/`*:
     - `button_attack.png`: Punho cerrado de alta definição, aro circular em laranja/vermelho neon, interior vidro escuro translúcido. É o maior botão do conjunto. Mapeado para **Tecla J** (`attack` e `attack_punch`).
     - `button_kick.png`: Silhueta branca de voadora marcial, aro metálico azulado, interior vidro escuro translúcido. Mapeado para **Tecla SPACE** (`attack_aerial` e `jump`).
     - `button_special.png`: Ícone de corte de fogo/energia em gradiente branco/amarelo/laranja/vermelho, contorno com aura de chamas. Mapeado para **Tecla E** e **Tecla O** (`attack_special` e `special`).
     - `button_block.png`: Ícone de seta para cima em branco sólido, aro metálico azulado. Mapeado para **Tecla K** e **Tecla H** (`guard`).
     - `button_pause.png`: Quadrado com cantos arredondados, fundo azul-marinho translúcido, aro metálico azulado, duas barras verticais brancas paralelas. Posicionado no canto superior direito dentro da safe area.
     - `mobile_dpad_base.png`, `mobile_dpad_arrows.png`, `mobile_dpad_thumb.png`: Direcional analógico no quadrante inferior esquerdo com base circular translúcida ampliada (raio de 112px / diâmetro 224px), 4 setas indicadoras e knob central metálico ampliado (raio de 48px), calibrado para alta precisão e ergonomia no toque mobile.
   - *Disposição Assimétrica do Cluster de Combate*:
     - Canto inferior direito: Punho J (maior dimensão).
     - Acima do Punho (mesmo alinhamento horizontal X): Bloqueio K (seta para cima).
     - Inferior esquerdo do cluster: Voadora SPACE.
     - Região intermediária (entre Voadora, Bloqueio e Punho): Especial E.
   - *Multitouch Concorrente e Robustez*:
     - Suporte a múltiplos toques simultâneos com rastreamento independente por `touch_index`.
     - Movimentação diagonal no joystick simultânea a ataques, bloqueios ou voadora.
     - Manutenção do bloqueio enquanto aciona ataques.
     - Liberação atômica de todas as ações virtuais via `release_all_virtual_actions()` ao pausar ou ao sair da cena.
   - *Integração do Pause*:
     - O botão de pause congela a `SceneTree` (`get_tree().paused = true`), suspende os controles virtuais para evitar acionamentos acidentais e exibe o `PauseMenu`. Ao despausar, os controles touch são reativados suavemente.
     - O botão de pause é exclusivo de telas de gameplay (não aparece em menus nem telas estáticas).

6. **Arquitetura PWA Premium Mobile & Web Streaming (Vercel CDN + WebAssembly)**:
   - *Execução Web Direct & Zero Barreiras*: O jogo é plenamente acessível pelo link da Vercel em smartphones Android e iOS sem necessidade de instalação obrigatória de aplicativo, mantendo fluidez a 60 FPS no navegador.
   - *Orientação Mandatória Horizontal (Landscape)*:
     - Detecção instantânea via CSS `@media (orientation: portrait)` e listener em `screen.orientation`.
     - Ao detectar modo retrato, o canvas do jogo é coberto por um overlay arcade escurecido com mensagem pulsante *"Gire o celular para jogar na horizontal"* (`#rotate-overlay`), impedindo distorções, cortes verticais ou touch desalinhado.
   - *Banner de Instalação PWA Não-Intrusivo*:
     - No Android: intercepta o evento nativo `beforeinstallprompt`, suprime pop-ups agressivos do navegador e renderiza um botão flutuante arcade discreto (`#pwa-install-banner`) com opção de instalação rápida ou dispensa (`DISPENSAR`), persistida em `localStorage`.
     - No iOS Safari: exibe guia ilustrado e contextual orientando o usuário a tocar em *"Compartilhar"* (ícone de seta para cima) e selecionar *"Adicionar à Tela de Início"*.
   - *Desbloqueio Universal de Áudio Web/Mobile (`unlockOnUserGesture`)*:
     - Contorna as políticas restritivas de *Autoplay* dos navegadores móveis (Safari iOS e Chrome Mobile).
     - Monitora eventos `touchstart`, `touchend` e `click` na janela; no primeiro toque, executa `AudioContext.resume()` no motor de áudio WebAudio e libera o pipeline de som do Godot sem telas mudas.
   - *Persistência Garantida de Savegames (`navigator.storage.persist()`)*:
     - Na inicialização do runtime web, a API de armazenamento solicita persistência permanente (`navigator.storage.persist()`).
     - Blindagem dos saves locais em `user://` (`savegame.json`, desbloqueios de mapas, configurações de volume e recordes) contra o expurgo automático de cache por falta de espaço no navegador.
   - *Estratégia Híbrida de Cache do Service Worker (`public/index.service.worker.js`)*:
     - **Network-First para Navegação**: Requisições de página (`/`, `index.html`) sempre buscam primeiro a rede com fallback para cache. Isso garante que qualquer novo deploy na Vercel seja identificado de imediato pelo jogador, evitando que o celular fique preso em versões antigas.
     - **Cache-First para Binários e Assets**: Arquivos estáticos imutáveis (`.wasm`, `.pck`, `.webp`, `.ttf`, `.mp3`) utilizam cache local prioritário, reduzindo drasticamente o consumo do plano de dados móvel do jogador.
     - **Versionamento Canônico**: O Service Worker utiliza `CACHE_VERSION` vinculado ao hash do commit Git (ex: `dfdfb95c`), sincronizado automaticamente via `scripts/pwa_post_export.js`.

---

## 27. FORBIDDEN ARCHITECTURAL PATTERNS
`STATUS: IMPLEMENTED`

- ❌ **Singletons Globais Desnecessários**: Proibido criar autoloads globais sem estrita necessidade arquitetural.
- ❌ **Caminhos de Nós Hardcoded**: Proibido utilizar referências rígidas de caminho de árvore (ex: `$World/Entities/Player`).
- ❌ **Aglomeração de Inimigos (Dogpiling)**: Proibido fazer inimigos perseguirem o jogador sem respeitar os tokens e pistas de flanqueamento do `CombatDirector`.
- ❌ **Múltiplo Dano por Frame**: Proibido causar dano contínuo sem registro individual de acertos (`hit_targets`).
- ❌ **Avanço Prematuro de Fase**: Proibido ativar a saída ou acionar "SIGA →" com inimigos vivos ou reforços em trânsito.
- ❌ **Rebuild Global de Navegação**: Proibido executar `bake_navigation_polygon()` em runtime.
- ❌ **Vídeo na Tela de Abertura**: A tela de abertura utiliza exclusivamente imagem estática `main.webp` via `TextureRect`. Proibido o uso de `VideoStreamPlayer` ou formatos `.ogv`/`.gif`.
- ❌ **Chamada Desprotegida de Viewport**: Proibido invocar `set_input_as_handled()` após mudança de cena sem verificar `if get_viewport() != null:`.
- ❌ **Inimigos sem NavigationAgent2D**: Proibido instanciar inimigos sem navegação com RVO avoidance.
- ❌ **Geração Desnecessária de Imagens/Assets**: Proibido gerar imagens, texturas, variações gráficas ou arquivos visuais desnecessariamente sem solicitação expressa do desenvolvedor. Reutilizar rigorosamente os assets existentes no repositório, preservando a identidade visual, peso do pacote e integridade dos ponteiros de recursos.

---

## 28. EXTENSION GUIDELINES
`STATUS: IMPLEMENTED`

### Como Criar Novos Elementos sem Modificar a Arquitetura Central:
1. **Novo Inimigo (`Enemy.tscn`)**:
   - Herdar de `CharacterBody2D`, ancorar pés em `(0, 0)`, adicionar aos grupos `"actors"`, `"enemies"`, `"damageable"`.
   - Incluir nós: `CollisionShape2D` (Layer 1, Mask 2), `NavigationAgent2D`, `Visual`, `MeleeAttack` (Layer 8, Mask 4), `Hurtbox` (Layer 4, Mask 0), `HealthComponent`.
2. **Novo Chefe (`Boss.tscn`)**:
   - Estender `EnemyAI` (ou herdar de `boss_alessandro.gd`), resolução visual em 250×330px, calibrar timers de telegraph e recuo.
3. **Novo NPC (`NPC.tscn`)**:
   - Herdar de `BaseNPC`, adicionar aos grupos `"actors"`, `"npcs"`, `"damageable"`. Não incluir no grupo `"enemies"`.
4. **Novo Prop Destrutível (`Barrel.tscn`, `Crate.tscn`)**:
   - Instanciar a cena base `destructible_prop.tscn`, configurar `max_health`, sprites em `Visual` e cena de drop opcional.
5. **Novo Gatilho de Nível (`Trigger.tscn`)**:
   - Instanciar `LevelEventTrigger`, configurar `event_id`, máscara Layer 1 e conectar sinal `triggered`.

---

## 29. PALETTE SWAP SYSTEM (ENEMY VISUAL VARIANTS)
`STATUS: IMPLEMENTED`

### Propósito
Permite diferenciar visualmente inimigos do mesmo tipo (ex: Jogador de Magic) sem regenerar sprites. Utiliza um **CanvasItem Shader de Hue Shift seletivo** que rotaciona a matiz de uma faixa de cor alvo (casaco azul ≈ 220°) preservando pele, cabelo, calça e botas intactos.

### Arquivos
- **Shader**: `shaders/palette_swap.gdshader` — Shader com parâmetros `hue_shift`, `target_hue`, `hue_tolerance`, `min_saturation`, `saturation_adjust`, `value_adjust`.
- **Integração**: `scripts/actors/enemy_ai.gd` — Enum `PaletteVariant`, `@export palette_variant`, métodos `_apply_palette_swap()` e `set_palette()`.
- **SpawnPoint**: `scripts/spawning/spawn_point.gd` — `@export enemy_palette_variant: int` para injeção de paleta no spawn.

### Variantes Disponíveis (`EnemyAI.PaletteVariant`)
| Enum | Valor | Hue Shift | Cor Resultante |
|------|:-----:|:---------:|----------------|
| `ORIGINAL` | 0 | 0° | Azul original (sem shader) |
| `RED` | 1 | 140° | Casaco vermelho |
| `GREEN` | 2 | 260° | Casaco verde |
| `PURPLE` | 3 | 80° | Casaco roxo/magenta |
| `ORANGE` | 4 | 170° | Casaco laranja |
| `CYAN` | 5 | 320° | Casaco ciano/turquesa |
| `RANDOM` | 6 | Sorteio | Variante aleatória ao spawnar |

### Regras
1. **Performance**: Variante `ORIGINAL` não aplica shader (zero custo de GPU extra).
2. **Instância Única**: Cada inimigo recebe um `ShaderMaterial` próprio para permitir variações individuais na mesma cena.
3. **SpawnPoint Integration**: O campo `enemy_palette_variant` no SpawnPoint injeta a paleta antes de `_ready()`. Valor `-1` = usa o padrão da cena.
4. **Runtime API**: `set_palette(PaletteVariant)` altera a paleta em tempo de execução (buffs visuais, eventos).

---

## 30. ARCADE HUD & UI ARCHITECTURE CONTRACT
`STATUS: IMPLEMENTED`

### 1. Separação de Responsabilidade e Nova Identidade Visual:
- **Arte Canônica**: Baseada no modelo oficial `modelo_hud_vf.jpg` (2170×725px), com Pixel Art HD, acabamento profissional e estética arcade retrô dos anos 90.
- **Identidade Temática dos 4 Heróis**:
  - **Guilherme**: Azul elétrico (`#00A2FF`).
  - **Gabriel**: Verde neon (`#00FF66`).
  - **André**: Amarelo/Laranja ouro (`#FFCC00`).
  - **Juliana**: Magenta/Roxo neon (`#FF00CC`).
- **Remoção Canônica de Textos Numéricos e Nível**: A HUD **NÃO** exibe o nível do herói e **NÃO** exibe textos numéricos brutos como `100/100` ou `8/100`. As barras segmentadas falam visualmente por si mesmas em pura estética arcade.
- **Nome do Personagem com Destaque e Sem Duplicidade**: O banner do nome (`hud_name_frame_*.png`) posiciona-se no início da barra ao lado do retrato, ampliado e em alta definição. O rótulo em texto simples é ocultado para evitar sobreposição ou duplicidade.
- **Placa de Ficha (Continues) Ampliada**: Imagem da ficha com dados ampliada com destaque (`hud_continue_plate.png`/`.webp`), acompanhada do número dinâmico em tipografia arcade condizente (`assets/fonts/arcade_bold.ttf`, tamanho >= 26, contorno escuro e amarelo ouro).

### 2. Barras Segmentadas com Chassi Diagonal Cyber-Arcade:
- **Estrutura Segmentada**: As barras de Vida (HP) e Especial são compostas por exatamente **8 segmentos em paralelogramo inclinado**, desenhados proceduralmente pela classe `SegmentedBar`.
- **Chassi Diagonal e Efeitos Visuais**:
  - A moldura acompanha rigorosamente a mesma inclinação diagonal dos segmentos (`slant_offset`).
  - Trilho superior neon luminoso com reflexo arcade na cor temática do herói / barra.
  - Trilho inferior de sustentação e chanfros metálicos escuros laterais (`#04070C`).
- **Estados Visuais**:
  - **Preenchido**: Cor temática com chanfro superior luminoso (highlight) e sombra inferior/lateral (relevo arcade 3D). HP é estritamente vermelho arcade (`#FF1818`); Especial utiliza a cor temática do herói selecionado.
  - **Buffer (Dano de HP)**: Segmentos em tom âmbar suave (`#FFB833`) que sustentam temporariamente a perda de vida antes de transicionarem para vazio.
  - **Vazio**: Segmentos escuros grafite/marinho (`#151B27`) com contorno nítido (`#28364D`).
- **Contenção Geométrica Estrita (Zero Overflow)**: Nenhum segmento ultrapassa as bordas da moldura. Quantidade de segmentos:
  $$\text{segmentos\_preenchidos} = \text{floor}(\text{progresso\_normalizado} \times 8)$$
  com garantia de que heróis vivos retêm ao menos 1 segmento visível, e exatamente 0 apenas ao morrer.

### 3. Sistema de Especial: Carregamento Gradual e Ativação Restrita a 100%:
- **Carga Inicial e Máxima**: Inicia estritamente em **0.0** (`SPECIAL_INITIAL_CHARGE`), com teto em **100.0** (`SPECIAL_MAX_CHARGE`).
- **Taxa de Carregamento**: Concede exatamente **2.0 pontos** por acerto real e aceito pelo sistema de dano em inimigo vivo (`SPECIAL_CHARGE_PER_HIT`), exigindo ~50 acertos para carregar do zero.
- **Proteções de Integridade**:
  - Golpes que erram o alvo (whiffs) não geram carga.
  - Alvos no mesmo golpe não concedem carga duplicada (controle de acerto único por golpe).
  - Inimigos mortos, civis (NPCs) e o próprio jogador não concedem carga.
  - Dano infligido pelo próprio especial não recarrega o medidor.
- **Ativação Restrita (Gatekeeping em Gameplay)**: `execute_special()` só pode ser disparado quando o medidor estiver rigorosamente em **100%** (`current_special >= max_special`). Pressões com carga parcial não geram dano, nem animação cinematográfica, nem invulnerabilidade.
- **Substituição de Custo**: O custo antigo de 15% de HP foi extinto; especial consome 100% da barra de especial sem subtrair HP do herói.
- **Apresentação Cinematográfica do Especial (2,50s)**:
  - **Separação Arquitetural**:
    - `HeroData`: Recurso desacoplado com propriedades exportadas `special_presentation_texture` (arte oficial do golpe, ex: `especial_1_guilherme.webp`), `special_title` (opcional/vazio para não poluir a arte), `special_theme_color` e `special_presentation_duration` (= 2.5).
    - `SpecialPresentation`: Componente visual puro (`CanvasLayer`, layer 120) que realiza cobertura total da viewport em qualquer proporção sem distorção (`STRETCH_KEEP_ASPECT_COVERED` e `EXPAND_IGNORE_SIZE`), zoom dramático com pivot centralizado responsivo e efeito de flash de impacto. Não exibe banner de texto para valorização integral da arte do herói.
    - `PlayerController`: Coordena o fluxo de combate — valida medidor a 100%, consome a carga, concede invulnerabilidade, instancia a apresentação conectando o sinal `impact_reached` ao dano global nos inimigos vivos com queda obrigatória (`FALL`), preservando NPCs civis, e só restabelece o estado `NORMAL` após o sinal `finished`.
  - **Cronograma Temporal Sincronizado**:
    - 0,00s - 0,35s: Abertura cinematográfica (fade-in, zoom inicial suave e entrada da arte oficial).
    - 0,35s - 0,90s: Construção de energia e aproximação rápida (zoom progressivo de 1.0 para 1.06 e pulso da cor temática do herói).
    - 0,90s - 1,30s: Hold dramático do clímax visual (tensão máxima no ápice).
    - 1,30s: **Ápice do Impacto** — emissão estrita do sinal `impact_reached`, aplicação atômica do dano global e disparo do flash branco de tela (0,20s).
    - 1,50s - 2,00s: Respiro pós-impacto com dissipação de energia e acomodação de escala.
    - 2,00s - 2,50s: Saída cinematográfica e recolhimento visual.
    - 2,50s: Emissão idempotente de `finished`, destruição limpa do nó (`queue_free()`) e retorno do herói a `NORMAL`.

### 4. Efeito de Aura Elétrica de Especial Pronto:
- **Aura Neon Pulsante**: Ao atingir 100%, o retrato do personagem recebe uma aura de energia elétrica azul animada (`hud_electric_aura.png`), pulsando suavemente ao redor da moldura.
- **Desativação Instantânea**: Ao consumir o especial ou se a carga cair abaixo de 100%, a aura é desligada imediatamente.

### 5. Indicador Dinâmico de Combo (Grafite Agressivo e Alta Escala):
- **Visibilidade Dinâmica**: Oculto com 0 hits (`hits <= 0`). Visível com acertos reais confirmados, acompanhado de animação arcade de impacto (punch de escala 1.35 → 1.0). Placa de combo em estética de grafite agressivo (`hud_combo_plate.png`) com número dinâmico em tipografia arcade condizente (`arcade_bold.ttf`).

### 6. Persistência de Vida e Energia Entre Seções do Mesmo Mapa:
- **Regra de Continuidade**: Dentro do mesmo mapa/fase (ex: seções de `Fase 1` - Mapas 1 a 4), a vida (`current_health`) e energia especial (`current_special`) acumuladas são preservadas entre transições via `GameSession.save_player_progression()` e restauradas no carregamento da nova seção.
- **Reset em Novo Mapa**: Ao transicionar para um mapa de outro grupo ou reiniciar a partida, a vida e energia são redefinidas para os valores padrão.

### 7. Indicador "SIGA →" com Acompanhamento de Câmera:
- **Comportamento Dinâmico**: Ao derrotar o último inimigo de um encontro, o banner estático de texto central ("Área Limpa") é suprimido, e o indicador visual piscante "SIGA →" é ativado na tela, acompanhando a posição da câmera para permanecer visível independentemente de onde o personagem estiver no cenário.

---


### 8. Menu Principal: Navegação Fluida e Confirmação Estroboscópica (Game UX):
- **Eliminação Permanente dos Chevrons (`<<` e `>>`)**: Chevrons visuais foram eliminados tanto no Desktop quanto no Mobile. O menu preserva visual limpo e sofisticado "Dark Premium Medieval", sem poluição gráfica sobre a tipografia clássica da arte `menu_state_vf.webp`.
- **Navegação e Escolha Fluida (Hover / Browsing)**:
  - **Desktop**: A pincelada dourada (`BrushHighlight`) desliza suavemente entre as opções (0.10s via `Tween.TRANS_CUBIC`, `EASE_OUT`) ao mover com teclado (Setas/WASD) ou hover do mouse, acompanhada de áudio arcade suave (`_sfx_move`). Em repouso, exibe pulsação orgânica de respiração (opacidade 0.70 <-> 1.00). Opções desabilitadas (ex: Configurações) exibem tonalidade grafite sutil (`Color(0.55, 0.55, 0.60, 0.45)`).
  - **Mobile**: Em repouso, a tela permanece 100% limpa (`brush_highlight.visible = false`) sem obstruir a arte. O realce surge de forma reativa e imediata ao primeiro toque sobre qualquer opção.
- **Feedback Estroboscópico de Confirmação (Arcade Strobe Flare)**:
  - Ao confirmar uma opção (Enter/Espaço/Clique no PC ou Toque no Mobile), a pincelada dourada executa uma sequência em 4 etapas:
    1. Pico de impacto luminoso em branco-ouro (`Color(2.6, 2.3, 1.4)`) com micro-punch de escala tátil (1.03x horizontal, 1.08x vertical) em 0.05s.
    2. Queda rápida de contraste (strobe dip, 0.05s).
    3. Segundo flash de confirmação brilhante (0.05s).
    4. Assentamento estável em ouro luminoso (0.08s) e reprodução do som canônico de confirmação (`_sfx_confirm`).
- **Zero Molduras Retangulares**: Não é criada nenhuma caixa retangular ou contorno `StyleBoxFlat` ao redor dos botões (permanecem estritamente transparentes).
- **Opções Desabilitadas (Recusa Clara)**: Feedback em flash âmbar/vermelho rápido (`Color(2.0, 0.4, 0.3)`), som de recusa (`_sfx_denied`) e micro-shake de tela, informando intuitivamente a indisponibilidade.
- **Janela de Respiro Pré-Transição**: Pausa calculada de 0.35s após o flash antes da troca de cena, permitindo que o jogador absorva o feedback de confirmação visual e auditivo.

---

## 31. DEFINITION OF DONE (DOD)
`STATUS: IMPLEMENTED`

Uma funcionalidade, refatoração ou evolução arquitetural só pode ser considerada **CONCLUÍDA** quando todos os itens abaixo forem rigorosamente satisfeitos:

```text
[x] Código implementado e modular (composição sobre herança)
[x] GDScript fortemente tipado (variáveis, parâmetros e retornos)
[x] Cenas válidas e livres de erros de parsing
[x] Referências de nós dinâmicas e desacopladas (sem caminhos rígidos)
[x] Camadas e máscaras de colisão verificadas (Layers 1 a 5)
[x] Malha e agentes de navegação verificados (sem rebuild global em runtime)
[x] Testes headless focados do componente executados com 100% de sucesso
[x] Bateria de regressão completa (21 suítes) executada sem falhas (para marcos/releases)
[x] Auditoria de performance a 60 FPS aprovada (desktop e mobile)
[x] Nenhuma regressão conhecida em combate, IA, mapas ou UI
[x] GAME_RULES.md atualizado refletindo estritamente a realidade do código
```

---

## 32. SPRITE VISUAL CONTRACT & ANIMATION QA SUITE
`STATUS: IMPLEMENTED`

### 1. Diretrizes de Geometria e Formato dos Sprites:
- **Resolução & Canvas Fixo**: Todos os conjuntos de sprites de heróis e capangas devem ser entregues em canvas fixo de **220 × 300 px** com fundo transparente (canal alfa RGBA ativo), salvo poses deitadas no solo (`death`, `fall_03`) que admitem largura estendida de até 260 px.
- **Ancoragem de Chão e Linha de Base**: Ponto de contato dos pés consistente, tangenciando a linha inferior do canvas ($Y = 300$, correspondendo a $Y = 0$ no espaço local 2.5D) com tolerância de até 20 px para poses de passada e salto.
- **Escala e Transformações**: Proibida qualquer distorção procedural de escala vertical durante golpes. A inversão de direção (flip horizontal) deve alterar estritamente o sinal de `scale.x`, mantendo `abs(scale.y) == 1.0`.

### 2. Suíte de Testes Automatizados Headless (`tests/player_animation_contract_test.gd`):
- **Validação de Imagens**: Varre o diretório de sprites e confirma dimensões (220×300 px), canal alfa e contagem mínima de recursos.
- **Validação de Linha de Base**: Inspeciona a caixa delimitadora (`used_rect`) e afere o gap de contato com o solo em todas as animações terrestres.
- **Validação de SpriteFrames**: Checa nomes canônicos, contagem exata de quadros (incluindo 6 quadros em `heavy`), flags de loop e taxas de FPS.
- **Estabilidade Geométrica da Cena**: Verifica nós visuais, ausência de deslocamento de compensação física e integridade de escalas no ataque e flip.
- **Revisão Visual Complementar**: Folha de contato / verificação manual no Godot para validação estética de poses e fluidez cinética.

---

## 33. MAP PROGRESSION & LEVEL TRANSITION ARCHITECTURE
`STATUS: IMPLEMENTED`

### 1. Transição de Campanha e Desbloqueio em Duas Etapas:
- **Etapa 1 (Ponto 1 -> Bônus 1)**: Após a conclusão do mapa 1-4 (`map_4.tscn`), a transição cinemática de mapa exibe `Mapa.webp`, anima a seta branca saindo do Ponto 1 (`Vector2(240, 348)`) e percorrendo a rota até o Ponto Bônus intermediário (`Vector2(578, 282)`). O Ponto 1 é coberto proceduralmente, e a cena seguinte é a fase bônus (`bonus_garage.tscn`).
- **Etapa 2 (Bônus 1 -> Ponto 2)**: Após a conclusão da fase bônus da garagem (`bonus_garage.tscn`), a transição cinemática parte do Ponto Bônus (`Vector2(578, 282)`), segue pelo trajeto até o Ponto 2 (`Vector2(870, 265)`), onde o cadeado é removido e a Fase 2 é oficialmente desbloqueada no `GameSession`.
- **Posicionamento Canônico da Seta no Bônus**: A seta de repouso e parada no Ponto Bônus está fixada estritamente em `Vector2(578, 282)`, repousando diretamente no topo do círculo vermelho sem cobrir o ícone de presente.
- **Persistência de Progresso no Menu de Mapa (`map_menu.tscn`)**:
  - Início do Jogo: Seta sobre Ponto 1 (`Vector2(240, 348)`), cadeado no Ponto 2 visível.
  - Bônus Desbloqueado: Seta sobre Ponto Bônus (`Vector2(578, 282)`), Ponto 1 coberto, cadeado no Ponto 2 visível.
  - Fase 2 Desbloqueada: Seta sobre Ponto 2 (`Vector2(870, 265)`), Ponto 1 coberto, cadeado do Ponto 2 removido.

### 2. Indicador "VAMOS, MALACOS!" (`SigaIndicator`):
- Todos os mapas de combate (`map_1.tscn`, `map_2.tscn`, `map_3.tscn`, `map_4.tscn`, `bonus_garage.tscn`) possuem o nó `SigaIndicator` instanciado.
- Ao limpar o encontro (`_on_encounter_cleared()`), `SigaIndicator.activate()` projeta o banner estilizado `vamos.webp` com animação de impacto e pulso contínuo arcade, sinalizando que a saída está livre para avanço.

### 3. Ponto de Reaparecimento Esquerdo no Mapa 1 (`SpawnPoint_Left`):
- Posição canônica calibrada: `Vector2(408, 557)`. Protegida contra reversões acidentais para coordenadas obsoletas fora da área útil.

---

## 34. ENEMY HUD PURITY & CINEMATIC INTRO EFFECTS
`STATUS: IMPLEMENTED`

### 1. Pureza Visual dos Inimigos (Remoção da Barra Flutuante Cinza):
- Todas as barras de vida suspensas/discretas (`FloatingHealthBar`) sobre capangas (`basic_enemy.tscn`) e chefes (`boss_alessandro.tscn`) foram desativadas (`visible = false`).
- A indicação de integridade física dos adversários é provida com exclusividade pela HUD Principal Superior (`PrototypeHud` / `EnemyHUD`), preservando a estética arcade limpa sem poluição visual sobre as silhuetas dos sprites.

### 2. Efeitos Cinemáticos da Introdução Narrativa (Fase 1):
Em estrita conformidade com o roteiro oficial (`Roteiro Introdução Fase 1.docx`):
- **CENA 01 (Título)**: Fade In suave de "Saka's" (0.5s), breve pausa, Fade In de "A ÚLTIMA FICHA" (0.5s), hold de 2s e Fade Out suave para o preto (0.5s).
- **CENA 02 (Os Quatro)**: Fade In lento da arte (0.8s) com zoom suave contínuo de 100% para 103% (`Vector2(1.03, 1.03)`).
- **CENA 03 (Os Que Não Estão)**: Crossfade atmosférico (0.45s) com disparo de glitch analógico de 3 frames simbolizando a falha de memória.
- **CENA 04 (A Sala Secreta)**: Fade In com pulsação sinusoidal lenta e contínua de luz âmbar/azulada de monitores CRT (`_crt_flicker_tween`).
- **CENA 05 (A Máquina)**: Fade In CRT com surto enérgico de brilho por 0.3s (sem blur), micro-jitter horizontal de 3px e pulso de luminosidade a cada linha do arcade.
- **CENA 06 (Passado e Presente)**: Crossfade temporal com glitch curto de 2 frames e micro-distorção horizontal a cada avanço de texto.
- **CENA 07 (Retorno à Locadora)**: Crossfade ultrarrápido (0.16s) entre as falas dos personagens para dinâmica ágil de diálogo arcade.

---

## 35. CANONICAL DROPPED ITEMS & PICKUPS ARCHITECTURE (2.5D)
`STATUS: IMPLEMENTED`

Todo e qualquer item dropado no jogo (consumíveis de cura, colecionáveis narrativos, cartas, revistas, armas ou moedas) DEVE obrigatoriamente seguir a padronização arquitetural, visual e de interação estabelecida por este contrato, sem exceções.

### 1. Componente Modular Reutilizável (`DroppedItemVisuals`)
- **Obrigatoriedade**: Todo item dropado DEVE instanciar e ser gerenciado pelo componente canônico `scripts/items/dropped_item_visuals.gd`.
- **Proibição de Código Paralelo**: É terminantemente proibido recriar sombras manuais, polígonos avulsos ou rotinas duplicadas de partículas e flutuação dentro de scripts individuais de pickups.

### 2. Normalização Canônica da Base Visual no Solo (2.5D & Y-Sort)
- **Princípio da Linha de Solo em $Y = 0$**: No motor 2.5D do Sakas, a origem local da cena raiz $(0, 0)$ representa estritamente o plano de contato físico com o chão (*feet on the ground* / linha de Y-sorting).
- **Normalização Automática (`normalize_target_base`)**:
  - Elementos visuais (`Sprite2D`, `AnimatedSprite2D` ou nós contêineres) jamais podem ter sua metade inferior atravessando o solo (evitando que a aura corte o meio do sprite, como ocorria originalmente na revista).
  - O método `DroppedItemVisuals.normalize_target_base()` detecta dinamicamente a geometria do sprite e garante que sua base inferior descanse na linha do solo com folga controlada ($Y = -ground\_clearance$, padrão de 2.0px).
- **Imutabilidade da Raiz Física (Blindagem do Y-Sort)**:
  - A raiz física (`Node2D` / `Area2D`) e o nó âncora `GroundAnchor` (com a sombra e a aura) permanecem rigorosamente estáticos em $(0, 0)$ no mundo.
  - O efeito senoidal de flutuação (*bobbing*) e pulso luminoso ocorre **exclusivamente na coordenada local Y do nó visual filho** (`target_visual.position.y`), nunca na raiz física.

### 3. Identidade Visual e Fidelidade Pixel Art HD
- **Sombra Fixa no Solo**: `Polygon2D` elíptico achatado em $(0, 0)$ com cor escura (`Color(0.02, 0.03, 0.06, 0.48)`), desacoplado da flutuação.
- **Aura Luminosa de Solo**: `Polygon2D` elíptico projetado com mistura aditiva (`CanvasItemMaterial.BLEND_MODE_ADD`), garantindo contraste legível com o calçamento urbano escuro.
- **Identidade Cromática por Categoria**:
  - **Consumíveis de Vida / Cura (`CocaPickup`)**: Verde ou verde-limão (`Color(0.25, 0.95, 0.40)`).
  - **Colecionáveis Narrativos / História / Especiais (`Revistas`)**: Dourado ou âmbar (`Color(0.98, 0.78, 0.22)`).
- **Partículas Procedurais**: Emissor moderado `CPUParticles2D` com brilhos ascendentes suaves e fade-out gradiente.
- **Animação de Ejeção (*Spawn Arc*)**: Transição elástica via `Tween` simulando a expulsão do item de dentro do prop destrutível e assentamento suave no solo.
- **Estética Rasterizada**: Todos os elementos devem manter `TEXTURE_FILTER_NEAREST`, sem blur bilinear ou deformações.

### 4. Contrato de Interação e Acessibilidade UX (PC & Mobile)
- **Texto Canônico Padronizado**: O botão de prompt deve exibir estritamente a string `"Pegar"`. É terminantemente proibido exibir `"J - Pegar"`, `"J - PEGAR"`, `"Pressione J"` ou qualquer indicação de tecla na interface.
- **Área de Toque Mobile**: Área interativa mínima de 48 × 48 dp (tamanho base 96 × 48 px no viewport; se a raiz possuir escala reduzida, o botão deve aplicar compensação de escala inversa, ex: escala 2.0 para raiz 0.5).
- **Controle Duplo (Toque & Teclado/Gamepad)**:
  - Mobile: toque direto no botão `PickUpHint` aciona a coleta imediata (`pressed`).
  - Desktop/Gamepad: a aproximação 2.5D registra o item como interactable no `Player`, e a tecla `J` (ou botão de ataque do controle) aciona `interact(player)`.
- **Arbitragem de Prompt Único**:
  - Todos os itens dropados interativos pertencem ao grupo canônico `"interactive_dropped_pickups"`.
  - Quando múltiplos itens estiverem simultaneamente ao alcance do herói, o botão "Pegar" deve ficar visível **apenas no item mais próximo** (distância euclidiana ao jogador), evitando sobreposição e poluição na tela.
- **Regra de Vida Cheia para Consumíveis**:
  - Itens de cura (`CocaPickup`) não devem exibir o botão "Pegar" nem aceitar comandos de coleta se o jogador já estiver com vida máxima (`current_health >= max_health`).
- **Camada Visual Dianteira (Z-Index)**:
  - O botão de prompt `PickUpHint` deve configurar `z_index = 100` e `z_as_relative = false` e posicionar-se acima do topo do sprite normalizado, impedindo que o Y-Sort do chão o oculte atrás de fragmentos de caixas ou mobílias.




