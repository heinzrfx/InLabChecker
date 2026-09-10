/*
================================================================================
 verifications\verif_nomenclatura.ms — V-20/21/22
--------------------------------------------------------------------------------
 V-20: nomenclatura oficial — EM ADVERTÊNCIA até definição (spec, seção 6);
       validNames vazio nos 8 structs.

 V-21/22 — CORRIGIDOS (auditoria de 08/08/2026, cruzando com a spec v1.0
 recuperada — a versão anterior deste arquivo tinha sido escrita sem acesso
 a ela e "chutou" outra lógica, registrada sob os mesmos IDs por engano):
   V-21 = nomes sem acento/espaço — apenas [A-Za-z0-9_]           (spec 2.7)
   V-22 = sufixos numéricos sequenciais sem lacuna (_01, _02...)  (spec 2.7)

 A checagem antiga de "nome default do Max" e "nomes duplicados" foi
 removida destes IDs — pode voltar como um V extra separado se for útil,
 mas não são o V-21/V-22 da spec.
================================================================================
*/

fn InLab_V20_Nomenclatura cfg =
(
    if cfg.validNames.count == 0 then
        InLab_RegistrarVerif "V-20" "Nomenclatura oficial da família" false "pendente definição oficial (Produtos + InLab) — modo advertência" critico:false
    else
    (
        local nomeArq = getFilenameFile maxFileName
        local ok = false
        for padrao in cfg.validNames while not ok do
            if matchPattern nomeArq pattern:padrao ignoreCase:true do ok = true
        InLab_RegistrarVerif "V-20" "Nomenclatura oficial da família" ok ("arquivo '" + nomeArq + "' vs padrões da família") critico:false
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
    local problemas = #()
    for g in grupos where g[2].count > 1 do
    (
        local nums = deepCopy g[2]
        sort nums
        for i = 1 to nums.count where nums[i] != i do
            append problemas (g[1] + "_*: sequência com lacuna — encontrado " + (nums as string) + ", esperado 1.." + nums.count as string)
    )
    local msg = if problemas.count == 0 then "sequências OK (ou sem sufixo numérico)" else (problemas as string)
    InLab_RegistrarVerif "V-22" "Sufixos numéricos sequenciais (_01, _02... sem lacuna)" (problemas.count == 0) msg critico:false
)
