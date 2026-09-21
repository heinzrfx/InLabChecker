/*
================================================================================
 functions\fn_autouv.ms — FUNÇÃO 2 · "Auto UV" (reescrita · bug 2, 13/Jul ·
 canal de bake, 18/Set)
--------------------------------------------------------------------------------
 18/Set (issue #1, Fase 2): o Auto UV não mexe mais no canal 1. O canal 1 é do
 material (UV em escala real) e fica intacto. O 0–1 empacotado para bake de
 textura e AO vai para o canal 3, como no ArchToolz 2026. A base sem
 modificadores vira Editable_mesh (uma cópia da base original fica guardada
 para o Reverter) e o Unwrap_UVW fica vivo no stack. O padding sai da
 resolução do bake: 4 px a 1K, 8 px a 2K, 16 px a 4K.
 Pipeline PROVISÓRIO até as Fases 3–4: Flatten pelo ângulo da UI → pack
 (sem relax, ver 21/Set abaixo). Cada objeto sai no log com as métricas de verifications\verif_uv.ms e
 com a checagem de que o canal 1 não mudou.
 O Clean UV passa a remover só os modificadores do canal 3. Antes ele apagava
 qualquer UVW, inclusive o UVW Map do material no canal 1.

 21/Set (causa do baseline inválido da Fase 1): "select o" num membro de grupo
 FECHADO seleciona o grupo inteiro, e o modPanel.addModToSelection aplicava UM
 Unwrap instanciado em todos os membros (26 peças da cadeira num 0–1 só;
 numberPolygons devolvia a contagem desse Unwrap compartilhado). Agora os
 grupos fechados acima do nó são abertos só durante o Unwrap e fechados de
 novo no final, e o modificador entra com addModifier no próprio nó.
 O nº de faces do Unwrap é conferido com o do objeto e a diferença vai pro log.

 13/Jul (bug 2): o relax falhava silenciosamente (assinatura errada engolida
 por try/catch). Ele roda SEMPRE, com cadeia de 3 assinaturas testadas em
 ordem, e o log registra QUAL rodou (ou acusa "relax indisponível").
 21/Set: a 1ª assinatura rodava com lockEdges = false, e isso colapsava as
 ilhas em linhas (área UV ~0). Agora as bordas ficam travadas.
 21/Set (decidido com os números da cadeira inteira): o relax SAIU
 do pipeline provisório. Sobre o flatten (projeção plana, distorção ≤ 1,7×)
 ele só piora: mesmo com as bordas travadas, dobrou faces em 8 de 125
 objetos (sobrepostas + invertidas, distorção até 285 000×). Sem ele, os 125
 saem sem inversão. InLab_TentarRelax fica para a Fase 4 (unfold conforme).
 O log por objeto sai #warn quando a medição acusa sobreposição, inversão
 (fora de objeto espelhado) ou UV fora do 0–1.

 21/Set (instâncias): o convertToMesh numa instância tornava ÚNICAS todas as
 instâncias, até as não selecionadas, e o Reverter não refazia o vínculo.
 Decidido manter a instância: base instanciada não é convertida (#warn), o
 Unwrap entra no stack compartilhado (todas as instâncias ficam com o mesmo
 canal 3) e as outras instâncias da mesma rodada são puladas. O registro de
 uma instância vale para todas (rodar de novo substitui, Reverter tira).

 21/Set (gutter): o pack aplica o espaçamento antes de reescalar para o 0–1,
 e o gutter real saía 25–30% menor que o padding (0,0027–0,0031 para 0,0039).
 Depois do pack, o gutter é medido e, se faltar, até 3 repassadas com o
 espaçamento aumentado na proporção (teto INLAB_UV_ESPACAMENTO_MAX) corrigem.
 Barras longas e finas precisam de 3–5× o padding. Vale a melhor repassada que
 não derruba o aproveitamento abaixo de 70%; senão fica o pack original e o
 log avisa (centenas de ilhas, ex.: ângulo 10° no Box008).

 21/Set (desempenho, " Armchair pillow 02" com 306 mil triângulos travava o
 Max): o Auto UV gastava ~15 min por objeto em verificações de MaxScript
 (InLab_MedirUV 186 s × até 5, assinatura do canal 1 7 s × 2), contra ~40 s
 do flatten nativo. Agora:
   - canal 1: confere que o Unwrap está no canal 3 e compara a contagem de
     vértices/faces de mapa (0,1 s). A assinatura completa fica nos testes;
   - malha acima de INLAB_UV_MEDIR_MAX_FACES: sem pack extra (o flatten já
     empacota, com espaçamento × INLAB_UV_FOLGA_ESPACAMENTO), sem correção
     medida do gutter e sem métricas completas; só a sobreposição nativa
     (selectOverlappedFaces, 0,1 s) vai para o log;
   - malha pequena (peças da cadeira: ~3 s cada): continua como antes.
 Os valores unfold* (1024, 1 px...) que a issue lista para o ArchToolz são os
 padrões de fábrica de um Unwrap novo, e o Unfold3DPack ignora unfoldRoomSpace
 (gutter ~1 px com qualquer valor), por isso ele não substitui o pack.

 UNDO: undo "InLab ..." + registro dedicado (InLab_UltimoAutoUV) para o
 Reverter, que alcança além do Ctrl+Z.
================================================================================
*/

