/*
 functions\fn_mapear_medir.ms — Mapear: medição do UV do canal 1 e critério de "ruim"
 Criado em 23/10/2026 (botão Mapear, spec 2026-10-23-mapear-design.md, seções 7 e 8).

 O que faz:
   - struct MapearMedida (temCanal, escala, p10, p90, emendaVistaQuebra, espelhado,
     veioOk, veioOkV, faces, amostra, falhou). Frações de 0.0 a 1.0; escala/p10/p90 em UV/cm.
     `faces` = triângulos considerados (após `faces:`/`matID:`); `amostra` =
     quantos deles foram de fato medidos (UV não degenerado; nunca mais que INLAB_MAPEAR_MAX_AMOSTRA);
     `falhou` = true se a medição caiu numa exceção no meio (as outras medidas
     são parciais e não valem).
   - InLab_Mapear_Medir o faces:undefined matID:undefined -> MapearMedida. Mede o
     canal 1 do nó avaliado (snapshotAsMesh). `faces` restringe aos triângulos da
     malha triangulada; `matID` filtra os triângulos por getFaceMatID (a Tarefa 5
     mede por ID de material). Só lê: não altera a cena.
   - InLab_Mapear_Motivo med regra alvoCmPorTile veio:#horizontal -> "" (bom) ou o texto do primeiro
     critério violado ("medição falhou" antes de todos, se med.falhou), na ordem da tabela da spec 7. veioOk só vale com #madeira;
     "escala longe do alvo" só com alvoCmPorTile != undefined.
   - INLAB_MAPEAR_LIMITES: limites provisórios da spec 7 (ajustáveis).

 Decisões:
   - Escala = sqrt(áreaUV/área3D) por triângulo (Spike_EscalaAtual); mediana, p10
     e p90 da amostra. Amostra: no máximo INLAB_MAPEAR_MAX_AMOSTRA (20 mil) faces,
     por passo fixo (teto da divisão: acima de 20 mil o passo é >= 2).
   - Correção 23/10/2026 (rodada de revisão 1): medição que falha no meio marca
     falhou (antes virava "bom"); passo de amostragem com teto da divisão (antes
     a divisão inteira media tudo até 39.999 faces).
   - Emenda à vista com quebra de direção: aresta com UV diferente dos dois lados,
     em superfície lisa (diedro < 30 graus) e com o U girando mais de 30 graus
     (sonda de cortes). Fração do comprimento total das arestas pareadas. Acima da
     amostra, as arestas são lidas em blocos de 16 faces consecutivas (os vizinhos
     de uma malha costumam ser consecutivos), para o pareamento funcionar.
   - Espelhado: sinal do determinante UV, corrigido pelo sinal do transform do nó
     (nó com escala negativa: o snapshot vem do avesso e o render vira a face).
   - veioOk: entre as faces alongadas (aresta longa > 2x a curta), fração com
     |cos| > 0,9 entre a aresta longa e o U (sonda de assets). Sem face
     alongada = 1.0.
   - 23/10/2026 (Tarefa 5, veio vertical): veioOkV = a mesma fração, mas com o V
     (dP/dv) na aresta longa. Textura de veio vertical (V = veio) é gerada com o
     UV girado 90 graus e teria veioOk ~0; o Motivo da #madeira usa veioOkV quando
     veio == #vertical (o orquestrador passa o veio detectado no difuso).
*/

global InLab_Log

global INLAB_MAPEAR_MAX_AMOSTRA = 20000
global INLAB_MAPEAR_LIMITES = #(
    #escalaRealWorld, 0.2,
    #densidadeP90P10, 1.3,
    #emendaVistaQuebra, 0.02,
    #espelhado, 0.05,
    #veioOk, 0.6 )

struct MapearMedida
(
    temCanal = false, escala = 0.0, p10 = 0.0, p90 = 0.0,
    emendaVistaQuebra = 0.0, espelhado = 0.0, veioOk = 1.0, veioOkV = 1.0, faces = 0,
    amostra = 0, falhou = false
)

global InLab_Mapear_Limite, InLab_Mapear_Tangente, InLab_Mapear_Quantil
global InLab_Mapear_TangenteCache
global InLab_Mapear_Medir, InLab_Mapear_Motivo, InLab_Mapear_Pct, InLab_Mapear_Num

fn InLab_Mapear_Limite nome =
(
    local r = 0.0
    for i = 1 to INLAB_MAPEAR_LIMITES.count by 2 where INLAB_MAPEAR_LIMITES[i] == nome do r = INLAB_MAPEAR_LIMITES[i + 1]
    r
)

