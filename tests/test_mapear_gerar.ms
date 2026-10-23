/*
 tests\test_mapear_gerar.ms — teste de functions\fn_mapear_gerar.ms
 (geradores de UV do Mapear: madeira, tubo, box e gravação). RODAR NUMA CENA VAZIA.
 Resultado: <pasta temp do Max>\inlab_test_mapear_gerar.txt (PASS/FAIL por item).
*/
global InLab_Log
global InLab_Mapear_Medir, InLab_Mapear_Motivo, InLab_Mapear_Limite, MapearMedida
global INLAB_MAPEAR_LIMITES, INLAB_MAPEAR_MAX_AMOSTRA, INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
global InLab_Mapear_GerarMadeira, InLab_Mapear_GerarTubo, InLab_Mapear_GerarBox, InLab_Mapear_Gravar
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_mapear_gerar.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info =
    (
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
        flush INLAB_TESTE_SAIDA
    )
    local criados = #()

    -- fração de faces laterais cujo U (dP/dU) é perpendicular ao eixo Z do objeto
    fn fracaoUPerpendicular o =
    (
        local ok = 0; local tot = 0
        for f = 1 to (polyop.getNumFaces o) do
        (
            local n = polyop.getFaceNormal o f
            if (abs n.z) < 0.5 do
            (
                local vs = polyop.getFaceVerts o f
                local mf = polyop.getMapFace o 1 f
                local p1 = polyop.getVert o vs[1]; local e1 = (polyop.getVert o vs[2]) - p1; local e2 = (polyop.getVert o vs[3]) - p1
                local t1 = polyop.getMapVert o 1 mf[1]
                local d1 = (polyop.getMapVert o 1 mf[2]) - t1; local d2 = (polyop.getMapVert o 1 mf[3]) - t1
                local det = d1.x*d2.y - d2.x*d1.y
                if (abs det) > 1e-12 do
                (
                    -- dP/dU = (e1*d2.y - e2*d1.y) / det
                    local dPdu = (e1*d2.y - e2*d1.y) / det
                    tot += 1
                    if (abs dPdu.z) / (length dPdu) < 0.5 do ok += 1
                )
            )
        )
        if tot == 0 then 0.0 else ok as float / tot
    )

    try
    (
        fileIn (raiz + @"functions\fn_mapear_medir.ms")
        fileIn (raiz + @"functions\fn_mapear_gerar.ms")
        local esc = 1.0 / 60

        -- 1. TORO: tubo fechado nas duas direções
        local toro = Torus radius1:30 radius2:3 segments:48 sides:12 name:"TESTE_mg_toro"
        append criados toro
        convertToPoly toro
        local fT = #{1..(polyop.getNumFaces toro)}
        local rT = InLab_Mapear_GerarTubo toro fT esc
        checar "Toro: GerarTubo reconhece" (rT != undefined)
        if rT != undefined do
        (
            checar "Toro: todas as faces no mapa" (rT[2].count == fT.numberSet)
            checar "Toro: Gravar devolve true" (InLab_Mapear_Gravar toro rT[1] rT[2])
            local mT = InLab_Mapear_Medir toro
            linha ("      toro: escala=" + mT.escala as string + " emenda=" + mT.emendaVistaQuebra as string + " esp=" + mT.espelhado as string)
            checar "Toro: emendaVistaQuebra < 1%" (mT.emendaVistaQuebra < 0.01)
            checar "Toro: espelhado == 0" (mT.espelhado == 0.0)
            checar "Toro: escala ≈ pedida (±10%)" (abs (mT.escala - esc) < esc * 0.1)
        )

        -- 1b. EMENDA DO COMPRIMENTO "ATRÁS" (+Y de mundo) com o nó girado e fora da origem
        for ang in #(0, 180) do
        (
            local tr = Torus radius1:30 radius2:3 segments:48 sides:12 name:"TESTE_mg_toro_rot"
            append criados tr
            convertToPoly tr
            tr.rotation = (eulerAngles 0 0 ang)
            tr.pos = [200, -150, 20]
            local fTr = #{1..(polyop.getNumFaces tr)}
            local rTr = InLab_Mapear_GerarTubo tr fTr esc
            -- eixo do comprimento = o de maior extensão do UV; emenda = faces com um vértice no mínimo desse eixo
            local mx = [-1e9,-1e9,0]; local mn = [1e9,1e9,0]
            for uv in rTr[1] do ( mx.x = amax mx.x uv.x; mx.y = amax mx.y uv.y; mn.x = amin mn.x uv.x; mn.y = amin mn.y uv.y )
            local eixoU = (mx.x - mn.x) >= (mx.y - mn.y)
            local minimo = if eixoU then mn.x else mn.y
            -- centro de mundo explícito: centro local * transform do nó
            local yMax = -1e9; local yMin = 1e9
            for f in fTr do
            (
                local cw = (in coordsys local (polyop.getFaceCenter tr f)) * tr.transform
                yMax = amax yMax cw.y; yMin = amin yMin cw.y
            )
            local soma = 0.0; local n = 0
            for e in rTr[2] do
            (
                local naEmenda = false
                for i in e[2] do ( local c = if eixoU then rTr[1][i].x else rTr[1][i].y; if (abs (c - minimo)) < 1e-4 do naEmenda = true )
                if naEmenda do ( soma += ((in coordsys local (polyop.getFaceCenter tr e[1])) * tr.transform).y; n += 1 )
            )
            local yMedio = if n == 0 then 0.0 else soma / n
            local yCentro = (yMax + yMin) / 2; local meia = (yMax - yMin) / 2
            linha ("      toro rot " + ang as string + ": Y de mundo das faces da emenda = " + yMedio as string + " (máx " + yMax as string + ", centro " + yCentro as string + ", faces " + n as string + ")")
            checar ("Toro girado " + ang as string + " graus: emenda do comprimento atrás (+Y de mundo)") (n > 0 and yMedio > yCentro + 0.8 * meia)
        )

        -- 2. TUBO ABERTO COM TAMPAS
        local cil = Cylinder radius:1 height:60 sides:18 heightsegs:5 capsegs:1 mapcoords:true name:"TESTE_mg_tubo"
        append criados cil
        convertToPoly cil
        local nfC = polyop.getNumFaces cil
        local fC = #{1..nfC}
        local rC = InLab_Mapear_GerarTubo cil fC esc
        checar "Tubo aberto com tampas: GerarTubo reconhece" (rC != undefined)
        if rC != undefined do
        (
            local noMapa = #{}
            for e in rC[2] do noMapa[e[1]] = true
            local tampas = #{}; local quads = #{}
            for f in fC do ( if (polyop.getFaceDeg cil f) == 4 then quads[f] = true else tampas[f] = true )
            linha ("      cilindro: faces=" + nfC as string + " quads=" + quads.numberSet as string + " tampas=" + tampas.numberSet as string + " no mapa=" + noMapa.numberSet as string)
            checar "Tubo: há tampas (n-gons/triângulos)" (tampas.numberSet > 0)
            checar "Tubo: tampas fora do mapa" ((noMapa * tampas).numberSet == 0)
            checar "Tubo: todos os quads no mapa" (noMapa.numberSet == quads.numberSet)
            checar "Tubo: Gravar com faces sem mapa (tampas)" (InLab_Mapear_Gravar cil rC[1] rC[2])
            local mC = InLab_Mapear_Medir cil
            checar "Tubo aberto: espelhado == 0" (mC.espelhado == 0.0)
        )

        -- 3. BOX COMUM NÃO É TUBO
        local bx = Box length:50 width:50 height:50 mapcoords:true name:"TESTE_mg_box"
        append criados bx
        convertToPoly bx
        local fB = #{1..(polyop.getNumFaces bx)}
        checar "Box comum: GerarTubo devolve undefined" ((InLab_Mapear_GerarTubo bx fB esc) == undefined)

        -- 4. MADEIRA: cone fino de pé, nó normal e nó espelhado
        local cn = Cone radius1:3 radius2:1.5 height:45 heightsegs:5 sides:24 mapcoords:true name:"TESTE_mg_cone"
        append criados cn
        convertToPoly cn
        local fCone = #{1..(polyop.getNumFaces cn)}
        local rN = InLab_Mapear_GerarMadeira cn fCone esc #horizontal
        checar "Madeira: mapa cobre todas as faces" (rN[2].count == fCone.numberSet)
        InLab_Mapear_Gravar cn rN[1] rN[2]
        local mN = InLab_Mapear_Medir cn
        linha ("      cone horizontal: veioOk=" + mN.veioOk as string + " esp=" + mN.espelhado as string + " escala=" + mN.escala as string)
        checar "Madeira horizontal: veioOk > 0.8" (mN.veioOk > 0.8)
        checar "Madeira horizontal: espelhado == 0" (mN.espelhado == 0.0)
        checar "Madeira: escala ≈ pedida (±15%)" (abs (mN.escala - esc) < esc * 0.15)

        cn.scale = [-1, -1, -1]
        local rN2 = InLab_Mapear_GerarMadeira cn fCone esc #horizontal
        InLab_Mapear_Gravar cn rN2[1] rN2[2]
        local mN2 = InLab_Mapear_Medir cn
        linha ("      cone espelhado (nó): veioOk=" + mN2.veioOk as string + " esp=" + mN2.espelhado as string)
        checar "Nó em scale -1: espelhado == 0" (mN2.espelhado == 0.0)
        checar "Nó em scale -1: veioOk > 0.8" (mN2.veioOk > 0.8)
        cn.scale = [1, 1, 1]

        -- 5. MADEIRA VERTICAL: V segue o comprimento
        local rV = InLab_Mapear_GerarMadeira cn fCone esc #vertical
        InLab_Mapear_Gravar cn rV[1] rV[2]
        local fp = fracaoUPerpendicular cn
        local mV = InLab_Mapear_Medir cn
        linha ("      cone vertical: U perpendicular=" + fp as string + " veioOk=" + mV.veioOk as string + " esp=" + mV.espelhado as string)
        checar "Madeira vertical: U perpendicular ao eixo em > 80% das laterais" (fp > 0.8)
        checar "Madeira vertical: espelhado == 0" (mV.espelhado == 0.0)
        local rS = InLab_Mapear_GerarMadeira cn fCone esc #semDirecao
        InLab_Mapear_Gravar cn rS[1] rS[2]
        checar "semDirecao = horizontal (U ao longo do eixo)" ((fracaoUPerpendicular cn) < 0.2)

        -- 6. BOX
        local rB = InLab_Mapear_GerarBox bx fB esc
        checar "GerarBox: mapa cobre todas as faces" (rB[2].count == fB.numberSet)
        InLab_Mapear_Gravar bx rB[1] rB[2]
        local mB = InLab_Mapear_Medir bx
        linha ("      box: escala=" + mB.escala as string + " emenda=" + mB.emendaVistaQuebra as string + " esp=" + mB.espelhado as string)
        checar "GerarBox: espelhado == 0" (mB.espelhado == 0.0)
        checar "GerarBox: emendaVistaQuebra == 0" (mB.emendaVistaQuebra == 0.0)
        checar "GerarBox: escala ≈ pedida" (abs (mB.escala - esc) < esc * 0.05)
        bx.scale = [-1, 1, 1]
        local rB2 = InLab_Mapear_GerarBox bx fB esc
        InLab_Mapear_Gravar bx rB2[1] rB2[2]
        local mB2 = InLab_Mapear_Medir bx
        checar "GerarBox em nó espelhado: espelhado == 0 " (mB2.espelhado == 0.0)
        bx.scale = [1, 1, 1]

        -- 6b. NÓ FORA DA ORIGEM: o UV é em espaço de objeto (move junto com o nó)
        bx.pos = [300, 200, 10]
        local rBp = InLab_Mapear_GerarBox bx fB esc
        checar "Box fora da origem: UVs iguais aos da origem" ((distance rBp[1][1] rB[1][1]) < 1e-4)
        bx.pos = [0, 0, 0]
        toro.pos = [300, 200, 10]
        local rTp = InLab_Mapear_GerarTubo toro fT esc
        checar "Tubo fora da origem: reconhece e mapa completo" (rTp != undefined and rTp[2].count == fT.numberSet)

        -- 7. GRAVAR: canal novo e faces sem mapa mantêm o UV
        local pl = Box length:10 width:10 height:10 mapcoords:false name:"TESTE_mg_gravar"
        append criados pl
        convertToPoly pl
        polyop.setMapSupport pl 1 false
        local rG = InLab_Mapear_GerarBox pl #{1..3} esc
        checar "Gravar ativa o canal 1 quando falta" (InLab_Mapear_Gravar pl rG[1] rG[2] and (polyop.getMapSupport pl 1))
        local rG2 = InLab_Mapear_GerarBox pl #{1..6} (2 * esc)
        InLab_Mapear_Gravar pl rG2[1] rG2[2]
        local antes = for mv in (polyop.getMapFace pl 1 6) collect (polyop.getMapVert pl 1 mv)
        local rG3 = InLab_Mapear_GerarBox pl #{1..3} (4 * esc)
        InLab_Mapear_Gravar pl rG3[1] rG3[2]
        local depois = for mv in (polyop.getMapFace pl 1 6) collect (polyop.getMapVert pl 1 mv)
        local igual = true
        for k = 1 to antes.count do if (distance antes[k] depois[k]) > 1e-6 do igual = false
        checar "Gravar: face sem mapa mantém o UV atual" igual
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    -- limpeza
    for o in criados where isValidNode o do try ( delete o ) catch ()
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
