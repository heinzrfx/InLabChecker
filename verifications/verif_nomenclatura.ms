/*
================================================================================
 verifications\verif_nomenclatura.ms — V-20/21/22
--------------------------------------------------------------------------------
 V-20: nomenclatura oficial. 02/10/2026 (issue #36): os nomes válidos saem do
       PRODUTO importado na seção Produto, não de lista fixa por família
       (validNames continua vazio nos 8 structs). Convenção confirmada pela
       Bianca (docs\superpowers\specs\2026-10-02-json-v2-respostas-bianca.md):
         arquivo .max = cod_est (ou o cod_est do master, se o produto é cópia
                        de bloco_3d — a cópia sai do .max do master);
         objeto       = um dos mesh_final do produto ("|" dividido);
         material     = um dos material_id das partes (sem as subpartes so3d,
                        cujo objeto usa o material da parte-mãe).
       Comparação exata, com maiúsculas e minúsculas. Sem produto importado a
       V-20 fica pendente. Continua NÃO crítica (advertência): tornar crítica
       é decisão de produto.

 V-21/22 — CORRIGIDOS (auditoria de 08/08/2026, cruzando com a spec v1.0
 recuperada — a versão anterior deste arquivo tinha sido escrita sem acesso
 a ela e "chutou" outra lógica, registrada sob os mesmos IDs por engano):
   V-21 = nomes sem acento/espaço — apenas [A-Za-z0-9_]           (spec 2.7)
   V-22 = sufixos numéricos sequenciais sem lacuna (_01, _02...)  (spec 2.7)

 A checagem antiga de "nome default do Max" e "nomes duplicados" foi
 removida destes IDs — pode voltar como um V extra separado se for útil,
 mas não são o V-21/V-22 da spec.

 23/09/2026 (issue #35): V-22 com uma mensagem por grupo, grupo de 1 item
 checado e sufixo repetido separado de lacuna.
================================================================================
*/

-- Pré-declarados: definidos em functions\fn_renomear_produto.ms (carregado
-- antes pelo manifesto; os testes que não usam produto não o carregam).
global InLab_Produto_Texto, InLab_Produto_MeshesDoProduto, InLab_Produto_PartesDeMaterial
global InLab_Produto_MateriaisDaSelecao, InLab_Produto_BaseDaCopia

-- "a, b, c" com no máximo `maximo` nomes e "… (+N)" no fim.
fn InLab_V20_Lista nomes maximo:5 =
(
    local txt = ""
    for i = 1 to (amin nomes.count maximo) do txt += (if i > 1 then ", " else "") + "'" + nomes[i] + "'"
    if nomes.count > maximo do txt += " … (+" + (nomes.count - maximo) as string + ")"
    txt
)

-- produto: o produto escolhido na seção Produto (formato de InLab_ParseJSON).
-- objetos: universo da verificação. nomeArquivo: só para teste (o padrão é
-- o nome do .max aberto, sem extensão).
fn InLab_V20_Nomenclatura cfg produto:undefined objetos:#() nomeArquivo:unsupplied =
(
    local titulo = "Nomenclatura oficial (arquivo, objetos e materiais)"
    if produto != undefined then
    (
        if nomeArquivo == unsupplied do nomeArquivo = getFilenameFile maxFileName
        local cod = InLab_Produto_Texto produto "cod_est"
        local base = InLab_Produto_BaseDaCopia produto
        local problemas = #()

        if nomeArquivo == "" then
            append problemas ("cena não salva: o .max leva o código do produto (" + cod + ")")
        else if (toLower nomeArquivo) != (toLower cod) and (base == "" or (toLower nomeArquivo) != (toLower base)) do
            append problemas ("arquivo '" + nomeArquivo + "' não é o código do produto (" + cod + (if base != "" then " ou " + base + ", o master" else "") + ")")

        local meshes = InLab_Produto_MeshesDoProduto produto
        if meshes.count == 0 then
            append problemas ("o produto " + cod + " não tem nome de objeto no JSON (mesh_final vazio)")
        else
        (
            local fora = for o in objetos where (findItem meshes o.name) == 0 collect o.name
            if fora.count > 0 do
                append problemas (fora.count as string + " objeto(s) com nome fora do produto: " + (InLab_V20_Lista fora) + " — válidos: " + (InLab_V20_Lista meshes maximo:8))
        )

        local ids = #()
        for parte in (InLab_Produto_PartesDeMaterial produto) where (InLab_Produto_Texto parte "material_id") != "" do
            appendIfUnique ids (InLab_Produto_Texto parte "material_id")
        local foraMat = for m in (InLab_Produto_MateriaisDaSelecao objetos) where (findItem ids m.name) == 0 collect m.name
        if foraMat.count > 0 do
            append problemas (foraMat.count as string + " material(is) com nome fora do produto: " + (InLab_V20_Lista foraMat))

        local msg = "produto " + cod + ": "
        if problemas.count == 0 then msg += "arquivo, " + objetos.count as string + " objeto(s) e materiais com os nomes oficiais"
        else for i = 1 to problemas.count do msg += (if i > 1 then "; " else "") + problemas[i]
        InLab_RegistrarVerif "V-20" titulo (problemas.count == 0) msg critico:false
    )
    else if cfg.validNames.count == 0 then
        InLab_RegistrarVerif "V-20" titulo false "pendente: importe o .json e escolha o produto na seção Produto para conferir os nomes — modo advertência" critico:false
    else
    (
        local nomeArq = getFilenameFile maxFileName
        local ok = false
        for padrao in cfg.validNames while not ok do
            if matchPattern nomeArq pattern:padrao ignoreCase:true do ok = true
        InLab_RegistrarVerif "V-20" titulo ok ("arquivo '" + nomeArq + "' vs padrões da família") critico:false
    )
)

