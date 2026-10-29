# Padrão Oficial para Cenas de Apresentação e Narrativa — Project Sakas

Este documento define o padrão visual, técnico e arquitetural para todas as sequências cinemáticas, aberturas de atos/fases e diálogos narrativos do **Project Sakas** (Godot 4.x).

---

## 1. Diretriz de Arte e Enquadramento Seguro

### 1.1 Proporções e Formato de Imagem
- **Resolução de Referência**: `1920 × 1080 px` (16:9 widescreen HD).
- **Filtragem**: `TEXTURE_FILTER_NEAREST` para manter a nitidez e o estilo Neo-16-bit urbano artesanal.
- **Modo de Esticamento**: `STRETCH_KEEP_ASPECT_CENTERED`. 
  - **PROIBIDO**: `STRETCH_KEEP_ASPECT_COVERED` no palco principal, pois corta bordas e decepa personagens/detalhes periféricos.
- **Camada de Ambientação (`AmbientBackground`)**: Um `TextureRect` espelhado com a mesma imagem, usando `STRETCH_KEEP_ASPECT_COVERED`, modulação escura e opacidade reduzida (`Color(0.2, 0.2, 0.28, 0.35)`), garantindo que monitores ultra-wide (21:9) ou formatos variáveis não exibam bordas pretas secas.

### 1.2 Palco de Arte (`ArtStage`) e Área Segura
- O palco de exibição visual (`ArtStage`) ocupa de **0% a 74%** da altura da tela (`anchor_bottom = 0.74`).
- A área reservada inferior (**74% a 97%**) é de uso exclusivo da moldura de diálogo.
- **Regra de Composição**: Nenhuma silhueta de personagem, rosto, mão ou item narrativo crucial deve ser posicionado abaixo de 74% da altura da arte original.
- **Margem de Segurança Periférica**: 5% no topo e laterais.

---

## 2. Moldura Arcade Oficial 9-Patch

### 2.1 Identidade Visual (Dark Premium Medieval / Neo-16-bit)
- **Fundo**: Ameixa profundo `#100D18` (Dark Plum).
- **Borda**: Dourado `#EAB308` com 3px de espessura e cantoneiras de fixação reforçadas estilo gabinete arcade.
- **Margens 9-Slice**: `16px` em todas as quatro direções (`patch_margin_left = 16`, `top = 16`, `right = 16`, `bottom = 16`).
- **Asset Oficial**: `res://assets/ui/hud/dialog_frame_9patch.png`.

### 2.2 Badge de Nome do Locutor (`SpeakerBadge`)
- **Posição**: Fixado sobre a borda superior da moldura em `offset_top = -22px`, `offset_left = 24px`.
- **Fundo**: Ameixa escuro com cantoneiras ciano (#06B6D4) e borda dourada.
- **Asset Oficial**: `res://assets/ui/hud/speaker_badge_9patch.png`.
- **Visibilidade**: Oculta automaticamente quando a cena não possui locutor definido (`speaker.is_empty()`).

### 2.3 Tipografia Arcade
- **Fonte Oficial**: `res://assets/fonts/arcade_bold.ttf`.
- **Diálogo**: `18px`, cor marfim `#F4F0E8`, autowrap `WORD_SMART`, sombra preta `#000000` com deslocamento de `(2, 2)`.
- **Locutor**: `14px`, cor dourado `#EAB308`.
- **Contador de Cenas (`SceneCounterLabel`)**: Rodapé esquerdo, `12px`, cor cinza claro `#94A3B8`, formato `"CENA 01 / 03"`.
- **Indicação de Avanço (`PromptLabel`)**: Rodapé direito, `12px`, cor dourado `#EAB308`, animação de pulso sutil: `"[ ESPAÇO ] AVANÇAR ❯"`.

---

## 3. Regras de Interação e Input

### 3.1 Avanço Estritamente Manual (Zero Auto-Advance)
- **PROIBIDO**: Temporizadores que forçam o avanço automático da fala.
- O diálogo permanece na tela indefinidamente até que o jogador confirme explicitamente.
- **Comandos Válidos**:
  - Teclado: `Espaço`, `Enter`, `Tecla Numérica Enter`.
  - Controle/Gamepad: Botão `A` (Xbox) / `Cruz` (PlayStation).
  - Mobile/Touch: Botão visual dedicado `BtnMobileAdvance` ou toque na área de diálogo.
  - Ações mapeadas no projeto: `ui_accept`, `attack`, `jump`.

### 3.2 Isolamento de Entrada (Input Cleansing)
- Para evitar que o `Espaço` ou botão de ataque usado para avançar o último quadro da cutscene vaze para a gameplay (provocando pulo ou soco fantasma no primeiro frame da fase):
  ```gdscript
  Input.action_release("jump")
  Input.action_release("attack")
  Input.action_release("attack_punch")
  Input.action_release("attack_aerial")
  Input.action_release("ui_accept")
  ```
- Pausa de estabilização de ~80ms antes da troca de cena para o nível jogável.

---

## 4. Estrutura de Dados Reutilizável (Declarativa)

Novas cenas devem ser criadas **exclusivamente** via recursos `.tres`, sem necessidade de alterar o código do `NarrativeDirector`:

```gdscript
# Exemplo: res://resources/story/story_intro_map1.tres
[gd_resource type="Resource" script_class="StorySequence" load_steps=...]

# Cada evento é um StoryEvent:
# - id: Identificador único ("title_card", "scene_01", etc.)
# - image_path: "res://assets/story/map_1/intro_group.webp"
# - speaker: "GUILHERME" (ou vazio para narrador)
# - texts: ["Primeiro bloco de texto.", "Segundo bloco de texto."]
# - entry_effect: "fade_in" | "slow_zoom" | "crossfade" | "glitch"
# - zoom_start / zoom_end: 1.0 a 1.03
# - transition_duration: 0.32s
# - safe_framing: true
```

---

## 5. Checklist de Validação para Novas Cenas
1. [ ] A imagem possui resolução 1920×1080 (16:9) e filtro NEAREST.
2. [ ] Nenhum elemento essencial (rostos, armas, mãos) está nos 26% inferiores da imagem.
3. [ ] Textos curtos e diretos (máximo 1–3 linhas por bloco de fala).
4. [ ] Testado com `godot_console.exe --headless -s tests/narrative_intro_test.gd`.

