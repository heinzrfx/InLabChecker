/*
================================================================================
 functions\fn_otim_escondidas.ms — Otimização · passo 3 · Faces escondidas
--------------------------------------------------------------------------------
 Spec: docs\superpowers\specs\2026-09-23-otimizacao-design.md, seções 3.4 e 5.
 Contrato: ver o cabeçalho de functions\fn_otim_nucleo.ms.

 CRITÉRIO (só marca face com prova geométrica): a face INTEIRA — o centro e
 os 3 cantos recuados 10% para o centro — tem que passar, em cada amostra,
 num destes testes contra OUTRA peça:
   - CONTATO: raio de `amostra - normal * tol` pela normal bate na outra peça
     a até 2 * tol (tol = 0,5 mm, units.decodeValue "0.5mm").
   - DENTRO: paridade ímpar de acertos (deduplicados pela distância) em pelo
     menos 2 de 3 direções "tortas" (não alinhadas a eixo).
 Cada amostra pode ser coberta por uma peça diferente (face sob dois
 assentos vizinhos); se uma amostra fica descoberta, a face NÃO entra (face
 parcial nunca entra). Motivo na lista: "dentro" se todas as amostras
 estão dentro de outra peça, "contato" nos demais casos.

 NUNCA ENTRAM:
   - o FUNDO: face virada para baixo (normal.z < -0,5) com todas as amostras
     a até tol do Z mínimo da cena. Não há objeto de chão, então fundo nunca
     encosta em nada — exceto duas faces de baixo coplanares (ponteira dentro
     do pé, ambas em Z=0), que o teste de contato aceitaria. A RA mostra o
     produto por baixo.
   - peças ANIMADAS (keys em posição/rotação/escala do nó ou de um pai, V-30):
     não são alvo nem cobrem ninguém; e a face de outra peça que encosta ou
     entra numa animada (interior de gaveta e porta, V-39) é descartada.
   - peça que já tem o modificador deste passo (nunca empilha: use Reverter).

 IMPLEMENTAÇÃO (sondagem da spec seção 5): um RayMeshGridIntersect POR PEÇA
 (com vários nós numa grade os raios erram as peças longe do 1º addNode),
 construído sob demanda e só para as peças cujo bbox encosta no da peça alvo;
 cada amostra ainda filtra pelo bbox (+2 tol) antes de lançar raio. A grade
 é um retrato do buildGrid (coordenadas de MUNDO). intersectRay com
 doubleSided:true (com false só conta face de frente para o raio e a
 paridade quebra — sondado em 24/09/2026). intersectSphere não serve (dá 0).
 Oclusor que já tem "Faces escondidas" aplicado tem o DeleteMesh desligado
 durante o buildGrid (malha furada estraga a paridade) e religado em seguida.

 INSTÂNCIAS: InLab_DeduplicarInstancias — o modificador vai no stack
 compartilhado, então a face só entra se estiver escondida em TODAS as
 instâncias (interseção por índice; inclusive instâncias fora da seleção).

 APLICAÇÃO (não destrutiva, no topo do stack): Mesh_Select
 "InLab · Faces escondidas · seleção" com as faces + DeleteMesh
 "InLab · Faces escondidas". Os índices são os do snapshotAsMesh do topo do
 stack; o Mesh_Select entrega a mesma triangulação (conferido em Editable
 Poly + TurboSmooth, Sphere e Cylinder poly, e depois de salvar/abrir o
 .max, em 24/09/2026). SONDAGEM do Mesh_Select por script (Max 2024):
   - setFaceSelection <nó> <mod> só funciona com o nó selecionado, painel
     Modify e o Mesh_Select corrente; e o nível de face (subObjectLevel = 3)
     tem que estar ativo.
   - addModifier do DeleteMesh depois disso apaga a PEÇA INTEIRA (o nível de
     sub-objeto volta a objeto); modPanel.addModToSelection com o Mesh_Select
     corrente em nível de face apaga só a seleção. Por isso o DeleteMesh entra
     por addModToSelection (grupos fechados acima do nó são abertos antes e
     fechados depois — pegadinha do painel Modify no CLAUDE.md).
 Aplicar confere que a peça perdeu exatamente as faces propostas; se não,
 remove os dois modificadores e loga #err. Se o stack abaixo mudou desde o
 Calcular (outra contagem de triângulos), a peça é pulada — calcule de novo.
 ATENÇÃO: a seleção é por ÍNDICE. Mexer no stack abaixo depois de aplicar
 (passo 1/2) muda os índices: aplique o passo 3 por último.
 O bake de AO desliga o DeleteMesh, assa e liga de novo; o colapso acontece no
 export (V-11).

 REVISÃO: as faces candidatas das linhas da lista (INLAB_OTIM_PROPOSTAS da UI,
 só as marcadas; sem UI, todas) são desenhadas em vermelho na viewport por um
 registerRedrawViewsCallback, até Aplicar/Reverter/novo Calcular. Desenho
 SEM z-buffer (gw.setRndLimits #(#wireframe)): as faces estão escondidas por
 definição, com z-buffer nada aparece. A UI redesenha a viewport depois de
 Calcular e ao marcar/desmarcar uma linha (ui\rollout_main.ms). Até
 INLAB_ESC_DESTAQUE_MAX triângulos (o resto é logado). Lista: uma linha por
 peça (stack) com contagem e motivo; a caixa da linha desmarca a peça inteira.

 PROGRESSO: barra nativa do Max (progressStart/progressUpdate) por peça, com
 Cancelar (devolve lista vazia, nada muda).

 DESEMPENHO (Max 2024, 24/09/2026): sofá sintético de 104.992 triângulos
 (grade adaptativa, ver INLAB_ESC_GRADE_K) = 20,4 s no Calcular; 01.max
 (cadeira + móveis, 125 peças, 114.948 triângulos) = 22,7 s no Calcular,
 12.753 faces em 98 peças, e 16,2 s no Aplicar (select + painel Modify por
 peça). Nas duas cenas o raio pela normal de TODA face marcada bate em outra
 peça, e a captura antes/depois de aplicar é igual.

 REGISTRO: InLab_UltimasEscondidas (EscondidasRecord por stack), acumula até
 o Reverter, que remove exatamente os dois modificadores registrados. Sem
 registro (plugin recarregado, cena reaberta), Reverter remove os
 modificadores pelo NOME em toda a cena.

 HISTÓRICO:
 23/09/2026 (issue #60): versão mínima, só para a tela e o manifesto.
 24/09/2026 (issue #63): o passo de verdade (este cabeçalho).

 `global` antes de cada fn (mesmo já declarada em fn_otim_nucleo.ms): este
 arquivo pode ser carregado sozinho por InLab_RecarregarPlugin() — padrão de
 functions\fn_renomear_produto.ms.
================================================================================
*/

