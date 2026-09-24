/*
================================================================================
 functions\fn_material_utils.ms — UTILIDADES DE MATERIAL (ref. ArchToolz)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 InLab_DetachPorMaterialSelecao — detach por Material ID com PROPAGAÇÃO:
 cada pedaço detachado recebe o SUBMATERIAL correspondente ao seu ID, não o
 Multi/Sub-Object inteiro. Sem isso, cada pedaço sai carregando todos os
 slots do material original — pior pra inspeção e pro export GLB, que só
 precisa do material que aquele pedaço realmente usa.

 ESCOPO: não depende de família carregada — funciona com qualquer objeto,
 igual às Utilidades Rápidas (fn_utilidades.ms).

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

 24/09/2026 (issue #52, limpeza): InLab_SelecionarPorMaterialSimilar,
 InLab_ObjBateComMaterial e InLab_NomeObjetoParaMaterial removidas — saíram
 da UI na issue #55 e ficaram sem nenhuma chamada (grep confirmou). Detach
 por Material é o único uso que sobra deste arquivo (migrou para Utilidades
 Rápidas na mesma #55).
================================================================================
*/

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
