/*
 tests\test_otim_nucleo.ms — teste automático do medidor da otimização
 Cobre functions\fn_otim_nucleo.ms: contagem de triângulos por nó e o texto
 com separador de milhar. 08/10/2026 (issue #126): saíram os casos de faixa,
 estado, pisos, registro de reversão e despachante dos 3 passos, que saíram
 do plugin.
 RODAR NUMA CENA VAZIA (File > New).
 Resultado: <pasta temp do Max>\inlab_test_otim_nucleo.txt (PASS/FAIL por item).
*/
global InLab_Log, InLab_Otim_Triangulos, InLab_Otim_Milhar
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_otim_nucleo.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn limparCena = ( delete (for o in objects collect o) )

    local logOriginal = InLab_Log

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms", @"functions\fn_otim_nucleo.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        limparCena()

        ---------------------------------------------------------------- CONTAGEM
        local b1 = Box()
        checar "Triângulos: Box padrão = 12" ((InLab_Otim_Triangulos #(b1)) == 12)
        local b2 = instance b1
        local ponto = Point()
        checar "Triângulos: instância conta por nó, helper não conta" ((InLab_Otim_Triangulos #(b1, b2, ponto)) == 24)

        ---------------------------------------------------------------- TEXTO
        checar "Milhar: 182340 -> 182.340" ((InLab_Otim_Milhar 182340) == "182.340")
        checar "Milhar: 999 -> 999" ((InLab_Otim_Milhar 999) == "999")
        checar "Milhar: 1000 -> 1.000" ((InLab_Otim_Milhar 1000) == "1.000")
        limparCena()
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    try ( limparCena() ) catch ()
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
