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
 Parte 3 (Tarefa 4, 27/10/2026): UV da peça com um Unfold3D só, escala por ilha e trama
 pela guia ou pela regra padrão (InLab_Cortar_UV). Detalhes no bloco da Parte 3.
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

/* ---------------------------------------------------------------------------------------
 Parte 3 (Tarefa 4, 27/10/2026): UV da peça. Spec seções 5.3, 5.4, 5.5 e 9.1. Nada é
 gravado: devolve #(uvs, mapa, nGuia, nRegra) no formato de InLab_Mapear_Gravar.
 1. UV inicial por painel: disco pela InLab_Paineis_UVDisco, anel pela InLab_Paineis_UVAnel
    (corte: no ângulo médio do pique/corte automático do anel). Os ids por canto vêm de
    InLab_Cortar_IdsCanto (piques + cortes automáticos; as costuras já separam os painéis,
    porque os ids são montados painel a painel). A posição de cada id sai da projeção por
    uma busca em largura pelas faces: cada face vizinha é transladada para bater no id
    compartilhado. Assim o anel fica desenrolado no corte de verdade, mesmo que o corte da
    UVAnel (um ângulo só) não coincida com o caminho do corte (lá o U difere de um perímetro).
 2. Um InLab_Paineis_Unfold só, com todas as faces (escala 1; sonda: 13.450 faces em 4 s).
    Acima de INLAB_CORTAR_MAX_FACES_UNFOLD faces, ou se o Unfold3D falha, fica a projeção
    do passo 1, com #warn.
 3. Cada ilha é reescalada pela própria área (área 3D / área UV) x escala do painel.
 4. Trama no V: guia (aresta girada pelo ângulo em volta da normal) ou regra padrão
    (anel: eixo do anel; senão |n.z| > INLAB_CORTAR_LIMIAR_DEITADO = deitado: Y; senão Z).
    Decisão desta tarefa: no painel em anel, a guia gira em volta da normal LOCAL da aresta
    (as faces dela no painel), porque a normal média do anel se anula (sonda 9.1); e o
    ângulo é medido só nas faces viradas para o mesmo lado da guia (dot > INLAB_CORTAR_COS_GUIA_ANEL),
    porque no anel desenrolado uma direção fixa do mundo se anula entre frente e trás.
    Giro menor entre (90 - ang) e (-90 - ang): a trama não tem sentido. Ilha espelhada
    (sentido de render, sinal do nó) tem o U invertido.
--------------------------------------------------------------------------------------- */
global INLAB_CORTAR_MAX_FACES_UNFOLD = 200000
global INLAB_CORTAR_LIMIAR_DEITADO = 0.7
-- anel com guia: faces com a normal a menos de ~25 graus da normal da aresta-guia medem o ângulo
global INLAB_CORTAR_COS_GUIA_ANEL = 0.9
global InLab_Paineis_UVDisco, InLab_Paineis_UVAnel, InLab_Paineis_CopiaBase, InLab_Paineis_Unfold
global InLab_Paineis_AngDir, InLab_Paineis_EspelhoUV, InLab_Paineis_Sinal, InLab_Paineis_NormalArea
global InLab_Cortar_Compor, InLab_Cortar_AngCorte, InLab_Cortar_Reescalar, InLab_Cortar_Norm180
global InLab_Cortar_DirRef, InLab_Cortar_Orientar, InLab_Cortar_UV

