# Contrato visual — disparo balístico do Gabriel

**Status:** `IMPLEMENTED WITH LIMITATION` — scripts, cenas e arte-fonte integrados; falta validar a importação e a leitura em execução dentro do Godot 4.7.2 e em tela mobile.

## Sequência de leitura

1. **Saída do cano:** o clarão amplo `muzzle_pistol` já utilizado pelo projeto é preservado. Sobre ele, `GabrielGunVFX` acrescenta o núcleo branco-quente `muzzle_core` (4 quadros, 48×48, 30 FPS), criando um foco curto e nítido no ponto real do `MuzzleMarker` sem substituir o clarão original.
2. **Trajetória:** o projétil passa a usar `gabriel_projectile.png`, uma sequência horizontal de 4 quadros de 80×32 a 30 FPS. A silhueta combina contorno escuro, corpo de latão incandescente, núcleo marfim e rastros quentes fragmentados. O offset visual alinha a ponta luminosa ao centro da hitbox.
3. **Contato:** `bullet_impact` usa 8 quadros de 96×96 a 30 FPS. A animação evolui de ponto de contato para estrela angular, ejeção de fragmentos e pequenas faíscas residuais. O disparo comum usa escala 0.82; o projétil de knockdown/finisher usa escala 1.10.

## Direção de arte

- Pixel Art HD nítida, clusters deliberados e filtro `nearest`, sem blur, glow filtrado ou interpolação suavizada.
- Paleta balística quente: contorno ameixa quase preto, ferrugem, laranja, âmbar, ouro e núcleo marfim/branco.
- Um ou dois pixels verde-esmeralda aparecem apenas como assinatura cromática sutil de Gabriel; o disparo continua sendo um projétil balístico, não um laser sci-fi.
- Impactos não usam sangue ou explosões desproporcionais. O feedback é seco, rápido e legível sobre o sprite do inimigo.

## Garantias de gameplay

A alteração é exclusivamente visual. Permanecem inalterados: velocidade 700 px/s, dano, alcance, tolerância de profundidade, layers/masks de colisão, hitstop, hitstun, knockback, evasão aérea, filtragem de aliados, consumo no primeiro impacto e regras do combo de Gabriel.

O efeito de impacto só é criado quando um alvo recebe dano ou quando o projétil toca um obstáculo sólido. Um tiro que erra ou passa sob um inimigo em salto não cria faísca de acerto.

## Arquivos

- `scripts/combat/gabriel_gun_vfx.gd`
- `scripts/actors/projectiles/player_bullet.gd`
- `scenes/actors/projectiles/player_bullet.tscn`
- `scenes/vfx/gabriel_gun_vfx_frames.tres`
- `assets/sprites/Efeitos/gabriel/gabriel_projectile.png`
- `assets/sprites/Efeitos/gabriel/gabriel_muzzle_core.png`
- `assets/sprites/Efeitos/gabriel/gabriel_bullet_impact.png`
- `tests/gabriel_gun_vfx_test.gd`

## Validação local

Executar:

```powershell
godot --headless -s tests/gabriel_gun_vfx_test.gd
```

Depois, validar visualmente no Godot: disparo para direita/esquerda, rajada dupla, finisher, tiro aéreo, acerto em inimigo, colisão com parede e leitura em viewport mobile. Ajustes de escala/offset devem ser feitos somente após essa inspeção em jogo.
