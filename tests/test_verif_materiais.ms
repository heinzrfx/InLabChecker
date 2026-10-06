/*
 tests\test_verif_materiais.ms — teste do grupo 7 de verificações (issue #103)
 Spec: docs\superpowers\specs\2026-10-06-verif-materiais-grupo7-design.md
 RODAR NUMA CENA VAZIA (File > New): cria e apaga os objetos de cada caso.
 Resultado: <pasta temp do Max>\inlab_test_verif_materiais.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_VerifResults, InLab_ResetarResultados, InLab_ObterFamilia
global InLab_Material_PerfilSlots, InLab_TipoDeMaterial, InLab_ParseJSON, InLab_Produto_Lista
global InLab_Mat_Uso, InLab_Mat_Resolver, InLab_Mat_MapasDoSlot, InLab_Mat_ArquivoDoMapa
global InLab_V23_SlotsPBR, InLab_V24_PNG, InLab_V25_IDsDeMaterial
global InLab_V35_Palha, InLab_V36_Cristal, InLab_V37_ZonasEstofado, InLab_V38_TampoAcessorio
global InLab_TampoAcessorioProduto, InLab_AprovacaoFinal
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_verif_materiais.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn statusDe idV =
    (
        local achado = #ausente
        for r in InLab_VerifResults where r.id == idV do achado = r.status
        achado
    )
    fn mensagemDe idV =
    (
        local achado = ""
        for r in InLab_VerifResults where r.id == idV do achado = r.mensagem
        achado
    )
    fn limparCena = ( delete (for o in objects collect o) )
    fn tem txt trecho = (findString txt trecho) != undefined

    local logOriginal = InLab_Log
    local unidadeOriginal = units.SystemType

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms",
                   @"familias\familia_corpo_unico.ms", @"familias\familia_pernas_tampo.ms", @"familias\familia_estrutura_estofado.ms",
                   @"functions\fn_json.ms", @"functions\fn_renomear_produto.ms", @"functions\fn_material_convert.ms",
                   @"verifications\verif_materiais.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        units.SystemType = #Centimeters
        limparCena()

        ---------------------------------------------------------------- perfil
        local pl = InLab_Material_PerfilSlots #legacy
        checar "Perfil Legacy: base = texmapDiffuse" (pl.mapaBase[1] == #texmapDiffuse)
        checar "Perfil Legacy: gloss = texmapReflectGlossiness" (pl.mapaGloss[1] == #texmapReflectGlossiness)
        checar "Perfil Legacy: bump = texmapBump, opacidade = texmapOpacity, refração = levelRefract" (pl.bump[1] == #texmapBump and pl.opacMapa[1] == #texmapOpacity and pl.refrVal[1] == #levelRefract)
        local pp = InLab_Material_PerfilSlots #physical
        checar "Perfil Physical: base = baseTexmap, roughness = baseRoughnessTexmap" (pp.mapaBase[1] == #baseTexmap and pp.mapaGloss[1] == #baseRoughnessTexmap)
        local pv = InLab_Material_PerfilSlots #vray
        checar "Perfil VRay: base = texmap_diffuse, opacidade = texmap_opacity" (pv.mapaBase[1] == #texmap_diffuse and pv.opacMapa[1] == #texmap_opacity)
        checar "Perfil #outro = Physical" ((InLab_Material_PerfilSlots #outro).mapaBase[1] == #baseTexmap)
        -- Os nomes do perfil existem de verdade nos materiais da build.
        local mL = CoronaLegacyMtl()
        checar "Perfil Legacy: todos os slots de mapa existem no CoronaLegacyMtl" ((for n in #(pl.mapaBase[1], pl.mapaGloss[1], pl.bump[1], pl.opacMapa[1], pl.refrVal[1]) where not (isProperty mL n) collect n).count == 0)
        local mP = CoronaPhysicalMtl()
        checar "Perfil Physical: todos os slots de mapa existem no CoronaPhysicalMtl" ((for n in #(pp.mapaBase[1], pp.mapaGloss[1], pp.bump[1], pp.opacMapa[1], pp.refrVal[1]) where not (isProperty mP n) collect n).count == 0)

        ---------------------------------------------------------------- helpers
        fn caixa nome p = ( local b = Box name:nome length:10 width:10 height:10 mapcoords:true pos:p; convertToPoly b; b )
        fn legacyCom nome difuso = ( local m = CoronaLegacyMtl(); m.name = nome; m.texmapDiffuse = difuso; m )
        -- Material direto: usado. Objeto sem material: ignorado.
        local m1 = legacyCom "Madeira" (CoronaColor())
        local b1 = caixa "b1" [0, 0, 0]
        b1.material = m1
        local b0 = caixa "b0" [30, 0, 0]
        local uso = InLab_Mat_Uso #(b1, b0)
        checar "Uso: material direto entra, objeto sem material é ignorado" (uso.usados.count == 1 and uso.usados[1] == m1 and uso.orfaos.count == 0 and uso.naoMedidos.count == 0)
        -- Multi/Sub: só os sub-materiais com faces entram.
        local mm = Multimaterial numsubs:3
        mm.materialList[1] = legacyCom "Tecido" (CoronaColor())
        mm.materialList[2] = legacyCom "Metal" (CoronaColor())
        mm.materialList[3] = legacyCom "Sem faces" (CoronaColor())
        local b2 = caixa "b2" [60, 0, 0]
        for f = 1 to (polyop.getNumFaces b2) do polyop.setFaceMatID b2 f (if f <= 3 then 1 else 2)
        b2.material = mm
        uso = InLab_Mat_Uso #(b2)
        checar "Uso: Multi/Sub entra pelos sub-materiais com faces (2 de 3)" (uso.usados.count == 2 and (findItem uso.usados mm.materialList[3]) == 0)
        -- Mesmo material em dois objetos: uma vez só.
        local b3 = caixa "b3" [90, 0, 0]
        b3.material = m1
        uso = InLab_Mat_Uso #(b1, b3)
        checar "Uso: mesmo material em dois objetos aparece uma vez" (uso.usados.count == 1)
        -- Resolver: tipo, especial e Layered.
        local mPalha = legacyCom "Palha natural" (CoronaColor())
        local lay = CoronaLayeredMtl()
        lay.name = "Camadas"
        lay.baseMtl = legacyCom "Base do layered" (CoronaColor())
        local layVazio = CoronaLayeredMtl()
        layVazio.name = "Camadas sem base"
        local mStd = StandardMaterial name:"Padrao"
        b1.material = mPalha
        b2.material = lay
        b3.material = mStd
        local b4 = caixa "b4" [120, 0, 0]
        b4.material = layVazio
        local infos = InLab_Mat_Resolver (InLab_Mat_Uso #(b1, b2, b3, b4))
        fn infoDe infos nome = ( local r = undefined; for i in infos where i.mtl.name == nome do r = i; r )
        checar "Resolver: Legacy com palavra palha = #legacy/#palha" ((infoDe infos "Palha natural").tipo == #legacy and (infoDe infos "Palha natural").especial == #palha)
        checar "Resolver: Layered lido pelo material base" ((infoDe infos "Camadas").tipo == #legacy and (infoDe infos "Camadas").base.name == "Base do layered")
        checar "Resolver: Layered sem base vira #outro, sem exceção" ((infoDe infos "Camadas sem base").tipo == #outro and (infoDe infos "Camadas sem base").base == undefined)
        checar "Resolver: Standard vira #outro" ((infoDe infos "Padrao").tipo == #outro)
        -- Árvore do slot: o bitmap dentro do CoronaMix aparece.
        local mix = CoronaMix()
        local bmt = Bitmaptexture filename:((getDir #temp) + "\\inlab_v24_dentro.png")
        setSubTexmap mix 1 bmt
        local mArv = legacyCom "Arvore" mix
        b1.material = mArv
        local iArv = (InLab_Mat_Resolver (InLab_Mat_Uso #(b1)))[1]
        local mapas = InLab_Mat_MapasDoSlot iArv #mapaBase
        checar "MapasDoSlot: percorre a árvore (CoronaMix + bitmap)" ((findItem mapas mix) > 0 and (findItem mapas bmt) > 0)
        checar "MapasDoSlot: slot vazio devolve #()" ((InLab_Mat_MapasDoSlot iArv #bump).count == 0)
        checar "ArquivoDoMapa: Bitmaptexture devolve o caminho" ((InLab_Mat_ArquivoDoMapa bmt) == bmt.filename)
        local cbm = CoronaBitmap()
        cbm.filename = (getDir #temp) + "\\inlab_v24_corona.png"
        checar "ArquivoDoMapa: CoronaBitmap devolve o caminho" ((InLab_Mat_ArquivoDoMapa cbm) == cbm.filename)
        checar "ArquivoDoMapa: procedural devolve undefined" ((InLab_Mat_ArquivoDoMapa mix) == undefined)
        checar "ArquivoDoMapa: Bitmaptexture sem arquivo devolve undefined" ((InLab_Mat_ArquivoDoMapa (Bitmaptexture())) == undefined)
        limparCena()

        ---------------------------------------------------------------- V-23 / V-24
        fn salvarBitmap nome = ( local arq = (getDir #temp) + "\\" + nome; local bm = bitmap 8 8 color:gray filename:arq; save bm; close bm; arq )
        local arqPng = salvarBitmap "inlab_v24.png"
        local arqJpg = salvarBitmap "inlab_v24.jpg"
        fn rodarMats f objs idV = ( InLab_ResetarResultados(); f (InLab_Mat_Resolver (InLab_Mat_Uso objs)); statusDe idV )
        local c1 = caixa "c1" [0, 0, 0]
        -- Só base color (procedural): passa, com nota.
        c1.material = legacyCom "So base" (CoronaColor())
        checar "V-23: só base color (procedural) passa" ((rodarMats InLab_V23_SlotsPBR #(c1) "V-23") == #pass)
        checar ("V-23: nota de roughness e normal vazios ('" + mensagemDe "V-23" + "')") (tem (mensagemDe "V-23") "sem roughness: So base" and tem (mensagemDe "V-23") "sem normal: So base")
        -- Sem mapa no base color: advertência provisória.
        c1.material = legacyCom "Sem base" undefined
        checar "V-23: base color sem mapa vira advertência" ((rodarMats InLab_V23_SlotsPBR #(c1) "V-23") == #warning)
        checar ("V-23: mensagem cita o material ('" + mensagemDe "V-23" + "')") (tem (mensagemDe "V-23") "Sem base: base color sem mapa")
        -- Standard: não convertível.
        c1.material = StandardMaterial name:"Padrao"
        checar "V-23: Standard vira advertência (não convertível)" ((rodarMats InLab_V23_SlotsPBR #(c1) "V-23") == #warning and tem (mensagemDe "V-23") "Padrao: tipo")
        -- Três slots preenchidos: passa sem nota.
        local mCheio = legacyCom "Cheio" (CoronaColor())
        mCheio.texmapReflectGlossiness = CoronaColor()
        mCheio.texmapBump = CoronaNormal()
        c1.material = mCheio
        checar "V-23: três slots preenchidos passa sem nota" ((rodarMats InLab_V23_SlotsPBR #(c1) "V-23") == #pass and not (tem (mensagemDe "V-23") "sem roughness"))

        -- V-24: PNG dentro de CoronaMix no base color reprova.
        local mixP = CoronaMix()
        setSubTexmap mixP 1 (Bitmaptexture filename:arqPng)
        c1.material = legacyCom "Laca" mixP
        checar "V-24: PNG dentro de CoronaMix no base color reprova" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #fail)
        checar ("V-24: mensagem cita material, slot e arquivo ('" + mensagemDe "V-24" + "')") (tem (mensagemDe "V-24") "Laca (base color): inlab_v24.png")
        -- PNG no roughness (CoronaBitmap) reprova.
        local mR = legacyCom "Verniz" (CoronaColor())
        local cbR = CoronaBitmap()
        cbR.filename = arqPng
        mR.texmapReflectGlossiness = cbR
        c1.material = mR
        checar "V-24: PNG em CoronaBitmap no roughness reprova" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #fail and tem (mensagemDe "V-24") "Verniz (roughness)")
        -- Palha com PNG: aceito.
        c1.material = legacyCom "Palha natural" (Bitmaptexture filename:arqPng)
        checar "V-24: PNG em palha passa" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #pass and tem (mensagemDe "V-24") "PNG aceito (alpha): Palha natural")
        -- Material com opacidade e PNG: aceito.
        local mOp = legacyCom "Tela" (Bitmaptexture filename:arqPng)
        mOp.texmapOpacity = CoronaColor()
        c1.material = mOp
        checar "V-24: PNG em material com opacidade passa" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #pass)
        -- JPG passa; PNG no bump não conta.
        local mJ = legacyCom "Carvalho" (Bitmaptexture filename:arqJpg)
        mJ.texmapReflectGlossiness = Bitmaptexture filename:arqJpg
        mJ.texmapBump = Bitmaptexture filename:arqPng
        c1.material = mJ
        checar "V-24: JPG em base e roughness passa (PNG no bump não conta)" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #pass)
        -- Bitmap sem arquivo: ignorado.
        c1.material = legacyCom "Vazio" (Bitmaptexture())
        checar "V-24: bitmap sem arquivo é ignorado" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #pass)
        -- Mesmo material com PNG em dois objetos: listado uma vez.
        c1.material = legacyCom "Laca" mixP
        local c2 = caixa "c2" [30, 0, 0]
        c2.material = c1.material
        rodarMats InLab_V24_PNG #(c1, c2) "V-24"
        local msg24 = mensagemDe "V-24"
        local ocorr = 0
        local pos = findString msg24 "Laca (base color)"
        while pos != undefined do ( ocorr += 1; msg24 = substring msg24 (pos + 1) -1; pos = findString msg24 "Laca (base color)" )
        checar ("V-24: material repetido listado uma vez (" + ocorr as string + ")") (ocorr == 1)
        try ( deleteFile arqPng; deleteFile arqJpg ) catch ( linha ("aviso: não apaguei os bitmaps de teste (" + getCurrentException() + ")") )
        limparCena()

        ---------------------------------------------------------------- V-25
        local js = "{\"produtos\": [{\"cod_est\": \"0090\", \"nome\": \"POLTRONA\", \"partes\": [" +
            "{\"nome_parte\": \"Estrutura\", \"tipo\": \"P\", \"so3d\": false, \"tecido\": false, \"acessorio\": false, \"material_id\": \"ART_P_Estrutura\", \"mesh_final\": \"0090\"}, " +
            "{\"nome_parte\": \"Assento\", \"tipo\": \"T\", \"so3d\": false, \"tecido\": true, \"acessorio\": false, \"material_id\": \"ART_T_Assento\", \"mesh_final\": \"0090\"}, " +
            "{\"nome_parte\": \"Encosto\", \"tipo\": \"T\", \"so3d\": false, \"tecido\": true, \"acessorio\": false, \"material_id\": \"ART_T_Encosto\", \"mesh_final\": \"0090\"}, " +
            "{\"nome_parte\": \"Tampo\", \"tipo\": \"P\", \"so3d\": false, \"tecido\": false, \"acessorio\": true, \"material_id\": \"ART_P_Tampo\", \"mesh_final\": \"0090\"}]}]}"
        local prod = (InLab_Produto_Lista (InLab_ParseJSON js))[1]
        fn multiCom nomes = ( local mm = Multimaterial numsubs:nomes.count; for k = 1 to nomes.count do mm.materialList[k] = legacyCom nomes[k] (CoronaColor()); mm )
        fn idsNasFaces o ids = ( local n = polyop.getNumFaces o; for f = 1 to n do polyop.setFaceMatID o f ids[1 + (mod (f - 1) ids.count) as integer]; o )
        fn rodar25 objs p = ( InLab_ResetarResultados(); InLab_V25_IDsDeMaterial (InLab_Mat_Uso objs) produto:p; statusDe "V-25" )
        local d1 = caixa "0090" [0, 0, 0]
        d1.material = multiCom #("ART_P_Estrutura", "ART_T_Assento", "ART_T_Encosto", "ART_P_Tampo")
        idsNasFaces d1 #(1, 2, 3, 4)
        checar ("V-25: todos os IDs com sub-material e todas as partes com faces passa ('" + (rodar25 #(d1) prod) as string + "')") ((rodar25 #(d1) prod) == #pass and not (tem (mensagemDe "V-25") "sem faces"))
        -- Face com ID fora da lista: reprova (crítica).
        idsNasFaces d1 #(1, 2, 3, 7)
        checar "V-25: ID sem sub-material reprova" ((rodar25 #(d1) prod) == #fail)
        checar ("V-25: mensagem cita objeto e ID ('" + mensagemDe "V-25" + "')") (tem (mensagemDe "V-25") "0090: ID 7 sem sub-material")
        -- Slot do Multi/Sub vazio com faces apontando para ele: reprova, sem exceção.
        d1.material.materialList[4] = undefined
        idsNasFaces d1 #(1, 2, 3, 4)
        checar "V-25: sub-material undefined com faces reprova sem exceção" ((rodar25 #(d1) prod) == #fail and tem (mensagemDe "V-25") "0090: ID 4 sem sub-material")
        -- Parte do produto sem faces: passa com nota (bloco sem o tampo acessório).
        d1.material = multiCom #("ART_P_Estrutura", "ART_T_Assento", "ART_T_Encosto")
        idsNasFaces d1 #(1, 2, 3)
        checar "V-25: parte sem faces passa com nota" ((rodar25 #(d1) prod) == #pass and tem (mensagemDe "V-25") "parte(s) do produto sem faces: ART_P_Tampo")
        -- Sem produto: só a regra dos IDs.
        checar "V-25: sem produto, IDs ok passa" ((rodar25 #(d1) undefined) == #pass)
        -- Material direto (não Multi/Sub): passa.
        d1.material = legacyCom "ART_P_Estrutura" (CoronaColor())
        checar "V-25: material direto passa" ((rodar25 #(d1) undefined) == #pass)
        limparCena()

        ---------------------------------------------------------------- V-35 / V-36
        local e1 = caixa "e1" [0, 0, 0]
        e1.material = legacyCom "Madeira" (CoronaColor())
        checar "V-35: sem palha não se aplica (passa)" ((rodarMats InLab_V35_Palha #(e1) "V-35") == #pass and tem (mensagemDe "V-35") "não se aplica")
        e1.material = legacyCom "Palha natural" (CoronaColor())
        checar "V-35: palha sem opacidade vira advertência" ((rodarMats InLab_V35_Palha #(e1) "V-35") == #warning and tem (mensagemDe "V-35") "Palha natural: sem mapa de opacidade")
        e1.material.texmapOpacity = CoronaColor()
        checar "V-35: palha com opacidade passa" ((rodarMats InLab_V35_Palha #(e1) "V-35") == #pass)

        e1.material = legacyCom "Madeira" (CoronaColor())
        checar "V-36: sem cristal não se aplica (passa)" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #pass and tem (mensagemDe "V-36") "não se aplica")
        -- Vidro jateado: refração ligada e glossiness baixo (fosco) passa.
        local mJat = legacyCom "Vidro Jateado" undefined
        mJat.levelRefract = 1.0
        mJat.reflectGlossiness = 0.3
        e1.material = mJat
        checar "V-36: vidro jateado (fosco) com refração passa" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #pass)
        mJat.levelRefract = 0.0
        checar "V-36: vidro com refração 0 vira advertência" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #warning and tem (mensagemDe "V-36") "Vidro Jateado: refração desligada")
        -- Physical.
        local mPh = CoronaPhysicalMtl()
        mPh.name = "Cristal liso"
        mPh.refractionAmount = 1.0
        e1.material = mPh
        checar "V-36: Physical com refração passa" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #pass)
        -- VRay (só se a classe existir).
        local mV = try ( VRayMtl() ) catch ( undefined )
        if mV == undefined then checar "V-36: VRay — pulado: VRay ausente" true
        else
        (
            mV.name = "Glass VRay"
            mV.refraction = color 255 255 255
            e1.material = mV
            checar "V-36: VRay com cor de refração passa" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #pass)
            mV.refraction = color 0 0 0
            checar "V-36: VRay com refração preta vira advertência" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #warning)
        )
        limparCena()

        ---------------------------------------------------------------- V-37 / V-38
        local cfgEstof = InLab_ObterFamilia "estrutura_estofado"
        local cfgUnico = InLab_ObterFamilia "corpo_unico"
        local cfgTampo = InLab_ObterFamilia "pernas_tampo"
        fn rodar37 cfg objs p = ( InLab_ResetarResultados(); InLab_V37_ZonasEstofado cfg (InLab_Mat_Uso objs) produto:p; statusDe "V-37" )
        fn rodar38 cfg objs p = ( InLab_ResetarResultados(); InLab_V38_TampoAcessorio cfg (InLab_Mat_Uso objs) produto:p; statusDe "V-38" )
        local g1 = caixa "0090" [0, 0, 0]
        g1.material = multiCom #("ART_P_Estrutura", "ART_T_Assento", "ART_T_Encosto")
        idsNasFaces g1 #(1, 2, 3)
        checar "V-37: família sem zona de acabamento não se aplica" ((rodar37 cfgUnico #(g1) prod) == #pass and tem (mensagemDe "V-37") "não se aplica")
        checar "V-37: as duas partes de tecido com faces passa" ((rodar37 cfgEstof #(g1) prod) == #pass)
        idsNasFaces g1 #(1, 2)
        checar "V-37: parte de tecido sem faces vira advertência" ((rodar37 cfgEstof #(g1) prod) == #warning and tem (mensagemDe "V-37") "ART_T_Encosto")
        -- Sem produto: um material só em tudo → advertência; mais de um → passa.
        g1.material = legacyCom "Tecido unico" (CoronaColor())
        checar "V-37: sem produto, estofado num único material vira advertência" ((rodar37 cfgEstof #(g1) undefined) == #warning and tem (mensagemDe "V-37") "único")
        g1.material = multiCom #("Tecido A", "Tecido B")
        idsNasFaces g1 #(1, 2)
        checar "V-37: sem produto, mais de um material passa" ((rodar37 cfgEstof #(g1) undefined) == #pass)

        -- V-38
        InLab_TampoAcessorioProduto = false
        checar "V-38: sem tampo acessório não se aplica" ((rodar38 cfgUnico #(g1) prod) == #pass and tem (mensagemDe "V-38") "não se aplica")
        InLab_TampoAcessorioProduto = true
        g1.material = multiCom #("ART_P_Estrutura", "ART_P_Tampo")
        idsNasFaces g1 #(1, 2)
        checar "V-38: tampo e estrutura no mesmo arquivo vira advertência" ((rodar38 cfgUnico #(g1) prod) == #warning and tem (mensagemDe "V-38") "separe")
        g1.material = legacyCom "ART_P_Tampo" (CoronaColor())
        checar "V-38: só o tampo passa" ((rodar38 cfgUnico #(g1) prod) == #pass)
        g1.material = legacyCom "ART_P_Estrutura" (CoronaColor())
        checar "V-38: só a estrutura passa" ((rodar38 cfgUnico #(g1) prod) == #pass)
        InLab_TampoAcessorioProduto = true
        local usoNM = InLab_Mat_Uso #(g1)
        append usoNM.naoMedidos "objX (erro simulado)"
        InLab_ResetarResultados(); InLab_V38_TampoAcessorio cfgUnico usoNM produto:prod
        checar "V-38: material não lido não passa em silêncio" ((statusDe "V-38") == #warning and tem (mensagemDe "V-38") "não medido")
        InLab_TampoAcessorioProduto = true  -- volta a true: o caso seguinte (pendente) precisa dele
        checar "V-38: sem produto fica pendente (advertência)" ((rodar38 cfgUnico #(g1) undefined) == #warning and tem (mensagemDe "V-38") "pendente")
        InLab_TampoAcessorioProduto = false
        -- Pela família (cfg.tampoAcessorio), sem o checkbox; o valor volta no fim.
        local tampoOriginal = cfgTampo.tampoAcessorio
        cfgTampo.tampoAcessorio = true
        g1.material = multiCom #("ART_P_Estrutura", "ART_P_Tampo")
        idsNasFaces g1 #(1, 2)
        checar "V-38: tampo acessório pela família também ativa" ((rodar38 cfgTampo #(g1) prod) == #warning)
        cfgTampo.tampoAcessorio = tampoOriginal
        -- Não crítica: o resultado sai com critico:false e não bloqueia a aprovação.
        local r38 = undefined
        for r in InLab_VerifResults where r.id == "V-38" do r38 = r
        checar "V-38 é não crítica (critico:false, aprovação continua)" (r38 != undefined and not r38.critico and InLab_AprovacaoFinal())
        limparCena()

        -- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    try ( limparCena() ) catch ()
    units.SystemType = unidadeOriginal
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
