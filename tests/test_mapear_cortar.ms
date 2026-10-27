/*
 tests\test_mapear_cortar.ms — teste de functions\fn_mapear_cortar.ms (Mapear assistido).
 RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear_cortar.txt (PASS/FAIL por item).
 27/10/2026 (Tarefa 2): marcas guardadas na peça (costuras e guias).
 27/10/2026 (Tarefa 3): painéis pelas costuras, piques, corte automático do anel, ids por canto, UVAnel corte:.
 27/10/2026 (Tarefa 4): UV da peça (um Unfold3D), densidade, trama pela regra e pela guia, peça espelhada.
*/
global InLab_Log, InLab_EhGeometria, InLab_Mapear_PolyDe
global InLab_Cortar_LerMarcas, InLab_Cortar_GravarMarcas, InLab_Cortar_ApagarMarcas, InLab_Cortar_TemMarcas
global InLab_CortarMarcas, InLab_CortarPaineis, InLab_Cortar_Paineis, InLab_Cortar_IdsCanto
global InLab_Paineis_PosMundo, InLab_Paineis_UVAnel
global InLab_Cortar_UV, InLab_Paineis_AngDir, InLab_Paineis_NormalArea, InLab_Paineis_Sinal, InLab_Paineis_EspelhoUV
global INLAB_CORTAR_MAX_FACES_UNFOLD
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\inlab_test_mapear_cortar.txt"
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
    fn temLog logs tipo t1 t2 =
    (
        (for l in logs where l[1] == tipo and (findString l[2] t1) != undefined and (findString l[2] t2) != undefined collect l).count > 0
    )
    local nomeCx = "TESTE_cr_caixa"
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
        fileIn (raiz + @"functions\fn_ver_uv.ms")
        fileIn (raiz + @"functions\fn_mapear_paineis.ms")
        fileIn (raiz + @"functions\fn_mapear_cortar.ms")

        local cx = ChamferBox length:100 width:100 height:20 fillet:5 fillet_segments:3 name:nomeCx
        convertToPoly cx
        checar "marcas: sem marca devolve undefined" ((InLab_Cortar_LerMarcas cx) == undefined)

        local mm = InLab_CortarMarcas nFaces:0 nArestas:0 costuras:#{1,5,9} guias:#(#(12, 45.0))
        InLab_Cortar_GravarMarcas cx mm
        local m = InLab_Cortar_LerMarcas cx
        checar "marcas: ida e volta" (m != undefined and m.costuras as string == "#{1, 5, 9}" and m.guias[1][1] == 12 and m.guias[1][2] == 45.0)
        checar "marcas: TemMarcas verdadeiro" (InLab_Cortar_TemMarcas cx)
        linha ("      guias gravadas: " + (getAppData cx 7302))

        holdMaxFile()
        fetchMaxFile quiet:true
        cx = getNodeByName nomeCx
        local m2 = if cx != undefined then InLab_Cortar_LerMarcas cx else undefined
        checar "marcas: sobrevive ao salvar e reabrir" (m2 != undefined and m2.costuras as string == "#{1, 5, 9}" and m2.guias[1][1] == 12 and m2.guias[1][2] == 45.0)

        logs.count = 0
        polyop.deleteFaces cx.baseobject #{1}
        local r = InLab_Cortar_LerMarcas cx
        checar "marcas: topologia mudada descarta com #warn" (r == undefined and temLog logs #warn "a malha mudou" "" and not (InLab_Cortar_TemMarcas cx))
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    -- Tarefa 3: painéis pelas costuras, piques, corte automático do anel, ids por canto
    local nomesT3 = #("TESTE_cr_pn", "TESTE_cr_plano", "TESTE_cr_grande")
    try
    (
        -- costuras pela normal (como a sonda): entre faces com |n.z| > 0,7 e as outras
        fn costurasPelaNormal po =
        (
            local nF = polyop.getNumFaces po
            local deitada = #{}
            for f = 1 to nF do if abs (polyop.getFaceNormal po f).z > 0.7 do deitada[f] = true
            local c = #{}
            for e = 1 to polyop.getNumEdges po do
            (
                local fs = polyop.getEdgeFaces po e
                if fs.count == 2 and deitada[fs[1]] != deitada[fs[2]] do c[e] = true
            )
            c
        )
        local cb = ChamferBox length:100 width:100 height:20 fillet:5 Fillet_Segments:3 Length_Segments:10 Width_Segments:10 Height_Segments:10 name:"TESTE_cr_pn"
        convertToPoly cb
        local po = cb.baseobject
        local nF = polyop.getNumFaces po
        local corpo = #{1..nF}
        local cost = costurasPelaNormal po
        linha ("      ChamferBox: " + nF as string + " faces, " + cost.numberSet as string + " arestas de costura")
        logs.count = 0
        local r = InLab_Cortar_Paineis cb corpo cost
        checar "paineis: caixa com costura no tampo e no fundo dá 3 painéis, 1 anel" (r.paineis.count == 3 and (for a in r.aneis where a collect a).count == 1)
        -- centro da caixa em mundo
        local bb = nodeGetBoundingBox cb (matrix3 1)
        local centro = (bb[1] + bb[2]) / 2.0
        local atras = true
        for v in (polyop.getVertsUsingEdge po r.cortesAuto) do
            if ((polyop.getVert po v) * cb.objectTransform).y <= centro.y do atras = false
        checar "paineis: anel sem pique ganha corte automático atrás" (not r.cortesAuto.isEmpty and atras)
        checar "paineis: corte automático sai no log (#info)" (temLog logs #info "corte automático" "")
        linha ("      corte automático: " + r.cortesAuto.numberSet as string + " arestas")
        checar "paineis: com costura fechada, nenhum pique" (r.piques.isEmpty and r.minusculos == 0)

        local r0 = InLab_Cortar_Paineis cb corpo #{}
        checar "paineis: sem costura, 1 painel por elemento" (r0.paineis.count == 1 and r0.cortesAuto.isEmpty)

        -- aresta solta no meio do tampo: os dois lados no tampo, longe da borda
        local zMax = bb[2].z
        local solta = 0
        for e = 1 to polyop.getNumEdges po while solta == 0 do
        (
            local vs = (polyop.getEdgeVerts po e)
            local p1 = polyop.getVert po vs[1], p2 = polyop.getVert po vs[2]
            if abs (p1.z - zMax) < 0.01 and abs (p2.z - zMax) < 0.01 and abs p1.x < 25 and abs p1.y < 25 and abs p2.x < 25 and abs p2.y < 25 do solta = e
        )
        local rp = InLab_Cortar_Paineis cb corpo (cost + #{solta})
        checar "paineis: aresta solta vira pique" (solta > 0 and rp.piques.numberSet == 1 and rp.piques[solta] and rp.paineis.count == 3)

        -- costura que isola 2 faces vizinhas do tampo
        local fs2 = (polyop.getEdgeFaces po solta) as bitarray
        local ilha = (polyop.getEdgesUsingFace po fs2) - #{solta}
        local rm = InLab_Cortar_Paineis cb corpo ilha
        checar "paineis: painel minúsculo contado" (rm.minusculos == 1 and rm.paineis.count == 2)

        -- InLab_Cortar_IdsCanto: plano 2x2, a linha do meio inteira (2 arestas de borda a borda) como corte
        local pl = Plane length:20 width:20 lengthsegs:2 widthsegs:2 name:"TESTE_cr_plano"
        convertToPoly pl
        local pp = pl.baseobject
        local meio = #{}
        for e = 1 to polyop.getNumEdges pp do
        (
            local vs = polyop.getEdgeVerts pp e
            if abs (polyop.getVert pp vs[1]).x < 0.01 and abs (polyop.getVert pp vs[2]).x < 0.01 do meio[e] = true
        )
        local ic = InLab_Cortar_IdsCanto pp #{1..(polyop.getNumFaces pp)} meio
        checar "ids: corte duplica os vértices da linha" (meio.numberSet == 2 and ic[2] == 12 and ic[1].count == 4)
        local ic0 = InLab_Cortar_IdsCanto pp #{1..(polyop.getNumFaces pp)} #{}
        checar "ids: sem corte, um id por vértice" (ic0[2] == 9)

        -- UVAnel: corte: dado substitui o padrão; o padrão (135° no eixo Z) dá o mesmo de antes
        local banda = undefined
        for k = 1 to r.paineis.count where r.aneis[k] do banda = r.paineis[k]
        local posM = InLab_Paineis_PosMundo cb banda
        local ua = InLab_Paineis_UVAnel po posM banda 3 1.0
        local ub = InLab_Paineis_UVAnel po posM banda 3 1.0 corte:135.0
        local uc = InLab_Paineis_UVAnel po posM banda 3 1.0 corte:45.0
        local igual = ua[1].count == ub[1].count
        if igual do for i = 1 to ua[1].count where (distance ua[1][i] ub[1][i]) > 1e-4 do igual = false
        local difere = ua[1].count != uc[1].count
        if not difere do for i = 1 to ua[1].count where (distance ua[1][i] uc[1][i]) > 1e-3 do difere = true
        checar "uvanel: corte:135 igual ao padrão, corte:45 diferente" (igual and difere)

        -- tempo numa caixa densa (~30 mil faces)
        local gr = ChamferBox length:100 width:100 height:20 fillet:5 Fillet_Segments:4 Length_Segments:100 Width_Segments:100 Height_Segments:30 name:"TESTE_cr_grande"
        convertToPoly gr
        local pg = gr.baseobject
        local costG = costurasPelaNormal pg
        local t0 = timeStamp()
        local rg = InLab_Cortar_Paineis gr #{1..(polyop.getNumFaces pg)} costG
        local seg = (timeStamp() - t0) / 1000.0
        linha ("      caixa densa: " + (polyop.getNumFaces pg) as string + " faces, " + rg.paineis.count as string + " painéis, corte " + rg.cortesAuto.numberSet as string + " arestas, " + seg as string + " s")
        checar "paineis: caixa densa em menos de 15 s, 3 painéis com corte" (seg < 15.0 and rg.paineis.count == 3 and not rg.cortesAuto.isEmpty)
    )
    catch ( linha ("FAIL  exceção no teste (Tarefa 3): " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )
    for n in nomesT3 do ( local s = getNodeByName n; if s != undefined do try ( delete s ) catch () )

    -- Tarefa 4: UV da peça (projeção, um Unfold3D, escala e direção)
    local nomesT4 = #("TESTE_cr_uv", "TESTE_cr_uv_esp")
    try
    (
        local t4 = timeStamp()
        -- ângulo de uma direção (sem sentido) dobrado em [0, 180)
        fn dobra a = ( while a < 0 do a += 180.0; while a >= 180.0 do a -= 180.0; a )
        fn costurasPelaNormal2 po =
        (
            local deitada = #{}
            for f = 1 to polyop.getNumFaces po do if abs (polyop.getFaceNormal po f).z > 0.7 do deitada[f] = true
            local c = #{}
            for e = 1 to polyop.getNumEdges po do
            (
                local fs = polyop.getEdgeFaces po e
                if fs.count == 2 and deitada[fs[1]] != deitada[fs[2]] do c[e] = true
            )
            c
        )
        fn caixaUV nome =
        (
            local c = ChamferBox length:100 width:100 height:20 fillet:5 Fillet_Segments:3 Length_Segments:10 Width_Segments:10 Height_Segments:10 name:nome
            convertToPoly c
            c
        )
        -- subconjunto do mapa com as faces do painel
        fn subDe mapa reg =
        (
            local r = #()
            for e in mapa do if reg[e[1]] do append r e
            r
        )
        -- índices dos painéis: tampo (normal +Z), faixa (anel)
        fn achar o pn =
        (
            local po = o.baseobject
            local tampo = 0, faixa = 0
            for i = 1 to pn.paineis.count do
            (
                if pn.aneis[i] then faixa = i
                else
                (
                    local posM = InLab_Paineis_PosMundo o pn.paineis[i]
                    local n = [0,0,0]
                    for f in pn.paineis[i] do n += InLab_Paineis_NormalArea posM (polyop.getFaceVerts po f) (InLab_Paineis_Sinal o)
                    if (normalize n).z > 0.7 do tampo = i
                )
            )
            #(tampo, faixa)
        )
        fn angulo o pn i uv dir =
        (
            local reg = pn.paineis[i]
            InLab_Paineis_AngDir o.baseobject (InLab_Paineis_PosMundo o reg) uv[1] (subDe uv[2] reg) dir
        )

        -- ângulo só nas faces da frente (normal -Y): no anel desenrolado, X vai para +U na
        -- frente e -U atrás, e a média na volta inteira se anula
        fn anguloFrente o pn i uv dir =
        (
            local reg = pn.paineis[i]
            local posM = InLab_Paineis_PosMundo o reg
            local fr = #{}
            for f in reg do ( local n = InLab_Paineis_NormalArea posM (polyop.getFaceVerts o.baseobject f) 1.0; if (normalize n).y < -0.9 do fr[f] = true )
            InLab_Paineis_AngDir o.baseobject posM uv[1] (subDe uv[2] fr) dir
        )

        local cu = caixaUV "TESTE_cr_uv"
        local pu = cu.baseobject
        local pnU = InLab_Cortar_Paineis cu #{1..(polyop.getNumFaces pu)} (costurasPelaNormal2 pu)
        local esc = for i = 1 to pnU.paineis.count collect (1.0 / 60.0)
        local ix = achar cu pnU
        logs.count = 0
        local tU = timeStamp()
        local uv0 = InLab_Cortar_UV cu pnU esc #()
        linha ("      UV da caixa: " + ((timeStamp() - tU) / 1000.0) as string + " s")
        local okUV = uv0 != undefined and ix[1] > 0 and ix[2] > 0
        local angTampo0 = if okUV then angulo cu pnU ix[1] uv0 [0,1,0] else 0.0
        local angFaixa0 = if okUV then angulo cu pnU ix[2] uv0 [0,0,1] else 0.0
        linha ("      tampo Y: " + angTampo0 as string + "; faixa Z: " + angFaixa0 as string)
        checar "uv: tampo deitado com trama de frente para trás" (okUV and abs ((dobra angTampo0) - 90.0) <= 2.0)
        checar "uv: faixa com trama no eixo do anel (Z)" (okUV and abs ((dobra angFaixa0) - 90.0) <= 2.0)
        checar "uv: contagem pela regra" (okUV and uv0[3] == 0 and uv0[4] == pnU.paineis.count)
        -- densidade: área UV / área 3D de cada painel = (1/60)^2
        local densOk = okUV
        if okUV do for i = 1 to pnU.paineis.count do
        (
            local reg = pnU.paineis[i]
            local posM = InLab_Paineis_PosMundo cu reg
            local a3 = 0.0, auv = 0.0
            for e in (subDe uv0[2] reg) do
            (
                a3 += length (InLab_Paineis_NormalArea posM (polyop.getFaceVerts pu e[1]) 1.0)
                local q = for k in e[2] collect uv0[1][k]
                for j = 2 to q.count - 1 do auv += abs (((q[j] - q[1]).x * (q[j+1] - q[1]).y - (q[j] - q[1]).y * (q[j+1] - q[1]).x) / 2.0)
            )
            local r = (auv / a3) / ((1.0 / 60.0) ^ 2)
            linha ("      painel " + i as string + ": densidade relativa " + r as string)
            if r < 0.9 or r > 1.1 do densOk = false
        )
        checar "uv: densidade de cada ilha dentro de 10% de 1/60" densOk

        -- guia: aresta horizontal (ao longo de X) no meio da faixa, na frente (y = -50, z = 10)
        local guiaE = 0
        for e = 1 to polyop.getNumEdges pu while guiaE == 0 do
        (
            local vs = polyop.getEdgeVerts pu e
            local p1 = polyop.getVert pu vs[1], p2 = polyop.getVert pu vs[2]
            if abs (p1.y + 50) < 0.01 and abs (p2.y + 50) < 0.01 and abs (p1.z - 10) < 0.01 and abs (p2.z - 10) < 0.01 and abs p1.x < 20 do guiaE = e
        )
        local uvG = InLab_Cortar_UV cu pnU esc #(#(guiaE, 0.0))
        local okG = guiaE > 0 and uvG != undefined
        local angFaixaG = if okG then anguloFrente cu pnU ix[2] uvG [1,0,0] else 0.0
        local angTampoG = if okG then angulo cu pnU ix[1] uvG [0,1,0] else 0.0
        linha ("      guia 0: faixa X " + angFaixaG as string + "; tampo Y " + angTampoG as string)
        checar "uv: guia horizontal põe a trama na horizontal só na faixa" (okG and abs ((dobra angFaixaG) - 90.0) <= 2.0 and abs ((dobra angTampoG) - (dobra angTampo0)) <= 1.0 and uvG[3] == 1)
        local uv45 = InLab_Cortar_UV cu pnU esc #(#(guiaE, 45.0))
        local ang45 = if uv45 != undefined then anguloFrente cu pnU ix[2] uv45 [1,0,0] else 0.0
        linha ("      guia 45: faixa X " + ang45 as string)
        -- X a 45 graus da trama (o V)
        checar "uv: guia a 45 graus" (uv45 != undefined and abs ((abs ((dobra ang45) - 90.0)) - 45.0) <= 3.0)
        -- duas guias no mesmo painel: vale a primeira, com #warn
        logs.count = 0
        local outraE = 0
        for e = 1 to polyop.getNumEdges pu while outraE == 0 do
        (
            local vs = polyop.getEdgeVerts pu e
            local p1 = polyop.getVert pu vs[1], p2 = polyop.getVert pu vs[2]
            if e != guiaE and abs (p1.y + 50) < 0.01 and abs (p2.y + 50) < 0.01 and abs (p1.z - 12) < 0.01 and abs (p2.z - 12) < 0.01 do outraE = e
        )
        local uv2g = InLab_Cortar_UV cu pnU esc #(#(guiaE, 0.0), #(outraE, 45.0))
        local ang2g = if uv2g != undefined then anguloFrente cu pnU ix[2] uv2g [1,0,0] else 0.0
        linha ("      duas guias: faixa X " + ang2g as string)
        checar "uv: duas guias no painel, vale a primeira com #warn" (outraE > 0 and uv2g != undefined and abs ((dobra ang2g) - 90.0) <= 2.0 and temLog logs #warn "guia" "")

        -- peça grande demais para o Unfold3D: fica a projeção, com #warn
        local tetoAntes = INLAB_CORTAR_MAX_FACES_UNFOLD
        INLAB_CORTAR_MAX_FACES_UNFOLD = 10
        logs.count = 0
        local uvP = InLab_Cortar_UV cu pnU esc #()
        INLAB_CORTAR_MAX_FACES_UNFOLD = tetoAntes
        local angP = if uvP != undefined then angulo cu pnU ix[1] uvP [0,1,0] else 0.0
        checar "uv: acima do teto fica a projeção, com #warn e trama certa" (uvP != undefined and temLog logs #warn "Unfold3D" "" and abs ((dobra angP) - 90.0) <= 2.0)

        -- espelhada (scale -1 em X), girada 30 graus em Z, pivô longe da origem
        local ce = caixaUV "TESTE_cr_uv_esp"
        ce.scale = [-1, 1, 1]
        rotate ce (eulerAngles 0 0 30)
        ce.pos = [500, 300, 0]
        local pe = ce.baseobject
        local pnE = InLab_Cortar_Paineis ce #{1..(polyop.getNumFaces pe)} (costurasPelaNormal2 pe)
        local ixE = achar ce pnE
        local uvE = InLab_Cortar_UV ce pnE esc #()
        local okE = uvE != undefined and ixE[1] > 0 and ixE[2] > 0
        local espOk = okE
        if okE do for i = 1 to pnE.paineis.count do
        (
            local reg = pnE.paineis[i]
            local es = InLab_Paineis_EspelhoUV pe (InLab_Paineis_PosMundo ce reg) uvE[1] (subDe uvE[2] reg) (InLab_Paineis_Sinal ce)
            linha ("      espelhada, painel " + i as string + ": espelho " + es as string)
            if es >= 0.01 do espOk = false
        )
        checar "uv: peça espelhada e girada sem ilha espelhada" espOk
        local angTampoE = if okE then angulo ce pnE ixE[1] uvE [0,1,0] else 0.0
        local angFaixaE = if okE then angulo ce pnE ixE[2] uvE [0,0,1] else 0.0
        linha ("      espelhada: tampo Y " + angTampoE as string + "; faixa Z " + angFaixaE as string)
        checar "uv: mesmos ângulos da cópia na origem" (okE and abs ((dobra angTampoE) - (dobra angTampo0)) <= 2.0 and abs ((dobra angFaixaE) - (dobra angFaixa0)) <= 2.0)

        local tmps = for n in objects where matchPattern n.name pattern:"InLab_tmp_*" collect n
        checar "uv: nenhum InLab_tmp_* sobra" (tmps.count == 0)
        linha ("      Tarefa 4: " + ((timeStamp() - t4) / 1000.0) as string + " s")
    )
    catch ( linha ("FAIL  exceção no teste (Tarefa 4): " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )
    for n in nomesT4 do ( local s = getNodeByName n; if s != undefined do try ( delete s ) catch () )

    local sobra = getNodeByName nomeCx
    if sobra != undefined do try ( delete sobra ) catch ()
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
