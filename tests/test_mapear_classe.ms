/*
 tests\test_mapear_classe.ms — teste de functions\fn_mapear_classe.ms
 (classificação da parte e direção do veio). RODAR NUMA CENA VAZIA.
 Resultado: <pasta temp do Max>\inlab_test_mapear_classe.txt (PASS/FAIL por item).
*/
global InLab_ParseJSON, InLab_JSON_Obter, InLab_Log
global InLab_Produto_Texto, InLab_Produto_Booleano, InLab_Produto_Normalizar
global InLab_CaminhoTextura, InLab_Produto_Lista, InLab_Produto_CarregarEmbutido, InLab_Mapear_MateriaPrima
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
            "{\"nome_parte\": \"Estrutura\", \"materia_prima\": {\"familia\": \"Madeira\", \"materia\": \"Cedro\"}, \"material_id\": \"ART_P_Estrutura\"}, " +
            "{\"nome_parte\": \"Pintada\", \"materia_prima\": {\"familia\": \"Madeira\", \"materia\": \"Microtextura\"}, \"material_id\": \"ART_P_Pintada\"}, " +
            "{\"nome_parte\": \"Sola\", \"materia_prima\": {\"familia\": \"Soleta\", \"materia\": \"\"}, \"material_id\": \"ART_Sola\"}, " +
            "{\"nome_parte\": \"Capa\", \"materia_prima\": {\"familia\": \"Couro\", \"materia\": \"\"}, \"material_id\": \"ART_Capa\"}, " +
            "{\"nome_parte\": \"Vidro\", \"materia_prima\": {\"familia\": \"Louise\", \"materia\": \"Transparente\"}, \"material_id\": \"ART_Vidro\"}, " +
            "{\"nome_parte\": \"Vazia\", \"materia_prima\": {\"familia\": \"\", \"materia\": \"\"}, \"material_id\": \"ART_Vazia\"}, " +
            "{\"nome_parte\": \"Bambu\", \"materia_prima\": {\"familia\": \"Bambu\", \"materia\": \"\"}, \"material_id\": \"ART_Bambu\"}, " +
            "{\"nome_parte\": \"Porta\", \"materia_prima\": {\"familia\": \"Madeira\", \"materia\": \"Cedro\"}, \"material_id\": \"ART_Porta\"}, " +
            "{\"nome_parte\": \"Porta_1\", \"materia_prima\": {\"familia\": \"\", \"materia\": \"\"}, \"so3d\": true, \"subparte_de\": \"Porta\", \"material_id\": \"ART_Porta_1\"}]}]}"
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

        -- 26/10/2026: família lida de materia_prima na lista embutida de verdade
        -- (o JSON acima era montado com familia solta e não pegou o export real).
        local emb = InLab_Produto_CarregarEmbutido raiz:raiz
        local nComFam = 0, semFam = #()
        if emb != undefined do
            for pr in InLab_Produto_Lista emb do
                for pt in (InLab_JSON_Obter pr "partes") where (InLab_Mapear_MateriaPrima pt "familia") != "" do
                (
                    nComFam += 1
                    local fam = InLab_Produto_Normalizar (InLab_Mapear_MateriaPrima pt "familia")
                    if (findItem #("madeira", "tecido", "couro", "soleta", "metal", "fibra de vidro", "louise", "vidro") fam) > 0 and \
                       (InLab_Mapear_RegraDaParte pr pt) == #semFamilia do
                        append semFam ((InLab_Produto_Texto pr "cod_est") + "/" + (InLab_Produto_Texto pt "nome_parte"))
                )
        checar ("lista embutida: partes com materia_prima.familia (" + nComFam as string + ")") (nComFam > 0)
        checar ("lista embutida: família conhecida nunca vira #semFamilia " + semFam as string) (semFam.count == 0)

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

        -- 3a. fix round 1 (23/10/2026): bitmap dentro de mapa intermediario
        local bmpN = Bitmaptexture filename:arq2
        bmpN.coords.W_Angle = 90.0
        local dOut = InLab_Mapear_DifusoDe (Standardmaterial diffuseMap:(Output map1:bmpN))
        checar "DifusoDe: bitmap dentro de Output (W=90)" (dOut != undefined and dOut[1] == arq2 and abs(dOut[2] - 90.0) < 0.01)
        local dCC = InLab_Mapear_DifusoDe (Standardmaterial diffuseMap:(Output map1:(Color_Correction map:(Bitmaptexture filename:arq2))))
        checar "DifusoDe: bitmap dentro de Output > Color_Correction" (dCC != undefined and dCC[1] == arq2)
        checar "DifusoDe: mapa intermediario sem bitmap -> undefined" ((InLab_Mapear_DifusoDe (Standardmaterial diffuseMap:(Output()))) == undefined)

        -- 3b. DIFUSO robusto
        local excD = false
        local dv = undefined
        local rv = #semDirecao
        try
        (
            dv = InLab_Mapear_DifusoDe (Standardmaterial diffuseMap:(Bitmaptexture()))
            if dv != undefined then rv = InLab_Mapear_VeioDaImagem dv[1] dv[2]
        ) catch ( excD = true )
        checar "Bitmaptexture sem arquivo: DifusoDe e VeioDaImagem sem excecao" (not excD and rv == #semDirecao)
        if CoronaBitmap != undefined then
        (
            local cb = CoronaBitmap filename:arq2
            cb.wAngle = 90.0
            local mc = CoronaPhysicalMtl baseTexmap:cb
            local dc = InLab_Mapear_DifusoDe mc
            checar "Corona: CoronaBitmap no difuso (W=90)" (dc != undefined and dc[1] == arq2 and abs(dc[2] - 90.0) < 0.01)
            local tp = CoronaTriplanar()
            tp.texmapX = CoronaBitmap filename:arq2
            local mt = CoronaPhysicalMtl baseTexmap:tp
            local dt = InLab_Mapear_DifusoDe mt
            checar "Corona: CoronaTriplanar com CoronaBitmap dentro" (dt != undefined and dt[1] == arq2)
            if CoronaColorCorrect != undefined do
            (
                local cc = CoronaColorCorrect()
                local cb2 = CoronaBitmap filename:arq2
                setSubTexmap cc 1 cb2
                local dcc = InLab_Mapear_DifusoDe (CoronaLegacyMtl texmapDiffuse:cc)
                checar "Corona: CoronaColorCorrect > CoronaBitmap (caso do Wenge)" (dcc != undefined and dcc[1] == arq2)
            )
        )
        else
        (
            checar "pulado: sem Corona (CoronaBitmap)" true
            checar "pulado: sem Corona (CoronaTriplanar)" true
        )

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
