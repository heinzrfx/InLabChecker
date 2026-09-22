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
global INLAB_CANAL_UV_MATERIAL, INLAB_CANAL_UV_BAKE, INLAB_UV_MEDIR_MAX_FACES
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
        checar "Auto UV processa 3 objetos" ((InLab_AutoUV objs angulo:55.0 seamsOcultas:true resolucao:1024) == 3)
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
        checar "Base Editable_Poly virou Editable_mesh" (classOf bPoly.baseObject == Editable_mesh)
        checar "Base do objeto no grupo virou Editable_mesh" (classOf bGrupo.baseObject == Editable_mesh)
        checar "Base com modificadores ficou como estava" (classOf cil.baseObject == Cylinder)
        checar "UVW Map do canal 1 continua no stack" (temModificador cil Uvwmap)
        checar "Objeto continua no grupo" (bGrupo.parent == grp and isGroupMember bGrupo)
        checar "Grupo continua fechado" (not (isOpenGroupHead grp))
        checar "Irmão no grupo não ganha modificador" (bIrmao.modifiers.count == 0)
        checar "Unwrap não é instanciado entre objetos" ((for o in objs where (refs.dependentNodes o.modifiers[1]).count != 1 collect o).count == 0)
        checar "Registro: 3 objetos" (InLab_UltimoAutoUV.count == 3)

        -- 2. RODAR DE NOVO: substitui o Unwrap, não empilha
        InLab_AutoUV #(bPoly) angulo:30.0 seamsOcultas:false resolucao:2048
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
        checar "Instâncias: processa A, B e o mesh" ((InLab_AutoUV #(iA, iB, eMesh) angulo:55.0 seamsOcultas:false resolucao:1024) == 3)
        checar "Instâncias: continuam as 3 ligadas" (nInst iA == 3 and nInst iC == 3)
        checar "Instâncias: base mantida" (classOf iA.baseObject == Editable_Poly)
        checar "Instâncias: um Unwrap só, compartilhado" (iA.modifiers.count == 1 and iC.modifiers.count == 1 and iA.modifiers[1] == iC.modifiers[1])
        local mInst = InLab_MedirUV iC INLAB_CANAL_UV_BAKE
        checar "Instâncias: canal 3 válido na instância não selecionada" (mInst != undefined and mInst.foraDe01 == 0 and mInst.sobrepostas == 0 and mInst.aproveitamento > 0.2)
        checar "Instâncias: um registro para o conjunto" (InLab_UltimoAutoUV.count == 2)
        InLab_AutoUV #(iC) angulo:40.0 seamsOcultas:false resolucao:1024
        checar "Instâncias: rodar de novo em C substitui o Unwrap" (iA.modifiers.count == 1 and InLab_UltimoAutoUV.count == 2)
        checar "Mesh: base continua Editable_mesh com Unwrap" (classOf eMesh.baseObject == Editable_mesh and eMesh.modifiers.count == 1)
        checar "Mesh: canal 1 idêntico" ((InLab_AssinaturaCanal eMesh INLAB_CANAL_UV_MATERIAL) == eMeshAntes)
        InLab_ReverterAutoUV()
        checar "Instâncias: Reverter tira o Unwrap de todas e mantém o vínculo" (iA.modifiers.count == 0 and iC.modifiers.count == 0 and nInst iA == 3)
        checar "Mesh: Reverter tira o Unwrap" (eMesh.modifiers.count == 0 and classOf eMesh.baseObject == Editable_mesh)

        -- 6. MALHA GRANDE (21/Set): acima de INLAB_UV_MEDIR_MAX_FACES o Auto UV
        -- pula o pack extra e as métricas de MaxScript. Antes, 306 mil faces
        -- levavam ~15 min só em verificação e travavam o Max.
        local esfG = Sphere name:"uv_grande" radius:20 segs:180 mapcoords:true pos:[0, 160, 0]
        append criados esfG
        local esfAntes = InLab_AssinaturaCanal esfG INLAB_CANAL_UV_MATERIAL
        local t0 = timeStamp()
        InLab_AutoUV #(esfG) angulo:55.0 seamsOcultas:false resolucao:1024
        local msG = timeStamp() - t0
        local mG = InLab_MedirUV esfG INLAB_CANAL_UV_BAKE
        linha ("      uv_grande: " + (GetTriMeshFaceCount esfG)[1] as string + " triângulos em " + msG as string + " ms · " + InLab_UVMetricasTexto mG)
        checar "Malha grande: acima do limite" ((GetTriMeshFaceCount esfG)[1] > INLAB_UV_MEDIR_MAX_FACES)
        checar "Malha grande: Auto UV em menos de 15 s" (msG < 15000)
        checar "Malha grande: canal 1 idêntico" ((InLab_AssinaturaCanal esfG INLAB_CANAL_UV_MATERIAL) == esfAntes)
        checar "Malha grande: nada fora do 0–1 e 0 sobrepostas" (mG != undefined and mG.foraDe01 == 0 and mG.sobrepostas == 0)
        checar "Malha grande: gutter >= padding com a folga" (mG != undefined and (mG.gutterMin == undefined or mG.gutterMin >= (InLab_PaddingUV 1024) * 0.98))

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
