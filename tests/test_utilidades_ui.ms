/*
 tests\test_utilidades_ui.ms — botões e campos das Utilidades Rápidas
 (InLab_Util_Montar / InLab_Util_Acao, ui\rollout_main.ms, 03/11/2026).
 Os botões são dotNet filhos de um Panel (botão nativo por cima do Panel
 sumia da tela). Monta num Panel solto, sem abrir o painel, e clica de
 verdade (PerformClick) com as funções das ações trocadas por stubs.
 Carrega os módulos na ordem do manifesto (INLAB_MODULOS lido do
 InLabChecker.ms), até ui\rollout_main.ms, sem chamar InLab_AbrirUI.
 RODAR NUMA CENA VAZIA (cria e apaga uma Box).
 Resultado: <pasta temp do Max>\inlab_test_utilidades_ui.txt
*/
global InLab_Log, INLAB_ROOT
global InLab_Util_Montar, InLab_Util_Acao, InLab_Util_ValorCampo, InLab_Util_DefinirCampo, InLab_Util_OnSeta
global InLab_Util_SpnBump, InLab_Util_SpnCanal, InLab_Util_LblLimite
global InLab_FindObjectsPesados, InLab_BumpFix, InLab_UVWClear, InLab_ResetXFormSelecao
global INLAB_UVWCLEAR_CANAL_PADRAO
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS, INLAB_TESTE_CHAMADAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_utilidades_ui.txt"
    INLAB_TESTE_SAIDA = openFile arqSaida mode:"wt"
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn botao pnl tag =
    (
        local achado = undefined
        for i = 0 to pnl.Controls.Count - 1 where (pnl.Controls.Item[i]).Tag == tag do achado = pnl.Controls.Item[i]
        achado
    )
    fn contar pnl tipo =
    (
        local n = 0
        for i = 0 to pnl.Controls.Count - 1 where ((pnl.Controls.Item[i]).GetType()).Name == tipo do n += 1
        n
    )

    local logOriginal = InLab_Log
    local originais = #()
    local caixa = undefined
    try
    (
        -- Manifesto lido do entry point: a lista fica num lugar só.
        local texto = (dotNetClass "System.IO.File").ReadAllText (raiz + "InLabChecker.ms")
        local ini = findString texto "INLAB_MODULOS = #("
        local bloco = substring texto ini (texto.count - ini)
        bloco = substring bloco 1 (findString bloco "ui\\rollout_main.ms\"")
        local mods = #()
        local rx = dotNetObject "System.Text.RegularExpressions.Regex" "@\"([^\"]+\\.ms)\""
        local ms = rx.Matches bloco
        for i = 0 to ms.Count - 1 do append mods ((ms.Item[i]).Groups.Item[1]).Value
        append mods @"ui\rollout_main.ms"
        checar ("Manifesto lido (" + mods.count as string + " módulos até o rollout_main)") (mods.count > 30)
        INLAB_ROOT = raiz
        for m in mods do fileIn (raiz + m)
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )

        -- MONTAGEM
        local pnl = dotNetObject "System.Windows.Forms.Panel"
        pnl.Size = dotNetObject "System.Drawing.Size" 438 124
        InLab_Util_Montar pnl
        checar "10 botões" ((contar pnl "Button") == 10)
        checar "2 campos numéricos (caixa com texto e setas)" ((contar pnl "Panel") == 2)
        checar "8 rótulos (título, limite, 4 linhas, Bump, canal)" ((contar pnl "Label") == 8)
        local total = pnl.Controls.Count
        InLab_Util_Montar pnl
        checar "Montar 2x não duplica" (pnl.Controls.Count == total)
        checar "Bump abre em 0,3" ((abs ((InLab_Util_ValorCampo InLab_Util_SpnBump) - 0.3)) < 0.001)
        checar "Canal abre no padrão" ((InLab_Util_ValorCampo InLab_Util_SpnCanal) == INLAB_UVWCLEAR_CANAL_PADRAO)
        checar "Canal aparece sem casas decimais" (InLab_Util_SpnCanal.Text == (INLAB_UVWCLEAR_CANAL_PADRAO as string))

        -- CAMPO: setas, faixa e texto digitado
        fn seta tb sinal =
        (
            local caixaCampo = tb.Parent
            local alvo = undefined
            for i = 0 to caixaCampo.Controls.Count - 1 where (caixaCampo.Controls.Item[i]).Tag == ((tb.Tag as string) + sinal) do alvo = caixaCampo.Controls.Item[i]
            InLab_Util_OnSeta alvo undefined
        )
        seta InLab_Util_SpnBump "+"
        checar "Seta ▴ soma o passo (0,30 → 0,35)" ((abs ((InLab_Util_ValorCampo InLab_Util_SpnBump) - 0.35)) < 0.001)
        seta InLab_Util_SpnBump "-"
        seta InLab_Util_SpnBump "-"
        checar "Seta ▾ tira o passo (0,35 → 0,25)" ((abs ((InLab_Util_ValorCampo InLab_Util_SpnBump) - 0.25)) < 0.001)
        InLab_Util_DefinirCampo InLab_Util_SpnBump 9
        checar "Acima do máximo fica no máximo (5)" ((InLab_Util_ValorCampo InLab_Util_SpnBump) == 5.0)
        InLab_Util_DefinirCampo InLab_Util_SpnCanal 0
        seta InLab_Util_SpnCanal "-"
        checar "Abaixo do mínimo fica no mínimo (canal 1)" ((InLab_Util_ValorCampo InLab_Util_SpnCanal) == 1.0)
        InLab_Util_SpnBump.Text = "0.8"
        checar "Aceita ponto" ((abs ((InLab_Util_ValorCampo InLab_Util_SpnBump) - 0.8)) < 0.001)
        InLab_Util_SpnBump.Text = "1,5"
        checar "Aceita vírgula" ((abs ((InLab_Util_ValorCampo InLab_Util_SpnBump) - 1.5)) < 0.001)
        InLab_Util_DefinirCampo InLab_Util_SpnBump 0.6
        InLab_Util_SpnBump.Text = "abc"
        checar "Texto inválido volta ao último válido (0,6)" ((abs ((InLab_Util_ValorCampo InLab_Util_SpnBump) - 0.6)) < 0.001)
        InLab_Util_DefinirCampo InLab_Util_SpnBump 0.3
        InLab_Util_DefinirCampo InLab_Util_SpnCanal INLAB_UVWCLEAR_CANAL_PADRAO
        checar "Rótulo do limite existe" (InLab_Util_LblLimite != undefined)
        checar "Todos os controles cabem no Panel (438x124)" (
            (for i = 0 to pnl.Controls.Count - 1 where (pnl.Controls.Item[i]).Right > 438 or (pnl.Controls.Item[i]).Bottom > 124 collect i).count == 0)

        -- CLIQUE DE VERDADE (PerformClick) com stubs
        originais = #(InLab_FindObjectsPesados, InLab_BumpFix, InLab_UVWClear, InLab_ResetXFormSelecao)
        INLAB_TESTE_CHAMADAS = #()
        InLab_FindObjectsPesados = fn _stubFind objs:undefined = ( append INLAB_TESTE_CHAMADAS #(#find); 0 )
        InLab_BumpFix = fn _stubBump v = ( append INLAB_TESTE_CHAMADAS #(#bump, v); 0 )
        InLab_UVWClear = fn _stubUVW objs canal = ( append INLAB_TESTE_CHAMADAS #(#uvw, objs.count, canal); 0 )
        InLab_ResetXFormSelecao = fn _stubRX objs = ( append INLAB_TESTE_CHAMADAS #(#resetx, objs.count); 0 )

        (botao pnl "find").PerformClick()
        checar "Find Objects chama InLab_FindObjectsPesados" (INLAB_TESTE_CHAMADAS.count == 1 and INLAB_TESTE_CHAMADAS[1][1] == #find)

        InLab_Util_DefinirCampo InLab_Util_SpnBump 1.25
        (botao pnl "bumpfix").PerformClick()
        local ult = INLAB_TESTE_CHAMADAS[INLAB_TESTE_CHAMADAS.count]
        checar "Bump Fix passa o valor do campo (1,25)" (ult[1] == #bump and (abs (ult[2] - 1.25)) < 0.001)

        clearSelection()
        local n0 = INLAB_TESTE_CHAMADAS.count
        (botao pnl "uvwclear").PerformClick()
        checar "UVW Clear sem seleção não chama nada" (INLAB_TESTE_CHAMADAS.count == n0)

        caixa = Box()
        select caixa
        InLab_Util_DefinirCampo InLab_Util_SpnCanal 4
        (botao pnl "uvwclear").PerformClick()
        ult = INLAB_TESTE_CHAMADAS[INLAB_TESTE_CHAMADAS.count]
        checar "UVW Clear passa a seleção e o canal do campo (4)" (ult[1] == #uvw and ult[2] == 1 and ult[3] == 4)

        (botao pnl "resetx").PerformClick()
        ult = INLAB_TESTE_CHAMADAS[INLAB_TESTE_CHAMADAS.count]
        checar "Reset XForm passa a seleção" (ult[1] == #resetx and ult[2] == 1)

        -- Ação desconhecida não lança exceção (loga #err).
        local ok = true
        try ( InLab_Util_Acao #naoexiste ) catch ( ok = false )
        checar "Ação desconhecida não lança exceção" ok
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("FAIL  EXCEÇÃO: " + getCurrentException())
    )

    if originais.count == 4 do
    (
        InLab_FindObjectsPesados = originais[1]
        InLab_BumpFix = originais[2]
        InLab_UVWClear = originais[3]
        InLab_ResetXFormSelecao = originais[4]
    )
    try ( if caixa != undefined and isValidNode caixa do delete caixa ) catch ()
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
