/*
 functions\fn_mapear_classe.ms — Mapear: classificação da parte e direção do veio
 Criado em 23/10/2026 (botão Mapear, spec 2026-10-23-mapear-design.md, 5.1 e 5.2).

 O que faz:
   - InLab_Mapear_RegraDaParte produto parte -> #madeira | #pintada | #tecido |
     #liso | #semFamilia, pela família do JSON (tabela da spec 5.1). Madeira com
     matéria "Microtextura" é #pintada (sem veio). Subparte so3d com família
     vazia herda da parte indicada em subparte_de.
   - InLab_Mapear_ParteDoMaterial produto nomeMaterial -> parte (todas, inclusive
     so3d) cujo material_id é o nome, ou undefined.
   - InLab_Mapear_VeioDaImagem arquivo wAngulo -> #horizontal | #vertical |
     #semDirecao. Reduz a imagem para 128x128 e compara a soma de |Δ brilho|
     vertical (gy) com a horizontal (gx): listras horizontais mudam de brilho
     de uma linha para outra (gy alto). gy/gx > 1,15 -> horizontal; < 1/1,15 ->
     vertical. W do bitmap perto de 90/270 graus (±10) troca os dois.
     Falha de leitura -> #semDirecao + #warn (nunca exceção).
   - InLab_Mapear_DifusoDe mtl -> #(arquivo, wAngulo) do bitmap do slot de
     difuso (também dentro de CoronaTriplanar), ou undefined.

 Decisões:
   - O Bitmap original é copiado para um Bitmap novo (já reduzido) e
     descartado na hora com .Dispose(): Bitmap(String) trava o arquivo em disco.
   - Cache por caminho (InLab_Mapear_CacheVeio) guarda a direção BRUTA (sem a
     troca por W), pois o mesmo arquivo pode ter W diferente em cada material.
   - Protótipo validado: wengé 10eb4f3be7b1.jpg gy/gx 1,60 (horizontal); girado
     90 graus 0,63 (vertical).
*/

global InLab_Log, InLab_JSON_Obter, InLab_Produto_Texto, InLab_Produto_Booleano
global InLab_Produto_Normalizar, InLab_CaminhoTextura
global INLAB_RWF_SLOTS_DIFUSO

global INLAB_MAPEAR_VEIO_RAZAO = 1.15
global InLab_Mapear_CacheVeio
global InLab_Mapear_RegraDaParte, InLab_Mapear_ParteDoMaterial
global InLab_Mapear_VeioDaImagem, InLab_Mapear_DifusoDe, InLab_Mapear_ZerarCache
global InLab_Mapear_BitmapDoMapa

fn InLab_Mapear_ZerarCache =
(
    InLab_Mapear_CacheVeio = dotNetObject "System.Collections.Generic.Dictionary`2[System.String,System.String]"
    ok
)
InLab_Mapear_ZerarCache()

