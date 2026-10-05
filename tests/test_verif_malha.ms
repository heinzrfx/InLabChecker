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

        ---------------------------------------------------------------- V-09
        fn rodar09 objs = ( InLab_ResetarResultados(); InLab_V09_Duplicados (InLab_Malha_AnalisarCena objs) objs; statusDe "V-09" )
        b = caixaMesh()
        checar "V-09: Box sem duplicata passa" ((rodar09 #(b)) == #pass)
        meshop.cloneFaces b #{1}
        update b
        checar "V-09: face clonada no lugar reprova" ((rodar09 #(b)) == #fail)
        checar ("V-09: mensagem cita faces coincidentes ('" + mensagemDe "V-09" + "')") ((findString (mensagemDe "V-09") "coincidente") != undefined)
        limparCena()
        b = caixaMesh()
        local b2 = copy b
        checar "V-09: dois Box iguais no mesmo lugar reprovam" ((rodar09 #(b, b2)) == #fail)
        checar ("V-09: mensagem cita os dois objetos ('" + mensagemDe "V-09" + "')") ((findString (mensagemDe "V-09") b2.name) != undefined)
        b2.pos = [100, 0, 0]
        checar "V-09: o mesmo Box em outro lugar passa" ((rodar09 #(b, b2)) == #pass)
        limparCena()
        -- membro de grupo fechado não é acusado contra a cabeça
        local gA = caixaMesh()
        local gB = caixaMesh()
        gB.pos = [100, 0, 0]
        local grp = group #(gA, gB) name:"Produto"
        checar "V-09: membros de grupo fechado, sem duplicata, passam" ((rodar09 #(gA, gB)) == #pass)
        limparCena()
        -- análise que falhou não passa em silêncio
        b = caixaMesh()
        local ae9 = MalhaAnalise no:b instancias:#(b) erro:"teste"
        InLab_ResetarResultados(); InLab_V09_Duplicados #(ae9) #(b)
        checar "Erro: V-09 não passa em silêncio (#warning)" ((statusDe "V-09") == #warning)
        checar "Erro: V-09 diz 'não analisado'" ((findString (mensagemDe "V-09") "não analisado") != undefined)
        limparCena()
        -- desempenho: painel de lado (plano x = const), milhares de faces com o mesmo qx
        local pl = Plane length:100 width:100 lengthsegs:100 widthsegs:100
        rotate pl (eulerAngles 0 90 0)
        convertToMesh pl
        local mp = snapshotAsMesh pl
        local tolp = InLab_Malha_Tolerancia()
        local qxs = for f = 1 to mp.numfaces collect (floor (((meshop.getFaceCenter mp f).x as double) / tolp + 0.5))
        local qx1 = qxs[1]
        local mesmoQx = (for x in qxs where x == qx1 collect x).count
        linha ("[LOG] plano: " + mp.numfaces as string + " faces, " + mesmoQx as string + " com o mesmo qx")
        checar "V-09 desempenho: o plano de lado tem quase todas as faces no mesmo qx" (mesmoQx > (mp.numfaces * 0.9))
        local t0p = timeStamp()
        local dupP = InLab_Malha_FacesDuplicadas mp tolp
        local segP = (timeStamp() - t0p) / 1000.0
        linha ("[LOG] FacesDuplicadas em " + mp.numfaces as string + " faces: " + segP as string + " s")
        checar "V-09 desempenho: plano de lado sem duplicata" (dupP == 0)
        checar ("V-09 desempenho: 20 mil faces em menos de 5 s (" + segP as string + " s)") (segP < 5.0)
        delete mp
        limparCena()
        ---------------------------------------------------------------- V-13
        fn cilindroPoly = ( local c = Cylinder radius:20 height:40 sides:6 heightsegs:1 capsegs:1 smooth:true; convertToPoly c; c )
        fn tampa p = ( local t = 0; for f = 1 to (polyop.getNumFaces p) where t == 0 and (polyop.getFaceDeg p f) == 6 do t = f; t )
        local c = cilindroPoly()
        checar ("V-13: cilindro poly (tampa ngon plana) passa ('" + (rodarMalha InLab_V13_Ngons #(c) "V-13") as string + "')") ((rodarMalha InLab_V13_Ngons #(c) "V-13") == #pass)
        local ft = tampa c
        polyop.moveVert c (polyop.getFaceVerts c ft)[1] [0, 0, 5]
        checar "V-13: tampa ngon não plana reprova" ((rodarMalha InLab_V13_Ngons #(c) "V-13") == #fail)
        checar ("V-13: mensagem diz não plana ('" + mensagemDe "V-13" + "')") ((findString (mensagemDe "V-13") "não plana") != undefined)
        limparCena()
        c = cilindroPoly()
        ft = tampa c
        local lado = 0
        for f = 1 to (polyop.getNumFaces c) where lado == 0 and (polyop.getFaceDeg c f) == 4 do lado = f
        polyop.setFaceSmoothGroup c #{ft} (polyop.getFaceSmoothGroup c lado)
        checar "V-13: tampa suavizada junto com o lado (90°) reprova" ((rodarMalha InLab_V13_Ngons #(c) "V-13") == #fail)
        checar ("V-13: mensagem diz suavizada ('" + mensagemDe "V-13" + "')") ((findString (mensagemDe "V-13") "suavizada") != undefined)
        limparCena()
        b = caixaMesh()
        checar "V-13: Editable Mesh passa como não se aplica" ((rodarMalha InLab_V13_Ngons #(b) "V-13") == #pass and (findString (mensagemDe "V-13") "não se aplica") != undefined)
        limparCena()
        -- leitura das ngons que falhou não passa em silêncio
        b = caixaMesh()
        local ae13 = MalhaAnalise no:b instancias:#(b) erroNgons:"teste" ngonsAplica:true
        InLab_ResetarResultados(); InLab_V13_Ngons #(ae13)
        checar "Erro: V-13 não passa em silêncio (#warning)" ((statusDe "V-13") == #warning)
        checar "Erro: V-13 diz 'não analisado'" ((findString (mensagemDe "V-13") "não analisado") != undefined)
        limparCena()
        ---------------------------------------------------------------- V-07
        local cfgCU = InLab_ObterFamilia "corpo_unico"
        INLAB_LIMITES_PROVISORIOS = true
        fn rodar07 cfg objs = ( InLab_ResetarResultados(); InLab_V07_RatioVT cfg objs; statusDe "V-07" )
        local esf = Sphere radius:20 segs:32 smooth:true mapcoords:true name:"Esfera_suave"
        checar ("V-07: esfera suavizada passa ('" + (rodar07 cfgCU #(esf)) as string + "': " + mensagemDe "V-07" + ")") ((rodar07 cfgCU #(esf)) == #pass)
        esf.smooth = false
        checar "V-07: esfera sem smoothing passa do limite (advertência, provisório)" ((rodar07 cfgCU #(esf)) == #warning)
        checar ("V-07: mensagem tem o objeto e o ratio ('" + mensagemDe "V-07" + "')") ((findString (mensagemDe "V-07") "Esfera_suave: 2.99") != undefined)
        INLAB_LIMITES_PROVISORIOS = false
        checar "V-07: com limites valendo, reprova" ((rodar07 cfgCU #(esf)) == #fail)
        INLAB_LIMITES_PROVISORIOS = true
        InLab_ResetarResultados()
        InLab_V07_RatioVT cfgCU #(esf) exportador:undefined
        checar "V-07: sem exportador vira 'não medido' (advertência)" (statusDe "V-07" == #warning and (findString (mensagemDe "V-07") "não medido") != undefined)
        checar "V-07: a pasta temporária foi apagada" ((getFiles ((getDir #temp) + "\inlab_v07\*")).count == 0)
        limparCena()
        -- Review Focus: nome repetido soma no mesmo item; oculto fica de fora sem "não medido"
        local r1 = Sphere radius:10 segs:16 smooth:true mapcoords:true name:"Repetido"
        local r2 = Sphere radius:10 segs:16 smooth:true mapcoords:true name:"Repetido" pos:[50, 0, 0]
        local oc = Sphere radius:10 segs:16 smooth:true mapcoords:true name:"Oculto" pos:[100, 0, 0]
        hide oc
        checar ("V-07: nome repetido e objeto oculto não quebram ('" + (rodar07 cfgCU #(r1, r2, oc)) as string + "': " + mensagemDe "V-07" + ")") ((rodar07 cfgCU #(r1, r2, oc)) == #pass)
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
