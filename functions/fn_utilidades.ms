/*
================================================================================
 functions\fn_utilidades.ms — UTILIDADES RÁPIDAS (solicitação Rafael, 08/Jul)
--------------------------------------------------------------------------------
 Duas operações independentes de preparação de cena, com undo padrão do Max:

 1. InLab_ResetXFormSelecao — aplica ResetXForm em cada objeto da seleção.
    O modificador XForm FICA no stack (colapso é decisão do desenhista;
    a V-12 da Fase 4 aponta XForm residual antes do export).

 2. InLab_CentralizarPivot — move o pivot de cada objeto para o centro
    geométrico (bounding box). Nota: as regras de pivot por família
    (V-17/27/28/31/32) têm critérios próprios — esta função é utilitário
    de modelagem, não substitui a verificação.
================================================================================
*/

fn InLab_ResetXFormSelecao objs =
(
    local n = 0
    undo "InLab ResetXForm" on
    (
        for o in objs where InLab_EhGeometria o do
        (
            ResetXForm o
            n += 1
            InLab_Log (o.name + ": ResetXForm aplicado (XForm no stack — colapsar antes do export).") tipo:#ok
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
