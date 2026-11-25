# Pizza Brawler — Guia Técnico de Integração (Map 7 / HAPPEN)

## 1. Visão Geral
`PizzaBrawler` (`scripts/actors/pizza_brawler.gd`) estende `EnemyAI` para o salão principal da pizzaria HAPPEN (`scenes/levels/map_7.tscn`). O mapa conta com **7 instâncias**: 6 capangas sentados em todas as cadeiras das duas mesas (`IdleRoutine.SITTING`) e 1 capanga de costas no balcão de pizzas pegando comida (`IdleRoutine.COUNTER_EATING`), todos com diversidade real de arquétipos (`GRUNT`, `AGGRESSOR`, `TANK`, `FLANKER`), paletas de uniforme e efeito contínuo/reativo de gordura na pele.

## 2. Arquivos Principais
- `assets/sprites/characters/inimigos/pizza_brawler/spritesheet_gorducho_vf.png` — Spritesheet fonte original preservado.
- `assets/sprites/characters/inimigos/pizza_brawler/frames/` — **46 quadros individuais** `240×220` RGBA recortados sem bleeding (`sit_idle_01..06`, `counter_eat_01..05`, `getup_01..06`, `idle_01..04`, `walk_01..06`, `attack_01..06`, `hurt_01..04`, `fall_01..04`, `downed_01`, `death_01..04`).
- `scenes/actors/enemies/pizza_brawler_frames.tres` — `SpriteFrames` com as 14 animações esperadas pelo `EnemyAI` e rotinas do `Map 7`.
- `shaders/palette_swap.gdshader` e `scripts/actors/enemy_ai.gd` — Suporte configurável a `primary_palette_source_hue = 0.0` (uniforme vermelho), `preserve_original` e brilho oleoso pixelado na pele (`oil_sheen_strength`).
- `scripts/actors/pizza_brawler.gd` e `scenes/actors/enemies/pizza_brawler.tscn` — Máquina de despertar (`SITTING`/`COUNTER_EATING` → `GETTING_UP` → `COMBAT`), liberação limpa da colisão de mobília via `step_out_offset`, `GreaseParticles` e `GreaseBurstParticles`.
- `scenes/levels/map_7.tscn` e `scripts/levels/map_7.gd` — Posicionamento nas 6 cadeiras + balcão de pizzas e perfil permitindo os 4 arquétipos.
- `tests/test_pizza_brawler.gd` — Suíte headless de 64 verificações.

## 3. Validação Headless
```powershell
godot_console --headless -s tests/test_pizza_brawler.gd
godot_console --headless -s tests/test_map7_happen_setup.gd
```
