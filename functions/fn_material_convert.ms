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
   CRISTAL ("cristal", "vidro", "glass") → transmission pela refração do
                                            material; roughness e IOR ficam os
                                            do material (06/10/2026, #119)

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
 06/10/2026 (issue #103): o perfil de propriedades por tipo de material saiu
 de InLab_ConverterCoronaMtl para InLab_Material_PerfilSlots, compartilhado
 com as verificações do grupo 7. Sem mudança de comportamento. Achado na
 sondagem: o VRayMtl não tem refraction_amount (a refração é a cor
 "refraction"), então a conversão ignorava a refração do vidro VRay e dava
 transmission 1.0 a todos.

 06/10/2026 (#118, #119): vidro VRay lê a cor de refração (média dos canais
 → transmission). O roughness do vidro não é mais forçado para 0,05: a V-36
 deixa roughness, IOR e refração livres (vidro jateado é fosco de propósito).
 09/10/2026 (issue #131): o bake sai sempre em INLAB_RESOLUCAO_BAKE (1024,
 definido em fn_autouv.ms); o dropdown de resolução saiu da UI.
 09/10/2026 (issue #153): palha e cristal vêm da matéria-prima da parte do
 produto escolhido (InLab_ConverterObjetos produto:, tabela de
 InLab_Produto_EspeciaisDoProduto), com volta ao nome
 (InLab_EspecialDoMaterial). Antes era só o nome, e depois da renomeação
 para o material_id (ART_*) o vidro saía com transmission 0 e a palha sem
 BLEND/doubleSided. Mesma regra das V-35/V-36.
 09/10/2026 (issue #110, sondagem 2026-10-09-bake-procedurais-sondagem.md):
 o renderMap deu o mesmo resultado com o Corona e com o Scanline nos 138
 slots do piloto (o "preto" era textura ausente, issue #162), e o RWF do
 Auto UV tira todo Triplanar antes da conversão. Sem Render-To-Texture; a
 conversão passa a AVISAR por material e slot (InLab_AvisosDoSlot) o que o
 glTF não reproduz: Triplanar (rodar o Auto UV antes), mapa em coordenada
 3D, falloff, tiling não inteiro dentro de procedural (emenda) e tiling de
 bitmap direto (o glTF Material recebe só o arquivo).
 09/10/2026 (issue #163): o tiling, o offset e o canal do bitmap passam para
 o Bitmaptexture do glTF Material (InLab_AplicarTransform), e o exportador
 do Max grava KHR_texture_transform (testado: tiling 3×5 e offset 0,2 saem
 como scale [3,5] e offset [-0,6, 0]). CoronaBitmap: uvwScale/uvwOffset
 mapeiam direto em U/V_Tiling e U/V_Offset (renderMap idêntico, diferença 0).
 Antes, "Bitmaptexture filename:" zerava a transformação e a textura mudava
 de escala (Puff Pol: tiling 20×200 no opacity). Bitmap de topo com
 transformação é processado SEM ela (ladrilho) e recebe a transformação no
 fim: roughness invertido e base+opacity com a mesma transformação. Base e
 opacity com transformações diferentes: o bake avalia cada um com a sua
 (renderMap), com aviso de resolução. Bitmap ainda em Real-World: não
 transfere e avisa para rodar o Auto UV antes.
 09/10/2026 (issue #162): o arquivo do bitmap é o que o Max resolve pelos
 map paths (InLab_CaminhoTextura, core\utils.ms), e é esse caminho que vai
 para o glTF Material. Textura que não existe: #err por material e slot, e
 o slot fica vazio (antes o GLB apontava para um arquivo inexistente, ou o
 bake de procedural saía preto sem aviso).
 09/10/2026 (issue #169): procedural bakeado vai para o canal dos bitmaps de
 dentro dele, se todos usam o mesmo (o RWF põe o conteúdo do Triplanar no
 canal 2 quando há bitmap em Real-World no canal 1).
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

-- 09/10/2026 (issue #153): #(especial, fonte) do material `nome`. especiais:
-- tabela #(#(material_id, especial), ...) da matéria-prima do produto
-- (InLab_Produto_EspeciaisDoProduto); fonte #materia se veio dela, #nome se
-- caiu nas palavras-chave (InLab_DetectarEspecial).
global InLab_EspecialDoMaterial
fn InLab_EspecialDoMaterial nome especiais:#() =
(
    local e = undefined
    for t in especiais where t[1] == nome do e = t[2]
    if e != undefined then #(e, #materia) else #(InLab_DetectarEspecial nome, #nome)
)

--------------------------------------------------------------------------------
-- 09/10/2026 (issue #110): avisos do que a conversão não reproduz num slot.
-- tm: o mapa do slot; rotulo: "base color", "roughness"... Só loga (#warn).
-- Devolve quantos avisos deu.
--------------------------------------------------------------------------------
global InLab_ArvoreDeMapas
fn InLab_ArvoreDeMapas tm acum =
(
    if tm != undefined and findItem acum tm == 0 do
    (
        append acum tm
        for i = 1 to (getNumSubTexmaps tm) do InLab_ArvoreDeMapas (getSubTexmap tm i) acum
    )
    acum
)

global InLab_AvisosDoSlot
fn InLab_AvisosDoSlot tm nomeMtl rotulo =
(
    local n = 0
    if tm != undefined do
    (
        local pre = nomeMtl + " (" + rotulo + "): "
        local ehBitmap = (classof tm == Bitmaptexture) or (InLab_ClasseContem tm "CoronaBitmap")
        local arvore = InLab_ArvoreDeMapas tm #()
        local vistos = #()
        local triplanar = false, falloffs = false, xyz = #(), tiling = #()
        for t in arvore where findItem vistos t == 0 do
        (
            append vistos t
            local cn = (classof t) as string
            if matchPattern cn pattern:"*Triplanar*" do triplanar = true
            if (classof t) == Falloff do falloffs = true
            local co = try ( t.coords ) catch ( undefined )
            if co != undefined and (classof co) == StandardXYZGen do appendIfUnique xyz cn
            -- tiling do bitmap: U_Tiling (Bitmaptexture) ou uvwScale (CoronaBitmap)
            local tu = undefined, tv = undefined
            if classof t == Bitmaptexture then ( tu = t.coords.U_Tiling ; tv = t.coords.V_Tiling )
            else if InLab_ClasseContem t "CoronaBitmap" do ( local s = try ( t.uvwScale ) catch ( undefined ) ; if s != undefined do ( tu = s.x ; tv = s.y ) )
            if tu != undefined do
            (
                local nome = try ( filenameFromPath t.filename ) catch ( t.name )
                local inteiro = (abs (tu - (floor (tu + 0.5)))) < 1e-3 and (abs (tv - (floor (tv + 0.5)))) < 1e-3
                -- #163: o bitmap direto leva o tiling para o glTF; só o de dentro
                -- de procedural (bakeado no 0–1) avisa.
                if not (ehBitmap and t == tm) and not inteiro do
                    append tiling (nome + " com tiling " + (formattedPrint tu format:".2f") + "×" + (formattedPrint tv format:".2f") + " dentro de procedural: o ladrilho bakeado não fecha (emenda no GLB)")
            )
        )
        if triplanar do ( InLab_Log (pre + "CoronaTriplanar no mapa — rode o Auto UV antes de converter (o Real World Fix troca o Triplanar por UVW Map); convertido assim, a textura sai numa projeção errada.") tipo:#warn ; n += 1 )
        for c in xyz do ( InLab_Log (pre + c + " em coordenadas 3D — o bake sai sem o padrão.") tipo:#warn ; n += 1 )
        if falloffs do ( InLab_Log (pre + "falloff — o efeito de borda não vai para o glTF; o bake aproxima.") tipo:#warn ; n += 1 )
        for t in tiling do ( InLab_Log (pre + t + ".") tipo:#warn ; n += 1 )
        -- #162: bitmap sem arquivo dentro de procedural → o bake sai preto ali.
        if not ehBitmap do
            for t in arvore where (InLab_TransformDoBitmap t) != undefined do
            (
                local a = try ( t.filename ) catch ( "" )
                if a != undefined and a != "" and (InLab_CaminhoTextura a) == "" do
                ( InLab_Log (pre + "textura não encontrada (" + a + ") — o bake sai preto onde ela entra.") tipo:#err ; n += 1 )
            )
    )
    n
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
-- 09/10/2026 (issue #163): transformação de UV de um bitmap.
-- #(tileU, tileV, offU, offV, canal, realWorld) de Bitmaptexture ou
-- CoronaBitmap; undefined se o mapa não é bitmap.
--------------------------------------------------------------------------------
global InLab_TransformDoBitmap, InLab_TransformIdentidade, InLab_AplicarTransform, InLab_BitmapSemTransform
fn InLab_TransformDoBitmap tm =
(
    if classof tm == Bitmaptexture then
        #(tm.coords.U_Tiling, tm.coords.V_Tiling, tm.coords.U_Offset, tm.coords.V_Offset, tm.coords.mapChannel, tm.coords.realWorldScale)
    else if InLab_ClasseContem tm "CoronaBitmap" then
    (
        local s = try ( tm.uvwScale ) catch ( [1, 1, 1] )
        local o = try ( tm.uvwOffset ) catch ( [0, 0, 0] )
        #(s.x, s.y, o.x, o.y, (try ( tm.uvwChannel ) catch ( 1 )), (try ( tm.realWorldScale ) catch ( false )))
    )
    else undefined
)

fn InLab_TransformIdentidade t =
    t == undefined or ((abs (t[1] - 1.0)) < 1e-4 and (abs (t[2] - 1.0)) < 1e-4 and (abs t[3]) < 1e-4 and (abs t[4]) < 1e-4)

-- Põe a transformação `t` no Bitmaptexture `bmp` do glTF Material (o
-- exportador grava KHR_texture_transform e o TEXCOORD do canal).
fn InLab_AplicarTransform t bmp =
(
    if t != undefined and bmp != undefined do
    (
        bmp.coords.U_Tiling = t[1]
        bmp.coords.V_Tiling = t[2]
        bmp.coords.U_Offset = t[3]
        bmp.coords.V_Offset = t[4]
        bmp.coords.mapChannel = t[5]
    )
    bmp
)

-- Cópia do bitmap sem tiling nem offset (um ladrilho), para bake/composição.
fn InLab_BitmapSemTransform tm =
(
    local c = copy tm
    if classof c == Bitmaptexture then
    (
        c.coords.U_Tiling = 1.0 ; c.coords.V_Tiling = 1.0
        c.coords.U_Offset = 0.0 ; c.coords.V_Offset = 0.0
    )
    else
    (
        try ( c.uvwScale = [1, 1, 1] ) catch ()
        try ( c.uvwOffset = [0, 0, 0] ) catch ()
    )
    c
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

    -- #163: a transformação do bitmap de topo vai para o bitmap do glTF.
    local tr = if ehBitmap then (InLab_TransformDoBitmap texmap) else undefined
    if tr != undefined and tr[6] do
    (
        InLab_Log (nomeBase + ": bitmap ainda em Real-World — rode o Auto UV antes de converter; a escala da textura não foi transferida.") tipo:#warn
        tr = undefined
    )
    -- #162: caminho que o Max resolve; textura ausente não vai para o glTF.
    local arqBruto = if ehBitmap then (try ( texmap.filename ) catch ( "" )) else ""
    if arqBruto == undefined do arqBruto = ""
    local arqResolvido = InLab_CaminhoTextura arqBruto
    if ehBitmap and arqResolvido == "" then
    (
        if arqBruto != "" then
            InLab_Log (nomeBase + ": textura não encontrada (" + arqBruto + ") — o slot fica vazio no glTF.") tipo:#err
    )
    else if ehBitmap and not inverter then
    (
        local arq = arqResolvido
        if arq != "" do
        (
            resultado = InLab_AplicarTransform tr (Bitmaptexture filename:arq)
            if not (InLab_TransformIdentidade tr) do
                InLab_Log (nomeBase + ": tiling " + (formattedPrint tr[1] format:".2f") + "×" + (formattedPrint tr[2] format:".2f") + " transferido para o glTF (KHR_texture_transform).") tipo:#ok
        )
    )
    else if fazerBake then
    (
        local fonte = texmap
        -- #163: bitmap com transformação é bakeado como um ladrilho, e a
        -- transformação vai para o resultado.
        local trBake = if tr != undefined and not (InLab_TransformIdentidade tr) then tr else undefined
        if trBake != undefined do fonte = InLab_BitmapSemTransform texmap
        if inverter do
        (
            -- Output map com invert: converte mapa de glossiness em roughness.
            local inv = Output()
            inv.map1 = fonte
            inv.output.invert = true
            fonte = inv
            InLab_Log (nomeBase + ": glossiness → roughness via bake invertido.") tipo:#warn
        )
        local arq = InLab_BakeTexmap fonte nomeBase tamanho precisaAlpha:precisaAlpha
        if arq != undefined do resultado = InLab_AplicarTransform trBake (Bitmaptexture filename:arq)
        -- #169: procedural bakeado lê os bitmaps de dentro no canal deles (o
        -- Real World Fix pode pôr o conteúdo do Triplanar no canal 2): o
        -- resultado vai para esse canal, se todos usam o mesmo.
        if resultado != undefined and trBake == undefined do
        (
            local canais = #()
            for t in (InLab_ArvoreDeMapas texmap #()) do
            (
                local trt = InLab_TransformDoBitmap t
                if trt != undefined do appendIfUnique canais trt[5]
            )
            if canais.count == 1 then resultado.coords.mapChannel = canais[1]
            else if canais.count > 1 do
                InLab_Log (nomeBase + ": procedural com bitmaps em canais diferentes " + canais as string + " — o bake fica no canal 1.") tipo:#warn
        )
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

    -- Caminho preferencial: pixels do arquivo em disco. #163: só sem
    -- transformação; com tiling/offset, o renderMap avalia o ladrilho certo.
    local ehBitmap = (classof texmap == Bitmaptexture) or (InLab_ClasseContem texmap "CoronaBitmap")
    local arq = if ehBitmap then (InLab_CaminhoTextura (try ( texmap.filename ) catch ( "" ))) else ""
    if ehBitmap and (InLab_TransformIdentidade (InLab_TransformDoBitmap texmap)) and arq != "" do
        bmFonte = try ( openBitMap arq ) catch ( undefined )

    -- Fallback: avaliação via renderMap (procedurais). #162: bitmap sem
    -- arquivo não vai para o renderMap, que devolveria preto.
    if ehBitmap and arq == "" then
        InLab_Log ((try ( texmap.name ) catch ( "bitmap" )) + ": textura não encontrada (" + (try ( texmap.filename ) catch ( "" )) + ").") tipo:#err
    else if bmFonte == undefined do
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
-- 06/10/2026 (issue #103): nomes de propriedade por tipo de material, em
-- ordem de tentativa (InLab_PropSafe). Usado pela conversão e pelas
-- verificações do grupo 7 (verif_materiais.ms), para as duas lerem
-- exatamente os mesmos slots. #outro devolve o perfil Physical (era o
-- "default" da conversão). No VRay a refração é COR ("refraction") e não
-- tem campo de valor: refrVal vazio, e conversão e V-36 leem a cor à parte
-- (06/10/2026, #118: refraction_amount não existe no VRayMtl).
--------------------------------------------------------------------------------
struct PerfilSlots ( cor, mapaBase, valGloss, mapaGloss, bump, opacMapa, refrVal, ior )

fn InLab_Material_PerfilSlots tipo =
(
    case tipo of
    (
        #legacy: PerfilSlots cor:#(#colorDiffuse, #diffuse) mapaBase:#(#texmapDiffuse) \
            valGloss:#(#reflectGlossiness, #levelReflectGlossiness) mapaGloss:#(#texmapReflectGlossiness) \
            bump:#(#texmapBump) opacMapa:#(#texmapOpacity) refrVal:#(#levelRefract) ior:#(#ior, #fresnelIor)
        #vray: PerfilSlots cor:#(#diffuse) mapaBase:#(#texmap_diffuse) \
            valGloss:#(#reflection_glossiness) mapaGloss:#(#texmap_reflectionGlossiness, #texmap_reflection_glossiness) \
            bump:#(#texmap_bump) opacMapa:#(#texmap_opacity) refrVal:#() ior:#(#refraction_ior)
        default: PerfilSlots cor:#(#baseColor) mapaBase:#(#baseTexmap) \
            valGloss:#(#baseRoughness, #roughness) mapaGloss:#(#baseRoughnessTexmap, #roughnessTexmap) \
            bump:#(#baseBumpTexmap, #bumpTexmap) opacMapa:#(#opacityTexmap) refrVal:#(#refractionAmount, #refraction) ior:#(#ior)
    )
)

--------------------------------------------------------------------------------
-- Converte UM CoronaPhysicalMtl em glTF Material. Retorna o material novo
-- ou undefined (material não-Corona → chamador mantém o original).
--------------------------------------------------------------------------------
fn InLab_ConverterCoronaMtl mtl tamanho fazerBake especiais:#() =
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
        local esp = InLab_EspecialDoMaterial mtl.name especiais:especiais
        local especial = esp[1]
        if esp[2] == #materia and especial != #nenhum do
            InLab_Log (mtl.name + ": " + (if especial == #cristal then "cristal" else "palha") + " pela matéria-prima do JSON.") tipo:#info

        -- ===== PERFIL DE PROPRIEDADES por renderizador (bug 4) =====
        local tipoMtl = InLab_TipoDeMaterial mtl
        local perfil = InLab_Material_PerfilSlots tipoMtl
        local candCor       = perfil.cor
        local candMapaBase  = perfil.mapaBase
        local candValGloss  = perfil.valGloss
        local candMapaGloss = perfil.mapaGloss
        local candBump      = perfil.bump
        local candOpacMapa  = perfil.opacMapa
        local candRefrVal   = perfil.refrVal
        local candIOR       = perfil.ior
        case tipoMtl of
        (
            #legacy: InLab_Log (mtl.name + ": perfil CoronaLegacyMtl (workflow glossiness).")
            #vray: InLab_Log (mtl.name + ": perfil VRayMtl (workflow glossiness).")
            default: ()
        )
        -- 09/10/2026 (issue #110): o que o glTF não reproduz, por slot.
        -- Bump: só o CoronaNormal vira normal map (o resto já avisa "bump escalar").
        for par in #(#(candMapaBase, "base color"), #(candMapaGloss, "roughness"), #(candBump, "normal"), #(candOpacMapa, "opacidade")) do
        (
            local tmSlot = InLab_PropSafe mtl par[1]
            if par[2] != "normal" or (InLab_ClasseContem tmSlot "CoronaNormal") do
                InLab_AvisosDoSlot tmSlot mtl.name par[2]
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
            -- #163: base (ou cor) e opacity bitmaps com a MESMA transformação:
            -- compõe um ladrilho e a transformação vai para o resultado. Senão
            -- cada um é avaliado com a sua no 0–1 (renderMap), com aviso.
            local trO = InLab_TransformDoBitmap mapaOpac
            -- Base procedural sem bitmap na árvore (cor, falloff) não depende do
            -- UV: compõe como ladrilho junto com a opacity.
            local baseSemUV = mapaBase != undefined and (InLab_TransformDoBitmap mapaBase) == undefined and                               (for t in (InLab_ArvoreDeMapas mapaBase #()) where (InLab_TransformDoBitmap t) != undefined collect t).count == 0
            local trB = if mapaBase == undefined or baseSemUV then trO else (InLab_TransformDoBitmap mapaBase)
            local trComp = undefined
            local baseComp = mapaBase, opacComp = mapaOpac
            if trO != undefined and trB != undefined and not trO[6] and not trB[6] and not (InLab_TransformIdentidade trO) and \
               (for k = 1 to 5 where (abs (trO[k] - trB[k])) > 1e-4 collect k).count == 0 then
            (
                trComp = trO
                opacComp = InLab_BitmapSemTransform mapaOpac
                if mapaBase != undefined and not baseSemUV do baseComp = InLab_BitmapSemTransform mapaBase
            )
            else
            (
                for tr in #(trB, trO) where tr != undefined and not (InLab_TransformIdentidade tr) do
                    if (amax tr[1] tr[2]) > 8.0 do
                        InLab_Log (mtl.name + ": base e opacity com tiling diferentes (até " + (formattedPrint (amax tr[1] tr[2]) format:".0f") + " repetições no 0–1): o composto respeita a escala, mas cada repetição fica com poucos pixels.") tipo:#warn
            )
            local arqRGBA = InLab_BakeBaseComAlpha baseComp corBase opacComp (mtl.name + "_basecolor_rgba") tamanho
            if arqRGBA != undefined do
            (
                local bmp = InLab_AplicarTransform trComp (Bitmaptexture filename:arqRGBA)
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
            -- 06/10/2026 (#118): no VRayMtl a refração é a COR "refraction"
            -- (não existe refraction_amount): o peso é a média dos canais.
            -- Antes caía no 1.0 e todo vidro VRay saía transparente.
            local refr = if tipoMtl == #vray then
            (
                local c = InLab_PropSafe mtl #(#refraction)
                if c == undefined then undefined else ((c.r + c.g + c.b) / (3.0 * 255.0))
            )
            else InLab_PropSafe mtl candRefrVal
            if tipoMtl == #vray and (InLab_PropSafe mtl #(#texmap_refraction)) != undefined do
                InLab_Log (mtl.name + ": mapa de refração do VRay não é convertido — transmission sai da cor de refração.") tipo:#warn
            local peso = if refr != undefined then refr else 1.0
            if (InLab_SetPropSafe g #(#transmission, #transmissionFactor, #transmissionWeight) peso) != undefined then
                InLab_Log (mtl.name + ": CRISTAL → transmission = " + peso as string + " (V-36).") tipo:#ok
            else
                InLab_Log (mtl.name + ": propriedade de transmission não encontrada — pendência KHR_materials_transmission (V-36).") tipo:#err

            local ior = InLab_PropSafe mtl candIOR
            if ior != undefined do InLab_SetPropSafe g #(#ior, #indexOfRefraction) ior

            -- 06/10/2026 (#119): o roughness do vidro NÃO é mais forçado para
            -- 0,05. Decisão da V-36: roughness, IOR e refração ficam livres
            -- (vidro jateado é fosco de propósito).
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
fn InLab_ConverterMaterialNode mtl tamanho fazerBake especiais:#() =
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
                local subNovo = InLab_ConverterCoronaMtl sub tamanho fazerBake especiais:especiais
                if subNovo != undefined then ( novo.materialList[i] = subNovo ; converteuAlgum = true )
                else novo.materialList[i] = sub   -- passa o original adiante
            )
        )
        if converteuAlgum then novo else undefined
    )
    else InLab_ConverterCoronaMtl mtl tamanho fazerBake especiais:especiais
)

--------------------------------------------------------------------------------
-- Ponto de entrada da UI: converte os materiais dos objetos selecionados.
--------------------------------------------------------------------------------
fn InLab_ConverterObjetos objs tamanhoBake:1024 fazerBake:true produto:undefined =
(
    -- #153: palha/cristal pela matéria-prima do produto escolhido, se houver.
    local especiais = if produto == undefined or InLab_Produto_EspeciaisDoProduto == undefined then #()
                      else InLab_Produto_EspeciaisDoProduto produto
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
                    novo = InLab_ConverterMaterialNode orig tamanhoBake fazerBake especiais:especiais
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
