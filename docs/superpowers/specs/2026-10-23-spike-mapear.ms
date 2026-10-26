-- REFERÊNCIA (não carregado pelo plugin): teste descartável de 23/10/2026 do botão Mapear.
-- Spec: 2026-10-23-mapear-design.md. Plano: docs/superpowers/plans/2026-10-23-mapear.md.
-- SPIKE descartável (23/10/2026): mapear canal 1 de tubos (vivos/costuras) e madeira.
-- Só roda em objetos TESTE_*. Resultado em global Spike_Log.
global Spike_Log = ""
global Spike_SinalUV, Spike_Espelhado
fn spk s = ( Spike_Log += s + "\n" )

-- escala mediana atual (UV/cm) no canal 1, para manter a densidade
fn Spike_EscalaAtual o =
(
    local m = snapshotAsMesh o
    local esc = #()
    local passo = amax 1 (m.numfaces / 3000)
    for f = 1 to m.numfaces by passo do
    (
        local fv = getFace m f; local tv = meshop.getMapFace m 1 f
        local e1 = (getVert m fv.y) - (getVert m fv.x); local e2 = (getVert m fv.z) - (getVert m fv.x)
        local u1 = meshop.getMapVert m 1 tv.x
        local du1 = (meshop.getMapVert m 1 tv.y) - u1; local du2 = (meshop.getMapVert m 1 tv.z) - u1
        local a3 = length (cross e1 e2); local a2 = abs (du1.x*du2.y - du2.x*du1.y)
        if a3 > 1e-9 and a2 > 1e-12 do append esc (sqrt (a2/a3))
    )
    delete m
    sort esc
    if esc.count == 0 then 0.02 else esc[esc.count/2 + 1]
)

-- vizinho do polígono f pela aresta (a,b), dentro do conjunto permitido
fn Spike_Vizinho o f a b permitidos =
(
    local fs = ((polyop.getFacesUsingVert o a) * (polyop.getFacesUsingVert o b)) - #{f}
    local r = undefined
    for g in fs where permitidos[g] do r = g
    r
)
-- no polígono g, o vizinho de v no ciclo que não é w
fn Spike_Outro o g v w =
(
    local vs = polyop.getFaceVerts o g
    local k = findItem vs v; local n = vs.count
    local ant = vs[if k == 1 then n else k - 1]; local prox = vs[if k == n then 1 else k + 1]
    if ant == w then prox else ant
)
-- quad = #(f, BL, BR, TR, TL)
fn Spike_Passo o q dir permitidos =
(
    -- dir: #dir (direita), #esq, #cima
    local a, b
    case dir of
    (
        #dir: ( a = q[3]; b = q[4] )
        #esq: ( a = q[2]; b = q[5] )
        #cima: ( a = q[5]; b = q[4] )
    )
    local g = Spike_Vizinho o q[1] a b permitidos
    if g == undefined then undefined
    else
    (
        local oa = Spike_Outro o g a b; local ob = Spike_Outro o g b a
        case dir of
        (
            #dir: #(g, a, oa, ob, b)
            #esq: #(g, oa, a, b, ob)
            #cima: #(g, a, b, ob, oa)
        )
    )
)

