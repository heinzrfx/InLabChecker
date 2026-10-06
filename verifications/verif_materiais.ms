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