-- Pré-declarados: definidos em verifications\verif_uv.ms, carregado depois.
global InLab_MedirUV, InLab_AssinaturaCanal, InLab_UVMetricasTexto

-- ===== PADRÃO InLab: canais de UV (ponto único de mudança) =====
global INLAB_CANAL_UV_MATERIAL = 1  -- UV do material, em escala real: o Auto UV nunca altera
global INLAB_CANAL_UV_BAKE = 3      -- 0–1 empacotado por objeto, para bake de textura e AO
global INLAB_UV_RESOLUCOES = #(1024, 2048, 4096) -- mesma ordem do dropdown da UI
global INLAB_UV_ESPACAMENTO_MAX = 8.0 -- teto da correção do gutter, em múltiplos do padding
-- Acima disto (triângulos) a malha é "grande": sem pack extra, sem correção
-- medida do gutter e sem métricas completas no log (ver cabeçalho, 21/Set).
global INLAB_UV_MEDIR_MAX_FACES = 30000
-- Folga do espaçamento do flatten em malha grande: o gutter real sai ~0,7–0,8×
-- o espaçamento pedido nas peças medidas.
global INLAB_UV_FOLGA_ESPACAMENTO = 1.4

-- Registro de um Auto UV aplicado (para o Reverter dedicado).
struct AutoUVRecord
(
    no,            -- nó da cena
    modificador,   -- instância exata do Unwrap_UVW adicionada (a mais recente)
    baseOriginal   -- cópia da base de antes do convertToMesh (undefined se não converteu)
)

-- Um registro por objeto, acumulado até o Reverter. Se o Auto UV rodar de
-- novo no mesmo objeto, o registro é reaproveitado e a base original
-- continua sendo a da primeira vez.
global InLab_UltimoAutoUV = #()

global InLab_TentarRelax, InLab_PaddingUV, InLab_AutoUV_PrepararBase, InLab_AutoUV_Registro
global InLab_AbrirGruposAcima, InLab_FecharGrupos, InLab_Instancias, InLab_ContagemCanal
global InLab_AutoUV, InLab_CanalDoModificadorUV, InLab_CleanUV, InLab_ReverterAutoUV

--------------------------------------------------------------------------------
-- RELAX com cadeia de assinaturas (a causa do bug 2 era confiar numa só):
-- tenta as variantes documentadas em ordem e retorna o nome da que rodou,
-- ou undefined se nenhuma existir nesta build.
-- Sem uso desde 21/Set (ver cabeçalho): volta na Fase 4, depois do unfold.
--------------------------------------------------------------------------------
fn InLab_TentarRelax uvw =
(
    local usado = undefined
    -- lockEdges TEM que ser true: com as bordas soltas o relax encolhe cada
    -- ilha até virar uma linha (aproveitamento 65% → 0% numa caixa, 21/Set).
    try ( uvw.relax 100 0.1 true true ; usado = "relax(100, 0.1, bordas travadas)" ) catch()
    if usado == undefined do
        try ( uvw.RelaxOneClick() ; usado = "RelaxOneClick" ) catch()
    if usado == undefined do
        try ( uvw.relaxByFaceAngle 100 0.05 0.05 false ; usado = "relaxByFaceAngle" ) catch()
    usado
)

