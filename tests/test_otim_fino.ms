/*
 tests\test_otim_fino.ms — teste automático de functions\fn_otim_fino.ms (issue #62)
 Spec 2026-09-23-otimizacao-design.md, seção 6: proteções ligadas; cada peça a
 até 10% da meta; piso protege peça pequena; instâncias com um modificador só;
 Reverter limpa. Mais: divisão da meta por área (conta pura), piso do .ini,
 Comparar, seleção do usuário restaurada.
 RODAR NUMA CENA VAZIA (File > New). Grava e apaga chaves "piso_fino_*" no ini real.
 Resultado: <pasta temp do Max>\inlab_test_otim_fino.txt (PASS/FAIL por item).
*/
global InLab_Log, InLab_FamiliaAtiva, InLab_PrefGravar, InLab_PrefApagar
global INLAB_OTIM_META_MANUAL, InLab_Otim_Triangulos
global InLab_OtimFino_Calcular, InLab_OtimFino_Aplicar, InLab_OtimFino_Reverter, InLab_OtimFino_Comparar
global InLab_OtimFino_DividirMeta, InLab_OtimFino_PisoPeca, InLab_UltimoAjusteFino, INLAB_FINO_TOLERANCIA
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_otim_fino.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn limparCena = ( delete (for o in objects collect o) )
    fn perto a b tol = (abs (a - b)) <= tol
    fn propDe props o = ( local r = undefined; for p in props where p.no == o do r = p; r )

    local logOriginal = InLab_Log
    local chavesIni = #("piso_fino_pct", "piso_fino_min")

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms", @"functions\fn_otim_nucleo.ms", @"functions\fn_otim_fino.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        limparCena()
        for k in chavesIni do InLab_PrefApagar k
        InLab_FamiliaAtiva = undefined

        ---------------------------------------------------------------- DIVISÃO DA META (conta pura)
        local d1 = InLab_OtimFino_DividirMeta #(1000, 1000) #(1.0, 9.0) #(1, 1) #(600, 600) 1700
        checar ("Peça econômica fica intacta e a sobra vai para a outra (" + d1 as string + ")") (perto d1[1] 700 1 and perto d1[2] 1000 1)
        local d2 = InLab_OtimFino_DividirMeta #(1000, 1000) #(1.0, 9.0) #(1, 1) #(600, 600) 1000
        checar ("Orçamento abaixo dos pisos: tudo no piso (" + d2 as string + ")") (perto d2[1] 600 0.1 and perto d2[2] 600 0.1)
        local d3 = InLab_OtimFino_DividirMeta #(1000, 1000) #(1.0, 1.0) #(2, 1) #(0, 0) 1500
        checar ("Peso por instância: 2 nós + 1 nó dividem 1500 em 500 (" + d3 as string + ")") (perto d3[1] 500 1 and perto d3[2] 500 1)
        local d4 = InLab_OtimFino_DividirMeta #(1000, 4000) #(1.0, 1.0) #(1, 1) #(0, 0) 2000
        checar ("Mesma área, meta igual: a peça densa perde mais (" + d4 as string + ")") (perto d4[1] 1000 1 and perto d4[2] 1000 1)

        ---------------------------------------------------------------- PISO POR PEÇA (+ .ini)
        checar "Piso padrão: 1000 tris -> 600 (60%)" (perto (InLab_OtimFino_PisoPeca 1000) 600 0.1)
        checar "Piso padrão: 400 tris -> 300 (mínimo)" (perto (InLab_OtimFino_PisoPeca 400) 300 0.1)
        checar "Piso nunca acima da peça: 200 tris -> 200" (perto (InLab_OtimFino_PisoPeca 200) 200 0.1)
        InLab_PrefGravar "piso_fino_pct" "80"
        InLab_PrefGravar "piso_fino_min" "900"
        checar "Piso do .ini: pct 80 -> 2000 tris = 1600" (perto (InLab_OtimFino_PisoPeca 2000) 1600 0.1)
        checar "Piso do .ini: mínimo 900 -> 1000 tris = 900" (perto (InLab_OtimFino_PisoPeca 1000) 900 0.1)
        for k in chavesIni do InLab_PrefApagar k

        ---------------------------------------------------------------- CENA
        -- mapcoords:true em tudo: sem UV no canal 1 o ProOptimizer desliga o
        -- KeepUV sozinho (ver cabeçalho de fn_otim_fino.ms).
        local esf   = Sphere name:"fino_esfera" radius:20 segs:64 mapcoords:true                              -- 3968 tris, densidade média
        local placa = Box name:"fino_placa" length:100 width:100 height:5 lengthsegs:20 widthsegs:20 mapcoords:true pos:[100, 0, 0] -- 1760, econômica
        local mini  = Sphere name:"fino_mini" radius:1.5 segs:18 mapcoords:true pos:[-50, 0, 0]              -- 288 < 300: nem proposta
        local pux   = Sphere name:"fino_puxador" radius:3 segs:32 mapcoords:true pos:[-50, 30, 0]            -- 960, densa: piso 60%
        local ponta = Sphere name:"fino_ponteira" radius:1.5 segs:20 mapcoords:true pos:[-50, 60, 0]         -- 360, densa: piso mínimo 300
        local bule1 = Teapot name:"fino_bule_1" radius:10 segs:6 mapcoords:true pos:[0, 80, 0]
        local bule2 = instance bule1
        bule2.name = "fino_bule_2"
        bule2.pos = [40, 80, 0]
        local todos = #(esf, placa, mini, pux, ponta, bule1, bule2)
        for o in todos do convertToPoly o
        -- convertToPoly numa instância torna todas únicas: refaz a instância.
        delete bule2
        bule2 = instance bule1
        bule2.name = "fino_bule_2"
        bule2.pos = [40, 80, 0]
        todos[7] = bule2
        local trisAntes = for o in todos collect (InLab_Otim_Triangulos #(o))
        local total = InLab_Otim_Triangulos todos
        INLAB_OTIM_META_MANUAL = (total * 0.70) as integer
        linha ("      cena: " + total as string + " triângulos, meta " + INLAB_OTIM_META_MANUAL as string)

        ---------------------------------------------------------------- CALCULAR
        local props = InLab_OtimFino_Calcular todos
        checar "Calcular não mexe na cena" ((for o in todos collect (InLab_Otim_Triangulos #(o))) as string == trisAntes as string and
                                            (for o in todos where o.modifiers.count > 0 collect o).count == 0)
        checar "Peça com menos que o piso mínimo (288 tris) não é proposta" ((propDe props mini) == undefined)
        checar "Peça econômica para o tamanho (placa) fica intacta" ((propDe props placa) == undefined)
        local pBule = for p in props where p.no == bule1 or p.no == bule2 collect p
        checar "Instâncias: uma proposta só para o stack dos bules" (pBule.count == 1)
        local pEsf = propDe props esf
        local pPux = propDe props pux
        local pPonta = propDe props ponta
        checar "Esfera, puxador e ponteira propostos" (pEsf != undefined and pPux != undefined and pPonta != undefined)
        if pEsf != undefined and pPux != undefined and pPonta != undefined and pBule.count == 1 do
        (
            checar ("Piso protege peça pequena: puxador na meta 60% (" + pPux.trisDepois as string + ")") (perto pPux.trisDepois 576 1)
            checar ("Piso mínimo: ponteira em 300 (" + pPonta.trisDepois as string + ")") (perto pPonta.trisDepois 300 1)
            local rEsf = pEsf.trisDepois as float / pEsf.trisAntes
            local rBule = pBule[1].trisDepois as float / pBule[1].trisAntes
            checar ("Peça mais densa perde mais: bule " + (formattedPrint rBule format:".2f") + " <= esfera " + (formattedPrint rEsf format:".2f")) (rBule <= rEsf and rEsf > 0.6)
            local soma = trisAntes[2] + trisAntes[3] + pEsf.trisDepois + pPux.trisDepois + pPonta.trisDepois + 2 * pBule[1].trisDepois
            checar ("Metas somam a meta da cena (" + soma as string + " ~ " + INLAB_OTIM_META_MANUAL as string + ")") (perto soma INLAB_OTIM_META_MANUAL 5)
            for p in props do
                checar ("Meta de " + p.no.name + " entre o piso e o atual") (p.trisDepois >= (InLab_OtimFino_PisoPeca p.trisAntes) - 1 and p.trisDepois < p.trisAntes)
        )

        ---------------------------------------------------------------- APLICAR
        select placa
        local nApl = InLab_OtimFino_Aplicar props
        checar ("Aplicar devolve uma por proposta (" + nApl as string + ")") (nApl == props.count and InLab_UltimoAjusteFino.count == props.count)
        checar "Seleção do usuário restaurada" (selection.count == 1 and selection[1] == placa)
        for p in props do
        (
            local obtido = InLab_Otim_Triangulos #(p.no)
            checar ("Cada peça a até 10% da meta: " + p.no.name + " " + obtido as string + " / " + p.trisDepois as string) \
                ((abs (obtido - p.trisDepois)) <= p.trisDepois * 0.10)
        )
        checar "Instâncias: um ProOptimizer só, compartilhado pelos dois bules" \
            (bule1.modifiers.count == 1 and bule2.modifiers.count == 1 and bule1.modifiers[1] == bule2.modifiers[1])
        checar "Peças fora da proposta sem modificador" (placa.modifiers.count == 0 and mini.modifiers.count == 0)
        local mods = for r in InLab_UltimoAjusteFino collect r.modificador
        local protOk = true
        local protTxt = ""
        for m in mods do
        (
            local v = #(m.LockMat, m.KeepUV, m.LockUV, m.KeepNormals, m.OptimizationMode)
            protTxt += v as string + " "
            if v as string != "#(true, true, true, true, 2)" do protOk = false
        )
        checar ("Proteções ligadas (LockMat, KeepUV, LockUV, KeepNormals, OptimizationMode 2): " + protTxt) (mods.count > 0 and protOk)

        ---------------------------------------------------------------- COMPARAR
        checar "Comparar desliga todos na viewport" ((InLab_OtimFino_Comparar false) == mods.count and
                                                     (for m in mods where m.enabledInViews collect m).count == 0)
        checar "Comparar religa" ((InLab_OtimFino_Comparar true) == mods.count and
                                  (for m in mods where not m.enabledInViews collect m).count == 0)

        ---------------------------------------------------------------- REVERTER
        local nRev = InLab_OtimFino_Reverter()
        checar ("Reverter devolve quantos saíram (" + nRev as string + ")") (nRev == props.count)
        checar "Reverter limpa: nenhum modificador e triângulos de volta" \
            ((for o in todos where o.modifiers.count > 0 collect o).count == 0 and
             (for o in todos collect (InLab_Otim_Triangulos #(o))) as string == trisAntes as string)
        checar "Reverter de novo não faz nada" ((InLab_OtimFino_Reverter()) == 0)
        checar "Comparar sem nada aplicado devolve 0" ((InLab_OtimFino_Comparar false) == 0)

        ---------------------------------------------------------------- SEGUNDA PASSADA
        -- Tolerância apertada à força para exercitar a correção do percentual.
        INLAB_FINO_TOLERANCIA = 0.0001
        local pSo = InLab_OtimFino_Calcular #(esf)
        if pSo.count == 1 then
        (
            InLab_OtimFino_Aplicar pSo
            local rec = InLab_UltimoAjusteFino[1]
            checar ("Segunda passada roda quando erra a meta (" + rec.trisDepois as string + " / " + rec.meta as string + ")") \
                (rec.passadas == 2 and (abs (rec.trisDepois - rec.meta)) <= rec.meta * 0.10)
            InLab_OtimFino_Reverter()
        )
        else checar "Segunda passada: esfera proposta" false
        INLAB_FINO_TOLERANCIA = 0.10
        checar "Segunda passada: Reverter limpou" (esf.modifiers.count == 0)

        ---------------------------------------------------------------- SEM META / JÁ CABE
        INLAB_OTIM_META_MANUAL = undefined
        checar "Sem família e sem meta: nenhuma proposta" ((InLab_OtimFino_Calcular todos).count == 0)
        INLAB_OTIM_META_MANUAL = total * 2
        checar "Já cabe na meta: nenhuma proposta" ((InLab_OtimFino_Calcular todos).count == 0)
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
    INLAB_FINO_TOLERANCIA = 0.10
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
