BÊBADO — FRAMES RENOMEADOS PARA GODOT 4.x
==========================================

Conteúdo: 41 PNGs individuais, em assets/sprites/enemies/bebado/.

PRESERVAÇÃO DOS ARQUIVOS
- Todos os PNGs foram mantidos sem edição, redimensionamento, recorte ou reexportação.
- Cada imagem continua com 256 x 220 px, modo RGBA e o mesmo canal alpha.
- O ZIP armazena os PNGs sem recompressão; o conteúdo interno de cada PNG é idêntico ao arquivo recebido.
- Apenas os nomes foram corrigidos e padronizados com prefixo "bebado_" e numeração sequencial.

MAPA DE ANIMAÇÕES (nomes dos arquivos)
- idle: 6 quadros — poses em pé/ociosas. Os antigos death_0..2 eram poses em pé, não mortes.
- walk: 5 quadros — sequência de deslocamento cambaleante. Os antigos drink_0..4 eram caminhada.
- drink: 3 quadros — poses de beber a garrafa. Inclui os antigos drink_5 e walk_7..8.
- guard: 5 poses — prontidão/guarda de combate.
- attack_jab: 1 pose — soco reto estendido.
- attack_hook: 1 pose — golpe curvo/baixo.
- attack_punch: 1 pose — outro golpe estendido.
- dodge_duck: 1 pose — esquiva baixa protegendo a cabeça.
- dodge_backhop: 1 pose — salto/recuo para trás.
- hit_recoil: 3 poses — reação/recua ao receber golpe.
- knockdown: 3 poses — transição de queda para o chão.
- crawl_enter: 2 poses — transição para a posição baixa/no chão.
- crawl: 3 poses — poses de deslocamento rastejante.
- prone: 2 poses — poses deitado no chão; não devem ser usadas como ciclo de rastejamento.
- getup: 3 quadros — recuperação para voltar a ficar em pé.
- lunge_pose: 1 pose — avanço baixo/agressivo.

OBSERVAÇÕES PARA A IMPLEMENTAÇÃO
- Os nomes identificam a função visual mais provável de cada quadro; não significam que toda ação tenha uma sequência animada completa.
- Ações com apenas um quadro são poses-chave e podem exigir interpolação por código, combinação com movimento ou quadros adicionais para parecerem fluidas.
- Use walk como ciclo, drink/getup/knockdown como animações não cíclicas, e prone como estado/pose de chão.
- A grade original tinha mais posições visuais do que os 41 PNGs presentes no RAR. Este pacote renomeia somente os 41 arquivos recebidos; nenhum quadro foi criado ou duplicado.
- Todos os nomes usam ASCII e sequência com dois dígitos para facilitar carregamento por código e organização no SpriteFrames.
