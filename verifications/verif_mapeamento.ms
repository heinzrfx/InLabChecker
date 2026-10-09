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
 05/10/2026 — correções da revisão final do branch:
   - BUG achado no piloto (Auto UV real): o Unwrap temporário media o canal 1,
     não o 3. O setMapChannel só vale ANTES da primeira avaliação do stack: com
     select/setCurrentObject antes dele o Unwrap já carregou o canal 1 e o
     setMapChannel 3 não recarrega (numberVertices fica igual). Os testes
     antigos não pegavam porque copiavam o canal 1 para o 3. Agora o
     setMapChannel 3 vem logo depois do addModifier (testado com redraw ligado
     e desligado), e há testes com um canal limpo e o outro sobreposto.
     Antes da correção: Mentha, 11 de 11 peças reprovadas (Box002: 8687 faces)
     com um Auto UV que se mede com 0 sobreposições.
   - Piloto depois da correção, Auto UV real em TODAS as peças (arquivos sem
     salvar): Poltrona Mentha (11 peças, 34 mil tri) Auto UV 88 s, V-14 passa,
     V-15 PASSA em 1,0 s; Mesa Lateral Nambu (14 peças, 40 mil tri) Auto UV 34 s,
     V-14 passa, V-15 PASSA em 1,2 s. Nenhum Unwrap temporário sobra (só os 11/14
     do próprio Auto UV), seleção e painel voltam. O log do Auto UV acusou 366
     faces sobrepostas na Shape018 (InLab_MedirUV, critério geométrico próprio);
     o selectOverlappedFaces nativo dá 0 nela (Unwrap vivo e V-15 concordam).
   - suspendEditing/resumeEditing: agora alwaysSuspend:true nos dois. Sondagem
     (8 peças com canal 3): saindo do Create ou do Modify o tempo é o mesmo
     (3,5 s, 0,44 s/peça; sem suspendEditing 8,8 s, 1,1 s/peça) e o painel Modify
     segue editável (getCurrentObject = Editable_mesh, modificador editável).
     O padrão (alwaysSuspend:false) também funcionou nesta build, mas só
     alwaysSuspend:true garante o par sem depender do painel aberto. Um suspend
     SEM resume deixa o painel morto (getCurrentObject = UndefinedClass) até
     um resumeEditing alwaysSuspend:true; há teste para isso.
   - V-14 e V-15 só contam vértices de mapa USADOS por faces
     (meshop.getMapVertsUsingMapFace): vértice órfão não gera falso FAIL.
   - V-14 distingue "colapsado num ponto" (largura e altura ≤ 1e-6) de
     "colapsado numa linha" (só um eixo).
   - Abrir/fechar grupos dentro de with undo off; redrawViews() após reativar
     o redesenho.

 09/10/2026 — V-15 tolera o imperceptível (decisão do usuário): o nativo
 reprovava a Poltrona Zac (Shape: 94 faces) e o Puff Pol (Shape03: 6) por
 encosto entre faces minúsculas, abaixo de ~3 px² e entrando menos de meio
 pixel umas nas outras. A contagem passa a ser InLab_UV_SobrepostasNativas
 (verif_uv.ms): o nativo marca, o eixo separador a meio pixel a 1024
 confirma. O log do Auto UV usa a mesma função.
================================================================================
*/

