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
 05/10/2026 — decisões da V-15 (implementação):
   - O Unwrap só entra em peça COM canal 3, conferido no snapshot antes.
   - Contagem em "faces" (Editable Poly = polígonos), nunca "triângulos".
   - InLab_Mapa_SobrepostasUnwrap nunca lança; falha por peça vira "não
     medido" (passou:false, critico:false) e o laço segue; o Unwrap sai sempre
     e os grupos abertos voltam a fechar mesmo se a abertura/fechamento falhar.
   - Seleção, painel, redraw e suspendEditing restaurados passo a passo.
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

-- Vértices de mapa do canal fora do 0–1 (tolerância INLAB_UV_FORA_TOL).
fn InLab_Mapa_ForaDe01 m canal =
(
    local n = 0
    local lo = -INLAB_UV_FORA_TOL
    local hi = 1.0 + INLAB_UV_FORA_TOL
    for v = 1 to (meshop.getNumMapVerts m canal) do
    (
        local p = meshop.getMapVert m canal v
        if p.x < lo or p.x > hi or p.y < lo or p.y > hi do n += 1
    )
    n
)

-- Faces sobrepostas no canal 3 por um Unwrap_UVW temporário. Devolve o número
-- de faces (polígonos no Editable Poly) ou undefined se a medição falhou. NUNCA
-- lança: abertura de grupo, criação do Unwrap, medição, remoção e fechamento
-- têm try próprio, e o Unwrap sai SEMPRE. Quem chama cuida de seleção, painel e
-- redesenho. falharTeste: só para teste.
fn InLab_Mapa_SobrepostasUnwrap o falharTeste:false =
(
    local n = undefined
    local uw = undefined
    -- Grupos fechados acima do nó, anotados ANTES de abrir: se a abertura
    -- lançar no meio, ainda sabemos o que fechar de volta.
    local fechadosAntes = #()
    try
    (
        local pai = o.parent
        while pai != undefined do
        (
            if isGroupHead pai and not (isOpenGroupHead pai) do append fechadosAntes pai
            pai = pai.parent
        )
    )
    catch ()
    local grupos = #()
    try
    (
        grupos = InLab_AbrirGruposAcima o
        uw = Unwrap_UVW()
        with undo off
        (
            addModifier o uw
            if falharTeste do throw "falha simulada (teste)"
            select o
            max modify mode
            modPanel.setCurrentObject uw
            uw.setMapChannel 3
            uw.selectOverlappedFaces()
            n = (uw.getSelectedFaces()).numberSet
        )
    )
    catch
    (
        n = undefined
        InLab_Log (o.name + ": V-15 não mediu a sobreposição (" + getCurrentException() + ").") tipo:#warn
    )
    if uw != undefined do
    (
        try
        (
            with undo off ( for m in o.modifiers where m == uw do deleteModifier o m )
        )
        catch
        (
            InLab_Log (o.name + ": não removi o Unwrap temporário da V-15 (" + getCurrentException() + ") — apague à mão.") tipo:#err
        )
    )
    try ( InLab_FecharGrupos grupos )
    catch
    (
        InLab_Log (o.name + ": V-15 não fechou os grupos (" + getCurrentException() + "); fechando direto.") tipo:#warn
        for g in fechadosAntes do try ( if isValidNode g do setGroupOpen g false ) catch ()
    )
    -- Se a abertura lançou no meio, grupos ficou vazio: fecha o que foi anotado.
    if grupos.count == 0 do
        for g in fechadosAntes do try ( if isValidNode g and (isOpenGroupHead g) do setGroupOpen g false ) catch ()
    n
)

-- V-15 · UV de bake (canal 3): sem sobreposição e dentro do 0–1. Peça sem
-- canal 3 é "não se aplica" e nunca recebe o Unwrap.
fn InLab_V15_UVBake objetos falharTeste:false =
(
    local titulo = "UV de bake sem sobreposição (canal 3)"
    local itens = #()
    local naoMedidos = #()
    local semCanal = #()
    local comCanal = #()
    for g in (InLab_DeduplicarInstancias objetos) do
    (
        local o = g.no
        local m = undefined
        try
        (
            m = snapshotAsMesh o
            if (InLab_UV_TemCanal m 3) and m.numfaces > 0 then
            (
                append comCanal o
                local fora = InLab_Mapa_ForaDe01 m 3
                if fora > 0 do append itens (o.name + ": " + fora as string + " vértice(s) de UV fora do 0–1 no canal 3")
            )
            else append semCanal o.name
        )
        catch
        (
            append naoMedidos (o.name + ": não analisado (" + getCurrentException() + ")")
            InLab_Log (o.name + ": V-15 não leu o canal 3 (" + getCurrentException() + ").") tipo:#err
        )
        if m != undefined do try ( delete m ) catch ()
    )
    if comCanal.count > 0 do
    (
        local sel = for s in selection collect s
        local modo = getCommandPanelTaskMode()
        local tratados = #()
        disableSceneRedraw()
        try ( suspendEditing() ) catch ()
        try
        (
            for o in comCanal do
            (
                append tratados o
                try
                (
                    local n = InLab_Mapa_SobrepostasUnwrap o falharTeste:falharTeste
                    if n == undefined then append naoMedidos (o.name + ": sobreposição não medida (ver log)")
                    else if n > 0 do append itens (o.name + ": " + n as string + " face(s) sobreposta(s) no canal 3")
                )
                catch
                (
                    append naoMedidos (o.name + ": sobreposição não medida (" + getCurrentException() + ")")
                    InLab_Log (o.name + ": V-15 " + getCurrentException()) tipo:#err
                )
            )
        )
        catch
        (
            InLab_Log ("V-15: " + getCurrentException()) tipo:#err
            for o in comCanal where findItem tratados o == 0 do
                append naoMedidos (o.name + ": sobreposição não medida (interrompida)")
        )
        -- Restauração: cada passo guardado, para um não pular o seguinte.
        try ( resumeEditing() ) catch ()
        try ( enableSceneRedraw() ) catch ()
        try
        (
            with undo off
            (
                clearSelection()
                local vivos = for s in sel where isValidNode s collect s
                if vivos.count > 0 do select vivos
            )
        )
        catch ( InLab_Log ("V-15: não restaurei a seleção (" + getCurrentException() + ")") tipo:#warn )
        try ( setCommandPanelTaskMode modo ) catch ( InLab_Log ("V-15: não restaurei o painel (" + getCurrentException() + ")") tipo:#warn )
    )
    if itens.count > 0 then
        InLab_RegistrarVerif "V-15" titulo false (InLab_Mapa_Lista (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-15" titulo false ("não medido: " + InLab_Mapa_Lista naoMedidos) critico:false
    else if comCanal.count == 0 then
        InLab_RegistrarVerif "V-15" titulo true "não se aplica: nenhuma peça com UV de bake (canal 3)" critico:true
    else
        InLab_RegistrarVerif "V-15" titulo true ("canal 3 sem sobreposição e dentro do 0–1 em " + comCanal.count as string + " peça(s)" + \
            (if semCanal.count > 0 then (" · não se aplica a " + semCanal.count as string + " peça(s) sem canal 3") else "")) critico:true
)