-- posição de cada id de canto (ic = InLab_Cortar_IdsCanto) a partir de uma projeção
-- #(uvsP, mapaP) com ids próprios: busca em largura pelas faces que compartilham ids, cada
-- face transladada para bater no id já posto. Devolve o array de posições (nIds).
fn InLab_Cortar_Compor ic proj =
(
    local mapaIds = ic[1], nIds = ic[2]
    local uvsP = proj[1]
    local idsP = #()
    for e in proj[2] do idsP[e[1]] = e[2]
    local facesDe = #()
    facesDe.count = nIds
    for k = 1 to mapaIds.count do
        for i in mapaIds[k][2] do
        (
            if facesDe[i] == undefined do facesDe[i] = #()
            append facesDe[i] k
        )
    local pos = #()
    pos.count = nIds
    local visto = #{}
    for k0 = 1 to mapaIds.count where not visto[k0] do
    (
        visto[k0] = true
        local fila = #(k0)
        local f0 = mapaIds[k0]
        local p0 = idsP[f0[1]]
        for j = 1 to f0[2].count where pos[f0[2][j]] == undefined do pos[f0[2][j]] = uvsP[p0[j]]
        local ini = 1
        while ini <= fila.count do
        (
            local g = mapaIds[fila[ini]]
            ini += 1
            for i in g[2] do
                for h in facesDe[i] where not visto[h] do
                (
                    visto[h] = true
                    local fh = mapaIds[h]
                    local ph = idsP[fh[1]]
                    local j = findItem fh[2] i
                    local desl = pos[i] - uvsP[ph[j]]
                    for jj = 1 to fh[2].count where pos[fh[2][jj]] == undefined do pos[fh[2][jj]] = uvsP[ph[jj]] + desl
                    append fila h
                )
        )
    )
    pos
)

fn InLab_Cortar_Norm180 a = ( while a > 180.0 do a -= 360.0; while a < -180.0 do a += 360.0; a )

-- ângulo (graus, na convenção da UVAnel) dos cortes de um anel em volta do eixo k; undefined sem corte
fn InLab_Cortar_AngCorte po posM fs k cortes =
(
    local e1 = if k == 3 then [1,0,0] else if k == 1 then [0,1,0] else [1,0,0]
    local e2 = if k == 3 then [0,1,0] else [0,0,1]
    local vs = polyop.getVertsUsingFace po fs
    local c1 = 0.0, c2 = 0.0
    for v in vs do ( c1 += dot posM[v] e1; c2 += dot posM[v] e2 )
    c1 /= vs.numberSet; c2 /= vs.numberSet
    local vc = (polyop.getVertsUsingEdge po (cortes * (polyop.getEdgesUsingFace po fs))) * vs
    if vc.isEmpty then undefined
    else
    (
        local sc = 0.0, ss = 0.0
        for v in vc do
        (
            local a = atan2 ((dot posM[v] e2) - c2) ((dot posM[v] e1) - c1)
            sc += cos a; ss += sin a
        )
        atan2 ss sc
    )
)

-- reescala os uvs da ilha sub pela própria área, em volta do centro: área UV = área 3D x esc^2
fn InLab_Cortar_Reescalar po posM uvs sub esc =
(
    local a3 = 0.0, auv = 0.0, c = [0,0,0]
    local idx = #{}
    for e in sub do
    (
        a3 += length (InLab_Paineis_NormalArea posM (polyop.getFaceVerts po e[1]) 1.0)
        local q = #()
        for i in e[2] do ( append q uvs[i]; idx[i] = true )
        for j = 2 to q.count - 1 do auv += abs (((q[j] - q[1]).x * (q[j+1] - q[1]).y - (q[j] - q[1]).y * (q[j+1] - q[1]).x) / 2.0)
    )
    if auv > 1e-12 and not idx.isEmpty do
    (
        for i in idx do c += uvs[i]
        c /= idx.numberSet
        local s = (sqrt (a3 / auv)) * esc
        for i in idx do uvs[i] = (uvs[i] - c) * s + c
    )
    uvs
)

-- direção (mundo) da trama do painel fs. guia = #(aresta, ângulo) ou undefined; anel = bool
fn InLab_Cortar_DirRef o po posM fs anel guia =
(
    local sinal = InLab_Paineis_Sinal o
    if guia != undefined then
    (
        local ev = polyop.getEdgeVerts po guia[1]
        local v0 = posM[ev[2]] - posM[ev[1]]
        local n = [0,0,0]
        if anel then
        (
            for f in (polyop.getEdgeFaces po guia[1]) where fs[f] do n += InLab_Paineis_NormalArea posM (polyop.getFaceVerts po f) sinal
        )
        else for f in fs do n += InLab_Paineis_NormalArea posM (polyop.getFaceVerts po f) sinal
        if (length n) < 1e-9 then normalize v0
        else
        (
            n = normalize n
            local v = v0 - n * (dot v0 n)
            if (length v) < 1e-9 then normalize v0
            else
            (
                v = normalize v
                local a = guia[2] as float
                -- Rodrigues com v perpendicular a n
                normalize (v * (cos a) + (cross n v) * (sin a))
            )
        )
    )
    else if anel then
        #([1,0,0], [0,1,0], [0,0,1])[InLab_Paineis_EixoAnel po posM fs sinal]
    else
    (
        local n = [0,0,0]
        for f in fs do n += InLab_Paineis_NormalArea posM (polyop.getFaceVerts po f) sinal
        if (length n) > 1e-9 and abs (normalize n).z > INLAB_CORTAR_LIMIAR_DEITADO then [0,1,0] else [0,0,1]
    )
)

