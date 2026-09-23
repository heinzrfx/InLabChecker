/*
 tests\test_verificacoes.ms — teste automático do motor de verificação (issue #34)
 Cobre as V-xx implementadas (uma a uma, em cena montada para cada caso),
 InLab_AprovacaoFinal com limite provisório e a rodada completa do
 orquestrador (sem ID repetido).
 RODAR NUMA CENA VAZIA (File > New): cria e apaga os objetos de cada caso.
 Resultado: <pasta temp do Max>\inlab_test_verificacoes.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_VerifResults, InLab_ResetarResultados, InLab_AprovacaoFinal, InLab_RegistrarVerif
global INLAB_LIMITES_PROVISORIOS, InLab_ObterFamilia, InLab_RodarVerificacoes
global InLab_V17_PivotRaiz, InLab_V18_EixosPivot, InLab_V11_Modificadores, InLab_V12_XForm
global InLab_V21_NomesValidos, InLab_V22_SufixosSequenciais, InLab_V30_Keyframes, InLab_V03_Poligonos
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_verificacoes.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    -- Status do resultado `idV` da última rodada (#pass/#fail/#warning, ou
    -- #ausente se a verificação não registrou nada).
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

    local logOriginal = InLab_Log
    local unidadeOriginal = units.SystemType
    local provOriginal = true

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms",
                   @"familias\familia_corpo_unico.ms", @"familias\familia_pernas_tampo.ms",
                   @"familias\familia_estrutura_estofado.ms", @"familias\familia_estrutura_modular.ms",
                   @"familias\familia_translacao.ms", @"familias\familia_rotacao.ms",
                   @"familias\familia_giro_assento.ms", @"familias\familia_movimento_especial.ms",
                   @"functions\fn_otim_nucleo.ms",
                   @"functions\fn_realworldscale.ms",
                   @"verifications\verif_peso_poly.ms", @"verifications\verif_pivot.ms",
                   @"verifications\verif_nomenclatura.ms", @"verifications\verif_geometria.ms",
                   @"verifications\verif_animacao.ms", @"report\report_generator.ms",
                   @"verifications\verif_orquestrador.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        provOriginal = INLAB_LIMITES_PROVISORIOS
        units.SystemType = #Centimeters
        limparCena()

        -- Roda UMA verificação sobre `objs` e devolve o status dela.
        fn rodar f objs idV = ( InLab_ResetarResultados(); f objs; statusDe idV )

        ---------------------------------------------------------------- V-17
        local b = Box length:40 width:40 height:40   -- pivot na base, centro XY, Z=0
        checar "V-17: pivot na base, centrado, Z=0 passa" ((rodar InLab_V17_PivotRaiz #(b) "V-17") == #pass)
        b.pivot = [0, 0, 0.05]                        -- 0,5 mm acima
        checar "V-17: pivot 0,5 mm acima passa (tolerância 1 mm)" ((rodar InLab_V17_PivotRaiz #(b) "V-17") == #pass)
        b.pivot = [0, 0, 0.5]                         -- 5 mm acima
        checar "V-17: pivot 5 mm acima reprova (issue #31)" ((rodar InLab_V17_PivotRaiz #(b) "V-17") == #fail)
        checar ("V-17: mensagem mostra o desvio em mm ('" + mensagemDe "V-17" + "')") ((findString (mensagemDe "V-17") "5.0 mm") != undefined)
        b.pivot = [0.5, 0, 0]                         -- 5 mm fora do centro em X
        checar "V-17: pivot 5 mm fora do centro XY reprova" ((rodar InLab_V17_PivotRaiz #(b) "V-17") == #fail)
        limparCena()

        -- Produto agrupado: o pivot que vale é o do nó de topo (cabeça do grupo).
        local g1 = Box length:40 width:40 height:40
        local g2 = Box length:20 width:20 height:20 pos:[60, 0, 0]
        local grp = group #(g1, g2) name:"Produto"
        local cx = (grp.min.x + grp.max.x) / 2.0
        grp.pivot = [cx, (grp.min.y + grp.max.y) / 2.0, 0]
        checar "V-17: grupo com pivot na base passa (issue #30)" ((rodar InLab_V17_PivotRaiz #(g1, g2) "V-17") == #pass)
        grp.pivot = [cx, grp.pivot.y, 80]
        checar "V-17: grupo com pivot 80 cm acima reprova (issue #30)" ((rodar InLab_V17_PivotRaiz #(g1, g2) "V-17") == #fail)
        grp.pivot = [cx, grp.pivot.y, 0]

        ---------------------------------------------------------------- V-18
        checar "V-18: grupo sem rotação passa" ((rodar InLab_V18_EixosPivot #(g1, g2) "V-18") == #pass)
        rotate grp (eulerAngles 0 0 10)
        checar "V-18: cabeça do grupo girada 10° reprova (issue #30)" ((rodar InLab_V18_EixosPivot #(g1, g2) "V-18") == #fail)
        limparCena()
        local r1 = Box length:40 width:40 height:40
        rotate r1 (eulerAngles 0 0 10)
        checar "V-18: objeto solto girado 10° reprova" ((rodar InLab_V18_EixosPivot #(r1) "V-18") == #fail)
        limparCena()

        ---------------------------------------------------------------- V-11 / V-12
        local m1 = Box length:40 width:40 height:40
        checar "V-11: stack vazio passa" ((rodar InLab_V11_Modificadores #(m1) "V-11") == #pass)
        addModifier m1 (Bend())
        checar "V-11: modificador no stack reprova" ((rodar InLab_V11_Modificadores #(m1) "V-11") == #fail)
        limparCena()
        local s1 = Box length:40 width:40 height:40
        checar "V-12: scale 100% passa" ((rodar InLab_V12_XForm #(s1) "V-12") == #pass)
        s1.scale = [1.5, 1.5, 1.5]
        checar "V-12: scale 150% reprova" ((rodar InLab_V12_XForm #(s1) "V-12") == #fail)
        limparCena()

        ---------------------------------------------------------------- V-21
        local n1 = Box name:"Pe_Mesa_01"
        checar "V-21: nome [A-Za-z0-9_] passa" ((rodar InLab_V21_NomesValidos #(n1) "V-21") == #pass)
        n1.name = "Pé Mesa"
        checar "V-21: nome com acento e espaço reprova" ((rodar InLab_V21_NomesValidos #(n1) "V-21") == #fail)
        limparCena()

        ---------------------------------------------------------------- V-22
        local p1 = Box name:"Perna_01"
        local p2 = Box name:"Perna_02"
        checar "V-22: Perna_01, Perna_02 passa" ((rodar InLab_V22_SufixosSequenciais #(p1, p2) "V-22") == #pass)
        p2.name = "Perna_03"
        local p3 = Box name:"Perna_04"
        checar "V-22: Perna_01, _03, _04 com lacuna não passa" ((rodar InLab_V22_SufixosSequenciais #(p1, p2, p3) "V-22") != #pass)
        local msg22 = mensagemDe "V-22"
        local ocorr = 0
        for i = 1 to msg22.count - 6 where (substring msg22 i 7) == "Perna_*" do ocorr += 1
        checar ("V-22: uma mensagem por grupo, não por índice (" + ocorr as string + ") (issue #35)") (ocorr == 1)
        limparCena()
        local q1 = Box name:"Perna_02"
        checar "V-22: Perna_02 sozinho não passa (issue #35)" ((rodar InLab_V22_SufixosSequenciais #(q1) "V-22") != #pass)
        q1.name = "Perna_01"
        local q2 = Box name:"Perna_01"
        local st = rodar InLab_V22_SufixosSequenciais #(q1, q2) "V-22"
        local m22 = mensagemDe "V-22"
        checar ("V-22: sufixo repetido acusado como repetido, não lacuna ('" + m22 + "')") (st != #pass and (findString m22 "repetido") != undefined and (findString m22 "lacuna") == undefined)
        limparCena()

        ---------------------------------------------------------------- V-30
        local cfgAnim = InLab_ObterFamilia "translacao"
        local cfgEst = InLab_ObterFamilia "corpo_unico"
        local k1 = Box length:40 width:40 height:40
        fn rodar30 cfg objs = ( InLab_ResetarResultados(); InLab_V30_Keyframes cfg objs; statusDe "V-30" )
        checar "V-30: família animada sem keys reprova" ((rodar30 cfgAnim #(k1)) == #fail)
        checar "V-30: família estática sem keys passa" ((rodar30 cfgEst #(k1)) == #pass)
        with animate on ( at time 10 k1.pos = [0, -30, 0] )
        checar "V-30: família animada com keys passa" ((rodar30 cfgAnim #(k1)) == #pass)
        checar "V-30: família estática com keys vira advertência" ((rodar30 cfgEst #(k1)) == #warning)
        limparCena()

        ---------------------------------------------------------------- V-03 (triângulos)
        local t1 = Box()   -- 6 faces quad = 12 triângulos
        InLab_ResetarResultados()
        InLab_V03_Poligonos cfgEst #(t1)
        local m03 = mensagemDe "V-03"
        checar ("V-03 conta triângulos: '" + m03 + "'") ((findString m03 "12 triângulos") != undefined)
        checar "V-03 abaixo da faixa vira advertência (limite provisório)" ((statusDe "V-03") == #warning)
        limparCena()

        ---------------------------------------------------------------- APROVAÇÃO
        INLAB_LIMITES_PROVISORIOS = true
        InLab_ResetarResultados()
        InLab_RegistrarVerif "T-01" "teste crítico ok" true "" critico:true
        InLab_RegistrarVerif "T-02" "teste provisório falho" false "" critico:true provisorio:true
        checar "Aprovação: falha provisória vira advertência" ((statusDe "T-02") == #warning)
        checar "Aprovação: falha provisória não reprova" (InLab_AprovacaoFinal())
        InLab_RegistrarVerif "T-03" "teste crítico falho" false "" critico:true
        checar "Aprovação: crítico em FAIL reprova" (not (InLab_AprovacaoFinal()))
        INLAB_LIMITES_PROVISORIOS = false
        InLab_ResetarResultados()
        InLab_RegistrarVerif "T-04" "limite validado falho" false "" critico:true provisorio:true
        checar "Aprovação: sem limites provisórios, a falha reprova" ((statusDe "T-04") == #fail and not (InLab_AprovacaoFinal()))
        INLAB_LIMITES_PROVISORIOS = provOriginal
        InLab_ResetarResultados()
        InLab_RegistrarVerif "T-05" "advertência não crítica" false "" critico:false
        checar "Aprovação: não crítico falho não reprova" (InLab_AprovacaoFinal() and (statusDe "T-05") == #warning)

        ---------------------------------------------------------------- RODADA COMPLETA
        local c1 = Box name:"Corpo_01" length:40 width:40 height:40
        for cfg in #(cfgEst, cfgAnim, InLab_ObterFamilia "giro_assento") do
        (
            InLab_RodarVerificacoes cfg
            local ids = for r in InLab_VerifResults collect r.id
            local unicos = makeUniqueArray (deepCopy ids)
            checar ("Rodada '" + cfg.nome + "': " + ids.count as string + " resultados, sem ID repetido") (ids.count >= 15 and unicos.count == ids.count)
        )
        limparCena()
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    try ( limparCena() ) catch ()
    units.SystemType = unidadeOriginal
    INLAB_LIMITES_PROVISORIOS = provOriginal
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
