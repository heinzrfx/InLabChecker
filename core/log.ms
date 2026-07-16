/*
================================================================================
 core\log.ms
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Motor de log compartilhado pelas duas frentes do plugin (Preparação e
 Verificação). Mantém o histórico da sessão em memória (InLab_LogLines),
 espelha cada linha em três lugares:
   1. array global (histórico da sessão)
   2. MAXScript Listener (via format) — útil para debug
   3. listbox da UI (quando a janela está aberta)
 e permite salvar o histórico em .txt.

 Tipos de mensagem: #info (padrão), #ok, #warn, #err — viram prefixo textual.
================================================================================
*/

-- Histórico da sessão. Persiste enquanto o Max estiver aberto,
-- mesmo se a janela do plugin for fechada e reaberta.
global InLab_LogLines = #()

-- Referência ao listbox do log na UI. É setada pelo rollout no evento "open"
-- e volta a undefined quando a janela fecha. O log funciona mesmo sem UI.
global InLab_LogUI = undefined

-- Reenvia o histórico completo para o listbox da UI (se ela estiver aberta)
-- e rola a seleção para a última linha.
fn InLab_RefreshLogUI =
(
    if InLab_LogUI != undefined do
    (
        InLab_LogUI.items = InLab_LogLines
        if InLab_LogLines.count > 0 do InLab_LogUI.selection = InLab_LogLines.count
    )
)

-- Função principal de log. Uso:
--   InLab_Log "mensagem"                → [INFO]
--   InLab_Log "mensagem" tipo:#ok       → [ OK ]
--   InLab_Log "mensagem" tipo:#warn     → [AVISO]
--   InLab_Log "mensagem" tipo:#err      → [ERRO]
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
    append InLab_LogLines linha       -- 1. histórico em memória
    format "%\n" linha                -- 2. eco no Listener
    InLab_RefreshLogUI()              -- 3. UI
    linha
)

-- Loga um array de linhas de uma vez (usado com FamiliaConfig.linhasDescricao
-- e, na Fase 5, com as linhas dos VerifResults).
fn InLab_LogLinhas linhas tipo:#info =
(
    for l in linhas do InLab_Log l tipo:tipo
)

-- Limpa o histórico da sessão e atualiza a UI.
fn InLab_LimparLog =
(
    InLab_LogLines = #()
    InLab_RefreshLogUI()
    InLab_Log "Log limpo."
)

-- Salva o histórico completo em um arquivo .txt.
-- Robustez: força extensão .txt, tenta o caminho escolhido e, se o disco/
-- pasta recusar (permissão, lock de sync do Google Drive etc.), cai para a
-- pasta temp do Max e informa o caminho real no log. Verifica o arquivo em
-- disco antes de declarar sucesso. Retorna o caminho salvo ou undefined.
fn InLab_SalvarLog arquivo =
(
    -- Garante a extensão .txt (getSaveFileName pode devolver sem extensão).
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
            -- Só declara sucesso com o arquivo confirmado em disco.
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
