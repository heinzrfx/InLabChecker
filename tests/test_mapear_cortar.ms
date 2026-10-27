/*
 tests\test_mapear_cortar.ms — teste de functions\fn_mapear_cortar.ms (Mapear assistido).
 RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear_cortar.txt (PASS/FAIL por item).
 27/10/2026 (Tarefa 2): marcas guardadas na peça (costuras e guias).
 27/10/2026 (Tarefa 3): painéis pelas costuras, piques, corte automático do anel, ids por canto, UVAnel corte:.
*/
global InLab_Log, InLab_EhGeometria, InLab_Mapear_PolyDe
global InLab_Cortar_LerMarcas, InLab_Cortar_GravarMarcas, InLab_Cortar_ApagarMarcas, InLab_Cortar_TemMarcas
global InLab_CortarMarcas, InLab_CortarPaineis, InLab_Cortar_Paineis, InLab_Cortar_IdsCanto
global InLab_Paineis_PosMundo, InLab_Paineis_UVAnel
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

    local sobra = getNodeByName nomeCx
    if sobra != undefined do try ( delete sobra ) catch ()
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
