---
name: pixelfx
description: "Produção, renderização e integração cirúrgica de efeitos visuais PixelFX (Pixel Art HD) ao jogo Sakas (Godot 4.x). Orienta a busca direcionada, prévia de quadros, exportação de spritesheets/metadados e integração ao CombatFeedback."
risk: safe
source: project
date_added: "2026-11-07"
---

# PixelFX — Guia de Integração de Efeitos Visuais (Projeto Sakas)

Guia oficial para pesquisa, geração, exportação e integração de efeitos de combate e ambientais do **PixelFX** no **Beat 'em Up — Sakas** (Godot 4.x / GDScript tipado).

---

## 1. Diretrizes Obrigatórias e Contrato Arquitetural

1. **Consulta Mandatória a `GAME_RULES.md`**:
   - Toda implementação deve respeitar as diretrizes de combate (Seções 3, 7, 9 e 30) e restrições mobile (Seção 26).
   - Identidade visual estrita: **Dark Premium Medieval / Arcade anos 90**, com pixel art nítida, paleta coesa, sem blur, antialiasing artificial ou perda de transparência.
2. **Ponto Único de Entrada**:
   - `CombatFeedback` (`scripts/combat/combat_feedback.gd`) é a autoridade central para feedback de impacto.
   - **Proibido** criar gerenciadores paralelos, singletons, nós extras de colisão ou bibliotecas paralelas de efeitos.
3. **Zero Dependência JavaScript em Runtime**:
   - A biblioteca PixelFX reside exclusivamente em `.tools/pixelfx/` como ferramenta de desenvolvimento offline.
   - O executável do jogo consome apenas spritesheets e recursos nativos (`.png`, `.tres`, `SpriteFrames`, `AtlasTexture`).
4. **Desempenho Mobile e 60 FPS**:
   - Todos os efeitos devem rodar a 60 FPS fixos em PC e dispositivos móveis.
   - Proibido o uso de `GPUParticles2D`. Manter estritamente `CPUParticles2D` e `ObjectPoolClass` para mitigar alocações de memória.

---

## 2. Fluxo de Trabalho (Workflow)

```
[Demanda de Efeito]
        │
        ▼
[1. Busca Direcionada em .tools/pixelfx/]
   node tools/list.mjs <palavra-chave>
        │
        ▼
[2. Renderização de Prévia e Julgamento Visual]
   node tools/render.mjs <categoria>/<id>
   (Avaliar contact.png: silhueta, contraste, tempo)
        │
        ▼
[3. Exportação de Spritesheet e Metadados]
   node tools/render.mjs <categoria>/<id> --sheet
   (Gera <id>.png e <id>.json com pivot e FPS)
        │
        ▼
[4. Preparação do Recurso no Godot 4.x]
   - Copiar spritesheet para res://assets/sprites/Efeitos/pixelfx/
   - Importar como Texture2D Lossless (compress/mode=0, sem mipmaps)
   - Adicionar AtlasTextures à animação em scenes/vfx/hit_effects_frames.tres
        │
        ▼
[5. Integração em CombatFeedback.spawn_hit_spark()]
   - Mapear para o perfil de impacto correspondente
   - Configurar escala e visual_offset baseados no pivot do efeito
   - Gerenciar ciclo de vida via animation_finished + timer dinâmico
        │
        ▼
[6. Validação com Testes Focados Headless]
   godot_console.exe --headless -s tests/<teste_focado>.gd
```

---

## 3. Pesquisa e Prévia de Efeitos

Trabalhe no diretório de ferramentas `.tools/pixelfx/`:

1. **Pesquisa por Categoria ou Função**:
   ```powershell
   cd .tools/pixelfx
   node tools/list.mjs blunt
   node tools/list.mjs impact
   node tools/list.mjs slash
   node tools/list.mjs explosion
   ```
2. **Renderizar Prévia (Contact Sheet)**:
   ```powershell
   node tools/render.mjs impacts/blunt-hit
   ```
   Inspecione o arquivo gerado em `.tools/pixelfx/records/<categoria>/<nome>/contact.png`.
3. **Avaliação Crítica de Pixel Art**:
   - Silhueta nítida e legível em escala 1x.
   - Núcleo quente nos primeiros quadros, desaceleração suave e dispersão orgânica de poeira/estilhaços.
   - Quadro final estritamente vazio (evita corte abrupto).

---

## 4. Exportação e Conversão para Godot 4.x

