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
global InLab_EhGeometria, InLab_ObjetosVerificacao, InLab_VEx01_Ocultos
global InLab_V01_PesoMax, InLab_SalvarAntesDeVerificar
global InLab_DrawCallsDoNo, InLab_V05_DrawCalls, InLab_TetoDrawCalls, InLab_PrefGravar, InLab_PrefApagar
global InLab_V20_Nomenclatura, InLab_ParseJSON, InLab_Produto_Lista
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
                   @"functions\fn_json.ms", @"functions\fn_renomear_produto.ms",
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

        ---------------------------------------------------------------- GEOMETRIA (issue #35)
        -- Bones/Biped não são produto; oculto conta e gera advertência EX-01.
        local gBox = Box length:40 width:40 height:40
        local gBone = BoneSys.createBone [0,0,0] [0,0,50] [0,1,0]
        checar "Geometria: Box conta" (InLab_EhGeometria gBox)
        checar "Geometria: Bone não conta" (not (InLab_EhGeometria gBone))
        biped.createNew 100 -90 [200,0,0]
        local bipeds = for o in objects where classof o == Biped_Object collect o
        checar ("Geometria: Biped não conta (" + bipeds.count as string + " peças)") (bipeds.count > 0 and (for o in bipeds where InLab_EhGeometria o collect o).count == 0)
        checar "Geometria: universo da verificação é só o Box" ((InLab_ObjetosVerificacao()).count == 1)
        checar "EX-01: nada oculto passa" ((rodar InLab_VEx01_Ocultos #(gBox) "EX-01") == #pass)
        hide gBox
        checar "Geometria: Box oculto continua contando" ((InLab_ObjetosVerificacao()).count == 1)
        checar "EX-01: Box oculto vira advertência" ((rodar InLab_VEx01_Ocultos #(gBox) "EX-01") == #warning)
        checar ("EX-01: mensagem cita o objeto ('" + mensagemDe "EX-01" + "')") ((findString (mensagemDe "EX-01") gBox.name) != undefined)
        checar "EX-01: não reprova" (InLab_AprovacaoFinal())
        unhide gBox
        local camOculta = LayerManager.newLayerFromName "InLab_teste_oculta"
        camOculta.addNode gBox
        camOculta.ishidden = true
        checar "EX-01: Box em camada oculta vira advertência" ((rodar InLab_VEx01_Ocultos #(gBox) "EX-01") == #warning)
        (LayerManager.getLayer 0).addNode gBox
        LayerManager.deleteLayerByName "InLab_teste_oculta"
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

        ---------------------------------------------------------------- V-05 (draw calls, issue #32)
        -- Draw call = material usado pelas faces, por objeto (primitive do glTF).
        local d1 = Box length:40 width:40 height:40                     -- sem material
        checar "Draw calls: Box sem material = 1" ((InLab_DrawCallsDoNo d1) == 1)
        d1.material = Standardmaterial()
        checar "Draw calls: Box com 1 material = 1" ((InLab_DrawCallsDoNo d1) == 1)
        d1.material = Multimaterial numsubs:3                            -- Box tem IDs 1..6
        checar ("Draw calls: Box com Multi/Sub de 3 = 3 (" + (InLab_DrawCallsDoNo d1) as string + ")") ((InLab_DrawCallsDoNo d1) == 3)
        convertToPoly d1
        polyop.setFaceMatID d1 #{1..(polyop.getNumFaces d1)} 1
        checar "Draw calls: Multi/Sub com só o ID 1 usado = 1" ((InLab_DrawCallsDoNo d1) == 1)
        polyop.setFaceMatID d1 #{1} 2
        checar "Draw calls: Multi/Sub com IDs 1 e 2 usados = 2" ((InLab_DrawCallsDoNo d1) == 2)
        limparCena()

        -- Giro de assento: conjunto + base + rodízios atachados = 3 objetos.
        local cfgGiro = copy (InLab_ObterFamilia "giro_assento")
        cfgGiro.maxDrawCalls = 4
        local gz = #(Box name:"Conjunto_Giratorio", Box name:"Base" pos:[0,0,-50], Box name:"Rodizios" pos:[0,0,-60])
        InLab_ResetarResultados(); InLab_V05_DrawCalls cfgGiro gz
        checar ("V-05: giro com conjunto + base + rodízios passa ('" + mensagemDe "V-05" + "')") ((statusDe "V-05") == #pass)
        checar "V-05: mensagem fala em draw calls e teto" ((findString (mensagemDe "V-05") "draw call") != undefined and (findString (mensagemDe "V-05") "teto 4") != undefined)
        gz[1].material = Multimaterial numsubs:3                         -- 3 + 1 + 1 = 5
        INLAB_LIMITES_PROVISORIOS = false
        InLab_ResetarResultados(); InLab_V05_DrawCalls cfgGiro gz
        checar ("V-05: Multi/Sub estoura o teto e reprova ('" + mensagemDe "V-05" + "')") ((statusDe "V-05") == #fail)
        checar "V-05: mensagem aponta o objeto com mais draw calls" ((findString (mensagemDe "V-05") "Conjunto_Giratorio") != undefined)
        INLAB_LIMITES_PROVISORIOS = provOriginal
        -- Teto alterável pelo ini, sem mexer no código.
        InLab_PrefGravar "maxDrawCalls_giro_assento" "8"
        checar "V-05: teto do ini vale no lugar do da família" ((InLab_TetoDrawCalls cfgGiro) == 8)
        InLab_ResetarResultados(); InLab_V05_DrawCalls cfgGiro gz
        checar ("V-05: com teto 8 do ini passa ('" + mensagemDe "V-05" + "')") ((statusDe "V-05") == #pass and (findString (mensagemDe "V-05") "ini") != undefined)
        InLab_PrefGravar "maxDrawCalls_giro_assento" "abc"
        checar "V-05: valor inválido no ini é ignorado" ((InLab_TetoDrawCalls cfgGiro) == 4)
        InLab_PrefApagar "maxDrawCalls_giro_assento"
        -- Família sem teto definido: advertência, não reprova.
        cfgGiro.maxDrawCalls = undefined
        InLab_ResetarResultados(); InLab_V05_DrawCalls cfgGiro gz
        checar "V-05: família sem teto vira advertência" ((statusDe "V-05") == #warning)
        for nome in #("corpo_unico", "pernas_tampo", "estrutura_estofado", "estrutura_modular", "translacao", "rotacao", "giro_assento", "movimento_especial") do
            checar ("V-05: família '" + nome + "' tem teto inteiro") (isKindOf (InLab_ObterFamilia nome).maxDrawCalls Integer)
        limparCena()

        ---------------------------------------------------------------- V-03 (triângulos)
        local t1 = Box()   -- 6 faces quad = 12 triângulos
        InLab_ResetarResultados()
        InLab_V03_Poligonos cfgEst #(t1)
        local m03 = mensagemDe "V-03"
        checar ("V-03 conta triângulos: '" + m03 + "'") ((findString m03 "12 triângulos") != undefined)
        checar "V-03 abaixo da faixa vira advertência (limite provisório)" ((statusDe "V-03") == #warning)
        limparCena()

        ---------------------------------------------------------------- V-01 (issue #33)
        -- caminho:/pendente: injetados para não salvar a cena da sessão.
        local cfgV01 = InLab_ObterFamilia "corpo_unico"
        local arqPeq = getSourceFileName()             -- arquivo pequeno que existe
        fn rodar01 cfg c p = ( InLab_ResetarResultados(); InLab_V01_PesoMax cfg caminho:c pendente:p; statusDe "V-01" )
        checar "V-01: cena nunca salva vira advertência" ((rodar01 cfgV01 "" false) == #warning)
        checar ("V-01: cena nunca salva diz 'não medido' ('" + mensagemDe "V-01" + "')") ((findString (mensagemDe "V-01") "não medido") != undefined)
        checar "V-01: cena nunca salva não reprova" (InLab_AprovacaoFinal())
        checar "V-01: alterações pendentes vira advertência (não mede o arquivo antigo)" ((rodar01 cfgV01 arqPeq true) == #warning)
        checar ("V-01: alterações pendentes explica ('" + mensagemDe "V-01" + "')") ((findString (mensagemDe "V-01") "alterações não salvas") != undefined)
        checar "V-01: cena salva e em dia mede e passa" ((rodar01 cfgV01 arqPeq false) == #pass)
        checar ("V-01: mensagem traz o teto ('" + mensagemDe "V-01" + "')") ((findString (mensagemDe "V-01") "teto") != undefined)
        -- Pergunta antes da rodada (cena de teste nunca salva). #yes salvaria a
        -- cena da sessão: fica para o teste manual.
        if maxFileName == "" do
        (
            checar "Salvar antes: 'Não' segue sem salvar" (InLab_SalvarAntesDeVerificar resposta:#no)
            checar "Salvar antes: 'Cancelar' não roda" (not (InLab_SalvarAntesDeVerificar resposta:#cancel))
            checar "Salvar antes: nada foi salvo" (maxFileName == "")
        )

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

        ---------------------------------------------------------------- V-20
        -- 02/10/2026 (issue #36): os nomes válidos saem do produto importado
        -- (.max = cod_est; objeto = mesh_final; material = material_id).
        -- Com produto importado a V-20 é CRÍTICA (reprova); sem produto, aviso.
        limparCena()
        local jsV20 = "{\"produtos\": [" +
            "{\"cod_est\": \"0020\", \"nome\": \"MESA\", \"bloco_3d\": {\"papel\": \"master\", \"base_codest\": \"0020\"}, \"partes\": [" +
            "{\"nome_parte\": \"Tampo\", \"qualificador\": \"\", \"tipo\": \"P\", \"so3d\": false, \"material_id\": \"ART_P_Tampo\", \"mesh_final\": \"0020\"}, " +
            "{\"nome_parte\": \"Prato\", \"qualificador\": \"\", \"tipo\": \"P\", \"so3d\": false, \"material_id\": \"ART_P_Prato\", \"mesh_final\": \"0020|0020_Prato\"}, " +
            "{\"nome_parte\": \"Prato_1\", \"qualificador\": \"\", \"tipo\": \"\", \"so3d\": true, \"subparte_de\": \"Prato\", \"material_id\": \"ART_Prato_1\", \"mesh_final\": \"0020_Prato\"}]}, " +
            "{\"cod_est\": \"0021\", \"nome\": \"COPIA\", \"bloco_3d\": {\"papel\": \"copia\", \"base_codest\": \"0020\"}, \"partes\": [" +
            "{\"nome_parte\": \"Tampo\", \"qualificador\": \"\", \"tipo\": \"P\", \"so3d\": false, \"material_id\": \"ART_P_Tampo\", \"mesh_final\": \"0021\"}]}, " +
            "{\"cod_est\": \"0022\", \"nome\": \"SEM MESH\", \"partes\": [" +
            "{\"nome_parte\": \"Base\", \"qualificador\": \"\", \"tipo\": \"P\", \"so3d\": false, \"material_id\": \"ART_P_Base\", \"mesh_final\": \"\"}]}, " +
            "{\"cod_est\": \"0023\", \"nome\": \"VARIANTES\", \"glb_multiplos\": {\"qtd\": 2, \"variantes\": [{\"acab_id\": \"L11\", \"glb\": \"0023_L11\", \"mesh_final\": \"0023_L11\"}, " +
            "{\"acab_id\": \"L12\", \"glb\": \"0023_L12\", \"mesh_final\": \"0023_L12\"}]}, \"partes\": [" +
            "{\"nome_parte\": \"Tampo\", \"qualificador\": \"\", \"tipo\": \"P\", \"so3d\": false, \"material_id\": \"ART_P_Tampo\", \"mesh_final\": \"0023\"}]}]}"
        local prodsV20 = InLab_Produto_Lista (InLab_ParseJSON jsV20)
        local mTampoV = StandardMaterial name:"ART_P_Tampo"
        local mPratoV = StandardMaterial name:"ART_P_Prato"
        local oMesa = Box name:"0020" material:mTampoV
        local oPrato = Box name:"0020_Prato" material:mPratoV pos:[60, 0, 0]
        fn rodar20 cfg p objs arq = ( InLab_ResetarResultados(); InLab_V20_Nomenclatura cfg produto:p objetos:objs nomeArquivo:arq; statusDe "V-20" )
        checar "V-20: sem produto importado fica em advertência e pede o produto" ((rodar20 cfgEst undefined #(oMesa) "0020") == #warning and (findString (mensagemDe "V-20") "seção Produto") != undefined)
        checar ("V-20: arquivo, objetos e materiais com os nomes do produto passa (" + mensagemDe "V-20" + ")") ((rodar20 cfgEst prodsV20[1] #(oMesa, oPrato) "0020") == #pass)
        checar "V-20: arquivo com outro nome reprova" ((rodar20 cfgEst prodsV20[1] #(oMesa, oPrato) "mesa_final_v3") == #fail and (findString (mensagemDe "V-20") "mesa_final_v3") != undefined)
        checar "V-20: cena não salva reprova" ((rodar20 cfgEst prodsV20[1] #(oMesa, oPrato) "") == #fail)
        checar "V-20: nome errado reprova o produto (crítica)" (not (InLab_AprovacaoFinal()))
        oPrato.name = "prato solto"
        checar "V-20: objeto fora dos nomes do produto é citado" ((rodar20 cfgEst prodsV20[1] #(oMesa, oPrato) "0020") == #fail and (findString (mensagemDe "V-20") "prato solto") != undefined)
        oPrato.name = "0020_Prato"
        mPratoV.name = "ART_Prato_1"
        checar "V-20: material com o material_id da subparte so3d não vale (é o da parte-mãe)" ((rodar20 cfgEst prodsV20[1] #(oMesa, oPrato) "0020") == #fail and (findString (mensagemDe "V-20") "ART_Prato_1") != undefined)
        mPratoV.name = "art_p_prato"
        checar "V-20: nome de material diferencia maiúscula de minúscula" ((rodar20 cfgEst prodsV20[1] #(oMesa, oPrato) "0020") == #fail)
        mPratoV.name = "ART_P_Prato"
        oMesa.name = "0021"
        checar "V-20: cópia aceita o .max com o código do master" ((rodar20 cfgEst prodsV20[2] #(oMesa) "0020") == #pass)
        checar "V-20: cópia aceita o .max com o próprio código" ((rodar20 cfgEst prodsV20[2] #(oMesa) "0021") == #pass)
        checar "V-20: produto sem mesh_final no JSON reprova" ((rodar20 cfgEst prodsV20[3] #(oMesa) "0022") == #fail and (findString (mensagemDe "V-20") "mesh_final") != undefined)
        -- Variante de posição (issue #92): .max e objeto = codEst_id
        oMesa.name = "0023_L11"
        checar ("V-20: variante — arquivo e objeto com o nome da variante passam (" + mensagemDe "V-20" + ")") ((rodar20 cfgEst prodsV20[4] #(oMesa) "0023_L11") == #pass)
        checar "V-20: variante — objeto com o nome de OUTRA variante reprova" ((rodar20 cfgEst prodsV20[4] #(oMesa) "0023_L12") == #fail and (findString (mensagemDe "V-20") "0023_L12") != undefined)
        checar "V-20: variante — arquivo com variante inexistente reprova" ((rodar20 cfgEst prodsV20[4] #(oMesa) "0023_L99") == #fail)
        oMesa.name = "0020"
        InLab_RodarVerificacoes cfgEst produto:prodsV20[1]
        checar "V-20: o orquestrador repassa o produto (mensagem cita o código)" ((findString (mensagemDe "V-20") "0020") != undefined)
        limparCena()

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
