# Sakas — Direção de Arte Unificada (Piloto)

**Status:** proposta para aprovação visual; ainda não incorporada ao repositório remoto.  
**Objetivo:** definir um contrato visual repetível para personagens, inimigos, cenários, efeitos de combate e HUD, antes de produzir o restante dos assets.  
**Referência de teste:** `Sakas_Cenario_Teste_01.png` (mockup conceitual gerado nesta etapa; não é asset final de produção).

---

## 1. Decisão de direção artística

### Nome de trabalho
**Neo-16-bit urbano brasileiro — beat ’em up 2.5D**

### Intenção
Um beat ’em up com leitura imediata de arcade dos anos 1990, pixel art HD deliberada, identidade urbana de São Paulo/Vila Prudente e profundidade de jogo 2.5D. A riqueza vem de silhuetas, clusters de pixels, contraste e composição — não de filtros que transformam ilustrações suaves em “pixel art”.

### Regras que todos os assets devem compartilhar

1. **Pixel art nativa:** cada pixel/cluster tem intenção; contornos nítidos, sem antialiasing acidental, blur, granulação fotográfica ou gradientes contínuos. Não aplicar filtro de pixelização como substituto do redesenho.
2. **Silhueta primeiro:** protagonista, inimigos, golpes, itens e efeitos devem continuar legíveis em tamanho de jogo e em escala de cinza.
3. **Luz coerente:** luz ambiente fria de noite urbana; fontes quentes vindas de vitrines e postes; cores de neon como recortes/acento, não como iluminação uniforme em tudo. No personagem, manter volumes e sombras consistentes com a luz predominante da cena.
4. **Paleta controlada:** herói: alvo inicial de 24–36 cores úteis; inimigos: paleta equivalente; cenário: paleta mais ampla, mas organizada por planos e materiais; efeitos: poucas cores muito contrastantes. Os números são limites iniciais para revisão, não uma regra que obrigue cores desnecessárias.
5. **Contorno e sombra:** contorno externo escuro coerente e sem variações aleatórias de espessura; sombras em blocos bem definidos; evitar pillow shading (escurecer igualmente todas as bordas) e banding acidental.
6. **Proporções preservadas:** a anatomia e os elementos identificadores do personagem não mudam de um frame para outro. Dobrar o corpo durante um golpe é permitido; esticar/achatar a arte inteira para simular movimento, não.
7. **Canvas e chão consistentes:** quadros animados da mesma família usam o mesmo canvas e ponto de referência; os pés de apoio não deslizam verticalmente entre frames sem uma intenção de movimento clara. Sombras de contato e colisores são tratados no Godot, não pintados na textura do personagem.
8. **2.5D de gameplay:** a profundidade vem do deslocamento no eixo Y, da ordenação dos atores, da perspectiva, das camadas e das sombras. Os sprites mantêm uma vista consistente de beat ’em up, com o corpo em 3/4 lateral suficiente para ler rosto, tronco e membros.
9. **Legibilidade de combate:** evitar detalhes de fundo mais contrastantes que os lutadores; manter uma faixa de gameplay no chão visualmente calma. O flash de impacto pode ser a forma mais brilhante por um instante.
10. **Uso em Godot:** texturas de pixel art importadas com filtro nearest/sem suavização; conferir escala inteira sempre que viável, sem alterar a origem física do ator para compensar quadros mal desenhados.

### Contexto visual
Vila Prudente, São Paulo, início/meados dos anos 1990: locadoras de VHS e videogames, fachadas de comércio de bairro, calçadas de concreto, postes, fios aéreos, portões, grafites, orelhões, cartazes e pequenos letreiros. Usar referências culturais brasileiras como detalhe ambiental, sem transformar a cena em uma coleção de clichês ou de marcas reais.

---

## 2. Bloco de estilo compartilhado

**Cole este bloco no final de cada prompt de asset.** Ele é o “style lock” que mantém a linguagem visual constante.

> **STYLE LOCK — SAKAS:** Create authentic, hand-crafted HD pixel art for a 2.5D side-scrolling arcade beat ’em up set in 1990s Vila Prudente, São Paulo, Brazil. Use crisp deliberate pixel clusters, clean hard pixel edges, a controlled palette, strong readable silhouettes, dark consistent outlines, and clearly grouped highlights and shadows. Preserve a coherent 16-bit arcade visual language across characters, environments, props, combat effects and UI. The scene is viewed from a consistent three-quarter side beat-’em-up camera, with gameplay depth on the vertical screen axis. Use cool deep blue/purple urban ambience with restrained warm shop/streetlamp light and small cyan/magenta neon accents. Pixel art must be authored as pixel art, not smooth digital painting run through a pixelation filter. No anti-aliased edges, no soft blur, no photographic textures, no vector gradients, no painterly brushwork, no 3D rendering, no subpixel smearing, no random stray pixels, no inconsistent anatomy, no unreadable micro-detail. At the intended in-game size, the subject must remain immediately readable.