1. **Exportar Spritesheet**:
   ```powershell
   node tools/render.mjs <categoria>/<nome> --sheet
   ```
   Isso produz:
   - `<nome>.png`: Spritesheet com canal alfa RGBA e quadros em grade.
   - `<nome>.json`: Metadados estruturados (FPS, contagem de quadros, tamanho do quadro `frameSize: [w, h]`, pivô `pivot: [x, y]`).

2. **Organização de Runtime**:
   - Copie o arquivo PNG e o JSON para `res://assets/sprites/Efeitos/pixelfx/<nome>.png`.
   - Assegure que as opções de importação preservem pixel art:
     - `compress/mode = 0` (Lossless)
     - `mipmaps/generate = false`
     - `process/fix_alpha_border = true`

3. **Inclusão em `SpriteFrames` (`hit_effects_frames.tres`)**:
   - Cada quadro da grade é instanciado como um `AtlasTexture` apontando para a região `Rect2(col * w, row * h, w, h)`.
   - A animação recebe o FPS exato informado nos metadados (`speed = fps`), com `loop = false`.

---

## 5. Padrões de Integração no `CombatFeedback`

No arquivo [`scripts/combat/combat_feedback.gd`](file:///c:/Users/bobor/Documents/beat%20em%20up%20-%20sakas/scripts/combat/combat_feedback.gd):

### A. Mapeamento por Perfil de Impacto
No método `spawn_hit_spark(parent, pos, direction, profile, region)`:

```gdscript
match profile:
    "punch":
        anim_name = &"blunt_hit"
        sprite_scale = 1.05
        visual_offset = Vector2(0.0, -6.0) # Alinha o centro da explosão com 'pos'
    "kick":
        anim_name = &"impacto"
        sprite_scale = 0.80
        visual_offset = Vector2(43.0, 35.0)
    "heavy", "finisher":
        anim_name = &"combinado"
        sprite_scale = 0.85
        visual_offset = Vector2(21.0, 26.0)
    "special":
        anim_name = &"impactoazul"
        sprite_scale = 0.95
        visual_offset = Vector2(46.0, 27.0)
```

### B. Cálculo Dinâmico de Ciclo de Vida (Zero Vazamento de Memória)
Nunca utilize timers estáticos arbitrários para efeitos com duração variável:

```gdscript
# Ciclo de vida reativo e seguro
var on_spark_finished: Callable
on_spark_finished = func():
    if is_instance_valid(effect_sprite):
        if effect_sprite.animation_finished.is_connected(on_spark_finished):
            effect_sprite.animation_finished.disconnect(on_spark_finished)
        if spark_pool != null and spark_pool.has_method("release"):
            spark_pool.call("release", effect_sprite)
        else:
            effect_sprite.queue_free()

effect_sprite.animation_finished.connect(on_spark_finished)

# Timer de segurança calculado com base nos quadros reais
var frame_count: int = vfx_frames.get_frame_count(anim_name)
var anim_fps: float = vfx_frames.get_animation_speed(anim_name)
var anim_duration: float = float(frame_count) / maxf(anim_fps, 1.0)
var safety_timer: SceneTreeTimer = parent.get_tree().create_timer(anim_duration + 0.15)
safety_timer.timeout.connect(func():
    if is_instance_valid(effect_sprite) and effect_sprite.is_playing():
        on_spark_finished.call()
)
```

---

## 6. Histórico de Efeitos Integrados (Exemplos Reais)

| ID PixelFX | Animação Godot | Perfil de Combate | Frames | FPS | Resolução / Offset |
|---|---|---|:---:|:---:|---|
| `impacts/blunt-hit` | `&"blunt_hit"` | `punch` (Golpes de punho) | 28 | 30 | 128×88 px, escala 1.05x, offset `(0, -6)` |

---

## 7. Critérios de Qualidade e Testes

Antes de finalizar qualquer integração:
1. Executar a suíte de testes focada do efeito:
   ```powershell
   & "C:\Users\bobor\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless -s tests/test_pixelfx_blunt_hit.gd
   ```
2. Garantir 100% de sucesso nos itens:
   - Preservação de whiffs (golpes sem alvo não instanciam faíscas).
   - Preservação dos perfis existentes (`kick`, `finisher`, `special`).
   - Simetria no espelhamento horizontal (`facing_sign`).
   - Execução integral de todos os quadros antes da reciclagem.
   - Retorno limpo ao `ObjectPool` ou liberação da memória.

