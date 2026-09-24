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

 21/Set (Fase 3, sondagem em docs/superpowers/specs/2026-09-21-autouv-fase3-
 sondagem.md): a base não é mais convertida (Editable_Poly fica poly;
 primitiva e Editable_mesh também ficam: converter primitiva para poly
 retriangula as tampas e mudaria o canal 1). Sobre poly o flatten não cria a
 ilha "em escada" do Box014. Em malha pequena, depois do flatten roda um
 Unfold3DSolve com guarda por ilha (InLab_UnfoldComGuarda): distorção
 ~1,05× e densidade ~1,00× nas peças da issue; as ilhas que o solve
 degenera (Box008, até 80×) voltam às posições do flatten.
 22/Set: o parâmetro seamsOcultas: saiu (nunca teve efeito, só avisava no
 log). A ocultação das seams ficou para uma issue própria.

 UNDO: undo "InLab ..." + registro dedicado (InLab_UltimoAutoUV) para o
 Reverter, que alcança além do Ctrl+Z.

 24/Set (issue #48, robustez): o processamento de cada objeto (entre abrir e
 fechar o grupo) não tinha `try` próprio — uma exceção não prevista (ex.:
 InLab_MedirUV, uvw.pack) abortava a rodada inteira e deixava os grupos
 abertos. Agora cada objeto roda dentro do seu próprio try/catch: exceção
 pega, logada com o nome do objeto, os outros objetos seguem e o grupo fecha
 sempre (inclusive no catch). O global InLab_AutoUV_ForcarFalha (só teste)
 injeta essa exceção de forma determinística. Quando setMapChannel,
 selectFaces ou flattenMap falham (ou a exceção forçada dispara), o Unwrap já
 adicionado ao stack agora é removido (deleteModifier) em vez de ficar órfão
 sem aviso; o registro (AutoUVRecord) some com ele. m0.gutterMin e
 mi.aproveitamento (correção do gutter) passam a checar `undefined` antes de
 ler a propriedade — InLab_MedirUV devolve undefined quando o canal não
 existe, igual à guarda que já existia mais abaixo. snapshotAsMesh devolve um
 valor TriMesh (não cria nó na cena) que só some da memória no próximo
 garbage collect do MAXScript; InLab_ContagemCanal passa a `delete` o valor
 (2× por objeto) para liberar essa memória na hora em vez de esperar o GC.
 InLab_CanalDoModificadorUV passa a tentar também a
 propriedade `Map_Channel` (confirmada no UVW_Xform desta build, além de
 `mapChannel`/`channel`/`mapID`) e loga qual delas leu o canal quando não é a
 primeira tentada; o Clean UV agora remove um UVW_Xform no canal de bake. O
 catch() mudo do UVW_Mapping_Clear passa a logar a exceção.

 24/Set (revisão 1 do PR #48): o catch() do deleteModifier no bloco de erro
 inesperado também engolia a exceção — agora loga #err com o nome do objeto,
 igual ao bloco de falha "normal". O "-- Unwrap órfão removido" só sai quando
 o deleteModifier realmente funcionou. Um AutoUVRecord criado nesta rodada
 (recNovo) que termina sem Unwrap sai de InLab_UltimoAutoUV — não tem nada a
 reverter e só confundiria o Reverter; se o registro já existia (o Unwrap de
 uma rodada anterior foi removido no início do laço e a nova tentativa também
 falhou), fica um aviso de que só o Ctrl+Z restaura o objeto. Tirada a
 segunda declaração `local metodo` (redundante — MAXScript já iça o nome pra
 função inteira).

 24/Set (issue #51, desempenho; medido no Max 2024 com 01.max, mesmo UV antes
 e depois — assinatura do canal 3 e métricas idênticas):
   - InLab_IlhasDoUnwrap pega só o 1º bit ligado de "resta" (o collect antigo
     listava todas as faces restantes a cada ilha). Box008 com flatten 10°
     (1 023 ilhas): 4,6 s → 3,1 s; o resto é o selectElement nativo.
   - A medição final reaproveita a última InLab_MedirUV da correção do
     gutter quando nenhum pack veio depois dela (antes o mesmo UV era medido
     de novo). Uma chamada a menos por peça: Box008 19,6 s → 16,5 s, peça de
     26,6 mil triângulos 30,7 s → 24,6 s.
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
-- Acima disto (max(r, 1/r) da pior face) a ilha do Unfold3DSolve volta às
-- posições do flatten. O flatten puro não passou de 1,74 nas peças da issue.
global INLAB_UV_DISTORCAO_MAX_SOLVE = 2.0

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
global InLab_IlhasDoUnwrap, InLab_DistorcaoIlhas, InLab_UnfoldComGuarda
global InLab_AutoUV, InLab_CanalDoModificadorUV, InLab_CleanUV, InLab_ReverterAutoUV

-- SÓ TESTE (issue #48): nome (string) do objeto cuja rodada do Auto UV deve
-- lançar uma exceção forçada no meio do processamento, para provar que o
-- try por objeto pega, fecha o grupo e segue para os demais. undefined em
-- uso normal. Ver tests\test_autouv.ms.
global InLab_AutoUV_ForcarFalha = undefined

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
-- Nº de vértices e faces de mapa do canal, "nV/nF" (ou "sem canal"). Guarda
-- barata do canal 1 no Auto UV: a assinatura completa (InLab_AssinaturaCanal)
-- leva ~7 s numa malha de 300 mil faces e fica só nos testes.
--------------------------------------------------------------------------------
fn InLab_ContagemCanal o canal =
(
    local m = snapshotAsMesh o
    local resultado = if canal < meshop.getNumMaps m and meshop.getMapSupport m canal then
        (meshop.getNumMapVerts m canal) as string + "/" + (meshop.getNumMapFaces m canal) as string
    else
        "sem canal"
    delete m -- 24/Set (#48): snapshotAsMesh devolve um TriMesh (memória até o GC) — libera na hora
    resultado
)

-- Nós que compartilham o objeto com "o" (inclui o próprio "o").
fn InLab_Instancias o =
(
    local inst = #()
    InstanceMgr.GetInstances o &inst
    if inst.count == 0 do inst = #(o)
    inst
)

--------------------------------------------------------------------------------
-- 21/Set (Fase 3): a base NÃO é mais convertida. Editable_Poly fica poly
-- (decisão do usuário: o flatten sobre poly não cria a escada do Box014);
-- primitiva e Editable_mesh também ficam, com o Unwrap por cima. Converter
-- primitiva para poly retriangula as tampas (cilindro 96 → 92 triângulos) e
-- mudaria o canal 1. Devolve sempre undefined (nada a restaurar no Reverter);
-- só avisa quando o Unwrap vai ser compartilhado entre instâncias.
--------------------------------------------------------------------------------
fn InLab_AutoUV_PrepararBase o =
(
    local nInst = (InLab_Instancias o).count
    if nInst > 1 do
        InLab_Log (o.name + ": instanciado (" + nInst as string + " nós) — Unwrap compartilhado: todas as instâncias ficam com o mesmo canal " +
                   INLAB_CANAL_UV_BAKE as string + ".") tipo:#warn
    undefined
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
-- Ilhas UV do Unwrap ativo, como BitArrays de faces. selectElement nativo:
-- uma chamada por ilha (o union-find em MaxScript levava 2,7 s no Box008).
--------------------------------------------------------------------------------
fn InLab_IlhasDoUnwrap uvw np =
(
    local ilhas = #()
    local resta = #{1..np}
    uvw.setTVSubObjectMode 3
    while resta.numberSet > 0 do
    (
        -- 24/Set (#51): só o primeiro bit ligado. O "collect" antigo montava a
        -- lista de TODAS as faces restantes a cada ilha (O(faces × ilhas)).
        local f0 = undefined
        for f in resta while f0 == undefined do f0 = f
        uvw.selectFaces #{f0}
        uvw.selectElement()
        local s = uvw.getSelectedFaces()
        if s.numberSet == 0 do s = #{f0}
        append ilhas s
        resta -= s
    )
    ilhas
)

--------------------------------------------------------------------------------
-- Distorção de área por ilha: max(r, 1/r) da pior face, r = densidade da
-- face / densidade da ilha. Mesma definição de InLab_MedirUV, só que por ilha.
--------------------------------------------------------------------------------
fn InLab_DistorcaoIlhas uvw ilhas =
(
    for s in ilhas collect
    (
        local x, y, w, h, aUV, aG
        local totUV = 0.0, totG = 0.0
        local faces = #()
        for f in s do
        (
            uvw.getArea #{f} &x &y &w &h &aUV &aG
            append faces #(aUV, aG)
            totUV += aUV
            totG += aG
        )
        local dI = if totG > 1e-9 then totUV / totG else 0.0
        local pior = 1.0
        if dI > 1e-12 do
            for p in faces where p[2] > 1e-9 and p[1] > 1e-12 do
            (
                local r = (p[1] / p[2]) / dI
                pior = amax pior (amax r (1.0 / r))
            )
        if dI <= 1e-12 then 1e9 else pior
    )
)

--------------------------------------------------------------------------------
-- Unfold3DSolve sobre o flatten, com guarda: as ilhas que o solve degenera
-- (Box008: distorção 80×) voltam às posições do flatten. Devolve o nº de
-- ilhas revertidas, ou -1 se o solve não existir nesta build.
-- 22/Set: o solve RENUMERA os vértices UV das faces (Box050: 78 de 294 faces;
-- é uma permutação, os mesmos vértices em uso). Voltar por índice de vértice
-- gravava as posições nos vértices errados (distorção 3 930×, 18 invertidos em
-- 7 peças da cadeira). A posição do flatten é guardada por CANTO de face e
-- gravada no vértice que o canto aponta depois do solve.
--------------------------------------------------------------------------------
fn InLab_UnfoldComGuarda uvw np =
(
    local ilhas = InLab_IlhasDoUnwrap uvw np
    local cantosFlat = for f = 1 to np collect
        (for k = 1 to (uvw.numberPointsInFace f) collect uvw.getVertexPosition 0 (uvw.getVertexIndexFromFace f k))
    uvw.selectFaces #{1..np}
    local ok = try ( uvw.Unfold3DSolve() ; true ) catch ( InLab_Log ("Unfold3DSolve: " + getCurrentException()) tipo:#warn ; false )
    if not ok then -1
    else
    (
        local dist = InLab_DistorcaoIlhas uvw ilhas
        local revertidas = 0
        for i = 1 to ilhas.count where dist[i] > INLAB_UV_DISTORCAO_MAX_SOLVE do
        (
            for f in ilhas[i] do
                for k = 1 to cantosFlat[f].count do
                    uvw.setVertexPosition 0 (uvw.getVertexIndexFromFace f k) cantosFlat[f][k]
            revertidas += 1
        )
        uvw.selectFaces #{1..np}
        revertidas
    )
)

--------------------------------------------------------------------------------
-- AUTO UV sobre a seleção. Grava no canal INLAB_CANAL_UV_BAKE.
--------------------------------------------------------------------------------
fn InLab_AutoUV objs angulo:55.0 resolucao:1024 =
(
    local processados = 0
    local padding = InLab_PaddingUV resolucao
    local normais = #([1,0,0], [-1,0,0], [0,1,0], [0,-1,0], [0,0,1], [0,0,-1])
    InLab_Log ("Auto UV: canal " + INLAB_CANAL_UV_BAKE as string + " · ângulo " + (formattedPrint angulo format:".0f") +
               "° · " + resolucao as string + " px (padding " + (formattedPrint padding format:".4f") + ")")

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
                local recNovo = (rec == undefined) -- fix#48/r1 (MINOR 4): se este registro nasce agora
                if rec == undefined then
                (
                    rec = AutoUVRecord no:o baseOriginal:(InLab_AutoUV_PrepararBase o)
                    append InLab_UltimoAutoUV rec
                )
                else if rec.modificador != undefined do
                    try ( deleteModifier o rec.modificador )
                    catch ( InLab_Log (o.name + ": Unwrap anterior do Auto UV não encontrado (removido à mão?).") tipo:#warn )

                -- Grupo fechado: abre durante o Unwrap para o select pegar só o nó.
                -- 24/Set (#48): todo o processamento do objeto (a partir daqui) fica
                -- dentro do try abaixo. Uma exceção não prevista (ou a falha forçada
                -- de teste) é pega, logada com o nome do objeto, e não impede os
                -- demais objetos nem deixa o grupo aberto — InLab_FecharGrupos roda
                -- sempre, dentro ou fora do catch.
                local gruposAbertos = InLab_AbrirGruposAcima o
                local uvw = undefined
                local metodo = undefined

                try
                (
                    select o
                    uvw = Unwrap_UVW()
                    uvw.name = "InLab AutoUV"
                    addModifier o uvw
                    modPanel.setCurrentObject uvw
                    rec.modificador = uvw

                    -- SÓ TESTE (issue #48): ver InLab_AutoUV_ForcarFalha no topo do arquivo.
                    if InLab_AutoUV_ForcarFalha == o.name do
                        throw (o.name + ": falha forçada para teste (InLab_AutoUV_ForcarFalha)")

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
                    metodo = undefined -- fix#48/r1 (MINOR 2): já é local lá em cima; reatribuir aqui, sem "local" de novo
                    try ( uvw.flattenMap angulo normais espFlatten true 0 true true ; metodo = "Flatten " + (formattedPrint angulo format:".0f") + "°" )
                    catch ( InLab_Log (o.name + ": flattenMap falhou — " + getCurrentException()) tipo:#err )

                    if metodo != undefined do
                    (
                        ------------------------------------------------------
                        -- 1b · UNFOLD COM GUARDA (Fase 3): só em malha pequena.
                        -- Na pillow 02 (306 mil tris) o solve sozinho leva 49 s.
                        ------------------------------------------------------
                        if not grande do
                        (
                            local rev = InLab_UnfoldComGuarda uvw nPolysUV
                            if rev < 0 then
                                InLab_Log (o.name + ": Unfold3DSolve indisponível — fica o flatten.") tipo:#warn
                            else
                                metodo += " → Unfold3D" + (if rev > 0 then " (" + rev as string + " ilha(s) voltaram ao flatten)" else "")
                        )

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
                        -- 24/Set (#51): medição feita sobre o layout ATUAL (nenhum pack
                        -- depois dela). A medição final reaproveita em vez de medir de
                        -- novo o mesmo UV — InLab_MedirUV é determinística, o resultado
                        -- é o mesmo e sai uma chamada de ~3 s no Box008.
                        local metAtual = undefined
                        if packUsado == "pack recursivo" do
                        (
                            -- 24/Set (#48): InLab_MedirUV devolve undefined quando o canal
                            -- não existe (mesma guarda que já havia na medição final, l.~536).
                            local m0 = InLab_MedirUV o INLAB_CANAL_UV_BAKE
                            metAtual = m0
                            local g0 = if m0 != undefined then m0.gutterMin else undefined
                            if g0 != undefined and g0 > 0.0 and g0 < padding * 0.98 do
                            (
                                local melhorEsp = padding, melhorG = g0, esp = padding, gAtual = g0
                                for it = 1 to 3 while melhorG < padding * 0.98 do
                                (
                                    esp = amin (esp * (padding / (amax gAtual 1e-5)) * 1.05) (padding * INLAB_UV_ESPACAMENTO_MAX)
                                    uvw.selectFaces #{1..nPolysUV}
                                    uvw.pack 1 esp true true true
                                    local mi = InLab_MedirUV o INLAB_CANAL_UV_BAKE
                                    metAtual = mi
                                    gAtual = if mi == undefined or mi.gutterMin == undefined then 0.0 else mi.gutterMin
                                    if mi != undefined and gAtual > melhorG and mi.aproveitamento >= m0.aproveitamento * 0.7 do
                                    (
                                        melhorG = gAtual
                                        melhorEsp = esp
                                    )
                                )
                                if esp != melhorEsp do
                                (
                                    uvw.selectFaces #{1..nPolysUV}
                                    uvw.pack 1 melhorEsp true true true
                                    metAtual = undefined -- layout mudou: a medição final mede de novo
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
                            local met = if metAtual != undefined then metAtual else InLab_MedirUV o INLAB_CANAL_UV_BAKE
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

                    -- 24/Set (#48): setMapChannel, selectFaces ou flattenMap falharam
                    -- (ou a checagem do canal 3) — "metodo" continua undefined e o
                    -- Unwrap que entrou no stack no início da rodada vira órfão sem
                    -- aviso. Remove aqui em vez de deixar no objeto.
                    if metodo == undefined do
                    (
                        -- fix#48/r1 (MINOR 3): só loga "removido" se a remoção deu certo.
                        local removido = true
                        try ( deleteModifier o uvw )
                        catch ( InLab_Log (o.name + ": não foi possível remover o Unwrap órfão do canal " + INLAB_CANAL_UV_BAKE as string + ".") tipo:#err ; removido = false )
                        rec.modificador = undefined
                        if removido do
                            InLab_Log (o.name + ": Unwrap órfão removido do stack (etapa anterior falhou).") tipo:#warn
                    )
                )
                catch
                (
                    InLab_Log (o.name + ": erro inesperado no Auto UV — " + getCurrentException()) tipo:#err
                    if uvw != undefined do
                    (
                        -- fix#48/r1 (IMPORTANT 1): catch() mudo engolia o erro — loga com o nome do objeto.
                        try ( deleteModifier o uvw )
                        catch ( InLab_Log (o.name + ": não foi possível remover o Unwrap órfão do canal " + INLAB_CANAL_UV_BAKE as string + " depois do erro.") tipo:#err )
                        rec.modificador = undefined
                    )
                )

                -- fix#48/r1 (MINOR 4): a rodada falhou para este objeto (rec.modificador
                -- continua undefined pela limpeza acima) — um registro CRIADO agora não
                -- tem nada a reverter (baseOriginal também é sempre undefined na Fase 3) e
                -- só confundiria o Reverter mais tarde; sai de InLab_UltimoAutoUV. Um
                -- registro que já existia (Auto UV anterior bem-sucedido, removido no topo
                -- do laço antes desta tentativa) fica — mas o objeto ficou sem nenhum
                -- Unwrap do Auto UV, então avisa que só o Ctrl+Z devolve o anterior.
                if rec.modificador == undefined do
                (
                    if recNovo then
                    (
                        local idx = findItem InLab_UltimoAutoUV rec
                        if idx > 0 do deleteItem InLab_UltimoAutoUV idx
                    )
                    else
                        InLab_Log (o.name + ": Auto UV falhou nesta rodada e o Unwrap anterior já tinha sido substituído — só o Ctrl+Z restaura este objeto.") tipo:#warn
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
    (
        -- 24/Set (#48): o UVW_Xform usa a propriedade Map_Channel (confirmado
        -- nesta build), não mapChannel/channel/mapID — sem ela o Clean UV não
        -- achava o canal e deixava o modificador no stack. Cadeia de
        -- candidatos, como as outras APIs por build (ver CLAUDE.md); loga só
        -- quando a achada não é a mais comum (#mapChannel), para não gerar
        -- ruído por objeto.
        local propUsada = undefined
        for p in #(#mapChannel, #Map_Channel, #channel, #mapID) while canal == undefined do
            if isProperty md p do ( canal = getProperty md p ; propUsada = p )
        if canal != undefined and propUsada != #mapChannel do
            InLab_Log ((classof md) as string + " " + md.name + ": canal lido pela propriedade " + propUsada as string + ".") tipo:#info
    )
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
            catch ( InLab_Log (o.name + ": UVW_Mapping_Clear falhou — " + getCurrentException()) tipo:#err )

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
