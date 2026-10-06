/*
================================================================================
 verifications\verif_materiais.ms — Grupo 7 · V-23, V-24, V-25, V-35, V-36,
                                    V-37, V-38 (materiais)
--------------------------------------------------------------------------------
 Spec: docs\superpowers\specs\2026-10-06-verif-materiais-grupo7-design.md
 (issue #103).

 Lê o material CORONA de origem, não o glTF Material: o acervo é Corona e a
 conversão (fn_material_convert.ms) herda tudo dele. Os slots são os mesmos
 que a conversão lê (InLab_Material_PerfilSlots). Qualquer mapa conta como
 slot preenchido, procedural incluído, e a árvore inteira do slot é
 percorrida (InLab_Produto_ColetarMapas).

 06/10/2026 — sondagem do piloto (Max 2024): quase tudo CoronaLegacyMtl, o
 Puff Pol inteiro em VRayMtl, nenhum CoronaPhysicalMtl; slots procedurais
 (CoronaColorCorrect, CoronaMix, CoronaTriplanar, CoronaColor), quase nenhum
 bitmap direto. O CoronaLegacyMtl não tem propriedade de 2-sided e o VRayMtl
 não tem refraction_amount (a refração é a cor "refraction").

 06/10/2026 — V-25 (IDs com sub-material, crítica): parte do produto sem
 faces é só nota. InLab_Mat_NomesUsados e InLab_Mat_IdsDasPartes servem à V-20.
================================================================================
*/

