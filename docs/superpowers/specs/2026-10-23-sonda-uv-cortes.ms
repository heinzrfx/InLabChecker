-- Sonda: cortes (emendas de UV) e direção da textura no canal 1. Só leitura.
-- 23/10/2026, estudo do automapeamento (2026-10-22-automapeamento-estudo.md).
-- Por objeto, pelas arestas da malha triangulada:
--   emenda       = aresta cujos dois lados têm UV em posições diferentes;
--   emenda à vista = emenda em superfície lisa (diedro < 30°); em quina viva
--                  ela fica escondida e é aceitável;
--   quebra de direção = o U de um lado e do outro difere mais de 30° (no 3D);
--   salto de escala   = a escala UV/cm muda mais de 30% entre os lados.
-- E a direção do U: nas laterais (normal quase horizontal), U horizontal,
-- vertical ou diagonal; no topo, U alinhado a X/Y ou diagonal.
-- Saída: (getDir #temp)\inlab_sonda_uv_cortes.txt (e o global SondaCortes_Arestas
-- guarda as emendas à vista com quebra, por objeto, para desenhar depois).
global SondaCortes_Saida = (getDir #temp) + "\\inlab_sonda_uv_cortes.txt"
global SondaCortes_Arestas = #()

fn SondaCortes_Pct a b = if b <= 0 then "-" else ((100.0*a/b) as integer) as string + "%"

-- tangente U (dP/du normalizado) e escala UV/cm de uma face; undefined se degenerada
fn SondaCortes_Tangente m f =
(
    local fv = getFace m f
    local tv = meshop.getMapFace m 1 f
    local p1 = getVert m fv.x; local p2 = getVert m fv.y; local p3 = getVert m fv.z
    local u1 = meshop.getMapVert m 1 tv.x; local u2 = meshop.getMapVert m 1 tv.y; local u3 = meshop.getMapVert m 1 tv.z
    local e1 = p2-p1; local e2 = p3-p1
    local du1 = u2-u1; local du2 = u3-u1
    local det = du1.x*du2.y - du2.x*du1.y
    if abs det < 1e-12 then undefined
    else
    (
        local dPdu = (e1*du2.y - e2*du1.y)/det
        local dPdv = (e2*du1.x - e1*du2.x)/det
        local lu = length dPdu; local lv = length dPdv
        if lu < 1e-9 or lv < 1e-9 then undefined
        else #(dPdu/lu, 1.0/(sqrt (lu*lv)), (if (dot (cross dPdu dPdv) (cross e1 e2)) > 0 then 1 else -1))
    )
)

fn SondaCortes_Objeto o arq =
(
    local m = snapshotAsMesh o
    format "\n=== % · faces:%\n" o.name m.numfaces to:arq
    if m.numfaces == 0 or not (meshop.getMapSupport m 1) then ( format "  SEM canal 1\n" to:arq; delete m; return ok )
    local tans = for f = 1 to m.numfaces collect (SondaCortes_Tangente m f)
    local nrms = for f = 1 to m.numfaces collect (getFaceNormal m f)
    -- direção do U
    local lat = 0; local latH = 0; local latV = 0; local latD = 0
    local topo = 0; local topoAlinh = 0; local topoD = 0; local espelho = 0
    -- nó com escala negativa: o snapshot vem com as faces do avesso no mundo e o
    -- render vira a face; o espelhamento visível é o contrário do medido
    local tm = o.transform
    local sinalNo = if (dot (cross tm.row1 tm.row2) tm.row3) < 0 then -1 else 1
    for f = 1 to m.numfaces where tans[f] != undefined do
    (
        local t = tans[f][1]; local n = nrms[f]
        if tans[f][3] * sinalNo < 0 do espelho += 1
        if abs n.z < 0.5 then
        (
            lat += 1
            if abs t.z < 0.26 then latH += 1 else if abs t.z > 0.87 then latV += 1 else latD += 1
        )
        else
        (
            topo += 1
            local a = amax (abs t.x) (abs t.y)
            if a > 0.97 then topoAlinh += 1 else topoD += 1
        )
    )
    -- arestas: chave pelos vértices da malha (menor_maior)
    local dic = Dictionary #string
    local total = 0.0; local emenda = 0.0; local vista = 0.0; local vistaQuebra = 0.0; local vistaEscala = 0.0
    local internaQuebra = 0.0
    local marcadas = #()
    for f = 1 to m.numfaces do
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
                local liso = (dot nrms[f] nrms[g]) > 0.866
                local quebra = false; local salto = false
                if tans[f] != undefined and tans[g] != undefined do
                (
                    quebra = (dot tans[f][1] tans[g][1]) < 0.866
                    local r = tans[f][2] / tans[g][2]
                    salto = r > 1.3 or r < (1/1.3)
                )
                if ehEmenda then
                (
                    emenda += comp
                    if liso do
                    (
                        vista += comp
                        if quebra do ( vistaQuebra += comp; append marcadas #(getVert m a, getVert m b) )
                        if salto do vistaEscala += comp
                    )
                )
                else if quebra and liso do internaQuebra += comp
            )
            else dic[chave] = #(f, ta, tb)
        )
    )
    append SondaCortes_Arestas #(o.name, marcadas)
    format "  emendas: % do comprimento das arestas · à vista (sup. lisa): % · à vista com quebra de direção: % · com salto de escala: %\n" \
        (SondaCortes_Pct emenda total) (SondaCortes_Pct vista total) (SondaCortes_Pct vistaQuebra total) (SondaCortes_Pct vistaEscala total) to:arq
    format "  sem emenda mas U torce >30° entre faces lisas: %\n" (SondaCortes_Pct internaQuebra total) to:arq
    format "  laterais (%): U horizontal % · vertical % · diagonal %\n" lat (SondaCortes_Pct latH lat) (SondaCortes_Pct latV lat) (SondaCortes_Pct latD lat) to:arq
    format "  topo/base (%): U alinhado a X/Y % · diagonal %\n" topo (SondaCortes_Pct topoAlinh topo) (SondaCortes_Pct topoD topo) to:arq
    format "  faces com UV espelhado: %\n" (SondaCortes_Pct espelho m.numfaces) to:arq
    delete m
)

(
    SondaCortes_Arestas = #()
    local arq = openFile SondaCortes_Saida mode:"wt"
    format "Sonda de cortes e direção (canal 1) · %\n" localTime to:arq
    local t0 = timestamp()
    for o in geometry where not o.isHidden do
        try ( SondaCortes_Objeto o arq ) catch ( format "  ERRO em %: %\n" o.name (getCurrentException()) to:arq )
    format "\nTempo: %s\n" ((timestamp() - t0)/1000.0) to:arq
    close arq
)
