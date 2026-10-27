/*
 tests\test_mapear_cortar.ms — teste de functions\fn_mapear_cortar.ms (Mapear assistido).
 RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear_cortar.txt (PASS/FAIL por item).
 27/10/2026 (Tarefa 2): marcas guardadas na peça (costuras e guias).
*/
global InLab_Log, InLab_EhGeometria, InLab_Mapear_PolyDe
global InLab_Cortar_LerMarcas, InLab_Cortar_GravarMarcas, InLab_Cortar_ApagarMarcas, InLab_Cortar_TemMarcas
global InLab_CortarMarcas
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\inlab_test_mapear_cortar.txt"
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
    local nomeCx = "TESTE_cr_caixa"
    try
    (
        fileIn (raiz + @"core\utils.ms")
        fileIn (raiz + @"functions\fn_json.ms")
        fileIn (raiz + @"functions\fn_renomear_produto.ms")
        fileIn (raiz + @"functions\fn_autouv.ms")
        fileIn (raiz + @"functions\fn_realworldfix.ms")
        fileIn (raiz + @"functions\fn_mapear_classe.ms")
        fileIn (raiz + @"functions\fn_mapear_medir.ms")
        fileIn (raiz + @"functions\fn_mapear_gerar.ms")
        fileIn (raiz + @"functions\fn_mapear.ms")
        fileIn (raiz + @"functions\fn_ver_uv.ms")
        fileIn (raiz + @"functions\fn_mapear_paineis.ms")
        fileIn (raiz + @"functions\fn_mapear_cortar.ms")

        local cx = ChamferBox length:100 width:100 height:20 fillet:5 fillet_segments:3 name:nomeCx
        convertToPoly cx
        checar "marcas: sem marca devolve undefined" ((InLab_Cortar_LerMarcas cx) == undefined)

        local mm = InLab_CortarMarcas nFaces:0 nArestas:0 costuras:#{1,5,9} guias:#(#(12, 45.0))
        InLab_Cortar_GravarMarcas cx mm
        local m = InLab_Cortar_LerMarcas cx
        checar "marcas: ida e volta" (m != undefined and m.costuras as string == "#{1, 5, 9}" and m.guias[1][1] == 12 and m.guias[1][2] == 45.0)
        checar "marcas: TemMarcas verdadeiro" (InLab_Cortar_TemMarcas cx)
        linha ("      guias gravadas: " + (getAppData cx 7302))

        holdMaxFile()
        fetchMaxFile quiet:true
        cx = getNodeByName nomeCx
        local m2 = if cx != undefined then InLab_Cortar_LerMarcas cx else undefined
        checar "marcas: sobrevive ao salvar e reabrir" (m2 != undefined and m2.costuras as string == "#{1, 5, 9}" and m2.guias[1][1] == 12 and m2.guias[1][2] == 45.0)

        logs.count = 0
        polyop.deleteFaces cx.baseobject #{1}
        local r = InLab_Cortar_LerMarcas cx
        checar "marcas: topologia mudada descarta com #warn" (r == undefined and temLog logs #warn "a malha mudou" "" and not (InLab_Cortar_TemMarcas cx))
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    local sobra = getNodeByName nomeCx
    if sobra != undefined do try ( delete sobra ) catch ()
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
