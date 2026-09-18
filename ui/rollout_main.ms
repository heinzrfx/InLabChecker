/*
================================================================================
 ui\rollout_main.ms — v0.10 (13/Jul) — reorganização completa de UI
--------------------------------------------------------------------------------
 MUDANÇAS DESTA VERSÃO (pedido da equipe, ref. ArchToolz):
   - Ordem "Somente seleção" / "Cena inteira" padronizada em todo o plugin.
   - Seções reordenadas: Família → Otimização → Utilidades → Converter
     Material → Exportar → Verificações → Log (sempre por último).
   - Log colorido (dotNet RichTextBox — listbox nativo não suporta cor).
   - Splash screen ao abrir.
   - Opção de fixar o painel à esquerda/direita da tela (reposicionamento
     de janela — NÃO é docking real; ver ressalva entregue à equipe).

 AJUSTE 15/Set (debug de UI, pedido Rafael): removidos dois blocos fixos que
 ficavam acima/abaixo das seções:
   - Barra de ferramentas do topo (Copy/Paste Objs/Mat, Paste DWG, Pick Mat)
     — os botões nem chamavam funções carregadas (fn_clipboard.ms não está
     no manifesto INLAB_MODULOS de InLabChecker.ms), então pressioná-los já
     dava erro. Removida por inteiro; fn_clipboard.ms continua no repo,
     intocado, caso a equipe decida reconectar essa função depois.
   - Barra de progresso fixa abaixo das seções (dncProgress/dncProgressLbl).
     InLab_ProgressoIniciar/Parar (core\log.ms) já protegem contra
     InLab_ProgressUI/InLab_ProgressLbl == undefined, então essas chamadas
     (ProOptimizer, Auto UV, Verificações) continuam funcionando normalmente
     como no-op silencioso — nada mais a ajustar nesses outros arquivos.

 ARQUITETURA: cada seção segue sendo um rollout independente, define-before-
 use, comunicação só via globais — mesma disciplina desde a v0.7.
================================================================================
*/

----------------------------------------------------------------------
-- SEÇÃO: Produto (Fase 5.2 import · 18/Set renomeação pelo JSON)
----------------------------------------------------------------------
-- Importa o export de nomenclatura da plataforma (Lovable + Supabase),
-- escolhe o produto (pré-selecionado pelo nome do .max = cod_est), liga
-- cada parte a um material da seleção e aplica os nomes oficiais. A lógica
-- toda está em functions\fn_renomear_produto.ms; aqui só fica o estado da
-- tela. Lista + dropdown nativos em vez de tabela dotNet: o número de
-- partes varia por produto e rollout não cria controles dinamicamente.
global InLab_ProdutoAtivo = undefined -- árvore crua do JSON importado (formato de InLab_ParseJSON)

