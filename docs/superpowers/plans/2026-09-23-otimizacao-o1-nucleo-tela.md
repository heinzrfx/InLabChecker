# Otimizacao O1 · Nucleo, medidor em triangulos e tela dos 3 passos — Plano de Implementacao

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar a base da Otimizacao em 3 passos (issue #60): nucleo compartilhado, contagem em triangulos (V-03/V-04), os 3 arquivos de passo no manifesto (passo 2 com o comportamento atual, passos 1 e 3 "em construcao") e a tela nova com medidor e lista de revisao, mais a secao "UV e Texturas".

**Architecture:** Um modulo de nucleo (`functions/fn_otim_nucleo.ms`) com contagem, faixa, pisos, registro de reversao e um despachante `InLab_Otim_Calcular/Aplicar/Reverter passo`. Cada passo mora no proprio arquivo e segue o contrato `InLab_Otim<Passo>_Calcular objs -> #(OtimProposta)`, `_Aplicar propostas`, `_Reverter`. A UI so chama o despachante; por isso #61, #62 e #63 depois so trocam o conteudo do proprio arquivo, sem tocar UI nem manifesto.

**Tech Stack:** MaxScript (3ds Max 2024), dotNet `System.Windows.Forms.ListView`/`Label` em `dotNetControl`, MCP do 3ds Max para rodar testes.

**Spec:** `docs/superpowers/specs/2026-09-23-otimizacao-design.md` (secoes 3.1, 4 e 7)

## Global Constraints

- **Pre-requisito:** #55 mergeada (a secao Materiais — Utilidades ja saiu de `ui/rollout_main.ms`). As ancoras deste plano sao nomes de rollout e de controle, nao numeros de linha.
- **Portugues em tudo:** codigo, comentario, log e UI. Plano e spec sem acento; codigo, log e UI com acento normal.
- **Prefixo:** funcao publica `InLab_`, constante `INLAB_MAIUSCULO`. `global Nome` antes de cada `fn` usada fora do arquivo (o arquivo pode ser carregado de dentro de `InLab_RecarregarPlugin()`, ver `functions/fn_json.ms`).
- **Modulo novo so existe se entrar em `INLAB_MODULOS`** (`InLabChecker.ms`).
- **Cabecalho de arquivo** `/* === ... === */` com caminho, o que faz e decisoes com data (23/09/2026).
- **Nunca engolir erro sem `InLab_Log`.**
- **Operacao na cena** dentro de `undo "InLab ..." on (...)` e com registro proprio para o Reverter.
- **Unidade:** triangulos (`(GetTriMeshFaceCount o)[1]`), por no (instancias contam uma vez por no, como o GLB exporta).
- **Textos novos de UI** no padrao da #58: simples, botao com 1 a 3 palavras, detalhe no `tooltip`. Textos que so mudam de secao (Auto UV, Real World Fix) ficam como estao; a #58 revisa depois.
- **Cores so do kit** (`InLab_Kit_Cor`, `ui/kit.ms`), nunca literal.
- **Handler de evento dotNet (`dotNet.addEventHandler`) nao enxerga `local` de rollout.** Este plano nao usa esse tipo de handler: a lista e lida pelos botoes MaxScript. O estado da lista fica num global (`INLAB_OTIM_PROPOSTAS`) para o teste e o `InLab_OtimUI_Atualizar` enxergarem.
- **MCP:** roda em `safe_mode` (sem `createFile` no codigo enviado; teste roda por `fileIn` do arquivo). Global de rollout criado numa chamada do MCP nao sobrevive a proxima: sondagem de UI cria, le e fecha na MESMA chamada. Chamada acima de 120 s vai para segundo plano.
- **Rodar teste:** numa cena vazia (`resetMaxFile #noPrompt`), `fileIn @"<repo>\tests\test_<nome>.ms"`, ler `(getDir #temp) + "\inlab_test_<nome>.txt"`. Salvar e reabrir a cena do usuario antes/depois.
- **Commit:** portugues, assunto sem acento, `feat(otimizacao): ...`. Branch `feat/otimizacao-nucleo` a partir de `main`. Terminar com `Co-Authored-By` conforme o repositorio.

---

## Estrutura de arquivos

| Arquivo | Responsabilidade | Tarefa |
| --- | --- | --- |
| `functions/fn_otim_nucleo.ms` | **Criar.** Contagem em triangulos, faixa-alvo, estado do medidor, pisos (padrao + `.ini`), registro de reversao, struct `OtimProposta`, despachante dos passos | 1, 3 |
| `functions/fn_otim_origem.ms` | **Criar (minimo).** Passo 1 "em construcao" — #61 preenche | 3 |
| `functions/fn_otim_fino.ms` | **Criar (provisorio).** Passo 2 com o ProOptimizer de hoje, uma linha por peca — #62 substitui | 3 |
| `functions/fn_otim_escondidas.ms` | **Criar (minimo).** Passo 3 "em construcao" — #63 preenche | 3 |
| `InLabChecker.ms` | **Alterar.** Os 4 modulos no manifesto, depois de `fn_prooptimizer.ms` | 1, 3 |
| `verifications/verif_peso_poly.ms` | **Alterar.** V-03 e V-04 em triangulos | 2 |
| `ui/rollout_main.ms` | **Alterar.** Secao Otimizacao nova, secao UV e Texturas, aviso ao mudar a familia | 4 |
| `tests/test_otim_nucleo.ms` | **Criar.** Nucleo + despachante + passo 2 provisorio | 1, 3 |
| `tests/test_verificacoes.ms`, `tests/test_familia_ativa.ms` | **Alterar.** Carregar o nucleo; caso da V-03 em triangulos | 2 |
| `docs/superpowers/specs/2026-09-23-otimizacao-design.md` | **Alterar.** Corrigir "V-03 e V-05" para "V-03 e V-04" (V-05 conta objetos/draw calls, nao triangulos) | 2 |

---

### Task 1: Nucleo da otimizacao

**Files:**
- Create: `functions/fn_otim_nucleo.ms`
- Modify: `InLabChecker.ms` (manifesto)
- Test: `tests/test_otim_nucleo.ms`

**Interfaces:**
- Consumes: `InLab_EhGeometria` (`core/utils.ms`), `InLab_PrefLer`/`InLab_PrefGravar`/`InLab_PrefApagar` (`core/prefs.ms`), `InLab_FamiliaAtiva` e `InLab_ObterFamilia` (`core/struct_familia.ms`), `InLab_Log`.
- Produces:
  - `struct OtimProposta (no, rotulo, alvo, prop, antes, depois, trisAntes, trisDepois, motivo, marcada)`
  - `INLAB_OTIM_PISOS` — array de `#(chave, valor)`
  - `INLAB_OTIM_META_MANUAL` — inteiro ou `undefined`
  - `InLab_Otim_Triangulos objs -> integer`
  - `InLab_Otim_Piso chave -> number | undefined`
  - `InLab_Otim_Faixa() -> #(min, max, alvo) | undefined`
  - `InLab_Otim_Estado total faixa -> #dentro | #perto | #longe | #sem`
  - `InLab_Otim_Milhar n -> string` ("182.340")
  - `InLab_Otim_TextoMedidor total faixa -> string`
  - `InLab_Otim_AlvoSelecao objs faixa -> integer | undefined`
  - `InLab_Otim_Guardar registro alvo prop -> registro` e `InLab_Otim_Restaurar registro -> integer`

- [ ] **Step 1: Criar a branch**

```bash
git checkout main && git pull && git checkout -b feat/otimizacao-nucleo
```

- [ ] **Step 2: Escrever o teste que falha — `tests/test_otim_nucleo.ms`**

```maxscript
/*
 tests\test_otim_nucleo.ms — teste automático do núcleo da otimização (issue #60)
 Cobre functions\fn_otim_nucleo.ms (contagem, faixa, estado, pisos com .ini,
 registro de reversão) e, a partir da Tarefa 3, o despachante dos 3 passos.
 RODAR NUMA CENA VAZIA (File > New). Grava e apaga chaves "piso_*" no ini real.
 Resultado: <pasta temp do Max>\inlab_test_otim_nucleo.txt (PASS/FAIL por item).
*/
global InLab_Log, InLab_FamiliaAtiva, InLab_ObterFamilia, InLab_DefinirFamiliaAtiva
global InLab_PrefGravar, InLab_PrefApagar
global INLAB_OTIM_META_MANUAL, InLab_Otim_Triangulos, InLab_Otim_Piso, InLab_Otim_Faixa, InLab_Otim_Estado
global InLab_Otim_Milhar, InLab_Otim_TextoMedidor, InLab_Otim_AlvoSelecao, InLab_Otim_Guardar, InLab_Otim_Restaurar
global InLab_Otim_Calcular, InLab_Otim_Aplicar, InLab_Otim_Reverter, InLab_OtimFino_Comparar
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_otim_nucleo.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn limparCena = ( delete (for o in objects collect o) )

    local logOriginal = InLab_Log
    local chavesIni = #("piso_turbosmooth", "piso_chamfer")

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms", @"familias\familia_corpo_unico.ms",
                   @"functions\fn_prooptimizer.ms", @"functions\fn_otim_nucleo.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        limparCena()
        InLab_FamiliaAtiva = undefined
        INLAB_OTIM_META_MANUAL = undefined

        ---------------------------------------------------------------- CONTAGEM
        local b1 = Box()
        checar "Triângulos: Box padrão = 12" ((InLab_Otim_Triangulos #(b1)) == 12)
        local b2 = instance b1
        local ponto = Point()
        checar "Triângulos: instância conta por nó, helper não conta" ((InLab_Otim_Triangulos #(b1, b2, ponto)) == 24)

        ---------------------------------------------------------------- PISOS
        for k in chavesIni do InLab_PrefApagar k
        checar "Piso padrão do TurboSmooth = 1" ((InLab_Otim_Piso "turbosmooth") == 1)
        InLab_PrefGravar "piso_turbosmooth" "2"
        checar "Piso do .ini vale por cima do padrão (2)" ((InLab_Otim_Piso "turbosmooth") == 2)
        InLab_PrefGravar "piso_chamfer" "abc"
        checar "Piso inválido no .ini cai no padrão (1)" ((InLab_Otim_Piso "chamfer") == 1)
        checar "Piso inexistente devolve undefined" ((InLab_Otim_Piso "nao_existe") == undefined)
        for k in chavesIni do InLab_PrefApagar k

        ---------------------------------------------------------------- FAIXA E ESTADO
        checar "Faixa sem família e sem meta = undefined" ((InLab_Otim_Faixa()) == undefined)
        INLAB_OTIM_META_MANUAL = 5000
        local fm = InLab_Otim_Faixa()
        checar "Faixa com meta manual = #(0, 5000, 5000)" (fm != undefined and fm[1] == 0 and fm[2] == 5000 and fm[3] == 5000)
        InLab_FamiliaAtiva = InLab_ObterFamilia "corpo_unico"
        local ff = InLab_Otim_Faixa()
        checar "Faixa da família vale por cima da meta manual (40000..100000, alvo 70000)" (ff[1] == 40000 and ff[2] == 100000 and ff[3] == 70000)
        checar "Estado: 70.000 dentro" ((InLab_Otim_Estado 70000 ff) == #dentro)
        checar "Estado: 105.000 perto (até 10% fora)" ((InLab_Otim_Estado 105000 ff) == #perto)
        checar "Estado: 150.000 longe" ((InLab_Otim_Estado 150000 ff) == #longe)
        checar "Estado: 38.000 perto (abaixo do mínimo, até 10%)" ((InLab_Otim_Estado 38000 ff) == #perto)
        checar "Estado sem faixa = #sem" ((InLab_Otim_Estado 1000 undefined) == #sem)

        ---------------------------------------------------------------- TEXTO
        checar "Milhar: 182340 -> 182.340" ((InLab_Otim_Milhar 182340) == "182.340")
        checar "Milhar: 999 -> 999" ((InLab_Otim_Milhar 999) == "999")
        checar "Milhar: 1000 -> 1.000" ((InLab_Otim_Milhar 1000) == "1.000")
        local txt = InLab_Otim_TextoMedidor 182340 ff
        checar ("Texto do medidor com a faixa ('" + txt + "')") ((findString txt "182.340") != undefined and (findString txt "40.000 a 100.000") != undefined)
        checar "Texto do medidor sem faixa pede família ou meta" ((findString (InLab_Otim_TextoMedidor 10 undefined) "família") != undefined)

        ---------------------------------------------------------------- ALVO DA SELEÇÃO
        limparCena()
        local c1 = Box()
        local c2 = Box pos:[50, 0, 0]
        InLab_FamiliaAtiva = undefined
        INLAB_OTIM_META_MANUAL = 20
        -- cena 24, meta 20: a seleção (c1, 12) pode ficar com 20 - (24 - 12) = 8
        checar "Alvo da seleção desconta o resto da cena (8)" ((InLab_Otim_AlvoSelecao #(c1) (InLab_Otim_Faixa())) == 8)
        checar "Alvo da seleção sem faixa = undefined" ((InLab_Otim_AlvoSelecao #(c1) undefined) == undefined)

        ---------------------------------------------------------------- REGISTRO DE REVERSÃO
        local ts = TurboSmooth iterations:3
        addModifier c1 ts
        local reg = #()
        InLab_Otim_Guardar reg ts #iterations
        ts.iterations = 2
        InLab_Otim_Guardar reg ts #iterations
        ts.iterations = 1
        local n = InLab_Otim_Restaurar reg
        checar "Restaurar volta ao valor mais antigo (3), na ordem inversa" (ts.iterations == 3 and n == 2)
        limparCena()
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    try ( limparCena() ) catch ()
    for k in chavesIni do try ( InLab_PrefApagar k ) catch ()
    InLab_FamiliaAtiva = undefined
    INLAB_OTIM_META_MANUAL = undefined
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
```

- [ ] **Step 3: Rodar e ver falhar**

No Max (MCP `execute_maxscript`), cena salva antes:

```maxscript
(
resetMaxFile #noPrompt
local err = ""
try (fileIn @"G:\Meu Drive\GitHub\InLabChecker\tests\test_otim_nucleo.ms") catch (err = getCurrentException())
local r = err + "\n"
local fs = openFile ((getDir #temp) + "\\inlab_test_otim_nucleo.txt")
while not eof fs do (local l = readLine fs; if not (matchPattern l pattern:"*LOG #*") do r += l + "\n")
close fs
r)
```

Esperado: `EXCEÇÃO` no `fileIn` de `functions\fn_otim_nucleo.ms` (arquivo nao existe).

- [ ] **Step 4: Implementar `functions/fn_otim_nucleo.ms`**

```maxscript
/*
================================================================================
 functions\fn_otim_nucleo.ms — núcleo da Otimização em 3 passos (23/09/2026)
--------------------------------------------------------------------------------
 Spec: docs\superpowers\specs\2026-09-23-otimizacao-design.md (issue #60).
 Base compartilhada dos 3 passos (Reduzir na origem, Ajuste fino, Faces
 escondidas): contagem em TRIÂNGULOS, faixa-alvo, estado do medidor, pisos
 de segurança (padrão aqui + ajuste da equipe no InLabChecker.ini, que
 sobrevive ao updater), registro de reversão e o despachante que a UI usa.

 CONTRATO DE CADA PASSO (um arquivo por passo, functions\fn_otim_*.ms):
   InLab_Otim<Passo>_Calcular objs     → #(OtimProposta), nada muda na cena
   InLab_Otim<Passo>_Aplicar propostas → aplica as marcadas, em undo, com registro
   InLab_Otim<Passo>_Reverter          → desfaz exatamente o último Aplicar
 <Passo> = Origem (1), Fino (2), Escondidas (3). A UI só fala com
 InLab_Otim_Calcular/Aplicar/Reverter passo — por isso #61, #62 e #63 só
 trocam o próprio arquivo.

 UNIDADE: triângulos por NÓ (instância conta uma vez por nó, como o GLB
 exporta). É o que o site carrega e não muda antes/depois do ProOptimizer
 (decisão do brainstorm de 23/09/2026).
================================================================================
*/

-- Nomes do contrato, declarados aqui porque os arquivos dos passos carregam
-- depois deste e o despachante abaixo é compilado antes deles.
global InLab_OtimOrigem_Calcular, InLab_OtimOrigem_Aplicar, InLab_OtimOrigem_Reverter
global InLab_OtimFino_Calcular, InLab_OtimFino_Aplicar, InLab_OtimFino_Reverter, InLab_OtimFino_Comparar
global InLab_OtimEscondidas_Calcular, InLab_OtimEscondidas_Aplicar, InLab_OtimEscondidas_Reverter

-- Uma linha da lista de revisão. `alvo`/`prop`/`antes`/`depois` descrevem o
-- ajuste (ex.: um TurboSmooth, #iterations, 3, 2); cada passo usa o que precisa.
struct OtimProposta
(
    no,              -- nó da cena que a linha afeta
    rotulo = "",     -- texto da linha na lista
    alvo,            -- objeto que recebe o ajuste (modificador, base object ou o nó)
    prop,            -- propriedade ajustada (#iterations, #VertexPercent...)
    antes,
    depois,
    trisAntes = 0,
    trisDepois = 0,
    motivo = "",
    marcada = true   -- caixa da lista; o Aplicar só usa as marcadas
)

-- Pisos de segurança e pesos (spec 3.2 e 3.3). Cada chave pode ser
-- sobrescrita no InLabChecker.ini como "piso_<chave>=valor".
global INLAB_OTIM_PISOS = #(
    #("turbosmooth", 1), #("meshsmooth", 1), #("opensubdiv", 1), #("nurms", 1),
    #("chamfer", 1), #("shell", 1), #("lathe", 8), #("extrude", 1),
    #("lados", 12), #("alturasegs", 1), #("esfera", 12),
    #("torus_segs", 12), #("torus_lados", 8), #("fillet", 1), #("boxsegs", 1),
    #("spline_passos", 2), #("spline_lados", 6),
    #("dano_subdiv", 2), #("dano_outros", 1),
    #("fino_pct", 60), #("fino_min", 300)
)

-- Meta digitada na tela quando não há família ativa (triângulos).
global INLAB_OTIM_META_MANUAL = undefined

global InLab_Otim_Triangulos
fn InLab_Otim_Triangulos objs =
(
    local total = 0
    for o in objs where InLab_EhGeometria o do total += (GetTriMeshFaceCount o)[1]
    total
)

global InLab_Otim_Piso
fn InLab_Otim_Piso chave =
(
    local padrao = undefined
    for p in INLAB_OTIM_PISOS where p[1] == chave do padrao = p[2]
    if padrao == undefined then
    (
        InLab_Log ("Otimização: piso '" + chave + "' não existe na tabela INLAB_OTIM_PISOS.") tipo:#err
        undefined
    )
    else
    (
        local txt = InLab_PrefLer ("piso_" + chave) ""
        if txt == "" then padrao
        else
        (
            local v = txt as float
            if v == undefined or v < 0 then
            (
                InLab_Log ("Otimização: piso_" + chave + "='" + txt + "' no InLabChecker.ini não é um número válido — usando " + padrao as string + ".") tipo:#warn
                padrao
            )
            else v
        )
    )
)

-- #(mínimo, máximo, alvo). Família ativa tem prioridade; sem família, a meta
-- manual vira #(0, meta, meta); sem nenhuma das duas, undefined.
global InLab_Otim_Faixa
fn InLab_Otim_Faixa =
(
    if InLab_FamiliaAtiva != undefined then
        #(InLab_FamiliaAtiva.polyMin, InLab_FamiliaAtiva.polyMax, (InLab_FamiliaAtiva.polyMin + InLab_FamiliaAtiva.polyMax) / 2)
    else if INLAB_OTIM_META_MANUAL != undefined then
        #(0, INLAB_OTIM_META_MANUAL, INLAB_OTIM_META_MANUAL)
    else undefined
)

-- Cor do medidor: #dentro (verde), #perto (até 10% fora, amarelo), #longe
-- (vermelho), #sem (sem faixa).
global InLab_Otim_Estado
fn InLab_Otim_Estado total faixa =
(
    if faixa == undefined then #sem
    else if total >= faixa[1] and total <= faixa[2] then #dentro
    else
    (
        local fora = if total > faixa[2] then ((total - faixa[2]) as float / (amax 1 faixa[2]))
                     else ((faixa[1] - total) as float / (amax 1 faixa[1]))
        if fora <= 0.10 then #perto else #longe
    )
)

-- 182340 → "182.340" (separador de milhar brasileiro).
global InLab_Otim_Milhar
fn InLab_Otim_Milhar n =
(
    local s = (n as integer) as string
    local r = ""
    for i = 1 to s.count do
    (
        r += s[i]
        local resta = s.count - i
        if resta > 0 and (mod resta 3) == 0 do r += "."
    )
    r
)

global InLab_Otim_TextoMedidor
fn InLab_Otim_TextoMedidor total faixa =
(
    local t = "Triângulos: " + (InLab_Otim_Milhar total)
    if faixa == undefined then t + "  ·  escolha a família (seção Produto) ou digite a meta"
    else if faixa[1] == 0 then t + "  ·  meta: " + (InLab_Otim_Milhar faixa[2])
    else t + "  ·  faixa da família: " + (InLab_Otim_Milhar faixa[1]) + " a " + (InLab_Otim_Milhar faixa[2])
)

-- Quanto a SELEÇÃO pode ter para a CENA inteira cair no alvo da faixa.
global InLab_Otim_AlvoSelecao
fn InLab_Otim_AlvoSelecao objs faixa =
(
    if faixa == undefined then undefined
    else
    (
        local cena = InLab_Otim_Triangulos (for o in geometry collect o)
        local sel = InLab_Otim_Triangulos objs
        amax 0 (faixa[3] - (cena - sel))
    )
)

-- Registro de reversão genérico: #(alvo, prop, valorAntes) por alteração.
global InLab_Otim_Guardar
fn InLab_Otim_Guardar registro alvo prop =
(
    append registro #(alvo, prop, getProperty alvo prop)
    registro
)

-- Volta na ORDEM INVERSA: se a mesma propriedade mudou duas vezes, termina no
-- valor mais antigo. Devolve quantas voltaram.
global InLab_Otim_Restaurar
fn InLab_Otim_Restaurar registro =
(
    local n = 0
    for i = registro.count to 1 by -1 do
    (
        local r = registro[i]
        try ( setProperty r[1] r[2] r[3]; n += 1 )
        catch ( InLab_Log ("Otimização: não voltou " + (r[2] as string) + " (" + getCurrentException() + ").") tipo:#err )
    )
    n
)
```

- [ ] **Step 5: Colocar no manifesto**

Em `InLabChecker.ms`, logo depois da linha `@"functions\fn_prooptimizer.ms",`:

```maxscript
            -- Otimização em 3 passos (issue #60): núcleo antes dos passos.
            @"functions\fn_otim_nucleo.ms",
```

- [ ] **Step 6: Rodar e ver passar**

Mesmo comando do Step 3. Esperado: 22 linhas `PASS` e `TUDO OK`.

- [ ] **Step 7: Commit**

```bash
git add functions/fn_otim_nucleo.ms tests/test_otim_nucleo.ms InLabChecker.ms
git commit -m "feat(otimizacao): nucleo com contagem em triangulos, faixa e pisos

Refs #60"
```

---

### Task 2: V-03 e V-04 em triangulos

**Files:**
- Modify: `verifications/verif_peso_poly.ms` (`InLab_V03_Poligonos`, `InLab_V04_PoligonosPorParte`)
- Modify: `tests/test_verificacoes.ms`, `tests/test_familia_ativa.ms` (lista de modulos)
- Modify: `docs/superpowers/specs/2026-09-23-otimizacao-design.md` (secao 3.1)
- Test: `tests/test_verificacoes.ms`

**Interfaces:**
- Consumes: `InLab_Otim_Triangulos objs` (Task 1).
- Produces: V-03 e V-04 medindo triangulos; nenhuma assinatura muda.

- [ ] **Step 1: Carregar o nucleo nos dois testes que rodam o orquestrador**

Em `tests/test_verificacoes.ms` e `tests/test_familia_ativa.ms`, na lista do `for m in #(...)`, logo depois de `@"core\utils.ms",` (em `test_familia_ativa.ms` a lista tem `@"functions\fn_realworldscale.ms"`; o nucleo entra antes dele):

```maxscript
                   @"functions\fn_otim_nucleo.ms",
```

E acrescentar `InLab_V03_Poligonos` ao bloco de `global` do topo de `tests/test_verificacoes.ms`.

- [ ] **Step 2: Escrever o caso que falha em `tests/test_verificacoes.ms`**

Antes do bloco `-- APROVAÇÃO`:

```maxscript
        ---------------------------------------------------------------- V-03 (triângulos)
        local t1 = Box()   -- 6 faces quad = 12 triângulos
        InLab_ResetarResultados()
        InLab_V03_Poligonos cfgEst #(t1)
        local m03 = mensagemDe "V-03"
        checar ("V-03 conta triângulos: '" + m03 + "'") ((findString m03 "12 triângulos") != undefined)
        checar "V-03 abaixo da faixa vira advertência (limite provisório)" ((statusDe "V-03") == #warning)
        limparCena()
```

(`cfgEst` ja existe no teste: `InLab_ObterFamilia "corpo_unico"`, definido no bloco da V-30. Se a ordem do arquivo colocar este bloco antes dele, mover o bloco para depois do bloco da V-30.)

- [ ] **Step 3: Rodar e ver falhar**

Comando da Task 1, Step 3, trocando `test_otim_nucleo` por `test_verificacoes`. Esperado: `FAIL  V-03 conta triângulos: '6 faces · faixa ...'`.

- [ ] **Step 4: Implementar em `verifications/verif_peso_poly.ms`**

Substituir `InLab_V03_Poligonos` inteira por:

```maxscript
-- V-03 · Total de TRIÂNGULOS dentro da faixa [polyMin, polyMax] da família.
-- 23/09/2026 (issue #60): passou de polígonos do Max para triângulos — o que
-- o GLB carrega (spec 2026-09-23-otimizacao-design.md). As faixas das
-- famílias foram escritas sem unidade: conferir com a equipe (#36).
fn InLab_V03_Poligonos cfg objetos =
(
    local total = InLab_Otim_Triangulos objetos
    local dentro = (total >= cfg.polyMin) and (total <= cfg.polyMax)
    local msg = total as string + " triângulos · faixa " + cfg.polyMin as string + "–" + cfg.polyMax as string + " (unidade da faixa a confirmar, #36)"
    InLab_RegistrarVerif "V-03" "Triângulos totais (faixa da família)" dentro msg provisorio:true
)
```

Em `InLab_V04_PoligonosPorParte`, trocar a linha

```maxscript
                local n = InLab_ContarPoligonos #(o)
```

por

```maxscript
                local n = InLab_Otim_Triangulos #(o)   -- triângulos (issue #60)
```

- [ ] **Step 5: Corrigir a spec**

Em `docs/superpowers/specs/2026-09-23-otimizacao-design.md`, secao 3.1, trocar

```
- **V-03 e V-05 passam a contar triangulos** (mesma funcao).
```

por

```
- **V-03 e V-04 passam a contar triangulos** (mesma funcao). A V-05 conta objetos (draw calls) e nao muda.
```

- [ ] **Step 6: Rodar os dois testes e ver passar**

`test_verificacoes`: esperado 35/35 `PASS`. `test_familia_ativa`: esperado 24/24.

- [ ] **Step 7: Commit**

```bash
git add verifications/verif_peso_poly.ms tests/test_verificacoes.ms tests/test_familia_ativa.ms docs/superpowers/specs/2026-09-23-otimizacao-design.md
git commit -m "feat(verif): V-03 e V-04 contam triangulos

Refs #60"
```

---

### Task 3: Os 3 passos no contrato (passo 2 provisorio)

**Files:**
- Create: `functions/fn_otim_origem.ms`, `functions/fn_otim_fino.ms`, `functions/fn_otim_escondidas.ms`
- Modify: `functions/fn_otim_nucleo.ms` (despachante no fim do arquivo), `InLabChecker.ms`
- Test: `tests/test_otim_nucleo.ms`

**Interfaces:**
- Consumes: Task 1 inteira; `InLab_ProOptimizer objs percentual`, `InLab_ReverterOtimizacao()` e `InLab_UltimaOtimizacao` (array de `OtimizacaoRecord` com o campo `modificador`) de `functions/fn_prooptimizer.ms`.
- Produces:
  - `InLab_Otim_Calcular passo objs -> #(OtimProposta)`, `InLab_Otim_Aplicar passo propostas -> integer`, `InLab_Otim_Reverter passo -> integer` (passo 1, 2 ou 3)
  - `InLab_OtimFino_Comparar ligar -> integer` (quantos modificadores mudaram)
  - As 10 funcoes do contrato declaradas no topo do nucleo

- [ ] **Step 1: Escrever os casos que falham**

Em `tests/test_otim_nucleo.ms`, acrescentar ao `for m in #(...)` do `fileIn`, depois de `fn_otim_nucleo.ms`:

```maxscript
                   @"functions\fn_otim_origem.ms", @"functions\fn_otim_fino.ms", @"functions\fn_otim_escondidas.ms"
```

E antes do `)` que fecha o `try`, depois do bloco de registro de reversao:

```maxscript
        ---------------------------------------------------------------- DESPACHANTE E PASSOS
        local e1 = Sphere radius:20 segs:48
        convertToPoly e1
        InLab_FamiliaAtiva = undefined
        local trisAntes = InLab_Otim_Triangulos #(e1)
        INLAB_OTIM_META_MANUAL = trisAntes / 2
        checar "Passo 1 (em construção) não propõe nada" ((InLab_Otim_Calcular 1 #(e1)).count == 0)
        checar "Passo 3 (em construção) não propõe nada" ((InLab_Otim_Calcular 3 #(e1)).count == 0)
        local props = InLab_Otim_Calcular 2 #(e1)
        checar "Passo 2 propõe uma linha por peça" (props.count == 1 and props[1].no == e1)
        checar "Passo 2: proposta com percentual < 100" (props[1].depois < 100.0)
        checar "Calcular não mexe na cena" ((InLab_Otim_Triangulos #(e1)) == trisAntes)
        InLab_Otim_Aplicar 2 props
        local trisDepois = InLab_Otim_Triangulos #(e1)
        checar ("Passo 2 reduz (" + trisAntes as string + " -> " + trisDepois as string + ")") (trisDepois < trisAntes * 0.75)
        checar "Comparar desliga o ajuste na viewport" ((InLab_OtimFino_Comparar false) == 1 and not e1.modifiers[1].enabledInViews)
        InLab_OtimFino_Comparar true
        props[1].marcada = false
        InLab_Otim_Reverter 2
        checar "Reverter do passo 2 volta os triângulos" ((InLab_Otim_Triangulos #(e1)) == trisAntes and e1.modifiers.count == 0)
        checar "Aplicar sem linha marcada não faz nada" ((InLab_Otim_Aplicar 2 props) == 0 and e1.modifiers.count == 0)
        checar "Passo inválido não propõe nada" ((InLab_Otim_Calcular 9 #(e1)).count == 0)
        limparCena()
```

- [ ] **Step 2: Rodar e ver falhar**

Esperado: `EXCEÇÃO` no `fileIn` de `functions\fn_otim_origem.ms`.

- [ ] **Step 3: Criar `functions/fn_otim_origem.ms`**

```maxscript
/*
================================================================================
 functions\fn_otim_origem.ms — Otimização · passo 1 · Reduzir na origem
--------------------------------------------------------------------------------
 23/09/2026 (issue #60): versão MÍNIMA, só para a tela e o manifesto já
 existirem. A issue #61 troca o conteúdo deste arquivo pelo passo de verdade
 (spec 2026-09-23-otimizacao-design.md, seção 3.2), sem mexer na UI.
 Contrato: ver o cabeçalho de functions\fn_otim_nucleo.ms.
================================================================================
*/

fn InLab_OtimOrigem_Calcular objs =
(
    InLab_Log "Reduzir na origem: em construção (issue #61)." tipo:#info
    #()
)

fn InLab_OtimOrigem_Aplicar propostas =
(
    InLab_Log "Reduzir na origem: em construção (issue #61)." tipo:#info
    0
)

fn InLab_OtimOrigem_Reverter =
(
    InLab_Log "Reduzir na origem: nada a reverter." tipo:#info
    0
)
```

(Sem `global` antes das `fn`: os nomes ja foram declarados `global` no topo de `fn_otim_nucleo.ms`, carregado antes.)

- [ ] **Step 4: Criar `functions/fn_otim_escondidas.ms`**

```maxscript
/*
================================================================================
 functions\fn_otim_escondidas.ms — Otimização · passo 3 · Faces escondidas
--------------------------------------------------------------------------------
 23/09/2026 (issue #60): versão MÍNIMA, só para a tela e o manifesto já
 existirem. A issue #63 troca o conteúdo deste arquivo pelo passo de verdade
 (spec 2026-09-23-otimizacao-design.md, seções 3.4 e 5), sem mexer na UI.
 Contrato: ver o cabeçalho de functions\fn_otim_nucleo.ms.
================================================================================
*/

fn InLab_OtimEscondidas_Calcular objs =
(
    InLab_Log "Faces escondidas: em construção (issue #63)." tipo:#info
    #()
)

fn InLab_OtimEscondidas_Aplicar propostas =
(
    InLab_Log "Faces escondidas: em construção (issue #63)." tipo:#info
    0
)

fn InLab_OtimEscondidas_Reverter =
(
    InLab_Log "Faces escondidas: nada a reverter." tipo:#info
    0
)
```

- [ ] **Step 5: Criar `functions/fn_otim_fino.ms`**

```maxscript
/*
================================================================================
 functions\fn_otim_fino.ms — Otimização · passo 2 · Ajuste fino
--------------------------------------------------------------------------------
 23/09/2026 (issue #60): versão PROVISÓRIA. Faz o que o botão antigo do
 ProOptimizer fazia (percentual ÚNICO calculado pela meta), agora como uma
 linha por peça na lista de revisão, para a seção Otimização nunca ficar sem
 ferramenta. A issue #62 troca o conteúdo deste arquivo pela meta por peça
 com proteções (spec 2026-09-23-otimizacao-design.md, seção 3.3).
 Usa InLab_ProOptimizer / InLab_ReverterOtimizacao de fn_prooptimizer.ms.
 Contrato: ver o cabeçalho de functions\fn_otim_nucleo.ms.
================================================================================
*/

fn InLab_OtimFino_Calcular objs =
(
    local geo = for o in objs where InLab_EhGeometria o collect o
    local total = InLab_Otim_Triangulos geo
    local alvo = InLab_Otim_AlvoSelecao geo (InLab_Otim_Faixa())
    if alvo == undefined then
    (
        InLab_Log "Ajuste fino: escolha a família (seção Produto) ou digite a meta." tipo:#warn
        #()
    )
    else if total == 0 or total <= alvo then
    (
        InLab_Log ("Ajuste fino: a seleção já cabe na meta (" + (InLab_Otim_Milhar total) + " triângulos).") tipo:#ok
        #()
    )
    else
    (
        local pct = amax 1.0 (100.0 * alvo / total)
        for o in geo collect
        (
            local t = InLab_Otim_Triangulos #(o)
            local depois = (t * pct / 100.0) as integer
            OtimProposta no:o alvo:o prop:#VertexPercent antes:100.0 depois:pct trisAntes:t trisDepois:depois \
                rotulo:(o.name + "  ·  " + (formattedPrint pct format:".0f") + "%  ·  " + (InLab_Otim_Milhar t) + " → " + (InLab_Otim_Milhar depois)) \
                motivo:"percentual único (provisório até a issue #62)"
        )
    )
)

fn InLab_OtimFino_Aplicar propostas =
(
    local marcadas = for p in propostas where p.marcada and isValidNode p.no collect p
    if marcadas.count == 0 then
    (
        InLab_Log "Ajuste fino: nenhuma peça marcada." tipo:#warn
        0
    )
    else InLab_ProOptimizer (for p in marcadas collect p.no) marcadas[1].depois
)

fn InLab_OtimFino_Reverter = InLab_ReverterOtimizacao()

-- Liga/desliga na viewport os ProOptimizer do último Aplicar (Comparar).
fn InLab_OtimFino_Comparar ligar =
(
    local n = 0
    for r in InLab_UltimaOtimizacao where r.modificador != undefined do
    (
        try ( r.modificador.enabledInViews = ligar; n += 1 )
        catch ( InLab_Log ("Comparar: não alternou o ProOptimizer de um objeto (" + getCurrentException() + ").") tipo:#warn )
    )
    n
)
```

- [ ] **Step 6: Acrescentar o despachante ao fim de `functions/fn_otim_nucleo.ms`**

```maxscript
--------------------------------------------------------------------------------
-- DESPACHANTE: a UI só chama estas três. passo = 1 (origem), 2 (fino), 3 (escondidas).
--------------------------------------------------------------------------------
global InLab_Otim_Calcular
fn InLab_Otim_Calcular passo objs =
(
    case passo of
    (
        1: InLab_OtimOrigem_Calcular objs
        2: InLab_OtimFino_Calcular objs
        3: InLab_OtimEscondidas_Calcular objs
        default: ( InLab_Log ("Otimização: passo " + passo as string + " não existe.") tipo:#err; #() )
    )
)

global InLab_Otim_Aplicar
fn InLab_Otim_Aplicar passo propostas =
(
    case passo of
    (
        1: InLab_OtimOrigem_Aplicar propostas
        2: InLab_OtimFino_Aplicar propostas
        3: InLab_OtimEscondidas_Aplicar propostas
        default: 0
    )
)

global InLab_Otim_Reverter
fn InLab_Otim_Reverter passo =
(
    case passo of
    (
        1: InLab_OtimOrigem_Reverter()
        2: InLab_OtimFino_Reverter()
        3: InLab_OtimEscondidas_Reverter()
        default: 0
    )
)
```

- [ ] **Step 7: Manifesto**

Em `InLabChecker.ms`, logo depois de `@"functions\fn_otim_nucleo.ms",`:

```maxscript
            @"functions\fn_otim_origem.ms",
            @"functions\fn_otim_fino.ms",
            @"functions\fn_otim_escondidas.ms",
```

- [ ] **Step 8: Rodar e ver passar**

Esperado: `test_otim_nucleo` com 32 `PASS` e `TUDO OK`. Se `Passo 2 reduz` falhar com os triangulos iguais, conferir no log do arquivo de saida se o ProOptimizer logou "NÃO reduziu": o `.Calculate` exige o no selecionado e o painel Modify (cabecalho de `fn_prooptimizer.ms`); o teste roda com o Max em primeiro plano.

- [ ] **Step 9: Commit**

```bash
git add functions/fn_otim_origem.ms functions/fn_otim_fino.ms functions/fn_otim_escondidas.ms functions/fn_otim_nucleo.ms InLabChecker.ms tests/test_otim_nucleo.ms
git commit -m "feat(otimizacao): os 3 passos no contrato, passo 2 provisorio

Refs #60"
```

---

### Task 4: Tela da Otimizacao e secao UV e Texturas

**Files:**
- Modify: `ui/rollout_main.ms` (rollout `InLabSecOtimizacao` reescrito, rollout `InLabSecUV` novo, `InLabSecProduto` avisa a mudanca de familia, `AddSubRollout`, cabecalho)

**Interfaces:**
- Consumes: `InLab_Otim_*` e `INLAB_OTIM_META_MANUAL` (Tasks 1 e 3), `InLab_ObjetosVerificacao()` (`verifications/verif_orquestrador.ms`), `InLab_SelecaoValida()`, `InLab_Kit_Cor`, `InLab_Kit_Fonte`, `InLab_AutoUV`, `InLab_CleanUV`, `InLab_ReverterAutoUV`, `InLab_RealWorldFix`, `INLAB_UV_RESOLUCOES`.
- Produces: `INLAB_OTIM_PROPOSTAS` (global, propostas do ultimo Calcular) e `InLab_OtimUI_Atualizar()` (repinta o medidor; chamada pela secao Produto quando a familia muda).

- [ ] **Step 1: Sondar o ListView com checkbox dentro de rollout (uma chamada so do MCP)**

```maxscript
(
    rollout sondaLV "sonda" width:300
    (
        dotNetControl lv "System.Windows.Forms.ListView" width:280 height:100
        on sondaLV open do
        (
            lv.View = (dotNetClass "System.Windows.Forms.View").Details
            lv.CheckBoxes = true
            lv.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").None
            lv.Columns.Add "Proposta" 260
            for t in #("a", "b") do ( local it = dotNetObject "System.Windows.Forms.ListViewItem" t; it.Checked = true; lv.Items.Add it )
            lv.Items.Item[1].Checked = false
        )
    )
    createDialog sondaLV
    local r = (sondaLV.lv.Items.Count as string) + " itens · " + (sondaLV.lv.Items.Item[0].Checked as string) + "/" + (sondaLV.lv.Items.Item[1].Checked as string)
    destroyDialog sondaLV
    r
)
```

Esperado: `"2 itens · true/false"`. Se der outra coisa, parar e registrar na issue #60 antes de seguir (a lista e o coracao da tela).

- [ ] **Step 2: Declarar o global de atualizacao no topo das secoes**

Em `ui/rollout_main.ms`, logo antes de `global InLab_ProdutoAtivo = undefined`:

```maxscript
-- Repinta o medidor da Otimização. Definida depois de InLabSecOtimizacao;
-- declarada aqui porque a seção Produto (abaixo) a chama quando a família muda.
global InLab_OtimUI_Atualizar
global INLAB_OTIM_PROPOSTAS = #()
```

- [ ] **Step 3: Avisar a Otimizacao quando a familia muda (secao Produto)**

Dentro de `rollout InLabSecProduto`, trocar o handler

```maxscript
    on ddlFamilia selected i do InLab_DefinirFamiliaAtiva (familiaEscolhida())
```

por

```maxscript
    on ddlFamilia selected i do
    (
        InLab_DefinirFamiliaAtiva (familiaEscolhida())
        if InLab_OtimUI_Atualizar != undefined do InLab_OtimUI_Atualizar()
    )
```

E em `fn sugerirFamilia`, logo depois de `mostrarFamilia()`:

```maxscript
            if InLab_OtimUI_Atualizar != undefined do InLab_OtimUI_Atualizar()
```

- [ ] **Step 4: Reescrever `rollout InLabSecOtimizacao` e criar `rollout InLabSecUV`**

Substituir o bloco inteiro, do comentario `-- SEÇÃO: Otimização (ProOptimizer + Auto UV + Real World Fix)` ate o `)` que fecha `rollout InLabSecOtimizacao`, por:

```maxscript
----------------------------------------------------------------------
-- SEÇÃO: Otimização em 3 passos (issue #60)
----------------------------------------------------------------------
-- Spec: docs\superpowers\specs\2026-09-23-otimizacao-design.md. Medidor da
-- cena inteira (triângulos x faixa da família) + lista de revisão. A seção
-- só fala com o despachante InLab_Otim_Calcular/Aplicar/Reverter passo
-- (functions\fn_otim_nucleo.ms): cada passo mora no próprio arquivo.
-- O botão antigo do ProOptimizer (percentual + "Alvo da família") saiu: o
-- passo 2 faz o mesmo, por peça, até a issue #62 trazer a meta por peça.
rollout InLabSecOtimizacao "Otimização" width:420
(
    local comparando = false

    dotNetControl lblMedidor "System.Windows.Forms.Label" width:395 height:24
    spinner spnMeta "Meta (triângulos):" range:[1000, 5000000, 100000] type:#integer fieldWidth:70 align:#left enabled:false
    radiobuttons rdoPasso labels:#("1 · Reduzir", "2 · Ajuste fino", "3 · Escondidas") default:2 columns:3
    button btnCalcular "Calcular" width:395 height:24 tooltip:"Mostra o que o passo propõe para a seleção. Nada muda até Aplicar."
    dotNetControl lvPropostas "System.Windows.Forms.ListView" width:395 height:150
    button btnAplicar "Aplicar" width:126 height:24 across:3 tooltip:"Aplica só as linhas marcadas."
    button btnComparar "Comparar" width:126 height:24 tooltip:"Liga e desliga o ajuste fino na tela para ver o antes e o depois."
    button btnReverter "Reverter" width:126 height:24 tooltip:"Desfaz o último Aplicar deste passo."

    fn pintarMedidor =
    (
        local faixa = InLab_Otim_Faixa()
        spnMeta.enabled = (InLab_FamiliaAtiva == undefined)
        local total = InLab_Otim_Triangulos (InLab_ObjetosVerificacao())
        local suf = case (InLab_Otim_Estado total faixa) of
        (
            #dentro: "OK"
            #perto:  "WARN"
            #longe:  "ERR"
            default: "INFO"
        )
        lblMedidor.Text = InLab_Otim_TextoMedidor total faixa
        lblMedidor.BackColor = InLab_Kit_Cor ((suf + "_FUNDO") as name)
        lblMedidor.ForeColor = InLab_Kit_Cor ((suf + "_TEXTO") as name)
    )

    fn encherLista =
    (
        lvPropostas.Items.Clear()
        for p in INLAB_OTIM_PROPOSTAS do
        (
            local it = dotNetObject "System.Windows.Forms.ListViewItem" p.rotulo
            it.Checked = p.marcada
            lvPropostas.Items.Add it
        )
    )

    fn lerMarcadas =
        for i = 1 to INLAB_OTIM_PROPOSTAS.count where i <= lvPropostas.Items.Count do
            INLAB_OTIM_PROPOSTAS[i].marcada = lvPropostas.Items.Item[i - 1].Checked

    fn pararComparacao =
        if comparando do
        (
            InLab_OtimFino_Comparar true
            comparando = false
            btnComparar.text = "Comparar"
        )

    on InLabSecOtimizacao open do
    (
        lblMedidor.Font = InLab_Kit_Fonte 9
        lblMedidor.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleLeft
        lvPropostas.View = (dotNetClass "System.Windows.Forms.View").Details
        lvPropostas.CheckBoxes = true
        lvPropostas.FullRowSelect = true
        lvPropostas.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").None
        lvPropostas.Columns.Add "Proposta" 372
        lvPropostas.BackColor = InLab_Kit_Cor #LOG
        lvPropostas.ForeColor = InLab_Kit_Cor #TEXTO
        if INLAB_OTIM_META_MANUAL != undefined do spnMeta.value = INLAB_OTIM_META_MANUAL
        btnComparar.enabled = (rdoPasso.state == 2)
        encherLista()
        pintarMedidor()
    )

    on spnMeta changed v do
    (
        INLAB_OTIM_META_MANUAL = v
        pintarMedidor()
    )

    on rdoPasso changed s do
    (
        pararComparacao()
        INLAB_OTIM_PROPOSTAS = #()
        encherLista()
        btnComparar.enabled = (s == 2)
    )

    on btnCalcular pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            pararComparacao()
            InLab_ProgressoIniciar "Calculando..."
            INLAB_OTIM_PROPOSTAS = InLab_Otim_Calcular rdoPasso.state objs
            InLab_ProgressoParar()
            encherLista()
            if INLAB_OTIM_PROPOSTAS.count > 0 do
                InLab_Log ("Otimização · passo " + rdoPasso.state as string + ": " + INLAB_OTIM_PROPOSTAS.count as string +
                           " proposta(s). Desmarque o que não quiser e clique em Aplicar.")
        )
    )

    on btnAplicar pressed do
    (
        if INLAB_OTIM_PROPOSTAS.count == 0 then
            InLab_Log "Clique em Calcular antes de Aplicar." tipo:#warn
        else
        (
            lerMarcadas()
            InLab_ProgressoIniciar "Aplicando..."
            InLab_Otim_Aplicar rdoPasso.state INLAB_OTIM_PROPOSTAS
            InLab_ProgressoParar()
            INLAB_OTIM_PROPOSTAS = #()
            encherLista()
            pintarMedidor()
        )
    )

    on btnComparar pressed do
    (
        comparando = not comparando
        InLab_OtimFino_Comparar (not comparando)
        btnComparar.text = if comparando then "Mostrar ajuste" else "Comparar"
    )

    on btnReverter pressed do
    (
        pararComparacao()
        InLab_Otim_Reverter rdoPasso.state
        pintarMedidor()
    )
)

fn InLab_OtimUI_Atualizar =
    try ( InLabSecOtimizacao.pintarMedidor() )
    catch ( InLab_Log ("Otimização: medidor não atualizou (" + getCurrentException() + ").") tipo:#warn )

----------------------------------------------------------------------
-- SEÇÃO: UV e Texturas (issue #60)
----------------------------------------------------------------------
-- Auto UV, Clean UV e Real World Fix saíram da seção Otimização sem mudar
-- nada: mesmos controles, mesmos handlers. Os textos entram na revisão #58.
rollout InLabSecUV "UV e Texturas" width:420
(
    -- 18/Set (issue #1): o padding sai da resolução do bake; o Auto UV grava
    -- no canal 3 e não toca no canal 1. Os itens do dropdown seguem a ordem
    -- de INLAB_UV_RESOLUCOES (functions\fn_autouv.ms).
    label lblF2 "Auto UV  (canal 3 · bake de textura e AO)" align:#left
    spinner spnAnguloUV "Ângulo flatten (°):" range:[10, 90, 55] type:#float fieldWidth:40 align:#left
    dropdownlist ddlResolucaoUV "Resolução do bake:" items:#("1024", "2048", "4096") selection:1 width:120 align:#left
    button btnF2 "Auto UV na Seleção" width:126 across:3
    button btnF2Clean "Clean UV" width:126
    button btnF2Reverter "Reverter Auto UV" width:126

    label lblF34 "Real World Fix  (tira o Real-World Map Size · WebGL)" align:#left across:1
    button btnRWFix "Real World Fix" width:390 height:25

    on btnF2 pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            InLab_ProgressoIniciar "Gerando Auto UV..."
            InLab_AutoUV objs angulo:spnAnguloUV.value resolucao:INLAB_UV_RESOLUCOES[ddlResolucaoUV.selection]
            InLab_ProgressoParar()
        )
    )
    on btnF2Clean pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_CleanUV objs
    )
    on btnF2Reverter pressed do InLab_ReverterAutoUV()

    on btnRWFix pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_RealWorldFix objs
    )
)
```

- [ ] **Step 5: Registrar a secao nova no painel**

Em `on InLabChecker_Rollout open do`, logo depois de `AddSubRollout subSecoes InLabSecOtimizacao rolledUp:true`:

```maxscript
        AddSubRollout subSecoes InLabSecUV rolledUp:true
```

- [ ] **Step 6: Cabecalho do arquivo**

No fim do bloco de historico do cabecalho de `ui/rollout_main.ms` (antes da linha `====` que fecha), acrescentar:

```
 23/09/2026 (issue #60): seção Otimização reescrita — medidor em triângulos
 (cena x faixa da família), seletor de passo 1/2/3 e lista de revisão
 (ListView com checkbox). Fala só com InLab_Otim_Calcular/Aplicar/Reverter.
 O ProOptimizer por percentual saiu da tela (o passo 2 faz o mesmo por peça).
 Auto UV, Clean UV e Real World Fix foram para a seção nova "UV e Texturas",
 sem mudar comportamento. A seção Produto repinta o medidor quando a família
 muda (InLab_OtimUI_Atualizar).
```

- [ ] **Step 7: Conferir no Max (uma chamada so do MCP)**

Com a cena do usuario salva, abrir o plugin e exercitar a secao pelo codigo:

```maxscript
(
    resetMaxFile #noPrompt
    fileIn @"G:\Meu Drive\GitHub\InLabChecker\InLabChecker.ms"
    local r = ""
    local s = InLabSecOtimizacao
    r += "medidor sem família: " + s.lblMedidor.Text + "\n"
    local e = Sphere radius:20 segs:48
    convertToPoly e
    select e
    INLAB_OTIM_META_MANUAL = (InLab_Otim_Triangulos #(e)) / 2
    InLab_OtimUI_Atualizar()
    r += "medidor com meta: " + s.lblMedidor.Text + "\n"
    INLAB_OTIM_PROPOSTAS = InLab_Otim_Calcular 2 #(e)
    s.encherLista()
    r += "linhas na lista: " + s.lvPropostas.Items.Count as string + " · marcada: " + (s.lvPropostas.Items.Item[0].Checked as string) + "\n"
    s.lerMarcadas()
    InLab_Otim_Aplicar 2 INLAB_OTIM_PROPOSTAS
    InLab_OtimUI_Atualizar()
    r += "depois de aplicar: " + s.lblMedidor.Text + "\n"
    InLab_DefinirFamiliaAtiva "corpo_unico"
    InLab_OtimUI_Atualizar()
    r += "com família: " + s.lblMedidor.Text + " · meta habilitada: " + (s.spnMeta.enabled as string) + "\n"
    r += "seção UV existe: " + ((InLabSecUV != undefined) as string)
    InLab_DefinirFamiliaAtiva ""
    INLAB_OTIM_META_MANUAL = undefined
    r
)
```

Esperado: medidor pedindo familia ou meta; com meta, "meta: N"; 1 linha marcada; triangulos caem depois de aplicar; com familia, "faixa da família: 40.000 a 100.000" e meta desabilitada; `seção UV existe: true`. Depois tirar uma captura (`capture_screen`) do painel com as secoes Otimizacao e UV e Texturas abertas e conferir que nada ficou cortado. Reabrir a cena do usuario no fim.

- [ ] **Step 8: Rodar a suite inteira**

```maxscript
(
local raiz = @"G:\Meu Drive\GitHub\InLabChecker\tests\"
local pares = #(#("versao","versao"),#("prefs","prefs"),#("renomear_produto","renomear"),#("verif_uv","verif_uv"),#("realworldfix","realworldfix"),#("kit_header","kit_header"),#("secao_atualizacao","secao_atualizacao"),#("updater_checagem","updater_checagem"),#("updater_aplicar","updater_aplicar"),#("familia_ativa","familia_ativa"),#("verificacoes","verificacoes"),#("otim_nucleo","otim_nucleo"),#("autouv","autouv"))
local res = "", tp = 0, tf = 0
for par in pares do (
  resetMaxFile #noPrompt
  local err = ""
  try (fileIn (raiz + "test_" + par[1] + ".ms")) catch (err = getCurrentException())
  local p = 0, f = 0, fails = ""
  local fs = openFile ((getDir #temp) + "\\inlab_test_" + par[2] + ".txt")
  while not eof fs do (local l = readLine fs; if matchPattern l pattern:"PASS*" do p += 1; if matchPattern l pattern:"FAIL*" or matchPattern l pattern:"EXCE*" do (f += 1; fails += "\n    " + l))
  close fs
  tp += p; tf += f
  res += "\n" + par[1] + ": " + p as string + "/" + (p+f) as string + (if err != "" then " EXC=" + err else "") + fails
)
"TOTAL PASS=" + tp as string + " FAIL=" + tf as string + res)
```

Esperado: `FAIL=0`. (Se testes novos entraram entre a escrita deste plano e a execucao, acrescentar na lista.)

- [ ] **Step 9: Commit, PR e issue**

```bash
git add ui/rollout_main.ms
git commit -m "feat(otimizacao): tela com medidor e revisao, secao UV e Texturas

Closes #60"
git push -u origin feat/otimizacao-nucleo
gh pr create --base main --title "feat(otimizacao): nucleo, medidor em triangulos e tela dos 3 passos" --body "Closes #60 ..."
```

No corpo do PR: o que mudou (4 modulos, V-03/V-04 em triangulos, tela, secao UV), o resultado da suite e da conferencia do Step 7, e a captura do painel. Depois do merge, trocar `bloqueada` por `livre` em #61, #62 (se #42 ja estiver fechada) e #63.

---

## Self-review (feito ao escrever)

- **Cobertura da spec (entrega O1, secao 7):** nucleo (Task 1); V-03 em triangulos (Task 2; a spec dizia V-05 por engano, corrigido no Step 5 da Task 2); tela completa com medidor, seletor, lista, Comparar so no passo 2 (Task 4); 3 arquivos no manifesto com versao minima e passo 2 provisorio (Task 3); ProOptimizer antigo fora da UI (Task 4, Step 4); secao UV e Texturas (Task 4); textos no padrao #58 nos controles novos (Task 4).
- **Fora de O1 de proposito:** pisos por familia, tela de pisos (spec secao 8); `InLab_PercentualParaAlvo` e `fn_prooptimizer.ms` ficam ate #62/#52.
- **Nomes conferidos entre tarefas:** `OtimProposta` (campos `no`, `rotulo`, `depois`, `marcada`), `InLab_Otim_Calcular/Aplicar/Reverter passo`, `InLab_OtimFino_Comparar ligar`, `INLAB_OTIM_PROPOSTAS`, `INLAB_OTIM_META_MANUAL`, `InLab_OtimUI_Atualizar`.
