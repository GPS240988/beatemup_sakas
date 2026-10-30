# Padrão Oficial para Cenas de Apresentação e Revelação — Project Sakas

Este documento define a especificação visual, técnica e arquitetural canônica para o modelo definitivo de **narração e revelação cinemática** do **Project Sakas** (Godot 4.x), derivado diretamente da referência visual oficial (`assets/backgrounds/referencia_introducao.webp`) e do roteiro canônico do jogo (`Roteiro Introdução Fase 1.docx`).

---

## 1. Referência Visual Obrigatória e Diretriz de Arte

### 1.1 Identidade Visual (Neo-16-bit Urbano Brasileiro / Arcade Premium)
- **Referência Oficial**: `res://assets/backgrounds/referencia_introducao.webp`
- **Fundo do Painel**: Azul-marinho profundo quase preto `#040B1B` com 95% de opacidade, garantindo contraste impecável e leitura confortável sem bloquear desnecessariamente o cenário.
- **Moldura Geométrica**: Contorno dourado chanfrado `#FACC15` / `#EAB308` com rebaixo sombreado `#CA8A04`, cantoneiras a 45 graus e estrias diagonais duplas no canto superior esquerdo e inferior direito (estilo gabinete arcade clássico dos anos 90).
- **Proporções de Tela e Viewport**: Resolução nativa de `1280 × 720 px` (16:9), adaptável a `1920 × 1080 px` e dispositivos móveis via âncoras e margens proporcionais.
- **Filtragem e Escala**: `TEXTURE_FILTER_NEAREST` para manter clusters de pixels nítidos e a integridade da pixel art artesanal sem borrões ou anti-aliasing indevido.

### 1.2 Palco de Arte (`ArtStage`) e Enquadramento Seguro
- **Área da Imagem**: Ocupa de **0% a 74%** da altura do viewport (`anchor_bottom = 0.74`).
- **Modo de Esticamento**: `STRETCH_KEEP_ASPECT_CENTERED` no `ImageDisplay`. É terminantemente proibido o uso de `STRETCH_KEEP_ASPECT_COVERED` no palco principal, pois cortaria as bordas e deceparia personagens ou elementos narrativos cruciais.
- **Camada de Ambientação (`AmbientBackground`)**: `TextureRect` espelhado ocupando 100% da tela em modo `STRETCH_KEEP_ASPECT_COVERED` com modulação escura `Color(0.18, 0.22, 0.32, 0.38)` para telas ultra-wide (21:9).
- **Área Reservada da Interface**: A moldura narrativa fica estritamente contida entre **74% e 97%** da tela, com 44px de margem lateral em cada lado.

---

## 2. Componentes Separados e Reutilizáveis (`assets/story/ui/`)

Em cumprimento à diretriz de arquitetura modular, os elementos foram decompostos em assets reutilizáveis:

1. **Moldura 9-Patch (`narrative_frame_9patch.png`)**:
   - Dimensões: `128 × 128 px` RGBA.
   - Margens de 9 fatias: `patch_margin = 48` nos 4 lados.
   - Permite que o painel se estique horizontal e verticalmente sem deformar os cantos chanfrados.
2. **Tecla ENTER Estilizada (`enter_key_badge.png`)**:
   - Dimensões: `52 × 28 px` RGBA.
   - Chanfro estilizado com borda dourada `#EAB308` e interior azul-marinho `#060F23`.
3. **Indicador Gráfico de Avanço Integrado**:
   - Teclado: `[ ENTER ]` em badge dourado + texto `"PARA AVANÇAR ❯"`.
   - Controle/Gamepad: Ícone `[ A ]` + `"PARA AVANÇAR ❯"`.
   - Mobile/Touch: Botão dedicado de toque `BtnMobileAdvance` (`"AVANÇAR ❯"`).
   - Animação: Pulso sutil de transparência de `0.55` a `1.0` a cada 0.45s.

---

## 3. Tipografia Arcade e Regras Editoriais

- **Fonte Oficial**: `res://assets/fonts/arcade_bold.ttf`.
- **Narração**: Tamanho `18px`, cor marfim `#F4F0E8`, sombra preta `#000000` em `(2, 2)`, autowrap inteligente `WORD_SMART`.
- **Suporte Idiomático**: Total compatibilidade com língua portuguesa (acentos agudo, circunflexo, til, crase, cedilha e pontuação).
- **Regra Editorial**: Cada bloco de texto possui no máximo 1 a 2 frases curtas (2 a 4 segundos de leitura média). Textos longos são subdivididos em múltiplos blocos para leitura confortável.
- **Identidade de Narração**: Na narração e na revelação, **não são exibidos nomes ou badges de personagens**, preservando a estética de observador e o foco no mistério. O modelo de diálogos futuro foi desacoplado para integração posterior.

---

## 4. Distinção Canônica: Narração vs. Revelação

A arquitetura (`StoryEvent`) distingue conceitualmente os eventos através do campo `event_type`:

