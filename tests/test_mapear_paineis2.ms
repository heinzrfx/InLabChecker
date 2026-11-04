/*
 tests\test_mapear_paineis2.ms — segunda parte do teste de functions\fn_mapear_paineis.ms:
 InLab_Paineis_CopiaBase (cópia temporária em mundo para o Unfold3D) e a limpeza do temporário
 numa exceção (InLab_Paineis_ForcarFalha, só teste). RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear_paineis2.txt (PASS/FAIL por item).
 27/10/2026 (Mapear assistido, Tarefa 7): saiu o Painéis automático; ficaram só os casos da
 infraestrutura que o Cortar e o Sentido usam. Os demais (pilha, Desfazer, escala por ID,
 Ver UV) estão em test_mapear_cortar.ms e test_mapear_cortar2.ms.
*/
global InLab_Log, InLab_EhGeometria, InLab_Mapear_PolyDe
global InLab_Paineis_Vert, InLab_Paineis_CopiaBase, InLab_Paineis_ForcarFalha, InLab_Paineis_Temp
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\inlab_test_mapear_paineis2.txt"
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
    try
    (
        fileIn (raiz + @"core\utils.ms")
        fileIn (raiz + @"functions\fn_json.ms")
        fileIn (raiz + @"functions\fn_renomear_produto.ms")
        fileIn (raiz + @"functions\fn_autouv.ms")
        fileIn (raiz + @"functions\fn_realworldfix.ms")
        fileIn (raiz + @"functions\fn_mapear_classe.ms")
        fileIn (raiz + @"functions\fn_mapear_medir.ms")
        fileIn (raiz + @"functions\fn_mapear_gerar.ms")
        fileIn (raiz + @"functions\fn_mapear.ms")
        fileIn (raiz + @"functions\fn_ver_uv.ms")
        fileIn (raiz + @"functions\fn_mapear_paineis.ms")

        local b = Box length:30 width:20 height:10 lengthsegs:2 widthsegs:2 heightsegs:2 name:"TESTE_pn2_base" pos:[4000,200,0]
        convertToPoly b
        append criados b
        rotate b (eulerAngles 0 0 30)
        local src = InLab_Paineis_CopiaBase b
        append criados src
        local ok = src != undefined and (polyop.getNumVerts src.baseobject) == (polyop.getNumVerts b.baseobject)
        for v = 1 to (polyop.getNumVerts b.baseobject) while ok do
            if (distance (polyop.getVert src.baseobject v) (InLab_Paineis_Vert b v)) > 1e-3 do ok = false
        checar "CopiaBase: cópia com os vértices em mundo" ok
        checar "CopiaBase: nó temporário na camada 0, visível" (src != undefined and src.layer.name == "0" and not src.isHidden)
        if isValidNode src do delete src

        InLab_Paineis_ForcarFalha = "CopiaBase"
        local exc = undefined
        try ( InLab_Paineis_CopiaBase b ) catch ( exc = getCurrentException() )
        InLab_Paineis_ForcarFalha = undefined
        local sobra = (for o in objects where (matchPattern o.name pattern:"InLab_tmp*") collect o).count
        linha ("      temporários depois da falha: " + sobra as string)
        for o in objects where (matchPattern o.name pattern:"InLab_tmp*") do try ( delete o ) catch ()
        checar "Exceção forçada no CopiaBase relança e não deixa InLab_tmp_*" (exc != undefined and sobra == 0)
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    for o in criados where isValidNode o do try ( delete o ) catch ()
    InLab_Paineis_ForcarFalha = undefined
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