-- gira (e espelha, se preciso) os uvs da ilha sub até dir cair no V, pelo menor giro;
-- devolve o ângulo final de dir no UV. medir: (subconjunto de sub) mede o ângulo só nessas
-- faces: num anel desenrolado, uma direção fixa do mundo vai para +U na frente e -U atrás,
-- e a média na volta inteira se anula (achado nesta tarefa com a guia na faixa)
fn InLab_Cortar_Orientar o po posM uvs sub dir medir:undefined =
(
    local idx = #{}
    for e in sub do for i in e[2] do idx[i] = true
    if idx.isEmpty do return 0.0
    local c = [0,0,0]
    for i in idx do c += uvs[i]
    c /= idx.numberSet
    if (InLab_Paineis_EspelhoUV po posM uvs sub (InLab_Paineis_Sinal o)) > 0.5 do
        for i in idx do uvs[i] = [2.0 * c.x - uvs[i].x, uvs[i].y, 0]
    local ang = InLab_Paineis_AngDir po posM uvs (if medir != undefined and medir.count > 0 then medir else sub) dir
    local r1 = InLab_Cortar_Norm180 (90.0 - ang), r2 = InLab_Cortar_Norm180 (-90.0 - ang)
    local r = if abs r1 <= abs r2 then r1 else r2
    local cs = cos r, sn = sin r
    for i in idx do
    (
        local u = uvs[i] - c
        uvs[i] = [u.x * cs - u.y * sn, u.x * sn + u.y * cs, 0] + c
    )
    InLab_Cortar_Norm180 (ang + r)
)

