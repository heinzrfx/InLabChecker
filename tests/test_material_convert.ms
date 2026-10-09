/*
 tests\test_material_convert.ms — teste automático de functions\fn_material_convert.ms
 Cobre o bug #45 (24/Set): histórico de conversão precisa ACUMULAR entre
 chamadas (só o Reverter zera) e reconverter um nó já convertido tem que
 manter o CORONA ORIGINAL como alvo do Reverter, nunca o glTF de uma rodada
 anterior. Também cobre InLab_SetPropSafe logando a falha de setProperty.
 Usa CoronaPhysicalMtl simples (sem mapa procedural) — não exercita o
 caminho de bake (renderMap), que é lento e fora do escopo deste teste.
 24/Set (issue #51): cobre InLab_BakeBaseComAlpha com bitmaps em memória
 (InLab_BitmapDoTexmap substituído no teste): RGB da base + alpha da
 luminância do opacity, e exceção no meio do laço pega (loga #err, devolve
 undefined, não grava PNG) em vez de propagar com os bitmaps abertos.
 RODAR NUMA CENA VAZIA (File > New): cria caixas + materiais de teste e
 apaga tudo no final. Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_material_convert.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log
global InLab_ConverterObjetos, InLab_ReverterConversao, InLab_UltimaConversao
global InLab_SetPropSafe, InLab_BakeBaseComAlpha, InLab_BitmapDoTexmap, InLab_PastaBake
global InLab_ConverterCoronaMtl, InLab_PropSafe, InLab_ResolverClasseGLTF
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
global InLab_ParseJSON, InLab_Produto_Lista, InLab_Produto_EspeciaisDoProduto, InLab_EspecialDoMaterial
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_material_convert.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    local logsCapturados = #() -- #(tipo, msg) de cada chamada, pra checar #err
    InLab_Log = fn _logTeste msg tipo:#info =
    (
        append logsCapturados #(tipo, msg)
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
        flush INLAB_TESTE_SAIDA
    )
    local criados = #()

    try
    (
        -- Corona precisa estar disponível nesta instalação do Max — sem ele
        -- não dá pra validar o comportamento real (CLAUDE.md: nunca fingir
        -- resultado que não rodou).
        local temCorona = try ( CoronaPhysicalMtl != undefined ) catch ( false )
        if not temCorona then
        (
            linha "PULADO — CoronaPhysicalMtl não disponível nesta instalação do Max."
        )
        else
        (
            -- #153: produto (matéria-prima) para palha/cristal na conversão.
            fileIn (raiz + @"functions\fn_json.ms")
            fileIn (raiz + @"functions\fn_renomear_produto.ms")
            fileIn (raiz + @"functions\fn_material_convert.ms")

            local temGLTF = (InLab_ResolverClasseGLTF()) != undefined
            checar "Classe glTF Material resolvida" temGLTF

            if temGLTF do
            (
                -- ===== 1. CONVERTER A, DEPOIS B, E REVERTER: A e B voltam =====
                local matA = CoronaPhysicalMtl name:"corona_A"
                local matB = CoronaPhysicalMtl name:"corona_B"
                local objA = Box name:"obj_A" material:matA
                local objB = Box name:"obj_B" material:matB pos:[40, 0, 0]
                append criados objA
                append criados objB

                InLab_ConverterObjetos #(objA)
                checar "Converter A: 1 registro no histórico" (InLab_UltimaConversao.count == 1)
                checar "Converter A: material do objA mudou" (objA.material != matA)

                InLab_ConverterObjetos #(objB)
                checar "Converter B: histórico ACUMULOU (não perdeu A)" (InLab_UltimaConversao.count == 2)
                checar "Converter B: material do objB mudou" (objB.material != matB)

                InLab_ReverterConversao()
                checar "Reverter: objA volta ao Corona original" (objA.material == matA)
                checar "Reverter: objB volta ao Corona original" (objB.material == matB)
                checar "Reverter: histórico zerado" (InLab_UltimaConversao.count == 0)

                -- ===== 2. CONVERTER A MESMA MATERIAL/NÓ DUAS VEZES: Reverter
                -- volta ao Corona original, não ao glTF da 1ª rodada =====
                local matC = CoronaPhysicalMtl name:"corona_C"
                local objC = Box name:"obj_C" material:matC pos:[80, 0, 0]
                append criados objC

                InLab_ConverterObjetos #(objC)
                checar "Converter C (1ª rodada): 1 registro" (InLab_UltimaConversao.count == 1)
                checar "Converter C (1ª rodada): materialOriginal é o Corona" (InLab_UltimaConversao[1].materialOriginal == matC)
                local gltf1 = objC.material

                InLab_ConverterObjetos #(objC) -- reconverte sem reverter antes
                checar "Converter C (2ª rodada): NÃO duplicou o registro" (InLab_UltimaConversao.count == 1)
                checar "Converter C (2ª rodada): materialOriginal continua o Corona (não o glTF da 1ª)" (InLab_UltimaConversao[1].materialOriginal == matC)
                local gltf2 = objC.material
                checar "Converter C (2ª rodada): gerou um glTF novo (não é o mesmo da 1ª rodada)" (gltf2 != gltf1)
                checar "Converter C (2ª rodada): materialNovo do registro é o da 2ª rodada" (InLab_UltimaConversao[1].materialNovo == gltf2)

                InLab_ReverterConversao()
                checar "Reverter após 2 conversões: objC volta ao Corona original (não ao glTF da 1ª rodada)" (objC.material == matC)
                checar "Reverter após 2 conversões: histórico zerado" (InLab_UltimaConversao.count == 0)

                -- ===== 3. InLab_SetPropSafe loga a falha (não engole o erro) =====
                logsCapturados = #()
                local mAux = CoronaPhysicalMtl name:"corona_setpropsafe" -- material solto, sem nó: nada a apagar
                local usado = InLab_SetPropSafe mAux #(#baseColor) "isso não é uma cor" -- tipo incompatível → setProperty deve falhar
                checar "SetPropSafe: falha não achou candidato válido (usado == undefined)" (usado == undefined)
                local achouErro = false
                for item in logsCapturados where item[1] == #err do achouErro = true
                checar "SetPropSafe: logou a falha com tipo #err" achouErro

                -- ===== 5. VIDRO (06/10/2026, #118 e #119) =====
                -- Roughness do vidro fica o do material (decisão da V-36: valores
                -- livres); transmission sai da refração, inclusive do VRay (cor).
                fn transmissionDe g = InLab_PropSafe g #(#transmission, #transmissionFactor, #transmissionWeight)
                fn roughnessDe g = InLab_PropSafe g #(#roughness, #roughnessFactor)
                local mFosco = CoronaLegacyMtl()
                mFosco.name = "Madeira fosca"
                mFosco.reflectGlossiness = 0.3
                local mJateado = CoronaLegacyMtl()
                mJateado.name = "Vidro Jateado"
                mJateado.reflectGlossiness = 0.3
                mJateado.levelRefract = 1.0
                local gFosco = InLab_ConverterCoronaMtl mFosco 256 false
                local gJateado = InLab_ConverterCoronaMtl mJateado 256 false
                checar ("Vidro jateado mantém o roughness do material (" + (roughnessDe gJateado) as string + " = " + (roughnessDe gFosco) as string + ", não 0,05)") ((roughnessDe gJateado) != undefined and (roughnessDe gJateado) > 0.1 and (abs ((roughnessDe gJateado) - (roughnessDe gFosco))) < 1e-4)
                checar ("Vidro jateado: transmission 1 (" + (transmissionDe gJateado) as string + ")") ((abs ((transmissionDe gJateado) - 1.0)) < 1e-4)
                local mParcial = CoronaPhysicalMtl name:"Cristal parcial"
                mParcial.refractionAmount = 0.6
                checar ("Physical: transmission = refractionAmount 0,6 (" + (transmissionDe (InLab_ConverterCoronaMtl mParcial 256 false)) as string + ")") ((abs ((transmissionDe (InLab_ConverterCoronaMtl mParcial 256 false)) - 0.6)) < 1e-3)
                local mV = try ( VRayMtl() ) catch ( undefined )
                if mV == undefined then checar "VRay — pulado: VRay ausente" true
                else
                (
                    mV.name = "Glass VRay"
                    mV.refraction = color 255 255 255
                    checar ("VRay: refração branca → transmission 1 (" + (transmissionDe (InLab_ConverterCoronaMtl mV 256 false)) as string + ")") ((abs ((transmissionDe (InLab_ConverterCoronaMtl mV 256 false)) - 1.0)) < 1e-3)
                    mV.refraction = color 128 128 128
                    local tCinza = transmissionDe (InLab_ConverterCoronaMtl mV 256 false)
                    checar ("VRay: refração cinza 128 → transmission ~0,5 (" + tCinza as string + ")") ((abs (tCinza - (128.0 / 255.0))) < 1e-2)
                    mV.refraction = color 0 0 0
                    checar ("VRay: refração preta → transmission 0 (" + (transmissionDe (InLab_ConverterCoronaMtl mV 256 false)) as string + ")") ((abs (transmissionDe (InLab_ConverterCoronaMtl mV 256 false))) < 1e-4)
                )

                -- ===== 6. PALHA/CRISTAL PELA MATÉRIA-PRIMA (09/10/2026, #153) =====
                -- Materiais já renomeados para o material_id: o nome não diz mais
                -- que é vidro. A tabela do produto decide; sem produto, o nome.
                local jsMp = "{\"produtos\": [{\"cod_est\": \"0093\", \"nome\": \"MESA\", \"partes\": [" +
                    "{\"nome_parte\": \"Tampo\", \"so3d\": false, \"material_id\": \"ART_E_Tampo\", \"materia_prima\": {\"familia\": \"Vidro\", \"materia\": \"\"}}, " +
                    "{\"nome_parte\": \"Base\", \"so3d\": false, \"material_id\": \"ART_P_Vidro_Fibra\", \"materia_prima\": {\"familia\": \"Fibra de Vidro\", \"materia\": \"\"}}, " +
                    "{\"nome_parte\": \"Assento\", \"so3d\": false, \"material_id\": \"ART_C_Assento\", \"materia_prima\": {\"familia\": \"Malacca / Fibra\", \"materia\": \"\"}}]}]}"
                local prodMp = (InLab_Produto_Lista (InLab_ParseJSON jsMp))[1]
                local tabMp = InLab_Produto_EspeciaisDoProduto prodMp
                checar ("#153: tabela da matéria-prima com as 3 partes (" + tabMp as string + ")") (tabMp.count == 3)
                checar "#153: consulta pela tabela (#materia)" ((InLab_EspecialDoMaterial "ART_E_Tampo" especiais:tabMp) as string == #(#cristal, #materia) as string)
                checar "#153: fora da tabela cai no nome (#nome)" ((InLab_EspecialDoMaterial "Vidro solto" especiais:tabMp) as string == #(#cristal, #nome) as string)
                fn vidroLegacy nome = ( local m = CoronaLegacyMtl(); m.name = nome; m.levelRefract = 1.0; m )
                local mTampo = vidroLegacy "ART_E_Tampo"
                checar "#153: ART_E_Tampo sem produto → transmission 0 (o nome não diz vidro)" ((abs (transmissionDe (InLab_ConverterCoronaMtl mTampo 256 false))) < 1e-4)
                checar "#153: ART_E_Tampo com a matéria-prima Vidro → transmission 1" ((abs ((transmissionDe (InLab_ConverterCoronaMtl mTampo 256 false especiais:tabMp)) - 1.0)) < 1e-4)
                local mFibra = vidroLegacy "ART_P_Vidro_Fibra"
                checar "#153: Fibra de Vidro sem produto → transmission 1 (o nome diz vidro)" ((abs ((transmissionDe (InLab_ConverterCoronaMtl mFibra 256 false)) - 1.0)) < 1e-4)
                checar "#153: Fibra de Vidro com a matéria-prima → transmission 0" ((abs (transmissionDe (InLab_ConverterCoronaMtl mFibra 256 false especiais:tabMp))) < 1e-4)
                local mAssento = CoronaLegacyMtl()
                mAssento.name = "ART_C_Assento"
                local gTrama = InLab_ConverterCoronaMtl mAssento 256 false especiais:tabMp
                checar "#153: Malacca / Fibra → doubleSided" ((InLab_PropSafe gTrama #(#doubleSided, #twoSided)) == true)
                local gTramaSem = InLab_ConverterCoronaMtl mAssento 256 false
                checar "#153: sem produto, ART_C_Assento não é palha" ((InLab_PropSafe gTramaSem #(#doubleSided, #twoSided)) != true)
                -- Ponta a ponta: InLab_ConverterObjetos produto: (Multi/Sub incluso).
                local mm = Multimaterial numsubs:2
                mm.materialList[1] = vidroLegacy "ART_E_Tampo"
                mm.materialList[2] = vidroLegacy "ART_P_Vidro_Fibra"
                local objMp = Box name:"obj_mp" material:mm pos:[120, 0, 0]
                append criados objMp
                InLab_ConverterObjetos #(objMp) produto:prodMp
                checar "#153: ConverterObjetos produto: tampo (sub 1) com transmission 1" ((abs ((transmissionDe objMp.material.materialList[1]) - 1.0)) < 1e-4)
                checar "#153: ConverterObjetos produto: fibra (sub 2) com transmission 0" ((abs (transmissionDe objMp.material.materialList[2])) < 1e-4)
                InLab_ReverterConversao()
                checar "#153: Reverter volta o Multi/Sub original" (objMp.material == mm)
            )

            -- ===== 7. AVISOS DO QUE O glTF NÃO REPRODUZ (09/10/2026, #110) =====
            if temGLTF do
            (
                fn avisou trecho = ( local a = false ; for l in logsCapturados where l[1] == #warn and (findString l[2] trecho) != undefined do a = true ; a )
                fn bmTile nome u v = ( local b = Bitmaptexture() ; b.name = nome ; b.coords.U_Tiling = u ; b.coords.V_Tiling = v ; b )
                -- Triplanar no difuso
                local mTri = CoronaLegacyMtl()
                mTri.name = "mat_tri"
                local tri = CoronaTriplanar()
                tri.texmapX = bmTile "bm_tri" 1 1
                mTri.texmapDiffuse = tri
                logsCapturados = #()
                InLab_ConverterCoronaMtl mTri 64 false
                checar "#110: Triplanar avisa para rodar o Auto UV antes" (avisou "mat_tri (base color): CoronaTriplanar")
                -- Noise 3D no glossiness
                local mNoise = CoronaLegacyMtl()
                mNoise.name = "mat_noise"
                mNoise.texmapReflectGlossiness = Noise()
                logsCapturados = #()
                InLab_ConverterCoronaMtl mNoise 64 false
                checar "#110: Noise em coordenadas 3D avisa" (avisou "mat_noise (roughness): noise em coordenadas 3D")
                -- falloff no difuso
                local mFall = CoronaLegacyMtl()
                mFall.name = "mat_fall"
                mFall.texmapDiffuse = Falloff()
                logsCapturados = #()
                InLab_ConverterCoronaMtl mFall 64 false
                checar "#110: falloff avisa" (avisou "mat_fall (base color): falloff")
                -- tiling 0,7 dentro de procedural: emenda
                local mCC = CoronaLegacyMtl()
                mCC.name = "mat_cc"
                local cc = Color_Correction()
                cc.map = bmTile "bm_07" 0.7 0.7
                mCC.texmapDiffuse = cc
                logsCapturados = #()
                InLab_ConverterCoronaMtl mCC 64 false
                checar "#110: tiling 0,7 dentro de procedural avisa emenda" (avisou "ladrilho bakeado não fecha")
                -- bitmap direto com tiling 2: desde a #163 o tiling vai para o glTF, sem aviso de escala
                local mDir = CoronaLegacyMtl()
                mDir.name = "mat_dir"
                mDir.texmapDiffuse = bmTile "bm_2" 2 2
                logsCapturados = #()
                InLab_ConverterCoronaMtl mDir 64 false
                checar "#110/#163: bitmap direto com tiling 2 não avisa mudança de escala" (not (avisou "muda de escala"))

                -- ===== 8. TILING E OFFSET PARA O glTF (09/10/2026, #163) =====
                local arqT = (getDir #temp) + "\\inlab_t163.jpg"
                local bmT = bitmap 16 16 color:gray filename:arqT
                save bmT ; close bmT
                fn mapaBaseDe g = InLab_PropSafe g #(#baseColorMap, #baseColorTexmap, #base_color_map)
                fn coordsDe t = if t == undefined then "undefined" else (formattedPrint t.coords.U_Tiling format:".2f") + "x" + (formattedPrint t.coords.V_Tiling format:".2f") + " off " + (formattedPrint t.coords.U_Offset format:".2f") + "," + (formattedPrint t.coords.V_Offset format:".2f") + " ch" + t.coords.mapChannel as string
                -- Bitmaptexture direto, tiling 3×5, offset 0,2/0,1
                local mT1 = CoronaLegacyMtl()
                mT1.name = "mat_t1"
                local bT1 = Bitmaptexture filename:arqT
                bT1.coords.U_Tiling = 3 ; bT1.coords.V_Tiling = 5 ; bT1.coords.U_Offset = 0.2 ; bT1.coords.V_Offset = 0.1
                mT1.texmapDiffuse = bT1
                local cT1 = coordsDe (mapaBaseDe (InLab_ConverterCoronaMtl mT1 64 false))
                checar ("#163: Bitmaptexture direto leva tiling e offset (" + cT1 + ")") (cT1 == "3.00x5.00 off 0.20,0.10 ch1")
                -- CoronaBitmap direto, uvwScale 2,5×0,7 e offset 0,13/0,17: mapeamento direto
                local mT2 = CoronaLegacyMtl()
                mT2.name = "mat_t2"
                local cbT = CoronaBitmap()
                cbT.filename = arqT
                cbT.realWorldScale = false
                cbT.uvwScale = [2.5, 0.7, 1] ; cbT.uvwOffset = [0.13, 0.17, 0]
                mT2.texmapDiffuse = cbT
                local cT2 = coordsDe (mapaBaseDe (InLab_ConverterCoronaMtl mT2 64 false))
                checar ("#163: CoronaBitmap leva uvwScale e uvwOffset (" + cT2 + ")") (cT2 == "2.50x0.70 off 0.13,0.17 ch1")
                -- Roughness invertido de um bitmap com tiling 4: bake de um ladrilho + tiling no resultado
                local mT3 = CoronaLegacyMtl()
                mT3.name = "mat_t3"
                local bT3 = Bitmaptexture filename:arqT
                bT3.coords.U_Tiling = 4 ; bT3.coords.V_Tiling = 4
                mT3.texmapReflectGlossiness = bT3
                local gT3 = InLab_ConverterCoronaMtl mT3 64 true
                local cT3 = coordsDe (InLab_PropSafe gT3 #(#roughnessMap, #roughnessTexmap))
                checar ("#163: roughness invertido leva o tiling 4 (" + cT3 + ")") (cT3 == "4.00x4.00 off 0.00,0.00 ch1")
                -- Base e opacity com a mesma transformação: composto de um ladrilho + transformação
                local mT4 = CoronaLegacyMtl()
                mT4.name = "mat_t4"
                local bT4a = Bitmaptexture filename:arqT
                bT4a.coords.U_Tiling = 10 ; bT4a.coords.V_Tiling = 70
                local bT4b = Bitmaptexture filename:arqT
                bT4b.coords.U_Tiling = 10 ; bT4b.coords.V_Tiling = 70
                mT4.texmapDiffuse = bT4a ; mT4.texmapOpacity = bT4b
                local cT4 = coordsDe (mapaBaseDe (InLab_ConverterCoronaMtl mT4 64 true))
                checar ("#163: base+opacity com a mesma transformação levam tiling 10×70 (" + cT4 + ")") (cT4 == "10.00x70.00 off 0.00,0.00 ch1")
                -- Só opacity com tiling (base é cor): idem
                local mT5 = CoronaLegacyMtl()
                mT5.name = "mat_t5"
                local bT5 = Bitmaptexture filename:arqT
                bT5.coords.U_Tiling = 20 ; bT5.coords.V_Tiling = 200
                mT5.texmapOpacity = bT5
                local cT5 = coordsDe (mapaBaseDe (InLab_ConverterCoronaMtl mT5 64 true))
                checar ("#163: só opacity com tiling 20×200 leva a transformação (" + cT5 + ")") (cT5 == "20.00x200.00 off 0.00,0.00 ch1")
                -- Base procedural sem bitmap (falloff) + opacity com tiling: ladrilho + transformação
                local mT7 = CoronaLegacyMtl()
                mT7.name = "mat_t7"
                mT7.texmapDiffuse = Falloff()
                local bT7 = Bitmaptexture filename:arqT
                bT7.coords.U_Tiling = 20 ; bT7.coords.V_Tiling = 200
                mT7.texmapOpacity = bT7
                local cT7 = coordsDe (mapaBaseDe (InLab_ConverterCoronaMtl mT7 64 true))
                checar ("#163: base falloff + opacity 20×200 leva a transformação (" + cT7 + ")") (cT7 == "20.00x200.00 off 0.00,0.00 ch1")
                -- Real-World ligado: não transfere e avisa
                local mT6 = CoronaLegacyMtl()
                mT6.name = "mat_t6"
                local bT6 = Bitmaptexture filename:arqT
                bT6.coords.realWorldScale = true ; bT6.coords.U_Tiling = 50 ; bT6.coords.V_Tiling = 50
                mT6.texmapDiffuse = bT6
                logsCapturados = #()
                local cT6 = coordsDe (mapaBaseDe (InLab_ConverterCoronaMtl mT6 64 false))
                checar ("#163: Real-World não transfere (" + cT6 + ") e avisa para rodar o Auto UV") (cT6 == "1.00x1.00 off 0.00,0.00 ch1" and avisou "rode o Auto UV")
                try ( deleteFile arqT ) catch ()
                -- caso limpo: bitmap direto tiling 1 e procedural com tiling inteiro → sem aviso de #110
                local mOk = CoronaLegacyMtl()
                mOk.name = "mat_ok"
                local cc2 = Color_Correction()
                cc2.map = bmTile "bm_3" 3 3
                mOk.texmapDiffuse = cc2
                mOk.texmapReflectGlossiness = bmTile "bm_1" 1 1
                logsCapturados = #()
                InLab_ConverterCoronaMtl mOk 64 false
                checar "#110: tiling inteiro e bitmap direto com tiling 1 não avisam" (not (avisou "mat_ok ("))
            )

            -- ===== 4. InLab_BakeBaseComAlpha (issue #51) =====
            -- Bitmaps em memória no lugar de InLab_BitmapDoTexmap (sem arquivo
            -- nem renderMap): base 32 px vermelha, opacity 32 px cinza 60.
            local bitmapDoTexmapOriginal = InLab_BitmapDoTexmap
            local arqsTeste = #()
            try
            (
                InLab_BitmapDoTexmap = fn _bmTeste texmap tamanho =
                (
                    if texmap == #base then bitmap tamanho tamanho color:(color 200 10 10)
                    else if texmap == #opac then bitmap tamanho tamanho color:(color 60 60 60)
                    else bitmap (tamanho / 2) (tamanho / 2) color:(color 60 60 60) -- #curto: força exceção no meio do laço
                )
                -- 4a. caminho feliz: PNG com o RGB da base e alpha = luminância do opacity
                local arqOk = InLab_BakeBaseComAlpha #base undefined #opac "inlab_teste_bake_ok" 32
                if arqOk != undefined do append arqsTeste arqOk
                checar "Bake RGBA: devolve o caminho do PNG" (arqOk != undefined and doesFileExist arqOk)
                if arqOk != undefined and doesFileExist arqOk do
                (
                    -- Lido pelo System.Drawing (RGBA do arquivo, sem pré-multiplicar;
                    -- o openBitMap do Max devolve o RGB multiplicado pelo alpha).
                    -- O save do Max aplica a gama de saída no RGB (200 vira ~229 com
                    -- gama 2,2), então a referência é um PNG da cor da base salvo
                    -- pelo próprio Max; o alpha não passa pela gama.
                    local arqRef = (InLab_PastaBake()) + "inlab_teste_bake_ref.png"
                    local bmRef = bitmap 32 32 color:(color 200 10 10) filename:arqRef
                    save bmRef
                    close bmRef
                    append arqsTeste arqRef
                    local bmLido = dotNetObject "System.Drawing.Bitmap" arqOk
                    local px = bmLido.GetPixel 5 7
                    bmLido.Dispose()
                    local bmLidoRef = dotNetObject "System.Drawing.Bitmap" arqRef
                    local pxRef = bmLidoRef.GetPixel 5 7
                    bmLidoRef.Dispose()
                    checar "Bake RGBA: RGB da base preservado" (px.R == pxRef.R and px.G == pxRef.G and px.B == pxRef.B and px.R > px.G)
                    checar "Bake RGBA: alpha = luminância do opacity (60)" (px.A == 60)
                )
                -- 4b. exceção no meio do laço: não propaga, loga #err e devolve undefined
                logsCapturados = #()
                local propagou = false
                local arqFalha = undefined
                try ( arqFalha = InLab_BakeBaseComAlpha #base undefined #curto "inlab_teste_bake_falha" 32 )
                catch ( propagou = true )
                checar "Bake RGBA com exceção no laço: não propaga a exceção" (not propagou)
                checar "Bake RGBA com exceção no laço: devolve undefined" (arqFalha == undefined)
                local achouErroBake = false
                for item in logsCapturados where item[1] == #err and (findString item[2] "FALHA na composição") != undefined do achouErroBake = true
                checar "Bake RGBA com exceção no laço: loga #err" achouErroBake
                local arqNaoCriado = (InLab_PastaBake()) + "inlab_teste_bake_falha.png"
                checar "Bake RGBA com exceção no laço: não grava PNG" (not (doesFileExist arqNaoCriado))
            )
            catch
            (
                INLAB_TESTE_FALHAS += 1
                linha ("EXCEÇÃO no bloco do bake: " + getCurrentException())
            )
            InLab_BitmapDoTexmap = bitmapDoTexmapOriginal
            for a in arqsTeste where doesFileExist a do deleteFile a
        )
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
