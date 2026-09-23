/*
================================================================================
 functions\fn_updater.ms — updater, parte 1: checagem assíncrona de versão
 (23/09/2026, issue #12 — sub-issue do épico #8)
--------------------------------------------------------------------------------
 Consulta /releases/latest do GitHub em segundo plano e termina em
 #disponivel: sabe que existe versão nova, loga e acende a pastilha do header.
 NÃO BAIXA NADA — o download, a troca de pastas e o rollback são a issue #13,
 que continua deste mesmo arquivo. Spec:
 docs\superpowers\specs\2026-09-22-updater-design.md.

 PÚBLICO NESTA ISSUE
   InLab_UpdateChecar silencioso:false → true se disparou a consulta
   InLab_UpdateEstadoTexto()          → frase do estado, para a seção (#14)
   InLab_Update                       → estado (struct UpdateEstado)

 POR QUE NÃO HÁ BackgroundWorker, FILA NEM TIMER (medido no Max 2024, 22 e
 23/09/2026): WebClient.DownloadStringAsync retorna em 11–16 ms e o evento
 DownloadStringCompleted chega ~300 ms depois NA THREAD PRINCIPAL DO MAX
 (ManagedThreadId 1 na chamada e no callback — o WebClient captura o
 SynchronizationContext do WinForms de quem chamou). Então o callback escreve
 no InLab_Log e chama InLab_Header_Estado direto, sem proteção de thread.
 Isso vale porque o disparo sai da thread principal; disparar de outra thread
 mudaria a thread do callback.

 LIMITAÇÃO MEDIDA (23/09/2026): a resolução de DNS do WebClient é SÍNCRONA,
 mesmo no método Async. Com host que não resolve, DownloadStringAsync segurou
 a thread principal por 2,9 s antes de retornar. Com rede normal: 11 ms. Sem
 adaptador de rede a falha costuma ser imediata; o caso lento é DNS quebrado
 ou lento. Com o intervalo de 4 h, isso é no máximo um engasgo raro na
 abertura. Se virar problema, o caminho é resolver o nome antes com
 Dns.BeginGetHostAddresses — não foi feito para não ganhar um timer de
 polling por um caso raro.

 AS DUAS GUARDAS
 - TOKEN: cada consulta leva um inteiro novo em userToken e o callback lê de
   volta em e.UserState. Se não bate com InLab_Update.token, descarta em
   silêncio. Pega o Reload durante o voo: o fileIn deste arquivo recria
   InLab_Update com token+1 (ver abaixo), o que invalida a consulta em voo.
 - INTERVALO: a API anônima dá 60 requisições/h por IP, e um estúdio atrás de
   um IP chega perto. Checagem silenciosa só roda 4 h depois de
   ultimaChecagem (core\prefs.ms). A manual (silencioso:false) ignora o
   intervalo. ultimaChecagem é gravada no DISPARO, não na resposta: sem rede,
   gravar só no sucesso faria toda abertura do Max tentar de novo.

 O ESTADO SOBREVIVE AO RELOAD: `global InLab_Update` é declarado sem valor e
 recriado copiando os campos da instância anterior (a definição do struct pode
 ter mudado numa versão nova, por isso copia campo a campo em try). O token
 sobe 1; um #checando em voo vira #ocioso, porque a resposta será descartada.

 ERROS: modo silencioso (abertura do Max) → só #warn no log e a pastilha fica
 quieta; modo manual → #err no log e pastilha em #erro. 404 não é erro do
 artista ("nenhuma release publicada"): fica #ocioso com a frase em msgErro.

 PONTO DE TROCA PARA TESTE: InLab_Update_Disparar é global e o teste a troca
 por um stub, para nunca tocar a rede (tests\test_updater_checagem.ms).
================================================================================
*/

global InLab_Header_Estado            -- ui\header.ms, carregado depois
global InLab_Update_Disparar, InLab_UpdatePintarHeader

global INLAB_UPDATE_API = "https://api.github.com/repos/heinzrfx/InLabChecker/releases/latest"
global INLAB_UPDATE_INTERVALO_S = 4 * 3600

struct UpdateEstado
(
    estado = #ocioso,       -- #ocioso | #checando | #disponivel | #baixando | #aplicando | #erro
    versaoRemota = "",      -- tag da release, sem o "v"
    urlZip = "",
    tamanhoZip = 0,
    notasUrl = "",
    msgErro = "",
    token = 0,
    silencioso = true,      -- modo da consulta em curso/última
    ignorada = false        -- versaoRemota é a versaoIgnorada do ini
)

