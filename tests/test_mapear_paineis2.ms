/*
 tests\test_mapear_paineis2.ms — segunda parte do teste de functions\fn_mapear_paineis.ms:
 os casos da revisão final da feature (26/10/2026). Separado de test_mapear_paineis.ms para
 cada arquivo rodar em menos de 120 s pelo MCP. RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear_paineis2.txt (PASS/FAIL por item).
 Casos: RWF -> Painéis -> Mapear -> Desfazer UV; Ver UV ligado e bitmap usado fora da
 seleção (Painéis e Mapear); escala por ID; vivo interno com o RWF no canal 2; exceção
 forçada sem InLab_tmp_* sobrando; varredura final dos temporários.
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
global InLab_VerUV_Ligar, InLab_VerUV_Desligar
-- revisão final (26/10/2026)
global InLab_Paineis_MontarGrade, InLab_Paineis_Dist, InLab_Paineis_ForcarFalha, MapearRecord, InLab_RWF_Rodar
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_mapear_paineis2.txt"
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
        fileIn (raiz + @"functions\fn_ver_uv.ms")
        fileIn (raiz + @"functions\fn_mapear_paineis.ms")

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

        fn criarMaterialC2 arq =
        (
            local b = Bitmaptexture filename:arq
            b.coords.mapChannel = 2
            Standardmaterial name:"ART_PnTecido" diffuseMap:b
        )
        fn rwfCanal2 o = ( addModifier o (Uvwmap name:"InLab RWF Triplanar" maptype:4 length:50 width:50 height:50 mapChannel:2) )

        -- RWF de verdade -> Painéis -> Mapear -> Desfazer UV: volta o canal 1 e o stack de antes do RWF
        InLab_UltimoRWF = #(); InLab_UltimoAutoUV = #(); InLab_UltimoMapear = #(); InLab_PilhaPaineis = #()
        local mRW2 = criarMaterial "ART_PnTecidoRW" arqImg
        mRW2.diffuseMap.coords.realWorldScale = true
        mRW2.diffuseMap.coords.realWorldWidth = 50; mRW2.diffuseMap.coords.realWorldHeight = 50
        local pr = mkPeca "TESTE_pn4_rwfpm" [300,4700,0]
        pr.material = mRW2; append criados pr
        local cPr0 = InLab_Mapear_LerCanal1 pr
        local nModsPr0 = pr.modifiers.count
        InLab_RWF_Rodar #(pr)
        local nModsRWF = pr.modifiers.count
        InLab_Paineis #(pr) produto
        local okPr = nModsRWF > nModsPr0 and InLab_PilhaPaineis.count == 1
        -- o tecido passa a ler o canal 2 de um RWF: sem a regra, o Mapear refaria a peça
        local mC2p = criarMaterialC2 arqImg
        pr.material = mC2p
        rwfCanal2 pr
        local modC2p = pr.modifiers[1]
        logs.count = 0
        InLab_Mapear #(pr) produto
        okPr = okPr and (temLog logs #info "TESTE_pn4_rwfpm" "tem painéis")
        -- volta o que o teste trocou à mão (material e o modificador do canal 2)
        if (findItem (for m in pr.modifiers collect m) modC2p) > 0 do deleteModifier pr modC2p
        pr.material = mRW2
        logs.count = 0
        local excPr = undefined
        try ( InLab_ReverterAutoUV() ) catch ( excPr = getCurrentException() )
        if excPr != undefined do linha ("      exceção no Desfazer UV: " + excPr)
        linha ("      RWF → Painéis → Mapear → Desfazer UV: mods " + pr.modifiers.count as string + " (antes " + nModsPr0 as string + ", com RWF " + nModsRWF as string + ")")
        checar "RWF → Painéis → Mapear → Desfazer UV volta canal 1 e stack de antes do RWF" \
            (okPr and excPr == undefined and (igualCanal cPr0 (InLab_Mapear_LerCanal1 pr)) and pr.modifiers.count == nModsPr0 and \
             mRW2.diffuseMap.coords.realWorldScale and InLab_PilhaPaineis.count == 0 and InLab_UltimoMapear.count == 0)
        InLab_UltimoRWF = #(); InLab_UltimoAutoUV = #(); InLab_UltimoMapear = #(); InLab_PilhaPaineis = #()

        ---------------- revisão final (26/10/2026) ----------------
        InLab_UltimoMapear = #(); InLab_PilhaPaineis = #()
        -- Ver UV ligado no produto: refs.dependentNodes não vê a peça com as listras
        local mC2v = criarMaterialC2 arqImg
        local vx = mkPeca "TESTE_pn4_vux" [0,4100,0]
        local vy = mkPeca "TESTE_pn4_vuy" [300,4100,0]
        for o in #(vx, vy) do ( o.material = mC2v; append criados o; rwfCanal2 o; append InLab_RWF_Feitos o )
        InLab_VerUV_Ligar #(vx, vy)
        logs.count = 0
        InLab_Paineis #(vx) produto
        local okVP = mC2v.diffuseMap.coords.mapChannel == 2 and (temLog logs #warn "TESTE_pn4_vux" "fora desta rodada") and \
            vy.modifiers.count == 1 and (temLog logs #warn "TESTE_pn4_vux" "continua lendo o canal 2")
        InLab_DesfazerPaineis tudo:true
        mC2v.diffuseMap.coords.mapChannel = 2
        logs.count = 0
        InLab_Mapear #(vx) produto
        local okVM = mC2v.diffuseMap.coords.mapChannel == 2 and (temLog logs #warn "TESTE_pn4_vux" "fora desta rodada") and vy.modifiers.count == 1
        if InLab_UltimoMapear.count > 0 do InLab_ReverterMapear()
        InLab_VerUV_Desligar()
        checar "Ver UV ligado no produto: Painéis não religa bitmap usado por peça fora da seleção" okVP
        checar "Ver UV ligado no produto: Mapear não religa bitmap usado por peça fora da seleção" okVM

        -- escala por ID: vivo como ID 1 (30 cm) e corpo como ID 2 (120 cm)
        InLab_UltimoMapear = #(); InLab_PilhaPaineis = #()
        local ev = mkPeca "TESTE_pn4_escid" [0,4400,0]
        local nfEv = polyop.getNumFaces ev
        local viE = mkVivo "TESTE_pn4_vi_e" 50.0 10.0 [0,4400,0]
        polyop.attach ev viE
        for f = 1 to (polyop.getNumFaces ev) do polyop.setFaceMatID ev f (if f > nfEv then 1 else 2)
        local mmE = Multimaterial numsubs:2
        mmE.materialList[1] = criarMaterial "ART_PnTecido" arqImg
        mmE.materialList[2] = criarMaterial "ART_PnTecidoRW" arqImg
        ev.material = mmE; append criados ev
        append InLab_UltimoMapear (MapearRecord no:ev cmPorID:#(#(1, 30.0), #(2, 120.0)))
        logs.count = 0
        InLab_Paineis #(ev) produto
        local medE = InLab_Mapear_Medir ev matID:2
        local cmE = if medE.escala > 0 then 1.0 / medE.escala else 0.0
        local recE = if InLab_PilhaPaineis.count > 0 then InLab_PilhaPaineis[InLab_PilhaPaineis.count][1] else undefined
        local cmIDs = if recE == undefined then #() else recE.cmPorID
        fn cmDoID lst id = ( local r = undefined; for x in lst where x[1] == id do r = x[2]; r )
        local c1E = cmDoID cmIDs 1, c2E = cmDoID cmIDs 2
        linha ("      escala por ID: corpo " + cmE as string + " cm por tile; cmPorID " + cmIDs as string)
        checar "Escala: vivo como ID 1 e corpo como ID 2 com tamanhos diferentes" \
            (cmE > 114.0 and cmE < 126.0 and c1E != undefined and (abs (c1E - 30.0)) < 0.5 and c2E != undefined and (abs (c2E - 120.0)) < 0.5)
        InLab_DesfazerPaineis tudo:true
        InLab_UltimoMapear = #()

        -- vivo interno com o RWF no canal 2: o UV do vivo no canal 1 é o do canal 2 de antes
        local vr = mkPeca "TESTE_pn4_vivorwf" [300,4400,0]
        local nfVr = polyop.getNumFaces vr
        local viR = mkVivo "TESTE_pn4_vi_r" 50.0 10.0 [300,4400,0]
        polyop.attach vr viR
        local mC2r = criarMaterialC2 arqImg
        vr.material = mC2r; append criados vr
        rwfCanal2 vr; append InLab_RWF_Feitos vr
        local triIni = 0
        for f = 1 to nfVr do triIni += (polyop.getFaceDeg vr.baseobject f) - 2
        fn uvTris o canal desde =
        (
            local m = snapshotAsMesh o
            local r = #()
            if canal < (meshop.getNumMaps m) and (meshop.getMapSupport m canal) do
                for t = desde + 1 to m.numfaces do
                (
                    local tv = meshop.getMapFace m canal t
                    for k = 1 to 3 do append r (meshop.getMapVert m canal tv[k])
                )
            delete m
            r
        )
        local uvVivo2 = uvTris vr 2 triIni
        local tilAntes = mC2r.diffuseMap.coords.U_Tiling
        logs.count = 0
        InLab_Paineis #(vr) produto
        local uvVivo1 = uvTris vr 1 triIni
        checar "Vivo interno com RWF no canal 2: densidade do vivo não muda depois do Painéis" \
            ((temLog logs #ok "TESTE_pn4_vivorwf" "painéis") and mC2r.diffuseMap.coords.mapChannel == 1 and \
             (abs (mC2r.diffuseMap.coords.U_Tiling - tilAntes)) < 1e-5 and (igualLista uvVivo2 uvVivo1))
        InLab_DesfazerPaineis tudo:true

        -- exceção forçada no meio: nenhum InLab_tmp_* sobra
        local tf = mkPeca "TESTE_pn4_falha" [600,4400,0]
        tf.material = mTec; append criados tf
        local tvv = Torus radius1:50 radius2:0.6 segments:48 sides:8 name:"TESTE_pn4_falha_vivo" pos:[600,4400,10]
        tvv.material = mTec; tvv.parent = tf; append criados tvv
        InLab_Paineis_ForcarFalha = "CopiaBase"
        try ( InLab_Paineis #(tf) produto ) catch ( linha ("      exceção: " + getCurrentException()) )
        local sobraC = (for o in objects where (matchPattern o.name pattern:"InLab_tmp*") collect o).count
        InLab_Paineis_ForcarFalha = "VivosDoProduto"
        try ( InLab_Paineis #(tf) produto ) catch ( linha ("      exceção: " + getCurrentException()) )
        local sobraV = (for o in objects where (matchPattern o.name pattern:"InLab_tmp*") collect o).count
        InLab_Paineis_ForcarFalha = undefined
        linha ("      temporários depois da falha: CopiaBase " + sobraC as string + ", VivosDoProduto " + sobraV as string)
        for o in objects where (matchPattern o.name pattern:"InLab_tmp*") do try ( delete o ) catch ()
        checar "Exceção forçada no CopiaBase não deixa InLab_tmp_*" (sobraC == 0)
        checar "Exceção forçada no VivosDoProduto não deixa InLab_tmp_*" (sobraV == 0)
        -- varredura do fim do Painéis: temporário órfão de antes é apagado com #warn
        local orfao = Box name:"InLab_tmp_orfao_teste" pos:[900,4400,0]
        logs.count = 0
        InLab_Paineis #(tf) produto
        checar "Painéis: varredura final apaga InLab_tmp_* com #warn" (not (isValidNode orfao) and (temLog logs #warn "Painéis" "temporário"))
        if isValidNode orfao do delete orfao
        InLab_DesfazerPaineis tudo:true
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    for o in criados where isValidNode o do try ( delete o ) catch ()
    InLab_RWF_Feitos = feitosAntes
    if arqImg != undefined do try ( deleteFile arqImg ) catch ()
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
