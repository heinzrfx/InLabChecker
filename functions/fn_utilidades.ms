/*
================================================================================
 functions\fn_utilidades.ms — UTILIDADES RÁPIDAS (solicitação Rafael, 08/Jul)
--------------------------------------------------------------------------------
 Duas operações independentes de preparação de cena, com undo padrão do Max:

 1. InLab_ResetXFormSelecao — aplica ResetXForm em cada objeto da seleção
    e colapsa o stack inteiro (collapseStack: poly continua poly, primitiva
    vira Editable_mesh).
    22/Set/2026 (pedido do usuário, igual ao ArchToolz): antes o XForm ficava
    no stack. Agora colapsa. Instância vira objeto único antes (o stack é
    compartilhado). Objeto espelhado (escala negativa) não precisa de Normal
    com flip: no Max 2024 o próprio ResetXForm já acerta o sentido das faces
    (testado; com o flip a malha ficava do avesso).

 2. InLab_CentralizarPivot — move o pivot para o centro geométrico
    (bounding box) da geometria.

 3. InLab_BasePivot — move o pivot para a base da geometria: centro XY e
    fundo (min.z) do bounding box. Mesmo critério de X/Y/Z que a V-17
    (verifications\verif_pivot.ms) cobra — mas não move o objeto para
    Z=0 do mundo: se o produto está flutuando, o pivot vai para a base
    ONDE ELE ESTÁ, e a V-17 vai acusar o desvio de Z.

 24/Set/2026 (issue #50): Center/Base Pivot não filtravam por
 InLab_EhGeometria — helpers e CABEÇAS DE GRUPO na seleção também tinham o
 pivot movido a partir do bounding box do próprio helper (sem sentido: o
 bbox de um Dummy/cabeça de grupo não é o do produto).
 Decidido na issue: Base Pivot num produto AGRUPADO move o pivot da CABEÇA
 DO GRUPO (é o nó que a V-17 verifica — verif_pivot.ms > InLab_RaizesGeometria,
 raiz = topo da hierarquia por .parent), calculado a partir do bounding box
 das geometrias DESCENDENTES do grupo (não o bbox do helper).
 As duas funções agora:
   - sobem de cada objeto selecionado até a raiz da hierarquia (mesma regra
     da V-17: sobe por .parent; objeto solto é raiz de si mesmo; membro de
     grupo aberto ou fechado resolve para a cabeça do grupo);
   - juntam as geometrias descendentes dessa raiz (InLab_EhGeometria) para
     o bounding box — a cabeça do grupo em si NUNCA entra no bbox nem é
     tratada como geometria;
   - movem o pivot só da raiz (uma vez por produto, não por peça).
 Raiz sem geometria (helper solto, grupo vazio) não tem pivot alterado —
 loga aviso e não conta no total.
================================================================================
*/

fn InLab_ResetXFormSelecao objs =
(
    local n = 0
    undo "InLab ResetXForm" on
    (
        for o in objs where InLab_EhGeometria o do
        (
            try
            (
                -- Instâncias compartilham o stack: o XForm apareceria nas
                -- outras sem o transform delas ser zerado.
                if (InLab_Instancias o).count > 1 do
                (
                    InstanceMgr.MakeObjectsUnique o #individual
                    InLab_Log (o.name + ": era instância. Ficou único para colapsar.") tipo:#warn
                )
                local nMods = o.modifiers.count
                ResetXForm o
                collapseStack o
                n += 1
                InLab_Log (o.name + ": ResetXForm aplicado e stack colapsado (" + (nMods + 1) as string + " modificador(es)) → " +
                           (classof o.baseObject) as string + ".") tipo:#ok
            )
            catch
                InLab_Log (o.name + ": ResetXForm falhou (" + getCurrentException() + ").") tipo:#err
        )
    )
    InLab_Log ("ResetXForm: " + n as string + " objeto(s).")
    n
)