---

## 3. Prompt 01 — Personagem jogador (Guilherme)

**Uso:** criar uma imagem-mestre do jogador para aprovar o estilo antes de produzir animações. Anexar a imagem atual de Guilherme como referência obrigatória.

> Use the supplied current Guilherme player sprite as a STRICT identity and costume reference. Redesign it into authentic hand-crafted HD pixel art while preserving the same recognizable face, hair, skin tone, shirt, pants, shoes, body type, and character identity. Create one complete full-body neutral combat/idle pose, facing right in the established three-quarter side beat-’em-up view. Keep both feet visible and firmly placed on a clear shared ground baseline. Use a stable, believable anatomy and a strong silhouette; hands, elbows, knees and shoes must remain readable at normal gameplay scale. Simplify tiny fabric seams and facial details into intentional pixel clusters rather than smooth shading. Use a small coherent character palette, dark clean outline, 2–3 readable value groups per material, and consistent light direction. Transparent background, no floor, no shadow baked into the sprite, no weapon unless it exists in the supplied reference, no text, no UI, no extra poses, no sheet, no frame border. Center the character on a consistent production canvas and leave safe transparent margins around hair, hands and shoes. Do not make the character taller, thinner, more muscular or more realistic than the reference. Apply the SAKAS STYLE LOCK.

**Validação:** comparar lado a lado com a referência aprovada; confirmar rosto, roupa, proporções e paleta. A imagem-mestre só é aprovada se parecer o mesmo Guilherme, refeito em pixel art — não um personagem novo inspirado nele.

---

## 4. Prompt 02 — Inimigo básico

**Uso:** substituir o inimigo geométrico provisório por um personagem que pertença ao mesmo elenco visual.

> Create one full-body basic street-thug enemy for the Sakas 2.5D beat-’em-up. The enemy is a working-class São Paulo street tough from the mid-1990s, wearing a worn burgundy/brown jacket, dark trousers and practical boots; make the costume distinct from Guilherme’s but believable for the same neighborhood and era. Neutral ready-to-fight pose, facing left toward the player, in the exact same three-quarter side beat-’em-up camera and apparent scale as the approved Guilherme master sprite. Use the same pixel cluster size, outline weight, palette discipline, lighting logic, shading density and level of anatomical stylization as the approved hero. Give the enemy a distinct readable silhouette (different shoulder line, hair shape and stance) without caricature or excessive detail. Keep feet on the same ground baseline and body proportions stable. Transparent background; one character only; no shadow baked into sprite; no weapons, text, UI, background, sheet or decorative frame unless specifically requested. Apply the SAKAS STYLE LOCK and use the approved hero image as the direct visual style reference.

**Validação:** colocar o inimigo e o jogador lado a lado no mesmo zoom. Se um parecer pintado e o outro parecer pixel art, ou se a densidade de pixels/contorno for diferente, reprovar e corrigir antes de produzir animações.

---

## 5. Prompt 03 — Cenário de gameplay (background sem personagens)

**Uso:** criar o primeiro fundo real do protótipo visual. O resultado deve servir ao gameplay, não ser apenas uma ilustração bonita.

> Create a wide 16:9 side-scrolling gameplay background for a 2.5D beat-’em-up, set outside a neighborhood VHS and videogame rental shop in Vila Prudente, São Paulo, around 1994–1997. Include a recognizable Brazilian street facade, metal shutters, hand-painted neighborhood signage, overhead utility wires, a streetlight, concrete sidewalk, cracked asphalt, a bus-stop or public-phone detail, a few posters, and a shop window with VHS tapes and 1990s game boxes. Keep the architecture grounded and lived-in, not cyberpunk fantasy. Use deep navy and violet night ambience, warm amber light spilling from the shop, and restrained cyan/magenta neon accents. Arrange the composition in distinct parallax-friendly depth bands: distant rooftops/sky, building facade, sidewalk props, and foreground pavement. Leave the lower 35–40% relatively calm and open as the playable floor lane; keep large props away from the central combat area. The pavement must provide a continuous clear ground plane with a readable perspective; avoid strong high-contrast cracks directly beneath where fighters will stand. No characters, enemies, hit effects, HUD, dialogue, logos or readable text. Draw it as authentic crisp pixel art with intentional clusters and controlled shading, suitable for later splitting into separate layers. Apply the SAKAS STYLE LOCK.