rollout InLabSecProduto "Produto" width:420
(
    local produtos = #()  -- itens de "produtos" do export importado
    local materiais = #() -- materiais lidos da seleção
    local ligacoes = #()  -- paralelo às partes do produto escolhido: material ou undefined
    local objsLidos = #() -- objetos da última leitura — são eles que recebem o mesh_final

    label lblProdutoAtivo "Nenhum produto carregado." align:#left
    button btnImportarProduto "Importar JSON do Produto..." width:395 height:26
    dropdownlist ddlProduto "Produto:" items:#() width:395
    button btnLerSelecao "Ler materiais da seleção" width:395 height:24
    listbox lbxPartes "Parte  →  material:" items:#() height:6 width:395
    dropdownlist ddlMaterial "Material da parte marcada:" items:#() width:395
    button btnAplicar "Aplicar nomes" width:192 height:26 across:2
    button btnDesfazer "Desfazer nomes" width:192 height:26

    fn produtoEscolhido =
        if ddlProduto.selection > 0 and ddlProduto.selection <= produtos.count then produtos[ddlProduto.selection] else undefined

    fn partesEscolhidas =
    (
        local p = produtoEscolhido()
        local partes = if p != undefined then InLab_JSON_Obter p "partes" else undefined
        if isKindOf partes Array then partes else #()
    )

    fn atualizarTela =
    (
        local partes = partesEscolhidas()
        local sel = lbxPartes.selection
        lbxPartes.items = for i = 1 to partes.count collect
            ((InLab_Produto_Rotulo partes[i]) + "  →  " + (if ligacoes[i] == undefined then "(sem material)" else ligacoes[i].name))
        if sel > 0 and sel <= partes.count do lbxPartes.selection = sel
        ddlMaterial.items = #("— nenhum —") + (for m in materiais collect m.name)
        local i = lbxPartes.selection
        ddlMaterial.selection = if i > 0 and ligacoes[i] != undefined then (findItem materiais ligacoes[i]) + 1 else 1
    )

    fn sugerir =
    (
        ligacoes = InLab_Produto_SugerirLigacoes (partesEscolhidas()) materiais
        atualizarTela()
    )

    fn limparProduto =
    (
        InLab_ProdutoAtivo = undefined
        produtos = #()
        ddlProduto.items = #()
        lblProdutoAtivo.text = "Nenhum produto carregado."
        sugerir()
    )

    on btnImportarProduto pressed do
    (
        local caminho = getOpenFileName caption:"Selecionar .json do produto" types:"JSON (*.json)|*.json"
        if caminho == undefined then
            InLab_Log "Importação de produto cancelada — nenhum arquivo selecionado." tipo:#warn
        else
        (
            local texto = InLab_JSON_LerArquivoUTF8 caminho
            local dados = if texto == undefined then undefined else InLab_ParseJSON texto
            if dados == undefined then limparProduto()
            else
            (
                InLab_ProdutoAtivo = dados
                local nomeArquivo = filenameFromPath caminho
                lblProdutoAtivo.text = "Produto carregado: " + nomeArquivo
                InLab_Log ("Produto importado com sucesso: " + nomeArquivo) tipo:#ok
                produtos = InLab_Produto_Lista dados
                ddlProduto.items = for p in produtos collect ((InLab_Produto_Texto p "cod_est") + " – " + (InLab_Produto_Texto p "nome"))
                if produtos.count == 0 then
                    InLab_Log "Este JSON não tem lista de produtos — importe o export da linha (nomenclatura_export_...json), não o nomenclatura_projeto.json." tipo:#warn
                else
                (
                    local cod = getFilenameFile maxFileName
                    local idx = InLab_Produto_IndicePorCodigo produtos cod
                    if idx > 0 then
                        InLab_Log ("Produto do arquivo aberto: " + ddlProduto.items[idx]) tipo:#ok
                    else
                    (
                        idx = 1
                        InLab_Log ("Nenhum produto com cod_est '" + cod + "' (nome do .max) — escolha na lista.") tipo:#warn
                    )
                    ddlProduto.selection = idx
                )
                sugerir()
            )
        )
    )

    on ddlProduto selected i do sugerir()

    on btnLerSelecao pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            objsLidos = objs
            materiais = InLab_Produto_MateriaisDaSelecao objs
            sugerir()
            local n = 0
            for l in ligacoes where l != undefined do n += 1
            InLab_Log (materiais.count as string + " material(is) em " + objs.count as string + " objeto(s) · " +
                       n as string + " parte(s) pré-ligada(s) — confira antes de aplicar.")
        )
    )

    on lbxPartes selected i do atualizarTela()

    on ddlMaterial selected j do
    (
        local i = lbxPartes.selection
        if i == 0 then
            InLab_Log "Marque uma parte na lista antes de escolher o material." tipo:#warn
        else
            ligacoes[i] = if j == 1 then undefined else materiais[j - 1]
        atualizarTela()
    )

    on btnAplicar pressed do
    (
        local p = produtoEscolhido()
        if p == undefined then
            InLab_Log "Importe o JSON e escolha o produto antes de aplicar." tipo:#warn
        else if objsLidos.count == 0 then
            InLab_Log "Clique em 'Ler materiais da seleção' antes de aplicar." tipo:#warn
        else
        (
            objsLidos = for o in objsLidos where isValidNode o collect o
            InLab_Produto_Aplicar p ligacoes objsLidos
            atualizarTela()
        )
    )

    on btnDesfazer pressed do
    (
        InLab_Produto_Reverter()
        atualizarTela()
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Otimização (ProOptimizer + Auto UV + Check Texture + Real World Scale)
----------------------------------------------------------------------
rollout InLabSecOtimizacao "Otimização" width:420
(
    label lblF1 "ProOptimizer" align:#left
    radiobuttons rdoModoOpt labels:#("Percentual manual", "Alvo da família (polyMax)") default:1 columns:2
    spinner spnPercent "VertexPercent:" range:[1.0, 100.0, 50.0] type:#float fieldWidth:55 align:#left
    button btnF1 "Aplicar" width:192 height:25 across:2
    button btnF1Undo "Desfazer Otimização" width:192 height:25

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

    -- AJUSTE 15/Set: InLab_ReverterOtimizacao (functions\fn_prooptimizer.ms)
    -- existia desde a v0.9 mas nunca teve botão — a "camada 2" de undo descrita
    -- no cabeçalho daquele módulo era código morto. Ela remove exatamente os
    -- modificadores da última rodada, e funciona mesmo que o usuário já tenha
    -- feito outras ações depois (cenário em que o Ctrl+Z simples não alcança).
    on btnF1Undo pressed do InLab_ReverterOtimizacao()

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
-- SEÇÃO: Materiais — Utilidades (ref. ArchToolz, pedido 10/Set)
-- Select by similar material / Object name → Material name / Detach by
-- Material com propagação de IDs — ver functions\fn_material_utils.ms.
----------------------------------------------------------------------
rollout InLabSecMatUtil "Materiais — Utilidades" width:420
(
    label lblMatSel "Selecionar por Material Similar" align:#left
    label lblMatSelInfo "(usa o material copiado — recurso Copy Mat / Pick Mat removido; ver nota 15/Set)" align:#left
    radiobuttons rdoEscopoMat labels:#("Somente seleção", "Cena inteira") default:2 columns:2
    checkbox chkMatPorNome "Também considerar mesmo NOME (cópias/instâncias diferentes)" checked:false
    button btnMatSel "Selecionar por Material Similar" width:395 height:24

    label lblMatNome "Nome do Objeto → Nome do Material" align:#left across:1
    button btnMatNome "Aplicar na Seleção" width:395 height:24

    label lblMatDetach "Detach por Material (propaga IDs para os pedaços)" align:#left
    button btnMatDetach "Detach por Material na Seleção" width:395 height:24

    on btnMatSel pressed do
    (
        local escopo = if rdoEscopoMat.state == 1 then #selecao else #cena
        InLab_SelecionarPorMaterialSimilar escopo:escopo porNome:chkMatPorNome.checked
    )
    on btnMatNome pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_NomeObjetoParaMaterial objs
    )
    on btnMatDetach pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_DetachPorMaterialSelecao objs
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Exportar
----------------------------------------------------------------------
-- BUG 10/Set: o botão chamava export headless (#noPrompt) direto — nunca
-- abria a janela nativa do Real-Time Exporter. Agora ele só garante a
-- seleção certa na viewport e abre a janela nativa; formato/compressão/
-- caminho o usuário escolhe DENTRO dela (ver fn_export_gltf.ms).
rollout InLabSecF6 "Exportar" width:420
(
    radiobuttons rdoEscopoExp labels:#("Somente seleção", "Cena inteira") default:1 columns:2
    button btnF6 "Abrir Real-Time Exporter..." width:395 height:24

    on btnF6 pressed do
    (
        local soSelecao = (rdoEscopoExp.state == 1)
        if soSelecao and selection.count == 0 then
            InLab_Log "Selecione os objetos a exportar (ou mude para cena inteira)." tipo:#warn
        else
        (
            local objs = if soSelecao then (for o in selection collect o) else undefined
            InLab_AbrirExportadorRealTime objs somenteSelecao:soSelecao
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
-- AJUSTE 10/Set — janela principal (e o splash, ver ui\splash.ms) não
-- abriam no TOPO da tela (referência ArchToolz): só havia reposicionamento
-- em X, e só reagindo à MUDANÇA do radiobutton — a abertura inicial caía
-- onde o Max/Windows decidisse (o comentário logo abaixo, em InLab_AbrirUI,
-- já dizia "posicionada conforme a última preferência de lado", mas isso
-- nunca tinha sido implementado de fato). Agora:
--   - global InLab_LadoPainel guarda a preferência (1=esquerda, 2=direita),
--     sobrevive a reloads dentro da mesma sessão do Max;
--   - InLab_PosicionarPainel fixa X (esquerda/direita) E Y (sempre no topo
--     do WorkingArea) — usada tanto na abertura quanto na mudança do rádio;
--   - InLab_MostrarSplash (ui\splash.ms) lê o MESMO InLab_LadoPainel, então
--     splash e janela principal sempre abrem no mesmo canto.
global InLab_LadoPainel = 2 -- 1 = esquerda, 2 = direita (default = direita, igual ao radiobutton)

fn InLab_PosicionarPainel lado =
(
    local area = (dotNetClass "System.Windows.Forms.Screen").PrimaryScreen.WorkingArea
    local x = if lado == 1 then area.Left else (area.Right - 446)
    try ( InLabChecker_Rollout.pos = [x, area.Top] ) catch()
)

rollout InLabChecker_Rollout "InLabChecker · InLab Artefacto · v0.10" width:446
(
    ------------------------------------------------------------------
    -- LADO DO PAINEL — reposicionamento na borda da tela (não é docking
    -- real; ver ressalva entregue à equipe).
    ------------------------------------------------------------------
    radiobuttons rdoLado labels:#("Fixar à esquerda", "Fixar à direita") default:2 columns:2

    -- Realocado de InLabSecFamilia (Fase 5.2): não é específico de nenhuma
    -- seção, então fica fixo aqui, no topo da janela.
    button btnReload "🔄 Reload Plugin" width:395 height:22

    -- AJUSTE 15/Set: sem pos: fixo — a barra de Copy/Paste que estava acima
    -- foi removida, então deixamos o fluxo automático do rollout posicionar
    -- subSecoes logo abaixo do Reload Plugin em vez de reusar o y:96 antigo
    -- (calculado pra caber a barra que não existe mais).
    subRollout subSecoes width:438 height:538

    ------------------------------------------------------------------
    -- EVENTOS
    ------------------------------------------------------------------
    on InLabChecker_Rollout open do
    (
        -- Sincroniza o rádio com a preferência lembrada e fixa a janela no
        -- topo do lado certo — ANTES de qualquer outra coisa, pra não haver
        -- frame em que a janela aparece no lugar errado.
        rdoLado.state = InLab_LadoPainel
        InLab_PosicionarPainel InLab_LadoPainel

        AddSubRollout subSecoes InLabSecProduto
        AddSubRollout subSecoes InLabSecOtimizacao rolledUp:true
        AddSubRollout subSecoes InLabSecUtil rolledUp:true
        AddSubRollout subSecoes InLabSecF5 rolledUp:true
        AddSubRollout subSecoes InLabSecMatUtil rolledUp:true
        AddSubRollout subSecoes InLabSecF6 rolledUp:true
        AddSubRollout subSecoes InLabSecFase4 rolledUp:true
        AddSubRollout subSecoes InLabSecLog

        InLab_Log ("Sessão InLabChecker v0.10 · " + localTime)
        InLab_Log ("Famílias registradas: " + InLab_Familias.count as string + " de 8")
        InLab_Log ("Unidade do sistema: " + (InLab_UnidadeSistema() as string))
        if InLab_Familias.count != 8 do
            InLab_Log "Nem todas as famílias foram carregadas — verificar o manifesto." tipo:#err
    )

    on InLabChecker_Rollout close do InLab_LogUI = undefined

    on btnReload pressed do InLab_RecarregarPlugin()

    -- Reposiciona a janela na borda esquerda/direita da tela de trabalho
    -- (sempre no topo) e lembra a preferência pra próxima abertura/reload.
    on rdoLado changed sel do
    (
        InLab_LadoPainel = sel
        InLab_PosicionarPainel sel
    )
)

-- Fecha instância anterior (se existir) e abre a janela já posicionada
-- conforme a última preferência de lado (padrão: direita).
--
-- global explícito aqui: o fileIn deste arquivo pode acontecer de DENTRO
-- de InLab_RecarregarPlugin() (reload), um escopo de função aninhado, o
-- que pode amarrar esta definição ao escopo local do chamador em vez do
-- global — mesmo problema que já resolvemos no InLabChecker.ms, agora
-- também no lado de quem DEFINE a função (bug constatado em 29/Jul).
--
-- SPLASH DESLIGADO (10/Set, pedido Rafael): InLab_MostrarSplash() comentada
-- abaixo — não removida do arquivo (ui\splash.ms continua íntegro) pra ser
-- fácil religar depois. Só descomentar a linha pra voltar a mostrar.
global InLab_AbrirUI
fn InLab_AbrirUI =
(
    try (destroyDialog InLabChecker_Rollout) catch()
    -- InLab_MostrarSplash()
    -- AJUSTE 15/Set: altura reduzida de 690 pra 600 — a barra do topo e a
    -- barra de progresso que ocupavam esse espaço foram removidas. Valor
    -- estimado, não testado no Max ainda; se sobrar/faltar espaço embaixo
    -- do Log de Sessão, é só ajustar este número.
    createDialog InLabChecker_Rollout 446 600
)