global INLAB_OTIM_PROPOSTAS

global INLAB_ESC_NOME_MOD = "InLab · Faces escondidas"
global INLAB_ESC_NOME_SEL = "InLab · Faces escondidas · seleção"
global INLAB_ESC_DESTAQUE_MAX = 20000
-- Resolução da grade de cada peça (RayMeshGridIntersect.Initialize n = n
-- células por eixo): INLAB_ESC_GRADE_K * raiz cúbica das faces, entre 10 e
-- INLAB_ESC_GRADE_MAX. Medido no sofá sintético de 105 mil triângulos
-- (24/09/2026): grade fixa 10 = 68,6 s, 20 = 40,2 s, 40 = 26,2 s, 80 = 21,5 s,
-- 150 = 18,9 s (mesmas faces marcadas em todas).
global INLAB_ESC_GRADE_K = 3.0
global INLAB_ESC_GRADE_MAX = 100

-- 3 direções "tortas" (não alinhadas a eixo) para a paridade do teste DENTRO.
global INLAB_ESC_DIRECOES = #(normalize [1.0, 0.618, 0.382], normalize [-0.382, 1.0, 0.618], normalize [0.618, -0.382, 1.0])

struct EscondidasRecord
(
    no,              -- representante do stack
    modSelecao,      -- Mesh_Select adicionado
    modApagar,       -- DeleteMesh adicionado
    faces = #{},
    instancias = 1,
    trisAntes = 0,
    trisDepois = 0
)

