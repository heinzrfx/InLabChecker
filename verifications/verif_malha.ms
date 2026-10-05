/*
================================================================================
 verifications\verif_malha.ms — Grupo 6 · V-07, V-08, V-09, V-10, V-13
--------------------------------------------------------------------------------
 Spec: docs\superpowers\specs\2026-10-05-verif-geometria-grupo6-design.md
 (issue #102). Só leitura: nada muda na cena.

 ANÁLISE POR PEÇA: InLab_Malha_Analisar tira UM snapshotAsMesh e preenche
 uma MalhaAnalise (furos, vizinhas invertidas, elementos do avesso, faces
 duplicadas); a V-13 lê o Editable Poly direto. InLab_Malha_AnalisarCena
 roda uma análise por grupo de instâncias (InLab_DeduplicarInstancias).

 05/10/2026 — decisões da sondagem (Max 2024):
   - TOLERÂNCIA: units.decodeValue "0.01mm" devolve 0.0 com separador decimal
     em vírgula (pt-BR; "0.5mm" idem; "1mm" funciona). A tolerância agora é
     INLAB_MALHA_TOL_MM * decodeValue "1mm" (InLab_Malha_Tolerancia).
   - SEM Dictionary em laço: como mapa de arestas levou 565 s numa malha de
     262 mil triângulos, e a chave inteira estourou. Duplicata e únicos saem
     de sort nativo sobre doubles (chave positiva, < 2^53).
   - CORREÇÃO (sondagem na implementação, Max 2024): meshop.getOpenEdges NÃO
     lista a aresta cujas duas faces vizinhas têm o MESMO sentido (Box com
     meshop.flipNormals #{1} -> abertas = #{}). Então a V-10a olha as arestas
     dirigidas de TODAS as faces (a→b repetida = sentido oposto) e a V-08 usa
     só getOpenEdges (furo de verdade). Limitação: faces duplicadas com o
     mesmo sentido também aparecem na V-10a (a V-09 as reporta à parte).
   - V-07 (implementação): exportador GLTF_Export grava nodes[].name = nome do
     objeto no Max; Sphere radius:20 segs:32 smooth:false exportou 2875 v /
     960 t (ratio 2.99; a sondagem anterior media 2879). Exporta a cena
     inteira (ignora selectedOnly) numa pasta temporária apagada em seguida.
   - V-08 é advertência: fundo aberto e faces escondidas apagadas pelo passo
     3 da Otimização são furos legítimos (Puff Dorset: 88 por peça).
   - Volume com sinal só em elemento fechado (sem aresta aberta). Medido no
     snapshot (mundo): espelho muda o sinal, mas a V-12 já pega escala
     negativa.
   - PILOTO (Aparador Zucchi): V-13 reprova o TAMPO (1 ngon suavizada numa
     curva). É uma tampa plana de 1605 lados cujas 1605 vizinhas dividem o
     smoothing group a 26,6°. Mantido por decisão do controller: a tampa
     triangula em fatias longas e o sombreado listra. Não é falso positivo.
   - DESEMPENHO: V-10b trocou meshop.getElementsUsingFace por elemento
     (O(faces) cada; 22 s no Teapot de 262 mil) por union-find nas faces,
     unidas por ARESTA comum (chave integer64 ordenada com sort nativo).
     Sondagem: dois cubos soldados num vértice são 2 elementos no Max (12 de
     24 faces); unir por vértice os fundia e escondia o cubo do avesso (teste
     em test_verif_malha.ms). Sem aproximação: se a chave não coubesse
     (nv² · nf >= 9e18, impossível na prática) a V-10 vira "não medido".
================================================================================
*/

global INLAB_MALHA_TOL_MM = 0.01          -- tolerância de posição, em milímetros
global INLAB_MALHA_PLANO_GRAUS = 1.0       -- V-13: ngon não plana
global INLAB_MALHA_CURVA_GRAUS = 15.0      -- V-13: vizinha suavizada em curva
global INLAB_MALHA_LOG_TRIS = 50000        -- loga o tempo das peças a partir disso

-- Tolerância de posição em unidades da cena. Não usar units.decodeValue "0.01mm":
-- com separador decimal em vírgula (pt-BR) devolve 0.0 e a V-09 estoura.
fn InLab_Malha_Tolerancia = ( INLAB_MALHA_TOL_MM * (units.decodeValue "1mm") )

