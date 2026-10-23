/*
 === functions\fn_mapear_gerar.ms ===
 Mapear (23/10/2026): geradores de UV do canal 1, portados do spike validado em
 Max em cadeiras reais (docs\superpowers\specs\2026-10-23-spike-mapear.ms).
 Todos recebem um Editable Poly `o`, um bitarray `faces` (faces do poly) e `escala`
 (UV por cm) e devolvem #(uvs, mapa):
   uvs  = array de point3;
   mapa = array de #(face, #(índices em uvs, na ordem de polyop.getFaceVerts)).
 Faces de `faces` sem entrada no mapa ficam para o chamador (tampas de tubo etc.).
 Coordenadas em espaço de objeto: polyop.getVert devolve MUNDO por padrão, então tudo
 roda em `in coordsys local` (cena em cm); a conta
 de espelhamento usa o transform do nó.

 - InLab_Mapear_GerarMadeira o faces escala veio : veio na aresta longa, projeção
   por face alisada por voto dos vizinhos, nenhuma face espelhada (spec 5.2).
   #vertical gira o UV 90 graus (U,V) -> (-V,U), que preserva a orientação;
   #semDirecao = #horizontal.
 - InLab_Mapear_GerarTubo o faces escala : grade comprimento x volta por quads, um
   elemento de cada vez (spec 5.3). undefined se nenhum elemento é tubo (grade
   irregular ou menos de 8 quads). Tampas ficam fora do mapa.
 - InLab_Mapear_GerarBox o faces escala : projeção por face pelo eixo dominante
   (laterais U horizontal, topo U = X, T x B = normal), vértices de UV por
   (vértice, eixo, sinal) (spec 5.5).
 - InLab_Mapear_Gravar o uvs mapa : grava no canal 1; faces sem mapa mantêm o UV atual.

 Decisões/lições: o spike acertou a madeira SEM inverter o B para nó espelhado, mas
 a medição (InLab_Mapear_Medir, que multiplica pelo sinal do nó) conta um nó espelhado
 como 100% espelhado; por isso madeira e box invertem o V quando o nó tem escala
 negativa (23/10/2026). O tubo usa o sinal da maioria das faces (InLab_Mapear_SinalUV,
 com a correção do transform do nó).
 Pegadinhas: "for e in array by N" não parseia (laço por índice); fn usado antes
 de definido precisa de global.
*/
global InLab_Log
global InLab_Mapear_NoEspelhado, InLab_Mapear_SinalUV, InLab_Mapear_Vizinho
global InLab_Mapear_Outro, InLab_Mapear_Passo, InLab_Mapear_TuboElemento
global InLab_Mapear_MadeiraLocal, InLab_Mapear_BoxLocal
global InLab_Mapear_GerarMadeira, InLab_Mapear_GerarTubo, InLab_Mapear_GerarBox, InLab_Mapear_Gravar

-- nó com escala negativa (espelhado)
fn InLab_Mapear_NoEspelhado o = ( local t = o.transform; (dot (cross t.row1 t.row2) t.row3) < 0 )

-- orientação do UV de uma face (+1 normal, -1 espelhado), no sentido de render
fn InLab_Mapear_SinalUV o f idx uvs base =
(
    local vs = polyop.getFaceVerts o f
    local p1 = polyop.getVert o vs[1]; local p2 = polyop.getVert o vs[2]; local p3 = polyop.getVert o vs[3]
    local t1 = uvs[idx[1] - base]; local t2 = uvs[idx[2] - base]; local t3 = uvs[idx[3] - base]
    local e1 = p2 - p1; local e2 = p3 - p1
    local d1 = t2 - t1; local d2 = t3 - t1
    -- dP/du e dP/dv sem dividir pelo det: o produto vetorial fica dividido por det², mesmo sinal
    local dPdu = (e1*d2.y - e2*d1.y); local dPdv = (e2*d1.x - e1*d2.x)
    local sg = dot (cross dPdu dPdv) (cross e1 e2)
    if InLab_Mapear_NoEspelhado o then (if sg > 0 then -1 else 1) else (if sg > 0 then 1 else -1)
)

-- vizinho do polígono f pela aresta (a,b), dentro do conjunto permitido
fn InLab_Mapear_Vizinho o f a b permitidos =
(
    local fs = ((polyop.getFacesUsingVert o a) * (polyop.getFacesUsingVert o b)) - #{f}
    local r = undefined
    for g in fs where permitidos[g] do r = g
    r
)

