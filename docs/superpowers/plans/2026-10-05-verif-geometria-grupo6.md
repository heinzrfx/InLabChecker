# Grupo 6 · Verificações de geometria — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ligar ao motor de verificação a V-07 (ratio vértices/triângulos do GLB), V-08 (arestas abertas), V-09 (duplicatas), V-10 (normais invertidas) e V-13 (ngons em curva), com teste no Max.

**Architecture:** Arquivo novo `verifications/verif_malha.ms`. As V-08/09/10/13 leem uma `MalhaAnalise` por grupo de instâncias, montada com um único `snapshotAsMesh` por peça e operações nativas (`meshop`, `polyop`, `sort`), sem `Dictionary` em laço. A V-07 exporta a cena para um glTF temporário e lê a contagem por nó. O orquestrador chama as cinco num bloco "Grupo 6".

**Tech Stack:** MaxScript (3ds Max 2024; alvo também 2027), MCP do 3ds Max para rodar os testes.

**Spec:** `docs/superpowers/specs/2026-10-05-verif-geometria-grupo6-design.md`

## Global Constraints

- Tudo em português: código, comentários, log e mensagens. Funções públicas `InLab_`, constantes `INLAB_MAIUSCULO`.
- Nenhum `Dictionary` (nem `hasDictValue`) em laço por face, canto ou aresta. Duplicata e únicos saem de `sort` nativo sobre doubles.
- Tolerância de posição `units.decodeValue "0.01mm"`; planaridade 1°; curvatura 15°.
- Severidade: V-07 `critico:true provisorio:true`; V-08 `critico:false`; V-09, V-10, V-13 `critico:true`. "Não medido" = `passou:false critico:false` (vira `#warning`).
- Só leitura: nada muda na cena. A V-07 escreve em `(getDir #temp) + "\inlab_v07\"` e apaga o que escreveu.
- Mensagens: no máximo 8 itens e depois "(+N)".
- Cabeçalho `/* === ... === */` com caminho, o que faz e decisões datadas (05/10/2026), como nos outros arquivos.
- Commits em português, sem acento no assunto, `feat(verif): ...`, terminando com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Nada é dado como pronto sem rodar no Max (MCP). Se o MCP não estiver conectado, avisar.

## Review Focus

- **Peça sem faces** (snapshot vazio): a análise devolve zeros sem erro de índice. Testado na Task 1 com `mesh numverts:0 numfaces:0`.
- **Objeto agrupado (grupo fechado)**: `snapshotAsMesh` e `polyop` funcionam no membro sem abrir o grupo; a V-09b não acusa o membro contra a cabeça do grupo (a cabeça não é geometria, `InLab_ObjetosVerificacao` não a inclui). Testado na Task 2.
- **Nome repetido no Max** na V-07: os nós de mesmo nome somam no mesmo item, sem erro. Testado na Task 4.
- **Cena com objeto oculto** na V-07: o exportador pode deixá-lo de fora do glTF; o objeto só não aparece na contagem, sem "não medido" se outros saíram. Testado na Task 4.
- **Peça grande**: Teapot de 262 mil triângulos abaixo do teto de tempo. Testado na Task 5.

---

## Como rodar um teste no Max (vale para todas as tasks)

Pelo MCP (`execute_maxscript`), numa chamada só:

```maxscript
(
resetMaxFile #noPrompt
local arq = (getDir #temp) + "\\inlab_test_verif_malha.txt"
try (fileIn @"G:\Meu Drive\GitHub\InLabChecker\tests\test_verif_malha.ms") catch ()
local out = ""; local p = 0
local fs = openFile arq mode:"rt"
while not eof fs do (local l = readLine fs; if matchPattern l pattern:"PASS*" then p += 1 else if matchPattern l pattern:"FAIL*" or matchPattern l pattern:"EXCE*" or matchPattern l pattern:"*FALHA*" or matchPattern l pattern:"TUDO*" do out += "\n" + l)
close fs
"PASS: " + p as string + out
)
```

"Passou" = nenhuma linha `FAIL`/`EXCEÇÃO` e a última linha `TUDO OK`.

---

### Task 1: Núcleo da análise, V-08 e V-10

**Files:**
- Create: `verifications/verif_malha.ms`
- Create: `tests/test_verif_malha.ms`
- Modify: `InLabChecker.ms` (manifesto, depois de `@"verifications\verif_geometria.ms",`)

**Interfaces:**
- Consumes: `InLab_Log msg tipo:` (core/log.ms), `InLab_RegistrarVerif id nome passou msg critico: provisorio:` (core/struct_result.ms), `InLab_DeduplicarInstancias objs` → array de `InLab_GrupoInstancias (no, instancias)` e `InLab_InstanciasDoNo o` (core/utils.ms).
- Produces:
  - `struct MalhaAnalise (no, instancias, tris, furos, invertidas, avesso, duplicadas, ngonsNaoPlanas, ngonsNaCurva, ngonsAplica, erro)`
  - `InLab_Malha_Lista itens maximo:8` → string
  - `InLab_Malha_ArestasInvertidas m abertas` → integer (arestas abertas com gêmea no mesmo sentido)
  - `InLab_Malha_ElementosDoAvesso m abertas` → integer
  - `InLab_Malha_Analisar o tol:` → `MalhaAnalise`
  - `InLab_Malha_AnalisarCena objs` → array de `MalhaAnalise`
  - `InLab_V08_MalhaFechada analises`, `InLab_V10_Normais analises`

- [ ] **Step 1: Escrever o teste (vermelho)**

Criar `tests/test_verif_malha.ms`:

```maxscript
/*
 tests\test_verif_malha.ms — teste do grupo 6 de verificações (issue #102)
 Spec: docs\superpowers\specs\2026-10-05-verif-geometria-grupo6-design.md
 RODAR NUMA CENA VAZIA (File > New): cria e apaga os objetos de cada caso.
 Resultado: <pasta temp do Max>\inlab_test_verif_malha.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_VerifResults, InLab_ResetarResultados, INLAB_LIMITES_PROVISORIOS, InLab_ObterFamilia
global InLab_Malha_Analisar, InLab_Malha_AnalisarCena, InLab_V08_MalhaFechada, InLab_V10_Normais
global InLab_V09_Duplicados, InLab_V13_Ngons, InLab_V07_RatioVT, InLab_ObjetosVerificacao
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_verif_malha.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn statusDe idV =
    (
        local achado = #ausente
        for r in InLab_VerifResults where r.id == idV do achado = r.status
        achado
    )
    fn mensagemDe idV =
    (
        local achado = ""
        for r in InLab_VerifResults where r.id == idV do achado = r.mensagem
        achado
    )
    fn limparCena = ( delete (for o in objects collect o) )
    -- Roda a análise e UMA verificação de malha; devolve o status.
    fn rodarMalha f objs idV = ( InLab_ResetarResultados(); f (InLab_Malha_AnalisarCena objs); statusDe idV )
    fn caixaMesh = ( local b = Box length:40 width:40 height:40; convertToMesh b; b )

    local logOriginal = InLab_Log
    local unidadeOriginal = units.SystemType
    local provOriginal = true

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms",
                   @"familias\familia_corpo_unico.ms",
                   @"functions\fn_json.ms", @"functions\fn_export_gltf.ms",
                   @"verifications\verif_malha.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        provOriginal = INLAB_LIMITES_PROVISORIOS
        units.SystemType = #Centimeters
        limparCena()

        ---------------------------------------------------------------- ANÁLISE
        local b = caixaMesh()
        local a = InLab_Malha_Analisar b
        checar ("Análise: Box fechado — 12 tris, 0 furo, 0 invertida, 0 avesso (" + a.tris as string + "/" + a.furos as string + "/" + a.invertidas as string + "/" + a.avesso as string + ")") \
            (a.tris == 12 and a.furos == 0 and a.invertidas == 0 and a.avesso == 0 and a.erro == undefined)
        limparCena()
        local vazio = mesh numverts:0 numfaces:0
        local av = InLab_Malha_Analisar vazio
        checar "Análise: malha vazia devolve zeros sem erro" (av.tris == 0 and av.furos == 0 and av.erro == undefined)
        limparCena()

        ---------------------------------------------------------------- V-08
        b = caixaMesh()
        checar "V-08: Box fechado passa" ((rodarMalha InLab_V08_MalhaFechada #(b) "V-08") == #pass)
        meshop.deleteFaces b #{1}
        update b
        checar "V-08: Box com uma face apagada vira advertência" ((rodarMalha InLab_V08_MalhaFechada #(b) "V-08") == #warning)
        checar ("V-08: mensagem tem o objeto e a contagem ('" + mensagemDe "V-08" + "')") ((findString (mensagemDe "V-08") (b.name + ": 3 aresta")) != undefined)
        checar "V-10: furo de verdade não é normal invertida" ((rodarMalha InLab_V10_Normais #(b) "V-10") == #pass)
        limparCena()

        ---------------------------------------------------------------- V-10
        b = caixaMesh()
        checar "V-10: Box fechado passa" ((rodarMalha InLab_V10_Normais #(b) "V-10") == #pass)
        meshop.flipNormals b #{1}
        update b
        checar "V-10: uma face com o sentido trocado reprova" ((rodarMalha InLab_V10_Normais #(b) "V-10") == #fail)
        checar ("V-10: mensagem fala de sentido oposto ('" + mensagemDe "V-10" + "')") ((findString (mensagemDe "V-10") "sentido oposto") != undefined)
        checar "V-08: as arestas da face trocada não contam como furo" ((rodarMalha InLab_V08_MalhaFechada #(b) "V-08") == #pass)
        limparCena()
        b = caixaMesh()
        meshop.flipNormals b #{1..12}
        update b
        checar "V-10: Box todo do avesso reprova" ((rodarMalha InLab_V10_Normais #(b) "V-10") == #fail)
        checar ("V-10: mensagem fala do avesso ('" + mensagemDe "V-10" + "')") ((findString (mensagemDe "V-10") "avesso") != undefined)
        limparCena()

        ---------------------------------------------------------------- INSTÂNCIAS
        b = caixaMesh()
        local bi = instance b
        bi.pos = [100, 0, 0]
        local grupos = InLab_Malha_AnalisarCena #(b, bi)
        checar ("Instâncias: 1 análise para 2 nós (" + grupos.count as string + ")") (grupos.count == 1 and grupos[1].instancias.count == 2)
        limparCena()

        -- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    try ( limparCena() ) catch ()
    units.SystemType = unidadeOriginal
    INLAB_LIMITES_PROVISORIOS = provOriginal
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
```

- [ ] **Step 2: Rodar e ver falhar**

Rodar como em "Como rodar um teste no Max". Esperado: `EXCEÇÃO: ... fileIn: can't open file ... verif_malha.ms` e `1 FALHA(S)`.

- [ ] **Step 3: Implementar o núcleo, V-08 e V-10**

Criar `verifications/verif_malha.ms`:

