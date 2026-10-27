/*
 functions\fn_mapear_cortar.ms — Mapear assistido: Cortar e Sentido (feature de 27/10/2026).
 Parte 1 (Tarefa 2): marcas guardadas na peça. O desenhista seleciona arestas de costura na
 base Editable Poly; o plugin guarda as costuras (bitarray de arestas) e as guias de veio
 (aresta + angulo) no proprio no via setAppData, para sobreviverem a salvar e reabrir o .max.
 Formato: costuras = "<nFaces>;<nArestas>;<e1>,<e2>,..." ; guias = "<e>:<ang>;<e>:<ang>"
 (angulo com formattedPrint format:".2f", ponto decimal garantido na gravacao e na leitura).
 Se nFaces/nArestas nao batem com a base (malha mudou), a leitura apaga as marcas e avisa.
 Parte 2 (Tarefa 3): painéis pelas costuras, piques e corte automático do anel
 (InLab_Cortar_Paineis) e ids de UV por canto abertos nos cortes (InLab_Cortar_IdsCanto).
 Só geometria; detalhes no bloco da Parte 2, mais abaixo.
 Spec: docs\superpowers\specs\2026-10-27-mapear-assistido-design.md
*/
global INLAB_CORTAR_APPDATA_COSTURAS = 7301
global INLAB_CORTAR_APPDATA_GUIAS = 7302
global InLab_Log

struct InLab_CortarMarcas ( nFaces, nArestas, costuras, guias )

fn InLab_Cortar_TemMarcas o =
(
    (getAppData o INLAB_CORTAR_APPDATA_COSTURAS) != undefined
)

fn InLab_Cortar_ApagarMarcas o =
(
    deleteAppData o INLAB_CORTAR_APPDATA_COSTURAS
    deleteAppData o INLAB_CORTAR_APPDATA_GUIAS
    true
)

fn InLab_Cortar_GravarMarcas o marcas =
(
    local b = o.baseobject
    local nF = polyop.getNumFaces b
    local nE = polyop.getNumEdges b
    local s = nF as string + ";" + nE as string + ";"
    local primeiro = true
    for e in marcas.costuras do
    (
        if not primeiro do s += ","
        s += e as string
        primeiro = false
    )
    setAppData o INLAB_CORTAR_APPDATA_COSTURAS s
    local g = ""
    for k = 1 to marcas.guias.count do
    (
        local a = formattedPrint (marcas.guias[k][2] as float) format:".2f"
        a = substituteString a "," "."
        if k > 1 do g += ";"
        g += (marcas.guias[k][1] as string) + ":" + a
    )
    setAppData o INLAB_CORTAR_APPDATA_GUIAS g
    true
)

fn InLab_Cortar_LerMarcas o =
(
    local sc = getAppData o INLAB_CORTAR_APPDATA_COSTURAS
    if sc == undefined do return undefined
    local b = o.baseobject
    local partes = filterString sc ";"
    local nF = if partes.count >= 1 then (partes[1] as integer) else undefined
    local nE = if partes.count >= 2 then (partes[2] as integer) else undefined
    if nF != polyop.getNumFaces b or nE != polyop.getNumEdges b do
    (
        InLab_Log (o.name + ": a malha mudou desde o último corte; marque as costuras de novo.") tipo:#warn
        InLab_Cortar_ApagarMarcas o
        return undefined
    )
    local cost = #{}
    if partes.count >= 3 do
        for t in (filterString partes[3] ",") do ( local v = t as integer; if v != undefined and v > 0 do cost[v] = true )
    local guias = #()
    local sg = getAppData o INLAB_CORTAR_APPDATA_GUIAS
    if sg != undefined do
        for par in (filterString sg ";") do
        (
            local kv = filterString par ":"
            if kv.count == 2 do
            (
                local ang = (substituteString kv[2] "," ".") as float
                append guias #(kv[1] as integer, ang)
            )
        )
    InLab_CortarMarcas nFaces:nF nArestas:nE costuras:cost guias:guias
)

