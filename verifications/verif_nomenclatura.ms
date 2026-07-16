/*
================================================================================
 verifications\verif_nomenclatura.ms — V-20/21/22
--------------------------------------------------------------------------------
 V-20: nomenclatura oficial — EM ADVERTÊNCIA até definição (spec, seção 6);
       validNames vazio nos 8 structs.
 V-21/22: LÓGICA INFERIDA (a spec v2.0 herda os nomes da v1.0 sem detalhar;
       a v1.0 não está disponível). Implementação a confirmar com o Rafael:
       V-21 = objetos com nome default do Max (não descritivo) → advertência
       V-22 = nomes duplicados (duplicam nós no GLB) → advertência
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

fn InLab_V21_NomesDescritivos objetos =
(
    local padroesDefault = #("Box*", "Object*", "Plane*", "Sphere*", "Cylinder*", "Teapot*", "GeoSphere*", "Editable*", "Shape*", "Line*")
    local ruins = #()
    for o in objetos do
        for p in padroesDefault do
            if matchPattern o.name pattern:p do appendIfUnique ruins o.name
    InLab_RegistrarVerif "V-21" "Nomes de objeto descritivos [lógica inferida]" (ruins.count == 0) (if ruins.count == 0 then "sem nomes default do Max" else (ruins as string)) critico:false
)

fn InLab_V22_NomesUnicos objetos =
(
    local vistos = #()
    local dups = #()
    for o in objetos do
    (
        local n = toLower o.name
        if (findItem vistos n) > 0 then appendIfUnique dups o.name
        else append vistos n
    )
    InLab_RegistrarVerif "V-22" "Nomes de objeto únicos [lógica inferida]" (dups.count == 0) (if dups.count == 0 then "sem duplicatas" else (dups as string)) critico:false
)
