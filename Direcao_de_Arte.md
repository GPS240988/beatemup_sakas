# Sakas — Direção de Arte: Vila Prudente Temporal

**Versão:** 2.0 — consolidação da identidade visual  
**Data:** 09/11/2026  
**Status:** proposta consolidada para aprovação de produção  
**Escopo:** personagens, inimigos, cenários, props, efeitos, cinemáticas e interface do Beat 'em Up Sakas.

> **Documento de direção artística.** Os contratos de implementação, dimensões de sprites, âncoras físicas, ordenação, importação, desempenho e arquitetura do Godot continuam subordinados ao `GAME_RULES.md`. Em caso de divergência, não se deve alterar uma regra técnica por conveniência artística: a direção de arte deve se adaptar ao contrato do motor.

---

## 1. Conceito central

### Vila Prudente Temporal — Neo-16-bit Urban Brazilian Beat 'em Up

**Premissa:** a Vila Prudente dos anos 1990 é a realidade visual de origem dos quatro protagonistas. Após o despertar da máquina arcade na sala secreta da locadora, passado e presente começam a ocupar simultaneamente os mesmos espaços. A cidade não vira uma paisagem futurista genérica: lugares familiares permanecem reconhecíveis, mas recebem sinais de outra época.

A fusão temporal não é um anacronismo aleatório. É uma manifestação narrativa ligada à revelação central da abertura — **“Passado e Presente”** — e deve ser percebida pelo contraste entre elementos de épocas diferentes dentro da mesma geografia.

### Regra de ouro

**Os anos 90 são a identidade original; o presente é a interferência; a estética arcade Neo-16-bit é a linguagem visual que unifica ambos.**

A modernidade deve ser filtrada pela gramática visual dos arcades dos anos 1990, com inspiração em Capcom CPS2 e SNK Neo Geo. Essas referências orientam densidade, contraste, cor, silhueta e acabamento; não são uma obrigação de copiar sprites, personagens ou layouts de jogos existentes.

### O que a direção de arte não deve fazer

- Não transformar toda a cidade em cyberpunk, ficção científica genérica ou neon permanente.
- Não trocar a identidade nostálgica da locadora por uma ambientação contemporânea dominante.
- Não inserir smartphones, fachadas atuais, carros modernos ou transporte elevado em todos os cenários apenas para provar que existe uma fusão temporal.
- Não tratar a imagem conceitual gerada por IA como cenário final, modelo anatômico ou referência canônica de personagem.
- Não inventar fatos da história, locais, marcas, veículos ou marcos urbanos que não tenham sido aprovados para a cena.

---

## 2. Hierarquia temporal e narrativa

### 2.1. Passado: identidade-base

A base visual é a Vila Prudente de meados dos anos 1990, com referências de bairro brasileiro vivido e reconhecível:

- Locadora de VHS e videogames como âncora emocional e visual.
- Máquinas arcade, televisores CRT, fitas VHS, caixas de jogos, cartazes e letreiros de comércio local.
- Fachadas, bares, padarias, calçadas de concreto, portões metálicos, muros, grafites, postes, orelhões e fiação aérea.
- Veículos compatíveis com a época, usados como contexto urbano e não como decoração excessiva.
- Roupas, penteados, objetos e hábitos cotidianos coerentes com os personagens e o período.

A ambientação deve parecer vivida, brasileira e específica. Evitar uma coleção de clichês visuais ou uma rua composta apenas por placas chamativas.

### 2.2. Presente: interferência temporal

Elementos contemporâneos podem surgir na mesma rua e no mesmo enquadramento dos elementos antigos, desde que tenham função narrativa e respeitem a geografia do local:

- Fachadas e equipamentos comerciais atuais ao lado, atrás ou parcialmente sobrepostos às estruturas antigas.
- Veículos contemporâneos dividindo a via com carros da década de 1990.
- Pedestres com roupas atuais e smartphones, em contraste com NPCs e protagonistas de aparência noventista.
- Infraestrutura urbana contemporânea — inclusive transporte elevado — somente quando for geograficamente coerente e aprovada para aquele cenário.
- Letreiros, mobiliário urbano e tecnologia atuais tratados com a mesma densidade de pixel e acabamento dos elementos antigos.