global InLab_UltimasEscondidas
if InLab_UltimasEscondidas == undefined do InLab_UltimasEscondidas = #()

-- Destaque da revisão: #(proposta, #(pontos em mundo, 3 por triângulo)).
global InLab_OtimEscondidas_Destaque
if InLab_OtimEscondidas_Destaque == undefined do InLab_OtimEscondidas_Destaque = #()

--------------------------------------------------------------------------------
-- AUXILIARES
--------------------------------------------------------------------------------

-- Nó (ou um pai) com keys em posição, rotação ou escala.
global InLab_OtimEscondidas_Animado
fn InLab_OtimEscondidas_Animado o =
(
    local achou = false
    local n = o
    while n != undefined and not achou do
    (
        -- .isAnimated vale também para controladores compostos (Position_XYZ),
        -- onde .keys do controlador pai vem vazio.
        try ( if n.position.isAnimated or n.rotation.isAnimated or n.scale.isAnimated do achou = true )
        catch ( InLab_Log (n.name + ": não li a animação (" + getCurrentException() + ") — tratada como estática.") tipo:#warn )
        n = n.parent
    )
    achou
)

-- Os dois modificadores do passo no stack do nó: #(selecao, apagar), undefined se faltar.
global InLab_OtimEscondidas_Mods
fn InLab_OtimEscondidas_Mods o =
(
    local sel = undefined, apg = undefined
    for m in o.modifiers do
    (
        if classof m == Mesh_Select and m.name == INLAB_ESC_NOME_SEL do sel = m
        if classof m == DeleteMesh and m.name == INLAB_ESC_NOME_MOD do apg = m
    )
    #(sel, apg)
)

global InLab_OtimEscondidas_TemModificador
fn InLab_OtimEscondidas_TemModificador o =
(
    local ms = InLab_OtimEscondidas_Mods o
    ms[1] != undefined or ms[2] != undefined
)

-- Quantas distâncias diferentes (raio pela diagonal de um quad bate em 2
-- triângulos na mesma distância).
global InLab_OtimEscondidas_Distintas
fn InLab_OtimEscondidas_Distintas ds eps =
(
    sort ds
    local n = 0
    local ult = undefined
    for d in ds do
        if ult == undefined or (d - ult) > eps do ( n += 1; ult = d )
    n
)

-- Grade de uma peça (cache: #(nós, grades)). DeleteMesh deste passo desligado
-- durante o buildGrid (ver cabeçalho).
global InLab_OtimEscondidas_Grade
fn InLab_OtimEscondidas_Grade o cache =
(
    local i = findItem cache[1] o
    if i > 0 then cache[2][i]
    else
    (
        local rm = undefined
        local apg = (InLab_OtimEscondidas_Mods o)[2]
        local estava = if apg != undefined then apg.enabled else false
        try
        (
            if apg != undefined do apg.enabled = false
            rm = RayMeshGridIntersect()
            local nf = (GetTriMeshFaceCount o)[1]
            rm.Initialize (amin INLAB_ESC_GRADE_MAX (amax 10 ((INLAB_ESC_GRADE_K * (pow (amax 1 nf) (1.0 / 3.0))) as integer)))
            rm.addNode o
            rm.buildGrid()
        )
        catch
        (
            InLab_Log (o.name + ": não montei a grade de raios (" + getCurrentException() + ") — a peça não cobre ninguém.") tipo:#warn
            rm = undefined
        )
        if apg != undefined do
            try ( apg.enabled = estava )
            catch ( InLab_Log (o.name + ": não religuei o DeleteMesh das faces escondidas (" + getCurrentException() + ").") tipo:#err )
        append cache[1] o
        append cache[2] rm
        rm
    )
)

global InLab_OtimEscondidas_LiberarGrades
fn InLab_OtimEscondidas_LiberarGrades cache =
(
    for rm in cache[2] where rm != undefined do
        try ( rm.free() ) catch ( InLab_Log ("Faces escondidas: não liberei uma grade (" + getCurrentException() + ").") tipo:#warn )
    cache[1] = #()
    cache[2] = #()
)

-- A amostra p (normal n da face) está coberta pela peça da grade rm?
-- Devolve 0 (não), 1 (contato) ou 2 (dentro).
global InLab_OtimEscondidas_Cobre
fn InLab_OtimEscondidas_Cobre rm p n tol eps =
(
    local r = 0
    local k = rm.intersectRay (p - n * tol) n true
    for i = 1 to k while r == 0 do
        if (rm.getHitDist i) <= 2.0 * tol do r = 1
    if r == 0 do
    (
        local sim = 0, nao = 0
        for d in INLAB_ESC_DIRECOES while sim < 2 and nao < 2 do
        (
            local h = rm.intersectRay p d true
            local ds = for i = 1 to h collect (rm.getHitDist i)
            if (mod (InLab_OtimEscondidas_Distintas ds eps) 2) == 1 then sim += 1 else nao += 1
        )
        if sim >= 2 do r = 2
    )
    r
)

-- Detecta as faces escondidas de UM nó. `outros` = #(nós, mins, maxs) das
-- peças estáticas que podem cobrir; `animados` idem para as animadas.
-- Devolve #(faces, dentro, nFaces, nAnimada, nFundo, malha) — malha é o
-- snapshot em mundo (quem chama apaga).
global InLab_OtimEscondidas_DetectarNo
fn InLab_OtimEscondidas_DetectarNo o outros animados cache tol zMin =
(
    local eps = tol * 0.02
    local m = snapshotAsMesh o
    local faces = #{}
    local dentro = #{}
    local nAnim = 0, nFundo = 0
    local omin = o.min - [2, 2, 2] * tol
    local omax = o.max + [2, 2, 2] * tol
    fn perto a amin amax = (a.x >= amin.x and a.y >= amin.y and a.z >= amin.z and a.x <= amax.x and a.y <= amax.y and a.z <= amax.z)
    fn filtrar lista o omin omax tol =
    (
        local r = #(#(), #(), #())
        for i = 1 to lista[1].count where lista[1][i] != o do
        (
            local bmin = lista[2][i] - [2, 2, 2] * tol
            local bmax = lista[3][i] + [2, 2, 2] * tol
            if bmin.x <= omax.x and bmin.y <= omax.y and bmin.z <= omax.z and bmax.x >= omin.x and bmax.y >= omin.y and bmax.z >= omin.z do
            ( append r[1] lista[1][i]; append r[2] bmin; append r[3] bmax )
        )
        r
    )
    local cand = filtrar outros o omin omax tol
    local candAnim = filtrar animados o omin omax tol
    if cand[1].count > 0 do
    (
        local grades = for c in cand[1] collect (InLab_OtimEscondidas_Grade c cache)
        local gradesAnim = for c in candAnim[1] collect (InLab_OtimEscondidas_Grade c cache)
        for f = 1 to m.numfaces do
        (
            local fv = getFace m f
            local v1 = getVert m fv.x, v2 = getVert m fv.y, v3 = getVert m fv.z
            local nrm = cross (v2 - v1) (v3 - v1)
            if (length nrm) > 1e-12 do
            (
                nrm = normalize nrm
                local c = (v1 + v2 + v3) / 3.0
                local amostras = #(c, v1 + (c - v1) * 0.1, v2 + (c - v2) * 0.1, v3 + (c - v3) * 0.1)
                local fundo = nrm.z < -0.5
                if fundo do for a in amostras where a.z > zMin + tol do fundo = false
                if fundo then nFundo += 1
                else
                (
                    local todas = true
                    local todasDentro = true
                    for a in amostras while todas do
                    (
                        local cob = 0
                        for i = 1 to grades.count while cob == 0 do
                            if grades[i] != undefined and (perto a cand[2][i] cand[3][i]) do
                                cob = InLab_OtimEscondidas_Cobre grades[i] a nrm tol eps
                        if cob == 0 then todas = false
                        else if cob == 1 do todasDentro = false
                    )
                    if todas do
                    (
                        local anim = false
                        for a in amostras while not anim do
                            for i = 1 to gradesAnim.count while not anim do
                                if gradesAnim[i] != undefined and (perto a candAnim[2][i] candAnim[3][i]) do
                                    if (InLab_OtimEscondidas_Cobre gradesAnim[i] a nrm tol eps) > 0 do anim = true
                        if anim then nAnim += 1
                        else
                        (
                            faces[f] = true
                            if todasDentro do dentro[f] = true
                        )
                    )
                )
            )
        )
    )
    #(faces, dentro, m.numfaces, nAnim, nFundo, m)
)

--------------------------------------------------------------------------------
-- DESTAQUE NA VIEWPORT
--------------------------------------------------------------------------------
global InLab_OtimEscondidas_Desenhar
fn InLab_OtimEscondidas_Desenhar =
(
    try
    (
        local lista = INLAB_OTIM_PROPOSTAS
        gw.setTransform (matrix3 1)
        -- Sem #zBuffer: as faces são escondidas por definição, então o
        -- destaque tem que aparecer através das peças que as cobrem.
        gw.setRndLimits #(#wireframe)
        gw.setColor #line (color 255 40 40)
        for e in InLab_OtimEscondidas_Destaque do
        (
            local mostrar = true
            if classof lista == Array do
            (
                mostrar = false
                for p in lista where p == e[1] and p.marcada do mostrar = true
            )
            if mostrar do
            (
                local pts = e[2]
                for i = 1 to pts.count by 3 do gw.polyline #(pts[i], pts[i + 1], pts[i + 2]) true
            )
        )
        gw.enlargeUpdateRect #whole
        gw.updateScreen()
    )
    catch
    (
        unregisterRedrawViewsCallback InLab_OtimEscondidas_Desenhar
        InLab_Log ("Faces escondidas: destaque na viewport desligado (" + getCurrentException() + ").") tipo:#warn
    )
)

global InLab_OtimEscondidas_LimparDestaque
fn InLab_OtimEscondidas_LimparDestaque =
(
    unregisterRedrawViewsCallback InLab_OtimEscondidas_Desenhar
    InLab_OtimEscondidas_Destaque = #()
    redrawViews()
)

--------------------------------------------------------------------------------
-- CALCULAR
--------------------------------------------------------------------------------
global InLab_OtimEscondidas_Calcular
fn InLab_OtimEscondidas_Calcular objs =
(
    InLab_OtimEscondidas_LimparDestaque()
    local t0 = timeStamp()
    local tol = units.decodeValue "0.5mm"
    local cena = for o in geometry where InLab_EhGeometria o collect o
    local animSet = for o in cena where InLab_OtimEscondidas_Animado o collect o
    local estaticos = #(#(), #(), #())
    local animados = #(#(), #(), #())
    local zMin = undefined
    for o in cena do
    (
        local lista = if findItem animSet o > 0 then animados else estaticos
        append lista[1] o
        append lista[2] o.min
        append lista[3] o.max
        if zMin == undefined or o.min.z < zMin do zMin = o.min.z
    )

    -- Grupos de instâncias alvo (animadas e já processadas ficam fora).
    local grupos = #()
    for g in InLab_DeduplicarInstancias (for o in objs where InLab_EhGeometria o collect o) do
    (
        local nos = for i in g.instancias where isValidNode i and InLab_EhGeometria i collect i
        if nos.count == 0 do nos = #(g.no)
        if (for i in nos where findItem animSet i > 0 collect i).count > 0 then
            InLab_Log (g.no.name + ": peça animada — fica fora das faces escondidas.") tipo:#info
        else if InLab_OtimEscondidas_TemModificador g.no then
            InLab_Log (g.no.name + ": já tem faces escondidas aplicado — use Reverter antes de recalcular.") tipo:#warn
        else append grupos #(g.no, nos)
    )

    local props = #()
    local cache = #(#(), #())
    local nDestaque = 0, nForaDestaque = 0
    local cancelado = false
    local totalFaces = 0, totalAnim = 0
    progressStart "Faces escondidas"
    try
    (
        for gi = 1 to grupos.count while not cancelado do
        (
            local rep = grupos[gi][1]
            local nos = grupos[gi][2]
            if not (progressUpdate (100.0 * (gi - 1) / grupos.count)) then cancelado = true
            else
            (
                InLab_ProgressoIniciar ("Faces escondidas: " + rep.name + " (" + gi as string + " de " + grupos.count as string + ")")
                local faces = undefined, dentro = undefined
                local nF = 0, nAnim = 0
                local malhas = #()
                for o in nos do
                (
                    local r = InLab_OtimEscondidas_DetectarNo o estaticos animados cache tol zMin
                    append malhas r[6]
                    nF = r[3]
                    nAnim += r[4]
                    if faces == undefined then ( faces = r[1]; dentro = r[2] )
                    else ( faces = faces * r[1]; dentro = dentro * r[2] )
                )
                if nAnim > 0 do
                    InLab_Log (rep.name + ": " + nAnim as string + " face(s) encostada(s) em peça animada ficam (gaveta/porta).") tipo:#info
                totalAnim += nAnim
                local n = faces.numberSet
                if n == 0 then
                    InLab_Log (rep.name + ": nenhuma face escondida.") tipo:#info
                else
                (
                    totalFaces += n * nos.count
                    local nDentro = (dentro * faces).numberSet
                    local nContato = n - nDentro
                    local motivo = ""
                    if nContato > 0 do motivo += "contato " + nContato as string
                    if nDentro > 0 do motivo += (if motivo != "" then " · " else "") + "dentro " + nDentro as string
                    local nomeInst = if nos.count > 1 then (rep.name + " (×" + nos.count as string + ")") else rep.name
                    local p = OtimProposta no:rep alvo:rep prop:#facesEscondidas antes:nF depois:faces \
                        trisAntes:nF trisDepois:(nF - n) motivo:motivo \
                        rotulo:(nomeInst + "  ·  " + (InLab_Otim_Milhar n) + " faces  ·  " + motivo)
                    append props p
                    -- Pontos do destaque (todas as instâncias).
                    local pts = #()
                    for mm in malhas do
                        for f in faces do
                        (
                            if nDestaque < INLAB_ESC_DESTAQUE_MAX then
                            (
                                local fv = getFace mm f
                                append pts (getVert mm fv.x); append pts (getVert mm fv.y); append pts (getVert mm fv.z)
                                nDestaque += 1
                            )
                            else nForaDestaque += 1
                        )
                    append InLab_OtimEscondidas_Destaque #(p, pts)
                    InLab_Log (nomeInst + ": " + n as string + " de " + nF as string + " faces escondidas (" + motivo + ").") tipo:#ok
                    if n == nF do
                        InLab_Log (nomeInst + ": a peça INTEIRA está escondida — confira se ela precisa existir.") tipo:#warn
                )
                for mm in malhas do delete mm
            )
        )
    )
    catch
    (
        InLab_Log ("Faces escondidas: erro no cálculo (" + getCurrentException() + ") — nada proposto.") tipo:#err
        props = #()
        InLab_OtimEscondidas_Destaque = #()
    )
    progressEnd()
    InLab_OtimEscondidas_LiberarGrades cache
    if cancelado do
    (
        InLab_Log "Faces escondidas: cálculo cancelado — nada proposto." tipo:#warn
        props = #()
        InLab_OtimEscondidas_Destaque = #()
    )

    local seg = (timeStamp() - t0) / 1000.0
    local tris = InLab_Otim_Triangulos (for g in grupos collect g[1])
    InLab_Log ("Faces escondidas: " + (InLab_Otim_Milhar totalFaces) + " face(s) em " + props.count as string + " peça(s); " +
               (InLab_Otim_Milhar tris) + " triângulos analisados em " + (formattedPrint seg format:".1f") + " s.") \
        tipo:(if props.count > 0 then #ok else #info)
    if nForaDestaque > 0 do
        InLab_Log ("Faces escondidas: destaque na viewport limitado a " + (InLab_Otim_Milhar INLAB_ESC_DESTAQUE_MAX) + " faces (" +
                   (InLab_Otim_Milhar nForaDestaque) + " não desenhadas; a lista tem todas).") tipo:#info
    if InLab_OtimEscondidas_Destaque.count > 0 do
    (
        registerRedrawViewsCallback InLab_OtimEscondidas_Desenhar
        redrawViews()
    )
    props
)

--------------------------------------------------------------------------------
-- APLICAR
--------------------------------------------------------------------------------

-- Mesh_Select com as faces + DeleteMesh no topo do stack do nó `o`
-- (contexto obrigatório: ver cabeçalho). Devolve #(sel, apagar).
global InLab_OtimEscondidas_PorModificadores
fn InLab_OtimEscondidas_PorModificadores o faces =
(
    local ms = Mesh_Select()
    ms.name = INLAB_ESC_NOME_SEL
    addModifier o ms
    select o
    setCommandPanelTaskMode #modify
    modPanel.setCurrentObject ms
    subObjectLevel = 3
    setFaceSelection o ms faces
    local dm = DeleteMesh()
    dm.name = INLAB_ESC_NOME_MOD
    modPanel.addModToSelection dm
    #(ms, dm)
)

global InLab_OtimEscondidas_Aplicar
fn InLab_OtimEscondidas_Aplicar propostas =
(
    InLab_OtimEscondidas_LimparDestaque()
    local marcadas = for p in propostas where p.marcada and isValidNode p.no and p.prop == #facesEscondidas collect p
    if marcadas.count == 0 then
    (
        InLab_Log "Faces escondidas: nenhuma peça marcada." tipo:#warn
        0
    )
    else
    (
        local aplicados = 0
        local selOriginal = selection as array
        local painelOriginal = getCommandPanelTaskMode()
        local reps = for g in InLab_DeduplicarInstancias (for p in marcadas collect p.no) collect g.no
        local feitos = #()
        undo "InLab Faces escondidas" on
        (
            for p in marcadas where findItem reps p.no > 0 and findItem feitos p.no == 0 do
            (
                local o = p.no
                append feitos o
                local triAntes = (GetTriMeshFaceCount o)[1]
                local n = p.depois.numberSet
                if InLab_OtimEscondidas_TemModificador o then
                    InLab_Log (o.name + ": já tem faces escondidas — não empilho outro (use Reverter antes).") tipo:#warn
                else if triAntes != p.antes then
                    InLab_Log (o.name + ": a malha mudou desde o Calcular (" + p.antes as string + " → " + triAntes as string +
                               " triângulos) — calcule de novo.") tipo:#warn
                else
                (
                    local abertos = #()
                    local mods = undefined
                    try
                    (
                        local pai = o.parent
                        while pai != undefined do
                        (
                            if isGroupHead pai and not (isOpenGroupHead pai) do ( setGroupOpen pai true; append abertos pai )
                            pai = pai.parent
                        )
                        mods = InLab_OtimEscondidas_PorModificadores o p.depois
                        local triDepois = (GetTriMeshFaceCount o)[1]
                        if triDepois != triAntes - n then
                        (
                            for m in mods do deleteModifier o m
                            InLab_Log (o.name + ": o DeleteMesh deixou " + triDepois as string + " triângulos (esperado " +
                                       (triAntes - n) as string + ") — modificadores removidos, peça intacta.") tipo:#err
                        )
                        else
                        (
                            local nInst = (InLab_InstanciasDoNo o).count
                            append InLab_UltimasEscondidas (EscondidasRecord no:o modSelecao:mods[1] modApagar:mods[2] faces:p.depois \
                                instancias:nInst trisAntes:triAntes trisDepois:triDepois)
                            aplicados += 1
                            InLab_Log (o.name + (if nInst > 1 then (" (×" + nInst as string + " instâncias, 1 modificador)") else "") + ": " +
                                       (InLab_Otim_Milhar triAntes) + " → " + (InLab_Otim_Milhar triDepois) + " triângulos (" +
                                       n as string + " faces escondidas apagadas).") tipo:#ok
                        )
                    )
                    catch
                    (
                        InLab_Log (o.name + ": erro ao aplicar faces escondidas (" + getCurrentException() + ") — peça intacta.") tipo:#err
                        for m in (InLab_OtimEscondidas_Mods o) where m != undefined do
                            try ( deleteModifier o m )
                            catch ( InLab_Log (o.name + ": não removi um modificador após o erro (" + getCurrentException() + ").") tipo:#err )
                    )
                    for g in abertos where isValidNode g do
                        try ( setGroupOpen g false )
                        catch ( InLab_Log (g.name + ": não fechei o grupo de volta (" + getCurrentException() + ").") tipo:#warn )
                )
            )
        )
        try
        (
            if selOriginal.count > 0 then select (for s in selOriginal where isValidNode s collect s) else clearSelection()
            setCommandPanelTaskMode painelOriginal
        )
        catch ( InLab_Log ("Faces escondidas: não restaurei seleção/painel (" + getCurrentException() + ").") tipo:#warn )
        InLab_Log ("Faces escondidas: " + aplicados as string + " de " + reps.count as string + " peça(s) com o modificador \"" +
                   INLAB_ESC_NOME_MOD + "\".") tipo:(if aplicados == reps.count then #ok else if aplicados == 0 then #err else #warn)
        aplicados
    )
)

--------------------------------------------------------------------------------
-- REVERTER
--------------------------------------------------------------------------------
global InLab_OtimEscondidas_Reverter
fn InLab_OtimEscondidas_Reverter =
(
    InLab_OtimEscondidas_LimparDestaque()
    local n = 0
    -- Sem registro: procura pelo nome (plugin recarregado / cena reaberta).
    local alvos = #()
    if InLab_UltimasEscondidas.count > 0 then
        alvos = for r in InLab_UltimasEscondidas collect #(r.no, #(r.modSelecao, r.modApagar))
    else
        for g in InLab_DeduplicarInstancias (for o in geometry where InLab_OtimEscondidas_TemModificador o collect o) do
            append alvos #(g.no, InLab_OtimEscondidas_Mods g.no)
    if alvos.count == 0 then
        InLab_Log "Faces escondidas: nada aplicado para reverter." tipo:#warn
    else
    (
        undo "InLab Reverter faces escondidas" on
        (
            for a in alvos do
            (
                local o = a[1]
                if not isValidNode o then InLab_Log "Faces escondidas: objeto do registro não existe mais na cena." tipo:#warn
                else
                (
                    local saiu = 0
                    for m in a[2] where m != undefined do
                    (
                        if (for x in o.modifiers where x == m collect x).count == 0 then
                            InLab_Log (o.name + ": \"" + m.name + "\" não está mais no stack (colapsado ou removido?).") tipo:#warn
                        else
                            try ( deleteModifier o m; saiu += 1 )
                            catch ( InLab_Log (o.name + ": não removi \"" + m.name + "\" (" + getCurrentException() + ").") tipo:#err )
                    )
                    if saiu > 0 do
                    (
                        n += 1
                        InLab_Log (o.name + ": faces escondidas de volta (" + (InLab_Otim_Milhar (GetTriMeshFaceCount o)[1]) + " triângulos).") tipo:#ok
                    )
                )
            )
        )
        InLab_UltimasEscondidas = #()
        InLab_Log ("Faces escondidas revertido: " + n as string + " peça(s).") tipo:#ok
    )
    n
)
