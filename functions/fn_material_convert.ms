/*
================================================================================
 functions\fn_material_convert.ms — FUNÇÃO 5 (Fase 3.1)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Converte materiais CoronaPhysicalMtl para o glTF Material nativo do 3ds Max
 (2023+), mapeando:
   baseColor/baseTexmap → base color · roughness (com inversão se o Corona
   estiver em modo glossiness) · metalness (modo metal/não-metal) · normal
   (via CoronaNormal) · opacity → alphaMode BLEND · refração → transmission.

 CASOS ESPECIAIS DA SPEC (detectados por palavra-chave no nome do material):
   PALHA ("palha", "trama", "rattan") → alphaMode BLEND + doubleSided
                                         (V-35 → GLB: BLEND + doubleSided)
   CRISTAL ("cristal", "vidro", "glass") → transmission real + roughness
                                            forçado ≤ 0.1 (V-36)

 BAKE (plano, seção Fase 3.1): mapas que NÃO são bitmap simples (procedurais,
 composições) são "achatados" via renderMap() para arquivo em disco.
 LIMITAÇÃO: renderMap avalia o texmap no espaço UV — procedurais 3D
 (coordenadas de objeto/mundo) não bakeiam fielmente por este caminho; o log
 avisa e o resultado deve ser conferido. Bake fiel exigiria Render-To-Texture
 com projeção (fora do escopo desta fase, conforme plano).

 ESTRATÉGIA CONTRA VARIAÇÃO DE API (o risco nº 1 deste módulo):
 Nenhum nome de propriedade é assumido como certo. Toda leitura/escrita passa
 por InLab_PropSafe/InLab_SetPropSafe, que testam uma LISTA de candidatos e
 logam qual nome funcionou. Primeiro teste real = mapa do que a sua build
 do Max 2024 + Corona 12 realmente expõe. Se algo falhar, rodar no Listener:
     showProperties (InLab_ResolverClasseGLTF()())
     showProperties <seu material Corona>
 e me enviar a saída.

 UNDO: mesmo padrão das Funções 1 e 2 — os materiais ORIGINAIS ficam
 registrados e InLab_ReverterConversao() os reatribui.

 CORREÇÃO 24/Set (issue #45): InLab_UltimaConversao zerava a cada chamada de
 InLab_ConverterObjetos — Converter A e depois B fazia o Reverter perder A
 (mesmo bug já corrigido em fn_renomear_produto.ms em 18/Set). Agora o
 histórico ACUMULA e só o Reverter zera. Reconverter um nó já convertido
 (material atual = glTF de uma rodada anterior não revertida) usa o Corona
 ORIGINAL daquele registro — nunca o glTF — e ATUALIZA o registro existente
 em vez de duplicar, para o Reverter sempre voltar ao Corona de verdade.
 InLab_ReverterConversao também apaga os bakes criados em InLab_bake\
 (só os arquivos que o próprio registro de conversão gravou ter criado —
 nunca outro arquivo) e InLab_SetPropSafe loga a falha de setProperty em vez
 de engolir o erro.

 24/Set (issue #51): InLab_BakeBaseComAlpha fecha os bitmaps (base, opacity
 e destino) também quando a exceção vem no meio do laço — antes ficavam
 abertos — e a mensagem de falha leva a exceção. O laço por pixel FICOU:
 medido no Max 2024 (2048 px: ~9,7 s; 4096 px: ~47 s), o tempo é do
 MaxScript por pixel, e a saída do MaxScript (System.Drawing/LockBits) não
 reproduz o resultado: os bitmaps do Max guardam 16 bits por canal
 (getPixels devolve 61,9105) e o alpha é a média desses valores arredondada
 só no save; em 8 bits o alpha mudaria ±1 em parte dos pixels. Gravar o
 alpha na linha da base em vez de criar uma cor por pixel deu o mesmo PNG e
 o mesmo tempo, por isso não entrou.
 24/09/2026 (issue #52, limpeza): InLab_BitmapQuadrado removida — código
 morto, nenhuma chamada (InLab_BitmapDoTexmap é a função em uso).
================================================================================
*/

--------------------------------------------------------------------------------
-- Detecção TOLERANTE de classes Corona: builds diferentes registram nomes
-- com variações (confirmado: Corona 12 do time expõe "_CoronaPhysicalMtl",
-- com underscore). Compara por substring case-insensitive.
--------------------------------------------------------------------------------
fn InLab_ClasseContem obj trecho =
(
    (findString (toLower (classof obj as string)) (toLower trecho)) != undefined
)

-- Registro de conversão por objeto (para o revert).
struct ConversaoRecord
(
    no,                 -- nó da cena
    materialOriginal,   -- material Corona original (preservado em memória)
    materialNovo,       -- material glTF atribuído
    bakes = #()         -- caminhos de arquivo bakeados em InLab_bake\ para este registro
)

