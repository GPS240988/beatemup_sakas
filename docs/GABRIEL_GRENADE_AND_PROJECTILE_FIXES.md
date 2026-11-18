# Gabriel — correção de projéteis e granadas

Base de implementação: `main` em `2c5cec91a5ce0fe2f107f1ed3704afded0609665`.

## Projétil

- O retângulo de colisão do disparo é recuado 14 px para que sua borda dianteira coincida com a ponta visual do projétil, reduzindo o contato antecipado.
- O projétil sai do marcador da pistola e desce suavemente 46 px nos primeiros 0,18 s, terminando alinhado ao torso dos inimigos comuns. A tolerância de profundidade continua comparando os pés do alvo com a pista do jogador.
- O feedback visual e `DamageInfo.impact_position` passam a usar o ponto da face da Hurtbox voltada ao disparo, calculado a partir do `CollisionShape2D` real. O dano continua sendo aceito/rejeitado pelo receptor.
- A Rajada Dupla ganha 0,16 s entre disparos (antes 0,06 s), deixando separação espacial de cerca de 112 px a 700 px/s.

## Granada

- Somente Gabriel recebe a habilidade: duas cargas por instância de mapa.
- Desktop: `H`. Para Gabriel, `H` deixa de ser guarda e passa a lançar granada; para os outros heróis, `H` continua sendo guarda. `K` permanece guarda para todos.
- Mobile: novo ícone contextual no cluster TouchControls, com contador `2`, `1`, `0`. O ícone não aparece para os outros personagens.
- Arremesso curto com arco, aterrissagem visível e detonação exatamente 2 s após o lançamento.
- Raio de 150 px no plano 2.5D, com falloff de dano. Inimigos recebem dano e knockdown; props destrutíveis recebem dano pelo contrato `take_damage(DamageInfo)`; Gabriel também recebe dano quando permanece dentro do raio. NPCs, civis e aliados são preservados.
- A munição é reiniciada quando uma nova cena de mapa instancia o jogador. As cargas restantes são serializadas e restauradas no `world_snapshot`, portanto salvar/carregar o mapa atual não devolve granadas já gastas.

## Integração local

O pacote contém os arquivos novos em seus caminhos de destino e um patch para os arquivos existentes. Na raiz do projeto, aplicar com:

```bash
git apply patches/gabriel_projectile_grenade.patch
```

Depois, abrir o projeto no Godot 4.7.2, deixar o editor importar as novas PNGs e executar os testes abaixo.

## Checklist de teste

1. Gabriel: disparo único — confirmar que o projétil atravessa visualmente o espaço até tocar o lado da Hurtbox e que o spark aparece na superfície do torso, não antes do sprite.
2. Gabriel: Rajada Dupla — confirmar dois projéteis claramente separados em voo, ambos com possibilidade de causar dano independente.
3. Gabriel: lançar duas granadas; a terceira tentativa não deve criar outra. Reentrar em outro mapa e confirmar duas cargas novas.
4. Ficar ao lado da granada: confirmar dano ao próprio Gabriel após 2 s; afastar-se antes da detonação e confirmar que evita o dano.
5. Confirmar dano a inimigos e props destrutíveis dentro do raio, sem afetar civis/NPCs/aliados.
6. Mobile: conferir o botão e contador contextual, multitouch com movimento e liberação correta ao pausar.
7. Outros personagens: conferir que o botão de granada não aparece e `H` continua guarda.

A validação final de colisão, sensação visual, áudio e frame pacing depende da execução dentro do projeto completo no Godot; não foi possível executar o motor nesta sessão remota.
