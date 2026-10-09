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
   - REVISÃO FINAL (05/10/2026):
       * V-10b: volume por elemento com âncora (1º vértice) subtraída antes do
         produto misto e decisão relativa (avesso só se vol < -1e-4·d³, d =
         2·raio do elemento a partir da âncora, >= diagonal do bbox; abaixo
         disso é indeterminado). Antes o
         limite absoluto de 1e-6 em float32 podia reprovar peça pequena longe
         da origem (não reproduzido em cubo de 0,3 cm, mantido por robustez).
       * V-10a: a contagem também pega face repetida no mesmo sentido e aresta
         com 3+ faces (mensagem diz isso).
       * V-09a: LIMITAÇÃO DE QUANTIZAÇÃO — dois pontos a menos de 0,01 mm, mas
         em lados opostos da fronteira de uma célula, caem em células
         diferentes e escapam; duplicatas exatas não são afetadas.
       * V-07: objeto que vai pro GLB sem nó de mesmo nome no glTF vira aviso
         ("N objeto(s) não medido(s)") e impede o "passou" limpo. Temporários
         apagados também nas subpastas (o MaxScript não remove diretório).
       * V-13: mensagem traz o maior ângulo com vizinha de mesmo smoothing bit.
 06/10/2026 — V-13 de 15° para 45° (decisão do usuário): o TAMPO do Aparador
   Zucchi (ngon plana de 1605 lados suavizada junto com o chanfro a 27°)
   reprovava. Por enquanto não reprova: 45° deixa passar chanfro comum e
   continua pegando quina viva suavizada (90°). Se o GLB mostrar faixas no
   sombreamento ou perda de otimização, rever o limite e decidir se vira aviso
   ou reprovação (INLAB_MALHA_CURVA_GRAUS).
 06/10/2026 — DESEMPENHO medido de novo (Max 2024, mesmo Teapot de 262 mil
   triângulos): o union-find por ARESTA da V-10b (commit 50c1d78) levou a
   etapa de 2,7 s para 6,5 s e a análise inteira de 11 s para ~15,4 s. O
   "Teapot 11 s" registrado naquele commit era da versão por vértice. O teto
   do teste (15 s) ficou no limite e falhava de forma intermitente; subiu
   para 20 s. Custo por etapa hoje: arestas invertidas 2,7 s, elementos do
   avesso 6,5 s, faces duplicadas 5,6 s.
 09/10/2026 (issue #112) — V-10a e V-10b numa ordenação só
   (InLab_Malha_Arestas): uma chave por (aresta sem sentido, face, sentido).
   No Teapot, as duas etapas foram de 7,5 s para 5,7 s, e a análise inteira
   levou 9,96 s; o teto do teste voltou a 15 s. Testado e descartado: chave
   double, bit.shift/bit.and, getElementsUsingFace (ver a função).
================================================================================
*/

global INLAB_MALHA_TOL_MM = 0.01          -- tolerância de posição, em milímetros
global INLAB_MALHA_PLANO_GRAUS = 1.0       -- V-13: ngon não plana
global INLAB_MALHA_CURVA_GRAUS = 45.0      -- V-13: vizinha suavizada em curva (era 15°, ver cabeçalho 06/10/2026)
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
    curvaMaxGraus = 0.0,    -- V-13: maior ângulo achado com vizinha de mesmo smoothing bit
    ngonsAplica = false,    -- V-13: Editable_Poly com stack vazio
    erro = undefined,       -- texto da exceção, se a análise falhou
    erroNgons = undefined,  -- falha na leitura das ngons (só V-13; não invalida as demais)
    erroAvesso = undefined  -- V-10b não medida (só V-10; não invalida as demais)
)

-- V-10a: quantas arestas (de todas as faces) têm uma gêmea no MESMO sentido
-- (vizinhas com sentido oposto). Em malha consistente cada aresta dirigida a→b
-- aparece uma vez. Sort nativo sobre doubles, sem Dictionary.
-- (ver cabeçalho, 05/10/2026). Desde a #112 a análise usa InLab_Malha_Arestas
-- (V-10a + V-10b juntas); esta fica para malha que não cabe na chave dela.
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

