/*
 tests\test_realworldfix.ms — teste automático de functions\fn_realworldfix.ms
 RODAR NUMA CENA VAZIA (File > New), com Corona instalado: cria caixas com
 UVW Map em Real-World e materiais Corona/Standard e apaga tudo no final.
 Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_realworldfix.txt (PASS/FAIL por item).
 O visual (render antes/depois) foi conferido à mão em 22/Set, ver o
 cabeçalho de fn_realworldfix.ms. Aqui confere-se o UV da malha e os bitmaps.
 08/10/2026 (issue #129): sem colapso (modificadores "InLab RWF" vivos),
 instância deduplicada, 2ª rodada sem Xform em dobro, Reverter da rodada e o
 RWF dentro do Auto UV (Desfazer UV desfaz os dois).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_EhGeometria, InLab_Instancias, InLab_RealWorldFix
global InLab_RWF_UltimaRodada, InLab_RWF_Reverter, InLab_AutoUV, InLab_ReverterAutoUV, InLab_UltimoRWF, InLab_UltimoAutoUV
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS, INLAB_TESTE_LOG
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_realworldfix.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    INLAB_TESTE_LOG = #()
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    -- true se alguma linha do log com esse tipo contém o texto
    fn logTem txt tipo =
    (
        local achou = false
        for l in INLAB_TESTE_LOG where l[1] == tipo and (findString l[2] txt) != undefined do achou = true
        achou
    )
    -- UV por canto de face que o objeto tem hoje (colapsa uma cópia)
    fn uvAtual o =
    (
        local c = copy o
        c.material = undefined
        convertToMesh c
        local res = #()
        for f in 1 to c.numfaces do
        (
            local mf = meshop.getMapFace c 1 f
            for k in 1 to 3 do append res (meshop.getMapVert c 1 mf[k])
        )
        delete c
        res
    )
    -- maior erro entre o UV depois e o UV antes ÷ tamanho
    fn erroUV antes depois tam =
    (
        if antes.count != depois.count then 1e9 else
        (
            local e = 0.0
            for i in 1 to antes.count do
                e = amax #(e, abs (depois[i].x - antes[i].x / tam.x), abs (depois[i].y - antes[i].y / tam.y), abs (depois[i].z - antes[i].z))
            e
        )
    )
    fn caixa nome pos maptype:0 dims:1.0 =
    (
        local b = Box name:nome length:80 width:100 height:50 lengthsegs:2 widthsegs:2 heightsegs:2 pos:pos
        local u = Uvwmap maptype:maptype length:dims width:dims height:dims
        addModifier b u
        u.realWorldMapSize = true
        b
    )
    fn coronaRW nome tam ofs =
    (
        local m = CoronaBitmap name:nome
        m.realWorldScale = true
        m.uvwScale = [tam.x, tam.y, 1]
        m.uvwOffset = ofs
        m
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info =
    (
        append INLAB_TESTE_LOG #(tipo, msg)
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
        flush INLAB_TESTE_SAIDA
    )
    local criados = #()

    try
    (
        fileIn (raiz + @"core\utils.ms")
        fileIn (raiz + @"verifications\verif_uv.ms")
        fileIn (raiz + @"functions\fn_autouv.ms")
        fileIn (raiz + @"functions\fn_realworldfix.ms")
        checar "Corona instalado" (CoronaBitmap != undefined and CoronaPhysicalMtl != undefined)

        -- 1. CENA
        -- A: planar, gizmo 1, Bend acima do UVW. Material Corona com difuso
        --    60×40 (offset 15,10), bump 120 e roughness nativo 60×40 (offset 6,4).
        local dif = coronaRW "t_dif" [60,40] [15,10,0]
        local bump = coronaRW "t_bump" [120,120] [0,0,0]
        local rough = Bitmaptexture name:"t_rough"
        rough.coords.realWorldScale = true
        rough.coords.realWorldWidth = 60
        rough.coords.realWorldHeight = 40
        rough.coords.U_Offset = 6
        rough.coords.V_Offset = 4
        local mA = CoronaPhysicalMtl name:"t_mtlA" baseTexmap:dif baseBumpTexmap:bump baseRoughnessTexmap:rough
        local a = caixa "t_A" [0,0,0]
        addModifier a (Bend angle:20)
        a.material = mA
        -- B: box, gizmo 100×80×50, mesmo material, FORA da seleção.
        local b = caixa "t_B" [200,0,0] maptype:4 dims:100.0
        b.material = mA
        -- C: usa o mesmo material sem UVW em Real-World (UV gravado na malha,
        --    caso do objeto já colapsado): entra pelo material, UV ÷ 60×40.
        local c = Box name:"t_C" pos:[400,0,0] mapcoords:true
        c.material = mA
        -- D: sem UVW em Real-World, na seleção (ignorado).
        local d = Box name:"t_D" pos:[600,0,0]
        addModifier d (Uvwmap())
        -- E + E2: instâncias com UVW compartilhado; Multi/Sub com Standard
        --    e difuso nativo 50×50.
        local difE = Bitmaptexture name:"t_difE"
        difE.coords.realWorldScale = true
        difE.coords.realWorldWidth = 50
        difE.coords.realWorldHeight = 50
        local mE = Multimaterial numsubs:2 name:"t_mtlE"
        mE.materialList[1] = StandardMaterial name:"t_stdE" diffuseMap:difE
        local e = caixa "t_E" [800,0,0] maptype:4
        e.material = mE
        local e2 = instance e name:"t_E2" pos:[1000,0,0]
        -- F + F2: CoronaTriplanar (espaço objeto, escala 75, offset 10 em X)
        --    compartilhado; F2 fora da seleção. "CoronaTriplanar name:..."
        --    derruba o Max: criar vazio e setar depois.
        local bmpF = CoronaBitmap name:"t_bmpF"
        local tpF = CoronaTriplanar()
        tpF.name = "t_tpF"
        tpF.texmapX = bmpF
        tpF.onlyTexmapX = true
        tpF.scale = 75.0
        tpF.offset = [10,0,0]
        local mF = CoronaPhysicalMtl name:"t_mtlF" baseTexmap:tpF
        local f = Box name:"t_F" length:80 width:100 height:60 pos:[1200,0,0]
        rotate f (eulerangles 0 0 30)
        f.material = mF
        local f2 = Box name:"t_F2" pos:[1400,0,0]
        f2.material = mF
        -- G: Triplanar em espaço 2 (nó de referência): não é convertido.
        local tpG = CoronaTriplanar()
        tpG.name = "t_tpG"
        tpG.texmapX = CoronaBitmap name:"t_bmpG"
        tpG.space = 2
        local g = Box name:"t_G" pos:[1600,0,0]
        g.material = CoronaPhysicalMtl name:"t_mtlG" baseTexmap:tpG
        criados = #(a, b, c, d, e, e2, f, f2, g)
        -- Um UVW Map criado por script só se ajusta ao objeto na 1ª avaliação
        -- do nó (classof avalia). Sem isso o UV "antes" do D vem de antes do ajuste.
        for o in criados do classof o

        local uvA = uvAtual a
        local uvB = uvAtual b
        local uvE = uvAtual e
        local uvE2 = uvAtual e2
        local uvD = uvAtual d
        local uvC = uvAtual c
        -- UV esperado do F: Box 75 com gizmo girado 180° em Z no pivot, −offset
        local uvFesp = (
            local cf = copy f
            cf.material = undefined
            addModifier cf (Uvwmap maptype:4 length:75 width:75 height:75)
            classof cf
            cf.modifiers[1].gizmo.transform = (rotateZMatrix 180) * (transMatrix [-10,0,0])
            local r = uvAtual cf
            delete cf
            r
        )

        -- 2. RODA na seleção A, D, E, F, G (B, C, E2 e F2 entram pelo material)
        local n = InLab_RealWorldFix #(a, d, e, f, g)

        -- 3. OBJETOS
        -- 08/10/2026 (#129): E2 é instância de E — um modificador só, no stack compartilhado.
        checar ("Retorno: 6 convertidos (A, B, C, E, F, F2; E2 junto com E): " + n as string) (n == 6)
        fn temRWF o = (for m in o.modifiers where matchPattern m.name pattern:"InLab RWF*" collect m).count
        checar "A sem colapso: base Box, UVW + Xform InLab RWF + Bend no stack" (classof a.baseobject == Box and a.modifiers.count == 3 and (temRWF a) == 1)
        checar "A: UV = UV antigo ÷ 60×40 (com Bend acima)" ((erroUV uvA (uvAtual a) [60,40]) < 1e-4)
        checar "B incluído pelo material, sem colapso" (classof b.baseobject == Box and (temRWF b) == 1)
        checar "B: UV = UV antigo ÷ 60×40 (gizmo 100)" ((erroUV uvB (uvAtual b) [60,40]) < 1e-4)
        checar "B: log avisa a inclusão" (logTem "t_B: fora da seleção" #warn)
        checar "C: UV gravado ÷ 60×40, Xform no topo, sem colapso" (classof c.baseobject == Box and (temRWF c) == 1 and (erroUV uvC (uvAtual c) [60,40]) < 1e-4)
        checar "C: log avisa a inclusão" (logTem "t_C: fora da seleção" #warn)
        checar "D: ignorado, UVW Map continua" (d.modifiers.count == 1 and (erroUV uvD (uvAtual d) [1,1]) < 1e-6)
        checar "E: UV ÷ 50 (Multi/Sub, difuso nativo)" ((erroUV uvE (uvAtual e) [50,50]) < 1e-4)
        checar "E2: instância também convertida, sem Xform em dobro" ((erroUV uvE2 (uvAtual e2) [50,50]) < 1e-4)
        checar "E: instância continua instância, um Xform no stack" ((InLab_Instancias e).count == 2 and (temRWF e) == 1 and (temRWF e2) == 1)
        checar "E: log avisa a instância" (logTem "instância de t_E" #info or logTem "instância de t_E2" #info)
        checar "F: sem colapso, UV = Box 75 do Triplanar" (classof f.baseobject == Box and (temRWF f) == 1 and (erroUV uvFesp (uvAtual f) [1,1]) < 1e-4)
        checar "F: Triplanar trocado pelo bitmap no material" (mF.baseTexmap == bmpF and (getClassInstances CoronaTriplanar target:mF).count == 0)
        checar "F2: incluído pelo Triplanar, sem colapso" (classof f2.baseobject == Box and (logTem "t_F2: fora da seleção" #warn))
        checar "G: Triplanar espaço 2 intocado" (classof g.baseobject == Box and g.material.baseTexmap == tpG)

        -- 4. BITMAPS
        checar "Difuso Corona: Real-World off, escala 1" (not dif.realWorldScale and dif.uvwScale == [1,1,1])
        checar "Difuso Corona: offset 15,10 cm → 0.25,0.25" ((distance dif.uvwOffset [0.25,0.25,0]) < 1e-5)
        checar "Bump: Real-World off, escala 1" (not bump.realWorldScale and bump.uvwScale == [1,1,1])
        checar "Bump: log avisa tamanho diferente" (logTem "t_bump: tamanho real" #warn)
        checar "Roughness nativo: Real-World off, tiling 1" (not rough.coords.realWorldScale and rough.coords.U_Tiling == 1.0 and rough.coords.V_Tiling == 1.0)
        checar "Roughness nativo: offset 6,4 cm → 0.1,0.1" ((abs (rough.coords.U_Offset - 0.1)) < 1e-5 and (abs (rough.coords.V_Offset - 0.1)) < 1e-5)
        checar "Difuso nativo E: Real-World off" (not difE.coords.realWorldScale)

        -- 5. NADA A FAZER (a 2ª rodada também não: o UVW Map do A já tem o Xform)
        local rodada1 = InLab_RWF_UltimaRodada
        checar "Seleção sem UVW em Real-World devolve 0" ((InLab_RealWorldFix #(d)) == 0)
        checar "2ª rodada em A/C/E/F não converte de novo (0) nem põe Xform em dobro" \
            ((InLab_RealWorldFix #(a, c, e, f)) == 0 and (temRWF a) == 1 and (temRWF c) == 1 and (temRWF e) == 1)

        -- 6. REVERTER DA RODADA (08/10/2026, #129)
        checar ("Registro: bitmaps, Triplanar e modificadores (" + rodada1.bitmaps.count as string + ", " +
                rodada1.triplanares.count as string + ", " + rodada1.mods.count as string + ")") \
            (rodada1.bitmaps.count == 4 and rodada1.triplanares.count == 1 and rodada1.mods.count == 6)
        InLab_RWF_Reverter rodada1
        checar "Reverter: A volta ao stack original (UVW + Bend) e ao UV antigo" (a.modifiers.count == 2 and (temRWF a) == 0 and (erroUV uvA (uvAtual a) [1,1]) < 1e-6)
        checar "Reverter: C, E e F sem modificador do RWF" ((temRWF c) == 0 and (temRWF e) == 0 and (temRWF f) == 0 and (temRWF f2) == 0)
        checar "Reverter: difuso Corona de volta (Real-World 60×40, offset 15,10)" (dif.realWorldScale and dif.uvwScale == [60,40,1] and (distance dif.uvwOffset [15,10,0]) < 1e-5)
        checar "Reverter: roughness nativo de volta (Real-World, offset 6,4)" (rough.coords.realWorldScale and (abs (rough.coords.U_Offset - 6)) < 1e-5)
        checar "Reverter: Triplanar de volta no material" (mF.baseTexmap == tpF)

        -- 7. DENTRO DO AUTO UV: RWF antes do Unwrap, Desfazer UV desfaz os dois
        local h = Box name:"t_H" length:80 width:100 height:50 lengthsegs:2 widthsegs:2 heightsegs:2 pos:[0,300,0]
        convertToPoly h
        local hu = Uvwmap maptype:0
        addModifier h hu
        hu.realWorldMapSize = true
        local difH = coronaRW "t_difH" [50,50] [0,0,0]
        local mH = CoronaPhysicalMtl name:"t_mtlH" baseTexmap:difH
        h.material = mH
        local h2 = Box name:"t_H2" pos:[200,300,0] mapcoords:true
        h2.material = mH
        append criados h
        append criados h2
        classof h
        local uvH = uvAtual h
        InLab_UltimoRWF = #()
        InLab_UltimoAutoUV = #()
        InLab_AutoUV #(h) resolucao:1024
        checar "Auto UV: Unwrap no topo, RWF abaixo, base continua poly" \
            (h.modifiers[1].name == "InLab AutoUV" and (temRWF h) == 1 and classof h.baseobject == Editable_Poly)
        checar "Auto UV: canal 1 ÷ 50 (RWF rodou)" ((erroUV uvH (uvAtual h) [50,50]) < 1e-4 and not difH.realWorldScale)
        checar "Auto UV: objeto fora da seleção recebe só o RWF" ((temRWF h2) == 1 and (for m in h2.modifiers where m.name == "InLab AutoUV" collect m).count == 0)
        checar "Auto UV: rodada do RWF registrada" (InLab_UltimoRWF.count == 1)
        InLab_AutoUV #(h) resolucao:1024
        checar "Auto UV 2×: um só Xform do RWF e um só Unwrap" ((temRWF h) == 1 and (for m in h.modifiers where m.name == "InLab AutoUV" collect m).count == 1)
        InLab_ReverterAutoUV()
        checar "Desfazer UV: sem Unwrap e sem RWF, UV do material de volta" \
            (h.modifiers.count == 1 and (temRWF h2) == 0 and (erroUV uvH (uvAtual h) [1,1]) < 1e-6)
        checar "Desfazer UV: bitmap de volta em Real-World 50×50" (difH.realWorldScale and difH.uvwScale == [50,50,1])

        -- 8. TRIPLANAR E BITMAP REAL-WORLD NO MESMO CANAL (09/10/2026, #169)
        -- Difuso: CoronaBitmap 300×300 em Real-World no canal 1 (UVW Map RW).
        -- Glossiness: Triplanar de 50 com bitmap também no canal 1. O Box do
        -- Triplanar vai para o canal 2 e o difuso fica no 1, ÷ 300.
        local k = caixa "t_K" [0,600,0] maptype:4
        append criados k
        local difK = coronaRW "t_difK" [300,300] [0,0,0]
        local bmpK = CoronaBitmap name:"t_bmpK"
        local tpK = CoronaTriplanar()
        tpK.name = "t_tpK"
        tpK.texmapX = bmpK
        tpK.onlyTexmapX = true
        tpK.scale = 50.0
        local mK = CoronaLegacyMtl()
        mK.name = "t_mtlK"
        mK.texmapDiffuse = difK
        mK.texmapReflectGlossiness = tpK
        k.material = mK
        local uvK = uvAtual k
        INLAB_TESTE_LOG = #()
        InLab_RealWorldFix #(k)
        local rodK = InLab_RWF_UltimaRodada
        local boxK = (for m in k.modifiers where m.name == "InLab RWF Triplanar" collect m)[1]
        checar "#169: bitmap de dentro do Triplanar passa para o canal 2" (bmpK.uvwChannel == 2)
        checar "#169: Box do Triplanar no canal 2" (boxK != undefined and boxK.mapChannel == 2)
        checar ("#169: canal 1 = UV antigo ÷ 300 (o difuso segue o próprio tamanho)") ((erroUV uvK (uvAtual k) [300,300]) < 1e-4)
        checar "#169: sem o aviso de 'prevalece'" (not (logTem "prevalece" #warn))
        checar "#169: Triplanar trocado pelo bitmap no glossiness" (mK.texmapReflectGlossiness == bmpK)
        InLab_RWF_Reverter rodK
        checar "#169: Desfazer volta o bitmap ao canal 1" (bmpK.uvwChannel == 1)
        checar "#169: Desfazer volta o UV e o Triplanar" ((erroUV uvK (uvAtual k) [1,1]) < 1e-6 and mK.texmapReflectGlossiness == tpK and difK.realWorldScale)
        -- Bitmap de dentro do Triplanar usado também direto no bump: não separa.
        mK.texmapBump = bmpK
        INLAB_TESTE_LOG = #()
        InLab_RealWorldFix #(k)
        local rodK2 = InLab_RWF_UltimaRodada
        checar "#169: bitmap compartilhado fora do Triplanar fica no canal 1, com aviso" (bmpK.uvwChannel == 1 and (logTem "também usado fora dele" #warn))
        InLab_RWF_Reverter rodK2
        mK.texmapBump = undefined
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    for o in criados where isValidNode o do delete o
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