-- #(tangenteU normalizada, escala UV/cm, sinal do UV, alongada) ou undefined se a
-- face for degenerada em 3D ou em UV. alongada: -1 = não alongada, 1 = U ao longo
-- da aresta longa, 0 = U atravessado; 5º item: o mesmo para o V (veio vertical)
fn InLab_Mapear_Tangente m f =
(
    local fv = getFace m f
    local tv = meshop.getMapFace m 1 f
    local p1 = getVert m fv.x; local p2 = getVert m fv.y; local p3 = getVert m fv.z
    local u1 = meshop.getMapVert m 1 tv.x; local u2 = meshop.getMapVert m 1 tv.y; local u3 = meshop.getMapVert m 1 tv.z
    local e1 = p2 - p1; local e2 = p3 - p1
    local du1 = u2 - u1; local du2 = u3 - u1
    local det = du1.x * du2.y - du2.x * du1.y
    local nn = cross e1 e2
    local a3 = length nn
    local r = undefined
    if abs det >= 1e-12 and a3 >= 1e-9 do
    (
        local dPdu = (e1 * du2.y - e2 * du1.y) / det
        local dPdv = (e2 * du1.x - e1 * du2.x) / det
        local lu = length dPdu; local lv = length dPdv
        if lu >= 1e-9 and lv >= 1e-9 do
        (
            local tu = dPdu / lu
            local e3 = p3 - p2
            local lg = e1
            if (length e2) > (length lg) do lg = e2
            if (length e3) > (length lg) do lg = e3
            local curta = amin (length e1) (amin (length e2) (length e3))
            local along = -1
            local alongV = -1
            if curta > 1e-9 and (length lg) > 2.0 * curta do
            (
                along = if (abs (dot (normalize lg) tu)) > 0.9 then 1 else 0
                alongV = if (abs (dot (normalize lg) (dPdv / lv))) > 0.9 then 1 else 0
            )
            local sinal = if (dot (cross dPdu dPdv) nn) > 0 then 1 else -1
            r = #(tu, (sqrt ((abs det) / a3)), sinal, along, alongV)
        )
    )
    r
)

-- tangente com cache (as arestas pedem a face vizinha)
fn InLab_Mapear_TangenteCache m f cache feito =
(
    if not feito[f] do ( cache[f] = InLab_Mapear_Tangente m f; feito[f] = true )
    cache[f]
)

fn InLab_Mapear_Quantil lista q =
(
    if lista.count == 0 then 0.0
    else lista[amin lista.count (amax 1 ((floor (q * lista.count)) as integer + 1))]
)