struct MalhaAnalise
(
    no,                     -- nó representante do grupo de instâncias
    instancias = #(),       -- todos os nós do grupo
    tris = 0,
    furos = 0,              -- V-08: arestas abertas (meshop.getOpenEdges)
    invertidas = 0,         -- V-10a: arestas dirigidas repetidas (vizinhas de sentido oposto)
    avesso = 0,             -- V-10b: elementos fechados com volume negativo
    duplicadas = 0,         -- V-09a: faces coincidentes com outra
    ngonsNaoPlanas = 0,     -- V-13
    ngonsNaCurva = 0,       -- V-13
    ngonsAplica = false,    -- V-13: Editable_Poly com stack vazio
    erro = undefined,       -- texto da exceção, se a análise falhou
    erroNgons = undefined,  -- falha na leitura das ngons (só V-13; não invalida as demais)
    erroAvesso = undefined  -- V-10b não medida (só V-10; não invalida as demais)
)

-- "a, b, c" com no máximo `maximo` itens e "… (+N)" no fim.
fn InLab_Malha_Lista itens maximo:8 =
(
    local txt = ""
    for i = 1 to (amin itens.count maximo) do txt += (if i > 1 then "; " else "") + itens[i]
    if itens.count > maximo do txt += "; … (+" + (itens.count - maximo) as string + ")"
    txt
)

-- V-10a: quantas arestas (de todas as faces) têm uma gêmea no MESMO sentido
-- (vizinhas com sentido oposto). Em malha consistente cada aresta dirigida a→b
-- aparece uma vez. Sort nativo sobre doubles, sem Dictionary.
-- (ver cabeçalho, 05/10/2026).
fn InLab_Malha_ArestasInvertidas m =
(
    local base = (m.numverts + 1) as double
    local chaves = #()
    for f = 1 to m.numfaces do
    (
        local v = getFace m f
        local a = v.x as integer
        local b = v.y as integer
        local c = v.z as integer
        append chaves ((a as double) * base + (b as double))
        append chaves ((b as double) * base + (c as double))
        append chaves ((c as double) * base + (a as double))
    )
    sort chaves
    local n = 0
    for i = 1 to chaves.count do
        if (i > 1 and chaves[i] == chaves[i - 1]) or (i < chaves.count and chaves[i] == chaves[i + 1]) do n += 1
    n
)

-- V-10b: elementos FECHADOS (nenhuma aresta aberta) com volume negativo.
fn InLab_Malha_ElementosDoAvesso m abertas =
(
    -- Perf (05/10/2026): meshop.getElementsUsingFace custa O(faces) por chamada e
    -- o Teapot de 262 mil triângulos tem centenas de elementos (22 s). Agora um
    -- union-find sobre as FACES dá o elemento de cada uma; o volume e a
    -- "abertura" são somados por elemento. Mesma semântica: só elemento sem
    -- aresta aberta entra no teste de volume.
    -- Conectividade por ARESTA (duas faces no mesmo elemento só se dividem uma
    -- aresta), como meshop.getElementsUsingFace: dois cubos soldados num só
    -- vértice são dois elementos (unir por vértice somaria os volumes e
    -- esconderia o cubo do avesso). Sem Dictionary: chave integer64 =
    -- (aresta sem sentido) * nf + (face - 1), ordenada com sort nativo (sort de
    -- integer64 mede 0,6 s em 786 mil chaves). Cabe até nv² · nf ~ 9,2e18, muito
    -- além de qualquer produto; passando disso lança erro (a análise loga e a
    -- V-10 vira "não medido"), nunca aproxima.
    local nf = m.numfaces
    local nv = m.numverts
    local base = (nv + 1) as integer64
    local nf64 = nf as integer64
    if ((nv + 1) as double) * ((nv + 1) as double) * (nf as double) >= 9.0e18 do
        throw ("malha grande demais para a V-10b (" + nv as string + " vértices, " + nf as string + " faces)")
    fn raiz pai i =
    (
        while pai[i] != i do ( pai[i] = pai[pai[i]]; i = pai[i] )
        i
    )
    local fv = #()
    fv.count = nf
    for f = 1 to nf do fv[f] = getFace m f
    local pai = #()
    pai.count = nf
    for f = 1 to nf do pai[f] = f
    local chaves = #()
    for f = 1 to nf do
    (
        local v = fv[f]
        local a = (v.x as integer) as integer64
        local b = (v.y as integer) as integer64
        local c = (v.z as integer) as integer64
        local fk = (f - 1) as integer64
        append chaves (((amin a b) * base + (amax a b)) * nf64 + fk)
        append chaves (((amin b c) * base + (amax b c)) * nf64 + fk)
        append chaves (((amin c a) * base + (amax c a)) * nf64 + fk)
    )
    sort chaves
    local anterior = -1L
    local fAnt = 0
    for k in chaves do
    (
        local aresta = k / nf64
        local fa = ((k - aresta * nf64) as integer) + 1
        if aresta == anterior do
        (
            local ra = raiz pai fa
            local rb = raiz pai fAnt
            if ra != rb do pai[ra] = rb
        )
        anterior = aresta
        fAnt = fa
    )
    local vol = #()
    vol.count = nf
    for f = 1 to nf do vol[f] = 0.0
    for f = 1 to nf do
    (
        local v = fv[f]
        local r = raiz pai f
        vol[r] += dot (getVert m v.x) (cross (getVert m v.y) (getVert m v.z))
    )
    local aberto = #{}
    for e in abertas do aberto[raiz pai ((e - 1) / 3 + 1)] = true
    local avesso = 0
    for f = 1 to nf do
        if pai[f] == f do
            if not aberto[f] and vol[f] < -1e-6 do avesso += 1
    avesso
)

