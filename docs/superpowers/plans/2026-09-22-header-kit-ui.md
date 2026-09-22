# Header com marca e kit de UI — Plano de Implementacao

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar o topo do painel do InLabChecker por uma faixa de 56 px com a marca, o botao Reload e uma pastilha de versao que e o proprio aviso de atualizacao, apoiada num modulo de cores e widgets compartilhado.

**Architecture:** Dois modulos novos no manifesto. `ui/kit.ms` guarda cores, fonte e os dois widgets que o header usa; `ui/header.ms` monta um `System.Windows.Forms.Panel` dentro do rollout principal e expoe `InLab_Header_Estado`, a API que o sub-projeto 3 vai chamar. A casca segue sendo `rollout`/`subRollout` — so o conteudo do topo vira dotNet.

**Tech Stack:** MaxScript (3ds Max 2024), dotNet via `dotNetObject`/`dotNetClass` (System.Windows.Forms, System.Drawing), MCP do 3ds Max para rodar e medir.

**Spec:** `docs/superpowers/specs/2026-09-22-header-kit-ui-design.md`

## Global Constraints

Valem para todas as tarefas.

- **Portugues em tudo:** codigo, comentario, log e UI. Specs e planos sem acento; codigo e log com acento normal.
- **Prefixo:** funcao publica `InLab_`, constante `INLAB_MAIUSCULO`.
- **Modulo novo so existe se entrar em `INLAB_MODULOS`** (`InLabChecker.ms`). Arquivo fora do manifesto nao e carregado.
- **Cabecalho de arquivo:** bloco `/* === ... === */` com caminho, o que faz, e as decisoes e correcoes com data. Manter o historico ao mudar comportamento.
- **Handler de evento dotNet nao enxerga `local` de rollout.** Todo estado em global, todo handler e funcao de nivel superior que so le global. Causa-raiz no cabecalho de `ui/splash.ms`.
- **Nunca engolir erro sem `InLab_Log`.** API que varia por build vai em cadeia de `try/catch` registrando qual variante rodou.
- **Nao dar mudanca como validada sem rodar no Max.** MCP conectado (Max 2024, `safe_mode`). Se cair, avisar.
- **MCP em `safe_mode` bloqueia `createFile`/`copyFile` no codigo enviado.** Teste roda por `fileIn` do arquivo em disco, onde `createFile` funciona; para escrever arquivo por codigo enviado, `openFile ... mode:"wt"`.
- **Chamada MCP acima de 120 s vai para segundo plano** e prende a thread principal do Max enquanto isso.
- **Cores travadas** (spec, secao 3): marca `#E8A429` (232,164,41), amostrada do logo. Status espelham `core/log.ms`: `#ok` (120,220,120), `#err` (235,90,90), `#info` (210,210,210), e `#warn` passa a ser a cor da marca.
- **Commit:** portugues, assunto sem acento, `feat(escopo): ...` / `fix(escopo): ...`. Branch `feat/header-kit-ui` a partir de `docs/header-kit-spec` (onde a spec esta).
- **Versao exibida:** `0.11` — a mais alta declarada hoje no repo (`InLabChecker.ms:4`). As strings de versao divergem entre 4 arquivos; unificar e do `core/versao.ms`, na spec do updater. Nao inventar numero novo.

---

## Estrutura de arquivos

| Arquivo | Responsabilidade | Tarefa |
| --- | --- | --- |
| `ui/kit.ms` | **Criar.** Cores nomeadas, fonte, estilo de botao-icone, pintura da pastilha. Nada de layout. | 2 |
| `core/log.ms` | **Alterar** uma linha: `#warn` passa a ser a cor da marca. | 2 |
| `ui/header.ms` | **Criar.** Monta os controles do header e expoe `InLab_Header_Estado`. Nada de cor literal — tudo vem do kit. | 3, 4 |
| `ui/img/header_bulbo.png` | **Criar.** Arte 120x160 gerada de `Logo\9.png`. | 3 |
| `ui/rollout_main.ms` | **Alterar.** `btnReload` sai, `pnlHeader` entra, controles descem. | 5 |
| `InLabChecker.ms` | **Alterar.** `ui\kit.ms` e `ui\header.ms` no manifesto. | 5 |
| `tests/test_kit_header.ms` | **Criar.** Cresce nas tarefas 2, 3 e 4. | 2, 3, 4 |
| `docs/superpowers/specs/2026-09-22-header-sondagem.md` | **Criar.** Registro do que o Max respondeu. | 1 |

**Por que dois modulos e nao um:** o kit nao sabe o que e um header, e o header nao decide cor. O sub-projeto 4 vai repaginar 7 secoes usando o kit sem tocar no header; o sub-projeto 3 vai chamar `InLab_Header_Estado` sem tocar no kit.

---

### Task 1: Sondagem no Max

Antes de escrever o header, descobrir duas coisas que decidem o desenho. Nada
do codigo desta tarefa fica no repo — so o documento com as respostas.

**Files:**
- Create: `docs/superpowers/specs/2026-09-22-header-sondagem.md`

**Interfaces:**
- Consumes: nada.
- Produces: as respostas que as tarefas 3 e 5 usam — se o `Panel` em `pos:[0,0]` encosta nas bordas da janela, e se o PNG com alpha deixa halo sobre fundo escuro.

- [ ] **Step 1: Confirmar que o MCP esta conectado**

Rodar `get_bridge_status`. Esperado: `"connected": true`, `"maxVersion": 2024`.
Se nao estiver conectado, **parar e avisar o usuario** — nada desta tarefa
funciona sem o Max.

- [ ] **Step 2: Sondar a margem interna do rollout**

A pergunta: um `dotNetControl` em `pos:[0,0]` encosta na borda da janela, ou o
rollout reserva margem propria? Se reservar, o header nao e a faixa cheia do
mockup.

Rodar via `execute_maxscript`:

```maxscript
try (destroyDialog _inlabSondaMargem) catch()
rollout _inlabSondaMargem "sonda" width:446
(
    dotNetControl pnl "System.Windows.Forms.Panel" pos:[0,0] width:446 height:56
    on _inlabSondaMargem open do
    (
        pnl.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 232 164 41
        local pai = pnl.Parent
        format "MARGEM pnl.Left=% pnl.Top=% pnl.Width=% pnl.Height=%\n" pnl.Left pnl.Top pnl.Width pnl.Height
        format "MARGEM paiClient=% x %\n" pai.ClientSize.Width pai.ClientSize.Height
    )
)
createDialog _inlabSondaMargem 446 200
```

Ler a saida. `pnl.Left == 0` e `pnl.Width == paiClient.Width` significa faixa
cheia. Qualquer outra coisa e margem, e o numero exato dela e o que interessa.

- [ ] **Step 3: Sondar o alpha do PNG sobre fundo escuro**

A pergunta: o `PictureBox` compoe o alpha contra branco e deixa halo claro na
borda do bulbo?

Gerar a arte de teste no Windows (PowerShell, fora do Max):

```powershell
Add-Type -AssemblyName System.Drawing
$dst = New-Object System.Drawing.Bitmap(120,160,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$src = New-Object System.Drawing.Bitmap("G:\Meu Drive\Trabalhos\2026\Artefacto\Logo\9.png")
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
# bbox medida do 9.png: x=217 y=23 w=1130 h=1522 -> cabe em 160 pela altura (119x160)
$g.DrawImage($src, (New-Object System.Drawing.Rectangle(0,0,119,160)), 217,23,1130,1522, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$dst.Save("$env:TEMP\inlab_sonda_bulbo.png",[System.Drawing.Imaging.ImageFormat]::Png)
$dst.Dispose(); $src.Dispose()
"ok"
```

