/*
 tests\test_mapear_cortar2.ms — botão Cortar (Mapear assistido, Tarefa 5, 27/10/2026):
 InLab_Cortar (guardas, costuras da seleção ou guardadas, pilha, marcas, seleção no fim,
 Ver UV), Desfazer Painéis devolvendo as marcas, o Mapear pulando peça cortada (também
 depois de reabrir), pique no anel dispensando o corte automático e peça grande com face morta.
 Tarefa 6 (27/10/2026): Ctrl+Z de um Cortar (marcas em custom attribute) e botão Sentido;
 revisão: instância com stack vazio continua instância, seleção no fim só com as costuras.
 Revisão final (27/10/2026): Cortar e Sentido com o painel Modify no nível Aresta da base
 (fluxo real do desenhista): sem erro, instâncias juntas, nível e costuras visíveis no fim.
 RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear_cortar2.txt (PASS/FAIL por item).
*/
global InLab_Log, InLab_EhGeometria, InLab_Mapear_PolyDe
global InLab_ParseJSON, InLab_Produto_Lista, InLab_RWF_Feitos, InLab_RWF_Rodar, InLab_UltimoRWF, InLab_UltimoAutoUV
global InLab_Mapear, InLab_UltimoMapear, InLab_Mapear_LerCanal1, InLab_ReverterMapear
global InLab_PilhaPaineis, InLab_DesfazerPaineis
global InLab_VerUV_Nos, InLab_VerUV_Desligar
global InLab_Cortar_LerMarcas, InLab_Cortar_TemMarcas, InLab_Cortar_ApagarMarcas, InLab_Cortar_Paineis
global InLab_Cortar, InLab_Cortar_SelecaoArestas, InLab_Sentido, InLab_Paineis_PosMundo, InLab_Paineis_AngDir
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_mapear_cortar2.txt"
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
        fileIn (raiz + @"functions\fn_ver_uv.ms")
        fileIn (raiz + @"functions\fn_mapear_paineis.ms")
        fileIn (raiz + @"functions\fn_mapear_cortar.ms")

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
        -- costuras pela normal: entre faces com |n.z| > 0,7 e as outras (tampo, fundo, faixa)
        fn costurasPelaNormal po =
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
        fn caixa nome pos =
        (
            local c = ChamferBox length:100 width:100 height:20 fillet:5 Fillet_Segments:3 Length_Segments:10 Width_Segments:10 Height_Segments:10 name:nome pos:pos
            convertToPoly c
            c
        )
        fn mesmo a b = ( (a as string) == (b as string) )

        InLab_RWF_Feitos = #()
        InLab_UltimoMapear = #()
        InLab_PilhaPaineis = #()
        InLab_UltimoRWF = #(); InLab_UltimoAutoUV = #()
        local js = "{\"produtos\": [{\"cod_est\": \"0002\", \"partes\": [" +
            "{\"nome_parte\": \"Almofada\", \"materia_prima\": {\"familia\": \"Tecido\", \"materia\": \"\"}, \"material_id\": \"ART_CrTecido\"}, " +
            "{\"nome_parte\": \"AlmofadaRW\", \"materia_prima\": {\"familia\": \"Tecido\", \"materia\": \"\"}, \"material_id\": \"ART_CrTecidoRW\"}, " +
            "{\"nome_parte\": \"Pe\", \"materia_prima\": {\"familia\": \"Madeira\", \"materia\": \"Cedro\"}, \"material_id\": \"ART_CrMadeira\"}]}]}"
        local produto = (InLab_Produto_Lista (InLab_ParseJSON js))[1]
        arqImg = gerarImagem "inlab_test_cortar2_listras.png"
        local mTec = criarMaterial "ART_CrTecido" arqImg
        local mMad = criarMaterial "ART_CrMadeira" arqImg
        local mRW = criarMaterial "ART_CrTecidoRW" arqImg
        mRW.diffuseMap.coords.realWorldScale = true
        mRW.diffuseMap.coords.realWorldWidth = 50; mRW.diffuseMap.coords.realWorldHeight = 50

        ---------------- pique no anel dispensa o corte automático (pendência da Tarefa 3) ----------------
        local cp = caixa "TESTE_cr2_pique" [0,-400,0]
        local pp = cp.baseobject
        local costP = costurasPelaNormal pp
        local todasP = #{1..(polyop.getNumFaces pp)}
        local rA = InLab_Cortar_Paineis cp todasP costP
        local faixa = undefined
        for k = 1 to rA.paineis.count where rA.aneis[k] do faixa = rA.paineis[k]
        -- cadeia de arestas internas da faixa no plano x = 0, na frente (y < 0): liga o contorno de cima ao de baixo
        local cadeia = #{}
        if faixa != undefined do
            for e in (polyop.getEdgesUsingFace pp faixa) where not costP[e] do
            (
                local fs = polyop.getEdgeFaces pp e
                local vs = polyop.getEdgeVerts pp e
                local p1 = polyop.getVert pp vs[1], p2 = polyop.getVert pp vs[2]
                if fs.count == 2 and faixa[fs[1]] and faixa[fs[2]] and abs p1.x < 0.01 and abs p2.x < 0.01 and p1.y < 0 and p2.y < 0 do cadeia[e] = true
            )
        local rB = InLab_Cortar_Paineis cp todasP (costP + cadeia)
        linha ("      pique no anel: cadeia " + cadeia.numberSet as string + " arestas; corte automático sem pique " + rA.cortesAuto.numberSet as string + ", com pique " + rB.cortesAuto.numberSet as string)
        checar "paineis: pique de borda a borda no anel dispensa o corte automático" \
            (not rA.cortesAuto.isEmpty and cadeia.numberSet > 0 and rB.cortesAuto.isEmpty and mesmo rB.piques cadeia and rB.paineis.count == 3)
        delete cp

        ---------------- guardas ----------------
        -- sem produto
        local g1 = caixa "TESTE_cr2_g1" [300,-400,0]
        g1.material = mTec
        polyop.setEdgeSelection g1.baseobject (costurasPelaNormal g1.baseobject)
        local cg0 = InLab_Mapear_LerCanal1 g1
        logs.count = 0
        local n0 = InLab_Cortar #(g1) undefined
        checar "cortar: sem produto, #warn e nada muda" (n0 == 0 and temLog logs #warn "produto" "" and igualCanal cg0 (InLab_Mapear_LerCanal1 g1))
        -- duas peças
        local g2 = caixa "TESTE_cr2_g2" [600,-400,0]
        g2.material = mTec
        logs.count = 0
        local n2 = InLab_Cortar #(g1, g2) produto
        checar "cortar: uma peça só" (n2 == 0 and temLog logs #warn "selecione uma peça de tecido só" "" and igualCanal cg0 (InLab_Mapear_LerCanal1 g1))
        logs.count = 0
        local nz = InLab_Cortar #() produto
        checar "cortar: nenhuma peça, #warn" (nz == 0 and temLog logs #warn "selecione uma peça de tecido só" "")
        -- sem RWF: material com Real-World e sem o Real World Fix
        g2.material = mRW
        logs.count = 0
        local nr = InLab_Cortar #(g2) produto
        checar "cortar: sem RWF, #warn e nada muda" (nr == 0 and (temLog logs #warn "Real World Fix" "") and InLab_PilhaPaineis.count == 0)
        -- não é tecido
        g2.material = mMad
        polyop.setEdgeSelection g2.baseobject (costurasPelaNormal g2.baseobject)
        logs.count = 0
        local nt = InLab_Cortar #(g2) produto
        checar "cortar: peça que não é tecido, #warn" (nt == 0 and temLog logs #warn "tecido" "" and InLab_PilhaPaineis.count == 0)
        -- sem seleção e sem marcas
        g2.material = mTec
        polyop.setEdgeSelection g2.baseobject #{}
        local cg2 = InLab_Mapear_LerCanal1 g2
        logs.count = 0
        local ns = InLab_Cortar #(g2) produto
        checar "cortar: pede as costuras e nada muda" (ns == 0 and temLog logs #warn "selecione as arestas" "" and igualCanal cg2 (InLab_Mapear_LerCanal1 g2) and InLab_PilhaPaineis.count == 0)
        -- seleção de arestas num Edit_Poly do stack, nenhuma na base
        local ep = Edit_Poly()
        addModifier g2 ep
        -- Edit_Poly por script: só com o nó selecionado, o modificador corrente e subObjectLevel de aresta
        select g2
        max modify mode
        modPanel.setCurrentObject ep
        subObjectLevel = 2
        local okSel = try ( ep.Select #Edge #{1..20} ) catch ( linha ("      Select: " + getCurrentException()); false )
        subObjectLevel = 0
        local selMod = try ( (ep.GetSelection #Edge node:g2).numberSet ) catch ( -1 )
        clearSelection()
        linha ("      Edit_Poly: SetSelection " + okSel as string + ", arestas no modificador " + selMod as string)
        logs.count = 0
        local ne = InLab_Cortar #(g2) produto
        checar "cortar: seleção no stack não vale" (ne == 0 and selMod > 0 and temLog logs #warn "selecione as arestas" "" and InLab_PilhaPaineis.count == 0)
        deleteModifier g2 ep
        -- base Editable_Mesh
        local gm = ChamferBox length:100 width:100 height:20 fillet:5 Fillet_Segments:3 name:"TESTE_cr2_mesh" pos:[900,-400,0]
        convertToMesh gm
        gm.material = mTec
        logs.count = 0
        local nm = InLab_Cortar #(gm) produto
        checar "cortar: base não-poly recusada sem converter" (nm == 0 and (classof gm.baseobject) == Editable_Mesh and temLog logs #warn "converta a base" "")
        delete #(g1, g2, gm)

        ---------------- Cortar, Recortar, Desfazer ----------------
        local cx = caixa "TESTE_cr2_caixa" [0,0,0]
        cx.material = mRW
        InLab_RWF_Rodar #(cx)
        local nModsRWF = cx.modifiers.count
        local po = cx.baseobject
        local cost = costurasPelaNormal po
        local c0 = InLab_Mapear_LerCanal1 cx
        local pnRef = InLab_Cortar_Paineis cx #{1..(polyop.getNumFaces po)} cost
        polyop.setEdgeSelection po cost
        logs.count = 0
        local n1 = InLab_Cortar #(cx) produto
        local c1 = InLab_Mapear_LerCanal1 cx
        checar "cortar: 3 painéis, canal 1 gravado, Ver UV ligado" \
            (n1 == 1 and temLog logs #ok "3 painéis pelas costuras" "cm por tile" and not (igualCanal c0 c1) and \
             (findItem InLab_VerUV_Nos cx) > 0 and InLab_PilhaPaineis.count == 1 and cx.modifiers.count < nModsRWF)
        local m1 = InLab_Cortar_LerMarcas cx
        checar "cortar: marcas guardadas" (InLab_Cortar_TemMarcas cx and m1 != undefined and mesmo m1.costuras cost)
        local sel1 = InLab_Cortar_SelecaoArestas cx
        -- revisão da Tarefa 6: a seleção volta só às costuras; o corte automático vai para o log
        checar "cortar: seleção volta às costuras (corte automático só no log)"             (not pnRef.cortesAuto.isEmpty and mesmo sel1 cost and temLog logs #info "corte automático do anel com" (pnRef.cortesAuto.numberSet as string))
        checar "cortar: log por etapa (painéis, Unfold3D, gravação)" \
            ((temLog logs #info "TESTE_cr2_caixa" "painéis") and (temLog logs #info "TESTE_cr2_caixa" "Unfold3D") and (temLog logs #info "TESTE_cr2_caixa" "gravação"))

        -- Mapear pula a peça cortada
        logs.count = 0
        InLab_Mapear #(cx) produto
        checar "mapear: pula peça cortada" (temLog logs #info "peça cortada nas costuras" "" and igualCanal c1 (InLab_Mapear_LerCanal1 cx))
        if InLab_UltimoMapear.count > 0 do InLab_ReverterMapear()

        -- sem seleção e com marcas
        -- Tarefa 6: o Cortar troca a base por uma cópia (Ctrl+Z); relê a base depois de cada Cortar
        po = cx.baseobject
        polyop.setEdgeSelection po #{}
        logs.count = 0
        local n2c = InLab_Cortar #(cx) produto
        checar "cortar: usa as costuras guardadas" \
            (n2c == 1 and InLab_PilhaPaineis.count == 2 and temLog logs #ok "3 painéis pelas costuras" "" and mesmo (InLab_Cortar_SelecaoArestas cx) cost)

        -- Recortar com uma aresta solta no tampo (pique)
        po = cx.baseobject
        local bb = nodeGetBoundingBox cx (matrix3 1)
        local zMax = bb[2].z
        local solta = 0
        for e = 1 to polyop.getNumEdges po while solta == 0 do
        (
            local vs = polyop.getEdgeVerts po e
            local p1 = (polyop.getVert po vs[1]) * cx.objectTransform, p2 = (polyop.getVert po vs[2]) * cx.objectTransform
            if abs (p1.z - zMax) < 0.01 and abs (p2.z - zMax) < 0.01 and abs p1.x < 25 and abs p1.y < 25 and abs p2.x < 25 and abs p2.y < 25 do solta = e
        )
        polyop.setEdgeSelection po (cost + #{solta})
        logs.count = 0
        local n3 = InLab_Cortar #(cx) produto
        local m3 = InLab_Cortar_LerMarcas cx
        checar "cortar: recorte com pique (log e seleção com o pique)" \
            (n3 == 1 and solta > 0 and temLog logs #ok "(1 piques)" "" and temLog logs #info "pique" "" and \
             m3 != undefined and mesmo m3.costuras (cost + #{solta}) and mesmo (InLab_Cortar_SelecaoArestas cx) (cost + #{solta}))

        -- Desfazer: volta as marcas de antes; até o fim, o canal 1 de antes do 1º Cortar e sem marcas
        logs.count = 0
        InLab_DesfazerPaineis()
        local m2d = InLab_Cortar_LerMarcas cx
        local okD1 = m2d != undefined and mesmo m2d.costuras cost
        InLab_DesfazerPaineis()
        InLab_DesfazerPaineis()
        checar "cortar: Desfazer volta o canal 1 exato e as marcas de antes" \
            (okD1 and igualCanal c0 (InLab_Mapear_LerCanal1 cx) and not (InLab_Cortar_TemMarcas cx) and InLab_PilhaPaineis.count == 0 and cx.modifiers.count == nModsRWF)
        InLab_VerUV_Desligar()
        delete cx

        ---------------- Ctrl+Z de um Cortar (Tarefa 6: marcas em custom attribute) ----------------
        local cz = caixa "TESTE_cr2_ctrlz" [0,-800,0]
        cz.material = mTec
        local pz = cz.baseobject
        local cz0 = InLab_Mapear_LerCanal1 cz
        polyop.setEdgeSelection pz (costurasPelaNormal pz)
        local nz1 = InLab_Cortar #(cz) produto
        local okZ1 = nz1 == 1 and InLab_Cortar_TemMarcas cz and not (igualCanal cz0 (InLab_Mapear_LerCanal1 cz))
        InLab_VerUV_Desligar()
        max undo
        linha ("      ctrl+z: canal antes " + (cz0 != undefined) as string + ", depois " + ((InLab_Mapear_LerCanal1 cz) != undefined) as string + ", cortou " + okZ1 as string + ", canal igual " + (igualCanal cz0 (InLab_Mapear_LerCanal1 cz)) as string + ", marcas " + (InLab_Cortar_TemMarcas cz) as string)
        checar "cortar: Ctrl+Z volta canal 1 e marcas" (okZ1 and igualCanal cz0 (InLab_Mapear_LerCanal1 cz) and not (InLab_Cortar_TemMarcas cz))
        -- revisão da Tarefa 6: dois Cortar seguidos sem mexer na seleção
        local costZ = costurasPelaNormal cz.baseobject
        polyop.setEdgeSelection cz.baseobject costZ
        InLab_Cortar #(cz) produto
        logs.count = 0
        local nz2 = InLab_Cortar #(cz) produto
        local mz2 = InLab_Cortar_LerMarcas cz
        checar "cortar: Cortar duas vezes seguidas não guarda o corte automático como costura"             (nz2 == 1 and temLog logs #ok "3 painéis pelas costuras (0 piques)" "" and mz2 != undefined and mesmo mz2.costuras costZ and              mesmo (InLab_Cortar_SelecaoArestas cz) costZ and temLog logs #info "corte automático do anel com" "")
        InLab_VerUV_Desligar()
        InLab_PilhaPaineis = #()
        delete cz

        ---------------- Sentido (Tarefa 6) ----------------
        -- ângulo do X do mundo no UV, medido nas faces fs (canal 1 atual da base)
        fn angX o fs =
        (
            local p = o.baseobject
            local posM = InLab_Paineis_PosMundo o fs
            local uvs = for i = 1 to (polyop.getNumMapVerts p 1) collect (polyop.getMapVert p 1 i)
            local sub = for f in fs collect #(f, polyop.getMapFace p 1 f)
            InLab_Paineis_AngDir p posM uvs sub [1,0,0]
        )
        -- UV por canto de face (posições), para comparar sem depender dos índices
        fn cantos o fs =
        (
            local p = o.baseobject
            for f in fs collect (for mv in (polyop.getMapFace p 1 f) collect (polyop.getMapVert p 1 mv))
        )
        fn igualCantos a b =
        (
            local ok = a.count == b.count
            for k = 1 to a.count while ok do
            (
                if a[k].count != b[k].count then ok = false
                else for j = 1 to a[k].count do if (distance a[k][j] b[k][j]) > 1e-5 do ok = false
            )
            ok
        )
        local cs = caixa "TESTE_cr2_sentido" [0,800,0]
        cs.material = mTec
        local costS = costurasPelaNormal cs.baseobject
        local cs0 = InLab_Mapear_LerCanal1 cs
        polyop.setEdgeSelection cs.baseobject costS
        local nS0 = InLab_Cortar #(cs) produto
        local ps = cs.baseobject
        local pnS = InLab_Cortar_Paineis cs #{1..(polyop.getNumFaces ps)} costS
        local faixaS = #{}, tampoFundo = #{}
        for k = 1 to pnS.paineis.count do if pnS.aneis[k] then faixaS = pnS.paineis[k] else tampoFundo += pnS.paineis[k]
        -- frente da faixa (normal -Y) e duas guias horizontais (ao longo de X) nela, longe das costuras
        local frente = for f in faixaS where (polyop.getFaceNormal ps f).y < -0.9 collect f
        frente = frente as bitarray
        local guias = #()
        for e in (polyop.getEdgesUsingFace ps frente) where not costS[e] and not pnS.cortesAuto[e] do
        (
            local vs = polyop.getEdgeVerts ps e
            local p1 = (polyop.getVert ps vs[1]) * cs.objectTransform, p2 = (polyop.getVert ps vs[2]) * cs.objectTransform
            if abs (p1.z - p2.z) < 0.01 and (abs (p1.x - p2.x)) > 1.0 and abs p1.x < 30 and p1.z > 5 and p1.z < 15 and \
               (for f in (polyop.getEdgeFaces ps e) where frente[f] collect f).count == 2 do append guias e
        )
        local guia = if guias.count > 0 then guias[1] else 0
        local angAntes = angX cs frente
        local tf0 = cantos cs tampoFundo
        local cS1 = InLab_Mapear_LerCanal1 cs
        linha ("      sentido: faixa " + faixaS.numberSet as string + " faces, guias candidatas " + guias.count as string + ", X no UV antes " + angAntes as string)
        polyop.setEdgeSelection ps #{guia}
        logs.count = 0
        local nS = InLab_Sentido #(cs) 0.0 produto:produto
        local angDepois = angX cs frente
        local mS = InLab_Cortar_LerMarcas cs
        linha ("      sentido: X no UV depois " + angDepois as string)
        checar "sentido: só a faixa muda" \
            (nS0 == 1 and guia > 0 and nS == 1 and abs ((abs angAntes) - 90.0) > 45.0 and abs ((abs angDepois) - 90.0) < 5.0 and \
             igualCantos tf0 (cantos cs tampoFundo) and temLog logs #ok "sentido de 1 painel(is) ajustado" "" and \
             mS != undefined and mS.guias.count == 1 and mS.guias[1][1] == guia and mS.guias[1][2] == 0.0 and \
             mesmo (InLab_Cortar_SelecaoArestas cs) costS and InLab_PilhaPaineis.count == 1)
        max undo
        local mZ = InLab_Cortar_LerMarcas cs
        checar "sentido: Ctrl+Z desfaz" (igualCanal cS1 (InLab_Mapear_LerCanal1 cs) and mZ != undefined and mZ.guias.count == 0)
        -- guia numa aresta de costura
        local eCost = 0
        for e in costS while eCost == 0 do eCost = e
        polyop.setEdgeSelection cs.baseobject #{eCost}
        logs.count = 0
        local nC = InLab_Sentido #(cs) 0.0 produto:produto
        checar "sentido: guia em costura recusada" (nC == 0 and temLog logs #warn "costura" "" and igualCanal cS1 (InLab_Mapear_LerCanal1 cs))
        -- duas guias no mesmo painel: vale a primeira
        polyop.setEdgeSelection cs.baseobject (#{guia} + (if guias.count > 1 then #{guias[guias.count]} else #{}))
        logs.count = 0
        local n2g = InLab_Sentido #(cs) 30.0 produto:produto
        local m2g = InLab_Cortar_LerMarcas cs
        checar "sentido: duas guias no painel, #warn e vale a primeira" \
            (guias.count > 1 and n2g == 1 and temLog logs #warn "mais de uma guia" "" and m2g.guias.count == 1 and m2g.guias[1][1] == guia and m2g.guias[1][2] == 30.0)
        max undo
        -- guia de novo (0 grau) e Cortar sem mexer na seleção (volta às costuras)
        polyop.setEdgeSelection cs.baseobject #{guia}
        InLab_Sentido #(cs) 0.0 produto:produto
        local cS2 = InLab_Mapear_LerCanal1 cs
        logs.count = 0
        local nCs = InLab_Cortar #(cs) produto
        local mCs = InLab_Cortar_LerMarcas cs
        local angCs = angX cs frente
        checar "cortar depois de sentido: mesmo corte e guia mantida" \
            (nCs == 1 and temLog logs #ok "3 painéis pelas costuras (0 piques), 1 com guia" "" and mCs != undefined and mesmo mCs.costuras costS and \
             mCs.guias.count == 1 and mCs.guias[1][1] == guia and abs ((abs angCs) - 90.0) < 5.0 and InLab_PilhaPaineis.count == 2)
        -- Desfazer Painéis: o 1º volta para depois do Sentido; o 2º para antes do 1º Cortar (sem marcas)
        InLab_DesfazerPaineis()
        local mD1 = InLab_Cortar_LerMarcas cs
        local okD1 = igualCanal cS2 (InLab_Mapear_LerCanal1 cs) and mD1 != undefined and mD1.guias.count == 1
        InLab_DesfazerPaineis()
        checar "sentido: Desfazer Painéis volta para antes do Cortar" \
            (okD1 and igualCanal cs0 (InLab_Mapear_LerCanal1 cs) and not (InLab_Cortar_TemMarcas cs) and InLab_PilhaPaineis.count == 0)
        -- sem marcas
        polyop.setEdgeSelection cs.baseobject #{guia}
        logs.count = 0
        local nSm = InLab_Sentido #(cs) 0.0 produto:produto
        checar "sentido: peça sem corte pede o Cortar" (nSm == 0 and temLog logs #warn "corte a peça antes" "")
        InLab_VerUV_Desligar()
        delete cs

        ---------------- instância com o stack vazio (revisão da Tarefa 6) ----------------
        -- a troca da base (Ctrl+Z) não pode separar as instâncias
        fn nInst o = ( local ins = #(); InstanceMgr.GetInstances o &ins; ins.count )
        fn juntas a b = ( (nInst a) == 2 and a.baseobject == b.baseobject and igualCanal (InLab_Mapear_LerCanal1 a) (InLab_Mapear_LerCanal1 b) )
        local ia = caixa "TESTE_cr2_instA" [0,1200,0]
        ia.material = mTec
        local ib = instance ia
        ib.name = "TESTE_cr2_instB"
        ib.pos = [300,1200,0]
        local ci0 = InLab_Mapear_LerCanal1 ia
        local costI = costurasPelaNormal ia.baseobject
        polyop.setEdgeSelection ia.baseobject costI
        local nI = InLab_Cortar #(ia) produto
        checar "instância sem stack: Cortar mantém as 2 instâncias" (nI == 1 and ia.modifiers.count == 0 and juntas ia ib and not (igualCanal ci0 (InLab_Mapear_LerCanal1 ib)))
        local ciC = InLab_Mapear_LerCanal1 ia
        -- guia horizontal na frente da faixa
        local pInst = ia.baseobject
        local pnI = InLab_Cortar_Paineis ia #{1..(polyop.getNumFaces pInst)} costI
        local guiaI = 0
        for k = 1 to pnI.paineis.count where pnI.aneis[k] do
            for e in (polyop.getEdgesUsingFace pInst pnI.paineis[k]) where guiaI == 0 and not costI[e] and not pnI.cortesAuto[e] do
            (
                local vs = polyop.getEdgeVerts pInst e
                local p1 = polyop.getVert pInst vs[1], p2 = polyop.getVert pInst vs[2]
                if abs (p1.z - p2.z) < 0.01 and (abs (p1.x - p2.x)) > 1.0 and abs p1.x < 30 and p1.y < -40 and p1.z > 5 and p1.z < 15 do guiaI = e
            )
        polyop.setEdgeSelection pInst #{guiaI}
        local nIS = InLab_Sentido #(ia) 0.0 produto:produto
        checar "instância sem stack: Sentido mantém as 2 instâncias" (guiaI > 0 and nIS == 1 and juntas ia ib and not (igualCanal ciC (InLab_Mapear_LerCanal1 ib)))
        max undo
        checar "instância sem stack: Ctrl+Z do Sentido mantém as 2 instâncias" (juntas ia ib and igualCanal ciC (InLab_Mapear_LerCanal1 ib))
        InLab_VerUV_Desligar()
        InLab_DesfazerPaineis()
        checar "instância sem stack: Desfazer Painéis volta as 2 instâncias" \
            (juntas ia ib and igualCanal ci0 (InLab_Mapear_LerCanal1 ia) and igualCanal ci0 (InLab_Mapear_LerCanal1 ib) and not (InLab_Cortar_TemMarcas ib) and InLab_PilhaPaineis.count == 0)
        delete #(ia, ib)

        ---------------- fluxo do desenhista: painel Modify no nível Aresta da base (revisão final) ----------------
        -- as arestas são selecionadas no nível 2 da Editable Poly (não por polyop em nível de objeto)
        local sa = caixa "TESTE_cr2_soA" [0,1600,0]
        sa.material = mTec
        local sb = instance sa
        sb.name = "TESTE_cr2_soB"
        sb.pos = [300,1600,0]
        local costSO = costurasPelaNormal sa.baseobject
        select sa
        max modify mode
        modPanel.setCurrentObject sa.baseobject
        subObjectLevel = 2
        sa.baseobject.EditablePoly.SetSelection #Edge costSO
        logs.count = 0
        local nSO = try ( InLab_Cortar (selection as array) produto ) catch ( linha ("      cortar no nível Aresta: " + getCurrentException()); -1 )
        linha ("      nível Aresta, depois do Cortar: subObjectLevel " + subObjectLevel as string + ", seleção " + ((for n in selection collect n.name) as string))
        checar "nível Aresta: Cortar sem erro, instâncias juntas, volta ao nível Aresta com as costuras selecionadas"             (nSO == 1 and (for l in logs where l[1] == #err collect l).count == 0 and juntas sa sb and subObjectLevel == 2 and              (modPanel.getCurrentObject()) == sa.baseobject and mesmo (InLab_Cortar_SelecaoArestas sa) costSO)
        -- guia escolhida no mesmo nível Aresta
        local pSO = sa.baseobject
        local pnSO = InLab_Cortar_Paineis sa #{1..(polyop.getNumFaces pSO)} costSO
        local guiaSO = 0
        for k = 1 to pnSO.paineis.count where pnSO.aneis[k] do
            for e in (polyop.getEdgesUsingFace pSO pnSO.paineis[k]) where guiaSO == 0 and not costSO[e] and not pnSO.cortesAuto[e] do
            (
                local vs = polyop.getEdgeVerts pSO e
                local p1 = polyop.getVert pSO vs[1], p2 = polyop.getVert pSO vs[2]
                if abs (p1.z - p2.z) < 0.01 and (abs (p1.x - p2.x)) > 1.0 and abs p1.x < 30 and p1.y < -40 and p1.z > 5 and p1.z < 15 do guiaSO = e
            )
        local soOk = subObjectLevel == 2
        if not soOk do ( modPanel.setCurrentObject sa.baseobject; subObjectLevel = 2 )
        sa.baseobject.EditablePoly.SetSelection #Edge #{guiaSO}
        logs.count = 0
        local nSSO = try ( InLab_Sentido (selection as array) 0.0 produto:produto ) catch ( linha ("      sentido no nível Aresta: " + getCurrentException()); -1 )
        checar "nível Aresta: Sentido sem erro, instâncias juntas, nível Aresta e costuras selecionadas"             (guiaSO > 0 and nSSO == 1 and (for l in logs where l[1] == #err collect l).count == 0 and juntas sa sb and subObjectLevel == 2 and              mesmo (InLab_Cortar_SelecaoArestas sa) costSO)
        subObjectLevel = 0
        clearSelection()
        InLab_VerUV_Desligar()
        InLab_PilhaPaineis = #()
        delete #(sa, sb)

        ---------------- peça grande com face morta ----------------
        local gr = ChamferBox length:100 width:100 height:20 fillet:5 Fillet_Segments:4 Length_Segments:100 Width_Segments:100 Height_Segments:30 name:"TESTE_cr2_grande" pos:[0,400,0]
        convertToPoly gr
        gr.material = mTec
        local pg = gr.baseobject
        local costG = costurasPelaNormal pg
        local nFG = polyop.getNumFaces pg
        -- face morta no meio do tampo (longe das costuras)
        local morta = 0
        for f = 1 to nFG while morta == 0 do
        (
            local c = polyop.getFaceCenter pg f
            if c.z > 19.9 and abs c.x < 3 and abs c.y < 3 do morta = f
        )
        polyop.setEdgeSelection pg costG
        polyop.setFaceFlags pg #{morta} 2 mask:2 undoable:false
        logs.count = 0
        local tG = timeStamp()
        local nG = InLab_Cortar #(gr) produto
        local segG = (timeStamp() - tG) / 1000.0
        linha ("      peça grande: " + nFG as string + " faces, " + segG as string + " s")
        local tmps = for n in objects where matchPattern n.name pattern:"InLab_tmp_*" collect n
        checar "cortar: peça grande com face morta em menos de 60 s" \
            (morta > 0 and nG == 1 and segG < 60.0 and temLog logs #ok "3 painéis pelas costuras" "" and tmps.count == 0 and InLab_Cortar_TemMarcas gr)
        InLab_VerUV_Desligar()

        ---------------- reabrir ----------------
        holdMaxFile()
        fetchMaxFile quiet:true
        local gr2 = getNodeByName "TESTE_cr2_grande"
        logs.count = 0
        if gr2 != undefined do InLab_Mapear #(gr2) produto
        checar "cortar: depois de reabrir, o Mapear ainda pula a peça" (gr2 != undefined and temLog logs #info "peça cortada nas costuras" "")
        if InLab_UltimoMapear.count > 0 do InLab_ReverterMapear()
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    InLab_PilhaPaineis = #()
    InLab_UltimoMapear = #()
    try ( InLab_VerUV_Desligar() ) catch ()
    for n in (for o in objects where matchPattern o.name pattern:"TESTE_cr2_*" collect o) where isValidNode n do try ( delete n ) catch ()
    InLab_RWF_Feitos = feitosAntes
    if arqImg != undefined do try ( deleteFile arqImg ) catch ()
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
