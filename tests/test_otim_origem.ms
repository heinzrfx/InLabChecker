/*
 tests\test_otim_origem.ms — teste automático do passo 1 da otimização (issue #61)
 Cobre functions\fn_otim_origem.ms (spec 2026-09-23-otimizacao-design.md, seção 6):
 cena com TurboSmooth, Chamfer, Shell, Cylinder instanciado, spline renderizável
 (fica fora: o medidor não a conta), spline sob Extrude, modificador desligado,
 base sob deformador e Chamfer sob TurboSmooth. Proposta cai na faixa; pisos
 respeitados (padrão e .ini); levantamento não deixa nada alterado (inclusive
 com exceção no meio); instância conta uma vez só e multiplica a economia;
 Aplicar/Reverter voltam os valores exatos.
 RODAR NUMA CENA VAZIA (File > New). Grava e apaga "piso_turbosmooth" no ini real.
 Resultado: <pasta temp do Max>\inlab_test_otim_origem.txt (PASS/FAIL por item).
*/
global InLab_Log, InLab_FamiliaAtiva, InLab_PrefGravar, InLab_PrefApagar
global INLAB_OTIM_META_MANUAL, InLab_Otim_Piso, InLab_Otim_Calcular, InLab_Otim_Aplicar, InLab_Otim_Reverter
global InLab_Otim_Triangulos, InLab_OtimOrigem_Calcular, InLab_OtimOrigem_NovoBotao, InLab_UltimaOtimOrigem
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
global INLAB_TESTE_TRIS_REAL, INLAB_TESTE_VIGIAR, INLAB_TESTE_ORIG, INLAB_TESTE_ALTERADO
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_otim_origem.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    INLAB_TESTE_TRIS_REAL = undefined
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn limparCena = ( delete (for o in objects collect o) )
    struct FamTeste (polyMin, polyMax)

    local logOriginal = InLab_Log
    local chavesIni = #("piso_turbosmooth")

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms", @"functions\fn_prooptimizer.ms", @"functions\fn_otim_nucleo.ms",
                   @"functions\fn_otim_origem.ms", @"functions\fn_otim_fino.ms", @"functions\fn_otim_escondidas.ms") do
            fileIn (raiz + m)
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        for k in chavesIni do InLab_PrefApagar k
        limparCena()
        INLAB_OTIM_META_MANUAL = undefined
        InLab_UltimaOtimOrigem = #()

        ---------------------------------------------------------------- CENA
        -- A: TurboSmooth 3 sobre Box 2x2x2 (segs da base = gaiola, ficam),
        --    render iterations ligado em 3.
        local a = Box length:40 width:40 height:40 lengthsegs:2 widthsegs:2 heightsegs:2 name:"A_TS"
        local ts = TurboSmooth iterations:3
        addModifier a ts
        ts.useRenderIterations = true
        ts.renderIterations = 3
        -- B: Chamfer 6 segmentos numa Box.
        local b = Box length:30 width:30 height:30 pos:[100, 0, 0] name:"B_Chamfer"
        local ch = Chamfer()
        addModifier b ch
        ch.segments = 6
        -- C: Shell 5 segmentos num Plane.
        local c = Plane length:30 width:30 pos:[200, 0, 0] name:"C_Shell"
        local sh = Shell()
        addModifier c sh
        sh.segments = 5
        -- D: Cylinder 48 lados, instanciado (D e D2).
        local d = Cylinder radius:5 height:40 sides:48 heightsegs:4 capsegs:2 pos:[300, 0, 0] name:"D_Cil"
        local d2 = instance d
        d2.pos = [320, 0, 0]
        d2.name = "D_Cil_inst"
        -- E: spline renderizável SEM modificador (Shape: o medidor não conta, fica fora).
        local e = Line name:"E_Spline"
        addNewSpline e
        addKnot e 1 #corner #line [400, 0, 0]
        addKnot e 1 #smooth #curve [450, 0, 0]
        addKnot e 1 #corner #line [450, 50, 0]
        updateShape e
        e.render_displayRenderMesh = true
        e.render_renderable = true
        e.steps = 12
        e.render_sides = 16
        -- F: TurboSmooth DESLIGADO (enabledInViews) sobre Box 1x1x1.
        local f = Box pos:[500, 0, 0] name:"F_TSoff"
        local tsOff = TurboSmooth iterations:3
        addModifier f tsOff
        tsOff.enabledInViews = false
        -- G: Cylinder 32 lados sob Bend (segmentos definem a forma).
        local g = Cylinder radius:5 height:60 sides:32 heightsegs:20 pos:[600, 0, 0] name:"G_Bend"
        addModifier g (Bend angle:45)
        -- E2: spline sob Extrude (nó é geometria: os passos da spline valem).
        local e2 = Line name:"E2_Extrude"
        addNewSpline e2
        addKnot e2 1 #corner #line [700, 0, 0]
        addKnot e2 1 #smooth #curve [750, 0, 0]
        addKnot e2 1 #corner #line [750, 50, 0]
        updateShape e2
        e2.steps = 12
        local ex = Extrude amount:20
        addModifier e2 ex
        -- H: Chamfer SOB TurboSmooth ligado (gaiola: o Chamfer fica, o TS vale).
        local h = Box length:30 width:30 height:30 pos:[800, 0, 0] name:"H_ChamferTS"
        local chH = Chamfer()
        addModifier h chH
        chH.segments = 4
        local tsH = TurboSmooth iterations:2
        addModifier h tsH

        -- Valores originais de todos os botões (para "nada alterado").
        local vigiar = #(#(ts, #iterations), #(ts, #renderIterations), #(ch, #segments), #(sh, #segments),
                         #(d.baseobject, #sides), #(d.baseobject, #heightsegs), #(d.baseobject, #capsegs),
                         #(e.baseobject, #steps), #(e.baseobject, #render_sides), #(tsOff, #iterations),
                         #(a.baseobject, #lengthsegs), #(g.baseobject, #sides), #(g.baseobject, #heightsegs),
                         #(e2.baseobject, #steps), #(ex, #segs), #(chH, #segments), #(tsH, #iterations))
        local originais = for v in vigiar collect getProperty v[1] v[2]
        fn tudoOriginal vigiar originais =
        (
            local ok = true
            for i = 1 to vigiar.count where (getProperty vigiar[i][1] vigiar[i][2]) != originais[i] do ok = false
            ok
        )
        local todos = for o in objects collect o
        -- Mesma contagem do medidor (só GeometryClass).
        local total0 = InLab_Otim_Triangulos todos

        ---------------------------------------------------------------- SEM FAIXA
        InLab_FamiliaAtiva = undefined
        checar "Sem família e sem meta: nada proposto" ((InLab_Otim_Calcular 1 todos).count == 0)

        ---------------------------------------------------------------- PROPRIEDADE AUSENTE
        checar "Propriedade ausente no build: botão pulado" ((InLab_OtimOrigem_NovoBotao b ch #naoExisteNoBuild "chamfer" false false #()) == undefined)

        ---------------------------------------------------------------- PROPOSTA NA FAIXA
        local fam = FamTeste polyMin:((total0 * 0.30) as integer) polyMax:((total0 * 0.60) as integer)
        InLab_FamiliaAtiva = fam
        local props = InLab_Otim_Calcular 1 todos
        checar ("Calcular propõe ajustes (" + props.count as string + ")") (props.count > 0)
        checar "Levantamento não deixa nada alterado (valores)" (tudoOriginal vigiar originais)
        checar "Levantamento não deixa nada alterado (triângulos)" ((InLab_Otim_Triangulos todos) == total0)
        local economia = 0
        for p in props do economia += (p.trisAntes - p.trisDepois)
        local estimado = total0 - economia
        checar ("Estimativa cai na faixa (" + total0 as string + " -> " + estimado as string + ", faixa " +
                fam.polyMin as string + ".." + fam.polyMax as string + ")") (estimado >= fam.polyMin and estimado <= fam.polyMax)
        checar "Modificador desligado ignorado" ((for p in props where p.alvo == tsOff collect p).count == 0)
        checar "Base sob TurboSmooth não é proposta (gaiola)" ((for p in props where p.alvo == a.baseobject collect p).count == 0)
        checar "Base sob Bend não é proposta (define a forma)" ((for p in props where p.alvo == g.baseobject collect p).count == 0)
        checar "Chamfer sob TurboSmooth ligado não é proposto (gaiola)" ((for p in props where p.alvo == chH collect p).count == 0)
        checar "Spline renderizável sem modificador fica fora (medidor não conta)" ((for p in props where p.alvo == e.baseobject collect p).count == 0)
        local repetido = false
        for i = 1 to props.count do for j = i + 1 to props.count where props[i].alvo == props[j].alvo and props[i].prop == props[j].prop do repetido = true
        checar "Nenhum botão (alvo + propriedade) proposto duas vezes" (not repetido)
        local okPiso = true
        for p in props where p.depois < 1 or p.depois >= p.antes do okPiso = false
        checar "Toda proposta baixa e fica >= 1" okPiso

        ---------------------------------------------------------------- APLICAR / REVERTER
        local nAplic = InLab_Otim_Aplicar 1 props
        checar ("Aplicar aplica todas as marcadas (" + nAplic as string + ")") (nAplic == props.count)
        local okVal = true
        for p in props where (getProperty p.alvo p.prop) != p.depois do okVal = false
        checar "Valores aplicados = propostos" okVal
        local totalReal = InLab_Otim_Triangulos todos
        checar ("Total real = estimado (" + totalReal as string + ")") (totalReal == estimado)
        local pts = for p in props where p.alvo == ts collect p
        checar ("renderIterations desce junto com iterations (" + ts.renderIterations as string + ")") (pts.count == 1 and pts[1].depois < 3 and ts.renderIterations == pts[1].depois)
        local nRev = InLab_Otim_Reverter 1
        checar ("Reverter volta os valores exatos (" + nRev as string + ")") (tudoOriginal vigiar originais)
        checar "Reverter volta os triângulos" ((InLab_Otim_Triangulos todos) == total0)
        checar "Reverter de novo não faz nada" ((InLab_Otim_Reverter 1) == 0)
        for p in props do p.marcada = false
        checar "Aplicar sem linha marcada não faz nada" ((InLab_Otim_Aplicar 1 props) == 0 and (tudoOriginal vigiar originais))

        ---------------------------------------------------------------- PISOS
        InLab_PrefGravar "piso_turbosmooth" "2"
        InLab_FamiliaAtiva = FamTeste polyMin:0 polyMax:10
        local pp = InLab_Otim_Calcular 1 todos
        checar "Tudo no piso: nada alterado depois do cálculo" (tudoOriginal vigiar originais)
        fn depoisDe pp alvo prop = ( local r = undefined; for p in pp where p.alvo == alvo and p.prop == prop do r = p.depois; r )
        checar "Piso do .ini: TurboSmooth para em 2" ((depoisDe pp ts #iterations) == 2)
        checar "Piso: Chamfer para em 1" ((depoisDe pp ch #segments) == (InLab_Otim_Piso "chamfer"))
        checar "Piso: Shell para em 1" ((depoisDe pp sh #segments) == (InLab_Otim_Piso "shell"))
        checar "Piso: lados do cilindro param em 12" ((depoisDe pp d.baseobject #sides) == (InLab_Otim_Piso "lados"))
        checar "Piso: passos da spline sob Extrude param em 2" ((depoisDe pp e2.baseobject #steps) == (InLab_Otim_Piso "spline_passos"))
        checar "Piso do .ini: TurboSmooth já em 2 não é proposto" ((depoisDe pp tsH #iterations) == undefined)
        checar "Tudo no piso: spline renderizável e Chamfer sob TS continuam fora" ((depoisDe pp e.baseobject #steps) == undefined and (depoisDe pp chH #segments) == undefined)
        local pi = for p in pp where p.alvo == d.baseobject and p.prop == #sides collect p
        checar "Instância: lados do cilindro propostos uma vez só" (pi.count == 1)
        checar "Instância: economia conta os 2 nós" (pi.count == 1 and pi[1].trisAntes == (InLab_Otim_Triangulos #(d, d2)) and pi[1].trisAntes == 2 * (InLab_Otim_Triangulos #(d)))
        local okMin = true
        for p in pp where p.depois < 1 do okMin = false
        checar "Nenhuma proposta abaixo de 1" okMin
        for k in chavesIni do InLab_PrefApagar k

        ---------------------------------------------------------------- EXCEÇÃO NO MEIO
        -- O contador falso lança só quando um botão vigiado JÁ ESTÁ alterado
        -- (depois do setProperty da medição), para exercitar a restauração.
        InLab_FamiliaAtiva = fam
        INLAB_TESTE_TRIS_REAL = InLab_Otim_Triangulos
        INLAB_TESTE_VIGIAR = vigiar
        INLAB_TESTE_ORIG = originais
        INLAB_TESTE_ALTERADO = false
        InLab_Otim_Triangulos = fn _trisFalha objs =
        (
            for i = 1 to INLAB_TESTE_VIGIAR.count where (getProperty INLAB_TESTE_VIGIAR[i][1] INLAB_TESTE_VIGIAR[i][2]) != INLAB_TESTE_ORIG[i] do
                INLAB_TESTE_ALTERADO = true
            if INLAB_TESTE_ALTERADO do throw "falha simulada"
            INLAB_TESTE_TRIS_REAL objs
        )
        local px = #(1)
        try ( px = InLab_OtimOrigem_Calcular todos ) catch ( px = #(1) )
        InLab_Otim_Triangulos = INLAB_TESTE_TRIS_REAL
        checar "Exceção no meio: lançada com um botão alterado" INLAB_TESTE_ALTERADO
        checar "Exceção no meio do cálculo: nada proposto" (px.count == 0)
        checar "Exceção no meio do cálculo: tudo restaurado" (tudoOriginal vigiar originais)
        checar "Exceção no meio do cálculo: triângulos iguais" ((InLab_Otim_Triangulos todos) == total0)

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
    InLab_UltimaOtimOrigem = #()
    if INLAB_TESTE_TRIS_REAL != undefined do InLab_Otim_Triangulos = INLAB_TESTE_TRIS_REAL
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
