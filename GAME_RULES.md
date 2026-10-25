# 📜 GAME_RULES.md — DIRETRIZES MESTRAS DO PROJETO SAKAS (BEAT 'EM UP 2.5D)
Act as a senior video game art director, professional character designer, and expert pixel artist specializing in high-quality 2D and 2.5D beat 'em up games."*
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
   - Sprites nativos de heróis e capangas em **220×300px** (`scale = Vector2(0.80, 0.80)` atingindo ~240px de altura final); chefes em **250×330px** com pés estritamente em `(0, 0)`.
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
  - Cenas de fases: `scenes/levels/map_1.tscn`, `map_2.tscn`, `map_3.tscn`, `map_4.tscn`.
  - Cenas de atores: `scenes/actors/player/player.tscn`, `scenes/actors/enemies/basic_enemy.tscn`, `scenes/actors/enemies/boss_alessandro.tscn`, `scenes/actors/npc.tscn`.
  - Cenas de props: `scenes/props/destructible_prop.tscn`.
  - Cenas de UI: `scenes/ui/title_screen.tscn`, `main_menu.tscn`, `character_select.tscn`, `loading_screen.tscn`, `prototype_hud.tscn`.
  - Recursos de navegação: `scenes/levels/map_1_navpoly.tres` a `map_4_navpoly.tres`.
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
  ├── HealthComponent (Node desacoplado para HP e sinais de dano)
  ├── Effects (Node2D contendo nós CPUParticles2D e AudioStreamPlayer2D)
  └── NavigationIntegration (NavigationObstacle2D para desvio dinâmico sem rebake)
  ```
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
    - O Finisher desfere impacto máximo e derruba o inimigo (`can_knockdown = true`).
    - Possui janela real de encadeamento (`combo_window`) escalonada pelo atributo Técnica e buffer de entrada (`_input_buffered`) que permite encadear golpes durante o recovery.
  - **Botão Exclusivo de Especial** (`attack_special` / `special`):
    - Dispara evento global de combate consumindo 15% do HP máximo (sem matar o jogador se HP <= 15).
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
  - **Hitstop Local**: Pausa de física e visual local do atacante e vítima (3 a 6 frames) sem congelar a árvore nem travar HUD/Mobile.
  - **Screen Shake**: Tremor suave e amortecido de câmera nos golpes pesados, finalizadores e especial.
  - **Faíscas e Partículas (CPUParticles2D + AnimatedSprite2D)**: Faíscas em Pixel Art HD (`impacto`, `impactoazul`, `combinado`) combinadas com partículas direcionais de alta velocidade e poeira de solo (`poeira`).
  - **Padronização da Altura de Impacto**: Golpes e faíscas NUNCA devem ser instanciados nos pés/canelas ($Y = -35$ a $-40$). A altura canônica do impacto de combate situa-se no tronco/peito do alvo:
    - Preferencial: `target_hurtbox.global_position` (quando o alvo possuir nó `Hurtbox`).
    - Fallback: `target.global_position + Vector2(0.0, -85.0)` (e $Y = -90.0$ para impactos de guarda).
- **Vitória do Encontro (`encounter_cleared`)**:
  - Ocorre estritamente quando `alive_enemies.is_empty()` **E** `pending_spawns_count == 0` **E** não houver chefe configurado pendente de spawn.

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
