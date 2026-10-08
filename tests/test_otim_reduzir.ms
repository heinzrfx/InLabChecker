/*
 tests\test_otim_reduzir.ms — teste automático de functions\fn_otim_reduzir.ms (issue #124)
 Reduzir 30% por clique (um modificador por stack, VertexPercent × 0,7), cada
 clique um passo de Ctrl+Z, Desfazer volta exatamente ao clique anterior,
 instâncias com um modificador só, grupo fechado, proteções, seleção restaurada,
 piso de 1% e registro que não bate depois de um Ctrl+Z.
 RODAR NUMA CENA VAZIA (File > New).
 Resultado: <pasta temp do Max>\inlab_test_otim_reduzir.txt (PASS/FAIL por item).
*/
global InLab_Log, InLab_Otim_Triangulos
global InLab_OtimReduzir, InLab_OtimReduzir_Desfazer, InLab_OtimReduzir_Modificador
global InLab_ReduzirHistorico, INLAB_REDUZIR_NOME_MOD, INLAB_REDUZIR_PCT_MIN
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_otim_reduzir.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn limparCena = ( delete (for o in objects collect o) )
    fn tris o = (GetTriMeshFaceCount o)[1]
    fn contaPO o = (for m in o.modifiers where classof m == ProOptimizer collect m).count

    local logOriginal = InLab_Log

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms", @"functions\fn_otim_nucleo.ms", @"functions\fn_otim_reduzir.ms",
                   @"functions\fn_autouv.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        limparCena()
        InLab_ReduzirHistorico = #()

        ---------------------------------------------------------------- CENA
        local esf = Sphere name:"red_esfera" radius:20 segs:64 mapcoords:true
        local bule1 = Teapot name:"red_bule_1" radius:10 segs:6 mapcoords:true pos:[60, 0, 0]
        convertToPoly esf
        convertToPoly bule1
        local bule2 = instance bule1
        bule2.name = "red_bule_2"
        bule2.pos = [100, 0, 0]
        local caixa = Box name:"red_caixa" length:20 width:20 height:20 lengthsegs:8 widthsegs:8 heightsegs:8 mapcoords:true pos:[0, 60, 0]
        convertToPoly caixa
        local grp = group #(caixa) name:"red_grupo"
        local esfT0 = tris esf, buleT0 = tris bule1, caixaT0 = tris caixa
        linha ("      cena: esfera " + esfT0 as string + ", bule " + buleT0 as string + ", caixa " + caixaT0 as string)

        ---------------------------------------------------------------- VAZIO
        checar "Sem geometria na lista: nada acontece" ((InLab_OtimReduzir #()) == 0 and InLab_ReduzirHistorico.count == 0)

        ---------------------------------------------------------------- CLIQUE 1
        select esf
        local n1 = InLab_OtimReduzir #(esf, bule1, bule2, caixa)
        local esfT1 = tris esf, buleT1 = tris bule1, caixaT1 = tris caixa
        local po = InLab_OtimReduzir_Modificador esf
        checar ("Clique 1 reduz as 3 peças (3 stacks): " + n1 as string) (n1 == 3)
        checar ("Esfera cai ~30% (" + esfT0 as string + " -> " + esfT1 as string + ")") (esfT1 < esfT0 and esfT1 <= esfT0 * 0.80 and esfT1 >= esfT0 * 0.60)
        checar "Modificador com o nome InLab e VertexPercent 70" (po != undefined and po.name == INLAB_REDUZIR_NOME_MOD and (abs (po.VertexPercent - 70.0)) < 0.01)
        checar "Proteções ligadas (KeepUV, LockUV, LockMat, Exclude Borders)" (po.KeepUV and po.LockUV and po.LockMat and po.OptimizationMode == 2)
        checar "Instâncias: um ProOptimizer só no stack compartilhado" (contaPO bule1 == 1 and (InLab_OtimReduzir_Modificador bule2) == (InLab_OtimReduzir_Modificador bule1))
        checar ("Instância fora da lista também reduz (" + (tris bule2) as string + ")") ((tris bule2) == buleT1 and buleT1 < buleT0)
        checar ("Membro de grupo fechado reduz (" + caixaT0 as string + " -> " + caixaT1 as string + ")") (caixaT1 < caixaT0)
        checar "Grupo volta fechado" (not (isOpenGroupHead grp))
        checar "Seleção do usuário restaurada" (selection.count == 1 and selection[1] == esf)
        checar "Histórico: 1 clique com 3 peças" (InLab_ReduzirHistorico.count == 1 and InLab_ReduzirHistorico[1].count == 3)

        ---------------------------------------------------------------- CLIQUE 2
        InLab_OtimReduzir #(esf)
        local esfT2 = tris esf
        checar "Clique 2 reaproveita o modificador (não empilha)" (contaPO esf == 1)
        checar ("Clique 2: VertexPercent 49 (" + po.VertexPercent as string + ")") ((abs (po.VertexPercent - 49.0)) < 0.01)
        checar ("Clique 2 reduz mais (" + esfT1 as string + " -> " + esfT2 as string + ")") (esfT2 < esfT1)

        ---------------------------------------------------------------- CTRL+Z
        max undo
        checar ("Ctrl+Z volta só o clique 2 (" + (tris esf) as string + ")") ((tris esf) == esfT1 and (abs (po.VertexPercent - 70.0)) < 0.01)
        -- O registro do clique 2 não bate mais: Desfazer pula a peça.
        local nPula = InLab_OtimReduzir_Desfazer()
        checar "Desfazer depois do Ctrl+Z pula a peça (registro não bate)" (nPula == 0 and (tris esf) == esfT1)

        ---------------------------------------------------------------- DESFAZER
        InLab_OtimReduzir #(esf)
        local nD = InLab_OtimReduzir_Desfazer()
        checar ("Desfazer volta exatamente ao clique anterior (" + (tris esf) as string + ")") (nD == 1 and (tris esf) == esfT1)
        nD = InLab_OtimReduzir_Desfazer()
        checar ("Desfazer do clique 1 remove os modificadores (" + nD as string + " peças)") \
            (nD == 3 and contaPO esf == 0 and contaPO bule1 == 0 and contaPO caixa == 0)
        checar "Malhas voltam ao original" ((tris esf) == esfT0 and (tris bule2) == buleT0 and (tris caixa) == caixaT0)
        checar "Histórico vazio" (InLab_ReduzirHistorico.count == 0)
        checar "Desfazer sem histórico não quebra" ((InLab_OtimReduzir_Desfazer()) == 0)

        ---------------------------------------------------------------- PISO
        InLab_OtimReduzir #(esf)
        po = InLab_OtimReduzir_Modificador esf
        po.VertexPercent = INLAB_REDUZIR_PCT_MIN
        checar "No piso de 1%: clique não reduz" ((InLab_OtimReduzir #(esf)) == 0)

        ---------------------------------------------------------------- UM CLIQUE = UM PASSO DE UNDO
        limparCena()
        InLab_ReduzirHistorico = #()
        local a = Sphere name:"red_a" radius:10 segs:48 mapcoords:true
        local b = Sphere name:"red_b" radius:10 segs:48 mapcoords:true pos:[40, 0, 0]
        convertToPoly a
        convertToPoly b
        local aT0 = tris a, bT0 = tris b
        InLab_OtimReduzir #(a, b)
        max undo
        checar "Um Ctrl+Z desfaz o clique inteiro (as 2 peças)" ((tris a) == aT0 and (tris b) == bT0 and contaPO a == 0 and contaPO b == 0)

        ---------------------------------------------------------------- MALHA ABAIXO MUDOU (teste adversarial 08/10)
        InLab_ReduzirHistorico = #()
        InLab_OtimReduzir #(a)
        local aT1 = tris a
        polyop.moveVert a #{1..100} [0, 0, 5]
        local aSujo = tris a
        local nSujo = InLab_OtimReduzir #(a)
        checar ("Malha abaixo mudou (" + aT1 as string + " -> " + aSujo as string + "): clique recalcula e reduz (" + (tris a) as string + ")") \
            (nSujo == 1 and (tris a) < aT1)
        checar "Recalcular não empilha modificador" (contaPO a == 1)

        ---------------------------------------------------------------- MODIFICADOR DESLIGADO
        local poA = InLab_OtimReduzir_Modificador a
        poA.enabled = false
        checar "Modificador desligado: clique não reduz nem mexe no VertexPercent" \
            ((InLab_OtimReduzir #(a)) == 0 and (abs (poA.VertexPercent - 49.0)) < 0.01)
        poA.enabled = true

        ---------------------------------------------------------------- PERCENTUAL SOBE (teste adversarial 08/10)
        -- O ProOptimizer não refaz a malha quando o VertexPercent sobe: o
        -- Desfazer/Ctrl+Z de um clique do meio tem que dar a mesma malha que
        -- uma peça nova reduzida direto àquele percentual.
        fn refBule pct =
        (
            local c = Teapot radius:10 segs:6 mapcoords:true pos:[0, -200, 0]
            convertToPoly c
            InLab_OtimReduzir #(c)
            (InLab_OtimReduzir_Modificador c).VertexPercent = pct
            local n = tris c
            delete c
            n
        )
        -- Referências ANTES: o refBule cria um passo de undo próprio, que um
        -- Ctrl+Z do meio da sequência desfaria no lugar do clique.
        local ref343 = refBule 34.3
        local ref49 = refBule 49.0
        local bu = Teapot name:"red_bule_sobe" radius:10 segs:6 mapcoords:true pos:[0, 200, 0]
        convertToPoly bu
        for i = 1 to 4 do InLab_OtimReduzir #(bu)
        local bu4 = tris bu
        InLab_OtimReduzir_Desfazer()
        checar ("Desfazer do clique 4 dá a malha de 34,3% (" + (tris bu) as string + ", ref " + ref343 as string + ", clique 4 = " + bu4 as string + ")") \
            ((tris bu) == ref343)
        InLab_OtimReduzir #(bu)
        max undo
        checar ("Ctrl+Z do clique refeito dá a malha de 34,3% (" + (tris bu) as string + ")") ((tris bu) == ref343)
        max undo
        checar ("Ctrl+Z do Desfazer volta à malha de 24% (" + (tris bu) as string + ", ref " + bu4 as string + ")") ((tris bu) == bu4)
        max undo
        checar ("Ctrl+Z do clique 4 dá a malha de 34,3% (" + (tris bu) as string + ")") ((tris bu) == ref343)
        max undo
        checar ("Ctrl+Z do clique 3 dá a malha de 49% (" + (tris bu) as string + ", ref " + ref49 as string + ")") ((tris bu) == ref49)

        ---------------------------------------------------------------- SELEÇÃO DEPOIS DO CTRL+Z (teste adversarial 08/10)
        fn nomesSel = (for s in selection collect s.name) as string
        local sd = Sphere name:"red_sd" segs:24 mapcoords:true pos:[0, 300, 0]
        local se = Sphere name:"red_se" segs:24 mapcoords:true pos:[50, 300, 0]
        convertToPoly sd
        convertToPoly se
        local gs = group #(sd, se) name:"red_gs"
        select gs
        local selG = nomesSel()
        InLab_OtimReduzir #(sd, se)
        max undo
        checar ("Grupo de 2 membros: Ctrl+Z mantém a seleção (" + selG + " -> " + nomesSel() + ")") (nomesSel() == selG)
        local ti = Teapot name:"red_ti" segs:4 mapcoords:true pos:[0, 400, 0]
        convertToPoly ti
        local ti2 = instance ti
        ti2.name = "red_ti2"
        ti2.pos = [60, 400, 0]
        select sd
        local selI = nomesSel()
        local tiT0 = tris ti
        InLab_OtimReduzir #(ti)
        local tiT1 = tris ti
        max undo
        checar ("Instância: Ctrl+Z do clique que cria o modificador mantém a seleção (" + selI + " -> " + nomesSel() + ")") (nomesSel() == selI)
        max redo
        checar ("Instância: Redo volta reduzida (" + (tris ti) as string + " = " + tiT1 as string + ") e a seleção igual") \
            ((tris ti) == tiT1 and tiT1 < tiT0 and nomesSel() == selI)

        ---------------------------------------------------------------- HISTÓRICO ZERA NA CENA NOVA
        checar "Histórico tem cliques antes do reset" (InLab_ReduzirHistorico.count > 0)
        resetMaxFile #noPrompt
        checar "Histórico zera no reset da cena" (InLab_ReduzirHistorico.count == 0)

        limparCena()
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )
    try ( limparCena() ) catch ()
    InLab_ReduzirHistorico = #()
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
)
