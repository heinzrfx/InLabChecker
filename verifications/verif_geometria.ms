/*
================================================================================
 verifications\verif_geometria.ms — V-11/12 · [V-07/08/09/10/13: Grupo 6]
--------------------------------------------------------------------------------
 Nesta entrega: stack de modificadores (V-11) e transform resetado (V-12).
 As verificações pesadas de malha (watertight, faces duplicadas, normais,
 ngons, ratio v/t) entram no Grupo 6.
================================================================================
*/

-- V-11 · Stack colapsado: qualquer modificador residual reprova (o asset
-- final não pode depender de avaliação de stack no export).
fn InLab_V11_Modificadores objetos =
(
    local com = for o in objetos where o.modifiers.count > 0 collect (o.name + " [" + o.modifiers.count as string + " mod.]")
    InLab_RegistrarVerif "V-11" "Stack de modificadores colapsado" (com.count == 0) (if com.count == 0 then "todos os stacks limpos" else (com as string)) critico:true
)

-- V-12 · Transform resetado: sem modificador XForm residual e scale = 100%.
fn InLab_V12_XForm objetos =
(
    local problemas = #()
    for o in objetos do
    (
        local temXForm = false
        for m in o.modifiers where classof m == XForm do temXForm = true
        local s = o.scale
        local escalaOk = ((abs (s.x - 1.0)) < 0.001) and ((abs (s.y - 1.0)) < 0.001) and ((abs (s.z - 1.0)) < 0.001)
        if temXForm or not escalaOk do
            append problemas (o.name + (if temXForm then " [XForm no stack]" else "") + (if not escalaOk then (" [scale " + s as string + "]") else ""))
    )
    InLab_RegistrarVerif "V-12" "Transform resetado (XForm colapsado, scale 100%)" (problemas.count == 0) (if problemas.count == 0 then "OK" else (problemas as string)) critico:true
)
