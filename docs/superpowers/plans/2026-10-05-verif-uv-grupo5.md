# Grupo 5 · Verificações de UV — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ligar ao motor de verificação a V-14 (UV no canal 1), V-15 (UV de bake no canal 3 sem sobreposição e dentro do 0–1) e V-16 (resolução das texturas ≥ 2048), com teste no Max.

**Architecture:**
- Arquivo novo `verifications/verif_mapeamento.ms`.
- **V-14** lê o canal 1 do `snapshotAsMesh`.
- **V-15** confere o canal 3 no snapshot **antes** de qualquer coisa. Só nas peças que têm o canal mede a sobreposição, com um `Unwrap_UVW` temporário (`selectOverlappedFaces`), sempre removido. O redesenho fica suspenso durante a medição, e a seleção e o painel do usuário voltam como estavam.
- **V-16** reaproveita `InLab_CheckTexture` (com `logar:false`).
- O orquestrador chama as três num bloco "Grupo 5".

**Tech Stack:** MaxScript (3ds Max 2024; alvo também 2027), MCP do 3ds Max para rodar os testes.

**Spec:** `docs/superpowers/specs/2026-10-05-verif-uv-grupo5-design.md`

## Global Constraints

- Tudo em português: código, comentários, log e mensagens. Funções públicas `InLab_`, constantes `INLAB_MAIUSCULO`.
- Severidade: V-14 `critico:true`; V-15 `critico:true`; V-16 `critico:false`. "Não medido" = `passou:false critico:false` (vira `#warning`).
- V-15: peça **sem** canal 3 nunca recebe o Unwrap (falso positivo sondado: o Unwrap acusa sobreposição num canal inexistente). Contagem do Unwrap = **faces** (no Editable Poly são polígonos), nunca "triângulos" na mensagem.
- V-15: o Unwrap é removido **sempre**, inclusive depois de exceção. Seleção e modo do painel restaurados. `disableSceneRedraw`/`suspendEditing` desfeitos mesmo com exceção. Grupos abertos são fechados de novo.
- Resolução mínima 2048 px no menor lado (`INLAB_TEXTURA_MIN_PX = 2048`). UV fora do 0–1 no canal 3 com tolerância `1e-4`. UV colapsado no canal 1 = bbox dos vértices de mapa com largura ou altura ≤ `1e-6`.
- Mensagens: no máximo 8 itens e depois "(+N)".
- Nunca `units.decodeValue "<decimal>mm"` (dá 0 em Max pt-BR; ver CLAUDE.md). Nenhum `Dictionary` em laço por face ou vértice.
- Cabeçalho `/* === ... === */` com caminho, o que faz e decisões datadas (05/10/2026).
- Commits em português, sem acento no assunto, `feat(verif): ...`, terminando com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Nada é dado como pronto sem rodar no Max (MCP).

## Review Focus

- **Peça sem faces** (malha vazia): V-14 diz "sem UV no canal 1"; V-15 diz "não se aplica"; nada de erro de índice. Testado na Task 1 e na Task 2.
- **Seleção vazia e painel Modify com outro objeto** antes de verificar: depois da V-15, a seleção continua vazia e o painel volta ao modo de antes. Testado na Task 2.
- **Material Multi/Sub-Object com bitmaps nos sub-materiais**: a V-16 enxerga as texturas dos sub-materiais. Testado na Task 3.
- **Mesma textura usada por duas peças**: a V-16 lista a textura uma vez. Testado na Task 3.
- **Peça com canal 3 e com modificador no stack** (o Unwrap entra no topo): mede e o modificador original fica intacto. Testado na Task 2.

---

## Como rodar um teste no Max (vale para todas as tasks)

Pelo MCP (`execute_maxscript`), numa chamada só:

```maxscript
(
resetMaxFile #noPrompt
local arq = (getDir #temp) + "\\inlab_test_verif_mapeamento.txt"
try (fileIn @"G:\Meu Drive\GitHub\InLabChecker\tests\test_verif_mapeamento.ms") catch ()
local out = ""; local p = 0
local fs = openFile arq mode:"rt"
while not eof fs do (local l = readLine fs; if matchPattern l pattern:"PASS*" then p += 1 else if matchPattern l pattern:"FAIL*" or matchPattern l pattern:"EXCE*" or matchPattern l pattern:"*FALHA*" or matchPattern l pattern:"TUDO*" do out += "\n" + l)
close fs
"PASS: " + p as string + out
)
```

"Passou" = nenhuma linha `FAIL`/`EXCEÇÃO` e a última linha `TUDO OK`. O MCP roda em safe_mode: código enviado direto não pode chamar `createFile`/`copyFile`/`deleteFile`, mas arquivo carregado por `fileIn` pode.

---

### Task 1: Esqueleto do arquivo, V-14 e teste

**Files:**
- Create: `verifications/verif_mapeamento.ms`
- Create: `tests/test_verif_mapeamento.ms`
- Modify: `InLabChecker.ms` (manifesto, logo depois de `@"verifications\verif_uv.ms",`)

