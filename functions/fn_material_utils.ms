/*
================================================================================
 functions\fn_material_utils.ms — UTILIDADES DE MATERIAL (ref. ArchToolz)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Três ferramentas de material que o ArchToolz tem e o InLabChecker ainda não
 tinha (pedido Rafael, 10/Set):

   1. InLab_SelecionarPorMaterialSimilar — seleciona, no escopo escolhido,
      todos os objetos cujo material bate com um material de REFERÊNCIA.
      Reaproveita o clipboard de material já existente (Copy Mat / Pick Mat,
      fn_clipboard.ms) como origem da referência — não pede um pick novo.
      Também entra em Multi/Sub-Object: basta UM submaterial bater.

   2. InLab_NomeObjetoParaMaterial — renomeia o material de cada objeto da
      seleção para o nome do próprio objeto (equivalente ao "Object name to
      Material name" do ArchToolz). Em Multi/Sub-Object, renomeia o material
      de topo (o multi), não os submateriais — os submateriais são zonas de
      acabamento, não identidade do objeto.

   3. InLab_DetachPorMaterialSelecao — detach por Material ID com PROPAGAÇÃO:
      cada pedaço detachado recebe o SUBMATERIAL correspondente ao seu ID,
      não o Multi/Sub-Object inteiro. Sem isso, cada pedaço sai carregando
      todos os slots do material original — pior pra inspeção e pro export
      GLB, que só precisa do material que aquele pedaço realmente usa.

 ESCOPO: nenhuma destas três depende de família carregada — funcionam com
 qualquer objeto, igual às Utilidades Rápidas (fn_utilidades.ms).

 CORREÇÕES:
 - 24/Set: issue #43 — InLab_DetachPorMaterialID resolvia o submaterial do
   pedaço por POSIÇÃO (materialList[id]), mas o Max casa material IDs de
   FACE com slot pelo materialIDList, não pela posição na lista. Com slots
   1,2,5 o pedaço do ID 5 ficava sem submaterial; com 3,7,9 o pedaço do ID 3
   recebia materialList[3] (o do ID 9) — material errado, sem aviso. Corrigido
   com InLab_SubMaterialPorID, que resolve por `findItem mtl.materialIDList
   id`, igual o Max. Também: objeto com modificador no stack agora é avisado
   (#warn) e PULADO — polyop age na base e ignora IDs trocados por modificador
   sem colapsar, e colapsar sem pedido do artista muda a malha por baixo dele.
================================================================================
*/

--------------------------------------------------------------------------------
-- SELECIONAR POR MATERIAL SIMILAR
--------------------------------------------------------------------------------

-- true se o material "de topo" do objeto bate com mtlRef — direto, ou (se
-- for Multi/Sub-Object) em qualquer um dos submateriais. porNome:true relaxa
-- o critério para "mesmo NOME" (cobre cópias/instâncias que não são o mesmo
-- objeto de material em memória — comum depois de "Make Unique" ou merge).
fn InLab_ObjBateComMaterial obj mtlRef porNome:false =
(
    local m = obj.material
    if m == undefined then false
    else if m == mtlRef then true
    else if porNome and m.name == mtlRef.name then true
    else if classof m == Multimaterial then
    (
        local achou = false
        for i = 1 to m.numsubs while not achou do
        (
            local sub = m.materialList[i]
            if sub != undefined do
            (
                if sub == mtlRef then achou = true
                else if porNome and sub.name == mtlRef.name do achou = true
            )
        )
        achou
    )
    else false
)

