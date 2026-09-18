# Renomear pelo JSON de Produto — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Na seção Produto, ligar cada parte do JSON a um material da cena e aplicar os nomes oficiais em materiais, mapas e objetos.

**Architecture:** Toda a lógica fica em `functions/fn_renomear_produto.ms`, sem UI, testada por um script MAXScript que grava PASS/FAIL num arquivo texto. `ui/rollout_main.ms` só guarda o estado da tela (produto escolhido, materiais lidos, ligações) e chama o módulo.

**Tech Stack:** MAXScript (3ds Max 2024+), parser JSON de `functions/fn_json.ms` (árvore nativa: objeto = array de pares `#(chave, valor)`, lido com `InLab_JSON_Obter`).

**Spec:** `docs/superpowers/specs/2026-09-18-renomear-produto-design.md`

## Global Constraints

- O código só roda dentro do 3ds Max. Quem executa o teste é o usuário (Scripting > Run Script...); o teste grava o resultado em `<getDir #temp>\inlab_test_renomear.txt`, que o agente lê. Nunca afirmar que algo funciona sem esse arquivo.
- Toda fn chamada de fora do próprio arquivo leva `global <Nome>` ANTES da definição (o arquivo pode ser carregado de dentro de `InLab_RecarregarPlugin()`, escopo aninhado). Fn recursiva também (um nome não declarado dentro de fn vira local `undefined`).
- Log só via `InLab_Log msg tipo:#info|#ok|#warn|#err`.
- Nada no disco é alterado; só `.name` de materiais, texmaps e nós.
- Comentários e mensagens em português, no estilo dos arquivos existentes.
- Commits só com autorização explícita do usuário.

## File Structure

| Arquivo | Ação | Responsabilidade |
|---|---|---|
| `functions/fn_renomear_produto.ms` | criar | dados do export, materiais/mapas da cena, sugestão, aplicar, reverter |
| `tests/test_renomear_produto.ms` | criar | teste automático do módulo, rodado numa cena vazia |
| `InLabChecker.ms:59` | modificar | incluir o módulo no manifesto, após `fn_json.ms` |
| `ui/rollout_main.ms:32-79` | modificar | seção Produto: lista de produtos, ligação, aplicar/desfazer |

---

### Task 1: Módulo `fn_renomear_produto.ms` + teste automático

**Files:**
- Create: `functions/fn_renomear_produto.ms`
- Create: `tests/test_renomear_produto.ms`
- Modify: `InLabChecker.ms:57-59`

**Interfaces:**
- Consumes: `InLab_JSON_Obter objetoComoPares chave`, `InLab_ParseJSON texto` (fn_json.ms); `InLab_Log`.
- Produces (todas `global`):
  - `InLab_Produto_Lista dados` → Array de produtos (`#()` se não houver `produtos`)
  - `InLab_Produto_IndicePorCodigo produtos cod` → Integer (0 = não achou)
  - `InLab_Produto_Texto obj chave` → String (`""` se ausente)
  - `InLab_Produto_Rotulo parte` → `"Encosto (Externo)"` / `"Tampo"`
  - `InLab_Produto_Normalizar s` → minúsculo, sem acento
  - `InLab_Produto_Canal nomeSlot` → só `[A-Za-z0-9]`; `"Mapa"` se vazio
  - `InLab_Produto_MateriaisDaSelecao objs` → Array de materiais únicos (submateriais de Multimaterial, nunca o Multimaterial)
  - `InLab_Produto_SugerirLigacoes partes mtls` → Array paralelo a `partes` (material ou `undefined`)
  - `InLab_Produto_Aplicar produto ligacoes objs` → `true`/`false` (false = conflito, nada renomeado)
  - `InLab_Produto_Reverter()` → restaura os nomes da última aplicação
  - `InLab_UltimaRenomeacao` → Array de `#(alvo, nomeAntigo)`

- [ ] **Step 1: Escrever o teste** — `tests/test_renomear_produto.ms`:

