/*
 tests\test_mapear_paineis.ms — teste de functions\fn_mapear_paineis.ms (Mapear por
 paineis). RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear_paineis.txt (PASS/FAIL por item).
 26/10/2026 (Tarefa 1): vivos e geometria em mundo.
 26/10/2026 (Tarefa 2): costuras pelo vivo, molde em caixa, contornos.
 26/10/2026 (Tarefa 3): UV de discos e anéis (InLab_Paineis_UV / InLab_Paineis_Torta).
 26/10/2026 (Tarefa 4): botão Painéis (InLab_Paineis), pilha, Desfazer Painéis, Desfazer
 Mapear e Desfazer UV com painéis por cima; ChamferBox com os nomes certos de segmentos.
*/
global InLab_Log, InLab_EhGeometria, InLab_Mapear_PolyDe
global InLab_Paineis_Vert, InLab_Paineis_Elementos, InLab_Paineis_VolArea
global InLab_Paineis_EhVivo, InLab_Paineis_VivosDoProduto, InLab_Paineis_NosDaCabeca
global InLab_Paineis_Separar, InLab_Paineis_Contornos
global InLab_Paineis_UV, InLab_Paineis_Torta, InLab_Mapear_Medir, InLab_Mapear_Gravar
global InLab_ParseJSON, InLab_Produto_Lista, InLab_RWF_Feitos, InLab_Mapear, InLab_ReverterMapear
global InLab_UltimoMapear, InLab_Mapear_LerCanal1, InLab_ReverterAutoUV, InLab_UltimoRWF, InLab_UltimoAutoUV
global InLab_Paineis, InLab_DesfazerPaineis, InLab_PilhaPaineis, InLab_Paineis_EsquecerPeca
global InLab_Paineis_EhTecido, InLab_Paineis_Escala
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
    local logs = #()
    InLab_Log = fn _logTeste msg tipo:#info =
    (
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
        flush INLAB_TESTE_SAIDA
        append logs #(tipo, msg)
    )
    -- algum log do tipo com os dois trechos
    fn temLog logs tipo t1 t2 =
    (
        (for l in logs where l[1] == tipo and (findString l[2] t1) != undefined and (findString l[2] t2) != undefined collect l).count > 0
    )
    fn contaLog logs t1 t2 =
    (
        (for l in logs where (findString l[2] t1) != undefined and (findString l[2] t2) != undefined collect l).count
    )
    local criados = #()
    local feitosAntes = InLab_RWF_Feitos
    local arqImg = undefined
    try
    (
        fileIn (raiz + @"core\utils.ms")
        fileIn (raiz + @"functions\fn_json.ms")
        fileIn (raiz + @"functions\fn_renomear_produto.ms")
        fileIn (raiz + @"functions\fn_autouv.ms")
        fileIn (raiz + @"functions\fn_realworldfix.ms")
        fileIn (raiz + @"functions\fn_mapear_classe.ms")
        fileIn (raiz + @"functions\fn_mapear_medir.ms")
        fileIn (raiz + @"functions\fn_mapear_gerar.ms")
        fileIn (raiz + @"functions\fn_mapear.ms")
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

        local pe = ChamferBox length:20 width:90 height:36 fillet:3 Fillet_Segments:3 Length_Segments:10 Width_Segments:10 Height_Segments:10 name:"TESTE_pn_empe"
        convertToPoly pe
        append criados pe
        local r3 = InLab_Paineis_Separar pe #{1..(polyop.getNumFaces pe.baseobject)} #()
        checar "caixa: almofada em pé (fina em Y) usa o eixo Y" (r3.eixoCaixa == 2)

        -- 26/10/2026 (Tarefa 4): ChamferBox usa Length_Segments/Width_Segments/Height_Segments e
        -- Fillet_Segments (lengthsegs:/filletsegs: eram ignorados em silêncio: malha de ~114 faces)
        local cb3 = ChamferBox length:100 width:100 height:20 fillet:5 Fillet_Segments:3 Length_Segments:10 Width_Segments:10 Height_Segments:10 name:"TESTE_pn_cb3"
        convertToPoly cb3
        append criados cb3
        local r3b = InLab_Paineis_Separar cb3 #{1..(polyop.getNumFaces cb3.baseobject)} #()
        checar "caixa: ChamferBox 100×100×20 (Fillet 5) sem vivo dá 3 painéis" (r3b.paineis.count == 3 and r3b.eixoCaixa == 3)
        checar "caixa: almofada em pé ChamferBox 90×20×36 dá 3 painéis no eixo Y" (r3.paineis.count == 3 and r3.eixoCaixa == 2)
        linha ("      ChamferBox: em pé " + (polyop.getNumFaces pe.baseobject) as string + " faces, 100×100×20 " + (polyop.getNumFaces cb3.baseobject) as string + " faces")
        checar "caixa: os ChamferBox do teste são densos (10 segmentos por lado)" ((polyop.getNumFaces pe.baseobject) > 1000 and (polyop.getNumFaces cb3.baseobject) > 1000)

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

            -- espelho: rolo com scale [-1,1,1] (o espelho conta pelo sinal do transform, como EspelhoUV)
            local rolo3 = mkRolo "TESTE_pn_rolo3"
            append criados rolo3
            rolo3.scale = [-1,1,1]
            local t3m = rolo3.objectTransform
            local sinal3 = if (dot (cross t3m.row1 t3m.row2) t3m.row3) < 0 then -1 else 1
            local pRolo3 = paineisRolo rolo3
            local rM = InLab_Paineis_UV rolo3 pRolo3 "vivo (1.0 cm)" 3 (1.0 / 60.0)
            local okM = false
            if rM != undefined do
            (
                local nEspM = 0
                for e in rM[2] do
                (
                    local t0 = rM[1][e[2][1]], t1 = rM[1][e[2][2]], t2 = rM[1][e[2][3]]
                    if ((t1 - t0).x * (t2 - t0).y - (t1 - t0).y * (t2 - t0).x) * sinal3 < 0 do nEspM += 1
                )
                local cR3 = centroFaces rolo3 pRolo3[1]
                local costM = facesCostura rolo3 pRolo3[1] rM[2]
                local zM = (centroFaces rolo3 costM).z
                linha ("      rolo espelhado: sinal " + sinal3 as string + ", faces espelhadas " + nEspM as string + ", z da costura " + zM as string + " (centro " + cR3.z as string + ")")
                okM = sinal3 < 0 and nEspM == 0 and costM.numberSet > 0 and zM < cR3.z - 0.8 * 15.0
            )
            checar "espelho: rolo com scale [-1,1,1] não sai espelhado e mantém corte embaixo" okM
        )

        -- desempenho: almofada arredondada de ~20 mil faces (molde em caixa; a faixa passa pelo Unfold3D)
        local grande = ChamferBox length:100 width:100 height:20 fillet:5 Fillet_Segments:4 Length_Segments:84 Width_Segments:84 Height_Segments:8 name:"TESTE_pn_grande"
        convertToPoly grande
        append criados grande
        local nfG = polyop.getNumFaces grande.baseobject
        local rG = InLab_Paineis_Separar grande #{1..nfG} #()
        local tIni = timeStamp()
        local uvG = InLab_Paineis_UV grande rG.paineis rG.metodo rG.eixoCaixa (1.0 / 60.0)
        local seg = (timeStamp() - tIni) / 1000.0
        linha ("      desempenho: " + nfG as string + " faces em " + seg as string + " s; " + (if uvG == undefined then "sem UV" else uvG[3]))
        checar "desempenho: 20 mil faces abaixo de 20 s" (nfG >= 19000 and uvG != undefined and seg < 20.0)

        ---------------- Tarefa 4: botão Painéis, pilha e Desfazer Painéis ----------------
        -- canal 1 da base (registro de InLab_Mapear_LerCanal1) igual
        fn igualCanal a b =
        (
            if a == undefined or b == undefined then a == b
            else if a[1] != b[1] or a[3].count != b[3].count then false
            else
            (
                local ok = true
                for k = 1 to a[1] while ok do if (distance a[2][k] b[2][k]) > 1e-5 do ok = false
                for k = 1 to a[3].count while ok do
                (
                    local fa = a[3][k][2], fb = b[3][k][2]
                    if fa.count != fb.count then ok = false
                    else for j = 1 to fa.count do if fa[j] != fb[j] do ok = false
                )
                ok
            )
        )
        -- UV avaliado (snapshot) por canto de triângulo, só das faces do ID (undefined = todas)
        fn canalID o id =
        (
            local m = snapshotAsMesh o
            local r = #()
            if (meshop.getNumMaps m) > 1 and (meshop.getMapSupport m 1) do
                for f = 1 to m.numfaces where id == undefined or (getFaceMatID m f) == id do
                (
                    local tv = meshop.getMapFace m 1 f
                    for k = 1 to 3 do append r (meshop.getMapVert m 1 tv[k])
                )
            delete m
            r
        )
        fn igualLista a b =
        (
            local ok = a.count == b.count and a.count > 0
            for k = 1 to a.count while ok do if (distance a[k] b[k]) > 1e-5 do ok = false
            ok
        )
        fn gerarImagem nome =
        (
            local arq = (getDir #temp) + "\\" + nome
            local bm = dotNetObject "System.Drawing.Bitmap" 64 64
            local claro = (dotNetClass "System.Drawing.Color").FromArgb 230 230 230
            local escuro = (dotNetClass "System.Drawing.Color").FromArgb 40 40 40
            for y = 0 to 63 do
            (
                local c = if (mod (y / 4) 2) == 0 then escuro else claro
                for x = 0 to 63 do bm.SetPixel x y c
            )
            bm.Save arq
            bm.Dispose()
            arq
        )
        fn criarMaterial nome arq =
        (
            local b = Bitmaptexture filename:arq
            b.coords.mapChannel = 1
            Standardmaterial name:nome diffuseMap:b
        )
        -- almofada Box 100×100×20 (10×10×2 segmentos) com UV de UVW Box de 60 cm colapsado
        fn mkPeca nome pos =
        (
            local b = Box length:100 width:100 height:20 lengthsegs:10 widthsegs:10 heightsegs:2 mapcoords:true name:nome pos:pos
            addModifier b (Uvwmap maptype:4 length:60 width:60 height:60)
            convertToPoly b
            b
        )
        -- vivo quadrado (4 barras finas de 1,2 cm, uma por lado) em volta de uma almofada de meia-medida h
        fn mkVivo nome h z desloc =
        (
            local n = (2 * h) as integer
            local v = Box length:1.2 width:(2 * h + 1.2) height:1.2 widthsegs:n pos:([0, h, z - 0.6] + desloc)
            convertToPoly v
            local outras = #(
                Box length:1.2 width:(2 * h + 1.2) height:1.2 widthsegs:n pos:([0, -h, z - 0.6] + desloc),
                Box length:(2 * h + 1.2) width:1.2 height:1.2 lengthsegs:n pos:([h, 0, z - 0.6] + desloc),
                Box length:(2 * h + 1.2) width:1.2 height:1.2 lengthsegs:n pos:([-h, 0, z - 0.6] + desloc))
            for b in outras do ( convertToPoly b; polyop.attach v b )
            v.name = nome
            v
        )
        InLab_RWF_Feitos = #()
        InLab_UltimoMapear = #()
        InLab_PilhaPaineis = #()
        InLab_UltimoRWF = #(); InLab_UltimoAutoUV = #()
        local js = "{\"produtos\": [{\"cod_est\": \"0002\", \"partes\": [" +
            "{\"nome_parte\": \"Almofada\", \"materia_prima\": {\"familia\": \"Tecido\", \"materia\": \"\"}, \"material_id\": \"ART_PnTecido\"}, " +
            "{\"nome_parte\": \"AlmofadaRW\", \"materia_prima\": {\"familia\": \"Tecido\", \"materia\": \"\"}, \"material_id\": \"ART_PnTecidoRW\"}, " +
            "{\"nome_parte\": \"Pe\", \"materia_prima\": {\"familia\": \"Madeira\", \"materia\": \"Cedro\"}, \"material_id\": \"ART_PnMadeira\"}]}]}"
        local produto = (InLab_Produto_Lista (InLab_ParseJSON js))[1]
        arqImg = gerarImagem "inlab_test_paineis_listras.png"
        local mTec = criarMaterial "ART_PnTecido" arqImg
        local mMad = criarMaterial "ART_PnMadeira" arqImg
        local mRW = criarMaterial "ART_PnTecidoRW" arqImg
        mRW.diffuseMap.coords.realWorldScale = true
        mRW.diffuseMap.coords.realWorldWidth = 50; mRW.diffuseMap.coords.realWorldHeight = 50

        local semMat = mkPeca "TESTE_pn4_semmat" [0,0,-500]
        append criados semMat
        checar "EhTecido: peça sem material não é tecido" ((InLab_Paineis_EhTecido semMat produto) == false)

        -- 1. almofada com vivo (RWF do canal 1 de 80 cm) + peça de madeira na mesma seleção
        local alm = mkPeca "TESTE_pn4_alm" [0,2000,0]
        alm.material = mTec; append criados alm
        local viv = mkVivo "TESTE_pn4_vivo" 50.0 10.0 [0,2000,0]
        viv.material = mTec; append criados viv
        viv.parent = alm
        addModifier alm (Uvwmap name:"InLab RWF Triplanar" maptype:4 length:80 width:80 height:80 mapChannel:1)
        append InLab_RWF_Feitos alm
        local canalVivAntes = InLab_Mapear_LerCanal1 viv
        local mad = mkPeca "TESTE_pn4_madeira" [300,2000,0]
        mad.material = mMad; append criados mad
        local canalMadAntes = InLab_Mapear_LerCanal1 mad
        local modsMadAntes = mad.modifiers.count
        checar "EhTecido: tecido sim, madeira não" ((InLab_Paineis_EhTecido alm produto) and not (InLab_Paineis_EhTecido mad produto))
        logs.count = 0
        local n1 = InLab_Paineis #(alm, mad) produto
        local med1 = InLab_Mapear_Medir alm
        local cm1 = if med1.escala > 0 then 1.0 / med1.escala else 0.0
        linha ("      almofada com vivo: refeitas " + n1 as string + ", " + cm1 as string + " cm por tile")
        checar "Painéis: almofada com vivo é refeita e o log diz '2 painéis pelo vivo'" (n1 == 1 and (temLog logs #ok "TESTE_pn4_alm" "2 painéis pelo vivo"))
        checar "Painéis: RWF do canal 1 sai e a escala vem dele (80 cm)" (alm.modifiers.count == 0 and cm1 > 76.0 and cm1 < 84.0 and (temLog logs #ok "TESTE_pn4_alm" "80,0 cm por tile"))
        checar "Painéis: linha de progresso por peça" (temLog logs #info "TESTE_pn4_alm" "mapeando por painéis (")
        checar "Painéis: o vivo (outra peça) não muda" (igualCanal canalVivAntes (InLab_Mapear_LerCanal1 viv))
        checar "Painéis: peça de madeira na seleção fica idêntica, com #warn 'só para tecido'" ((temLog logs #warn "TESTE_pn4_madeira" "só para tecido") and \
            (igualCanal canalMadAntes (InLab_Mapear_LerCanal1 mad)) and mad.modifiers.count == modsMadAntes)
        checar "Painéis: uma rodada na pilha, com a almofada" (InLab_PilhaPaineis.count == 1 and InLab_PilhaPaineis[1].count == 1 and InLab_PilhaPaineis[1][1].no == alm)
        logs.count = 0
        local d1 = InLab_DesfazerPaineis()
        checar "Desfazer Painéis: RWF de volta e canal 1 de antes" (d1 == 1 and alm.modifiers.count == 1 and (matchPattern alm.modifiers[1].name pattern:"InLab RWF*") and InLab_PilhaPaineis.count == 0)

        -- 2. Multi/Sub: ID 1 tecido (tampo e faixa), ID 2 madeira (fundo)
        local mc = mkPeca "TESTE_pn4_multi" [0,2300,0]
        for f = 1 to (polyop.getNumFaces mc) do polyop.setFaceMatID mc f (if (polyop.getFaceNormal mc f).z < -0.9 then 2 else 1)
        local mm = Multimaterial numsubs:2
        mm.materialList[1] = mTec; mm.materialList[2] = mMad
        mc.material = mm; append criados mc
        local uvMc1 = canalID mc 1, uvMc2 = canalID mc 2
        logs.count = 0
        InLab_Paineis #(mc) produto
        checar "Painéis: Multi/Sub muda só as faces do ID de tecido" ((igualLista uvMc2 (canalID mc 2)) and not (igualLista uvMc1 (canalID mc 1)) and \
            (temLog logs #ok "TESTE_pn4_multi" "painéis"))
        InLab_DesfazerPaineis()

        -- 3. sem produto
        local sp = mkPeca "TESTE_pn4_semprod" [300,2300,0]
        sp.material = mTec; append criados sp
        local canalSp = InLab_Mapear_LerCanal1 sp
        logs.count = 0
        local nSp = InLab_Paineis #(sp) undefined
        checar "Painéis: sem produto, #warn e nada muda" (nSp == 0 and (temLog logs #warn "Painéis" "produto") and (igualCanal canalSp (InLab_Mapear_LerCanal1 sp)) and InLab_PilhaPaineis.count == 0)

        -- 4. sem RWF (bitmap Real-World e a peça fora de InLab_RWF_Feitos)
        local sr = mkPeca "TESTE_pn4_semrwf" [600,2300,0]
        sr.material = mRW; append criados sr
        local canalSr = InLab_Mapear_LerCanal1 sr
        logs.count = 0
        local nSr = InLab_Paineis #(sr) produto
        checar "Painéis: sem RWF, #err e peça pulada" (nSr == 0 and (temLog logs #err "TESTE_pn4_semrwf" "Real World Fix") and (igualCanal canalSr (InLab_Mapear_LerCanal1 sr)))

        -- 5. duas rodadas, dois cliques
        local p = mkPeca "TESTE_pn4_p" [0,2600,0]
        p.material = mTec; append criados p
        local q = mkPeca "TESTE_pn4_q" [300,2600,0]
        q.material = mTec; append criados q
        local p0 = InLab_Mapear_LerCanal1 p, q0 = InLab_Mapear_LerCanal1 q
        InLab_Paineis #(p) produto
        local p1 = InLab_Mapear_LerCanal1 p
        InLab_Paineis #(q) produto
        local okR = InLab_PilhaPaineis.count == 2 and not (igualCanal p0 p1) and not (igualCanal q0 (InLab_Mapear_LerCanal1 q))
        InLab_DesfazerPaineis()
        okR = okR and (igualCanal q0 (InLab_Mapear_LerCanal1 q)) and (igualCanal p1 (InLab_Mapear_LerCanal1 p)) and InLab_PilhaPaineis.count == 1
        InLab_DesfazerPaineis()
        okR = okR and (igualCanal p0 (InLab_Mapear_LerCanal1 p)) and InLab_PilhaPaineis.count == 0
        checar "Desfazer Painéis: duas rodadas, dois cliques, uma de cada vez" okR
        logs.count = 0
        checar "Desfazer Painéis: pilha vazia, #warn e 0" ((InLab_DesfazerPaineis()) == 0 and (temLog logs #warn "Painéis" "nada a desfazer"))

        -- 6. escala depois do Mapear de 200 cm; Desfazer Painéis volta ao estado do Mapear
        fn mkSemUV nome pos =
        (
            local b = Box length:100 width:100 height:20 lengthsegs:10 widthsegs:10 heightsegs:2 mapcoords:false name:nome pos:pos
            convertToPoly b
            polyop.setMapSupport b 1 false
            addModifier b (UVW_Xform name:"InLab RWF" U_Tile:(1.0 / 200) V_Tile:(1.0 / 200) Map_Channel:1)
            b
        )
        local f1 = mkSemUV "TESTE_pn4_f1" [0,2900,0]
        local f2 = mkSemUV "TESTE_pn4_f2" [300,2900,0]
        for o in #(f1, f2) do ( o.material = mTec; append criados o; append InLab_RWF_Feitos o )
        local f1Antes = InLab_Mapear_LerCanal1 f1
        InLab_UltimoMapear = #()
        InLab_Mapear #(f1, f2) produto
        local recF1 = undefined
        for r in InLab_UltimoMapear where r.no == f1 do recF1 = r
        linha ("      cmPorID do Mapear: " + (if recF1 == undefined then "sem registro" else recF1.cmPorID as string))
        local f1M = InLab_Mapear_LerCanal1 f1, f2M = InLab_Mapear_LerCanal1 f2
        logs.count = 0
        InLab_Paineis #(f1) produto
        local medF = InLab_Mapear_Medir f1
        local cmF = if medF.escala > 0 then 1.0 / medF.escala else 0.0
        linha ("      escala depois do Mapear: " + cmF as string + " cm por tile")
        checar "Escala: depois do Mapear de 200 cm, os painéis saem com 200 cm" (f1.modifiers.count == 0 and cmF >= 190.0 and cmF <= 210.0)
        InLab_DesfazerPaineis()
        checar "Desfazer Painéis: volta a peça ao estado do Mapear, sem mexer em outra peça refeita pelo Mapear" \
            ((igualCanal f1M (InLab_Mapear_LerCanal1 f1)) and (igualCanal f2M (InLab_Mapear_LerCanal1 f2)) and f1.modifiers.count == 0 and InLab_UltimoMapear.count == 2)

        -- 7. Desfazer Mapear depois de Painéis: a rodada da peça sai da pilha, a de outra peça fica
        InLab_Paineis #(f1) produto
        InLab_Paineis #(q) produto
        logs.count = 0
        InLab_ReverterMapear()
        local okM = (igualCanal f1Antes (InLab_Mapear_LerCanal1 f1)) and f1.modifiers.count == 1 and InLab_PilhaPaineis.count == 1 and \
            InLab_PilhaPaineis[1].count == 1 and InLab_PilhaPaineis[1][1].no == q
        checar "Desfazer Mapear depois de Painéis: canal 1 de antes do Mapear e pilha sem a peça" okM
        InLab_DesfazerPaineis()
        checar "Desfazer Painéis depois do Desfazer Mapear: a outra peça volta" ((igualCanal q0 (InLab_Mapear_LerCanal1 q)) and InLab_PilhaPaineis.count == 0)

        -- 8. Desfazer UV desfaz antes os painéis
        InLab_UltimoRWF = #(); InLab_UltimoAutoUV = #(); InLab_UltimoMapear = #()
        InLab_Paineis #(p) produto
        logs.count = 0
        local excUV = undefined
        try ( InLab_ReverterAutoUV() ) catch ( excUV = getCurrentException() )
        if excUV != undefined do linha ("      exceção no Desfazer UV: " + excUV)
        checar "Desfazer UV desfaz antes os painéis" (excUV == undefined and (temLog logs #info "Desfazer UV" "desfazendo antes os painéis") and \
            InLab_PilhaPaineis.count == 0 and (igualCanal p0 (InLab_Mapear_LerCanal1 p)))

        -- 9. instância girada
        local i1 = mkPeca "TESTE_pn4_inst1" [0,3200,0]
        i1.material = mTec; append criados i1
        local i2 = instance i1 name:"TESTE_pn4_inst2" pos:[300,3200,0]
        append criados i2
        rotate i2 (eulerAngles 0 0 90)
        local uvI = canalID i1 undefined
        logs.count = 0
        InLab_Paineis #(i1, i2) produto
        checar "Instância girada: mesmo UV nas duas e #warn" ((igualLista (canalID i1 undefined) (canalID i2 undefined)) and \
            not (igualLista uvI (canalID i1 undefined)) and (temLog logs #warn "TESTE_pn4_inst2" "girada") and \
            (contaLog logs "mapeando por painéis" "") == 1 and (InLab_Instancias i1).count == 2)
        InLab_DesfazerPaineis()

        -- 10. peça de ~20 mil faces
        local g20 = ChamferBox length:100 width:100 height:20 fillet:5 Fillet_Segments:4 Length_Segments:84 Width_Segments:84 Height_Segments:8 name:"TESTE_pn4_grande"
        convertToPoly g20
        g20.material = mTec; append criados g20
        logs.count = 0
        local t0 = timeStamp()
        InLab_Paineis #(g20) produto
        local segG = (timeStamp() - t0) / 1000.0
        local segLog = undefined
        for l in logs where (matchPattern l[2] pattern:"Painéis: *") and (findString l[2] " s)") != undefined do
        (
            local s = l[2]
            local i = findString s "em "
            if i != undefined do
            (
                local num = substring s (i + 3) -1
                num = substituteString (substring num 1 ((findString num " s") - 1)) "," "."
                segLog = num as float
            )
        )
        linha ("      20 mil faces: " + segG as string + " s medidos; no log: " + segLog as string)
        checar "Peça de 20 mil faces: tempo no log abaixo de 60 s" (segLog != undefined and segLog < 60.0 and (temLog logs #ok "TESTE_pn4_grande" "painéis"))
        InLab_DesfazerPaineis()
        checar "nenhum nó temporário sobrou" ((for o in objects where (matchPattern o.name pattern:"InLab_tmp*") collect o).count == 0)
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    for o in criados where isValidNode o do try ( delete o ) catch ()
    InLab_RWF_Feitos = feitosAntes
    if arqImg != undefined do try ( deleteFile arqImg ) catch ()
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
