/*
================================================================================
 functions\fn_checktexture.ms — FUNÇÃO 3 (Fase 1.3)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Varre a cena (ou a seleção) e produz um inventário de texturas:
   - caminho do arquivo e se está MISSING
   - resolução (lida do arquivo em disco via openBitMap, sem carregar na cena)
   - formato, com flag para PNG (proibido pela V-24)
   - quais materiais usam cada textura

 Cobre as duas classes de bitmap do pipeline InLab:
   - Bitmaptexture (nativo do Max)
   - CoronaBitmap  (Corona 12) — detectada dinamicamente: ler uma global
     inexistente em MaxScript retorna undefined (não erro), então sem o
     Corona instalado a classe é simplesmente ignorada.

 DUPLA FUNÇÃO: ferramenta standalone (log) + insumo — retorna um array de
 structs TexturaInfo que as verificações V-23/24/25 (Fase 4) vão consumir
 sem precisar varrer a cena de novo.
================================================================================
*/

-- Inventário de uma textura única (deduplicada por caminho, case-insensitive).
struct TexturaInfo
(
    arquivo,      -- caminho completo do bitmap
    existe,       -- true/false (missing)
    resolucao,    -- point2 (largura, altura) ou undefined se não lida
    formato,      -- extensão em minúsculas, ex.: ".jpg"
    ehPNG,        -- true → alerta V-24
    materiais,    -- array de nomes de materiais que usam a textura
    classes       -- array de classes de mapa que referenciam
)

--------------------------------------------------------------------------------
-- Resolução de um arquivo de imagem em disco. point2 ou undefined.
--------------------------------------------------------------------------------
fn InLab_ResolucaoBitmap arquivo =
(
    local res = undefined
    try
    (
        local b = openBitMap arquivo
        if b != undefined do
        (
            res = point2 b.width b.height
            close b
            free b
        )
    )
    catch ( res = undefined )
    res
)

--------------------------------------------------------------------------------
-- Nomes dos materiais que dependem de um mapa. refs.dependents sobe a cadeia
-- inteira de referências — cobre mapas aninhados (ex.: bitmap dentro de um
-- Mix dentro de um CoronaPhysicalMtl dentro de um Multi/Sub-Object).
--------------------------------------------------------------------------------
fn InLab_MateriaisDoMapa mapa =
(
    local nomes = #()
    for dep in (refs.dependents mapa) where superclassof dep == material do
        appendIfUnique nomes dep.name
    nomes
)

--------------------------------------------------------------------------------
-- true se o mapa é usado por algum dos nós em `objs` — os nós da cena
-- aparecem na cadeia de dependentes do mapa quando o material está aplicado.
--------------------------------------------------------------------------------
fn InLab_MapaUsadoPor mapa objs =
(
    local usa = false
    for dep in (refs.dependents mapa) while not usa do
        if isValidNode dep and (findItem objs dep) > 0 do usa = true
    usa
)

--------------------------------------------------------------------------------
-- Varredura principal.
--   escopo:#cena    → todos os mapas da cena
--   escopo:#selecao → apenas mapas usados pelos objetos em `objs`
-- Retorna array de TexturaInfo e loga o relatório.
--------------------------------------------------------------------------------
fn InLab_CheckTexture escopo:#cena objs:#() =
(
    ----------------------------------------------------------------------
    -- 1. Coleta das instâncias de mapa
    ----------------------------------------------------------------------
    local mapas = #()
    join mapas (getClassInstances Bitmaptexture)
    if CoronaBitmap != undefined do join mapas (getClassInstances CoronaBitmap)

    if escopo == #selecao and objs.count > 0 do
        mapas = for m in mapas where (InLab_MapaUsadoPor m objs) collect m

    if mapas.count == 0 then
    (
        InLab_Log "Check Texture: nenhum bitmap encontrado no escopo." tipo:#warn
        #()
    )
    else
    (
        ------------------------------------------------------------------
        -- 2. Deduplicação por caminho + montagem dos TexturaInfo
        ------------------------------------------------------------------
        local inventario = #()   -- array de TexturaInfo
        local indices    = #()   -- caminhos em minúsculas, paralelo ao inventário

        for m in mapas do
        (
            local caminho = try ( m.filename ) catch ( undefined )
            if caminho != undefined and caminho != "" do
            (
                local chave = toLower caminho
                local idx = findItem indices chave
                if idx == 0 then
                (
                    local ext = toLower (getFilenameType caminho)
                    local info = TexturaInfo()
                    info.arquivo   = caminho
                    info.existe    = doesFileExist caminho
                    info.resolucao = if info.existe then InLab_ResolucaoBitmap caminho else undefined
                    info.formato   = ext
                    info.ehPNG     = (ext == ".png")
                    info.materiais = InLab_MateriaisDoMapa m
                    info.classes   = #(classof m as string)
                    append inventario info
                    append indices chave
                )
                else
                (
                    for nm in (InLab_MateriaisDoMapa m) do appendIfUnique inventario[idx].materiais nm
                    appendIfUnique inventario[idx].classes (classof m as string)
                )
            )
        )

        ------------------------------------------------------------------
        -- 3. Relatório no log
        ------------------------------------------------------------------
        local missing = 0
        local pngs = 0
        InLab_Log ("Check Texture: " + inventario.count as string +
                   " textura(s) única(s) · escopo " + escopo as string + ".")
        for t in inventario do
        (
            local resTxt = if t.resolucao != undefined then
                (((t.resolucao.x as integer) as string) + "x" + ((t.resolucao.y as integer) as string))
                else "n/d"
            local matsTxt = if t.materiais.count > 0 then (t.materiais as string) else "sem material rastreado"

            if not t.existe then
            (
                missing += 1
                InLab_Log ("MISSING · " + t.arquivo + " · usado por " + matsTxt) tipo:#err
            )
            else if t.ehPNG then
            (
                pngs += 1
                InLab_Log ("PNG (proibido V-24) · " + (filenameFromPath t.arquivo) + " · " + resTxt +
                           " · " + matsTxt) tipo:#warn
            )
            else
                InLab_Log ((filenameFromPath t.arquivo) + " · " + t.formato + " · " + resTxt +
                           " · " + matsTxt) tipo:#ok
        )
        local tipoResumo = if missing > 0 then #err else (if pngs > 0 then #warn else #ok)
        InLab_Log ("Resumo: " + missing as string + " missing · " + pngs as string + " PNG(s).") tipo:tipoResumo
        inventario
    )
)
