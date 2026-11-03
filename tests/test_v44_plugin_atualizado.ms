/*
 tests\test_v44_plugin_atualizado.ms — V-44, plugin na versão mais recente
 (verifications\verif_orquestrador.ms, 03/11/2026).
 Caso real: a mesa 00124145 foi verificada na v1.2.3, sem a V-43, e saiu
 aprovada com um Standardmaterial que vira o "fallback Material" no GLB.
 Não toca a rede: o estado do updater é um struct de teste em InLab_Update, e
 a preferência "ultimaVersaoRemota" volta ao que era no fim.
 Resultado: <pasta temp do Max>\inlab_test_v44_plugin_atualizado.txt
*/
global InLab_Log, INLAB_VERSAO, InLab_CompararVersao
global InLab_PrefLer, InLab_PrefGravar, InLab_PrefApagar
global InLab_ResetarResultados, InLab_VerifResults, InLab_AprovacaoFinal
global InLab_V44_PluginAtualizado, InLab_Update
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
struct TesteUpdateEstado ( versaoRemota = "", ignorada = false )
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_v44_plugin_atualizado.txt"
    INLAB_TESTE_SAIDA = openFile arqSaida mode:"wt"
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    -- Roda a V-44 sozinha e devolve o resultado.
    fn rodar instalada =
    (
        InLab_ResetarResultados()
        InLab_V44_PluginAtualizado versaoInstalada:instalada
        InLab_VerifResults[InLab_VerifResults.count]
    )

    local logOriginal = InLab_Log
    local updateOriginal = InLab_Update
    local ausente = "<ausente>"
    local prefAntes = ausente
    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"verifications\verif_orquestrador.ms") do
            fileIn (raiz + m)
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        prefAntes = InLab_PrefLer "ultimaVersaoRemota" ausente
        InLab_PrefApagar "ultimaVersaoRemota"

        -- 1. Nunca consultou: não dá para saber, só avisa.
        InLab_Update = TesteUpdateEstado()
        local r = rodar "1.3.8"
        checar "Sem consulta: advertência" (r.status == #warning)
        checar "Sem consulta: não é crítica (não reprova)" (not r.critico)

        -- 2. O caso da mesa: v1.2.3 instalada, GitHub com a 1.3.9.
        InLab_Update = TesteUpdateEstado versaoRemota:"1.3.9"
        r = rodar "1.2.3"
        checar "Desatualizado: reprova" (r.status == #fail)
        checar "Desatualizado: crítica" r.critico
        checar "Desatualizado: reprova o bloco" (not (InLab_AprovacaoFinal()))
        checar ("Desatualizado: mensagem cita as duas versões ('" + r.mensagem + "')") (matchPattern r.mensagem pattern:"*v1.2.3*v1.3.9*")

        -- 3. Versão nova ignorada pelo desenhista: reprova igual.
        InLab_Update = TesteUpdateEstado versaoRemota:"1.3.9" ignorada:true
        checar "Versão ignorada: reprova igual" ((rodar "1.3.8").status == #fail)

        -- 4. Na versão mais recente (e na frente dela, checkout de desenvolvimento).
        InLab_Update = TesteUpdateEstado versaoRemota:"1.3.8"
        checar "Mesma versão: passa" ((rodar "1.3.8").status == #pass)
        checar "Instalada na frente da release: passa" ((rodar "1.3.9").status == #pass)
        checar "Comparação numérica (1.3.10 > 1.3.9): passa" ((InLab_Update = TesteUpdateEstado versaoRemota:"1.3.9"; rodar "1.3.10").status == #pass)

        -- 5. Sessão sem consulta (intervalo de 4 h): vale a da última consulta.
        InLab_Update = TesteUpdateEstado()
        InLab_PrefGravar "ultimaVersaoRemota" "1.3.9"
        checar "Última consulta gravada, desatualizado: reprova" ((rodar "1.3.8").status == #fail)
        checar "Última consulta gravada, em dia: passa" ((rodar "1.3.9").status == #pass)

        -- 6. A consulta da sessão vale mais que a gravada.
        InLab_Update = TesteUpdateEstado versaoRemota:"1.4.0"
        checar "Consulta da sessão manda sobre a gravada" ((rodar "1.3.9").status == #fail)

        -- 7. Updater nem carregado (InLab_Update undefined): lê a gravada.
        InLab_Update = undefined
        checar "Sem InLab_Update: lê a gravada" ((rodar "1.3.8").status == #fail)
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("FAIL  EXCEÇÃO: " + getCurrentException())
    )

    try ( if prefAntes != ausente then InLab_PrefGravar "ultimaVersaoRemota" prefAntes else InLab_PrefApagar "ultimaVersaoRemota" ) catch ()
    InLab_Update = updateOriginal
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
