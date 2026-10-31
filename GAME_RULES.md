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
Beat 'em up 2.5D arcade clássico inspirado nos títulos dos anos 90, com ambientação urbana em Vila Prudente, São Paulo (ruas, locadoras de videogame, bares e becos), estética Pixel Art HD, profundidade no eixo Y e física determinística em Godot Engine 4.x (`4.7.2.stable`).

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
    - Exibe apresentação visual cinematográfica rápida (0.35s - 0.50s) com frames existentes do herói e tema de cor próprio.
    - Aplica dano global e queda obrigatória em todos os inimigos vivos do encontro, preservando NPCs civis.
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
      - Os frames originais de faíscas de impacto (`assets/sprites/Efeitos/` em canvas 195×196) possuem o miolo da explosão no quadrante superior esquerdo (~55, ~64) e não no centro geométrico da textura (97.5, 98.0).
      - `CombatFeedback.spawn_hit_spark()` aplica compensação local de offset (`visual_offset = Vector2(43, 35)` para punch/kick, `Vector2(21, 26)` para finisher, `Vector2(46, 27)` para especial) e espelhamento horizontal via `scale.x = sprite_scale * facing_sign`.
      - Isso garante que a faísca visual coincida rigorosamente com o ponto de impacto no corpo do alvo em ambos os lados, eliminando a assimetria onde golpes para a direita pareciam detonar no atacante.
    - **Garantia de Dano Único**: Um ataque que intersecta múltiplas regiões do mesmo alvo aplica dano estritamente uma única vez (`hit_targets.append(target_actor)`).
    - **Suíte de Validação**: `tests/anatomical_combat_impact_test.gd`.
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

- **Sistema Declarativo de Narrativa Cinemática (`StoryEvent`, `StorySequence`, `NarrativeDirector`)**:
  - **Padrão Oficial de Apresentação Arcade (Neo-16-bit Urbano)**:
    - *Referência Visual Obrigatória*: Baseado na composição canônica de `assets/backgrounds/referencia_introducao.webp`.
    - *Enquadramento e Área Segura*: O palco de arte (`ArtStage`) ocupa os 74% superiores da tela com modo `STRETCH_KEEP_ASPECT_CENTERED` e `TEXTURE_FILTER_NEAREST`. As imagens mantêm 100% da proporção original sem corte de personagens nas bordas. Camada de fundo ambiente (`AmbientBackground`) preenche aspectos de tela variáveis sem barras vazias. A moldura inferior nunca encobre rostos, mãos, pés ou silhuetas essenciais.
    - *Moldura Oficial Cyber-Brawler Glassmorphism*: Painel em azul-marinho profundo/violeta `#0C0C18` (94% opacidade) com borda neon rosa/magenta `#FF2A6D` (3px), cantoneiras metálicas em ciano `#05D9E8` e magenta, barra de status de transmissão, badge superior flutuante para o orador e sombra projetada neon.
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
      6. *CENA 06 (Passado e Presente - Revelação Central)*: Imagem `assets/story/map_1/past_present.webp`, telas mostrando lugares conhecidos com passado e presente ocupando o mesmo espaço físico.
      7. *CENA 07 (Retorno à Locadora)*: Imagem `assets/story/map_1/street_memory.webp`, transição com a identificação "MAPA 1 — A LOCADORA" e entrada suave no gameplay de `map_1.tscn`.
  - **Diretor de Apresentação (`NarrativeDirector`)**:
    - Instanciado em `CanvasLayer` superior (layer = 120), preservando a cena de gameplay intacta ao fundo.
    - Suporte integral a Teclado, Gamepad, Mouse e Toque Mobile (`InputEventScreenTouch`).
    - Botão visual "PULAR ⏩" no canto superior e comando [ESC] para pular a sequência completa a qualquer momento.
    - Efeitos sonoros procedurais autônomos (`_create_wav`, `_create_noise_wav`): zumbido analógico grave, chime de nostalgia e estática de glitch.
  - **Integração de Sessão e Salvamento**:
    - Novo Jogo inicia com `GameSession.has_played_intro = false`, garantindo a exibição na transição pós-instruções.
    - Ao concluir ou pular, `has_played_intro` é definido como `true`.
    - Ao carregar jogo salvo (CONTINUAR via `load_game_from_slot`), `has_played_intro = true` é ativado de imediato, garantindo que o prólogo **NÃO** seja reproduzido novamente.

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

## 26. MOBILE CONSTRAINTS
`STATUS: IMPLEMENTED`

1. **Suporte Touch Nativo Sob Demanda**:
   - A HUD (`prototype_hud.tscn`) suporta alternância para controles virtuais na tela (`TouchControls`).
   - Botões interativos possuem tamanho mínimo de toque de **48 × 48 dp**.
2. **Safe Area Touch**:
   - Elementos essenciais de controle e interface devem residir dentro dos 90% centrais da tela (5% de margem em cada borda), evitando interferência com notch, cantos arredondados ou barras de navegação do sistema operacional.
3. **Orçamento e Otimização de Assets**:
   - Viewport nativo 1280×720 (16:9 widescreen) com preenchimento letterbox/pillarbox via `DarkBase`.
   - Assets exportados em formato **WebP** transparente ou Q90 RGB, limitando o peso por tela a **< 1 MB**.

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



