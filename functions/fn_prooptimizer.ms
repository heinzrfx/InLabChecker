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
 - A propriedade que dispara o cálculo é '.Calculate' (confirmado por
   showProperties (ProOptimizer()) no Max 2024). Ela é resolvida por sondagem
   (isProperty) para sobreviver a variação entre builds.
 - ARMADILHA PRINCIPAL DESTE MÓDULO: '.Calculate' só executa com o nó
   SELECIONADO e o modificador corrente no painel Modify. Fora desse contexto
   a atribuição é aceita e descartada em silêncio — sem exceção nenhuma. Por
   isso o loop seleciona objeto a objeto e usa modPanel.setCurrentObject, e
   restaura seleção/painel do usuário no final. NÃO REMOVA esse bloco achando
   que é ruído: sem ele o plugin volta a não otimizar nada.
 - FALHA É ALTA, NÃO SILENCIOSA: se o cálculo não disparar, ou se a malha sair
   com o mesmo número de vértices que entrou, o modificador é REMOVIDO e o log
   registra o objeto como não otimizado. Antes o try/catch engolia a falha e a
   função reportava sucesso sobre uma malha intacta.
 - ATENÇÃO À UNIDADE DE CONTAGEM: este módulo mede em TRIÂNGULOS
   (GetTriMeshFaceCount), enquanto core\utils.ms mede em faces do poly
   (getPolygonCount). Numa malha all-quad os dois diferem por 2x. Ver ressalva
   entregue à equipe sobre o polyMax das famílias.
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
-- 23/09/2026: sem uso desde a issue #60 (tela nova); remover na #62/#52.
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
        -- Estado do usuário a ser restaurado no fim: precisamos mexer na
        -- seleção e no painel de comando (ver bloco do Calculate abaixo),
        -- e isso não pode vazar pra quem apertou o botão.
        local selOriginal   = selection as array
        local painelOriginal = getCommandPanelTaskMode()

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

                -- CONTEXTO OBRIGATÓRIO PRO Calculate (bug 15/Set, ver abaixo):
                -- o nó precisa estar SELECIONADO e o painel Modify ativo, e o
                -- modificador precisa ser o objeto CORRENTE do painel. Fora
                -- disso o Calculate é descartado em silêncio.
                select o
                setCommandPanelTaskMode #modify
                try ( subObjectLevel = 0 ) catch ()

                local po = ProOptimizer()
                addModifier o po
                try ( modPanel.setCurrentObject po ) catch ()

                -- As opções (KeepUV etc.) precisam estar setadas ANTES do
                -- cálculo: ele monta a estrutura de otimização já respeitando
                -- esses flags, igual ao fluxo da UI do modificador.
                try ( po.KeepUV = manterUV )
                catch ( InLab_Log ("ProOptimizer.KeepUV indisponível em '" + o.name + "'") tipo:#err )

                -- BUG 15/Set — POR QUE O PROOPTIMIZER NUNCA REDUZIA NADA.
                -- Duas causas empilhadas, nesta ordem:
                --
                -- (a) o código setava 'CalculationEnabled', que NÃO EXISTE na
                --     API — showProperties (ProOptimizer()) no Max 2024 lista
                --     '.Calculate'. Resolvido por sondagem logo abaixo.
                --
                -- (b) a de verdade: '.Calculate' NÃO É UM FLAG DE PARAMBLOCK,
                --     é um COMANDO. Ele só executa quando o modificador é o
                --     objeto corrente do painel Modify. Setado fora desse
                --     contexto, o valor é descartado EM SILÊNCIO — sem
                --     exceção, e lendo de volta retorna 'false'. Nenhum
                --     try/catch pegaria isso. Daí o bloco 'select o' +
                --     setCommandPanelTaskMode + modPanel.setCurrentObject
                --     logo acima, que é o que faz o cálculo rodar de fato.
                --     Medido: 7666 -> 3833 verts com VertexPercent 50.
                --
                -- Sintomas que isso explicava:
                --   · Editable Mesh (já triangulado) -> contagem idêntica.
                --   · Editable Poly (quads) -> parecia DOBRAR, porque o
                --     modificador converte quads em tris sem reduzir nada
                --     (10k quads exibidos viram 20k tris exibidos).
                local propCalc = undefined
                for c in #(#Calculate, #CalculationEnabled) while propCalc == undefined do
                    if isProperty po c do
                        ( try ( setProperty po c true ; propCalc = c ) catch () )

                if propCalc == undefined then
                (
                    deleteModifier o po
                    InLab_Log (o.name + ": ProOptimizer sem propriedade de cálculo — nenhuma de " +
                               "Calculate/CalculationEnabled existe nesta build. Objeto NÃO otimizado, " +
                               "modificador removido.") tipo:#err
                )
                else
                (
                    local pctOk = false
                    try ( po.VertexPercent = percentual ; pctOk = true ) catch ()
                    if not pctOk do
                        ( InLab_Log ("ProOptimizer.VertexPercent indisponível em '" + o.name + "'") tipo:#err )

                    local triDepois  = (GetTriMeshFaceCount o)[1]
                    local vertDepois = (GetTriMeshFaceCount o)[2]

                    -- VERIFICAÇÃO DE EFEITO REAL: sem isto a função logava
                    -- "aplicado com sucesso" mesmo sem ter removido um vértice
                    -- sequer — foi o que mascarou o bug acima por semanas.
                    -- ProOptimizer reduz por VÉRTICES, então o veredito é medido
                    -- em vértices, não em faces.
                    if vertDepois >= vertAntes then
                    (
                        deleteModifier o po
                        InLab_Log (o.name + ": ProOptimizer NÃO reduziu (" +
                                   vertAntes as string + " -> " + vertDepois as string +
                                   " verts). Modificador removido — malha intacta.") tipo:#warn
                    )
                    else
                    (
                        -- Camada 2 de undo: registro dedicado para revert cirúrgico.
                        local rec = OtimizacaoRecord()
                        rec.no          = o
                        rec.modificador = po
                        rec.polysAntes  = triAntes
                        rec.polysDepois = triDepois
                        append InLab_UltimaOtimizacao rec

                        InLab_Log (o.name + ": " + triAntes as string + " -> " + triDepois as string + " tris · " +
                                   vertAntes as string + " -> " + vertDepois as string + " verts") tipo:#ok
                        otimizados += 1
                    )
                )
            )
        )

        -- Restaura seleção e painel de comando. Fica FORA do bloco de undo
        -- de propósito: restaurar não é parte da operação que o Ctrl+Z desfaz.
        try
        (
            if selOriginal.count > 0 then select selOriginal else clearSelection()
            setCommandPanelTaskMode painelOriginal
        )
        catch ( InLab_Log "Não foi possível restaurar seleção/painel após a otimização." tipo:#warn )

        if otimizados == 0 then
            InLab_Log ("ProOptimizer NÃO otimizou nenhum objeto (VertexPercent = " +
                       (formattedPrint percentual format:".1f") + "%). Ver linhas acima.") tipo:#err
        else
            InLab_Log ("ProOptimizer aplicado a " + otimizados as string +
                       " objeto(s) com VertexPercent = " + (formattedPrint percentual format:".1f") + "%.") tipo:#ok
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