global InLab_Update
(
    local novo = UpdateEstado()
    if InLab_Update != undefined do
    (
        for campo in #(#estado, #versaoRemota, #urlZip, #tamanhoZip, #notasUrl, #msgErro, #token, #silencioso, #ignorada) do
            try ( setProperty novo campo (getProperty InLab_Update campo) ) catch ()
        novo.token += 1
        if novo.estado == #checando do novo.estado = #ocioso
    )
    InLab_Update = novo
)

-- Segundos Unix (UTC), como inteiro 32 bits — Integer64 `as string` sai com
-- "L" no final e não serve para o ini.
fn InLab_UpdateAgora = ((dotNetClass "System.DateTimeOffset").UtcNow.ToUnixTimeSeconds()) as integer

fn InLab_UpdateDeveChecar silencioso =
(
    if not silencioso then true
    else
    (
        local ultima = (InLab_PrefLer "ultimaChecagem" "") as integer
        ultima == undefined or ((InLab_UpdateAgora()) - ultima) >= INLAB_UPDATE_INTERVALO_S
    )
)

fn InLab_UpdateSemV v =
(
    local s = trimLeft (trimRight (v as string))
    if s.count > 0 and (s[1] == "v" or s[1] == "V") do s = substring s 2 -1
    s
)

fn InLab_UpdateFalhar msg =
(
    InLab_Update.estado = #erro
    InLab_Update.msgErro = msg
    InLab_Log ("Atualização: " + msg) tipo:(if InLab_Update.silencioso then #warn else #err)
    InLab_UpdatePintarHeader()
)

fn InLab_UpdatePintarHeader =
(
    if InLab_Header_Estado != undefined do
    try
    (
        local u = InLab_Update
        case u.estado of
        (
            #disponivel:
                if u.ignorada then InLab_Header_Estado #ocioso versao:INLAB_VERSAO
                else InLab_Header_Estado #disponivel versao:u.versaoRemota
            #checando: InLab_Header_Estado #checando
            #erro:
                if u.silencioso then InLab_Header_Estado #ocioso versao:INLAB_VERSAO
                else InLab_Header_Estado #erro
            default: InLab_Header_Estado #ocioso versao:INLAB_VERSAO
        )
    )
    catch
        InLab_Log ("Atualização: falha ao pintar a pastilha (" + getCurrentException() + ").") tipo:#warn
)

-- Interpreta a resposta. `tok` é o token que a consulta levou; `texto` o corpo
-- (undefined em erro); `status` o HTTP de erro (0 = sem resposta).
-- Devolve false se descartou por token, true se processou.
fn InLab_UpdateProcessar tok texto status:0 erro:undefined =
(
    if tok != InLab_Update.token then false
    else
    (
        if erro != undefined then
        (
            case status of
            (
                404:
                (
                    InLab_Update.estado = #ocioso
                    InLab_Update.msgErro = "Nenhuma release publicada ainda."
                    InLab_Log ("Atualização: " + InLab_Update.msgErro) tipo:#info
                    InLab_UpdatePintarHeader()
                )
                403: InLab_UpdateFalhar "o GitHub recusou a consulta (limite de 60 por hora por IP). Tente mais tarde."
                0: InLab_UpdateFalhar ("sem conexão com o GitHub (" + erro + ").")
                default: InLab_UpdateFalhar ("o GitHub respondeu HTTP " + status as string + " (" + erro + ").")
            )
        )
        else
        (
            local json = InLab_ParseJSON texto
            local tag = InLab_JSON_Obter json "tag_name"
            local assets = InLab_JSON_Obter json "assets"
            local zip = undefined
            if isKindOf assets Array do
                for a in assets while zip == undefined do
                (
                    local nome = InLab_JSON_Obter a "name"
                    if isKindOf nome String and matchPattern nome pattern:"*.zip" do zip = a
                )

            if json == undefined then InLab_UpdateFalhar "a resposta do GitHub não é um JSON válido."
            else if not (isKindOf tag String) then InLab_UpdateFalhar "a release não tem tag_name."
            else if zip == undefined then InLab_UpdateFalhar ("a release " + tag + " não tem um anexo .zip.")
            else
            (
                local u = InLab_Update
                u.versaoRemota = InLab_UpdateSemV tag
                u.urlZip = InLab_JSON_Obter zip "browser_download_url"
                u.tamanhoZip = InLab_JSON_Obter zip "size"
                u.notasUrl = InLab_JSON_Obter json "html_url"
                u.msgErro = ""
                if (InLab_CompararVersao INLAB_VERSAO u.versaoRemota) == -1 then
                (
                    local ign = InLab_PrefLer "versaoIgnorada" ""
                    u.ignorada = ign != "" and (InLab_CompararVersao ign u.versaoRemota) == 0
                    u.estado = #disponivel
                    if u.ignorada then
                        InLab_Log ("Atualização: v" + u.versaoRemota + " disponível, ignorada a seu pedido.") tipo:#info
                    else
                        InLab_Log ("Atualização: v" + u.versaoRemota + " disponível (instalada: v" + INLAB_VERSAO + ").") tipo:#warn
                )
                else
                (
                    u.ignorada = false
                    u.estado = #ocioso
                    InLab_Log ("Atualização: v" + INLAB_VERSAO + " é a versão mais recente.") tipo:#ok
                )
                InLab_UpdatePintarHeader()
            )
        )
        true
    )
)

-- Handler do DownloadStringCompleted. Nível superior e global para o
-- addEventHandler achar. Nada escapa: exceção aqui morreria sem rastro.
fn InLab_Update_OnConcluido sender e =
(
    try
    (
        local tok = try ( e.UserState as integer ) catch ( undefined )
        local texto = undefined
        local status = 0
        local erro = undefined
        if e.Cancelled then erro = "consulta cancelada"
        else if e.Error != undefined then
        (
            erro = e.Error.Message
            status = try ( e.Error.Response.StatusCode.value__ ) catch ( 0 )
        )
        else texto = e.Result
        try ( sender.Dispose() ) catch ()
        InLab_UpdateProcessar tok texto status:status erro:erro
    )
    catch
        InLab_Log ("Atualização: falha ao tratar a resposta (" + getCurrentException() + ").") tipo:#err
)

-- Dispara a consulta e retorna na hora. Trocada por stub nos testes.
fn InLab_Update_Disparar url tok =
(
    local ok = false
    try
    (
        local spm = dotNetClass "System.Net.ServicePointManager"
        spm.SecurityProtocol = (dotNetClass "System.Net.SecurityProtocolType").Tls12
        local wc = dotNetObject "System.Net.WebClient"
        wc.Encoding = (dotNetClass "System.Text.Encoding").UTF8
        wc.Headers.Add "User-Agent" ("InLabChecker/" + INLAB_VERSAO)   -- o GitHub recusa sem
        wc.Headers.Add "Accept" "application/vnd.github+json"
        dotnet.addEventHandler wc "DownloadStringCompleted" InLab_Update_OnConcluido
        dotnet.setLifetimeControl wc #dotnet
        wc.DownloadStringAsync (dotNetObject "System.Uri" url) tok
        ok = true
    )
    catch
        InLab_Log ("Atualização: não foi possível iniciar a consulta (" + getCurrentException() + ").") tipo:#warn
    ok
)

fn InLab_UpdateChecar silencioso:false =
(
    local u = InLab_Update
    if u.estado == #baixando or u.estado == #aplicando then
    (
        if not silencioso do InLab_Log "Atualização: já há uma atualização em andamento." tipo:#warn
        false
    )
    else if not (InLab_UpdateDeveChecar silencioso) then false
    else
    (
        u.token += 1
        u.silencioso = silencioso
        u.estado = #checando
        u.msgErro = ""
        InLab_PrefGravar "ultimaChecagem" ((InLab_UpdateAgora()) as string)
        if not silencioso do InLab_Log "Atualização: procurando versão nova..." tipo:#info
        InLab_UpdatePintarHeader()
        local ok = InLab_Update_Disparar INLAB_UPDATE_API u.token
        if not ok do InLab_UpdateFalhar "não foi possível iniciar a consulta."
        ok
    )
)

fn InLab_UpdateEstadoTexto =
(
    local u = InLab_Update
    case u.estado of
    (
        #checando: "Procurando atualização..."
        #disponivel:
            "v" + u.versaoRemota + " disponível (instalada: v" + INLAB_VERSAO + ")" + \
            (if u.ignorada then ", ignorada." else ".")
        #baixando: "Baixando v" + u.versaoRemota + "..."
        #aplicando: "Aplicando v" + u.versaoRemota + "..."
        #erro: "Erro: " + u.msgErro
        default:
            if u.msgErro != "" then u.msgErro
            else if u.versaoRemota == "" then "Versão instalada: v" + INLAB_VERSAO + "."
            else "Você está na versão mais recente (v" + INLAB_VERSAO + ")."
    )
)
