/*
 tests\test_mapear_paineis.ms — teste de functions\fn_mapear_paineis.ms (Mapear por
 paineis). RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear_paineis.txt (PASS/FAIL por item).
 26/10/2026 (Tarefa 1): vivos e geometria em mundo.
 26/10/2026 (Tarefa 2): costuras pelo vivo, molde em caixa, contornos.
 26/10/2026 (Tarefa 3): UV de discos e anéis (InLab_Paineis_UV / InLab_Paineis_Torta).
*/
global InLab_Log, InLab_EhGeometria, InLab_Mapear_PolyDe
global InLab_Paineis_Vert, InLab_Paineis_Elementos, InLab_Paineis_VolArea
global InLab_Paineis_EhVivo, InLab_Paineis_VivosDoProduto, InLab_Paineis_NosDaCabeca
global InLab_Paineis_Separar, InLab_Paineis_Contornos
global InLab_Paineis_UV, InLab_Paineis_Torta, InLab_Mapear_Medir, InLab_Mapear_Gravar
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_mapear_paineis.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info =
    (
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
        flush INLAB_TESTE_SAIDA
    )
    local criados = #()
    try
    (
        fileIn (raiz + @"core\utils.ms")
        fileIn (raiz + @"functions\fn_mapear_classe.ms")
        fileIn (raiz + @"functions\fn_mapear_medir.ms")
        fileIn (raiz + @"functions\fn_mapear_gerar.ms")
        fileIn (raiz + @"functions\fn_mapear_paineis.ms")

        -- almofada: Box 100x100x20 arredondado
        local almofada = ChamferBox length:100 width:100 height:20 fillet:5 filletsegs:3 name:"TESTE_pn_almofada"
        convertToPoly almofada
        append criados almofada
        -- vivo: toro fino
        local toro = Torus radius1:50 radius2:0.6 segments:48 sides:8 name:"TESTE_pn_toro" pos:[0,0,10]
        convertToPoly toro
        append criados toro

        local pa = almofada.baseobject, pt = toro.baseobject
        local elA = InLab_Paineis_Elementos pa #{1..(polyop.getNumFaces pa)}
        local elT = InLab_Paineis_Elementos pt #{1..(polyop.getNumFaces pt)}
        checar "elementos: almofada e toro tem 1 elemento cada" (elA.count == 1 and elT.count == 1)
        checar "vivo: toro fino é vivo" ((InLab_Paineis_EhVivo toro elT[1])[1] == true)
        checar "vivo: almofada não é vivo" ((InLab_Paineis_EhVivo almofada elA[1])[1] == false)
        local pts = InLab_Paineis_VivosDoProduto almofada nos:#(almofada, toro)
        checar "vivo: VivosDoProduto acha os vértices do toro" (pts.count == polyop.getNumVerts pt)

        -- sem nos: varre a hierarquia da cabeça (toro filho da almofada)
        toro.parent = almofada
        local pts2 = InLab_Paineis_VivosDoProduto toro
        checar "vivo: sem nos varre a hierarquia a partir da cabeça" (pts2.count == polyop.getNumVerts pt)

        -- plano fino aberto não é vivo
        local plano = Plane length:200 width:2 lengthsegs:4 widthsegs:1 name:"TESTE_pn_plano"
        convertToPoly plano
        append criados plano
        local elP = InLab_Paineis_Elementos plano.baseobject #{1..(polyop.getNumFaces plano.baseobject)}
        checar "vivo: plano fino aberto não é vivo" ((InLab_Paineis_EhVivo plano elP[1])[1] == false)

        -- nó Editable_Mesh com um toro fino
        local toroM = Torus radius1:50 radius2:0.6 segments:48 sides:8 name:"TESTE_pn_toroM" pos:[0,500,10]
        convertToMesh toroM
        append criados toroM
        local ptsM = InLab_Paineis_VivosDoProduto toroM nos:#(toroM)
        checar "vivo: VivosDoProduto acha o vivo de um nó Editable_Mesh" (ptsM.count == 48 * 8)
        local nTemp = (for o in objects where (matchPattern o.name pattern:"InLab_tmp_paineis*") collect o).count
        checar "vivo: cópia temporária apagada" (nTemp == 0)
        local el0 = #{1..(getNumFaces toroM.mesh)}
        local r0 = try ( InLab_Paineis_EhVivo toroM el0 ) catch ( undefined )
        checar "guarda: EhVivo numa base Editable_Mesh devolve false sem exceção" (r0 != undefined and r0[1] == false)

        -- mundo: nó com pivô deslocado
        local m = Box length:30 width:20 height:10 name:"TESTE_pn_mundo"
        convertToPoly m
        append criados m
        m.pos = [5000,0,0]
        m.pivot = [5010,5,3]
        rotate m (eulerAngles 0 0 30)
        local malha = snapshotAsMesh m
        local pm = m.baseobject
        local ok = true
        -- ordem dos vértices do snapshot do poly = ordem da base (Box convertido, sem triangulação extra)
        for v = 1 to (polyop.getNumVerts pm) while ok do
            if (distance (InLab_Paineis_Vert m v) (getVert malha v)) > 1e-3 do ok = false
        checar "mundo: vértice de nó com pivô em [5000,0,0]" ok
        delete malha

        ---------------- Tarefa 2: costuras e paineis ----------------
        -- laço de vivo (mundo): quadrado de meia-medida h em volta da almofada, na altura z
        fn lacoVivo h z desloc =
        (
            local pts = #()
            for k = -h to h by 1.0 do
            (
                append pts ([k, h, z] + desloc)
                append pts ([k, -h, z] + desloc)
                append pts ([h, k, z] + desloc)
                append pts ([-h, k, z] + desloc)
            )
            pts
        )
        -- almofada de teste: Box segmentado (o topo do ChamferBox é um n-gono só)
        fn mkAlmofada nome =
        (
            local a = Box length:100 width:100 height:20 lengthsegs:10 widthsegs:10 heightsegs:2 name:nome
            convertToPoly a
            a
        )
        local a2 = mkAlmofada "TESTE_pn_alm2"
        append criados a2
        local pa2 = a2.baseobject
        local corpo2 = #{1..(polyop.getNumFaces pa2)}
        local vv = lacoVivo 50.0 10.0 [0,0,0]
        local r1 = InLab_Paineis_Separar a2 corpo2 vv
        checar "costura: almofada com vivo no meio dá 2 painéis pelo vivo" (r1.paineis.count == 2 and (matchPattern r1.metodo pattern:"vivo*"))
        local soma = 0, inter = false, uniao = #{}
        for p in r1.paineis do ( soma += p.numberSet; if (uniao * p).numberSet > 0 do inter = true; uniao += p )
        checar "costura: os 2 painéis cobrem todas as faces do corpo" (soma == corpo2.numberSet and not inter and uniao.numberSet == corpo2.numberSet)

        local r2 = InLab_Paineis_Separar a2 corpo2 #()
        checar "caixa: sem vivo dá molde em caixa no eixo Z com 3 painéis" (r2.paineis.count == 3 and r2.eixoCaixa == 3 and (matchPattern r2.metodo pattern:"molde em caixa*"))

        local pe = ChamferBox length:20 width:90 height:36 fillet:3 filletsegs:3 lengthsegs:4 widthsegs:8 heightsegs:4 name:"TESTE_pn_empe"
        convertToPoly pe
        append criados pe
        local r3 = InLab_Paineis_Separar pe #{1..(polyop.getNumFaces pe.baseobject)} #()
        checar "caixa: almofada em pé (fina em Y) usa o eixo Y" (r3.eixoCaixa == 2)

        local cb3 = ChamferBox length:100 width:100 height:20 fillet:5 filletsegs:3 name:"TESTE_pn_cb3"
        convertToPoly cb3
        append criados cb3
        local r3b = InLab_Paineis_Separar cb3 #{1..(polyop.getNumFaces cb3.baseobject)} #()
        checar "caixa: ChamferBox 100×100×20 (Fillet 5) sem vivo dá 3 painéis" (r3b.paineis.count == 3 and r3b.eixoCaixa == 3)
        checar "caixa: almofada em pé ChamferBox 90×20×36 dá 3 painéis no eixo Y" (r3.paineis.count == 3 and r3.eixoCaixa == 2)

        local cil = Cylinder radius:20 height:45 heightsegs:3 sides:24 name:"TESTE_pn_cil"
        convertToPoly cil
        append criados cil
        local r4 = InLab_Paineis_Separar cil #{1..(polyop.getNumFaces cil.baseobject)} #()
        checar "caixa: cilindro Ø40 × 45 fica no eixo Z" (r4.eixoCaixa == 3)
        checar "caixa: cilindro Ø40 × 45 (sides 24) dá 3 painéis" (r4.paineis.count == 3)

        local r5 = InLab_Paineis_Separar a2 corpo2 (lacoVivo 55.0 10.0 [0,0,0])
        checar "diag: vivo a 5 cm não separa e o motivo diz isso" ((matchPattern r5.metodo pattern:"molde em caixa*") and (findString r5.diag "3 cm") != undefined)

        local a3 = mkAlmofada "TESTE_pn_alm3"
        append criados a3
        a3.pos = [5000,300,0]
        a3.pivot = [5005,303,0]
        local r6 = InLab_Paineis_Separar a3 #{1..(polyop.getNumFaces a3.baseobject)} (lacoVivo 50.0 10.0 [5000,300,0])
        local c1 = for p in r1.paineis collect p.numberSet
        local c6 = for p in r6.paineis collect p.numberSet
        sort c1; sort c6
        checar "mundo: a mesma almofada com pivô em [5000,300,0] dá os mesmos painéis" (c1.count == c6.count and c1.count == 2 and c1[1] == c6[1] and c1[2] == c6[2])
        local r7 = InLab_Paineis_Separar a3 #{1..(polyop.getNumFaces a3.baseobject)} #()
        checar "mundo: molde em caixa com pivô deslocado dá 3 painéis" (r7.paineis.count == 3 and r7.eixoCaixa == 3)

        checar "contornos: anel 2, disco 1" (r2.paineis.count == 3 and (InLab_Paineis_Contornos pa2 r2.paineis[3]) == 2 and (InLab_Paineis_Contornos pa2 r2.paineis[1]) == 1)

        ---------------- Tarefa 3: UV de cada painel ----------------
        -- normal de face em mundo (vetor)
        fn normalMundo o f = ( local tm = o.objectTransform; normalize ((polyop.getFaceNormal o.baseobject f) * tm - tm.row4) )
        -- centro (mundo) das faces fs
        fn centroFaces o fs =
        (
            local c = [0,0,0], n = 0
            for v in (polyop.getVertsUsingFace o.baseobject fs) do ( c += InLab_Paineis_Vert o v; n += 1 )
            c / n
        )
        -- faces de fs vizinhas de uma costura do UV (vértice de mapa diferente numa aresta comum)
        fn facesCostura o fs mapa =
        (
            local po = o.baseobject
            local idsDe = #()
            for e in mapa do idsDe[e[1]] = e[2]
            local res = #{}
            for e in (polyop.getEdgesUsingFace po fs) do
            (
                local fe = polyop.getEdgeFaces po e
                if fe.count == 2 and fs[fe[1]] and fs[fe[2]] do
                (
                    local fv1 = polyop.getFaceVerts po fe[1], fv2 = polyop.getFaceVerts po fe[2]
                    local corta = false
                    for v in (polyop.getEdgeVerts po e) do
                        if idsDe[fe[1]][findItem fv1 v] != idsDe[fe[2]][findItem fv2 v] do corta = true
                    if corta do ( res[fe[1]] = true; res[fe[2]] = true )
                )
            )
            res
        )
        -- faces com UV espelhado (produto vetorial 2D das arestas de UV < 0)
        fn nEspelhadas uvs mapa =
        (
            local n = 0
            for e in mapa do
            (
                local t0 = uvs[e[2][1]], t1 = uvs[e[2][2]], t2 = uvs[e[2][3]]
                if ((t1 - t0).x * (t2 - t0).y - (t1 - t0).y * (t2 - t0).x) < 0 do n += 1
            )
            n
        )
        -- rolo: cilindro r15 × 100 deitado em X (nó girado; a base fica no eixo Z do objeto)
        fn mkRolo nome =
        (
            local c = Cylinder radius:15 height:100 sides:32 heightsegs:6 capsegs:3 name:nome
            rotate c (eulerAngles 0 90 0)
            convertToPoly c
            c
        )
        -- painéis do rolo: faixa (|n·X| < 0.97) e os dois tampos
        fn paineisRolo o =
        (
            local po = o.baseobject
            local faixa = #{}, tA = #{}, tB = #{}
            local cx = (centroFaces o #{1..(polyop.getNumFaces po)}).x
            for f = 1 to polyop.getNumFaces po do
            (
                local n = normalMundo o f
                if abs n.x < 0.97 then faixa[f] = true
                else if (centroFaces o #{f}).x < cx then tA[f] = true else tB[f] = true
            )
            #(faixa, tA, tB)
        )
        local rolo = mkRolo "TESTE_pn_rolo"
        append criados rolo
        local pRolo = paineisRolo rolo
        -- canal 1 do nó antes (o teste garante que ele existe, para conferir que não muda)
        polyop.setMapSupport rolo.baseobject 1 true
        local nMapAntes = polyop.getNumMapVerts rolo.baseobject 1
        local uvMapAntes = polyop.getMapVert rolo.baseobject 1 1
        local mfAntes = for f = 1 to (polyop.getNumFaces rolo.baseobject) collect (polyop.getMapFace rolo.baseobject 1 f) as string
        local rR = InLab_Paineis_UV rolo pRolo "vivo (1.0 cm)" 3 (1.0 / 60.0)
        checar "anel: UV do rolo gerado" (rR != undefined and rR.count == 3)
        if rR != undefined do
        (
            local tR = InLab_Paineis_Torta rR[1] rR[2] rolo pRolo[1] [1,0,0] 0.0
            linha ("      torta do rolo: " + tR as string + "; resumo: " + rR[3])
            checar "anel: rolo deitado em X (cilindro 100 × r15) dá U ao longo de X" (tR < 0.05)
            local cRolo = centroFaces rolo pRolo[1]
            local cost = facesCostura rolo pRolo[1] rR[2]
            local zc = (centroFaces rolo cost).z
            checar "anel: corte do rolo fica embaixo" (cost.numberSet > 0 and zc < cRolo.z - 0.8 * 15.0)
            local mfIgual = true
            for f = 1 to mfAntes.count while mfIgual do if ((polyop.getMapFace rolo.baseobject 1 f) as string) != mfAntes[f] do mfIgual = false
            checar "não grava: canal 1 do nó intacto e nó temporário apagado" (mfIgual and polyop.getNumMapVerts rolo.baseobject 1 == nMapAntes and (distance (polyop.getMapVert rolo.baseobject 1 1) uvMapAntes) < 1e-6 and (for o in objects where (matchPattern o.name pattern:"InLab_tmp*") collect o).count == 0)
            checar "anel: mapa cobre todas as faces dos painéis" (rR[2].count == polyop.getNumFaces rolo.baseobject)

            -- mundo: a mesma geometria (mundo) num nó com pivô em [5000,0,0] e girado 30° em Z
            local rolo2 = mkRolo "TESTE_pn_rolo2"
            append criados rolo2
            local p2o = rolo2.baseobject
            local pw = for v = 1 to (polyop.getNumVerts p2o) collect InLab_Paineis_Vert rolo2 v
            rolo2.transform = (rotateZMatrix 30) * (transMatrix [5000,0,0])
            local inv = inverse rolo2.objectTransform
            for v = 1 to pw.count do polyop.setVert p2o v (pw[v] * inv)
            local okGeo = true
            for v = 1 to pw.count while okGeo do if (distance (InLab_Paineis_Vert rolo2 v) pw[v]) > 1e-3 do okGeo = false
            local rR2 = InLab_Paineis_UV rolo2 (paineisRolo rolo2) "vivo (1.0 cm)" 3 (1.0 / 60.0)
            local tR2 = if rR2 == undefined then 9.0 else InLab_Paineis_Torta rR2[1] rR2[2] rolo2 (paineisRolo rolo2)[1] [1,0,0] 0.0
            linha ("      torta do rolo com pivô longe: " + tR2 as string)
            checar "mundo: rolo com pivô em [5000,0,0] e girado 30° em Z dá a mesma torta (±0.02)" (okGeo and abs (tR2 - tR) <= 0.02)

            local nEsp = nEspelhadas rR[1] rR[2]
            -- molde em caixa: faixa vertical, corte na quina de trás
            local rB = InLab_Paineis_UV a2 r2.paineis r2.metodo r2.eixoCaixa (1.0 / 60.0)
            checar "anel: UV da almofada (molde em caixa) gerado" (rB != undefined)
            if rB != undefined do
            (
                linha ("      resumo da almofada: " + rB[3])
                local faixaB = r2.paineis[3]
                local cB = centroFaces a2 faixaB
                local costB = facesCostura a2 faixaB rB[2]
                local okB = costB.numberSet > 0
                for f in costB do ( local q = centroFaces a2 #{f}; if not (q.y > cB.y and q.x < cB.x) do okB = false )
                checar "anel: faixa vertical (molde em caixa) corta na quina de trás" okB
                nEsp += nEspelhadas rB[1] rB[2]
            )
            -- disco: tampo de uma almofada girada 30° em Z
            local a4 = mkAlmofada "TESTE_pn_alm4"
            append criados a4
            rotate a4 (eulerAngles 0 0 30)
            local r8 = InLab_Paineis_Separar a4 #{1..(polyop.getNumFaces a4.baseobject)} #()
            local rD = InLab_Paineis_UV a4 r8.paineis r8.metodo r8.eixoCaixa (1.0 / 60.0)
            local tD = if rD == undefined then 9.0 else InLab_Paineis_Torta rD[1] rD[2] a4 r8.paineis[1] [1,0,0] 0.0
            linha ("      torta do tampo: " + tD as string)
            checar "disco: tampo plano sai com o X do mundo no U" (r8.paineis.count == 3 and tD < 0.02)
            if rD != undefined do nEsp += nEspelhadas rD[1] rD[2]
            linha ("      faces espelhadas: " + nEsp as string)
            checar "espelho: nenhum painel espelhado" (nEsp == 0)

            -- escala: 1/200 por cm, gravado e medido
            local rE = InLab_Paineis_UV rolo pRolo "vivo (1.0 cm)" 3 (1.0 / 200.0)
            local cmTile = 0.0
            if rE != undefined and (InLab_Mapear_Gravar rolo rE[1] rE[2]) do
            (
                local med = InLab_Mapear_Medir rolo
                if med.escala > 0 do cmTile = 1.0 / med.escala
            )
            linha ("      cm por tile: " + cmTile as string)
            checar "escala: 1/200 por cm dá 200 cm por tile" (cmTile >= 190.0 and cmTile <= 210.0)
        )
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    for o in criados where isValidNode o do try ( delete o ) catch ()
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
