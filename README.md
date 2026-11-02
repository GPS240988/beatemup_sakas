# Beat 'em Up 2.5D — Fundação Técnica, Combate e Multiplataforma

Projeto de um jogo estilo **beat 'em up** de progressão lateral para um jogador, desenvolvido com **Godot 4.x** e **GDScript tipado**.

Implementa movimentação em profundidade (2.5D), ordenação visual por profundidade (**Y-Sort**), sistema desacoplado de combate, inteligência artificial (FSM), interface e **suporte multiplataforma (PC & Mobile)**.

---

## 🎮 Controles

### No PC (Tela Limpa por padrão)
| Ação | Teclas Primárias | Teclas Secundárias |
| :--- | :--- | :--- |
| **Mover em 2.5D** | `W` (fundo) / `S` (frente) / `A` (esq) / `D` (dir) | Setas do Teclado |
| **Golpe / Ataque Básico** | `J` | `Barra de Espaço` |
| **Reiniciar a Fase** | `R` | — |

### No Mobile / Celular (Controles Virtuais na Tela)
* **Joystick Virtual (Canto Esquerdo)**: D-Pad analógico sensível a toque/arraste para movimentação nos eixos X e Y.
* **Botão [SOCO] (Canto Direito)**: Desfere o golpe corpo a corpo.
* **Botão [RST] (Canto Direito)**: Reinicia a fase instantaneamente.
* **Multitouch Ativo**: É possível mover com o polegar esquerdo e golpear com o polegar direito ao mesmo tempo.

---

## 📱 Alternar Controles Touch (PC & Mobile)

* No canto superior direito da tela, há um botão discreto: **`[📱 Controles Touch: LIGADO / DESLIGADO]`**.
* **Detecção Automática**:
  * Em **computadores (PC)**: O jogo inicia com a **tela limpa** (controles virtuais desligados). Você pode clicar no botão no topo para ligar e testar os controles virtuais com o mouse!
  * Em **dispositivos móveis (Celulares / Tablets)**: O jogo inicia com os **controles virtuais ligados** automaticamente. O jogador pode tocar no botão no topo para desligá-los caso use um controle Bluetooth/gamepad.

---

## ⚔️ Mecânicas de Combate 2.5D

1. **Regra de Acerto em Profundidade**:
   - Um ataque só causa dano se o alvo estiver dentro da tolerância do eixo Y (alinhamento no chão) e na frente do personagem dentro do alcance horizontal configurado.
   - Golpes nas costas do atacante ou fora da faixa de profundidade erram naturalmente.
2. **Dano Único por Golpe**:
   - Cada execução de ataque registra os alvos atingidos e impede que um mesmo golpe cause múltiplos danos ao mesmo alvo.
3. **Inteligência Artificial do Inimigo (`EnemyAI`)**:
   - Máquina de estados: `IDLE`, `CHASE`, `ATTACK`, `HURT`, `DEAD`.
   - Persegue o jogador, alinha-se nos eixos X/Y e desfere golpes com intervalo controlado.
   - Reage ao dano com recuo leve e flash visual.
   - Ao ser derrotado, deita-se no chão, desativa colisões e interrompe ações.
4. **Vida e Derrota**:
   - Gerenciada pelo [`HealthComponent`](file:///c:/Users/bobor/Documents/beat%20em%20up%20-%20sakas/scripts/components/health_component.gd).
   - Vida nunca desce abaixo de zero e personagens derrotados não sofrem dano adicional.
   - A derrota do jogador exibe um aviso claro de Game Over e bloqueia novos comandos até o reinício.

---

## 🚀 Como Abrir e Executar

1. Abra a **Godot Engine 4.x** (versão instalada: `4.7.2`).
2. Clique em **Import** e selecione o arquivo [`project.godot`](file:///c:/Users/bobor/Documents/beat%20em%20up%20-%20sakas/project.godot).
3. Pressione **Import & Edit**.
4. Pressione **F5** para iniciar o jogo.

---

## 🧪 Testes Automatizados Headless

O projeto inclui uma suite com **25 cenários automatizados** validando regras de dano, tolerância de profundidade, bloqueio de alvos derrotados e integridade de cenas. Para executar via terminal:

```powershell
& "$env:LOCALAPPDATA\Microsoft\WinGet\Links\godot_console.exe" --headless -s tests/combat_smoke_test.gd
```
*(Resultado: 25/25 testes aprovados)*
