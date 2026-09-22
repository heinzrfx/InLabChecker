# Header com marca e kit de UI compartilhado

**Data:** 22/09/2026
**Status:** aguardando revisao
**Epic:** feat(ui): header com marca e kit de UI compartilhado

Sub-projeto **1 de 4**. Os outros tres (icone de toolbar, secao Atualizacao,
repaginacao das 7 secoes) tem spec propria e dependem do kit que este
documento cria. Mockup: canvas "InLabChecker - Header, Kit e Atualizacao";
prototipo em 1:1: "Bancada do Header".

---

## 1. Problema

O topo do painel hoje (`ui/rollout_main.ms`, rollout `InLabChecker_Rollout`)
tem um radiobutton de lado e um botao "Reload Plugin" de 395x22. Dai vem
quatro problemas:

- **O produto nao se identifica.** A unica marca e a legenda da janela, que e
  a legenda do Max, nao nossa. A equipe pediu a referencia ArchToolz, que abre
  com uma faixa de marca.
- **Nao ha onde mostrar a versao.** A spec do updater (22/09) precisou inventar
  uma "tarja de aviso" — um `label visible:false` abaixo do Reload — porque
  **nao da pra trocar a legenda de um rollout em tempo de execucao**. E uma
  linha inteira do painel gasta so pra avisar.
- **Nao ha vocabulario visual.** Cada secao escolhe suas cores na hora. O
  `core/log.ms` tem quatro cores de status aprovadas pela equipe que **nada
  fora do log usa**.
- **O topo gasta duas linhas com o que nao e trabalho.** Lado do painel e
  Reload nao sao tarefa de artista; sao chrome ocupando a area util.

## 2. Decisoes do brainstorm

| Decisao | Escolha | Motivo |
| --- | --- | --- |
| Papel do header | Funcional, com o aviso de update embutido | A pastilha de versao **e** o aviso: nao gasta linha e e clicavel |
| Controles no header | Reload + pastilha de versao | Radio de lado e "salvar log" ficam onde estao — nao ganham nada subindo |
| Arte | PNG no repo (`ui/img/`) | Decisao do usuario; o pacote do updater e um zip do repo, entao a arte pega carona |
| Variante | **A** — bulbo (`Logo\9.png`) + texto | Ver secao 3: o lockup do `6.png` nao le no tamanho disponivel |
| Arquitetura | Kit dotNet compartilhado, casca nativa | `rollout`/`subRollout` continuam; so o conteudo vira dotNet |
| Cabecalho de secao colorido | **Fora** | Quem desenha a faixa do `subRollout` e o Max; nao ha como pintar por script |

## 3. Medicoes

Feitas em 22/09/2026 nesta maquina. Max 2024, MCP conectado em `safe_mode`.

### Arte

| Arquivo | Arte opaca dentro do canvas 1563x1563 | Proporcao |
| --- | --- | --- |
| `Logo\6.png` (lockup: bulbo + "artefacto") | 1295 x 513 | 2,52:1 |
| `Logo\9.png` (bulbo) | 1130 x 1522 | 0,74:1 |

O lockup do `6.png` e **diagonal** — bulbo em cima a esquerda, wordmark
embaixo a direita — e o "artefacto" e branco de traco fino. Numa faixa de 40 px
de altura o wordmark fica com ~7 px: ilegivel no painel do Max. Por isso a
variante A usa o bulbo sozinho e poe "InLabChecker" em texto. Beneficio
colateral: **e o mesmo asset do icone de toolbar** do sub-projeto 2.

### Cor

O ambar da marca foi amostrado do proprio logo: **`#E8A429`**, cor chapada,
sem gradiente.

As cores de status foram **lidas de `core/log.ms`**, nao deduzidas do mockup:

| Tipo | `InLab_CorDoTipo` | Hex |
| --- | --- | --- |
| `#ok` | `FromArgb 120 220 120` | `#78DC78` |
| `#err` | `FromArgb 235 90 90` | `#EB5A5A` |
| `#warn` | `FromArgb 230 180 90` | `#E6B45A` |
| `#info` | `FromArgb 210 210 210` | `#D2D2D2` |

