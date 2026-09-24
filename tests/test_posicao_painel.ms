/*
 tests\test_posicao_painel.ms — teste automatico da posicao lembrada do
 painel principal (ui\rollout_main.ms, issue #56)
 Cobre as 5 funcoes que substituem InLab_LadoPainel/InLab_PosicionarPainel:
   - InLab_PosicaoValida (pura): validacao de x,y contra areas inventadas,
     sem depender de monitor nenhum de verdade.
   - InLab_AreasDeTrabalho / InLab_PosicaoPainelPadrao: leem o(s) monitor(es)
     REAIS da maquina que roda o teste (Screen.AllScreens/PrimaryScreen) —
     so confere formato e coerencia, nao valores fixos.
   - InLab_PosicaoPainelLer: le/valida a preferencia gravada, com fallback
     pro padrao quando ausente/invalida/corrompida.
   - InLab_PosicaoPainelGravar: grava .pos de um rollout QUALQUER nas
     preferencias — testado com um rollout de mentirinha (createDialog
     proprio), sem abrir o InLabChecker_Rollout inteiro.
 Mexe na chave real "painelX"/"painelY" do ini e apaga no final (nao existia
 antes desta issue, entao nao ha valor anterior pra devolver).
 RODAR NUMA CENA QUALQUER: nao cria nem apaga objeto de cena.
 Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_posicao_painel.txt (PASS/FAIL por item).
*/
global InLab_Log, INLAB_ROOT, INLAB_VERSAO
global InLab_PrefLer, InLab_PrefGravar, InLab_PrefApagar
global InLab_PosicaoValida, InLab_AreasDeTrabalho, InLab_PosicaoPainelPadrao
global InLab_PosicaoPainelLer, InLab_PosicaoPainelGravar
global INLAB_PAINEL_LARGURA, INLAB_PAINEL_MARGEM_VISIVEL
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS

-- Rollout de mentirinha pra testar InLab_PosicaoPainelGravar sem abrir o
-- InLabChecker_Rollout inteiro (que arrasta header, familias, JSON etc.).
-- Definido no nivel superior do arquivo, igual InLabSplash em ui\splash.ms
-- — nao dentro do bloco do teste, pra nao depender de rollout aninhado
-- funcionar dentro de try().
rollout _rTesteFake "" width:100 height:60
(
    label lblFake "teste"
)

