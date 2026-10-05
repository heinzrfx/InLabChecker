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
   - V-08 é advertência: fundo aberto e faces escondidas apagadas pelo passo
     3 da Otimização são furos legítimos (Puff Dorset: 88 por peça).
   - Volume com sinal só em elemento fechado (sem aresta aberta). Medido no
     snapshot (mundo): espelho muda o sinal, mas a V-12 já pega escala
     negativa.
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
    erro = undefined        -- texto da exceção, se a análise falhou
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
    local restantes = #{1..m.numfaces}
    local avesso = 0
    while not restantes.isEmpty do
    (
        local f0 = 0
        for f in restantes while f0 == 0 do f0 = f
        local elem = meshop.getElementsUsingFace m #{f0}
        restantes -= elem
        if ((meshop.getEdgesUsingFace m elem) * abertas).isEmpty do
        (
            local vol = 0.0
            for f in elem do
            (
                local v = getFace m f
                vol += dot (getVert m v.x) (cross (getVert m v.y) (getVert m v.z))
            )
            if vol < -1e-6 do avesso += 1
        )
    )
    avesso
)

-- V-09a: faces cujos 3 cantos coincidem (na tolerância) com os de outra face
-- do mesmo objeto, em qualquer ordem — no mesmo sentido ou costas com costas.
-- Centro quantizado por eixo; sort nativo de (qx − qxMin)·(nf+1) + f
-- (double, positiva); só as faces com o mesmo qx são comparadas entre si.
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
        local qxMin = q[1][1]
        for f = 2 to nf where q[f][1] < qxMin do qxMin = q[f][1]
        local base = (nf + 1) as double
        local chaves = for f = 1 to nf collect ((q[f][1] - qxMin) * base + f)
        sort chaves
        -- cantos quantizados e ordenados, como texto (só para as faces de um grupo)
        fn cantos m f tol =
        (
            local v = getFace m f
            local ps = for i in #(v.x, v.y, v.z) collect (local p = getVert m i; (floor (p.x / tol + 0.5)) as string + "," + (floor (p.y / tol + 0.5)) as string + "," + (floor (p.z / tol + 0.5)) as string)
            sort ps
            ps[1] + "|" + ps[2] + "|" + ps[3]
        )
        local dup = #{}
        local i = 1
        while i <= nf do
        (
            local qi = floor (chaves[i] / base)
            local j = i
            while j < nf and (floor (chaves[j + 1] / base)) == qi do j += 1
            if j > i do
            (
                local fs = for k = i to j collect ((chaves[k] - qi * base) as integer)
                for x = 1 to fs.count do
                    for y = x + 1 to fs.count do
                    (
                        local fa = fs[x]; local fb = fs[y]
                        if q[fa][2] == q[fb][2] and q[fa][3] == q[fb][3] and (cantos m fa tol) == (cantos m fb tol) do ( dup[fa] = true; dup[fb] = true )
                    )
            )
            i = j + 1
        )
        dup.numberSet
    )
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
            a.avesso = InLab_Malha_ElementosDoAvesso m abertas
            a.duplicadas = InLab_Malha_FacesDuplicadas m tol
        )
    )
    catch
    (
        a.erro = getCurrentException()
        InLab_Log (o.name + ": falha na análise de malha (" + a.erro + ").") tipo:#err
    )
    delete m
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
