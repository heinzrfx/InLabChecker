/*
 functions\fn_mapear_paineis.ms — Mapear por paineis (feature de 26/10/2026).
 Parte 1 (Tarefa 1): vivos (cordao/viés/debrum) e geometria em MUNDO.
 Parte 2 (Tarefa 2): costuras pelo vivo e molde em caixa (InLab_Paineis_Separar),
 contornos (InLab_Paineis_Contornos). Logica do spike (SPK_MontarGrade/Dist/Regioes/
 Juntar/Contornos e o bloco molde em caixa de SPK_Peca), em MUNDO via objectTransform.
 Vivo amostrado a no maximo 8000 pontos por passo fixo num while (collect com
 parametro da "Bad free thunk").
 Spec/plano: docs\superpowers\specs e docs\superpowers\plans (Mapear por paineis);
 logica de referencia no spike docs\superpowers\specs\2026-10-26-spike-paineis.ms.

 Regras:
 - Toda a logica usa coordenadas de MUNDO. polyop.getVert na base devolve espaço
   de OBJETO: InLab_Paineis_Vert multiplica por o.objectTransform.
 - Vivo = elemento fechado, fino (2V/A < 1.5 cm, o raio do tubo) e comprido
   (maior medida > 12 x raio).
 - Nunca polyop.getFacesUsingEdge por aresta (travou o Max 30 min): usa getEdgeFaces.
 - InLab_Paineis_VivosDoProduto: com nos: indefinido varre a geometria sob a mesma
   cabeça de hierarquia de o (a Tarefa 4 restringe as pecas de tecido).
 - Pre-condicao: Vert, VolArea, EhVivo e Elementos exigem no cuja base seja
   Editable_Poly. Sem isso logam #err ("<nome>: base não é Editable_Poly (<classe>)")
   e devolvem valor neutro (Vert undefined, VolArea #(0,0), EhVivo #(false,0,0)).
 - VivosDoProduto avalia nos de base nao-poly (Editable_Mesh, spline renderizavel)
   ou com modificadores por uma copia temporaria em mundo (snapshotAsMesh ->
   Editable_Mesh com transform identidade -> convertToPoly), apagada no fim; malha
   avaliada sem faces: #warn e pula (fix 26/10/2026).
 Pegadinhas: nomes sao case-insensitive (local "a" esconde o parametro "A"); o
 parametro de fn usado dentro de collect em bloco aninhado da "Bad free thunk".
*/
global InLab_Log, InLab_EhGeometria
global InLab_Mapear_PolyDe
global InLab_Paineis_Vert, InLab_Paineis_Elementos, InLab_Paineis_VolArea
global InLab_Paineis_BaseOk, InLab_Paineis_CopiaMundo
global InLab_Paineis_EhVivo, InLab_Paineis_VivosDoProduto, InLab_Paineis_NosDaCabeca
global InLab_Paineis_Separar, InLab_Paineis_Contornos, InLab_Paineis_Regioes, InLab_Paineis_Juntar
global InLab_Paineis_MontarGrade, InLab_Paineis_Dist
global INLAB_PAINEIS_DISTANCIAS = #(0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 3.0)
global INLAB_PAINEIS_LIMIAR_CAIXA = 0.97
global INLAB_PAINEIS_VIVO_MAX_PONTOS = 8000
global INLAB_PAINEIS_GRADE, INLAB_PAINEIS_GMIN, INLAB_PAINEIS_GN, INLAB_PAINEIS_VIVOP

-- base é Editable_Poly? Senão loga #err e devolve false
fn InLab_Paineis_BaseOk o =
(
    local ok = isValidNode o and (classof o.baseobject == Editable_Poly)
    if not ok do
        InLab_Log ((if isValidNode o then o.name else "<nó inválido>") + ": base não é Editable_Poly (" + (if isValidNode o then (classof o.baseobject) as string else "undefined") + ")") tipo:#err
    ok
)