A presença moderna deve ser seletiva. Em cada cenário, definir quais elementos pertencem ao passado, quais pertencem ao presente e qual é o sinal visual que revela a sobreposição.

### 2.3. Gramática visual da sobreposição

A fusão temporal deve ser compreendida sem depender de texto explicativo:

1. **Geografia constante:** o jogador reconhece a rua, fachada, esquina ou estabelecimento antes e depois da interferência.
2. **Contraste de época:** objetos, fachadas, veículos e pessoas revelam que dois períodos ocupam o mesmo espaço.
3. **Sobreposição controlada:** usar justaposição, duplicação parcial de contornos, letreiros em duas versões, reflexos divergentes ou pequenas áreas de dupla exposição. Não duplicar tudo.
4. **Glitch como pontuação:** glitches curtos e localizados marcam a fratura temporal em momentos narrativos. Não usar distorção constante como filtro de tela.
5. **Continuidade do lugar:** mudanças visuais não devem destruir os pontos de referência que permitem reconhecer o local.

O roteiro não exige explicar a mecânica temporal como portal, viagem convencional ou tecnologia futurista. A direção de arte deve preservar o mistério e representar o fenômeno como coexistência espacial de épocas.

### 2.4. Progressão visual

| Momento | Leitura visual desejada |
|---|---|
| Locadora e cotidiano inicial | Predomínio dos anos 90; tecnologia atual ausente ou não enfatizada. |
| Sala secreta e máquina arcade | A estética noventista permanece; CRT, luz e glitch anunciam a ruptura. |
| Cena 06 — Passado e Presente | Revelação explícita da mesma geografia ocupada por duas épocas. |
| Cena 07 — Retorno à Locadora | O lugar familiar continua reconhecível, mas há sinais de que o mundo mudou. |
| Gameplay e fases seguintes | A interferência aparece conforme o roteiro e o cenário exigirem; não é obrigatório que todos os mapas tenham a mesma intensidade temporal. |

A progressão acima é uma diretriz de representação. Ela não autoriza alterar o roteiro, a ordem das fases ou a geografia estabelecida.

---

## 3. Linguagem visual compartilhada — Pixel Art HD Neo-16-bit

### 3.1. Pixel grid e densidade coerentes

- Produzir pixel art deliberada, com clusters legíveis e bordas nítidas. Não converter uma pintura suave em pixel art apenas com filtro.
- Manter densidade aparente de pixels, peso de contorno e nível de detalhe coerentes entre personagens, inimigos, cenário, props e efeitos.
- Não impor um tamanho de pixel absoluto idêntico a todos os arquivos: sprites, fundos e objetos têm dimensões e funções diferentes. A consistência deve ser julgada na escala real de gameplay.
- Evitar *mixels*, bordas suavizadas acidentais, antialiasing, blur, granulação fotográfica, smear de subpixel, ruído aleatório e microdetalhes que desaparecem na tela.
- Usar filtro `nearest`/sem suavização para texturas de pixel art. Priorizar escala inteira quando viável, sem deformar ou reposicionar a origem física do ator para compensar o desenho.
- Glitch, zoom ou deslocamentos cinematográficos podem existir como efeitos controlados, desde que não introduzam borrão persistente nem prejudiquem a leitura do pixel art.

### 3.2. Clusters, contornos e volumes

- Cada cluster deve descrever forma, material, iluminação ou textura; evitar pixels isolados sem função.
- Contornos externos escuros de peso consistente nos personagens e objetos interativos, normalmente na faixa visual de 1–2 pixels conforme a escala final.
- Elementos distantes podem usar contornos mais suaves ou menos contrastados para reforçar profundidade.
- Organizar luz e sombra em grupos de valores claros; evitar *pillow shading*, banding involuntário e contorno com espessura aleatória.
- Anatomia, mãos, cotovelos, joelhos, calçados e direção do golpe precisam ser legíveis no tamanho de jogo.

### 3.3. Paleta e iluminação

A paleta deve unir a cidade noturna e a distinção temporal sem transformar todo o cenário em neon:

- **Base urbana:** azul-marinho, azul profundo, violeta e cinzas frios.
- **Passado e memória:** âmbar, amarelo de sódio, ocres, marrons e luz quente de vitrines.
- **Presente:** ciano, azul mais frio e brancos de iluminação comercial, usados seletivamente.
- **Fratura temporal:** magenta, rosa elétrico e pequenos highlights quase brancos, restritos aos pontos de interferência.
- **Combate:** personagens e sinais de ataque devem ter contraste suficiente para dominar a faixa jogável.

