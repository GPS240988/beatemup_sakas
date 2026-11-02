# Arquitetura Técnica — Beat 'em Up 2.5D

## 1. Visão Geral
Este projeto estabelece a fundação técnica e o ciclo básico de combate para um jogo beat 'em up para um jogador desenvolvido na Godot Engine 4.x, utilizando GDScript tipado e perspectiva 3/4 com ordenação dinâmica em profundidade (2.5D em plano 2D).

---

## 2. Árvore de Cenas e Estrutura de Arquivos

```text
res://
├── project.godot                          # Configurações do motor (1280x720, Nearest filter, Input Map)
├── README.md                              # Guia de execução e controles
├── docs/
│   └── architecture.md                    # Esta documentação técnica
├── scenes/
│   ├── main/
│   │   └── main.tscn                      # Ponto de entrada (carrega test_street)
│   ├── levels/
│   │   └── test_street.tscn               # Cenário de teste (área caminhável, limites, Y-sort, câmera)
│   ├── actors/
│   │   ├── player/
│   │   │   └── player.tscn                # Personagem jogável (CharacterBody2D + Health + MeleeAttack)
│   │   ├── enemies/
│   │   │   └── basic_enemy.tscn           # Inimigo de teste (CharacterBody2D + Health + MeleeAttack + HUD flutuante)
│   │   └── props/
│   │       └── sorting_dummy.tscn         # Objeto de teste de profundidade (StaticBody2D)
│   └── ui/
│       └── prototype_hud.tscn             # Interface desacoplada em CanvasLayer com barras de HP e banners
├── scripts/
│   ├── actors/
│   │   ├── player_controller.gd           # Movimentação 2.5D, comando de ataque e estados
│   │   └── enemy_ai.gd                    # FSM do inimigo (IDLE, CHASE, ATTACK, HURT, DEAD)
│   ├── components/
│   │   ├── health_component.gd            # Componente de vida, dano e sinalização de derrota
│   │   └── melee_attack.gd                # Componente de ataque corpo a corpo 2.5D
│   ├── levels/
│   │   └── test_street.gd                 # Orquestração do nível, conexões e reinício com tecla R
│   └── ui/
│       └── prototype_hud.gd               # Controle das barras de vida e avisos da interface
└── tests/
    └── combat_smoke_test.gd               # Suite de testes automatizados headless (25 cenários)
```

---

## 3. Convenções Espaciais 2.5D e Ordenação por Y (Y-Sort)

### Ponto de Contato com o Chão (Origem `0, 0`)
1. **Origem do Nó**: A coordenada local `(0, 0)` de qualquer ator (`Player`, `BasicEnemy`) ou prop (`SortingDummy`) representa **exatamente o ponto onde os pés tocam o solo**.
2. **Representação Visual**: O nó `Visual` estende-se para cima (`Y < 0`).
3. **Colisão Física**: Restrita à área de pegada dos pés (`Y` próximo a 0).
4. **Sombra**: Ancorada na origem `(0, 0)` em tom semitransparente.

### Mecanismo de Ordenação por Profundidade
- O nó `World/Entities` possui `y_sort_enabled = true`.
- Elementos com menor Y são desenhados atrás; elementos com maior Y são desenhados à frente.
- O cenário de fundo utiliza `z_index = -10` e a área caminhável `z_index = -5`, permanecendo sempre sob os personagens.
- A interface (`PrototypeHud`) roda em um `CanvasLayer` independente.

---

## 4. Sistema de Combate 2.5D

### 4.1 Componente de Vida (`HealthComponent`)
- Desacoplado e reutilizável por jogador e inimigos.
- `max_health`, `current_health` e `is_dead`.
- Método `take_damage(amount: float) -> bool`:
  - Protege contra valores negativos de vida.
  - Se `is_dead == true`, ignora novos danos.
  - Dispara o sinal `died` uma única vez ao atingir 0 de vida.
- Emite `health_changed(current, max_health)` e `damaged(amount)`.

### 4.2 Componente de Ataque Corpo a Corpo (`MeleeAttack`)
Executa o golpe e valida as **6 Regras de Acerto no Espaço 2.5D**:
1. **Alvo Vivo**: O alvo possui `HealthComponent` e `not is_dead`.
2. **Alcance Horizontal**: Distância horizontal `abs(target_x - attacker_x) <= horizontal_range`.
3. **Tolerância de Profundidade Y**: Diferença de profundidade dos pés `abs(target_y - attacker_y) <= depth_tolerance`.
4. **Direção (Facing)**: O alvo está à frente do atacante na direção do golpe (`forward_distance >= -10.0`).
5. **Janela Ativa**: O golpe está dentro da janela de acerto (`is_active_window == true`, durando `active_duration`).
6. **Alvo Único por Golpe**: Alvos atingidos são registrados em `hit_targets: Array[Node]` e ignorados em verificações subsequentes da mesma execução, impedindo danos repetidos indesejados.

### 4.3 Inteligência Artificial do Inimigo (`EnemyAI`)
Máquina de estados finita explícita (`enum State { IDLE, CHASE, ATTACK, HURT, DEAD }`):
- `CHASE`: Aproxima-se do jogador nos eixos X e Y sem tremer ou oscilar.
- `ATTACK`: Ao alinhar em X e profundidade Y, para e executa o ataque com cooldown.
- `HURT`: Ao sofrer dano, cancela ataques em andamento, pisca em vermelho e sofre um recuo suave (knockback).
- `DEAD`: Ao atingir 0 HP, desativa a IA, cancela ataques, desativa colisões e adota o visual deitado no chão.
- `IDLE`: Se o jogador morrer, o inimigo interrompe perseguição e ataques.

---

## 5. Interface e Reinício da Fase

- **HUD**:
  - Barra de vida em tempo real para o Jogador (`100/100 HP`).
  - Barra de vida em tempo real para o Inimigo (`80/80 HP`), complementada pela barra flutuante acima de sua cabeça.
  - Banners centrais comunicando vitória ("INIMIGO DERROTADO!") ou derrota ("VOCÊ FOI DERROTADO!").
- **Reinício**:
  - Tecla `R` configurada no Input Map (`restart`).
  - Recarrega a cena via `get_tree().reload_current_scene()`, restaurando posições, timers, estados e vidas sem persistência residual.

---

## 6. Próximos Passos (Etapa Futura 3 — Animações e Sprites)

1. Substituição dos nós geométricos `Visual` por nós `AnimatedSprite2D` em pixel art HD.
2. Sincronização dos quadros de animação com a abertura e fechamento da janela ativa de `MeleeAttack`.
3. Inclusão de efeitos visuais de impacto (hit sparks em pixel art) nas coordenadas de acerto.
4. Adição de combos básicos (cadeia de 2 ou 3 socos antes do knockdown).