```maxscript
/*
================================================================================
 verifications\verif_malha.ms — Grupo 6 · V-07, V-08, V-09, V-10, V-13
--------------------------------------------------------------------------------
 Spec: docs\superpowers\specs\2026-10-05-verif-geometria-grupo6-design.md
 (issue #102). Só leitura: nada muda na cena.

 ANÁLISE POR PEÇA: InLab_Malha_Analisar tira UM snapshotAsMesh e preenche
 uma MalhaAnalise (furos, vizinhas invertidas, elementos do avesso, faces
 duplicadas); a V-13 lê o Editable Poly direto. InLab_Malha_AnalisarCena
 roda uma análise por grupo de instâncias (InLab_DeduplicarInstancias).

 05/10/2026 — decisões da sondagem (Max 2024):
   - SEM Dictionary em laço: como mapa de arestas levou 565 s numa malha de
     262 mil triângulos, e a chave inteira estourou. Duplicata e únicos saem
     de sort nativo sobre doubles (chave positiva, < 2^53).
   - No Mesh do Max, aresta cujas duas faces vizinhas têm o MESMO sentido já
     aparece em meshop.getOpenEdges. A V-10 separa essas (a gêmea dirigida
     a→b se repete entre as abertas) e a V-08 conta só o resto.
   - V-08 é advertência: fundo aberto e faces escondidas apagadas pelo passo
     3 da Otimização são furos legítimos (Puff Dorset: 88 por peça).
   - Volume com sinal só em elemento fechado (sem aresta aberta). Medido no
     snapshot (mundo): espelho muda o sinal, mas a V-12 já pega escala
     negativa.
================================================================================
*/

global INLAB_MALHA_TOL = "0.01mm"          -- tolerância de posição (units.decodeValue)
global INLAB_MALHA_PLANO_GRAUS = 1.0       -- V-13: ngon não plana
global INLAB_MALHA_CURVA_GRAUS = 15.0      -- V-13: vizinha suavizada em curva
global INLAB_MALHA_LOG_TRIS = 50000        -- loga o tempo das peças a partir disso

struct MalhaAnalise
(
    no,                     -- nó representante do grupo de instâncias
    instancias = #(),       -- todos os nós do grupo
    tris = 0,
    furos = 0,              -- V-08: arestas abertas que não são da V-10
    invertidas = 0,         -- V-10a: arestas abertas com gêmea no mesmo sentido
    avesso = 0,             -- V-10b: elementos fechados com volume negativo
    duplicadas = 0,         -- V-09a: faces coincidentes com outra
    ngonsNaoPlanas = 0,     -- V-13
    ngonsNaCurva = 0,       -- V-13
    ngonsAplica = false,    -- V-13: Editable_Poly com stack vazio
    erro = undefined        -- texto da exceção, se a análise falhou
)

-- "a, b, c" com no máximo `maximo` itens e "… (+N)" no fim.
fn InLab_Malha_Lista itens maximo:8 =
(
    local txt = ""
    for i = 1 to (amin itens.count maximo) do txt += (if i > 1 then "; " else "") + itens[i]
    if itens.count > maximo do txt += "; … (+" + (itens.count - maximo) as string + ")"
    txt
)

-- Vértices dirigidos da aresta `e` do Mesh: a aresta k (1..3) da face f
-- vai do canto k ao canto k+1 (mod 3); e = 3*(f-1) + k.
fn InLab_Malha_VertsDaAresta m e =
(
    local f = (e - 1) / 3 + 1
    local k = (e - 1) - (f - 1) * 3 + 1
    local v = getFace m f
    local vs = #(v.x as integer, v.y as integer, v.z as integer)
    #(vs[k], vs[(if k == 3 then 1 else k + 1)])
)

-- V-10a: quantas arestas abertas têm uma gêmea aberta no MESMO sentido
-- (vizinhas com sentido oposto). Só olha as abertas, que são poucas.
fn InLab_Malha_ArestasInvertidas m abertas =
(
    local base = (m.numverts + 1) as double
    local chaves = for e in abertas collect (local ab = InLab_Malha_VertsDaAresta m e; (ab[1] as double) * base + (ab[2] as double))
    sort chaves
    local n = 0
    for i = 1 to chaves.count do
        if (i > 1 and chaves[i] == chaves[i - 1]) or (i < chaves.count and chaves[i] == chaves[i + 1]) do n += 1
    n
)

-- V-10b: elementos FECHADOS (nenhuma aresta aberta) com volume negativo.
fn InLab_Malha_ElementosDoAvesso m abertas =
(
    local restantes = #{1..m.numfaces}
    local avesso = 0
    while not restantes.isEmpty do
    (
        local f0 = 0
        for f in restantes while f0 == 0 do f0 = f
        local elem = meshop.getElementsUsingFace m #{f0}
        restantes -= elem
        if ((meshop.getEdgesUsingFace m elem) * abertas).isEmpty do
        (
            local vol = 0.0
            for f in elem do
            (
                local v = getFace m f
                vol += dot (getVert m v.x) (cross (getVert m v.y) (getVert m v.z))
            )
            if vol < -1e-6 do avesso += 1
        )
    )
    avesso
)

-- Análise de UMA peça. tol: tolerância de posição em unidades da cena.
fn InLab_Malha_Analisar o tol:undefined =
(
    if tol == undefined do tol = units.decodeValue INLAB_MALHA_TOL
    local a = MalhaAnalise no:o instancias:(InLab_InstanciasDoNo o)
    local m = snapshotAsMesh o
    try
    (
        a.tris = m.numfaces
        if a.tris > 0 do
        (
            local abertas = meshop.getOpenEdges m
            a.invertidas = InLab_Malha_ArestasInvertidas m abertas
            a.furos = abertas.numberSet - a.invertidas
            a.avesso = InLab_Malha_ElementosDoAvesso m abertas
        )
    )
    catch
    (
        a.erro = getCurrentException()
        InLab_Log (o.name + ": falha na análise de malha (" + a.erro + ").") tipo:#err
    )
    delete m
    a
)

-- Uma análise por grupo de instâncias; loga o tempo das peças grandes.
fn InLab_Malha_AnalisarCena objs =
(
    local tol = units.decodeValue INLAB_MALHA_TOL
    for g in (InLab_DeduplicarInstancias objs) collect
    (
        local t0 = timeStamp()
        local a = InLab_Malha_Analisar g.no tol:tol
        a.instancias = g.instancias
        if a.tris >= INLAB_MALHA_LOG_TRIS do
            InLab_Log (g.no.name + ": malha analisada (" + a.tris as string + " triângulos) em " + ((timeStamp() - t0) / 1000.0) as string + " s.") tipo:#info
        a
    )
)

-- Nome para o relatório: o representante e quantas instâncias vêm junto.
fn InLab_Malha_Nome a =
(
    a.no.name + (if a.instancias.count > 1 then (" (+" + (a.instancias.count - 1) as string + " instância(s))") else "")
)

-- V-08 · Malha fechada. Advertência: furo pode ser legítimo.
fn InLab_V08_MalhaFechada analises =
(
    local itens = #()
    for a in analises do
    (
        if a.erro != undefined do append itens ((InLab_Malha_Nome a) + ": não analisado (" + a.erro + ")")
        if a.furos > 0 do append itens ((InLab_Malha_Nome a) + ": " + a.furos as string + " aresta(s) aberta(s)")
    )
    InLab_RegistrarVerif "V-08" "Malha fechada (arestas abertas)" (itens.count == 0) \
        (if itens.count == 0 then "nenhuma aresta aberta" else ("confira se o furo é de propósito (fundo aberto, faces escondidas): " + InLab_Malha_Lista itens)) critico:false
)

-- V-10 · Normais invertidas: vizinhas com sentido oposto ou peça do avesso.
fn InLab_V10_Normais analises =
(
    local itens = #()
    for a in analises do
    (
        if a.invertidas > 0 do append itens ((InLab_Malha_Nome a) + ": " + (a.invertidas / 2) as string + " aresta(s) entre faces de sentido oposto")
        if a.avesso > 0 do append itens ((InLab_Malha_Nome a) + ": " + a.avesso as string + " parte(s) do avesso (normais para dentro)")
    )
    InLab_RegistrarVerif "V-10" "Normais invertidas" (itens.count == 0) \
        (if itens.count == 0 then "normais consistentes" else InLab_Malha_Lista itens) critico:true
)
```