-- no polígono g, o vizinho de v no ciclo que não é w
fn InLab_Mapear_Outro o g v w =
(
    local vs = polyop.getFaceVerts o g
    local k = findItem vs v; local n = vs.count
    local ant = vs[if k == 1 then n else k - 1]; local prox = vs[if k == n then 1 else k + 1]
    if ant == w then prox else ant
)

-- quad = #(f, BL, BR, TR, TL); dir: #dir (direita), #esq, #cima
fn InLab_Mapear_Passo o q dir permitidos =
(
    local a, b
    case dir of
    (
        #dir: ( a = q[3]; b = q[4] )
        #esq: ( a = q[2]; b = q[5] )
        #cima: ( a = q[5]; b = q[4] )
    )
    local g = InLab_Mapear_Vizinho o q[1] a b permitidos
    if g == undefined then undefined
    else
    (
        local oa = InLab_Mapear_Outro o g a b; local ob = InLab_Mapear_Outro o g b a
        case dir of
        (
            #dir: #(g, a, oa, ob, b)
            #esq: #(g, oa, a, b, ob)
            #cima: #(g, a, b, ob, oa)
        )
    )
)

-- mapeia um elemento tubular; #(uvs, mapa, cobertas) ou undefined. `base` desloca os índices.
fn InLab_Mapear_TuboElemento o faces s base =
(
    local quads = #{}
    for f in faces where polyop.getFaceDeg o f == 4 do quads[f] = true
    if quads.numberSet < 8 do return undefined
    local f0 = (for f in quads collect f)[1]
    local vs = polyop.getFaceVerts o f0
    local q0 = #(f0, vs[1], vs[2], vs[3], vs[4])
    -- faixa i (direita), fechada ou aberta
    local faixa = #(q0); local fechadaI = false
    local q = q0
    while true do
    (
        q = InLab_Mapear_Passo o q #dir quads
        if q == undefined then exit
        if q[1] == f0 then ( fechadaI = true; exit )
        append faixa q
        if faixa.count > 100000 then exit
    )
    if not fechadaI do
    (
        q = q0
        while true do
        (
            q = InLab_Mapear_Passo o q #esq quads
            if q == undefined then exit
            insertItem q faixa 1
        )
    )
    -- colunas j (cima)
    local Q = #(); local fechadaJ = undefined; local nj = undefined
    for qi in faixa do
    (
        local col = #(qi); local fc = false; local p = qi
        while true do
        (
            p = InLab_Mapear_Passo o p #cima quads
            if p == undefined then exit
            if p[1] == qi[1] then ( fc = true; exit )
            append col p
            if col.count > 100000 then exit
        )
        if not fc do
        (
            p = qi
            local passosDesce = 0
            -- descer: usa #cima a partir do quad virado (BL<->TL, BR<->TR)
            while true do
            (
                passosDesce += 1
                if passosDesce > 100000 do
                (
                    InLab_Log (o.name + ": Mapear, tubo: descida da coluna sem fim (malha helicoidal ou não-manifold), elemento ignorado") tipo:#warn
                    return undefined
                )
                local virado = #(p[1], p[5], p[4], p[3], p[2])
                local d = InLab_Mapear_Passo o virado #cima quads
                if d == undefined then exit
                insertItem #(d[1], d[5], d[4], d[3], d[2]) col 1
                p = col[1]
            )
        )
        if nj == undefined then ( nj = col.count; fechadaJ = fc )
        else if col.count != nj or fc != fechadaJ then return undefined -- grade irregular
        append Q col
    )
    local ni = Q.count
    local cobertas = #{}
    for col in Q do for qq in col do cobertas[qq[1]] = true
    -- grade de vértices V[i+1][j+1], i 0..ni, j 0..nj
    fn vert Q i j ni nj =
    (
        local ii = amin i (ni - 1); local jj = amin j (nj - 1)
        local qq = Q[ii + 1][jj + 1]
        if i < ni and j < nj then qq[2] else if i == ni and j < nj then qq[3] else if i < ni and j == nj then qq[5] else qq[4]
    )
    local Li = for i = 0 to ni - 1 collect ( local t = 0.0; for j = 0 to nj - 1 do t += distance (polyop.getVert o (vert Q i j ni nj)) (polyop.getVert o (vert Q (i+1) j ni nj)); t / nj )
    local Lj = for j = 0 to nj - 1 collect ( local t = 0.0; for i = 0 to ni - 1 do t += distance (polyop.getVert o (vert Q i j ni nj)) (polyop.getVert o (vert Q i (j+1) ni nj)); t / ni )
    local totI = 0.0; for x in Li do totI += x
    local totJ = 0.0; for x in Lj do totJ += x
    -- emendas: volta -> lado que aponta para o centro do elemento; comprimento -> atrás (+Y de mundo, via transform do nó)
    local centro = [0,0,0]; local nvc = 0
    for f in cobertas do ( centro += polyop.getFaceCenter o f; nvc += 1 )
    centro /= nvc
    local i0 = 0; local j0 = 0
    local voltaEhJ = totJ <= totI
    -- índice de início da dimensão "volta" (fechada): linha mais virada para o centro
    fn escolherVolta o Q ni nj centro voltaEhJ =
    (
        local melhor = 0; local mv = 1e9
        local n = if voltaEhJ then nj else ni
        for k = 0 to n - 1 do
        (
            local sc = 0.0
            local m = if voltaEhJ then ni else nj
            for t = 0 to m - 1 by (amax 1 (m/24)) do
            (
                local qq = if voltaEhJ then Q[t+1][k+1] else Q[k+1][t+1]
                local f = qq[1]
                sc += dot (polyop.getFaceNormal o f) (normalize (centro - (polyop.getFaceCenter o f)))
            )
            if -sc < mv do ( mv = -sc; melhor = k )
        )
        melhor
    )
    fn escolherAtras o Q ni nj voltaEhJ =
    (
        local melhor = 0; local mv = -1e9
        local n = if voltaEhJ then ni else nj
        for k = 0 to n - 1 do
        (
            local qq = if voltaEhJ then Q[k+1][1] else Q[1][k+1]
            -- "atrás" = +Y de MUNDO (frente do produto em -Y): centro local passado pelo transform do nó
            local y = ((polyop.getFaceCenter o qq[1]) * o.transform).y
            if y > mv do ( mv = y; melhor = k )
        )
        melhor
    )
    if voltaEhJ then
    (
        if fechadaJ do j0 = escolherVolta o Q ni nj centro true
        if fechadaI do i0 = escolherAtras o Q ni nj true
    )
    else
    (
        if fechadaI do i0 = escolherVolta o Q ni nj centro false
        if fechadaJ do j0 = escolherAtras o Q ni nj false
    )
    -- coordenadas acumuladas a partir do início
    local Ui = #(0.0); for t = 0 to ni - 1 do append Ui (Ui[Ui.count] + Li[(mod (i0 + t) ni) as integer + 1])
    local Vj = #(0.0); for t = 0 to nj - 1 do append Vj (Vj[Vj.count] + Lj[(mod (j0 + t) nj) as integer + 1])
    -- vértices de UV: (p,q) com p 0..ni, q 0..nj
    local uvs = #()
    for p = 0 to ni do for qn = 0 to nj do
    (
        local a = Ui[p+1] * s; local b = Vj[qn+1] * s
        append uvs (if voltaEhJ then [a, b, 0] else [b, a, 0])
    )
    local mapa = #()
    for i = 0 to ni - 1 do for j = 0 to nj - 1 do
    (
        local qq = Q[i+1][j+1]
        local p = (mod (i - i0 + ni) ni) as integer
        local r = (mod (j - j0 + nj) nj) as integer
        local idx = #()
        idx[1] = p*(nj+1) + r + 1           -- BL
        idx[2] = (p+1)*(nj+1) + r + 1       -- BR
        idx[3] = (p+1)*(nj+1) + (r+1) + 1   -- TR
        idx[4] = p*(nj+1) + (r+1) + 1       -- TL
        local fv = polyop.getFaceVerts o qq[1]
        local m = for v in fv collect ( local k = findItem #(qq[2], qq[3], qq[4], qq[5]) v; base + idx[k] )
        append mapa #(qq[1], m)
    )
    -- orientação: a maioria das faces tem de sair sem espelhar
    local soma = 0
    for k = 1 to mapa.count by 7 do soma += InLab_Mapear_SinalUV o mapa[k][1] mapa[k][2] uvs base
    if soma < 0 do for k = 1 to uvs.count do uvs[k].y = -uvs[k].y
    #(uvs, mapa, cobertas)
)

-- tubo(s): um elemento de `faces` por vez; undefined se nenhum é tubo
fn InLab_Mapear_GerarTubo o faces escala =
(
    local uvs = #(); local mapa = #()
    local resto = copy faces
    local tubos = 0; local naoTubo = 0
    while not resto.isEmpty do
    (
        local f1 = (for i in resto collect i)[1]
        local el = (polyop.getElementsUsingFace o #{f1}) * faces
        resto -= el
        resto[f1] = false
        local r = undefined
        try ( in coordsys local ( r = InLab_Mapear_TuboElemento o el escala uvs.count ) )
        catch ( InLab_Log (o.name + ": Mapear, tubo falhou (" + (getCurrentException()) + ")") tipo:#err )
        if r != undefined then ( join uvs r[1]; join mapa r[2]; tubos += 1 )
        else naoTubo += 1
    )
    if tubos == 0 then undefined
    else
    (
        InLab_Log (o.name + ": Mapear, " + tubos as string + " tubo(s) reconhecido(s), " + naoTubo as string + " elemento(s) fora da grade") tipo:#info
        #(uvs, mapa)
    )
)

-- madeira: projeção por face com o veio (U) na aresta longa, alisada, sem espelhar
fn InLab_Mapear_MadeiraLocal o faces escala veio =
(
    local nf = polyop.getNumFaces o
    local eixo = #(); local sinal = #(); local voto = #(); local peso = #()
    eixo.count = nf; sinal.count = nf; voto.count = nf; peso.count = nf
    for f in faces do
    (
        local n = polyop.getFaceNormal o f
        local a = if abs n.x >= abs n.y and abs n.x >= abs n.z then 1 else if abs n.y >= abs n.z then 2 else 3
        eixo[f] = a; sinal[f] = (if n[a] >= 0 then 1 else -1)
        local vs = polyop.getFaceVerts o f
        local lg = [0,0,0]; local mx = 0.0; local mn = 1e9
        for k = 1 to vs.count do
        (
            local e = (polyop.getVert o vs[if k == vs.count then 1 else k + 1]) - (polyop.getVert o vs[k])
            local l = length e
            if l > mx do ( mx = l; lg = e )
            if l < mn do mn = l
        )
        -- +1 = "U na 1ª opção" (lateral: vertical; topo: X), -1 = 2ª
        voto[f] = if a == 3 then (if abs lg.x >= abs lg.y then 1 else -1) else (if abs lg.z >= (amax (abs lg.x) (abs lg.y)) then 1 else -1)
        peso[f] = amin 4.0 (amax 0.0 (mx / (amax 1e-6 mn) - 1))
    )
    -- vizinhos por aresta (só dentro de `faces`)
    local viz = #(); viz.count = nf
    for f in faces do viz[f] = ((polyop.getFacesUsingEdge o (polyop.getFaceEdges o f)) - #{f}) * faces
    for passe = 1 to 4 do
    (
        local novo = copy voto #nomap
        for f in faces do
        (
            local sc = voto[f] * (peso[f] + 0.5)
            local lado = eixo[f] != 3
            for g in viz[f] where (eixo[g] != 3) == lado do sc += voto[g] * peso[g]
            novo[f] = if sc >= 0 then 1 else -1
        )
        voto = novo
    )
    -- UV por (vértice, eixo, sinal, modo)
    local dic = Dictionary #string
    local uvs = #(); local mapa = #()
    local X = [1,0,0]; local Y = [0,1,0]; local Z = [0,0,1]
    local girar = (veio == #vertical)
    for f in faces do
    (
        local a = eixo[f]; local sg = sinal[f]
        local nAx = (if a == 1 then X else if a == 2 then Y else Z) * sg
        local T = if a == 3 then (if voto[f] > 0 then X else Y) else (if voto[f] > 0 then Z else (if a == 1 then Y else X))
        local B = cross nAx T
        local vs = polyop.getFaceVerts o f
        local m = for v in vs collect
        (
            local chave = v as string + "_" + a as string + "_" + sg as string + "_" + voto[f] as string
            if not (hasDictValue dic chave) do
            (
                local p = polyop.getVert o v
                local u = (dot p T) * escala; local w = (dot p B) * escala
                -- veio vertical: gira 90 graus, (U,V) -> (-V,U), sem espelhar
                append uvs (if girar then [-w, u, 0] else [u, w, 0])
                dic[chave] = uvs.count
            )
            dic[chave]
        )
        append mapa #(f, m)
    )
    -- nó espelhado (escala negativa): inverte o V, senão o InLab_Mapear_Medir conta 100% espelhado
    if InLab_Mapear_NoEspelhado o do for k = 1 to uvs.count do uvs[k].y = -uvs[k].y
    #(uvs, mapa)
)

-- caixa por face: eixo dominante; laterais U horizontal (B = Z), topo/base U = X; T x B = normal
fn InLab_Mapear_BoxLocal o faces escala =
(
    local dic = Dictionary #string
    local uvs = #(); local mapa = #()
    local X = [1,0,0]; local Y = [0,1,0]; local Z = [0,0,1]
    for f in faces do
    (
        local n = polyop.getFaceNormal o f
        local a = if abs n.x >= abs n.y and abs n.x >= abs n.z then 1 else if abs n.y >= abs n.z then 2 else 3
        local sg = if n[a] >= 0 then 1 else -1
        local nAx = (if a == 1 then X else if a == 2 then Y else Z) * sg
        local T, B
        if a == 3 then ( T = X; B = cross nAx T )
        else ( B = Z; T = cross B nAx )
        local vs = polyop.getFaceVerts o f
        local m = for v in vs collect
        (
            local chave = v as string + "_" + a as string + "_" + sg as string
            if not (hasDictValue dic chave) do
            (
                local p = polyop.getVert o v
                append uvs [(dot p T) * escala, (dot p B) * escala, 0]
                dic[chave] = uvs.count
            )
            dic[chave]
        )
        append mapa #(f, m)
    )
    -- nó espelhado: inverte o V (mesma regra da madeira)
    if InLab_Mapear_NoEspelhado o do for k = 1 to uvs.count do uvs[k].y = -uvs[k].y
    #(uvs, mapa)
)

-- madeira e box: o coordsys local vale também nas chamadas de dentro
fn InLab_Mapear_GerarMadeira o faces escala veio =
(
    local r = undefined
    in coordsys local ( r = InLab_Mapear_MadeiraLocal o faces escala veio )
    r
)
fn InLab_Mapear_GerarBox o faces escala =
(
    local r = undefined
    in coordsys local ( r = InLab_Mapear_BoxLocal o faces escala )
    r
)

-- grava uvs + mapa no canal 1; faces sem mapa mantêm o UV atual. true = gravou
fn InLab_Mapear_Gravar o uvs mapa =
(
    local ok = false
    try
    (
        local nf = polyop.getNumFaces o
        local tinha = polyop.getMapSupport o 1
        local temMapa = #{}
        local porFace = #(); porFace.count = nf
        for e in mapa do ( temMapa[e[1]] = true; porFace[e[1]] = e[2] )
        local todos = copy uvs #nomap
        local semMapa = (#{1..nf}) - temMapa
        if tinha then
        (
            -- copia o UV atual das faces que o mapa não cobre
            for f in semMapa do
            (
                local mf = polyop.getMapFace o 1 f
                porFace[f] = for mv in mf collect ( append todos (polyop.getMapVert o 1 mv); todos.count )
            )
        )
        else
        (
            polyop.setMapSupport o 1 true
            -- canal novo: faces sem mapa apontam para um vértice de UV neutro
            if not semMapa.isEmpty do
            (
                append todos [0,0,0]
                local neutro = todos.count
                for f in semMapa do porFace[f] = for k = 1 to (polyop.getFaceDeg o f) collect neutro
            )
        )
        polyop.setNumMapVerts o 1 todos.count keep:false
        for k = 1 to todos.count do polyop.setMapVert o 1 k todos[k]
        for f = 1 to nf do polyop.setMapFace o 1 f porFace[f]
        ok = true
    )
    catch InLab_Log (o.name + ": Mapear, não gravou o canal 1 (" + (getCurrentException()) + ")") tipo:#err
    ok
)
