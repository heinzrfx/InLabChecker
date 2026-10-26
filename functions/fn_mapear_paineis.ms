/*
 functions\fn_mapear_paineis.ms — Mapear por paineis (feature de 26/10/2026).
 Parte 1 (Tarefa 1): vivos (cordao/viés/debrum) e geometria em MUNDO.
 Parte 2 (Tarefa 2): costuras pelo vivo e molde em caixa (InLab_Paineis_Separar),
 contornos (InLab_Paineis_Contornos). Logica do spike (SPK_MontarGrade/Dist/Regioes/
 Juntar/Contornos e o bloco molde em caixa de SPK_Peca), em MUNDO via objectTransform.
 Vivo amostrado a no maximo 8000 pontos por passo fixo num while (collect com
 parametro da "Bad free thunk").
 Parte 3 (Tarefa 3): UV de cada painel (InLab_Paineis_UV, sem gravar: devolve #(uvs, mapa,
 resumo) do InLab_Mapear_Gravar) e trama torta (InLab_Paineis_Torta). Port de SPK_UVDisco,
 SPK_UVAnel (volta e perfil varrido, sem escalar U por r/rOut), SPK_Unfold, SPK_AngDir,
 SPK_Girar, SPK_FlipU, SPK_Espelho e SPK_DesalinhoRef, em MUNDO. Unfold3D num nó temporário
 (polyop.detachFaces asNode de uma CÓPIA do nó, ambos apagados no fim: o detach com
 delete:false acrescenta vértices de mapa no canal 1 da origem, achado em 26/10/2026;
 select/modPanel em with undo off; seleção devolvida), lido por canto de face. Nó espelhado: normal e espelho pelo sinal do transform.
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
global InLab_Mapear_NoEspelhado
global InLab_Paineis_Sinal, InLab_Paineis_PosMundo, InLab_Paineis_NormalArea, InLab_Paineis_EixoAnel
global InLab_Paineis_UVDisco, InLab_Paineis_AngP, InLab_Paineis_LDe, InLab_Paineis_RDe, InLab_Paineis_SPerfil
global InLab_Paineis_UVAnel, InLab_Paineis_DirUV, InLab_Paineis_TortaP, InLab_Paineis_Torta
global InLab_Paineis_AngDir, InLab_Paineis_Girar, InLab_Paineis_FlipU, InLab_Paineis_EspelhoUV
global InLab_Paineis_Unfold, InLab_Paineis_UV
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

---------------- Tarefa 3: UV de cada painel (spec 5.5 e 5.6) ----------------
-- Tudo em MUNDO. Nada é gravado no nó: cada painel gera #(uvs, mapa) próprios, e o
-- Unfold3D roda num nó temporário (detachFaces asNode, apagado no fim).

-- -1 se o nó é espelhado (a normal que aparece é a oposta do sentido dos vértices em mundo)
fn InLab_Paineis_Sinal o = ( if InLab_Mapear_NoEspelhado o then -1.0 else 1.0 )

-- posição (mundo) dos vértices das faces fs, indexada pelo vértice da base
fn InLab_Paineis_PosMundo o fs =
(
    local po = InLab_Mapear_PolyDe o
    local tm = o.objectTransform
    local posM = #()
    for v in (polyop.getVertsUsingFace po fs) do posM[v] = (polyop.getVert po v) * tm
    posM
)

-- normal (mundo) de uma face com comprimento = área; sinal -1 no nó espelhado
fn InLab_Paineis_NormalArea posM vs sinal =
(
    local n = [0,0,0]
    local p0 = posM[vs[1]]
    for j = 2 to vs.count - 1 do n += cross (posM[vs[j]] - p0) (posM[vs[j+1]] - p0)
    n * (0.5 * sinal)
)

-- eixo do anel pelo vivo: o eixo do mundo com menor soma de área x |n·eixo|
fn InLab_Paineis_EixoAnel po posM fs sinal =
(
    local s = #(0.0, 0.0, 0.0)
    for f in fs do
    (
        local n = InLab_Paineis_NormalArea posM (polyop.getFaceVerts po f) sinal
        s[1] += abs n.x; s[2] += abs n.y; s[3] += abs n.z
    )
    local k = 1
    for i = 2 to 3 where s[i] < s[k] do k = i
    k
)

-- disco: projeção plana na normal média (T horizontal, X do mundo se a normal é quase vertical)
fn InLab_Paineis_UVDisco po posM fs escala sinal =
(
    local n = [0,0,0]
    for f in fs do n += InLab_Paineis_NormalArea posM (polyop.getFaceVerts po f) sinal
    n = normalize n
    local eT = if abs n.z > 0.9 then [1,0,0] else normalize [-n.y, n.x, 0]
    local eB = cross n eT
    local uvs = #(), mapa = #(), tab = #()
    for f in fs do
    (
        local ids = #()
        for v in (polyop.getFaceVerts po f) do
        (
            if tab[v] == undefined do
            (
                local q = posM[v]
                append uvs [(dot q eT) * escala, (dot q eB) * escala, 0]
                tab[v] = uvs.count
            )
            append ids tab[v]
        )
        append mapa #(f, ids)
    )
    #(uvs, mapa, n)
)

-- ângulo (0..360) de p em volta do centro (c1, c2) no plano (e1, e2), já deslocado para o corte ficar em 0
fn InLab_Paineis_AngP p e1 e2 c1 c2 corte =
(
    local s = (atan2 ((dot p e2) - c2) ((dot p e1) - c1)) - corte
    while s < 0 do s += 360.0
    while s >= 360 do s -= 360.0
    s
)
-- comprimento ao longo do contorno de fora no ângulo ang (tabela ângulo -> comprimento)
fn InLab_Paineis_LDe ang tabA tabL =
(
    if ang < tabA[1] do ang += 360.0
    local i = 1
    while i < tabA.count and tabA[i+1] < ang do i += 1
    if i >= tabA.count then tabL[tabL.count]
    else tabL[i] + (ang - tabA[i]) / (amax 1e-6 (tabA[i+1] - tabA[i])) * (tabL[i+1] - tabL[i])
)
-- raio de fora no ângulo ang (faixa de 2 graus mais perto que tem amostra)
fn InLab_Paineis_RDe ang rOut =
(
    local b = (floor (ang / 2.0)) as integer + 1
    if b > 180 do b = 180
    local i = 0
    local r = undefined
    while r == undefined and i < 90 do
    (
        for s in #(b + i, b - i) where s >= 1 and s <= 180 and r == undefined do r = rOut[s]
        i += 1
    )
    if r == undefined then 0.0 else r
)
-- comprimento ao longo do perfil da seção, no plano (dr, t)
fn InLab_Paineis_SPerfil dr t drc tc perfTabA perfTabS =
(
    local ang = atan2 (t - tc) (dr - drc)
    local i = 1
    while i < perfTabA.count and perfTabA[i+1] < ang do i += 1
    if i >= perfTabA.count then perfTabS[perfTabS.count]
    else if ang <= perfTabA[1] then 0.0
    else perfTabS[i] + (ang - perfTabA[i]) / (amax 1e-6 (perfTabA[i+1] - perfTabA[i])) * (perfTabS[i+1] - perfTabS[i])
)

-- anel em volta do eixo k (1=X 2=Y 3=Z). Volta pelo contorno de fora (maior raio a cada
-- 2 graus); corte numa quina de trás (entre -X e +Y) se o eixo é Z, embaixo (-Z) se é
-- horizontal. perfil:true troca a coordenada no eixo pelo comprimento ao longo do perfil
-- da seção (plano raio x eixo). O U NÃO é escalado por r/rOut (abre a trama em leque).
fn InLab_Paineis_UVAnel po posM fs k escala perfil:false =
(
    local ax = #([1,0,0], [0,1,0], [0,0,1])[k]
    local e1 = if k == 3 then [1,0,0] else if k == 1 then [0,1,0] else [1,0,0]
    local e2 = if k == 3 then [0,1,0] else [0,0,1]
    local vs = (polyop.getVertsUsingFace po fs) as array
    local c1 = 0.0, c2 = 0.0
    for v in vs do ( local q = posM[v]; c1 += dot q e1; c2 += dot q e2 )
    c1 /= vs.count; c2 /= vs.count
    local corte = if k == 3 then 135.0 else -90.0
    -- contorno de fora: maior raio a cada 2 graus
    local bins = #()
    bins.count = 180
    for v in vs do
    (
        local q = posM[v]
        local ang = InLab_Paineis_AngP q e1 e2 c1 c2 corte
        local r = distance [(dot q e1), (dot q e2), 0] [c1, c2, 0]
        local b = (floor (ang / 2.0)) as integer + 1
        if b > 180 do b = 180
        if bins[b] == undefined or r > bins[b][1] do bins[b] = #(r, [(dot q e1), (dot q e2), 0], ang)
    )
    local pts = #()
    for b in bins where b != undefined do append pts b
    local tabA = #(), tabL = #()
    local acc = 0.0
    for i = 1 to pts.count do
    (
        if i > 1 do acc += distance pts[i][2] pts[i-1][2]
        append tabA pts[i][3]
        append tabL acc
    )
    local perim = acc + (distance pts[1][2] pts[pts.count][2])
    append tabA (pts[1][3] + 360.0)
    append tabL perim
    local rOut = #()
    rOut.count = 180
    for i = 1 to 180 where bins[i] != undefined do rOut[i] = bins[i][1]
    local perfTabA = #(), perfTabS = #(), drc = 0.0, tc = 0.0
    if perfil do
    (
        local amostras = #(), drMin = 0.0, tMin = 1e9, tMax = -1e9
        for v in vs do
        (
            local q = posM[v]
            local ang = InLab_Paineis_AngP q e1 e2 c1 c2 corte
            local r = distance [(dot q e1), (dot q e2), 0] [c1, c2, 0]
            local dr = r - (InLab_Paineis_RDe ang rOut)
            local tq = dot q ax
            append amostras [dr, tq, 0]
            drMin = amin drMin dr; tMin = amin tMin tq; tMax = amax tMax tq
        )
        drc = drMin
        tc = (tMin + tMax) / 2.0
        -- por grau do ângulo em volta de (drc, tc), o ponto mais longe
        local pb = #()
        pb.count = 181
        for am in amostras do
        (
            local ang = atan2 (am.y - tc) (am.x - drc)
            local i = (floor (ang + 90.0)) as integer + 1
            if i < 1 do i = 1
            if i > 181 do i = 181
            local d = distance am [drc, tc, 0]
            if pb[i] == undefined or d > pb[i][1] do pb[i] = #(d, am, ang)
        )
        local ps2 = #()
        for b in pb where b != undefined do append ps2 b
        local acc2 = 0.0
        for i = 1 to ps2.count do
        (
            if i > 1 do acc2 += distance ps2[i][2] ps2[i-1][2]
            append perfTabA ps2[i][3]
            append perfTabS acc2
        )
    )
    local uvs = #(), mapa = #(), tabBaixo = #(), tabAlto = #()
    for f in fs do
    (
        local fv = polyop.getFaceVerts po f
        local angs = #()
        for v in fv do append angs (InLab_Paineis_AngP posM[v] e1 e2 c1 c2 corte)
        local atravessa = ((amax angs) - (amin angs)) > 180.0
        local ids = #()
        for j = 1 to fv.count do
        (
            local alto = atravessa and angs[j] < 180.0
            local tt = if alto then tabAlto else tabBaixo
            local v = fv[j]
            if tt[v] == undefined do
            (
                local q = posM[v]
                local s = (InLab_Paineis_LDe angs[j] tabA tabL) + (if alto then perim else 0.0)
                local tEixo = dot q ax
                if perfil do
                (
                    local r = distance [(dot q e1), (dot q e2), 0] [c1, c2, 0]
                    local ro = InLab_Paineis_RDe angs[j] rOut
                    tEixo = InLab_Paineis_SPerfil (r - ro) (dot q ax) drc tc perfTabA perfTabS
                )
                -- eixo vertical: U = volta, V = altura (ou perfil); horizontal: U = eixo (ou perfil), V = volta
                append uvs (if k == 3 then [s * escala, tEixo * escala, 0] else [tEixo * escala, s * escala, 0])
                tt[v] = uvs.count
            )
            append ids tt[v]
        )
        append mapa #(f, ids)
    )
    #(uvs, mapa)
)

-- direção (2D, no UV) da direção dir do mundo projetada na face f (pela combinação exata
-- das arestas); undefined se dir fica quase na normal (projeção < lim) ou a face é degenerada
fn InLab_Paineis_DirUV po posM f ids uvs dir lim =
(
    local vs = polyop.getFaceVerts po f
    local p0 = posM[vs[1]], p1 = posM[vs[2]], p2 = posM[vs[3]]
    local t0 = uvs[ids[1]], t1 = uvs[ids[2]], t2 = uvs[ids[3]]
    local a1 = p1 - p0, a2 = p2 - p0
    local cr = cross a1 a2
    local res = undefined
    if (length cr) > 1e-12 do
    (
        local nn = normalize cr
        local xp = dir - nn * (dot nn dir)
        if (length xp) > lim do
        (
            local g11 = dot a1 a1, g12 = dot a1 a2, g22 = dot a2 a2
            local b1 = dot xp a1, b2 = dot xp a2
            local det = g11*g22 - g12*g12
            if abs det > 1e-12 do
            (
                local x1 = (b1*g22 - b2*g12) / det, x2 = (b2*g11 - b1*g12) / det
                local d = (t1 - t0) * x1 + (t2 - t0) * x2
                if (length d) > 1e-12 do res = d
            )
        )
    )
    res
)

-- fração da área (0..1) em que dir (mundo) sai a mais de 15 graus do ângulo alvo no UV (mod 180)
fn InLab_Paineis_TortaP po posM uvs mapa fs dir alvo =
(
    local ruim = 0.0, tot = 0.0
    for e in mapa where fs[e[1]] do
    (
        local d = InLab_Paineis_DirUV po posM e[1] e[2] uvs dir 0.3
        if d != undefined do
        (
            local dv = abs ((atan2 d.y d.x) - alvo)
            while dv > 180.0 do dv -= 180.0
            if dv > 90.0 do dv = 180.0 - dv
            local ar = length (InLab_Paineis_NormalArea posM (polyop.getFaceVerts po e[1]) 1.0)
            tot += ar
            if dv > 15.0 do ruim += ar
        )
    )
    if tot > 0 then ruim / tot else 0.0
)

-- trama torta (spike SPK_DesalinhoRef) de uvs/mapa (formato do InLab_Mapear_Gravar) nas faces fs de o
fn InLab_Paineis_Torta uvs mapa o fs dir alvo =
(
    if not (InLab_Paineis_BaseOk o) then 1.0
    else InLab_Paineis_TortaP (InLab_Mapear_PolyDe o) (InLab_Paineis_PosMundo o fs) uvs mapa fs dir alvo
)

-- ângulo médio (graus, no UV) de dir do mundo projetada nas faces
fn InLab_Paineis_AngDir po posM uvs mapa dir =
(
    local g = [0,0,0]
    for e in mapa do
    (
        local d = InLab_Paineis_DirUV po posM e[1] e[2] uvs dir 0.2
        if d != undefined do g += (normalize d) * (length (InLab_Paineis_NormalArea posM (polyop.getFaceVerts po e[1]) 1.0))
    )
    atan2 g.y g.x
)

-- gira todos os uvs em volta do centro (graus)
fn InLab_Paineis_Girar uvs ang =
(
    local c = [0,0,0]
    for q in uvs do c += q
    c /= uvs.count
    local cs = cos ang, sn = sin ang
    for i = 1 to uvs.count do
    (
        local u = uvs[i] - c
        uvs[i] = [u.x * cs - u.y * sn, u.x * sn + u.y * cs, 0] + c
    )
    uvs
)

fn InLab_Paineis_FlipU uvs = ( for i = 1 to uvs.count do uvs[i] = [-uvs[i].x, uvs[i].y, 0]; uvs )

-- fração da área com UV espelhado (produto vetorial 2D contra o sentido da face que aparece)
fn InLab_Paineis_EspelhoUV po posM uvs mapa sinal =
(
    local ruim = 0.0, tot = 0.0
    for e in mapa do
    (
        local ids = e[2]
        local t0 = uvs[ids[1]], t1 = uvs[ids[2]], t2 = uvs[ids[3]]
        local cuv = (t1 - t0).x * (t2 - t0).y - (t1 - t0).y * (t2 - t0).x
        local ar = length (InLab_Paineis_NormalArea posM (polyop.getFaceVerts po e[1]) 1.0)
        tot += ar
        if cuv * sinal < 0 do ruim += ar
    )
    if tot > 0 then ruim / tot else 0.0
)

-- Unfold3D a partir de uvs/mapa (o UV inicial, com os cortes) num nó temporário com as faces fs
-- (polyop.detachFaces asNode, apagado no fim). Escala pela área (3D em mundo / UV) e posição pelo
-- centro do UV inicial; o giro fica para quem chama. A face k do nó temporário é a k-ésima de fs;
-- o resultado é lido por canto de face (o solve renumera os vértices de UV). undefined se falhou.
fn InLab_Paineis_Unfold o fs uvs mapa posM escala =
(
    local po = InLab_Mapear_PolyDe o
    local lista = fs as array
    local idsDe = #()
    for e in mapa do idsDe[e[1]] = e[2]
    local nome = uniqueName "InLab_tmp_unfold"
    local tmp = undefined, src = undefined, novos = undefined
    local selAntes = selection as array
    try
    (
        with undo off
        (
            -- o detach (mesmo com delete:false) mexe no canal 1 da origem (acrescenta vértices
            -- de mapa): destaca de uma cópia do nó, nunca do nó real
            src = copy o
            src.name = uniqueName "InLab_tmp_unfold_src"
            polyop.detachFaces src.baseobject fs delete:false asNode:true name:nome node:src
            tmp = getNodeByName nome
            local tp = tmp.baseobject
            if (polyop.getNumFaces tp) != lista.count do throw "nó temporário com outro número de faces"
            for k = 1 to lista.count do
                if (polyop.getFaceDeg tp k) != idsDe[lista[k]].count do throw "nó temporário com faces em outra ordem"
            polyop.setMapSupport tp 1 true
            polyop.setNumMapVerts tp 1 uvs.count keep:false
            for i = 1 to uvs.count do polyop.setMapVert tp 1 i uvs[i]
            for k = 1 to lista.count do polyop.setMapFace tp 1 k idsDe[lista[k]]
            max modify mode
            select tmp
            local uvw = Unwrap_UVW()
            addModifier tmp uvw
            modPanel.setCurrentObject uvw
            uvw.setMapChannel 1
            uvw.selectFaces #{1..(uvw.numberPolygons())}
            uvw.Unfold3DSolve()
            novos = #()
            for k = 1 to lista.count do
            (
                local q = #()
                for j = 1 to (uvw.numberPointsInFace k) do append q (uvw.getVertexPosition 0 (uvw.getVertexIndexFromFace k j))
                if q.count != idsDe[lista[k]].count do throw "face com outro número de cantos depois do Unfold3D"
                append novos q
            )
        )
    )
    catch
    (
        InLab_Log (o.name + ": painéis: Unfold3D falhou (" + (getCurrentException()) + ")") tipo:#warn
        novos = undefined
    )
    with undo off
    (
        if isValidNode tmp do delete tmp
        if isValidNode src do delete src
        clearSelection()
        for n in selAntes where isValidNode n do selectMore n
    )
    if novos == undefined then undefined
    else
    (
        local a3 = 0.0, auv = 0.0, cN = [0,0,0], cV = [0,0,0], nc = 0
        for k = 1 to lista.count do
        (
            a3 += length (InLab_Paineis_NormalArea posM (polyop.getFaceVerts po lista[k]) 1.0)
            local q = novos[k]
            for j = 2 to q.count - 1 do auv += abs (((q[j] - q[1]).x * (q[j+1] - q[1]).y - (q[j] - q[1]).y * (q[j+1] - q[1]).x) / 2.0)
            local ids = idsDe[lista[k]]
            for j = 1 to ids.count do ( cN += q[j]; cV += uvs[ids[j]]; nc += 1 )
        )
        cN /= nc; cV /= nc
        local s = (sqrt (a3 / (amax 1e-12 auv))) * escala
        local novoDe = #(), uvs2 = #(), mapa2 = #()
        for k = 1 to lista.count do
        (
            local ids = idsDe[lista[k]]
            local ids2 = #()
            for j = 1 to ids.count do
            (
                if novoDe[ids[j]] == undefined do
                (
                    local q = (novos[k][j] - cN) * s + cV
                    append uvs2 [q.x, q.y, 0]
                    novoDe[ids[j]] = uvs2.count
                )
                append ids2 novoDe[ids[j]]
            )
            append mapa2 #(lista[k], ids2)
        )
        #(uvs2, mapa2)
    )
)

-- UV de cada painel, SEM gravar: #(uvs, mapa, resumo) no formato de InLab_Mapear_Gravar.
-- Disco: plano + Unfold3D + giro travado. Anel: eixo da caixa (molde em caixa) ou o do mundo
-- pelas normais; volta, Unfold3D a partir da volta e perfil varrido; fica o de menor trama
-- torta (o Unfold3D só se ganhar por 0,02). escala = UV por cm. undefined (com #warn) se um
-- disco não abre no Unfold3D ou um painel não tem contorno.
fn InLab_Paineis_UV o paineis metodo eixoCaixa escala =
(
    if not (InLab_Paineis_BaseOk o) do return undefined
    if paineis.count == 0 do
    (
        InLab_Log (o.name + ": painéis: nenhum painel para mapear") tipo:#warn
        return undefined
    )
    local po = InLab_Mapear_PolyDe o
    local sinal = InLab_Paineis_Sinal o
    local caixa = matchPattern metodo pattern:"molde em caixa*"
    local uvsT = #(), mapaT = #(), partes = #(), nDiscos = 0
    local falhou = ""
    for pn in paineis while falhou == "" do
    (
        local posM = InLab_Paineis_PosMundo o pn
        local nCont = InLab_Paineis_Contornos po pn
        local cand = undefined
        if nCont >= 2 then
        (
            -- no molde em caixa a faixa é vertical por construção
            local k = if caixa then eixoCaixa else InLab_Paineis_EixoAnel po posM pn sinal
            local dirA = #([1,0,0], [0,1,0], [0,0,1])[k]
            local alvo = if k == 3 then 90.0 else 0.0
            -- 1. volta
            local cVolta = InLab_Paineis_UVAnel po posM pn k escala
            if (InLab_Paineis_EspelhoUV po posM cVolta[1] cVolta[2] sinal) > 0.5 do InLab_Paineis_FlipU cVolta[1]
            local desVolta = InLab_Paineis_TortaP po posM cVolta[1] cVolta[2] pn dirA alvo
            -- 2. Unfold3D a partir da volta, giro travado pelo eixo
            local desUnf = 2.0
            local cUnf = InLab_Paineis_Unfold o pn cVolta[1] cVolta[2] posM escala
            if cUnf != undefined do
            (
                InLab_Paineis_Girar cUnf[1] (alvo - (InLab_Paineis_AngDir po posM cUnf[1] cUnf[2] dirA))
                if (InLab_Paineis_EspelhoUV po posM cUnf[1] cUnf[2] sinal) > 0.5 do InLab_Paineis_FlipU cUnf[1]
                desUnf = InLab_Paineis_TortaP po posM cUnf[1] cUnf[2] pn dirA alvo
            )
            -- 3. perfil varrido
            local cPerf = InLab_Paineis_UVAnel po posM pn k escala perfil:true
            if (InLab_Paineis_EspelhoUV po posM cPerf[1] cPerf[2] sinal) > 0.5 do InLab_Paineis_FlipU cPerf[1]
            local desPerf = InLab_Paineis_TortaP po posM cPerf[1] cPerf[2] pn dirA alvo
            local usa = "pelo perfil", desF = desPerf
            cand = cPerf
            if desVolta <= desF do ( usa = "pela volta"; desF = desVolta; cand = cVolta )
            if cUnf != undefined and desUnf + 0.02 < desF do ( usa = "pelo Unfold3D"; desF = desUnf; cand = cUnf )
            append partes ("faixa " + usa + ", " + (if k == 3 then "corte na quina de trás" else "corte embaixo"))
        )
        else if nCont == 1 then
        (
            local cDisco = InLab_Paineis_UVDisco po posM pn escala sinal
            local nD = cDisco[3]
            cand = InLab_Paineis_Unfold o pn cDisco[1] cDisco[2] posM escala
            if cand == undefined then falhou = "Unfold3D falhou num disco"
            else
            (
                local vertical = abs nD.z > 0.9
                local dirD = if vertical then [1,0,0] else [0,0,1]
                local alvoD = if vertical then 0.0 else 90.0
                InLab_Paineis_Girar cand[1] (alvoD - (InLab_Paineis_AngDir po posM cand[1] cand[2] dirD))
                if (InLab_Paineis_EspelhoUV po posM cand[1] cand[2] sinal) > 0.5 do InLab_Paineis_FlipU cand[1]
                nDiscos += 1
            )
        )
        else falhou = "painel sem contorno"
        if falhou == "" do
        (
            local base = uvsT.count
            join uvsT cand[1]
            for e in cand[2] do
            (
                local ids = #()
                for i in e[2] do append ids (i + base)
                append mapaT #(e[1], ids)
            )
        )
    )
    if falhou != "" then
    (
        InLab_Log (o.name + ": painéis: " + falhou + "; peça como estava") tipo:#warn
        undefined
    )
    else
    (
        if nDiscos > 0 do append partes (nDiscos as string + (if nDiscos == 1 then " disco" else " discos"))
        local resumo = ""
        for i = 1 to partes.count do resumo += (if i > 1 then "; " else "") + partes[i]
        #(uvsT, mapaT, resumo)
    )
)
