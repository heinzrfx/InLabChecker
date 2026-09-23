/*
 tests\test_prefs.ms — teste automatico de core\prefs.ms (issue #10)
 RODAR NUMA CENA QUALQUER: nao cria nem apaga objeto de cena, nao toca rede.
 Grava chaves "teste_*" no ini real ((getDir #plugcfg)\InLabChecker.ini) e
 apaga todas no final. Chaves de verdade (autoCheck etc.) nao sao tocadas.
 Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_prefs.txt (PASS/FAIL por item).
*/
global InLab_Log, INLAB_ROOT
global InLab_PrefLer, InLab_PrefGravar, InLab_PrefApagar, InLab_PrefArquivo
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_prefs.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    local chaves = #("teste_valor", "teste_nunca_gravada", "teste_vazio", "teste_numero")

    try
    (
        fileIn (raiz + @"core\prefs.ms")
        -- Estado limpo mesmo se um teste anterior morreu no meio.
        for c in chaves do InLab_PrefApagar c

        -- 1. LER ANTES DE GRAVAR (primeira execucao)
        local r = undefined
        try ( r = InLab_PrefLer "teste_nunca_gravada" "padrao_x" ) catch ( r = #excecao )
        checar "Ler chave inexistente nao lanca erro" (r != #excecao)
        checar "Chave inexistente devolve o padrao" (r == "padrao_x")
        checar "Padrao volta sem conversao" ((InLab_PrefLer "teste_nunca_gravada" true) == true)

        -- 2. GRAVA E LE DE VOLTA
        checar "Gravar devolve true" ((InLab_PrefGravar "teste_valor" "abc") == true)
        checar "Le de volta o valor gravado" ((InLab_PrefLer "teste_valor" "padrao") == "abc")
        InLab_PrefGravar "teste_valor" "def"
        checar "Regravar sobrescreve" ((InLab_PrefLer "teste_valor" "padrao") == "def")
        InLab_PrefGravar "teste_numero" 42
        checar "Nao-string e gravado como string" ((InLab_PrefLer "teste_numero" "") == "42")
        InLab_PrefGravar "teste_vazio" ""
        checar "Valor vazio gravado nao vira o padrao" ((InLab_PrefLer "teste_vazio" "padrao") == "")

        -- 3. O INI FICA FORA DA PASTA DO PLUGIN
        -- O updater renomeia INLAB_ROOT inteiro; o ini tem que estar fora.
        local arq = toLower (InLab_PrefArquivo())
        checar "Ini fica em #plugcfg" (matchPattern arq pattern:((toLower (getDir #plugcfg)) + "*"))
        checar "Ini NAO fica sob a raiz do plugin" (not (matchPattern arq pattern:((toLower raiz) + "*")))
        if INLAB_ROOT != undefined do
            checar "Ini NAO fica sob INLAB_ROOT" (not (matchPattern arq pattern:((toLower INLAB_ROOT) + "*")))

        -- 4. APAGAR
        checar "Apagar devolve true" ((InLab_PrefApagar "teste_valor") == true)
        checar "Depois de apagar volta o padrao" ((InLab_PrefLer "teste_valor" "padrao") == "padrao")
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("FAIL  EXCECAO: " + getCurrentException())
    )

    -- LIMPEZA
    for c in chaves do try ( InLab_PrefApagar c ) catch ()
    local sobrou = for c in chaves where (InLab_PrefLer c undefined) != undefined collect c
    checar "Nenhuma chave de teste sobrou no ini" (sobrou.count == 0)

    InLab_Log = logOriginal
    linha ("---- " + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
)
