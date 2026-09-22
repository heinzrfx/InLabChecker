/*
================================================================================
 core\log.ms — v0.10 (13/Jul): log colorido via dotNet RichTextBox
--------------------------------------------------------------------------------
 LIMITAÇÃO DE ENGINE (documentada, não contornável): o listbox nativo do
 MaxScript não suporta cor por linha. Substituído por um controle dotNet
 RichTextBox embutido no rollout — permite cor por linha e fonte monoespaçada.

 Mapeamento de cor pedido pela equipe:
   #err  (verificação FAIL)        → vermelho
   #ok   (verificação PASS / sucesso genérico) → verde
   #warn (advertência)             → âmbar (decisão: não é "falha" nem
                                      neutro puro — mantém sinalização visível
                                      sem confundir com FAIL)
   #info (mensagens neutras)       → cinza claro (cor padrão do tema escuro)

 22/09/2026: o tom do âmbar de #warn mudou de FromArgb 230 180 90 para
 FromArgb 232 164 41 — o mesmo âmbar amostrado do logo (G:\Meu Drive\
 Trabalhos\2026\Artefacto\Logo\9.png, ativo de design fora do repo), usado
 como cor de marca em ui\kit.ms. O cabeçalho acima ("âmbar") continua
 verdadeiro, só mudou o tom. Ver ui\kit.ms e a spec
 2026-09-22-header-kit-ui-design.md.

 Fundo escuro fixo (independe do tema do Max) para manter contraste com as
 cores acima — combina com a paleta escura do restante da UI de referência.
================================================================================
*/

global InLab_LogLines = #()      -- histórico da sessão (texto puro, sem cor)
global InLab_LogUI    = undefined -- referência ao dotNet RichTextBox

fn InLab_CorDoTipo tipo =
(
    case tipo of
    (
        #ok:      (dotNetClass "System.Drawing.Color").FromArgb 120 220 120
        #err:     (dotNetClass "System.Drawing.Color").FromArgb 235 90 90
        -- 22/09/2026: era FromArgb 230 180 90. Passou a ser o ambar da marca
        -- (#E8A429, amostrado de G:\Meu Drive\Trabalhos\2026\Artefacto\
        -- Logo\9.png, fora do repo) pra aviso e marca serem a mesma cor —
        -- ver ui\kit.ms e a spec 2026-09-22-header-kit-ui-design.md.
        #warn:    (dotNetClass "System.Drawing.Color").FromArgb 232 164 41
        default:  (dotNetClass "System.Drawing.Color").FromArgb 210 210 210
    )
)

-- Reenvia o histórico completo para o RichTextBox (usado ao abrir a janela
-- ou reconectar). Reconstrói as cores a partir do prefixo de cada linha,
-- já que o histórico em InLab_LogLines é texto puro.
fn InLab_RefreshLogUI =
(
    if InLab_LogUI != undefined do
    (
        InLab_LogUI.Clear()
        for l in InLab_LogLines do
        (
            local tipo = case (substring l 1 7) of
            (
                "[ OK ] ": #ok
                "[ERRO] ": #err
                "[AVISO]": #warn
                default:   #info
            )
            InLab_LogUI.SelectionStart  = InLab_LogUI.TextLength
            InLab_LogUI.SelectionLength = 0
            InLab_LogUI.SelectionColor  = InLab_CorDoTipo tipo
            InLab_LogUI.AppendText (l + "\n")
        )
        InLab_LogUI.SelectionStart = InLab_LogUI.TextLength
        InLab_LogUI.ScrollToCaret()
    )
)

fn InLab_Log msg tipo:#info =
(
    local prefixo = case tipo of
    (
        #info: "[INFO] "
        #ok:   "[ OK ] "
        #warn: "[AVISO]"
        #err:  "[ERRO] "
        default: "[INFO] "
    )
    local linha = prefixo + " " + (msg as string)
    append InLab_LogLines linha
    format "%\n" linha

    if InLab_LogUI != undefined do
    (
        InLab_LogUI.SelectionStart  = InLab_LogUI.TextLength
        InLab_LogUI.SelectionLength = 0
        InLab_LogUI.SelectionColor  = InLab_CorDoTipo tipo
        InLab_LogUI.AppendText (linha + "\n")
        InLab_LogUI.SelectionStart = InLab_LogUI.TextLength
        InLab_LogUI.ScrollToCaret()
    )
    linha
)

fn InLab_LogLinhas linhas tipo:#info =
(
    for l in linhas do InLab_Log l tipo:tipo
)

fn InLab_LimparLog =
(
    InLab_LogLines = #()
    InLab_RefreshLogUI()
    InLab_Log "Log limpo."
)

-- Salva o histórico (texto puro, sem cor — cor é só de tela) em .txt.
-- Robustez mantida: cai para pasta temp se o caminho escolhido recusar.
fn InLab_SalvarLog arquivo =
(
    if (toLower (getFilenameType arquivo)) != ".txt" do arquivo += ".txt"
    local salvoEm = undefined
    local tentativas = #(arquivo, ((getDir #temp) + "\\" + (filenameFromPath arquivo)))
    for caminho in tentativas while salvoEm == undefined do
    (
        local f = try ( createFile caminho ) catch ( undefined )
        if f != undefined do
        (
            for l in InLab_LogLines do format "%\n" l to:f
            close f
            if doesFileExist caminho do salvoEm = caminho
        )
    )
    if salvoEm != undefined then
    (
        if salvoEm != arquivo do
            InLab_Log ("Caminho original recusado — log salvo na pasta temp: " + salvoEm) tipo:#warn
        salvoEm
    )
    else undefined
)

--------------------------------------------------------------------------------
-- PROGRESSO (v0.10): indicador visual fixo, fora das abas, para operações
-- demoradas (ProOptimizer, Auto UV, Verificações). Como as operações não
-- expõem progresso granular, usa barra INDETERMINADA (efeito "marquee") —
-- comunica "processando", não percentual real.
--------------------------------------------------------------------------------
global InLab_ProgressUI = undefined   -- dotNet ProgressBar
global InLab_ProgressLbl = undefined  -- dotNet Label (texto de status)

fn InLab_ProgressoIniciar msg =
(
    if InLab_ProgressUI != undefined do
    (
        InLab_ProgressUI.Style = (dotNetClass "System.Windows.Forms.ProgressBarStyle").Marquee
        InLab_ProgressUI.Visible = true
    )
    if InLab_ProgressLbl != undefined do
    (
        InLab_ProgressLbl.Text = msg
        InLab_ProgressLbl.Visible = true
    )
    try ( windows.processPostedMessages() ) catch()
)

fn InLab_ProgressoParar =
(
    if InLab_ProgressUI != undefined do InLab_ProgressUI.Visible = false
    if InLab_ProgressLbl != undefined do InLab_ProgressLbl.Visible = false
)
