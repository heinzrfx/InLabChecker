/*
 tests\test_reload.ms — teste automatico do InLab_RecarregarPlugin (InLabChecker.ms, issue #52)
 RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt): carrega o plugin INTEIRO (fileIn
 de InLabChecker.ms, igual "Scripting > Run Script"), abre e fecha a UI de verdade.
 AUTOCONTIDO (24/Set/2026): o proprio teste cria functions\_teste_reload_quebrado.ms
 (fora do manifesto, com erro de sintaxe de proposito) antes do reload que precisa
 dele, e apaga o arquivo no final — em todo caminho, inclusive apos excecao no catch.
 A restricao de safe_mode do MCP (createFile/copyFile bloqueados) vale so pra codigo
 enviado direto por execute_maxscript; um teste carregado por fileIn pode usar
 createFile/deleteFile normalmente (este arquivo ja usa createFile pra sua saida).
 Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_reload.txt (PASS/FAIL por item).
*/
global INLAB_ROOT, INLAB_MODULOS, InLab_RecarregarPlugin, InLab_AbrirUI
global InLabChecker_Rollout, InLab_Log
global INLAB_RELOAD_MOSTRAR_MSGBOX, InLab_UltimoErroReload
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_reload.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local moduloQuebrado = @"functions\_teste_reload_quebrado.ms"
    local caminhoQuebrado = raiz + moduloQuebrado
    local modulosOriginais = undefined

    try
    (
        -- Cria o modulo quebrado (fora do manifesto, erro de sintaxe de proposito)
        -- ANTES do reload que precisa dele. Apagado no bloco de limpeza no final,
        -- em todo caminho (sucesso ou catch).
        local arqQuebrado = createFile caminhoQuebrado
        format "-- modulo de teste com erro de sintaxe de proposito, criado por tests\\test_reload.ms\n" to:arqQuebrado
        format "fn _testeReloadQuebrado a b = ( a + )\n" to:arqQuebrado
        close arqQuebrado
        checar "Arquivo quebrado de teste foi criado" (doesFileExist caminhoQuebrado)

        -- Carga real do plugin, igual "Scripting > Run Script" (CLAUDE.md).
        -- getSourceFileName() dentro de InLabChecker.ms resolve pra este fileIn.
        fileIn (raiz + @"InLabChecker.ms")

        -- Troca o logger DEPOIS da carga real (senao o proprio InLabChecker.ms
        -- redefine InLab_Log por cima ao carregar core\log.ms).
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )

        checar "Plugin carregou: INLAB_MODULOS existe" (INLAB_MODULOS != undefined and INLAB_MODULOS.count > 0)
        checar "Plugin carregou: InLabChecker_Rollout existe" (InLabChecker_Rollout != undefined)
        checar "INLAB_RELOAD_MOSTRAR_MSGBOX comeca true (default)" (INLAB_RELOAD_MOSTRAR_MSGBOX == true)

        modulosOriginais = for m in INLAB_MODULOS collect m

        -- 1. RELOAD LIMPO (sem forcar erro) — sanidade da funcao em si.
        INLAB_RELOAD_MOSTRAR_MSGBOX = false -- nunca deixa o messageBox abrir num teste automatizado
        InLab_UltimoErroReload = undefined
        local ok1 = InLab_RecarregarPlugin()
        checar "Reload limpo retorna true" (ok1 == true)
        checar "Reload limpo nao seta InLab_UltimoErroReload" (InLab_UltimoErroReload == undefined)

        -- 2. RELOAD COM MODULO QUEBRADO — o cerne da issue #52: o erro REAL
        -- (getCurrentException) tem que aparecer, nao so "falha em <modulo>".
        local novoModulos = for m in modulosOriginais collect m
        append novoModulos moduloQuebrado
        INLAB_MODULOS = novoModulos
        InLab_UltimoErroReload = undefined
        local ok2 = InLab_RecarregarPlugin()
        checar "Reload com modulo quebrado retorna false" (ok2 == false)
        checar "InLab_UltimoErroReload preenchido" (InLab_UltimoErroReload != undefined and InLab_UltimoErroReload != "")
        if InLab_UltimoErroReload != undefined do
        (
            linha ("      InLab_UltimoErroReload = " + InLab_UltimoErroReload)
            checar "Mensagem cita o modulo quebrado" ((findString InLab_UltimoErroReload "_teste_reload_quebrado.ms") != undefined)
            local prefixoSemErro = "InLabChecker Reload — falha em " + moduloQuebrado + ":\n"
            checar "Mensagem tem texto do erro real (alem do nome do modulo)" (InLab_UltimoErroReload.count > prefixoSemErro.count)
        )

        -- 3. RESTAURA a lista de modulos e recarrega limpo, deixando o plugin
        -- num estado normal pro resto da sessao do Max.
        INLAB_MODULOS = modulosOriginais
        InLab_UltimoErroReload = undefined
        local ok3 = InLab_RecarregarPlugin()
        checar "Reload de limpeza (restaurado) retorna true" (ok3 == true)
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCECAO: " + getCurrentException())
        -- Garante que INLAB_MODULOS nao fica quebrado se o teste explodir no meio.
        if modulosOriginais != undefined do INLAB_MODULOS = modulosOriginais
    )

    -- Nunca deixa o painel aberto nem o messageBox desligado pro resto da sessao.
    try ( destroyDialog InLabChecker_Rollout ) catch()
    INLAB_RELOAD_MOSTRAR_MSGBOX = true

    -- Apaga o modulo quebrado em TODO caminho (sucesso ou apos excecao no catch),
    -- pra nao deixar lixo fora do manifesto no disco (CLAUDE.md: arquivo fora do
    -- manifesto nao carrega, mas nao deve sobrar de um teste).
    try
    (
        if doesFileExist caminhoQuebrado do
        (
            deleteFile caminhoQuebrado
            checar "Arquivo quebrado de teste foi apagado no final" (not (doesFileExist caminhoQuebrado))
        )
    )
    catch ( linha ("EXCECAO ao apagar modulo quebrado: " + getCurrentException()) )

    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluido — %\n" arqSaida
)
