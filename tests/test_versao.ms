/*
 tests\test_versao.ms — teste automatico de core\versao.ms (issue #9)
 RODAR NUMA CENA QUALQUER: nao cria nem apaga objeto de cena, nao toca rede.
 Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_versao.txt (PASS/FAIL por item).
*/
global INLAB_VERSAO, InLab_CompararVersao
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_versao.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    try
    (
        fileIn (raiz + @"core\versao.ms")

        -- 1. A CONSTANTE
        checar "INLAB_VERSAO e string" (classof INLAB_VERSAO == String)
        checar "INLAB_VERSAO nao tem 'v'" (INLAB_VERSAO.count > 0 and INLAB_VERSAO[1] != "v")
        checar "INLAB_VERSAO igual a ela mesma com 'v'" ((InLab_CompararVersao INLAB_VERSAO ("v" + INLAB_VERSAO)) == 0)

        -- 2. COMPARACAO NUMERICA (o caso que quebra com string)
        checar "0.9 < 0.10"         ((InLab_CompararVersao "0.9" "0.10") == -1)
        checar "0.10 > 0.9"         ((InLab_CompararVersao "0.10" "0.9") == 1)
        checar "0.13 == 0.13"       ((InLab_CompararVersao "0.13" "0.13") == 0)
        checar "v0.13 == 0.13"      ((InLab_CompararVersao "v0.13" "0.13") == 0)
        checar "V0.13 == 0.13"      ((InLab_CompararVersao "V0.13" "0.13") == 0)
        checar "1.0 > 0.99"         ((InLab_CompararVersao "1.0" "0.99") == 1)
        checar "INLAB_VERSAO < 99.0"((InLab_CompararVersao INLAB_VERSAO "99.0") == -1)

        -- 3. NUMERO DIFERENTE DE COMPONENTES
        local r = undefined
        try ( r = InLab_CompararVersao "1.2" "1.2.1" ) catch ( r = #excecao )
        checar "1.2 < 1.2.1 sem excecao" (r == -1)
        checar "1.2.1 > 1.2"        ((InLab_CompararVersao "1.2.1" "1.2") == 1)
        checar "1.2 == 1.2.0"       ((InLab_CompararVersao "1.2" "1.2.0") == 0)
        checar "Espaco nas pontas"  ((InLab_CompararVersao " v0.13 " "0.13") == 0)
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("FAIL  EXCECAO: " + getCurrentException())
    )

    linha ("---- " + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
)