-- Uso de material pelas faces, calculado uma vez e compartilhado pela V-25,
-- V-37 e V-38. usados: material direto ou sub-material de Multi/Sub com pelo
-- menos uma face. orfaos: "obj: ID n sem sub-material". naoMedidos: falhas.
struct MatUso ( usados = #(), orfaos = #(), naoMedidos = #() )

fn InLab_Mat_Uso objetos =
(
    local uso = MatUso()
    for o in objetos where o.material != undefined do
    (
        try
        (
            local m = o.material
            if classof m == Multimaterial then
            (
                local malha = snapshotAsMesh o
                local ids = #{}
                for f = 1 to malha.numfaces do ids[getFaceMatID malha f] = true
                delete malha
                for id in ids do
                (
                    local idx = findItem m.materialIDList id
                    local sub = if idx > 0 then m.materialList[idx] else undefined
                    if sub == undefined then append uso.orfaos (o.name + ": ID " + id as string + " sem sub-material")
                    else appendIfUnique uso.usados sub
                )
            )
            else appendIfUnique uso.usados m
        )
        catch
        (
            local erro = getCurrentException()
            append uso.naoMedidos (o.name + " (" + erro + ")")
            InLab_Log (o.name + ": material não lido — " + erro) tipo:#err
        )
    )
    uso
)

-- mtl: o material usado (nome para mensagens e palavras-chave). base: o que
-- se lê nos slots (o próprio, ou o base de um Layered). tipo: #physical,
-- #legacy, #vray ou #outro (a conversão não suporta). especial: #palha,
-- #cristal ou #nenhum (mesmas palavras da conversão).
struct MatInfo ( mtl, base, tipo, especial )

fn InLab_Mat_Resolver uso =
(
    for m in uso.usados collect
    (
        local base = m
        if InLab_ClasseContem m "CoronaLayeredMtl" do base = InLab_PropSafe m #(#baseMtl, #baseMaterial, #base)
        local tipo = if base == undefined then #outro else InLab_TipoDeMaterial base
        MatInfo mtl:m base:base tipo:tipo especial:(InLab_DetectarEspecial m.name)
    )
)

-- Todos os texmaps da árvore do slot `campo` (#mapaBase, #mapaGloss, #bump,
-- #opacMapa). #() se o slot está vazio ou o tipo é #outro.
fn InLab_Mat_MapasDoSlot info campo =
(
    if info.tipo == #outro then #()
    else
    (
        local nomes = getProperty (InLab_Material_PerfilSlots info.tipo) campo
        local tm = InLab_PropSafe info.base nomes
        if tm == undefined then #() else InLab_Produto_ColetarMapas tm #()
    )
)

-- Caminho do arquivo de Bitmaptexture ou CoronaBitmap; undefined se não é
-- mapa de arquivo ou se o caminho está vazio.
fn InLab_Mat_ArquivoDoMapa tm =
(
    local arq = undefined
    if classof tm == Bitmaptexture or (InLab_ClasseContem tm "CoronaBitmap") do
        arq = try ( tm.filename ) catch ( undefined )
    if arq == undefined or arq == "" then undefined else arq
)

-- Registro no padrão do grupo 5: problema → falha (critico/provisorio);
-- só "não medido" → advertência; senão passa com okMsg.
fn InLab_Mat_Registrar idV titulo problemas naoMedidos okMsg critico:true provisorio:false =
(
    if problemas.count > 0 then
        InLab_RegistrarVerif idV titulo false (InLab_ListaResumida (problemas + naoMedidos)) critico:critico provisorio:provisorio
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif idV titulo false ("não medido: " + InLab_ListaResumida naoMedidos) critico:false
    else
        InLab_RegistrarVerif idV titulo true okMsg critico:critico provisorio:provisorio
)

-- V-23 · Slots PBR (advertência provisória). Base color sem nenhum mapa ou
-- material que a conversão não suporta → advertência. Roughness ou normal
-- vazios: só nota (decisão de 06/10/2026: um mapa só é exceção válida).
fn InLab_V23_SlotsPBR infos =
(
    local titulo = "Slots PBR (base color, roughness, normal)"
    local problemas = #(), naoMedidos = #(), semRough = #(), semNormal = #()
    for i in infos do
    (
        try
        (
            if i.tipo == #outro then
                append problemas (i.mtl.name + ": tipo " + (classof i.mtl) as string + " não é convertido para glTF")
            else
            (
                if (InLab_Mat_MapasDoSlot i #mapaBase).count == 0 do append problemas (i.mtl.name + ": base color sem mapa")
                if (InLab_Mat_MapasDoSlot i #mapaGloss).count == 0 do append semRough i.mtl.name
                if (InLab_Mat_MapasDoSlot i #bump).count == 0 do append semNormal i.mtl.name
            )
        )
        catch ( append naoMedidos (i.mtl.name + " (" + getCurrentException() + ")") )
    )
    local nota = ""
    if semRough.count > 0 do nota += " · sem roughness: " + InLab_ListaResumida semRough
    if semNormal.count > 0 do nota += " · sem normal: " + InLab_ListaResumida semNormal
    if problemas.count > 0 do append problemas (nota)
    InLab_Mat_Registrar "V-23" titulo (for p in problemas where p != "" collect p) naoMedidos \
        (infos.count as string + " material(is) com base color mapeado" + nota) critico:true provisorio:true
)

-- V-24 · PNG proibido no base color e no roughness (crítica). Exceção: palha
-- ou material com mapa de opacidade (o alpha exige PNG; decisão de 06/10/2026).
fn InLab_V24_PNG infos =
(
    local titulo = "Sem PNG no base color e no roughness"
    local problemas = #(), naoMedidos = #(), aceitos = #()
    for i in infos where i.tipo != #outro do
    (
        try
        (
            local alpha = i.especial == #palha or (InLab_Mat_MapasDoSlot i #opacMapa).count > 0
            for par in #(#(#mapaBase, "base color"), #(#mapaGloss, "roughness")) do
                for tm in (InLab_Mat_MapasDoSlot i par[1]) do
                (
                    local arq = InLab_Mat_ArquivoDoMapa tm
                    if arq != undefined and (toLower (getFilenameType arq)) == ".png" do
                    (
                        if alpha then appendIfUnique aceitos i.mtl.name
                        else appendIfUnique problemas (i.mtl.name + " (" + par[2] + "): " + filenameFromPath arq)
                    )
                )
        )
        catch ( append naoMedidos (i.mtl.name + " (" + getCurrentException() + ")") )
    )
    local okMsg = "nenhum PNG no base color nem no roughness"
    if aceitos.count > 0 do okMsg = "PNG aceito (alpha): " + InLab_ListaResumida aceitos
    InLab_Mat_Registrar "V-24" titulo problemas naoMedidos okMsg critico:true
)

fn InLab_Mat_NomesUsados uso = ( for m in uso.usados collect m.name )

-- material_id das partes do produto (sem as subpartes so3d), filtradas por
-- `filtro` (fn parte -> bool) quando dado.
fn InLab_Mat_IdsDasPartes produto filtro:undefined =
(
    local ids = #()
    for p in (InLab_Produto_PartesDeMaterial produto) where (filtro == undefined or (filtro p)) do
    (
        local id = InLab_Produto_Texto p "material_id"
        if id != "" do appendIfUnique ids id
    )
    ids
)

-- V-25 · IDs de material com correspondência de parte (crítica). Face com ID
-- que não leva a um sub-material reprova. Parte do produto sem faces é só
-- nota: o bloco pode não ter todas as partes (tampo acessório, variante).
-- O nome do sub-material contra o material_id é da V-20.
fn InLab_V25_IDsDeMaterial uso produto:undefined =
(
    local titulo = "IDs de material com sub-material"
    local okMsg = "todos os IDs de material das faces têm sub-material"
    if produto != undefined do
    (
        local usados = InLab_Mat_NomesUsados uso
        local semFaces = for id in (InLab_Mat_IdsDasPartes produto) where (findItem usados id) == 0 collect id
        if semFaces.count > 0 do okMsg += " · nota: parte(s) do produto sem faces: " + InLab_ListaResumida semFaces
    )
    InLab_Mat_Registrar "V-25" titulo uso.orfaos uso.naoMedidos okMsg critico:true
)