Duas consequencias:

- **Acento e texto nao podem ser a mesma cor.** `#EB5A5A` sobre o fundo
  `#452626` da 3,8:1 — reprova para texto pequeno. O tom claro `#F0A9A9` da
  6,8:1. Entao cada status tem *acento* (bolinha, barra: precisa de 3:1) e
  *texto* (precisa de 4,5:1), separados.
- **O `#warn` muda.** Sai `#E6B45A`, entra o `#E8A429` do logo, para marca e
  aviso serem a mesma cor. E a unica alteracao que este sub-projeto faz no
  `core/log.ms`.

### Altura

| Item | Delta |
| --- | --- |
| Header novo | +56 px |
| Botao "Reload Plugin" (22 px + espacamento) | -26 px |
| Legenda da janela do Max (nao e nossa, nao muda) | 0 |
| **Liquido no corpo do painel** | **+30 px** |

Hoje: `createDialog InLabChecker_Rollout 446 600` e
`subRollout subSecoes width:438 height:538`. **O 600 de hoje nunca foi medido**
— o proprio comentario no arquivo diz "valor estimado, nao testado no Max
ainda" (15/Set). Entao a altura final **nao e escolhida nesta spec**: e medida
no Max durante a implementacao, com o header no lugar, e o numero medido entra
no codigo com a data.

## 4. Arquitetura

Dois arquivos novos, tres arquivos alterados.

### `ui/kit.ms` — novo, antes de `ui/rollout_main.ms` no manifesto

O vocabulario visual compartilhado. Mexer numa cor aqui muda o painel inteiro.

```
INLAB_KIT_CORES          -- nome (name) -> #(r,g,b)
fn InLab_Kit_Cor nome    -- -> System.Drawing.Color; magenta + log #err se o nome nao existir
fn InLab_Kit_Fonte tam bold:false   -- -> System.Drawing.Font ("Segoe UI")
fn InLab_Kit_BotaoIcone btn         -- aplica o estilo chato escuro a um dotNet Button
fn InLab_Kit_Pastilha ctrl estado texto   -- pinta a pastilha de versao
```

Nomes de cor: `FUNDO_HEADER`, `FUNDO_PAINEL`, `SUPERFICIE`, `LOG`, `MARCA`, e
por status `OK_*`, `WARN_*`, `ERR_*`, `INFO_*`, `PROGRESSO_*` nos sufixos
`_ACENTO`, `_FUNDO`, `_BORDA`, `_TEXTO`.

`PROGRESSO` (azul `#6F8FB0`) **nao vem do log** — e um papel novo, para
"trabalho em andamento", que os estados `#checando` e `#baixando` usam. Os
outros quatro espelham `core/log.ms` e sao travados por teste (secao 8). Fica
explicito aqui porque e a unica cor do kit sem origem no codigo existente.

**YAGNI deliberado:** o kit nasce so com o que o header consome. Caixa de
status e barra de progresso entram no sub-projeto 3, quando existir a secao
Atualizacao que as usa. Escrever widget sem consumidor e escrever widget
errado.

### `ui/header.ms` — novo, depois do kit

O header **nao e um rollout**. E um `dotNetControl` do tipo
`System.Windows.Forms.Panel` declarado dentro de `InLabChecker_Rollout`, e os
filhos (PictureBox, labels, botao, pastilha) sao criados em codigo e adicionados
ao `.Controls`.

Isso escapa da pegadinha "rollout nao cria controle em tempo de execucao"
registrada no CLAUDE.md: a restricao vale para controle **de rollout**. Filho de
`Panel` dotNet e criado a hora que quiser.