-- UV da peça pelos painéis pn (InLab_CortarPaineis). escPorPainel: UV por cm de cada painel
-- (array, ou um número para todos); guias: #(#(aresta, ângulo)...). Devolve
-- #(uvs, mapa, nGuia, nRegra), ou undefined (com #warn).
fn InLab_Cortar_UV o pn escPorPainel guias =
(
    if pn == undefined or pn.paineis.count == 0 do
    (
        InLab_Log (o.name + ": cortar: nenhum painel para mapear.") tipo:#warn
        return undefined
    )
    local po = InLab_Mapear_PolyDe o
    local sinal = InLab_Paineis_Sinal o
    local nP = pn.paineis.count
    local escDe = for i = 1 to nP collect (if classof escPorPainel == Array then escPorPainel[i] else escPorPainel)
    local todas = #{}
    for reg in pn.paineis do todas += reg
    local posM = InLab_Paineis_PosMundo o todas
    local cortes = pn.piques + pn.cortesAuto
    local uvs = #(), mapa = #()
    local painelDe = #()
    local erro = undefined
    try
    (
        -- 1. UV inicial por painel
        for i = 1 to nP do
        (
            local reg = pn.paineis[i]
            for f in reg do painelDe[f] = i
            local proj = undefined
            if pn.aneis[i] then
            (
                local k = InLab_Paineis_EixoAnel po posM reg sinal
                local ac = InLab_Cortar_AngCorte po posM reg k cortes
                proj = InLab_Paineis_UVAnel po posM reg k escDe[i] corte:ac
            )
            else proj = InLab_Paineis_UVDisco po posM reg escDe[i] sinal
            local ic = InLab_Cortar_IdsCanto po reg cortes
            local pos = InLab_Cortar_Compor ic proj
            local base = uvs.count
            for q in pos do append uvs (if q == undefined then [0,0,0] else [q.x, q.y, 0])
            for e in ic[1] do
            (
                local ids = #()
                for i2 in e[2] do append ids (i2 + base)
                append mapa #(e[1], ids)
            )
        )
    )
    catch ( erro = getCurrentException() )
    if erro != undefined do
    (
        InLab_Log (o.name + ": cortar: erro no UV inicial dos painéis (" + erro + ")") tipo:#warn
        return undefined
    )
    -- 2. um Unfold3D com todas as faces
    local nF = todas.numberSet
    local res = undefined
    if nF > INLAB_CORTAR_MAX_FACES_UNFOLD then
        InLab_Log (o.name + ": cortar: " + nF as string + " faces, acima do teto do Unfold3D (" + INLAB_CORTAR_MAX_FACES_UNFOLD as string + "); fica a projeção plana.") tipo:#warn
    else
    (
        local selAntes = selection as array
        local src = undefined
        try
        (
            src = InLab_Paineis_CopiaBase o
            with undo off ( max modify mode )
            res = InLab_Paineis_Unfold src todas uvs mapa posM 1.0 o.name
        )
        catch
        (
            InLab_Log (o.name + ": cortar: erro no Unfold3D (" + (getCurrentException()) + ")") tipo:#warn
            res = undefined
        )
        with undo off
        (
            if isValidNode src do delete src
            clearSelection()
            for n in selAntes where isValidNode n do selectMore n
        )
        if res == undefined do
            InLab_Log (o.name + ": cortar: o Unfold3D não abriu a peça; fica a projeção plana.") tipo:#warn
    )
    if res != undefined do ( uvs = res[1]; mapa = res[2] )
    -- guias por painel (a aresta toca alguma face do painel)
    local guiaDe = #()
    guiaDe.count = nP
    local nE = polyop.getNumEdges po
    for g in guias do
    (
        if g[1] == undefined or g[1] < 1 or g[1] > nE then
            InLab_Log (o.name + ": cortar: guia na aresta " + g[1] as string + " fora da malha; ignorada.") tipo:#warn
        else
        (
            local ps = #()
            for f in (polyop.getEdgeFaces po g[1]) where painelDe[f] != undefined do appendIfUnique ps painelDe[f]
            for i in ps do
            (
                if guiaDe[i] == undefined then guiaDe[i] = g
                else InLab_Log (o.name + ": cortar: painel " + i as string + " tem mais de uma guia; vale a primeira (aresta " + guiaDe[i][1] as string + ").") tipo:#warn
            )
        )
    )
    -- 3 e 4. escala e direção por ilha
    local subs = for i = 1 to nP collect #()
    for e in mapa do append subs[painelDe[e[1]]] e
    local nGuia = 0, nRegra = 0
    for i = 1 to nP do
    (
        InLab_Cortar_Reescalar po posM uvs subs[i] escDe[i]
        local dir = InLab_Cortar_DirRef o po posM pn.paineis[i] pn.aneis[i] guiaDe[i]
        if guiaDe[i] != undefined then nGuia += 1 else nRegra += 1
        -- anel com guia: o ângulo é medido nas faces viradas para o mesmo lado da aresta-guia
        local medir = undefined
        if pn.aneis[i] and guiaDe[i] != undefined do
        (
            local nG = [0,0,0]
            for f in (polyop.getEdgeFaces po guiaDe[i][1]) where pn.paineis[i][f] do nG += InLab_Paineis_NormalArea posM (polyop.getFaceVerts po f) sinal
            if (length nG) > 1e-9 do
            (
                nG = normalize nG
                medir = #()
                for e in subs[i] do
                (
                    local nf = InLab_Paineis_NormalArea posM (polyop.getFaceVerts po e[1]) sinal
                    if (length nf) > 1e-12 and (dot (normalize nf) nG) > INLAB_CORTAR_COS_GUIA_ANEL do append medir e
                )
            )
        )
        InLab_Cortar_Orientar o po posM uvs subs[i] dir medir:medir
    )
    #(uvs, mapa, nGuia, nRegra)
)
