/*
================================================================================
 ui\rollout_update.ms — seção "Atualização" (23/09/2026, issue #14)
--------------------------------------------------------------------------------
 Em arquivo próprio não pelo tamanho de rollout_main.ms, mas porque é a ÚNICA
 seção com estado assíncrono: o que ela mostra muda sozinho, quando a resposta
 do GitHub ou o download chegam. Toda a lógica está em functions\fn_updater.ms;
 aqui só se lê InLab_Update e se chama InLab_UpdateExecutar.

 OS CONTROLES EXISTEM SEMPRE: rollout de MaxScript não cria controle em tempo
 de execução. InLab_SecUpdate_Atualizar muda só .text, .enabled, .visible,
 .pos e .width conforme o estado. Os 6 estados seguem o mockup
 (https://claude.ai/artifact/BmdGKqEzK5qiDALMdcC99L):
   #ocioso     verde   "Você está na versão mais recente."  Procurar; Voltar (se há .bak)
   #checando   neutra  "Consultando o GitHub..."             Procurar (desabilitado)
   #disponivel âmbar   "vX disponível · N KB" + data         Atualizar; Notas; Ignorar
   #baixando / #aplicando  progresso + barra                 Cancelar
   pós-sucesso verde   "Atualizado para vX" + 3 linhas       Procurar; Voltar para a vY
   #erro       vermelha a causa + 3 linhas                   Tentar de novo; Copiar log
 As cores vêm de ui\kit.ms (OK/WARN/ERR/INFO/PROGRESSO), nunca literais.
 A caixa de status tem 62 px (3 linhas + padding): a causa de um #erro ("pacote
 incompleto, falta(m) 1 módulo(s): verifications\verif_uv.ms.") quebra em
 duas linhas sozinha, com 40 px a linha "Você continua na vX" era cortada.

 QUEM REPINTA: fn_updater.ms chama InLab_SecUpdate_Atualizar no fim de
 InLab_UpdatePintarHeader, que roda a cada mudança de estado — inclusive no
 callback que chega DEPOIS de um Reload, quando este rollout pode estar
 fechado ou recriado. Por isso a função confere .isDisplayed e roda inteira
 em try (o chamador loga). Numa sub-seção, .open quer dizer "desenrolada" (e
 é o que desenrola, em InLab_SecUpdate_Mostrar); .rolledUp não existe como
 propriedade, só como parâmetro do AddSubRollout.

 A TARJA DA SPEC NÃO EXISTE: quem avisa é a pastilha do header (ver a nota de
 obsoleto na spec do updater, seção 4). O clique na pastilha em #disponivel ou
 #erro abre esta seção (InLab_SecUpdate_Mostrar).
================================================================================
*/

global InLab_SecUpdate_Atualizar, InLab_SecUpdate_Mostrar
global InLabSecUpdate, InLabChecker_Rollout

-- Ação de cada um dos 3 botões no estado atual; o handler só repassa.
global INLAB_SECUPDATE_ACOES = #(undefined, undefined, undefined)

