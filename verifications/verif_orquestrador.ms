/*
================================================================================
 verifications\verif_orquestrador.ms — FUNÇÃO 7 (motor de verificação)
--------------------------------------------------------------------------------
 Roda as verificações na ORDEM DE CUSTO CRESCENTE da spec (seção 5), para a
 família selecionada, sobre TODA a geometria da cena (1 bloco = 1 arquivo).

 STATUS DA IMPLEMENTAÇÃO:
   Grupo 1 (rápidas)        → V-19, V-01/02, V-17/18            [ENTREGUE]
   Grupo 2 (config/família) → V-30                               [ENTREGUE]
   Grupo 3 (médias)         → V-20/21/22, V-03/05/06, V-11/12    [ENTREGUE — auditado contra spec v1.0/v2.0; V-04 removida em 05/10/2026]
   Grupo 4 (animação)       → V-26, V-31/32/33, V-34, V-40       [próxima entrega]
   Grupo 5 (UV)             → V-14/15/16, V-29/V-39              [próxima entrega]
   Grupo 6 (pesadas)        → V-07, V-08/09/10/13                [ENTREGUE 05/10/2026 — verif_malha.ms, issue #102]
   Grupo 7 (materiais)      → V-23/24/25, V-35/36/37, V-38       [próxima entrega]

 REVISÃO DO GRUPO 3 (auditoria pós-entrega, corrigindo divergências da spec):
   V-03  → agora é UMA verificação só: total de polígonos dentro da faixa
           [polyMin, polyMax] da família. (Antes o "V-04" testava o piso da
           mesma faixa, duplicando o V-03 e deixando o V-04 real vago.)
   V-04  → reescrita para o que a spec pede de fato: limite individual de
           polígonos por parte nomeada (cfg.limitesPorParte). Fica em modo
           advertência até esses limites serem definidos por família.
           05/10/2026 (issue #36): REMOVIDA. O produto estático chega como
           uma mesh só (codEst), sem objeto por parte para medir.
   V-05  → agora cobre as 8 famílias: numérico p/ corpo_unico, pernas_tampo
           e giro_assento (regra fixa); advertência p/ as demais ("1 por
           parte" não é verificável até a nomenclatura oficial existir).
   V-17  → tolerância corrigida para ±1mm fixo (spec), e passou a checar o
           pivot em Z=0 do MUNDO, não só a base do próprio objeto.
   V-21  → reescrita: nomes sem acento/espaço ([A-Za-z0-9_]), como a spec
           v1.0 define. (Estava checando nome-default do Max, sem relação
           com o V-21 real.)
   V-22  → reescrita: sufixos numéricos sequenciais sem lacuna (_01, _02...),
           como a spec v1.0 define. (Estava checando duplicata de nome, sem
           relação com o V-22 real — essa checagem de duplicata foi removida
           por ora, pode voltar como um V extra se for útil.)

 28/09/2026 (issue #33): InLab_SalvarAntesDeVerificar — o botão pergunta se
 quer salvar quando a cena nunca foi salva ou tem alterações pendentes, para
 a V-01 medir o arquivo certo (sem salvar, ela sai "não medido").

 28/09/2026 (issue #35): Bones/Biped/CAT saem do universo (InLab_EhGeometria);
 objeto oculto continua contando e a EX-01 (verif_geometria.ms) avisa.

 28/09/2026 (issue #37): codEst:/nomeProduto: (produto escolhido na UI) vão
 para o relatório em arquivo (report_generator.ms: JSON + HTML).

 02/10/2026 (issue #36): produto: (o produto escolhido na seção Produto) vai
 para a V-20, que confere arquivo, objetos e materiais contra os nomes dele.
================================================================================
*/

-- Propriedade do PRODUTO (não da família): informada pelo checkbox da UI.
-- Consumida pela V-38 (Grupo 7).
global InLab_TampoAcessorioProduto = false

-- Universo da verificação: toda a geometria renderizável da cena.
fn InLab_ObjetosVerificacao =
(
    for o in geometry where InLab_EhGeometria o collect o
)

