/*
================================================================================
 verifications\verif_mapeamento.ms — Grupo 5 · V-14, V-15, V-16 (UV e texturas)
--------------------------------------------------------------------------------
 Spec: docs\superpowers\specs\2026-10-05-verif-uv-grupo5-design.md (issue #101).

 DOIS CANAIS (fn_autouv.ms): canal 1 = UV do material, em escala real (repete
 de propósito, sai do 0–1); canal 3 = UV 0–1 empacotado para bake e AO,
 opcional no v1 (decisão de 05/10/2026).
   V-14: canal 1 presente e não colapsado num ponto.
   V-15: só nas peças COM canal 3 — sem sobreposição e dentro do 0–1.
   V-16: texturas das peças com o menor lado ≥ 2048 px (advertência).

 05/10/2026 — sondagem (Max 2024):
   - Sobreposição pelo Unwrap_UVW temporário (selectOverlappedFaces): 1,3 s em
     262 mil triângulos, contra ~0,27 ms por triângulo em InLab_MedirUV.
   - Num canal INEXISTENTE o Unwrap monta um mapeamento padrão e acusa
     sobreposição (12 de 12 num Box): o canal 3 é conferido no snapshot ANTES.
   - No Editable Poly, getSelectedFaces conta POLÍGONOS: a mensagem diz "faces".
   - O Unwrap mexe na seleção e no painel (Create → Modify): os dois são
     restaurados. disableSceneRedraw + suspendEditing: 1 s → 0,37 s por peça,
     mesmo resultado. Mede em instância, membro de grupo fechado, peça oculta,
     congelada e com modificador; getSaveRequired não muda.
================================================================================
*/

global INLAB_TEXTURA_MIN_PX = 2048     -- V-16: menor lado mínimo
global INLAB_UV_FORA_TOL = 1e-4        -- V-15: tolerância do 0–1 no canal 3

-- "a; b; c" com no máximo `maximo` itens e "… (+N)" no fim.
fn InLab_Mapa_Lista itens maximo:8 =
(
    local txt = ""
    for i = 1 to (amin itens.count maximo) do txt += (if i > 1 then "; " else "") + itens[i]
    if itens.count > maximo do txt += "; … (+" + (itens.count - maximo) as string + ")"
    txt
)

-- V-14 · UV presente no canal 1 (uma vez por grupo de instâncias).
fn InLab_V14_UVPresente objetos =
(
    local titulo = "UV presente (canal 1)"
    local itens = #()
    local naoMedidos = #()
    local grupos = InLab_DeduplicarInstancias objetos
    for g in grupos do
    (
        local o = g.no
        local m = undefined
        try
        (
            m = snapshotAsMesh o
            if not (InLab_UV_TemCanal m 1) then append itens (o.name + ": sem UV no canal 1")
            else
            (
                local nv = meshop.getNumMapVerts m 1
                local uMin = 1e30
                local uMax = -1e30
                local vMin = 1e30
                local vMax = -1e30
                for v = 1 to nv do
                (
                    local p = meshop.getMapVert m 1 v
                    if p.x < uMin do uMin = p.x
                    if p.x > uMax do uMax = p.x
                    if p.y < vMin do vMin = p.y
                    if p.y > vMax do vMax = p.y
                )
                if nv == 0 or (uMax - uMin) <= 1e-6 or (vMax - vMin) <= 1e-6 do
                    append itens (o.name + ": UV colapsado num ponto (canal 1)")
            )
        )
        catch
        (
            append naoMedidos (o.name + ": não analisado (" + getCurrentException() + ")")
            InLab_Log (o.name + ": V-14 não leu o UV (" + getCurrentException() + ").") tipo:#err
        )
        if m != undefined do try ( delete m ) catch ()
    )
    if itens.count > 0 then
        InLab_RegistrarVerif "V-14" titulo false (InLab_Mapa_Lista (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-14" titulo false ("não medido: " + InLab_Mapa_Lista naoMedidos) critico:false
    else
        InLab_RegistrarVerif "V-14" titulo true ("UV no canal 1 em " + grupos.count as string + " peça(s)") critico:true
)
