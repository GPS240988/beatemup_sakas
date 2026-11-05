# AGENTS.md — Project Sakas (Beat 'em Up 2.5D)

Guia oficial para assistentes de IA que trabalham neste repositório. Estas regras priorizam a integridade do projeto, evitam downloads desnecessários do Git LFS e definem de onde cada ambiente deve obter os arquivos.

## 0. REGRA PRIORITÁRIA — IDENTIFICAR O AMBIENTE DE TRABALHO

Antes de ler, editar, testar ou empacotar qualquer arquivo, identifique o ambiente real pelas ferramentas e arquivos efetivamente disponíveis. Não presuma que existe acesso local ou remoto.

### A. ChatGPT em conversa, sem workspace local do projeto

Considere este o **Modo ChatGPT / GitHub remoto** quando o trabalho estiver sendo feito numa conversa do ChatGPT e não houver uma pasta local do projeto acessível para leitura e escrita.

- Use a integração GitHub conectada à conta do usuário como fonte do projeto. Confirme o repositório `GPS240988/beatemup_sakas`, a branch e o commit mais recente antes de iniciar cada tarefa.
- A conta do ChatGPT precisa ter autorização para o repositório. Se a integração não estiver disponível ou não tiver acesso, informe o bloqueio; não finja que leu a versão atual.
- Leia somente os diretórios e arquivos relevantes para a solicitação. Para arquivos grandes, leia trechos específicos quando isso bastar.
- **Não clone nem baixe o repositório inteiro apenas para fazer alterações em código.**
- **Não baixe objetos Git LFS por padrão.** Não execute `git lfs pull`, `git lfs fetch` amplo ou download de arquivo de exportação apenas para analisar scripts, cenas ou configurações.
- Para arquivos LFS como `public/index.pck`, `public/index.wasm`, `*.ogv` e `*.mp4`, aceite consultar apenas o ponteiro e seus metadados quando necessário. Um ponteiro LFS contém `version`, `oid sha256` e `size`; isso não é o arquivo original.
- Nunca trate um ponteiro LFS como se fosse o conteúdo real do PCK, WASM, vídeo ou áudio. Nunca coloque um ponteiro com extensão `.pck` ou `.wasm` dentro de um pacote e o apresente como arquivo funcional.
- Faça alterações remotas somente em uma branch de trabalho, nunca diretamente em `main`, salvo autorização explícita do usuário. Prefira abrir um Pull Request para revisão.
- Como o conector remoto pode não disponibilizar arquivos binários, não prometa que consegue reconstruir um projeto Godot completo com todos os assets a partir de texto remoto.

#### ZIPs no Modo ChatGPT

- Por padrão, gere um ZIP de **arquivos alterados e novos**, preservando seus caminhos relativos dentro do projeto. Inclua também um manifesto/lista dos arquivos incluídos.
- Inclua scripts, cenas e demais arquivos de texto/configuração relevantes (`.gd`, `.tscn`, `.tres`, `.godot`, `.cfg`, `.json`, `.md` etc.) conforme a alteração.
- Não inclua por padrão artefatos de exportação Web, como `public/index.pck` e `public/index.wasm`, nem objetos LFS que não foram baixados.
- Não declare que o ZIP é um projeto completo, importável ou executável se ele contiver apenas os arquivos alterados ou se estiverem faltando assets binários necessários. Descreva precisamente o conteúdo e as limitações.
- Se o usuário pedir um ZIP integral e executável com todos os assets binários, explique que a integração remota de leitura de código não equivale a um clone local completo. Solicite o uso do Modo IDE Local ou de um artefato de CI preparado para essa finalidade. Não faça download amplo de LFS sem autorização explícita.
- Só obtenha um objeto LFS específico quando ele for indispensável à tarefa e o usuário tiver autorizado esse download. Prefira uma busca pontual ao arquivo necessário, nunca uma sincronização ampla.

### B. IDE ou agente com workspace local (Antigravity, IDE semelhante ou agente local)

Considere este o **Modo IDE Local** quando o agente tiver acesso ao sistema de arquivos e existir uma pasta do projeto aberta/montada no workspace.