-- Agrupa as faces de `lista` pelo valor quantizado do eixo `eixo` de q[f]
-- (q[f] = #(qx, qy, qz)). Sort nativo de (qv − qvMin)·(k+1) + posição (double,
-- positiva), sem Dictionary. Devolve só os grupos com 2 faces ou mais.
fn InLab_Malha_AgruparPorEixo lista q eixo =
(
    local k = lista.count
    local grupos = #()
    if k >= 2 do
    (
        local qMin = q[lista[1]][eixo]
        for f in lista where q[f][eixo] < qMin do qMin = q[f][eixo]
        local base = (k + 1) as double
        local chaves = for idx = 1 to k collect ((q[lista[idx]][eixo] - qMin) * base + idx)
        sort chaves
        local i = 1
        while i <= k do
        (
            local qi = floor (chaves[i] / base)
            local j = i
            while j < k and (floor (chaves[j + 1] / base)) == qi do j += 1
            if j > i do append grupos (for x = i to j collect lista[(chaves[x] - qi * base) as integer])
            i = j + 1
        )
    )
    grupos
)

-- V-09a: faces cujos 3 cantos coincidem (na tolerância) com os de outra face
-- do mesmo objeto, em qualquer ordem — no mesmo sentido ou costas com costas.
-- Centro quantizado por eixo; agrupa por qx e depois, dentro de cada grupo, por
-- qy (dois sorts nativos): painel de lado, com milhares de faces no mesmo qx,
-- não vira k² comparações. Só dentro de (qx, qy) iguais confere qz e cantos.
fn InLab_Malha_FacesDuplicadas m tol =
(
    local nf = m.numfaces
    if nf < 2 then 0
    else
    (
        local q = for f = 1 to nf collect
        (
            local c = meshop.getFaceCenter m f
            #(floor ((c.x as double) / tol + 0.5), floor ((c.y as double) / tol + 0.5), floor ((c.z as double) / tol + 0.5))
        )
        -- cantos quantizados e ordenados, como texto (só para as faces de um grupo)
        fn cantos m f tol =
        (
            local v = getFace m f
            local ps = for i in #(v.x, v.y, v.z) collect (local p = getVert m i; (floor (p.x / tol + 0.5)) as string + "," + (floor (p.y / tol + 0.5)) as string + "," + (floor (p.z / tol + 0.5)) as string)
            sort ps
            ps[1] + "|" + ps[2] + "|" + ps[3]
        )
        local dup = #{}
        for gx in (InLab_Malha_AgruparPorEixo (#{1..nf} as array) q 1) do
            for fs in (InLab_Malha_AgruparPorEixo gx q 2) do
                for x = 1 to fs.count do
                    for y = x + 1 to fs.count do
                    (
                        local fa = fs[x]
                        local fb = fs[y]
                        if q[fa][3] == q[fb][3] and (cantos m fa tol) == (cantos m fb tol) do ( dup[fa] = true; dup[fb] = true )
                    )
        dup.numberSet
    )
)

-- V-13: ngons (5+ lados) do Editable Poly de stack vazio. Não plana = maior
-- distância de um vértice ao plano da face ÷ maior distância ao centro >
-- tan 1°. Suavizada na curva = divide smoothing group com uma vizinha a mais
-- de 15°. Tampa de cilindro (plana, smoothing próprio) passa.
fn InLab_Malha_Ngons o a =
(
    if classof o.baseobject == Editable_Poly and o.modifiers.count == 0 do
    (
        a.ngonsAplica = true
        local tanPlano = tan INLAB_MALHA_PLANO_GRAUS
        local cosCurva = cos INLAB_MALHA_CURVA_GRAUS
        for f = 1 to (polyop.getNumFaces o) where (polyop.getFaceDeg o f) > 4 do
        (
            local n = polyop.getFaceNormal o f
            local c = polyop.getFaceCenter o f
            local desvio = 0.0
            local raio = 0.0
            for v in (polyop.getFaceVerts o f) do
            (
                local p = polyop.getVert o v
                desvio = amax desvio (abs (dot (p - c) n))
                raio = amax raio (distance p c)
            )
            if raio > 0 and desvio / raio > tanPlano then a.ngonsNaoPlanas += 1
            else
            (
                local sg = polyop.getFaceSmoothGroup o f
                local naCurva = false
                if sg != 0 do
                    for g in (polyop.getFacesUsingEdge o (polyop.getEdgesUsingFace o #{f})) do
                        if not naCurva and g != f and (bit.and sg (polyop.getFaceSmoothGroup o g)) != 0 and (dot n (polyop.getFaceNormal o g)) < cosCurva do
                            naCurva = true
                if naCurva do a.ngonsNaCurva += 1
            )
        )
    )
    a
)

-- Análise de UMA peça. tol: tolerância de posição em unidades da cena.
fn InLab_Malha_Analisar o tol:undefined =
(
    if tol == undefined do tol = InLab_Malha_Tolerancia()
    local a = MalhaAnalise no:o instancias:(InLab_InstanciasDoNo o)
    local m = snapshotAsMesh o
    try
    (
        a.tris = m.numfaces
        if a.tris > 0 do
        (
            local abertas = meshop.getOpenEdges m
            a.invertidas = InLab_Malha_ArestasInvertidas m
            a.furos = abertas.numberSet
            try ( a.avesso = InLab_Malha_ElementosDoAvesso m abertas ) catch
            (
                a.erroAvesso = getCurrentException()
                InLab_Log (o.name + ": V-10b não medida (" + a.erroAvesso + ").") tipo:#warn
            )
            a.duplicadas = InLab_Malha_FacesDuplicadas m tol
        )
    )
    catch
    (
        a.erro = getCurrentException()
        InLab_Log (o.name + ": falha na análise de malha (" + a.erro + ").") tipo:#err
    )
    delete m
    try ( InLab_Malha_Ngons o a ) catch
    (
        a.erroNgons = getCurrentException()
        InLab_Log (o.name + ": falha na leitura das ngons (" + a.erroNgons + ").") tipo:#err
    )
    a
)

-- Uma análise por grupo de instâncias; loga o tempo das peças grandes.
fn InLab_Malha_AnalisarCena objs =
(
    local tol = InLab_Malha_Tolerancia()
    for g in (InLab_DeduplicarInstancias objs) collect
    (
        local t0 = timeStamp()
        local a = InLab_Malha_Analisar g.no tol:tol
        a.instancias = g.instancias
        if a.tris >= INLAB_MALHA_LOG_TRIS do
            InLab_Log (g.no.name + ": malha analisada (" + a.tris as string + " triângulos) em " + ((timeStamp() - t0) / 1000.0) as string + " s.") tipo:#info
        a
    )
)

-- Nome para o relatório: o representante e quantas instâncias vêm junto.
fn InLab_Malha_Nome a =
(
    a.no.name + (if a.instancias.count > 1 then (" (+" + (a.instancias.count - 1) as string + " instância(s))") else "")
)

-- V-08 · Malha fechada. Advertência: furo pode ser legítimo.
fn InLab_V08_MalhaFechada analises =
(
    local itens = #()
    for a in analises do
    (
        if a.erro != undefined do append itens ((InLab_Malha_Nome a) + ": não analisado (" + a.erro + ")")
        if a.furos > 0 do append itens ((InLab_Malha_Nome a) + ": " + a.furos as string + " aresta(s) aberta(s)")
    )
    InLab_RegistrarVerif "V-08" "Malha fechada (arestas abertas)" (itens.count == 0) \
        (if itens.count == 0 then "nenhuma aresta aberta" else ("confira se o furo é de propósito (fundo aberto, faces escondidas): " + InLab_Malha_Lista itens)) critico:false
)

-- V-10 · Normais invertidas: vizinhas com sentido oposto ou peça do avesso.
fn InLab_V10_Normais analises =
(
    local itens = #()
    local naoMedidos = #()
    for a in analises do
    (
        if a.erro != undefined do append naoMedidos ((InLab_Malha_Nome a) + ": não analisado (" + a.erro + ")")
        if a.erroAvesso != undefined do append naoMedidos ((InLab_Malha_Nome a) + ": elementos do avesso não medidos (" + a.erroAvesso + ")")
        if a.invertidas > 0 do append itens ((InLab_Malha_Nome a) + ": " + (a.invertidas / 2) as string + " aresta(s) entre faces de sentido oposto")
        if a.avesso > 0 do append itens ((InLab_Malha_Nome a) + ": " + a.avesso as string + " parte(s) do avesso (normais para dentro)")
    )
    if itens.count > 0 then
        InLab_RegistrarVerif "V-10" "Normais invertidas" false (InLab_Malha_Lista (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-10" "Normais invertidas" false ("não medido: " + InLab_Malha_Lista naoMedidos) critico:false
    else
        InLab_RegistrarVerif "V-10" "Normais invertidas" true "normais consistentes" critico:true
)

-- V-09 · Duplicatas: faces coincidentes no objeto, ou objeto inteiro em cima
-- de outro (mesma contagem de triângulos e mesmo bbox de mundo). Instância no
-- mesmo lugar também conta. Análise que falhou: "não medido" (não passa em silêncio).
fn InLab_V09_Duplicados analises objetos =
(
    local itens = #()
    local naoMedidos = #()
    for a in analises do
    (
        if a.erro != undefined do append naoMedidos ((InLab_Malha_Nome a) + ": não analisado (" + a.erro + ")")
        if a.duplicadas > 0 do append itens ((InLab_Malha_Nome a) + ": " + a.duplicadas as string + " face(s) coincidente(s)")
    )
    local tol = InLab_Malha_Tolerancia()
    local tris = for o in objetos collect (GetTriMeshFaceCount o)[1]
    for i = 1 to objetos.count do
        for j = i + 1 to objetos.count do
        (
            local p = objetos[i]
            local q = objetos[j]
            if tris[i] > 0 and tris[i] == tris[j] and (distance p.min q.min) <= tol and (distance p.max q.max) <= tol do
                append itens (p.name + " e " + q.name + ": objeto duplicado no mesmo lugar")
        )
    if itens.count > 0 then
        InLab_RegistrarVerif "V-09" "Faces e objetos duplicados" false (InLab_Malha_Lista (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-09" "Faces e objetos duplicados" false ("não medido: " + InLab_Malha_Lista naoMedidos) critico:false
    else
        InLab_RegistrarVerif "V-09" "Faces e objetos duplicados" true "nenhuma duplicata" critico:true
)

-- V-13 · Ngons em superfície curva (só Editable Poly de stack vazio).
-- Falha na leitura (erroNgons/erro) é "não medido", não passa em silêncio.
fn InLab_V13_Ngons analises =
(
    local itens = #()
    local naoMedidos = #()
    for a in analises do
    (
        if a.erro != undefined do append naoMedidos ((InLab_Malha_Nome a) + ": não analisado (" + a.erro + ")")
        if a.erroNgons != undefined do append naoMedidos ((InLab_Malha_Nome a) + ": não analisado (" + a.erroNgons + ")")
        if a.ngonsNaoPlanas > 0 do append itens ((InLab_Malha_Nome a) + ": " + a.ngonsNaoPlanas as string + " ngon(s) não plana(s)")
        if a.ngonsNaCurva > 0 do append itens ((InLab_Malha_Nome a) + ": " + a.ngonsNaCurva as string + " ngon(s) suavizada(s) numa curva")
    )
    if itens.count > 0 then
        InLab_RegistrarVerif "V-13" "Ngons em superfície curva" false (InLab_Malha_Lista (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-13" "Ngons em superfície curva" false ("não medido: " + InLab_Malha_Lista naoMedidos) critico:false
    else
    (
        local semPoly = for a in analises where not a.ngonsAplica collect a.no.name
        local msg = if semPoly.count == analises.count then "não se aplica: nenhum objeto em Editable Poly com stack vazio" \
            else ("nenhuma ngon em superfície curva" + (if semPoly.count > 0 then (" · não se aplica a " + InLab_Malha_Lista semPoly) else ""))
        InLab_RegistrarVerif "V-13" "Ngons em superfície curva" true msg critico:true
    )
)

-- V-07 · vértices e triângulos por nó como o GLB tem: exporta a cena inteira
-- para um .gltf temporário e lê os accessors. Na sondagem de 05/10/2026 o
-- exportador ignorou selectedOnly:true, e estimar pela malha errou de −44% a
-- +10% (normais editadas, smoothing groups que dividem bits). Exportar levou
-- 0,3–0,6 s. Devolve #(#ok, nomes, verts, tris) ou #(#naoMedido, motivo).
-- exportador: só para teste (undefined = simula "nenhum exportador").
fn InLab_GLTF_VerticesPorNo exportador:unsupplied =
(
    local cls = if exportador == unsupplied then InLab_ResolverExportadorGLTF() else exportador
    if cls == undefined then #(#naoMedido, "nenhum exportador glTF instalado")
    else
    (
        local pasta = (getDir #temp) + "\inlab_v07\\"
        makeDir pasta all:true
        local arq = pasta + "cena.gltf"
        local res = undefined
        try
        (
            local ok = exportFile arq #noPrompt selectedOnly:false using:cls
            if ok != true or not (doesFileExist arq) then res = #(#naoMedido, "o export glTF não gerou arquivo")
            else
            (
                local js = InLab_ParseJSON (InLab_JSON_LerArquivoUTF8 arq)
                local acc = InLab_JSON_Obter js "accessors"
                local meshes = InLab_JSON_Obter js "meshes"
                local nomes = #(); local verts = #(); local tris = #()
                for n in (InLab_JSON_Obter js "nodes") do
                (
                    local mi = InLab_JSON_Obter n "mesh"
                    if mi != undefined do
                    (
                        local v = 0; local t = 0
                        for p in (InLab_JSON_Obter meshes[mi + 1] "primitives") do
                        (
                            local nv = InLab_JSON_Obter acc[(InLab_JSON_Obter (InLab_JSON_Obter p "attributes") "POSITION") + 1] "count"
                            local ii = InLab_JSON_Obter p "indices"
                            v += nv
                            t += (if ii == undefined then nv else (InLab_JSON_Obter acc[ii + 1] "count")) / 3
                        )
                        local nome = (InLab_JSON_Obter n "name") as string
                        local k = findItem nomes nome
                        if k == 0 then ( append nomes nome; append verts v; append tris t )
                        else ( verts[k] += v; tris[k] += t )
                    )
                )
                res = #(#ok, nomes, verts, tris)
            )
        )
        catch ( res = #(#naoMedido, "falha no export ou na leitura do glTF: " + getCurrentException()) )
        for f in (getFiles (pasta + "*")) do deleteFile f
        res
    )
)

-- V-07 · Ratio vértices/triângulos do GLB, por objeto, contra cfg.maxRatioVT.
fn InLab_V07_RatioVT cfg objetos exportador:unsupplied =
(
    local titulo = "Ratio vértices/triângulos (GLB)"
    local r = InLab_GLTF_VerticesPorNo exportador:exportador
    if r[1] != #ok then
    (
        InLab_Log ("V-07 não medida: " + r[2]) tipo:#warn
        InLab_RegistrarVerif "V-07" titulo false ("não medido: " + r[2]) critico:false
    )
    else
    (
        local nomesObj = for o in objetos collect o.name
        local acima = #(); local maior = 0.0; local medidos = 0
        for i = 1 to r[2].count where (findItem nomesObj r[2][i]) > 0 and r[4][i] > 0 do
        (
            medidos += 1
            local ratio = r[3][i] as float / r[4][i]
            if ratio > maior do maior = ratio
            if ratio > cfg.maxRatioVT do
                append acima (r[2][i] + ": " + (formattedPrint ratio format:".2f") + " (" + r[3][i] as string + " v / " + r[4][i] as string + " t)")
        )
        if medidos == 0 then
            InLab_RegistrarVerif "V-07" titulo false "não medido: nenhum objeto da cena saiu no glTF" critico:false
        else
            InLab_RegistrarVerif "V-07" titulo (acima.count == 0) \
                ((if acima.count == 0 then ("maior " + (formattedPrint maior format:".2f")) else InLab_Malha_Lista acima) + " · limite " + cfg.maxRatioVT as string) \
                critico:true provisorio:true
    )
)
