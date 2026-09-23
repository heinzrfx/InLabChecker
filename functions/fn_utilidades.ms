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

 2. InLab_CentralizarPivot — move o pivot de cada objeto para o centro
    geométrico (bounding box). Nota: as regras de pivot por família
    (V-17/27/28/31/32) têm critérios próprios — esta função é utilitário
    de modelagem, não substitui a verificação.

 3. InLab_BasePivot — move o pivot para a base do objeto: centro XY e
    fundo (min.z) do bounding box, mesmo critério da V-17. Não move o
    objeto para Z=0 do mundo. (22/Set/2026: o botão "Base Pivot" chamava
    esta função, que não existia — erro na linha 301 de rollout_main.ms.)
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

fn InLab_CentralizarPivot objs =
(
    local n = 0
    undo "InLab Centralizar Pivot" on
    (
        for o in objs do
        (
            o.pivot = o.center
            n += 1
            InLab_Log (o.name + ": pivot centralizado no bounding box.") tipo:#ok
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
        for o in objs do
        (
            o.pivot = [o.center.x, o.center.y, o.min.z]
            n += 1
            InLab_Log (o.name + ": pivot na base (centro XY, fundo do bounding box).") tipo:#ok
        )
    )
    InLab_Log ("Base pivot: " + n as string + " objeto(s).")
    n
)