-- Ponto de entrada da UI. mtlRef default = material já copiado pelo usuário
-- (Copy Mat / Pick Mat da barra fixa) — reaproveita o fluxo existente em vez
-- de pedir um pick novo.
fn InLab_SelecionarPorMaterialSimilar escopo:#cena porNome:false =
(
    local mtlRef = InLab_ClipboardMat
    if mtlRef == undefined then
    (
        InLab_Log "Selecionar por Material Similar: nenhum material de referência — use Copy Mat ou Pick Mat primeiro." tipo:#warn
        #()
    )
    else
    (
        local universo = if escopo == #selecao then (selection as array)
                          else (for o in geometry where InLab_EhGeometria o collect o)
        local achados = for o in universo where InLab_ObjBateComMaterial o mtlRef porNome:porNome collect o

        if achados.count > 0 do select achados
        InLab_Log ("Selecionar por Material Similar: '" + mtlRef.name + "' → " + achados.count as string +
                   " objeto(s) (" + (if escopo == #selecao then "seleção" else "cena inteira") +
                   (if porNome then ", por nome" else "") + ").") tipo:(if achados.count > 0 then #ok else #warn)
        achados
    )
)

--------------------------------------------------------------------------------
-- NOME DO OBJETO → NOME DO MATERIAL
--------------------------------------------------------------------------------
fn InLab_NomeObjetoParaMaterial objs =
(
    local n = 0
    undo "InLab Nome Objeto -> Material" on
    (
        for o in objs do
        (
            if o.material == undefined then
                InLab_Log (o.name + ": sem material — nada a renomear.") tipo:#warn
            else if o.material.name == o.name then
                InLab_Log (o.name + ": material já tem o mesmo nome — ignorado.")
            else
            (
                local m = o.material
                local nomeAntigo = m.name
                -- Material compartilhado por outros nós (mesma instância):
                -- renomear afeta TODOS eles — avisa em vez de esconder.
                local outros = for x in geometry where x != o and InLab_EhGeometria x and x.material == m collect x
                m.name = o.name
                n += 1
                if outros.count > 0 then
                    InLab_Log (o.name + ": material '" + nomeAntigo + "' → '" + o.name +
                               "' (COMPARTILHADO com " + outros.count as string + " outro(s) objeto(s) — todos afetados).") tipo:#warn
                else
                    InLab_Log (o.name + ": material '" + nomeAntigo + "' → '" + o.name + "'.") tipo:#ok
            )
        )
    )
    InLab_Log ("Nome Objeto → Material: " + n as string + " material(is) renomeado(s) de " + objs.count as string + " objeto(s).")
    n
)

--------------------------------------------------------------------------------
-- DETACH POR MATERIAL, COM PROPAGAÇÃO DE IDS
--------------------------------------------------------------------------------

-- BitArray das faces de obj cujo Material ID == id. Recalculado SEMPRE no
-- estado atual do objeto — nunca cacheado entre detaches: cada detach
-- remove faces e RENUMERA as que restam, então um bitarray de uma leitura
-- anterior aponta pras faces erradas depois do primeiro corte.
fn InLab_FacesPorMatID obj id =
(
    local total = polyop.getNumFaces obj
    local bits = #{}
    for f = 1 to total do
        if (polyop.getFaceMatID obj f) == id do bits[f] = true
    bits
)

-- Submaterial de um Multi/Sub-Object correspondente ao Material ID "id" —
-- resolvido do jeito que o Max resolve (por materialIDList), NUNCA por
-- posição: materialList[i] e materialIDList[i] são o par do slot i, e o ID
-- de um slot não precisa bater com a posição dele na lista (ex.: slots com
-- IDs 3, 7, 9 — o ID 3 é o 1º slot, não o 3º). undefined se nenhum slot
-- carrega esse ID (issue #43).
fn InLab_SubMaterialPorID mtl id =
(
    local idx = findItem mtl.materialIDList id
    if idx > 0 then mtl.materialList[idx] else undefined
)

-- Detach de UM objeto. Retorna array com todos os nós resultantes (o
-- original, que sobra com o primeiro ID, + os novos detachados).
fn InLab_DetachPorMaterialID obj =
(
    if obj.modifiers.count > 0 then
    (
        InLab_Log (obj.name + ": tem " + obj.modifiers.count as string +
                   " modificador(es) no stack — polyop age na base e ignora IDs trocados por modificador. " +
                   "Pulado (colapsar precisa ser pedido pelo artista, não automático).") tipo:#warn
        #(obj)
    )
    else
    (
        if not (isKindOf obj Editable_Poly) do
        (
            InLab_Log (obj.name + ": não é Editable Poly — convertendo antes do detach.") tipo:#warn
            convertToPoly obj
        )

        local mtl = obj.material
        if mtl == undefined or classof mtl != Multimaterial then
        (
            InLab_Log (obj.name + ": sem Multi/Sub-Object material — nada para detach por ID.") tipo:#warn
            #(obj)
        )
        else
        (
            local total = polyop.getNumFaces obj
            local idsPresentes = #()
            for f = 1 to total do appendIfUnique idsPresentes (polyop.getFaceMatID obj f)
            sort idsPresentes

            if idsPresentes.count <= 1 then
            (
                InLab_Log (obj.name + ": só 1 Material ID nas faces — nada para separar.") tipo:#warn
                #(obj)
            )
            else
            (
                local novos = #()
                local nomeBase = obj.name

                -- Do último ID pro segundo: SEMPRE recalcula o bitarray na hora
                -- (ver InLab_FacesPorMatID) — é o que torna seguro fazer vários
                -- detaches em sequência no mesmo objeto.
                for i = idsPresentes.count to 2 by -1 do
                (
                    local id = idsPresentes[i]
                    local faces = InLab_FacesPorMatID obj id
                    if faces.numberSet > 0 do
                    (
                        local nomeNovo = uniqueName (nomeBase + "_MatID" + id as string)
                        local ok = polyop.detachFaces obj faces delete:true asNode:true name:nomeNovo
                        local novo = if ok then getNodeByName nomeNovo else undefined
                        if novo != undefined then
                        (
                            -- PROPAGAÇÃO: o pedaço recebe só o SUBMATERIAL do seu
                            -- ID — não o Multi/Sub-Object inteiro (senão cada
                            -- pedaço carrega todos os slots à toa).
                            local sub = InLab_SubMaterialPorID mtl id
                            if sub != undefined then novo.material = sub
                            else InLab_Log (nomeNovo + ": ID " + id as string + " sem submaterial correspondente — material mantido como estava.") tipo:#warn
                            append novos novo
                            InLab_Log (nomeBase + ": ID " + id as string + " → '" + nomeNovo + "'" +
                                       (if sub != undefined then " · material '" + sub.name + "'" else "") + ".") tipo:#ok
                        )
                        else
                            InLab_Log (nomeBase + ": FALHA ao detachar ID " + id as string + ".") tipo:#err
                    )
                )

                -- Original fica só com o PRIMEIRO ID — material também se
                -- resolve pro submaterial correspondente (mesma lógica acima).
                local idRestante = idsPresentes[1]
                local subRestante = InLab_SubMaterialPorID mtl idRestante
                if subRestante != undefined do obj.material = subRestante
                InLab_Log (obj.name + ": mantém ID " + idRestante as string +
                           (if subRestante != undefined then " · material '" + subRestante.name + "'" else "") + " (objeto original).") tipo:#ok

                append novos obj
                novos
            )
        )
    )
)

-- Ponto de entrada da UI: roda o detach em cada objeto da seleção.
fn InLab_DetachPorMaterialSelecao objs =
(
    local todosNovos = #()
    undo "InLab Detach por Material (IDs)" on
    (
        for o in objs do join todosNovos (InLab_DetachPorMaterialID o)
    )
    if todosNovos.count > 0 do select todosNovos
    InLab_Log ("Detach por Material: " + objs.count as string + " objeto(s) processado(s) → " +
               todosNovos.count as string + " objeto(s) no total.")
    todosNovos
)
