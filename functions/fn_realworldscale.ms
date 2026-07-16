/*
================================================================================
 functions\fn_realworldscale.ms — FUNÇÃO 4 (Fase 1.2)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Diagnostica (e opcionalmente corrige) três problemas de escala:

 1. UNIDADE DO SISTEMA divergente do padrão InLab (CENTÍMETROS — confirmado
    pela equipe em Jul/2026).
    ATENÇÃO: mudar units.SystemType via script NÃO reescala a geometria —
    os números permanecem e o tamanho real muda. Por isso a correção só
    roda com confirmação explícita (a UI pergunta antes).

 2. TRANSFORM SCALE != 100% no nó (obj.scale != [1,1,1]).
    Causa clássica de export GLB com dimensões erradas. A correção
    oferecida é ResetXForm — que ADICIONA um modificador XForm ao stack.
    O colapso fica manual (a V-12 da Fase 4 apontará XForm residual).

 3. BOUNDING BOX fora da faixa plausível de móvel.
    Heurística: maior dimensão do bbox convertida para METROS deve estar
    entre INLAB_MOVEL_MIN_M e INLAB_MOVEL_MAX_M.

 PREMISSA AINDA ABERTA: faixa plausível 0.2–5.0 m (constantes abaixo).
================================================================================
*/

-- ===== CONSTANTES DO PIPELINE =====
global INLAB_UNIDADE_PADRAO = #Centimeters   -- CONFIRMADO pela equipe (base da futura V-19)
global INLAB_MOVEL_MIN_M    = 0.2            -- menor "maior dimensão" plausível, em metros
global INLAB_MOVEL_MAX_M    = 5.0            -- maior dimensão plausível, em metros

--------------------------------------------------------------------------------
-- Fator de conversão da unidade de sistema atual para METROS.
--------------------------------------------------------------------------------
fn InLab_FatorParaMetros =
(
    case units.SystemType of
    (
        #Millimeters: 0.001
        #Centimeters: 0.01
        #Meters:      1.0
        #Kilometers:  1000.0
        #Inches:      0.0254
        #Feet:        0.3048
        #Miles:       1609.34
        default:      1.0
    )
)

--------------------------------------------------------------------------------
-- 1. UNIDADE DO SISTEMA
-- corrigir:false → só diagnostica. corrigir:true → seta o padrão (a UI só
-- passa true após confirmação do usuário).
-- Retorna true se a unidade está (ou ficou) correta.
--------------------------------------------------------------------------------
fn InLab_VerificarUnidade corrigir:false =
(
    local atual = units.SystemType
    if atual == INLAB_UNIDADE_PADRAO then
    (
        InLab_Log ("Unidade do sistema OK: " + atual as string) tipo:#ok
        true
    )
    else
    (
        InLab_Log ("Unidade do sistema divergente: atual " + atual as string +
                   " · padrão InLab " + INLAB_UNIDADE_PADRAO as string) tipo:#warn
        if corrigir then
        (
            units.SystemType = INLAB_UNIDADE_PADRAO
            InLab_Log ("Unidade alterada para " + INLAB_UNIDADE_PADRAO as string +
                       ". ATENÇÃO: a geometria NÃO foi reescalada — conferir dimensões reais.") tipo:#warn
            true
        )
        else false
    )
)

--------------------------------------------------------------------------------
-- 2 + 3. ESCALA DOS OBJETOS
-- aplicarResetXForm:true → aplica ResetXForm nos objetos com scale != 100%
-- (a UI controla via checkbox).
-- Retorna o número de objetos com algum problema detectado.
--------------------------------------------------------------------------------
fn InLab_VerificarEscala objs aplicarResetXForm:false rotulo:"" =
(
    local fator = InLab_FatorParaMetros()
    local problemas = 0
    if rotulo != "" do InLab_Log ("— Real World Scale · " + rotulo + " (" + objs.count as string + " objeto(s)) —")

    -- PASSE PRÉVIO (bug 3, ordem validada com o Rafael): ResetXForm ANTES
    -- de qualquer medição — transform não resetado mascara a escala real.
    if aplicarResetXForm do
        for o in objs where InLab_EhGeometria o do
        (
            local s0 = o.scale
            local neutra0 = (abs (s0.x - 1.0) < 0.001) and (abs (s0.y - 1.0) < 0.001) and (abs (s0.z - 1.0) < 0.001)
            if not neutra0 do
            (
                ResetXForm o
                InLab_Log (o.name + ": ResetXForm aplicado ANTES da medição (scale era " + s0 as string + "). Colapsar antes do export.") tipo:#ok
            )
        )

    for o in objs where InLab_EhGeometria o do
    (
        local temProblema = false

        -- (2) Transform scale do nó. Tolerância de 0.1% para ruído numérico.
        local s = o.scale
        local escalaNeutra = (abs (s.x - 1.0) < 0.001) and (abs (s.y - 1.0) < 0.001) and (abs (s.z - 1.0) < 0.001)
        if not escalaNeutra do
        (
            temProblema = true
            InLab_Log (o.name + ": transform scale " + s as string +
                       " (esperado [1,1,1] — risco de export GLB fora de escala).") tipo:#warn
        )

        -- (3) Bounding box em metros vs. faixa plausível de móvel.
        local dims = (o.max - o.min) * fator
        local maiorDim = amax #(dims.x, dims.y, dims.z)
        if maiorDim < INLAB_MOVEL_MIN_M or maiorDim > INLAB_MOVEL_MAX_M then
        (
            temProblema = true
            InLab_Log (o.name + ": maior dimensão " + (formattedPrint maiorDim format:".2f") +
                       " m — fora da faixa plausível de móvel (" +
                       INLAB_MOVEL_MIN_M as string + "-" + INLAB_MOVEL_MAX_M as string + " m).") tipo:#warn
        )
        else if escalaNeutra do
            InLab_Log (o.name + ": escala OK · " +
                       (formattedPrint dims.x format:".2f") + " x " +
                       (formattedPrint dims.y format:".2f") + " x " +
                       (formattedPrint dims.z format:".2f") + " m") tipo:#ok

        if temProblema do problemas += 1
    )

    if problemas == 0 then InLab_Log "Real World Scale: nenhum problema de escala detectado." tipo:#ok
    else InLab_Log ("Real World Scale: " + problemas as string + " objeto(s) com problema.") tipo:#warn
    problemas
)