Orçamento inicial de cores, sujeito a revisão no conjunto final:

- Herói ou inimigo: aproximadamente 24–36 cores úteis por personagem.
- Módulo de cenário: aproximadamente 32–64 cores organizadas por materiais e planos.
- Efeitos: paleta curta e de alto contraste.

Esses números são metas de controle, não limites matemáticos que obriguem a remover cores necessárias. Cores compartilhadas entre materiais devem ser reaproveitadas quando isso preservar a leitura.

### 3.4. Dithering e superfícies

- Usar dithering manual em clusters para asfalto molhado, sombras, reflexos e transições de material.
- Reflexos de postes e vitrines devem seguir a geometria da superfície e a direção da luz; evitar gradientes digitais contínuos.
- Não espalhar reflexos coloridos por toda a faixa de combate. O chão precisa continuar legível para os pés dos atores e para a profundidade 2.5D.

---

## 4. Personagens e inimigos

### 4.1. Identidade canônica

- As referências aprovadas de Guilherme, Gabriel, André e Juliana são a fonte primária de rosto, cabelo, roupa, anatomia, proporção e identidade.
- Não redesenhar um protagonista como personagem novo apenas porque uma referência genérica de beat 'em up parece mais atraente.
- Cada personagem deve manter características reconhecíveis em idle, caminhada, ataque, dano, queda, recuperação e vitória.
- A expressão pode variar com a ação; a identidade, a roupa e as proporções fundamentais não.
- Não substituir automaticamente os personagens oficiais por lutadores genéricos de jaqueta de couro ou por capangas encapuzados usados em ilustrações conceituais.

### 4.2. Inimigos

- O inimigo básico deve preservar a identidade visual definida para o elenco do Sakas, incluindo a referência de jaqueta vinho/marrom quando aplicável.
- Diferenciar arquétipos por silhueta, postura, cabelo, roupa e comportamento, não apenas por troca de cor.
- A presença de capuzes, máscaras, smartphones ou roupas contemporâneas depende do arquétipo e do momento narrativo; não padronizar todos os inimigos como gangue moderna.
- Heróis e inimigos devem compartilhar escala aparente, linguagem de clusters, contorno, densidade de sombra e perspectiva.

### 4.3. Contrato técnico

As dimensões de canvas, escala de importação, âncora dos pés, tolerâncias de animação e exceções para poses deitadas permanecem exatamente como definidas no `GAME_RULES.md`. Este documento não redefine dimensões, colisores, origem física ou Y-Sort.

---

## 5. Cenários 2.5D e composição de gameplay

### 5.1. Câmera e leitura espacial

- Manter a câmera consistente de beat 'em up lateral em 3/4, com profundidade de gameplay no eixo vertical da tela.
- O eixo Y representa a profundidade caminhável; a perspectiva arquitetônica deve reforçar essa leitura, não competir com ela.
- A faixa jogável deve ter piso contínuo, perspectiva compreensível e contraste moderado.
- Como ponto de partida para prompts, reservar aproximadamente os 35–40% inferiores para o plano de chão e a circulação dos atores. Ajustar essa proporção à câmera e ao layout real de cada mapa.
- Evitar rachaduras, poças, faixas de pedestre, brilhos ou texturas de alto contraste diretamente sob os pés dos lutadores.
- Elementos grandes não devem bloquear a leitura de golpes, inimigos, pickups ou caminhos.

### 5.2. Planos e oclusão

Separar os elementos conforme a estrutura e a necessidade de cada mapa:

- Fundo distante: céu, horizonte, prédios distantes e silhuetas urbanas.
- Plano intermediário: fachadas, lojas, muros e elementos arquitetônicos.
- Props de fundo: vitrines, placas, postes, mobiliário e detalhes sem colisão de gameplay.
- Mundo caminhável: piso, props sólidos, props destrutíveis e atores.
- Primeiro plano: elementos que podem passar visualmente à frente dos atores, sem alterar colisão ou navegação.