```maxscript
/*
 tests\test_renomear_produto.ms — teste automático de functions\fn_renomear_produto.ms
 RODAR NUMA CENA VAZIA (File > New): cria 4 caixas + materiais de teste e
 apaga as caixas no final. Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_renomear.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_ParseJSON, InLab_JSON_Obter, InLab_Log
global InLab_Produto_Lista, InLab_Produto_IndicePorCodigo, InLab_Produto_Texto
global InLab_Produto_Rotulo, InLab_Produto_Normalizar, InLab_Produto_Canal
global InLab_Produto_MateriaisDaSelecao, InLab_Produto_SugerirLigacoes
global InLab_Produto_Aplicar, InLab_Produto_Reverter
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_renomear.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    local criados = #()

    try
    (
        fileIn (raiz + @"functions\fn_json.ms")
        fileIn (raiz + @"functions\fn_renomear_produto.ms")

        -- 1. DADOS DO JSON
        local js = "{\"versao_export\": \"nomenclatura-3D-v2\", \"produtos\": [{\"cod_est\": \"0001\", \"nome\": \"TESTE\", \"partes\": [" +
            "{\"nome_parte\": \"Tampo\", \"qualificador\": \"\", \"tipo\": \"P\", \"material_id\": \"ART_P_Tampo\", \"mesh_final\": \"0001\"}, " +
            "{\"nome_parte\": \"Encosto\", \"qualificador\": \"Externo\", \"tipo\": \"T\", \"material_id\": \"ART_T_Encosto_Externo\", \"mesh_final\": \"0001\"}, " +
            "{\"nome_parte\": \"Encosto\", \"qualificador\": \"Interno\", \"tipo\": \"T\", \"material_id\": \"ART_T_Encosto_Interno\", \"mesh_final\": \"0001\"}, " +
            "{\"nome_parte\": \"Gavetas\", \"qualificador\": \"\", \"tipo\": \"\", \"material_id\": \"ART_Gavetas\", \"mesh_final\": \"ART_C_Gavetas\"}]}]}"
        local produtos = InLab_Produto_Lista (InLab_ParseJSON js)
        checar "Lista: 1 produto" (produtos.count == 1)
        checar "Lista vazia p/ JSON sem 'produtos'" ((InLab_Produto_Lista (InLab_ParseJSON "{\"linhas\": []}")).count == 0)
        checar "IndicePorCodigo acha 0001" ((InLab_Produto_IndicePorCodigo produtos "0001") == 1)
        checar "IndicePorCodigo devolve 0 se não existe" ((InLab_Produto_IndicePorCodigo produtos "9999") == 0)
        local partes = InLab_JSON_Obter produtos[1] "partes"
        checar "Rotulo com qualificador" ((InLab_Produto_Rotulo partes[2]) == "Encosto (Externo)")
        checar "Rotulo sem qualificador" ((InLab_Produto_Rotulo partes[1]) == "Tampo")
        checar "Texto de chave ausente = \"\"" ((InLab_Produto_Texto partes[1] "nao_existe") == "")
        checar "Normalizar tira acento e caixa" ((InLab_Produto_Normalizar "Pistão ÇÉ") == "pistao ce")
        checar "Canal tira espaço e símbolo" ((InLab_Produto_Canal "Diffuse Color") == "DiffuseColor")
        checar "Canal vazio vira Mapa" ((InLab_Produto_Canal " #") == "Mapa")

        -- 2. CENA DE TESTE
        local bmpDif = Bitmaptexture name:"dif_qualquer"
        local bmpNorm = Bitmaptexture name:"norm_qualquer"
        local nb = Normal_Bump name:"nb_qualquer" normal_map:bmpNorm
        local mTampo = StandardMaterial name:"tampo_madeira" diffuseMap:bmpDif bumpMap:nb
        local mExt = StandardMaterial name:"Encosto Externo couro"
        local mInt = StandardMaterial name:"encosto_interno"
        local mGav = StandardMaterial name:"Material #99"
        local multiEnc = Multimaterial numsubs:2 name:"multi_encosto"
        multiEnc.materialList[1] = mExt
        multiEnc.materialList[2] = mInt
        local multiMisto = Multimaterial numsubs:2 name:"multi_misto"
        multiMisto.materialList[1] = mTampo
        multiMisto.materialList[2] = mGav
        local b1 = Box name:"obj_tampo" material:mTampo
        local b2 = Box name:"obj_encosto" material:multiEnc pos:[40,0,0]
        local b3 = Box name:"obj_gaveta" material:mGav pos:[80,0,0]
        local b4 = Box name:"obj_misto" material:multiMisto pos:[120,0,0]
        criados = #(b1, b2, b3, b4)

        local mtls = InLab_Produto_MateriaisDaSelecao criados
        checar "MateriaisDaSelecao: 4 únicos, sem o Multimaterial" (mtls.count == 4 and (findItem mtls mTampo) > 0 and (findItem mtls mExt) > 0 and (findItem mtls mInt) > 0 and (findItem mtls mGav) > 0)

        -- 3. SUGESTÃO
        local lig = InLab_Produto_SugerirLigacoes partes mtls
        checar "Sugestão Tampo → tampo_madeira" (lig[1] == mTampo)
        checar "Sugestão Encosto (Externo) → Encosto Externo couro" (lig[2] == mExt)
        checar "Sugestão Encosto (Interno) → encosto_interno" (lig[3] == mInt)
        checar "Sugestão Gavetas → nenhuma" (lig[4] == undefined)

        -- 4. CONFLITO: mesmo material em duas partes bloqueia tudo
        local todos = #(mTampo, mExt, mInt, mGav)
        local nomesAntes = (for m in todos collect m.name) as string
        checar "Conflito: Aplicar devolve false" ((InLab_Produto_Aplicar produtos[1] #(mTampo, mExt, mInt, mTampo) criados) == false)
        checar "Conflito: nenhum material renomeado" ((for m in todos collect m.name) as string == nomesAntes)
        checar "Conflito: nenhum objeto renomeado" (b1.name == "obj_tampo")

        -- 5. APLICAR
        lig[4] = mGav
        checar "Aplicar devolve true" ((InLab_Produto_Aplicar produtos[1] lig criados) == true)
        checar "Material Tampo" (mTampo.name == "ART_P_Tampo")
        checar "Material Encosto Externo" (mExt.name == "ART_T_Encosto_Externo")
        checar "Material Encosto Interno" (mInt.name == "ART_T_Encosto_Interno")
        checar "Material Gavetas (tipo vazio, nome provisório)" (mGav.name == "ART_Gavetas")
        local canalDif = ""
        local canalBump = ""
        for i = 1 to (getNumSubTexmaps mTampo) do
        (
            local t = getSubTexmap mTampo i
            if t == bmpDif do canalDif = InLab_Produto_Canal (getSubTexmapSlotName mTampo i)
            if t == nb do canalBump = InLab_Produto_Canal (getSubTexmapSlotName mTampo i)
        )
        linha ("      canais lidos: difuso='" + canalDif + "' bump='" + canalBump + "'")
        checar "Mapa difuso = material_id_canal" (bmpDif.name == "ART_P_Tampo_" + canalDif)
        checar "Mapa bump (Normal_Bump)" (nb.name == "ART_P_Tampo_" + canalBump)
        checar "Mapa dentro do Normal_Bump ganha _2" (bmpNorm.name == "ART_P_Tampo_" + canalBump + "_2")
        checar "Objeto tampo → 0001" (b1.name == "0001")
        checar "Objeto encosto (multi) → 0001" (b2.name == "0001")
        checar "Objeto gaveta → ART_C_Gavetas" (b3.name == "ART_C_Gavetas")
        checar "Objeto misto (2 meshes) NÃO renomeado" (b4.name == "obj_misto")

        -- 6. REVERTER
        InLab_Produto_Reverter()
        checar "Reverter: material" (mTampo.name == "tampo_madeira" and mGav.name == "Material #99")
        checar "Reverter: mapas" (bmpDif.name == "dif_qualquer" and bmpNorm.name == "norm_qualquer")
        checar "Reverter: objetos" (b1.name == "obj_tampo" and b3.name == "obj_gaveta")
        -- Ctrl+Z nativo NÃO é testável daqui: rodado de dentro do script,
        -- `max undo` desfaz o script inteiro (inclusive a criação das caixas),
        -- não só a renomeação — confirmado em 18/Set. Conferir à mão pela UI.
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    for o in criados where isValidNode o do delete o
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
```