Depois, no Max:

```maxscript
try (destroyDialog _inlabSondaAlpha) catch()
rollout _inlabSondaAlpha "sonda alpha" width:200
(
    dotNetControl pnl "System.Windows.Forms.Panel" pos:[0,0] width:200 height:70
    on _inlabSondaAlpha open do
    (
        pnl.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 31 31 31
        local arte = (systemTools.getEnvVariable "TEMP") + "\\inlab_sonda_bulbo.png"
        local pb = dotNetObject "System.Windows.Forms.PictureBox"
        pb.Location = dotNetObject "System.Drawing.Point" 12 15
        pb.Size = dotNetObject "System.Drawing.Size" 30 40
        pb.SizeMode = (dotNetClass "System.Windows.Forms.PictureBoxSizeMode").Zoom
        pb.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 31 31 31
        local tmp = dotNetObject "System.Drawing.Bitmap" arte
        pb.Image = dotNetObject "System.Drawing.Bitmap" tmp
        tmp.Dispose()
        pnl.Controls.Add pb
        format "ALPHA carregado de %\n" arte
    )
)
createDialog _inlabSondaAlpha 200 90
```

Note o `Bitmap(tmp)` seguido de `tmp.Dispose()`: **`Image.FromFile` e
`Bitmap(String)` mantem o arquivo travado** enquanto a imagem viver. Um PNG
travado impediria o updater de renomear a pasta de instalacao no passo 5 dele.
Copiar para um `Bitmap` novo e descartar o original solta o arquivo.

Capturar a tela com `capture_screen` e **olhar a borda do bulbo**: halo claro,
ou traco limpo contra o `#1F1F1F`?

- [ ] **Step 4: Fechar as sondas**

```maxscript
try (destroyDialog _inlabSondaMargem) catch()
try (destroyDialog _inlabSondaAlpha) catch()
"sondas fechadas"
```

- [ ] **Step 5: Escrever o documento da sondagem**

Criar `docs/superpowers/specs/2026-09-22-header-sondagem.md` na forma de
`docs/superpowers/specs/2026-09-18-autouv-fase0-apis.md`: sem acento, data e
maquina no topo, uma tabela `Sondagem | Resultado`, e abaixo de cada resultado
o que ele decide. Registrar os numeros exatos que sairam, nao "funcionou".

Cobrir:

| Sondagem | O que registrar |
| --- | --- |
| Margem do rollout | `pnl.Left`, `pnl.Top`, `pnl.Width` e o `ClientSize` do pai, e a decisao: faixa cheia ou faixa com margem de N px |
| Alpha sobre `#1F1F1F` | halo sim/nao; se sim, que `BackColor` no `PictureBox` resolveu |
| Trava de arquivo | que `Bitmap(tmp)` + `Dispose` e o caminho usado, e por que (updater renomeia a pasta) |

- [ ] **Step 6: Commit**

```bash
git checkout -b feat/header-kit-ui
git add docs/superpowers/specs/2026-09-22-header-sondagem.md
git commit -m "docs(ui): sondagem de margem de rollout e alpha de PNG no Max 2024"
```

---

### Task 2: `ui/kit.ms` — a paleta

**Files:**
- Create: `ui/kit.ms`
- Create: `tests/test_kit_header.ms`
- Modify: `core/log.ms` (a linha do `#warn` em `InLab_CorDoTipo`)

**Interfaces:**
- Consumes: `InLab_Log msg tipo:` (de `core/log.ms`), `InLab_CorDoTipo tipo` (idem).
- Produces:
  - `INLAB_KIT_CORES` — array de `#(<name>, #(r,g,b))`.
  - `fn InLab_Kit_Cor nome` -> `System.Drawing.Color`. Nome desconhecido: loga `#err` e devolve magenta (255,0,255), para a falha aparecer na tela em vez de passar batido.
  - `fn InLab_Kit_Fonte tam bold:false` -> `System.Drawing.Font`, familia "Segoe UI", `tam` em **pontos**.
  - `fn InLab_Kit_BotaoIcone btn` -> o proprio `btn`, com o estilo chato escuro aplicado.
  - `fn InLab_Kit_Pastilha ctrl tipo texto clicavel:false` -> `ctrl`. `tipo` e `#OK`, `#WARN`, `#ERR`, `#INFO` ou `#PROGRESSO`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `tests/test_kit_header.ms`. A forma vem de
`tests/test_renomear_produto.ms`: globais pre-declarados **antes** do bloco
(o bloco compila antes de os `fileIn` rodarem), `InLab_Log` trocado por um
logger de arquivo, `checar "descricao" condicao`, saida em `(getDir #temp)`.

