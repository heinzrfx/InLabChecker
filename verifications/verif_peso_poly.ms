/*
================================================================================
 verifications\verif_peso_poly.ms — V-01 a V-06
--------------------------------------------------------------------------------
 Peso de arquivo, faixa de polígonos e draw calls. Todos os limites vêm da
 FamiliaConfig e passam pela flag INLAB_LIMITES_PROVISORIOS (advertência até
 validação do Birô).

 23/09/2026 (issue #60): V-03 e V-04 passaram de polígonos do Max
 (`InLab_ContarPoligonos`) para triângulos (`InLab_Otim_Triangulos`,
 functions\fn_otim_nucleo.ms) — a mesma unidade que o GLB carrega. A V-05
 conta objetos (draw calls) e não muda.
================================================================================
*/

-- V-01 · Peso do arquivo .max vs teto da família.
fn InLab_V01_PesoMax cfg =
(
    local mb = InLab_TamanhoCenaMB()
    if mb == undefined then
        InLab_RegistrarVerif "V-01" "Peso do arquivo MAX" false "cena não salva — salvar antes de verificar" critico:true
    else
        InLab_RegistrarVerif "V-01" "Peso do arquivo MAX" (mb <= cfg.maxFileMB) ((InLab_FormatarMB mb) + " · teto " + cfg.maxFileMB as string + " MB") provisorio:true
)

-- V-02 · Peso do .skp: arquivo SketchUp não é acessível de dentro do Max —
-- fica como advertência de verificação externa (só nas famílias que o usam).
fn InLab_V02_PesoSKP cfg =
(
    if cfg.maxSkpMB == undefined then
        InLab_RegistrarVerif "V-02" "Peso do arquivo SKP" true "não se aplica a esta família"
    else
        InLab_RegistrarVerif "V-02" "Peso do arquivo SKP" false ("verificação externa — teto " + cfg.maxSkpMB as string + " MB (SKP fora do escopo do Max)") critico:false
)

-- V-03 · Total de TRIÂNGULOS dentro da faixa [polyMin, polyMax] da família.
-- 23/09/2026 (issue #60): passou de polígonos do Max para triângulos — o que
-- o GLB carrega (spec 2026-09-23-otimizacao-design.md). As faixas das
-- famílias foram escritas sem unidade: conferir com a equipe (#36).
fn InLab_V03_Poligonos cfg objetos =
(
    local total = InLab_Otim_Triangulos objetos
    local dentro = (total >= cfg.polyMin) and (total <= cfg.polyMax)
    local msg = total as string + " triângulos · faixa " + cfg.polyMin as string + "–" + cfg.polyMax as string + " (unidade da faixa a confirmar, #36)"
    InLab_RegistrarVerif "V-03" "Triângulos totais (faixa da família)" dentro msg provisorio:true
)

-- V-04 · Distribuição por parte nomeada (spec 2.2 · seção 2.4 v1.0).
-- Só valida partes com limite definido em cfg.limitesPorParte — igual ao
-- padrão já usado no V-20 para nomenclatura pendente.
fn InLab_V04_PoligonosPorParte cfg objetos =
(
    if cfg.limitesPorParte.count == 0 then
    (
        InLab_RegistrarVerif "V-04" "Polígonos por parte (limite individual)" true "sem limites por parte definidos para esta família — pendente (spec 2.2)" critico:false
    )
    else
    (
        local problemas = #()
        for regra in cfg.limitesPorParte do
        (
            local prefixo = regra[1]
            local limite  = regra[2]
            for o in objetos where (matchPattern o.name pattern:(prefixo + "*") ignoreCase:true) do
            (
                local n = InLab_Otim_Triangulos #(o)   -- triângulos (issue #60)
                if n > limite do append problemas (o.name + ": " + n as string + " > " + limite as string + " (" + prefixo + ")")
            )
        )
        local msg = if problemas.count == 0 then "todas as partes dentro do limite individual" else (problemas as string)
        InLab_RegistrarVerif "V-04" "Polígonos por parte (limite individual)" (problemas.count == 0) msg critico:true
    )
)

-- V-05 · Draw calls por regra da família (spec v2.0 · seção 2.3).
-- Famílias com regra FIXA são validadas numericamente. Famílias "1 por parte"
-- não têm como ser validadas ainda: o número de partes esperadas depende da
-- nomenclatura oficial (validNames), que está pendente — mesmo caso do V-20.
fn InLab_V05_DrawCalls cfg objetos =
(
    local n = objetos.count
    case cfg.nome of
    (
        "corpo_unico":    InLab_RegistrarVerif "V-05" "Draw calls" (n <= 2) (n as string + " objeto(s) · regra: " + cfg.drawCallsRule) provisorio:true
        "pernas_tampo":   InLab_RegistrarVerif "V-05" "Draw calls" (n <= 2) (n as string + " objeto(s) · regra: " + cfg.drawCallsRule) provisorio:true
        "giro_assento":   InLab_RegistrarVerif "V-05" "Draw calls" (n <= 2) (n as string + " objeto(s) · regra: " + cfg.drawCallsRule) provisorio:true
        default:          InLab_RegistrarVerif "V-05" "Draw calls" true (n as string + " objeto(s) · regra: '" + cfg.drawCallsRule + "' — não verificável numericamente até nomenclatura oficial (valid_names) definir as partes esperadas") critico:false
    )
)

-- V-06 · Sugestão de Attach: objetos compartilhando o MESMO material são
-- candidatos a Attach (reduz draw calls). Advertência.
fn InLab_V06_SugestaoAttach objetos =
(
    local vistos = #()
    local sugest = 0
    for o in objetos where o.material != undefined do
    (
        local idx = 0
        for i = 1 to vistos.count where vistos[i] == o.material do idx = i
        if idx > 0 then sugest += 1 else append vistos o.material
    )
    InLab_RegistrarVerif "V-06" "Attach de partes (draw calls)" (sugest == 0) (if sugest == 0 then "sem duplicidade de material entre objetos" else (sugest as string + " objeto(s) compartilham material com outro — candidatos a Attach")) critico:false
)