(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_posicao_painel.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    local aberto = false

    try
    (
        -- Carga na MESMA ordem de INLAB_MODULOS (InLabChecker.ms), ate
        -- ui\rollout_main.ms inclusive — sem chamar InLab_AbrirUI, entao o
        -- painel nunca abre de verdade. Reproduz a ordem real em vez de
        -- inventar uma lista menor: as secoes dentro de rollout_main.ms so
        -- resolvem os globais que usam quando um botao e apertado (nunca
        -- acontece aqui), mas a DEFINICAO do arquivo (titulo do rollout,
        -- itens literais de dropdown etc.) precisa de tudo que ele depende
        -- ja carregado, igual roda no Max de verdade.
        for m in #(
            @"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms",
            @"core\struct_familia.ms", @"core\log.ms", @"core\utils.ms",
            @"familias\familia_corpo_unico.ms", @"familias\familia_pernas_tampo.ms",
            @"familias\familia_estrutura_estofado.ms", @"familias\familia_estrutura_modular.ms",
            @"familias\familia_translacao.ms", @"familias\familia_rotacao.ms",
            @"familias\familia_giro_assento.ms", @"familias\familia_movimento_especial.ms",
            @"functions\fn_json.ms", @"functions\fn_updater.ms",
            @"functions\fn_renomear_produto.ms", @"functions\fn_prooptimizer.ms",
            @"functions\fn_otim_nucleo.ms", @"functions\fn_otim_origem.ms",
            @"functions\fn_otim_fino.ms", @"functions\fn_otim_escondidas.ms",
            @"functions\fn_realworldscale.ms", @"functions\fn_checktexture.ms",
            @"functions\fn_autouv.ms", @"functions\fn_realworldfix.ms",
            @"functions\fn_material_convert.ms", @"functions\fn_material_utils.ms",
            @"functions\fn_export_gltf.ms", @"functions\fn_utilidades.ms",
            @"verifications\verif_peso_poly.ms", @"verifications\verif_pivot.ms",
            @"verifications\verif_nomenclatura.ms", @"verifications\verif_geometria.ms",
            @"verifications\verif_animacao.ms", @"verifications\verif_uv.ms",
            @"report\report_generator.ms", @"verifications\verif_orquestrador.ms",
            @"ui\kit.ms") do
            fileIn (raiz + m)

        -- Depois dos fileIn: core\log.ms redefine InLab_Log. ui\header.ms
        -- le INLAB_ROOT pra achar a arte — fora do plugin, o teste define a
        -- raiz na mao (mesmo padrao de tests\test_kit_header.ms).
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        INLAB_ROOT = raiz
        for m in #(@"ui\header.ms", @"ui\splash.ms", @"ui\rollout_update.ms", @"ui\rollout_main.ms") do
            fileIn (raiz + m)

        -- Chave nova (issue #56): nao existe preferencia anterior real pra
        -- guardar/devolver, mas apaga antes por garantia (teste anterior
        -- morto no meio).
        InLab_PrefApagar "painelX"
        InLab_PrefApagar "painelY"

        -- 1. InLab_PosicaoValida — PURA, sem tocar o Max
        local areas1 = #(#(0, 0, 1920, 1080))
        checar "Ponto dentro da unica area e valido" (InLab_PosicaoValida 100 50 areas1)
        checar "Canto exato (0,0) e valido" (InLab_PosicaoValida 0 0 areas1)
        checar "X negativo (fora, a esquerda) e invalido" (not (InLab_PosicaoValida -50 50 areas1))
        checar "Y negativo (fora, acima) e invalido" (not (InLab_PosicaoValida 100 -10 areas1))
        checar "X alem da direita (sem folga) e invalido" (not (InLab_PosicaoValida 1900 50 areas1))
        checar "Y alem da base (sem folga) e invalido" (not (InLab_PosicaoValida 100 1060 areas1))
        checar "Falta a MARGEM_VISIVEL da borda e invalido" (not (InLab_PosicaoValida (1920 - INLAB_PAINEL_MARGEM_VISIVEL + 1) 50 areas1))
        checar "Exatamente a MARGEM_VISIVEL da borda e valido" (InLab_PosicaoValida (1920 - INLAB_PAINEL_MARGEM_VISIVEL) 50 areas1)

        -- Multiplos monitores (2 telas lado a lado — o caso do enunciado)
        local areas2 = #(#(0, 0, 1920, 1080), #(1920, 0, 3840, 1080))
        checar "Ponto no 2o monitor e valido com 2 monitores" (InLab_PosicaoValida 2000 100 areas2)
        checar "Ponto entre os 2 monitores (nenhum) e invalido" (not (InLab_PosicaoValida 1919 2000 areas2))

        -- Monitor desligado/removido: lista de areas vazia — nada e valido
        checar "Sem nenhum monitor, nada e valido" (not (InLab_PosicaoValida 100 100 #()))
        checar "x/y undefined e invalido, sem excecao" (not (InLab_PosicaoValida undefined undefined areas1))

        -- 2. InLab_AreasDeTrabalho / InLab_PosicaoPainelPadrao — monitor REAL
        local areasReais = InLab_AreasDeTrabalho()
        checar "AreasDeTrabalho devolve pelo menos 1 monitor" (areasReais.count >= 1)
        checar "Cada area tem 4 numeros (esq,topo,dir,baixo)" ((for a in areasReais where a.count != 4 collect a).count == 0)
        checar "Cada area tem direita > esquerda e baixo > topo" \
            ((for a in areasReais where not (a[3] > a[1] and a[4] > a[2]) collect a).count == 0)

        local padrao = InLab_PosicaoPainelPadrao()
        checar "Padrao e Point2 (tem .x e .y)" (padrao.x != undefined and padrao.y != undefined)
        checar "Padrao cai dentro de alguma area de trabalho real" (InLab_PosicaoValida padrao.x padrao.y areasReais)
        -- Topo a direita: x = Right - LARGURA, y = Top da tela primaria
        local areaPrimaria = (dotNetClass "System.Windows.Forms.Screen").PrimaryScreen.WorkingArea
        checar "Padrao.x = borda direita da tela primaria - largura do painel" (padrao.x == (areaPrimaria.Right - INLAB_PAINEL_LARGURA))
        checar "Padrao.y = topo da tela primaria" (padrao.y == areaPrimaria.Top)

        -- 3. InLab_PosicaoPainelLer — le/valida a preferencia
        -- 3a. SEM preferencia gravada: cai no padrao
        InLab_PrefApagar "painelX"
        InLab_PrefApagar "painelY"
        local semPref = InLab_PosicaoPainelLer()
        checar "Sem preferencia gravada, le o padrao (1a execucao)" (semPref.x == padrao.x and semPref.y == padrao.y)

        -- 3b. Preferencia VALIDA gravada: le de volta o valor gravado
        local xValido = padrao.x -- reaproveita um ponto ja confirmado valido
        local yValido = padrao.y
        InLab_PrefGravar "painelX" xValido
        InLab_PrefGravar "painelY" yValido
        local comPref = InLab_PosicaoPainelLer()
        checar "Com preferencia valida, le de volta o valor gravado" (comPref.x == xValido and comPref.y == yValido)

        -- 3c. Preferencia FORA da area de trabalho (monitor desligado /
        -- resolucao menor): cai no padrao
        InLab_PrefGravar "painelX" -99999
        InLab_PrefGravar "painelY" -99999
        local foraDaArea = InLab_PosicaoPainelLer()
        checar "Posicao fora da area de trabalho cai no padrao" (foraDaArea.x == padrao.x and foraDaArea.y == padrao.y)

        -- 3d. Preferencia CORROMPIDA (nao numerica): cai no padrao, sem excecao
        InLab_PrefGravar "painelX" "abacaxi"
        InLab_PrefGravar "painelY" "banana"
        local corrompida = #naoRodou
        try ( corrompida = InLab_PosicaoPainelLer() ) catch ( corrompida = #excecao )
        checar "Preferencia corrompida nao lanca excecao" (corrompida != #excecao)
        checar "Preferencia corrompida cai no padrao" (corrompida.x == padrao.x and corrompida.y == padrao.y)

        -- 3e. So uma das duas chaves gravada (ini escrito na mao / parcial):
        -- cai no padrao
        InLab_PrefGravar "painelX" xValido
        InLab_PrefApagar "painelY"
        local parcial = InLab_PosicaoPainelLer()
        checar "So painelX sem painelY cai no padrao" (parcial.x == padrao.x and parcial.y == padrao.y)

        InLab_PrefApagar "painelX"
        InLab_PrefApagar "painelY"

        -- 4. InLab_PosicaoPainelGravar — grava .pos de um rollout QUALQUER
        -- (_rTesteFake, definido no topo do arquivo).
        try
        (
            createDialog _rTesteFake 100 60 pos:[321, 45]
            aberto = true
            local ok = InLab_PosicaoPainelGravar _rTesteFake
            checar "Gravar devolve true" (ok == true)
            checar "Gravou painelX certo" ((InLab_PrefLer "painelX" "") == "321")
            checar "Gravou painelY certo" ((InLab_PrefLer "painelY" "") == "45")
            destroyDialog _rTesteFake
            aberto = false
        )
        catch
        (
            INLAB_TESTE_FALHAS += 1
            linha ("FAIL  EXCECAO no bloco do rollout de teste: " + getCurrentException())
        )

        -- 4b. Grava -> le de volta -> mesma posicao (ciclo completo)
        local cicloLer = InLab_PosicaoPainelLer()
        checar "Ciclo gravar->ler devolve a mesma posicao" (cicloLer.x == 321 and cicloLer.y == 45)

        -- 4c. Gravar com rollout invalido (sem .pos) nao lanca excecao
        local okInvalido = #naoRodou
        try ( okInvalido = InLab_PosicaoPainelGravar undefined ) catch ( okInvalido = #excecao )
        checar "Gravar com rollout invalido nao lanca excecao" (okInvalido != #excecao)
        checar "Gravar com rollout invalido devolve false" (okInvalido == false)

        InLab_PrefApagar "painelX"
        InLab_PrefApagar "painelY"
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("FAIL  EXCECAO: " + getCurrentException())
        if aberto do try ( destroyDialog _rTesteFake ) catch()
    )

    -- LIMPEZA — chave nova desta issue, nao ha valor anterior pra devolver.
    InLab_PrefApagar "painelX"
    InLab_PrefApagar "painelY"
    local sobrou = for c in #("painelX", "painelY") where (InLab_PrefLer c undefined) != undefined collect c
    checar "Nenhuma chave de posicao sobrou no ini" (sobrou.count == 0)

    InLab_Log = logOriginal
    linha ("---- " + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluido — %\n" arqSaida
)
