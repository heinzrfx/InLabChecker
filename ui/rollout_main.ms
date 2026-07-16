/*
================================================================================
 ui\rollout_main.ms — v0.7
--------------------------------------------------------------------------------
 REESTRUTURAÇÃO (solicitação Rafael, 08/Jul): a janela agora usa um container
 de SUB-ROLLOUTS — cada seção é um rollout independente e COLAPSÁVEL pelo
 clique no título (mesmo comportamento do ArchToolz). Seções pouco usadas
 abrem minimizadas por padrão.

 ARQUITETURA: cada seção é um rollout definido ANTES do rollout principal
 (define-before-use). A comunicação entre seções acontece só por globais
 (InLab_FamiliaAtiva, InLab_LogUI, funções InLab_*) — nenhuma seção lê
 controles de outra, o que permite colapsar/reordenar livremente.
================================================================================
*/

----------------------------------------------------------------------
-- SEÇÃO: Família Estrutural
----------------------------------------------------------------------
rollout InLabSecFamilia "Família Estrutural" width:420
(
    local nomesExibicao = #(
        "— selecione a família —",
        "Corpo Único  (Lote 1)",
        "Pernas + Tampo  (Lote 1)",
        "Estrutura + Estofado  (Lote 1)",
        "Estrutura Modular  (Lote 1)",
        "Translação  (Lote 2 · animada)",
        "Rotação  (Lote 2 · animada)",
        "Giro de Assento  (Lote 2 · animada)",
        "Movimento Especial  (Lote 2 · animada)"
    )
    local nomesInternos = #(
        "", "corpo_unico", "pernas_tampo", "estrutura_estofado", "estrutura_modular",
        "translacao", "rotacao", "giro_assento", "movimento_especial"
    )

    dropdownlist ddlFamilia items:nomesExibicao width:395
    button btnCarregar "Carregar Configuração da Família" width:395 height:24

    on btnCarregar pressed do
    (
        local i = ddlFamilia.selection
        if i <= 1 then
            InLab_Log "Selecione uma família antes de carregar." tipo:#warn
        else
        (
            local cfg = InLab_ObterFamilia nomesInternos[i]
            if cfg == undefined then
                InLab_Log ("Config da família '" + nomesInternos[i] + "' não encontrada no registro.") tipo:#err
            else
            (
                InLab_FamiliaAtiva = cfg
                InLab_Log "----------------------------------------------"
                InLab_Log ("Família ativa carregada: " + cfg.nome) tipo:#ok
                InLab_LogLinhas (cfg.linhasDescricao())
                InLab_Log "----------------------------------------------"
            )
        )
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Função 1 · ProOptimizer
----------------------------------------------------------------------
rollout InLabSecF1 "1 · ProOptimizer" width:420
(
    radiobuttons rdoModoOpt labels:#("Percentual manual", "Alvo da família (polyMax)") default:1 columns:2
    spinner spnPercent "VertexPercent:" range:[1.0, 100.0, 50.0] type:#float fieldWidth:55 align:#left across:2
    checkbox chkKeepUV "Manter UVs" checked:true align:#right
    button btnF1 "Aplicar na Seleção" width:192 across:2
    button btnF1Rev "Reverter Última" width:192

    on btnF1 pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            local pct = spnPercent.value
            if rdoModoOpt.state == 2 do
            (
                if InLab_FamiliaAtiva == undefined then
                (
                    InLab_Log "Modo alvo requer uma família carregada (polyMax)." tipo:#warn
                    pct = undefined
                )
                else
                (
                    pct = InLab_PercentualParaAlvo objs InLab_FamiliaAtiva.polyMax
                    InLab_Log ("Alvo '" + InLab_FamiliaAtiva.nome + "': polyMax " +
                               InLab_FamiliaAtiva.polyMax as string + " → VertexPercent " +
                               (formattedPrint pct format:".1f") + "%.")
                )
            )
            if pct != undefined do InLab_ProOptimizer objs pct manterUV:chkKeepUV.checked
        )
    )
    on btnF1Rev pressed do InLab_ReverterOtimizacao()
)