rollout InLabSecUpdate "Atualização" width:420 height:200
(
    checkbox chkAuto "Procurar atualizações automaticamente" pos:[10,6] checked:true
    label lblInstalada "Instalada: v" pos:[10,28] width:200 align:#left
    label lblChecagem "Checagem: nunca" pos:[210,28] width:198 align:#right
    dotNetControl lblStatus "System.Windows.Forms.Label" pos:[10,48] width:398 height:62
    progressbar pbDown pos:[10,116] width:398 height:10 value:0 visible:false
    dotNetControl lblHist "System.Windows.Forms.Label" pos:[10,116] width:398 height:44
    button btnA "Procurar atualização agora" pos:[10,168] width:398 height:24
    button btnB "" pos:[214,168] width:90 height:24 visible:false
    button btnC "" pos:[318,168] width:90 height:24 visible:false

    on InLabSecUpdate open do
    (
        chkAuto.checked = (InLab_PrefLer "autoCheck" "true") == "true"
        lblStatus.Font = InLab_Kit_Fonte 9
        lblStatus.Padding = dotNetObject "System.Windows.Forms.Padding" 6 4 6 4
        lblStatus.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
        lblHist.Font = dotNetObject "System.Drawing.Font" "Consolas" 8
        lblHist.BackColor = InLab_Kit_Cor #LOG
        lblHist.ForeColor = InLab_Kit_Cor #PROGRESSO_TEXTO
        lblHist.Padding = dotNetObject "System.Windows.Forms.Padding" 4 3 4 3
        pbDown.color = (color 111 143 176)   -- PROGRESSO_ACENTO do kit; progressbar nativo pede color MaxScript
        try ( InLab_SecUpdate_Atualizar() )
        catch ( InLab_Log ("Atualização: falha ao montar a seção (" + getCurrentException() + ").") tipo:#warn )
    )

    on chkAuto changed estado do
    (
        InLab_PrefGravar "autoCheck" (if estado then "true" else "false")
        InLab_Log ("Atualização: procurar automaticamente " + (if estado then "ligado." else "desligado.")) tipo:#info
    )

    on btnA pressed do InLab_UpdateExecutar INLAB_SECUPDATE_ACOES[1]
    on btnB pressed do InLab_UpdateExecutar INLAB_SECUPDATE_ACOES[2]
    on btnC pressed do InLab_UpdateExecutar INLAB_SECUPDATE_ACOES[3]
)

-- Pinta a caixa de status. tipo: #OK | #WARN | #ERR | #INFO | #PROGRESSO
fn InLab_SecUpdate_Caixa tipo linha1 linha2 =
(
    local r = InLabSecUpdate
    local suf = tipo as string
    r.lblStatus.BackColor = InLab_Kit_Cor ((suf + "_FUNDO") as name)
    r.lblStatus.ForeColor = InLab_Kit_Cor ((suf + "_TEXTO") as name)
    r.lblStatus.Text = "●  " + linha1 + (if linha2 != "" then "\n     " + linha2 else "")
)

-- botoes: #(#(texto, acao, habilitado), ...) com 1 a 3 itens. O 1º ocupa o
-- que sobra da largura; os outros têm largura fixa.
fn InLab_SecUpdate_Botoes botoes =
(
    local r = InLabSecUpdate
    local ctrls = #(r.btnA, r.btnB, r.btnC)
    -- 2 botões: o 2º é largo ("Voltar para a v0.12", "Copiar log do erro");
    -- 3 botões: Notas e Ignorar cabem em 90.
    local fixa = if botoes.count == 2 then 150 else 90
    local larg = #(0, fixa, fixa)
    local x0 = 10
    local total = 398
    local fixos = 0
    for i = 2 to botoes.count do fixos += larg[i] + 6
    larg[1] = total - fixos
    local x = x0
    for i = 1 to 3 do
    (
        if i <= botoes.count then
        (
            ctrls[i].visible = true
            ctrls[i].text = botoes[i][1]
            ctrls[i].enabled = botoes[i][3]
            ctrls[i].width = larg[i]
            ctrls[i].pos = [x, 168]
            x += larg[i] + 6
            INLAB_SECUPDATE_ACOES[i] = botoes[i][2]
        )
        else
        (
            ctrls[i].visible = false
            INLAB_SECUPDATE_ACOES[i] = undefined
        )
    )
)

fn InLab_SecUpdate_Hist =
(
    local linhas = ""
    local n = INLAB_UPDATE_HIST.count
    for i = (amax 1 (n - 2)) to n do linhas += INLAB_UPDATE_HIST[i] + (if i < n then "\n" else "")
    linhas
)

fn InLab_SecUpdate_Atualizar =
(
    -- .isDisplayed (está no painel), NÃO .open: numa sub-seção, .open é
    -- "desenrolada", e a seção entra enrolada — com .open ela nunca pintaria.
    if InLabSecUpdate != undefined and InLabSecUpdate.isDisplayed do
    (
        local r = InLabSecUpdate
        local u = InLab_Update
        local bak = InLab_UpdateVersaoBak()
        local ocupado = u.estado == #baixando or u.estado == #aplicando

        r.lblInstalada.text = "Instalada: v" + INLAB_VERSAO
        r.lblChecagem.text = if ocupado then "Aplicando: v" + u.versaoRemota
                             else "Checagem: " + (InLab_UpdateUltimaChecagemTexto())
        r.chkAuto.enabled = not ocupado
        r.pbDown.visible = ocupado
        r.pbDown.value = if u.estado == #aplicando then 100 else u.pct
        r.lblHist.visible = false

        local botaoVoltar = if bak != undefined then #("Voltar para a v" + bak, #reverter, true) else undefined

        case u.estado of
        (
            #checando:
            (
                InLab_SecUpdate_Caixa #PROGRESSO "Consultando o GitHub em segundo plano..." ""
                InLab_SecUpdate_Botoes #(#("Procurar atualização agora", #procurar, false))
            )
            #disponivel:
            (
                local tam = InLab_UpdateTamanhoTexto u.tamanhoZip
                local l1 = "v" + u.versaoRemota + " disponível" + (if tam != "" then " · " + tam else "") + (if u.ignorada then " (ignorada)" else "")
                local l2 = (if u.publicadaEm != "" then "Publicada em " + u.publicadaEm + " · " else "") + "nada foi baixado ainda"
                InLab_SecUpdate_Caixa #WARN l1 l2
                InLab_SecUpdate_Botoes #(#("Atualizar agora", #aplicar, true), #("Notas", #notas, u.notasUrl != ""), \
                                         #((if u.ignorada then "Ignorada" else "Ignorar"), #ignorar, not u.ignorada))
            )
            #baixando:
            (
                InLab_SecUpdate_Caixa #PROGRESSO ("Baixando v" + u.versaoRemota + "... " + u.pct as string + "%") "O Max continua utilizável durante o download."
                InLab_SecUpdate_Botoes #(#("Cancelar", #cancelar, true))
            )
            #aplicando:
            (
                InLab_SecUpdate_Caixa #PROGRESSO ("Aplicando v" + u.versaoRemota + "...") "Validando o pacote e trocando a pasta do plugin."
                InLab_SecUpdate_Botoes #(#("Cancelar", #cancelar, false))
            )
            #erro:
            (
                InLab_SecUpdate_Caixa #ERR u.msgErro ("Você continua na v" + INLAB_VERSAO + ".")
                r.lblHist.Text = InLab_SecUpdate_Hist()
                r.lblHist.visible = true
                InLab_SecUpdate_Botoes #(#("Tentar de novo", #tentar, true), #("Copiar log do erro", #copiar, true))
            )
            default:   -- #ocioso, com ou sem aviso de sucesso
            (
                if u.aviso != "" then
                (
                    InLab_SecUpdate_Caixa #OK u.aviso (if bak != undefined then "Plugin recarregado. A v" + bak + " ficou guardada em InLabChecker.bak." else "")
                    r.lblHist.Text = InLab_SecUpdate_Hist()
                    r.lblHist.visible = true
                )
                else if u.msgErro != "" then InLab_SecUpdate_Caixa #INFO u.msgErro ""
                else if u.versaoRemota == "" then InLab_SecUpdate_Caixa #INFO "Ainda não procurou atualização nesta sessão." ""
                else InLab_SecUpdate_Caixa #OK "Você está na versão mais recente." ""
                local bs = #(#("Procurar atualização agora", #procurar, true))
                if botaoVoltar != undefined do append bs botaoVoltar
                InLab_SecUpdate_Botoes bs
            )
        )
    )
)

-- Clique na pastilha do header: desenrola a seção para o artista ver.
fn InLab_SecUpdate_Mostrar =
(
    if InLabSecUpdate != undefined and InLabSecUpdate.isDisplayed then
    (
        InLabSecUpdate.open = true   -- desenrola (não existe .rolledUp)
        InLab_SecUpdate_Atualizar()
        true
    )
    else false
)
