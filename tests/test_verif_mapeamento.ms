/*
 tests\test_verif_mapeamento.ms — teste do grupo 5 de verificações (issue #101)
 Spec: docs\superpowers\specs\2026-10-05-verif-uv-grupo5-design.md
 RODAR NUMA CENA VAZIA (File > New): cria e apaga os objetos de cada caso.
 Resultado: <pasta temp do Max>\inlab_test_verif_mapeamento.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_VerifResults, InLab_ResetarResultados
global InLab_V14_UVPresente, InLab_V15_UVBake, InLab_V16_ResolucaoTexturas, InLab_CheckTexture
global InLab_AbrirGruposAcima, InLab_FecharGrupos
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_verif_mapeamento.txt"
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
    fn rodar f objs idV = ( InLab_ResetarResultados(); f objs; statusDe idV )
    fn caixa p = ( local b = Box length:10 width:10 height:10 mapcoords:true pos:p; convertToMesh b; b )
    -- Copia o canal `de` para o canal `para` (cria o canal se faltar).
    fn copiarCanal o de para =
    (
        if (meshop.getNumMaps o) <= para do meshop.setNumMaps o (para + 1) keep:true
        meshop.setMapSupport o para true
        local nv = meshop.getNumMapVerts o de
        meshop.setNumMapVerts o para nv
        for v = 1 to nv do meshop.setMapVert o para v (meshop.getMapVert o de v)
        for f = 1 to (getNumFaces o) do meshop.setMapFace o para f (meshop.getMapFace o de f)
        update o
    )

    local logOriginal = InLab_Log
    local unidadeOriginal = units.SystemType

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms",
                   @"verifications\verif_uv.ms", @"functions\fn_autouv.ms", @"functions\fn_checktexture.ms",
                   @"verifications\verif_mapeamento.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        units.SystemType = #Centimeters
        limparCena()

        ---------------------------------------------------------------- V-14
        local b = caixa [0, 0, 0]
        checar "V-14: Box com UV no canal 1 passa" ((rodar InLab_V14_UVPresente #(b) "V-14") == #pass)
        meshop.setMapSupport b 1 false
        update b
        checar "V-14: sem canal 1 reprova" ((rodar InLab_V14_UVPresente #(b) "V-14") == #fail)
        checar ("V-14: mensagem diz 'sem UV no canal 1' ('" + mensagemDe "V-14" + "')") ((findString (mensagemDe "V-14") (b.name + ": sem UV no canal 1")) != undefined)
        limparCena()
        b = caixa [0, 0, 0]
        for v = 1 to (meshop.getNumMapVerts b 1) do meshop.setMapVert b 1 v [0.5, 0.5, 0]
        update b
        checar "V-14: UV colapsado num ponto reprova" ((rodar InLab_V14_UVPresente #(b) "V-14") == #fail)
        checar ("V-14: mensagem diz 'colapsado' ('" + mensagemDe "V-14" + "')") ((findString (mensagemDe "V-14") "colapsado") != undefined)
        limparCena()
        b = caixa [0, 0, 0]
        for v = 1 to (meshop.getNumMapVerts b 1) do meshop.setMapVert b 1 v ((meshop.getMapVert b 1 v) * 37.0)
        update b
        checar "V-14: UV em escala real (fora do 0–1) passa" ((rodar InLab_V14_UVPresente #(b) "V-14") == #pass)
        limparCena()
        local vazio = mesh numverts:0 numfaces:0
        checar "V-14: malha vazia reprova sem erro (sem UV)" ((rodar InLab_V14_UVPresente #(vazio) "V-14") == #fail)
        limparCena()
        b = caixa [0, 0, 0]
        local bi = instance b
        bi.pos = [30, 0, 0]
        meshop.setMapSupport b 1 false
        update b
        InLab_ResetarResultados()
        InLab_V14_UVPresente #(b, bi)
        checar ("V-14: instâncias contam uma vez ('" + mensagemDe "V-14" + "')") ((findString (mensagemDe "V-14") bi.name) == undefined)
        limparCena()

        ---------------------------------------------------------------- V-15
        -- Sem canal 3: não se aplica, e o Unwrap não pode ser usado (falso positivo).
        b = caixa [0, 0, 0]
        checar "V-15: peça sem canal 3 passa como 'não se aplica'" ((rodar InLab_V15_UVBake #(b) "V-15") == #pass and (findString (mensagemDe "V-15") "não se aplica") != undefined)
        checar "V-15: nenhum modificador sobrou" (b.modifiers.count == 0)
        limparCena()
        -- Canal 3 limpo: cópia do canal 1 de um Plane (uma ilha).
        local pl = Plane length:10 width:10 lengthsegs:4 widthsegs:4 mapcoords:true
        convertToMesh pl
        copiarCanal pl 1 3
        checar ("V-15: canal 3 limpo passa ('" + (rodar InLab_V15_UVBake #(pl) "V-15") as string + "': " + mensagemDe "V-15" + ")") ((rodar InLab_V15_UVBake #(pl) "V-15") == #pass)
        limparCena()
        -- Canal 3 sobreposto: os 6 lados do Box no mesmo 0–1.
        b = caixa [0, 0, 0]
        copiarCanal b 1 3
        checar "V-15: canal 3 sobreposto reprova" ((rodar InLab_V15_UVBake #(b) "V-15") == #fail)
        checar ("V-15: mensagem diz 'sobreposta' ('" + mensagemDe "V-15" + "')") ((findString (mensagemDe "V-15") "face(s) sobreposta(s)") != undefined)
        checar "V-15: Unwrap removido" (b.modifiers.count == 0)
        limparCena()
        -- Fora do 0–1.
        pl = Plane length:10 width:10 lengthsegs:4 widthsegs:4 mapcoords:true
        convertToMesh pl
        copiarCanal pl 1 3
        meshop.setMapVert pl 3 1 [1.3, 0.5, 0]
        update pl
        checar "V-15: vértice fora do 0–1 reprova" ((rodar InLab_V15_UVBake #(pl) "V-15") == #fail and (findString (mensagemDe "V-15") "fora do 0–1") != undefined)
        limparCena()
        -- Membro de grupo fechado.
        local gA = caixa [0, 0, 0]
        local gB = caixa [30, 0, 0]
        copiarCanal gA 1 3
        local grp = group #(gA, gB) name:"Produto"
        checar "V-15: membro de grupo fechado é medido" ((rodar InLab_V15_UVBake #(gA, gB) "V-15") == #fail)
        checar "V-15: grupo fechado de novo e sem modificador" (not (isOpenGroupHead grp) and gA.modifiers.count == 0)
        limparCena()
        -- Instâncias: uma medição, sem sobra em nenhuma.
        b = caixa [0, 0, 0]
        copiarCanal b 1 3
        bi = instance b
        bi.pos = [30, 0, 0]
        InLab_ResetarResultados()
        InLab_V15_UVBake #(b, bi)
        checar ("V-15: instâncias medidas uma vez ('" + mensagemDe "V-15" + "')") ((findString (mensagemDe "V-15") bi.name) == undefined and b.modifiers.count == 0 and bi.modifiers.count == 0)
        limparCena()
        -- Seleção e painel do usuário voltam como estavam.
        local outro = caixa [60, 0, 0]
        b = caixa [0, 0, 0]
        copiarCanal b 1 3
        select outro
        setCommandPanelTaskMode #create
        InLab_ResetarResultados()
        InLab_V15_UVBake #(b)
        checar ("V-15: seleção restaurada (" + (for s in selection collect s.name) as string + ")") (selection.count == 1 and selection[1] == outro)
        checar ("V-15: painel restaurado (" + (getCommandPanelTaskMode()) as string + ")") ((getCommandPanelTaskMode()) == #create)
        clearSelection()
        InLab_ResetarResultados()
        InLab_V15_UVBake #(b)
        checar "V-15: seleção vazia continua vazia" (selection.count == 0)
        limparCena()
        -- Peça com modificador no stack.
        b = Box length:10 width:10 height:10 mapcoords:true
        convertToMesh b
        copiarCanal b 1 3
        addModifier b (Bend angle:20)
        checar "V-15: peça com Bend é medida e o Bend fica" ((rodar InLab_V15_UVBake #(b) "V-15") == #fail and b.modifiers.count == 1 and classof b.modifiers[1] == Bend)
        limparCena()
        -- Malha vazia: não se aplica, sem erro.
        local vz = mesh numverts:0 numfaces:0
        checar "V-15: malha vazia é 'não se aplica'" ((rodar InLab_V15_UVBake #(vz) "V-15") == #pass)
        limparCena()
        -- Exceção simulada no meio da medição.
        b = caixa [0, 0, 0]
        copiarCanal b 1 3
        InLab_ResetarResultados()
        InLab_V15_UVBake #(b) falharTeste:true
        checar ("V-15: exceção vira 'não medido' ('" + mensagemDe "V-15" + "')") (statusDe "V-15" == #warning and (findString (mensagemDe "V-15") "não medid") != undefined)
        checar "V-15: exceção não deixa modificador" (b.modifiers.count == 0)
        limparCena()
        ---------------------------------------------------------------- V-15 (falhas fora da medição)
        -- Seleção original = cabeça de grupo fechado.
        gA = caixa [0, 0, 0]
        gB = caixa [30, 0, 0]
        copiarCanal gA 1 3
        grp = group #(gA, gB) name:"Produto"
        select grp
        local antes = for s in selection collect s.name
        InLab_ResetarResultados()
        InLab_V15_UVBake #(gA, gB)
        local depois = for s in selection collect s.name
        checar ("V-15: seleção = grupo fechado volta igual (" + antes as string + " -> " + depois as string + ")") (antes.count > 0 and antes.count == depois.count and (for nm in antes where findItem depois nm == 0 collect nm).count == 0 and findItem depois grp.name > 0 and not (isOpenGroupHead grp))
        limparCena()
        -- (a) InLab_AbrirGruposAcima lança.
        fn abrirQuebrado o = ( throw "abertura quebrada (teste)" )
        fn fecharQuebrado g = ( throw "fechamento quebrado (teste)" )
        local origAbrir = InLab_AbrirGruposAcima
        local origFechar = InLab_FecharGrupos
        local outro2 = caixa [60, 0, 0]
        b = caixa [0, 0, 0]
        copiarCanal b 1 3
        select outro2
        setCommandPanelTaskMode #create
        InLab_AbrirGruposAcima = abrirQuebrado
        try ( InLab_ResetarResultados(); InLab_V15_UVBake #(b) ) catch ( linha ("EXCEÇÃO inesperada em V-15 (a): " + getCurrentException()); INLAB_TESTE_FALHAS += 1 )
        InLab_AbrirGruposAcima = origAbrir
        checar ("V-15: abertura de grupo quebrada vira 'não medido' ('" + mensagemDe "V-15" + "')") (statusDe "V-15" == #warning and (findString (mensagemDe "V-15") "não medid") != undefined)
        checar "V-15: abertura quebrada não deixa Unwrap" (b.modifiers.count == 0)
        checar "V-15: abertura quebrada restaura seleção e painel" (selection.count == 1 and selection[1] == outro2 and (getCommandPanelTaskMode()) == #create)
        checar "V-15: abertura quebrada deixa o redraw ligado" (not (isSceneRedrawDisabled()))
        limparCena()
        -- (b) InLab_FecharGrupos lança, peça em grupo e sobreposta: nunca PASS.
        gA = caixa [0, 0, 0]
        gB = caixa [30, 0, 0]
        copiarCanal gA 1 3
        grp = group #(gA, gB) name:"Produto"
        InLab_FecharGrupos = fecharQuebrado
        try ( InLab_ResetarResultados(); InLab_V15_UVBake #(gA) ) catch ( linha ("EXCEÇÃO inesperada em V-15 (b): " + getCurrentException()); INLAB_TESTE_FALHAS += 1 )
        InLab_FecharGrupos = origFechar
        checar ("V-15: fechamento quebrado não dá PASS ('" + statusDe "V-15" as string + "')") (statusDe "V-15" != #pass and statusDe "V-15" != #ausente)
        checar "V-15: fechamento quebrado não deixa Unwrap e o grupo volta fechado" (gA.modifiers.count == 0 and not (isOpenGroupHead grp))
        checar "V-15: fechamento quebrado deixa o redraw ligado" (not (isSceneRedrawDisabled()))
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
