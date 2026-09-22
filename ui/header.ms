/*
================================================================================
 ui\header.ms — v0.12 (22/09/2026): faixa de marca no topo do painel
--------------------------------------------------------------------------------
 O QUE E: um System.Windows.Forms.Panel de 56px que mora dentro de
 InLabChecker_Rollout, com a marca a esquerda, o titulo no meio, e a direita o
 botao Reload e a pastilha de versao. A pastilha E o aviso de atualizacao.

 POR QUE dotNet E NAO CONTROLE DE ROLLOUT: rollout nao cria controle em tempo
 de execucao (pegadinha ja no CLAUDE.md), e nao pinta faixa. A restricao vale
 pra controle DE ROLLOUT — filho de Panel dotNet e criado a hora que quiser, e
 e por isso que os 5 estados da pastilha cabem num controle so.

 TODO ESTADO EM GLOBAL, DE PROPOSITO: handler de evento dotNet roda num escopo
 que NAO enxerga `local` do rollout que o declarou — so globais e funcoes de
 nivel superior. Mesma causa-raiz documentada em ui\splash.ms. Nenhum handler
 deste arquivo le local de rollout.

 A ARTE PODE FALTAR: o pacote do updater e validado so contra INLAB_MODULOS,
 que e tudo .ms — um pacote sem ui\img\header_bulbo.png passa na validacao. O
 header entao monta sem a imagem, so com a tipografia, e loga #warn. Ver a
 spec 2026-09-22-header-kit-ui-design.md, secao 6.

 O PNG NAO PODE FICAR TRAVADO: Image.FromFile e Bitmap(String) seguram o
 arquivo enquanto a imagem viver, e o updater precisa renomear a pasta de
 instalacao. Por isso a imagem e copiada pra um Bitmap novo e o original e
 descartado na hora.

 DE ONDE VEM A ARTE: ui\img\header_bulbo.png e derivada de
 G:\Meu Drive\Trabalhos\2026\Artefacto\Logo\9.png, um ativo de design que
 mora FORA deste repo (nao versionado). Só a derivada 120x160 gerada dele —
 ui\img\header_bulbo.png — fica versionada aqui.
================================================================================
*/

global INLAB_ROOT
global INLAB_HEADER_VERSAO_PADRAO = "0.11"  -- maior versao declarada no repo
                                            -- (InLabChecker.ms). Unificar as
                                            -- strings e do core\versao.ms, na
                                            -- spec do updater.
global InLab_Header_Pnl, InLab_Header_Marca, InLab_Header_Titulo
global InLab_Header_Sub, InLab_Header_BtnReload, InLab_Header_Pastilha
global InLab_Header_Montar, InLab_Header_OnReload
global InLab_RecarregarPlugin

-- Handler de nivel superior: so le global.
fn InLab_Header_OnReload sender arg =
(
    try ( InLab_RecarregarPlugin() )
    catch ( InLab_Log ("Header: falha no Reload — " + getCurrentException()) tipo:#err )
)

-- Carrega o PNG sem deixar o arquivo travado. Devolve a imagem ou undefined.
fn InLab_Header_CarregarArte caminho =
(
    if not (doesFileExist caminho) then
    (
        InLab_Log ("Header: arte ausente (" + caminho + ") — seguindo sem a marca.") tipo:#warn
        undefined
    )
    else
    (
        local img = undefined
        try
        (
            local tmp = dotNetObject "System.Drawing.Bitmap" caminho
            img = dotNetObject "System.Drawing.Bitmap" tmp
            tmp.Dispose()   -- solta o arquivo; sem isso o updater nao renomeia a pasta
        )
        catch
        (
            InLab_Log ("Header: falha ao ler a arte — " + getCurrentException()) tipo:#warn
            img = undefined
        )
        img
    )
)

fn InLab_Header_Montar pnl =
(
    InLab_Header_Pnl = pnl
    pnl.Controls.Clear()   -- idempotente: montar 2x nao duplica
    pnl.BackColor = InLab_Kit_Cor #FUNDO_HEADER

    local dir = (dotNetClass "System.Windows.Forms.AnchorStyles")
    local ancRight = dotNet.combineEnums dir.Top dir.Right

    -- MARCA
    InLab_Header_Marca = dotNetObject "System.Windows.Forms.PictureBox"
    InLab_Header_Marca.Location = dotNetObject "System.Drawing.Point" 10 8
    InLab_Header_Marca.Size = dotNetObject "System.Drawing.Size" 30 40
    InLab_Header_Marca.SizeMode = (dotNetClass "System.Windows.Forms.PictureBoxSizeMode").Zoom
    InLab_Header_Marca.BackColor = InLab_Kit_Cor #FUNDO_HEADER
    local img = InLab_Header_CarregarArte (INLAB_ROOT + @"ui\img\header_bulbo.png")
    if img != undefined do InLab_Header_Marca.Image = img
    pnl.Controls.Add InLab_Header_Marca

    -- TITULO
    InLab_Header_Titulo = dotNetObject "System.Windows.Forms.Label"
    InLab_Header_Titulo.Text = "InLabChecker"
    InLab_Header_Titulo.Font = InLab_Kit_Fonte 11 bold:true
    InLab_Header_Titulo.ForeColor = InLab_Kit_Cor #TEXTO_FORTE
    InLab_Header_Titulo.BackColor = InLab_Kit_Cor #FUNDO_HEADER
    InLab_Header_Titulo.AutoSize = true
    InLab_Header_Titulo.Location = dotNetObject "System.Drawing.Point" 51 10
    pnl.Controls.Add InLab_Header_Titulo

    -- SUBTITULO
    InLab_Header_Sub = dotNetObject "System.Windows.Forms.Label"
    InLab_Header_Sub.Text = "preparação e verificação · InLab artefacto"
    InLab_Header_Sub.Font = InLab_Kit_Fonte 7
    InLab_Header_Sub.ForeColor = InLab_Kit_Cor #TEXTO_FRACO
    InLab_Header_Sub.BackColor = InLab_Kit_Cor #FUNDO_HEADER
    InLab_Header_Sub.AutoSize = true
    InLab_Header_Sub.Location = dotNetObject "System.Drawing.Point" 53 32
    pnl.Controls.Add InLab_Header_Sub

    -- PASTILHA (canto direito; Task 4 pinta o estado)
    InLab_Header_Pastilha = dotNetObject "System.Windows.Forms.Button"
    InLab_Header_Pastilha.Size = dotNetObject "System.Drawing.Size" 74 28
    InLab_Header_Pastilha.Location = dotNetObject "System.Drawing.Point" (pnl.Width - 84) 14
    InLab_Header_Pastilha.Anchor = ancRight
    InLab_Kit_Pastilha InLab_Header_Pastilha #INFO ("v" + INLAB_HEADER_VERSAO_PADRAO)
    pnl.Controls.Add InLab_Header_Pastilha

    -- RELOAD
    InLab_Header_BtnReload = dotNetObject "System.Windows.Forms.Button"
    InLab_Header_BtnReload.Size = dotNetObject "System.Drawing.Size" 28 28
    InLab_Header_BtnReload.Location = dotNetObject "System.Drawing.Point" (pnl.Width - 118) 14
    InLab_Header_BtnReload.Anchor = ancRight
    InLab_Header_BtnReload.Text = "⟳"
    InLab_Kit_BotaoIcone InLab_Header_BtnReload
    InLab_Header_BtnReload.Font = InLab_Kit_Fonte 12
    dotNet.addEventHandler InLab_Header_BtnReload "Click" InLab_Header_OnReload
    pnl.Controls.Add InLab_Header_BtnReload

    true
)
