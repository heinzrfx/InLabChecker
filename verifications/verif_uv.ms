/*
================================================================================
 verifications\verif_uv.ms — medição de UV por objeto e canal (18/Set · issue #1)
--------------------------------------------------------------------------------
 Só leitura: tira um snapshotAsMesh do objeto (stack avaliado, espaço do
 mundo) e mede o canal pedido. Não registra verificação V-xx: é o helper que
 o Auto UV usa no log e que as fases da issue #1 usam para comparar com o
 ArchToolz 2026.

   nIlhas             componentes conexos pelos vértices de mapa (union-find)
   aproveitamento     soma da área UV das faces / área do 0–1. Sobreposição
                      conta duas vezes, por isso "sobrepostas" vem junto.
   densidadeRazao     densidade LINEAR, sqrt(áreaUV/área3D), da ilha mais
                      densa sobre a menos densa. densidadeRazaoArea = a mesma
                      razão em área (= densidadeRazao²).
   distorcaoMax       pior face: max(r, 1/r), r = densidade de área da face
                      sobre a densidade de área da ilha dela
   foraDe01           vértices de mapa usados fora de [0,1]
   sobrepostas        faces que cruzam outra face (grade + eixo separador);
                      faces vizinhas que só encostam numa aresta não contam
   invertidos         faces com área UV negativa (sentido horário)
   espelhado          transform com determinante negativo: aí a inversão é
                      esperada e deve ser reportada, não corrigida
   gutterMin          menor distância entre arestas de borda de ilhas
                      diferentes, procurada até INLAB_UV_GUTTER_BUSCA (acima
                      disso fica no limite). 0 se ilhas diferentes se cruzam.
                      undefined com uma ilha só.
   bordaMin           menor distância de um UV usado até a borda do 0–1
                      (negativa se houver UV fora)

 21/Set: meshop.getMapSupport dá erro de runtime com canal acima de
 meshop.getNumMaps - 1 (não devolve false). InLab_UV_TemCanal confere o
 intervalo antes.
================================================================================
*/

global INLAB_UV_EPS = 1e-6
global INLAB_UV_TOL_SOBREPOSICAO = 1e-5
global INLAB_UV_GUTTER_BUSCA = 0.02
global INLAB_UV_GRADE_SOBREPOSICAO = 64

struct UVMetricas
(
    canal,
    nFaces = 0,
    nIlhas = 0,
    aproveitamento = 0.0,
    densidadeRazao = 1.0,
    densidadeRazaoArea = 1.0,
    distorcaoMax = 1.0,
    foraDe01 = 0,
    sobrepostas = 0,
    invertidos = 0,
    espelhado = false,
    gutterMin = undefined,
    bordaMin = undefined
)

global InLab_UV_Raiz, InLab_UV_Unir, InLab_UV_AreaSinal, InLab_UV_TriSobrepoe
global InLab_UV_DistPontoSeg, InLab_UV_Celula, InLab_UV_TemCanal
global InLab_MedirUV, InLab_AssinaturaCanal, InLab_UVMetricasTexto

-- Canal existe e tem suporte no mesh? getMapSupport sozinho dá erro de
-- runtime se o canal passar de getNumMaps - 1.
fn InLab_UV_TemCanal m canal = (canal >= -2 and canal < (meshop.getNumMaps m) and meshop.getMapSupport m canal)

-- Union-find com compressão de caminho. "pai" é alterado no lugar.
fn InLab_UV_Raiz pai i =
(
    while pai[i] != i do
    (
        pai[i] = pai[pai[i]]
        i = pai[i]
    )
    i
)

fn InLab_UV_Unir pai a b =
(
    local ra = InLab_UV_Raiz pai a
    local rb = InLab_UV_Raiz pai b
    if ra != rb do pai[rb] = ra
)