/* ---------------------------------------------------------------------------------------
 Parte 2 (Tarefa 3, 27/10/2026): painéis pelas costuras, piques e corte do anel. Só
 geometria: nada é gravado na cena. Spec seções 5.2 e 5.3.
 - Painéis: InLab_Paineis_Regioes com as costuras como barreira, elemento por elemento
   (InLab_Paineis_Elementos já tira face morta). Elemento sem costura = 1 painel.
 - Pique: aresta de costura com a mesma região dos dois lados.
 - Anel: região com 2+ contornos de borda (o mesmo critério de InLab_Paineis_Contornos,
   aqui calculado pela adjacência montada uma vez). Se nenhum pique liga os contornos, o
   corte automático é o caminho mais curto (Dijkstra com heap binário, peso = comprimento
   da aresta em mundo) entre os contornos, só por vértices do lado escondido: Y maior que
   o centro da região (a frente é -Y) ou, com o eixo do anel horizontal (X ou Y), Z menor.
   Sem caminho no lado escondido: caminho sem restrição, com #info. Com 3+ contornos, um
   corte por vez até todos ficarem ligados.
 - Adjacência montada uma vez com polyop.getFaceEdges/getEdgeFaces/getEdgeVerts (nunca
   getFacesUsingEdge por aresta: travou o Max por 30 min no Painéis).
--------------------------------------------------------------------------------------- */
global InLab_Paineis_Elementos, InLab_Paineis_Regioes, InLab_Paineis_PosMundo, InLab_Paineis_EixoAnel
global InLab_Mapear_PolyDe
global InLab_Cortar_UFRaiz, InLab_Cortar_Caminho, InLab_Cortar_AbrirAnel
global InLab_Cortar_Paineis, InLab_Cortar_IdsCanto

struct InLab_CortarPaineis ( paineis, aneis, piques, cortesAuto, minusculos )

-- raiz no union-find (array de pais), com compressão de caminho
fn InLab_Cortar_UFRaiz pai i =
(
    local r = i
    while pai[r] != r do r = pai[r]
    while pai[i] != r do ( local n = pai[i]; pai[i] = r; i = n )
    r
)

-- Dijkstra com heap binário. nbV/nbE/nbW: vizinhos, arestas e pesos por vértice.
-- fontes: array de vértices; alvo: bitarray; permitido: bitarray (undefined = todos).
-- Devolve o bitarray de arestas do caminho, ou undefined se não há caminho.
fn InLab_Cortar_Caminho nbV nbE nbW fontes alvo permitido =
(
    local dist = #(), viaE = #(), viaV = #()
    local hk = #(), hv = #()
    for s in fontes where permitido == undefined or permitido[s] do
    (
        dist[s] = 0.0
        append hk 0.0
        append hv s
    )
    local achado = 0
    while hk.count > 0 and achado == 0 do
    (
        -- tira o topo do heap
        local d = hk[1], v = hv[1]
        local n = hk.count
        hk[1] = hk[n]; hv[1] = hv[n]
        hk.count = n - 1; hv.count = n - 1
        n -= 1
        local i = 1
        local desce = true
        while desce do
        (
            local l = 2 * i, m = i
            if l <= n and hk[l] < hk[m] do m = l
            if l + 1 <= n and hk[l + 1] < hk[m] do m = l + 1
            if m == i then desce = false
            else
            (
                local tk = hk[i], tv = hv[i]
                hk[i] = hk[m]; hv[i] = hv[m]; hk[m] = tk; hv[m] = tv
                i = m
            )
        )
        if d <= dist[v] do
        (
            if alvo[v] then achado = v
            else if nbV[v] != undefined do
                for j = 1 to nbV[v].count do
                (
                    local u = nbV[v][j]
                    if permitido == undefined or permitido[u] do
                    (
                        local nd = d + nbW[v][j]
                        if dist[u] == undefined or nd < dist[u] do
                        (
                            dist[u] = nd; viaE[u] = nbE[v][j]; viaV[u] = v
                            -- põe no heap
                            append hk nd
                            append hv u
                            local c = hk.count
                            local sobe = true
                            while sobe and c > 1 do
                            (
                                local p = c / 2
                                if hk[p] > hk[c] then
                                (
                                    local tk = hk[p], tv = hv[p]
                                    hk[p] = hk[c]; hv[p] = hv[c]; hk[c] = tk; hv[c] = tv
                                    c = p
                                )
                                else sobe = false
                            )
                        )
                    )
                )
        )
    )
    if achado == 0 then undefined
    else
    (
        local cam = #{}
        local v = achado
        while viaE[v] != undefined do ( cam[viaE[v]] = true; v = viaV[v] )
        cam
    )
)

