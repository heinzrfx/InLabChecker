/*
 tests\test_verif_malha.ms — teste do grupo 6 de verificações (issue #102)
 Spec: docs\superpowers\specs\2026-10-05-verif-geometria-grupo6-design.md
 RODAR NUMA CENA VAZIA (File > New): cria e apaga os objetos de cada caso.
 Resultado: <pasta temp do Max>\inlab_test_verif_malha.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_VerifResults, InLab_ResetarResultados, INLAB_LIMITES_PROVISORIOS, InLab_ObterFamilia
global MalhaAnalise, InLab_Malha_Analisar, InLab_Malha_AnalisarCena, InLab_V08_MalhaFechada, InLab_V10_Normais
global InLab_V09_Duplicados, InLab_V13_Ngons, InLab_V07_RatioVT, InLab_ObjetosVerificacao
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_verif_malha.txt"
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
    -- Roda a análise e UMA verificação de malha; devolve o status.
    fn rodarMalha f objs idV = ( InLab_ResetarResultados(); f (InLab_Malha_AnalisarCena objs); statusDe idV )
    fn caixaMesh = ( local b = Box length:40 width:40 height:40; convertToMesh b; b )

    local logOriginal = InLab_Log
    local unidadeOriginal = units.SystemType
    local provOriginal = true

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms",
                   @"familias\familia_corpo_unico.ms",
                   @"functions\fn_json.ms", @"functions\fn_export_gltf.ms",
                   @"verifications\verif_malha.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        provOriginal = INLAB_LIMITES_PROVISORIOS
        units.SystemType = #Centimeters
        limparCena()

        ---------------------------------------------------------------- ANÁLISE
        local b = caixaMesh()
        local a = InLab_Malha_Analisar b
        checar ("Análise: Box fechado — 12 tris, 0 furo, 0 invertida, 0 avesso (" + a.tris as string + "/" + a.furos as string + "/" + a.invertidas as string + "/" + a.avesso as string + ")") \
            (a.tris == 12 and a.furos == 0 and a.invertidas == 0 and a.avesso == 0 and a.erro == undefined)
        limparCena()
        local vazio = mesh numverts:0 numfaces:0
        local av = InLab_Malha_Analisar vazio
        checar "Análise: malha vazia devolve zeros sem erro" (av.tris == 0 and av.furos == 0 and av.erro == undefined)
        limparCena()

        ---------------------------------------------------------------- V-08
        b = caixaMesh()
        checar "V-08: Box fechado passa" ((rodarMalha InLab_V08_MalhaFechada #(b) "V-08") == #pass)
        meshop.deleteFaces b #{1}
        update b
        checar "V-08: Box com uma face apagada vira advertência" ((rodarMalha InLab_V08_MalhaFechada #(b) "V-08") == #warning)
        checar ("V-08: mensagem tem o objeto e a contagem ('" + mensagemDe "V-08" + "')") ((findString (mensagemDe "V-08") (b.name + ": 3 aresta")) != undefined)
        checar "V-10: furo de verdade não é normal invertida" ((rodarMalha InLab_V10_Normais #(b) "V-10") == #pass)
        limparCena()

        ---------------------------------------------------------------- V-10
        b = caixaMesh()
        checar "V-10: Box fechado passa" ((rodarMalha InLab_V10_Normais #(b) "V-10") == #pass)
        meshop.flipNormals b #{1}
        update b
        checar "V-10: uma face com o sentido trocado reprova" ((rodarMalha InLab_V10_Normais #(b) "V-10") == #fail)
        checar ("V-10: mensagem fala de sentido oposto ('" + mensagemDe "V-10" + "')") ((findString (mensagemDe "V-10") "sentido oposto") != undefined)
        checar "V-08: as arestas da face trocada não contam como furo" ((rodarMalha InLab_V08_MalhaFechada #(b) "V-08") == #pass)
        limparCena()
        b = caixaMesh()
        meshop.flipNormals b #{1..12}
        update b
        checar "V-10: Box todo do avesso reprova" ((rodarMalha InLab_V10_Normais #(b) "V-10") == #fail)
        checar ("V-10: mensagem fala do avesso ('" + mensagemDe "V-10" + "')") ((findString (mensagemDe "V-10") "avesso") != undefined)
        limparCena()

        ---------------------------------------------------------------- INSTÂNCIAS
        b = caixaMesh()
        local bi = instance b
        bi.pos = [100, 0, 0]
        local grupos = InLab_Malha_AnalisarCena #(b, bi)
        checar ("Instâncias: 1 análise para 2 nós (" + grupos.count as string + ")") (grupos.count == 1 and grupos[1].instancias.count == 2)
        limparCena()

        ---------------------------------------------------------------- ERRO DE ANÁLISE
        b = caixaMesh()
        local ae = MalhaAnalise no:b instancias:#(b) erro:"teste"
        InLab_ResetarResultados(); InLab_V08_MalhaFechada #(ae)
        checar "Erro: V-08 vira advertência" ((statusDe "V-08") == #warning)
        checar "Erro: V-08 diz 'não analisado'" ((findString (mensagemDe "V-08") "não analisado") != undefined)
        InLab_ResetarResultados(); InLab_V10_Normais #(ae)
        checar "Erro: V-10 não passa em silêncio (#warning)" ((statusDe "V-10") == #warning)
        checar "Erro: V-10 diz 'não analisado'" ((findString (mensagemDe "V-10") "não analisado") != undefined)
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
    INLAB_LIMITES_PROVISORIOS = provOriginal
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
