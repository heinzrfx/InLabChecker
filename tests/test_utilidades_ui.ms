/*
 tests\test_utilidades_ui.ms — botões e campos das Utilidades Rápidas
 (InLab_Util_Montar / InLab_Util_Acao, ui\rollout_main.ms, 03/11/2026).
 Os botões são dotNet filhos das peças do fundo (botão nativo por cima de
 um Panel sumia da tela); os campos Bump/canal são spinners nativos ENTRE as
 peças (INLAB_UTIL_PECAS). Monta num Panel solto e nas 6 peças, sem abrir o
 painel, e clica de verdade (PerformClick) com as ações trocadas por stubs.
 O spinner nativo não existe fora de rollout: aqui é um struct com .value.
 Carrega os módulos na ordem do manifesto (INLAB_MODULOS lido do
 InLabChecker.ms), até ui\rollout_main.ms, sem chamar InLab_AbrirUI.
 RODAR NUMA CENA VAZIA (cria e apaga uma Box).
 Resultado: <pasta temp do Max>\inlab_test_utilidades_ui.txt
*/
global InLab_Log, INLAB_ROOT
global InLab_Util_Montar, InLab_Util_Acao, InLab_Util_ValorCampo, INLAB_UTIL_PECAS
global InLab_Util_SpnBump, InLab_Util_SpnCanal, InLab_Util_BtnFind, InLab_Util_Dica, InLab_UVWClear_Desfazer
global InLab_FindObjectsPesados, InLab_BumpFix, InLab_UVWClear, InLab_ResetXFormSelecao
global INLAB_UVWCLEAR_CANAL_PADRAO
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS, INLAB_TESTE_CHAMADAS, INLAB_TESTE_ERROS
struct TesteSpinner ( value = 0 )
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

        -- MONTAGEM num Panel só, do tamanho do grupo
        local spnB = TesteSpinner value:0.3
        local spnC = TesteSpinner value:INLAB_UVWCLEAR_CANAL_PADRAO
        InLab_Util_SpnBump = spnB
        InLab_Util_SpnCanal = spnC
        local pnl = dotNetObject "System.Windows.Forms.Panel"
        pnl.Size = dotNetObject "System.Drawing.Size" 438 124
        InLab_Util_Montar #(#(pnl, 0, 0))
        checar "11 botões (com o ↶ Desfazer do UVW Clear)" ((contar pnl "Button") == 11)
        checar "7 rótulos (título, 4 linhas, Bump, canal; o limite saiu do topo)" ((contar pnl "Label") == 7)
        local total = pnl.Controls.Count
        InLab_Util_Montar #(#(pnl, 0, 0))
        checar "Montar 2x não duplica" (pnl.Controls.Count == total)

        -- PEÇAS DO FUNDO: não se sobrepõem e cobrem o grupo todo menos os
        -- dois spinners (x 301..346, y 74..90 e 99..115).
        fn dentro pc x y = (x >= pc[2] and x < pc[2] + pc[4] and y >= pc[3] and y < pc[3] + pc[5])
        local sobra = 0
        local dupla = 0
        for x = 0 to 437 do for y = 0 to 123 do
        (
            local n = 0
            for pc in INLAB_UTIL_PECAS where dentro pc x y do n += 1
            local spin = x >= 301 and x < 346 and ((y >= 74 and y < 90) or (y >= 99 and y < 115))
            if n > 1 do dupla += 1
            if spin and n > 0 do dupla += 1
            if not spin and n == 0 do sobra += 1
        )
        checar "Peças não se sobrepõem nem cobrem os spinners" (dupla == 0)
        checar ("Peças cobrem o grupo todo fora dos spinners (" + sobra as string + " px de buraco)") (sobra == 0)

        -- Montar nas 6 peças de verdade: todo controle cabe numa peça.
        INLAB_TESTE_ERROS = 0
        local logAntes = InLab_Log
        InLab_Log = fn _logConta msg tipo:#info = ( if tipo == #err do INLAB_TESTE_ERROS += 1 )
        local pecas = for pc in INLAB_UTIL_PECAS collect
        (
            local pp = dotNetObject "System.Windows.Forms.Panel"
            pp.Size = dotNetObject "System.Drawing.Size" pc[4] pc[5]
            #(pp, pc[2], pc[3])
        )
        InLab_Util_Montar pecas
        InLab_Log = logAntes
        local nCtrl = 0
        for pc in pecas do nCtrl += pc[1].Controls.Count
        checar "Nas 6 peças: todo botão e rótulo cabe numa peça (nenhum #err)" (INLAB_TESTE_ERROS == 0)
        checar "Nas 6 peças: os 18 controles foram distribuídos" (nCtrl == 18)
        InLab_Util_Montar #(#(pnl, 0, 0))

        checar "Limite do Find Objects vai na dica do botão" (InLab_Util_BtnFind != undefined and matchPattern (InLab_Util_Dica.GetToolTip InLab_Util_BtnFind) pattern:"*objetos*")
        checar "Todos os controles cabem no Panel (438x124)" (
            (for i = 0 to pnl.Controls.Count - 1 where (pnl.Controls.Item[i]).Right > 438 or (pnl.Controls.Item[i]).Bottom > 124 collect i).count == 0)

        -- CLIQUE DE VERDADE (PerformClick) com stubs
        originais = #(InLab_FindObjectsPesados, InLab_BumpFix, InLab_UVWClear, InLab_ResetXFormSelecao, InLab_UVWClear_Desfazer)
        INLAB_TESTE_CHAMADAS = #()
        InLab_FindObjectsPesados = fn _stubFind objs:undefined = ( append INLAB_TESTE_CHAMADAS #(#find); 0 )
        InLab_BumpFix = fn _stubBump v = ( append INLAB_TESTE_CHAMADAS #(#bump, v); 0 )
        InLab_UVWClear = fn _stubUVW objs canal = ( append INLAB_TESTE_CHAMADAS #(#uvw, objs.count, canal); 0 )
        InLab_ResetXFormSelecao = fn _stubRX objs = ( append INLAB_TESTE_CHAMADAS #(#resetx, objs.count); 0 )
        InLab_UVWClear_Desfazer = fn _stubDesf = ( append INLAB_TESTE_CHAMADAS #(#uvwdesf); 0 )

        (botao pnl "find").PerformClick()
        checar "Find Objects chama InLab_FindObjectsPesados" (INLAB_TESTE_CHAMADAS.count == 1 and INLAB_TESTE_CHAMADAS[1][1] == #find)

        spnB.value = 1.25
        (botao pnl "bumpfix").PerformClick()
        local ult = INLAB_TESTE_CHAMADAS[INLAB_TESTE_CHAMADAS.count]
        checar "Bump Fix passa o valor do campo (1,25)" (ult[1] == #bump and (abs (ult[2] - 1.25)) < 0.001)

        clearSelection()
        local n0 = INLAB_TESTE_CHAMADAS.count
        (botao pnl "uvwclear").PerformClick()
        checar "UVW Clear sem seleção não chama nada" (INLAB_TESTE_CHAMADAS.count == n0)

        caixa = Box()
        select caixa
        spnC.value = 4
        (botao pnl "uvwclear").PerformClick()
        ult = INLAB_TESTE_CHAMADAS[INLAB_TESTE_CHAMADAS.count]
        checar "UVW Clear passa a seleção e o canal do campo (4)" (ult[1] == #uvw and ult[2] == 1 and ult[3] == 4)

        (botao pnl "resetx").PerformClick()
        ult = INLAB_TESTE_CHAMADAS[INLAB_TESTE_CHAMADAS.count]
        checar "Reset XForm passa a seleção" (ult[1] == #resetx and ult[2] == 1)

        (botao pnl "uvwdesf").PerformClick()
        ult = INLAB_TESTE_CHAMADAS[INLAB_TESTE_CHAMADAS.count]
        checar "↶ Desfazer chama InLab_UVWClear_Desfazer" (ult[1] == #uvwdesf)

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

    if originais.count == 5 do
    (
        InLab_UVWClear_Desfazer = originais[5]
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
