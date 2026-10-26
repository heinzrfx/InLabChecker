/*
 spike_paineis.ms — TESTE DESCARTÁVEL (26/10/2026). Mapear por painéis em
 cópias das peças de tecido. Não entra no plugin. Depende dos módulos do
 plugin já carregados (InLab_Mapear_Medir, InLab_Mapear_Num).
 Tudo em cópias com transform identidade (espaço do objeto = mundo).
*/
global SPK_ESC = 1.0 / 60.0
global SPK_Res = #()          -- resultados por peça

global SPK_CopiaMundo, SPK_Elementos, SPK_VolArea, SPK_EhVivo, SPK_Grade, SPK_GMin, SPK_GN, SPK_VivoP
global SPK_MontarGrade, SPK_Dist, SPK_Regioes, SPK_Contornos, SPK_Juntar, SPK_Eixo, SPK_UVAnel, SPK_UVDisco
global SPK_Unfold, SPK_Procrustes, SPK_AngDir, SPK_Girar, SPK_Desalinho, SPK_Espelho, SPK_Peca, SPK_CopiaBox
global SPK_SalvarUV, SPK_RestaurarUV, SPK_FlipU

fn SPK_CopiaMundo o nome =
(
    local m = snapshotAsMesh o
    local c = Editable_Mesh name:nome
    c.mesh = m
    update c
    convertToPoly c
    c
)

fn SPK_Elementos po faces =
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

-- #(volume, área) de um conjunto de faces (fan dos polígonos)
fn SPK_VolArea po fs =
(
    local v = 0.0, a = 0.0
    for f in fs do
    (
        local vs = polyop.getFaceVerts po f
        local p0 = polyop.getVert po vs[1]
        for k = 2 to vs.count - 1 do
        (
            local p1 = polyop.getVert po vs[k], p2 = polyop.getVert po vs[k+1]
            v += (dot p0 (cross p1 p2)) / 6.0
            a += (length (cross (p1 - p0) (p2 - p0))) / 2.0
        )
    )
    #(abs v, a)
)

-- vivo: fechado, fino (2V/A = raio do tubo) e comprido
fn SPK_EhVivo po el =
(
    local va = SPK_VolArea po el
    local abertas = 0
    for e in (polyop.getEdgesUsingFace po el) do if (polyop.getEdgeFaces po e).count < 2 do abertas += 1
    local mn = [1e9,1e9,1e9], mx = -mn
    for v in (polyop.getVertsUsingFace po el) do (local p = polyop.getVert po v; mn = [amin mn.x p.x, amin mn.y p.y, amin mn.z p.z]; mx = [amax mx.x p.x, amax mx.y p.y, amax mx.z p.z])
    local tam = amax #((mx - mn).x, (mx - mn).y, (mx - mn).z)
    local r = if va[2] > 1e-6 then 2.0 * va[1] / va[2] else 0.0
    #(abertas == 0 and r < 1.5 and tam > 12.0 * r, r, tam)
)

fn SPK_MontarGrade pts =
(
    SPK_VivoP = pts
    local mn = [1e9,1e9,1e9], mx = -mn
    for p in pts do (mn = [amin mn.x p.x, amin mn.y p.y, amin mn.z p.z]; mx = [amax mx.x p.x, amax mx.y p.y, amax mx.z p.z])
    SPK_GMin = mn - [4,4,4]
    SPK_GN = [ceil (mx.x - mn.x + 8), ceil (mx.y - mn.y + 8), ceil (mx.z - mn.z + 8)]
    SPK_Grade = #()
    SPK_Grade.count = (SPK_GN.x * SPK_GN.y * SPK_GN.z) as integer
    for i = 1 to pts.count do
    (
        local q = pts[i] - SPK_GMin
        local k = (floor q.x + SPK_GN.x * (floor q.y + SPK_GN.y * floor q.z)) as integer + 1
        if SPK_Grade[k] == undefined then SPK_Grade[k] = #(i) else append SPK_Grade[k] i
    )
    ok
)

-- distância até o vivo mais perto (raio de busca 3 células), 1e9 se longe
fn SPK_Dist p =
(
    local melhor = 1e9
    local q = p - SPK_GMin
    local cx = floor q.x, cy = floor q.y, cz = floor q.z
    if cx >= 3 and cy >= 3 and cz >= 3 and cx <= SPK_GN.x - 4 and cy <= SPK_GN.y - 4 and cz <= SPK_GN.z - 4 do
        for dx = -3 to 3 do for dy = -3 to 3 do for dz = -3 to 3 do
        (
            local lst = SPK_Grade[(cx + dx + SPK_GN.x * (cy + dy + SPK_GN.y * (cz + dz))) as integer + 1]
            if lst != undefined do for i in lst do (local d = distance p SPK_VivoP[i]; if d < melhor do melhor = d)
        )
    melhor
)