- [ ] **Step 2: (sem rodada "vermelha")** — cada execução depende do usuário no Max; o teste só é rodado depois da implementação (Step 4). Sem o módulo, o `fileIn` falharia e o arquivo registraria `EXCEÇÃO`.

- [ ] **Step 3: Implementar** — `functions/fn_renomear_produto.ms`:

```maxscript
/*
================================================================================
 functions\fn_renomear_produto.ms — renomeação pelo JSON de produto (18/Set)
--------------------------------------------------------------------------------
 Aplica os nomes oficiais do export de nomenclatura da plataforma
 (versao_export "nomenclatura-3D-v2") no produto aberto no Max:
   material ligado a cada parte → material_id          (ex.: ART_P_Base)
   mapas dentro desse material  → material_id_<canal>  (ex.: ART_P_Base_Bump)
   objeto                       → mesh_final das partes que ele usa
 A LIGAÇÃO parte → material é decidida pelo modelador na seção Produto
 (ui\rollout_main.ms); InLab_Produto_SugerirLigacoes só pré-preenche por
 semelhança de nome. Este arquivo não tem UI.
 Spec: docs\superpowers\specs\2026-09-18-renomear-produto-design.md

 UNDO: Aplicar roda dentro de `undo on` E guarda os nomes antigos em
 InLab_UltimaRenomeacao, restaurados por InLab_Produto_Reverter — mesmo
 padrão de InLab_ReverterOtimizacao / InLab_ReverterConversao (o undo nativo
 pode não cobrir .name de material/texmap alterado por script).

 `global` antes de cada fn usada fora daqui (ou recursiva): este arquivo
 pode ser carregado de dentro de InLab_RecarregarPlugin() — ver fn_json.ms.
================================================================================
*/

global InLab_UltimaRenomeacao = #() -- pares #(alvo, nomeAntigo) da última aplicação

--------------------------------------------------------------------------------
-- DADOS DO JSON
--------------------------------------------------------------------------------

-- Valor de texto de um campo, "" se ausente/null (o export usa "" e null).
global InLab_Produto_Texto
fn InLab_Produto_Texto obj chave =
(
    local v = InLab_JSON_Obter obj chave
    if v == undefined then "" else (v as string)
)

-- Produtos do export. #() se o JSON não tiver "produtos" (ex.: foi importado
-- o nomenclatura_projeto.json, que é o arquivo de trabalho do app).
global InLab_Produto_Lista
fn InLab_Produto_Lista dados =
(
    local produtos = InLab_JSON_Obter dados "produtos"
    if isKindOf produtos Array then produtos else #()
)

-- Índice (1-based) do produto com esse cod_est; 0 se não houver.
global InLab_Produto_IndicePorCodigo
fn InLab_Produto_IndicePorCodigo produtos cod =
(
    local idx = 0
    for i = 1 to produtos.count where idx == 0 and (InLab_Produto_Texto produtos[i] "cod_est") == cod do idx = i
    idx
)

-- Rótulo da parte na UI. O qualificador entra porque o nome sozinho repete
-- (ex.: 07112075 tem "Encosto" Externo e Interno).
global InLab_Produto_Rotulo
fn InLab_Produto_Rotulo parte =
(
    local nome = InLab_Produto_Texto parte "nome_parte"
    local qual = InLab_Produto_Texto parte "qualificador"
    if qual == "" then nome else (nome + " (" + qual + ")")
)

--------------------------------------------------------------------------------
-- TEXTO
--------------------------------------------------------------------------------

global INLAB_REN_ACENTOS = #(#("áàâãäÁÀÂÃÄ", "a"), #("éèêëÉÈÊË", "e"), #("íìîïÍÌÎÏ", "i"),
                             #("óòôõöÓÒÔÕÖ", "o"), #("úùûüÚÙÛÜ", "u"), #("çÇ", "c"))

-- Minúsculo e sem acento — só para COMPARAR nomes na sugestão.
global InLab_Produto_Normalizar
fn InLab_Produto_Normalizar s =
(
    local saida = ""
    for i = 1 to s.count do
    (
        local c = s[i]
        for par in INLAB_REN_ACENTOS where (findString par[1] c) != undefined do c = par[2]
        saida += c
    )
    toLower saida
)

-- Nome de slot do Max ("Diffuse Color") → sufixo de mapa ("DiffuseColor").
global InLab_Produto_Canal
fn InLab_Produto_Canal nomeSlot =
(
    local permitidos = "abcdefghijklmnopqrstuvwxyz0123456789" -- findString ignora caixa
    local saida = ""
    for i = 1 to nomeSlot.count where (findString permitidos nomeSlot[i]) != undefined do saida += nomeSlot[i]
    if saida == "" then "Mapa" else saida
)

--------------------------------------------------------------------------------
-- CENA: materiais e mapas
--------------------------------------------------------------------------------

-- Materiais únicos dos objetos. De um Multi/Sub-Object entram os
-- submateriais — o multi em si não é acabamento de nenhuma parte.
global InLab_Produto_MateriaisDaSelecao
fn InLab_Produto_MateriaisDaSelecao objs =
(
    local mtls = #()
    for o in objs where o.material != undefined do
    (
        local m = o.material
        if classOf m == Multimaterial then
            for s in m.materialList where s != undefined do appendIfUnique mtls s
        else appendIfUnique mtls m
    )
    mtls
)

-- O objeto usa o material direto ou como submaterial do seu Multi/Sub.
global InLab_Produto_ObjUsaMaterial
fn InLab_Produto_ObjUsaMaterial o mtl =
(
    local m = o.material
    if m == mtl then true
    else if m != undefined and classOf m == Multimaterial then (findItem m.materialList mtl) > 0
    else false
)

-- O texmap e todos os que estão dentro dele (ex.: bitmap dentro de Normal_Bump).
global InLab_Produto_ColetarMapas
fn InLab_Produto_ColetarMapas tm acum =
(
    append acum tm
    for i = 1 to (getNumSubTexmaps tm) do
    (
        local s = getSubTexmap tm i
        if s != undefined do InLab_Produto_ColetarMapas s acum
    )
    acum
)

-- #(canal, texmap) para cada mapa do material. Mapas aninhados herdam o
-- canal do slot de topo. Genérico: não depende de nomes de propriedade de
-- Corona/glTF, só da interface de sub-texmaps que todo material expõe.
global InLab_Produto_MapasDoMaterial
fn InLab_Produto_MapasDoMaterial mtl =
(
    local itens = #()
    for i = 1 to (getNumSubTexmaps mtl) do
    (
        local tm = getSubTexmap mtl i
        if tm != undefined do
        (
            local canal = InLab_Produto_Canal (getSubTexmapSlotName mtl i)
            for m in (InLab_Produto_ColetarMapas tm #()) do append itens #(canal, m)
        )
    )
    itens
)

--------------------------------------------------------------------------------
-- SUGESTÃO DE LIGAÇÃO
--------------------------------------------------------------------------------

-- Array paralelo a `partes`: material sugerido ou undefined. Um material
-- nunca é sugerido para duas partes.
--   1º material que já se chama exatamente material_id (plugin já rodou);
--   2º nome normalizado contém nome_parte (e o qualificador, se houver) —
--      partes COM qualificador primeiro, pra "Encosto" sem qualificador não
--      pegar o material de "Encosto (Externo)".
global InLab_Produto_SugerirLigacoes
fn InLab_Produto_SugerirLigacoes partes mtls =
(
    local ligacoes = for p in partes collect undefined
    local usados = #()
    for i = 1 to partes.count do
    (
        local mid = InLab_Produto_Texto partes[i] "material_id"
        for m in mtls where ligacoes[i] == undefined and m.name == mid and (findItem usados m) == 0 do
        (
            ligacoes[i] = m
            append usados m
        )
    )
    for passo in #(#comQual, #semQual) do
        for i = 1 to partes.count where ligacoes[i] == undefined do
        (
            local nome = InLab_Produto_Normalizar (InLab_Produto_Texto partes[i] "nome_parte")
            local qual = InLab_Produto_Normalizar (InLab_Produto_Texto partes[i] "qualificador")
            if nome != "" and ((passo == #comQual) == (qual != "")) do
                for m in mtls where ligacoes[i] == undefined and (findItem usados m) == 0 do
                (
                    local nm = InLab_Produto_Normalizar m.name
                    if (findString nm nome) != undefined and (qual == "" or (findString nm qual) != undefined) do
                    (
                        ligacoes[i] = m
                        append usados m
                    )
                )
        )
    ligacoes
)

--------------------------------------------------------------------------------
-- APLICAR / REVERTER
--------------------------------------------------------------------------------

-- Renomeia guardando o nome antigo para InLab_Produto_Reverter.
global InLab_Produto_Renomear
fn InLab_Produto_Renomear alvo novoNome =
(
    if alvo.name != novoNome do
    (
        append InLab_UltimaRenomeacao #(alvo, alvo.name)
        alvo.name = novoNome
    )
)

-- ligacoes: paralelo às partes do produto (material ou undefined).
-- objs: objetos que recebem o mesh_final. Devolve false (e não renomeia
-- NADA) se um material estiver ligado a mais de uma parte.
global InLab_Produto_Aplicar
fn InLab_Produto_Aplicar produto ligacoes objs =
(
    local partes = InLab_JSON_Obter produto "partes"
    if not (isKindOf partes Array) do partes = #()

    local conflito = false
    for i = 1 to partes.count where ligacoes[i] != undefined do
        for j = (i + 1) to partes.count where ligacoes[j] == ligacoes[i] do
        (
            conflito = true
            InLab_Log ("Material '" + ligacoes[i].name + "' ligado a duas partes: " +
                       (InLab_Produto_Rotulo partes[i]) + " e " + (InLab_Produto_Rotulo partes[j]) + ".") tipo:#err
        )

    if conflito then
    (
        InLab_Log "Nada foi renomeado — cada material só pode ter um nome. Corrija as ligações e aplique de novo." tipo:#err
        false
    )
    else
    (
        InLab_UltimaRenomeacao = #()
        local nMat = 0, nMap = 0, nObj = 0, nAviso = 0
        local mapasFeitos = #()
        undo "InLab: Renomear pelo JSON" on
        (
            for i = 1 to partes.count do
            (
                local rot = InLab_Produto_Rotulo partes[i]
                local mid = InLab_Produto_Texto partes[i] "material_id"
                local mtl = ligacoes[i]
                if mtl == undefined then
                (
                    InLab_Log ("Parte '" + rot + "' sem material ligado — pulada.") tipo:#warn
                    nAviso += 1
                )
                else
                (
                    if (InLab_Produto_Texto partes[i] "tipo") == "" do
                    (
                        InLab_Log ("Parte '" + rot + "' sem tipo no JSON — nome provisório '" + mid + "'. Classificar a parte na plataforma.") tipo:#warn
                        nAviso += 1
                    )
                    InLab_Produto_Renomear mtl mid
                    nMat += 1
                    local bases = #()
                    local contagens = #()
                    for item in (InLab_Produto_MapasDoMaterial mtl) do
                    (
                        local tm = item[2]
                        if (findItem mapasFeitos tm) > 0 then
                        (
                            InLab_Log ("Mapa '" + tm.name + "' é usado em mais de um lugar — mantido o primeiro nome.") tipo:#warn
                            nAviso += 1
                        )
                        else
                        (
                            local base = mid + "_" + item[1]
                            local k = findItem bases base
                            if k == 0 then
                            (
                                append bases base
                                append contagens 1
                                k = bases.count
                            )
                            else contagens[k] += 1
                            InLab_Produto_Renomear tm (if contagens[k] == 1 then base else (base + "_" + contagens[k] as string))
                            append mapasFeitos tm
                            nMap += 1
                        )
                    )
                )
            )

            for o in objs where isValidNode o do
            (
                local meshes = #()
                for i = 1 to partes.count where ligacoes[i] != undefined and (InLab_Produto_ObjUsaMaterial o ligacoes[i]) do
                    appendIfUnique meshes (InLab_Produto_Texto partes[i] "mesh_final")
                case meshes.count of
                (
                    0: (
                        InLab_Log ("Objeto '" + o.name + "' não usa nenhum material ligado — não renomeado.") tipo:#warn
                        nAviso += 1
                    )
                    1: (
                        InLab_Produto_Renomear o meshes[1]
                        nObj += 1
                    )
                    default: (
                        InLab_Log ("Objeto '" + o.name + "' mistura partes de meshes diferentes " + (meshes as string) + " — não renomeado.") tipo:#warn
                        nAviso += 1
                    )
                )
            )
        )
        InLab_Log ("Renomeação: " + nMat as string + " material(is), " + nMap as string + " mapa(s), " +
                   nObj as string + " objeto(s) · " + nAviso as string + " aviso(s).") tipo:#ok
        true
    )
)

global InLab_Produto_Reverter
fn InLab_Produto_Reverter =
(
    if InLab_UltimaRenomeacao.count == 0 then
        InLab_Log "Nenhuma renomeação para desfazer." tipo:#warn
    else
    (
        local n = 0
        -- ordem inversa: se o mesmo alvo mudou duas vezes, volta ao nome original
        for i = InLab_UltimaRenomeacao.count to 1 by -1 do
        (
            local par = InLab_UltimaRenomeacao[i]
            try ( par[1].name = par[2]; n += 1 ) catch () -- alvo apagado da cena
        )
        InLab_UltimaRenomeacao = #()
        InLab_Log ("Nomes revertidos: " + n as string + ".") tipo:#ok
    )
)
```