- A pasta local aberta pelo usuário é a **fonte de verdade** para leitura, edição, testes e geração de ZIPs.
- Trabalhe diretamente na cópia local existente. Não faça outro `git clone` se o projeto já estiver aberto.
- Não substitua a pasta local pela versão do GitHub e não use arquivos remotos para sobrescrever arquivos locais.
- Não execute `git pull`, `git reset`, `git checkout`, `git clean`, `git restore`, rebase ou operações que descartem/mudem arquivos do usuário sem autorização explícita.
- Antes de editar, identifique a raiz do projeto (a pasta que contém `project.godot`) e verifique o estado do Git com `git status --short --branch`. Preserve todas as alterações locais não commitadas, inclusive arquivos não rastreados.
- Se a IDE estiver aberta numa pasta que não contém `project.godot`, não procure ou clone outra cópia automaticamente. Informe o que está faltando e peça para abrir a pasta correta.
- Use o terminal e os arquivos locais para executar Godot, ferramentas e testes. Não alegue que executou algo que não foi efetivamente executado.
- No Antigravity, este arquivo na raiz do workspace é uma instrução persistente do projeto. Não dependa de uma cópia remota do `AGENTS.md` para localizar o projeto: use a pasta local aberta.

#### Git LFS no Modo IDE Local

- Não execute `git lfs pull` nem `git lfs fetch` automaticamente.
- Se um asset LFS já estiver presente localmente como arquivo real, use-o sem baixá-lo novamente.
- Se um arquivo LFS local for apenas um ponteiro de texto (`version https://git-lfs.github.com/spec/v1`), não o trate como o asset real.
- Se a tarefa não precisar desse asset, prossiga sem baixá-lo.
- Se a tarefa exigir um asset LFS ausente, explique qual arquivo é necessário e solicite autorização antes de baixá-lo. Quando autorizado, busque somente o caminho necessário, usando filtros específicos do Git LFS em vez de baixar todos os objetos.
- Nunca baixe `public/index.pck` ou `public/index.wasm` apenas para alterar scripts, cenas ou configurações que não dependem do conteúdo exportado.

#### ZIPs no Modo IDE Local

- Quando o usuário pedir um ZIP do projeto atualizado, use os arquivos da pasta local, incluindo as alterações locais ainda não enviadas ao GitHub.
- Preserve a estrutura de diretórios e inclua os assets-fonte do jogo que já estão presentes localmente (`assets/`, `resources/`, `scenes/` etc.) e que são necessários para abrir o projeto na Godot.
- Exclua normalmente metadados e caches locais como `.git/`, `.godot/`, `.venv/`, `venv/`, `__pycache__/`, `.pytest_cache/`, `.ruff_cache/` e arquivos temporários.
- Exclua os artefatos de exportação Web `public/index.pck` e `public/index.wasm`
- Antes de concluir, confira se assets necessários não estão ausentes ou representados por ponteiros LFS. Não entregue um ZIP aparentemente completo se estiver faltando conteúdo necessário; informe exatamente o que falta.
- Nunca inclua segredos, tokens, chaves privadas, arquivos `.env` ou credenciais no ZIP.

### C. Ambiente ambíguo ou sem acesso suficiente

- Se não for possível determinar se existe workspace local, verifique as ferramentas e caminhos disponíveis antes de agir.
- Não invente caminhos locais, não presuma que o computador do usuário está montado no ChatGPT e não afirme que acessou arquivos que não estão disponíveis.
- Se houver ChatGPT sem workspace local, use o Modo ChatGPT / GitHub remoto. Se houver IDE com workspace local, use o Modo IDE Local.
- Se o usuário pedir explicitamente uma fonte diferente da regra padrão, siga essa instrução específica, desde que não destrua alterações existentes nem exponha credenciais.

## 1. IDENTIDADE E ARQUITETURA DO PROJETO

- Projeto: **Beat 'em Up — Sakas**, jogo beat 'em up 2.5D desenvolvido em Godot 4.x e GDScript tipado.
- O arquivo `project.godot` é a referência para configuração do projeto e cena principal.
- A arquitetura oficial, contratos de nós, regras de física 2.5D, combate, UI e convenções do jogo estão em [`GAME_RULES.md`](GAME_RULES.md). Leia as seções relevantes antes de alterar sistemas centrais.
- Para o servidor MCP Python (`src/godot_ai/`) e o plugin do editor (`plugin/addons/godot_ai/`), consulte [`docs/AGENTS_GODOT_AI.md`](docs/AGENTS_GODOT_AI.md), se esse arquivo existir na versão de trabalho.
- Respeite a arquitetura, os nomes existentes, os sinais, os grupos, os caminhos `res://` e os contratos das cenas. Não crie sistemas paralelos quando já existir um componente adequado.
- Prefira GDScript tipado, funções pequenas, responsabilidades claras e baixo acoplamento.
- Preserve compatibilidade com a versão Godot 4.x indicada em `project.godot` e nos documentos do projeto. Não use APIs de Godot 3.x.