-- Nó do TOPO da hierarquia de `no` (sobe por .parent até não ter mais pai).
-- Mesma regra usada pela V-17 (verifications\verif_pivot.ms >
-- InLab_RaizesGeometria) para achar a "raiz" de um produto: objeto solto é
-- raiz de si mesmo; membro de grupo (aberto ou fechado) resolve para a
-- cabeça do grupo, que é quem a V-17 confere.
fn InLab_RaizDoNo no =
(
    local topo = no
    while topo.parent != undefined do topo = topo.parent
    topo
)

-- Geometrias (InLab_EhGeometria) que descendem de `raiz`, incluindo ela
-- mesma se for geometria. Cabeça de grupo/Dummy nunca entra no resultado —
-- só o que teria ido para `geometry` na verificação normal.
fn InLab_GeometriasDescendentes raiz =
(
    local geoms = #()
    local pilha = #(raiz)
    while pilha.count > 0 do
    (
        local atual = pilha[pilha.count]
        deleteItem pilha pilha.count
        if InLab_EhGeometria atual do appendIfUnique geoms atual
        for c in atual.children do append pilha c
    )
    geoms
)

-- Bounding box [min, max] da união de `geoms` (arrays de nós de geometria).
fn InLab_BBoxGeometrias geoms =
(
    local bMin = undefined
    local bMax = undefined
    for o in geoms do
    (
        if bMin == undefined then ( bMin = copy o.min; bMax = copy o.max )
        else
        (
            bMin = [amin bMin.x o.min.x, amin bMin.y o.min.y, amin bMin.z o.min.z]
            bMax = [amax bMax.x o.max.x, amax bMax.y o.max.y, amax bMax.z o.max.z]
        )
    )
    #(bMin, bMax)
)

-- Raízes ÚNICAS (InLab_RaizDoNo) dos objetos de `objs`, na ordem em que
-- aparecem — sem repetir quando duas peças selecionadas resolvem para a
-- mesma cabeça de grupo.
fn InLab_RaizesDaSelecao objs =
(
    local raizes = #()
    for o in objs do appendIfUnique raizes (InLab_RaizDoNo o)
    raizes
)

fn InLab_CentralizarPivot objs =
(
    local n = 0
    undo "InLab Centralizar Pivot" on
    (
        for raiz in (InLab_RaizesDaSelecao objs) do
        (
            local geoms = InLab_GeometriasDescendentes raiz
            if geoms.count == 0 then
                InLab_Log (raiz.name + ": sem geometria (helper ou grupo vazio) — pivot não alterado.") tipo:#warn
            else
            (
                local bb = InLab_BBoxGeometrias geoms
                local centro = [(bb[1].x + bb[2].x) / 2.0, (bb[1].y + bb[2].y) / 2.0, (bb[1].z + bb[2].z) / 2.0]
                raiz.pivot = centro
                n += 1
                InLab_Log (raiz.name + ": pivot centralizado no bounding box (" + geoms.count as string + " geometria(s)).") tipo:#ok
            )
        )
    )
    InLab_Log ("Centralizar pivot: " + n as string + " objeto(s).")
    n
)

fn InLab_BasePivot objs =
(
    local n = 0
    undo "InLab Base Pivot" on
    (
        for raiz in (InLab_RaizesDaSelecao objs) do
        (
            local geoms = InLab_GeometriasDescendentes raiz
            if geoms.count == 0 then
                InLab_Log (raiz.name + ": sem geometria (helper ou grupo vazio) — pivot não alterado.") tipo:#warn
            else
            (
                local bb = InLab_BBoxGeometrias geoms
                raiz.pivot = [(bb[1].x + bb[2].x) / 2.0, (bb[1].y + bb[2].y) / 2.0, bb[1].z]
                n += 1
                InLab_Log (raiz.name + ": pivot na base (centro XY, fundo do bounding box; " + geoms.count as string + " geometria(s)).") tipo:#ok
            )
        )
    )
    InLab_Log ("Base pivot: " + n as string + " objeto(s).")
    n
)