```
fn InLab_Header_Montar pnl      -- constroi os filhos; idempotente (limpa .Controls antes)
                                -- termina repintando o estado corrente, nao um #INFO fixo
fn InLab_Header_Estado estado versao:unsupplied pct:0
    -- estado: #ocioso | #checando | #disponivel | #baixando | #erro
    -- pct: so usado em #baixando
    -- e a API que o sub-projeto 3 chama; aqui ela ja existe e so nao e chamada por ninguem
    -- PRE-CONDICAO: chamar na thread principal do Max; quem marshala e o chamador
global InLab_Header_Pnl, InLab_Header_Pastilha, InLab_Header_EstadoAtual, InLab_Header_Versao
```

**Todo estado em global.** Handler de evento dotNet nao enxerga `local` do
rollout que o declarou — causa-raiz ja documentada no cabecalho de
`ui/splash.ms`. Nenhum handler deste arquivo referencia local de rollout.

### `ui/img/` — novo

| Arquivo | Tamanho | Uso |
| --- | --- | --- |
| `header_bulbo.png` | 120 x 160 (4x de 30x40) | `PictureBox.SizeMode = Zoom` |

Entregue em 4x e reduzido pelo `Zoom` para sair limpo em qualquer escala de
DPI do Windows. Os PNGs de toolbar sao do sub-projeto 2 e nao entram aqui.

**Se o PNG nao existir, o header monta assim mesmo**: sem a imagem, so com a
tipografia, e loga `#warn`. Ver secao 6 — o pacote do updater pode chegar sem
os assets e passar na validacao.

### Alteracoes

| Arquivo | O que muda |
| --- | --- |
| `InLabChecker.ms` | `ui/kit.ms` e `ui/header.ms` entram em `INLAB_MODULOS`, nessa ordem, antes de `ui/rollout_main.ms` |
| `ui/rollout_main.ms` | `btnReload` sai; entra `dotNetControl pnlHeader ... pos:[0,0] height:56`; `rdoLado` e `subRollout` descem; `on open` chama `InLab_Header_Montar` e `InLab_Header_Estado InLab_Header_EstadoAtual` (o estado corrente, que nasce `#ocioso` e sobrevive ao Reload), os dois sob `try/catch` pra que uma falha no header nao impeca os `AddSubRollout` |
| `core/log.ms` | `#warn` passa de `FromArgb 230 180 90` para `FromArgb 232 164 41` |

## 5. Estados da pastilha

Os controles **existem sempre**; so mudam cor, texto e `.Cursor`.

| Estado | Acento | Fundo | Borda | Texto | Clicavel |
| --- | --- | --- | --- | --- | --- |
| `#ocioso` | `#78DC78` | `#333333` | `#454545` | `#A8A8A8` | nao |
| `#checando` | `#6F8FB0` | `#2F3742` | `#3C4654` | `#A8B6C4` | nao |
| `#disponivel` | `#E8A429` | `#4A3C22` | `#9A7C34` | `#F0C883` | **sim** — abre a secao Atualizacao |
| `#baixando` | `#6F8FB0` | `#2F3742` | `#3C4654` | `#A8B6C4` | nao — mostra percentual |
| `#erro` | `#EB5A5A` | `#452626` | `#6E3838` | `#F0A9A9` | **sim** — abre o log do erro |

Em `#baixando` a pastilha troca de forma: percentual em cima, barra de 3 px
embaixo. E por isso que a barra de progresso fixa removida em 15/Set **nao
precisa voltar**.

Neste sub-projeto a pastilha nasce presa em `#ocioso`, exibindo a versao
instalada. Os outros quatro estados so tem quem os dispare no sub-projeto 3;
o codigo deles ja fica escrito e testavel por chamada direta.

## 6. O que isto muda na spec do updater

A spec `2026-09-22-updater-design.md` precisa de tres correcoes. Elas nao sao
feitas aqui — ficam registradas para a implementacao daquele epico.

1. **A secao "Tarja de aviso em `ui/rollout_main.ms`" deixa de existir.** Ela
   resolvia com um `label visible:false` o problema de a legenda do rollout nao
   mudar. A pastilha do header resolve melhor: sempre visivel, sem gastar linha,
   e clicavel.