-- mapeia um elemento tubular; devolve #(uvs, mapa face->#(idx por vértice)) ou undefined
fn Spike_Tubo o faces s base =
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
        q = Spike_Passo o q #dir quads
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
            q = Spike_Passo o q #esq quads
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
            p = Spike_Passo o p #cima quads
            if p == undefined then exit
            if p[1] == qi[1] then ( fc = true; exit )
            append col p
            if col.count > 100000 then exit
        )
        if not fc do
        (
            p = qi
            -- descer: usa #cima a partir do quad virado (BL<->TL, BR<->TR)
            while true do
            (
                local virado = #(p[1], p[5], p[4], p[3], p[2])
                local d = Spike_Passo o virado #cima quads
                if d == undefined then exit
                insertItem #(d[1], d[5], d[4], d[3], d[2]) col 1
                p = col[1]
            )
        )
        if nj == undefined then ( nj = col.count; fechadaJ = fc )
        else if col.count != nj or fc != fechadaJ then ( spk ("    grade irregular (coluna " + col.count as string + " vs " + nj as string + ")"); return undefined )
        append Q col
    )
    local ni = Q.count
    local cobertas = #{}
    for col in Q do for qq in col do cobertas[qq[1]] = true
    -- grade de vértices V[i+1][j+1], i 0..ni, j 0..nj
    fn vert Q i j ni nj =
    (
        -- i em 0..ni, j em 0..nj
        local ii = amin i (ni - 1); local jj = amin j (nj - 1)
        local qq = Q[ii + 1][jj + 1]
        if i < ni and j < nj then qq[2] else if i == ni and j < nj then qq[3] else if i < ni and j == nj then qq[5] else qq[4]
    )
    local Li = for i = 0 to ni - 1 collect ( local t = 0.0; for j = 0 to nj - 1 do t += distance (polyop.getVert o (vert Q i j ni nj)) (polyop.getVert o (vert Q (i+1) j ni nj)); t / nj )
    local Lj = for j = 0 to nj - 1 collect ( local t = 0.0; for i = 0 to ni - 1 do t += distance (polyop.getVert o (vert Q i j ni nj)) (polyop.getVert o (vert Q i (j+1) ni nj)); t / ni )
    local totI = 0.0; for x in Li do totI += x
    local totJ = 0.0; for x in Lj do totJ += x
    -- emendas: volta → lado que aponta para o centro do elemento; comprimento → atrás (+Y)
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
            local y = (polyop.getFaceCenter o qq[1]).y
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
    for k = 1 to mapa.count by 7 do soma += Spike_SinalUV o mapa[k][1] mapa[k][2] uvs base
    local virou = soma < 0
    if virou do for k = 1 to uvs.count do uvs[k].y = -uvs[k].y
    spk ("    tubo" + (if virou then " (V invertido)" else "") + ": " + ni as string + "×" + nj as string + (if fechadaI then " fechado" else " aberto") + "/" + (if fechadaJ then "fechado" else "aberto") + " · comprimento " + (formattedPrint (amax totI totJ) format:".1f") + " cm · volta " + (formattedPrint (amin totI totJ) format:".1f") + " cm · fora da grade: " + (faces.numberSet - cobertas.numberSet) as string + " faces")
    #(uvs, mapa, cobertas)
)

-- nó com escala negativa (espelhado)
fn Spike_Espelhado o = ( local t = o.transform; (dot (cross t.row1 t.row2) t.row3) < 0 )

-- orientação do UV de uma face (+1 normal, -1 espelhado), no sentido de render
fn Spike_SinalUV o f idx uvs base =
(
    local vs = polyop.getFaceVerts o f
    local p1 = polyop.getVert o vs[1]; local p2 = polyop.getVert o vs[2]; local p3 = polyop.getVert o vs[3]
    local t1 = uvs[idx[1] - base]; local t2 = uvs[idx[2] - base]; local t3 = uvs[idx[3] - base]
    local e1 = p2 - p1; local e2 = p3 - p1
    local d1 = t2 - t1; local d2 = t3 - t1
    -- dP/du e dP/dv sem dividir pelo det: o produto vetorial fica dividido por det², mesmo sinal
    local dPdu = (e1*d2.y - e2*d1.y); local dPdv = (e2*d1.x - e1*d2.x)
    local sg = dot (cross dPdu dPdv) (cross e1 e2)
    if Spike_Espelhado o then (if sg > 0 then -1 else 1) else (if sg > 0 then 1 else -1)
)