-- 28/09/2026 (issue #33): chamada pelo botão ANTES de InLab_RodarVerificacoes.
-- Cena nunca salva ou com alterações pendentes: pergunta se quer salvar, para
-- a V-01 medir o arquivo certo. Sim → salva (Salvar Como na cena nova); Não →
-- roda assim mesmo e a V-01 sai "não medido"; Cancelar → não roda.
-- Devolve true para seguir, false para cancelar. resposta: só para teste
-- (pula a caixa de diálogo, que é modal).
fn InLab_SalvarAntesDeVerificar resposta:unsupplied =
(
    local nuncaSalva = (maxFileName == "")
    if not nuncaSalva and not (getSaveRequired()) then true
    else
    (
        if resposta == unsupplied do
            resposta = yesNoCancelBox ((if nuncaSalva then "A cena ainda não foi salva." else "A cena tem alterações não salvas.") + \
                "\n\nSalvar antes de verificar? Sem salvar, o peso do arquivo (V-01) não é medido.") title:"InLab · Verificações"
        case resposta of
        (
            #yes:
            (
                local caminho = if nuncaSalva then getMaxSaveFileName() else (maxFilePath + maxFileName)
                if caminho == undefined then
                (
                    InLab_Log "Salvar cancelado — verificação cancelada." tipo:#warn
                    false
                )
                else if saveMaxFile caminho quiet:true then
                (
                    InLab_Log ("Cena salva antes de verificar: " + caminho) tipo:#ok
                    true
                )
                else
                (
                    InLab_Log ("Não foi possível salvar em " + caminho + " — V-01 não será medida.") tipo:#err
                    true
                )
            )
            #no:
            (
                InLab_Log "Verificando sem salvar — V-01 (peso do arquivo) não será medida." tipo:#warn
                true
            )
            default:
            (
                InLab_Log "Verificação cancelada." tipo:#info
                false
            )
        )
    )
)

fn InLab_RodarVerificacoes cfg tampoAcessorio:false codEst:"" nomeProduto:"" produto:undefined =
(
    InLab_TampoAcessorioProduto = tampoAcessorio
    InLab_ResetarResultados()
    local objetos = InLab_ObjetosVerificacao()

    InLab_Log ("========= VERIFICAÇÃO · família '" + cfg.nome + "' · " + objetos.count as string + " objeto(s) =========")
    if objetos.count == 0 then
    (
        InLab_Log "Cena sem geometria — nada a verificar." tipo:#err
        false
    )
    else
    (
        -- ===== Grupo 1 · Rápidas =====
        InLab_RegistrarVerif "V-19" "Unidade do sistema" (units.SystemType == INLAB_UNIDADE_PADRAO) ((units.SystemType as string) + " · padrão InLab: " + INLAB_UNIDADE_PADRAO as string) critico:true
        InLab_V01_PesoMax cfg
        InLab_V02_PesoSKP cfg
        InLab_V17_PivotRaiz objetos
        InLab_V18_EixosPivot objetos

        -- ===== Grupo 2 · Config/família =====
        InLab_V30_Keyframes cfg objetos

        -- ===== Grupo 3 · Médias =====
        InLab_V20_Nomenclatura cfg produto:produto objetos:objetos
        InLab_V21_NomesValidos objetos
        InLab_V22_SufixosSequenciais objetos
        InLab_V03_Poligonos cfg objetos
        InLab_V05_DrawCalls cfg objetos
        InLab_V06_SugestaoAttach objetos
        InLab_V11_Modificadores objetos
        InLab_V12_XForm objetos
        InLab_VEx01_Ocultos objetos

        -- ===== Grupo 6 · Pesadas (issue #102, verif_malha.ms) =====
        InLab_V07_RatioVT cfg objetos
        local analises = InLab_Malha_AnalisarCena objetos
        InLab_V08_MalhaFechada analises
        InLab_V09_Duplicados analises objetos
        InLab_V10_Normais analises
        InLab_V13_Ngons analises

        -- ===== Grupos 4, 5 e 7 · próximas entregas =====
        InLab_Log "Grupos 4, 5 e 7 (animação avançada, UV, materiais) ainda não implementados — relatório parcial." tipo:#warn

        InLab_GerarRelatorio cfg codEst:codEst nomeProduto:nomeProduto
    )
)