A implementação deve respeitar a árvore de cena e os valores de ordenação descritos no `GAME_RULES.md` (incluindo `Background/Far/Mid/BackProps`, `World`, `Foreground` e Y-Sort). Não compensar uma arte mal recortada alterando `z_index` ou a posição física do personagem.

### 5.3. Cenário de gameplay versus ilustração narrativa

- **Background de gameplay:** não deve conter protagonistas, inimigos, HUD, hit effects ou textos de diálogo fundidos na imagem. Deve permitir separação em planos e uso no motor.
- **Ilustração cinematográfica:** pode conter personagens e composição narrativa, desde que respeite a identidade oficial e a área segura definida para a apresentação.
- **Mockup integrado:** serve para avaliar atmosfera e hierarquia visual; não substitui assets separados, spritesheets alinhados ou elementos de UI construídos no Godot.

### 5.4. Marcas, letreiros e geografia

- A paisagem de bairro é mais importante do que logotipos comerciais.
- Preferir letreiros genéricos ou nomes ficcionais quando a marca real não for essencial ao roteiro.
- Marcas reais só devem aparecer quando sua presença for deliberada, contextual e aprovada; não aceitar texto inventado ou deformado por gerador de imagem como asset final.
- Não inserir uma estação, monotrilho, loja ou marco urbano apenas porque combina com a estética. Confirmar primeiro a coerência geográfica e narrativa da cena.
- Refazer textos, placas, números, logotipos e sinalização em ferramentas de produção ou diretamente no Godot quando a precisão for necessária.

---

## 6. Efeitos, HUD e interface

### 6.1. Efeitos de combate

- Impactos devem ter silhueta compacta, direcional e legível, com clusters rígidos e paleta de alto contraste.
- A energia vem da forma, da direção e da alternância de valores; blur, lens flare ou glow suave não são necessários para comunicar impacto.
- O efeito não deve encobrir rosto, tronco ou leitura do golpe por tempo excessivo.
- A origem do efeito deve ser fácil de posicionar no ponto de contato pelo Godot.

### 6.2. HUD

- A HUD oficial definida no `GAME_RULES.md` prevalece sobre qualquer HUD sugerida por prompt ou mockup.
- Retratos, nomes, barras, cronômetro, contador de combo e textos devem permanecer elementos independentes/editáveis do Godot sempre que aplicável.
- Não gerar uma tela completa e usar a imagem como HUD final.
- Tipografia e números finais devem ser implementados com os recursos/fontes do projeto, não depender de texto gerado por IA.
- A estética arcade pode usar azul-marinho, ciano, magenta e dourado, mas a interface deve preservar hierarquia, legibilidade e espaço para o gameplay.

### 6.3. Molduras narrativas

- A moldura da abertura deve preservar a linguagem arcade Neo-16-bit e os parâmetros funcionais já definidos no `GAME_RULES.md`.
- Não acrescentar barras de status de transmissão, indicadores fictícios de conexão ou rótulos técnicos decorativos que não façam parte do roteiro.
- A moldura não pode encobrir rostos, mãos, pés ou silhuetas essenciais da ilustração.
- Glitches e transições temporais pertencem à imagem ou ao efeito de transição; não devem transformar o painel de diálogo em uma interface cyberpunk genérica.

---

## 7. Style lock — bloco compartilhado para prompts

Usar este bloco ao final dos prompts de arte. Completar o prompt principal com a época, o tipo de asset e sua função específica.

> **SAKAS STYLE LOCK — VILA PRUDENTE TEMPORAL:** Create authentic, handcrafted HD pixel art for a 2.5D side-scrolling arcade beat 'em up set in Vila Prudente, São Paulo, Brazil. The 1990s are the visual and emotional baseline; contemporary details may intrude into the same recognizable locations only when the narrative calls for the temporal overlap. Render past and present through one coherent Neo-16-bit arcade visual language inspired by the visual grammar of Capcom CPS2 and SNK Neo Geo. Use deliberate pixel clusters, crisp hard edges, controlled indexed-style palettes, readable silhouettes, consistent outlines, grouped highlights and shadows, and a coherent three-quarter side beat-'em-up camera. Use deep navy and violet night ambience, warm amber storefront/streetlamp light, restrained cyan accents for contemporary elements, and localized magenta/white glitches for temporal fractures. Keep the playable floor lane continuous and visually calm. No accidental anti-aliasing, blur, photographic texture, smooth digital gradients, painterly brushwork, 3D rendering, subpixel smearing, random stray pixels, unreadable micro-detail, invented character designs, or generic cyberpunk overload. Pixel art must be authored as pixel art, not a smooth illustration processed through a pixelation filter. Judge the result at intended in-game size.

