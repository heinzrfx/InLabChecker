/*
 tests\test_mapear.ms — teste de functions\fn_mapear.ms (orquestrador do botão
 Mapear, registro e Desfazer). RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear.txt (PASS/FAIL por item).
 23/10/2026 (Tarefa 5).
*/
global InLab_Log, InLab_ParseJSON, InLab_Produto_Lista, InLab_RWF_Feitos
global InLab_Mapear, InLab_ReverterMapear, InLab_UltimoMapear, InLab_Mapear_LerCanal1
global InLab_Mapear_Medir, InLab_Mapear_GerarTubo, InLab_Mapear_Gravar
global InLab_Instancias
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
            "{\"nome_parte\": \"Pe\", \"familia\": \"Madeira\", \"materia\": \"Cedro\", \"material_id\": \"ART_Pe\"}, " +
            "{\"nome_parte\": \"Assento\", \"familia\": \"Tecido\", \"materia\": \"\", \"material_id\": \"ART_Tecido\"}, " +
            "{\"nome_parte\": \"Capa\", \"familia\": \"Tecido\", \"materia\": \"\", \"material_id\": \"ART_Capa\"}, " +
            "{\"nome_parte\": \"Base\", \"familia\": \"Metal\", \"materia\": \"\", \"material_id\": \"ART_Metal\"}, " +
            "{\"nome_parte\": \"BaseRW\", \"familia\": \"Metal\", \"materia\": \"\", \"material_id\": \"ART_MetalRW\"}, " +
            "{\"nome_parte\": \"Acabamento\", \"familia\": \"\", \"materia\": \"\", \"material_id\": \"ART_Vazia\"}]}]}"
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
        -- (GeoSphere: só triângulos, não é tubo; a Sphere comum vira "tubo" pela grade de quads)
        local esf = GeoSphere radius:30 segs:6 mapcoords:true name:"TESTE_map_esfera" pos:[0,300,0]
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
        local esf2 = GeoSphere radius:30 segs:6 mapcoords:true name:"TESTE_map_esfera2" pos:[0,450,0]
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
