/*
================================================================================
 verifications\verif_animacao.ms — V-30 · [V-26/31/32/33/34/38/40: Grupo 4]
--------------------------------------------------------------------------------
 Nesta entrega: presença de keyframes (V-30). Hierarquia, pivôs de animação,
 attach vinculado e estado inicial entram no Grupo 4.
================================================================================
*/

-- true se o objeto tem keyframes em posição, rotação ou escala.
fn InLab_ObjetoTemKeys o =
(
    local achou = false
    try ( if o.position.controller.keys.count > 0 do achou = true ) catch()
    try ( if o.rotation.controller.keys.count > 0 do achou = true ) catch()
    try ( if o.scale.controller.keys.count    > 0 do achou = true ) catch()
    achou
)

-- V-30 · Famílias animadas exigem keyframes no arquivo (gltf.animations não
-- vazio no GLB). Família estática COM animação vira advertência.
fn InLab_V30_Keyframes cfg objetos =
(
    local animados = for o in objetos where InLab_ObjetoTemKeys o collect o.name
    if cfg.animado then
        InLab_RegistrarVerif "V-30" "Keyframes de animação presentes" (animados.count > 0) (if animados.count > 0 then (animados as string) else "família animada SEM keyframes no arquivo") critico:true
    else
        InLab_RegistrarVerif "V-30" "Keyframes de animação presentes" (animados.count == 0) (if animados.count == 0 then "família estática — sem animação, correto" else ("família estática COM keyframes: " + animados as string)) critico:false
)