**Interfaces:**
- Consumes:
  - `InLab_Log msg tipo:` (core/log.ms);
  - `InLab_RegistrarVerif id nome passou msg critico: provisorio:` (core/struct_result.ms);
  - `InLab_DeduplicarInstancias objs` → array de `InLab_GrupoInstancias (no, instancias)` (core/utils.ms);
  - `InLab_UV_TemCanal m canal` → bool (verifications/verif_uv.ms).
- Produces:
  - `INLAB_TEXTURA_MIN_PX = 2048`, `INLAB_UV_FORA_TOL = 1e-4`;
  - `InLab_Mapa_Lista itens maximo:8` → string;
  - `InLab_V14_UVPresente objetos`.

- [ ] **Step 1: Escrever o teste (vermelho)**

Criar `tests/test_verif_mapeamento.ms`:

```maxscript
/*
 tests\test_verif_mapeamento.ms — teste do grupo 5 de verificações (issue #101)
 Spec: docs\superpowers\specs\2026-10-05-verif-uv-grupo5-design.md
 RODAR NUMA CENA VAZIA (File > New): cria e apaga os objetos de cada caso.
 Resultado: <pasta temp do Max>\inlab_test_verif_mapeamento.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_VerifResults, InLab_ResetarResultados
global InLab_V14_UVPresente, InLab_V15_UVBake, InLab_V16_ResolucaoTexturas, InLab_CheckTexture
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_verif_mapeamento.txt"
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
    fn rodar f objs idV = ( InLab_ResetarResultados(); f objs; statusDe idV )
    fn caixa p = ( local b = Box length:10 width:10 height:10 mapcoords:true pos:p; convertToMesh b; b )
    -- Copia o canal `de` para o canal `para` (cria o canal se faltar).
    fn copiarCanal o de para =
    (
        if (meshop.getNumMaps o) <= para do meshop.setNumMaps o (para + 1) keep:true
        meshop.setMapSupport o para true
        local nv = meshop.getNumMapVerts o de
        meshop.setNumMapVerts o para nv
        for v = 1 to nv do meshop.setMapVert o para v (meshop.getMapVert o de v)
        for f = 1 to (getNumFaces o) do meshop.setMapFace o para f (meshop.getMapFace o de f)
        update o
    )

    local logOriginal = InLab_Log
    local unidadeOriginal = units.SystemType

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms",
                   @"verifications\verif_uv.ms", @"functions\fn_autouv.ms", @"functions\fn_checktexture.ms",
                   @"verifications\verif_mapeamento.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        units.SystemType = #Centimeters
        limparCena()

        ---------------------------------------------------------------- V-14
        local b = caixa [0, 0, 0]
        checar "V-14: Box com UV no canal 1 passa" ((rodar InLab_V14_UVPresente #(b) "V-14") == #pass)
        meshop.setMapSupport b 1 false
        update b
        checar "V-14: sem canal 1 reprova" ((rodar InLab_V14_UVPresente #(b) "V-14") == #fail)
        checar ("V-14: mensagem diz 'sem UV no canal 1' ('" + mensagemDe "V-14" + "')") ((findString (mensagemDe "V-14") (b.name + ": sem UV no canal 1")) != undefined)
        limparCena()
        b = caixa [0, 0, 0]
        for v = 1 to (meshop.getNumMapVerts b 1) do meshop.setMapVert b 1 v [0.5, 0.5, 0]
        update b
        checar "V-14: UV colapsado num ponto reprova" ((rodar InLab_V14_UVPresente #(b) "V-14") == #fail)
        checar ("V-14: mensagem diz 'colapsado' ('" + mensagemDe "V-14" + "')") ((findString (mensagemDe "V-14") "colapsado") != undefined)
        limparCena()
        b = caixa [0, 0, 0]
        for v = 1 to (meshop.getNumMapVerts b 1) do meshop.setMapVert b 1 v ((meshop.getMapVert b 1 v) * 37.0)
        update b
        checar "V-14: UV em escala real (fora do 0–1) passa" ((rodar InLab_V14_UVPresente #(b) "V-14") == #pass)
        limparCena()
        local vazio = mesh numverts:0 numfaces:0
        checar "V-14: malha vazia reprova sem erro (sem UV)" ((rodar InLab_V14_UVPresente #(vazio) "V-14") == #fail)
        limparCena()
        b = caixa [0, 0, 0]
        local bi = instance b
        bi.pos = [30, 0, 0]
        meshop.setMapSupport b 1 false
        update b
        InLab_ResetarResultados()
        InLab_V14_UVPresente #(b, bi)
        checar ("V-14: instâncias contam uma vez ('" + mensagemDe "V-14" + "')") ((findString (mensagemDe "V-14") bi.name) == undefined)
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
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
```

- [ ] **Step 2: Rodar e ver falhar**

Rodar como em "Como rodar um teste no Max". Esperado: `EXCEÇÃO: ... fileIn: can't open file ... verif_mapeamento.ms` e `1 FALHA(S)`.

- [ ] **Step 3: Implementar**

Criar `verifications/verif_mapeamento.ms`:

```maxscript
/*
================================================================================
 verifications\verif_mapeamento.ms — Grupo 5 · V-14, V-15, V-16 (UV e texturas)
--------------------------------------------------------------------------------
 Spec: docs\superpowers\specs\2026-10-05-verif-uv-grupo5-design.md (issue #101).

 DOIS CANAIS (fn_autouv.ms): canal 1 = UV do material, em escala real (repete
 de propósito, sai do 0–1); canal 3 = UV 0–1 empacotado para bake e AO,
 opcional no v1 (decisão de 05/10/2026).
   V-14: canal 1 presente e não colapsado num ponto.
   V-15: só nas peças COM canal 3 — sem sobreposição e dentro do 0–1.
   V-16: texturas das peças com o menor lado ≥ 2048 px (advertência).

 05/10/2026 — sondagem (Max 2024):
   - Sobreposição pelo Unwrap_UVW temporário (selectOverlappedFaces): 1,3 s em
     262 mil triângulos, contra ~0,27 ms por triângulo em InLab_MedirUV.
   - Num canal INEXISTENTE o Unwrap monta um mapeamento padrão e acusa
     sobreposição (12 de 12 num Box): o canal 3 é conferido no snapshot ANTES.
   - No Editable Poly, getSelectedFaces conta POLÍGONOS: a mensagem diz "faces".
   - O Unwrap mexe na seleção e no painel (Create → Modify): os dois são
     restaurados. disableSceneRedraw + suspendEditing: 1 s → 0,37 s por peça,
     mesmo resultado. Mede em instância, membro de grupo fechado, peça oculta,
     congelada e com modificador; getSaveRequired não muda.
================================================================================
*/

global INLAB_TEXTURA_MIN_PX = 2048     -- V-16: menor lado mínimo
global INLAB_UV_FORA_TOL = 1e-4        -- V-15: tolerância do 0–1 no canal 3

-- "a; b; c" com no máximo `maximo` itens e "… (+N)" no fim.
fn InLab_Mapa_Lista itens maximo:8 =
(
    local txt = ""
    for i = 1 to (amin itens.count maximo) do txt += (if i > 1 then "; " else "") + itens[i]
    if itens.count > maximo do txt += "; … (+" + (itens.count - maximo) as string + ")"
    txt
)

-- V-14 · UV presente no canal 1 (uma vez por grupo de instâncias).
fn InLab_V14_UVPresente objetos =
(
    local titulo = "UV presente (canal 1)"
    local itens = #()
    local naoMedidos = #()
    local grupos = InLab_DeduplicarInstancias objetos
    for g in grupos do
    (
        local o = g.no
        local m = undefined
        try
        (
            m = snapshotAsMesh o
            if not (InLab_UV_TemCanal m 1) then append itens (o.name + ": sem UV no canal 1")
            else
            (
                local nv = meshop.getNumMapVerts m 1
                local uMin = 1e30
                local uMax = -1e30
                local vMin = 1e30
                local vMax = -1e30
                for v = 1 to nv do
                (
                    local p = meshop.getMapVert m 1 v
                    if p.x < uMin do uMin = p.x
                    if p.x > uMax do uMax = p.x
                    if p.y < vMin do vMin = p.y
                    if p.y > vMax do vMax = p.y
                )
                if nv == 0 or (uMax - uMin) <= 1e-6 or (vMax - vMin) <= 1e-6 do
                    append itens (o.name + ": UV colapsado num ponto (canal 1)")
            )
        )
        catch
        (
            append naoMedidos (o.name + ": não analisado (" + getCurrentException() + ")")
            InLab_Log (o.name + ": V-14 não leu o UV (" + getCurrentException() + ").") tipo:#err
        )
        if m != undefined do try ( delete m ) catch ()
    )
    if itens.count > 0 then
        InLab_RegistrarVerif "V-14" titulo false (InLab_Mapa_Lista (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-14" titulo false ("não medido: " + InLab_Mapa_Lista naoMedidos) critico:false
    else
        InLab_RegistrarVerif "V-14" titulo true ("UV no canal 1 em " + grupos.count as string + " peça(s)") critico:true
)
```

No `InLabChecker.ms`, logo depois de `@"verifications\verif_uv.ms",`:

```maxscript
            -- grupo 5 de UV (issue #101): usa verif_uv, fn_autouv e fn_checktexture
            @"verifications\verif_mapeamento.ms",
```

- [ ] **Step 4: Rodar e ver passar**

Esperado: todos `PASS`, `TUDO OK`. Se `meshop.setMapSupport b 1 false` não tirar o canal num Editable Mesh, confira com `meshop.getMapSupport b 1` num probe e use `meshop.freeMapChannel b 1` (registrar no cabeçalho qual funcionou).

- [ ] **Step 5: Commit**