-- madeira: projeção por face com o veio (U) na aresta longa, alisada, sem espelhar
fn Spike_Madeira o s =
(
    local nf = polyop.getNumFaces o
    local eixo = #(); local sinal = #(); local voto = #(); local peso = #()
    for f = 1 to nf do
    (
        local n = polyop.getFaceNormal o f
        local a = if abs n.x >= abs n.y and abs n.x >= abs n.z then 1 else if abs n.y >= abs n.z then 2 else 3
        append eixo a; append sinal (if n[a] >= 0 then 1 else -1)
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
        local v = if a == 3 then (if abs lg.x >= abs lg.y then 1 else -1) else (if abs lg.z >= (amax (abs lg.x) (abs lg.y)) then 1 else -1)
        append voto v
        append peso (amin 4.0 (amax 0.0 (mx / (amax 1e-6 mn) - 1)))
    )
    -- vizinhos por aresta
    local viz = for f = 1 to nf collect ((polyop.getFacesUsingEdge o (polyop.getFaceEdges o f)) - #{f})
    for passe = 1 to 4 do
    (
        local novo = copy voto #nomap
        for f = 1 to nf do
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
    for f = 1 to nf do
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
                append uvs [(dot p T) * s, (dot p B) * s, 0]
                dic[chave] = uvs.count
            )
            dic[chave]
        )
        append mapa #(f, m)
    )
    local nv = 0; for v in voto where v > 0 do nv += 1
    spk ("    madeira: " + nf as string + " faces · veio no 1º modo (lateral vertical/topo X): " + ((100*nv/nf) as integer) as string + "%")
    #(uvs, mapa)
)

-- grava UVs + mapa no canal 1; faces sem mapa mantêm o UV atual
fn Spike_Gravar o uvs mapa =
(
    local nf = polyop.getNumFaces o
    local temMapa = #{}
    local porFace = #()
    for e in mapa do ( temMapa[e[1]] = true; porFace[e[1]] = e[2] )
    -- faces sem mapa: copia o UV atual
    local todos = copy uvs #nomap
    for f = 1 to nf where not temMapa[f] do
    (
        local mf = polyop.getMapFace o 1 f
        porFace[f] = for mv in mf collect ( append todos (polyop.getMapVert o 1 mv); todos.count )
    )
    polyop.setNumMapVerts o 1 todos.count keep:false
    for k = 1 to todos.count do polyop.setMapVert o 1 k todos[k]
    for f = 1 to nf do polyop.setMapFace o 1 f porFace[f]
)

fn Spike_Rodar =
(
    Spike_Log = ""
    local t0 = timestamp()
    for o in geometry where findString o.name "TESTE_" == 1 and classof o == Editable_Poly do
    (
        local matNome = if o.material == undefined then "" else o.material.name
        local s = Spike_EscalaAtual o
        spk (o.name + " · " + matNome + " · escala atual " + (formattedPrint s format:".4f") + " UV/cm")
        -- UV em escala de Real-World (~1 UV/cm): usa a convenção
        if s > 0.2 do
        (
            s = if matNome == "Wenge Semigloss" then 1.0/60 else 0.0239
            spk ("    escala corrigida para " + (formattedPrint s format:".4f") + " UV/cm (1 tile a cada " + (formattedPrint (1.0/s) format:".1f") + " cm)")
        )
        if matNome == "Wenge Semigloss" then
        (
            local r = Spike_Madeira o s
            Spike_Gravar o r[1] r[2]
        )
        else if (findString o.name "Shape" != undefined) or (findString o.name "Carpet" != undefined) then
        (
            local nf = polyop.getNumFaces o
            local resto = #{1..nf}
            local uvs = #(); local mapa = #()
            while not resto.isEmpty do
            (
                local f1 = (for i in resto collect i)[1]
                local el = polyop.getElementsUsingFace o #{f1}
                resto -= el
                local r = try ( Spike_Tubo o el s uvs.count ) catch ( spk ("    ERRO: " + getCurrentException()); undefined )
                if r != undefined then ( join uvs r[1]; join mapa r[2] )
                else spk ("    elemento de " + el.numberSet as string + " faces: não é tubo, mantém o UV")
            )
            Spike_Gravar o uvs mapa
        )
        else spk "    (fora do teste: mantém o UV)"
    )
    spk ("Tempo: " + ((timestamp() - t0) / 1000.0) as string + " s")
    Spike_Log
)
