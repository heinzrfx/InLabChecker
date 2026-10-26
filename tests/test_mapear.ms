/*
 tests\test_mapear.ms — teste de functions\fn_mapear.ms (orquestrador do botão
 Mapear, registro e Desfazer). RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear.txt (PASS/FAIL por item).
 23/10/2026 (Tarefa 5). Seção 14 (Tarefa 6): casos de borda do stack, Multi/Sub e
 RWF + Mapear + Desfazer UV (InLab_ReverterAutoUV desfaz antes o Mapear).
 Seção 15 (revisão final): escala do nó, bitmap compartilhado fora da rodada,
 topologia no Desfazer, ilhas das faces mantidas, teto do tubo e logs.
*/
global InLab_Log, InLab_ParseJSON, InLab_Produto_Lista, InLab_RWF_Feitos
global InLab_Mapear, InLab_ReverterMapear, InLab_UltimoMapear, InLab_Mapear_LerCanal1
global InLab_Mapear_Medir, InLab_Mapear_GerarTubo, InLab_Mapear_Gravar
global InLab_Instancias, InLab_RWF_Rodar, InLab_Mapear_ForcarFalha
global InLab_ReverterAutoUV, InLab_UltimoRWF, InLab_UltimoAutoUV
global INLAB_TESTE_MEDIR_ORIG, INLAB_TESTE_MEDIR_N
global INLAB_MAPEAR_TUBO_MAX_PASSOS
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_mapear.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn contem s trecho = ( (findString s trecho) != undefined )

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
    -- canal 1 da base igual (registro de InLab_Mapear_LerCanal1)
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
                local fa = a[3][k][2]; local fb = b[3][k][2]
                if fa.count != fb.count then ok = false
                else for j = 1 to fa.count do if fa[j] != fb[j] do ok = false
            )
            ok
        )
    )
    -- canal do snapshot (UV por canto de triângulo)
    fn canalSnapshot o canal =
    (
        local m = snapshotAsMesh o
        local r = #()
        if canal < (meshop.getNumMaps m) and (meshop.getMapSupport m canal) do
            for f = 1 to m.numfaces do
            (
                local tv = meshop.getMapFace m canal f
                for k = 1 to 3 do append r (meshop.getMapVert m canal tv[k])
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
    -- listras horizontais de 4 em 4 px
    fn gerarImagem nome =
    (
        local arq = (getDir #temp) + "\\" + nome
        local bm = dotNetObject "System.Drawing.Bitmap" 128 128
        local claro = (dotNetClass "System.Drawing.Color").FromArgb 230 230 230
        local escuro = (dotNetClass "System.Drawing.Color").FromArgb 40 40 40
        for y = 0 to 127 do
        (
            local c = if (mod (y / 4) 2) == 0 then escuro else claro
            for x = 0 to 127 do bm.SetPixel x y c
        )
        bm.Save arq
        bm.Dispose()
        arq
    )
    fn criarMaterial nome arq canal:1 =
    (
        local b = Bitmaptexture filename:arq
        b.coords.mapChannel = canal
        Standardmaterial name:nome diffuseMap:b
    )
    -- peça com UV de UVW Box de 60 cm gravado na base (colapsado)
    fn comUVBox o =
    (
        addModifier o (Uvwmap maptype:4 length:60 width:60 height:60)
        convertToPoly o
        o
    )

    local criados = #()
    local arqImg = undefined
    local feitosAntes = InLab_RWF_Feitos
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
        InLab_UltimoMapear = #()
        InLab_RWF_Feitos = #()

        local js = "{\"produtos\": [{\"cod_est\": \"0001\", \"partes\": [" +
            "{\"nome_parte\": \"Pe\", \"materia_prima\": {\"familia\": \"Madeira\", \"materia\": \"Cedro\"}, \"material_id\": \"ART_Pe\"}, " +
            "{\"nome_parte\": \"Assento\", \"materia_prima\": {\"familia\": \"Tecido\", \"materia\": \"\"}, \"material_id\": \"ART_Tecido\"}, " +
            "{\"nome_parte\": \"Capa\", \"materia_prima\": {\"familia\": \"Tecido\", \"materia\": \"\"}, \"material_id\": \"ART_Capa\"}, " +
            "{\"nome_parte\": \"Base\", \"materia_prima\": {\"familia\": \"Metal\", \"materia\": \"\"}, \"material_id\": \"ART_Metal\"}, " +
            "{\"nome_parte\": \"BaseRW\", \"materia_prima\": {\"familia\": \"Metal\", \"materia\": \"\"}, \"material_id\": \"ART_MetalRW\"}, " +
            "{\"nome_parte\": \"CapaB\", \"materia_prima\": {\"familia\": \"Tecido\", \"materia\": \"\"}, \"material_id\": \"ART_CapaB\"}, " +
            "{\"nome_parte\": \"CapaH\", \"materia_prima\": {\"familia\": \"Tecido\", \"materia\": \"\"}, \"material_id\": \"ART_CapaH\"}, " +
            "{\"nome_parte\": \"PeRW\", \"materia_prima\": {\"familia\": \"Madeira\", \"materia\": \"Cedro\"}, \"material_id\": \"ART_PeRW\"}, " +
            "{\"nome_parte\": \"PeRWB\", \"materia_prima\": {\"familia\": \"Madeira\", \"materia\": \"Cedro\"}, \"material_id\": \"ART_PeRWB\"}, " +
            "{\"nome_parte\": \"Acabamento\", \"materia_prima\": {\"familia\": \"\", \"materia\": \"\"}, \"material_id\": \"ART_Vazia\"}]}]}"
        local produto = (InLab_Produto_Lista (InLab_ParseJSON js))[1]
        arqImg = gerarImagem "inlab_test_mapear_listras.png"
        local mPe = criarMaterial "ART_Pe" arqImg
        local mTec = criarMaterial "ART_Tecido" arqImg
        local mMet = criarMaterial "ART_Metal" arqImg
        local mVaz = Standardmaterial name:"ART_Vazia"
        local mRW = criarMaterial "ART_MetalRW" arqImg
        mRW.diffuseMap.coords.realWorldScale = true
        mRW.diffuseMap.coords.realWorldWidth = 50
        mRW.diffuseMap.coords.realWorldHeight = 50
        local mCapa = criarMaterial "ART_Capa" arqImg canal:2
        local bump = Bitmaptexture filename:arqImg
        bump.coords.mapChannel = 2
        bump.coords.U_Tiling = 2.0; bump.coords.V_Tiling = 2.0
        mCapa.bumpMap = bump

        -- 1. pé de madeira com o veio atravessado (UVW Box num cilindro alto)
        local pe = comUVBox (Cylinder radius:2.5 height:80 heightsegs:5 sides:16 mapcoords:true name:"TESTE_map_pe")
        pe.material = mPe; append criados pe
        -- 2. toro de tecido com UVW Box
        local toro = comUVBox (Torus radius1:30 radius2:3 segments:48 sides:12 mapcoords:true name:"TESTE_map_toro" pos:[150,0,0])
        toro.material = mTec; append criados toro
        -- 3. Box de metal com bitmap e UV bom
        local met = comUVBox (Box length:50 width:50 height:50 mapcoords:true name:"TESTE_map_metal" pos:[0,150,0])
        met.material = mMet; append criados met
        -- 4. sem família, sem canal 1
        local vaz = Box length:40 width:40 height:40 mapcoords:true name:"TESTE_map_vazia" pos:[0,-150,0]
        convertToPoly vaz
        polyop.setMapSupport vaz 1 false
        vaz.material = mVaz; append criados vaz
        -- 5. tecido já bem mapeado
        local bem = Torus radius1:30 radius2:3 segments:48 sides:12 mapcoords:true name:"TESTE_map_bem" pos:[150,150,0]
        convertToPoly bem
        local rb = InLab_Mapear_GerarTubo bem #{1..(polyop.getNumFaces bem)} (1.0 / 60)
        InLab_Mapear_Gravar bem rb[1] rb[2]
        bem.material = mTec; append criados bem
        -- 6. bitmap em Real-World sem RWF
        local rw = comUVBox (Box length:50 width:50 height:50 mapcoords:true name:"TESTE_map_rw" pos:[300,0,0])
        rw.material = mRW; append criados rw
        -- 7. instâncias de madeira
        local i1 = comUVBox (Cylinder radius:2 height:60 heightsegs:4 sides:12 mapcoords:true name:"TESTE_map_inst1" pos:[300,150,0])
        i1.material = mPe; append criados i1
        local i2 = instance i1 name:"TESTE_map_inst2" pos:[330,150,0]
        append criados i2
        -- 8. grupo fechado
        local gm1 = comUVBox (Cylinder radius:2 height:60 heightsegs:4 sides:12 mapcoords:true name:"TESTE_map_grupo_pe" pos:[-150,0,0])
        gm1.material = mPe
        local gm2 = comUVBox (Box length:30 width:30 height:30 mapcoords:true name:"TESTE_map_grupo_box" pos:[-200,0,0])
        gm2.material = mMet
        local grp = group #(gm1, gm2) name:"TESTE_map_grupo"
        setGroupOpen grp false
        append criados gm1; append criados gm2; append criados grp
        -- 9. peça com RWF no stack (canal 1 e Triplanar no canal 2, #169) e AutoUV no canal 3
        local cp = Box length:50 width:50 height:50 lengthsegs:2 widthsegs:2 heightsegs:2 mapcoords:true name:"TESTE_map_rwf" pos:[-150,150,0]
        convertToPoly cp
        cp.material = mCapa; append criados cp
        local rwf1 = Uvwmap name:"InLab RWF Triplanar" maptype:4 length:1 width:1 height:1 mapChannel:1
        addModifier cp rwf1
        local rwf2 = Uvwmap name:"InLab RWF Triplanar" maptype:4 length:50 width:50 height:50 mapChannel:2
        addModifier cp rwf2
        local auv = Uvwmap name:"InLab AutoUV" maptype:4 length:37 width:37 height:37 mapChannel:3
        addModifier cp auv
        append InLab_RWF_Feitos cp
        local modsCpAntes = for m in cp.modifiers collect m
        local canal3Antes = canalSnapshot cp 3
        -- 10. UVW Map do usuário no canal 1 acima da base
        local us = Box length:30 width:30 height:30 mapcoords:true name:"TESTE_map_usuario" pos:[-300,0,0]
        convertToPoly us
        addModifier us (Uvwmap name:"UVW do usuario" maptype:4 length:60 width:60 height:60)
        us.material = mPe; append criados us

        -- estado antes
        local antes = #()
        for o in #(pe, toro, met, vaz, bem, rw, i1, gm1, cp, us) do append antes (InLab_Mapear_LerCanal1 o)

        ------------------------------------------------------------------
        local objs = #(pe, toro, met, vaz, bem, rw, i1, i2, gm1, cp, us)
        local nRef = InLab_Mapear objs produto
        linha ("      refeitas = " + nRef as string)

        local mPe2 = InLab_Mapear_Medir pe
        linha ("      pé: veioOk=" + mPe2.veioOk as string + " escala=" + mPe2.escala as string)
        checar "madeira refeita: veioOk > 0.8" (mPe2.veioOk > 0.8)
        checar "madeira: densidade de 60 cm preservada" (abs (mPe2.escala - 1.0/60) < (1.0/60) * 0.15)
        local mTo = InLab_Mapear_Medir toro
        linha ("      toro: emenda=" + mTo.emendaVistaQuebra as string + " esp=" + mTo.espelhado as string)
        checar "toro refeito: emendaVistaQuebra < 0.01" (mTo.emendaVistaQuebra < 0.01)
        checar "Box de metal bem mapeado mantido (canal 1 idêntico)" (igualCanal antes[3] (InLab_Mapear_LerCanal1 met))
        checar "sem família ganhou canal 1 e #warn" ((polyop.getMapSupport vaz.baseobject 1) and (temLog logs #warn "TESTE_map_vazia" "sem matéria-prima"))
        checar "peça bem mapeada mantida" (igualCanal antes[5] (InLab_Mapear_LerCanal1 bem) and (temLog logs #ok "TESTE_map_bem" "mantido"))
        checar "peça sem RWF com bitmap Real-World pulada com #err" ((temLog logs #err "TESTE_map_rw" "Real World Fix") and igualCanal antes[6] (InLab_Mapear_LerCanal1 rw))
        checar "instância: mapeada uma vez e as duas iguais" ((contaLog logs "TESTE_map_inst" "refeito") == 1 and \
            (temLog logs #info "TESTE_map_inst2" "instância de TESTE_map_inst1") and \
            (igualLista (canalSnapshot i1 1) (canalSnapshot i2 1)) and (not (igualCanal antes[7] (InLab_Mapear_LerCanal1 i1))))
        checar "instância continua instância" ((InLab_Instancias i1).count == 2)
        checar "grupo fechado continua fechado e com os mesmos membros" (isValidNode grp and (not (isOpenGroupHead grp)) and \
            gm1.parent == grp and gm2.parent == grp and grp.children.count == 2 and (isGroupMember gm1))
        checar "membro do grupo refeito" (not (igualCanal antes[8] (InLab_Mapear_LerCanal1 gm1)))
        -- peça com RWF
        local nRWF = (for m in cp.modifiers where matchPattern m.name pattern:"InLab RWF*" collect m).count
        checar "RWF: modificadores InLab RWF tirados" (nRWF == 0)
        checar "RWF: difuso e bump religados ao canal 1" (mCapa.diffuseMap.coords.mapChannel == 1 and bump.coords.mapChannel == 1)
        checar "RWF: tiling preservado (Triplanar de 50 cm -> 1 tile a cada 50 cm)" \
            ((abs (mCapa.diffuseMap.coords.U_Tiling - 1.0)) < 1e-3 and (abs (bump.coords.U_Tiling - 2.0)) < 1e-3)
        local mCp = InLab_Mapear_Medir cp
        linha ("      rwf: escala=" + mCp.escala as string + " emenda=" + mCp.emendaVistaQuebra as string)
        checar "RWF: canal 1 com 1 tile a cada 50 cm" (abs (mCp.escala - 1.0/50) < (1.0/50) * 0.05)
        checar "canal 3 e InLab AutoUV intactos" ((findItem (for m in cp.modifiers collect m) auv) > 0 and igualLista canal3Antes (canalSnapshot cp 3))
        checar "UVW do usuário no canal 1: pulada com #warn" ((temLog logs #warn "TESTE_map_usuario" "canal 1") and igualCanal antes[10] (InLab_Mapear_LerCanal1 us))
        checar "resumo no log" (temLog logs #warn "Mapear:" "pulada(s)")
        checar "registros acumulados" (InLab_UltimoMapear.count == nRef and nRef >= 6)

        -- 11. unwrap opcional nas peças grandes de tecido
        -- (fix round 1: a Sphere de quads não passa mais por tubo, proporção < 4x)
        local esf = Sphere radius:30 segs:24 mapcoords:true name:"TESTE_map_esfera" pos:[0,300,0]
        convertToPoly esf
        esf.material = mTec; append criados esf
        polyop.setMapSupport esf.baseobject 1 false
        InLab_Mapear #(esf) produto unwrapGrande:true
        local mEs = InLab_Mapear_Medir esf
        linha ("      esfera unwrap: escala=" + mEs.escala as string + " esp=" + mEs.espelhado as string + " emenda=" + mEs.emendaVistaQuebra as string)
        checar "unwrapGrande: canal 1 criado, densidade do alvo (±15%)" (mEs.temCanal and abs (mEs.escala - 1.0/60) < (1.0/60) * 0.15)
        checar "unwrapGrande: sem espelhamento" (mEs.espelhado < 0.01)
        checar "unwrapGrande: nó temporário apagado" ((for o in objects where matchPattern o.name pattern:"InLab_Mapear_tmp*" collect o).count == 0)
        checar "unwrapGrande: caminho do Unwrap rodou (sem queda para a caixa)" (not (temLog logs #warn "TESTE_map_esfera" "Unwrap da peça grande falhou"))
        -- peça grande de tecido sem unwrap: Box simples e aviso de corte à vista
        local esf2 = Sphere radius:30 segs:24 mapcoords:true name:"TESTE_map_esfera2" pos:[0,450,0]
        convertToPoly esf2
        polyop.setMapSupport esf2.baseobject 1 false
        esf2.material = mTec; append criados esf2
        InLab_Mapear #(esf2) produto
        local mEs2 = InLab_Mapear_Medir esf2
        linha ("      esfera caixa: emenda=" + mEs2.emendaVistaQuebra as string + " (unwrap " + mEs.emendaVistaQuebra as string + ")")
        checar "peça grande de tecido com caixa: #warn corte à vista" ((mEs2.emendaVistaQuebra > 0.02) == (temLog logs #warn "TESTE_map_esfera2" "considere o Unwrap") and mEs2.emendaVistaQuebra > 0.02)

        -- 12. Desfazer
        local nRev = InLab_ReverterMapear()
        checar "Desfazer devolve o nº de peças" (nRev == nRef + 2)
        local okCanais = true
        local nomes = #("pe", "toro", "met", "vaz", "bem", "rw", "i1", "gm1", "cp", "us")
        local nos = #(pe, toro, met, vaz, bem, rw, i1, gm1, cp, us)
        for k = 1 to nos.count do
            if not (igualCanal antes[k] (InLab_Mapear_LerCanal1 nos[k])) do ( okCanais = false; linha ("      canal diferente depois do Desfazer: " + nomes[k]) )
        local modsCpDepois = for m in cp.modifiers collect m
        local okMods = modsCpDepois.count == modsCpAntes.count
        if okMods do for k = 1 to modsCpAntes.count do if modsCpDepois[k] != modsCpAntes[k] do okMods = false
        checar "Desfazer restaura o canal 1 exato e os modificadores InLab RWF na mesma posição" (okCanais and okMods)
        checar "Desfazer devolve o canal dos bitmaps" (mCapa.diffuseMap.coords.mapChannel == 2 and bump.coords.mapChannel == 2 and \
            (abs (bump.coords.U_Tiling - 2.0)) < 1e-3)
        checar "Desfazer: esfera sem canal 1 de novo" (not (polyop.getMapSupport esf.baseobject 1))
        checar "Desfazer zera InLab_UltimoMapear" (InLab_UltimoMapear.count == 0)
        checar "canal 3 intacto depois do Desfazer" (igualLista canal3Antes (canalSnapshot cp 3))

        ------------------------------------------------------------------
        -- 13. FIX ROUND 1
        ------------------------------------------------------------------
        logs.count = 0
        local mPeRW = criarMaterial "ART_PeRW" arqImg
        mPeRW.diffuseMap.coords.realWorldScale = true
        mPeRW.diffuseMap.coords.realWorldWidth = 60; mPeRW.diffuseMap.coords.realWorldHeight = 60
        local mPeRWB = criarMaterial "ART_PeRWB" arqImg
        mPeRWB.diffuseMap.coords.realWorldScale = true
        mPeRWB.diffuseMap.coords.realWorldWidth = 60; mPeRWB.diffuseMap.coords.realWorldHeight = 60
        local mCapaA = criarMaterial "ART_Capa" arqImg canal:2
        local mCapaB = criarMaterial "ART_CapaB" arqImg canal:2
        local mCapaH = criarMaterial "ART_CapaH" arqImg canal:2

        -- B: bases que não são Editable_Poly
        local b1 = Box length:40 width:40 height:40 mapcoords:false name:"TESTE_fx_box_prim" pos:[0,-400,0]
        b1.material = mVaz; append criados b1
        local b2 = Box length:40 width:40 height:40 mapcoords:false name:"TESTE_fx_box_inst1" pos:[100,-400,0]
        b2.material = mVaz; append criados b2
        local b2i = instance b2 name:"TESTE_fx_box_inst2" pos:[150,-400,0]
        append criados b2i
        local b3 = Box length:40 width:40 height:40 mapcoords:true name:"TESTE_fx_mesh" pos:[200,-400,0]
        convertToMesh b3
        meshop.setMapSupport b3 1 false
        b3.material = mVaz; append criados b3
        local b4 = Box length:40 width:40 height:40 mapcoords:true name:"TESTE_fx_mesh_unwrap" pos:[300,-400,0]
        convertToMesh b4
        meshop.setMapSupport b4 1 false
        b4.material = mVaz; append criados b4
        select b4; max modify mode
        local uw = Unwrap_UVW(); uw.name = "InLab AutoUV"
        addModifier b4 uw
        modPanel.setCurrentObject uw
        uw.setMapChannel 3
        clearSelection()
        local canal3B4 = canalSnapshot b4 3
        local b5 = Cylinder radius:5 height:20 sides:24 mapcoords:false name:"TESTE_fx_cil_prim" pos:[400,-400,0]
        b5.material = mVaz; append criados b5

        -- C: Multi/Sub com dois IDs lendo o canal 2 do RWF; o ID 2 falha de propósito
        local mc = Box length:50 width:50 height:50 mapcoords:true name:"TESTE_fx_multi" pos:[0,-550,0]
        convertToPoly mc
        for f = 1 to 6 do polyop.setFaceMatID mc f (if f <= 3 then 1 else 2)
        local mm = Multimaterial numsubs:2
        mm.materialList[1] = mCapaA; mm.materialList[2] = mCapaB
        mc.material = mm; append criados mc
        local rwfC = Uvwmap name:"InLab RWF Triplanar" maptype:4 length:50 width:50 height:50 mapChannel:2
        addModifier mc rwfC
        append InLab_RWF_Feitos mc

        -- E1: UV avaliado do ID mantido com RWF no canal 1
        local ma = Box length:50 width:50 height:150 mapcoords:true name:"TESTE_fx_avaliado" pos:[100,-550,0]
        convertToPoly ma
        for f = 1 to (polyop.getNumFaces ma) do
            polyop.setFaceMatID ma f (if (abs (polyop.getFaceNormal ma f).z) > 0.9 then 1 else 2)
        local mm2 = Multimaterial numsubs:2
        mm2.materialList[1] = mMet; mm2.materialList[2] = mPe
        ma.material = mm2; append criados ma
        addModifier ma (Uvwmap name:"InLab RWF Triplanar" maptype:4 length:60 width:60 height:60 mapChannel:1)
        append InLab_RWF_Feitos ma
        fn canalID o id =
        (
            local m = snapshotAsMesh o
            local r = #()
            for f = 1 to m.numfaces where (getFaceMatID m f) == id do
            (
                local tv = meshop.getMapFace m 1 f
                for k = 1 to 3 do append r (meshop.getMapVert m 1 tv[k])
            )
            delete m
            r
        )
        local uvID1Antes = canalID ma 1

        -- E3: caso B do RWF (UV em cm na malha + bitmap Real-World -> Xform no topo)
        local eb = Cylinder radius:2.5 height:80 heightsegs:5 sides:16 mapcoords:true name:"TESTE_fx_rwf_b" pos:[300,-550,0]
        addModifier eb (Uvwmap maptype:4 length:1 width:1 height:1)
        convertToPoly eb
        eb.material = mPeRWB; append criados eb
        InLab_RWF_Rodar #(eb)
        local modsEB = for m in eb.modifiers collect m
        checar "caso B: RWF pôs o Xform \"InLab RWF\" no topo" (modsEB.count == 1 and classof modsEB[1] == UVW_Xform and modsEB[1].name == "InLab RWF")
        local canalEBAntes = InLab_Mapear_LerCanal1 eb

        -- H1: densidade do canal do RWF implausível (1 cm) -> 60 cm sem compensar o tiling
        local hp = Box length:50 width:50 height:50 mapcoords:true name:"TESTE_fx_h1" pos:[400,-550,0]
        convertToPoly hp
        hp.material = mCapaH; append criados hp
        addModifier hp (Uvwmap name:"InLab RWF Triplanar" maptype:4 length:1 width:1 height:1 mapChannel:2)
        append InLab_RWF_Feitos hp

        -- G: peça sem faces
        local gz = Box length:10 width:10 height:10 name:"TESTE_fx_vazia" pos:[500,-550,0]
        convertToPoly gz
        polyop.deleteFaces gz #{1..(polyop.getNumFaces gz)}
        gz.material = mVaz; append criados gz

        InLab_Mapear_ForcarFalha = "TESTE_fx_multi (ID 2)"
        logs.count = 0
        local nFx = InLab_Mapear #(b1, b2, b2i, b3, b4, b5, mc, ma, eb, hp, gz) produto
        InLab_Mapear_ForcarFalha = undefined
        linha ("      fix round 1: refeitas = " + nFx as string)
        -- B
        checar "B: Box primitiva sem modificador vira Editable_Poly com canal 1" ((classof b1.baseobject) == Editable_Poly and (polyop.getMapSupport b1.baseobject 1))
        checar "B: Box primitiva com 2 instâncias: continuam instâncias, UV gravado" ((InLab_Instancias b2).count == 2 and \
            (classof b2i.baseobject) == Editable_Poly and igualLista (canalSnapshot b2 1) (canalSnapshot b2i 1))
        checar "B: Editable_Mesh sem modificador vira Editable_Poly com canal 1" ((classof b3.baseobject) == Editable_Poly and (polyop.getMapSupport b3.baseobject 1))
        checar "B: Editable_Mesh com Unwrap acima: pulada com #warn e canal 3 intacto" ((classof b4.baseobject) == Editable_mesh and \
            (temLog logs #warn "TESTE_fx_mesh_unwrap" "Unwrap acima da base") and igualLista canal3B4 (canalSnapshot b4 3))
        checar "B: Cylinder primitiva (triângulos mudam): #err e base devolvida" ((classof b5.baseobject) == Cylinder and \
            (temLog logs #err "TESTE_fx_cil_prim" "triângulos de render"))
        -- C
        checar "C: modificador do canal 2 continua com o ID 2 não refeito" ((findItem (for m in mc.modifiers collect m) rwfC) > 0 and \
            (temLog logs #warn "TESTE_fx_multi" "canal 2 do Real World Fix continua"))
        checar "C: bitmap do ID não refeito continua lendo o canal 2" (mCapaB.diffuseMap.coords.mapChannel == 2)
        checar "C: ID 1 refeito" (temLog logs #ok "TESTE_fx_multi (ID 1)" "refeito")
        -- E1
        checar "E1: ID 2 refeito e RWF do canal 1 tirado" ((temLog logs #ok "TESTE_fx_avaliado (ID 2)" "refeito") and ma.modifiers.count == 0)
        checar "E1: UV visível do ID mantido não muda (UV avaliado copiado)" (igualLista uvID1Antes (canalID ma 1))
        -- E3
        checar "caso B: refeita e Xform \"InLab RWF\" tirado" ((temLog logs #ok "TESTE_fx_rwf_b" "refeito") and eb.modifiers.count == 0)
        -- H1
        local mH = InLab_Mapear_Medir hp
        checar "H1: canal implausível -> 60 cm, tiling não compensado e #warn verdadeiro" ((abs (mCapaH.diffuseMap.coords.U_Tiling - 1.0)) < 1e-4 and \
            mCapaH.diffuseMap.coords.mapChannel == 1 and (abs (mH.escala - 1.0/60)) < (1.0/60) * 0.05 and (temLog logs #warn "TESTE_fx_h1" "passa a 60,0 cm"))
        -- G
        checar "G: peça sem faces: #info 'nada a mapear' e fora das contagens" ((temLog logs #info "TESTE_fx_vazia" "nada a mapear") and \
            (temLog logs #warn "Mapear: 7 refeita(s), 0 mantida(s), 2 pulada(s)" "."))

        -- E2 + D: caso A do RWF (UVW Map Real-World com o Xform logo acima), Ctrl+Z e Desfazer
        local ea = Cylinder radius:2.5 height:80 heightsegs:5 sides:16 mapcoords:true name:"TESTE_fx_rwf_a" pos:[200,-550,0]
        convertToPoly ea
        ea.material = mPeRW; append criados ea
        local uRW = Uvwmap maptype:4 length:1 width:1 height:1
        uRW.realWorldMapSize = true
        addModifier ea uRW
        InLab_RWF_Rodar #(ea)
        local modsEA = for m in ea.modifiers collect m
        checar "caso A: RWF pôs o Xform \"InLab RWF\" logo acima do UVW Map" (modsEA.count == 2 and modsEA[1].name == "InLab RWF" and modsEA[2] == uRW)
        local canalEAAntes = InLab_Mapear_LerCanal1 ea
        local uvEAAntes = canalSnapshot ea 1
        logs.count = 0
        InLab_Mapear #(ea) produto
        checar "caso A: refeita, UVW Map e Xform saem juntos" ((temLog logs #ok "TESTE_fx_rwf_a" "refeito") and ea.modifiers.count == 0)
        max undo
        checar "D: Ctrl+Z devolveu os modificadores" (ea.modifiers.count == 2)
        InLab_ReverterMapear()
        local nUVW = (for m in ea.modifiers where m == uRW collect m).count
        local nX = (for m in ea.modifiers where m == modsEA[1] collect m).count
        checar "D: Desfazer depois do Ctrl+Z: cada modificador uma vez só" (ea.modifiers.count == 2 and nUVW == 1 and nX == 1 and ea.modifiers[1] == modsEA[1])
        checar "D: canal 1 original (base e visível)" (igualCanal canalEAAntes (InLab_Mapear_LerCanal1 ea) and igualLista uvEAAntes (canalSnapshot ea 1))
        checar "caso B: Desfazer devolve o Xform e o canal" (eb.modifiers.count == 1 and eb.modifiers[1] == modsEB[1] and igualCanal canalEBAntes (InLab_Mapear_LerCanal1 eb))
        checar "E1: Desfazer devolve o RWF do canal 1 e o UV visível" (ma.modifiers.count == 1 and igualLista uvID1Antes (canalID ma 1))

        -- H2: a remedição falha depois de refeita: conta como refeita
        local h2 = Box length:40 width:40 height:40 mapcoords:true name:"TESTE_fx_h2" pos:[600,-550,0]
        convertToPoly h2
        polyop.setMapSupport h2 1 false
        h2.material = mVaz; append criados h2
        INLAB_TESTE_MEDIR_ORIG = InLab_Mapear_Medir
        INLAB_TESTE_MEDIR_N = 0
        InLab_Mapear_Medir = fn _medirTeste o faces:undefined matID:undefined =
        (
            INLAB_TESTE_MEDIR_N += 1
            if INLAB_TESTE_MEDIR_N > 1 do throw "remedição forçada a falhar"
            INLAB_TESTE_MEDIR_ORIG o faces:faces matID:matID
        )
        logs.count = 0
        local nH2 = 0
        try ( nH2 = InLab_Mapear #(h2) produto ) catch ( linha ("      H2 exceção: " + getCurrentException()) )
        InLab_Mapear_Medir = INLAB_TESTE_MEDIR_ORIG
        checar "H2: remedição que falha não vira pulada" (nH2 == 1 and (temLog logs #warn "TESTE_fx_h2" "medição de conferência falhou") and \
            (temLog logs #ok "Mapear: 1 refeita(s), 0 mantida(s), 0 pulada(s)" "."))
        InLab_ReverterMapear()

        ------------------------------------------------------------------
        -- 14. CASOS DE BORDA DO STACK (Tarefa 6)
        ------------------------------------------------------------------
        -- TurboSmooth e Symmetry acima da base: mapeia na base e avisa
        local ts = comUVBox (Cylinder radius:2.5 height:80 heightsegs:5 sides:16 mapcoords:true name:"TESTE_t6_turbo" pos:[0,-700,0])
        ts.material = mPe; append criados ts
        addModifier ts (TurboSmooth iterations:1)
        local sy = comUVBox (Cylinder radius:2.5 height:80 heightsegs:5 sides:16 mapcoords:true name:"TESTE_t6_simetria" pos:[100,-700,0])
        sy.material = mPe; append criados sy
        addModifier sy (Symmetry())
        local canalTsAntes = InLab_Mapear_LerCanal1 ts
        logs.count = 0
        local nT6 = InLab_Mapear #(ts, sy) produto
        linha ("      t6 stack: refeitas = " + nT6 as string)
        checar "T6 TurboSmooth acima: mapeada na base com #warn \"UV calculado na base, abaixo de\"" ((temLog logs #ok "TESTE_t6_turbo" "refeito") and             (temLog logs #warn "TESTE_t6_turbo" "UV calculado na base, abaixo de") and ts.modifiers.count == 1 and classof ts.modifiers[1] == TurboSmooth and             not (igualCanal canalTsAntes (InLab_Mapear_LerCanal1 ts)))
        checar "T6 Symmetry acima: #warn \"pode espelhar o UV\"" ((temLog logs #ok "TESTE_t6_simetria" "refeito") and (temLog logs #warn "TESTE_t6_simetria" "pode espelhar o UV"))
        InLab_ReverterMapear()
        checar "T6 Desfazer devolve o canal 1 da peça com TurboSmooth" (igualCanal canalTsAntes (InLab_Mapear_LerCanal1 ts) and ts.modifiers.count == 1)

        -- Multi/Sub: ID 1 Madeira (laterais, veio atravessado) + ID 2 Metal (tampas, UV bom, mantido)
        local ms1 = comUVBox (Cylinder radius:2.5 height:80 heightsegs:5 sides:16 mapcoords:true name:"TESTE_t6_multi" pos:[200,-700,0])
        for f = 1 to (polyop.getNumFaces ms1) do
            polyop.setFaceMatID ms1 f (if (abs (polyop.getFaceNormal ms1 f).z) > 0.9 then 2 else 1)
        local mmT6 = Multimaterial numsubs:2
        mmT6.materialList[1] = mPe; mmT6.materialList[2] = mMet
        ms1.material = mmT6; append criados ms1
        local uvT6id1 = canalID ms1 1
        local uvT6id2 = canalID ms1 2
        logs.count = 0
        InLab_Mapear #(ms1) produto
        checar "T6 Multi/Sub: ID 1 madeira refeito pela regra da madeira" (temLog logs #ok "TESTE_t6_multi (ID 1)" "refeito (madeira")
        checar "T6 Multi/Sub: ID 2 mantido, faces do ID 2 com o UV de antes" ((temLog logs #ok "TESTE_t6_multi (ID 2)" "mantido") and igualLista uvT6id2 (canalID ms1 2))
        checar "T6 Multi/Sub: faces do ID 1 mudaram" (not (igualLista uvT6id1 (canalID ms1 1)))
        InLab_ReverterMapear()
        checar "T6 Multi/Sub: Desfazer devolve o UV dos dois IDs" (igualLista uvT6id1 (canalID ms1 1) and igualLista uvT6id2 (canalID ms1 2))

        -- Multi/Sub: ID 1 Madeira + ID 2 Tecido (cada um com a sua regra)
        local ms2 = Torus radius1:30 radius2:3 segments:48 sides:12 mapcoords:true name:"TESTE_t6_multi2" pos:[300,-700,0]
        addModifier ms2 (Uvwmap maptype:4 length:60 width:60 height:60)
        convertToPoly ms2
        local nf2 = polyop.getNumFaces ms2
        for f = 1 to nf2 do polyop.setFaceMatID ms2 f (if f <= nf2 / 2 then 1 else 2)
        local mmT6b = Multimaterial numsubs:2
        mmT6b.materialList[1] = mPe; mmT6b.materialList[2] = mTec
        ms2.material = mmT6b; append criados ms2
        logs.count = 0
        InLab_Mapear #(ms2) produto
        checar "T6 Multi/Sub madeira+tecido: cada ID com a sua regra" ((contaLog logs "TESTE_t6_multi2 (ID 1)" "(madeira") == 1 and (contaLog logs "TESTE_t6_multi2 (ID 2)" "(tecido") == 1)
        InLab_ReverterMapear()

        -- RWF + Mapear + Desfazer UV (Reverter do Auto UV) sem exceção
        local mPeRWC = criarMaterial "ART_PeRWB" arqImg
        mPeRWC.diffuseMap.coords.realWorldScale = true
        mPeRWC.diffuseMap.coords.realWorldWidth = 60; mPeRWC.diffuseMap.coords.realWorldHeight = 60
        local rr = Cylinder radius:2.5 height:80 heightsegs:5 sides:16 mapcoords:true name:"TESTE_t6_rwf" pos:[400,-700,0]
        addModifier rr (Uvwmap maptype:4 length:1 width:1 height:1)
        convertToPoly rr
        rr.material = mPeRWC; append criados rr
        InLab_UltimoRWF = #(); InLab_UltimoAutoUV = #()
        local canalRRAntes = InLab_Mapear_LerCanal1 rr
        local uvRRAntes = canalSnapshot rr 1
        InLab_RWF_Rodar #(rr)
        InLab_Mapear #(rr) produto
        checar "T6 RWF+Mapear: modificadores InLab RWF saíram" (rr.modifiers.count == 0)
        logs.count = 0
        local excRev = undefined
        try ( InLab_ReverterAutoUV() ) catch ( excRev = getCurrentException() )
        if excRev != undefined do linha ("      exceção no Desfazer UV: " + excRev)
        checar "T6 RWF+Mapear+Desfazer UV (InLab_ReverterAutoUV): sem exceção" (excRev == undefined)
        checar "T6 Desfazer UV desfez antes o Mapear (#info) e concluiu" ((temLog logs #info "Desfazer UV" "desfazendo antes o Mapear") and (temLog logs #info "Reversão de UV concluída" ""))
        checar "T6 Desfazer UV: InLab_UltimoMapear vazio e sem modificadores" (InLab_UltimoMapear.count == 0 and rr.modifiers.count == 0)
        checar "T6 Desfazer UV: canal 1 igual ao de antes do RWF" (igualCanal canalRRAntes (InLab_Mapear_LerCanal1 rr) and igualLista uvRRAntes (canalSnapshot rr 1))
        checar "T6 Desfazer UV: bitmap com Real-World como antes do RWF" (mPeRWC.diffuseMap.coords.realWorldScale and             (abs (mPeRWC.diffuseMap.coords.realWorldWidth - 60)) < 1e-3 and mPeRWC.diffuseMap.coords.mapChannel == 1)
        -- stack colapsado pelo usuário depois do RWF: continua #warn
        local rc = Cylinder radius:2.5 height:80 heightsegs:5 sides:16 mapcoords:true name:"TESTE_t6_colapsado" pos:[500,-700,0]
        addModifier rc (Uvwmap maptype:4 length:1 width:1 height:1)
        convertToPoly rc
        rc.material = mPeRWC; append criados rc
        InLab_UltimoRWF = #(); InLab_UltimoAutoUV = #()
        InLab_RWF_Rodar #(rc)
        convertToPoly rc
        logs.count = 0
        try ( InLab_ReverterAutoUV() ) catch ( linha ("      exceção: " + getCurrentException()) )
        checar "T6 stack colapsado pelo usuário: #warn \"não está mais no stack\"" (temLog logs #warn "TESTE_t6_colapsado" "não está mais no stack")

        ------------------------------------------------------------------
        -- 15. REVISÃO FINAL
        ------------------------------------------------------------------
        InLab_UltimoMapear = #()
        -- I1: escala do nó
        local s1 = Box length:400 width:400 height:400 mapcoords:false name:"TESTE_rf_escala" pos:[0,-900,0]
        convertToPoly s1
        polyop.setMapSupport s1 1 false
        s1.scale = [0.1, 0.1, 0.1]
        s1.material = mVaz; append criados s1
        local s2 = Box length:40 width:40 height:40 mapcoords:false name:"TESTE_rf_nao_uniforme" pos:[100,-900,0]
        convertToPoly s2
        polyop.setMapSupport s2 1 false
        s2.scale = [1, 1, 2]
        s2.material = mVaz; append criados s2
        -- I2: bitmap compartilhado com peça fora da seleção
        local mCompart = criarMaterial "ART_Capa" arqImg canal:2
        local bx1 = Box length:50 width:50 height:50 mapcoords:true name:"TESTE_rf_dentro" pos:[200,-900,0]
        local bx2 = Box length:50 width:50 height:50 mapcoords:true name:"TESTE_rf_fora" pos:[300,-900,0]
        for b in #(bx1, bx2) do
        (
            convertToPoly b
            b.material = mCompart; append criados b
            addModifier b (Uvwmap name:"InLab RWF Triplanar" maptype:4 length:50 width:50 height:50 mapChannel:2)
            append InLab_RWF_Feitos b
        )
        local canalFora = InLab_Mapear_LerCanal1 bx2
        local modFora = bx2.modifiers[1]
        -- I4: Multi/Sub sem RWF, ID 1 mantido e ID 2 refeito
        local i4 = Box length:50 width:50 height:150 lengthsegs:2 widthsegs:2 heightsegs:1 mapcoords:true name:"TESTE_rf_ilhas" pos:[400,-900,0]
        convertToPoly i4
        for f = 1 to (polyop.getNumFaces i4) do
            polyop.setFaceMatID i4 f (if (abs (polyop.getFaceNormal i4 f).z) > 0.9 then 1 else 2)
        local mm4 = Multimaterial numsubs:2
        mm4.materialList[1] = mMet; mm4.materialList[2] = mPe
        i4.material = mm4; append criados i4
        fn vertsDoID o id =
        (
            local r = #{}
            for f = 1 to (polyop.getNumFaces o) where (polyop.getFaceMatID o f) == id do
                for mv in (polyop.getMapFace o 1 f) do r[mv] = true
            r.numberSet
        )
        local nV4Antes = vertsDoID i4 1
        -- minor a: três toros num objeto só, uma linha de tubos
        local tt = Torus radius1:30 radius2:3 segments:48 sides:12 mapcoords:true name:"TESTE_rf_toros" pos:[0,-1100,0]
        convertToPoly tt
        for k = 1 to 2 do
        (
            local t2 = Torus radius1:30 radius2:3 segments:48 sides:12 mapcoords:true pos:[0,-1100,10 * k]
            convertToPoly t2
            polyop.attach tt t2
        )
        addModifier tt (Uvwmap maptype:4 length:60 width:60 height:60)
        convertToPoly tt
        tt.material = mTec; append criados tt

        logs.count = 0
        InLab_Mapear #(s1, s2, bx1, i4, tt) produto
        local mS1 = InLab_Mapear_Medir s1
        linha ("      escala 0,1: medido " + (1.0 / mS1.escala) as string + " cm por tile")
        checar "I1: nó com scale 0,1 (sem Reset XForm): ~60 cm por tile (±10%)" (mS1.escala > 0 and (abs ((1.0 / mS1.escala) - 60.0)) < 6.0)
        checar "I1: escala não uniforme -> #warn" (temLog logs #warn "TESTE_rf_nao_uniforme" "escala não uniforme")
        checar "I2: bitmap compartilhado continua no canal 2" (mCompart.diffuseMap.coords.mapChannel == 2)
        checar "I2: peça de fora intacta" (bx2.modifiers.count == 1 and bx2.modifiers[1] == modFora and igualCanal canalFora (InLab_Mapear_LerCanal1 bx2))
        checar "I2: #warn com o nome da peça de fora" (temLog logs #warn "TESTE_rf_fora" "fora desta rodada")
        checar "I2: RWF do canal 2 da peça selecionada continua" (bx1.modifiers.count == 1)
        local nV4Depois = vertsDoID i4 1
        linha ("      ilhas do ID mantido: " + nV4Antes as string + " -> " + nV4Depois as string + " vértices de mapa")
        checar "I4: ID mantido com os mesmos vértices de mapa (ilhas preservadas)" ((temLog logs #ok "TESTE_rf_ilhas (ID 2)" "refeito") and \
            (temLog logs #ok "TESTE_rf_ilhas (ID 1)" "mantido") and nV4Depois == nV4Antes)
        checar "minor a: uma linha de tubos por ID (3 tubos)" ((contaLog logs "TESTE_rf_toros" "tubo(s) reconhecido(s)") == 1 and \
            (temLog logs #info "TESTE_rf_toros" "3 tubo(s) reconhecido(s)"))
        checar "minor b: linha de progresso por peça" (temLog logs #info "TESTE_rf_escala" "mapeando (")

        -- minor d: Desfazer UV só com o Mapear registrado
        InLab_UltimoRWF = #(); InLab_UltimoAutoUV = #()
        logs.count = 0
        InLab_ReverterAutoUV()
        checar "minor d: Desfazer UV só com o Mapear: #info, sem o #warn 'Nenhum Auto UV'" ((not (temLog logs #warn "Nenhum Auto UV" "")) and \
            (temLog logs #info "só o Mapear" "") and InLab_UltimoMapear.count == 0)

        -- I3: topologia mudou entre o Mapear e o Desfazer
        local t3 = Box length:40 width:40 height:40 mapcoords:false name:"TESTE_rf_topologia" pos:[500,-900,0]
        convertToPoly t3
        polyop.setMapSupport t3 1 false
        t3.material = mVaz; append criados t3
        InLab_Mapear #(t3) produto
        polyop.deleteFaces t3 #{1}
        logs.count = 0
        local nRev3 = InLab_ReverterMapear()
        checar "I3: topologia mudou: peça pulada com #warn" (nRev3 == 0 and (temLog logs #warn "TESTE_rf_topologia" "a malha mudou desde o Mapear"))
        checar "I3: canal 1 válido (não regravado)" ((polyop.getMapSupport t3 1) and (polyop.getNumMapFaces t3 1) == (polyop.getNumFaces t3))

        -- I5: teto do laço #esq do tubo (faixa aberta nos dois sentidos, as 4 orientações)
        local faixas = #()
        for v = 1 to 4 do
        (
            local pl = if v <= 2 then Plane length:5 width:100 lengthsegs:1 widthsegs:20 else Plane length:100 width:5 lengthsegs:20 widthsegs:1
            pl.name = "TESTE_rf_faixa" + v as string
            convertToPoly pl
            if (mod v 2) == 0 do polyop.flipNormals pl #{1..(polyop.getNumFaces pl)}
            append criados pl; append faixas pl
        )
        local todas = (for pl in faixas where (InLab_Mapear_GerarTubo pl #{1..(polyop.getNumFaces pl)} (1.0/60)) != undefined collect pl).count
        checar "I5: as 4 faixas abertas são tubo com o teto normal" (todas == 4)
        INLAB_MAPEAR_TUBO_MAX_PASSOS = 3
        logs.count = 0
        local presas = (for pl in faixas where (InLab_Mapear_GerarTubo pl #{1..(polyop.getNumFaces pl)} (1.0/60)) == undefined collect pl).count
        INLAB_MAPEAR_TUBO_MAX_PASSOS = 100000
        checar "I5: teto do #esq devolve undefined com #warn" (presas >= 1 and (temLog logs #warn "TESTE_rf_faixa" "esquerda sem fim"))
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    -- limpeza
    for o in criados where isValidNode o do try ( delete o ) catch ()
    InLab_Log = logOriginal
    InLab_RWF_Feitos = feitosAntes
    if arqImg != undefined do try ( deleteFile arqImg ) catch ()
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