| Atributo | Narração (`event_type = "narration"`) | Revelação (`event_type = "revelation"`) |
| :--- | :--- | :--- |
| **Objetivo** | Situar o jogador, ambientar e conectar fatos. | Exibir anomalias, equipamentos e fatos que alteram o entendimento. |
| **Composição Visual** | Padrão, enquadramento balanceado. | Prioridade total na imagem (zoom, iluminação, CRT flicker). |
| **Tratamento de Texto**| Alinhamento à esquerda, marfim `#F4F0E8`. | Destaque dourado/âmbar ou centralizado (ex.: mensagens de arcade). |
| **Transição Típica** | `fade_in`, `slow_zoom` (100% a 103%), `crossfade`. | `glitch` curto analógico (2-3 frames), crossfade temporal. |
| **Áudio Integrado** | Ambientes sonoros, sinos nostálgicos. | Estática CRT, ruídos de relé, graves pontuais. |

---

## 5. Roteiro Canônico Implementado: Mapa 1 (Cenas 01 a 07)

A abertura oficial em `res://resources/story/story_intro_map1.tres` implementa fielmente as 7 cenas do documento canônico:

1. **Cena 01 — A Última Ficha (`title_card`)**:
   - Tela preta, fade suave. Título central `Saka's`, depois `A ÚLTIMA FICHA`. Som de hum elétrico profundo.
2. **Cena 02 — Os Quatro (`the_four`)**:
   - Imagem: `intro_group.webp` (rua de Vila Prudente à noite em direção à locadora).
   - Texto: *"Anos depois da adolescência, quatro velhos amigos ainda continuavam se encontrando."* / *"Guilherme, Gabriel, André e Juliana."*
   - Efeito: `slow_zoom` (100% para 103%), sino nostálgico.
3. **Cena 03 — Os Que Não Estão (`the_missing`)**:
   - Imagem: `missing_friends.webp`.
   - Texto: *"Mas dois deles já estavam desaparecidos havia algum tempo."* / *"Alessandro. Fernando."*
   - Efeito: `glitch` de 3 frames com ruído de interferência CRT.
4. **Cena 04 — A Sala Secreta (`secret_room`)**:
   - Imagem: `secret_room.webp`.
   - Texto: *"O antigo dono da locadora revelou uma sala que ninguém conhecia."* / *"Ali dentro, havia uma máquina que deveria ter permanecido desligada."*
5. **Cena 05 — A Máquina (`arcade_machine` - Revelação)**:
   - Imagem: `arcade_machine.webp` (close cinematográfico com reflexos).
   - Texto de Tela Arcade: `"INSERT COIN"` → `"4 PLAYERS DETECTED"` → `"CONTINUE?"`.
   - Efeito: `glitch` de 2 frames, texto dourado centralizado simulando CRT.
6. **Cena 06 — Passado e Presente (`past_present` - Revelação Central)**:
   - Imagem: `past_present.webp` (rua de Vila Prudente com passado e presente sobrepostos).
   - Texto: *"As telas mostraram lugares que eles conheciam."* / *"Mas não como eles eram."* / *"O passado e o presente estavam ocupando o mesmo espaço."*
   - Efeito: `crossfade` com leve aproximação de imagem.
7. **Cena 07 — Retorno à Locadora (`back_to_arcade`)**:
   - Imagem: `street_memory.webp`.
   - Texto: *"Retornando à locadora, a realidade ao redor já não parecia mais a mesma."* / *"MAPA 1 — A LOCADORA"*.
   - Transição segura para gameplay do Mapa 1 Fase 1 (`map_1.tscn`).

---

## 6. Regras de Input e Proteção contra Vazamento

1. **Avanço Estritamente Manual**: Zero auto-advance. Nenhuma fala avança sem confirmação do jogador.
2. **Isolamento de Entrada**:
   Na conclusão ou ao pular a sequência cinematográfica, o sistema executa:
   ```gdscript
   Input.action_release("jump")
   Input.action_release("attack")
   Input.action_release("attack_punch")
   Input.action_release("attack_aerial")
   Input.action_release("ui_accept")
   ```
   Garantindo que a tecla `Espaço` ou `Enter` usada para avançar o último quadro não provoque pulo ou soco fantasma no primeiro frame jogável.
3. **Comando de Pular Seguro (`BtnSkip`)**:
   Botão visual `PULAR ⏩` no topo direito, ou tecla `ESC` / `ui_cancel`. Limpa os tweens com segurança e encerra a sequência emitindo `sequence_skipped`.

---

## 7. Checklist de Validação Técnica
- [x] Suíte `tests/narrative_intro_test.gd`: 80/80 testes passando com 0 falhas.
- [x] Suíte `tests/ui_flow_test.gd`: 67/67 testes passando com 0 falhas.
- [x] Suíte `tests/map_progression_test.gd`: 67/67 testes passando com 0 falhas.
- [x] Suíte `tests/combat_smoke_test.gd`: 72/72 testes passando com 0 falhas.
- [x] Suíte `tests/loading_screen_test.gd`: 18/18 testes passando com 0 falhas.
- [x] Web export: Zero dependências GDExtension (`gdextensionLibs: []`), compatibilidade total PC e Mobile.