-- V-10a + V-10b numa ordenação só (09/10/2026, issue #112). Devolve
-- #(invertidas, avesso):
--   invertidas (V-10a): arestas dirigidas que aparecem mais de uma vez no
--     mesmo sentido (mesma regra de InLab_Malha_ArestasInvertidas);
--   avesso (V-10b): elementos FECHADOS (nenhuma aresta aberta) com volume
--     negativo.
-- Elementos por conectividade de ARESTA (duas faces no mesmo elemento só se
-- dividem uma aresta), como meshop.getElementsUsingFace: dois cubos soldados
-- num só vértice são dois elementos (unir por vértice somaria os volumes e
-- esconderia o cubo do avesso). Histórico: getElementsUsingFace por elemento
-- levava 22 s no Teapot de 262 mil triângulos (41 ms por chamada, e as faces
-- degeneradas dos polos viram centenas de "elementos"); o union-find por
-- aresta (05/10/2026) levou a 6,5 s, mais 2,7 s da ordenação própria da
-- V-10a. #112: UMA chave integer64 por (aresta sem sentido, face, sentido) =
-- aresta · 2nf + 2(face − 1) + sentido, ordenada com sort nativo. Na mesma
-- passada: faces da mesma aresta se unem (V-10b) e, dentro de cada aresta,
-- cada sentido com 2 ou mais ocorrências conta como invertida (V-10a).
-- Teapot 262 mil: V-10a + V-10b de 7,5 s para 5,7 s. Testado e descartado:
-- chave double (mais lenta), bit.shift/bit.and no lugar da divisão (0,27 s
-- contra 0,17 s em 786 mil), getElementsUsingFace (acima).
-- Cabe até nv² · 2nf ~ 9,2e18; passando disso lança erro (quem chama mede a
-- V-10a pela função própria e a V-10b vira "não medido"), nunca aproxima.
fn InLab_Malha_Arestas m abertas =
(
    local nf = m.numfaces
    local nv = m.numverts
    local base = (nv + 1) as integer64
    local nf2 = (2 * nf) as integer64
    if ((nv + 1) as double) * ((nv + 1) as double) * (2.0 * nf) >= 9.0e18 do
        throw ("malha grande demais para a V-10b (" + nv as string + " vértices, " + nf as string + " faces)")
    local fv = #()
    fv.count = nf
    local pai = #()
    pai.count = nf
    local chaves = #()
    for f = 1 to nf do
    (
        local v = getFace m f
        fv[f] = v
        pai[f] = f
        local a = (v.x as integer) as integer64
        local b = (v.y as integer) as integer64
        local c = (v.z as integer) as integer64
        local fk = (2 * (f - 1)) as integer64
        append chaves ((if a < b then a * base + b else b * base + a) * nf2 + fk + (if a < b then 0L else 1L))
        append chaves ((if b < c then b * base + c else c * base + b) * nf2 + fk + (if b < c then 0L else 1L))
        append chaves ((if c < a then c * base + a else a * base + c) * nf2 + fk + (if c < a then 0L else 1L))
    )
    sort chaves
    local invertidas = 0
    local anterior = -1L
    local fAnt = 0
    local c0 = 0, c1 = 0
    for k in chaves do
    (
        local aresta = k / nf2
        local r = (k - aresta * nf2) as integer
        local fa = r / 2 + 1
        if aresta == anterior then
        (
            local ra = fa, rb = fAnt
            while pai[ra] != ra do ( pai[ra] = pai[pai[ra]]; ra = pai[ra] )
            while pai[rb] != rb do ( pai[rb] = pai[pai[rb]]; rb = pai[rb] )
            if ra != rb do pai[ra] = rb
        )
        else
        (
            if c0 >= 2 do invertidas += c0
            if c1 >= 2 do invertidas += c1
            c0 = 0
            c1 = 0
        )
        if (mod r 2) == 0 then c0 += 1 else c1 += 1
        anterior = aresta
        fAnt = fa
    )
    if c0 >= 2 do invertidas += c0
    if c1 >= 2 do invertidas += c1
    -- pai[f] = raiz, uma vez
    for f = 1 to nf do
    (
        local x = f
        while pai[x] != x do x = pai[x]
        pai[f] = x
    )
    -- Robustez (05/10/2026): ponto float32 longe da origem perde precisão no
    -- produto misto. Cada elemento subtrai uma âncora (1º vértice da 1ª face
    -- vista) antes do cross e acumula o raio máximo a partir dela; a decisão é
    -- relativa (d = 2·raio, que cobre a diagonal do bbox, sem custo de bbox).
    local vs = for i = 1 to nv collect getVert m i
    local vol = #(); vol.count = nf
    local anc = #(); anc.count = nf
    local mn = #(); mn.count = nf   -- raio máximo (distância à âncora) por elemento
    for f = 1 to nf do
    (
        local v = fv[f]
        local e = pai[f]
        local p1 = vs[v.x], p2 = vs[v.y], p3 = vs[v.z]
        if anc[e] == undefined do ( anc[e] = p1; mn[e] = 0.0; vol[e] = 0.0 )
        local o = anc[e]
        local q1 = p1 - o, q2 = p2 - o, q3 = p3 - o
        local rr = amax (length q1) (length q2) (length q3)
        if rr > mn[e] do mn[e] = rr
        vol[e] += dot q1 (cross q2 q3)
    )
    local aberto = #{}
    for e in abertas do aberto[pai[(e - 1) / 3 + 1]] = true
    local avesso = 0
    for f = 1 to nf where pai[f] == f and not aberto[f] do
    (
        local d = 2.0 * mn[f]   -- mn[f] = raio máximo a partir da âncora
        -- |vol| abaixo de 1e-4·d³ é indeterminado (não conta como avesso)
        if vol[f] < -(1e-4 * d * d * d) do avesso += 1
    )
    #(invertidas, avesso)
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
-- de INLAB_MALHA_CURVA_GRAUS (45°). Tampa de cilindro (plana, smoothing próprio) passa.
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
                local anguloMax = 0.0   -- maior ângulo com vizinha que divide bit de smoothing
                if sg != 0 do
                    for g in (polyop.getFacesUsingEdge o (polyop.getEdgesUsingFace o #{f})) do
                        if g != f and (bit.and sg (polyop.getFaceSmoothGroup o g)) != 0 do
                        (
                            local cs = dot n (polyop.getFaceNormal o g)
                            if cs < cosCurva do naCurva = true
                            local ang = acos (amax -1.0 (amin 1.0 cs))
                            if ang > anguloMax do anguloMax = ang
                        )
                if naCurva do a.ngonsNaCurva += 1
                if anguloMax > a.curvaMaxGraus do a.curvaMaxGraus = anguloMax
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
    local m = undefined
    try
    (
        m = snapshotAsMesh o
        a.tris = m.numfaces
        if a.tris > 0 do
        (
            local abertas = meshop.getOpenEdges m
            a.furos = abertas.numberSet
            -- #112: V-10a e V-10b numa ordenação só. Se a malha não cabe na
            -- chave, a V-10a é medida à parte e a V-10b fica "não medida".
            try
            (
                local ar = InLab_Malha_Arestas m abertas
                a.invertidas = ar[1]
                a.avesso = ar[2]
            )
            catch
            (
                a.erroAvesso = getCurrentException()
                InLab_Log (o.name + ": V-10b não medida (" + a.erroAvesso + ").") tipo:#warn
                a.invertidas = InLab_Malha_ArestasInvertidas m
            )
            a.duplicadas = InLab_Malha_FacesDuplicadas m tol
        )
    )
    catch
    (
        a.erro = getCurrentException()
        InLab_Log (o.name + ": falha na análise de malha (" + a.erro + ").") tipo:#err
    )
    if m != undefined do try ( delete m ) catch ()
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
        (if itens.count == 0 then "nenhuma aresta aberta" else ("confira se o furo é de propósito (fundo aberto, faces escondidas): " + InLab_ListaResumida itens)) critico:false
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
        if a.invertidas > 0 do append itens ((InLab_Malha_Nome a) + ": " + (a.invertidas / 2) as string + " aresta(s) entre faces de sentido oposto (ou face repetida / aresta com 3+ faces)")
        if a.avesso > 0 do append itens ((InLab_Malha_Nome a) + ": " + a.avesso as string + " parte(s) do avesso (normais para dentro)")
    )
    if itens.count > 0 then
        InLab_RegistrarVerif "V-10" "Normais invertidas" false (InLab_ListaResumida (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-10" "Normais invertidas" false ("não medido: " + InLab_ListaResumida naoMedidos) critico:false
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
        InLab_RegistrarVerif "V-09" "Faces e objetos duplicados" false (InLab_ListaResumida (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-09" "Faces e objetos duplicados" false ("não medido: " + InLab_ListaResumida naoMedidos) critico:false
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
        if a.ngonsNaCurva > 0 do append itens ((InLab_Malha_Nome a) + ": " + a.ngonsNaCurva as string + " ngon(s) suavizada(s) numa curva (vizinha a " + (formattedPrint a.curvaMaxGraus format:".0f") + "°)")
    )
    if itens.count > 0 then
        InLab_RegistrarVerif "V-13" "Ngons em superfície curva" false (InLab_ListaResumida (itens + naoMedidos)) critico:true
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif "V-13" "Ngons em superfície curva" false ("não medido: " + InLab_ListaResumida naoMedidos) critico:false
    else
    (
        local semPoly = for a in analises where not a.ngonsAplica collect a.no.name
        local msg = if semPoly.count == analises.count then "não se aplica: nenhum objeto em Editable Poly com stack vazio" \
            else ("nenhuma ngon em superfície curva" + (if semPoly.count > 0 then (" · não se aplica a " + InLab_ListaResumida semPoly) else ""))
        InLab_RegistrarVerif "V-13" "Ngons em superfície curva" true msg critico:true
    )
)

-- Apaga os arquivos de `pasta` e de todas as subpastas. O MaxScript não tem API
-- para remover diretório: as pastas vazias ficam (só os arquivos saem).
fn InLab_Malha_LimparPasta pasta =
(
    for d in (getDirectories (pasta + "*")) do InLab_Malha_LimparPasta d
    for f in (getFiles (pasta + "*")) do
        if not (deleteFile f) do InLab_Log ("V-07: não consegui apagar o temporário " + f) tipo:#warn
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
        InLab_Malha_LimparPasta pasta
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
        -- Objeto que vai pro GLB mas sem nó de mesmo nome no glTF: não medido (aviso).
        local semNo = #()
        for o in objetos where (InLab_VaiProGLB o) and (findItem r[2] o.name) == 0 do append semNo o.name
        local txtSemNo = ""
        if semNo.count > 0 do
        (
            txtSemNo = semNo.count as string + " objeto(s) não medido(s): " + (InLab_ListaResumida semNo)
            InLab_Log ("V-07: " + txtSemNo + " (sem nó de mesmo nome no glTF).") tipo:#warn
        )
        if medidos == 0 then
            InLab_RegistrarVerif "V-07" titulo false ("não medido: " + (if semNo.count > 0 then txtSemNo else "nenhum objeto da cena saiu no glTF")) critico:false
        else if acima.count == 0 and semNo.count > 0 then
            InLab_RegistrarVerif "V-07" titulo false ("nenhum acima do limite, mas " + txtSemNo) critico:false
        else
            InLab_RegistrarVerif "V-07" titulo (acima.count == 0) \
                ((if acima.count == 0 then ("maior " + (formattedPrint maior format:".2f")) else InLab_ListaResumida acima) + " · limite " + cfg.maxRatioVT as string \
                    + (if semNo.count > 0 then (" · " + txtSemNo) else "")) \
                critico:true provisorio:true
    )
)
