/*
 tests\test_mapear_classe.ms — teste de functions\fn_mapear_classe.ms
 (classificação da parte e direção do veio). RODAR NUMA CENA VAZIA.
 Resultado: <pasta temp do Max>\inlab_test_mapear_classe.txt (PASS/FAIL por item).
*/
global InLab_ParseJSON, InLab_JSON_Obter, InLab_Log
global InLab_Produto_Texto, InLab_Produto_Booleano, InLab_Produto_Normalizar
global InLab_CaminhoTextura, InLab_Produto_Lista
global INLAB_RWF_SLOTS_DIFUSO
global InLab_Mapear_RegraDaParte, InLab_Mapear_ParteDoMaterial, InLab_Mapear_VeioDaImagem
global InLab_Mapear_DifusoDe, InLab_Mapear_ZerarCache, InLab_Mapear_CacheVeio
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_mapear_classe.txt"
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
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
        flush INLAB_TESTE_SAIDA
        append logsCapturados #(tipo, msg)
    )
    local arquivosTeste = #()

    -- listras horizontais de 4 em 4 px (ou imagem lisa)
    fn gerarImagem nome listras =
    (
        local arq = (getDir #temp) + "\\" + nome
        local bm = dotNetObject "System.Drawing.Bitmap" 128 128
        local claro = (dotNetClass "System.Drawing.Color").FromArgb 230 230 230
        local escuro = (dotNetClass "System.Drawing.Color").FromArgb 40 40 40
        for y = 0 to 127 do
        (
            local c = if listras and (mod (y / 4) 2) == 0 then escuro else claro
            for x = 0 to 127 do bm.SetPixel x y c
        )
        bm.Save arq
        bm.Dispose()
        arq
    )

    try
    (
        fileIn (raiz + @"functions\fn_json.ms")
        fileIn (raiz + @"functions\fn_renomear_produto.ms")
        fileIn (raiz + @"functions\fn_realworldfix.ms")
        fileIn (raiz + @"functions\fn_mapear_classe.ms")

        -- 1. CLASSIFICAÇÃO
        local js = "{\"produtos\": [{\"cod_est\": \"0001\", \"partes\": [" +
            "{\"nome_parte\": \"Estrutura\", \"familia\": \"Madeira\", \"materia\": \"Cedro\", \"material_id\": \"ART_P_Estrutura\"}, " +
            "{\"nome_parte\": \"Pintada\", \"familia\": \"Madeira\", \"materia\": \"Microtextura\", \"material_id\": \"ART_P_Pintada\"}, " +
            "{\"nome_parte\": \"Sola\", \"familia\": \"Soleta\", \"materia\": \"\", \"material_id\": \"ART_Sola\"}, " +
            "{\"nome_parte\": \"Capa\", \"familia\": \"Couro\", \"materia\": \"\", \"material_id\": \"ART_Capa\"}, " +
            "{\"nome_parte\": \"Vidro\", \"familia\": \"Louise\", \"materia\": \"Transparente\", \"material_id\": \"ART_Vidro\"}, " +
            "{\"nome_parte\": \"Vazia\", \"familia\": \"\", \"materia\": \"\", \"material_id\": \"ART_Vazia\"}, " +
            "{\"nome_parte\": \"Bambu\", \"familia\": \"Bambu\", \"materia\": \"\", \"material_id\": \"ART_Bambu\"}, " +
            "{\"nome_parte\": \"Porta\", \"familia\": \"Madeira\", \"materia\": \"Cedro\", \"material_id\": \"ART_Porta\"}, " +
            "{\"nome_parte\": \"Porta_1\", \"familia\": \"\", \"so3d\": true, \"subparte_de\": \"Porta\", \"material_id\": \"ART_Porta_1\"}]}]}"
        local produto = (InLab_Produto_Lista (InLab_ParseJSON js))[1]
        local partes = InLab_JSON_Obter produto "partes"

        checar "Madeira/Cedro -> #madeira" ((InLab_Mapear_RegraDaParte produto partes[1]) == #madeira)
        checar "Madeira/Microtextura -> #pintada" ((InLab_Mapear_RegraDaParte produto partes[2]) == #pintada)
        checar "Soleta -> #tecido" ((InLab_Mapear_RegraDaParte produto partes[3]) == #tecido)
        checar "Couro -> #tecido" ((InLab_Mapear_RegraDaParte produto partes[4]) == #tecido)
        checar "Louise/Transparente -> #liso" ((InLab_Mapear_RegraDaParte produto partes[5]) == #liso)
        checar "familia vazia -> #semFamilia" ((InLab_Mapear_RegraDaParte produto partes[6]) == #semFamilia)
        checar "familia 'Bambu' (desconhecida) -> #semFamilia" ((InLab_Mapear_RegraDaParte produto partes[7]) == #semFamilia)
        checar "so3d Porta_1 herda Madeira da Porta" ((InLab_Mapear_RegraDaParte produto partes[9]) == #madeira)
        local p = InLab_Mapear_ParteDoMaterial produto "ART_P_Estrutura"
        checar "ParteDoMaterial acha ART_P_Estrutura" (p != undefined and (InLab_Produto_Texto p "nome_parte") == "Estrutura")
        checar "ParteDoMaterial acha parte so3d" ((InLab_Mapear_ParteDoMaterial produto "ART_Porta_1") != undefined)
        checar "ParteDoMaterial devolve undefined para material sem parte" ((InLab_Mapear_ParteDoMaterial produto "ART_Nada") == undefined)

        -- 2. VEIO
        InLab_Mapear_ZerarCache()
        local arqH = gerarImagem "inlab_mapear_listras.png" true
        local arqL = gerarImagem "inlab_mapear_lisa.png" false
        append arquivosTeste arqH; append arquivosTeste arqL
        checar "listras horizontais -> #horizontal" ((InLab_Mapear_VeioDaImagem arqH 0.0) == #horizontal)
        checar "mesma imagem com W=90 -> #vertical" ((InLab_Mapear_VeioDaImagem arqH 90.0) == #vertical)
        checar "mesma imagem com W=270 -> #vertical" ((InLab_Mapear_VeioDaImagem arqH 270.0) == #vertical)
        checar "imagem lisa -> #semDirecao" ((InLab_Mapear_VeioDaImagem arqL 0.0) == #semDirecao)
        local r = #semDirecao
        local excecao = false
        try ( r = InLab_Mapear_VeioDaImagem (arqH + ".nao_existe.png") 0.0 ) catch ( excecao = true )
        checar "arquivo inexistente -> #semDirecao sem excecao" (r == #semDirecao and not excecao)
        checar "arquivo inexistente loga #warn" ((for l in logsCapturados where l[1] == #warn collect l).count > 0)
        checar "arquivo nao fica travado (deletavel)" (try ( deleteFile arqH ) catch ( false ))

        -- 3. DIFUSO
        local arq2 = gerarImagem "inlab_mapear_listras2.png" true
        append arquivosTeste arq2
        local bmp = Bitmaptexture filename:arq2
        bmp.coords.W_Angle = 90.0
        local mtl = Standardmaterial diffuseMap:bmp
        local d = InLab_Mapear_DifusoDe mtl
        checar "DifusoDe acha arquivo e W do Bitmaptexture" (d != undefined and d[1] == arq2 and abs(d[2] - 90.0) < 0.01)
        checar "DifusoDe sem mapa -> undefined" ((InLab_Mapear_DifusoDe (Standardmaterial())) == undefined)

        -- 4. WENGÉ (se houver Corona)
        local wenge = ""
        for cand in #(@"C:\Program Files\Chaos\Corona\materials\assets\10eb4f3be7b1.jpg") do
            if wenge == "" and doesFileExist cand do wenge = cand
        if wenge == "" then linha "SKIP  wengé da biblioteca Corona (arquivo não encontrado)"
        else checar "wengé da biblioteca Corona (10eb4f3be7b1.jpg) -> #horizontal" ((InLab_Mapear_VeioDaImagem wenge 0.0) == #horizontal)
    )
    catch
    (
        checar ("EXCECAO: " + getCurrentException()) false
    )

    InLab_Log = logOriginal
    for a in arquivosTeste do try ( deleteFile a ) catch ()
    linha (if INLAB_TESTE_FALHAS == 0 then "RESULTADO: TUDO PASS" else ("RESULTADO: " + INLAB_TESTE_FALHAS as string + " FALHA(S)"))
    close INLAB_TESTE_SAIDA
)
