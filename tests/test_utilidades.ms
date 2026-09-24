/*
 tests\test_utilidades.ms — teste automático de functions\fn_utilidades.ms
 (issue #50: Reset XForm, Center Pivot e Base Pivot — grupo tratado pela
 cabeça, não pelas peças; helper/cabeça de grupo nunca vira "geometria").
 Cobre também a ponte com a V-17 (verifications\verif_pivot.ms): Base Pivot
 seguido de "Rodar Verificações" tem que passar na V-17, objeto solto e
 produto agrupado — critério pedido no aceite da issue.
 RODAR NUMA CENA VAZIA (File > New): cria e apaga os objetos de cada caso.
 Resultado: <pasta temp do Max>\inlab_test_utilidades.txt (PASS/FAIL por item).

 24/Set/2026 (issue #47): seção "FIND OBJECTS PESADOS" — critério A da
 decisão do humano (acima de 25% do polyMax da família ativa, em
 triângulos) e o caso sem família ativa (N mais pesados da cena). Carrega
 core\struct_familia.ms (FamiliaConfig, InLab_FamiliaAtiva) e
 functions\fn_otim_nucleo.ms (InLab_Otim_Triangulos) a mais que os casos
 de pivot acima.
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_EhGeometria, InLab_Instancias
global InLab_ResetXFormSelecao, InLab_CentralizarPivot, InLab_BasePivot
global InLab_RaizDoNo, InLab_GeometriasDescendentes, InLab_BBoxGeometrias, InLab_RaizesDaSelecao
global InLab_RegistrarVerif, InLab_ResetarResultados, InLab_VerifResults, InLab_V17_PivotRaiz
global FamiliaConfig, InLab_FamiliaAtiva, InLab_Otim_Triangulos
global InLab_FindObjectsPesados, InLab_FindCompararPeso, INLAB_FIND_FRACAO_POLYMAX, INLAB_FIND_TOP_N
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_utilidades.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    -- Compara Point3 com tolerância (undo/pivot em ponto flutuante).
    fn pertoP3 a b tol = (abs (a.x - b.x) <= tol and abs (a.y - b.y) <= tol and abs (a.z - b.z) <= tol)

    -- Status da V-17 numa rodada isolada (reseta o coletor antes).
    fn statusV17 objs =
    (
        InLab_ResetarResultados()
        InLab_V17_PivotRaiz objs
        InLab_VerifResults[InLab_VerifResults.count].status
    )

    fn limparCena = ( delete (for o in objects collect o) )

    local logOriginal = InLab_Log
    local unidadeOriginal = units.SystemType
    local familiaOriginal = InLab_FamiliaAtiva

    try
    (
        for m in #(@"core\struct_result.ms", @"core\struct_familia.ms", @"core\utils.ms",
                   @"functions\fn_otim_nucleo.ms", @"functions\fn_autouv.ms", @"functions\fn_utilidades.ms",
                   @"verifications\verif_pivot.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms (via nenhum aqui) não redefine nada;
        -- InLab_Log já existe como global (declarado acima), sobrescreve direto.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        units.SystemType = #Centimeters
        limparCena()

        ---------------------------------------------------------- RESET XFORM
        local rx1 = Box length:40 width:40 height:40
        rx1.scale = [2, 1, 1]
        local nrx = InLab_ResetXFormSelecao #(rx1)
        checar "ResetXForm: 1 objeto processado" (nrx == 1)
        checar "ResetXForm: scale volta a [1,1,1]" (pertoP3 rx1.scale [1,1,1] 0.001)
        checar "ResetXForm: stack colapsado para Editable_mesh" ((classof rx1.baseObject) == Editable_mesh)
        local rxPt = Point()
        checar "ResetXForm: helper não é geometria, 0 processado" ((InLab_ResetXFormSelecao #(rxPt)) == 0)
        limparCena()

        ---------------------------------------------------------- CENTER PIVOT (solto)
        local cp1 = Box length:20 width:10 height:30 pos:[100, 0, 0]
        cp1.pivot = [1, 1, 1]   -- estraga o pivot de propósito
        checar "CenterPivot: 1 objeto processado" ((InLab_CentralizarPivot #(cp1)) == 1)
        checar "CenterPivot: pivot no centro do bbox (100,0,15)" (pertoP3 cp1.pivot [100, 0, 15] 0.01)
        limparCena()

        ---------------------------------------------------------- CENTER PIVOT: helper não vira geometria
        local cpPt = Point pos:[50, 50, 50]
        local cpPivotAntes = copy cpPt.pivot
        checar "CenterPivot: helper sozinho, 0 processado" ((InLab_CentralizarPivot #(cpPt)) == 0)
        checar "CenterPivot: pivot do helper não mudou" (pertoP3 cpPt.pivot cpPivotAntes 0.001)
        limparCena()

        ---------------------------------------------------------- CENTER PIVOT: grupo — cabeça, não as peças
        local cg1 = Box length:40 width:40 height:40
        local cg2 = Box length:20 width:20 height:20 pos:[60, 0, 0]
        local cgGrupo = group #(cg1, cg2) name:"ProdutoCentro"
        local cg1PivotAntes = copy cg1.pivot
        local cg2PivotAntes = copy cg2.pivot
        cgGrupo.pivot = [999, 999, 999]   -- estraga o pivot da cabeça
        checar "CenterPivot grupo: 1 raiz processada (não 2 peças)" ((InLab_CentralizarPivot #(cg1, cg2)) == 1)
        checar "CenterPivot grupo: pivot da cabeça no centro do bbox (25,0,20)" (pertoP3 cgGrupo.pivot [25, 0, 20] 0.01)
        checar "CenterPivot grupo: peça 1 não teve o pivot tocado" (pertoP3 cg1.pivot cg1PivotAntes 0.001)
        checar "CenterPivot grupo: peça 2 não teve o pivot tocado" (pertoP3 cg2.pivot cg2PivotAntes 0.001)
        limparCena()

        ---------------------------------------------------------- BASE PIVOT (solto) + V-17
        local bp1 = Box length:40 width:40 height:40
        bp1.pivot = [5, 5, 5]   -- estraga o pivot de propósito
        checar "BasePivot solto: 1 objeto processado" ((InLab_BasePivot #(bp1)) == 1)
        checar "BasePivot solto: pivot na base, centro XY (0,0,0)" (pertoP3 bp1.pivot [0, 0, 0] 0.01)
        checar "BasePivot solto → Rodar Verificações: V-17 passa" ((statusV17 #(bp1)) == #pass)
        limparCena()

        ---------------------------------------------------------- BASE PIVOT: não move pro Z=0 do mundo, só pra base do objeto
        local bp2 = Box length:20 width:20 height:20 pos:[0, 0, 20]   -- produto "flutuando" 20 cm acima do chão
        InLab_BasePivot #(bp2)
        checar "BasePivot flutuando: pivot vai pra base DO OBJETO (z=20), não pro chão" (pertoP3 bp2.pivot [0, 0, 20] 0.01)
        checar "BasePivot flutuando → V-17 reprova (produto não está no chão)" ((statusV17 #(bp2)) == #fail)
        limparCena()

        ---------------------------------------------------------- BASE PIVOT: helper não vira geometria
        local bpPt = Point()
        local bpPivotAntes = copy bpPt.pivot
        checar "BasePivot: helper sozinho, 0 processado" ((InLab_BasePivot #(bpPt)) == 0)
        checar "BasePivot: pivot do helper não mudou" (pertoP3 bpPt.pivot bpPivotAntes 0.001)
        limparCena()

        ---------------------------------------------------------- BASE PIVOT: grupo (aceite da issue #50)
        -- Seleção com as PEÇAS (grupo aberto, várias selecionadas por dentro).
        local bg1 = Box length:40 width:40 height:40
        local bg2 = Box length:20 width:20 height:20 pos:[60, 0, 0]
        local bgGrupo = group #(bg1, bg2) name:"ProdutoBase"
        local bg1PivotAntes = copy bg1.pivot
        local bg2PivotAntes = copy bg2.pivot
        bgGrupo.pivot = [999, -999, 500]   -- estraga o pivot da cabeça
        checar "BasePivot grupo (peças selecionadas): 1 raiz processada" ((InLab_BasePivot #(bg1, bg2)) == 1)
        checar "BasePivot grupo: pivot da cabeça na base, centro XY (25,0,0)" (pertoP3 bgGrupo.pivot [25, 0, 0] 0.01)
        checar "BasePivot grupo: peça 1 não teve o pivot tocado" (pertoP3 bg1.pivot bg1PivotAntes 0.001)
        checar "BasePivot grupo: peça 2 não teve o pivot tocado" (pertoP3 bg2.pivot bg2PivotAntes 0.001)
        checar "BasePivot grupo (peças) → Rodar Verificações: V-17 passa" ((statusV17 #(bg1, bg2)) == #pass)

        -- Mesmo grupo, agora simulando clique num grupo FECHADO: a seleção
        -- do Max só traz a cabeça (pitfall documentado no CLAUDE.md).
        bgGrupo.pivot = [1, 2, 3]   -- estraga de novo
        checar "BasePivot grupo (cabeça selecionada, grupo fechado): 1 raiz processada" ((InLab_BasePivot #(bgGrupo)) == 1)
        checar "BasePivot grupo (cabeça selecionada): pivot correto (25,0,0)" (pertoP3 bgGrupo.pivot [25, 0, 0] 0.01)
        checar "BasePivot grupo (cabeça selecionada) → V-17 passa" ((statusV17 #(bg1, bg2)) == #pass)
        limparCena()

        ---------------------------------------------------------- FIND OBJECTS PESADOS (issue #47)
        checar "Find Objects: constante de fração = 25% do polyMax" (INLAB_FIND_FRACAO_POLYMAX == 0.25)
        checar "Find Objects: constante N sem família = 5" (INLAB_FIND_TOP_N == 5)

        -- Critério B (sem família ativa): os N objetos com mais triângulos da
        -- cena. 7 caixas com lengthsegs diferentes → 7 pesos distintos; mede
        -- com o mesmo helper que a função usa (InLab_Otim_Triangulos) em vez
        -- de supor a fórmula de tessellation da caixa.
        InLab_FamiliaAtiva = undefined
        local semFamObjs = for i = 1 to 7 collect (Box length:10 width:10 height:10 lengthsegs:i name:("FindB" + i as string))
        local paresReais = for o in semFamObjs collect #(o, InLab_Otim_Triangulos #(o))
        qsort paresReais InLab_FindCompararPeso
        local nomesEsperadosSemFam = for i = 1 to INLAB_FIND_TOP_N collect paresReais[i][1].name
        clearSelection()
        local nSemFam = InLab_FindObjectsPesados objs:semFamObjs
        checar "Find Objects sem família: retorna INLAB_FIND_TOP_N" (nSemFam == INLAB_FIND_TOP_N)
        local nomesSelSemFam = for o in (selection as array) collect o.name
        checar "Find Objects sem família: seleciona os N mais pesados da cena" (nomesSelSemFam.count == nomesEsperadosSemFam.count and
            (for n in nomesEsperadosSemFam where (findItem nomesSelSemFam n) == 0 collect n).count == 0)
        limparCena()

        -- Critério A (com família ativa): acima de INLAB_FIND_FRACAO_POLYMAX
        -- do polyMax, em triângulos. polyMax calculado a partir dos pesos
        -- REAIS medidos (não de uma fórmula suposta) pra cair exatamente
        -- entre "média" e "pesada".
        local leve   = Box length:10 width:10 height:10 lengthsegs:1  name:"FindLeve"
        local media  = Box length:10 width:10 height:10 lengthsegs:5  name:"FindMedia"
        local pesada = Box length:10 width:10 height:10 lengthsegs:20 name:"FindPesada"
        local trisLeve   = InLab_Otim_Triangulos #(leve)
        local trisMedia  = InLab_Otim_Triangulos #(media)
        local trisPesada = InLab_Otim_Triangulos #(pesada)
        checar "Find Objects: setup com 3 pesos distintos e crescentes" (trisLeve < trisMedia and trisMedia < trisPesada)
        local cfgTeste = FamiliaConfig nome:"teste_find" polyMax:(((trisMedia + trisPesada) / 2.0) / INLAB_FIND_FRACAO_POLYMAX)
        InLab_FamiliaAtiva = cfgTeste
        clearSelection()
        local nComFam = InLab_FindObjectsPesados objs:#(leve, media, pesada)
        checar "Find Objects com família: só o objeto acima de 25% do polyMax" (nComFam == 1)
        checar "Find Objects com família: seleciona só o objeto pesado" (selection.count == 1 and selection[1].name == "FindPesada")
        limparCena()

        -- Nenhum objeto acima do limite: nada selecionado, retorna 0.
        local leve2 = Box length:10 width:10 height:10 lengthsegs:1 name:"FindLeve2"
        local cfgAlto = FamiliaConfig nome:"teste_find_alto" polyMax:1000000000
        InLab_FamiliaAtiva = cfgAlto
        clearSelection()
        local nNenhum = InLab_FindObjectsPesados objs:#(leve2)
        checar "Find Objects com família: nenhum acima do limite retorna 0" (nNenhum == 0)
        checar "Find Objects com família: nada fica selecionado" (selection.count == 0)
        limparCena()

        -- Helper sozinho não é geometria: não entra na contagem nem na seleção.
        InLab_FamiliaAtiva = undefined
        local ptFind = Point()
        clearSelection()
        local nHelper = InLab_FindObjectsPesados objs:#(ptFind)
        checar "Find Objects: helper sozinho não conta como geometria, retorna 0" (nHelper == 0)
        checar "Find Objects: helper sozinho não fica selecionado" (selection.count == 0)
        limparCena()
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    try ( limparCena() ) catch ()
    units.SystemType = unidadeOriginal
    InLab_Log = logOriginal
    InLab_FamiliaAtiva = familiaOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