**Validação:** confirmar que a faixa de combate fica limpa, que a perspectiva permite andar em profundidade e que personagens de alto contraste continuam mais legíveis que os detalhes do cenário. Exportar planos separados se o mockup for aprovado.

---

## 6. Prompt 04 — Efeito de impacto de golpe

**Uso:** fixar a gramática visual de socos e golpes pesados. Começar por um único quadro de referência; a animação será desenhada depois.

> Create one isolated hit-impact effect for a heavy punch in the Sakas 2.5D pixel-art beat-’em-up. Show a compact, asymmetrical starburst made of hard-edged pixel clusters: a bright warm yellow/cream core, orange and red outer shards, and a few short cyan-blue fragments as secondary contrast. The impact should communicate a strong arcade hit instantly, with jagged directional shapes pointing away from the contact point and a small number of detached square pixels. Keep the silhouette compact enough to sit between two fighters without obscuring their faces or bodies. Transparent background, centered contact origin, no character, no fist, no speed-line background, no text, no glow blur, no lens flare, no gradient haze, no border. Use a small palette and the same outline/cluster language as the approved hero and enemy. Apply the SAKAS STYLE LOCK.

**Validação:** verificar legibilidade em tamanho pequeno e sobre fundo claro/escuro. A energia visual deve vir dos clusters e do contraste, não de blur. A posição de origem deve ser fácil de alinhar ao ponto de contato no Godot.

---

## 7. Prompt 05 — Recorte de HUD arcade

**Uso:** definir o visual do HUD sem gerar uma tela inteira. A tipografia e os números finais deverão ser implementados como UI no Godot, não depender do texto gerado na imagem.

> Create a clean horizontal crop of a retro 16-bit arcade beat-’em-up HUD for Sakas, designed to occupy the top edge of a 16:9 gameplay screen. On the left, reserve a compact portrait frame and the player name “GUILHERME”, then a segmented warm amber/yellow health bar and a smaller cyan energy bar. On the right, create a mirrored enemy panel with a portrait placeholder and a segmented red health bar. In the center, leave a compact area for a stage label and timer. Use dark navy panels, crisp pixel-font lettering, pixel-perfect borders, restrained cyan/magenta accents and high contrast. The crop must be straight-on, flat and readable, with consistent border thickness and pixel scale; it must feel native to the same game as the approved character sprites and background. Transparent or solid near-black background, no gameplay scene, no full characters, no extra decorations, no 3D bevels, no smooth gradients, no glossy mobile-game UI. Treat the exact text as layout guidance only; keep the layout spacious enough for real Godot labels to replace generated lettering. Apply the SAKAS STYLE LOCK.

**Validação:** testar a 100% do tamanho previsto na janela de jogo. Nome, barras e retratos precisam continuar legíveis sem ocupar área excessiva da arena; os textos finais serão elementos Godot separados.

---

## 8. Prompt 06 — Primeiro cenário integrado de teste (os cinco elementos juntos)

**Uso:** gerar um mockup de aprovação visual para avaliar a coerência do conjunto. **Não usar a imagem integrada como asset final:** personagens, HUD e efeitos devem ser exportados separadamente após aprovação.

> Create a wide 16:9 gameplay screenshot concept for “Beat ’em Up Sakas”, a 1990s-inspired 2.5D pixel-art arcade brawler set in Vila Prudente, São Paulo. Use a nighttime street outside a Brazilian VHS and videogame rental shop as the test environment: metal shutter with local graffiti, concrete storefront, VHS/game displays, overhead cables, a streetlight, cracked sidewalk and wet asphalt with restrained colored reflections. In the lower-middle gameplay lane, show the approved Guilherme design (white T-shirt, blue/dark jeans, sneakers; preserve the supplied character reference when provided) landing a powerful straight punch on one basic thug in a burgundy jacket. The player and enemy must share the exact same pixel scale, outline weight, shading density, lighting, anatomy style and ground plane. Put one compact hard-edged yellow/orange/cyan pixel impact burst exactly at the contact point. Include a restrained arcade HUD along the top edge: player portrait/name and amber/cyan bars on the left; stage and timer in the center; enemy portrait and red health bar on the right. Keep all five visual elements distinct and readable; the fighters are the highest-priority focal points, the impact is briefly brightest, and the background is less contrasty in the combat lane. Authentic hand-crafted pixel clusters, consistent 16-bit arcade language, no smooth illustrated characters, no geometric placeholder enemies, no antialiasing, no motion blur, no photographic textures, no 3D render, no unreadable tiny signage, no extra fighters or floating UI. Apply the SAKAS STYLE LOCK.