```maxscript
/*
 tests\test_kit_header.ms — teste automatico de ui\kit.ms e ui\header.ms
 RODAR NUMA CENA QUALQUER: nao cria nem apaga objeto de cena.
 Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_kit_header.txt (PASS/FAIL por item).
*/
global InLab_Log, InLab_CorDoTipo
global INLAB_KIT_CORES, InLab_Kit_Cor, InLab_Kit_Fonte
global InLab_Kit_BotaoIcone, InLab_Kit_Pastilha
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_kit_header.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn corIgual a b = (a.R == b.R and a.G == b.G and a.B == b.B)

    local logOriginal = InLab_Log

    try
    (
        -- ATENCAO A ORDEM: core\log.ms DEFINE InLab_Log. Trocar o logger antes
        -- deste fileIn nao adianta — o fileIn redefine por cima e o teste passa
        -- a escrever no RichTextBox (ou em nada) em vez do arquivo de saida.
        -- Por isso o fileIn vem primeiro e a troca vem depois.
        fileIn (raiz + @"core\log.ms")
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )

        fileIn (raiz + @"ui\kit.ms")

        -- 1. CORES BASICAS
        local marca = InLab_Kit_Cor #MARCA
        checar "MARCA e o ambar amostrado do logo (232,164,41)" (marca.R == 232 and marca.G == 164 and marca.B == 41)
        local fundo = InLab_Kit_Cor #FUNDO_HEADER
        checar "FUNDO_HEADER e #1F1F1F" (fundo.R == 31 and fundo.G == 31 and fundo.B == 31)

        -- 2. O KIT NAO PODE DIVERGIR DO LOG
        -- Trava os dois lados: quebra se alguem mudar um sem o outro.
        checar "OK_ACENTO == InLab_CorDoTipo #ok"     (corIgual (InLab_Kit_Cor #OK_ACENTO)   (InLab_CorDoTipo #ok))
        checar "ERR_ACENTO == InLab_CorDoTipo #err"   (corIgual (InLab_Kit_Cor #ERR_ACENTO)  (InLab_CorDoTipo #err))
        checar "WARN_ACENTO == InLab_CorDoTipo #warn" (corIgual (InLab_Kit_Cor #WARN_ACENTO) (InLab_CorDoTipo #warn))
        checar "INFO_ACENTO == InLab_CorDoTipo #info" (corIgual (InLab_Kit_Cor #INFO_ACENTO) (InLab_CorDoTipo #info))
        checar "WARN_ACENTO e a cor da MARCA" (corIgual (InLab_Kit_Cor #WARN_ACENTO) marca)

        -- 3. PROGRESSO nao vem do log: e papel novo
        local p = InLab_Kit_Cor #PROGRESSO_ACENTO
        checar "PROGRESSO_ACENTO e #6F8FB0" (p.R == 111 and p.G == 143 and p.B == 176)

        -- 4. OS 5 TIPOS TEM OS 4 SUFIXOS
        local faltando = #()
        for t in #("OK", "WARN", "ERR", "INFO", "PROGRESSO") do
            for s in #("_ACENTO", "_FUNDO", "_BORDA", "_TEXTO") do
            (
                local nm = (t + s) as name
                local achou = false
                for par in INLAB_KIT_CORES where par[1] == nm do achou = true
                if not achou do append faltando (t + s)
            )
        checar ("Todos os 20 nomes de status existem (faltando: " + faltando as string + ")") (faltando.count == 0)

        -- 5. NOME DESCONHECIDO: magenta e log, sem excecao
        local ruim = InLab_Kit_Cor #NAO_EXISTE
        checar "Cor desconhecida devolve magenta" (ruim.R == 255 and ruim.G == 0 and ruim.B == 255)

        -- 6. FONTE
        local f = InLab_Kit_Fonte 10.5
        checar "Fonte e Segoe UI" (f.FontFamily.Name == "Segoe UI")
        checar "Fonte respeita o tamanho" (abs (f.Size - 10.5) < 0.01)
        local fb = InLab_Kit_Fonte 10.5 bold:true
        checar "Fonte bold e bold" (fb.Bold == true)
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCECAO: " + getCurrentException())
    )

    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluido — %\n" arqSaida
)
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Via MCP:

```maxscript
resetMaxFile #noPrompt
fileIn @"G:\Meu Drive\GitHub\InLabChecker\tests\test_kit_header.ms"
```

Depois ler o arquivo de saida:

```maxscript
local f = openFile ((getDir #temp) + "\\inlab_test_kit_header.txt")
local s = ""
while not (eof f) do s += (readLine f) + "\n"
close f
s
```

Esperado: `EXCECAO:` citando `ui\kit.ms` inexistente. **O arquivo de saida e a
unica fonte de verdade** — nao concluir nada pelo que o Listener mostrou.

- [ ] **Step 3: Escrever `ui/kit.ms`**

```maxscript
/*
================================================================================
 ui\kit.ms — v0.12 (22/09/2026): vocabulario visual compartilhado
--------------------------------------------------------------------------------
 O QUE E: as cores, a fonte e os dois widgets que o header usa. Nao sabe o que
 e um header nem o que e uma secao — so entrega cor e estilo. Mexer numa cor
 aqui muda o painel inteiro.

 DE ONDE VEM CADA COR (medido em 22/09/2026, ver
 docs\superpowers\specs\2026-09-22-header-kit-ui-design.md secao 3):
   - MARCA #E8A429: amostrada do proprio logo (Logo\9.png), cor chapada.
   - OK / ERR / INFO: lidas de InLab_CorDoTipo em core\log.ms. Sao as cores
     que a equipe aprovou em 13/Jul; o kit promove elas do log pro painel.
   - WARN: passou de #E6B45A para a cor da MARCA em 22/09, pra marca e aviso
     serem a mesma cor. Unica alteracao deste modulo no core\log.ms.
   - PROGRESSO #6F8FB0: NAO vem do log. E papel novo — "trabalho em andamento"
     — que os estados #checando e #baixando usam.

 POR QUE ACENTO E TEXTO SAO CORES DIFERENTES: a cor do log serve de bolinha
 (grafico, precisa 3:1) mas reprova como texto pequeno sobre o fundo colorido.
 #EB5A5A sobre #452626 da 3,8:1; o tom claro #F0A9A9 da 6,8:1.

 YAGNI: nasce so com o que o header consome. Caixa de status e barra de
 progresso entram quando a secao Atualizacao existir (sub-projeto 3).
================================================================================
*/

global INLAB_KIT_CORES
global InLab_Kit_Cor, InLab_Kit_Fonte, InLab_Kit_BotaoIcone, InLab_Kit_Pastilha

INLAB_KIT_CORES = #(
    -- superficies
    #(#FUNDO_HEADER,     #( 31,  31,  31)),
    #(#FUNDO_PAINEL,     #( 43,  43,  43)),
    #(#SUPERFICIE,       #( 63,  63,  63)),
    #(#LOG,              #( 35,  35,  35)),
    -- marca
    #(#MARCA,            #(232, 164,  41)),
    -- texto
    #(#TEXTO_FORTE,      #(240, 240, 240)),
    #(#TEXTO,            #(216, 216, 216)),
    #(#TEXTO_FRACO,      #(138, 138, 138)),
    -- botao de icone
    #(#BOTAO_FUNDO,      #( 58,  58,  58)),
    #(#BOTAO_BORDA,      #( 74,  74,  74)),
    #(#BOTAO_ICONE,      #(208, 208, 208)),
    -- status: acento espelha core\log.ms; fundo/borda/texto sao do painel
    #(#OK_ACENTO,        #(120, 220, 120)),
    #(#OK_FUNDO,         #( 49,  58,  46)),
    #(#OK_BORDA,         #( 58,  74,  54)),
    #(#OK_TEXTO,         #(169, 214, 155)),
    #(#WARN_ACENTO,      #(232, 164,  41)),
    #(#WARN_FUNDO,       #( 74,  60,  34)),
    #(#WARN_BORDA,       #(154, 124,  52)),
    #(#WARN_TEXTO,       #(240, 200, 131)),
    #(#ERR_ACENTO,       #(235,  90,  90)),
    #(#ERR_FUNDO,        #( 69,  38,  38)),
    #(#ERR_BORDA,        #(110,  56,  56)),
    #(#ERR_TEXTO,        #(240, 169, 169)),
    #(#INFO_ACENTO,      #(210, 210, 210)),
    #(#INFO_FUNDO,       #( 51,  51,  51)),
    #(#INFO_BORDA,       #( 69,  69,  69)),
    #(#INFO_TEXTO,       #(168, 168, 168)),
    #(#PROGRESSO_ACENTO, #(111, 143, 176)),
    #(#PROGRESSO_FUNDO,  #( 47,  55,  66)),
    #(#PROGRESSO_BORDA,  #( 60,  70,  84)),
    #(#PROGRESSO_TEXTO,  #(168, 182, 196))
)

-- Cor por nome. Nome errado nao passa batido: vira magenta na tela e #err no
-- log, pra aparecer na primeira olhada em vez de virar um cinza qualquer.
fn InLab_Kit_Cor nome =
(
    local rgb = undefined
    for par in INLAB_KIT_CORES where par[1] == nome do rgb = par[2]
    if rgb == undefined then
    (
        InLab_Log ("Kit: cor desconhecida '" + (nome as string) + "' — usando magenta.") tipo:#err
        (dotNetClass "System.Drawing.Color").FromArgb 255 0 255
    )
    else (dotNetClass "System.Drawing.Color").FromArgb rgb[1] rgb[2] rgb[3]
)

-- tam em PONTOS, nao pixels: e o que System.Drawing.Font recebe.
fn InLab_Kit_Fonte tam bold:false =
(
    local estilo = if bold then (dotNetClass "System.Drawing.FontStyle").Bold
                   else (dotNetClass "System.Drawing.FontStyle").Regular
    dotNetObject "System.Drawing.Font" "Segoe UI" (tam as float) estilo
)

fn InLab_Kit_BotaoIcone btn =
(
    btn.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
    btn.FlatAppearance.BorderColor = InLab_Kit_Cor #BOTAO_BORDA
    btn.FlatAppearance.BorderSize = 1
    btn.BackColor = InLab_Kit_Cor #BOTAO_FUNDO
    btn.ForeColor = InLab_Kit_Cor #BOTAO_ICONE
    btn.Font = InLab_Kit_Fonte 9
    btn.Cursor = (dotNetClass "System.Windows.Forms.Cursors").Hand
    btn
)

-- tipo: #OK | #WARN | #ERR | #INFO | #PROGRESSO
fn InLab_Kit_Pastilha ctrl tipo texto clicavel:false =
(
    local suf = tipo as string
    ctrl.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
    ctrl.FlatAppearance.BorderSize = 1
    ctrl.FlatAppearance.BorderColor = InLab_Kit_Cor ((suf + "_BORDA") as name)
    ctrl.BackColor = InLab_Kit_Cor ((suf + "_FUNDO") as name)
    ctrl.ForeColor = InLab_Kit_Cor ((suf + "_TEXTO") as name)
    ctrl.Font = InLab_Kit_Fonte 8.25 bold:clicavel
    ctrl.Text = texto
    ctrl.Cursor = if clicavel then (dotNetClass "System.Windows.Forms.Cursors").Hand
                  else (dotNetClass "System.Windows.Forms.Cursors").Default
    ctrl
)
```

- [ ] **Step 4: Alterar o `#warn` em `core/log.ms`**

Em `InLab_CorDoTipo`, trocar a linha do `#warn`:

```maxscript
        #warn:    (dotNetClass "System.Drawing.Color").FromArgb 230 180 90
```

por:

```maxscript
        -- 22/09/2026: era FromArgb 230 180 90. Passou a ser o ambar da marca
        -- (#E8A429, amostrado de Logo\9.png) pra aviso e marca serem a mesma
        -- cor — ver ui\kit.ms e a spec 2026-09-22-header-kit-ui-design.md.
        #warn:    (dotNetClass "System.Drawing.Color").FromArgb 232 164 41
```

E acrescentar a mesma nota no bloco de cabecalho do arquivo, onde o mapeamento
de cor pedido pela equipe esta descrito — o cabecalho diz "âmbar" e continua
verdade, so mudou o tom.

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Mesmo par de comandos do Step 2. Esperado no arquivo de saida: 13 linhas
`PASS` e `TUDO OK`. Nenhuma linha `FAIL`, nenhuma `EXCECAO`.

Se `WARN_ACENTO e a cor da MARCA` falhar, o Step 4 nao foi aplicado ou o
`core/log.ms` carregado e outro.

- [ ] **Step 6: Commit**

```bash
git add ui/kit.ms core/log.ms tests/test_kit_header.ms
git commit -m "feat(ui): kit de cores e widgets compartilhado

O kit promove pro painel as 4 cores de status que so o log usava, e
separa acento de texto porque a cor do log reprova como texto pequeno
sobre o fundo colorido (#EB5A5A sobre #452626 da 3,8:1).

O #warn do log passa a ser o ambar da marca, amostrado do logo. O teste
trava os dois lados: quebra se alguem mudar um sem o outro."
```

---

### Task 3: `ui/header.ms` — montar os controles

**Files:**
- Create: `ui/header.ms`
- Create: `ui/img/header_bulbo.png`
- Modify: `tests/test_kit_header.ms` (acrescenta o bloco 7)

**Interfaces:**
- Consumes: `InLab_Kit_Cor`, `InLab_Kit_Fonte`, `InLab_Kit_BotaoIcone` (Task 2); `INLAB_ROOT` (`InLabChecker.ms`); `InLab_Log`.
- Produces:
  - `fn InLab_Header_Montar pnl` -> `true`. Idempotente: limpa `pnl.Controls` antes.
  - Globais `InLab_Header_Pnl`, `InLab_Header_Marca`, `InLab_Header_Titulo`, `InLab_Header_Sub`, `InLab_Header_BtnReload`, `InLab_Header_Pastilha` — os controles, para os handlers e para `InLab_Header_Estado` (Task 4) alcancarem sem `local`.
  - `INLAB_HEADER_VERSAO_PADRAO` — `"0.11"`.
  - `fn InLab_Header_OnReload sender arg`.

- [ ] **Step 1: Gerar a arte**

```powershell
Add-Type -AssemblyName System.Drawing
$out = "G:\Meu Drive\GitHub\InLabChecker\ui\img"
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Force $out | Out-Null }
$src = New-Object System.Drawing.Bitmap("G:\Meu Drive\Trabalhos\2026\Artefacto\Logo\9.png")
$dst = New-Object System.Drawing.Bitmap(120,160,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
# bbox opaca medida do 9.png: x=217 y=23 w=1130 h=1522 (0,74:1)
# 160 de altura -> 119 de largura; 1px de folga a esquerda pra centrar em 120
$g.DrawImage($src, (New-Object System.Drawing.Rectangle(1,0,119,160)), 217,23,1130,1522, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$dst.Save("$out\header_bulbo.png",[System.Drawing.Imaging.ImageFormat]::Png)
$dst.Dispose(); $src.Dispose()
(Get-Item "$out\header_bulbo.png").Length
```

Entregue em 4x do tamanho de tela (30x40) e reduzido pelo `SizeMode = Zoom`,
pra sair limpo em qualquer escala de DPI do Windows.

- [ ] **Step 2: Escrever o teste que falha**

Acrescentar em `tests/test_kit_header.ms`, **dentro do `try`**, depois do bloco
6, e acrescentar `ui\header.ms` aos `fileIn` e os globais novos ao topo do
arquivo:

No topo, junto dos outros globais:

```maxscript
global INLAB_ROOT, INLAB_HEADER_VERSAO_PADRAO
global InLab_Header_Montar, InLab_Header_Pnl, InLab_Header_Pastilha
global InLab_Header_Titulo, InLab_Header_Marca
```

Logo apos `fileIn (raiz + @"ui\kit.ms")`:

```maxscript
        -- ui\header.ms le INLAB_ROOT pra achar a arte. Fora do plugin, o teste
        -- define a raiz na mao.
        INLAB_ROOT = raiz
        fileIn (raiz + @"ui\header.ms")
```

E o bloco novo:

```maxscript
        -- 7. MONTAGEM DO HEADER
        local pnlTeste = dotNetObject "System.Windows.Forms.Panel"
        pnlTeste.Width = 446
        pnlTeste.Height = 56
        checar "Montar devolve true" ((InLab_Header_Montar pnlTeste) == true)
        checar "Montar criou controles" (pnlTeste.Controls.Count > 0)
        local qtd1 = pnlTeste.Controls.Count
        InLab_Header_Montar pnlTeste
        checar "Montar 2x nao duplica controle" (pnlTeste.Controls.Count == qtd1)
        checar "Fundo do header e FUNDO_HEADER" (corIgual pnlTeste.BackColor (InLab_Kit_Cor #FUNDO_HEADER))
        checar "Titulo diz InLabChecker" (InLab_Header_Titulo.Text == "InLabChecker")
        checar "Versao padrao e a do repo" (INLAB_HEADER_VERSAO_PADRAO == "0.11")

        -- 8. ARTE AUSENTE NAO DERRUBA O HEADER
        -- O pacote do updater e validado so contra INLAB_MODULOS, que e tudo
        -- .ms: um pacote sem o PNG passa na validacao. O header tem que montar
        -- assim mesmo. Ver spec, secao 6, item 2.
        local raizBoa = INLAB_ROOT
        INLAB_ROOT = "Z:\\nao_existe_de_proposito\\"
        local pnlSemArte = dotNetObject "System.Windows.Forms.Panel"
        pnlSemArte.Width = 446
        pnlSemArte.Height = 56
        local okSemArte = false
        try ( okSemArte = (InLab_Header_Montar pnlSemArte) ) catch ( okSemArte = false )
        checar "Monta sem a arte, sem excecao" (okSemArte == true)
        checar "Sem arte, o texto continua la" (pnlSemArte.Controls.Count > 0)
        INLAB_ROOT = raizBoa

        -- 9. O PNG NAO PODE FICAR TRAVADO
        -- Image.FromFile e Bitmap(String) seguram o arquivo enquanto a imagem
        -- viver. Um PNG travado impede o updater de renomear a pasta de
        -- instalacao (passo 5 da spec do updater). Se o arquivo puder ser
        -- aberto pra escrita com o header montado, nao esta travado.
        local arte = INLAB_ROOT + @"ui\img\header_bulbo.png"
        local travado = true
        try
        (
            -- UMA LINHA SO, de proposito. MaxScript nao tem continuacao por
            -- "\", e parenteses formam BLOCO DE EXPRESSOES: quebrar a chamada
            -- dentro deles viraria varias expressoes, nao uma chamada com
            -- varios argumentos. Por isso os aliases curtos acima.
            local fMode = dotNetClass "System.IO.FileMode"
            local fAcc = dotNetClass "System.IO.FileAccess"
            local fShare = dotNetClass "System.IO.FileShare"
            local fs = dotNetObject "System.IO.FileStream" arte fMode.Open fAcc.ReadWrite fShare.None
            fs.Close()
            travado = false
        )
        catch ( travado = true )
        checar "PNG nao fica travado pelo header" (travado == false)
```

- [ ] **Step 3: Rodar o teste e confirmar que falha**

```maxscript
resetMaxFile #noPrompt
fileIn @"G:\Meu Drive\GitHub\InLabChecker\tests\test_kit_header.ms"
```

Esperado: `EXCECAO:` citando `ui\header.ms` inexistente. Os 13 `PASS` da
Task 2 nao aparecem, porque a excecao aborta o `try` inteiro — isso e esperado
e e exatamente por que o teste roda de novo no Step 5.

- [ ] **Step 4: Escrever `ui/header.ms`**

```maxscript
/*
================================================================================
 ui\header.ms — v0.12 (22/09/2026): faixa de marca no topo do painel
--------------------------------------------------------------------------------
 O QUE E: um System.Windows.Forms.Panel de 56px que mora dentro de
 InLabChecker_Rollout, com a marca a esquerda, o titulo no meio, e a direita o
 botao Reload e a pastilha de versao. A pastilha E o aviso de atualizacao.

 POR QUE dotNet E NAO CONTROLE DE ROLLOUT: rollout nao cria controle em tempo
 de execucao (pegadinha ja no CLAUDE.md), e nao pinta faixa. A restricao vale
 pra controle DE ROLLOUT — filho de Panel dotNet e criado a hora que quiser, e
 e por isso que os 5 estados da pastilha cabem num controle so.

 TODO ESTADO EM GLOBAL, DE PROPOSITO: handler de evento dotNet roda num escopo
 que NAO enxerga `local` do rollout que o declarou — so globais e funcoes de
 nivel superior. Mesma causa-raiz documentada em ui\splash.ms. Nenhum handler
 deste arquivo le local de rollout.

 A ARTE PODE FALTAR: o pacote do updater e validado so contra INLAB_MODULOS,
 que e tudo .ms — um pacote sem ui\img\header_bulbo.png passa na validacao. O
 header entao monta sem a imagem, so com a tipografia, e loga #warn. Ver a
 spec 2026-09-22-header-kit-ui-design.md, secao 6.

 O PNG NAO PODE FICAR TRAVADO: Image.FromFile e Bitmap(String) seguram o
 arquivo enquanto a imagem viver, e o updater precisa renomear a pasta de
 instalacao. Por isso a imagem e copiada pra um Bitmap novo e o original e
 descartado na hora.
================================================================================
*/

global INLAB_ROOT
global INLAB_HEADER_VERSAO_PADRAO = "0.11"  -- maior versao declarada no repo
                                            -- (InLabChecker.ms). Unificar as
                                            -- strings e do core\versao.ms, na
                                            -- spec do updater.
global InLab_Header_Pnl, InLab_Header_Marca, InLab_Header_Titulo
global InLab_Header_Sub, InLab_Header_BtnReload, InLab_Header_Pastilha
global InLab_Header_Montar, InLab_Header_OnReload
global InLab_RecarregarPlugin

-- Handler de nivel superior: so le global.
fn InLab_Header_OnReload sender arg =
(
    try ( InLab_RecarregarPlugin() )
    catch ( InLab_Log ("Header: falha no Reload — " + getCurrentException()) tipo:#err )
)

-- Carrega o PNG sem deixar o arquivo travado. Devolve a imagem ou undefined.
fn InLab_Header_CarregarArte caminho =
(
    if not (doesFileExist caminho) then
    (
        InLab_Log ("Header: arte ausente (" + caminho + ") — seguindo sem a marca.") tipo:#warn
        undefined
    )
    else
    (
        local img = undefined
        try
        (
            local tmp = dotNetObject "System.Drawing.Bitmap" caminho
            img = dotNetObject "System.Drawing.Bitmap" tmp
            tmp.Dispose()   -- solta o arquivo; sem isso o updater nao renomeia a pasta
        )
        catch
        (
            InLab_Log ("Header: falha ao ler a arte — " + getCurrentException()) tipo:#warn
            img = undefined
        )
        img
    )
)

fn InLab_Header_Montar pnl =
(
    InLab_Header_Pnl = pnl
    pnl.Controls.Clear()   -- idempotente: montar 2x nao duplica
    pnl.BackColor = InLab_Kit_Cor #FUNDO_HEADER

    local dir = (dotNetClass "System.Windows.Forms.AnchorStyles")
    local ancRight = dotNet.combineEnums dir.Top dir.Right

    -- MARCA
    InLab_Header_Marca = dotNetObject "System.Windows.Forms.PictureBox"
    InLab_Header_Marca.Location = dotNetObject "System.Drawing.Point" 10 8
    InLab_Header_Marca.Size = dotNetObject "System.Drawing.Size" 30 40
    InLab_Header_Marca.SizeMode = (dotNetClass "System.Windows.Forms.PictureBoxSizeMode").Zoom
    InLab_Header_Marca.BackColor = InLab_Kit_Cor #FUNDO_HEADER
    local img = InLab_Header_CarregarArte (INLAB_ROOT + @"ui\img\header_bulbo.png")
    if img != undefined do InLab_Header_Marca.Image = img
    pnl.Controls.Add InLab_Header_Marca

    -- TITULO
    InLab_Header_Titulo = dotNetObject "System.Windows.Forms.Label"
    InLab_Header_Titulo.Text = "InLabChecker"
    InLab_Header_Titulo.Font = InLab_Kit_Fonte 11 bold:true
    InLab_Header_Titulo.ForeColor = InLab_Kit_Cor #TEXTO_FORTE
    InLab_Header_Titulo.BackColor = InLab_Kit_Cor #FUNDO_HEADER
    InLab_Header_Titulo.AutoSize = true
    InLab_Header_Titulo.Location = dotNetObject "System.Drawing.Point" 51 10
    pnl.Controls.Add InLab_Header_Titulo

    -- SUBTITULO
    InLab_Header_Sub = dotNetObject "System.Windows.Forms.Label"
    InLab_Header_Sub.Text = "preparação e verificação · InLab artefacto"
    InLab_Header_Sub.Font = InLab_Kit_Fonte 7
    InLab_Header_Sub.ForeColor = InLab_Kit_Cor #TEXTO_FRACO
    InLab_Header_Sub.BackColor = InLab_Kit_Cor #FUNDO_HEADER
    InLab_Header_Sub.AutoSize = true
    InLab_Header_Sub.Location = dotNetObject "System.Drawing.Point" 53 32
    pnl.Controls.Add InLab_Header_Sub

    -- PASTILHA (canto direito; Task 4 pinta o estado)
    InLab_Header_Pastilha = dotNetObject "System.Windows.Forms.Button"
    InLab_Header_Pastilha.Size = dotNetObject "System.Drawing.Size" 74 28
    InLab_Header_Pastilha.Location = dotNetObject "System.Drawing.Point" (pnl.Width - 84) 14
    InLab_Header_Pastilha.Anchor = ancRight
    InLab_Kit_Pastilha InLab_Header_Pastilha #INFO ("v" + INLAB_HEADER_VERSAO_PADRAO)
    pnl.Controls.Add InLab_Header_Pastilha

    -- RELOAD
    InLab_Header_BtnReload = dotNetObject "System.Windows.Forms.Button"
    InLab_Header_BtnReload.Size = dotNetObject "System.Drawing.Size" 28 28
    InLab_Header_BtnReload.Location = dotNetObject "System.Drawing.Point" (pnl.Width - 118) 14
    InLab_Header_BtnReload.Anchor = ancRight
    InLab_Header_BtnReload.Text = "⟳"
    InLab_Kit_BotaoIcone InLab_Header_BtnReload
    InLab_Header_BtnReload.Font = InLab_Kit_Fonte 12
    dotNet.addEventHandler InLab_Header_BtnReload "Click" InLab_Header_OnReload
    pnl.Controls.Add InLab_Header_BtnReload

    true
)
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Mesmo par de comandos do Step 3. Esperado: `TUDO OK`, com os 13 `PASS` da
Task 2 mais os 9 desta.

Se `PNG nao fica travado pelo header` falhar, o `tmp.Dispose()` nao rodou ou a
imagem foi atribuida direto do `Bitmap(caminho)`.

- [ ] **Step 6: Commit**

```bash
git add ui/header.ms ui/img/header_bulbo.png tests/test_kit_header.ms
git commit -m "feat(ui): monta a faixa de header com marca, Reload e pastilha

Panel dotNet dentro do rollout: filho de Panel pode ser criado em tempo
de execucao, ao contrario de controle de rollout, e e por isso que os 5
estados da pastilha cabem num controle so.

A arte e copiada pra um Bitmap novo e o original descartado na hora --
Image.FromFile trava o arquivo, e o updater precisa renomear a pasta de
instalacao. Header monta sem a arte se ela faltar, porque a validacao do
pacote so confere os .ms do manifesto."
```

---

### Task 4: `InLab_Header_Estado` — os 5 estados

**Files:**
- Modify: `ui/header.ms`
- Modify: `tests/test_kit_header.ms` (acrescenta o bloco 10)

**Interfaces:**
- Consumes: tudo da Task 3, mais `InLab_Kit_Pastilha`.
- Produces:
  - `fn InLab_Header_Estado estado versao:unsupplied pct:0` -> `true` se aceitou, `false` se o estado e invalido. Nao levanta excecao.
  - `InLab_Header_EstadoAtual` — o estado corrente, um dos 5 names.
  - `InLab_Header_Versao` — a string de versao mostrada.
  - `fn InLab_Header_OnPastilha sender arg` — o handler do clique.
  - `INLAB_HEADER_ESTADOS` — `#(#ocioso, #checando, #disponivel, #baixando, #erro)`.

Esta e a API que o sub-projeto 3 chama. Aqui ela ja existe inteira e e
testavel por chamada direta; o unico estado que alguem dispara e `#ocioso`,
na abertura do painel.

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar os globais no topo do arquivo de teste:

```maxscript
global InLab_Header_Estado, InLab_Header_EstadoAtual, InLab_Header_Versao
global INLAB_HEADER_ESTADOS
```

E o bloco novo, dentro do `try`, depois do bloco 9:

```maxscript
        -- 10. OS 5 ESTADOS DA PASTILHA
        InLab_Header_Montar pnlTeste

        checar "Aceita #ocioso"     ((InLab_Header_Estado #ocioso versao:"0.11") == true)
        checar "Guardou o estado"   (InLab_Header_EstadoAtual == #ocioso)
        checar "Ocioso pinta OK"    (corIgual InLab_Header_Pastilha.BackColor (InLab_Kit_Cor #OK_FUNDO))
        checar "Ocioso mostra a versao" (InLab_Header_Pastilha.Text == "v0.11")

        checar "Aceita #checando"   ((InLab_Header_Estado #checando) == true)
        checar "Checando pinta PROGRESSO" (corIgual InLab_Header_Pastilha.BackColor (InLab_Kit_Cor #PROGRESSO_FUNDO))
        checar "Checando mantem a versao" (InLab_Header_Versao == "0.11")

        checar "Aceita #disponivel" ((InLab_Header_Estado #disponivel versao:"0.13") == true)
        checar "Disponivel pinta WARN" (corIgual InLab_Header_Pastilha.BackColor (InLab_Kit_Cor #WARN_FUNDO))
        checar "Disponivel mostra a versao nova" (InLab_Header_Pastilha.Text == "v0.13")
        checar "Disponivel e clicavel" (InLab_Header_Pastilha.Cursor.ToString() == (dotNetClass "System.Windows.Forms.Cursors").Hand.ToString())

        checar "Aceita #baixando"   ((InLab_Header_Estado #baixando pct:62) == true)
        checar "Baixando mostra o percentual" (InLab_Header_Pastilha.Text == "62%")

        checar "Aceita #erro"       ((InLab_Header_Estado #erro) == true)
        checar "Erro pinta ERR"     (corIgual InLab_Header_Pastilha.BackColor (InLab_Kit_Cor #ERR_FUNDO))

        -- Estado invalido: recusa sem excecao e sem mexer no que estava
        local antes = InLab_Header_EstadoAtual
        local recusou = true
        try ( recusou = ((InLab_Header_Estado #banana) == false) ) catch ( recusou = false )
        checar "Estado invalido devolve false, sem excecao" (recusou == true)
        checar "Estado invalido nao muda o estado atual" (InLab_Header_EstadoAtual == antes)

        checar "A lista de estados tem os 5" (INLAB_HEADER_ESTADOS.count == 5)
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

```maxscript
resetMaxFile #noPrompt
fileIn @"G:\Meu Drive\GitHub\InLabChecker\tests\test_kit_header.ms"
```

Esperado: `EXCECAO:` por `InLab_Header_Estado` indefinido (chamar `undefined`
como funcao levanta "Unknown property" / "not a function").

- [ ] **Step 3: Implementar em `ui/header.ms`**

Acrescentar aos globais do topo:

```maxscript
global INLAB_HEADER_ESTADOS = #(#ocioso, #checando, #disponivel, #baixando, #erro)
global InLab_Header_EstadoAtual = #ocioso
global InLab_Header_Versao = INLAB_HEADER_VERSAO_PADRAO
global InLab_Header_Estado, InLab_Header_OnPastilha
```

E, no fim do arquivo, depois de `InLab_Header_Montar`:

```maxscript
-- Clique na pastilha. Só faz sentido em #disponivel e #erro; nos outros
-- estados a pastilha não é clicável e o handler não faz nada.
--
-- Abrir a seção Atualização é do sub-projeto 3, que ainda não existe: por
-- enquanto o clique registra no log, que é onde o artista já olha.
fn InLab_Header_OnPastilha sender arg =
(
    case InLab_Header_EstadoAtual of
    (
        #disponivel: InLab_Log ("Atualização v" + InLab_Header_Versao + " disponível — a seção Atualização entra no próximo sub-projeto.") tipo:#warn
        #erro:       InLab_Log "A última atualização falhou e foi revertida — o motivo está acima neste log." tipo:#err
        default:     ()
    )
)

-- Pinta a pastilha conforme o estado. Os controles EXISTEM SEMPRE; só mudam
-- cor, texto e cursor — é o que permite cobrir 5 estados num rollout, que não
-- cria controle em tempo de execução.
--
--   estado : #ocioso | #checando | #disponivel | #baixando | #erro
--   versao : troca a versão exibida (em #disponivel, é a versão NOVA)
--   pct    : só usado em #baixando
--
-- Devolve true se aceitou, false se o estado é inválido — nunca levanta
-- exceção, porque quem vai chamar isto é um callback assíncrono do updater e
-- uma exceção lá dentro morre sem deixar rastro.
fn InLab_Header_Estado estado versao:unsupplied pct:0 =
(
    if (findItem INLAB_HEADER_ESTADOS estado) == 0 then
    (
        InLab_Log ("Header: estado desconhecido '" + (estado as string) + "' — mantendo " + (InLab_Header_EstadoAtual as string) + ".") tipo:#warn
        return false
    )
    if versao != unsupplied do InLab_Header_Versao = versao
    InLab_Header_EstadoAtual = estado

    if InLab_Header_Pastilha == undefined then
    (
        InLab_Log "Header: estado mudou antes de o header ser montado — só guardei." tipo:#info
        return true
    )

    local tipo = #INFO
    local texto = "v" + InLab_Header_Versao
    local clicavel = false
    case estado of
    (
        #ocioso:
        (
            tipo = #OK
        )
        #checando:
        (
            tipo = #PROGRESSO
            texto = "v" + InLab_Header_Versao + " ···"
        )
        #disponivel:
        (
            tipo = #WARN
            clicavel = true
        )
        #baixando:
        (
            tipo = #PROGRESSO
            texto = (pct as integer) as string + "%"
        )
        #erro:
        (
            tipo = #ERR
            clicavel = true
        )
    )
    InLab_Kit_Pastilha InLab_Header_Pastilha tipo texto clicavel:clicavel
    true
)
```

Note o `case` em multiplas linhas: **`case` inline com `;` nao parseia** em
MaxScript — pegadinha ja documentada no CLAUDE.md.

E, dentro de `InLab_Header_Montar`, logo depois de `pnl.Controls.Add InLab_Header_Pastilha`, ligar o handler:

```maxscript
    dotNet.addEventHandler InLab_Header_Pastilha "Click" InLab_Header_OnPastilha
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Mesmo par de comandos do Step 2. Esperado: `TUDO OK`, com os 22 `PASS`
anteriores mais os 18 desta tarefa.

- [ ] **Step 5: Commit**

```bash
git add ui/header.ms tests/test_kit_header.ms
git commit -m "feat(ui): os 5 estados da pastilha de versao

A pastilha E o aviso de atualizacao: fica ambar e clicavel quando ha
versao nova. Isso substitui a tarja solta que a spec do updater previa
abaixo do Reload, e devolve a barra de progresso -- em #baixando o
percentual mora dentro da propria pastilha.

InLab_Header_Estado devolve false em vez de levantar excecao: quem vai
chamar isso e um callback assincrono do updater, e excecao la dentro
morre sem deixar rastro."
```

---

### Task 5: Integracao no painel

**Files:**
- Modify: `InLabChecker.ms` (manifesto)
- Modify: `ui/rollout_main.ms:479-559`

**Interfaces:**
- Consumes: `InLab_Header_Montar`, `InLab_Header_Estado`, `INLAB_HEADER_VERSAO_PADRAO`.
- Produces: nada para tarefas seguintes — e a ultima.

- [ ] **Step 1: Pôr os dois modulos no manifesto**

Em `InLabChecker.ms`, na secao `-- 5. UI` de `INLAB_MODULOS`, **antes** de
`ui\splash.ms`:

```maxscript
            -- 5. UI
            -- kit antes de tudo: header e (depois) as secoes leem cor dele.
            @"ui\kit.ms",
            @"ui\header.ms",
            @"ui\splash.ms",
            @"ui\rollout_main.ms"
```

- [ ] **Step 2: Trocar o topo do rollout**

Em `ui/rollout_main.ms`, dentro de `rollout InLabChecker_Rollout`, trocar o
bloco que vai do `radiobuttons rdoLado` ate o `subRollout subSecoes` por:

```maxscript
    ------------------------------------------------------------------
    -- HEADER (22/09/2026) — faixa de marca com Reload e pastilha de
    -- versao. Substitui o botao "Reload Plugin" de 395x22 que ficava
    -- aqui. O conteudo e montado por InLab_Header_Montar (ui\header.ms):
    -- rollout nao cria controle em tempo de execucao, mas filho de Panel
    -- dotNet cria.
    ------------------------------------------------------------------
    dotNetControl pnlHeader "System.Windows.Forms.Panel" pos:[0,0] width:446 height:56

    ------------------------------------------------------------------
    -- LADO DO PAINEL — reposicionamento na borda da tela (nao e docking
    -- real; ver ressalva entregue a equipe).
    ------------------------------------------------------------------
    radiobuttons rdoLado labels:#("Fixar à esquerda", "Fixar à direita") default:2 columns:2 pos:[8,64]

    subRollout subSecoes width:438 height:508 pos:[4,88]
```

O `height:508` e provisorio: sai medido no Step 5. Os `pos:` explicitos
substituem o fluxo automatico, que nao conta com o `dotNetControl`.

- [ ] **Step 3: Montar o header na abertura**

Em `on InLabChecker_Rollout open do`, logo depois de
`InLab_PosicionarPainel InLab_LadoPainel` e **antes** dos `AddSubRollout`:

```maxscript
        InLab_Header_Montar pnlHeader
        InLab_Header_Estado #ocioso versao:INLAB_HEADER_VERSAO_PADRAO
```

- [ ] **Step 4: Tirar o botao velho**

Apagar a declaracao `button btnReload "🔄 Reload Plugin" width:395 height:22`
(e o comentario "Realocado de InLabSecFamilia..." logo acima) e o handler
`on btnReload pressed do InLab_RecarregarPlugin()`.

Conferir que nao sobrou referencia:

```bash
grep -rn "btnReload" --include="*.ms" .
```

Esperado: nenhuma linha.

- [ ] **Step 5: Abrir no Max e medir a altura**

```maxscript
fileIn @"G:\Meu Drive\GitHub\InLabChecker\InLabChecker.ms"
```

Com o painel aberto, medir onde o `subRollout` realmente termina:

```maxscript
local d = InLabChecker_Rollout
format "JANELA altura=% larg=%\n" d.height d.width
format "SUBROLLOUT pos=% altura=%\n" d.subSecoes.pos d.subSecoes.height
format "SOBRA abaixo = %\n" (d.height - (d.subSecoes.pos.y + d.subSecoes.height))
```

**O 600 de hoje nunca foi medido** — o comentario em `InLab_AbrirUI` diz
"valor estimado, nao testado no Max ainda" (15/Set). Ajustar `createDialog` e
`subSecoes.height` ate a sobra abaixo do Log de Sessao ficar entre 4 e 10 px,
com todas as secoes recolhidas menos o Log. Anotar o numero medido no
comentario do `InLab_AbrirUI`, com a data e a palavra "medido" — para nao
virar o terceiro chute.

- [ ] **Step 6: Verificar a margem, contra a sondagem**

Comparar o que se ve com o que a Task 1 registrou: o `pnlHeader` encosta nas
bordas da janela?

Se a sondagem disse que **encosta**, confirmar visualmente com
`capture_screen`.

Se a sondagem disse que **sobra margem de N px**, a faixa nao vai da borda a
borda. Duas saidas, e a escolha e do usuario — **parar e perguntar**:
(a) aceitar a margem, ou (b) o `Panel` perder o `BackColor` proprio e o header
virar so os controles sobre o fundo do rollout.

- [ ] **Step 7: Verificar o Reload de dentro do header**

Clicar no botao ⟳. `InLab_RecarregarPlugin()` refaz o `fileIn` de **todos** os
modulos, inclusive do `ui\header.ms` que contem o botao que disparou a
chamada — mesma classe de problema do passo 5 do updater (codigo que se
substitui enquanto roda).

Esperado: a UI fecha e reabre com o header no lugar, e o log mostra as linhas
de sessao.

**Se travar, der excecao ou a janela nao reabrir**, trocar o handler em
`ui/header.ms` por um que adia a chamada para depois de o clique retornar:

```maxscript
global InLab_Header_TimerReload

fn InLab_Header_DispararReload sender arg =
(
    try ( InLab_Header_TimerReload.Stop() ) catch()
    try ( InLab_RecarregarPlugin() )
    catch ( InLab_Log ("Header: falha no Reload — " + getCurrentException()) tipo:#err )
)

-- O clique so ARMA o timer e volta. Quando o tick dispara, a pilha do evento
-- de clique ja foi desfeita, entao o fileIn pode redefinir este arquivo sem
-- puxar o tapete de baixo do proprio handler.
fn InLab_Header_OnReload sender arg =
(
    if InLab_Header_TimerReload == undefined do
    (
        InLab_Header_TimerReload = dotNetObject "System.Windows.Forms.Timer"
        InLab_Header_TimerReload.Interval = 1
        dotNet.addEventHandler InLab_Header_TimerReload "Tick" InLab_Header_DispararReload
    )
    InLab_Header_TimerReload.Start()
)
```

Declarar `InLab_Header_DispararReload` e `InLab_Header_TimerReload` nos globais
do topo do arquivo, e registrar no cabecalho **qual dos dois caminhos ficou** e
por que — a disciplina de "registrar qual variante rodou" do CLAUDE.md.

- [ ] **Step 8: Validar a olho contra o prototipo**

Abrir a "Bancada do Header"
(https://claude.ai/artifact/LL19Fc1ZwJQHkrYkeyXgdh) em 1:1, na mesma tela, ao
lado do painel do Max. Conferir os 5 itens do checklist que a bancada lista:

1. O subtitulo de 7 pt le de longe.
2. O bulbo a 30x40 nao fecha o traco nem mostra halo claro na borda.
3. A pastilha ambar chama atencao sem competir com botao de acao das secoes.
4. Alinhamento vertical: marca, titulo, Reload e pastilha centrados na faixa.
5. O topo ficou mais limpo sem o botao de 395 px.

Os estados `#checando`, `#disponivel`, `#baixando` e `#erro` ainda nao tem quem
os dispare. Para olhar cada um:

```maxscript
InLab_Header_Estado #disponivel versao:"0.13"
InLab_Header_Estado #baixando pct:62
InLab_Header_Estado #erro
InLab_Header_Estado #ocioso versao:"0.11"
```

Ajuste de pixel que sair daqui (posicao, tamanho de fonte) volta pro
`ui/header.ms` e o teste roda de novo antes do commit.

- [ ] **Step 9: Conferir a 150% de escala do Windows**

Risco listado na spec, secao 7. O header tem 56 px fixos e o subtitulo 7 pt: a
150% o Max redesenha tudo e as duas coisas podem brigar.

**Isto nao e roteirizavel** — mudar a escala do Windows exige reiniciar o Max, e
a sessao do MCP cai junto. **Pedir ao usuario** que rode, ou rodar com ele por
perto:

1. Windows: Configuracoes > Sistema > Tela > Escala = 150%.
2. Reiniciar o 3ds Max e abrir o plugin.
3. Olhar: o subtitulo cortou? A pastilha saiu da faixa? O bulbo esticou?
4. Voltar a escala de origem e reiniciar o Max.

Se quebrar, o conserto **nao** e fixar outro numero: e trocar a altura fixa de
56 px por uma altura derivada da fonte — `InLab_Header_Titulo.Height +
InLab_Header_Sub.Height + 16` depois de as labels terem `AutoSize`, lida em
`InLab_Header_Montar` e devolvida pro `pnlHeader.Height`. Registrar o que
aconteceu no cabecalho de `ui/header.ms`, com a escala testada.

Se o usuario nao puder testar agora, **anotar como pendencia conhecida** no
cabecalho do arquivo em vez de dar por validado — nao afirmar que funciona em
150% sem ter visto.

- [ ] **Step 10: Rodar o teste inteiro uma ultima vez**

```maxscript
resetMaxFile #noPrompt
fileIn @"G:\Meu Drive\GitHub\InLabChecker\tests\test_kit_header.ms"
```

Ler `(getDir #temp)\inlab_test_kit_header.txt`. Esperado: `TUDO OK`, 40 `PASS`.

- [ ] **Step 11: Commit**

```bash
git add InLabChecker.ms ui/rollout_main.ms ui/header.ms
git commit -m "feat(ui): header no lugar do botao Reload no topo do painel

kit.ms e header.ms entram no manifesto antes do rollout_main. O botao
Reload de 395x22 sai do corpo e vira icone no header; o radio de lado e
o subRollout descem 56px.

Altura do subRollout MEDIDA no Max com o header montado, nao estimada --
o 600 anterior nunca tinha sido conferido (comentario de 15/Set)."
```

- [ ] **Step 12: Atualizar o CLAUDE.md**

O CLAUDE.md descreve a arquitetura, e ela mudou. Acrescentar em `Arquitetura`,
na linha de `ui/`:

- que `ui/kit.ms` e a fonte das cores e que secao nova le cor de la, nao literal;
- que `ui/header.ms` e um `Panel` dotNet dentro do rollout, e que **filho de
  Panel dotNet pode ser criado em tempo de execucao** — a pegadinha de "rollouts
  nao criam controles dinamicamente" vale so para controle de rollout;
- que `ui/img/` existe e que o header monta sem a arte se ela faltar.

E em `Pegadinhas`, acrescentar que `Image.FromFile`/`Bitmap(String)` travam o
arquivo em disco, e que a saida e copiar pra um `Bitmap` novo e descartar o
original.

```bash
git add CLAUDE.md
git commit -m "docs: registra kit, header e a trava de arquivo do Bitmap no CLAUDE.md"
```

---

## Ordem e dependencias

```
Task 1 (sondagem)  ->  Task 3 (precisa saber do alpha)
Task 2 (kit)       ->  Task 3  ->  Task 4  ->  Task 5
Task 1             ->  Task 5 (precisa saber da margem)
```

Task 2 nao depende da Task 1 e pode ir em paralelo se houver dois executores.
As outras sao sequenciais.

## Fora deste plano

Sub-projetos 2, 3 e 4 (icone de toolbar, secao Atualizacao, repaginacao das 7
secoes) tem plano proprio. As tres correcoes na spec do updater listadas na
secao 6 da spec sao feitas no epico do updater, nao aqui.