-- regiões de faces conectadas sem atravessar arestas de costura
fn SPK_Regioes po faces costura =
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
            local f = fila[fila.count]; fila.count = fila.count - 1
            for e in (polyop.getFaceEdges po f) where not costura[e] do
                for g in (polyop.getEdgeFaces po e) where resta[g] do (resta[g] = false; reg[g] = true; append fila g)
        )
        append regs reg
    )
    regs
)

fn SPK_Contornos po fs =
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
        local fila = #(e0); resta[e0] = false; n += 1
        while fila.count > 0 do
        (
            local e = fila[fila.count]; fila.count = fila.count - 1
            for v in (polyop.getEdgeVerts po e) do for e2 in (polyop.getEdgesUsingVert po v) where resta[e2] do (resta[e2] = false; append fila e2)
        )
    )
    n
)

-- faces soltas vão para o painel vizinho mais votado
fn SPK_Juntar po grandes soltas =
(
    local dono = #()
    dono.count = polyop.getNumFaces po
    for i = 1 to grandes.count do for f in grandes[i] do dono[f] = i
    local passes = 0
    while not soltas.isEmpty and passes < 60 do
    (
        passes += 1
        for f in soltas do
        (
            local voto = for i = 1 to grandes.count collect 0
            for e in (polyop.getFaceEdges po f) do for g in (polyop.getEdgeFaces po e) where g != f and dono[g] != undefined do voto[dono[g]] += 1
            local m = 0, k = 0
            for i = 1 to grandes.count where voto[i] > m do (m = voto[i]; k = i)
            if k > 0 do (dono[f] = k; grandes[k][f] = true; soltas[f] = false)
        )
    )
    grandes
)

-- eixo do anel: o eixo do mundo ao qual as normais ficam mais perpendiculares
fn SPK_Eixo po fs =
(
    local s = #(0.0, 0.0, 0.0)
    for f in fs do
    (
        local n = polyop.getFaceNormal po f, a = polyop.getFaceArea po f
        s[1] += a * abs n.x; s[2] += a * abs n.y; s[3] += a * abs n.z
    )
    local k = 1
    for i = 2 to 3 where s[i] < s[k] do k = i
    k
)

fn SPK_GravarUV po mapas uvs =
(
    local base = polyop.getNumMapVerts po 1
    polyop.setNumMapVerts po 1 (base + uvs.count) keep:true
    for k = 1 to uvs.count do polyop.setMapVert po 1 (base + k) uvs[k]
    for m in mapas do polyop.setMapFace po 1 m[1] (for k in m[2] collect base + k)
    ok
)

