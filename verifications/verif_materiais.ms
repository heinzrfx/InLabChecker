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
 faces é só nota. InLab_Mat_NomesUsados e InLab_Mat_IdsDasPartes servem à V-25,
 V-37 e V-38.

 06/10/2026 — revisão final: (1) cena já convertida. A conversão troca o
 material por um glTF Material; InLab_Mat_Resolver procura o original em
 InLab_UltimaConversao (materialNovo == glTF) e lê o Corona dele (o especial
 vem do nome do original, porque o glTF ganha sufixo "_GLTF"). Sem registro, o
 tipo é #gltf: V-23/V-35/V-36 avisam "já convertido" e a V-24 (crítica) põe o
 material em "não medido", nunca passe limpo sem leitura. (2) InLab_Mat_Registrar
 ganhou nota:, texto " · ..." no fim da mensagem em todos os ramos (roughness/
 normal da V-23, PNG aceito da V-24, parte sem faces da V-25).

 06/10/2026 — V-35 (palha com opacidade) e V-36 (cristal com refração), ambas
 advertência provisória. V-35 não confere 2-sided (a conversão liga sozinha).
 V-36 nunca reprova por valor; no VRay lê a cor "refraction".
 06/10/2026 — V-37 (zonas do estofado, advertência provisória) e V-38 (tampo
 acessório, critico:false). V-38 lê InLab_TampoAcessorioProduto, que o
 orquestrador define; aqui só é pré-declarada, sem valor.

 06/10/2026 — piloto (5 arquivos de PILOTO PLUGIN INLAB\ARTEFACTO, leitura,
 sem salvar; V-23..V-38 levam 0,04 a 0,07 s por arquivo, sem exceção nem
 "não medido"):
   Aparador Zucchi  — V-23 pass; V-24 FAIL (Material #0, LOURO MATE 02_basecolor.png,
                      PNG real no base color); V-25/35/36/37/38 pass.
   Poltrona Mentha  — tudo pass (V-23 com roughness/normal ausentes só listados).
   Mesa Nambu       — V-23 warning ("metal dourado artefacto": base color sem mapa,
                      cor lisa sem procedural; sem normal no Material #17); resto pass.
   Mesa Louise Jat. — V-23 warning (Vidro Jateado, Glass Bronze Distorted: cor lisa);
                      V-36 pass (2 materiais de cristal com refração).
   Puff Pol (VRay)  — V-23 warning (MET - marrom metal, MET - caixilho metal: cor lisa);
                      checagens rodam sem erro; V-37 pass (6 materiais).
 Nenhum procedural no difuso virou "base color sem mapa" (os materiais acusados
 têm texmapDiffuse indefinido), nem ID órfão na V-25.

 09/10/2026 (issue #145): V-35/V-36 escolhem o material especial pela
 matéria-prima da parte do JSON (material_id da parte = nome do material),
 com volta ao nome quando não há produto ou a parte vem sem
 materia_prima.familia. A V-24 herda (palha aceita PNG). As notas dizem
 quantos vieram do JSON e quais o nome marcaria mas a matéria-prima tirou.
 09/10/2026 (issue #153): a regra foi para fn_renomear_produto.ms
 (InLab_Produto_EspeciaisDoProduto) e a conversão passou a usá-la também.
================================================================================
*/

-- Definida e preenchida pelo orquestrador (checkbox da UI); aqui só é lida.
global InLab_TampoAcessorioProduto
-- Registro da conversão (fn_material_convert.ms); pré-declarada sem valor.
global InLab_UltimaConversao

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
-- #legacy, #vray, #outro (a conversão não suporta) ou #gltf (já convertido e
-- sem registro do original). especial: #palha,
-- #cristal ou #nenhum. fonte: #materia (matéria-prima da parte no JSON) ou
-- #nome (mesmas palavras da conversão). especialNome: o que o nome daria.
struct MatInfo ( mtl, base, tipo, especial, fonte = #nome, especialNome = #nenhum )

-- 09/10/2026 (issue #145): o especial vem da matéria-prima da parte cujo
-- material_id é o nome do material (InLab_Produto_EspeciaisDoProduto, em
-- fn_renomear_produto.ms desde a #153, que a conversão também usa), com
-- volta ao nome (InLab_EspecialDoMaterial, fn_material_convert.ms).
fn InLab_Mat_Resolver uso produto:undefined =
(
    local tabela = InLab_Produto_EspeciaisDoProduto produto
    for m in uso.usados collect
    (
        local origem = m
        local nomeEsp = m.name
        local semOrigem = false
        -- Cena já convertida: o material é um glTF; o Corona original está no
        -- registro da conversão (InLab_UltimaConversao).
        if InLab_ClasseContem m "gltf" do
        (
            local rec = undefined
            if InLab_UltimaConversao != undefined do
                for r in InLab_UltimaConversao where rec == undefined and r.materialNovo == m and r.materialOriginal != undefined do rec = r
            if rec != undefined then ( origem = rec.materialOriginal; nomeEsp = origem.name )
            else semOrigem = true
        )
        local base = undefined
        local tipo = #gltf
        if not semOrigem do
        (
            base = origem
            if InLab_ClasseContem origem "CoronaLayeredMtl" do base = InLab_PropSafe origem #(#baseMtl, #baseMaterial, #base)
            tipo = if base == undefined then #outro else InLab_TipoDeMaterial base
        )
        local esp = InLab_EspecialDoMaterial nomeEsp especiais:tabela
        MatInfo mtl:m base:base tipo:tipo especial:esp[1] fonte:esp[2] especialNome:(InLab_DetectarEspecial nomeEsp)
    )
)

-- Todos os texmaps da árvore do slot `campo` (#mapaBase, #mapaGloss, #bump,
-- #opacMapa). #() se o slot está vazio ou o tipo é #outro/#gltf.
fn InLab_Mat_MapasDoSlot info campo =
(
    if info.tipo == #outro or info.tipo == #gltf then #()
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
fn InLab_Mat_Registrar idV titulo problemas naoMedidos okMsg critico:true provisorio:false nota:"" =
(
    if problemas.count > 0 then
    (
        local itens = for p in problemas collect p
        for n in naoMedidos do append itens ("não medido: " + n)
        InLab_RegistrarVerif idV titulo false ((InLab_ListaResumida itens) + nota) critico:critico provisorio:provisorio
    )
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif idV titulo false ("não medido: " + (InLab_ListaResumida naoMedidos) + nota) critico:false
    else
        InLab_RegistrarVerif idV titulo true (okMsg + nota) critico:critico provisorio:provisorio
)

-- Mensagem de material já convertido (V-23, V-35, V-36).
fn InLab_Mat_MsgGltf nome = ( nome + ": já convertido para glTF — verifique antes de converter (ou Reverter a conversão)" )

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
            if i.tipo == #gltf then
                append problemas (InLab_Mat_MsgGltf i.mtl.name)
            else if i.tipo == #outro then
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
    InLab_Mat_Registrar "V-23" titulo problemas naoMedidos \
        (infos.count as string + " material(is) com base color mapeado") critico:true provisorio:true nota:nota
)

-- V-24 · PNG proibido no base color e no roughness (crítica). Exceção: palha
-- ou material com mapa de opacidade (o alpha exige PNG; decisão de 06/10/2026).
fn InLab_V24_PNG infos =
(
    local titulo = "Sem PNG no base color e no roughness"
    local problemas = #(), naoMedidos = #(), aceitos = #()
    for i in infos do
    (
        try
        (
            if i.tipo == #gltf then append naoMedidos (i.mtl.name + ": já convertido para glTF")
            else if i.tipo == #outro then append naoMedidos (i.mtl.name + ": tipo " + (classof i.mtl) as string + " não lido")
            else
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
        )
        catch ( append naoMedidos (i.mtl.name + " (" + getCurrentException() + ")") )
    )
    local okMsg = "nenhum PNG no base color nem no roughness"
    local nota = ""
    if aceitos.count > 0 do nota = " · PNG aceito (alpha): " + InLab_ListaResumida aceitos
    InLab_Mat_Registrar "V-24" titulo problemas naoMedidos okMsg critico:true nota:nota
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
    local nota = ""
    if produto != undefined do
    (
        local usados = InLab_Mat_NomesUsados uso
        local semFaces = for id in (InLab_Mat_IdsDasPartes produto) where (findItem usados id) == 0 collect id
        if semFaces.count > 0 do nota = " · parte(s) do produto sem faces: " + InLab_ListaResumida semFaces
    )
    InLab_Mat_Registrar "V-25" titulo uso.orfaos uso.naoMedidos okMsg critico:true nota:nota
)

-- Nota da V-35/V-36 (issue #145): quantos vieram da matéria-prima do JSON e
-- quais o nome marcaria mas a matéria-prima tirou (ex.: "Fibra de Vidro").
fn InLab_Mat_NotaFonte infos esp =
(
    local doJson = (for i in infos where i.especial == esp and i.fonte == #materia collect i).count
    local fora = for i in infos where i.fonte == #materia and i.especialNome == esp and i.especial != esp collect i.mtl.name
    local nota = ""
    if doJson > 0 do nota += " · " + doJson as string + " pela matéria-prima do JSON"
    if fora.count > 0 do nota += " · fora pela matéria-prima: " + InLab_ListaResumida fora
    nota
)

-- V-35 · Palha com opacidade (advertência provisória). O 2-sided não é
-- conferido: a conversão liga doubleSided sozinha e o CoronaLegacyMtl não tem
-- a propriedade (sondagem de 06/10/2026).
fn InLab_V35_Palha infos =
(
    local titulo = "Palha com mapa de opacidade"
    local palhas = for i in infos where i.especial == #palha collect i
    local problemas = #(), naoMedidos = #()
    for i in palhas do
    (
        try
        (
            if i.tipo == #gltf then append problemas (InLab_Mat_MsgGltf i.mtl.name)
            else if i.tipo == #outro then append problemas (i.mtl.name + ": tipo não convertido para glTF")
            else if (InLab_Mat_MapasDoSlot i #opacMapa).count == 0 do append problemas (i.mtl.name + ": sem mapa de opacidade")
        )
        catch ( append naoMedidos (i.mtl.name + " (" + getCurrentException() + ")") )
    )
    local okMsg = if palhas.count == 0 then "não se aplica: nenhum material de palha" else (palhas.count as string + " material(is) de palha com opacidade")
    InLab_Mat_Registrar "V-35" titulo problemas naoMedidos okMsg critico:true provisorio:true nota:(InLab_Mat_NotaFonte infos #palha)
)

-- Refração ligada: VRay pela cor "refraction" (não tem refraction_amount);
-- Corona pelo valor do perfil (levelRefract / refractionAmount) > 0.
fn InLab_Mat_RefracaoLigada i =
(
    if i.tipo == #vray then
    (
        local c = InLab_PropSafe i.base #(#refraction)
        c != undefined and (c.r + c.g + c.b) > 0
    )
    else
    (
        local v = InLab_PropSafe i.base (InLab_Material_PerfilSlots i.tipo).refrVal
        v != undefined and v > 0
    )
)

-- V-36 · Cristal com refração (advertência provisória). Nunca reprova por
-- valor: roughness, IOR e intensidade ficam livres (decisão de 06/10/2026;
-- vidro jateado é fosco de propósito).
fn InLab_V36_Cristal infos =
(
    local titulo = "Cristal com refração ligada"
    local cristais = for i in infos where i.especial == #cristal collect i
    local problemas = #(), naoMedidos = #()
    for i in cristais do
    (
        try
        (
            if i.tipo == #gltf then append problemas (InLab_Mat_MsgGltf i.mtl.name)
            else if i.tipo == #outro then append problemas (i.mtl.name + ": tipo não convertido para glTF")
            else if not (InLab_Mat_RefracaoLigada i) do append problemas (i.mtl.name + ": refração desligada")
        )
        catch ( append naoMedidos (i.mtl.name + " (" + getCurrentException() + ")") )
    )
    local okMsg = if cristais.count == 0 then "não se aplica: nenhum material de cristal/vidro" else (cristais.count as string + " material(is) de cristal com refração")
    InLab_Mat_Registrar "V-36" titulo problemas naoMedidos okMsg critico:true provisorio:true nota:(InLab_Mat_NotaFonte infos #cristal)
)

-- Filtros das partes do produto (globais nomeadas: fn dentro de bloco/lambda
-- em argumento nomeado é frágil no MaxScript).
fn InLab_Mat_EhTecido p = InLab_Produto_Booleano p "tecido"
fn InLab_Mat_EhTampoAcessorio p =
    (InLab_Produto_Booleano p "acessorio") and (findString (InLab_Produto_Normalizar (InLab_Produto_Texto p "nome_parte")) "tampo") != undefined

-- V-37 · Zonas de acabamento do estofado (advertência provisória). Só nas
-- famílias com "zona_acabamento" em materialTypes. Com produto: cada parte
-- tecido:true precisa ter faces com o seu material_id. Sem produto: um único
-- material em tudo → advertência ("pode ser produto sem desmembramento").
fn InLab_V37_ZonasEstofado cfg uso produto:undefined =
(
    local titulo = "Zonas de acabamento do estofado"
    if (findItem cfg.materialTypes "zona_acabamento") == 0 then
        InLab_RegistrarVerif "V-37" titulo true ("não se aplica: família " + cfg.nome + " sem zona de acabamento") critico:true provisorio:true
    else if produto != undefined then
    (
        local usados = InLab_Mat_NomesUsados uso
        local tecidos = InLab_Mat_IdsDasPartes produto filtro:InLab_Mat_EhTecido
        local faltam = for id in tecidos where (findItem usados id) == 0 collect ("parte de tecido sem faces: " + id)
        local okMsg = if tecidos.count == 0 then "não se aplica: produto sem parte de tecido" else (tecidos.count as string + " parte(s) de tecido com o seu material")
        InLab_Mat_Registrar "V-37" titulo faltam uso.naoMedidos okMsg critico:true provisorio:true
    )
    else
    (
        local problemas = if uso.usados.count == 1 then #("estofado num único material (pode ser produto sem desmembramento; importe o .json para conferir as partes)") else #()
        local okMsg = if uso.usados.count == 0 then "não se aplica: nenhum material nas peças" else (uso.usados.count as string + " materiais no estofado")
        InLab_Mat_Registrar "V-37" titulo problemas uso.naoMedidos okMsg critico:true provisorio:true
    )
)

-- V-38 · Tampo acessório em bloco separado (advertência, critico:false).
-- Ativa pelo checkbox (InLab_TampoAcessorioProduto) ou pela família. Com
-- produto: faces do material do tampo acessório E de outra parte no mesmo
-- arquivo → advertência. Sem produto: pendente.
fn InLab_V38_TampoAcessorio cfg uso produto:undefined =
(
    local titulo = "Tampo acessório em arquivo separado"
    if not (InLab_TampoAcessorioProduto == true or cfg.tampoAcessorio) then
        InLab_RegistrarVerif "V-38" titulo true "não se aplica: produto sem tampo acessório" critico:false
    else if produto == undefined then
        InLab_RegistrarVerif "V-38" titulo false "pendente: importe o .json e escolha o produto na seção Produto para conferir estrutura e tampo" critico:false
    else
    (
        local idsTampo = InLab_Mat_IdsDasPartes produto filtro:InLab_Mat_EhTampoAcessorio
        local idsOutros = for id in (InLab_Mat_IdsDasPartes produto) where (findItem idsTampo id) == 0 collect id
        local usados = InLab_Mat_NomesUsados uso
        local temTampo = (for id in idsTampo where (findItem usados id) > 0 collect id).count > 0
        local temOutros = (for id in idsOutros where (findItem usados id) > 0 collect id).count > 0
        local problemas = if temTampo and temOutros then #("estrutura e tampo acessório no mesmo arquivo: separe em dois blocos (intercambialidade)") else #()
        InLab_Mat_Registrar "V-38" titulo problemas uso.naoMedidos \
            (if temTampo then "arquivo só com o tampo" else if temOutros then "arquivo só com a estrutura" else "nenhuma parte do produto nas faces (ver V-20)") critico:false
    )
)
