/*
 tests\test_verif_mapeamento.ms — teste do grupo 5 de verificações (issue #101)
 Spec: docs\superpowers\specs\2026-10-05-verif-uv-grupo5-design.md
 RODAR NUMA CENA VAZIA (File > New): cria e apaga os objetos de cada caso.
 Resultado: <pasta temp do Max>\inlab_test_verif_mapeamento.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_VerifResults, InLab_ResetarResultados
global InLab_V14_UVPresente, InLab_V15_UVBake, InLab_V16_ResolucaoTexturas, InLab_CheckTexture
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