global InLab_UltimaConversao = #()
global InLab_ClasseGLTF = undefined   -- cache da classe resolvida
global InLab_BakesDestaConversao = #() -- acumulador temporário: bakes criados na conversão em andamento

--------------------------------------------------------------------------------
-- Resolve a classe do glTF Material testando os nomes conhecidos entre
-- builds do Max. Retorna a classe ou undefined (Max < 2023 / módulo ausente).
--------------------------------------------------------------------------------
fn InLab_ResolverClasseGLTF =
(
    if InLab_ClasseGLTF == undefined do
    (
        -- 1ª tentativa: nomes diretos conhecidos (rápido).
        -- "glTFMaterial" confirmado no Max 2024 do time (log 07/Jul/2026).
        local candidatos = #("glTFMaterial", "gltfMaterial", "glTF_Material", "gltfMtl")
        for nomeCls in candidatos while InLab_ClasseGLTF == undefined do
        (
            local cls = try ( execute nomeCls ) catch ( undefined )
            if cls != undefined and superclassof cls == material do InLab_ClasseGLTF = cls
        )

        -- 2ª tentativa (robusta): varre TODAS as classes de material
        -- registradas no Max procurando "gltf" no nome — independe do
        -- nome exato que a build usa.
        if InLab_ClasseGLTF == undefined do
            for cls in material.classes while InLab_ClasseGLTF == undefined do
            (
                local nomeCls = toLower (cls as string)
                if (findString nomeCls "gltf") != undefined and cls.creatable do
                    InLab_ClasseGLTF = cls
            )

        if InLab_ClasseGLTF != undefined then
            InLab_Log ("Classe glTF Material resolvida: " + (InLab_ClasseGLTF as string)) tipo:#ok
        else
        (
            InLab_Log "Nenhuma classe de material glTF registrada nesta instalação do Max." tipo:#err
            InLab_Log "Diagnóstico: rodar no Listener →  for c in material.classes do format \"%\n\" c" tipo:#err
        )
    )
    InLab_ClasseGLTF
)

--------------------------------------------------------------------------------
-- Leitura segura: retorna o valor da PRIMEIRA propriedade existente da lista
-- de candidatos, ou undefined.
--------------------------------------------------------------------------------
fn InLab_PropSafe obj candidatos =
(
    local valor = undefined
    for c in candidatos while valor == undefined do
        if isProperty obj c do valor = getProperty obj c
    valor
)

