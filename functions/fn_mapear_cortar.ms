/*
 functions\fn_mapear_cortar.ms — Mapear assistido: Cortar e Sentido (feature de 27/10/2026).
 Parte 1 (Tarefa 2): marcas guardadas na peça. O desenhista seleciona arestas de costura na
 base Editable Poly; o plugin guarda as costuras (bitarray de arestas) e as guias de veio
 (aresta + angulo) num custom attribute da base (InLabCortarMarcas; ate a Tarefa 6 era
 appData no no, que nao entra no Ctrl+Z), para sobreviverem a salvar e reabrir o .max.
 Formato: costuras = "<nFaces>;<nArestas>;<e1>,<e2>,..." ; guias = "<e>:<ang>;<e>:<ang>"
 (angulo com formattedPrint format:".2f", ponto decimal garantido na gravacao e na leitura).
 Se nFaces/nArestas nao batem com a base (malha mudou), a leitura apaga as marcas e avisa.
 Parte 2 (Tarefa 3): painéis pelas costuras, piques e corte automático do anel
 (InLab_Cortar_Paineis) e ids de UV por canto abertos nos cortes (InLab_Cortar_IdsCanto).
 Só geometria; detalhes no bloco da Parte 2, mais abaixo.
 Parte 3 (Tarefa 4, 27/10/2026): UV da peça com um Unfold3D só, escala por ilha e trama
 pela guia ou pela regra padrão (InLab_Cortar_UV). Detalhes no bloco da Parte 3.
 Parte 4 (Tarefa 5, 27/10/2026): botão Cortar (InLab_Cortar), uma peça por vez, com pilha,
 marcas e Ver UV. Detalhes no bloco da Parte 4.
 Parte 5 (Tarefa 6, 27/10/2026): botão Sentido (InLab_Sentido), aresta-guia + ângulo nos painéis
 já cortados, sem Unfold3D e sem pilha; Ctrl+Z pela troca da base. Detalhes no bloco da Parte 5.
 Revisão final (27/10/2026): o Cortar volta o painel Modify ao nível de sub-objeto em que o
 desenhista estava (InLab_Cortar_NivelAntes/VoltarNivel; o Unfold3D o levava para objeto e as
 costuras selecionadas não apareciam); a guia do Cortar usa o filtro "a face tem a aresta";
 log próprio na guarda de 50 voltas do corte do anel.
 Spec: docs\superpowers\specs\2026-10-27-mapear-assistido-design.md
*/
global InLab_Log

struct InLab_CortarMarcas ( nFaces, nArestas, costuras, guias )

-- 27/10/2026 (Tarefa 6): custom attribute na BASE em vez de appData no nó. O setAppData não
-- entra no Ctrl+Z (conferido no Max: undo on (setAppData ...) e max undo mantém o valor novo);
-- mudança em parameter block entra, e o custAttributes.add também. Instâncias dividem a base,
-- então dividem as marcas. attribID fixo: a definição salva no .max é achada de novo ao reabrir.
global INLAB_CORTAR_CA_DEF = attributes InLabCortarMarcas attribID:#(0x4c7e2a91, 0x1b9d63f5)
(
    parameters main
    (
        costuras type:#string default:""
        guias type:#string default:""
    )
)

-- o custom attribute das marcas na base de o, ou undefined
fn InLab_Cortar_AtribMarcas o =
(
    if not (isValidNode o) or o.baseobject == undefined then undefined
    else custAttributes.get o.baseobject INLAB_CORTAR_CA_DEF
)

fn InLab_Cortar_TemMarcas o =
(
    local ca = InLab_Cortar_AtribMarcas o
    ca != undefined and ca.costuras != ""
)

-- zera as marcas (parameter block: entra no Ctrl+Z)
fn InLab_Cortar_ApagarMarcas o =
(
    local ca = InLab_Cortar_AtribMarcas o
    if ca != undefined do ( ca.costuras = ""; ca.guias = "" )
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
    local g = ""
    for k = 1 to marcas.guias.count do
    (
        local a = formattedPrint (marcas.guias[k][2] as float) format:".2f"
        a = substituteString a "," "."
        if k > 1 do g += ";"
        g += (marcas.guias[k][1] as string) + ":" + a
    )
    local ca = InLab_Cortar_AtribMarcas o
    if ca == undefined do
    (
        custAttributes.add b INLAB_CORTAR_CA_DEF
        ca = InLab_Cortar_AtribMarcas o
    )
    ca.costuras = s
    ca.guias = g
    true
)

