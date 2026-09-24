/*
 tests\test_autouv.ms — teste automático de functions\fn_autouv.ms (issue #1, Fase 2)
 RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt): cria uma caixa Editable_Poly,
 uma caixa dentro de um grupo e um cilindro com UVW Map no canal 1, e apaga
 tudo no final.
 Resultado: <pasta temp do Max>\inlab_test_autouv.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_EhGeometria
global InLab_MedirUV, InLab_AssinaturaCanal, InLab_UVMetricasTexto
global InLab_AutoUV, InLab_CleanUV, InLab_ReverterAutoUV, InLab_PaddingUV, InLab_UltimoAutoUV
global InLab_IlhasDoUnwrap, InLab_DistorcaoIlhas, InLab_UnfoldComGuarda
global InLab_AutoUV_ForcarFalha, InLab_CanalDoModificadorUV
global INLAB_CANAL_UV_MATERIAL, INLAB_CANAL_UV_BAKE, INLAB_UV_MEDIR_MAX_FACES, INLAB_UV_DISTORCAO_MAX_SOLVE
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_autouv.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn temModificador o cls =
    (
        local achou = false
        for md in o.modifiers where isKindOf md cls do achou = true
        achou
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    local criados = #()

    try
    (
        fileIn (raiz + @"core\utils.ms")
        fileIn (raiz + @"verifications\verif_uv.ms")
        fileIn (raiz + @"functions\fn_autouv.ms")

        -- 0. PADDING POR RESOLUÇÃO
        checar "Padding 1K = 4 px" (abs ((InLab_PaddingUV 1024) - 4.0 / 1024) < 1e-9)
        checar "Padding 2K = 8 px" (abs ((InLab_PaddingUV 2048) - 8.0 / 2048) < 1e-9)
        checar "Padding 4K = 16 px" (abs ((InLab_PaddingUV 4096) - 16.0 / 4096) < 1e-9)

        -- CENA
        local bPoly = Box name:"uv_poly" length:20 width:20 height:20 mapcoords:true
        convertToPoly bPoly
        -- Grupo FECHADO com dois membros: "select" num membro seleciona o grupo
        -- todo, e o Auto UV antigo instanciava um Unwrap só em todos (21/Set).
        -- bIrmao fica fora da lista de objetos e não pode ganhar modificador.
        local bGrupo = Box name:"uv_grupo" length:20 width:40 height:10 pos:[60, 0, 0] mapcoords:true
        local bIrmao = Box name:"uv_irmao" length:10 width:10 height:10 pos:[60, 30, 0]
        local grp = group #(bGrupo, bIrmao) name:"uv_grp"
        setGroupOpen grp false
        local cil = Cylinder name:"uv_cil" radius:10 height:30 sides:24 pos:[120, 0, 0]
        addModifier cil (Uvwmap maptype:4 mapChannel:1)
        criados = #(bPoly, bGrupo, bIrmao, cil, grp)
        local objs = #(bPoly, bGrupo, cil)
        local antes = for o in objs collect InLab_AssinaturaCanal o INLAB_CANAL_UV_MATERIAL
        local facesAntes = polyop.getNumFaces bPoly
        checar "Cena: canal 1 existe nos 3 objetos" ((for s in antes where s == undefined collect s).count == 0)

        -- 1. AUTO UV
        checar "Auto UV processa 3 objetos" ((InLab_AutoUV objs angulo:55.0 resolucao:1024) == 3)
        for i = 1 to objs.count do
        (
            local o = objs[i]
            local topo = o.modifiers[1]
            checar (o.name + ": Unwrap no topo, canal 3") (isKindOf topo Unwrap_UVW and topo.getMapChannel() == 3)
            checar (o.name + ": canal 1 idêntico") ((InLab_AssinaturaCanal o INLAB_CANAL_UV_MATERIAL) == antes[i])
            local m = InLab_MedirUV o INLAB_CANAL_UV_BAKE
            linha ("      " + o.name + ": " + InLab_UVMetricasTexto m)
            checar (o.name + ": nada fora do 0–1") (m != undefined and m.foraDe01 == 0)
            checar (o.name + ": 0 sobrepostas") (m != undefined and m.sobrepostas == 0)
            checar (o.name + ": 0 invertidos") (m != undefined and m.invertidos == 0)
            -- pega ilhas colapsadas em linha (relax com bordas soltas, 21/Set)
            checar (o.name + ": aproveitamento > 20%") (m != undefined and m.aproveitamento > 0.2)
            -- o pack sozinho deixava o gutter 25–30% abaixo do padding (21/Set)
            checar (o.name + ": gutter >= padding de 1K") (m != undefined and m.gutterMin != undefined and m.gutterMin >= (InLab_PaddingUV 1024) * 0.98)
        )
        -- 21/Set (Fase 3): a base não é mais convertida (primitiva para poly mudaria o canal 1)
        checar "Base Editable_Poly continua Editable_Poly" (classOf bPoly.baseObject == Editable_Poly)
        checar "Primitiva no grupo continua Box" (classOf bGrupo.baseObject == Box)
        checar "Base com modificadores ficou como estava" (classOf cil.baseObject == Cylinder)
        checar "UVW Map do canal 1 continua no stack" (temModificador cil Uvwmap)
        checar "Objeto continua no grupo" (bGrupo.parent == grp and isGroupMember bGrupo)
        checar "Grupo continua fechado" (not (isOpenGroupHead grp))
        checar "Irmão no grupo não ganha modificador" (bIrmao.modifiers.count == 0)
        checar "Unwrap não é instanciado entre objetos" ((for o in objs where (refs.dependentNodes o.modifiers[1]).count != 1 collect o).count == 0)
        checar "Registro: 3 objetos" (InLab_UltimoAutoUV.count == 3)

        -- 2. RODAR DE NOVO: substitui o Unwrap, não empilha
        InLab_AutoUV #(bPoly) angulo:30.0 resolucao:2048
        checar "Rodar de novo não empilha Unwrap" (bPoly.modifiers.count == 1)
        checar "Rodar de novo mantém um registro por objeto" (InLab_UltimoAutoUV.count == 3)

        -- 3. CLEAN UV: tira só o que é do canal 3
        InLab_CleanUV #(cil)
        checar "Clean UV remove o Unwrap do canal 3" (not (temModificador cil Unwrap_UVW))
        checar "Clean UV mantém o UVW Map do canal 1" (temModificador cil Uvwmap)
        checar "Clean UV: canal 1 idêntico" ((InLab_AssinaturaCanal cil INLAB_CANAL_UV_MATERIAL) == antes[3])

        -- 4. REVERTER
        InLab_ReverterAutoUV()
        checar "Reverter: base volta a Editable_Poly" (classOf bPoly.baseObject == Editable_Poly)
        checar "Reverter: mesmo nº de polígonos" (classOf bPoly.baseObject == Editable_Poly and (polyop.getNumFaces bPoly) == facesAntes)
        checar "Reverter: base do grupo volta a Box" (classOf bGrupo.baseObject == Box)
        checar "Reverter: sem Unwrap" (bPoly.modifiers.count == 0 and bGrupo.modifiers.count == 0)
        checar "Reverter: canal 1 idêntico" ((InLab_AssinaturaCanal bPoly INLAB_CANAL_UV_MATERIAL) == antes[1] and (InLab_AssinaturaCanal bGrupo INLAB_CANAL_UV_MATERIAL) == antes[2])
        checar "Reverter: grupo preservado" (bGrupo.parent == grp)
        checar "Reverter: registro zerado" (InLab_UltimoAutoUV.count == 0)

        -- 5. INSTÂNCIAS E BASE JÁ EM EDITABLE_MESH (21/Set)
        -- O convertToMesh antigo tornava únicas todas as instâncias, até as não
        -- selecionadas. Agora a instância é mantida e o Unwrap é compartilhado.
        fn nInst o = ( local i = #() ; InstanceMgr.GetInstances o &i ; i.count )
        local iA = Box name:"uv_instA" length:20 width:20 height:20 mapcoords:true pos:[0, 60, 0]
        convertToPoly iA
        local iB = instance iA
        iB.name = "uv_instB"
        iB.pos = [40, 60, 0]
        local iC = instance iA
        iC.name = "uv_instC"
        iC.pos = [80, 60, 0]
        local eMesh = Box name:"uv_emesh" length:10 width:10 height:10 mapcoords:true pos:[0, 100, 0]
        convertToMesh eMesh
        join criados #(iA, iB, iC, eMesh)
        local eMeshAntes = InLab_AssinaturaCanal eMesh INLAB_CANAL_UV_MATERIAL
        checar "Instâncias: processa A, B e o mesh" ((InLab_AutoUV #(iA, iB, eMesh) angulo:55.0 resolucao:1024) == 3)
        checar "Instâncias: continuam as 3 ligadas" (nInst iA == 3 and nInst iC == 3)
        checar "Instâncias: base mantida" (classOf iA.baseObject == Editable_Poly)
        checar "Instâncias: um Unwrap só, compartilhado" (iA.modifiers.count == 1 and iC.modifiers.count == 1 and iA.modifiers[1] == iC.modifiers[1])
        local mInst = InLab_MedirUV iC INLAB_CANAL_UV_BAKE
        checar "Instâncias: canal 3 válido na instância não selecionada" (mInst != undefined and mInst.foraDe01 == 0 and mInst.sobrepostas == 0 and mInst.aproveitamento > 0.2)
        checar "Instâncias: um registro para o conjunto" (InLab_UltimoAutoUV.count == 2)
        InLab_AutoUV #(iC) angulo:40.0 resolucao:1024
        checar "Instâncias: rodar de novo em C substitui o Unwrap" (iA.modifiers.count == 1 and InLab_UltimoAutoUV.count == 2)
        checar "Mesh: base continua Editable_mesh com Unwrap" (classOf eMesh.baseObject == Editable_mesh and eMesh.modifiers.count == 1)
        checar "Mesh: canal 1 idêntico" ((InLab_AssinaturaCanal eMesh INLAB_CANAL_UV_MATERIAL) == eMeshAntes)
        InLab_ReverterAutoUV()
        checar "Instâncias: Reverter tira o Unwrap de todas e mantém o vínculo" (iA.modifiers.count == 0 and iC.modifiers.count == 0 and nInst iA == 3)
        checar "Mesh: Reverter tira o Unwrap" (eMesh.modifiers.count == 0 and classOf eMesh.baseObject == Editable_mesh)

        -- 5b. UNFOLD COM GUARDA (Fase 3): flatten sobre poly + Unfold3DSolve por ilha
        local almof = ChamferBox name:"uv_almofada" length:40 width:40 height:12 fillet:3 filletSegs:3 mapcoords:true pos:[0, 220, 0]
        convertToPoly almof
        append criados almof
        local t0a = timeStamp()
        InLab_AutoUV #(almof) angulo:55.0 resolucao:1024
        local msA = timeStamp() - t0a
        local mA = InLab_MedirUV almof INLAB_CANAL_UV_BAKE
        linha ("      uv_almofada: " + msA as string + " ms · " + InLab_UVMetricasTexto mA)
        checar "Almofada: base continua Editable_Poly" (classOf almof.baseObject == Editable_Poly)
        checar "Almofada: no máximo 6 ilhas (topo, fundo e tiras)" (mA.nIlhas <= 6)
        checar "Almofada: distorção ≤ 1,2 (o flatten sozinho dava ~1,6)" (mA.distorcaoMax <= 1.2)
        checar "Almofada: densidade ≤ 1,05" (mA.densidadeRazao <= 1.05)
        checar "Almofada: 0 sobrepostas, nada fora do 0–1" (mA.sobrepostas == 0 and mA.foraDe01 == 0)
        checar "Almofada: menos de 5 s" (msA < 5000)

        -- a guarda: distorção por ilha de um UV conhecido (caixa com flatten = 1,0)
        local cxG = Box name:"uv_guarda" length:20 width:20 height:20 mapcoords:true pos:[80, 220, 0]
        convertToPoly cxG
        append criados cxG
        max modify mode
        select cxG
        local uG = Unwrap_UVW()
        addModifier cxG uG
        modPanel.setCurrentObject uG
        uG.setMapChannel 3
        local npG = uG.numberPolygons()
        uG.selectFaces #{1..npG}
        uG.flattenMap 55.0 #([1,0,0], [-1,0,0], [0,1,0], [0,-1,0], [0,0,1], [0,0,-1]) 0.01 true 0 true true
        local ilG = InLab_IlhasDoUnwrap uG npG
        checar "Guarda: caixa tem 6 ilhas" (ilG.count == 6)
        checar "Guarda: distorção por ilha 1,0" ((for d in (InLab_DistorcaoIlhas uG ilG) where abs (d - 1.0) > 0.01 collect d).count == 0)

        -- a reversão (22/Set): o Unfold3DSolve renumera os vértices UV das faces
        -- (Box050: 78 de 294 faces), então voltar ao flatten por índice de vértice
        -- gravava as posições nos vértices errados (distorção 3 930×, 18 invertidos).
        -- Com o limite em 0,5 todas as ilhas voltam, e o UV tem que sair idêntico
        -- ao flatten, canto por canto. Torus: o solve renumera 99 de 288 faces
        -- (caixa, cilindro e ChamferBox não renumeram).
        local cxR = Torus name:"uv_reverte" radius1:20 radius2:5 segs:24 sides:12 mapcoords:true pos:[160, 220, 0]
        convertToPoly cxR
        append criados cxR
        select cxR
        local uR = Unwrap_UVW()
        addModifier cxR uR
        modPanel.setCurrentObject uR
        uR.setMapChannel 3
        local npR = uR.numberPolygons()
        uR.selectFaces #{1..npR}
        uR.flattenMap 55.0 #([1,0,0], [-1,0,0], [0,1,0], [0,-1,0], [0,0,1], [0,0,-1]) 0.01 true 0 true true
        fn cantosUV u np = ( for f = 1 to np collect (for k = 1 to (u.numberPointsInFace f) collect u.getVertexPosition 0 (u.getVertexIndexFromFace f k)) )
        fn indicesUV u np = ( for f = 1 to np collect (for k = 1 to (u.numberPointsInFace f) collect u.getVertexIndexFromFace f k) )
        local cFlat = cantosUV uR npR
        local iFlat = indicesUV uR npR
        local limOrig = INLAB_UV_DISTORCAO_MAX_SOLVE
        INLAB_UV_DISTORCAO_MAX_SOLVE = 0.5
        local revR = InLab_UnfoldComGuarda uR npR
        INLAB_UV_DISTORCAO_MAX_SOLVE = limOrig
        local iDep = indicesUV uR npR
        checar "Reversão: o solve renumerou vértices (pré-condição do teste)" ((for f = 1 to npR where (iFlat[f] as string) != (iDep[f] as string) collect f).count > 0)
        checar "Reversão: todas as ilhas voltaram" (revR == (InLab_IlhasDoUnwrap uR npR).count)
        local cDep = cantosUV uR npR
        local difR = 0
        for f = 1 to npR do for k = 1 to cFlat[f].count where distance cFlat[f][k] cDep[f][k] > 1e-5 do difR += 1
        checar ("Reversão: UV idêntico ao flatten, canto por canto (" + difR as string + " cantos diferentes)") (difR == 0)

        -- 6. MALHA GRANDE (21/Set): acima de INLAB_UV_MEDIR_MAX_FACES o Auto UV
        -- pula o pack extra e as métricas de MaxScript. Antes, 306 mil faces
        -- levavam ~15 min só em verificação e travavam o Max.
        local esfG = Sphere name:"uv_grande" radius:20 segs:180 mapcoords:true pos:[0, 160, 0]
        append criados esfG
        local esfAntes = InLab_AssinaturaCanal esfG INLAB_CANAL_UV_MATERIAL
        local t0 = timeStamp()
        InLab_AutoUV #(esfG) angulo:55.0 resolucao:1024
        local msG = timeStamp() - t0
        local mG = InLab_MedirUV esfG INLAB_CANAL_UV_BAKE
        linha ("      uv_grande: " + (GetTriMeshFaceCount esfG)[1] as string + " triângulos em " + msG as string + " ms · " + InLab_UVMetricasTexto mG)
        checar "Malha grande: acima do limite" ((GetTriMeshFaceCount esfG)[1] > INLAB_UV_MEDIR_MAX_FACES)
        checar "Malha grande: Auto UV em menos de 15 s" (msG < 15000)
        checar "Malha grande: canal 1 idêntico" ((InLab_AssinaturaCanal esfG INLAB_CANAL_UV_MATERIAL) == esfAntes)
        checar "Malha grande: nada fora do 0–1 e 0 sobrepostas" (mG != undefined and mG.foraDe01 == 0 and mG.sobrepostas == 0)
        checar "Malha grande: gutter >= padding com a folga" (mG != undefined and (mG.gutterMin == undefined or mG.gutterMin >= (InLab_PaddingUV 1024) * 0.98))

        -- 7. FALHA FORÇADA NO MEIO DA RODADA (issue #48): InLab_AutoUV_ForcarFalha
        -- injeta uma exceção depois que o Unwrap já entrou no stack do objeto, para
        -- provar que (a) os outros objetos da rodada seguem sendo processados,
        -- (b) o grupo acima do objeto que falhou fecha de novo, (c) o erro sai no
        -- log com o nome do objeto e (d) o Unwrap que já tinha entrado no stack não
        -- fica órfão.
        local fOk = Box name:"uv_falha_ok" length:15 width:15 height:15 mapcoords:true pos:[0, 260, 0]
        convertToPoly fOk
        local fRuim = Box name:"uv_falha_ruim" length:15 width:15 height:15 pos:[40, 260, 0]
        local fVizinho = Box name:"uv_falha_vizinho" length:10 width:10 height:10 pos:[40, 290, 0]
        local fGrp = group #(fRuim, fVizinho) name:"uv_falha_grp"
        setGroupOpen fGrp false
        append criados fOk
        join criados #(fRuim, fVizinho, fGrp)

        -- Captura os logs desta chamada (além de continuar gravando no arquivo)
        -- para conferir a mensagem de erro com o nome do objeto. try/catch aqui
        -- (fix#48/r1, MINOR 7): InLab_Log e InLab_AutoUV_ForcarFalha voltam ao
        -- normal em qualquer caminho, mesmo se InLab_AutoUV lançar algo inesperado.
        local logsCapturados = #()
        local logDoTeste = InLab_Log
        local nOk = 0
        try
        (
            InLab_Log = fn _logCaptura msg tipo:#info =
            (
                append logsCapturados #(tipo, msg)
                format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
                flush INLAB_TESTE_SAIDA
            )
            InLab_AutoUV_ForcarFalha = fRuim.name
            nOk = InLab_AutoUV #(fOk, fRuim) angulo:55.0 resolucao:1024
        )
        catch ( linha ("      EXCEÇÃO na seção 7 (falha forçada): " + getCurrentException()) )
        InLab_AutoUV_ForcarFalha = undefined
        InLab_Log = logDoTeste

        local erroComNome = false
        for l in logsCapturados where l[1] == #err and (matchPattern l[2] pattern:("*" + fRuim.name + "*")) do erroComNome = true

        checar "Falha forçada: o objeto bom conta como processado, o ruim não" (nOk == 1)
        checar "Falha forçada: objeto bom recebeu o Unwrap normalmente" (temModificador fOk Unwrap_UVW)
        checar "Falha forçada: objeto ruim NÃO fica com Unwrap órfão" (not (temModificador fRuim Unwrap_UVW))
        checar "Falha forçada: grupo fecha de novo" (not (isOpenGroupHead fGrp))
        checar "Falha forçada: objeto continua no grupo" (fRuim.parent == fGrp)
        checar "Falha forçada: erro no log com o nome do objeto" erroComNome

        -- 8. CLEAN UV remove UVW_Xform no canal de bake, mantém no canal 1
        -- (issue #48): sondado via MCP nesta build — a propriedade de canal do
        -- UVW_Xform é Map_Channel (mapChannel/channel/mapID não existem nele).
        -- Caso negativo (fix#48/r1, MINOR 7): um UVW_Xform no canal 1 (material)
        -- no MESMO objeto não pode ser removido pelo Clean UV.
        local cX = Box name:"uv_xform" length:12 width:12 height:12 mapcoords:true pos:[80, 260, 0]
        convertToPoly cX
        append criados cX
        max modify mode
        select cX
        local mxBake = UVW_Xform()
        addModifier cX mxBake
        mxBake.Map_Channel = INLAB_CANAL_UV_BAKE
        select cX
        local mxMat = UVW_Xform()
        addModifier cX mxMat
        mxMat.Map_Channel = INLAB_CANAL_UV_MATERIAL
        checar "UVW_Xform: InLab_CanalDoModificadorUV lê o canal de bake pela Map_Channel" ((InLab_CanalDoModificadorUV mxBake) == INLAB_CANAL_UV_BAKE)
        checar "UVW_Xform: InLab_CanalDoModificadorUV lê o canal 1 pela Map_Channel" ((InLab_CanalDoModificadorUV mxMat) == INLAB_CANAL_UV_MATERIAL)
        InLab_CleanUV #(cX)
        local temBake = false, temMat = false
        for md in cX.modifiers where isKindOf md UVW_Xform do
        (
            if md == mxBake do temBake = true
            if md == mxMat do temMat = true
        )
        checar "Clean UV remove o UVW_Xform do canal de bake" (not temBake)
        checar "Clean UV mantém o UVW_Xform do canal 1 (material)" temMat

        -- Ctrl+Z nativo NÃO é testável daqui: rodado de dentro do script,
        -- `max undo` desfaz o script inteiro. Conferir à mão pela UI.
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    for o in criados where isValidNode o do delete o
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