E no manifesto, `InLabChecker.ms` (após a linha `@"functions\fn_json.ms",`):

```maxscript
            -- fn_json.ms primeiro: parser genérico consumido pela seção de
            -- Produto (ui\rollout_main.ms) — só depende de core\log.ms.
            @"functions\fn_json.ms",
            -- renomeação pelo JSON de produto — depende de fn_json.ms.
            @"functions\fn_renomear_produto.ms",
```

- [ ] **Step 4: Usuário roda o teste** — Max com cena vazia (File > New), Scripting > Run Script... > `tests\test_renomear_produto.ms`. Agente lê `<getDir #temp>\inlab_test_renomear.txt` (Max 2024: `%LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\temp\`).
  Esperado: todas as linhas `PASS`, última linha `TUDO OK`, linha `INFO` registrando se o `max undo` restaurou material/mapa (informativo — o botão Desfazer cobre o caso negativo).

- [ ] **Step 5: Commit** (se autorizado)

```bash
git add functions/fn_renomear_produto.ms tests/test_renomear_produto.ms InLabChecker.ms
git commit -m "feat(produto): renomeia materiais, mapas e objetos pelo JSON"
```

---

### Task 2: Seção Produto na UI

**Files:**
- Modify: `ui/rollout_main.ms:32-79` (substituir o bloco inteiro da seção Produto)

**Interfaces:**
- Consumes: todas as fns `InLab_Produto_*` da Task 1; `InLab_JSON_LerArquivoUTF8`, `InLab_ParseJSON`, `InLab_JSON_Obter` (fn_json.ms); `InLab_SelecaoValida()` (core/utils.ms).
- Produces: `global InLab_ProdutoAtivo` (árvore crua do JSON, mantida como antes).

- [ ] **Step 1: Substituir a seção** (de `-- SEÇÃO: Produto` até o `)` que fecha `rollout InLabSecProduto`):

```maxscript
----------------------------------------------------------------------
-- SEÇÃO: Produto (Fase 5.2 import · 18/Set renomeação pelo JSON)
----------------------------------------------------------------------
-- Importa o export de nomenclatura da plataforma (Lovable + Supabase),
-- escolhe o produto (pré-selecionado pelo nome do .max = cod_est), liga
-- cada parte a um material da seleção e aplica os nomes oficiais. A lógica
-- toda está em functions\fn_renomear_produto.ms; aqui só fica o estado da
-- tela. Lista + dropdown nativos em vez de tabela dotNet: o número de
-- partes varia por produto e rollout não cria controles dinamicamente.
global InLab_ProdutoAtivo = undefined -- árvore crua do JSON importado (formato de InLab_ParseJSON)