----------------------------------------------------------------------
-- SEÇÃO: Função 2 · Auto UV
----------------------------------------------------------------------
rollout InLabSecF2 "2 · Auto UV" width:420
(
    spinner spnPadding "Padding:" range:[0.0, 0.05, 0.005] scale:0.001 type:#float fieldWidth:50 align:#left
    button btnF2 "Auto UV na Seleção" width:192 across:2
    button btnF2Clean "Clean UV" width:192
    button btnF2Rev "Reverter Último Auto UV" width:395

    on btnF2 pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_AutoUV objs padding:spnPadding.value
    )
    on btnF2Clean pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_CleanUV objs
    )
    on btnF2Rev pressed do InLab_ReverterAutoUV()
)

----------------------------------------------------------------------
-- SEÇÃO: Funções 3 e 4 · Texturas e Escala
----------------------------------------------------------------------
rollout InLabSecF34 "3 · Check Texture  |  4 · Real World Scale" width:420
(
    radiobuttons rdoEscopoTex labels:#("Cena inteira", "Somente seleção") default:1 columns:2
    button btnF3 "3 · Inventariar Texturas" width:192 across:2
    button btnF4 "4 · Verificar Escala (seleção)" width:192
    checkbox chkResetXForm "ResetXForm automático em objetos com scale fora de 100%" checked:false

    on btnF3 pressed do
    (
        if rdoEscopoTex.state == 1 then
            InLab_CheckTexture escopo:#cena
        else
        (
            local objs = InLab_SelecaoValida()
            if objs.count > 0 do InLab_CheckTexture escopo:#selecao objs:objs
        )
    )

    on btnF4 pressed do
    (
        -- BUG 3: unidade primeiro; depois SELEÇÃO (se houver) e por fim a
        -- CENA INTEIRA — nessa ordem. Sem seleção, vai direto para a cena.
        local unidadeOk = InLab_VerificarUnidade()
        if not unidadeOk do
        (
            local msg = "A unidade do sistema diverge do padrão InLab (" +
                        INLAB_UNIDADE_PADRAO as string + ").\n\nCorrigir agora?\n\n" +
                        "ATENÇÃO: a geometria NÃO será reescalada."
            if queryBox msg title:"InLabChecker · Unidade do Sistema" do
                InLab_VerificarUnidade corrigir:true
        )

        local todaCena = for o in geometry where InLab_EhGeometria o collect o
        if selection.count > 0 do
            InLab_VerificarEscala (selection as array) aplicarResetXForm:chkResetXForm.checked rotulo:"seleção"
        InLab_VerificarEscala todaCena aplicarResetXForm:chkResetXForm.checked rotulo:"cena inteira"
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Função 5 · Converter Material
----------------------------------------------------------------------
rollout InLabSecF5 "5 · Converter Material (Corona → glTF)" width:420
(
    dropdownlist ddlBakeRes items:#("512", "1024", "2048", "4096") selection:2 width:90 align:#left across:2
    checkbox chkBakeProc "Bake de mapas procedurais" checked:true align:#right
    button btnF5 "Converter Materiais da Seleção" width:192 across:2
    button btnF5Rev "Reverter Conversão" width:192

    on btnF5 pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            local tam = ddlBakeRes.selected as integer
            InLab_ConverterObjetos objs tamanhoBake:tam fazerBake:chkBakeProc.checked
        )
    )
    on btnF5Rev pressed do InLab_ReverterConversao()
)