---

## 8. Prompts-base de produção

Os prompts abaixo não substituem referências anexadas. Quando houver personagem ou asset aprovado, a imagem de referência correspondente é obrigatória.

### 8.1. Personagem — Guilherme

> Use the supplied approved Guilherme sprite as a STRICT identity, anatomy, and costume reference. Recreate the same recognizable character as handcrafted HD Neo-16-bit pixel art for the Sakas 2.5D beat-'em-up. Preserve face, hair, skin tone, clothing, shoes, body type, proportions, and identity exactly as shown in the reference. Create one complete neutral combat/idle pose, facing right in the established three-quarter side beat-'em-up view. Keep both feet visible on the same clear ground baseline. Use readable hands, elbows, knees and shoes, deliberate pixel clusters, a stable outline, controlled character palette, and consistent light direction. Transparent background; one character only; no floor, baked shadow, weapon, text, HUD, extra pose, spritesheet, or decorative frame. Respect the actor canvas, foot origin and import scale from `GAME_RULES.md`. Apply the SAKAS STYLE LOCK.

### 8.2. Inimigo básico

> Create one basic street-thug enemy for the Sakas 2.5D beat-'em-up, grounded in mid-1990s Vila Prudente. Use the approved enemy reference if supplied; otherwise follow the canonical burgundy/brown jacket identity, dark trousers and practical footwear. Do not turn the enemy into a generic modern masked/hooded fighter. Create one neutral ready-to-fight pose facing left toward the player, using the same apparent pixel scale, camera, outline weight, cluster density, anatomy stylization and ground baseline as the approved hero. Give the enemy a distinct but believable silhouette. Transparent background; one character only; no baked shadow, background, UI, text, weapon or sheet. Respect the actor contract in `GAME_RULES.md`. Apply the SAKAS STYLE LOCK.

### 8.3. Background de gameplay — rua e locadora

> Create a wide 16:9 side-scrolling gameplay background for a 2.5D beat-'em-up outside a Brazilian VHS and videogame rental shop in Vila Prudente, São Paulo, around the mid-1990s. Preserve a lived-in neighborhood atmosphere: recognizable local storefront, metal shutters, concrete sidewalk, overhead utility wires, streetlight, posters, a few period-appropriate urban props and a shop window with VHS tapes and 1990s game boxes. Keep the architecture grounded, not cyberpunk. Use deep navy/violet night ambience and warm amber light from the shop and streetlights, with restrained neon accents. Separate distant skyline, facade, sidewalk props and foreground pavement into parallax-friendly layers. Keep a continuous, readable playable floor lane across the lower part of the composition. No characters, enemies, NPCs, HUD, dialogue, hit effects, baked logos or generated readable text. Make the background suitable for splitting into editable layers. Apply the SAKAS STYLE LOCK.

### 8.4. Cena narrativa — sobreposição temporal

> Create a cinematic 16:9 Neo-16-bit pixel-art illustration for the central temporal revelation in Sakas. Show one recognizable Vila Prudente street location as two eras occupying the same physical space: the mid-1990s version remains the visual foundation, while selected contemporary storefront details, vehicles, street furniture or pedestrians overlap or replace specific parts of the same geography. Preserve recognizable landmarks and spatial continuity. Use controlled partial double exposure, duplicated sign contours or a brief localized magenta glitch to communicate temporal interference; do not turn the whole image into a portal, fantasy world or generic cyberpunk city. Keep era-specific objects visually distinguishable but rendered with the same pixel density, cluster language and outline quality. No invented story text or interface. Use the exact approved location references when provided. Apply the SAKAS STYLE LOCK.

### 8.5. Efeito de impacto

> Create one isolated, compact heavy-hit effect for the Sakas Neo-16-bit beat-'em-up. Use a hard-edged asymmetrical starburst with a bright warm yellow/cream core, orange/red shards and a few cyan fragments as secondary contrast. The direction of the clusters must communicate force immediately without obscuring the fighters. Transparent background, centered contact origin, no character, fist, text, border, blur, lens flare or gradient haze. Apply the SAKAS STYLE LOCK.

