/*
 tests\test_prooptimizer.ms — teste automático de functions\fn_prooptimizer.ms
 (issue #42: instâncias recebiam o ProOptimizer duas vezes — stack
 compartilhado empilhava um modificador por nó selecionado.)
 RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt): cria esferas/caixas de teste
 e apaga tudo no final. Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_prooptimizer.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_EhGeometria, InLab_ContarPoligonos
global InLab_InstanciasDoNo, InLab_DeduplicarInstancias
global InLab_ProOptimizer, InLab_ReverterOtimizacao, InLab_UltimaOtimizacao
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_prooptimizer.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    local criados = #()

    try
    (
        fileIn (raiz + @"core\utils.ms")
        fileIn (raiz + @"functions\fn_prooptimizer.ms")

        -- 1. OBJETO SOLTO ------------------------------------------------
        local s1 = Sphere radius:50 segs:24 pos:[0,0,0]
        append criados s1
        local vertAntesS1 = (GetTriMeshFaceCount s1)[2]

        local n1 = InLab_ProOptimizer #(s1) 50.0
        checar "Solto: InLab_ProOptimizer devolve 1" (n1 == 1)
        checar "Solto: 1 modificador no stack" (s1.modifiers.count == 1)
        checar "Solto: reduziu vértices" ((GetTriMeshFaceCount s1)[2] < vertAntesS1)
        checar "Solto: registro com 1 item" (InLab_UltimaOtimizacao.count == 1)

        -- 2. INSTÂNCIAS (bug da issue #42) --------------------------------
        local i1 = Sphere radius:50 segs:24 pos:[200,0,0]
        local i2 = instance i1
        i2.pos = [260,0,0]
        append criados i1
        append criados i2
        local vertAntesI = (GetTriMeshFaceCount i1)[2]

        local n2 = InLab_ProOptimizer #(i1, i2) 50.0
        checar "Instâncias: InLab_ProOptimizer devolve 1 (1 stack, não 2 nós)" (n2 == 1)
        checar "Instâncias: 1 modificador no stack de i1" (i1.modifiers.count == 1)
        checar "Instâncias: mesmo modificador aparece em i2 (stack compartilhado)" (i2.modifiers.count == 1)
        checar "Instâncias: registro com 1 item (por stack, não por nó)" (InLab_UltimaOtimizacao.count == 1)
        local vertDepoisI = (GetTriMeshFaceCount i1)[2]
        local razaoI = vertDepoisI as float / vertAntesI as float
        linha ("      i1: " + vertAntesI as string + " -> " + vertDepoisI as string + " verts (razão " + (formattedPrint razaoI format:".3f") + ")")
        -- Com o bug (2 ProOptimizer empilhados a 50% cada), a razão cairia a
        -- ~0,25; com a correção (1 só), fica em torno de 0,5.
        checar "Instâncias: reduziu ~50% uma vez só (não ~25% dobrado)" (razaoI > 0.35 and razaoI < 0.65)

        -- 3. REVERTER (sobre o estado das instâncias, antes do próximo teste
        --    sobrescrever InLab_UltimaOtimizacao) -------------------------
        InLab_ReverterOtimizacao()
        checar "Reverter: i1 sem modificador" (i1.modifiers.count == 0)
        checar "Reverter: i2 sem modificador (stack compartilhado)" (i2.modifiers.count == 0)
        checar "Reverter: i1 volta ao poly original" ((GetTriMeshFaceCount i1)[2] == vertAntesI)
        checar "Reverter: registro zerado" (InLab_UltimaOtimizacao.count == 0)

        -- 4. GRUPO FECHADO (suspeita descartada na issue: membro de grupo
        --    fechado é otimizado normalmente, e o outro membro não é tocado) --
        local g1 = Sphere radius:50 segs:24 pos:[400,0,0]
        local g2 = Sphere radius:50 segs:24 pos:[460,0,0]
        append criados g1
        append criados g2
        local grp = group #(g1, g2) name:"InLab_Teste_Grupo42"
        setGroupOpen grp false
        checar "Grupo: fechado antes do teste" (not (isOpenGroupHead grp))

        local vertAntesG1 = (GetTriMeshFaceCount g1)[2]
        local vertAntesG2 = (GetTriMeshFaceCount g2)[2]
        local n4 = InLab_ProOptimizer #(g1) 50.0
        checar "Grupo: InLab_ProOptimizer devolve 1" (n4 == 1)
        checar "Grupo: g1 recebeu 1 modificador" (g1.modifiers.count == 1)
        checar "Grupo: g2 (outro membro) não recebeu modificador" (g2.modifiers.count == 0)
        checar "Grupo: g1 reduziu vértices" ((GetTriMeshFaceCount g1)[2] < vertAntesG1)
        checar "Grupo: g2 permanece intacto" ((GetTriMeshFaceCount g2)[2] == vertAntesG2)

        -- Abre e desfaz o grupo antes de apagar os nós na limpeza final.
        setGroupOpen grp true
        ungroup grp
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