-- Família normalizada -> regra (spec 5.1).
fn InLab_Mapear_RegraDaFamilia familia materia =
(
    local f = InLab_Produto_Normalizar familia
    local m = InLab_Produto_Normalizar materia
    if f == "madeira" then (if m == "microtextura" then #pintada else #madeira)
    else if f == "tecido" or f == "couro" or f == "soleta" then #tecido
    else if f == "metal" or f == "fibra de vidro" or f == "louise" or f == "vidro" then #liso
    else #semFamilia
)

fn InLab_Mapear_ParteDoMaterial produto nomeMaterial =
(
    local achada = undefined
    local partes = InLab_JSON_Obter produto "partes"
    if isKindOf partes Array and nomeMaterial != undefined and nomeMaterial != "" do
        for p in partes while achada == undefined do
            if (InLab_Produto_Texto p "material_id") == nomeMaterial do achada = p
    achada
)

fn InLab_Mapear_RegraDaParte produto parte =
(
    local fam = InLab_Produto_Texto parte "familia"
    local mat = InLab_Produto_Texto parte "materia"
    if fam == "" and (InLab_Produto_Booleano parte "so3d") do
    (
        local mae = InLab_Produto_Texto parte "subparte_de"
        local partes = InLab_JSON_Obter produto "partes"
        if mae != "" and isKindOf partes Array do
        (
            local achou = false
            for p in partes while not achou where (InLab_Produto_Texto p "nome_parte") == mae do
            (
                achou = true
                fam = InLab_Produto_Texto p "familia"
                mat = InLab_Produto_Texto p "materia"
            )
        )
    )
    InLab_Mapear_RegraDaFamilia fam mat
)

-- Direção bruta (sem W) de uma imagem; #erro se não leu.
fn InLab_Mapear_VeioBruto arquivo =
(
    local res = #erro
    local orig = undefined
    local bm = undefined
    try
    (
        orig = dotNetObject "System.Drawing.Bitmap" arquivo
        bm = dotNetObject "System.Drawing.Bitmap" orig 128 128
        orig.Dispose(); orig = undefined
        local lum = #()
        for y = 0 to 127 do
        (
            local linha = #()
            for x = 0 to 127 do
            (
                local c = bm.GetPixel x y
                append linha (0.3 * c.R + 0.59 * c.G + 0.11 * c.B)
            )
            append lum linha
        )
        local gx = 0.0
        local gy = 0.0
        for y = 1 to 127 do
            for x = 1 to 127 do
            (
                gx += abs (lum[y][x + 1] - lum[y][x])
                gy += abs (lum[y + 1][x] - lum[y][x])
            )
        local lim = INLAB_MAPEAR_VEIO_RAZAO
        res = #semDirecao
        if gx < 1.0 and gy < 1.0 then res = #semDirecao
        else if gx < 0.0001 then res = #horizontal
        else if gy < 0.0001 then res = #vertical
        else if (gy / gx) > lim then res = #horizontal
        else if (gy / gx) < (1.0 / lim) then res = #vertical
    )
    catch
    (
        InLab_Log ("Veio: não consegui ler a imagem '" + arquivo + "': " + getCurrentException()) tipo:#warn
        res = #erro
    )
    if orig != undefined do try ( orig.Dispose() ) catch ( InLab_Log "Veio: falha ao liberar o bitmap original." tipo:#warn )
    if bm != undefined do try ( bm.Dispose() ) catch ( InLab_Log "Veio: falha ao liberar o bitmap reduzido." tipo:#warn )
    res
)

fn InLab_Mapear_VeioDaImagem arquivo wAngulo =
(
    local caminho = InLab_CaminhoTextura arquivo
    if caminho == "" then
    (
        InLab_Log ("Veio: textura não encontrada (" + (arquivo as string) + "); assumo sem direção.") tipo:#warn
        return #semDirecao
    )
    if InLab_Mapear_CacheVeio == undefined do InLab_Mapear_ZerarCache()
    local bruto = undefined
    local guardado = ""
    if InLab_Mapear_CacheVeio.TryGetValue caminho &guardado then bruto = guardado as name
    else
    (
        bruto = InLab_Mapear_VeioBruto caminho
        InLab_Mapear_CacheVeio.set_Item caminho (bruto as string)
    )
    if bruto == #erro then #semDirecao
    else if bruto == #semDirecao then #semDirecao
    else
    (
        local w = mod (if wAngulo == undefined then 0.0 else wAngulo) 360.0
        if w < 0 do w += 360.0
        local girado = (abs (w - 90.0) <= 10.0) or (abs (w - 270.0) <= 10.0)
        if girado then (if bruto == #horizontal then #vertical else #horizontal)
        else bruto
    )
)

-- Primeiro bitmap (CoronaBitmap/Bitmaptexture) de um mapa, abrindo o triplanar.
fn InLab_Mapear_BitmapDoMapa mapa =
(
    if mapa == undefined then undefined
    else if classof mapa == Bitmaptexture then mapa
    else if CoronaBitmap != undefined and classof mapa == CoronaBitmap then mapa
    else if CoronaTriplanar != undefined and classof mapa == CoronaTriplanar then
    (
        local r = undefined
        for p in #(#texmapX, #texmapY, #texmapZ) while r == undefined do
            if hasProperty mapa p do r = InLab_Mapear_BitmapDoMapa (getProperty mapa p)
        r
    )
    else undefined
)

fn InLab_Mapear_DifusoDe mtl =
(
    local res = undefined
    if mtl != undefined do
    (
        local bmp = undefined
        for p in INLAB_RWF_SLOTS_DIFUSO while bmp == undefined do
            if hasProperty mtl p do bmp = InLab_Mapear_BitmapDoMapa (getProperty mtl p)
        if bmp != undefined do
        (
            if classof bmp == Bitmaptexture then
                res = #(bmp.filename, bmp.coords.W_Angle)
            else
                res = #(bmp.filename, bmp.wAngle)
        )
    )
    res
)
