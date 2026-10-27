/*
 tests\test_mapear_paineis.ms — teste da infraestrutura de functions\fn_mapear_paineis.ms (geometria em
 mundo, Elementos, EhVivo, Contornos, EhTecido, Escala, Desfazer Painéis). RODAR NUMA CENA VAZIA
 (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear_paineis.txt (PASS/FAIL por item).
 26/10/2026 (Tarefa 1): vivos e geometria em mundo.
 27/10/2026 (hotfix 1.3.2): face morta em Elementos e InLab_Paineis_TirarMortas.
 27/10/2026 (Mapear assistido, Tarefa 7): saiu o Painéis automático e com ele os casos de
 VivosDoProduto, Separar, Dist, UV/Torta e do botão InLab_Paineis; a pilha, o Desfazer e o
 Mapear->Cortar são cobertos por test_mapear_cortar.ms e test_mapear_cortar2.ms.
*/
global InLab_Log, InLab_EhGeometria, InLab_Mapear_PolyDe
global InLab_Paineis_Vert, InLab_Paineis_Elementos, InLab_Paineis_VolArea, InLab_Paineis_TirarMortas
global InLab_Paineis_EhVivo, InLab_Paineis_Contornos, InLab_Mapear_Medir, InLab_Mapear_Gravar
global InLab_ParseJSON, InLab_Produto_Lista, InLab_RWF_Feitos, InLab_Mapear, InLab_ReverterMapear
global InLab_UltimoMapear, InLab_Mapear_LerCanal1, InLab_ReverterAutoUV, InLab_UltimoRWF, InLab_UltimoAutoUV
global InLab_DesfazerPaineis, InLab_PilhaPaineis, InLab_Paineis_EsquecerPeca
global InLab_Paineis_EhTecido, InLab_Paineis_Escala
global InLab_VerUV_Ligar, InLab_VerUV_Desligar
global MapearRecord, InLab_RWF_Rodar
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
        fileIn (raiz + @"functions\fn_ver_uv.ms")
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

        -- hotfix 1.3.2: face morta (bit 2 das flags) travava InLab_Paineis_Elementos
        local morta = Box length:20 width:20 height:20 lengthsegs:2 widthsegs:2 heightsegs:2 name:"TESTE_pn_morta"
        convertToPoly morta
        append criados morta
        local pm = morta.baseobject
        polyop.setFaceFlags pm #{5} 2 mask:2 undoable:false
        checar "face morta: preparada (getFaceDeg undefined)" ((polyop.getFaceDeg pm 5) == undefined)
        local t0m = timeStamp()
        local elM = InLab_Paineis_Elementos pm #{1..(polyop.getNumFaces pm)}
        checar "face morta: Elementos termina e ignora a face morta" (elM.count == 1 and elM[1].numberSet == 23 and not elM[1][5] and (timeStamp() - t0m) < 5000)
        checar "face morta: TirarMortas conta 1 e compacta a base" ((InLab_Paineis_TirarMortas morta) == 1 and (polyop.getNumFaces pm) == 23)
        checar "face morta: TirarMortas sem morta não muda nada" ((InLab_Paineis_TirarMortas morta) == 0 and (polyop.getNumFaces pm) == 23)
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

        ---------------- Contornos ----------------
        local plc = Plane length:40 width:40 lengthsegs:4 widthsegs:4 name:"TESTE_pn_plc"
        convertToPoly plc
        append criados plc
        local bxc = Box length:40 width:40 height:40 lengthsegs:2 widthsegs:2 heightsegs:2 name:"TESTE_pn_bxc"
        convertToPoly bxc
        append criados bxc
        local nfBx = polyop.getNumFaces bxc.baseobject
        local tampo = #()
        for f = 1 to nfBx where (polyop.getFaceNormal bxc.baseobject f).z > 0.9 or (polyop.getFaceNormal bxc.baseobject f).z < -0.9 do append tampo f
        local faixa = #{1..nfBx} - (tampo as bitarray)
        checar "contornos: plano aberto 1, caixa fechada 0, faixa em volta 2"             ((InLab_Paineis_Contornos plc.baseobject #{1..(polyop.getNumFaces plc.baseobject)}) == 1 and              (InLab_Paineis_Contornos bxc.baseobject #{1..nfBx}) == 0 and (InLab_Paineis_Contornos bxc.baseobject faixa) == 2)


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
        -- Ver UV ligado: a peça Multi/Sub de tecido ainda é reconhecida (o.material são as listras)
        local multi = Multimaterial name:"TESTE_pn_multi" numsubs:2
        multi.materialIDList[1] = 1; multi.materialList[1] = mTec
        multi.materialIDList[2] = 2; multi.materialList[2] = mMad
        local pMulti = mkPeca "TESTE_pn4_multi" [0,-2500,0]
        pMulti.material = multi; append criados pMulti
        local antesVU = InLab_Paineis_EhTecido pMulti produto
        InLab_VerUV_Ligar #(pMulti)
        local duranteVU = InLab_Paineis_EhTecido pMulti produto
        InLab_VerUV_Desligar()
        checar "Ver UV ligado: Painéis ainda reconhece uma peça Multi/Sub de tecido" (antesVU and duranteVU)
        -- F2: ID de tecido mantido pelo Mapear (tampos com o mapcoords de 50 cm) e ID de madeira refeito
        local km = Box length:50 width:50 height:150 lengthsegs:2 widthsegs:2 heightsegs:1 mapcoords:true name:"TESTE_pn4_kept" pos:[300,3800,0]
        convertToPoly km
        for f = 1 to (polyop.getNumFaces km) do polyop.setFaceMatID km f (if (abs (polyop.getFaceNormal km f).z) > 0.9 then 1 else 2)
        local mmK = Multimaterial numsubs:2
        mmK.materialList[1] = mTec; mmK.materialList[2] = mMad
        km.material = mmK; append criados km
        InLab_UltimoMapear = #()
        logs.count = 0
        InLab_Mapear #(km) produto
        local recK = undefined
        for r in InLab_UltimoMapear where r.no == km do recK = r
        local cmK = undefined
        if recK != undefined do for x in recK.cmPorID where x[1] == 1 do cmK = x[2]
        local eK = InLab_Paineis_Escala km 1
        linha ("      ID mantido: cmPorID " + (if recK == undefined then "sem registro" else recK.cmPorID as string) + "; escala " + (1.0 / eK) as string + " cm")
        checar "Escala: ID mantido pelo Mapear guarda o tamanho" ((temLog logs #ok "TESTE_pn4_kept (ID 1)" "mantido") and cmK != undefined and \
            (abs (cmK - 50.0)) < 1.0 and (abs (1.0 / eK - 50.0)) < 1.0)
        InLab_ReverterMapear()

        logs.count = 0
        InLab_PilhaPaineis = #()
        checar "Desfazer Painéis: pilha vazia, #warn e 0" ((InLab_DesfazerPaineis()) == 0 and (temLog logs #warn "Painéis" "nada a desfazer"))
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