-- V-21 · Sem acentos/espaços — apenas [A-Za-z0-9_] (spec v1.0 · seção 2.7).
fn InLab_V21_NomesValidos objetos =
(
    local permitidos = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    local problemas = #()
    for o in objetos do
        for i = 1 to o.name.count do
        (
            local c = o.name[i]
            if (findString permitidos c) == undefined do
                appendIfUnique problemas (o.name + " → caractere inválido: '" + c + "'")
        )
    local msg = if problemas.count == 0 then "todos os nomes válidos" else (problemas as string)
    InLab_RegistrarVerif "V-21" "Nomes sem acentos/espaços" (problemas.count == 0) msg critico:true
)

-- V-22 · Sufixos numéricos sequenciais sem lacuna (spec v1.0 · seção 2.7).
-- Detecta grupos "Prefixo_NN" automaticamente a partir dos nomes da cena —
-- não depende da lista oficial (validNames), que ainda está pendente.
fn InLab_V22_SufixosSequenciais objetos =
(
    local grupos = #()
    for o in objetos do
    (
        local n = o.name
        local under = undefined
        for i = n.count to 1 by -1 while under == undefined do if n[i] == "_" do under = i
        if under != undefined and under < n.count then
        (
            local prefixo = substring n 1 (under - 1)
            local sufixo  = substring n (under + 1) (n.count - under)
            local numOk = true
            local num = 0
            try ( num = sufixo as integer ; if num == undefined do numOk = false ) catch ( numOk = false )
            if numOk do
            (
                local idx = 0
                for i = 1 to grupos.count where grupos[i][1] == prefixo do idx = i
                if idx == 0 then ( append grupos #(prefixo, #(num)) )
                else append grupos[idx][2] num
            )
        )
    )
    -- 23/09/2026 (issue #35): UMA mensagem por grupo (antes saía uma por
    -- índice fora de lugar, repetida); grupo de 1 item também é checado
    -- (Perna_02 sozinho passava); sufixo repetido tem mensagem própria em vez
    -- de virar "lacuna".
    local problemas = #()
    for g in grupos do
    (
        local nums = deepCopy g[2]
        sort nums
        local unicos = makeUniqueArray (deepCopy nums)
        local lacuna = false
        for i = 1 to unicos.count where unicos[i] != i do lacuna = true
        local txt = ""
        if lacuna do
            txt += "sequência com lacuna — encontrado " + (unicos as string) + ", esperado 1.." + unicos.count as string
        if unicos.count < nums.count do
            txt += (if txt != "" then "; " else "") + "sufixo repetido em " + (nums.count - unicos.count) as string + " objeto(s)"
        if txt != "" do append problemas (g[1] + "_*: " + txt)
    )
    local msg = if problemas.count == 0 then "sequências OK (ou sem sufixo numérico)" else (problemas as string)
    InLab_RegistrarVerif "V-22" "Sufixos numéricos sequenciais (_01, _02... sem lacuna)" (problemas.count == 0) msg critico:false
)