global INLAB_TEXTURA_MIN_PX = 2048     -- V-16: menor lado mínimo
global INLAB_UV_FORA_TOL = 1e-4        -- V-15: tolerância do 0–1 no canal 3

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
                -- Só vértices de mapa usados por alguma face (órfão não conta).
                local usados = meshop.getMapVertsUsingMapFace m 1 #{1..m.numfaces}
                local nv = usados.numberSet
                local uMin = 1e30
                local uMax = -1e30
                local vMin = 1e30
                local vMax = -1e30
                for v in usados do
                (
                    local p = meshop.getMapVert m 1 v
                    if p.x < uMin do uMin = p.x
                    if p.x > uMax do uMax = p.x
                    if p.y < vMin do vMin = p.y
                    if p.y > vMax do vMax = p.y
                )
                local semLargura = (uMax - uMin) <= 1e-6
                local semAltura = (vMax - vMin) <= 1e-6
                if nv == 0 or (semLargura and semAltura) then
                    append itens (o.name + ": UV colapsado num ponto (canal 1)")
                else if semLargura or semAltura do
                    append itens (o.name + ": UV colapsado numa linha (canal 1)")
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
        InLab_RegistrarVerif "V-14" titulo false (InLab_ListaResumida (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-14" titulo false ("não medido: " + InLab_ListaResumida naoMedidos) critico:false
    else
        InLab_RegistrarVerif "V-14" titulo true ("UV no canal 1 em " + grupos.count as string + " peça(s)") critico:true
)

-- Vértices de mapa do canal fora do 0–1 (tolerância INLAB_UV_FORA_TOL).
fn InLab_Mapa_ForaDe01 m canal =
(
    local n = 0
    local lo = -INLAB_UV_FORA_TOL
    local hi = 1.0 + INLAB_UV_FORA_TOL
    -- Só vértices usados por faces: órfão fora do 0–1 não reprova.
    for v in (meshop.getMapVertsUsingMapFace m canal #{1..m.numfaces}) do
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
        with undo off ( grupos = InLab_AbrirGruposAcima o )
        uw = Unwrap_UVW()
        with undo off
        (
            addModifier o uw
            -- O canal TEM de ser escolhido aqui, antes de qualquer avaliação do
            -- stack (select, painel): depois disso o setMapChannel não recarrega e
            -- o Unwrap segue medindo o canal 1 (sondagem de 05/10/2026).
            uw.setMapChannel 3
            if falharTeste do throw "falha simulada (teste)"
            select o
            max modify mode
            modPanel.setCurrentObject uw
            -- 09/10/2026: nativo confirmado a meio pixel (verif_uv.ms); o
            -- encosto imperceptível entre faces minúsculas não reprova.
            n = InLab_UV_SobrepostasNativas uw
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
    try ( with undo off ( InLab_FecharGrupos grupos ) )
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
        -- alwaysSuspend:true: suspende e retoma SEMPRE em par, com o painel Modify aberto ou não.
        try ( suspendEditing alwaysSuspend:true ) catch ()
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
        try ( resumeEditing alwaysSuspend:true ) catch ()
        try ( enableSceneRedraw(); redrawViews() ) catch ()
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
        InLab_RegistrarVerif "V-15" titulo false (InLab_ListaResumida (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-15" titulo false ("não medido: " + InLab_ListaResumida naoMedidos) critico:false
    else if comCanal.count == 0 then
        InLab_RegistrarVerif "V-15" titulo true "não se aplica: nenhuma peça com UV de bake (canal 3)" critico:true
    else
        InLab_RegistrarVerif "V-15" titulo true ("canal 3 sem sobreposição e dentro do 0–1 em " + comCanal.count as string + " peça(s)" + \
            (if semCanal.count > 0 then (" · não se aplica a " + semCanal.count as string + " peça(s) sem canal 3") else "")) critico:true
)

-- V-16 · Resolução das texturas usadas pelas peças (advertência). Textura sem
-- arquivo ou com resolução ilegível é "não medida". O que só o ambiente usa
-- fica de fora (InLab_CheckTexture escopo:#selecao).
fn InLab_V16_ResolucaoTexturas objetos =
(
    local titulo = "Resolução das texturas (≥ " + INLAB_TEXTURA_MIN_PX as string + ")"
    local infos = InLab_CheckTexture escopo:#selecao objs:objetos logar:false
    if infos.count == 0 then
        InLab_RegistrarVerif "V-16" titulo true "nenhuma textura nas peças" critico:false
    else
    (
        local baixas = #()
        local naoMedidas = #()
        for t in infos do
        (
            local nome = filenameFromPath t.arquivo
            if not t.existe then append naoMedidas (nome + ": não medida (arquivo não encontrado)")
            else if t.resolucao == undefined then append naoMedidas (nome + ": não medida (resolução ilegível)")
            else if (amin t.resolucao.x t.resolucao.y) < INLAB_TEXTURA_MIN_PX do
                append baixas (nome + ": " + (t.resolucao.x as integer) as string + "x" + (t.resolucao.y as integer) as string)
        )
        local ok = baixas.count == 0 and naoMedidas.count == 0
        InLab_RegistrarVerif "V-16" titulo ok \
            (if ok then (infos.count as string + " textura(s) com " + INLAB_TEXTURA_MIN_PX as string + " px ou mais") else InLab_ListaResumida (baixas + naoMedidas)) critico:false
    )
)