### 8.6. Referência de HUD

> Create a clean horizontal crop of a 16-bit arcade beat-'em-up HUD for visual reference only. Use dark navy panels, crisp pixel borders, restrained cyan/magenta accents and clear empty areas for portrait, player name, segmented bars, stage and timer. Do not invent final labels, numbers, icons or game rules. Keep all elements separable and editable; final UI must be implemented using the official Godot nodes, textures and typography from `GAME_RULES.md`. Apply the SAKAS STYLE LOCK.

---

## 9. Gate de aprovação de assets

Um asset só está pronto para produção depois de passar por todas as verificações aplicáveis:

- [ ] Identidade: corresponde às referências aprovadas de personagem, local ou objeto.
- [ ] Época: a presença de elementos dos anos 90 e/ou contemporâneos tem justificativa narrativa e geográfica.
- [ ] Silhueta: personagem, inimigo, item, golpe ou objeto permanece legível no tamanho real de gameplay.
- [ ] Pixel art: clusters, contornos, paleta e iluminação são coerentes; não há blur ou antialiasing acidental.
- [ ] Perspectiva: câmera e plano de chão são compatíveis com a profundidade 2.5D.
- [ ] Ancoragem: pés e base dos props respeitam o contrato de origem física e Y-Sort do `GAME_RULES.md`.
- [ ] Composição: cenário não compete com os lutadores nem polui a faixa de combate.
- [ ] Modularidade: o asset está separado em camadas ou elementos quando o gameplay exige parallax, oclusão ou interação.
- [ ] Integridade: textos, marcas e detalhes legíveis foram revisados; não há erros de geração tratados como informação canônica.
- [ ] Godot: foi conferido em cena real, com filtro nearest, escala final, HUD e atores.
- [ ] Performance: resolução, transparência, quantidade de camadas e tamanho do arquivo são compatíveis com o orçamento do projeto.

Aprovar um piloto integrado — um protagonista, um inimigo, uma fatia de cenário, um efeito de impacto e a HUD oficial — antes de produzir em massa uma nova família de assets.

---

## 10. Notas de produção e autoridade dos documentos

1. `Direcao_de_Arte.md` define conceito, linguagem visual, regras de composição e critérios de aprovação artística.
2. `GAME_RULES.md` define arquitetura, contratos técnicos, dimensões, escalas, âncoras, física, ordenação, importação, desempenho, UI funcional e testes.
3. O roteiro e os recursos `StoryEvent`/`StorySequence` definem o que acontece e em que ordem. A direção de arte não altera o cânone narrativo.
4. Uma referência conceitual gerada por IA serve para atmosfera e composição. Não substitui spritesheets, transparência limpa, assets separados, texto revisado ou validação no motor.
5. Não aplicar alterações em massa aos assets existentes antes de aprovar o piloto no jogo.
6. Não declarar uma regra visual como implementada apenas porque está documentada. Registrar a validação real e atualizar o status correspondente.
7. Ao criar um novo cenário, definir explicitamente: época-base, sinais de presente (se houver), ponto de referência geográfico, intensidade da interferência temporal e camadas necessárias ao gameplay.

---

## 11. Pipeline de Arte Procedural e Estilização Analógica — Integração p5.brush

### 11.1. Filosofia: Mídias Tradicionais como Suporte à Pixel Art Neo-16-bit

O Beat 'em Up Sakas combina a precisão técnica da Pixel Art HD (Capcom CPS2 / SNK Neo Geo) com a organicidade da arte analógica tradicional. A biblioteca procedural **`p5.brush`** (localizada em `libs/p5.brush/`, isolada de Git e deploy Vercel) funciona como uma **bancada de artesão digital offline** para gerar texturas em alta resolução, efeitos de hachura, campos de fluxo orgânico, aguadas e decalques urbanos que são posteriormente rasterizados em PNG/WebP e importados no Godot Engine com filtro `nearest`.

> **DIRETRIZ DE ARQUITETURA**: O `p5.brush` **não é executado em runtime no Godot nem na Web**. Seu papel é gerar assets estáticos e spritesheets offline com qualidade analógica superior, eliminando o aspecto artificial ou vetorial frio de geradores convencionais.