----------------------------------------------------------------------
-- SEÇÃO: Função 6 · Export
----------------------------------------------------------------------
rollout InLabSecF6 "6 · Export glTF/GLB" width:420
(
    radiobuttons rdoEscopoExp labels:#("Somente seleção", "Cena inteira") default:1 columns:2
    button btnF6 "Exportar..." width:395 height:24

    on btnF6 pressed do
    (
        local soSelecao = (rdoEscopoExp.state == 1)
        if soSelecao and selection.count == 0 then
            InLab_Log "Selecione os objetos a exportar (ou mude o escopo para cena inteira)." tipo:#warn
        else
        (
            local f = getSaveFileName caption:"Exportar glTF/GLB" types:"GLB binário (*.glb)|*.glb|glTF (*.gltf)|*.gltf"
            if f != undefined do InLab_ExportGLTF f somenteSelecao:soSelecao
        )
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Utilidades Rápidas (Rafael, 08/Jul)
----------------------------------------------------------------------
rollout InLabSecUtil "Utilidades Rápidas" width:420
(
    button btnUResetX "ResetXForm na Seleção" width:192 across:2
    button btnUPivot "Centralizar Pivot" width:192

    on btnUResetX pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_ResetXFormSelecao objs
    )
    on btnUPivot pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_CentralizarPivot objs
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Fase 4 (placeholder)
----------------------------------------------------------------------
rollout InLabSecFase4 "7 · Verificações (grupos 1-3 ativos)" width:420
(
    checkbox chkTampoAcess "Produto com tampo acessório (V-38 · Pernas+Tampo)" checked:false
    button btnVerificar "Rodar Verificações" width:395 height:26

    on btnVerificar pressed do
    (
        if InLab_FamiliaAtiva == undefined then
            InLab_Log "Carregue a família do produto antes de verificar (seção Família Estrutural)." tipo:#warn
        else
            InLab_RodarVerificacoes InLab_FamiliaAtiva tampoAcessorio:chkTampoAcess.checked
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Log
----------------------------------------------------------------------
rollout InLabSecLog "Log da Sessão" width:420
(
    listbox lbLog items:#() height:11 width:395
    button btnLimpar "Limpar" width:126 across:3
    button btnSalvar "Salvar .txt" width:126
    button btnFechar "Fechar Plugin" width:126

    on btnLimpar pressed do InLab_LimparLog()
    on btnSalvar pressed do
    (
        local f = getSaveFileName caption:"Salvar log da sessão" types:"Arquivo de texto (*.txt)|*.txt"
        if f != undefined do
        (
            local salvoEm = InLab_SalvarLog f
            if salvoEm != undefined then InLab_Log ("Log salvo em: " + salvoEm) tipo:#ok
            else InLab_Log "Falha ao salvar o log em ambos os caminhos (escolhido e temp) — reportar." tipo:#err
        )
    )
    on btnFechar pressed do destroyDialog InLabChecker_Rollout
)

----------------------------------------------------------------------
-- ROLLOUT PRINCIPAL: container de sub-rollouts colapsáveis
----------------------------------------------------------------------
rollout InLabChecker_Rollout "InLabChecker · InLab Artefacto · v0.9" width:446
(
    subRollout subSecoes width:438 height:724 pos:[3, 4]

    on InLabChecker_Rollout open do
    (
        -- Ordem de exibição. rolledUp:true = seção abre minimizada.
        AddSubRollout subSecoes InLabSecFamilia
        AddSubRollout subSecoes InLabSecF1 rolledUp:true
        AddSubRollout subSecoes InLabSecF2 rolledUp:true
        AddSubRollout subSecoes InLabSecF34 rolledUp:true
        AddSubRollout subSecoes InLabSecF5 rolledUp:true
        AddSubRollout subSecoes InLabSecF6 rolledUp:true
        AddSubRollout subSecoes InLabSecUtil rolledUp:true
        AddSubRollout subSecoes InLabSecFase4 rolledUp:true
        AddSubRollout subSecoes InLabSecLog

        -- Conecta o listbox do log (vive na seção de log) ao motor de log.
        InLab_LogUI = InLabSecLog.lbLog
        InLab_RefreshLogUI()
        InLab_Log ("Sessão InLabChecker v0.9 · " + localTime)
        InLab_Log ("Famílias registradas: " + InLab_Familias.count as string + " de 8")
        InLab_Log ("Unidade do sistema: " + (InLab_UnidadeSistema() as string))
        if InLab_Familias.count != 8 do
            InLab_Log "Nem todas as famílias foram carregadas — verificar o manifesto." tipo:#err
    )

    on InLabChecker_Rollout close do InLab_LogUI = undefined
)

-- Fecha instância anterior (se existir) e abre uma nova.
fn InLab_AbrirUI =
(
    try (destroyDialog InLabChecker_Rollout) catch()
    createDialog InLabChecker_Rollout 446 732
)
