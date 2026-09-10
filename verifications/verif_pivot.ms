/*
================================================================================
 verifications\verif_pivot.ms — V-17/18 (raiz) · [V-27/28/28b/31/32/32b: Grupo 4]
--------------------------------------------------------------------------------
 Pivôs. Nesta entrega: pivot raiz na base/centro (V-17) e eixos sem rotação
 residual (V-18). Os pivôs de ANIMAÇÃO por tipo de movimento (tabela seção 4
 da spec) entram no Grupo 4.
================================================================================
*/

-- Raízes = objetos de geometria sem pai (topo da hierarquia do bloco).
fn InLab_RaizesGeometria objetos =
(
    for o in objetos where o.parent == undefined collect o
)

-- V-17 · Pivot raiz: base (Z = fundo do bbox) e centro XY.
-- Tolerância: 2% da altura do objeto (mínimo 1 unidade de sistema).
fn InLab_V17_PivotRaiz objetos =
(
    local raizes = InLab_RaizesGeometria objetos
    local problemas = #()
    local tol = 1.0   -- ±1mm FIXO, conforme spec (Z=0 do MUNDO — não % da altura)
    for o in raizes do
    (
        local cx = (o.min.x + o.max.x) / 2.0
        local cy = (o.min.y + o.max.y) / 2.0
        local okZmundo = (abs o.pivot.z) <= tol
        local okBase   = (abs (o.pivot.z - o.min.z)) <= tol
        local okXY     = ((abs (o.pivot.x - cx)) <= tol) and ((abs (o.pivot.y - cy)) <= tol)
        
        if not (okZmundo and okXY) do
        (
            local motivo = if (not okZmundo) and okBase then
            (
                " [base OK, mas objeto flutuando — pivot Z=" + (formattedPrint o.pivot.z format:".2f") + "mm, esperado 0]"
            )
            else ""
            
            append problemas (o.name + " pivot:" + o.pivot as string + motivo)
        )
    )
    
    InLab_RegistrarVerif "V-17" "Pivot raiz em Z=0 (mundo), centrado em XY" (problemas.count == 0) (if problemas.count == 0 then (raizes.count as string + " raiz(es) OK") else (problemas as string)) critico:true
)

-- V-18 · Eixos do pivot alinhados ao mundo (sem rotação residual no nó).
-- Ângulo do quaternion de rotação deve ser ~0° (tolerância 0.5°).
-- Nota: acos() do MaxScript retorna GRAUS.
fn InLab_V18_EixosPivot objetos =
(
    local problemas = #()
    for o in (InLab_RaizesGeometria objetos) do
    (
        local w = abs o.rotation.w
        if w > 1.0 do w = 1.0
        local anguloGraus = 2.0 * (acos w)
        if anguloGraus > 0.5 do append problemas (o.name + " rot:" + (formattedPrint anguloGraus format:".2f") + "°")
    )
    InLab_RegistrarVerif "V-18" "Eixos do pivot alinhados ao mundo" (problemas.count == 0) (if problemas.count == 0 then "sem rotação residual nas raízes" else (problemas as string)) critico:true
)