/*
================================================================================
 verifications\verif_geometria.ms — V-11/12 e EX-01
--------------------------------------------------------------------------------
 Stack de modificadores (V-11) e transform resetado (V-12). As verificações
 pesadas de malha (V-07, V-08, V-09, V-10, V-13) ficam em verif_malha.ms
 (05/10/2026, issue #102).

 28/09/2026 (issue #35): EX-01 (extra, fora da numeração da spec) — objeto
 oculto ou não renderizável na cena vira advertência. Ele continua contando
 na V-03/V-05 (o glTF pode exportá-lo); o aviso é para apagar antes da entrega.
================================================================================
*/

-- V-11 · Stack colapsado: qualquer modificador residual reprova (o asset
-- final não pode depender de avaliação de stack no export).
fn InLab_V11_Modificadores objetos =
(
    local com = for o in objetos where o.modifiers.count > 0 collect (o.name + " [" + o.modifiers.count as string + " mod.]")
    InLab_RegistrarVerif "V-11" "Stack de modificadores colapsado" (com.count == 0) (if com.count == 0 then "todos os stacks limpos" else (com as string)) critico:true
)

-- EX-01 · Objetos ocultos ou não renderizáveis (também pela camada).
fn InLab_VEx01_Ocultos objetos =
(
    local fora = for o in objetos where not (InLab_VaiProGLB o) collect o.name
    InLab_RegistrarVerif "EX-01" "Objeto oculto na cena" (fora.count == 0) \
        (if fora.count == 0 then "nenhum objeto oculto" else ("apagar antes da entrega (contam no peso e nos polígonos): " + fora as string)) critico:false
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