-- Área com sinal do triângulo no UV: positiva no sentido anti-horário.
fn InLab_UV_AreaSinal a b c = ((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2.0

-- Teste do eixo separador entre dois triângulos 2D (arrays de 3 Point3 com
-- z = 0). Encostar numa aresta, como faces vizinhas fazem, não conta.
fn InLab_UV_TriSobrepoe t1 t2 =
(
    local separados = false
    for t in #(t1, t2) while not separados do
        for k = 1 to 3 while not separados do
        (
            local p = t[k]
            local q = t[if k == 3 then 1 else k + 1]
            local eixo = [p.y - q.y, q.x - p.x, 0]
            local tam = length eixo
            if tam > INLAB_UV_EPS do
            (
                eixo = eixo / tam
                local mn1 = 1e30, mx1 = -1e30, mn2 = 1e30, mx2 = -1e30
                for v in t1 do ( local d = dot v eixo ; if d < mn1 do mn1 = d ; if d > mx1 do mx1 = d )
                for v in t2 do ( local d = dot v eixo ; if d < mn2 do mn2 = d ; if d > mx2 do mx2 = d )
                if ((amin mx1 mx2) - (amax mn1 mn2)) <= INLAB_UV_TOL_SOBREPOSICAO do separados = true
            )
        )
    not separados
)

fn InLab_UV_DistPontoSeg p a b =
(
    local ab = b - a
    local l2 = dot ab ab
    local t = if l2 < 1e-12 then 0.0 else (dot (p - a) ab) / l2
    t = amax 0.0 (amin 1.0 t)
    distance p (a + ab * t)
)

-- Índice (1..n) da célula de x numa grade de n células a partir de "mn",
-- cada uma com largura "tam".
fn InLab_UV_Celula x mn tam n = amax 1 (amin n ((floor ((x - mn) / tam)) as integer + 1))

fn InLab_MedirUV obj canal =
(
    local m = snapshotAsMesh obj
    local res = undefined
    if not (InLab_UV_TemCanal m canal) then
        InLab_Log (obj.name + ": canal " + canal as string + " inexistente — sem medição.") tipo:#warn
    else
    (
        res = UVMetricas canal:canal
        local nF = m.numfaces
        local nV = meshop.getNumMapVerts m canal
        local tm = obj.transform
        res.nFaces = nF
        res.espelhado = (dot (cross tm.row1 tm.row2) tm.row3) < 0

        -- UVs em 2D (a 3ª coordenada do canal é ignorada) e cantos por face
        local uv = for v = 1 to nV collect ( local p = meshop.getMapVert m canal v ; [p.x, p.y, 0] )
        local cantos = for f = 1 to nF collect ( local c = meshop.getMapFace m canal f ; #(c.x as integer, c.y as integer, c.z as integer) )

        -- 1. ILHAS
        local pai = for v = 1 to nV collect v
        for c in cantos do
        (
            InLab_UV_Unir pai c[1] c[2]
            InLab_UV_Unir pai c[1] c[3]
        )
        local ilhaDaRaiz = for v = 1 to nV collect 0
        local ilhaFace = for c in cantos collect
        (
            local r = InLab_UV_Raiz pai c[1]
            if ilhaDaRaiz[r] == 0 do ( res.nIlhas += 1 ; ilhaDaRaiz[r] = res.nIlhas )
            ilhaDaRaiz[r]
        )

        -- 2. ÁREAS, INVERTIDOS E APROVEITAMENTO
        local areaUVIlha = for i = 1 to res.nIlhas collect 0.0
        local area3DIlha = for i = 1 to res.nIlhas collect 0.0
        local areaUV = #()
        local area3D = #()
        for f = 1 to nF do
        (
            local c = cantos[f]
            local s = InLab_UV_AreaSinal uv[c[1]] uv[c[2]] uv[c[3]]
            if s < -1e-12 do res.invertidos += 1
            areaUV[f] = abs s
            area3D[f] = meshop.getFaceArea m f
            areaUVIlha[ilhaFace[f]] += areaUV[f]
            area3DIlha[ilhaFace[f]] += area3D[f]
            res.aproveitamento += areaUV[f]
        )

        -- 3. DENSIDADE ENTRE ILHAS E DISTORÇÃO DENTRO DA ILHA
        local densMax = 0.0, densMin = 1e30
        for i = 1 to res.nIlhas where area3DIlha[i] > INLAB_UV_EPS and areaUVIlha[i] > 1e-12 do
        (
            local d = areaUVIlha[i] / area3DIlha[i]
            densMax = amax densMax d
            densMin = amin densMin d
        )
        if densMax > 0.0 do
        (
            res.densidadeRazaoArea = densMax / densMin
            res.densidadeRazao = sqrt res.densidadeRazaoArea
        )
        for f = 1 to nF where area3D[f] > INLAB_UV_EPS and areaUV[f] > 1e-12 do
        (
            local i = ilhaFace[f]
            local r = (areaUV[f] / area3D[f]) / (areaUVIlha[i] / area3DIlha[i])
            res.distorcaoMax = amax res.distorcaoMax (amax r (1.0 / r))
        )

        -- 4. FORA DO 0–1, BORDA E BBOX DOS UVs USADOS
        local usados = #{}
        for c in cantos do ( usados[c[1]] = true ; usados[c[2]] = true ; usados[c[3]] = true )
        local uMin = 1e30, uMax = -1e30, vMin = 1e30, vMax = -1e30
        if usados.numberSet > 0 do res.bordaMin = 1e30
        for v in usados do
        (
            local p = uv[v]
            if p.x < -INLAB_UV_EPS or p.x > 1.0 + INLAB_UV_EPS or p.y < -INLAB_UV_EPS or p.y > 1.0 + INLAB_UV_EPS do
                res.foraDe01 += 1
            res.bordaMin = amin #(res.bordaMin, p.x, p.y, 1.0 - p.x, 1.0 - p.y)
            uMin = amin uMin p.x ; uMax = amax uMax p.x
            vMin = amin vMin p.y ; vMax = amax vMax p.y
        )

        -- 5. SOBREPOSIÇÃO: grade N×N sobre o bbox, eixo separador por par
        local sobreEntreIlhas = false
        if nF > 1 do
        (
            local N = INLAB_UV_GRADE_SOBREPOSICAO
            local tamU = (amax (uMax - uMin) INLAB_UV_EPS) / N
            local tamV = (amax (vMax - vMin) INLAB_UV_EPS) / N
            local celulas = for i = 1 to N * N collect #()
            local caixas = #()
            for f = 1 to nF where areaUV[f] > 1e-12 do
            (
                local c = cantos[f]
                local a = uv[c[1]], b = uv[c[2]], d = uv[c[3]]
                caixas[f] = #(amin #(a.x, b.x, d.x), amin #(a.y, b.y, d.y), amax #(a.x, b.x, d.x), amax #(a.y, b.y, d.y))
                for i = (InLab_UV_Celula caixas[f][1] uMin tamU N) to (InLab_UV_Celula caixas[f][3] uMin tamU N) do
                    for j = (InLab_UV_Celula caixas[f][2] vMin tamV N) to (InLab_UV_Celula caixas[f][4] vMin tamV N) do
                        append celulas[(j - 1) * N + i] f
            )
            local sobre = #{}
            sobre.count = nF
            for cel in celulas where cel.count > 1 do
                for p = 1 to cel.count - 1 do
                    for q = p + 1 to cel.count do
                    (
                        local f1 = cel[p], f2 = cel[q]
                        if not (sobre[f1] and sobre[f2]) do
                        (
                            local b1 = caixas[f1], b2 = caixas[f2]
                            if b1[1] < b2[3] and b2[1] < b1[3] and b1[2] < b2[4] and b2[2] < b1[4] do
                            (
                                local t1 = for k in cantos[f1] collect uv[k]
                                local t2 = for k in cantos[f2] collect uv[k]
                                if InLab_UV_TriSobrepoe t1 t2 do
                                (
                                    sobre[f1] = true
                                    sobre[f2] = true
                                    if ilhaFace[f1] != ilhaFace[f2] do sobreEntreIlhas = true
                                )
                            )
                        )
                    )
            res.sobrepostas = sobre.numberSet
        )

        -- 6. GUTTER: arestas de borda (usadas por uma face só) de ilhas diferentes
        if res.nIlhas > 1 do
        (
            local vizinhos = for v = 1 to nV collect #() -- vértice menor → vértices maiores
            local contagem = for v = 1 to nV collect #() -- paralelo: faces por aresta
            for c in cantos do
                for k = 1 to 3 do
                (
                    local a = c[k], b = c[if k == 3 then 1 else k + 1]
                    local lo = amin a b, hi = amax a b
                    local idx = findItem vizinhos[lo] hi
                    if idx == 0 then ( append vizinhos[lo] hi ; append contagem[lo] 1 )
                    else contagem[lo][idx] += 1
                )
            local segs = #() -- #(pontoA, pontoB, ilha)
            for lo = 1 to nV do
                for idx = 1 to vizinhos[lo].count where contagem[lo][idx] == 1 do
                    append segs #(uv[lo], uv[vizinhos[lo][idx]], ilhaDaRaiz[InLab_UV_Raiz pai lo])

            local R = INLAB_UV_GUTTER_BUSCA
            local nx = (ceil ((uMax - uMin) / R)) as integer + 1
            local ny = (ceil ((vMax - vMin) / R)) as integer + 1
            if nx * ny > 250000 then
                InLab_Log (obj.name + ": canal " + canal as string + " espalhado demais para medir o gutter.") tipo:#warn
            else
            (
                local grade = for i = 1 to nx * ny collect #()
                for s = 1 to segs.count do
                (
                    local a = segs[s][1], b = segs[s][2]
                    for i = (InLab_UV_Celula (amin a.x b.x) uMin R nx) to (InLab_UV_Celula (amax a.x b.x) uMin R nx) do
                        for j = (InLab_UV_Celula (amin a.y b.y) vMin R ny) to (InLab_UV_Celula (amax a.y b.y) vMin R ny) do
                            append grade[(j - 1) * nx + i] s
                )
                local g = if sobreEntreIlhas then 0.0 else R
                for s in segs while g > 0.0 do
                    for p in #(s[1], s[2]) do
                    (
                        local ci = InLab_UV_Celula p.x uMin R nx
                        local cj = InLab_UV_Celula p.y vMin R ny
                        for i = ci - 1 to ci + 1 where i >= 1 and i <= nx do
                            for j = cj - 1 to cj + 1 where j >= 1 and j <= ny do
                                for t in grade[(j - 1) * nx + i] where segs[t][3] != s[3] do
                                    g = amin g (InLab_UV_DistPontoSeg p segs[t][1] segs[t][2])
                    )
                res.gutterMin = g
            )
        )
    )
    res
)

-- Texto que identifica o UV de cada canto de face do canal. Serve para
-- provar que um canal não mudou (antes == depois). undefined se não existe.
fn InLab_AssinaturaCanal obj canal =
(
    local m = snapshotAsMesh obj
    local s = undefined
    if InLab_UV_TemCanal m canal do
    (
        local ss = stringStream ""
        for f = 1 to m.numfaces do
        (
            local c = meshop.getMapFace m canal f
            for k in #(c.x, c.y, c.z) do
            (
                local p = meshop.getMapVert m canal (k as integer)
                format "%,%;" (formattedPrint p.x format:".5f") (formattedPrint p.y format:".5f") to:ss
            )
        )
        s = ss as string
    )
    s
)

fn InLab_UVMetricasTexto met =
(
    if met == undefined then "sem medição"
    else
    (
        "canal " + met.canal as string +
        " · " + met.nIlhas as string + " ilha(s)" +
        " · aproveitamento " + (formattedPrint (met.aproveitamento * 100.0) format:".0f") + "%" +
        " · densidade máx/mín " + (formattedPrint met.densidadeRazao format:".2f") + "×" +
        " · distorção máx " + (formattedPrint met.distorcaoMax format:".2f") + "×" +
        " · fora do 0–1: " + met.foraDe01 as string +
        " · sobrepostas: " + met.sobrepostas as string +
        " · invertidos: " + met.invertidos as string + (if met.espelhado then " (objeto espelhado)" else "") +
        " · gutter mín " + (if met.gutterMin == undefined then "n/d"
                            else if met.gutterMin >= INLAB_UV_GUTTER_BUSCA then "≥" + (formattedPrint INLAB_UV_GUTTER_BUSCA format:".3f")
                            else formattedPrint met.gutterMin format:".4f") +
        " · borda mín " + (if met.bordaMin == undefined then "n/d" else formattedPrint met.bordaMin format:".4f")
    )
)