```bash
git add verifications/verif_mapeamento.ms tests/test_verif_mapeamento.ms InLabChecker.ms
git commit -m "feat(verif): V-14 UV presente no canal 1 (#101)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: V-15 · UV de bake (canal 3)

**Files:**
- Modify: `verifications/verif_mapeamento.ms` (fim do arquivo)
- Modify: `tests/test_verif_mapeamento.ms` (antes de `-- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI`)

**Interfaces:**
- Consumes:
  - `InLab_Mapa_Lista`, `INLAB_UV_FORA_TOL` (Task 1);
  - `InLab_UV_TemCanal m canal`;
  - `InLab_DeduplicarInstancias objs`;
  - `InLab_AbrirGruposAcima o` → array de grupos abertos, e `InLab_FecharGrupos grupos` (functions/fn_autouv.ms).
- Produces:
  - `InLab_Mapa_ForaDe01 m canal` → integer;
  - `InLab_Mapa_SobrepostasUnwrap o falharTeste:false` → integer ou `undefined`;
  - `InLab_V15_UVBake objetos falharTeste:false`.

- [ ] **Step 1: Escrever os casos (vermelho)**

Inserir antes de `-- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI`:

```maxscript
        ---------------------------------------------------------------- V-15
        -- Sem canal 3: não se aplica, e o Unwrap não pode ser usado (falso positivo).
        b = caixa [0, 0, 0]
        checar "V-15: peça sem canal 3 passa como 'não se aplica'" ((rodar InLab_V15_UVBake #(b) "V-15") == #pass and (findString (mensagemDe "V-15") "não se aplica") != undefined)
        checar "V-15: nenhum modificador sobrou" (b.modifiers.count == 0)
        limparCena()
        -- Canal 3 limpo: cópia do canal 1 de um Plane (uma ilha).
        local pl = Plane length:10 width:10 lengthsegs:4 widthsegs:4 mapcoords:true
        convertToMesh pl
        copiarCanal pl 1 3
        checar ("V-15: canal 3 limpo passa ('" + (rodar InLab_V15_UVBake #(pl) "V-15") as string + "': " + mensagemDe "V-15" + ")") ((rodar InLab_V15_UVBake #(pl) "V-15") == #pass)
        limparCena()
        -- Canal 3 sobreposto: os 6 lados do Box no mesmo 0–1.
        b = caixa [0, 0, 0]
        copiarCanal b 1 3
        checar "V-15: canal 3 sobreposto reprova" ((rodar InLab_V15_UVBake #(b) "V-15") == #fail)
        checar ("V-15: mensagem diz 'sobreposta' ('" + mensagemDe "V-15" + "')") ((findString (mensagemDe "V-15") "face(s) sobreposta(s)") != undefined)
        checar "V-15: Unwrap removido" (b.modifiers.count == 0)
        limparCena()
        -- Fora do 0–1.
        pl = Plane length:10 width:10 lengthsegs:4 widthsegs:4 mapcoords:true
        convertToMesh pl
        copiarCanal pl 1 3
        meshop.setMapVert pl 3 1 [1.3, 0.5, 0]
        update pl
        checar "V-15: vértice fora do 0–1 reprova" ((rodar InLab_V15_UVBake #(pl) "V-15") == #fail and (findString (mensagemDe "V-15") "fora do 0–1") != undefined)
        limparCena()
        -- Membro de grupo fechado.
        local gA = caixa [0, 0, 0]
        local gB = caixa [30, 0, 0]
        copiarCanal gA 1 3
        local grp = group #(gA, gB) name:"Produto"
        checar "V-15: membro de grupo fechado é medido" ((rodar InLab_V15_UVBake #(gA, gB) "V-15") == #fail)
        checar "V-15: grupo fechado de novo e sem modificador" (not (isOpenGroupHead grp) and gA.modifiers.count == 0)
        limparCena()
        -- Instâncias: uma medição, sem sobra em nenhuma.
        b = caixa [0, 0, 0]
        copiarCanal b 1 3
        bi = instance b
        bi.pos = [30, 0, 0]
        InLab_ResetarResultados()
        InLab_V15_UVBake #(b, bi)
        checar ("V-15: instâncias medidas uma vez ('" + mensagemDe "V-15" + "')") ((findString (mensagemDe "V-15") bi.name) == undefined and b.modifiers.count == 0 and bi.modifiers.count == 0)
        limparCena()
        -- Seleção e painel do usuário voltam como estavam.
        local outro = caixa [60, 0, 0]
        b = caixa [0, 0, 0]
        copiarCanal b 1 3
        select outro
        setCommandPanelTaskMode #create
        InLab_ResetarResultados()
        InLab_V15_UVBake #(b)
        checar ("V-15: seleção restaurada (" + (for s in selection collect s.name) as string + ")") (selection.count == 1 and selection[1] == outro)
        checar ("V-15: painel restaurado (" + (getCommandPanelTaskMode()) as string + ")") ((getCommandPanelTaskMode()) == #create)
        clearSelection()
        InLab_ResetarResultados()
        InLab_V15_UVBake #(b)
        checar "V-15: seleção vazia continua vazia" (selection.count == 0)
        limparCena()
        -- Peça com modificador no stack.
        b = Box length:10 width:10 height:10 mapcoords:true
        convertToMesh b
        copiarCanal b 1 3
        addModifier b (Bend angle:20)
        checar "V-15: peça com Bend é medida e o Bend fica" ((rodar InLab_V15_UVBake #(b) "V-15") == #fail and b.modifiers.count == 1 and classof b.modifiers[1] == Bend)
        limparCena()
        -- Malha vazia: não se aplica, sem erro.
        local vz = mesh numverts:0 numfaces:0
        checar "V-15: malha vazia é 'não se aplica'" ((rodar InLab_V15_UVBake #(vz) "V-15") == #pass)
        limparCena()
        -- Exceção simulada no meio da medição.
        b = caixa [0, 0, 0]
        copiarCanal b 1 3
        InLab_ResetarResultados()
        InLab_V15_UVBake #(b) falharTeste:true
        checar ("V-15: exceção vira 'não medido' ('" + mensagemDe "V-15" + "')") (statusDe "V-15" == #warning and (findString (mensagemDe "V-15") "não medid") != undefined)
        checar "V-15: exceção não deixa modificador" (b.modifiers.count == 0)
        limparCena()
```

- [ ] **Step 2: Rodar e ver falhar**

Esperado: `EXCEÇÃO: ... InLab_V15_UVBake` (undefined) e `1 FALHA(S)`.

- [ ] **Step 3: Implementar**

No fim de `verifications/verif_mapeamento.ms`:

```maxscript
-- Vértices de mapa do canal fora do 0–1 (tolerância INLAB_UV_FORA_TOL).
fn InLab_Mapa_ForaDe01 m canal =
(
    local n = 0
    local lo = -INLAB_UV_FORA_TOL
    local hi = 1.0 + INLAB_UV_FORA_TOL
    for v = 1 to (meshop.getNumMapVerts m canal) do
    (
        local p = meshop.getMapVert m canal v
        if p.x < lo or p.x > hi or p.y < lo or p.y > hi do n += 1
    )
    n
)

-- Faces sobrepostas no canal 3 por um Unwrap_UVW temporário. Devolve o número
-- de faces (polígonos no Editable Poly) ou undefined se a medição falhou. O
-- Unwrap sai SEMPRE (try da remoção separado do try da medição). Quem chama
-- cuida de seleção, painel e redesenho. falharTeste: só para teste.
fn InLab_Mapa_SobrepostasUnwrap o falharTeste:false =
(
    local n = undefined
    local uw = Unwrap_UVW()
    local grupos = InLab_AbrirGruposAcima o
    try
    (
        with undo off
        (
            addModifier o uw
            if falharTeste do throw "falha simulada (teste)"
            select o
            max modify mode
            modPanel.setCurrentObject uw
            uw.setMapChannel 3
            uw.selectOverlappedFaces()
            n = (uw.getSelectedFaces()).numberSet
        )
    )
    catch
    (
        n = undefined
        InLab_Log (o.name + ": V-15 não mediu a sobreposição (" + getCurrentException() + ").") tipo:#warn
    )
    try
    (
        with undo off ( for m in o.modifiers where m == uw do deleteModifier o m )
    )
    catch
    (
        InLab_Log (o.name + ": não removi o Unwrap temporário da V-15 (" + getCurrentException() + ") — apague à mão.") tipo:#err
    )
    InLab_FecharGrupos grupos
    n
)

-- V-15 · UV de bake (canal 3): sem sobreposição e dentro do 0–1. Peça sem
-- canal 3 é "não se aplica" e nunca recebe o Unwrap.
fn InLab_V15_UVBake objetos falharTeste:false =
(
    local titulo = "UV de bake sem sobreposição (canal 3)"
    local itens = #()
    local naoMedidos = #()
    local semCanal = #()
    local comCanal = #()
    for g in (InLab_DeduplicarInstancias objetos) do
    (
        local o = g.no
        local m = undefined
        try
        (
            m = snapshotAsMesh o
            if (InLab_UV_TemCanal m 3) and m.numfaces > 0 then
            (
                append comCanal o
                local fora = InLab_Mapa_ForaDe01 m 3
                if fora > 0 do append itens (o.name + ": " + fora as string + " vértice(s) de UV fora do 0–1 no canal 3")
            )
            else append semCanal o.name
        )
        catch
        (
            append naoMedidos (o.name + ": não analisado (" + getCurrentException() + ")")
            InLab_Log (o.name + ": V-15 não leu o canal 3 (" + getCurrentException() + ").") tipo:#err
        )
        if m != undefined do try ( delete m ) catch ()
    )
    if comCanal.count > 0 do
    (
        local sel = for s in selection collect s
        local modo = getCommandPanelTaskMode()
        disableSceneRedraw()
        suspendEditing()
        try
        (
            for o in comCanal do
            (
                local n = InLab_Mapa_SobrepostasUnwrap o falharTeste:falharTeste
                if n == undefined then append naoMedidos (o.name + ": sobreposição não medida (ver log)")
                else if n > 0 do append itens (o.name + ": " + n as string + " face(s) sobreposta(s) no canal 3")
            )
        )
        catch ( InLab_Log ("V-15: " + getCurrentException()) tipo:#err )
        resumeEditing()
        enableSceneRedraw()
        clearSelection()
        local vivos = for s in sel where isValidNode s collect s
        if vivos.count > 0 do select vivos
        setCommandPanelTaskMode modo
    )
    if itens.count > 0 then
        InLab_RegistrarVerif "V-15" titulo false (InLab_Mapa_Lista (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-15" titulo false ("não medido: " + InLab_Mapa_Lista naoMedidos) critico:false
    else if comCanal.count == 0 then
        InLab_RegistrarVerif "V-15" titulo true "não se aplica: nenhuma peça com UV de bake (canal 3)" critico:true
    else
        InLab_RegistrarVerif "V-15" titulo true ("canal 3 sem sobreposição e dentro do 0–1 em " + comCanal.count as string + " peça(s)" + \
            (if semCanal.count > 0 then (" · não se aplica a " + semCanal.count as string + " peça(s) sem canal 3") else "")) critico:true
)
```

- [ ] **Step 4: Rodar e ver passar**

Esperado: `TUDO OK`. Se o caso "membro de grupo fechado" falhar porque a seleção restaurada abre o grupo, conferir no log em que ponto e ajustar só a restauração (a medição já foi sondada).

- [ ] **Step 5: Commit**

```bash
git add verifications/verif_mapeamento.ms tests/test_verif_mapeamento.ms
git commit -m "feat(verif): V-15 UV de bake sem sobreposicao no canal 3 (#101)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: V-16 · resolução das texturas

**Files:**
- Modify: `functions/fn_checktexture.ms` (parâmetro `logar:true` em `InLab_CheckTexture`)
- Modify: `verifications/verif_mapeamento.ms` (fim do arquivo)
- Modify: `tests/test_verif_mapeamento.ms`

**Interfaces:**
- Consumes: `InLab_CheckTexture escopo:#selecao objs: logar:` → array de `TexturaInfo (arquivo, existe, resolucao, formato, ehPNG, materiais, classes)`; `InLab_Mapa_Lista`; `INLAB_TEXTURA_MIN_PX`.
- Produces: `InLab_V16_ResolucaoTexturas objetos`.

- [ ] **Step 1: Escrever os casos (vermelho)**

Inserir antes de `-- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI`:

```maxscript
        ---------------------------------------------------------------- V-16
        fn salvarBitmap tam nome = ( local arq = (getDir #temp) + "\\" + nome; local bm = bitmap tam tam color:gray filename:arq; save bm; close bm; arq )
        local arq1k = salvarBitmap 1024 "inlab_v16_1024.jpg"
        local arq2k = salvarBitmap 2048 "inlab_v16_2048.jpg"
        b = caixa [0, 0, 0]
        checar "V-16: peça sem material passa ('nenhuma textura')" ((rodar InLab_V16_ResolucaoTexturas #(b) "V-16") == #pass and (findString (mensagemDe "V-16") "nenhuma textura") != undefined)
        b.material = standardMaterial diffuseMap:(Bitmaptexture filename:arq2k)
        checar ("V-16: textura 2048 passa ('" + mensagemDe "V-16" + "')") ((rodar InLab_V16_ResolucaoTexturas #(b) "V-16") == #pass)
        b.material = standardMaterial diffuseMap:(Bitmaptexture filename:arq1k)
        checar "V-16: textura 1024 vira advertência" ((rodar InLab_V16_ResolucaoTexturas #(b) "V-16") == #warning)
        checar ("V-16: mensagem tem '1024x1024' ('" + mensagemDe "V-16" + "')") ((findString (mensagemDe "V-16") "inlab_v16_1024.jpg: 1024x1024") != undefined)
        b.material = standardMaterial diffuseMap:(Bitmaptexture filename:((getDir #temp) + "\\inlab_v16_nao_existe.jpg"))
        checar ("V-16: arquivo inexistente vira 'não medida' ('" + mensagemDe "V-16" + "')") ((rodar InLab_V16_ResolucaoTexturas #(b) "V-16") == #warning and (findString (mensagemDe "V-16") "não medida") != undefined)
        -- Multi/Sub-Object com bitmap no sub-material; mesma textura em duas peças.
        local mm = Multimaterial numsubs:2
        mm.materialList[1] = standardMaterial diffuseMap:(Bitmaptexture filename:arq1k)
        mm.materialList[2] = standardMaterial ()
        b.material = mm
        local b2 = caixa [30, 0, 0]
        b2.material = standardMaterial diffuseMap:(Bitmaptexture filename:arq1k)
        InLab_ResetarResultados()
        InLab_V16_ResolucaoTexturas #(b, b2)
        local ocorr = 0
        local msg16 = mensagemDe "V-16"
        local pos = findString msg16 "inlab_v16_1024.jpg"
        while pos != undefined do ( ocorr += 1; msg16 = substring msg16 (pos + 1) -1; pos = findString msg16 "inlab_v16_1024.jpg" )
        checar ("V-16: Multi/Sub enxergado e textura repetida listada uma vez (" + ocorr as string + ")") (statusDe "V-16" == #warning and ocorr == 1)
        -- Ambiente: textura que nenhuma peça usa fica de fora.
        b.material = undefined
        b2.material = undefined
        environmentMap = Bitmaptexture filename:arq1k
        checar "V-16: textura só do ambiente fica de fora" ((rodar InLab_V16_ResolucaoTexturas #(b, b2) "V-16") == #pass)
        environmentMap = undefined
        limparCena()
```

- [ ] **Step 2: Rodar e ver falhar**

Esperado: `EXCEÇÃO: ... InLab_V16_ResolucaoTexturas` (undefined) e `1 FALHA(S)`.

- [ ] **Step 3: Implementar**

Em `functions/fn_checktexture.ms`:
- trocar `fn InLab_CheckTexture escopo:#cena objs:#() =` por `fn InLab_CheckTexture escopo:#cena objs:#() logar:true =`;
- pôr `if logar do` na frente de **cada** `InLab_Log` da função: o aviso "nenhum bitmap encontrado", o cabeçalho "Check Texture: N textura(s)", as linhas por textura e o "Resumo";
- acrescentar ao comentário da função: `--   logar:false → não loga o relatório (usado pela V-16); o retorno não muda.`;
- acrescentar ao cabeçalho do arquivo, com data: `05/10/2026 (issue #101): parâmetro logar: — a V-16 consome o inventário sem despejar o relatório no log da verificação.`

No fim de `verifications/verif_mapeamento.ms`:

```maxscript
-- V-16 · Resolução das texturas usadas pelas peças (advertência). Textura sem
-- arquivo ou com resolução ilegível é "não medida". O que só o ambiente usa
-- fica de fora (InLab_CheckTexture escopo:#selecao).
fn InLab_V16_ResolucaoTexturas objetos =
(
    local titulo = "Resolução das texturas (≥ " + INLAB_TEXTURA_MIN_PX as string + ")"
    local infos = InLab_CheckTexture escopo:#selecao objs:objetos logar:false
    if infos.count == 0 then
        InLab_RegistrarVerif "V-16" titulo true "nenhuma textura nas peças" critico:false
    else
    (
        local baixas = #()
        local naoMedidas = #()
        for t in infos do
        (
            local nome = filenameFromPath t.arquivo
            if not t.existe then append naoMedidas (nome + ": não medida (arquivo não encontrado)")
            else if t.resolucao == undefined then append naoMedidas (nome + ": não medida (resolução ilegível)")
            else if (amin t.resolucao.x t.resolucao.y) < INLAB_TEXTURA_MIN_PX do
                append baixas (nome + ": " + (t.resolucao.x as integer) as string + "x" + (t.resolucao.y as integer) as string)
        )
        local ok = baixas.count == 0 and naoMedidas.count == 0
        InLab_RegistrarVerif "V-16" titulo ok \
            (if ok then (infos.count as string + " textura(s) com " + INLAB_TEXTURA_MIN_PX as string + " px ou mais") else InLab_Mapa_Lista (baixas + naoMedidas)) critico:false
    )
)
```

- [ ] **Step 4: Rodar e ver passar**

Esperado: `TUDO OK`. Se o caso "Multi/Sub-Object" falhar por a textura do sub-material não aparecer (`InLab_MapaUsadoPor` usa `refs.dependents` do mapa), investigue com um probe e corrija em `InLab_MapaUsadoPor`, registrando no cabeçalho de `fn_checktexture.ms`. Também confirme, rodando `tests/test_verificacoes.ms` e qualquer teste que chame `InLab_CheckTexture`, que o padrão `logar:true` não mudou o comportamento atual.

- [ ] **Step 5: Commit**

```bash
git add functions/fn_checktexture.ms verifications/verif_mapeamento.ms tests/test_verif_mapeamento.ms
git commit -m "feat(verif): V-16 resolucao das texturas das pecas (#101)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Ligar no orquestrador, piloto e suíte

**Files:**
- Modify: `verifications/verif_orquestrador.ms` (cabeçalho de status; bloco do grupo 5 depois de `InLab_VEx01_Ocultos objetos`; aviso dos grupos)
- Modify: `core/struct_result.ms` (lista de não críticas no cabeçalho)
- Modify: `tests/test_verificacoes.ms`, `tests/test_familia_ativa.ms`, `tests/test_posicao_painel.ms` (lista de módulos; caso "grupo 5 presente")

**Interfaces:**
- Consumes: `InLab_V14_UVPresente objetos`, `InLab_V15_UVBake objetos`, `InLab_V16_ResolucaoTexturas objetos`.
- Produces: rodada completa do motor com V-14, V-15 e V-16.

- [ ] **Step 1: Escrever o caso da rodada completa (vermelho)**

Em `tests/test_verificacoes.ms`, na lista de `fileIn`, trocar

```maxscript
                   @"verifications\verif_animacao.ms", @"report\report_generator.ms",
```

por

```maxscript
                   @"verifications\verif_animacao.ms",
                   @"verifications\verif_uv.ms", @"functions\fn_autouv.ms", @"functions\fn_checktexture.ms",
                   @"verifications\verif_mapeamento.ms", @"report\report_generator.ms",
```

e, na seção `RODADA COMPLETA`, depois do `checar ("Rodada '" ...`:

```maxscript
            checar ("Rodada '" + cfg.nome + "': grupo 5 presente (V-14, V-15, V-16)") \
                ((for idV in #("V-14", "V-15", "V-16") where (statusDe idV) == #ausente collect idV).count == 0)
```

Fazer o mesmo acréscimo de módulos (`verif_uv.ms`, `fn_autouv.ms`, `fn_checktexture.ms`, `verif_mapeamento.ms`, nessa ordem, antes de `report\report_generator.ms` ou de `verif_orquestrador.ms`) nas listas de `tests/test_familia_ativa.ms` e `tests/test_posicao_painel.ms`. Achar com `grep -n "verif_animacao.ms" tests/test_familia_ativa.ms tests/test_posicao_painel.ms`, e pular o módulo que a lista já tiver.

- [ ] **Step 2: Rodar e ver falhar**

`test_verificacoes.ms`: esperado `FAIL  Rodada '...': grupo 5 presente`.

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

        -- ===== Grupo 5 · UV (issue #101, verif_mapeamento.ms) =====
        InLab_V14_UVPresente objetos
        InLab_V15_UVBake objetos
        InLab_V16_ResolucaoTexturas objetos

        -- ===== Grupos 4, 6 e 7 · próximas entregas =====
        InLab_Log "Grupos 4, 6 e 7 (animação avançada, geometria pesada, materiais) ainda não implementados — relatório parcial." tipo:#warn
```

Se `main` já tiver o grupo 6 (PR #107), o bloco do grupo 5 entra **antes** do bloco "Grupo 6 · Pesadas", e o aviso fica "Grupos 4 e 7 (animação avançada, materiais)".

No cabeçalho do mesmo arquivo, trocar

```
   Grupo 5 (UV)             → V-14/15/16, V-29/V-39              [próxima entrega]
```

por

```
   Grupo 5 (UV)             → V-14/15/16                          [ENTREGUE 05/10/2026 — verif_mapeamento.ms, issue #101; V-29/V-39 ficam para o v2]
```

Em `core/struct_result.ms`, no cabeçalho, acrescentar a V-16 à lista de não críticas, ao lado da V-02, com a nota `(V-16 acrescentada em 05/10/2026, issue #101)`.

- [ ] **Step 4: Rodar a suíte inteira e o piloto**

Rodar todos os arquivos de `tests/` com o laço já usado nas validações anteriores:
- um `resetMaxFile #noPrompt` e um `fileIn` por arquivo, contando `PASS` e `FAIL` em `(getDir #temp) + "\\inlab_test_<nome>.txt"`;
- `test_renomear_produto.ms` grava em `inlab_test_renomear.txt`;
- marcar "NAO ATUALIZADO" se a data do arquivo de saída não mudar.

Esperado: 0 FAIL em todos.

Depois, o piloto (só leitura, sem salvar), numa chamada:

```maxscript
(
fileIn @"G:\Meu Drive\GitHub\InLabChecker\InLabChecker.ms"
local out = ""
for a in #(@"APARADOR ZUCCHI - 147 X 042 X 072.5 H.max", @"PUFF DORSET - 046 X 046 X 045 H.max", @"POLTRONA MENTHA - 080 X 080 X 072 H.max", @"MESA LATERAL NAMBU - 055 X 040 X 055 H.max") do
(
    loadMaxFile (@"G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\PILOTO PLUGIN INLAB\ARTEFACTO\" + a) quiet:true useFileUnits:true
    InLab_ResetarResultados()
    local objs = InLab_ObjetosVerificacao()
    local t0 = timeStamp()
    InLab_V14_UVPresente objs; InLab_V15_UVBake objs; InLab_V16_ResolucaoTexturas objs
    out += "\n## " + a + " (" + ((timeStamp() - t0) / 1000.0) as string + " s)"
    for r in InLab_VerifResults do out += "\n  " + r.id + " " + r.status as string + " · " + r.mensagem
)
resetMaxFile #noPrompt
out
)
```

Esperado:
- **V-14:** `#fail` só no Puff (`Box244448649`, `Box244448650` e `Shape009`: "sem UV no canal 1"); `#pass` nos outros três;
- **V-15:** `#pass` "não se aplica" nos quatro (nenhum tem canal 3);
- **V-16:** `#warning` com texturas "não medida (arquivo não encontrado)", porque as texturas do piloto não estão neste computador.

Qualquer `#fail` da V-15 aqui é falso positivo: parar e investigar antes do commit.

- [ ] **Step 5: Commit (sem push nem PR)**

```bash
git add verifications/verif_orquestrador.ms core/struct_result.ms tests/test_verificacoes.ms tests/test_familia_ativa.ms tests/test_posicao_painel.ms
git commit -m "feat(verif): grupo 5 de UV no motor de verificacao (#101)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

O push e o PR saem depois da revisão final da branch.