No `InLabChecker.ms`, logo depois de `@"verifications\verif_geometria.ms",`:

```maxscript
            -- grupo 6 de geometria (issue #102): usa fn_export_gltf e fn_json
            @"verifications\verif_malha.ms",
```

- [ ] **Step 4: Rodar e ver passar**

Esperado: todos `PASS`, `TUDO OK`. Se "V-08: mensagem tem o objeto e a contagem" falhar porque o Box com uma face apagada tem outra contagem de arestas abertas, ler a contagem real no log e corrigir **o teste** só se a contagem for a de um furo triangular (3 arestas); qualquer outra contagem é bug na análise.

- [ ] **Step 5: Commit**

```bash
git add verifications/verif_malha.ms tests/test_verif_malha.ms InLabChecker.ms
git commit -m "feat(verif): V-08 e V-10 com analise de malha por peca (#102)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: V-09 · faces e objetos duplicados

**Files:**
- Modify: `verifications/verif_malha.ms` (nova função antes de `InLab_Malha_Analisar`; uma linha dentro dela; `InLab_V09_Duplicados` no fim)
- Modify: `tests/test_verif_malha.ms` (antes de `-- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI`)

**Interfaces:**
- Consumes: `MalhaAnalise`, `InLab_Malha_AnalisarCena`, `InLab_Malha_Nome`, `InLab_Malha_Lista` (Task 1).
- Produces: `InLab_Malha_FacesDuplicadas m tol` → integer; `InLab_V09_Duplicados analises objetos`.

- [ ] **Step 1: Escrever os casos (vermelho)**

Inserir antes de `-- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI`:

```maxscript
        ---------------------------------------------------------------- V-09
        fn rodar09 objs = ( InLab_ResetarResultados(); InLab_V09_Duplicados (InLab_Malha_AnalisarCena objs) objs; statusDe "V-09" )
        b = caixaMesh()
        checar "V-09: Box sem duplicata passa" ((rodar09 #(b)) == #pass)
        meshop.cloneFaces b #{1}
        update b
        checar "V-09: face clonada no lugar reprova" ((rodar09 #(b)) == #fail)
        checar ("V-09: mensagem cita faces coincidentes ('" + mensagemDe "V-09" + "')") ((findString (mensagemDe "V-09") "coincidente") != undefined)
        limparCena()
        b = caixaMesh()
        local b2 = copy b
        checar "V-09: dois Box iguais no mesmo lugar reprovam" ((rodar09 #(b, b2)) == #fail)
        checar ("V-09: mensagem cita os dois objetos ('" + mensagemDe "V-09" + "')") ((findString (mensagemDe "V-09") b2.name) != undefined)
        b2.pos = [100, 0, 0]
        checar "V-09: o mesmo Box em outro lugar passa" ((rodar09 #(b, b2)) == #pass)
        limparCena()
        -- Review Focus: membro de grupo fechado não é acusado contra a cabeça
        local gA = caixaMesh()
        local gB = caixaMesh()
        gB.pos = [100, 0, 0]
        local grp = group #(gA, gB) name:"Produto"
        checar "V-09: membros de grupo fechado, sem duplicata, passam" ((rodar09 #(gA, gB)) == #pass)
        limparCena()
```

- [ ] **Step 2: Rodar e ver falhar**

Esperado: `EXCEÇÃO: ... InLab_V09_Duplicados` (undefined) e `1 FALHA(S)`.

- [ ] **Step 3: Implementar**

Em `verifications/verif_malha.ms`, antes de `-- Análise de UMA peça.`:

```maxscript
-- V-09a: faces cujos 3 cantos coincidem (na tolerância) com os de outra face
-- do mesmo objeto, em qualquer ordem — no mesmo sentido ou costas com costas.
-- Centro quantizado por eixo; sort nativo de (qx − qxMin)·(nf+1) + f
-- (double, positiva); só as faces com o mesmo qx são comparadas entre si.
fn InLab_Malha_FacesDuplicadas m tol =
(
    local nf = m.numfaces
    if nf < 2 then 0
    else
    (
        local q = for f = 1 to nf collect
        (
            local c = meshop.getFaceCenter m f
            #(floor ((c.x as double) / tol + 0.5), floor ((c.y as double) / tol + 0.5), floor ((c.z as double) / tol + 0.5))
        )
        local qxMin = q[1][1]
        for f = 2 to nf where q[f][1] < qxMin do qxMin = q[f][1]
        local base = (nf + 1) as double
        local chaves = for f = 1 to nf collect ((q[f][1] - qxMin) * base + f)
        sort chaves
        -- cantos quantizados e ordenados, como texto (só para as faces de um grupo)
        fn cantos m f tol =
        (
            local v = getFace m f
            local ps = for i in #(v.x, v.y, v.z) collect (local p = getVert m i; (floor (p.x / tol + 0.5)) as string + "," + (floor (p.y / tol + 0.5)) as string + "," + (floor (p.z / tol + 0.5)) as string)
            sort ps
            ps[1] + "|" + ps[2] + "|" + ps[3]
        )
        local dup = #{}
        local i = 1
        while i <= nf do
        (
            local qi = floor (chaves[i] / base)
            local j = i
            while j < nf and (floor (chaves[j + 1] / base)) == qi do j += 1
            if j > i do
            (
                local fs = for k = i to j collect ((chaves[k] - qi * base) as integer)
                for x = 1 to fs.count do
                    for y = x + 1 to fs.count do
                    (
                        local fa = fs[x]; local fb = fs[y]
                        if q[fa][2] == q[fb][2] and q[fa][3] == q[fb][3] and (cantos m fa tol) == (cantos m fb tol) do ( dup[fa] = true; dup[fb] = true )
                    )
            )
            i = j + 1
        )
        dup.numberSet
    )
)
```

Dentro de `InLab_Malha_Analisar`, depois de `a.avesso = InLab_Malha_ElementosDoAvesso m abertas`:

```maxscript
            a.duplicadas = InLab_Malha_FacesDuplicadas m tol
```

No fim do arquivo:

```maxscript
-- V-09 · Duplicatas: faces coincidentes no objeto, ou objeto inteiro em cima
-- de outro (mesma contagem de triângulos e mesmo bbox de mundo). Instância no
-- mesmo lugar também conta.
fn InLab_V09_Duplicados analises objetos =
(
    local itens = for a in analises where a.duplicadas > 0 collect ((InLab_Malha_Nome a) + ": " + a.duplicadas as string + " face(s) coincidente(s)")
    local tol = units.decodeValue INLAB_MALHA_TOL
    local tris = for o in objetos collect (GetTriMeshFaceCount o)[1]
    for i = 1 to objetos.count do
        for j = i + 1 to objetos.count do
        (
            local p = objetos[i]; local q = objetos[j]
            if tris[i] > 0 and tris[i] == tris[j] and (distance p.min q.min) <= tol and (distance p.max q.max) <= tol do
                append itens (p.name + " e " + q.name + ": objeto duplicado no mesmo lugar")
        )
    InLab_RegistrarVerif "V-09" "Faces e objetos duplicados" (itens.count == 0) \
        (if itens.count == 0 then "nenhuma duplicata" else InLab_Malha_Lista itens) critico:true
)
```

- [ ] **Step 4: Rodar e ver passar**

Esperado: `TUDO OK`. Se `meshop.cloneFaces` não deixar a face no lugar (cópia deslocada), conferir com `meshop.getFaceCenter` no log antes de mexer no código.

- [ ] **Step 5: Commit**

```bash
git add verifications/verif_malha.ms tests/test_verif_malha.ms
git commit -m "feat(verif): V-09 faces e objetos duplicados (#102)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: V-13 · ngons em superfície curva

**Files:**
- Modify: `verifications/verif_malha.ms` (função nova antes de `InLab_Malha_Analisar`; uma linha no fim dela; `InLab_V13_Ngons` no fim)
- Modify: `tests/test_verif_malha.ms`

**Interfaces:**
- Consumes: `MalhaAnalise`, `InLab_Malha_AnalisarCena`, `InLab_Malha_Nome`, `InLab_Malha_Lista`.
- Produces: `InLab_Malha_Ngons o a` (preenche `a.ngonsAplica`, `a.ngonsNaoPlanas`, `a.ngonsNaCurva`); `InLab_V13_Ngons analises`.

- [ ] **Step 1: Escrever os casos (vermelho)**

Inserir antes de `-- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI`:

```maxscript
        ---------------------------------------------------------------- V-13
        fn cilindroPoly = ( local c = Cylinder radius:20 height:40 sides:6 heightsegs:1 capsegs:1 smooth:true; convertToPoly c; c )
        fn tampa p = ( local t = 0; for f = 1 to (polyop.getNumFaces p) where t == 0 and (polyop.getFaceDeg p f) == 6 do t = f; t )
        local c = cilindroPoly()
        checar ("V-13: cilindro poly (tampa ngon plana) passa ('" + (rodarMalha InLab_V13_Ngons #(c) "V-13") as string + "')") ((rodarMalha InLab_V13_Ngons #(c) "V-13") == #pass)
        local ft = tampa c
        polyop.moveVert c (polyop.getFaceVerts c ft)[1] [0, 0, 5]
        checar "V-13: tampa ngon não plana reprova" ((rodarMalha InLab_V13_Ngons #(c) "V-13") == #fail)
        checar ("V-13: mensagem diz não plana ('" + mensagemDe "V-13" + "')") ((findString (mensagemDe "V-13") "não plana") != undefined)
        limparCena()
        c = cilindroPoly()
        ft = tampa c
        local lado = 0
        for f = 1 to (polyop.getNumFaces c) where lado == 0 and (polyop.getFaceDeg c f) == 4 do lado = f
        polyop.setFaceSmoothGroup c #{ft} (polyop.getFaceSmoothGroup c lado)
        checar "V-13: tampa suavizada junto com o lado (90°) reprova" ((rodarMalha InLab_V13_Ngons #(c) "V-13") == #fail)
        checar ("V-13: mensagem diz suavizada ('" + mensagemDe "V-13" + "')") ((findString (mensagemDe "V-13") "suavizada") != undefined)
        limparCena()
        b = caixaMesh()
        checar "V-13: Editable Mesh passa como não se aplica" ((rodarMalha InLab_V13_Ngons #(b) "V-13") == #pass and (findString (mensagemDe "V-13") "não se aplica") != undefined)
        limparCena()
```

- [ ] **Step 2: Rodar e ver falhar**

Esperado: `EXCEÇÃO: ... InLab_V13_Ngons` (undefined) e `1 FALHA(S)`.

- [ ] **Step 3: Implementar**

Antes de `-- Análise de UMA peça.`:

```maxscript
-- V-13: ngons (5+ lados) do Editable Poly de stack vazio. Não plana = maior
-- distância de um vértice ao plano da face ÷ maior distância ao centro >
-- tan 1°. Suavizada na curva = divide smoothing group com uma vizinha a mais
-- de 15°. Tampa de cilindro (plana, smoothing próprio) passa.
fn InLab_Malha_Ngons o a =
(
    if classof o.baseobject == Editable_Poly and o.modifiers.count == 0 do
    (
        a.ngonsAplica = true
        local tanPlano = tan INLAB_MALHA_PLANO_GRAUS
        local cosCurva = cos INLAB_MALHA_CURVA_GRAUS
        for f = 1 to (polyop.getNumFaces o) where (polyop.getFaceDeg o f) > 4 do
        (
            local n = polyop.getFaceNormal o f
            local c = polyop.getFaceCenter o f
            local desvio = 0.0; local raio = 0.0
            for v in (polyop.getFaceVerts o f) do
            (
                local p = polyop.getVert o v
                desvio = amax desvio (abs (dot (p - c) n))
                raio = amax raio (distance p c)
            )
            if raio > 0 and desvio / raio > tanPlano then a.ngonsNaoPlanas += 1
            else
            (
                local sg = polyop.getFaceSmoothGroup o f
                local naCurva = false
                if sg != 0 do
                    for g in (polyop.getFacesUsingEdge o (polyop.getEdgesUsingFace o #{f})) do
                        if not naCurva and g != f and (bit.and sg (polyop.getFaceSmoothGroup o g)) != 0 and (dot n (polyop.getFaceNormal o g)) < cosCurva do
                            naCurva = true
                if naCurva do a.ngonsNaCurva += 1
            )
        )
    )
    a
)
```

Em `InLab_Malha_Analisar`, logo depois de `delete m`:

```maxscript
    try ( InLab_Malha_Ngons o a ) catch
    (
        a.erro = getCurrentException()
        InLab_Log (o.name + ": falha na leitura das ngons (" + a.erro + ").") tipo:#err
    )
```

No fim do arquivo:

```maxscript
-- V-13 · Ngons em superfície curva (só Editable Poly de stack vazio).
fn InLab_V13_Ngons analises =
(
    local itens = #()
    for a in analises do
    (
        if a.ngonsNaoPlanas > 0 do append itens ((InLab_Malha_Nome a) + ": " + a.ngonsNaoPlanas as string + " ngon(s) não plana(s)")
        if a.ngonsNaCurva > 0 do append itens ((InLab_Malha_Nome a) + ": " + a.ngonsNaCurva as string + " ngon(s) suavizada(s) numa curva")
    )
    local semPoly = for a in analises where not a.ngonsAplica collect a.no.name
    local msg = if itens.count > 0 then InLab_Malha_Lista itens \
        else if semPoly.count == analises.count then "não se aplica: nenhum objeto em Editable Poly com stack vazio" \
        else ("nenhuma ngon em superfície curva" + (if semPoly.count > 0 then (" · não se aplica a " + InLab_Malha_Lista semPoly) else ""))
    InLab_RegistrarVerif "V-13" "Ngons em superfície curva" (itens.count == 0) msg critico:true
)
```

- [ ] **Step 4: Rodar e ver passar**

Esperado: `TUDO OK`. Se o cilindro "passa" falhar como suavizada: o Cylinder do Max põe a tampa em smoothing group próprio; conferir `polyop.getFaceSmoothGroup` da tampa e do lado no log antes de mudar a regra (a regra está na spec 3.4).

- [ ] **Step 5: Commit**

```bash
git add verifications/verif_malha.ms tests/test_verif_malha.ms
git commit -m "feat(verif): V-13 ngons nao planas ou suavizadas em curva (#102)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: V-07 · ratio do GLB pelo exportador

**Files:**
- Modify: `verifications/verif_malha.ms` (fim do arquivo)
- Modify: `tests/test_verif_malha.ms`

**Interfaces:**
- Consumes: `InLab_ResolverExportadorGLTF()` → classe ou `undefined` (functions/fn_export_gltf.ms); `InLab_ParseJSON txt`, `InLab_JSON_LerArquivoUTF8 caminho`, `InLab_JSON_Obter obj chave` (functions/fn_json.ms; índices do glTF são 0-based, arrays MaxScript 1-based); `cfg.maxRatioVT` (FamiliaConfig).
- Produces: `InLab_GLTF_VerticesPorNo exportador:` → `#(#ok, nomes, verts, tris)` ou `#(#naoMedido, motivo)`; `InLab_V07_RatioVT cfg objetos exportador:`.

- [ ] **Step 1: Escrever os casos (vermelho)**

Inserir antes de `-- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI`:

```maxscript
        ---------------------------------------------------------------- V-07
        local cfgCU = InLab_ObterFamilia "corpo_unico"
        INLAB_LIMITES_PROVISORIOS = true
        fn rodar07 cfg objs = ( InLab_ResetarResultados(); InLab_V07_RatioVT cfg objs; statusDe "V-07" )
        local esf = Sphere radius:20 segs:32 smooth:true mapcoords:true name:"Esfera_suave"
        checar ("V-07: esfera suavizada passa ('" + (rodar07 cfgCU #(esf)) as string + "': " + mensagemDe "V-07" + ")") ((rodar07 cfgCU #(esf)) == #pass)
        esf.smooth = false
        checar "V-07: esfera sem smoothing passa do limite (advertência, provisório)" ((rodar07 cfgCU #(esf)) == #warning)
        checar ("V-07: mensagem tem o objeto e o ratio ('" + mensagemDe "V-07" + "')") ((findString (mensagemDe "V-07") "Esfera_suave: 3.00") != undefined)
        INLAB_LIMITES_PROVISORIOS = false
        checar "V-07: com limites valendo, reprova" ((rodar07 cfgCU #(esf)) == #fail)
        INLAB_LIMITES_PROVISORIOS = true
        InLab_ResetarResultados()
        InLab_V07_RatioVT cfgCU #(esf) exportador:undefined
        checar "V-07: sem exportador vira 'não medido' (advertência)" (statusDe "V-07" == #warning and (findString (mensagemDe "V-07") "não medido") != undefined)
        checar "V-07: a pasta temporária foi apagada" ((getFiles ((getDir #temp) + "\\inlab_v07\\*")).count == 0)
        limparCena()
        -- Review Focus: nome repetido soma no mesmo item; oculto fica de fora sem "não medido"
        local r1 = Sphere radius:10 segs:16 smooth:true mapcoords:true name:"Repetido"
        local r2 = Sphere radius:10 segs:16 smooth:true mapcoords:true name:"Repetido" pos:[50, 0, 0]
        local oc = Sphere radius:10 segs:16 smooth:true mapcoords:true name:"Oculto" pos:[100, 0, 0]
        hide oc
        checar ("V-07: nome repetido e objeto oculto não quebram ('" + (rodar07 cfgCU #(r1, r2, oc)) as string + "': " + mensagemDe "V-07" + ")") ((rodar07 cfgCU #(r1, r2, oc)) == #pass)
        limparCena()
```

- [ ] **Step 2: Rodar e ver falhar**

Esperado: `EXCEÇÃO: ... InLab_V07_RatioVT` (undefined) e `1 FALHA(S)`.

- [ ] **Step 3: Implementar**

No fim de `verifications/verif_malha.ms`:

```maxscript
-- V-07 · vértices e triângulos por nó como o GLB tem: exporta a cena inteira
-- para um .gltf temporário e lê os accessors. Na sondagem de 05/10/2026 o
-- exportador ignorou selectedOnly:true, e estimar pela malha errou de −44% a
-- +10% (normais editadas, smoothing groups que dividem bits). Exportar levou
-- 0,3–0,6 s. Devolve #(#ok, nomes, verts, tris) ou #(#naoMedido, motivo).
-- exportador: só para teste (undefined = simula "nenhum exportador").
fn InLab_GLTF_VerticesPorNo exportador:unsupplied =
(
    local cls = if exportador == unsupplied then InLab_ResolverExportadorGLTF() else exportador
    if cls == undefined then #(#naoMedido, "nenhum exportador glTF instalado")
    else
    (
        local pasta = (getDir #temp) + "\\inlab_v07\\"
        makeDir pasta all:true
        local arq = pasta + "cena.gltf"
        local res = undefined
        try
        (
            local ok = exportFile arq #noPrompt selectedOnly:false using:cls
            if ok != true or not (doesFileExist arq) then res = #(#naoMedido, "o export glTF não gerou arquivo")
            else
            (
                local js = InLab_ParseJSON (InLab_JSON_LerArquivoUTF8 arq)
                local acc = InLab_JSON_Obter js "accessors"
                local meshes = InLab_JSON_Obter js "meshes"
                local nomes = #(); local verts = #(); local tris = #()
                for n in (InLab_JSON_Obter js "nodes") do
                (
                    local mi = InLab_JSON_Obter n "mesh"
                    if mi != undefined do
                    (
                        local v = 0; local t = 0
                        for p in (InLab_JSON_Obter meshes[mi + 1] "primitives") do
                        (
                            local nv = InLab_JSON_Obter acc[(InLab_JSON_Obter (InLab_JSON_Obter p "attributes") "POSITION") + 1] "count"
                            local ii = InLab_JSON_Obter p "indices"
                            v += nv
                            t += (if ii == undefined then nv else (InLab_JSON_Obter acc[ii + 1] "count")) / 3
                        )
                        local nome = (InLab_JSON_Obter n "name") as string
                        local k = findItem nomes nome
                        if k == 0 then ( append nomes nome; append verts v; append tris t )
                        else ( verts[k] += v; tris[k] += t )
                    )
                )
                res = #(#ok, nomes, verts, tris)
            )
        )
        catch ( res = #(#naoMedido, "falha no export ou na leitura do glTF: " + getCurrentException()) )
        for f in (getFiles (pasta + "*")) do deleteFile f
        res
    )
)

-- V-07 · Ratio vértices/triângulos do GLB, por objeto, contra cfg.maxRatioVT.
fn InLab_V07_RatioVT cfg objetos exportador:unsupplied =
(
    local titulo = "Ratio vértices/triângulos (GLB)"
    local r = InLab_GLTF_VerticesPorNo exportador:exportador
    if r[1] != #ok then
    (
        InLab_Log ("V-07 não medida: " + r[2]) tipo:#warn
        InLab_RegistrarVerif "V-07" titulo false ("não medido: " + r[2]) critico:false
    )
    else
    (
        local nomesObj = for o in objetos collect o.name
        local acima = #(); local maior = 0.0; local medidos = 0
        for i = 1 to r[2].count where (findItem nomesObj r[2][i]) > 0 and r[4][i] > 0 do
        (
            medidos += 1
            local ratio = r[3][i] as float / r[4][i]
            if ratio > maior do maior = ratio
            if ratio > cfg.maxRatioVT do
                append acima (r[2][i] + ": " + (formattedPrint ratio format:".2f") + " (" + r[3][i] as string + " v / " + r[4][i] as string + " t)")
        )
        if medidos == 0 then
            InLab_RegistrarVerif "V-07" titulo false "não medido: nenhum objeto da cena saiu no glTF" critico:false
        else
            InLab_RegistrarVerif "V-07" titulo (acima.count == 0) \
                ((if acima.count == 0 then ("maior " + (formattedPrint maior format:".2f")) else InLab_Malha_Lista acima) + " · limite " + cfg.maxRatioVT as string) \
                critico:true provisorio:true
    )
)
```

- [ ] **Step 4: Rodar e ver passar**

Esperado: `TUDO OK`. A esfera sem smoothing exporta 2879 vértices / 960 triângulos (sondagem): a mensagem traz `Esfera_suave: 3.00`. Se o exportador gravar o nome do nó com outro texto (ex.: sufixo), ler `nodes[].name` do `.gltf` antes de apagar (comentar o `deleteFile` só durante a investigação) e ajustar a ligação nome → objeto.

- [ ] **Step 5: Commit**

```bash
git add verifications/verif_malha.ms tests/test_verif_malha.ms
git commit -m "feat(verif): V-07 ratio de vertices do GLB pelo exportador (#102)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Ligar no orquestrador, desempenho, piloto e suíte

**Files:**
- Modify: `verifications/verif_orquestrador.ms` (cabeçalho de status; bloco do grupo 6 depois de `InLab_VEx01_Ocultos objetos`; aviso dos grupos)
- Modify: `verifications/verif_geometria.ms` (cabeçalho)
- Modify: `core/struct_result.ms` (lista de não críticas no cabeçalho)
- Modify: `tests/test_verificacoes.ms`, `tests/test_familia_ativa.ms`, `tests/test_posicao_painel.ms` (lista de módulos)
- Modify: `tests/test_verif_malha.ms` (caso de desempenho)

**Interfaces:**
- Consumes: `InLab_V07_RatioVT cfg objetos`, `InLab_Malha_AnalisarCena objs`, `InLab_V08_MalhaFechada analises`, `InLab_V09_Duplicados analises objetos`, `InLab_V10_Normais analises`, `InLab_V13_Ngons analises`.
- Produces: rodada completa do motor com V-07, V-08, V-09, V-10 e V-13.

- [ ] **Step 1: Escrever o caso de desempenho e o da rodada completa (vermelho)**

Em `tests/test_verif_malha.ms`, antes de `-- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI`:

```maxscript
        ---------------------------------------------------------------- DESEMPENHO
        local bule = Teapot segs:64          -- 262 mil triângulos
        local t0 = timeStamp()
        local ab = InLab_Malha_AnalisarCena #(bule)
        local seg = (timeStamp() - t0) / 1000.0
        linha ("      tempo da análise do Teapot " + ab[1].tris as string + " tris: " + seg as string + " s")
        checar ("Desempenho: Teapot de 262 mil triângulos abaixo de 30 s (" + seg as string + " s)") (ab[1].tris == 262144 and seg < 30.0)
        limparCena()
```

Em `tests/test_verificacoes.ms`, na lista de `fileIn`, trocar

```maxscript
                   @"functions\fn_json.ms", @"functions\fn_renomear_produto.ms",
```

por

```maxscript
                   @"functions\fn_json.ms", @"functions\fn_renomear_produto.ms", @"functions\fn_export_gltf.ms",
```

e

```maxscript
                   @"verifications\verif_animacao.ms", @"report\report_generator.ms",
```

por

```maxscript
                   @"verifications\verif_animacao.ms", @"verifications\verif_malha.ms", @"report\report_generator.ms",
```

e, na seção `RODADA COMPLETA`, depois do `checar ("Rodada '" ...`:

```maxscript
            checar ("Rodada '" + cfg.nome + "': grupo 6 presente (V-07, V-08, V-09, V-10, V-13)") \
                ((for idV in #("V-07", "V-08", "V-09", "V-10", "V-13") where (statusDe idV) == #ausente collect idV).count == 0)
```

Fazer o mesmo acréscimo de `@"functions\fn_export_gltf.ms"` e `@"verifications\verif_malha.ms"` nas listas de `tests/test_familia_ativa.ms` e `tests/test_posicao_painel.ms` (achar com `grep -n "verif_animacao.ms\|fn_json.ms" tests/test_familia_ativa.ms tests/test_posicao_painel.ms`; `fn_export_gltf.ms` depois de `fn_json.ms`, `verif_malha.ms` depois de `verif_animacao.ms`).

- [ ] **Step 2: Rodar e ver falhar**

`test_verificacoes.ms`: esperado `FAIL  Rodada '...': grupo 6 presente` (o motor ainda não chama). `test_verif_malha.ms`: o desempenho pode já passar — anotar o tempo medido.

- [ ] **Step 3: Ligar no orquestrador e atualizar cabeçalhos**

Em `verifications/verif_orquestrador.ms`, trocar

```maxscript
        InLab_VEx01_Ocultos objetos

        -- ===== Grupos 4–7 · próximas entregas =====
        InLab_Log "Grupos 4–7 (animação avançada, UV, geometria pesada, materiais) ainda não implementados — relatório parcial." tipo:#warn
```

por

```maxscript
        InLab_VEx01_Ocultos objetos

        -- ===== Grupo 6 · Pesadas (issue #102, verif_malha.ms) =====
        InLab_V07_RatioVT cfg objetos
        local analises = InLab_Malha_AnalisarCena objetos
        InLab_V08_MalhaFechada analises
        InLab_V09_Duplicados analises objetos
        InLab_V10_Normais analises
        InLab_V13_Ngons analises

        -- ===== Grupos 4, 5 e 7 · próximas entregas =====
        InLab_Log "Grupos 4, 5 e 7 (animação avançada, UV, materiais) ainda não implementados — relatório parcial." tipo:#warn
```

No cabeçalho do mesmo arquivo, trocar

```
   Grupo 6 (pesadas)        → V-07, V-08/09/10/13                [próxima entrega]
```

por

```
   Grupo 6 (pesadas)        → V-07, V-08/09/10/13                [ENTREGUE 05/10/2026 — verif_malha.ms, issue #102]
```

Em `verifications/verif_geometria.ms`, trocar a 1ª linha do cabeçalho e o parágrafo seguinte:

```
 verifications\verif_geometria.ms — V-11/12 · [V-07/08/09/10/13: Grupo 6]
--------------------------------------------------------------------------------
 Nesta entrega: stack de modificadores (V-11) e transform resetado (V-12).
 As verificações pesadas de malha (watertight, faces duplicadas, normais,
 ngons, ratio v/t) entram no Grupo 6.
```

por

```
 verifications\verif_geometria.ms — V-11/12 e EX-01
--------------------------------------------------------------------------------
 Stack de modificadores (V-11) e transform resetado (V-12). As verificações
 pesadas de malha (V-07, V-08, V-09, V-10, V-13) ficam em verif_malha.ms
 (05/10/2026, issue #102).
```

Em `core/struct_result.ms`, trocar

```
   V-05 (famílias sem regra numérica), V-06,
```

por

```
   V-05 (famílias sem regra numérica), V-06, V-08 (arestas abertas),
```

- [ ] **Step 4: Rodar a suíte inteira e o piloto**

Rodar os 24 arquivos de `tests/` (os 23 de antes e `test_verif_malha.ms`), com o mesmo laço usado nas validações anteriores (um `resetMaxFile #noPrompt` + `fileIn` por arquivo, contando `PASS`/`FAIL`; `test_renomear_produto.ms` grava em `inlab_test_renomear.txt`). Esperado: 0 FAIL em todos. Se passar de 120 s, a chamada vai para segundo plano: esperar a notificação.

Depois, conferir o piloto (só leitura, sem salvar), numa chamada:

```maxscript
(
fileIn @"G:\Meu Drive\GitHub\InLabChecker\InLabChecker.ms"
local out = ""
for a in #(@"APARADOR ZUCCHI - 147 X 042 X 072.5 H.max", @"PUFF DORSET - 046 X 046 X 045 H.max") do
(
    loadMaxFile (@"G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\PILOTO PLUGIN INLAB\ARTEFACTO\" + a) quiet:true useFileUnits:true
    InLab_ResetarResultados()
    local objs = InLab_ObjetosVerificacao()
    local t0 = timeStamp()
    InLab_V07_RatioVT (InLab_ObterFamilia "corpo_unico") objs
    local an = InLab_Malha_AnalisarCena objs
    InLab_V08_MalhaFechada an; InLab_V09_Duplicados an objs; InLab_V10_Normais an; InLab_V13_Ngons an
    out += "\n## " + a + " (" + ((timeStamp() - t0) / 1000.0) as string + " s)"
    for r in InLab_VerifResults do out += "\n  " + r.id + " " + r.status as string + " · " + r.mensagem
)
resetMaxFile #noPrompt
out
)
```

Esperado: V-09, V-10 e V-13 em `#pass` nos dois; V-08 `#warning` só no Puff (as duas bases com 88); V-07 com os números da sondagem (Puff: `Box244448652` e `Box244448651` a 1,59, advertência). Qualquer `#fail` de V-09/V-10/V-13 aqui é falso positivo: parar e investigar antes do commit.

- [ ] **Step 5: Commit, push e PR**

```bash
git add verifications/verif_orquestrador.ms verifications/verif_geometria.ms core/struct_result.ms tests/test_verif_malha.ms tests/test_verificacoes.ms tests/test_familia_ativa.ms tests/test_posicao_painel.ms
git commit -m "feat(verif): grupo 6 de geometria no motor de verificacao (#102)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push -u origin feat/verif-geometria-grupo6
```

Abrir o PR para `main` com `gh pr create`: título `feat(verif): grupo 6 de geometria - V-07, V-08, V-09, V-10, V-13`; corpo com o que cada verificação mede, a severidade, os números da sondagem (export 0,3–0,6 s; estimativa errava −44% a +10%), o tempo do Teapot medido no Step 4, o resultado do piloto e da suíte, "Resolve #102", e no fim a linha `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
