/*
 tests\test_ver_uv.ms — teste de functions\fn_ver_uv.ms (Ver UV: troca o material
 por listras para conferir o mapeamento). RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_ver_uv.txt (PASS/FAIL por item).
 26/10/2026 (Mapear por paineis, Tarefa 5).
*/
global InLab_Log, INLAB_ROOT
global InLab_VerUV_Ligar, InLab_VerUV_Desligar, InLab_VerUV_Ligado
global InLab_VerUV_MaterialDe, InLab_VerUV_Textura
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\inlab_test_ver_uv.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    local logs = #()
    InLab_Log = fn _logTeste msg tipo:#info =
    (
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
        flush INLAB_TESTE_SAIDA
    )
    local rootOriginal = INLAB_ROOT
    local arqMax = (getDir #temp) + "\inlab_test_ver_uv.max"

    try
    (
        if INLAB_ROOT == undefined do INLAB_ROOT = raiz
        resetMaxFile #noPrompt
        fileIn (raiz + "functions\fn_ver_uv.ms")

        local mA = StandardMaterial name:"TESTE_matA"
        local mB = StandardMaterial name:"TESTE_matB"
        local mM = Multimaterial name:"TESTE_multi" numsubs:2
        local b1 = Box name:"TESTE_vu1" pos:[0,0,0]
        local b2 = Box name:"TESTE_vu2" pos:[50,0,0]
        local b3 = Box name:"TESTE_vu3" pos:[100,0,0]
        b1.material = mA; b2.material = mM; b3.material = undefined

        -- 1
        local n = InLab_VerUV_Ligar #(b1, b2)
        checar "Ver UV: liga, troca o material de 2 nós e guarda os originais" \
            (n == 2 and InLab_VerUV_Ligado() and b1.material.name == "InLab Ver UV" and b2.material == b1.material \
             and classof b1.material.diffuseMap == BitmapTexture and b1.material.diffuseMap.coords.mapChannel == 1 \
             and b1.material.diffuseMap.coords.U_Tiling == 3 and b3.material == undefined)
        -- 6
        checar "Ver UV: MaterialDe devolve o original enquanto ligado" \
            (InLab_VerUV_MaterialDe b1 == mA and InLab_VerUV_MaterialDe b2 == mM and InLab_VerUV_MaterialDe b3 == undefined)
        -- 2
        local d = InLab_VerUV_Desligar()
        checar "Ver UV: desliga e devolve exatamente os materiais (inclusive Multi/Sub e undefined)" \
            (d == 2 and not (InLab_VerUV_Ligado()) and b1.material == mA and b2.material == mM and b3.material == undefined \
             and (InLab_VerUV_MaterialDe b1) == mA)
        -- 3
        InLab_VerUV_Ligar #(b1, b3)
        delete b1
        local ok3 = true
        local d3 = 0
        try ( d3 = InLab_VerUV_Desligar() ) catch ( ok3 = false )
        checar "Ver UV: nó apagado com o Ver UV ligado não quebra o Desligar" (ok3 and d3 == 1 and b3.material == undefined)
        -- 4
        b1 = Box name:"TESTE_vu1" pos:[0,0,0]
        b1.material = mA
        InLab_VerUV_Ligar #(b1)
        saveMaxFile arqMax quiet:true
        local nomeAposSalvar = if b1.material != undefined then b1.material.name else "(undefined)"
        resetMaxFile #noPrompt
        loadMaxFile arqMax quiet:true useFileUnits:true
        local c1 = getNodeByName "TESTE_vu1"
        checar "Ver UV: salvar com o Ver UV ligado salva o material original" \
            (c1 != undefined and c1.material != undefined and c1.material.name == "TESTE_matA" and not (InLab_VerUV_Ligado()))
        -- 5
        local b5 = Box name:"TESTE_vu5"
        b5.material = StandardMaterial name:"TESTE_matC"
        InLab_VerUV_Ligar #(b5)
        resetMaxFile #noPrompt
        checar "Ver UV: resetMaxFile desliga" (not (InLab_VerUV_Ligado()) and objects.count == 0)
        -- 7
        INLAB_ROOT = (getDir #temp) + "\inlab_sem_raiz\\"
        local arqGerado = (getDir #temp) + "\inlab_uv_listras.png"
        if doesFileExist arqGerado do deleteFile arqGerado
        local tex = InLab_VerUV_Textura()
        checar "Ver UV: sem o PNG no repo, gera a textura no temp" (tex == arqGerado and doesFileExist arqGerado)
        INLAB_ROOT = if rootOriginal != undefined then rootOriginal else raiz
        checar "Ver UV: com o PNG no repo, usa o do repo" (doesFileExist (InLab_VerUV_Textura()) and (findString (InLab_VerUV_Textura()) "ui\img") != undefined)
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    try ( InLab_VerUV_Desligar() ) catch ()
    INLAB_ROOT = rootOriginal
    InLab_Log = logOriginal
    if doesFileExist arqMax do try ( deleteFile arqMax ) catch ()
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