2. **A validacao pos-extracao precisa cobrir os assets.** Hoje ela confere os
   caminhos de `INLAB_MODULOS`, que sao todos `.ms`. Um pacote sem
   `ui/img/header_bulbo.png` **passa** na validacao. Duas defesas, as duas
   necessarias: o header desenha sem a imagem (secao 4, ja nesta spec), e a
   lista de validacao ganha os assets (naquela spec).
3. **O icone de toolbar mora fora do repo**, em `usericons`, na pasta do
   usuario — o updater nao o alcanca. Tratado no sub-projeto 2.

## 7. Riscos e sondagens

Tudo abaixo e sondado no Max **antes** de escrever o codigo final, na disciplina
que o CLAUDE.md ja exige para API que varia por build.

| Risco | Por que importa | Como resolver |
| --- | --- | --- |
| **Rollout tem margem interna propria** | Se o `Panel` em `pos:[0,0]` nao encostar nas bordas da janela, o header vira uma faixa flutuando com margem — nao a faixa cheia do mockup | Sondar. Se nao encostar: ou aceita a margem, ou o header perde o fundo proprio e vira so os controles |
| PNG com alpha sobre Panel escuro | PictureBox pode compor o alpha contra branco e deixar halo na borda do bulbo | Sondar com o PNG real; se houver halo, `BackColor` do PictureBox igual ao do Panel |
| DPI a 150% | Header de 56 px e texto de 10 px podem virar outra coisa | Medir no Max com escala do Windows em 150% |
| Altura util do `subRollout` | Os +30 px precisam sair de algum lugar, e o 600 de hoje nunca foi medido | Medir com o header montado; o numero medido vai pro codigo com a data |
| Reload dentro do header | `InLab_RecarregarPlugin()` refaz o `fileIn` de tudo e reabre a UI — inclusive do `ui/header.ms` que contem o botao que disparou a chamada | Testar explicitamente; se quebrar, o clique agenda o reload em vez de chamar direto |

O ultimo e o mais serio: e a mesma classe de problema do passo 5 do updater
(codigo que se substitui enquanto roda), ja documentada naquela spec.

## 8. Testes

`tests/test_kit_header.ms`, na forma de `tests/test_renomear_produto.ms`:
pre-declarar globais, `fileIn` so dos modulos necessarios, trocar `InLab_Log`
por logger de arquivo, `checar "descricao" condicao`, limpar no fim.
Saida em `(getDir #temp)\inlab_test_kit_header.txt`.

Cobre o que da pra verificar sem olho:

- `InLab_Kit_Cor` devolve a cor certa para cada nome, e cor de falta + log para
  nome inexistente.
- Os quatro status do kit batem com `InLab_CorDoTipo` do `core/log.ms` — o teste
  quebra se alguem mudar um dos dois lados sem o outro.
- `InLab_Header_Estado` aceita os 5 estados e rejeita um sexto sem excecao.
- `InLab_Header_Montar` roda com `ui/img/header_bulbo.png` ausente, sem excecao
  e com `#warn` no log.
- `InLab_Header_Montar` chamado duas vezes nao duplica controle.

Aparencia — alinhamento, legibilidade a 150%, traco do bulbo — nao tem teste:
e validada a olho no Max contra o prototipo "Bancada do Header", em 1:1.

## 9. Fora de escopo

- Icone de toolbar do Max (sub-projeto 2).
- Secao Atualizacao e qualquer backend de updater (sub-projeto 3).
- Repaginacao das 7 secoes existentes (sub-projeto 4).
- Variante B do header e o lockup `6.png` — descartados, registrados no canvas.
- Cabecalho de secao colorido — a linguagem nao permite.
- Unificar as strings de versao espalhadas em 4 arquivos: e do
  `core/versao.ms`, na spec do updater. Aqui a pastilha le a versao de onde
  ela ja estiver.
