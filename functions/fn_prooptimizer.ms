/*
================================================================================
 functions\fn_prooptimizer.ms — FUNÇÃO 1 (Fase 1.1)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Aplica o modificador ProOptimizer sobre um conjunto de objetos, com dois
 modos de operação (decididos na UI):
   - percentual manual (VertexPercent direto)
   - alvo da família: percentual calculado para levar o TOTAL de polígonos
     da seleção até o polyMax da família ativa

 ESTRATÉGIA DE UNDO (requisito funcional 1) — duas camadas:
   1. Toda a operação roda dentro de "undo ... on" → Ctrl+Z padrão do Max.
   2. Registro dedicado: cada modificador aplicado fica guardado em
      InLab_UltimaOtimizacao. InLab_ReverterOtimizacao() remove EXATAMENTE
      esses modificadores, mesmo que o usuário tenha feito outras ações
      depois (cenário em que o Ctrl+Z simples não resolve).
 Para o revert funcionar, o ProOptimizer é mantido como MODIFICADOR VIVO
 no stack — o colapso fica para a etapa de export (Fase 3).

 NOTAS TÉCNICAS:
 - ProOptimizer reduz por VÉRTICES (VertexPercent), não faces. A redução de
   faces acompanha aproximadamente; o log reporta a contagem REAL de faces
   antes/depois por objeto.
 - Cada set de propriedade está em try/catch individual: se algum nome de
   propriedade divergir na sua versão do Max/Corona, o log aponta qual.
   Nesse caso, rodar no Listener:  showProperties (ProOptimizer())
   e me enviar a saída para eu ajustar os nomes.
================================================================================
*/

-- Registro de uma otimização aplicada a um objeto (para o revert dedicado).
struct OtimizacaoRecord
(
    no,             -- o nó da cena
    modificador,    -- a instância exata do ProOptimizer adicionada
    polysAntes,     -- contagem de faces antes
    polysDepois     -- contagem de faces depois
)

-- Registros da ÚLTIMA rodada de otimização. Sobrescrito a cada execução.
global InLab_UltimaOtimizacao = #()

--------------------------------------------------------------------------------
-- Percentual necessário para levar o TOTAL de polígonos de `objs` até
-- `alvoPoly` (polyMax da família). Retorna 100.0 se já está no alvo.
--------------------------------------------------------------------------------
fn InLab_PercentualParaAlvo objs alvoPoly =
(
    local total = InLab_ContarPoligonos objs
    if total <= alvoPoly or total == 0 then 100.0
    else amax 1.0 (100.0 * alvoPoly / total)
)

--------------------------------------------------------------------------------
-- Aplica o ProOptimizer.
--   objs        → array de nós (já validado pela UI)
--   percentual  → VertexPercent (1.0–100.0)
--   manterUV    → preserva UVs durante a otimização (padrão true)
-- Retorna o número de objetos efetivamente otimizados.
--------------------------------------------------------------------------------
fn InLab_ProOptimizer objs percentual manterUV:true =
(
    InLab_UltimaOtimizacao = #()
    local otimizados = 0

    if percentual >= 100.0 then
    (
        InLab_Log "Percentual = 100% — nada a otimizar (seleção já dentro do alvo)." tipo:#warn
        0
    )
    else
    (
        -- Camada 1 de undo: bloco nomeado no histórico do Max.
        undo "InLab ProOptimizer" on
        (
            for o in objs where InLab_EhGeometria o do
            (
                -- MEDIÇÃO CONSISTENTE (bug 1): o ProOptimizer emite TRIÂNGULOS;
                -- comparar quads (antes) com tris (depois) dava a ilusão de
                -- "dobrar polígonos". Antes/depois agora medem sempre a
                -- trimesh (tris + vértices).
                local triAntes  = (GetTriMeshFaceCount o)[1]
                local vertAntes = (GetTriMeshFaceCount o)[2]

                local po = ProOptimizer()
                addModifier o po

                try ( po.KeepUV = manterUV )
                catch ( InLab_Log ("ProOptimizer.KeepUV indisponível em '" + o.name + "'") tipo:#err )

                -- ORDEM CORRIGIDA (bug 1): "Calculate" PRIMEIRO, percentual
                -- DEPOIS — como no fluxo da UI do modificador. Na ordem
                -- invertida o percentual não aplica e a malha passa sem
                -- redução (vértices idênticos).
                try ( po.CalculationEnabled = true )
                catch ( InLab_Log ("ProOptimizer.CalculationEnabled indisponível em '" + o.name + "'") tipo:#err )

                try ( po.VertexPercent = percentual )
                catch ( InLab_Log ("ProOptimizer.VertexPercent indisponível em '" + o.name + "'") tipo:#err )

                local triDepois  = (GetTriMeshFaceCount o)[1]
                local vertDepois = (GetTriMeshFaceCount o)[2]
                local antes  = triAntes
                local depois = triDepois

                -- Camada 2 de undo: registro dedicado para revert cirúrgico.
                local rec = OtimizacaoRecord()
                rec.no          = o
                rec.modificador = po
                rec.polysAntes  = antes
                rec.polysDepois = depois
                append InLab_UltimaOtimizacao rec

                InLab_Log (o.name + ": " + triAntes as string + " -> " + triDepois as string + " tris · " +
                           vertAntes as string + " -> " + vertDepois as string + " verts") tipo:#ok
                otimizados += 1
            )
        )
        InLab_Log ("ProOptimizer aplicado a " + otimizados as string +
                   " objeto(s) com VertexPercent = " + (formattedPrint percentual format:".1f") + "%.")
        otimizados
    )
)

--------------------------------------------------------------------------------
-- Reverte a ÚLTIMA rodada: remove do stack exatamente os modificadores
-- registrados, mesmo que outras ações tenham acontecido depois.
--------------------------------------------------------------------------------
fn InLab_ReverterOtimizacao =
(
    if InLab_UltimaOtimizacao.count == 0 then
        InLab_Log "Nenhuma otimização registrada nesta sessão para reverter." tipo:#warn
    else
    (
        local revertidos = 0
        undo "InLab Reverter ProOptimizer" on
        (
            for r in InLab_UltimaOtimizacao do
            (
                -- isValidNode protege contra objetos deletados após a otimização.
                if isValidNode r.no then
                (
                    try
                    (
                        deleteModifier r.no r.modificador
                        InLab_Log (r.no.name + ": ProOptimizer removido (volta a " +
                                   r.polysAntes as string + " faces).") tipo:#ok
                        revertidos += 1
                    )
                    catch
                    (
                        InLab_Log (r.no.name + ": modificador não encontrado no stack (colapsado ou removido?).") tipo:#warn
                    )
                )
                else InLab_Log "Objeto do registro não existe mais na cena." tipo:#warn
            )
        )
        InLab_UltimaOtimizacao = #()
        InLab_Log ("Reversão concluída: " + revertidos as string + " objeto(s).")
    )
)
