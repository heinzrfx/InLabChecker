/*
 tests\test_export_gltf.ms — teste automático de functions\fn_export_gltf.ms
 (issue #49 — modo "Cena inteira" e foco da janela do Real-Time Exporter)
 RODAR NUMA CENA VAZIA (File > New): cria 2 caixas e apaga no final. Abre e
 fecha a janela NATIVA do Real-Time Exporter (GameExporterOpenDialog/
 HideDialog) várias vezes — é modeless, então fecha por script sem travar o
 Max (confirmado na sondagem da issue #49). Scripting > Run Script... > este
 arquivo.
 Resultado: <pasta temp do Max>\inlab_test_export_gltf.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log
global InLab_AbrirExportadorRealTime, InLab_LocalizarJanelaExportadorRealTime
global InLab_FocarJanelaExportadorRealTime, InLab_ExportGLTF, InLab_ResolverExportadorGLTF
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_export_gltf.txt"
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
    local criados = #()

    try
    (
        fileIn (raiz + @"functions\fn_export_gltf.ms")

        local temGameExporter = (try (GameExporterShown(); true) catch (false))
        if not temGameExporter then
            linha "      Real-Time Exporter indisponível nesta build (Max < 2017) — pulando testes que dependem dele."
        else
        (
            -- garante estado limpo (nenhuma instância aberta de um teste anterior)
            try ( if GameExporterShown() do GameExporterHideDialog() ) catch()

            -- 1. LOCALIZAR / FOCAR SEM JANELA ABERTA
            checar "Localizar: undefined sem janela aberta" ((InLab_LocalizarJanelaExportadorRealTime()) == undefined)
            checar "Focar: false com hwnd undefined (sem exceção)" ((InLab_FocarJanelaExportadorRealTime undefined) == false)

            -- 2. CENA DE TESTE
            local b1 = Box name:"CaixaA" pos:[0,0,0]
            local b2 = Box name:"CaixaB" pos:[200,0,0]
            criados = #(b1, b2)

            -- 3. MODO "CENA INTEIRA" (somenteSelecao:false) — issue #49: tinha
            -- que limpar a seleção anterior antes de abrir a janela.
            select #(b1)
            checar "Pré-condição: 1 objeto selecionado antes de abrir" (selection.count == 1)
            local okCena = InLab_AbrirExportadorRealTime undefined somenteSelecao:false
            checar "Cena inteira: retorno true" (okCena == true)
            checar "Cena inteira: seleção anterior foi limpa" (selection.count == 0)
            checar "Cena inteira: GameExporterShown() true" (GameExporterShown() == true)

            local hwnd = InLab_LocalizarJanelaExportadorRealTime()
            checar "Cena inteira: janela localizada por HWND" (hwnd != undefined)
            if hwnd != undefined do
                checar "Cena inteira: foco confirmado (windows.getFocus() == hwnd)" ((InLab_FocarJanelaExportadorRealTime hwnd) == true)

            -- 3b. RAMO "JÁ ABERTA" — chamar de novo com a janela já aberta
            -- (o bug original só logava "trazida ao foco" sem focar de fato).
            local okJaAberta = InLab_AbrirExportadorRealTime undefined somenteSelecao:false
            checar "Já aberta: retorno true" (okJaAberta == true)
            checar "Já aberta: continua GameExporterShown() true" (GameExporterShown() == true)

            try ( GameExporterHideDialog() ) catch()
            checar "Cena inteira: janela fechada por script" (GameExporterShown() == false)
            checar "Depois de fechar: localizar volta undefined" ((InLab_LocalizarJanelaExportadorRealTime()) == undefined)

            -- 4. MODO "SOMENTE SELEÇÃO" (somenteSelecao:true) — não deve mudar,
            -- continua selecionando os objetos pedidos antes de abrir.
            clearSelection()
            local okSel = InLab_AbrirExportadorRealTime #(b2) somenteSelecao:true
            checar "Somente seleção: retorno true" (okSel == true)
            checar "Somente seleção: objeto certo selecionado" (selection.count == 1 and selection[1] == b2)
            checar "Somente seleção: GameExporterShown() true" (GameExporterShown() == true)

            try ( GameExporterHideDialog() ) catch()
            checar "Somente seleção: janela fechada por script" (GameExporterShown() == false)
        )
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    -- Segurança: garante que nenhuma instância da janela fica pendurada
    -- mesmo se um checar acima tiver disparado exceção no meio do teste.
    try ( if GameExporterShown() do GameExporterHideDialog() ) catch()

    for o in criados where isValidNode o do delete o
    clearSelection()
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
