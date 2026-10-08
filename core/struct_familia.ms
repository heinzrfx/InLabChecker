/*
================================================================================
 core\struct_familia.ms
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Define o struct FamiliaConfig — substituto MaxScript-nativo do JSON de família
 da spec v2.0 (seção 2.2) — e o registro global onde as 10 famílias se inscrevem
 ao serem carregadas via fileIn.

 Cada arquivo em familias\ instancia este struct como variável global
 (ex.: cfgGiroAssento) e chama InLab_RegistrarFamilia no final.

 DECISÃO (Fase 4, 08/Jul): "max_ratio_v_t" incluído como maxRatioVT (V-07).
 "behaviors" do JSON original ficou de fora — nenhuma verificação o consome.

 23/09/2026: InLab_DefinirFamiliaAtiva e InLab_FamiliaRotulo. A família ativa
 voltou a ter quem a defina (dropdown Família da seção Produto) — ver a nota
 em InLab_FamiliaAtiva abaixo.

 02/10/2026: InLab_FamiliasDaUI. O v1 do plugin trata produto animado como
 estático (Bianca, respostas v3), então o dropdown Família mostra só as 4
 estruturais. As 4 animadas continuam registradas, com as verificações e os
 testes delas: para o v2 basta INLAB_FAMILIAS_ANIMADAS_NA_UI = true.

 08/10/2026 (issue #138): a família vem da "natureza" do produto no JSON v7
 em diante. Saem o dropdown, InLab_FamiliasDaUI e
 INLAB_FAMILIAS_ANIMADAS_NA_UI: produto animado usa a família animada que o
 JSON mandar. Sai também o campo validNames (V-20): os nomes válidos vêm
 sempre do produto importado.

 05/10/2026 (issue #36): saiu o campo limitesPorParte, junto com a V-04
 (ver o cabeçalho de verifications\verif_peso_poly.ms).

 05/10/2026: famílias Corpo + Portas/Gavetas e Base + Cabeceira (arquétipos
 4 e 5 da equipe), com limites provisórios. São 10: 6 estruturais + 4
 animadas.
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
    drawCallsRule    = "",         -- string descritiva da composição esperada (só texto, não é interpretada)
    maxDrawCalls     = undefined,  -- V-05: teto de draw calls (materiais usados, somados por objeto). Provisório; o ini pode sobrescrever (maxDrawCalls_<nome>)
    requiresInterior = false,      -- V-39: interior modelado obrigatório (Translação/Rotação)
    tampoAcessorio   = false,      -- V-38: só relevante para Pernas+Tampo
    materialTypes    = #(),        -- ex.: #("zona_acabamento"), #("palha"), #("cristal") → V-35/36/37

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
        append L ("Draw calls: até " + (if maxDrawCalls == undefined then "?" else maxDrawCalls as string) + " · " + drawCallsRule)
        append L ("Interior modelado (V-39): " + (if requiresInterior then "obrigatório" else "não se aplica"))
        append L ("Tampo acessório (V-38): " + (if tampoAcessorio then "sim" else "não"))
        append L ("Materiais especiais: " + (if materialTypes.count > 0 then (materialTypes as string) else "nenhum"))
        L
    )
)

--------------------------------------------------------------------------------
-- REGISTRO GLOBAL DE FAMÍLIAS
--------------------------------------------------------------------------------

-- Array com as 10 configs registradas (populado pelos arquivos de familias\).
global InLab_Familias = #()

-- Família atualmente selecionada na UI.
--
-- 23/09/2026: ficou ÓRFÃ da Fase 5.2 até hoje — a seção Família (dropdown +
-- "Carregar Configuração") saiu da UI e nada mais atribuía este global, então
-- "Rodar Verificações" e o modo "Alvo da família" do ProOptimizer nunca
-- rodavam. Agora é atribuída SÓ por InLab_DefinirFamiliaAtiva.
-- 08/10/2026 (issue #138): quem chama é a seção Produto (ui\rollout_main.ms),
-- com a "natureza" do produto escolhido (InLab_Produto_Familia,
-- functions\fn_renomear_produto.ms). Não há mais dropdown nem sugestão pela
-- classe. O campo "familia" do JSON continua sendo a LINHA comercial.
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
global InLab_ObterFamilia
fn InLab_ObterFamilia nomeFam =
(
    local encontrada = undefined
    for f in InLab_Familias where f.nome == nomeFam do encontrada = f
    encontrada
)

-- Nome legível para a UI e o log ("giro_assento" → "Giro de Assento").
global InLab_FamiliaRotulo
fn InLab_FamiliaRotulo nomeFam =
(
    case nomeFam of
    (
        "corpo_unico":         "Corpo Único"
        "pernas_tampo":        "Pernas + Tampo"
        "estrutura_estofado":  "Estrutura + Estofado"
        "estrutura_modular":   "Estrutura Modular"
        "corpo_portas_gavetas": "Corpo + Portas/Gavetas"
        "base_cabeceira":      "Base + Cabeceira"
        "translacao":          "Translação (gavetas)"
        "rotacao":             "Rotação (portas / pratos)"
        "giro_assento":        "Giro de Assento"
        "movimento_especial":  "Movimento Especial"
        default:               nomeFam
    )
)

-- Define a família ativa pelo nome interno ("" ou undefined limpa). Loga a
-- config inteira, para o modelador ver os limites que as verificações vão
-- usar. Devolve a config (ou undefined se o nome não existir).
global InLab_DefinirFamiliaAtiva
fn InLab_DefinirFamiliaAtiva nomeFam =
(
    if nomeFam == undefined or nomeFam == "" then
    (
        InLab_FamiliaAtiva = undefined
        InLab_Log "Família ativa: nenhuma." tipo:#info
    )
    else
    (
        local cfg = InLab_ObterFamilia nomeFam
        if cfg == undefined then
            InLab_Log ("Família '" + nomeFam + "' não está registrada — família ativa mantida.") tipo:#err
        else
        (
            InLab_FamiliaAtiva = cfg
            InLab_Log ("Família ativa: " + (InLab_FamiliaRotulo nomeFam)) tipo:#ok
            for l in cfg.linhasDescricao() do InLab_Log ("   " + l) tipo:#info
        )
    )
    InLab_FamiliaAtiva
)

