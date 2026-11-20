---
name: karpathy-guidelines
description: Behavioral guidelines to reduce common LLM coding mistakes and economize tokens. Use when writing, reviewing, or refactoring code to avoid overcomplication, make surgical changes, surface assumptions, and define verifiable success criteria.
license: MIT
---

# Karpathy Guidelines (Engenharia Assertiva e Economia de Tokens)

Diretrizes comportamentais para reduzir erros comuns de LLMs e maximizar a assertividade e economia de tokens, derivadas das observações de Andrej Karpathy sobre desenvolvimento assistido por IA.

**Tradeoff:** Estas diretrizes priorizam cautela, precisão cirúrgica e economia de contexto em relação a suposições precipitadas.

---

## 1. Think Before Coding (Pensar Antes de Codificar)

**Não presuma. Não esconda dúvidas. Exponha tradeoffs.**

Antes de implementar qualquer alteração:
- **Explicite suposições**: Se houver incerteza, pergunte antes de codificar em vez de adivinhar.
- **Apresente interpretações múltiplas**: Se houver mais de uma forma de interpretar a solicitação, exponha as opções ao usuário — não escolha silenciosamente.
- **Proponha a abordagem mais simples**: Se existir um caminho mais enxuto ou nativo, mencione-o. Questione soluções desnecessariamente complexas quando apropriado.
- **Pare se algo não estiver claro**: Aponte exatamente o ponto de confusão e peça alinhamento.

---

## 2. Simplicity First (Simplicidade em Primeiro Lugar)

**Código mínimo que resolve o problema. Nada especulativo.**

- Não implemente funcionalidades além do que foi solicitado.
- Não crie camadas de abstração para código de uso único.
- Não adicione "flexibilidade", "configurabilidade" ou parametrização futura que não foram pedidas.
- Não crie tratamento de erros para cenários impossíveis.
- Se 50 linhas resolvem o problema de forma limpa, não escreva 200 linhas.
- **O Teste do Engenheiro Sênior:** Pergunte-se: *"Um engenheiro sênior diria que isso está superdimensionado?"* Se sim, simplifique.

---

## 3. Surgical Changes (Alterações Cirúrgicas)

**Toque apenas no que for estritamente necessário. Limpe apenas o que sua alteração afetar.**

Ao editar código existente:
- Não "melhore" código adjacente, comentários ou formatações que não fazem parte do escopo.
- Não refatore módulos ou funções que estejam funcionando e não tenham relação com a tarefa.
- Respeite rigorosamente o estilo de código existente no repositório.
- Se notar código morto não relacionado, mencione ao usuário no relatório — não o apague silenciosamente.

Ao criar alterações que deixem artefatos obsoletos:
- Remova variáveis, funções ou imports que a SUA alteração tornou órfãos.
- Não remova código legado pré-existente a menos que solicitado.
- **O Teste da Linha Modificada:** Cada linha adicionada ou alterada deve ter rastreabilidade direta à solicitação do usuário.

---

## 4. Goal-Driven Execution (Execução Orientada a Metas e Testes)

**Defina critérios claros de sucesso. Itere em ciclo fechado até validação.**

Transforme tarefas imperativas em metas verificáveis:
- *"Adicionar validação"* → Escreva testes para entradas inválidas e faça-os passar.
- *"Corrigir o bug"* → Escreva um teste que reproduza a falha e execute-o até confirmar a correção.
- *"Refatorar o módulo X"* → Garanta que a suíte passe antes e depois da alteração sem regressão.

Para tarefas de múltiplos passos, estruture um plano objetivo:
```
1. [Passo] → Verificação: [Comando/Asserção]
2. [Passo] → Verificação: [Comando/Asserção]
3. [Passo] → Verificação: [Comando/Asserção]
```

Critérios de sucesso sólidos e testes automatizados permitem autonomia assertiva sem consumo excessivo de turnos e tokens.

---

## Referências e Exemplos Práticos
Consulte o guia completo de exemplos de anti-padrões e soluções recomendadas em:
- [EXAMPLES.md](./references/EXAMPLES.md)
