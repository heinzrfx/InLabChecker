/*
 tests\test_ver_uv.ms — teste de functions\fn_ver_uv.ms (Ver UV: troca o material
 por listras para conferir o mapeamento). RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_ver_uv.txt (PASS/FAIL por item).
 26/10/2026 (Mapear por paineis, Tarefa 5).
 26/10/2026 (revisao final): InLab_VerUV_Garantir (clone com as listras, Converter
 Material com o Ver UV ligado, export e verificacoes recusam com listras sobrando,
 Desligar mantem material trocado). O teste do ExportGLTF tira o callback
 #InLabVerUV durante a chamada (o #preExport mascarava o Desligar da funcao).
*/
global InLab_Log, INLAB_ROOT
global InLab_VerUV_Garantir, InLab_ConverterObjetos, InLab_ReverterConversao, InLab_UltimaConversao
global InLab_AbrirExportadorRealTime, InLab_Produto_MateriaisDaSelecao, InLab_RealWorldFix
global InLab_VerUV_Ligar, InLab_VerUV_Desligar, InLab_VerUV_Ligado
global InLab_VerUV_MaterialDe, InLab_VerUV_Textura
global InLab_VerUV_ExportadorAberto
global InLab_Mapear_Mat, InLab_ExportGLTF, InLab_RodarVerificacoes
global InLab_VerUV_SincronizarUI, InLab_VerUV_Chamadas
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\inlab_test_ver_uv.txt"
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
    local rootOriginal = INLAB_ROOT
    local arqMax = (getDir #temp) + "\inlab_test_ver_uv.max"

    try
    (
        if INLAB_ROOT == undefined do INLAB_ROOT = raiz
        resetMaxFile #noPrompt
        fileIn (raiz + "core\utils.ms")
        fileIn (raiz + "functions\fn_json.ms")
        fileIn (raiz + "functions\fn_renomear_produto.ms")
        fileIn (raiz + "functions\fn_autouv.ms")
        fileIn (raiz + "functions\fn_realworldfix.ms")
        fileIn (raiz + "functions\fn_mapear.ms")
        fileIn (raiz + "functions\fn_ver_uv.ms")
        fileIn (raiz + "functions\fn_material_convert.ms")
        fileIn (raiz + "functions\fn_export_gltf.ms")
        fileIn (raiz + "verifications\verif_orquestrador.ms")

        local mA = StandardMaterial name:"TESTE_matA"
        local mB = StandardMaterial name:"TESTE_matB"
        local mM = Multimaterial name:"TESTE_multi" numsubs:2
        local b1 = Box name:"TESTE_vu1" pos:[0,0,0]
        local b2 = Box name:"TESTE_vu2" pos:[50,0,0]
        local b3 = Box name:"TESTE_vu3" pos:[100,0,0]
        b1.material = mA; b2.material = mM; b3.material = undefined

        -- 1
        local n = InLab_VerUV_Ligar #(b1, b2)
        checar "Ver UV: liga, troca o material de 2 nós e guarda os originais" \
            (n == 2 and InLab_VerUV_Ligado() and b1.material.name == "InLab Ver UV" and b2.material == b1.material \
             and classof b1.material.diffuseMap == BitmapTexture and b1.material.diffuseMap.coords.mapChannel == 1 \
             and b1.material.diffuseMap.coords.U_Tiling == 3 and b3.material == undefined)
        -- 6
        checar "Ver UV: MaterialDe devolve o original enquanto ligado" \
            (InLab_VerUV_MaterialDe b1 == mA and InLab_VerUV_MaterialDe b2 == mM and InLab_VerUV_MaterialDe b3 == undefined)
        -- 2
        local d = InLab_VerUV_Desligar()
        checar "Ver UV: desliga e devolve exatamente os materiais (inclusive Multi/Sub e undefined)" \
            (d == 2 and not (InLab_VerUV_Ligado()) and b1.material == mA and b2.material == mM and b3.material == undefined \
             and (InLab_VerUV_MaterialDe b1) == mA)
        -- 3
        InLab_VerUV_Ligar #(b1, b3)
        delete b1
        local ok3 = true
        local d3 = 0
        try ( d3 = InLab_VerUV_Desligar() ) catch ( ok3 = false )
        checar "Ver UV: nó apagado com o Ver UV ligado não quebra o Desligar" (ok3 and d3 == 1 and b3.material == undefined)
        -- 4
        b1 = Box name:"TESTE_vu1" pos:[0,0,0]
        b1.material = mA
        InLab_VerUV_Ligar #(b1)
        saveMaxFile arqMax quiet:true
        local nomeAposSalvar = if b1.material != undefined then b1.material.name else "(undefined)"
        resetMaxFile #noPrompt
        loadMaxFile arqMax quiet:true useFileUnits:true
        local c1 = getNodeByName "TESTE_vu1"
        checar "Ver UV: salvar com o Ver UV ligado salva o material original" \
            (c1 != undefined and c1.material != undefined and c1.material.name == "TESTE_matA" and not (InLab_VerUV_Ligado()))
        -- 5
        local b5 = Box name:"TESTE_vu5"
        b5.material = StandardMaterial name:"TESTE_matC"
        InLab_VerUV_Ligar #(b5)
        resetMaxFile #noPrompt
        checar "Ver UV: resetMaxFile desliga" (not (InLab_VerUV_Ligado()) and objects.count == 0)
        -- 8: callback #preExport
        local ss = StringStream ""
        callbacks.show id:#InLabVerUV to:ss
        checar "Ver UV: callback #preExport registrado com o id #InLabVerUV" ((findString (ss as string) "preExport") != undefined)
        -- 9: Ligar duas vezes
        local c9 = Box name:"TESTE_vu9"
        local m9 = StandardMaterial name:"TESTE_mat9"
        c9.material = m9
        InLab_VerUV_Ligar #(c9)
        local n9 = InLab_VerUV_Ligar #(c9)
        InLab_VerUV_Desligar()
        checar "Ver UV: Ligar duas vezes não troca os originais pelas listras" (n9 == 0 and c9.material == m9)
        -- 10: Mapear_Mat
        InLab_VerUV_Ligar #(c9)
        local mat10 = c9.material
        local ok10 = (InLab_Mapear_Mat c9) == m9 and mat10.name == "InLab Ver UV"
        InLab_VerUV_Desligar()
        checar "Ver UV: InLab_Mapear_Mat devolve o original com o Ver UV ligado e o.material sem ele" (ok10 and (InLab_Mapear_Mat c9) == m9)
        -- 11: ExportGLTF desliga antes de exportar
        InLab_VerUV_Ligar #(c9)
        select c9
        -- sem o callback #InLabVerUV: o #preExport desligaria sozinho e mascararia a função
        callbacks.removeScripts id:#InLabVerUV
        try ( InLab_ExportGLTF ((getDir #temp) + "\inlab_test_ver_uv.glb") ) catch ()
        fileIn (raiz + "functions\fn_ver_uv.ms")   -- recoloca os callbacks (o registro não tem inicializador)
        checar "Ver UV: InLab_ExportGLTF desliga antes de exportar" (not (InLab_VerUV_Ligado()) and c9.material == m9)
        -- 12: verificações desligam
        InLab_VerUV_Ligar #(c9)
        try ( InLab_RodarVerificacoes undefined ) catch ()
        checar "Ver UV: verificações desligam o Ver UV" (not (InLab_VerUV_Ligado()) and c9.material == m9)
        delete c9
        -- 13: Real-Time Exporter aberto
        local c13 = Box name:"TESTE_vu13"
        local m13 = StandardMaterial name:"TESTE_mat13"
        c13.material = m13
        local abertoOrig = InLab_VerUV_ExportadorAberto
        InLab_VerUV_ExportadorAberto = fn _exportadorFalso = ( true )
        local n13 = -1
        try ( n13 = InLab_VerUV_Ligar #(c13) ) catch ()
        InLab_VerUV_ExportadorAberto = abertoOrig
        local sobrou13 = InLab_VerUV_Ligado()
        InLab_VerUV_Desligar()
        checar "Ver UV: não liga com o Real-Time Exporter aberto" (n13 == 0 and not sobrou13 and c13.material == m13)
        delete c13
        ---------------- revisão final (26/10/2026): InLab_VerUV_Garantir ----------------
        fn comListras = ( for o in objects where o.material != undefined and o.material.name == "InLab Ver UV" collect o )
        -- material trocado com o Ver UV ligado: o Desligar mantém o atual
        local cW = Box name:"TESTE_vu_troca"
        local mW = StandardMaterial name:"TESTE_matW", mW2 = StandardMaterial name:"TESTE_matW2"
        cW.material = mW
        InLab_VerUV_Ligar #(cW)
        cW.material = mW2
        logs.count = 0
        InLab_VerUV_Desligar()
        checar "Ver UV: material trocado com o Ver UV ligado fica no Desligar, com #warn" \
            (cW.material == mW2 and (temLog logs #warn "TESTE_vu_troca" "material trocado com o Ver UV ligado"))
        delete cW
        -- Converter Material com o Ver UV ligado
        if (try ( CoronaPhysicalMtl != undefined ) catch ( false )) then
        (
            local cA = Box name:"TESTE_vu_conv"
            local mCor = CoronaPhysicalMtl name:"TESTE_corona_conv"
            cA.material = mCor
            InLab_UltimaConversao = #()
            InLab_VerUV_Ligar #(cA)
            local nConv = try ( InLab_ConverterObjetos #(cA) fazerBake:false ) catch ( -1 )
            local matConv = cA.material
            InLab_VerUV_Desligar()
            local depois = cA.material
            try ( InLab_ReverterConversao() ) catch ()
            linha ("      converter: " + nConv as string + " convertido(s), material " + (if matConv == undefined then "undefined" else matConv.name))
            checar "Ver UV: Converter com o Ver UV ligado não deixa listras" \
                (nConv == 1 and matConv != undefined and matConv.name != "InLab Ver UV" and depois == matConv and \
                 cA.material == mCor and (comListras()).count == 0)
            delete cA
        )
        else linha "PULADO  Ver UV: Converter com o Ver UV ligado (CoronaPhysicalMtl não disponível)"
        -- Renomear pelo JSON e RWF com o Ver UV ligado: leem o material de verdade
        local cR = Box name:"TESTE_vu_ren"
        local mR = StandardMaterial name:"TESTE_matR"
        cR.material = mR
        InLab_VerUV_Ligar #(cR)
        local mtlsR = try ( InLab_Produto_MateriaisDaSelecao #(cR) ) catch ( #() )
        checar "Ver UV: lista de materiais do Renomear não traz as listras" \
            (mtlsR.count == 1 and mtlsR[1] == mR and not (InLab_VerUV_Ligado()) and cR.material == mR)
        InLab_VerUV_Ligar #(cR)
        try ( InLab_RealWorldFix #(cR) silencioso:true ) catch ( linha ("      RWF: " + getCurrentException()) )
        checar "Ver UV: Real World Fix desliga o Ver UV antes" (not (InLab_VerUV_Ligado()) and cR.material == mR)
        delete cR
        -- clone com o Ver UV ligado: instância recebe o original; cópia dá #err
        local cO = Box name:"TESTE_vu_orig"
        local mO = StandardMaterial name:"TESTE_matO"
        cO.material = mO
        InLab_VerUV_Ligar #(cO)
        local cI = instance cO name:"TESTE_vu_inst" pos:[0,80,0]
        local cC = copy cO name:"TESTE_vu_copia" pos:[0,160,0]
        logs.count = 0
        local sobra = try ( InLab_VerUV_Garantir() ) catch ( -1 )
        checar "Ver UV: clone com o Ver UV ligado volta ao original da instância ou dá #err" \
            (sobra == 1 and cO.material == mO and cI.material == mO and (temLog logs #info "TESTE_vu_inst" "TESTE_vu_orig") and \
             cC.material != undefined and cC.material.name == "InLab Ver UV" and (temLog logs #err "TESTE_vu_copia" "aplique o material"))
        -- export e verificações recusam com listras sobrando (a cópia)
        local glb2 = (getDir #temp) + "\inlab_test_ver_uv2.glb"
        if doesFileExist glb2 do deleteFile glb2
        select cC
        logs.count = 0
        local rExp = try ( InLab_ExportGLTF glb2 ) catch ( "exceção" )
        -- sem o Garantir (antes da correção) o Real-Time Exporter abriria de verdade: só chama com ele
        local rRT = if InLab_VerUV_Garantir == undefined then "sem Garantir" else (try ( InLab_AbrirExportadorRealTime #(cC) ) catch ( "exceção" ))
        local rVer = try ( InLab_RodarVerificacoes undefined ) catch ( "exceção" )
        linha ("      export: " + rExp as string + ", real-time: " + rRT as string + ", verificações: " + rVer as string)
        checar "Ver UV: export recusa com listras sobrando na cena" \
            (rExp == false and rRT == false and not (doesFileExist glb2) and (temLog logs #err "Exporta" "listras"))
        checar "Ver UV: verificações recusam com listras sobrando na cena" (rVer == false and (temLog logs #err "Verifica" "listras"))
        if doesFileExist glb2 do deleteFile glb2
        delete #(cO, cI, cC)
        -- 7
        INLAB_ROOT = (getDir #temp) + "\inlab_sem_raiz\\"
        local arqGerado = (getDir #temp) + "\inlab_uv_listras.png"
        if doesFileExist arqGerado do deleteFile arqGerado
        local tex = InLab_VerUV_Textura()
        checar "Ver UV: sem o PNG no repo, gera a textura no temp" (tex == arqGerado and doesFileExist arqGerado)
        INLAB_ROOT = if rootOriginal != undefined then rootOriginal else raiz
        checar "Ver UV: com o PNG no repo, usa o do repo" (doesFileExist (InLab_VerUV_Textura()) and (findString (InLab_VerUV_Textura()) "ui\img") != undefined)
        -- 8. gancho da UI (26/10/2026): o botao Ver UV acompanha os desligamentos automaticos
        local ganchoOrig = InLab_VerUV_SincronizarUI
        InLab_VerUV_Chamadas = 0
        InLab_VerUV_SincronizarUI = fn _ganchoFalso = ( InLab_VerUV_Chamadas += 1 )
        local c14 = Box name:"TESTE_vuv_c14"
        try
        (
            InLab_VerUV_Ligar #(c14)
            local aposLigar = InLab_VerUV_Chamadas
            InLab_VerUV_Desligar()
            checar "Ver UV: Desligar chama o gancho da UI" (InLab_VerUV_Chamadas == aposLigar + 1 and aposLigar >= 1)
        )
        catch ( checar ("Ver UV: Desligar chama o gancho da UI (excecao: " + getCurrentException() + ")") false )
        InLab_VerUV_SincronizarUI = ganchoOrig
        delete c14
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    try ( InLab_VerUV_Desligar() ) catch ()
    INLAB_ROOT = rootOriginal
    InLab_Log = logOriginal
    if doesFileExist arqMax do try ( deleteFile arqMax ) catch ()
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
