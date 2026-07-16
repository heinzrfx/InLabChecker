/*
================================================================================
 verifications\verif_peso_poly.ms — V-01 a V-06
--------------------------------------------------------------------------------
 Peso de arquivo, faixa de polígonos e draw calls. Todos os limites vêm da
 FamiliaConfig e passam pela flag INLAB_LIMITES_PROVISORIOS (advertência até
 validação do Birô).
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

-- V-03/V-04 · Total de polígonos dentro da faixa [polyMin, polyMax].
fn InLab_V03_V04_Poligonos cfg objetos =
(
    local total = InLab_ContarPoligonos objetos
    InLab_RegistrarVerif "V-03" "Polígonos — teto" (total <= cfg.polyMax) (total as string + " faces · teto " + cfg.polyMax as string) provisorio:true
    InLab_RegistrarVerif "V-04" "Polígonos — piso" (total >= cfg.polyMin) (total as string + " faces · piso " + cfg.polyMin as string) critico:false
)

-- V-05 · Draw calls ≈ número de objetos de geometria. Regra dura codificada
-- só para as famílias com contagem fixa; demais reportam a contagem contra
-- a regra descritiva da config.
fn InLab_V05_DrawCalls cfg objetos =
(
    local n = objetos.count
    local ok = true
    if cfg.nome == "corpo_unico" or cfg.nome == "pernas_tampo" do ok = (n <= 2)
    InLab_RegistrarVerif "V-05" "Draw calls (contagem de objetos)" ok (n as string + " objeto(s) · regra da família: " + cfg.drawCallsRule) provisorio:true
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