fn InLab_Mapear_Medir o faces:undefined matID:undefined =
(
    local med = MapearMedida()
    local m = undefined
    try ( m = snapshotAsMesh o )
    catch ( InLab_Log (o.name + ": Mapear, snapshot falhou (" + (getCurrentException()) + ")") tipo:#err )
    if m == undefined do return med
    try
    (
        if m.numfaces > 0 and (meshop.getNumMaps m) >= 2 and (meshop.getMapSupport m 1) do
        (
            med.temCanal = true
            -- triângulos considerados
            local conj = #{1..m.numfaces}
            if faces != undefined do conj = conj * faces
            if matID != undefined do
                for f in (conj as array) where (getFaceMatID m f) != matID do conj[f] = false
            local lista = conj as array
            med.faces = lista.count
            if lista.count > 0 do
            (
                local maxA = INLAB_MAPEAR_MAX_AMOSTRA
                local passo = amax 1 ((lista.count + maxA - 1) / maxA)
                local tm = o.transform
                local sinalNo = if (dot (cross tm.row1 tm.row2) tm.row3) < 0 then -1 else 1
                local cache = #()
                cache.count = m.numfaces
                local feito = #{}

                -- escala, espelhamento e veio, por amostra de passo fixo
                local esc = #(); local esp = 0; local nT = 0; local alongadas = 0; local alongOk = 0; local alongOkV = 0
                for i = 1 to lista.count by passo do
                (
                    local t = InLab_Mapear_TangenteCache m lista[i] cache feito
                    if t != undefined do
                    (
                        nT += 1
                        append esc t[2]
                        if t[3] * sinalNo < 0 do esp += 1
                        if t[4] >= 0 do ( alongadas += 1; alongOk += t[4]; alongOkV += t[5] )
                    )
                )
                med.amostra = nT
                sort esc
                med.escala = InLab_Mapear_Quantil esc 0.5
                med.p10 = InLab_Mapear_Quantil esc 0.1
                med.p90 = InLab_Mapear_Quantil esc 0.9
                if nT > 0 do med.espelhado = esp as float / nT
                med.veioOk = if alongadas > 0 then alongOk as float / alongadas else 1.0
                med.veioOkV = if alongadas > 0 then alongOkV as float / alongadas else 1.0

                -- emendas à vista com quebra de direção
                local candidatas = lista
                if passo > 1 do
                (
                    candidatas = #()
                    local bloco = 16
                    local salto = bloco * passo
                    for i = 1 to lista.count by salto do
                        for k = i to (amin lista.count (i + bloco - 1)) do append candidatas lista[k]
                )
                local dic = Dictionary #string
                local total = 0.0; local vistaQuebra = 0.0
                for f in candidatas do
                (
                    local fv = getFace m f
                    local tv = meshop.getMapFace m 1 f
                    local vs = #(fv.x as integer, fv.y as integer, fv.z as integer)
                    local ts = #(tv.x as integer, tv.y as integer, tv.z as integer)
                    for k = 1 to 3 do
                    (
                        local k2 = if k == 3 then 1 else k + 1
                        local a = vs[k]; local b = vs[k2]
                        local ta = ts[k]; local tb = ts[k2]
                        if a > b do ( local x = a; a = b; b = x; x = ta; ta = tb; tb = x )
                        local chave = a as string + "_" + b as string
                        if hasDictValue dic chave then
                        (
                            local outro = dic[chave]
                            removeDictValue dic chave
                            local g = outro[1]
                            local comp = distance (getVert m a) (getVert m b)
                            total += comp
                            local uvA1 = meshop.getMapVert m 1 ta; local uvB1 = meshop.getMapVert m 1 tb
                            local uvA2 = meshop.getMapVert m 1 outro[2]; local uvB2 = meshop.getMapVert m 1 outro[3]
                            local ehEmenda = (distance uvA1 uvA2) > 1e-5 or (distance uvB1 uvB2) > 1e-5
                            if ehEmenda and (dot (getFaceNormal m f) (getFaceNormal m g)) > 0.866 do
                            (
                                local tf = InLab_Mapear_TangenteCache m f cache feito
                                local tg = InLab_Mapear_TangenteCache m g cache feito
                                if tf != undefined and tg != undefined and (dot tf[1] tg[1]) < 0.866 do
                                    vistaQuebra += comp
                            )
                        )
                        else dic[chave] = #(f, ta, tb)
                    )
                )
                if total > 0.0 do med.emendaVistaQuebra = vistaQuebra / total
            )
        )
    )
    catch
    (
        med.falhou = true
        InLab_Log (o.name + ": Mapear, medição falhou (" + (getCurrentException()) + ")") tipo:#err
    )
    try ( delete m )
    catch ( InLab_Log (o.name + ": Mapear, não liberou o snapshot (" + (getCurrentException()) + ")") tipo:#warn )
    med
)

fn InLab_Mapear_Pct x = ( (((x * 100.0) as integer) as string) + "%" )

-- número com uma casa decimal e vírgula
fn InLab_Mapear_Num x =
(
    local s = formattedPrint x format:".1f"
    substituteString s "." ","
)

fn InLab_Mapear_Motivo med regra alvoCmPorTile veio:#horizontal =
(
    local r = ""
    local fracVeio = if veio == #vertical then med.veioOkV else med.veioOk
    if med.falhou then r = "medição falhou"
    else if not med.temCanal then r = "sem canal 1"
    else if med.escala > (InLab_Mapear_Limite #escalaRealWorld) then
        r = "UV na escala do Real-World (1 tile a cada " + (InLab_Mapear_Num (1.0 / med.escala)) + " cm)"
    else if alvoCmPorTile != undefined and alvoCmPorTile > 0 and med.escala > 0 and \
        ((1.0 / med.escala) < alvoCmPorTile * 0.7 or (1.0 / med.escala) > alvoCmPorTile * 1.3) then
        r = "escala longe do alvo (1 tile a cada " + (InLab_Mapear_Num (1.0 / med.escala)) + " cm, alvo " + (InLab_Mapear_Num alvoCmPorTile) + " cm)"
    else if med.p10 > 0 and (med.p90 / med.p10) > (InLab_Mapear_Limite #densidadeP90P10) then
        r = "densidade desigual (p90/p10 = " + (InLab_Mapear_Num (med.p90 / med.p10)) + ")"
    else if med.emendaVistaQuebra > (InLab_Mapear_Limite #emendaVistaQuebra) then
        r = "emendas à vista com quebra de direção (" + (InLab_Mapear_Pct med.emendaVistaQuebra) + ")"
    else if med.espelhado > (InLab_Mapear_Limite #espelhado) then
        r = "UV espelhado (" + (InLab_Mapear_Pct med.espelhado) + " das faces)"
    else if regra == #madeira and fracVeio < (InLab_Mapear_Limite #veioOk) then
        r = "veio atravessado (" + (InLab_Mapear_Pct fracVeio) + " das faces no sentido certo)"
    r
)