### 11.2. Mapeamento das 10 Possibilidades Artísticas para o Sakas

#### 1. Backgrounds de Fase com Textura Artesanal
- **Conceito**: Enriquecer as camadas estáticas de fundo (skyline, prédios distantes, paredes de tijolo da Vila Prudente) com aguadas de aquarela e hachuras finas a nanquim, criando profundidade atmosférica sem poluir o primeiro plano.
- **Brushes sugeridos**: `charcoal` (contornos e ranhuras), `wash()` (manchas de umidade e atmosfera urbana), `hatch()` (sombreamento tonal cruzado).
- **Regra de Composição**: A textura analógica deve ficar restrita aos planos de fundo e paralaxe intermediário. A faixa caminhável e os atores mantêm bordas pixel art 100% nítidas.

#### 2. VFX Procedurais para Golpes e Impactos
- **Conceito**: Criar faíscas assimétricas, slashes em meia-lua, ondas de choque e rascunhos de energia com traço dinâmico de pincel, gerando spritesheets para o sistema `CombatFeedback`.
- **Brushes sugeridos**: `marker` (pinceladas cortantes com afinamento dinâmico de pressão), `rotring` (linhas precisas de energia estática), `spray` (faíscas e partículas dispersas).
- **Parâmetros**: Variação de pressão `[2.0, 0.4]` para golpes que começam densos e terminam pontiagudos; scatter moderado para vibração visual.

#### 3. Flow Fields para Efeitos Atmosféricos Urbanos
- **Conceito**: Utilizar campos vetoriais matemáticos (`brush.field()`) para orientar o fluxo orgânico de fumaça de bueiros, névoa noturna, vapor de escapamentos, chuva de vento e poeira de asfalto.
- **Campos nativos**: `waves` (ondulações de vapor e calor sobre o asfalto), `spiral` (redemoinhos de folhas e vento sujo), `seabed` (turbulência leve para neblina baixa).
- **Exportação**: Texturas semi-transparentes em looping ou overlays estáticos com gradiente alfa suave.

#### 4. Molduras e Elementos de UI Neo-16-bit Hand-Drawn
- **Conceito**: Desenhar as molduras decorativas das caixas narrativas, painéis de menu e cards de personagens com micro-ondulações manuais sutis (`brush.wiggle(2)`), conferindo calor artesanal às interfaces.
- **Brushes sugeridos**: `pen` (traçado limpo de caneta-tinteiro com leve variação de espessura), `cpencil` (detalhes e biséis em tom âmbar/dourado `#eac16c`).
- **Paleta de Interface**: Dourado nobre (`#eac16c`), âmbar escuro (`#b58a3f`), base em azul-petróleo/grafite (`#12131d`).

#### 5. Efeitos de Dano e Marcas Procedurais no Cenário
- **Conceito**: Gerar decalques de impacto, rachaduras em concreto, vidros estilhaçados e lascas de madeira para os objetos destrutíveis (props como caixas de jogos, orelhões, tambores).
- **Brushes sugeridos**: `charcoal` (fissuras profundas), `hatchStyle("dense")` (zonas de esfarelamento de argamassa), `spray` (detritos microscópicos).
- **Aplicação**: Texturas de overlay modular aplicáveis sobre `destructible_prop.gd` via sub-regiões de atlas.

#### 6. Texturas de Papel, Cartões e Fichas de Arcade
- **Conceito**: Fundos de pergaminho, fichas de locadora em papel cartão envelhecido, encartes de fitas VHS e formulários de save game com fibras visíveis.
- **Brushes sugeridos**: `2H` (linhas ultra-finas de fibra celulósica), `wash()` sépia/ocre (`#d7c3a3` com opacidade 80–120), `fillBleed()` para manchas de café/umidade nas bordas.

#### 7. Overlays de Iluminação e Clima da Vila Prudente
- **Conceito**: Camadas estáticas de iluminação com atmosfera crepuscular e noturna — o azul-marinho profundo do céu contrastando com os cones de luz amarelada dos postes de vapor de sódio e reflexos de neon em poças d'água.
- **Técnica**: `brush.wash()` com gradiente radial simulando dispersão luminescente sobre a pixel art, preservando a legibilidade dos atores no piso.

