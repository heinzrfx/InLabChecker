/*
 tests\test_otim_nucleo.ms — teste automático do núcleo da otimização (issue #60)
 Cobre functions\fn_otim_nucleo.ms (contagem, faixa, estado, pisos com .ini,
 registro de reversão) e, a partir da Tarefa 3, o despachante dos 3 passos.
 RODAR NUMA CENA VAZIA (File > New). Grava e apaga chaves "piso_*" no ini real.
 Resultado: <pasta temp do Max>\inlab_test_otim_nucleo.txt (PASS/FAIL por item).
*/
global InLab_Log, InLab_FamiliaAtiva, InLab_ObterFamilia, InLab_DefinirFamiliaAtiva
global InLab_PrefGravar, InLab_PrefApagar
global INLAB_OTIM_META_MANUAL, InLab_Otim_Triangulos, InLab_Otim_Piso, InLab_Otim_Faixa, InLab_Otim_Estado
global InLab_Otim_Milhar, InLab_Otim_TextoMedidor, InLab_Otim_AlvoSelecao, InLab_Otim_Guardar, InLab_Otim_Restaurar
global InLab_Otim_Calcular, InLab_Otim_Aplicar, InLab_Otim_Reverter, InLab_OtimFino_Comparar
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
    local chavesIni = #("piso_turbosmooth", "piso_chamfer")

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms", @"familias\familia_corpo_unico.ms",
                   @"functions\fn_prooptimizer.ms", @"functions\fn_otim_nucleo.ms",
                   @"functions\fn_otim_origem.ms", @"functions\fn_otim_fino.ms", @"functions\fn_otim_escondidas.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        limparCena()
        InLab_FamiliaAtiva = undefined
        INLAB_OTIM_META_MANUAL = undefined

        ---------------------------------------------------------------- CONTAGEM
        local b1 = Box()
        checar "Triângulos: Box padrão = 12" ((InLab_Otim_Triangulos #(b1)) == 12)
        local b2 = instance b1
        local ponto = Point()
        checar "Triângulos: instância conta por nó, helper não conta" ((InLab_Otim_Triangulos #(b1, b2, ponto)) == 24)

        ---------------------------------------------------------------- PISOS
        for k in chavesIni do InLab_PrefApagar k
        checar "Piso padrão do TurboSmooth = 1" ((InLab_Otim_Piso "turbosmooth") == 1)
        InLab_PrefGravar "piso_turbosmooth" "2"
        checar "Piso do .ini vale por cima do padrão (2)" ((InLab_Otim_Piso "turbosmooth") == 2)
        InLab_PrefGravar "piso_chamfer" "abc"
        checar "Piso inválido no .ini cai no padrão (1)" ((InLab_Otim_Piso "chamfer") == 1)
        checar "Piso inexistente devolve undefined" ((InLab_Otim_Piso "nao_existe") == undefined)
        for k in chavesIni do InLab_PrefApagar k

        ---------------------------------------------------------------- FAIXA E ESTADO
        checar "Faixa sem família e sem meta = undefined" ((InLab_Otim_Faixa()) == undefined)
        INLAB_OTIM_META_MANUAL = 5000
        local fm = InLab_Otim_Faixa()
        checar "Faixa com meta manual = #(0, 5000, 5000)" (fm != undefined and fm[1] == 0 and fm[2] == 5000 and fm[3] == 5000)
        InLab_FamiliaAtiva = InLab_ObterFamilia "corpo_unico"
        local ff = InLab_Otim_Faixa()
        checar "Faixa da família vale por cima da meta manual (40000..100000, alvo 70000)" (ff[1] == 40000 and ff[2] == 100000 and ff[3] == 70000)
        checar "Estado: 70.000 dentro" ((InLab_Otim_Estado 70000 ff) == #dentro)
        checar "Estado: 105.000 perto (até 10% fora)" ((InLab_Otim_Estado 105000 ff) == #perto)
        checar "Estado: 150.000 longe" ((InLab_Otim_Estado 150000 ff) == #longe)
        checar "Estado: 38.000 perto (abaixo do mínimo, até 10%)" ((InLab_Otim_Estado 38000 ff) == #perto)
        checar "Estado sem faixa = #sem" ((InLab_Otim_Estado 1000 undefined) == #sem)

        ---------------------------------------------------------------- TEXTO
        checar "Milhar: 182340 -> 182.340" ((InLab_Otim_Milhar 182340) == "182.340")
        checar "Milhar: 999 -> 999" ((InLab_Otim_Milhar 999) == "999")
        checar "Milhar: 1000 -> 1.000" ((InLab_Otim_Milhar 1000) == "1.000")
        local txt = InLab_Otim_TextoMedidor 182340 ff
        checar ("Texto do medidor com a faixa ('" + txt + "')") ((findString txt "182.340") != undefined and (findString txt "40.000 a 100.000") != undefined)
        checar "Texto do medidor sem faixa pede família ou meta" ((findString (InLab_Otim_TextoMedidor 10 undefined) "família") != undefined)

        ---------------------------------------------------------------- ALVO DA SELEÇÃO
        limparCena()
        local c1 = Box()
        local c2 = Box pos:[50, 0, 0]
        InLab_FamiliaAtiva = undefined
        INLAB_OTIM_META_MANUAL = 20
        -- cena 24, meta 20: a seleção (c1, 12) pode ficar com 20 - (24 - 12) = 8
        checar "Alvo da seleção desconta o resto da cena (8)" ((InLab_Otim_AlvoSelecao #(c1) (InLab_Otim_Faixa())) == 8)
        checar "Alvo da seleção sem faixa = undefined" ((InLab_Otim_AlvoSelecao #(c1) undefined) == undefined)

        ---------------------------------------------------------------- REGISTRO DE REVERSÃO
        local ts = TurboSmooth iterations:3
        addModifier c1 ts
        local reg = #()
        InLab_Otim_Guardar reg ts #iterations
        ts.iterations = 2
        InLab_Otim_Guardar reg ts #iterations
        ts.iterations = 1
        local n = InLab_Otim_Restaurar reg
        checar "Restaurar volta ao valor mais antigo (3), na ordem inversa" (ts.iterations == 3 and n == 2)
        limparCena()

        ---------------------------------------------------------------- DESPACHANTE E PASSOS
        local e1 = Sphere radius:20 segs:48
        convertToPoly e1
        InLab_FamiliaAtiva = undefined
        local trisAntes = InLab_Otim_Triangulos #(e1)
        INLAB_OTIM_META_MANUAL = trisAntes / 2
        checar "Passo 1 (em construção) não propõe nada" ((InLab_Otim_Calcular 1 #(e1)).count == 0)
        checar "Passo 3 (em construção) não propõe nada" ((InLab_Otim_Calcular 3 #(e1)).count == 0)
        local props = InLab_Otim_Calcular 2 #(e1)
        checar "Passo 2 propõe uma linha por peça" (props.count == 1 and props[1].no == e1)
        checar "Passo 2: proposta com percentual < 100" (props[1].depois < 100.0)
        checar "Calcular não mexe na cena" ((InLab_Otim_Triangulos #(e1)) == trisAntes)
        InLab_Otim_Aplicar 2 props
        local trisDepois = InLab_Otim_Triangulos #(e1)
        checar ("Passo 2 reduz (" + trisAntes as string + " -> " + trisDepois as string + ")") (trisDepois < trisAntes * 0.75)
        checar "Comparar desliga o ajuste na viewport" ((InLab_OtimFino_Comparar false) == 1 and not e1.modifiers[1].enabledInViews)
        InLab_OtimFino_Comparar true
        props[1].marcada = false
        InLab_Otim_Reverter 2
        checar "Reverter do passo 2 volta os triângulos" ((InLab_Otim_Triangulos #(e1)) == trisAntes and e1.modifiers.count == 0)
        checar "Aplicar sem linha marcada não faz nada" ((InLab_Otim_Aplicar 2 props) == 0 and e1.modifiers.count == 0)
        checar "Passo inválido não propõe nada" ((InLab_Otim_Calcular 9 #(e1)).count == 0)
        limparCena()
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    try ( limparCena() ) catch ()
    for k in chavesIni do try ( InLab_PrefApagar k ) catch ()
    InLab_FamiliaAtiva = undefined
    INLAB_OTIM_META_MANUAL = undefined
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
