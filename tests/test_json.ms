/*
 tests\test_json.ms — leitor de JSON (functions\fn_json.ms) em Max 2024 a 2027
 06/10/2026: Max 2025+ roda .NET 8+ e não tem JavaScriptSerializer
 (System.Web.Extensions); o leitor novo usa System.Text.Json.
 RODAR NUMA CENA VAZIA. Resultado: <pasta temp do Max>\inlab_test_json.txt
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_ParseJSON, InLab_JSON_Obter, INLAB_JSON_Leitor
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_json.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn quase a b = (a != undefined and b != undefined and (abs (a - b)) < 1e-9)

    local logOriginal = InLab_Log
    try
    (
        for m in #(@"core\log.ms", @"functions\fn_json.ms") do fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )

        local versaoMax = (maxVersion())[1]
        linha ("      Max " + versaoMax as string)

        ---------------------------------------------------------------- tipos
        local js = "{\"texto\": \"Cadeira São José\", \"aspas\": \"a\\\"b\\nc\", \"unicode\": \"\\u00e7\", " +
                   "\"inteiro\": 42, \"negativo\": -7, \"decimal\": 2.5, \"decNeg\": -0.125, \"expoente\": 1.5e3, " +
                   "\"grande\": 3000000000, \"sim\": true, \"nao\": false, \"nulo\": null, " +
                   "\"lista\": [1, \"dois\", [3], {\"k\": \"v\"}], \"vazio\": {}, \"listaVazia\": [], " +
                   "\"obj\": {\"interno\": {\"x\": 1}}}"
        local r = InLab_ParseJSON js
        checar ("Objeto vira array de pares (" + (classof r) as string + ")") (isKindOf r Array and r.count == 16 and isKindOf r[1] Array and r[1][1] == "texto")
        checar "Texto com acento" ((InLab_JSON_Obter r "texto") == "Cadeira São José")
        checar "Aspas e quebra de linha escapadas" ((InLab_JSON_Obter r "aspas") == "a\"b\nc")
        checar "Escape \\u00e7 vira ç" ((InLab_JSON_Obter r "unicode") == "ç")
        local i42 = InLab_JSON_Obter r "inteiro"
        checar ("Inteiro vira Integer (" + (classof i42) as string + ")") (i42 == 42 and (classof i42 == Integer or classof i42 == Integer64))
        checar "Inteiro negativo" ((InLab_JSON_Obter r "negativo") == -7)
        checar ("Decimal 2.5 sem truncar (" + (InLab_JSON_Obter r "decimal") as string + ")") (quase (InLab_JSON_Obter r "decimal") 2.5)
        checar "Decimal negativo -0.125" (quase (InLab_JSON_Obter r "decNeg") -0.125)
        checar "Expoente 1.5e3" (quase (InLab_JSON_Obter r "expoente") 1500.0)
        checar ("Inteiro acima de 2^31 (" + (InLab_JSON_Obter r "grande") as string + ")") ((InLab_JSON_Obter r "grande") as double == 3000000000.0)
        checar "true e false" ((InLab_JSON_Obter r "sim") == true and (InLab_JSON_Obter r "nao") == false)
        checar "null vira undefined" ((InLab_JSON_Obter r "nulo") == undefined)
        local lista = InLab_JSON_Obter r "lista"
        checar "Lista mista" (isKindOf lista Array and lista.count == 4 and lista[1] == 1 and lista[2] == "dois" and lista[3][1] == 3 and (InLab_JSON_Obter lista[4] "k") == "v")
        checar "Objeto e lista vazios" ((InLab_JSON_Obter r "vazio").count == 0 and (InLab_JSON_Obter r "listaVazia").count == 0)
        checar "Objeto aninhado" ((InLab_JSON_Obter (InLab_JSON_Obter (InLab_JSON_Obter r "obj") "interno") "x") == 1)
        checar "Raiz que é lista" ((InLab_ParseJSON "[1, 2, 3]") as string == "#(1, 2, 3)")

        ---------------------------------------------------------------- erros
        local mal = undefined
        local lancou = false
        try ( mal = InLab_ParseJSON "{\"a\": [1, 2" ) catch ( lancou = true )
        checar "JSON malformado devolve undefined sem exceção" (not lancou and mal == undefined)
        checar "Texto vazio devolve undefined" ((InLab_ParseJSON "") == undefined)

        ---------------------------------------------------------------- leitor
        local esperado = if versaoMax >= 27000 then #systemTextJson else #javaScriptSerializer
        checar ("Leitor nativo do .NET desta versão: " + INLAB_JSON_Leitor as string + " (esperado " + esperado as string + ")") (INLAB_JSON_Leitor == esperado)

        ---------------------------------------------------------------- dado real
        local arqReal = @"G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\produtos_teste_plugin_rafa_v5.json"
        if not (doesFileExist arqReal) then checar "JSON real — pulado: arquivo ausente" true
        else
        (
            local txt = (dotNetClass "System.IO.File").ReadAllText arqReal (dotNetClass "System.Text.Encoding").UTF8
            local t0 = timeStamp()
            local real = InLab_ParseJSON txt
            local seg = (timeStamp() - t0) / 1000.0
            local prods = InLab_JSON_Obter real "produtos"
            checar ("JSON real: " + (if prods == undefined then "0" else prods.count as string) + " produtos em " + seg as string + " s (abaixo de 30 s)") (prods != undefined and prods.count == 66 and seg < 30.0)
        )
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