--------------------------------------------------------------------------------
-- Escrita segura: seta a PRIMEIRA propriedade existente da lista. Retorna o
-- nome usado (para o log) ou undefined se nenhuma existir.
--------------------------------------------------------------------------------
fn InLab_SetPropSafe obj candidatos valor =
(
    local usado = undefined
    for c in candidatos while usado == undefined do
        if isProperty obj c do
        (
            try ( setProperty obj c valor ; usado = c )
            catch ( InLab_Log ("InLab_SetPropSafe: falha ao setar '" + c as string + "' em " +
                               (classof obj as string) + " — " + (getCurrentException()) as string) tipo:#err )
        )
    usado
)

--------------------------------------------------------------------------------
-- Classifica o material pelos indícios do nome (critério da spec: "materiais
-- cujo slot indica palha/cristal"). Retorna #palha, #cristal ou #nenhum.
--------------------------------------------------------------------------------
fn InLab_DetectarEspecial nomeMtl =
(
    local n = toLower nomeMtl
    local achou = #nenhum
    for kw in #("palha", "trama", "rattan", "wicker", "vime", "straw", "cane") while achou == #nenhum do
        if (findString n kw) != undefined do achou = #palha
    for kw in #("cristal", "vidro", "glass") while achou == #nenhum do
        if (findString n kw) != undefined do achou = #cristal
    achou
)

--------------------------------------------------------------------------------
-- Sanitiza nomes para uso em arquivo/URL: espaços e caracteres especiais
-- (#, acentos etc.) viram "_" — "#" quebra URLs em viewers web de GLB.
--------------------------------------------------------------------------------
fn InLab_NomeSeguro s =
(
    local ok = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
    local saida = ""
    for i = 1 to s.count do
        saida += if (findString ok s[i]) != undefined then s[i] else "_"
    saida
)

--------------------------------------------------------------------------------
-- Pasta de destino dos bakes: <pasta da cena>\InLab_bake\ (cria se preciso).
-- Cena não salva → pasta de export do Max, com aviso.
--------------------------------------------------------------------------------
fn InLab_PastaBake =
(
    local base = if maxFilePath != "" then maxFilePath else ((getDir #export) + "\\")
    if maxFilePath == "" do
        InLab_Log ("Cena não salva — bakes irão para " + base) tipo:#warn
    local pasta = base + "InLab_bake\\"
    if not (doesFileExist pasta) do makeDir pasta all:true
    pasta
)

--------------------------------------------------------------------------------
-- Achata um texmap qualquer para arquivo em disco via renderMap().
-- Formato JPG por padrão (V-24 proíbe PNG); precisaAlpha:true força PNG com
-- aviso — contradição spec registrada como pendência (alpha exige PNG).
-- Retorna o caminho do arquivo ou undefined.
--------------------------------------------------------------------------------
fn InLab_BakeTexmap texmap nomeBase tamanho precisaAlpha:false =
(
    local ext = if precisaAlpha then ".png" else ".jpg"
    if precisaAlpha do
        InLab_Log (nomeBase + ": bake com alpha exige PNG — conflita com V-24; validar com o Birô.") tipo:#warn
    local arq = (InLab_PastaBake()) + (InLab_NomeSeguro nomeBase) + ext
    local ok = undefined
    try
    (
        local bm = renderMap texmap filename:arq size:[tamanho, tamanho] display:false
        save bm
        close bm
        ok = arq
        append InLab_BakesDestaConversao arq
        InLab_Log (nomeBase + ": procedural bakeado em " + tamanho as string + "px → " + arq) tipo:#ok
    )
    catch ( InLab_Log (nomeBase + ": FALHA no renderMap — mapa mantido de fora.") tipo:#err )
    ok
)

--------------------------------------------------------------------------------
-- Converte um texmap de origem em Bitmaptexture pronto para o glTF Material:
--   bitmap simples (Bitmaptexture/CoronaBitmap) → reusa o mesmo arquivo
--   procedural/composição → bake (se habilitado)
-- inverter:true embrulha num mapa Output com invert (caso glossiness→roughness)
-- e força bake, pois o glTF Material precisa de arquivo final.
--------------------------------------------------------------------------------
fn InLab_TexmapParaGLTF texmap nomeBase tamanho fazerBake inverter:false precisaAlpha:false =
(
    local resultado = undefined
    local ehBitmap = (classof texmap == Bitmaptexture) or (InLab_ClasseContem texmap "CoronaBitmap")

    if ehBitmap and not inverter then
    (
        local arq = try ( texmap.filename ) catch ( undefined )
        if arq != undefined and arq != "" do
            resultado = Bitmaptexture filename:arq
    )
    else if fazerBake then
    (
        local fonte = texmap
        if inverter do
        (
            -- Output map com invert: converte mapa de glossiness em roughness.
            local inv = Output()
            inv.map1 = texmap
            inv.output.invert = true
            fonte = inv
            InLab_Log (nomeBase + ": glossiness → roughness via bake invertido.") tipo:#warn
        )
        local arq = InLab_BakeTexmap fonte nomeBase tamanho precisaAlpha:precisaAlpha
        if arq != undefined do resultado = Bitmaptexture filename:arq
    )
    else
        InLab_Log (nomeBase + ": mapa procedural e bake desabilitado — slot ficará vazio.") tipo:#warn

    resultado
)

--------------------------------------------------------------------------------
-- Obtém um bitmap AVALIADO de um texmap, normalizado para tamanho×tamanho:
--   mapa de arquivo (Bitmaptexture/CoronaBitmap) → lê os pixels DIRETO do
--   arquivo em disco (openBitMap + resize via copy). Mapas Corona avaliados
--   por renderMap fora do renderizador Corona podem sair PRETOS — causa da
--   palha 100% transparente no teste de 08/Jul.
--   procedural → renderMap (única opção; limitações já documentadas).
-- Retorna bitmap (responsabilidade do chamador fechar) ou undefined.
--------------------------------------------------------------------------------
fn InLab_BitmapDoTexmap texmap tamanho =
(
    local bmFonte = undefined

    -- Caminho preferencial: pixels do arquivo em disco.
    if (classof texmap == Bitmaptexture) or (InLab_ClasseContem texmap "CoronaBitmap") do
    (
        local arq = try ( texmap.filename ) catch ( undefined )
        if arq != undefined and arq != "" and doesFileExist arq do
            bmFonte = try ( openBitMap arq ) catch ( undefined )
    )

    -- Fallback: avaliação via renderMap (procedurais).
    if bmFonte == undefined do
        bmFonte = try ( renderMap texmap size:[tamanho, tamanho] display:false ) catch ( undefined )

    if bmFonte == undefined then undefined
    else
    (
        -- Normaliza dimensões para o tamanho alvo (copy redimensiona).
        local re = bitmap tamanho tamanho
        copy bmFonte re
        close bmFonte
        re
    )
)

--------------------------------------------------------------------------------
-- COMPOSIÇÃO BASE+ALPHA (correção palha): no glTF a opacidade vive no canal
-- ALPHA da textura de base color — não existe slot separado. Esta função
-- bakeia o base color (mapa ou cor sólida) e o mapa de opacity, e compõe
-- pixel a pixel num único PNG RGBA. Retorna o caminho ou undefined.
-- PNG obrigatório aqui (alpha) — conflito com V-24 registrado como pendência.
--------------------------------------------------------------------------------
fn InLab_BakeBaseComAlpha mapaBase corBase mapaOpac nomeBase tamanho =
(
    local arq = (InLab_PastaBake()) + (InLab_NomeSeguro nomeBase) + ".png"
    local resultado = undefined
    -- 24/Set (#51): declarados fora do try para o catch fechar o que abriu.
    local bmBase = undefined, bmOpac = undefined, destino = undefined
    try
    (
        bmBase = if mapaBase != undefined then (InLab_BitmapDoTexmap mapaBase tamanho) else undefined
        bmOpac = InLab_BitmapDoTexmap mapaOpac tamanho
        if bmOpac == undefined then
        (
            InLab_Log (nomeBase + ": não foi possível avaliar o mapa de opacity — composição abortada.") tipo:#err
            if bmBase != undefined do ( close bmBase ; bmBase = undefined ) -- 24/Set (#51): ficava aberto
        )
        else
        (
            local corFundo = if corBase != undefined then corBase else white
            destino = bitmap tamanho tamanho color:corFundo
            local somaAlpha = 0.0

            for y = 0 to tamanho - 1 do
            (
                local linhaBase = if bmBase != undefined then (getPixels bmBase [0, y] tamanho) else (getPixels destino [0, y] tamanho)
                local linhaOpac = getPixels bmOpac [0, y] tamanho
                local linhaFinal = for x = 1 to tamanho collect
                (
                    -- alpha = luminância do opacity (0-255).
                    local a = (linhaOpac[x].r + linhaOpac[x].g + linhaOpac[x].b) / 3.0
                    somaAlpha += a
                    color linhaBase[x].r linhaBase[x].g linhaBase[x].b a
                )
                setPixels destino [0, y] linhaFinal
            )

            destino.filename = arq
            try ( pngio.setAlpha true ) catch ( InLab_Log (nomeBase + ": pngio.setAlpha indisponível — " + getCurrentException()) tipo:#warn )
            save destino
            close destino
            destino = undefined
            if bmBase != undefined do ( close bmBase ; bmBase = undefined )
            close bmOpac
            bmOpac = undefined

            -- DIAGNÓSTICO: alpha médio do composto. ~0% = tudo transparente,
            -- ~100% = tudo opaco — ambos indicam avaliação errada do opacity.
            local mediaAlpha = 100.0 * somaAlpha / (tamanho * tamanho * 255.0)
            local tipoMedia = if mediaAlpha < 2.0 or mediaAlpha > 98.0 then #warn else #ok
            InLab_Log (nomeBase + ": composto RGBA " + tamanho as string + "px · alpha médio " +
                       (formattedPrint mediaAlpha format:".1f") + "% → " + arq) tipo:tipoMedia
            if tipoMedia == #warn do
                InLab_Log (nomeBase + ": alpha médio extremo — verificar se o mapa de opacity avaliou corretamente.") tipo:#warn
            InLab_Log (nomeBase + ": PNG exigido pelo alpha — conflito com V-24, pendência Birô.") tipo:#warn
            resultado = arq
            append InLab_BakesDestaConversao arq
        )
    )
    catch
    (
        InLab_Log (nomeBase + ": FALHA na composição base+alpha — " + getCurrentException()) tipo:#err
        -- 24/Set (#51): antes os bitmaps ficavam abertos (memória e arquivo) quando
        -- a exceção vinha no meio do laço.
        for bm in #(destino, bmBase, bmOpac) where bm != undefined do
            try ( close bm ) catch ( InLab_Log (nomeBase + ": não foi possível fechar um bitmap da composição — " + getCurrentException()) tipo:#warn )
    )
    resultado
)

--------------------------------------------------------------------------------
-- AUDITORIA PÓS-CONVERSÃO: lê DE VOLTA o glTF Material recém-criado e loga
-- uma linha-resumo do que efetivamente foi preenchido. Transforma qualquer
-- log de sessão em diagnóstico completo, sem rodada extra de teste.
--------------------------------------------------------------------------------
fn InLab_AuditarGLTF g nomeOrigem =
(
    local mapaB = InLab_PropSafe g #(#baseColorMap, #baseColorTexmap, #base_color_map)
    local temBaseMap = mapaB != undefined and superclassof mapaB == textureMap
    local vAlpha     = InLab_PropSafe g #(#alphaMode)
    local vDouble    = InLab_PropSafe g #(#doubleSided, #twoSided)
    local vTransm    = InLab_PropSafe g #(#transmission, #transmissionFactor, #transmissionWeight)
    local vRough     = InLab_PropSafe g #(#roughness, #roughnessFactor)
    local mapaN = InLab_PropSafe g #(#normalMap, #normalTexmap, #normal)
    local temNormal  = mapaN != undefined and superclassof mapaN == textureMap
    InLab_Log ("AUDIT [" + nomeOrigem + "] baseColorMap:" + (if temBaseMap then "SIM" else "NÃO") +
               " · alphaMode:" + (vAlpha as string) +
               " · doubleSided:" + (vDouble as string) +
               " · roughness:" + (vRough as string) +
               " · transmission:" + (vTransm as string) +
               " · normalMap:" + (if temNormal then "SIM" else "NÃO"))
)

--------------------------------------------------------------------------------
-- TIPO DE MATERIAL (bug 4): classifica o material de origem para escolher o
-- perfil de propriedades. Substrings tolerantes a prefixo/sufixo de build.
--------------------------------------------------------------------------------
fn InLab_TipoDeMaterial mtl =
(
    local nomeCls = toLower (classof mtl as string)
    if (findString nomeCls "coronaphysicalmtl") != undefined then #physical
    else if (findString nomeCls "coronalegacymtl") != undefined or nomeCls == "coronamtl" or nomeCls == "_coronamtl" then #legacy
    else if (findString nomeCls "vraymtl") != undefined then #vray
    else #outro
)

--------------------------------------------------------------------------------
-- Converte UM CoronaPhysicalMtl em glTF Material. Retorna o material novo
-- ou undefined (material não-Corona → chamador mantém o original).
--------------------------------------------------------------------------------
fn InLab_ConverterCoronaMtl mtl tamanho fazerBake =
(
    if InLab_ClasseContem mtl "CoronaLayeredMtl" then
    (
        -- Acervo real usa materiais em camadas: converte o material BASE e
        -- descarta as camadas, com aviso. Bake achatado das camadas =
        -- decisão de escopo pendente (Fase 6). [log 08/Jul: #124/#128]
        local baseMtl = InLab_PropSafe mtl #(#baseMtl, #baseMaterial, #base)
        if baseMtl != undefined then
        (
            InLab_Log (mtl.name + ": CoronaLayeredMtl → convertendo o material BASE '" + baseMtl.name + "'; camadas descartadas.") tipo:#warn
            InLab_ConverterCoronaMtl baseMtl tamanho fazerBake
        )
        else
        (
            InLab_Log (mtl.name + ": CoronaLayeredMtl sem material base legível — mantido original.") tipo:#err
            undefined
        )
    )
    else if (InLab_TipoDeMaterial mtl) == #outro then
    (
        InLab_Log (mtl.name + ": tipo não suportado (" + (classof mtl as string) + ") — mantido original. Suportados: CoronaPhysical, CoronaLegacy, VRayMtl.") tipo:#warn
        undefined
    )
    else
    (
        local cls = InLab_ResolverClasseGLTF()
        local g = cls()
        g.name = mtl.name + "_GLTF"
        local especial = InLab_DetectarEspecial mtl.name

        -- ===== PERFIL DE PROPRIEDADES por renderizador (bug 4) =====
        local tipoMtl = InLab_TipoDeMaterial mtl
        local candCor       = #(#baseColor)
        local candMapaBase  = #(#baseTexmap)
        local candValGloss  = #(#baseRoughness, #roughness)
        local candMapaGloss = #(#baseRoughnessTexmap, #roughnessTexmap)
        local candBump      = #(#baseBumpTexmap, #bumpTexmap)
        local candOpacMapa  = #(#opacityTexmap)
        local candRefrVal   = #(#refractionAmount, #refraction)
        local candIOR       = #(#ior)
        case tipoMtl of
        (
            #legacy:
            (
                candCor       = #(#colorDiffuse, #diffuse)
                candMapaBase  = #(#texmapDiffuse)
                candValGloss  = #(#reflectGlossiness, #levelReflectGlossiness)
                candMapaGloss = #(#texmapReflectGlossiness)
                candBump      = #(#texmapBump)
                candOpacMapa  = #(#texmapOpacity)
                candRefrVal   = #(#levelRefract)
                candIOR       = #(#ior, #fresnelIor)
                InLab_Log (mtl.name + ": perfil CoronaLegacyMtl (workflow glossiness).")
            )
            #vray:
            (
                candCor       = #(#diffuse)
                candMapaBase  = #(#texmap_diffuse)
                candValGloss  = #(#reflection_glossiness)
                candMapaGloss = #(#texmap_reflectionGlossiness, #texmap_reflection_glossiness)
                candBump      = #(#texmap_bump)
                candOpacMapa  = #(#texmap_opacity)
                candRefrVal   = #(#refraction_amount)
                candIOR       = #(#refraction_ior)
                InLab_Log (mtl.name + ": perfil VRayMtl (workflow glossiness).")
            )
            default: ()
        )

        ------------------------------------------------------------------
        -- BASE COLOR (valor + mapa) — com composição de alpha quando há
        -- opacity map (no glTF a opacidade vive no alpha do base color).
        ------------------------------------------------------------------
        local corBase  = InLab_PropSafe mtl candCor
        local mapaBase = InLab_PropSafe mtl candMapaBase
        local mapaOpac = InLab_PropSafe mtl candOpacMapa

        if corBase != undefined do
        (
            local usado = InLab_SetPropSafe g #(#baseColor, #baseColorFactor, #base_color) corBase
            if usado == undefined do InLab_Log (mtl.name + ": propriedade de base color não encontrada no glTF Material.") tipo:#err
        )

        if mapaOpac != undefined then
        (
            -- Caminho palha/opacity: composto RGBA único.
            local arqRGBA = InLab_BakeBaseComAlpha mapaBase corBase mapaOpac (mtl.name + "_basecolor_rgba") tamanho
            if arqRGBA != undefined do
            (
                local bmp = Bitmaptexture filename:arqRGBA
                if (InLab_SetPropSafe g #(#baseColorMap, #baseColorTexmap, #base_color_map) bmp) == undefined do
                    InLab_Log (mtl.name + ": slot de base color map não encontrado.") tipo:#err
            )
        )
        else if mapaBase != undefined do
        (
            local bmp = InLab_TexmapParaGLTF mapaBase (mtl.name + "_basecolor") tamanho fazerBake
            if bmp != undefined do
                if (InLab_SetPropSafe g #(#baseColorMap, #baseColorTexmap, #base_color_map) bmp) == undefined do
                    InLab_Log (mtl.name + ": slot de base color map não encontrado.") tipo:#err
        )

        ------------------------------------------------------------------
        -- ROUGHNESS — Corona pode operar em modo glossiness: inverter.
        -- roughnessMode: loga o valor cru para calibrarmos no 1º teste.
        ------------------------------------------------------------------
        -- CONFIRMADO pela equipe (07/Jul/2026): no Corona 12, roughnessMode = 1
        -- significa GLOSSINESS → inverter para roughness. 0 = roughness direto.
        -- Physical: depende do roughnessMode (1 = glossiness, confirmado).
        -- Legacy e VRay: SEMPRE glossiness → sempre inverter.
        local modoRough = InLab_PropSafe mtl #(#roughnessMode)
        local inverter = if tipoMtl == #physical then (modoRough != undefined and modoRough != 0) else true
        if modoRough != undefined do
            InLab_Log (mtl.name + ": roughnessMode cru = " + modoRough as string + (if inverter then " (tratando como glossiness → invertendo)" else " (tratando como roughness)"))
        local valRough  = InLab_PropSafe mtl candValGloss
        local mapaRough = InLab_PropSafe mtl candMapaGloss
        if mapaRough != undefined then
        (
            -- Com MAPA presente, o fator glTF MULTIPLICA o mapa — precisa ser
            -- 1.0, senão anula o mapa (bug do log 08/Jul: glossiness 1.0
            -- invertida virava fator 0.0 = material espelhado).
            local bmp = InLab_TexmapParaGLTF mapaRough (mtl.name + "_roughness") tamanho fazerBake inverter:inverter
            if bmp != undefined do InLab_SetPropSafe g #(#roughnessMap, #roughnessTexmap) bmp
            InLab_SetPropSafe g #(#roughness, #roughnessFactor) 1.0
        )
        else if valRough != undefined do
        (
            local v = if inverter then (1.0 - valRough) else valRough
            InLab_SetPropSafe g #(#roughness, #roughnessFactor) v
        )

        ------------------------------------------------------------------
        -- METALNESS — no CoronaPhysicalMtl é um modo, não um float.
        ------------------------------------------------------------------
        if tipoMtl == #physical then
        (
            local modoMetal = InLab_PropSafe mtl #(#metalnessMode)
            if modoMetal != undefined do
            (
                InLab_Log (mtl.name + ": metalnessMode cru = " + modoMetal as string)
                local ehMetal = ((toLower (modoMetal as string)) == "metal") or (modoMetal == 1)
                InLab_SetPropSafe g #(#metalness, #metallic, #metallicFactor) (if ehMetal then 1.0 else 0.0)
            )
        )
        else if tipoMtl == #vray then
        (
            -- VRayMtl moderno tem metalness float; legacy Corona não tem.
            local vm = InLab_PropSafe mtl #(#metalness)
            InLab_SetPropSafe g #(#metalness, #metallic, #metallicFactor) (if vm != undefined then vm else 0.0)
        )
        else
            InLab_SetPropSafe g #(#metalness, #metallic, #metallicFactor) 0.0

        ------------------------------------------------------------------
        -- NORMAL/BUMP — só CoronaNormal (normal map real) é roteado; bump
        -- escalar não tem equivalente direto no glTF sem bake de normal.
        ------------------------------------------------------------------
        local mapaBump = InLab_PropSafe mtl candBump
        if mapaBump != undefined do
        (
            if (InLab_ClasseContem mapaBump "CoronaNormal") or (InLab_ClasseContem mapaBump "NormalMap") then
            (
                local interno = InLab_PropSafe mapaBump #(#normalTexmap, #normal_map, #normalMap, #map)
                if interno != undefined do
                (
                    local bmp = InLab_TexmapParaGLTF interno (mtl.name + "_normal") tamanho fazerBake
                    if bmp != undefined do InLab_SetPropSafe g #(#normalMap, #normalTexmap, #normal) bmp
                )
            )
            else
                InLab_Log (mtl.name + ": bump escalar (" + (classof mapaBump as string) + ") não convertido — usar CoronaNormal com normal map.") tipo:#warn
        )

        ------------------------------------------------------------------
        -- OPACITY / PALHA (V-35): alphaMode BLEND + doubleSided.
        -- alphaMode varia entre builds (enum/int/string) — três tentativas.
        ------------------------------------------------------------------
        if mapaOpac != undefined or especial == #palha do
        (
            local usadoAM = InLab_SetPropSafe g #(#alphaMode) #blend
            if usadoAM == undefined do usadoAM = InLab_SetPropSafe g #(#alphaMode) 2
            if usadoAM == undefined do usadoAM = InLab_SetPropSafe g #(#alphaMode) "BLEND"
            if usadoAM == undefined then InLab_Log (mtl.name + ": alphaMode não aceito — reportar showProperties do glTF Material.") tipo:#err
            else InLab_Log (mtl.name + ": alphaMode = BLEND.") tipo:#ok

            if especial == #palha do
            (
                if (InLab_SetPropSafe g #(#doubleSided, #twoSided) true) != undefined then
                    InLab_Log (mtl.name + ": PALHA → doubleSided = true (V-35).") tipo:#ok
                else
                    InLab_Log (mtl.name + ": propriedade doubleSided não encontrada (V-35 em risco).") tipo:#err
            )
            if mapaOpac != undefined do
                InLab_Log (mtl.name + ": opacity composto no alpha do base color (RGBA).") tipo:#ok
        )

        ------------------------------------------------------------------
        -- CRISTAL (V-36): transmission real + roughness ≤ 0.1.
        ------------------------------------------------------------------
        if especial == #cristal do
        (
            local refr = InLab_PropSafe mtl candRefrVal
            local peso = if refr != undefined then refr else 1.0
            if (InLab_SetPropSafe g #(#transmission, #transmissionFactor, #transmissionWeight) peso) != undefined then
                InLab_Log (mtl.name + ": CRISTAL → transmission = " + peso as string + " (V-36).") tipo:#ok
            else
                InLab_Log (mtl.name + ": propriedade de transmission não encontrada — pendência KHR_materials_transmission (V-36).") tipo:#err

            local ior = InLab_PropSafe mtl candIOR
            if ior != undefined do InLab_SetPropSafe g #(#ior, #indexOfRefraction) ior

            -- V-36 exige roughness baixo: força se estiver acima.
            local rAtual = InLab_PropSafe g #(#roughness, #roughnessFactor)
            if rAtual != undefined and rAtual > 0.1 do
            (
                InLab_SetPropSafe g #(#roughness, #roughnessFactor) 0.05
                InLab_Log (mtl.name + ": roughness " + rAtual as string + " > 0.1 → forçado 0.05 (V-36).") tipo:#warn
            )
        )

        -- Transmission default do glTFMaterial nesta build = 1.0 (constatado
        -- na auditoria de 08/Jul): se o exportador emitir, TODO material vira
        -- vidro no viewer. Zera explicitamente fora do caso cristal.
        if especial != #cristal do
            InLab_SetPropSafe g #(#transmission, #transmissionFactor, #transmissionWeight) 0.0

        -- Auditoria: registra no log o estado final real do material gerado.
        InLab_AuditarGLTF g mtl.name

        g
    )
)

--------------------------------------------------------------------------------
-- Converte o material de um nó, preservando Multi/Sub-Object (IDs intactos —
-- crítico para as zonas de acabamento da V-37). Retorna material novo ou
-- undefined (nada convertível).
--------------------------------------------------------------------------------
fn InLab_ConverterMaterialNode mtl tamanho fazerBake =
(
    if classof mtl == Multimaterial then
    (
        local novo = Multimaterial numsubs:mtl.numsubs
        try ( novo.materialIDList = mtl.materialIDList ) catch()
        try ( novo.names = mtl.names ) catch()
        novo.name = mtl.name + "_GLTF"
        local converteuAlgum = false
        for i = 1 to mtl.numsubs do
        (
            local sub = mtl.materialList[i]
            if sub != undefined then
            (
                local subNovo = InLab_ConverterCoronaMtl sub tamanho fazerBake
                if subNovo != undefined then ( novo.materialList[i] = subNovo ; converteuAlgum = true )
                else novo.materialList[i] = sub   -- passa o original adiante
            )
        )
        if converteuAlgum then novo else undefined
    )
    else InLab_ConverterCoronaMtl mtl tamanho fazerBake
)

--------------------------------------------------------------------------------
-- Ponto de entrada da UI: converte os materiais dos objetos selecionados.
--------------------------------------------------------------------------------
fn InLab_ConverterObjetos objs tamanhoBake:1024 fazerBake:true =
(
    -- NÃO zera InLab_UltimaConversao aqui — o histórico acumula entre
    -- chamadas, só o Reverter zera (bug #45, mesmo padrão de
    -- fn_renomear_produto.ms). Zerar aqui fazia "Converter A, depois B" e
    -- Reverter perder A.
    local convertidos = 0

    if (InLab_ResolverClasseGLTF()) == undefined then 0
    else
    (
        -- Deduplicação: objetos que compartilham o mesmo material recebem a
        -- MESMA instância convertida (preserva instancing e draw calls).
        local origens = #()
        local novos   = #()
        local bakesGrupo = #()

        undo "InLab Converter Material" on
        (
            for o in objs where o.material != undefined do
            (
                -- Nó já convertido nesta sessão (material atual = glTF de um
                -- registro ainda não revertido)? O ORIGINAL de verdade é o
                -- Corona daquele registro, nunca o glTF da rodada anterior.
                local jaConvertido = undefined
                for r in InLab_UltimaConversao where jaConvertido == undefined and r.no == o and r.materialNovo == o.material do
                    jaConvertido = r

                local orig = if jaConvertido != undefined then jaConvertido.materialOriginal else o.material

                local idx = 0
                for i = 1 to origens.count where origens[i] == orig do idx = i

                local novo = undefined
                local bakesDoGrupo = #()
                if idx > 0 then ( novo = novos[idx]; bakesDoGrupo = bakesGrupo[idx] )
                else
                (
                    InLab_BakesDestaConversao = #()
                    novo = InLab_ConverterMaterialNode orig tamanhoBake fazerBake
                    bakesDoGrupo = InLab_BakesDestaConversao
                    append origens orig
                    append novos novo
                    append bakesGrupo bakesDoGrupo
                )

                if novo != undefined do
                (
                    -- Atualiza o registro existente (mantém o Corona original)
                    -- em vez de duplicar, para o Reverter não se perder.
                    if jaConvertido != undefined then
                    (
                        jaConvertido.materialNovo = novo
                        for b in bakesDoGrupo do appendIfUnique jaConvertido.bakes b
                    )
                    else
                    (
                        local rec = ConversaoRecord()
                        rec.no               = o
                        rec.materialOriginal = orig
                        rec.materialNovo     = novo
                        rec.bakes            = bakesDoGrupo
                        append InLab_UltimaConversao rec
                    )
                    o.material = novo
                    convertidos += 1
                    InLab_Log (o.name + ": material '" + orig.name + "' → '" + novo.name + "'.") tipo:#ok
                )
            )
        )
        InLab_Log ("Conversão: " + convertidos as string + " de " + objs.count as string + " objeto(s).")
        convertidos
    )
)

--------------------------------------------------------------------------------
-- Reverte a última conversão: reatribui os materiais Corona originais.
--------------------------------------------------------------------------------
fn InLab_ReverterConversao =
(
    if InLab_UltimaConversao.count == 0 then
        InLab_Log "Nenhuma conversão registrada nesta sessão para reverter." tipo:#warn
    else
    (
        local revertidos = 0
        local bakesApagados = 0
        undo "InLab Reverter Conversão" on
        (
            for r in InLab_UltimaConversao do
            (
                if isValidNode r.no do
                (
                    r.no.material = r.materialOriginal
                    revertidos += 1
                    InLab_Log (r.no.name + ": material original '" + r.materialOriginal.name + "' restaurado.") tipo:#ok
                )
                -- Apaga só os arquivos que ESTE registro gravou ter bakeado
                -- em InLab_bake\ — nunca outro arquivo da pasta.
                if r.bakes != undefined do
                    for arq in r.bakes where doesFileExist arq do
                    (
                        try
                        (
                            deleteFile arq
                            bakesApagados += 1
                        )
                        catch ( InLab_Log ("Falha ao apagar bake '" + arq + "'.") tipo:#err )
                    )
            )
        )
        InLab_UltimaConversao = #()
        InLab_Log ("Reversão de materiais concluída: " + revertidos as string + " objeto(s) · " +
                   bakesApagados as string + " bake(s) apagado(s).")
    )
)