fn InLab_Cortar_LerMarcas o =
(
    local ca = InLab_Cortar_AtribMarcas o
    if ca == undefined or ca.costuras == "" do return undefined
    local sc = ca.costuras
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
    local sg = ca.guias
    if sg != "" do
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
 - Tarefa 5 (27/10/2026): depois do polyop.collapseDeadStructs de uma face morta (o Preparar
   tira), o getEdgeFaces das arestas dela ainda lista o índice antigo, que agora é outra
   face ("array index 0" no InLab_Cortar_IdsCanto). Paineis e IdsCanto só aceitam a face
   que tem a aresta no getFaceEdges.
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
                -- revisão final: a guarda de 50 voltas tem log próprio (antes saía "sem caminho")
                if cam == undefined then
                    InLab_Log (nomePeca + ": anel sem caminho entre as bordas; ficou sem corte automático.") tipo:#warn
                else
                    InLab_Log (nomePeca + ": anel com mais de 50 contornos de borda para ligar; parei o corte automático na 50ª ligação (o resto fica sem corte).") tipo:#warn
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
    -- Tarefa 5: depois do collapseDeadStructs de uma face morta, as arestas dela ainda listam o
    -- índice antigo (agora outra face) no getEdgeFaces: só fica a face que tem a aresta
    local descartadas = 0
    for e in arestas do
    (
        local fs = #()
        for g in (polyop.getEdgeFaces po e) do
        (
            -- referência de face fora de 1..nF (resto de face morta compactada): ignora e conta
            if g < 1 or g > nF then descartadas += 1
            else
            (
                local eg = if faceEdges[g] != undefined then faceEdges[g] else polyop.getFaceEdges po g
                if (findItem eg e) > 0 do append fs g
            )
        )
        edgeFaces[e] = fs
        eVerts[e] = polyop.getEdgeVerts po e
    )
    if descartadas > 0 do InLab_Log (o.name + ": " + descartadas as string + " referência(s) de face inválida(s) nas arestas ignorada(s).") tipo:#warn
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
    local fEdges = #()
    fEdges.count = nF
    for f in lista do ( fEdges[f] = polyop.getFaceEdges po f; for e in fEdges[f] do arestas[e] = true )
    for e in arestas where not cortes[e] do
    (
        -- Tarefa 5: face que não tem a aresta (índice velho depois do collapseDeadStructs) fica fora
        local gs = for g in (polyop.getEdgeFaces po e) where ini[g] != undefined and (findItem fEdges[g] e) > 0 collect g
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
global InLab_Cortar_DirRef, InLab_Cortar_Orientar, InLab_Cortar_UV, InLab_Cortar_MedirAnel

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

-- anel com guia: as entradas de sub (#(face, ids)) cujas faces estão viradas para o mesmo lado
-- da aresta-guia (normal local das faces dela no painel reg); undefined se a normal se anula.
-- Usado pelo Cortar (InLab_Cortar_UV) e pelo Sentido para o medir: do InLab_Cortar_Orientar.
fn InLab_Cortar_MedirAnel po posM reg sub aresta sinal =
(
    local medir = undefined
    local nG = [0,0,0]
    for f in (polyop.getEdgeFaces po aresta) where reg[f] do nG += InLab_Paineis_NormalArea posM (polyop.getFaceVerts po f) sinal
    if (length nG) > 1e-9 do
    (
        nG = normalize nG
        medir = #()
        for e in sub do
        (
            local nf = InLab_Paineis_NormalArea posM (polyop.getFaceVerts po e[1]) sinal
            if (length nf) > 1e-12 and (dot (normalize nf) nG) > INLAB_CORTAR_COS_GUIA_ANEL do append medir e
        )
    )
    medir
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
    -- guias por painel (a aresta toca alguma face do painel; só face que de fato lista a aresta,
    -- o mesmo filtro de InLab_Cortar_PaineisDaAresta, revisão final de 27/10/2026)
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
            for f in (polyop.getEdgeFaces po g[1]) where painelDe[f] != undefined and (findItem (polyop.getFaceEdges po f) g[1]) > 0 do appendIfUnique ps painelDe[f]
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
        local medir = if pn.aneis[i] and guiaDe[i] != undefined then InLab_Cortar_MedirAnel po posM pn.paineis[i] subs[i] guiaDe[i][1] sinal else undefined
        InLab_Cortar_Orientar o po posM uvs subs[i] dir medir:medir
    )
    #(uvs, mapa, nGuia, nRegra)
)

/* ---------------------------------------------------------------------------------------
 Parte 4 (Tarefa 5, 27/10/2026): botão Cortar. Spec seções 4, 5.1, 5.2, 6 e 7.
 Uma peça por vez. Guardas (#warn, nada muda): sem produto; nenhuma ou mais de uma peça
 (instâncias da mesma peça contam como uma); sem RWF; base que não é Editable_Poly (a
 conversão renumeraria as arestas selecionadas); não é tecido; sem costuras (seleção de
 arestas da BASE vazia e nenhuma marca guardada; seleção num Edit_Poly do stack não vale).
 Orquestração como o InLab_Paineis faz para uma peça: InLab_Mapear_CanaisIni/TamIni,
 grupos abertos, undo "InLab Cortar", varredura dos InLab_tmp_*, pilha InLab_PilhaPaineis.
 - As costuras vão para a seleção de arestas da base ANTES do InLab_Paineis_Preparar: o
   collapseDeadStructs da face morta renumera as faces e mantém a seleção (sonda de 27/10),
   então as costuras são relidas da seleção depois do Preparar.
 - Corpo = faces dos IDs de tecido menos os elementos de vivo (InLab_Paineis_EhVivo), a mesma
   regra do passo 3 de InLab_Paineis_Peca.
 - cm por ID: TODOS os IDs de prep.tec vão no refeitasCmPorID (o Aplicar põe 1.0 no que
   faltar); o painel que mistura IDs usa a escala do ID com mais faces nele.
 - rec.marcas = marcas de antes do Cortar, ou #nenhuma (não havia marca). O Desfazer
   Painéis e o InLab_Paineis_RestaurarPeca devolvem (InLab_Paineis_VoltarMarcas).
 - Marcas novas = costuras + guias de antes. Seleção no fim = só as costuras guardadas
   (piques são costuras, ficam selecionados). Revisão da Tarefa 6: o corte automático do
   anel saiu da seleção (um 2º Cortar o guardava como costura, contra a spec 5.3); vai para
   o log (#info com o nº de arestas). Ver UV ligado na peça.
 - Tarefa 6 (27/10/2026): o Cortar troca a base por uma cópia dentro do undo
   (InLab_Cortar_TrocarBase, a mesma cópia em todas as instâncias) e grava nela; peça pulada
   volta a base original (InLab_Cortar_PorBase). Motivo: as
   escritas de canal de mapa do polyop não entram no Ctrl+Z, e a troca de base entra.
--------------------------------------------------------------------------------------- */
global InLab_Cortar, InLab_Cortar_SelecaoArestas, InLab_Cortar_Corpo, InLab_Cortar_Peca, InLab_Cortar_TrocarBase
global InLab_Cortar_NosDaBase, InLab_Cortar_PorBase, InLab_Cortar_NivelAntes, InLab_Cortar_VoltarNivel
global InLab_Paineis_Preparar, InLab_Paineis_Aplicar, InLab_Paineis_DevolverBase
global InLab_Paineis_EhTecido, InLab_Paineis_EhVivo, InLab_Paineis_Escala, InLab_Paineis_UTil, InLab_Paineis_Girada
global InLab_Mapear_FacesDoID, InLab_Mapear_SemRWF, InLab_Mapear_ZerarCache, InLab_Mapear_Num
global InLab_Mapear_CanaisIni, InLab_Mapear_TamIni, InLab_Mapear_Bitmaps, InLab_Mapear_Mat, InLab_RWF_CanalBitmap
global InLab_Mapear_EhRWF, InLab_Mapear_CanalModUV, InLab_Mapear_DensRWF, InLab_Mapear_Grupos
global InLab_Mapear_BitmapDifuso, InLab_Mapear_TamDoBitmap
global InLab_PilhaPaineis, InLab_VerUV_Ligar, InLab_EhGeometria
global InLab_Instancias, InLab_DeduplicarInstancias, InLab_AbrirGruposAcima, InLab_FecharGrupos

-- Tarefa 6 (27/10/2026): troca a base de o (e das instâncias, que dividem a base) por uma
-- cópia e devolve a original. Chamar dentro do undo: o polyop.setMapVert/setMapFace/
-- setNumMapVerts NÃO entra no Ctrl+Z (sondado no Max 2024: depois do max undo o canal 1
-- fica como gravado), mas a troca da base entra; o Ctrl+Z volta a base original intacta,
-- com o canal 1 e as marcas (custom attribute, copiado junto) de antes.
-- Correção da revisão (27/10/2026): com o stack VAZIO (o normal depois de um Cortar, que tira
-- os RWF) o o.baseobject = ... troca só o objeto daquele nó e a instância fica com a base
-- velha (InstanceMgr.GetInstances cai de 2 para 1). Por isso a mesma cópia vai para todos os
-- nós que dividem a base (instâncias + referências); com modificador também vale (sondado).
fn InLab_Cortar_NosDaBase o =
(
    local b = o.baseobject
    local ns = #(o)
    for n in (InLab_Instancias o) where isValidNode n do appendIfUnique ns n
    for n in (refs.dependentNodes b) where isValidNode n and n.baseobject == b do appendIfUnique ns n
    ns
)

-- põe a base b em todos os nós que dividem a base atual de o
fn InLab_Cortar_PorBase o b =
(
    local ns = InLab_Cortar_NosDaBase o
    for n in ns do n.baseobject = b
    ns
)

fn InLab_Cortar_TrocarBase o =
(
    local orig = o.baseobject
    InLab_Cortar_PorBase o (copy orig)
    orig
)

-- Revisão final (27/10/2026): fluxo real do desenhista, painel Modify no nível Aresta da base.
-- Sondado no Max 2024: a troca da base com subObjectLevel 2 não dá erro e mantém o nível e as
-- instâncias, mas o Unfold3D (select do nó temporário e a seleção devolvida) volta o nível para
-- objeto, e as costuras guardadas ficam selecionadas sem aparecer. O Cortar guarda o nível
-- antes e devolve no fim (with undo off). O Sentido não mexe na seleção de nós: o nível fica.
-- nível de sub-objeto do painel Modify se ele mostra a base de o (senão 0)
fn InLab_Cortar_NivelAntes o =
(
    local so = 0
    try
    (
        if (getCommandPanelTaskMode()) == #modify and selection.count == 1 and            (findItem (InLab_Cortar_NosDaBase o) selection[1]) > 0 and (modPanel.getCurrentObject()) == o.baseobject do
            so = subObjectLevel
    )
    catch ( so = 0 )
    if so == undefined then 0 else so
)

-- devolve o nível so na base de o, se a seleção ainda é a peça (ou uma instância dela)
fn InLab_Cortar_VoltarNivel o so =
(
    if so > 0 and isValidNode o and selection.count == 1 and (findItem (InLab_Cortar_NosDaBase o) selection[1]) > 0 do
        try
        (
            with undo off
            (
                if (getCommandPanelTaskMode()) != #modify do max modify mode
                if (modPanel.getCurrentObject()) != o.baseobject do modPanel.setCurrentObject o.baseobject
                subObjectLevel = so
            )
        )
        catch ( InLab_Log (o.name + ": não voltei o nível de sub-objeto do painel Modify (" + getCurrentException() + ").") tipo:#warn )
)

-- seleção de arestas da base Editable Poly (#{} em outra classe)
fn InLab_Cortar_SelecaoArestas o =
(
    if isValidNode o and (classof o.baseobject) == Editable_Poly then polyop.getEdgeSelection o.baseobject else #{}
)

-- faces dos IDs de tecido menos os elementos de vivo: #(corpo, nº de vivos)
fn InLab_Cortar_Corpo o tec =
(
    local po = o.baseobject
    local tecFaces = #{}
    for id in tec do tecFaces += InLab_Mapear_FacesDoID o id
    local corpo = copy tecFaces
    local nVivos = 0
    for el in (InLab_Paineis_Elementos po tecFaces) do
        if (InLab_Paineis_EhVivo o el)[1] do ( corpo -= el; nVivos += 1 )
    #(corpo, nVivos)
)

-- uma peça já conferida pelas guardas. costuras: bitarray; marcasAntes: InLab_CortarMarcas ou
-- undefined. Devolve #(#refeita, MapearRecord, painéis) ou #(#pulada, undefined, undefined).
fn InLab_Cortar_Peca o produto costuras marcasAntes rodada =
(
    local res = #(#pulada, undefined, undefined)
    local t0 = timeStamp()
    local po = o.baseobject
    local selAntes = polyop.getEdgeSelection po
    polyop.setEdgeSelection po costuras
    local prep = InLab_Paineis_Preparar o produto
    if prep == undefined do
    (
        polyop.setEdgeSelection po selAntes
        return res
    )
    -- relida: o Preparar pode ter tirado face morta (a seleção acompanha a renumeração)
    costuras = polyop.getEdgeSelection po
    local tec = prep.tec
    local cv = InLab_Cortar_Corpo o tec
    local corpo = cv[1], nVivos = cv[2]
    if corpo.isEmpty do
    (
        InLab_Log (o.name + ": só há vivo nas faces de tecido; peça como estava.") tipo:#warn
        polyop.setEdgeSelection po selAntes
        InLab_Paineis_DevolverBase o prep
        return res
    )
    -- painéis
    local tP = timeStamp()
    local pn = InLab_Cortar_Paineis o corpo costuras
    InLab_Log (o.name + ": " + pn.paineis.count as string + " painéis pelas costuras (" + costuras.numberSet as string +
               " aresta(s)) em " + (InLab_Mapear_Num ((timeStamp() - tP) / 1000.0)) + " s.") tipo:#info
    if not pn.piques.isEmpty do
        InLab_Log (o.name + ": " + pn.piques.numberSet as string + " aresta(s) de costura são pique (abrem o UV sem separar painel).") tipo:#info
    for reg in pn.paineis where reg.numberSet < 4 do
        InLab_Log (o.name + ": painel minúsculo de " + reg.numberSet as string + " face(s) (costura mal fechada?); aberto como os outros.") tipo:#warn
    -- escala por ID (todos os IDs de tecido) e por painel (o ID com mais faces nele)
    local escPorID = #(), cmPorIDp = #()
    for id in tec do
    (
        local e = InLab_Paineis_Escala o id
        append escPorID e
        append cmPorIDp (1.0 / (e * (InLab_Paineis_UTil o id)))
    )
    local escPainel = #()
    for reg in pn.paineis do
    (
        local cont = for id in tec collect 0
        for f in reg do
        (
            local k = findItem tec (polyop.getFaceMatID po f)
            if k > 0 do cont[k] += 1
        )
        local kM = 1
        for k = 2 to tec.count where cont[k] > cont[kM] do kM = k
        append escPainel escPorID[kM]
    )
    -- UV (um Unfold3D) com as guias de antes
    local guias = if marcasAntes != undefined then marcasAntes.guias else #()
    local tU = timeStamp()
    local uv = InLab_Cortar_UV o pn escPainel guias
    InLab_Log (o.name + ": UV dos painéis (Unfold3D) em " + (InLab_Mapear_Num ((timeStamp() - tU) / 1000.0)) + " s.") tipo:#info
    if uv == undefined do
    (
        InLab_Log (o.name + ": não gerei o UV dos painéis; peça como estava.") tipo:#warn
        polyop.setEdgeSelection po selAntes
        InLab_Paineis_DevolverBase o prep
        return res
    )
    -- gravação
    local tG = timeStamp()
    local cmLista = #()
    for k = 1 to tec.count do append cmLista #(tec[k], cmPorIDp[k])
    local ap = InLab_Paineis_Aplicar o prep uv cmLista rodada
    if ap[1] != #refeita do
    (
        polyop.setEdgeSelection po selAntes
        InLab_Paineis_DevolverBase o prep
        return res
    )
    local rec = ap[2]
    rec.marcas = if marcasAntes != undefined then marcasAntes else #nenhuma
    InLab_Cortar_GravarMarcas o (InLab_CortarMarcas costuras:costuras guias:guias)
    -- revisão da Tarefa 6: só as costuras (com o corte automático selecionado, um 2º Cortar o guardava como costura)
    polyop.setEdgeSelection po costuras
    if not pn.cortesAuto.isEmpty do
        InLab_Log (o.name + ": corte automático do anel com " + pn.cortesAuto.numberSet as string + " aresta(s) (fica fora da seleção e é recalculado a cada Cortar).") tipo:#info
    InLab_Log (o.name + ": gravação do canal 1 e das marcas em " + (InLab_Mapear_Num ((timeStamp() - tG) / 1000.0)) + " s.") tipo:#info
    -- resumo (spec 7)
    local txtCm = InLab_Mapear_Num cmPorIDp[1]
    local iguais = true
    for k = 2 to cmPorIDp.count where (abs (cmPorIDp[k] / cmPorIDp[1] - 1.0)) > 0.01 do iguais = false
    if not iguais do
    (
        txtCm = ""
        for k = 1 to tec.count do txtCm += (if k > 1 then ", " else "") + "ID " + tec[k] as string + " " + (InLab_Mapear_Num cmPorIDp[k])
    )
    InLab_Log (o.name + ": " + pn.paineis.count as string + " painéis pelas costuras (" + pn.piques.numberSet as string + " piques), " +
               uv[3] as string + " com guia, " + uv[4] as string + " pela regra; " + txtCm + " cm por tile" +
               (if nVivos > 0 then "; " + nVivos as string + " vivo(s) como estavam" else "") +
               " (em " + (InLab_Mapear_Num ((timeStamp() - t0) / 1000.0)) + " s).") tipo:#ok
    #(#refeita, rec, pn)
)

-- Entrada do botão Cortar: nº de peças cortadas (0 ou 1).
fn InLab_Cortar objs produto =
(
    if produto == undefined do
    (
        InLab_Log "Cortar: nenhum produto carregado; escolha o produto antes. Nada mudou." tipo:#warn
        return 0
    )
    local geo = if objs == undefined then #() else (for o in objs where isValidNode o and InLab_EhGeometria o collect o)
    local grs = InLab_DeduplicarInstancias geo
    if grs.count != 1 do
    (
        InLab_Log "Cortar: selecione uma peça de tecido só." tipo:#warn
        return 0
    )
    local o = grs[1].no
    if InLab_Mapear_SemRWF o do
    (
        InLab_Log (o.name + ": tem Real-World ou Triplanar e não passou pelo Real World Fix; rode o Real World Fix antes. Nada mudou.") tipo:#warn
        return 0
    )
    if (classof o.baseobject) != Editable_Poly do
    (
        InLab_Log (o.name + ": converta a base para Editable Poly e marque as costuras.") tipo:#warn
        return 0
    )
    if not (InLab_Paineis_EhTecido o produto) do
    (
        InLab_Log (o.name + ": Cortar é só para tecido; peça como estava.") tipo:#warn
        return 0
    )
    -- costuras: a seleção de arestas da base, senão as guardadas (as marcas de antes valem para as guias)
    local marcasAntes = InLab_Cortar_LerMarcas o
    local costuras = InLab_Cortar_SelecaoArestas o
    local deOnde = "da seleção"
    if costuras.isEmpty and marcasAntes != undefined do ( costuras = copy marcasAntes.costuras; deOnde = "guardadas" )
    if costuras.isEmpty do
    (
        InLab_Log (o.name + ": selecione as arestas de costura.") tipo:#warn
        return 0
    )
    InLab_Log (o.name + ": cortando com " + costuras.numberSet as string + " aresta(s) de costura " + deOnde + ".") tipo:#info
    local feitas = 0
    InLab_Mapear_ZerarCache()
    local rec = undefined
    local nivelAntes = InLab_Cortar_NivelAntes o
    try
    (
        -- nós da rodada (as instâncias) e estado do início da rodada, como no Painéis
        local rodada = InLab_Instancias o
        InLab_Mapear_CanaisIni = #()
        for n in rodada where (InLab_Mapear_Mat n) != undefined do
            for b in (InLab_Mapear_Bitmaps (InLab_Mapear_Mat n)) where (for x in InLab_Mapear_CanaisIni where x[1] == b collect x).count == 0 do
                append InLab_Mapear_CanaisIni #(b, InLab_RWF_CanalBitmap b)
        InLab_Mapear_TamIni = #()
        for m in o.modifiers where (InLab_Mapear_EhRWF m) do
        (
            local c = InLab_Mapear_CanalModUV m
            local dn = InLab_Mapear_DensRWF o m
            if c != undefined and dn != undefined do
                for g in (InLab_Mapear_Grupos o) do
                (
                    local b = InLab_Mapear_BitmapDifuso g[2]
                    if b != undefined and (InLab_Mapear_TamDoBitmap b) == undefined and (InLab_RWF_CanalBitmap b) == c do
                        append InLab_Mapear_TamIni #(b, dn)
                )
        )
        undo "InLab Cortar" on
        (
            for n in rodada where n != o do
            (
                InLab_Log (n.name + ": instância de " + o.name + ", recebe o mesmo corte" +
                           (if (findItem geo n) > 0 then "." else " (fora da seleção).")) tipo:#info
                if InLab_Paineis_Girada o n do
                    InLab_Log (n.name + ": instância girada ou espelhada; corte e trama calculados pela peça " + o.name + ".") tipo:#warn
            )
            local abertos = #()
            with undo off ( abertos = InLab_AbrirGruposAcima o )
            local r = #(#pulada, undefined, undefined)
            -- Tarefa 6: o Cortar trabalha numa cópia da base (o Ctrl+Z devolve a original)
            local baseOrig = InLab_Cortar_TrocarBase o
            try ( r = InLab_Cortar_Peca o produto costuras marcasAntes rodada )
            catch ( InLab_Log (o.name + ": erro inesperado no Cortar (" + getCurrentException() + ").") tipo:#err; r = #(#pulada, undefined, undefined) )
            if r[1] != #refeita do try ( InLab_Cortar_PorBase o baseOrig ) catch ( InLab_Log (o.name + ": não devolvi a base de antes (" + getCurrentException() + "); use o Ctrl+Z.") tipo:#err )
            with undo off ( InLab_FecharGrupos abertos )
            if r[1] == #refeita do ( feitas = 1; rec = r[2] )
        )
    )
    catch ( InLab_Log ("Cortar: erro inesperado (" + getCurrentException() + ").") tipo:#err )
    InLab_Mapear_CanaisIni = #()
    InLab_Mapear_TamIni = #()
    -- nenhum nó temporário fica na cena
    local sobras = for n in objects where (matchPattern n.name pattern:"InLab_tmp_*") collect n
    if sobras.count > 0 do
    (
        with undo off ( for n in sobras where isValidNode n do try ( delete n ) catch () )
        InLab_Log ("Cortar: " + sobras.count as string + " nó(s) temporário(s) InLab_tmp_* apagado(s).") tipo:#warn
    )
    if rec != undefined do
    (
        append InLab_PilhaPaineis #(rec)
        if InLab_VerUV_Ligar != undefined do InLab_VerUV_Ligar #(o)
    )
    -- revisão final: o desenhista volta ao nível em que estava (Aresta) e vê as costuras
    InLab_Cortar_VoltarNivel o nivelAntes
    feitas
)

/* ---------------------------------------------------------------------------------------
 Parte 5 (Tarefa 6, 27/10/2026): botão Sentido. Spec seções 4 (item 2 e "Regras da
 seleção"), 5.1, 5.5 e 6.
 - Uma peça (instâncias contam como uma), base Editable_Poly, marcas guardadas (senão #warn
   "corte a peça antes (Cortar)") e canal 1 na base.
 - Painéis: InLab_Cortar_Paineis com as costuras guardadas e o mesmo corpo do Cortar (faces
   dos IDs de tecido menos os vivos). Sem produto (produto:undefined), o corpo é a peça
   inteira menos os vivos: painel que mistura tecido e outro material sem costura entre eles
   seria girado inteiro, então a UI passa o produto.
 - Guias = seleção de arestas da base menos as costuras. Se a seleção ainda tem TODAS as
   costuras (o que o Cortar/Sentido deixam selecionado), as costuras e os cortes automáticos
   do anel saem calados: o desenhista pode só somar a guia à seleção. Senão, aresta de
   costura ou de corte automático na seleção: #warn e ignorada (é borda de UV, de dois
   painéis). Aresta fora dos painéis: #warn e ignorada. Duas guias no mesmo painel:
   #warn, vale a de menor índice.
 - Lê o UV atual do canal 1 (polyop.getMapFace/getMapVert) só dos painéis com guia nova,
   com vértices de mapa próprios por painel, gira (e espelha, se preciso) com
   InLab_Cortar_DirRef + InLab_Cortar_Orientar (no anel, medir: pela normal local da guia,
   InLab_Cortar_MedirAnel) e grava com InLab_Mapear_Gravar (as outras faces ficam com o UV
   que tinham). Sem Unfold3D, sem reescala, sem pilha.
 - undo "InLab Sentido": troca a base por uma cópia (InLab_Cortar_TrocarBase; a escrita no
   canal de mapa não entra no Ctrl+Z), grava, atualiza as guias guardadas (guia nova no
   painel troca a antiga) e volta a seleção às costuras guardadas.
--------------------------------------------------------------------------------------- */
global InLab_Sentido, InLab_Mapear_Gravar, InLab_Cortar_PaineisDaAresta

-- painéis (índices) de uma aresta: só as faces que de fato têm a aresta (ver Tarefa 5 na Parte 2)
fn InLab_Cortar_PaineisDaAresta po regDe e =
(
    local ps = #()
    for f in (polyop.getEdgeFaces po e) where regDe[f] != undefined and (findItem (polyop.getFaceEdges po f) e) > 0 do appendIfUnique ps regDe[f]
    ps
)

-- Entrada do botão Sentido: nº de painéis ajustados. angulo em graus (-90 a 90).
fn InLab_Sentido objs angulo produto:undefined =
(
    local geo = if objs == undefined then #() else (for o in objs where isValidNode o and InLab_EhGeometria o collect o)
    local grs = InLab_DeduplicarInstancias geo
    if grs.count != 1 do
    (
        InLab_Log "Sentido: selecione uma peça de tecido só." tipo:#warn
        return 0
    )
    local o = grs[1].no
    if (classof o.baseobject) != Editable_Poly do
    (
        InLab_Log (o.name + ": converta a base para Editable Poly e marque as costuras.") tipo:#warn
        return 0
    )
    local marcas = InLab_Cortar_LerMarcas o
    local po = o.baseobject
    if marcas == undefined or not (polyop.getMapSupport po 1) do
    (
        InLab_Log (o.name + ": corte a peça antes (Cortar).") tipo:#warn
        return 0
    )
    angulo = if angulo == undefined then 0.0 else (angulo as float)
    local costuras = marcas.costuras
    local sel = polyop.getEdgeSelection po
    local n = 0
    try
    (
        if InLab_Mapear_ZerarCache != undefined do InLab_Mapear_ZerarCache()
        -- corpo como no Cortar
        local corpo = #{}
        if produto != undefined then
        (
            local tec = for g in (InLab_Mapear_Grupos o) where (InLab_Paineis_EhTecido o produto id:g[1]) collect g[1]
            corpo = (InLab_Cortar_Corpo o tec)[1]
        )
        else
        (
            local todas = #{1..(polyop.getNumFaces po)}
            corpo = copy todas
            for el in (InLab_Paineis_Elementos po todas) do if (InLab_Paineis_EhVivo o el)[1] do corpo -= el
        )
        local pn = InLab_Cortar_Paineis o corpo costuras
        local nP = pn.paineis.count
        local regDe = #()
        regDe.count = polyop.getNumFaces po
        for i = 1 to nP do for f in pn.paineis[i] do regDe[f] = i
        -- guias da seleção
        local bordas = costuras + pn.cortesAuto
        local cand = sel - bordas
        local recusadas = if (costuras - sel).isEmpty then #{} else (sel * bordas)
        if not recusadas.isEmpty do
            InLab_Log (o.name + ": " + recusadas.numberSet as string + " aresta(s) de costura (ou do corte do anel) na seleção, ignorada(s): a guia é uma aresta de dentro do painel.") tipo:#warn
        local guiaDe = #()
        guiaDe.count = nP
        local fora = 0
        for e in cand do
        (
            local ps = InLab_Cortar_PaineisDaAresta po regDe e
            if ps.count == 0 then fora += 1
            else
                for i in ps do
                (
                    if guiaDe[i] == undefined then guiaDe[i] = e
                    else InLab_Log (o.name + ": painel " + i as string + " tem mais de uma guia na seleção; vale a primeira (aresta " + guiaDe[i] as string + ").") tipo:#warn
                )
        )
        if fora > 0 do
            InLab_Log (o.name + ": " + fora as string + " aresta(s) da seleção fora dos painéis de tecido, ignorada(s).") tipo:#warn
        local alvos = for i = 1 to nP where guiaDe[i] != undefined collect i
        if alvos.count == 0 then
        (
            if recusadas.isEmpty and fora == 0 do
                InLab_Log (o.name + ": selecione uma aresta-guia dentro do painel (uma por painel).") tipo:#warn
            polyop.setEdgeSelection po costuras
        )
        else
        (
            -- UV atual dos painéis com guia, com vértices de mapa próprios por painel
            local sinal = InLab_Paineis_Sinal o
            local faces = #{}
            for i in alvos do faces += pn.paineis[i]
            local posM = InLab_Paineis_PosMundo o faces
            local uvs = #(), mapa = #()
            for i in alvos do
            (
                local novoDe = #()
                local sub = #()
                for f in pn.paineis[i] do
                (
                    local ids = #()
                    for mv in (polyop.getMapFace po 1 f) do
                    (
                        if novoDe[mv] == undefined do ( append uvs (polyop.getMapVert po 1 mv); novoDe[mv] = uvs.count )
                        append ids novoDe[mv]
                    )
                    local ent = #(f, ids)
                    append sub ent
                    append mapa ent
                )
                local dir = InLab_Cortar_DirRef o po posM pn.paineis[i] pn.aneis[i] #(guiaDe[i], angulo)
                local medir = if pn.aneis[i] then InLab_Cortar_MedirAnel po posM pn.paineis[i] sub guiaDe[i] sinal else undefined
                InLab_Cortar_Orientar o po posM uvs sub dir medir:medir
            )
            -- guias guardadas: guia nova no painel troca a antiga
            local nE = polyop.getNumEdges po
            local novas = #()
            for g in marcas.guias do
            (
                local ps = if g[1] != undefined and g[1] >= 1 and g[1] <= nE then InLab_Cortar_PaineisDaAresta po regDe g[1] else #()
                local trocada = false
                for i in ps where guiaDe[i] != undefined do trocada = true
                if not trocada do append novas g
            )
            for i in alvos do append novas #(guiaDe[i], angulo)
            undo "InLab Sentido" on
            (
                local orig = InLab_Cortar_TrocarBase o
                if InLab_Mapear_Gravar o uvs mapa then
                (
                    InLab_Cortar_GravarMarcas o (InLab_CortarMarcas costuras:costuras guias:novas)
                    polyop.setEdgeSelection o.baseobject costuras
                    n = alvos.count
                )
                else
                (
                    InLab_Cortar_PorBase o orig
                    InLab_Log (o.name + ": sentido não gravado; peça como estava.") tipo:#warn
                )
            )
            if n > 0 do InLab_Log (o.name + ": sentido de " + n as string + " painel(is) ajustado.") tipo:#ok
        )
    )
    catch ( InLab_Log (o.name + ": erro inesperado no Sentido (" + getCurrentException() + ").") tipo:#err; n = 0 )
    n
)
