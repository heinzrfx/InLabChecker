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

 28/09/2026 (issue #33): V-01 não mede mais arquivo velho nem reprova cena
 nunca salva — as duas viram advertência "não medido" (ver a função).

 28/09/2026 (issue #32): V-05 passou a contar draw calls reais (materiais
 usados, somados por objeto) contra `maxDrawCalls` da família, que o ini pode
 sobrescrever. Tetos: docs\superpowers\specs\2026-09-28-draw-calls-benchmark.md.
================================================================================
*/

-- V-01 · Peso do arquivo .max vs teto da família.
-- 28/09/2026 (issue #33): só mede o arquivo em disco quando ele é a cena
-- atual. Cena nunca salva ou com alterações pendentes (getSaveRequired) vira
-- advertência "não medido" em vez de FAIL crítico (nunca salva) ou de medir
-- o arquivo antigo em silêncio (pendente). O pedido de salvar fica antes da
-- rodada, em InLab_SalvarAntesDeVerificar (verif_orquestrador.ms).
-- caminho:/pendente: só para teste (padrão: a cena atual).
fn InLab_V01_PesoMax cfg caminho:unsupplied pendente:unsupplied =
(
    if caminho == unsupplied do caminho = maxFilePath + maxFileName
    if pendente == unsupplied do pendente = getSaveRequired()
    local mb = InLab_TamanhoArquivoMB caminho
    if mb == undefined then
        InLab_RegistrarVerif "V-01" "Peso do arquivo MAX" false "não medido — cena nunca salva" critico:false
    else if pendente then
        InLab_RegistrarVerif "V-01" "Peso do arquivo MAX" false ("não medido — cena com alterações não salvas (o arquivo em disco, " + InLab_FormatarMB mb + ", é do último save)") critico:false
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

-- Draw calls de UM nó no GLB: cada material usado pelas faces vira um
-- primitive (1 draw call). Sem material ou material simples = 1. Multi/Sub =
-- nº de sub-materiais que alguma face usa de fato (slot sem face não é
-- exportado). ID fora de materialIDList cai no slot pelo módulo, como o Max
-- faz no viewport. Instância conta por nó: glTF básico não tem instancing.
-- 28/09/2026 (issue #32).
fn InLab_DrawCallsDoNo o =
(
    local mat = o.material
    if classof mat != Multimaterial or mat.numsubs == 0 then 1
    else
    (
        local slots = #()
        local malha = snapshotAsMesh o
        try
        (
            local ids = #()
            for f = 1 to malha.numfaces while slots.count < mat.numsubs do
            (
                local id = getFaceMatID malha f
                if findItem ids id == 0 do
                (
                    append ids id
                    local k = findItem mat.materialIDList id
                    if k == 0 do k = (mod (id - 1) mat.numsubs) as integer + 1
                    appendIfUnique slots k
                )
            )
        )
        catch ( InLab_Log (o.name + ": não li os IDs de material (" + getCurrentException() + ") — contado como 1 draw call.") tipo:#warn )
        delete malha
        amax #(1, slots.count)
    )
)

-- Teto de draw calls da família. O ini de preferências (core\prefs.ms,
-- chave "maxDrawCalls_<família>") vale no lugar do valor da família: dá para
-- ajustar sem editar o código, e o ini sobrevive às atualizações do plugin.
-- Valor inválido no ini é ignorado com aviso. undefined = família sem teto.
fn InLab_TetoDrawCalls cfg =
(
    local chave = "maxDrawCalls_" + cfg.nome
    local txt = InLab_PrefLer chave ""
    local v = if txt == "" then undefined else (try (txt as integer) catch undefined)
    if txt != "" and (v == undefined or v < 1) do
    (
        InLab_Log ("Preferência " + chave + " = '" + txt + "' não é um inteiro ≥ 1 — usando o teto da família.") tipo:#warn
        v = undefined
    )
    if v != undefined then v else cfg.maxDrawCalls
)

-- V-05 · Draw calls (spec v2.0 · seção 2.3).
-- 28/09/2026 (issue #32): conta DRAW CALLS REAIS do GLB — soma dos materiais
-- usados por objeto (InLab_DrawCallsDoNo) — contra um teto numérico por
-- família (cfg.maxDrawCalls, sobrescrevível pelo ini). Antes contava objetos
-- (≤ 2) só em 3 famílias, e o giro de assento com rodízios sempre estourava.
-- Decisão da issue: rodízios atachados = 1 objeto. Os tetos saíram de um
-- benchmark de guias públicos (ver familias\*.ms) e são provisórios até o
-- Birô validar.
fn InLab_V05_DrawCalls cfg objetos =
(
    local teto = InLab_TetoDrawCalls cfg
    local porNo = for o in objetos collect #(InLab_DrawCallsDoNo o, o.name)
    local total = 0
    for p in porNo do total += p[1]
    local maior = undefined
    for p in porNo where p[1] > 1 and (maior == undefined or p[1] > maior[1]) do maior = p
    local msg = total as string + " draw call(s) em " + objetos.count as string + " objeto(s)"
    if maior != undefined do msg += " · maior: " + maior[2] + " (" + maior[1] as string + " materiais)"
    if teto == undefined then
        InLab_RegistrarVerif "V-05" "Draw calls" false (msg + " · família sem teto definido") critico:false
    else
    (
        msg += " · teto " + teto as string + (if teto != cfg.maxDrawCalls then " (ini)" else "") + " · regra: " + cfg.drawCallsRule
        InLab_RegistrarVerif "V-05" "Draw calls" (total <= teto) msg provisorio:true
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
