/*
================================================================================
 ui\kit.ms — v0.12 (22/09/2026): vocabulario visual compartilhado
--------------------------------------------------------------------------------
 O QUE E: as cores, a fonte e os dois widgets que o header usa. Nao sabe o que
 e um header nem o que e uma secao — so entrega cor e estilo. Mexer numa cor
 aqui muda o painel inteiro.

 DE ONDE VEM CADA COR (medido em 22/09/2026, ver
 docs\superpowers\specs\2026-09-22-header-kit-ui-design.md secao 3):
   - MARCA #E8A429: amostrada do proprio logo (G:\Meu Drive\Trabalhos\2026\
     Artefacto\Logo\9.png, ativo de design fora do repo), cor chapada.
   - OK / ERR / INFO: lidas de InLab_CorDoTipo em core\log.ms. Sao as cores
     que a equipe aprovou em 13/Jul; o kit promove elas do log pro painel.
   - WARN: passou de #E6B45A para a cor da MARCA em 22/09, pra marca e aviso
     serem a mesma cor. Unica alteracao deste modulo no core\log.ms.
   - PROGRESSO #6F8FB0: NAO vem do log. E papel novo — "trabalho em andamento"
     — que os estados #checando e #baixando usam.

 POR QUE ACENTO E TEXTO SAO CORES DIFERENTES: a cor do log serve de bolinha
 (grafico, precisa 3:1) mas reprova como texto pequeno sobre o fundo colorido.
 #EB5A5A sobre #452626 da 3,8:1; o tom claro #F0A9A9 da 6,8:1.

 YAGNI: nasce so com o que o header consome. Caixa de status e barra de
 progresso entram quando a secao Atualizacao existir (sub-projeto 3).
 FUNDO_PAINEL, SUPERFICIE, LOG e TEXTO ficam sem consumidor por enquanto DE
 PROPOSITO: a spec (secao 4) nomeia as quatro na lista do kit e a repaginacao
 das 7 secoes (sub-projeto 4) e a consumidora imediata.

 CONSERTOS DO REVIEW FINAL (22/09/2026):
   - LOG passou de (35,35,35) para (30,30,30), que e o valor real lido em
     ui\rollout_main.ms (rtbLog.BackColor). Divergia do log de verdade.
   - InLab_Kit_Pastilha parou de criar um System.Drawing.Font por chamada.
     Ver o comentario de INLAB_KIT_FONTE_PASTILHA abaixo.
================================================================================
*/

global INLAB_KIT_CORES
global InLab_Kit_Cor, InLab_Kit_Fonte, InLab_Kit_BotaoIcone, InLab_Kit_Pastilha

-- FONTES DA PASTILHA — CRIADAS UMA VEZ SO (22/09/2026). Cada
-- System.Drawing.Font e um handle GDI, e o processo tem cota (~10 mil). O
-- consumidor documentado de InLab_Kit_Pastilha e o estado #baixando pct:, que
-- e um callback de progresso de download: uma fonte nova por tick vazaria
-- handle ate o Max ficar sem. Declaradas SEM valor de proposito — `global X`
-- sem atribuicao nao zera um global que ja existe, entao as duas fontes
-- sobrevivem ao reload (`global X = expr` recriaria as duas a cada fileIn).
global INLAB_KIT_FONTE_PASTILHA, INLAB_KIT_FONTE_PASTILHA_BOLD

INLAB_KIT_CORES = #(
    -- superficies
    #(#FUNDO_HEADER,     #( 31,  31,  31)),
    #(#FUNDO_PAINEL,     #( 43,  43,  43)),
    #(#SUPERFICIE,       #( 63,  63,  63)),
    -- LOG: lido de ui\rollout_main.ms (rtbLog.BackColor = FromArgb 30 30 30),
    -- nao estimado. Estava (35,35,35) ate 22/09/2026 e divergia do log real —
    -- a primeira secao a trocar o literal pela cor do kit teria mudado o fundo
    -- do log sem querer.
    #(#LOG,              #( 30,  30,  30)),
    -- marca
    #(#MARCA,            #(232, 164,  41)),
    -- texto
    #(#TEXTO_FORTE,      #(240, 240, 240)),
    #(#TEXTO,            #(216, 216, 216)),
    #(#TEXTO_FRACO,      #(138, 138, 138)),
    -- botao de icone
    #(#BOTAO_FUNDO,      #( 58,  58,  58)),
    #(#BOTAO_BORDA,      #( 74,  74,  74)),
    #(#BOTAO_ICONE,      #(208, 208, 208)),
    -- status: acento espelha core\log.ms; fundo/borda/texto sao do painel
    #(#OK_ACENTO,        #(120, 220, 120)),
    #(#OK_FUNDO,         #( 49,  58,  46)),
    #(#OK_BORDA,         #( 58,  74,  54)),
    #(#OK_TEXTO,         #(169, 214, 155)),
    #(#WARN_ACENTO,      #(232, 164,  41)),
    #(#WARN_FUNDO,       #( 74,  60,  34)),
    #(#WARN_BORDA,       #(154, 124,  52)),
    #(#WARN_TEXTO,       #(240, 200, 131)),
    #(#ERR_ACENTO,       #(235,  90,  90)),
    #(#ERR_FUNDO,        #( 69,  38,  38)),
    #(#ERR_BORDA,        #(110,  56,  56)),
    #(#ERR_TEXTO,        #(240, 169, 169)),
    #(#INFO_ACENTO,      #(210, 210, 210)),
    #(#INFO_FUNDO,       #( 51,  51,  51)),
    #(#INFO_BORDA,       #( 69,  69,  69)),
    #(#INFO_TEXTO,       #(168, 168, 168)),
    #(#PROGRESSO_ACENTO, #(111, 143, 176)),
    #(#PROGRESSO_FUNDO,  #( 47,  55,  66)),
    #(#PROGRESSO_BORDA,  #( 60,  70,  84)),
    #(#PROGRESSO_TEXTO,  #(168, 182, 196))
)

