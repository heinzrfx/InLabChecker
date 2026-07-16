/*
================================================================================
 core\struct_familia.ms
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Define o struct FamiliaConfig — substituto MaxScript-nativo do JSON de família
 da spec v2.0 (seção 2.2) — e o registro global onde as 8 famílias se inscrevem
 ao serem carregadas via fileIn.

 Cada arquivo em familias\ instancia este struct como variável global
 (ex.: cfgGiroAssento) e chama InLab_RegistrarFamilia no final.

 DECISÃO (Fase 4, 08/Jul): "max_ratio_v_t" incluído como maxRatioVT (V-07).
 "behaviors" do JSON original ficou de fora — nenhuma verificação o consome.
================================================================================
*/

struct FamiliaConfig
(
    nome             = "",         -- identificador interno, ex.: "giro_assento"
    lote             = 1,          -- 1 (estáticas) ou 2 (animadas)
    animado          = false,      -- equivalente a has_animation do JSON
    animationType    = "",         -- "translacao", "rotacao", "giro_assento", "movimento_especial"
    pivotRule        = "",         -- regra de pivot de animação (tabela seção 4 da spec)
    maxFileMB        = 0,          -- peso máximo do .max (V-01)
    maxSkpMB         = undefined,  -- peso máximo do .skp (V-02) — só algumas famílias usam
    polyMin          = 0,          -- faixa de polígonos (V-03/04)
    polyMax          = 0,
    maxRatioVT       = 1.2,        -- V-07: ratio v/t máximo (spec 2.2 · provisório para todas as famílias)
    drawCallsRule    = "",         -- string descritiva; a regra é codificada na verificação (V-05), não interpretada em runtime
    requiresInterior = false,      -- V-39: interior modelado obrigatório (Translação/Rotação)
    tampoAcessorio   = false,      -- V-38: só relevante para Pernas+Tampo
    materialTypes    = #(),        -- ex.: #("zona_acabamento"), #("palha"), #("cristal") → V-35/36/37
    validNames       = #(),        -- V-20: vazio até a nomenclatura oficial ser definida (fica em advertência)

    -- Gera a descrição da config como ARRAY de linhas, prontas para o log da UI.
    -- (o listbox do log trabalha linha a linha, por isso não retorna string única)
    fn linhasDescricao =
    (
        local L = #()
        append L ("Família: " + nome + "  ·  Lote " + lote as string)
        append L ("Animação: " + (if animado then ("sim — tipo: " + animationType) else "não"))
        if animado do append L ("Regra de pivot: " + pivotRule)
        local pesoTxt = "Peso MAX: até " + maxFileMB as string + " MB"
        if maxSkpMB != undefined do pesoTxt += "  ·  SKP: até " + maxSkpMB as string + " MB"
        append L pesoTxt
        append L ("Polígonos: " + polyMin as string + " a " + polyMax as string + " · ratio v/t máx " + maxRatioVT as string)
        append L ("Draw calls: " + drawCallsRule)
        append L ("Interior modelado (V-39): " + (if requiresInterior then "obrigatório" else "não se aplica"))
        append L ("Tampo acessório (V-38): " + (if tampoAcessorio then "sim" else "não"))
        append L ("Materiais especiais: " + (if materialTypes.count > 0 then (materialTypes as string) else "nenhum"))
        append L ("Nomes válidos (V-20): " + (if validNames.count == 0 then "pendente — verificação em modo advertência" else (validNames as string)))
        L
    )
)

--------------------------------------------------------------------------------
-- REGISTRO GLOBAL DE FAMÍLIAS
--------------------------------------------------------------------------------

-- Array com as 8 configs registradas (populado pelos arquivos de familias\).
global InLab_Familias = #()

-- Família atualmente selecionada na UI (setada pelo botão "Carregar Configuração").
global InLab_FamiliaAtiva = undefined

-- Registra uma config no array global. Se uma família com o mesmo nome já
-- existir, SUBSTITUI — isso permite re-executar fileIn de um arquivo de família
-- durante o desenvolvimento sem duplicar entradas.
fn InLab_RegistrarFamilia cfg =
(
    local idx = 0
    for i = 1 to InLab_Familias.count where InLab_Familias[i].nome == cfg.nome do idx = i
    if idx > 0 then InLab_Familias[idx] = cfg
    else append InLab_Familias cfg
    cfg
)

-- Busca uma config pelo nome interno (ex.: "giro_assento").
-- Retorna undefined se não encontrada.
fn InLab_ObterFamilia nomeFam =
(
    local encontrada = undefined
    for f in InLab_Familias where f.nome == nomeFam do encontrada = f
    encontrada
)
