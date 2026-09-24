/*
 tests\test_material_utils.ms — teste automático de functions\fn_material_utils.ms
 (issue #43: Detach por Material ID pegava o submaterial pela POSIÇÃO na lista
 em vez de casar pelo materialIDList, igual o Max faz)
 RODAR NUMA CENA VAZIA (File > New): cria caixas Editable Poly + Multi/Sub-
 Object de teste e apaga tudo no final. Scripting > Run Script... > este
 arquivo.
 Resultado: <pasta temp do Max>\inlab_test_material_utils.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes do fileIn rodar.
global InLab_Log, InLab_DetachPorMaterialID, InLab_DetachPorMaterialSelecao, InLab_SubMaterialPorID
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_material_utils.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    local logsCapturados = #()
    InLab_Log = fn _logTeste msg tipo:#info =
    (
        append logsCapturados #(tipo, msg)
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
        flush INLAB_TESTE_SAIDA
    )
    local criados = #()

    -- Acha, numa lista de nós, o único cujo .material é exatamente "alvo".
    fn achaNoPorMaterial lista alvo =
    (
        local r = undefined
        for n in lista where n.material == alvo do r = n
        r
    )

    -- Monta um Box (6 faces quad), converte pra Editable Poly, cria um
    -- Multimaterial com os IDs/nomes dados (materialIDList = ids, NA MESMA
    -- ORDEM da lista de submateriais) e distribui as faces em grupos de 2
    -- por ID. Devolve #(obj, mtl, #(subMtl1, subMtl2, ...)) — subMtl[i] é o
    -- submaterial do ID ids[i].
    fn montarObjMultiSub nome ids p =
    (
        local o = Box name:nome pos:p
        convertToPoly o
        local subs = for id in ids collect (StandardMaterial name:(nome + "_sub" + id as string))
        local mtl = Multimaterial numsubs:ids.count name:(nome + "_multi")
        mtl.materialIDList = ids
        for i = 1 to ids.count do mtl.materialList[i] = subs[i]
        o.material = mtl
        local total = polyop.getNumFaces o
        for f = 1 to total do
        (
            local idx = (ceil (f as float / 2.0)) as integer
            if idx > ids.count do idx = ids.count
            polyop.setFaceMatID o f ids[idx]
        )
        #(o, mtl, subs)
    )

    try
    (
        fileIn (raiz + @"functions\fn_material_utils.ms")

        -- 1. IDs NÃO SEQUENCIAIS 1, 2, 5 — o caso do bug: ID 5 é o 3º slot
        --    (3ª posição), mas materialList[5] está fora do range de um
        --    Multimaterial com 3 slots — o pedaço do ID 5 ficava sem
        --    submaterial (warn).
        local r1 = montarObjMultiSub "objA" #(1, 2, 5) [0,0,0]
        local oA = r1[1]; local subsA = r1[3]
        append criados oA
        local novosA = InLab_DetachPorMaterialID oA
        checar "1,2,5: gera 3 nós (original + 2 detachados)" (novosA.count == 3)
        for n in novosA where isValidNode n and n != oA do append criados n
        checar "1,2,5: pedaço do ID 1 tem o submaterial do ID 1" ((achaNoPorMaterial novosA subsA[1]) != undefined)
        checar "1,2,5: pedaço do ID 2 tem o submaterial do ID 2" ((achaNoPorMaterial novosA subsA[2]) != undefined)
        checar "1,2,5: pedaço do ID 5 tem o submaterial do ID 5 (não undefined)" ((achaNoPorMaterial novosA subsA[3]) != undefined)
        checar "1,2,5: original mantém ID 1 (menor) com o submaterial certo" (oA.material == subsA[1])

        -- 2. IDs NÃO SEQUENCIAIS 3, 7, 9 — o caso "material errado sem
        --    aviso": materialList[3] (por POSIÇÃO) é o submaterial do ID 9,
        --    não do ID 3.
        local r2 = montarObjMultiSub "objB" #(3, 7, 9) [40,0,0]
        local oB = r2[1]; local subsB = r2[3]
        append criados oB
        local novosB = InLab_DetachPorMaterialID oB
        checar "3,7,9: gera 3 nós (original + 2 detachados)" (novosB.count == 3)
        for n in novosB where isValidNode n and n != oB do append criados n
        checar "3,7,9: pedaço do ID 3 tem o submaterial do ID 3 (não o do ID 9)" ((achaNoPorMaterial novosB subsB[1]) != undefined)
        checar "3,7,9: pedaço do ID 7 tem o submaterial do ID 7" ((achaNoPorMaterial novosB subsB[2]) != undefined)
        checar "3,7,9: pedaço do ID 9 tem o submaterial do ID 9" ((achaNoPorMaterial novosB subsB[3]) != undefined)
        checar "3,7,9: original mantém ID 3 (menor) com o submaterial certo" (oB.material == subsB[1])

        -- 3. IDs SEQUENCIAIS 1..3 — já funcionava antes; confirma que
        --    continua funcionando depois da correção.
        local r3 = montarObjMultiSub "objC" #(1, 2, 3) [80,0,0]
        local oC = r3[1]; local subsC = r3[3]
        append criados oC
        local novosC = InLab_DetachPorMaterialID oC
        checar "1,2,3: gera 3 nós (original + 2 detachados)" (novosC.count == 3)
        for n in novosC where isValidNode n and n != oC do append criados n
        checar "1,2,3: pedaço do ID 2 correto" ((achaNoPorMaterial novosC subsC[2]) != undefined)
        checar "1,2,3: pedaço do ID 3 correto" ((achaNoPorMaterial novosC subsC[3]) != undefined)
        checar "1,2,3: original mantém ID 1 (menor) com o submaterial certo" (oC.material == subsC[1])

        -- 4. OBJETO COM MODIFICADOR NO STACK — avisar e pular, sem
        --    colapsar (polyop agiria na base e ignoraria os IDs trocados
        --    pelo modificador).
        local r4 = montarObjMultiSub "objD" #(1, 2) [120,0,0]
        local oD = r4[1]
        append criados oD
        addModifier oD (Bend())
        local nModsAntes = oD.modifiers.count
        local mtlAntes = oD.material
        logsCapturados = #()
        local novosD = InLab_DetachPorMaterialID oD
        checar "com modificador: devolve só o próprio objeto (nada detachado)" (novosD.count == 1 and novosD[1] == oD)
        checar "com modificador: modificador continua no stack (não colapsou)" (oD.modifiers.count == nModsAntes)
        checar "com modificador: material não mudou" (oD.material == mtlAntes)
        local achouWarn = false
        for lg in logsCapturados where lg[1] == #warn and (matchPattern lg[2] pattern:("*" + oD.name + "*")) do achouWarn = true
        checar "com modificador: logou aviso citando o objeto" achouWarn

        -- 5. Ponto de entrada da UI (InLab_DetachPorMaterialSelecao) numa
        --    seleção mista: 1 objeto normal (novo, IDs 1,2,5) + o objeto com
        --    modificador — confirma que a seleção mista processa cada um
        --    com a regra certa sem travar.
        local r5 = montarObjMultiSub "objE" #(1, 2, 5) [160,0,0]
        local oE = r5[1]
        append criados oE
        local totalNos = InLab_DetachPorMaterialSelecao #(oE, oD)
        for n in totalNos where isValidNode n and (findItem criados n) == 0 do append criados n
        checar "seleção mista: objE detachado (3 nós) + objD pulado (1 nó) = 4" (totalNos.count == 4)
        checar "seleção mista: objD ainda com o modificador" (oD.modifiers.count == nModsAntes)
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