## 2. REGRAS DE ALTERAÇÃO E SEGURANÇA

- Antes de editar, leia o arquivo completo quando o tamanho permitir e procure referências, sinais, cenas, recursos e chamadas relacionadas à mudança.
- Faça a menor alteração coerente que resolva a solicitação. Evite refatorações abrangentes não solicitadas.
- Preserve recursos, cenas, configurações e funcionalidades existentes que não façam parte da tarefa.
- Não apague, renomeie ou mova arquivos sem necessidade comprovada e sem explicar o impacto.
- Não altere configurações de exportação, pipeline de publicação, CI/CD, cache, service worker ou deployment sem verificar seus efeitos e a relação com a solicitação.
- Não inclua senhas, tokens, chaves de API, credenciais ou dados pessoais em código, logs, documentação, commits ou ZIPs.
- Não faça deploy, publicação, merge de Pull Request ou alteração destrutiva sem autorização explícita do usuário.
- Ao modificar um arquivo, mantenha sua codificação, quebras de linha, convenções de nomenclatura e estilo sempre que possível.
- Verifique referências a recursos e caminhos `res://` ao criar ou mover cenas e scripts.

## 3. TESTES E VALIDAÇÃO

- Para iterações pontuais, execute somente a suíte focada no módulo alterado (por exemplo, `godot --headless -s tests/<teste_especifico>.gd`, usando o executável e o caminho adequados ao sistema operacional).
- A bateria completa de regressão (`tests/run_all_tests.ps1`) deve ser executada para fechamento de marcos, CI ou quando solicitada explicitamente.
- Se a alteração envolver cenas, recursos ou configuração Godot, valide também referências, caminhos e carregamento das cenas quando o ambiente permitir.
- Se o teste não puder ser executado por falta da Godot, de dependências ou de assets locais, informe o bloqueio. Não transforme uma inspeção estática em alegação de teste executado.
- Ao concluir, informe quais testes foram executados, quais passaram/falharam e quais não puderam ser executados.

## 4. GIT, BRANCHES E COMMITS

- Não sobrescreva trabalho local não commitado.
- No Modo IDE Local, não faça sincronização com o remoto automaticamente. O usuário pode ter alterações locais mais recentes que o GitHub.
- No Modo ChatGPT / GitHub remoto, confirme a branch e o commit-base, trabalhe em branch própria e não escreva diretamente em `main` sem autorização explícita.
- Nunca use `git push --force`, `git reset --hard` ou `git clean -fd` sem autorização explícita e uma justificativa clara.
- Ao criar commits, use mensagens objetivas que descrevam a mudança.
- Ao abrir um Pull Request, descreva o comportamento alterado, os arquivos afetados e os testes realizados. Não faça merge sem autorização.

## 5. ENTREGA E RELATÓRIO

Ao concluir uma tarefa, apresente um resumo curto com:

1. O que foi implementado.
2. Quais arquivos foram criados ou modificados.
3. Quais testes e validações foram executados e seus resultados.
4. Limitações conhecidas ou etapas que dependem de assets, ferramentas ou autorização.
5. O caminho/link do ZIP, quando solicitado, e uma descrição precisa do que ele contém.

Não diga que o projeto inteiro foi atualizado, testado ou empacotado quando somente um subconjunto foi acessado. Diferencie claramente ZIP de arquivos alterados, ZIP do projeto-fonte e pacote de exportação/distribuição.

## 6. CONTROLES MOBILE E COMPATIBILIDADE

- O jogo deve preservar o suporte a PC e dispositivos móveis previsto na arquitetura.
- Ao alterar controles, UI ou layout, considere toque, multitouch, diferentes proporções de tela, orientação, escala e áreas seguras.
- Não remova controles de teclado, gamepad ou toque sem solicitação explícita.
- Ao mudar uma tela ou fluxo, verifique os caminhos de navegação e retorno, inclusive a cena principal definida em `project.godot`.