-- Cor por nome. Nome errado nao passa batido: vira magenta na tela e #err no
-- log, pra aparecer na primeira olhada em vez de virar um cinza qualquer.
fn InLab_Kit_Cor nome =
(
    local rgb = undefined
    for par in INLAB_KIT_CORES where par[1] == nome do rgb = par[2]
    if rgb == undefined then
    (
        InLab_Log ("Kit: cor desconhecida '" + (nome as string) + "' — usando magenta.") tipo:#err
        (dotNetClass "System.Drawing.Color").FromArgb 255 0 255
    )
    else (dotNetClass "System.Drawing.Color").FromArgb rgb[1] rgb[2] rgb[3]
)

-- tam em PONTOS, nao pixels: e o que System.Drawing.Font recebe.
fn InLab_Kit_Fonte tam bold:false =
(
    local estilo = if bold then (dotNetClass "System.Drawing.FontStyle").Bold
                   else (dotNetClass "System.Drawing.FontStyle").Regular
    dotNetObject "System.Drawing.Font" "Segoe UI" (tam as float) estilo
)

fn InLab_Kit_BotaoIcone btn =
(
    btn.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
    btn.FlatAppearance.BorderColor = InLab_Kit_Cor #BOTAO_BORDA
    btn.FlatAppearance.BorderSize = 1
    btn.BackColor = InLab_Kit_Cor #BOTAO_FUNDO
    btn.ForeColor = InLab_Kit_Cor #BOTAO_ICONE
    btn.Font = InLab_Kit_Fonte 9
    btn.Cursor = (dotNetClass "System.Windows.Forms.Cursors").Hand
    btn
)

-- tipo: #OK | #WARN | #ERR | #INFO | #PROGRESSO
fn InLab_Kit_Pastilha ctrl tipo texto clicavel:false =
(
    local suf = tipo as string
    ctrl.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
    ctrl.FlatAppearance.BorderSize = 1
    ctrl.FlatAppearance.BorderColor = InLab_Kit_Cor ((suf + "_BORDA") as name)
    ctrl.BackColor = InLab_Kit_Cor ((suf + "_FUNDO") as name)
    ctrl.ForeColor = InLab_Kit_Cor ((suf + "_TEXTO") as name)

    -- Fonte: reusa as duas globais e so atribui quando o negrito TEM que
    -- mudar. Sem isso, cada chamada (incluindo cada tick de #baixando)
    -- criaria um System.Drawing.Font novo e vazaria o handle GDI.
    if INLAB_KIT_FONTE_PASTILHA == undefined do
        INLAB_KIT_FONTE_PASTILHA = InLab_Kit_Fonte 8.25
    if INLAB_KIT_FONTE_PASTILHA_BOLD == undefined do
        INLAB_KIT_FONTE_PASTILHA_BOLD = InLab_Kit_Fonte 8.25 bold:true
    local fonteAlvo = if clicavel then INLAB_KIT_FONTE_PASTILHA_BOLD
                      else INLAB_KIT_FONTE_PASTILHA
    local fonteAtual = ctrl.Font
    -- A familia e o tamanho entram na comparacao porque um Button recem-criado
    -- ja vem com a fonte padrao do WinForms e Bold == false: olhar so o negrito
    -- deixaria a pastilha com a fonte de fabrica na primeira pintura.
    local fonteOk = false
    if fonteAtual != undefined do
    (
        if fonteAtual.Bold == clicavel and fonteAtual.FontFamily.Name == fonteAlvo.FontFamily.Name do
            fonteOk = (abs (fonteAtual.Size - fonteAlvo.Size)) < 0.01
    )
    if not fonteOk do ctrl.Font = fonteAlvo

    ctrl.Text = texto
    ctrl.Cursor = if clicavel then (dotNetClass "System.Windows.Forms.Cursors").Hand
                  else (dotNetClass "System.Windows.Forms.Cursors").Default
    ctrl
)
