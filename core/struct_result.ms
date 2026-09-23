/*
================================================================================
 core\struct_result.ms
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Define o struct VerifResult — a unidade de saída de CADA verificação (V-01 a
 V-40) — e o coletor global de resultados que o report_generator.ms (Fase 5)
 vai consumir no final da execução.

 Regra de aprovação (spec v2.0, seção 1):
   aprovado = 100% dos resultados com critico:true em status:#pass.
   Itens critico:false aparecem no relatório mas não bloqueiam a aprovação.
   Implementados hoje como não críticos: V-02 (SKP, externa), V-04 (enquanto
   limitesPorParte estiver vazio), V-05 (famílias sem regra numérica), V-06,
   V-20, V-22 e V-30 em família estática. Previstos na spec: V-33, V-37 a V-40.
   Falha em limite provisorio:true também vira não crítica (ver abaixo).
   (Lista atualizada em 23/09/2026, issue #35.)
================================================================================
*/

struct VerifResult
(
    id       = "",      -- identificador da verificação, ex.: "V-31"
    nome     = "",      -- nome curto, ex.: "Pivot de giro de assento"
    status   = #pass,   -- #pass / #fail / #warning
    mensagem = "",      -- texto explicativo que vai para o relatório
    critico  = true,    -- true = bloqueia aprovação; false = advertência

    -- Converte o status (name) em texto legível para log/relatório.
    fn statusTexto =
    (
        case status of
        (
            #pass:    "PASS "
            #fail:    "FAIL "
            #warning: "AVISO"
            default:  "  ?  "
        )
    ),

    -- Formata o resultado em uma linha única, pronta para o log ou relatório.
    -- Ex.: "[FAIL ] V-31 — Pivot de giro de assento: pivot em Z=0"
    fn linha =
    (
        local txt = "[" + statusTexto() + "] " + id + " — " + nome
        if mensagem != "" do txt += ": " + mensagem
        txt
    )
)

--------------------------------------------------------------------------------
-- COLETOR GLOBAL DE RESULTADOS
-- Cada função de verificação (Fase 4) chama InLab_AdicionarResultado durante a
-- execução. O relatório final (Fase 5) lê este array.
--------------------------------------------------------------------------------
global InLab_VerifResults = #()

-- Zera o coletor. Deve ser chamado no início de cada rodada de verificação.
fn InLab_ResetarResultados =
(
    InLab_VerifResults = #()
)

-- Adiciona um VerifResult ao coletor e o retorna (permite encadear com log).
fn InLab_AdicionarResultado r =
(
    append InLab_VerifResults r
    r
)

-- Calcula a aprovação final: false se QUALQUER item crítico não passou.
fn InLab_AprovacaoFinal =
(
    local aprovado = true
    for r in InLab_VerifResults where r.critico and r.status != #pass do aprovado = false
    aprovado
)


--------------------------------------------------------------------------------
-- FLAG DE LIMITES PROVISÓRIOS (spec, seção 6): enquanto o Birô não validar
-- os tetos de peso/polígono/draw calls, estouro desses limites vira
-- ADVERTÊNCIA em vez de reprovação. Quando validados → mudar para false.
--------------------------------------------------------------------------------
global INLAB_LIMITES_PROVISORIOS = true

--------------------------------------------------------------------------------
-- FÁBRICA DE RESULTADOS: cria o VerifResult, aplica o rebaixamento de limite
-- provisório quando aplicável, registra no coletor E loga a linha — ponto
-- único usado por todas as verificações da Fase 4.
--   passou     → true/false
--   critico    → se a falha bloqueia aprovação
--   provisorio → true para checks de limite ainda não validados pelo Birô
--------------------------------------------------------------------------------
fn InLab_RegistrarVerif idV nomeV passou msgTexto critico:true provisorio:false =
(
    local r = VerifResult()
    r.id       = idV
    r.nome     = nomeV
    r.mensagem = msgTexto
    r.critico  = critico

    if passou then r.status = #pass
    else if provisorio and INLAB_LIMITES_PROVISORIOS then
    (
        r.status   = #warning
        r.critico  = false
        r.mensagem += " [limite provisório — não reprova até validação do Birô]"
    )
    else r.status = if critico then #fail else #warning

    InLab_AdicionarResultado r

    -- case em forma multi-linha: a forma inline com ";" não parseia dentro
    -- de argumento nomeado (erro constatado em 13/Jul).
    local tipoLog = case r.status of
    (
        #pass:    #ok
        #fail:    #err
        #warning: #warn
        default:  #info
    )
    InLab_Log (r.linha()) tipo:tipoLog
    r
)
