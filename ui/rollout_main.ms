/*
================================================================================
 ui\rollout_main.ms — v0.10 (13/Jul) — reorganização completa de UI
--------------------------------------------------------------------------------
 MUDANÇAS DESTA VERSÃO (pedido da equipe, ref. ArchToolz):
   - Barra de ferramentas FIXA no topo (Copy/Paste Objs/Mat, Pick Mat).
     Paste DWG: desabilitado — pendência de escopo (ver fn_clipboard.ms).
   - Ordem "Somente seleção" / "Cena inteira" padronizada em todo o plugin.
   - Seções reordenadas: Família → Otimização → Utilidades → Converter
     Material → Exportar → Verificações → Log (sempre por último).
   - Log colorido (dotNet RichTextBox — listbox nativo não suporta cor).
   - Progress bar fixa abaixo das seções (fora das abas).
   - Splash screen ao abrir.
   - Opção de fixar o painel à esquerda/direita da tela (reposicionamento
     de janela — NÃO é docking real; ver ressalva entregue à equipe).

 ARQUITETURA: cada seção segue sendo um rollout independente, define-before-
 use, comunicação só via globais — mesma disciplina desde a v0.7.
================================================================================
*/

----------------------------------------------------------------------
-- SEÇÃO: Família Estrutural
----------------------------------------------------------------------
rollout InLabSecFamilia "Família Estrutural" width:420
(
    local nomesExibicao = #(
        "— selecione a família —",
        "Corpo Único  (Lote 1)", "Pernas + Tampo  (Lote 1)",
        "Estrutura + Estofado  (Lote 1)", "Estrutura Modular  (Lote 1)",
        "Translação  (Lote 2 · animada)", "Rotação  (Lote 2 · animada)",
        "Giro de Assento  (Lote 2 · animada)", "Movimento Especial  (Lote 2 · animada)"
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
        if i <= 1 then InLab_Log "Selecione uma família antes de carregar." tipo:#warn
        else
        (
            local cfg = InLab_ObterFamilia nomesInternos[i]
            if cfg == undefined then
                InLab_Log ("Config da família '" + nomesInternos[i] + "' não encontrada.") tipo:#err
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
    button btnReload "🔄 Reload Plugin" width:120 height:20
    
    on btnReload pressed do InLab_RecarregarPlugin()
)

----------------------------------------------------------------------
-- SEÇÃO: Otimização (ProOptimizer + Auto UV + Check Texture + Real World Scale)
----------------------------------------------------------------------
rollout InLabSecOtimizacao "Otimização" width:420
(
    label lblF1 "ProOptimizer" align:#left
    radiobuttons rdoModoOpt labels:#("Percentual manual", "Alvo da família (polyMax)") default:1 columns:2
    spinner spnPercent "VertexPercent:" range:[1.0, 100.0, 50.0] type:#float fieldWidth:55 align:#left
    button btnF1 "Aplicar" width:395 height:25

    label lblF2 "Auto UV" align:#left across:1
    spinner spnPadding "Padding:" range:[0.0, 0.05, 0.005] scale:0.001 type:#float fieldWidth:50 align:#left
    button btnF2 "Auto UV na Seleção" width:192 across:2
    button btnF2Clean "Clean UV" width:192

    label lblF34 "Check Texture  |  Real World Scale" align:#left across:1
    radiobuttons rdoEscopoTex labels:#("Somente seleção", "Cena inteira") default:1 columns:2
    button btnF3 "Inventariar Texturas" width:192 across:2
    button btnF4 "Verificar Escala" width:192
    checkbox chkResetXForm "ResetXForm automático (scale fora de 100%)" checked:false

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
            if pct != undefined do
            (
                InLab_ProgressoIniciar "Otimizando geometria..."
                InLab_ProOptimizer objs pct
                InLab_ProgressoParar()
            )
        )
    )

    on btnF2 pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            InLab_ProgressoIniciar "Gerando Auto UV..."
            InLab_AutoUV objs padding:spnPadding.value
            InLab_ProgressoParar()
        )
    )
    on btnF2Clean pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_CleanUV objs
    )

    on btnF3 pressed do
    (
        if rdoEscopoTex.state == 1 then
        (
            local objs = InLab_SelecaoValida()
            if objs.count > 0 do InLab_CheckTexture escopo:#selecao objs:objs
        )
        else InLab_CheckTexture escopo:#cena
    )

    on btnF4 pressed do
    (
        local unidadeOk = InLab_VerificarUnidade()
        if not unidadeOk do
        (
            local msg = "A unidade do sistema diverge do padrão InLab (" + INLAB_UNIDADE_PADRAO as string +
                        ").\n\nCorrigir agora?\n\nATENÇÃO: a geometria NÃO será reescalada."
            if queryBox msg title:"InLabChecker · Unidade do Sistema" do InLab_VerificarUnidade corrigir:true
        )
        -- Ordem fixa (bug 3): seleção primeiro (se houver), cena depois.
        if selection.count > 0 do
            InLab_VerificarEscala (selection as array) aplicarResetXForm:chkResetXForm.checked rotulo:"seleção"
        local todaCena = for o in geometry where InLab_EhGeometria o collect o
        InLab_VerificarEscala todaCena aplicarResetXForm:chkResetXForm.checked rotulo:"cena inteira"
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Utilidades Rápidas
----------------------------------------------------------------------
rollout InLabSecUtil "Utilidades Rápidas" width:420
(
    button btnUResetX "Reset XForm" width:130 across:3
    button btnUCenter "Center Pivot" width:130
    button btnUBase "Base Pivot" width:130

    label lblFind "Find Objects (polígonos acima do limite):" align:#left across:1
    label lblFindLimite "limite: carregue uma família" align:#left
    button btnUFind "Find Objects" width:395 height:24

    on btnUResetX pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_ResetXFormSelecao objs
    )
    on btnUCenter pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_CentralizarPivot objs
    )
    on btnUBase pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_BasePivot objs
    )
    on btnUFind pressed do InLab_FindObjectsPesados()

    -- Atualiza o rótulo do limite sempre que a seção é exibida — mantém o
    -- valor visível sincronizado com a família carregada (não é campo
    -- editável: vem sempre do polyMax, conforme decisão da equipe).
    on InLabSecUtil open do
        if InLab_FamiliaAtiva != undefined do
            lblFindLimite.text = "limite: " + InLab_FamiliaAtiva.polyMax as string + " faces (polyMax de '" + InLab_FamiliaAtiva.nome + "')"
)