-- corte automático de uma região em anel. Devolve as arestas do corte (bitarray, vazio se
-- os piques já ligam os contornos). eVerts: vértices por aresta; eFacesReg: quantas faces
-- da região tocam a aresta (1 = borda, 2 = interior); piquesReg: piques da região.
fn InLab_Cortar_AbrirAnel po posM reg arestasReg eVerts eFacesReg piquesReg nomePeca =
(
    local nV = polyop.getNumVerts po
    -- union-find por vértice: une pelas bordas (contornos) e pelos piques
    local pai = for i = 1 to nV collect i
    local naBorda = #{}
    for e in arestasReg where eFacesReg[e] == 1 or piquesReg[e] do
    (
        local a = eVerts[e][1], b = eVerts[e][2]
        if eFacesReg[e] == 1 do ( naBorda[a] = true; naBorda[b] = true )
        local ra = InLab_Cortar_UFRaiz pai a, rb = InLab_Cortar_UFRaiz pai b
        if ra != rb do pai[ra] = rb
    )
    local corte = #{}
    -- grafo do Dijkstra: arestas internas da região
    local nbV = #(), nbE = #(), nbW = #()
    nbV.count = nV; nbE.count = nV; nbW.count = nV
    for e in arestasReg where eFacesReg[e] == 2 do
    (
        local a = eVerts[e][1], b = eVerts[e][2]
        local w = distance posM[a] posM[b]
        if nbV[a] == undefined do ( nbV[a] = #(); nbE[a] = #(); nbW[a] = #() )
        if nbV[b] == undefined do ( nbV[b] = #(); nbE[b] = #(); nbW[b] = #() )
        append nbV[a] b; append nbE[a] e; append nbW[a] w
        append nbV[b] a; append nbE[b] e; append nbW[b] w
    )
    -- lado escondido: Y maior que o centro; Z menor se o eixo do anel é horizontal
    local vsReg = polyop.getVertsUsingFace po reg
    local mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]
    for v in vsReg do
    (
        local p = posM[v]
        mn = [amin mn.x p.x, amin mn.y p.y, amin mn.z p.z]
        mx = [amax mx.x p.x, amax mx.y p.y, amax mx.z p.z]
    )
    local centro = (mn + mx) / 2.0
    -- sinal 1.0: EixoAnel só soma |n|
    local k = InLab_Paineis_EixoAnel po posM reg 1.0
    local escondido = #{}
    for v in vsReg do
        if (if k == 3 then posM[v].y > centro.y else posM[v].z < centro.z) do escondido[v] = true
    local voltas = 0
    local seguir = true
    while seguir do
    (
        -- grupos de contorno ainda separados
        local raizes = #()
        for v in naBorda do appendIfUnique raizes (InLab_Cortar_UFRaiz pai v)
        if raizes.count < 2 then seguir = false
        else
        (
            voltas += 1
            local rA = raizes[1]
            local fontes = #(), alvo = #{}
            for v in vsReg do
            (
                local r = InLab_Cortar_UFRaiz pai v
                if r == rA then append fontes v
                else if (findItem raizes r) > 0 do alvo[v] = true
            )
            local cam = InLab_Cortar_Caminho nbV nbE nbW fontes (alvo * escondido) escondido
            if cam == undefined do
            (
                cam = InLab_Cortar_Caminho nbV nbE nbW fontes alvo undefined
                if cam != undefined do
                    InLab_Log (nomePeca + ": anel sem caminho pelo lado escondido; corte automático pelo caminho mais curto em qualquer lado.") tipo:#info
            )
            if cam == undefined or voltas > 50 then
            (
                InLab_Log (nomePeca + ": anel sem caminho entre as bordas; ficou sem corte automático.") tipo:#warn
                seguir = false
            )
            else
            (
                corte += cam
                for e in cam do
                (
                    local ra = InLab_Cortar_UFRaiz pai eVerts[e][1], rb = InLab_Cortar_UFRaiz pai eVerts[e][2]
                    if ra != rb do pai[ra] = rb
                )
            )
        )
    )
    corte
)

-- painéis pelas costuras. o: nó (base Editable Poly); corpo: faces de tecido sem os vivos
-- (bitarray da base); costuras: bitarray de arestas da base. Devolve InLab_CortarPaineis.
fn InLab_Cortar_Paineis o corpo costuras =
(
    local po = InLab_Mapear_PolyDe o
    local nE = polyop.getNumEdges po
    local nF = polyop.getNumFaces po
    -- adjacência montada uma vez (faces mortas fora)
    local faceEdges = #(), edgeFaces = #(), eVerts = #()
    faceEdges.count = nF; edgeFaces.count = nE; eVerts.count = nE
    local arestas = #{}
    for f in corpo do
    (
        local d = polyop.getFaceDeg po f
        if d != undefined and d >= 3 do
        (
            faceEdges[f] = polyop.getFaceEdges po f
            for e in faceEdges[f] do arestas[e] = true
        )
    )
    for e in arestas do ( edgeFaces[e] = polyop.getEdgeFaces po e; eVerts[e] = polyop.getEdgeVerts po e )
    local adj = #(faceEdges, edgeFaces)
    local posM = InLab_Paineis_PosMundo o corpo
    local nomePeca = o.name
    local paineis = #(), aneis = #()
    local piques = #{}, cortesAuto = #{}
    local minusculos = 0
    local regDe = #()
    regDe.count = nF
    for el in (InLab_Paineis_Elementos po corpo) do
        for reg in (InLab_Paineis_Regioes po el costuras adj:adj) do
        (
            append paineis reg
            for f in reg do regDe[f] = paineis.count
        )
    -- piques: costura com a mesma região dos dois lados
    for e in (arestas * costuras) do
    (
        local fs = edgeFaces[e]
        if fs.count == 2 and regDe[fs[1]] != undefined and regDe[fs[1]] == regDe[fs[2]] do piques[e] = true
    )
    local eFacesReg = #()
    eFacesReg.count = nE
    for i = 1 to paineis.count do
    (
        local reg = paineis[i]
        if reg.numberSet < 4 do minusculos += 1
        -- arestas da região e quantas faces dela tocam cada uma
        local arestasReg = #{}
        for f in reg do for e in faceEdges[f] do arestasReg[e] = true
        for e in arestasReg do
        (
            local n = 0
            for g in edgeFaces[e] where regDe[g] == i do n += 1
            eFacesReg[e] = n
        )
        -- contornos: arestas de borda agrupadas pelos vértices
        local nC = 0
        local pai = #()
        for e in arestasReg where eFacesReg[e] == 1 do for v in eVerts[e] do pai[v] = v
        for e in arestasReg where eFacesReg[e] == 1 do
        (
            local ra = InLab_Cortar_UFRaiz pai eVerts[e][1], rb = InLab_Cortar_UFRaiz pai eVerts[e][2]
            if ra != rb do pai[ra] = rb
        )
        for v = 1 to pai.count where pai[v] == v do nC += 1
        local ehAnel = nC >= 2
        append aneis ehAnel
        if ehAnel do
        (
            local corte = InLab_Cortar_AbrirAnel po posM reg arestasReg eVerts eFacesReg (piques * arestasReg) nomePeca
            if not corte.isEmpty do
            (
                cortesAuto += corte
                InLab_Log (nomePeca + ": painel em anel (" + reg.numberSet as string + " faces) ganhou corte automático de " + corte.numberSet as string + " aresta(s).") tipo:#info
            )
        )
    )
    InLab_CortarPaineis paineis:paineis aneis:aneis piques:piques cortesAuto:cortesAuto minusculos:minusculos
)

-- ids de UV por canto: cada vértice ganha um id por grupo de faces de fs em volta dele
-- ligadas por arestas fora de cortes. Devolve #(mapa, nIds), mapa = #(#(face, #(ids))).
fn InLab_Cortar_IdsCanto po fs cortes =
(
    local nF = polyop.getNumFaces po
    local ini = #(), fVerts = #()
    ini.count = nF; fVerts.count = nF
    local n = 0
    local lista = #()
    for f in fs do
    (
        local d = polyop.getFaceDeg po f
        if d != undefined and d >= 3 do
        (
            fVerts[f] = polyop.getFaceVerts po f
            ini[f] = n
            n += fVerts[f].count
            append lista f
        )
    )
    local pai = for i = 1 to n collect i
    local arestas = #{}
    for f in lista do for e in (polyop.getFaceEdges po f) do arestas[e] = true
    for e in arestas where not cortes[e] do
    (
        local gs = for g in (polyop.getEdgeFaces po e) where ini[g] != undefined collect g
        if gs.count == 2 do
            for v in (polyop.getEdgeVerts po e) do
            (
                local c1 = ini[gs[1]] + (findItem fVerts[gs[1]] v)
                local c2 = ini[gs[2]] + (findItem fVerts[gs[2]] v)
                local ra = InLab_Cortar_UFRaiz pai c1, rb = InLab_Cortar_UFRaiz pai c2
                if ra != rb do pai[ra] = rb
            )
    )
    local idDe = #()
    idDe.count = n
    local nIds = 0
    local mapa = #()
    for f in lista do
    (
        local ids = #()
        for j = 1 to fVerts[f].count do
        (
            local r = InLab_Cortar_UFRaiz pai (ini[f] + j)
            if idDe[r] == undefined do ( nIds += 1; idDe[r] = nIds )
            append ids idDe[r]
        )
        append mapa #(f, ids)
    )
    #(mapa, nIds)
)