-- anel em volta do eixo k (1=X 2=Y 3=Z). Volta pelo contorno de fora; corte
-- atrás (+Y, entre −X e +Y) se o eixo é Z, embaixo (−Z) se é horizontal.
fn SPK_UVAnel po fs k perfil:false =
(
    local ax = #([1,0,0], [0,1,0], [0,0,1])[k]
    local e1 = if k == 3 then [1,0,0] else if k == 1 then [0,1,0] else [1,0,0]
    local e2 = if k == 3 then [0,1,0] else [0,0,1]
    local vs = (polyop.getVertsUsingFace po fs) as array
    local c1 = 0.0, c2 = 0.0
    for v in vs do (local p = polyop.getVert po v; c1 += dot p e1; c2 += dot p e2)
    c1 /= vs.count; c2 /= vs.count
    local corte = if k == 3 then 135.0 else -90.0
    -- ângulo de cada vértice já deslocado para o corte ficar em 0
    fn angP p e1 e2 c1 c2 corte = (local s = (atan2 ((dot p e2) - c2) ((dot p e1) - c1)) - corte; while s < 0 do s += 360.0; while s >= 360 do s -= 360.0; s)
    -- contorno de fora: maior raio a cada 2 graus
    local bins = for i = 1 to 180 collect undefined
    for v in vs do
    (
        local p = polyop.getVert po v
        local a = angP p e1 e2 c1 c2 corte
        local r = distance [(dot p e1), (dot p e2), 0] [c1, c2, 0]
        local b = (floor (a / 2.0)) as integer + 1
        if b > 180 do b = 180
        if bins[b] == undefined or r > bins[b][1] do bins[b] = #(r, [(dot p e1), (dot p e2), 0], a)
    )
    local pts = for b in bins where b != undefined collect b
    local tabA = #(), tabL = #()
    local acc = 0.0
    for i = 1 to pts.count do
    (
        if i > 1 do acc += distance pts[i][2] pts[i-1][2]
        append tabA pts[i][3]; append tabL acc
    )
    local perim = acc + (distance pts[1][2] pts[pts.count][2])
    append tabA (pts[1][3] + 360.0); append tabL perim
    fn lDe a tabA tabL = (if a < tabA[1] do a += 360.0; local i = 1; while i < tabA.count and tabA[i+1] < a do i += 1; if i >= tabA.count then tabL[tabL.count] else tabL[i] + (a - tabA[i]) / (amax 1e-6 (tabA[i+1] - tabA[i])) * (tabL[i+1] - tabL[i]))
    -- perfil varrido: no plano (dr, t) — dr = raio menos o raio de fora no
    -- mesmo ângulo, t = coordenada no eixo — o comprimento ao longo do perfil
    local rOut = for b in bins collect (if b == undefined then undefined else b[1])
    fn rDe a rOut = (local b = (floor (a / 2.0)) as integer + 1; if b > 180 do b = 180; local i = 0; local r = undefined; while r == undefined and i < 90 do (for s in #(b + i, b - i) where s >= 1 and s <= 180 and r == undefined do r = rOut[s]; i += 1); if r == undefined then 0.0 else r)
    local perfTabA = #(), perfTabS = #(), drc = 0.0, tc = 0.0
    if perfil do
    (
        local amostras = #(), drMin = 0.0, tMin = 1e9, tMax = -1e9
        for v in vs do
        (
            local p = polyop.getVert po v
            local a = angP p e1 e2 c1 c2 corte
            local r = distance [(dot p e1), (dot p e2), 0] [c1, c2, 0]
            local dr = r - (rDe a rOut)
            local t = dot p ax
            append amostras [dr, t, 0]
            drMin = amin drMin dr; tMin = amin tMin t; tMax = amax tMax t
        )
        drc = drMin; tc = (tMin + tMax) / 2.0
        -- por grau do ângulo em volta de (drc, tc), o ponto mais longe
        local pb = for i = 1 to 181 collect undefined
        for q in amostras do
        (
            local ang = atan2 (q.y - tc) (q.x - drc)
            local i = (floor (ang + 90.0)) as integer + 1
            if i < 1 do i = 1
            if i > 181 do i = 181
            local d = distance q [drc, tc, 0]
            if pb[i] == undefined or d > pb[i][1] do pb[i] = #(d, q, ang)
        )
        local ps2 = for b in pb where b != undefined collect b
        local acc2 = 0.0
        for i = 1 to ps2.count do (if i > 1 do acc2 += distance ps2[i][2] ps2[i-1][2]; append perfTabA ps2[i][3]; append perfTabS acc2)
    )
    fn sPerfil dr t drc tc perfTabA perfTabS = (local ang = atan2 (t - tc) (dr - drc); local i = 1; while i < perfTabA.count and perfTabA[i+1] < ang do i += 1; if i >= perfTabA.count then perfTabS[perfTabS.count] else if ang <= perfTabA[1] then 0.0 else perfTabS[i] + (ang - perfTabA[i]) / (amax 1e-6 (perfTabA[i+1] - perfTabA[i])) * (perfTabS[i+1] - perfTabS[i]))
    local uvs = #(), mapas = #(), tA = #(), tB = #()
    for f in fs do
    (
        local fv = polyop.getFaceVerts po f
        local ps = for v in fv collect angP (polyop.getVert po v) e1 e2 c1 c2 corte
        local atravessa = ((amax ps) - (amin ps)) > 180.0
        local ids = #()
        for j = 1 to fv.count do
        (
            local alto = atravessa and ps[j] < 180.0
            local t = if alto then tB else tA
            local v = fv[j]
            if t[v] == undefined do
            (
                local p = polyop.getVert po v
                local s = (lDe ps[j] tabA tabL) + (if alto then perim else 0.0)
                local tEixo = dot p ax
                if perfil do
                (
                    local r = distance [(dot p e1), (dot p e2), 0] [c1, c2, 0]
                    local ro = rDe ps[j] rOut
                    tEixo = sPerfil (r - ro) (dot p ax) drc tc perfTabA perfTabS
                )
                -- eixo vertical: U = volta, V = altura (ou perfil); horizontal: U = eixo (ou perfil), V = volta
                append uvs (if k == 3 then [s * SPK_ESC, tEixo * SPK_ESC, 0] else [tEixo * SPK_ESC, s * SPK_ESC, 0])
                t[v] = uvs.count
            )
            append ids t[v]
        )
        append mapas #(f, ids)
    )
    SPK_GravarUV po mapas uvs
    perim
)

fn SPK_UVDisco po fs =
(
    local n = [0,0,0]
    for f in fs do n += (polyop.getFaceNormal po f) * (polyop.getFaceArea po f)
    n = normalize n
    local T = if abs n.z > 0.9 then [1,0,0] else normalize [-n.y, n.x, 0]
    if abs n.z > 0.9 and n.z < 0 do T = [1,0,0]
    local B = cross n T
    local uvs = #(), mapas = #(), tab = #()
    for f in fs do
    (
        local ids = for v in (polyop.getFaceVerts po f) collect (if tab[v] == undefined do (local p = polyop.getVert po v; append uvs [(dot p T) * SPK_ESC, (dot p B) * SPK_ESC, 0]; tab[v] = uvs.count); tab[v])
        append mapas #(f, ids)
    )
    SPK_GravarUV po mapas uvs
    n
)

-- Unfold3D num nó temporário, encaixe de escala pela área e posição pelo
-- centro; o giro é travado depois (SPK_AngDir). false se o solve falhou.
fn SPK_Unfold c fs =
(
    local po = c.baseobject
    local lista = fs as array
    local nome = uniqueName "SPK_tmp"
    polyop.detachFaces po fs delete:false asNode:true name:nome node:c
    local tmp = getNodeByName nome
    local uvw = Unwrap_UVW()
    with undo off ( max modify mode; select tmp )
    addModifier tmp uvw
    with undo off ( modPanel.setCurrentObject uvw )
    uvw.setMapChannel 1
    local np = uvw.numberPolygons()
    uvw.selectFaces #{1..np}
    local ok = try ( uvw.Unfold3DSolve(); true ) catch ( false )
    local novos = #()
    if ok do for k = 1 to lista.count do
        novos[k] = for j = 1 to (uvw.numberPointsInFace k) collect (uvw.getVertexPosition 0 (uvw.getVertexIndexFromFace k j))
    delete tmp
    if not ok then false else
    (
        local a3 = 0.0, auv = 0.0, cN = [0,0,0], cV = [0,0,0], n = 0
        for k = 1 to lista.count do
        (
            a3 += polyop.getFaceArea po lista[k]
            local p = novos[k]
            for j = 2 to p.count - 1 do auv += abs (((p[j] - p[1]).x * (p[j+1] - p[1]).y - (p[j] - p[1]).y * (p[j+1] - p[1]).x) / 2.0)
            local mf = polyop.getMapFace po 1 lista[k]
            for j = 1 to mf.count do (cN += p[j]; cV += polyop.getMapVert po 1 mf[j]; n += 1)
        )
        cN /= n; cV /= n
        local s = (sqrt (a3 / (amax 1e-12 auv))) * SPK_ESC
        local mapaNovo = #(), novosUV = #(), faces = #()
        local base = polyop.getNumMapVerts po 1
        for k = 1 to lista.count do
        (
            local mf = polyop.getMapFace po 1 lista[k]
            local ids = #()
            for j = 1 to mf.count do
            (
                local q = (novos[k][j] - cN) * s + cV
                local idx = findItem mapaNovo mf[j]
                if idx == 0 do (append mapaNovo mf[j]; append novosUV q; idx = mapaNovo.count)
                append ids (base + idx)
            )
            append faces #(lista[k], ids)
        )
        polyop.setNumMapVerts po 1 (base + novosUV.count) keep:true
        for i = 1 to novosUV.count do polyop.setMapVert po 1 (base + i) novosUV[i]
        for e in faces do polyop.setMapFace po 1 e[1] e[2]
        true
    )
)

-- direção média (graus no UV) de uma direção do mundo projetada nas faces
fn SPK_AngDir po fs dir =
(
    local g = [0,0,0]
    for f in fs do
    (
        local vs = polyop.getFaceVerts po f
        local mf = polyop.getMapFace po 1 f
        local p0 = polyop.getVert po vs[1], p1 = polyop.getVert po vs[2], p2 = polyop.getVert po vs[3]
        local t0 = polyop.getMapVert po 1 mf[1], t1 = polyop.getMapVert po 1 mf[2], t2 = polyop.getMapVert po 1 mf[3]
        local a1 = p1 - p0, a2 = p2 - p0
        local nn = normalize (cross a1 a2)
        local xp = dir - nn * (dot nn dir)
        if (length xp) > 0.2 do
        (
            local g11 = dot a1 a1, g12 = dot a1 a2, g22 = dot a2 a2
            local b1 = dot xp a1, b2 = dot xp a2
            local det = g11*g22 - g12*g12
            if abs det > 1e-12 do
            (
                local x1 = (b1*g22 - b2*g12) / det, x2 = (b2*g11 - b1*g12) / det
                local d = (t1 - t0) * x1 + (t2 - t0) * x2
                if (length d) > 1e-12 do g += (normalize d) * (polyop.getFaceArea po f)
            )
        )
    )
    atan2 g.y g.x
)

fn SPK_Girar po fs ang =
(
    local mv = #{}
    for f in fs do for k in (polyop.getMapFace po 1 f) do mv[k] = true
    local c = [0,0,0], n = 0
    for k in mv do (c += polyop.getMapVert po 1 k; n += 1)
    c /= n
    for k in mv do (local u = (polyop.getMapVert po 1 k) - c; polyop.setMapVert po 1 k ([u.x*(cos ang) - u.y*(sin ang), u.x*(sin ang) + u.y*(cos ang), 0] + c))
    ok
)

fn SPK_FlipU po fs =
(
    local mv = #{}
    for f in fs do for k in (polyop.getMapFace po 1 f) do mv[k] = true
    for k in mv do (local u = polyop.getMapVert po 1 k; polyop.setMapVert po 1 k [-u.x, u.y, 0])
    ok
)

-- fração da área (0..1) com a trama a mais de 15 graus da horizontal
-- (U deve seguir a horizontal da face; no tampo, o X do mundo)
fn SPK_Desalinho po fs =
(
    local ruim = 0.0, tot = 0.0
    for f in fs do
    (
        local vs = polyop.getFaceVerts po f
        local mf = polyop.getMapFace po 1 f
        local p0 = polyop.getVert po vs[1], p1 = polyop.getVert po vs[2], p2 = polyop.getVert po vs[3]
        local t0 = polyop.getMapVert po 1 mf[1], t1 = polyop.getMapVert po 1 mf[2], t2 = polyop.getMapVert po 1 mf[3]
        local a1 = p1 - p0, a2 = p2 - p0
        local nn = normalize (cross a1 a2)
        local h = if abs nn.z > 0.9 then [1,0,0] - nn * nn.x else normalize (cross [0,0,1] nn)
        local g11 = dot a1 a1, g12 = dot a1 a2, g22 = dot a2 a2
        local b1 = dot h a1, b2 = dot h a2
        local det = g11*g22 - g12*g12
        local ar = polyop.getFaceArea po f
        if abs det > 1e-12 do
        (
            local x1 = (b1*g22 - b2*g12) / det, x2 = (b2*g11 - b1*g12) / det
            local d = (t1 - t0) * x1 + (t2 - t0) * x2
            if (length d) > 1e-12 do
            (
                local ang = abs (atan2 d.y d.x)
                if ang > 90.0 do ang = 180.0 - ang
                tot += ar
                if ang > 15.0 do ruim += ar
            )
        )
    )
    if tot > 0 then ruim / tot else 0.0
)

-- fração da área em que a direção de referência do painel (dir do mundo,
-- projetada na face) sai a mais de 15 graus do ângulo alvo no UV (mod 180)
global SPK_DesalinhoRef
fn SPK_DesalinhoRef po fs dir alvo =
(
    local ruim = 0.0, tot = 0.0
    for f in fs do
    (
        local vs = polyop.getFaceVerts po f
        local mf = polyop.getMapFace po 1 f
        local p0 = polyop.getVert po vs[1], p1 = polyop.getVert po vs[2], p2 = polyop.getVert po vs[3]
        local t0 = polyop.getMapVert po 1 mf[1], t1 = polyop.getMapVert po 1 mf[2], t2 = polyop.getMapVert po 1 mf[3]
        local a1 = p1 - p0, a2 = p2 - p0
        local nn = normalize (cross a1 a2)
        local xp = dir - nn * (dot nn dir)
        if (length xp) > 0.3 do
        (
            local g11 = dot a1 a1, g12 = dot a1 a2, g22 = dot a2 a2
            local b1 = dot xp a1, b2 = dot xp a2
            local det = g11*g22 - g12*g12
            if abs det > 1e-12 do
            (
                local x1 = (b1*g22 - b2*g12) / det, x2 = (b2*g11 - b1*g12) / det
                local d = (t1 - t0) * x1 + (t2 - t0) * x2
                if (length d) > 1e-12 do
                (
                    local dv = abs ((atan2 d.y d.x) - alvo)
                    while dv > 180.0 do dv -= 180.0
                    if dv > 90.0 do dv = 180.0 - dv
                    local ar = polyop.getFaceArea po f
                    tot += ar
                    if dv > 15.0 do ruim += ar
                )
            )
        )
    )
    if tot > 0 then ruim / tot else 0.0
)

-- fração da área com UV espelhado (T × B contra a normal)
fn SPK_Espelho po fs =
(
    local ruim = 0.0, tot = 0.0
    for f in fs do
    (
        local vs = polyop.getFaceVerts po f
        local mf = polyop.getMapFace po 1 f
        local p0 = polyop.getVert po vs[1], p1 = polyop.getVert po vs[2], p2 = polyop.getVert po vs[3]
        local t0 = polyop.getMapVert po 1 mf[1], t1 = polyop.getMapVert po 1 mf[2], t2 = polyop.getMapVert po 1 mf[3]
        local cuv = (t1 - t0).x * (t2 - t0).y - (t1 - t0).y * (t2 - t0).x
        local ar = polyop.getFaceArea po f
        tot += ar
        if cuv < 0 do ruim += ar
    )
    if tot > 0 then ruim / tot else 0.0
)

fn SPK_SalvarUV po fs = for f in fs collect #(f, for i in (polyop.getMapFace po 1 f) collect polyop.getMapVert po 1 i)
fn SPK_RestaurarUV po salvo =
(
    local uvs = #(), mapas = #()
    for s in salvo do ( local ids = for p in s[2] collect (append uvs p; uvs.count); append mapas #(s[1], ids) )
    SPK_GravarUV po mapas uvs
)

-- Box de 60 cm na cópia (o que o Mapear de hoje faz numa peça grande de tecido)
fn SPK_CopiaBox o nome =
(
    local c = SPK_CopiaMundo o nome
    addModifier c (Uvwmap maptype:4 length:60 width:60 height:60)
    convertToPoly c
    c
)

--------------------------------------------------------------------------------
-- Uma peça. vivoPts: vértices (mundo) dos vivos do produto.
-- Devolve um registro com a decisão e os números.
--------------------------------------------------------------------------------
global dMinG = 1e9
fn SPK_Peca o vivoPts produto =
(
    local diagVivo = ""
    local eixoCaixa = 3
    dMinG = 1e9
    local t0 = timeStamp()
    local res = #(#produto, produto, #peca, o.name)
    local cb = SPK_CopiaBox o (uniqueName ("SPK_BOX_" + o.name + "_"))
    local cp = SPK_CopiaMundo o (uniqueName ("SPK_PAIN_" + o.name + "_"))
    local po = cp.baseobject
    polyop.setMapSupport po 1 true
    local nf = polyop.getNumFaces po
    local tudo = #{1..nf}
    -- elementos: vivos ficam com o UV do Box (o Mapear trata vivo como tubo)
    local els = SPK_Elementos po tudo
    local corpo = #{}, nVivos = 0
    for el in els do (local ev = SPK_EhVivo po el; if ev[1] then nVivos += 1 else corpo += el)
    local metodo = "nenhum"
    local paineis = #()
    if corpo.numberSet > 0 do
    (
        -- 1. pelo vivo
        if vivoPts.count > 0 do
        (
            local passo = amax 1 ((vivoPts.count / 8000) as integer)
            local amostraViv = #()
            local iv = 1
            while iv <= vivoPts.count do (append amostraViv vivoPts[iv]; iv += passo)
            SPK_MontarGrade amostraViv
            dMinG = 1e9
            local es = (polyop.getEdgesUsingFace po corpo) as array
            local ds = for e in es collect (local vs = polyop.getEdgeVerts po e; SPK_Dist (((polyop.getVert po vs[1]) + (polyop.getVert po vs[2])) / 2.0))
            for d in ds do if d < dMinG do dMinG = d
            local achou = false
            for lim in #(0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 3.0) while not achou do
            (
                local cost = #{}
                for i = 1 to es.count where ds[i] < lim do cost[es[i]] = true
                if cost.numberSet > 0 do
                (
                    local regs = SPK_Regioes po corpo cost
                    local minimo = amax 50 (corpo.numberSet * 0.03)
                    local grandes = for g in regs where g.numberSet >= minimo collect g
                    if grandes.count >= 2 do
                    (
                        local soltas = #{}
                        for g in regs where g.numberSet < minimo do soltas += g
                        paineis = SPK_Juntar po grandes soltas
                        metodo = "vivo (" + lim as string + " cm)"
                        achou = true
                    )
                )
            )
        )
        if vivoPts.count > 0 and paineis.count == 0 do diagVivo = "vivo não separou (menor distância " + (if dMinG < 1e8 then (InLab_Mapear_Num dMinG) + " cm" else "acima de 3 cm") + ")"
        -- 2. molde em caixa (tampo/fundo planos e faixa)
        if paineis.count == 0 do
        (
            local lado = #()
            lado.count = nf
            local mnC = [1e9,1e9,1e9], mxC = -mnC
            for v in (polyop.getVertsUsingFace po corpo) do (local q = polyop.getVert po v; mnC = [amin mnC.x q.x, amin mnC.y q.y, amin mnC.z q.z]; mxC = [amax mxC.x q.x, amax mxC.y q.y, amax mxC.z q.z])
            local tamC = mxC - mnC
            local tams = #(tamC.x, tamC.y, tamC.z)
            local kMin = 3
            for i = 1 to 3 where tams[i] < tams[kMin] do kMin = i
            local outros = for i = 1 to 3 where i != kMin collect tams[i]
            eixoCaixa = if kMin != 3 and tams[kMin] < 0.8 * (amin outros) then kMin else 3
            local ax = #([1,0,0], [0,1,0], [0,0,1])[eixoCaixa]
            for f in corpo do (local n = polyop.getFaceNormal po f; local c = dot n ax; lado[f] = if c > 0.97 then 1 else if c < -0.97 then 2 else 3)
            for passe = 1 to 4 do
            (
                local novo = copy lado #nomap
                for f in corpo do
                (
                    local w = #(0,0,0)
                    for e in (polyop.getFaceEdges po f) do for g in (polyop.getEdgeFaces po e) where g != f and corpo[g] do w[lado[g]] += 1
                    local m = lado[f]
                    for k = 1 to 3 where w[k] > w[m] do m = k
                    if m != lado[f] and w[m] >= 2 do novo[f] = m
                )
                lado = novo
            )
            local pp = #(#{}, #{}, #{})
            for f in corpo do pp[lado[f]][f] = true
            paineis = for p in pp where p.numberSet > 0 collect p
            metodo = "molde em caixa (eixo " + #("X","Y","Z")[eixoCaixa] + ")"
        )
    )
    -- 3. UV de cada painel
    local tipos = #(), valido = paineis.count > 0
    local detalhes = ""
    local desSoma = 0.0, desArea = 0.0, piorPainel = 0.0, areaTotal = 0.0
    for p in paineis do for f in p do areaTotal += polyop.getFaceArea po f
    for p in paineis do
    (
        local nc = SPK_Contornos po p
        local areaP = 0.0
        for f in p do areaP += polyop.getFaceArea po f
        if nc >= 2 then
        (
            -- no molde em caixa a faixa é vertical por construção
            local k = if (matchPattern metodo pattern:"molde em caixa*") then eixoCaixa else SPK_Eixo po p
            local dirAlvo = if k == 3 then #([0,0,1], 90.0) else #(#([1,0,0], [0,1,0], [0,0,1])[k], 0.0)
            -- A: volta cilíndrica
            SPK_UVAnel po p k
            if (SPK_Espelho po p) > 0.5 do SPK_FlipU po p
            local desA = SPK_DesalinhoRef po p dirAlvo[1] dirAlvo[2]
            local salvoA = SPK_SalvarUV po p
            -- B: Unfold3D a partir da volta, com o giro travado
            local desB = 2.0
            if SPK_Unfold cp p do
            (
                SPK_Girar po p (dirAlvo[2] - (SPK_AngDir po p dirAlvo[1]))
                if (SPK_Espelho po p) > 0.5 do SPK_FlipU po p
                desB = SPK_DesalinhoRef po p dirAlvo[1] dirAlvo[2]
            )
            local salvoB = SPK_SalvarUV po p
            -- C: perfil varrido
            SPK_UVAnel po p k perfil:true
            if (SPK_Espelho po p) > 0.5 do SPK_FlipU po p
            local desC = SPK_DesalinhoRef po p dirAlvo[1] dirAlvo[2]
            local usa = "perfil", desF = desC
            if desA <= desF do (usa = "volta"; desF = desA)
            if desB + 0.02 < desF do (usa = "unfold"; desF = desB)
            if usa == "volta" do SPK_RestaurarUV po salvoA
            if usa == "unfold" do SPK_RestaurarUV po salvoB
            desSoma += desF * areaP; desArea += areaP
            if areaP > 0.05 * areaTotal do piorPainel = amax piorPainel desF
            append tipos ("anel " + #("X","Y","Z")[k] + " " + usa)
            detalhes += "anel" + #("X","Y","Z")[k] + "(" + p.numberSet as string + "f, torta volta " + (InLab_Mapear_Num (desA*100)) + "% unfold " + (InLab_Mapear_Num (desB*100)) + "% perfil " + (InLab_Mapear_Num (desC*100)) + "%, " + usa + ") "
        )
        else if nc == 1 then
        (
            local n = SPK_UVDisco po p
            local okU = SPK_Unfold cp p
            local dir = if abs n.z > 0.9 then #([1,0,0], 0.0) else #([0,0,1], 90.0)
            SPK_Girar po p (dir[2] - (SPK_AngDir po p dir[1]))
            if (SPK_Espelho po p) > 0.5 do SPK_FlipU po p
            local desD = SPK_DesalinhoRef po p dir[1] dir[2]
            desSoma += desD * areaP; desArea += areaP
            if areaP > 0.05 * areaTotal do piorPainel = amax piorPainel desD
            append tipos "disco"
            detalhes += "disco(" + p.numberSet as string + "f, unfold " + (if okU then "ok" else "FALHOU") + ", torta " + (InLab_Mapear_Num (desD*100)) + "%) "
        )
        else
        (
            valido = false
            detalhes += "painel fechado sem contorno(" + p.numberSet as string + "f) "
        )
    )
    update cp
    -- 4. números e decisão
    local mb = InLab_Mapear_Medir cb faces:corpo
    local mp = InLab_Mapear_Medir cp faces:corpo
    local desBox = SPK_Desalinho cb.baseobject corpo
    local desPain = if desArea > 0 then desSoma / desArea else 1.0
    local espP = SPK_Espelho po corpo
    local dens = if mp.p10 > 0 then mp.p90 / mp.p10 else 99.0
    local motivo = ""
    if not valido then motivo = "painéis inválidos"
    else if espP > 0.01 then motivo = "espelhado " + (InLab_Mapear_Num (espP*100)) + "%"
    else if dens > 1.35 then motivo = "densidade desigual " + (InLab_Mapear_Num dens)
    else if desPain > 0.10 then motivo = "trama torta no painel " + (InLab_Mapear_Num (desPain*100)) + "%"
    else if piorPainel > 0.10 then motivo = "um painel com trama torta " + (InLab_Mapear_Num (piorPainel*100)) + "%"
    else if mp.emendaVistaQuebra > mb.emendaVistaQuebra + 0.002 then motivo = "mais emenda à vista que o Box"
    local decisao = if motivo == "" then "PAINÉIS" else "BOX"
    join res #(#decisao, decisao, #motivo, motivo, #metodo, metodo, #paineis, paineis.count, #vivos, nVivos,
        #tipos, tipos, #detalhes, detalhes,
        #quebraBox, mb.emendaVistaQuebra, #quebraPain, mp.emendaVistaQuebra, #desBox, desBox, #desPain, desPain,
        #espPain, espP, #densPain, dens, #faces, corpo.numberSet, #t, (timeStamp() - t0) / 1000.0,
        #piorPainel, piorPainel, #diagVivo, diagVivo, #copiaBox, cb.name, #copiaPain, cp.name, #noOrig, o, #noBox, cb, #noPain, cp)
    cb.isHidden = true
    cp.isHidden = true
    append SPK_Res res
    res
)