----------------------------------------------------------------------
-- SEÇÃO: Converter Material
----------------------------------------------------------------------
rollout InLabSecF5 "Converter Material" width:420
(
    dropdownlist ddlConversao items:#("Corona → glTF (Physical / Legacy / VRay)") selection:1 width:395
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
            InLab_ProgressoIniciar "Convertendo materiais..."
            InLab_ConverterObjetos objs tamanhoBake:tam fazerBake:chkBakeProc.checked
            InLab_ProgressoParar()
        )
    )
    on btnF5Rev pressed do InLab_ReverterConversao()
)

----------------------------------------------------------------------
-- SEÇÃO: Exportar
----------------------------------------------------------------------
rollout InLabSecF6 "Exportar" width:420
(
    dropdownlist ddlFormato items:#("glTF Binário (.glb)", "glTF (.gltf)") selection:1 width:395
    radiobuttons rdoEscopoExp labels:#("Somente seleção", "Cena inteira") default:1 columns:2
    button btnF6 "Exportar..." width:395 height:24

    on btnF6 pressed do
    (
        local soSelecao = (rdoEscopoExp.state == 1)
        if soSelecao and selection.count == 0 then
            InLab_Log "Selecione os objetos a exportar (ou mude para cena inteira)." tipo:#warn
        else
        (
            local objs = if soSelecao then (for o in selection collect o) else undefined
            InLab_ExportGLTF objs somenteSelecao:soSelecao
        )
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Verificações (sem mudanças de lógica — só reordenada)
----------------------------------------------------------------------
rollout InLabSecFase4 "Verificações (grupos 1-3 ativos)" width:420
(
    checkbox chkTampoAcess "Produto com tampo acessório (V-38 · Pernas+Tampo)" checked:false
    button btnVerificar "Rodar Verificações" width:395 height:26

    on btnVerificar pressed do
    (
        if InLab_FamiliaAtiva == undefined then
            InLab_Log "Carregue a família do produto antes de verificar." tipo:#warn
        else
        (
            InLab_ProgressoIniciar "Rodando verificações..."
            InLab_RodarVerificacoes InLab_FamiliaAtiva tampoAcessorio:chkTampoAcess.checked
            InLab_ProgressoParar()
        )
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Log (sempre por último — regra fixa independente de novas seções)
----------------------------------------------------------------------
rollout InLabSecLog "Log de Sessão" width:420
(
    dotNetControl rtbLog "System.Windows.Forms.RichTextBox" width:398 height:220
    button btnLimpar "Limpar" width:126 across:3
    button btnSalvar "Salvar .txt" width:126
    button btnFechar "Fechar Plugin" width:126

    on InLabSecLog open do
    (
        rtbLog.ReadOnly   = true
        rtbLog.BackColor  = (dotNetClass "System.Drawing.Color").FromArgb 30 30 30
        rtbLog.ForeColor  = (dotNetClass "System.Drawing.Color").FromArgb 210 210 210
        rtbLog.Font       = dotNetObject "System.Drawing.Font" "Consolas" 9
        rtbLog.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").None
        InLab_LogUI = rtbLog
        InLab_RefreshLogUI()
    )

    on btnLimpar pressed do InLab_LimparLog()
    on btnSalvar pressed do
    (
        local f = getSaveFileName caption:"Salvar log da sessão" types:"Arquivo de texto (*.txt)|*.txt"
        if f != undefined do
        (
            local salvoEm = InLab_SalvarLog f
            if salvoEm != undefined then InLab_Log ("Log salvo em: " + salvoEm) tipo:#ok
            else InLab_Log "Falha ao salvar o log em ambos os caminhos — reportar." tipo:#err
        )
    )
    on btnFechar pressed do destroyDialog InLabChecker_Rollout
)

----------------------------------------------------------------------
-- ROLLOUT PRINCIPAL
----------------------------------------------------------------------
rollout InLabChecker_Rollout "InLabChecker · InLab Artefacto · v0.10" width:446
(
    ------------------------------------------------------------------
    -- BARRA FIXA (topo) — Copy/Paste Objs/Mat, Pick Mat. Sempre visível,
    -- independente da seção/aba ativa. Paste DWG desabilitado (pendência
    -- de escopo — ver fn_clipboard.ms).
    ------------------------------------------------------------------
    button btnCopyObjs  "Copy Objs"  width:68 across:6 offset:[0,0]
    button btnPasteObjs "Paste Objs" width:68
    button btnCopyMat   "Copy Mat"   width:68
    button btnPasteMat  "Paste Mat"  width:68
    button btnPasteDWG  "Paste DWG"  width:68 enabled:false
    button btnPickMat   "Pick Mat"   width:68

    ------------------------------------------------------------------
    -- LADO DO PAINEL — reposicionamento na borda da tela (não é docking
    -- real; ver ressalva entregue à equipe).
    ------------------------------------------------------------------
    radiobuttons rdoLado labels:#("Fixar à esquerda", "Fixar à direita") default:2 columns:2

    subRollout subSecoes width:438 height:560 pos:[3, 74]

    ------------------------------------------------------------------
    -- PROGRESSO — fixo, fora das abas, abaixo das seções.
    ------------------------------------------------------------------
    dotNetControl dncProgress "System.Windows.Forms.ProgressBar" width:398 height:14 pos:[3, 640]
    dotNetControl dncProgressLbl "System.Windows.Forms.Label" width:398 height:16 pos:[3, 656]

    ------------------------------------------------------------------
    -- EVENTOS
    ------------------------------------------------------------------
    on InLabChecker_Rollout open do
    (
        AddSubRollout subSecoes InLabSecFamilia
        AddSubRollout subSecoes InLabSecOtimizacao rolledUp:true
        AddSubRollout subSecoes InLabSecUtil rolledUp:true
        AddSubRollout subSecoes InLabSecF5 rolledUp:true
        AddSubRollout subSecoes InLabSecF6 rolledUp:true
        AddSubRollout subSecoes InLabSecFase4 rolledUp:true
        AddSubRollout subSecoes InLabSecLog

        dncProgress.Visible = false
        dncProgressLbl.Visible = false
        dncProgressLbl.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 200 200 200
        InLab_ProgressUI  = dncProgress
        InLab_ProgressLbl = dncProgressLbl

        InLab_Log ("Sessão InLabChecker v0.10 · " + localTime)
        InLab_Log ("Famílias registradas: " + InLab_Familias.count as string + " de 8")
        InLab_Log ("Unidade do sistema: " + (InLab_UnidadeSistema() as string))
        if InLab_Familias.count != 8 do
            InLab_Log "Nem todas as famílias foram carregadas — verificar o manifesto." tipo:#err
    )

    on InLabChecker_Rollout close do InLab_LogUI = undefined

    on btnCopyObjs pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_CopyObjs objs
    )
    on btnPasteObjs pressed do InLab_PasteObjs()
    on btnCopyMat pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_CopyMat objs
    )
    on btnPasteMat pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_PasteMat objs
    )
    on btnPickMat pressed do InLab_PickMat()

    -- Reposiciona a janela na borda esquerda/direita da tela de trabalho.
    on rdoLado changed sel do
    (
        local area = (dotNetClass "System.Windows.Forms.Screen").PrimaryScreen.WorkingArea
        local x = if sel == 1 then area.Left else (area.Right - 446)
        try ( InLabChecker_Rollout.pos = [x, InLabChecker_Rollout.pos.y] ) catch()
    )
)

-- Fecha instância anterior (se existir), mostra o splash e abre a janela
-- já posicionada conforme a última preferência de lado (padrão: direita).
fn InLab_AbrirUI =
(
    try (destroyDialog InLabChecker_Rollout) catch()
    InLab_MostrarSplash()
    createDialog InLabChecker_Rollout 446 690
)