rollout InLabSecProduto "Produto" width:420
(
    local produtos = #()  -- itens de "produtos" do export importado
    local materiais = #() -- materiais lidos da seleção
    local ligacoes = #()  -- paralelo às partes do produto escolhido: material ou undefined
    local objsLidos = #() -- objetos da última leitura — são eles que recebem o mesh_final

    label lblProdutoAtivo "Nenhum produto carregado." align:#left
    button btnImportarProduto "Importar JSON do Produto..." width:395 height:26
    dropdownlist ddlProduto "Produto:" items:#() width:395
    button btnLerSelecao "Ler materiais da seleção" width:395 height:24
    listbox lbxPartes "Parte  →  material:" items:#() height:6 width:395
    dropdownlist ddlMaterial "Material da parte marcada:" items:#() width:395
    button btnAplicar "Aplicar nomes" width:192 height:26 across:2
    button btnDesfazer "Desfazer nomes" width:192 height:26

    fn produtoEscolhido =
        if ddlProduto.selection > 0 and ddlProduto.selection <= produtos.count then produtos[ddlProduto.selection] else undefined

    fn partesEscolhidas =
    (
        local p = produtoEscolhido()
        local partes = if p != undefined then InLab_JSON_Obter p "partes" else undefined
        if isKindOf partes Array then partes else #()
    )

    fn atualizarTela =
    (
        local partes = partesEscolhidas()
        local sel = lbxPartes.selection
        lbxPartes.items = for i = 1 to partes.count collect
            ((InLab_Produto_Rotulo partes[i]) + "  →  " + (if ligacoes[i] == undefined then "(sem material)" else ligacoes[i].name))
        if sel > 0 and sel <= partes.count do lbxPartes.selection = sel
        ddlMaterial.items = #("— nenhum —") + (for m in materiais collect m.name)
        local i = lbxPartes.selection
        ddlMaterial.selection = if i > 0 and ligacoes[i] != undefined then (findItem materiais ligacoes[i]) + 1 else 1
    )

    fn sugerir =
    (
        ligacoes = InLab_Produto_SugerirLigacoes (partesEscolhidas()) materiais
        atualizarTela()
    )

    fn limparProduto =
    (
        InLab_ProdutoAtivo = undefined
        produtos = #()
        ddlProduto.items = #()
        lblProdutoAtivo.text = "Nenhum produto carregado."
        sugerir()
    )

    on btnImportarProduto pressed do
    (
        local caminho = getOpenFileName caption:"Selecionar .json do produto" types:"JSON (*.json)|*.json"
        if caminho == undefined then
            InLab_Log "Importação de produto cancelada — nenhum arquivo selecionado." tipo:#warn
        else
        (
            local texto = InLab_JSON_LerArquivoUTF8 caminho
            local dados = if texto == undefined then undefined else InLab_ParseJSON texto
            if dados == undefined then limparProduto()
            else
            (
                InLab_ProdutoAtivo = dados
                local nomeArquivo = filenameFromPath caminho
                lblProdutoAtivo.text = "Produto carregado: " + nomeArquivo
                InLab_Log ("Produto importado com sucesso: " + nomeArquivo) tipo:#ok
                produtos = InLab_Produto_Lista dados
                ddlProduto.items = for p in produtos collect ((InLab_Produto_Texto p "cod_est") + " – " + (InLab_Produto_Texto p "nome"))
                if produtos.count == 0 then
                    InLab_Log "Este JSON não tem lista de produtos — importe o export da linha (nomenclatura_export_...json), não o nomenclatura_projeto.json." tipo:#warn
                else
                (
                    local cod = getFilenameFile maxFileName
                    local idx = InLab_Produto_IndicePorCodigo produtos cod
                    if idx > 0 then
                        InLab_Log ("Produto do arquivo aberto: " + ddlProduto.items[idx]) tipo:#ok
                    else
                    (
                        idx = 1
                        InLab_Log ("Nenhum produto com cod_est '" + cod + "' (nome do .max) — escolha na lista.") tipo:#warn
                    )
                    ddlProduto.selection = idx
                )
                sugerir()
            )
        )
    )

    on ddlProduto selected i do sugerir()

    on btnLerSelecao pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            objsLidos = objs
            materiais = InLab_Produto_MateriaisDaSelecao objs
            sugerir()
            local n = 0
            for l in ligacoes where l != undefined do n += 1
            InLab_Log (materiais.count as string + " material(is) em " + objs.count as string + " objeto(s) · " +
                       n as string + " parte(s) pré-ligada(s) — confira antes de aplicar.")
        )
    )

    on lbxPartes selected i do atualizarTela()

    on ddlMaterial selected j do
    (
        local i = lbxPartes.selection
        if i == 0 then
            InLab_Log "Marque uma parte na lista antes de escolher o material." tipo:#warn
        else
            ligacoes[i] = if j == 1 then undefined else materiais[j - 1]
        atualizarTela()
    )

    on btnAplicar pressed do
    (
        local p = produtoEscolhido()
        if p == undefined then
            InLab_Log "Importe o JSON e escolha o produto antes de aplicar." tipo:#warn
        else if objsLidos.count == 0 then
            InLab_Log "Clique em 'Ler materiais da seleção' antes de aplicar." tipo:#warn
        else
        (
            objsLidos = for o in objsLidos where isValidNode o collect o
            InLab_Produto_Aplicar p ligacoes objsLidos
            atualizarTela()
        )
    )

    on btnDesfazer pressed do
    (
        InLab_Produto_Reverter()
        atualizarTela()
    )
)
```

- [ ] **Step 2: Usuário testa no Max** — numa **cópia** de `Pack_Contract_Rafa\Blocos_3d\05111058.max`:
  1. abrir o plugin (ou Reload Plugin); seção Produto → Importar `nomenclatura_export_linha contract_health.json`;
     esperado: dropdown mostra `05111058 – APARADOR RIZZI...` selecionado, log `Produto do arquivo aberto`;
  2. selecionar os objetos do produto → Ler materiais da seleção; esperado: 4 partes (Base, Tampo, Prateleira, Deslizadores) com ligação sugerida ou `(sem material)`;
  3. marcar cada parte e escolher o material no dropdown;
  4. Aplicar nomes; conferir no Material Editor os nomes `ART_P_Base`, `ART_C_Tampo`... e mapas `ART_..._<canal>`; objeto `05111058`; resumo no log;
  5. Desfazer nomes; conferir nomes originais de volta.
  O usuário relata o que viu (ou salva o log pelo botão "Salvar .txt" e informa o caminho).

- [ ] **Step 3: Commit** (se autorizado)

```bash
git add ui/rollout_main.ms
git commit -m "feat(ui): secao Produto liga partes a materiais e aplica nomes"
```

---

## Desvios durante a execução (18/09)

- **Teste, etapa de Ctrl+Z removida:** `max undo` rodado de dentro do script desfez a criação das caixas de teste, não a renomeação. Ctrl+Z só é conferível à mão.
- **Histórico do Desfazer acumula:** `InLab_Produto_Aplicar` não zera mais `InLab_UltimaRenomeacao`; só `InLab_Produto_Reverter` zera. No teste da UI, o modelador aplicou, trocou a ligação da Base e aplicou de novo; cada Aplicar zerava o histórico e o Desfazer não achou nada (ficaram dois materiais `ART_P_Base`). Teste novo: etapa 7 de `tests/test_renomear_produto.ms`.