-- cópia temporária em MUNDO (Editable_Poly, transform identidade) da malha avaliada
fn InLab_Paineis_CopiaMundo o =
(
    local c = undefined
    with undo off
    (
        local m = snapshotAsMesh o
        if m.numFaces > 0 do
        (
            c = Editable_Mesh name:(uniqueName "InLab_tmp_paineis")
            c.mesh = m
            update c
            convertToPoly c
        )
        delete m
    )
    c
)

-- vértice v da base de o em coordenadas de mundo
fn InLab_Paineis_Vert o v =
(
    if not (InLab_Paineis_BaseOk o) then undefined
    else (polyop.getVert (InLab_Mapear_PolyDe o) v) * o.objectTransform
)

-- elementos conexos (bitarrays de faces) dentro de faces
fn InLab_Paineis_Elementos po faces =
(
    local resta = copy faces
    local els = #()
    while not resta.isEmpty do
    (
        local f0 = 0
        for f in resta while f0 == 0 do f0 = f
        local el = (polyop.getElementsUsingFace po #{f0}) * faces
        append els el
        resta -= el
    )
    els
)

-- #(volume, area) em MUNDO de um conjunto de faces (fan dos poligonos)
fn InLab_Paineis_VolArea o fs =
(
    if not (InLab_Paineis_BaseOk o) then return #(0.0, 0.0)
    local po = InLab_Mapear_PolyDe o
    local tm = o.objectTransform
    local cache = #()
    local v = 0.0, a = 0.0
    for f in fs do
    (
        local vs = polyop.getFaceVerts po f
        local pts = #()
        for k = 1 to vs.count do
        (
            if cache[vs[k]] == undefined do cache[vs[k]] = (polyop.getVert po vs[k]) * tm
            append pts cache[vs[k]]
        )
        local p0 = pts[1]
        for k = 2 to pts.count - 1 do
        (
            local p1 = pts[k], p2 = pts[k+1]
            v += (dot p0 (cross p1 p2)) / 6.0
            a += (length (cross (p1 - p0) (p2 - p0))) / 2.0
        )
    )
    #(abs v, a)
)

-- #(ehVivo, raio, maiorMedida): fechado, 2V/A < 1.5 cm e maior medida > 12 x raio
fn InLab_Paineis_EhVivo o el =
(
    if not (InLab_Paineis_BaseOk o) then return #(false, 0.0, 0.0)
    local po = InLab_Mapear_PolyDe o
    local va = InLab_Paineis_VolArea o el
    local abertas = ((polyop.getOpenEdges po) * (polyop.getEdgesUsingFace po el)).numberSet
    local mn = [1e9,1e9,1e9], mx = [-1e9,-1e9,-1e9]
    for v in (polyop.getVertsUsingFace po el) do
    (
        local p = InLab_Paineis_Vert o v
        mn = [amin mn.x p.x, amin mn.y p.y, amin mn.z p.z]
        mx = [amax mx.x p.x, amax mx.y p.y, amax mx.z p.z]
    )
    local tam = amax #(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
    local r = if va[2] > 1e-6 then 2.0 * va[1] / va[2] else 0.0
    #(abertas == 0 and va[2] > 1e-6 and r < 1.5 and tam > 12.0 * r, r, tam)
)

-- o nó e todos os descendentes
fn InLab_Paineis_NosDaCabeca cabeca =
(
    local res = #(cabeca)
    local i = 1
    while i <= res.count do
    (
        for c in res[i].children do append res c
        i += 1
    )
    res
)

-- vértices (mundo) dos vivos das peças. nos: lista a varrer; indefinido = toda a
-- geometria sob a cabeça de hierarquia de o (inclusive o). Só varre base Editable_Poly.
fn InLab_Paineis_VivosDoProduto o nos:undefined =
(
    local lista = nos
    if lista == undefined do
    (
        local cabeca = o
        while cabeca.parent != undefined do cabeca = cabeca.parent
        lista = InLab_Paineis_NosDaCabeca cabeca
    )
    local pts = #()
    for n in lista where isValidNode n and (InLab_EhGeometria n) do
    (
        local alvo = n, temp = undefined
        if not (classof n.baseobject == Editable_Poly and n.modifiers.count == 0) do
        (
            temp = InLab_Paineis_CopiaMundo n
            if temp == undefined then
            (
                InLab_Log (n.name + ": malha avaliada sem faces, ignorada nos vivos") tipo:#warn
                alvo = undefined
            )
            else alvo = temp
        )
        if alvo != undefined do
        (
            local po = alvo.baseobject
            local tudo = #{1..(polyop.getNumFaces po)}
            for el in (InLab_Paineis_Elementos po tudo) do
            (
                if (InLab_Paineis_EhVivo alvo el)[1] do
                    for v in (polyop.getVertsUsingFace po el) do append pts (InLab_Paineis_Vert alvo v)
            )
        )
        if temp != undefined do with undo off ( delete temp )
    )
    pts
)

-- grade de 1 cm dos pontos de vivo (mundo). Estado nos globais INLAB_PAINEIS_GRADE/GMIN/GN/VIVOP.
fn InLab_Paineis_MontarGrade pts =
(
    INLAB_PAINEIS_VIVOP = pts
    local mn = [1e9,1e9,1e9], mx = [-1e9,-1e9,-1e9]
    for p in pts do
    (
        mn = [amin mn.x p.x, amin mn.y p.y, amin mn.z p.z]
        mx = [amax mx.x p.x, amax mx.y p.y, amax mx.z p.z]
    )
    INLAB_PAINEIS_GMIN = mn - [4,4,4]
    INLAB_PAINEIS_GN = [ceil (mx.x - mn.x + 8), ceil (mx.y - mn.y + 8), ceil (mx.z - mn.z + 8)]
    local gn = INLAB_PAINEIS_GN
    INLAB_PAINEIS_GRADE = #()
    INLAB_PAINEIS_GRADE.count = (gn.x * gn.y * gn.z) as integer
    for i = 1 to pts.count do
    (
        local q = pts[i] - INLAB_PAINEIS_GMIN
        local k = (floor q.x + gn.x * (floor q.y + gn.y * floor q.z)) as integer + 1
        if INLAB_PAINEIS_GRADE[k] == undefined then INLAB_PAINEIS_GRADE[k] = #(i) else append INLAB_PAINEIS_GRADE[k] i
    )
    true
)

-- distância de p (mundo) ao vivo mais perto (busca de 3 células); 1e9 se longe
fn InLab_Paineis_Dist p =
(
    local melhor = 1e9
    local gn = INLAB_PAINEIS_GN
    local q = p - INLAB_PAINEIS_GMIN
    local cx = floor q.x, cy = floor q.y, cz = floor q.z
    if cx >= 3 and cy >= 3 and cz >= 3 and cx <= gn.x - 4 and cy <= gn.y - 4 and cz <= gn.z - 4 do
        for dx = -3 to 3 do for dy = -3 to 3 do for dz = -3 to 3 do
        (
            local lst = INLAB_PAINEIS_GRADE[(cx + dx + gn.x * (cy + dy + gn.y * (cz + dz))) as integer + 1]
            if lst != undefined do
                for i in lst do
                (
                    local d = distance p INLAB_PAINEIS_VIVOP[i]
                    if d < melhor do melhor = d
                )
        )
    melhor
)

-- regiões de faces conectadas sem atravessar arestas de costura
fn InLab_Paineis_Regioes po faces costura =
(
    local resta = copy faces
    local regs = #()
    while not resta.isEmpty do
    (
        local f0 = 0
        for f in resta while f0 == 0 do f0 = f
        local reg = #{f0}, fila = #(f0)
        resta[f0] = false
        while fila.count > 0 do
        (
            local f = fila[fila.count]
            fila.count = fila.count - 1
            for e in (polyop.getFaceEdges po f) where not costura[e] do
                for g in (polyop.getEdgeFaces po e) where resta[g] do
                (
                    resta[g] = false
                    reg[g] = true
                    append fila g
                )
        )
        append regs reg
    )
    regs
)

-- faces soltas vão para o painel vizinho mais votado (o que sobrar sem vizinho vai ao maior)
fn InLab_Paineis_Juntar po grandes soltas =
(
    local dono = #()
    dono.count = polyop.getNumFaces po
    for i = 1 to grandes.count do for f in grandes[i] do dono[f] = i
    local passes = 0
    while not soltas.isEmpty and passes < 60 do
    (
        passes += 1
        for f in (soltas as array) do
        (
            local voto = for i = 1 to grandes.count collect 0
            for e in (polyop.getFaceEdges po f) do
                for g in (polyop.getEdgeFaces po e) where g != f and dono[g] != undefined do voto[dono[g]] += 1
            local m = 0, k = 0
            for i = 1 to grandes.count where voto[i] > m do ( m = voto[i]; k = i )
            if k > 0 do ( dono[f] = k; grandes[k][f] = true; soltas[f] = false )
        )
    )
    if not soltas.isEmpty do
    (
        local maior = 1
        for i = 2 to grandes.count where grandes[i].numberSet > grandes[maior].numberSet do maior = i
        InLab_Log ("painéis: " + soltas.numberSet as string + " face(s) sem painel vizinho foram para o maior painel") tipo:#info
        grandes[maior] += soltas
    )
    grandes
)

-- número de contornos (bordas fechadas) de um conjunto de faces: 1 = disco, >=2 = anel, 0 = fechado
fn InLab_Paineis_Contornos po fs =
(
    local borda = #{}
    for f in fs do for e in (polyop.getFaceEdges po f) do
    (
        local dentro = 0
        for g in (polyop.getEdgeFaces po e) where fs[g] do dentro += 1
        if dentro == 1 do borda[e] = true
    )
    local resta = copy borda, n = 0
    while not resta.isEmpty do
    (
        local e0 = 0
        for e in resta while e0 == 0 do e0 = e
        local fila = #(e0)
        resta[e0] = false
        n += 1
        while fila.count > 0 do
        (
            local e = fila[fila.count]
            fila.count = fila.count - 1
            for v in (polyop.getEdgeVerts po e) do
                for e2 in (polyop.getEdgesUsingVert po v) where resta[e2] do ( resta[e2] = false; append fila e2 )
        )
    )
    n
)

struct InLab_PaineisSeparacao ( paineis, metodo, eixoCaixa, diag )

-- separa as faces do corpo (bitarray da base de o, sem os vivos) em paineis. vivoPts: pontos
-- de vivo em mundo. Primeiro pelo vivo (menor distancia da lista que dá >= 2 regioes grandes);
-- sem vencedor, molde em caixa (tampo, fundo e faixa pelo eixoCaixa).
fn InLab_Paineis_Separar o corpo vivoPts =
(
    local res = InLab_PaineisSeparacao paineis:#() metodo:"nenhum" eixoCaixa:3 diag:""
    if not (InLab_Paineis_BaseOk o) do return res
    if corpo.numberSet == 0 do
    (
        InLab_Log (o.name + ": painéis: corpo sem faces, nada a separar") tipo:#warn
        return res
    )
    local po = InLab_Mapear_PolyDe o
    local tm = o.objectTransform
    local cacheV = #()
    local nf = polyop.getNumFaces po
    local lista = #()
    local metodo = "nenhum"
    local diag = ""
    if vivoPts.count > 0 do
    (
        -- amostra por passo fixo (while: collect com parametro da "Bad free thunk")
        local passo = amax 1 (vivoPts.count / INLAB_PAINEIS_VIVO_MAX_PONTOS)
        local amostra = #()
        local iv = 1
        while iv <= vivoPts.count do ( append amostra vivoPts[iv]; iv += passo )
        InLab_Paineis_MontarGrade amostra
        local es = (polyop.getEdgesUsingFace po corpo) as array
        local ds = #()
        local dMin = 1e9
        for e in es do
        (
            local vs = polyop.getEdgeVerts po e
            for v in vs where cacheV[v] == undefined do cacheV[v] = (polyop.getVert po v) * tm
            local d = InLab_Paineis_Dist ((cacheV[vs[1]] + cacheV[vs[2]]) / 2.0)
            append ds d
            if d < dMin do dMin = d
        )
        local achou = false
        for lim in INLAB_PAINEIS_DISTANCIAS while not achou do
        (
            local cost = #{}
            for i = 1 to es.count where ds[i] < lim do cost[es[i]] = true
            if cost.numberSet > 0 do
            (
                local regs = InLab_Paineis_Regioes po corpo cost
                local minimo = amax 50 (corpo.numberSet * 0.03)
                local grandes = for g in regs where g.numberSet >= minimo collect g
                if grandes.count >= 2 do
                (
                    local soltas = #{}
                    for g in regs where g.numberSet < minimo do soltas += g
                    lista = InLab_Paineis_Juntar po grandes soltas
                    metodo = "vivo (" + (lim as string) + " cm)"
                    achou = true
                )
            )
        )
        if not achou do
            diag = if dMin < 1e8 then ("vivo não fechou o contorno (menor distância " + (((floor (dMin * 10.0 + 0.5)) / 10.0) as string) + " cm)") else "vivo a mais de 3 cm"
    )
    local eixo = 3
    if lista.count == 0 do
    (
        -- molde em caixa: eixo = a menor medida do corpo (se bem mais fina que as outras), senão Z
        local mn = [1e9,1e9,1e9], mx = [-1e9,-1e9,-1e9]
        for v in (polyop.getVertsUsingFace po corpo) do
        (
            local q = (polyop.getVert po v) * tm
            mn = [amin mn.x q.x, amin mn.y q.y, amin mn.z q.z]
            mx = [amax mx.x q.x, amax mx.y q.y, amax mx.z q.z]
        )
        local tams = #(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
        local kMin = 3
        for i = 1 to 3 where tams[i] < tams[kMin] do kMin = i
        local outros = for i = 1 to 3 where i != kMin collect tams[i]
        eixo = if kMin != 3 and tams[kMin] < 0.8 * (amin outros) then kMin else 3
        local ax = #([1,0,0], [0,1,0], [0,0,1])[eixo]
        local lado = #()
        lado.count = nf
        for f in corpo do
        (
            local n = (polyop.getFaceNormal po f) * tm - tm.row4  -- normal em mundo (vetor)
            local c = dot (normalize n) ax
            lado[f] = if c > INLAB_PAINEIS_LIMIAR_CAIXA then 1 else if c < -INLAB_PAINEIS_LIMIAR_CAIXA then 2 else 3
        )
        -- suavização: voto ponderado pelo comprimento (mundo) da aresta compartilhada; só faces da
        -- faixa (classe 3) viram tampo/fundo, e só se essa classe tem MAIS DA METADE do perímetro
        local elen = #()
        for passe = 1 to 4 do
        (
            local novo = copy lado #nomap
            for f in corpo do
            (
                local w = #(0.0, 0.0, 0.0)
                local per = 0.0
                for e in (polyop.getFaceEdges po f) do
                (
                    if elen[e] == undefined do
                    (
                        local ev = polyop.getEdgeVerts po e
                        for v in ev where cacheV[v] == undefined do cacheV[v] = (polyop.getVert po v) * tm
                        elen[e] = distance cacheV[ev[1]] cacheV[ev[2]]
                    )
                    per += elen[e]
                    for g in (polyop.getEdgeFaces po e) where g != f and corpo[g] do w[lado[g]] += elen[e]
                )
                local m = lado[f]
                for k = 1 to 3 where w[k] > w[m] do m = k
                -- face plana de verdade (classe 1/2, normal acima do limiar) nunca muda: um n-gono grande
                -- de tampo teria 100% do perímetro encostado na faixa e seria engolido por ela
                if lado[f] == 3 and m != 3 and w[m] > per / 2.0 do novo[f] = m
            )
            lado = novo
        )
        local pp = #(#{}, #{}, #{})
        for f in corpo do pp[lado[f]][f] = true
        lista = for p in pp where p.numberSet > 0 collect p
        metodo = "molde em caixa (eixo " + #("X","Y","Z")[eixo] + ")"
    )
    res.paineis = lista
    res.metodo = metodo
    res.eixoCaixa = eixo
    res.diag = diag
    res
)