--------------------------------------------------------------------------------
-- Gutter entre ilhas, em unidades de UV: 4 px a 1K, 8 px a 2K, 16 px a 4K
-- (issue #1). Dá ~0,0039 em qualquer resolução.
--------------------------------------------------------------------------------
fn InLab_PaddingUV resolucao =
(
    local px = case resolucao of
    (
        2048: 8.0
        4096: 16.0
        default: 4.0
    )
    px / resolucao
)

--------------------------------------------------------------------------------
-- Converte a base para Editable_mesh (como o ArchToolz) e devolve uma cópia
-- da base original para o Reverter. Com modificadores no stack a base fica
-- como está, porque converter exigiria colapsar (proibido pela issue #1).
-- Base instanciada também fica: converter quebraria todas as instâncias.
--------------------------------------------------------------------------------
-- Nº de vértices e faces de mapa do canal, "nV/nF" (ou "sem canal"). Guarda
-- barata do canal 1 no Auto UV: a assinatura completa (InLab_AssinaturaCanal)
-- leva ~7 s numa malha de 300 mil faces e fica só nos testes.
fn InLab_ContagemCanal o canal =
(
    local m = snapshotAsMesh o
    if canal < meshop.getNumMaps m and meshop.getMapSupport m canal then
        (meshop.getNumMapVerts m canal) as string + "/" + (meshop.getNumMapFaces m canal) as string
    else
        "sem canal"
)

-- Nós que compartilham o objeto com "o" (inclui o próprio "o").
fn InLab_Instancias o =
(
    local inst = #()
    InstanceMgr.GetInstances o &inst
    if inst.count == 0 do inst = #(o)
    inst
)

fn InLab_AutoUV_PrepararBase o =
(
    local original = undefined
    local nInst = (InLab_Instancias o).count
    if classOf o.baseObject != Editable_mesh do
    (
        if nInst > 1 then
            InLab_Log (o.name + ": instanciado (" + nInst as string + " nós) — base " + (classOf o.baseObject) as string +
                       " mantida e Unwrap compartilhado: todas as instâncias ficam com o mesmo canal " +
                       INLAB_CANAL_UV_BAKE as string + ".") tipo:#warn
        else if o.modifiers.count > 0 then
            InLab_Log (o.name + ": base " + (classOf o.baseObject) as string + " mantida — há " +
                       o.modifiers.count as string + " modificador(es) no stack e converter colapsaria.") tipo:#warn
        else
        (
            original = copy o.baseObject
            convertToMesh o
        )
    )
    original
)

--------------------------------------------------------------------------------
-- Abre os grupos FECHADOS acima do nó e devolve os que abriu. Com o grupo
-- fechado, "select o" seleciona o grupo inteiro e o painel Modify passa a
-- operar em todos os membros. InLab_FecharGrupos desfaz.
--------------------------------------------------------------------------------
fn InLab_AbrirGruposAcima o =
(
    local abertos = #()
    local p = o.parent
    while p != undefined do
    (
        if isGroupHead p and not (isOpenGroupHead p) do
        (
            setGroupOpen p true
            append abertos p
        )
        p = p.parent
    )
    abertos
)

fn InLab_FecharGrupos grupos =
(
    for g in grupos where isValidNode g do setGroupOpen g false
)

-- Registro do nó ou de qualquer instância dele (o Unwrap é compartilhado).
fn InLab_AutoUV_Registro o =
(
    local achado = undefined
    local inst = InLab_Instancias o
    for r in InLab_UltimoAutoUV where isValidNode r.no do
        if achado == undefined and findItem inst r.no > 0 do achado = r
    achado
)

--------------------------------------------------------------------------------
-- AUTO UV sobre a seleção. Grava no canal INLAB_CANAL_UV_BAKE.
--------------------------------------------------------------------------------
fn InLab_AutoUV objs angulo:55.0 seamsOcultas:true resolucao:1024 =
(
    local processados = 0
    local padding = InLab_PaddingUV resolucao
    local normais = #([1,0,0], [-1,0,0], [0,1,0], [0,-1,0], [0,0,1], [0,0,-1])
    InLab_Log ("Auto UV: canal " + INLAB_CANAL_UV_BAKE as string + " · ângulo " + (formattedPrint angulo format:".0f") +
               "° · " + resolucao as string + " px (padding " + (formattedPrint padding format:".4f") + ")")
    if seamsOcultas do
        InLab_Log "Auto UV: \"Preferir seams em regiões ocultas\" ainda não tem efeito (entra na Fase 3 da issue #1)." tipo:#warn

    undo "InLab AutoUV" on
    (
        max modify mode
        local feitosNaRodada = #() -- nós já cobertos nesta rodada (inclui instâncias)

        for o in objs where InLab_EhGeometria o do
        (
            if (getPolygonCount o)[1] == 0 then
                InLab_Log (o.name + ": sem faces — ignorado.") tipo:#warn
            else if findItem feitosNaRodada o > 0 then
            (
                InLab_Log (o.name + ": instância de um objeto já processado — recebeu o mesmo Unwrap.")
                processados += 1
            )
            else
            (
                local canal1Antes = InLab_ContagemCanal o INLAB_CANAL_UV_MATERIAL

                -- Rodar de novo substitui o Unwrap anterior em vez de empilhar.
                local rec = InLab_AutoUV_Registro o
                if rec == undefined then
                (
                    rec = AutoUVRecord no:o baseOriginal:(InLab_AutoUV_PrepararBase o)
                    append InLab_UltimoAutoUV rec
                )
                else if rec.modificador != undefined do
                    try ( deleteModifier o rec.modificador )
                    catch ( InLab_Log (o.name + ": Unwrap anterior do Auto UV não encontrado (removido à mão?).") tipo:#warn )

                -- Grupo fechado: abre durante o Unwrap para o select pegar só o nó.
                local gruposAbertos = InLab_AbrirGruposAcima o
                select o
                local uvw = Unwrap_UVW()
                uvw.name = "InLab AutoUV"
                addModifier o uvw
                modPanel.setCurrentObject uvw
                rec.modificador = uvw

                local falhou = false
                if selection.count != 1 do
                (
                    InLab_Log (o.name + ": seleção com " + selection.count as string + " nós em vez de 1 — Auto UV cancelado neste objeto.") tipo:#err
                    falhou = true
                )
                if not falhou do
                    try ( uvw.setMapChannel INLAB_CANAL_UV_BAKE )
                    catch ( InLab_Log (o.name + ": falha em setMapChannel.") tipo:#err ; falhou = true )
                -- Guarda principal do canal 1: o Unwrap TEM que estar no canal 3.
                if not falhou and (uvw.getMapChannel()) != INLAB_CANAL_UV_BAKE do
                (
                    InLab_Log (o.name + ": Unwrap ficou no canal " + (uvw.getMapChannel()) as string + " em vez do " +
                               INLAB_CANAL_UV_BAKE as string + " — Auto UV cancelado neste objeto.") tipo:#err
                    falhou = true
                )

                local nPolysObj = (getPolygonCount o)[1]
                local nPolysUV = nPolysObj
                try ( nPolysUV = uvw.numberPolygons() )
                catch ( InLab_Log (o.name + ": numberPolygons indisponível — usando " + nPolysObj as string + " faces do objeto.") tipo:#warn )
                if nPolysUV != nPolysObj do
                    InLab_Log (o.name + ": Unwrap vê " + nPolysUV as string + " faces e o objeto tem " + nPolysObj as string + " — conferir o resultado.") tipo:#warn
                if not falhou do
                    try ( uvw.selectFaces #{1..nPolysUV} )
                    catch ( InLab_Log (o.name + ": falha em selectFaces.") tipo:#err ; falhou = true )

                if not falhou do
                (
                    InLab_Log (o.name + ": Auto UV em processamento (a UI pode congelar alguns segundos)...")
                    try ( windows.processPostedMessages() ) catch()

                    ------------------------------------------------------
                    -- 1 · FLATTEN pelo ângulo da UI (provisório até a Fase 3)
                    ------------------------------------------------------
                    local nTris = (GetTriMeshFaceCount o)[1]
                    local grande = nTris > INLAB_UV_MEDIR_MAX_FACES
                    -- Malha grande: o flatten já empacota com folga no espaçamento e
                    -- o pack extra (18 s em 300 mil faces) não roda.
                    local espFlatten = if grande then padding * INLAB_UV_FOLGA_ESPACAMENTO else padding
                    local metodo = undefined
                    try ( uvw.flattenMap angulo normais espFlatten true 0 true true ; metodo = "Flatten " + (formattedPrint angulo format:".0f") + "°" )
                    catch ( InLab_Log (o.name + ": flattenMap falhou — " + getCurrentException()) tipo:#err )

                    if metodo != undefined do
                    (
                        ------------------------------------------------------
                        -- 2 · PACK com o padding da resolução; fallback Unfold3DPack
                        ------------------------------------------------------
                        local packUsado = undefined
                        if grande then
                            packUsado = "pack do flatten (malha grande)"
                        else
                        (
                            try ( uvw.pack 1 padding true true true ; packUsado = "pack recursivo" ) catch()
                            if packUsado == undefined do
                                try ( uvw.Unfold3DPack() ; packUsado = "Unfold3DPack" ) catch()
                            if packUsado == undefined do
                                InLab_Log (o.name + ": pack indisponível — ilhas podem ficar fora do 0-1.") tipo:#warn
                        )

                        -- Correção do gutter: o pack aplica o espaçamento antes de
                        -- reescalar para o 0–1, e o gutter real sai menor que o pedido.
                        -- Até 3 repassadas com o espaçamento aumentado na proporção
                        -- (teto INLAB_UV_ESPACAMENTO_MAX). Vale a melhor que aumentou o
                        -- gutter sem derrubar o aproveitamento abaixo de 70% do inicial;
                        -- no fim o pack é refeito com o espaçamento dela (o pack parte
                        -- do layout atual, então "voltar" = repackar com esse valor).
                        if packUsado == "pack recursivo" do
                        (
                            local m0 = InLab_MedirUV o INLAB_CANAL_UV_BAKE
                            local g0 = m0.gutterMin
                            if g0 != undefined and g0 > 0.0 and g0 < padding * 0.98 do
                            (
                                local melhorEsp = padding, melhorG = g0, esp = padding, gAtual = g0
                                for it = 1 to 3 while melhorG < padding * 0.98 do
                                (
                                    esp = amin (esp * (padding / (amax gAtual 1e-5)) * 1.05) (padding * INLAB_UV_ESPACAMENTO_MAX)
                                    uvw.selectFaces #{1..nPolysUV}
                                    uvw.pack 1 esp true true true
                                    local mi = InLab_MedirUV o INLAB_CANAL_UV_BAKE
                                    gAtual = if mi.gutterMin == undefined then 0.0 else mi.gutterMin
                                    if gAtual > melhorG and mi.aproveitamento >= m0.aproveitamento * 0.7 do
                                    (
                                        melhorG = gAtual
                                        melhorEsp = esp
                                    )
                                )
                                if esp != melhorEsp do
                                (
                                    uvw.selectFaces #{1..nPolysUV}
                                    uvw.pack 1 melhorEsp true true true
                                )
                                if melhorEsp != padding do packUsado += " + gutter corrigido"
                            )
                        )

                        ------------------------------------------------------
                        -- 3 · MEDIÇÃO + guarda do canal 1
                        ------------------------------------------------------
                        if (InLab_ContagemCanal o INLAB_CANAL_UV_MATERIAL) != canal1Antes do
                            InLab_Log (o.name + ": o canal 1 mudou durante o Auto UV — reportar.") tipo:#err
                        if grande then
                        (
                            -- Métricas completas em MaxScript levam ~3 min em 300 mil
                            -- faces. Aqui só a checagem nativa de sobreposição.
                            local nSobre = -1
                            try ( uvw.selectOverlappedFaces() ; nSobre = (uvw.getSelectedFaces()).numberSet ; uvw.selectFaces #{} ) catch()
                            local txtSobre = if nSobre < 0 then "sobreposição não verificada" else "sobrepostas: " + nSobre as string
                            InLab_Log (o.name + (if nSobre != 0 then ": Auto UV com problema no UV (conferir) · " else ": Auto UV OK · ") + metodo +
                                       " → " + packUsado + " · " + nTris as string + " triângulos: métricas completas e gutter não medidos · " + txtSobre) \
                                       tipo:(if nSobre != 0 then #warn else #ok)
                        )
                        else
                        (
                            local met = InLab_MedirUV o INLAB_CANAL_UV_BAKE
                            local comProblema = met == undefined or met.sobrepostas > 0 or met.foraDe01 > 0 or (met.invertidos > 0 and not met.espelhado)
                            if met != undefined and met.gutterMin != undefined and met.gutterMin > 0.0 and met.gutterMin < padding * 0.98 do
                                InLab_Log (o.name + ": gutter " + (formattedPrint met.gutterMin format:".4f") + " abaixo do padding " +
                                           (formattedPrint padding format:".4f") + " — risco de vazamento no bake.") tipo:#warn
                            InLab_Log (o.name + (if comProblema then ": Auto UV com problema no UV (conferir) · " else ": Auto UV OK · ") + metodo +
                                       " → " + (if packUsado != undefined then packUsado else "sem pack") +
                                       " · " + InLab_UVMetricasTexto met) tipo:(if comProblema then #warn else #ok)
                        )
                        processados += 1
                        join feitosNaRodada (InLab_Instancias o)
                    )
                )
                InLab_FecharGrupos gruposAbertos
            )
        )
        try ( select objs ) catch()
    )

    InLab_Log ("Auto UV: " + processados as string + " de " + objs.count as string + " objeto(s).")
    processados
)

--------------------------------------------------------------------------------
-- Canal em que um modificador de UV escreve, ou undefined se não der para
-- ler (quem chama loga).
--------------------------------------------------------------------------------
fn InLab_CanalDoModificadorUV md =
(
    local canal = undefined
    if isKindOf md Unwrap_UVW then
        try ( canal = md.getMapChannel() ) catch()
    else
        for p in #(#mapChannel, #channel, #mapID) while canal == undefined do
            if isProperty md p do canal = getProperty md p
    canal
)

--------------------------------------------------------------------------------
-- CLEAN UV: remove os modificadores de UV do canal de bake e aplica o UVW
-- Mapping Clear nesse canal. Modificadores de outros canais (ex.: o UVW Map
-- do material no canal 1) ficam. O Clear FICA no stack (colapso é decisão do
-- desenhista — V-11 aponta antes do export).
--------------------------------------------------------------------------------
fn InLab_CleanUV objs =
(
    local n = 0
    undo "InLab CleanUV" on
    (
        for o in objs where InLab_EhGeometria o do
        (
            -- De cima para baixo para não invalidar os índices.
            local removidos = 0
            for i = o.modifiers.count to 1 by -1 do
            (
                local md = o.modifiers[i]
                local nomeCls = (classof md) as string
                if (matchPattern nomeCls pattern:"*Unwrap*") or (matchPattern nomeCls pattern:"*UVW*") do
                (
                    local canal = InLab_CanalDoModificadorUV md
                    if canal == INLAB_CANAL_UV_BAKE then
                    (
                        deleteModifier o i
                        removidos += 1
                    )
                    else if canal == undefined do
                        InLab_Log (o.name + ": " + md.name + " mantido — não deu para ler o canal.") tipo:#warn
                )
            )

            local limpou = false
            try
            (
                local clr = UVW_Mapping_Clear()
                clr.mapID = INLAB_CANAL_UV_BAKE -- única propriedade de canal (Fase 0, resposta d)
                addModifier o clr
                limpou = true
            )
            catch()

            InLab_Log (o.name + ": Clean UV · " + removidos as string + " modificador(es) do canal " + INLAB_CANAL_UV_BAKE as string + " removido(s)" +
                       (if limpou then " · canal " + INLAB_CANAL_UV_BAKE as string + " limpo (colapsar antes do export)" else " · UVW Mapping Clear indisponível nesta build")) tipo:#ok
            n += 1
        )
    )
    InLab_Log ("Clean UV: " + n as string + " objeto(s).")
    n
)

--------------------------------------------------------------------------------
-- Reverte todos os Auto UV registrados desde o último Reverter: remove o
-- Unwrap e devolve a base original (Editable_Poly, primitiva...).
--------------------------------------------------------------------------------
fn InLab_ReverterAutoUV =
(
    if InLab_UltimoAutoUV.count == 0 then
        InLab_Log "Nenhum Auto UV registrado nesta sessão para reverter." tipo:#warn
    else
    (
        local revertidos = 0
        undo "InLab Reverter AutoUV" on
        (
            for r in InLab_UltimoAutoUV where isValidNode r.no do
            (
                local ok = true
                try ( deleteModifier r.no r.modificador )
                catch ( InLab_Log (r.no.name + ": Unwrap do Auto UV não encontrado (removido ou colapsado?).") tipo:#warn ; ok = false )
                if r.baseOriginal != undefined do
                    try ( r.no.baseObject = r.baseOriginal )
                    catch ( InLab_Log (r.no.name + ": não foi possível restaurar a base original — " + getCurrentException()) tipo:#err ; ok = false )
                if ok do
                (
                    InLab_Log (r.no.name + ": Auto UV revertido" +
                               (if r.baseOriginal != undefined then " · base " + (classOf r.baseOriginal) as string + " restaurada." else ".")) tipo:#ok
                    revertidos += 1
                )
            )
        )
        InLab_UltimoAutoUV = #()
        InLab_Log ("Reversão de UV concluída: " + revertidos as string + " objeto(s).")
    )
)
