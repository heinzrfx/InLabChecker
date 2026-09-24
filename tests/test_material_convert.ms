/*
 tests\test_material_convert.ms — teste automático de functions\fn_material_convert.ms
 Cobre o bug #45 (24/Set): histórico de conversão precisa ACUMULAR entre
 chamadas (só o Reverter zera) e reconverter um nó já convertido tem que
 manter o CORONA ORIGINAL como alvo do Reverter, nunca o glTF de uma rodada
 anterior. Também cobre InLab_SetPropSafe logando a falha de setProperty.
 Usa CoronaPhysicalMtl simples (sem mapa procedural) — não exercita o
 caminho de bake (renderMap), que é lento e fora do escopo deste teste.
 RODAR NUMA CENA VAZIA (File > New): cria caixas + materiais de teste e
 apaga tudo no final. Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_material_convert.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log
global InLab_ConverterObjetos, InLab_ReverterConversao, InLab_UltimaConversao
global InLab_SetPropSafe
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
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
            )
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