**Validação:** avaliar primeiro o conjunto em escala de jogo, depois cada elemento isolado. O mockup atual `Sakas_Cenario_Teste_01.png` serve como primeira referência composicional; deve-se gerar uma segunda versão usando as imagens aprovadas de Guilherme e do inimigo quando estiverem disponíveis.

---

## 9. Texto proposto para incorporar ao `GAME_RULES.md`

Copiar esta seção para o bloco de direção artística existente e depois harmonizar/remover regras duplicadas.

```md
## Art Direction Lock — Neo-16-bit Urban Brazilian Pixel Art

### Visual Identity
The game uses handcrafted HD pixel art for a 2.5D arcade beat-'em-up set in 1990s Vila Prudente, São Paulo, Brazil. Characters, enemies, environments, props, hit effects, and HUD must share one visual language. Pixel art must be authored through deliberate pixel clusters; smooth illustrations processed with a pixelation filter are not an acceptable substitute.

### Pixel and Palette Rules
- Use crisp hard pixel edges; disable texture filtering/smoothing for pixel-art textures.
- No accidental anti-aliasing, blur, photographic grain, painterly brushwork, continuous gradient shading, or subpixel smearing.
- Use controlled palettes, coherent outline weight, clustered highlights/shadows, and a consistent dominant light direction. Neon hues are accents, not a substitute for form shading.
- Avoid pillow shading, accidental banding, isolated stray pixels, and micro-details that disappear at gameplay scale.
- Judge every asset at its actual in-game size as well as in an enlarged inspection view.

### Character Consistency
- Maintain approved character identity, costume, face, body proportions, palette, outline, and shading across all animations.
- All frames in an animation family use the same canvas dimensions and ground reference.
- Grounded moves keep supporting feet on a stable baseline unless intentional motion (jump, fall, recoil) requires otherwise.
- Do not stretch the full sprite or move the physical actor to hide inconsistencies between frames.
- Player and enemies must share the same stylization, apparent pixel scale, shading density, and camera perspective while remaining distinct by silhouette and costume.

### 2.5D Environment and Composition
- Use a consistent three-quarter side beat-'em-up camera; gameplay depth is expressed along the screen's vertical axis.
- Separate background, architecture, playable floor, and foreground elements when parallax or actor occlusion requires it.
- Preserve a readable continuous combat lane. Background contrast and detail must not overpower fighters, attack tells, items, or hit effects.
- Use Brazilian urban references from 1990s São Paulo with restraint and contextual consistency.

### Combat Effects and HUD
- Hit effects use crisp, compact pixel shapes and a limited high-contrast palette; no soft glow is required for impact readability.
- HUD elements use pixel-font styling, consistent borders and spacing, and remain legible at the target resolution.
- Keep text, portraits, health bars, timers, and effects as separate editable game elements wherever practical; do not bake gameplay UI into the stage background.

### Asset Approval Gate
A visual asset is not approved until it passes: (1) identity/style comparison against the approved references; (2) readability at gameplay scale; (3) pixel-edge and palette review; (4) composition/ground-line review; and (5) an in-engine check with nearest filtering and the real HUD/combat lane. A cohesive pilot scene containing one player, one enemy, one environment slice, one impact effect, and the HUD must be approved before producing the full asset set.
```

---

## 10. Checklist de aprovação do piloto

- [ ] Guilherme continua imediatamente reconhecível em relação à referência original.
- [ ] Herói e inimigo parecem pertencer ao mesmo jogo e à mesma escala de pixel.
- [ ] O cenário remete a Vila Prudente dos anos 1990 sem competir com o combate.
- [ ] Existe uma faixa de chão contínua e legível para caminhar em profundidade.
- [ ] O impacto tem silhueta clara em tamanho pequeno e fundo transparente limpo.
- [ ] O HUD pode ser reconstruído com nós/controles Godot independentes.
- [ ] Os sprites não dependem de blur, antialiasing ou brilho suave para parecerem acabados.
- [ ] A cena é revisada no Godot com o filtro nearest e a escala final de gameplay.
- [ ] A decisão visual é registrada antes de iniciar a produção em massa.

## 11. Notas de produção

- Os prompts de personagem/inimigo devem sempre receber as referências visuais aprovadas como imagens anexadas. Sem referência, um gerador pode inventar outro design, mesmo quando o texto pede consistência.
- Imagens integradas geradas por IA servem como estudo de direção e composição. Não substituem spritesheets bem alinhados, transparência validada, slices e assets de HUD editáveis.
- Não aplicar alterações em massa nos assets existentes antes de aprovar o piloto no jogo.
- O mockup de teste pode conter texto imperfeito ou detalhes inventados. Refazer nomes, placares, números, logos e sinalização em ferramentas de produção ou diretamente no Godot.