#### 8. Retratos Estilizados e Concept Art dos Protagonistas
- **Conceito**: Portraits ilustrados para menus, tela de seleção e encerramentos, começando com o traçado a lápis/grafite e preenchimento gradual em aquarela/cores canônicas.
- **Brushes sugeridos**: `HB` / `2B` (traçado anatômico e contorno de silhueta), `cpencil` (meios-tons da pele e tecidos), `rotring` (detalhes dos olhos e cabelos).
- **Caso Canônico**: Retrato de Guilherme no Menu Principal com shader de revelação procedural em tempo real que replica o ato do traçado analógico.

#### 9. Variação Procedural de Grafites e Decalques Urbanos
- **Conceito**: Produção em lote de 10 a 30 pichações, tags e grafites típicos da São Paulo dos anos 90 (`randomSeed()`), variando traço, densidade de tinta e escorrimento sem repetição visual nas paredes das fases 1-1 a 1-4.
- **Brushes sugeridos**: `marker2` (ponta chanfrada clássica de street art), `spray` (halo de aerógrafo nos contornos).

#### 10. Tipografia Expressiva e Letreiros de Bairro
- **Conceito**: Criação de logotipos, títulos de fases, letreiros de comércio ("Bar do Zé", "Locadora Sakas", "Pizzaria") e advertências urbanas com tipografia manual expressiva.
- **Brushes sugeridos**: `flowLine()` com spline cúbica para letras caligráficas retrô e `mass()` para preenchimento consistente de caracteres com textura interna.

### 11.3. Matriz de Brushes p5.brush vs. Aplicações no Sakas

| Brush p5 | Natureza do Traço | Aplicação Primária no Sakas | Arquitetura Destino |
|---|---|---|---|
| `2B` | Grafite macio, denso | Contornos de concept art e portraits | Cutscenes / Menus |
| `HB` | Grafite médio equilibrado | Linhas guias e rascunhos de anatomia | UI Concept / Mockups |
| `2H` | Grafite rígido, cinza claro | Fibras de papel, ranhuras microscópicas | Telas de Pause / Save slots |
| `cpencil` | Lápis de cor com textura | Detalhes de iluminação quente (âmbar) | Biséis e molduras de UI |
| `pen` | Caneta de tinta nanquim | Bordas nítidas de caixas de diálogo | StandardDialogueBox / UI |
| `rotring` | Caneta técnica de precisão | Efeitos de corte de energia e HUD | CombatFeedback / VFX |
| `spray` | Aerógrafo / dispersão | Fumaça, partículas, pó e luz difusa | Spritesheets de impacto |
| `marker` | Marcador chanfrado largo | Traços de slash dinâmico de golpes | Especial e combos pesados |
| `marker2` | Marcador largo com vazamento | Grafites, tags urbanas e letreiros | Backgrounds de fases |
| `charcoal` | Carvão mineral rústico | Sombras profundas, fissuras e desgaste | Props e paredes destruídas |
| `wash()` | Aguada de aquarela fluida | Manchas atmosféricas e iluminação noturna | Overlays de cenário |
| `hatch()` | Hachura geométrica densa | Sombreamento tonal Neo-16-bit | Texturas de fundo |

### 11.4. Protocolo de Exportação e Validação de Assets no Godot

1. **Desenvolvimento do Sketch**: O script gerador deve residir exclusivamente no diretório `libs/p5.brush/` (ou em `tools/` caso seja utilitário de automação em Python/Node).
2. **Resolução de Renderização**: Gerar em canvas proporcional de 2× a 4× em relação ao target do jogo (ex: 2560×1440 para telas 16:9 de 1280×720), assegurando detalhe no traço analógico.
3. **Conversão e Otimização**: Salvar como PNG RGBA (32-bit com transparência) ou WebP com compressão sem perdas (lossless).
4. **Importação no Godot**:
   - Texturas de Pixel Art: `texture_filter = NEAREST` (evita blur).
   - Overlays e Iluminação: `texture_filter = LINEAR` apenas quando houver gradiente suave de luz intencional.
5. **Critério de Inviolabilidade**: O asset gerado não pode alterar o contrato de colisão, origem dos pés dos atores nem poluir a faixa de combate definida no `GAME_RULES.md`.


