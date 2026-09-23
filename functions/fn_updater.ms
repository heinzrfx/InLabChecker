/*
================================================================================
 functions\fn_updater.ms — updater: checagem (issue #12) e download, troca
 de pastas e rollback (issue #13) — sub-issues do épico #8
--------------------------------------------------------------------------------
 Parte 1 (23/09/2026, #12): consulta /releases/latest do GitHub em segundo
 plano e termina em #disponivel — loga e acende a pastilha do header.
 Parte 2 (23/09/2026, #13): só no clique do artista, baixa o zip, valida o
 pacote, troca a pasta do plugin e recarrega, com rollback. Ver "PARTE 2"
 mais abaixo neste cabeçalho. Spec:
 docs\superpowers\specs\2026-09-22-updater-design.md.

 PÚBLICO
   InLab_UpdateChecar silencioso:false → true se disparou a consulta
   InLab_UpdateBaixarEAplicar()        → true se disparou o download
   InLab_UpdateCancelar()              → cancela o download em curso
   InLab_UpdateReverter()              → troca a instalação pelo .bak
   InLab_UpdateVersaoBak()             → versão guardada no .bak, ou undefined
   InLab_UpdateEstadoTexto()           → frase do estado, para a seção (#14)
   InLab_Update                        → estado (struct UpdateEstado)

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

 PARTE 2 — DOWNLOAD, TROCA E ROLLBACK (23/09/2026, issue #13)
 Fluxo, só no clique (InLab_UpdateBaixarEAplicar):
   1. DownloadFileAsync do zip para (getDir #temp)\inlab_update\v<X>.zip. O
      progresso vai para a pastilha (#baixando pct) e para o log a cada 25%.
      Mesmo WebClient, mesma thread principal no callback (ver acima): o Max
      continua utilizável durante o download.
   2. Tamanho baixado contra o `size` do asset — pega download truncado.
   3. Extrai com ZipFile depois de Assembly.LoadWithPartialName
      "System.IO.Compression.FileSystem". Assembly.Load com nome forte FALHOU
      na sondagem de 22/09; LoadWithPartialName funcionou. NÃO TROCAR.
   4. Valida o pacote extraído contra o manifesto DO PRÓPRIO PACOTE (os @"..."
      de INLAB_MODULOS lidos do InLabChecker.ms novo) e confere que o
      core\versao.ms dele diz a versão da tag. Falhou: aborta com a lista do
      que falta; a instalação não foi tocada.
   5. Troca: .bak anterior → .bak.old; INLAB_ROOT → InLabChecker.bak;
      extraído → INLAB_ROOT.
   6. Recarrega pelo fileIn do InLabChecker.ms NOVO — não por
      InLab_RecarregarPlugin(), que percorre o INLAB_MODULOS EM MEMÓRIA (o da
      versão velha) e nunca carregaria um módulo que a versão nova acrescentou.
      Confere que INLAB_VERSAO carregado = versão da tag.
   Sucesso: apaga o .bak.old. O .bak SOBREVIVE ao sucesso e só sai na próxima
   atualização bem-sucedida — o artista pode descobrir no meio do turno que a
   versão nova quebrou o fluxo dele, e InLab_UpdateReverter volta sem fechar
   o Max.
   Falha em 5 ou 6: rollback — apaga o que entrou, .bak volta a ser
   INLAB_ROOT, .bak.old volta a ser .bak, recarrega a versão anterior pelo
   fileIn do entry point dela, loga #err com a causa.

 EXTRAI AO LADO DE INLAB_ROOT (InLabChecker.novo), NÃO NO TEMP: a troca é
 Directory.Move, que só renomeia no MESMO volume. %TEMP% pode estar em outro
 disco; a pasta vizinha nunca está. Desvio consciente da spec, que extraía em
 temp\inlab_update\v<X>\ — o zip continua indo para o temp.

 PARECE PERIGOSO E NÃO É: o passo 5 renomeia a pasta que contém ESTE arquivo,
 enquanto ele executa. É seguro: o MaxScript compilou o código na carga e não
 relê o .ms. Depois do passo 6 as globais (InLab_Update, InLab_Log...)
 apontam para as definições NOVAS, e o resto desta função, ainda o código
 velho em memória, fala com elas pelo nome global. Não "consertar" isto
 copiando o updater para outro lugar antes de trocar.

 PROTEÇÃO DO CHECKOUT DE DESENVOLVIMENTO: se INLAB_ROOT tem .git, aplicar e
 reverter se recusam — trocariam o repositório pelo pacote da release.

 PONTOS DE TROCA PARA TESTE: InLab_Update_Recarregar (o fileIn do entry point)
 e a raiz passada a InLab_UpdateAplicarZip (tests\test_updater_aplicar.ms usa
 um INLAB_ROOT falso no temp e zips montados na hora; não toca a rede).

 PONTO DE TROCA PARA TESTE: InLab_Update_Disparar é global e o teste a troca
 por um stub, para nunca tocar a rede (tests\test_updater_checagem.ms).
================================================================================
*/

global InLab_Header_Estado            -- ui\header.ms, carregado depois
global InLab_Update_Disparar, InLab_UpdatePintarHeader
global InLab_Update_Recarregar
global InLab_Update_WC                -- WebClient do download em curso (Cancelar)

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
    ignorada = false,       -- versaoRemota é a versaoIgnorada do ini
    pct = 0,                -- progresso do download (#13)
    aviso = ""              -- frase de sucesso ("Atualizado para vX.") (#13)
)

global InLab_Update
(
    local novo = UpdateEstado()
    if InLab_Update != undefined do
    (
        for campo in #(#estado, #versaoRemota, #urlZip, #tamanhoZip, #notasUrl, #msgErro, #token, #silencioso, #ignorada, #pct, #aviso) do
            try ( setProperty novo campo (getProperty InLab_Update campo) ) catch ()
        novo.token += 1
        if novo.estado == #checando do novo.estado = #ocioso
        -- Download em voo: a resposta vai ser descartada pelo token, então
        -- cancela e volta para #disponivel. #aplicando NÃO muda: é o reload
        -- que a própria troca faz (passo 6), e quem aplica acerta o estado.
        if novo.estado == #baixando do
        (
            novo.estado = #disponivel
            if InLab_Update_WC != undefined do try ( InLab_Update_WC.CancelAsync() ) catch ()
        )
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
            #baixando: InLab_Header_Estado #baixando pct:u.pct
            #aplicando: InLab_Header_Estado #baixando pct:100
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
        u.aviso = ""
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
            if u.aviso != "" then u.aviso
            else if u.msgErro != "" then u.msgErro
            else if u.versaoRemota == "" then "Versão instalada: v" + INLAB_VERSAO + "."
            else "Você está na versão mais recente (v" + INLAB_VERSAO + ")."
    )
)

--------------------------------------------------------------------------------
-- PARTE 2 (issue #13): DOWNLOAD, VALIDAÇÃO, TROCA E ROLLBACK
-- Ver o cabeçalho. As funções "Em"/"Zip"/"Trocar" recebem a raiz como
-- parâmetro e devolvem "" (ok) ou a causa, sem mexer em InLab_Update: são o
-- núcleo síncrono que o teste exercita com um INLAB_ROOT falso.
--------------------------------------------------------------------------------

global InLab_Update_UltimoMarco = 0   -- último múltiplo de 25% logado

fn InLab_UpdateSemBarra p =
(
    if p.count > 0 and (p[p.count] == "\\" or p[p.count] == "/") then substring p 1 (p.count - 1) else p
)

-- #(instalação, .bak, .bak.old, .novo), sem barra no fim
fn InLab_UpdateCaminhos raiz =
(
    local r = InLab_UpdateSemBarra raiz
    #(r, r + ".bak", r + ".bak.old", r + ".novo")
)

fn InLab_UpdateDirExiste p = (dotNetClass "System.IO.Directory").Exists p
fn InLab_UpdateApagarDir p = ( if InLab_UpdateDirExiste p do (dotNetClass "System.IO.Directory").Delete p true )
fn InLab_UpdateMover de para = (dotNetClass "System.IO.Directory").Move de para
fn InLab_UpdateEhCheckout raiz = InLab_UpdateDirExiste ((InLab_UpdateSemBarra raiz) + "\\.git")
fn InLab_UpdateArqZip versao = (getDir #temp) + "\\inlab_update\\v" + versao + ".zip"

-- INLAB_VERSAO de uma pasta, lida do texto de core\versao.ms (sem executar).
fn InLab_UpdateLerVersao dir =
(
    local arq = (InLab_UpdateSemBarra dir) + "\\core\\versao.ms"
    local v = undefined
    if doesFileExist arq do
    (
        local txt = (dotNetClass "System.IO.File").ReadAllText arq
        local m = (dotNetClass "System.Text.RegularExpressions.Regex").Match txt "global\\s+INLAB_VERSAO\\s*=\\s*\"([^\"]+)\""
        if m.Success do v = (m.Groups.Item 1).Value
    )
    v
)

-- Os @"..." de INLAB_MODULOS de um InLabChecker.ms, lidos como texto. Corta o
-- comentário de cada linha antes: os comentários do manifesto têm parênteses,
-- e um ")" de comentário fecharia a lista cedo demais.
fn InLab_UpdateLerManifesto arqEntry =
(
    local mods = #()
    local rx = dotNetObject "System.Text.RegularExpressions.Regex" "@\"([^\"]+)\""
    local dentro = false
    local fim = false
    for l in ((dotNetClass "System.IO.File").ReadAllLines arqEntry) while not fim do
    (
        local c = findString l "--"
        local codigo = trimLeft (if c != undefined then substring l 1 (c - 1) else l)
        if not dentro then
        (
            if matchPattern codigo pattern:"*INLAB_MODULOS*=*#(*" do dentro = true
        )
        else if codigo.count > 0 and codigo[1] == ")" then fim = true
        else
        (
            local ms = rx.Matches codigo
            for k = 0 to ms.Count - 1 do append mods ((ms.Item k).Groups.Item 1).Value
        )
    )
    mods
)

-- Pacote extraído: tem entry point, todo módulo do PRÓPRIO manifesto e a
-- versão da tag? "" ou a causa. versaoEsperada undefined = não confere versão.
fn InLab_UpdateValidarPacote dir versaoEsperada =
(
    local d = InLab_UpdateSemBarra dir
    local entry = d + "\\InLabChecker.ms"
    if not (doesFileExist entry) then "o pacote não tem InLabChecker.ms na raiz."
    else
    (
        local mods = InLab_UpdateLerManifesto entry
        if mods.count == 0 then "não achei INLAB_MODULOS no InLabChecker.ms do pacote."
        else
        (
            local faltam = for m in mods where not (doesFileExist (d + "\\" + m)) collect m
            if faltam.count > 0 then
            (
                local lista = ""
                for f in faltam do lista += (if lista == "" then "" else ", ") + f
                "pacote incompleto, falta(m) " + faltam.count as string + " módulo(s): " + lista + "."
            )
            else
            (
                local v = InLab_UpdateLerVersao d
                if v == undefined then "o pacote não tem INLAB_VERSAO em core\\versao.ms."
                else if versaoEsperada != undefined and (InLab_CompararVersao v versaoEsperada) != 0 then
                    "o pacote diz v" + v + ", mas a release é v" + versaoEsperada + "."
                else ""
            )
        )
    )
)

-- Carrega o plugin pelo entry point da raiz (redefine INLAB_MODULOS, carrega,
-- abre o painel). Devolve a INLAB_VERSAO carregada, ou undefined. Trocada por
-- stub no teste.
fn InLab_Update_Recarregar raiz =
(
    local entry = (InLab_UpdateSemBarra raiz) + "\\InLabChecker.ms"
    try
    (
        fileIn entry
        INLAB_VERSAO
    )
    catch
    (
        InLab_Log ("Atualização: falha ao carregar " + entry + " (" + getCurrentException() + ").") tipo:#err
        undefined
    )
)

-- Passos 5 e 6 com rollback. dirNovo = pacote extraído e validado, vizinho da
-- raiz. "" ou a causa (e, com causa, a versão anterior já foi restaurada).
fn InLab_UpdateTrocar raiz dirNovo versaoEsperada =
(
    local c = InLab_UpdateCaminhos raiz
    local passo = ""
    local causa = ""
    local bakParaOld = false
    local raizParaBak = false
    try
    (
        passo = "guardar o .bak anterior"
        InLab_UpdateApagarDir c[3]
        if InLab_UpdateDirExiste c[2] do ( InLab_UpdateMover c[2] c[3]; bakParaOld = true )
        passo = "renomear a instalação para .bak"
        InLab_UpdateMover c[1] c[2]
        raizParaBak = true
        passo = "pôr a versão nova no lugar"
        InLab_UpdateMover dirNovo c[1]
        passo = "carregar a versão nova"
        local v = InLab_Update_Recarregar c[1]
        if v == undefined then causa = "a versão nova não carregou."
        else if versaoEsperada != undefined and (InLab_CompararVersao v versaoEsperada) != 0 do
            causa = "carregou v" + v + " em vez de v" + versaoEsperada + "."
    )
    catch
        causa = "falha ao " + passo + " (" + getCurrentException() + ")."

    if causa == "" then
    (
        try ( InLab_UpdateApagarDir c[3] )
        catch ( InLab_Log ("Atualização: não apagou " + c[3] + " (" + getCurrentException() + "). Pode apagar à mão.") tipo:#warn )
    )
    else
    (
        -- ROLLBACK: desfaz só o que foi feito, na ordem inversa.
        InLab_Log ("Atualização: " + causa + " Voltando para a versão anterior...") tipo:#err
        try
        (
            if raizParaBak do
            (
                InLab_UpdateApagarDir c[1]
                InLab_UpdateMover c[2] c[1]
            )
            if bakParaOld do InLab_UpdateMover c[3] c[2]
            local v = InLab_Update_Recarregar c[1]
            if v != undefined then
                InLab_Log ("Atualização: versão anterior restaurada (v" + v + ").") tipo:#warn
            else
                InLab_Log ("Atualização: os arquivos da versão anterior voltaram para " + c[1] + ", mas ela não carregou. Feche e abra o Max.") tipo:#err
        )
        catch
            InLab_Log ("Atualização: O ROLLBACK FALHOU (" + getCurrentException() + "). Confira " + c[1] + " e " + c[2] + "; se preciso, reinstale pelo zip da release.") tipo:#err
    )
    causa
)

-- Passos 2 a 6 sobre um zip já baixado. "" ou a causa.
fn InLab_UpdateAplicarZip arqZip raiz versao tamanho =
(
    local c = InLab_UpdateCaminhos raiz
    if InLab_UpdateEhCheckout raiz then
        "a pasta do plugin é um checkout do git (" + c[1] + "); a atualização só roda numa instalação."
    else if not (doesFileExist arqZip) then "o zip baixado não foi encontrado."
    else
    (
        local tam = ((dotNetObject "System.IO.FileInfo" arqZip).Length) as integer
        if tamanho != undefined and tamanho > 0 and tam != tamanho then
            "download incompleto: " + tam as string + " de " + tamanho as string + " bytes."
        else
        (
            local causa = ""
            try
            (
                InLab_UpdateApagarDir c[4]
                (dotNetClass "System.Reflection.Assembly").LoadWithPartialName "System.IO.Compression.FileSystem"
                (dotNetClass "System.IO.Compression.ZipFile").ExtractToDirectory arqZip c[4]
            )
            catch ( causa = "falha ao extrair o zip (" + getCurrentException() + ")." )
            if causa == "" do causa = InLab_UpdateValidarPacote c[4] versao
            if causa == "" do causa = InLab_UpdateTrocar raiz c[4] versao
            -- Sobra quando abortou antes de mover (ou depois de um rollback).
            try ( InLab_UpdateApagarDir c[4] )
            catch ( InLab_Log ("Atualização: não apagou " + c[4] + " (" + getCurrentException() + ").") tipo:#warn )
            causa
        )
    )
)

fn InLab_UpdateConcluir causa versao =
(
    -- InLab_Update aqui já pode ser a instância criada pela versão nova.
    local u = InLab_Update
    if causa == "" then
    (
        u.estado = #ocioso
        u.msgErro = ""
        u.ignorada = false
        u.aviso = "Atualizado para v" + versao + "."
        InLab_Log ("Atualização: v" + versao + " instalada. A versão anterior ficou guardada (InLabChecker.bak) e dá para voltar sem fechar o Max.") tipo:#ok
        InLab_UpdatePintarHeader()
    )
    else
    (
        u.silencioso = false
        InLab_UpdateFalhar ("não aplicou a v" + versao + ": " + causa)
    )
)

fn InLab_UpdateAplicarBaixado arqZip =
(
    local u = InLab_Update
    local versao = u.versaoRemota
    u.estado = #aplicando
    u.pct = 100
    InLab_UpdatePintarHeader()
    InLab_Log ("Atualização: aplicando v" + versao + "...") tipo:#info
    local causa = InLab_UpdateAplicarZip arqZip INLAB_ROOT versao u.tamanhoZip
    try ( (dotNetClass "System.IO.File").Delete arqZip )
    catch ( InLab_Log ("Atualização: não apagou " + arqZip + " (" + getCurrentException() + ").") tipo:#warn )
    InLab_UpdateConcluir causa versao
)

fn InLab_Update_OnProgresso sender e =
(
    try
    (
        local u = InLab_Update
        if (e.UserState as integer) == u.token and u.estado == #baixando do
        (
            u.pct = e.ProgressPercentage
            InLab_UpdatePintarHeader()
            local marco = (u.pct / 25) * 25
            if marco > InLab_Update_UltimoMarco and marco < 100 do
            (
                InLab_Update_UltimoMarco = marco
                InLab_Log ("Atualização: baixando v" + u.versaoRemota + "... " + marco as string + "%") tipo:#info
            )
        )
    )
    catch
        InLab_Log ("Atualização: falha no progresso do download (" + getCurrentException() + ").") tipo:#warn
)

fn InLab_Update_OnBaixado sender e =
(
    try
    (
        local tok = try ( e.UserState as integer ) catch ( undefined )
        try ( sender.Dispose() ) catch ()
        if tok == InLab_Update.token do
        (
            InLab_Update_WC = undefined
            local u = InLab_Update
            local arq = InLab_UpdateArqZip u.versaoRemota
            if e.Cancelled then
            (
                u.estado = #disponivel
                u.pct = 0
                try ( (dotNetClass "System.IO.File").Delete arq ) catch ()
                InLab_Log "Atualização: download cancelado. Nada foi alterado." tipo:#info
                InLab_UpdatePintarHeader()
            )
            else if e.Error != undefined then
            (
                u.silencioso = false
                try ( (dotNetClass "System.IO.File").Delete arq ) catch ()
                InLab_UpdateFalhar ("o download da v" + u.versaoRemota + " falhou (" + e.Error.Message + ").")
            )
            else InLab_UpdateAplicarBaixado arq
        )
    )
    catch
        InLab_Log ("Atualização: falha ao tratar o fim do download (" + getCurrentException() + ").") tipo:#err
)

fn InLab_UpdateBaixarEAplicar =
(
    local u = InLab_Update
    if not (u.estado == #disponivel or (u.estado == #erro and u.urlZip != "")) then
    (
        InLab_Log ("Atualização: nada para aplicar (estado " + u.estado as string + ").") tipo:#warn
        false
    )
    else if InLab_UpdateEhCheckout INLAB_ROOT then
    (
        InLab_Log ("Atualização: a pasta do plugin é um checkout do git (" + INLAB_ROOT + "); atualize pelo git. A atualização só roda numa instalação.") tipo:#err
        false
    )
    else
    (
        u.token += 1
        local tok = u.token
        u.estado = #baixando
        u.pct = 0
        u.msgErro = ""
        u.aviso = ""
        u.silencioso = false
        InLab_Update_UltimoMarco = 0
        local arq = InLab_UpdateArqZip u.versaoRemota
        local ok = false
        try
        (
            makeDir (getFilenamePath arq) all:true
            if doesFileExist arq do (dotNetClass "System.IO.File").Delete arq
            (dotNetClass "System.Net.ServicePointManager").SecurityProtocol = (dotNetClass "System.Net.SecurityProtocolType").Tls12
            local wc = dotNetObject "System.Net.WebClient"
            wc.Headers.Add "User-Agent" ("InLabChecker/" + INLAB_VERSAO)
            dotnet.addEventHandler wc "DownloadProgressChanged" InLab_Update_OnProgresso
            dotnet.addEventHandler wc "DownloadFileCompleted" InLab_Update_OnBaixado
            dotnet.setLifetimeControl wc #dotnet
            InLab_Update_WC = wc
            wc.DownloadFileAsync (dotNetObject "System.Uri" u.urlZip) arq tok
            ok = true
            InLab_Log ("Atualização: baixando v" + u.versaoRemota + " (" + ((u.tamanhoZip / 1024) as string) + " KB)...") tipo:#info
            InLab_UpdatePintarHeader()
        )
        catch
            InLab_UpdateFalhar ("não foi possível iniciar o download (" + getCurrentException() + ").")
        ok
    )
)

fn InLab_UpdateCancelar =
(
    if InLab_Update.estado == #baixando and InLab_Update_WC != undefined then
    (
        try
        (
            InLab_Update_WC.CancelAsync()
            InLab_Log "Atualização: cancelando o download..." tipo:#info
            true
        )
        catch
        (
            InLab_Log ("Atualização: não conseguiu cancelar (" + getCurrentException() + ").") tipo:#warn
            false
        )
    )
    else false
)

fn InLab_UpdateVersaoBak =
(
    local c = InLab_UpdateCaminhos INLAB_ROOT
    if InLab_UpdateDirExiste c[2] then InLab_UpdateLerVersao c[2] else undefined
)

-- Troca simétrica instalação <-> .bak e recarrega. "" ou a causa.
fn InLab_UpdateReverterEm raiz =
(
    local c = InLab_UpdateCaminhos raiz
    local troca = c[1] + ".troca"
    if InLab_UpdateEhCheckout raiz then "a pasta do plugin é um checkout do git; volte de versão pelo git."
    else if not (InLab_UpdateDirExiste c[2]) then "não há versão anterior guardada (.bak)."
    else
    (
        local causa = InLab_UpdateValidarPacote c[2] undefined
        if causa != "" then "o .bak não está íntegro: " + causa
        else
        (
            local feito = 0
            try
            (
                InLab_UpdateApagarDir troca
                InLab_UpdateMover c[1] troca
                feito = 1
                InLab_UpdateMover c[2] c[1]
                feito = 2
                InLab_UpdateMover troca c[2]
                feito = 3
                if (InLab_Update_Recarregar c[1]) == undefined do causa = "a versão anterior não carregou."
            )
            catch ( causa = "falha ao trocar as pastas (" + getCurrentException() + ")." )

            if causa != "" do
            (
                InLab_Log ("Atualização: " + causa + " Desfazendo a volta...") tipo:#err
                try
                (
                    if feito >= 3 do InLab_UpdateMover c[2] troca
                    if feito >= 2 do InLab_UpdateMover c[1] c[2]
                    if feito >= 1 do InLab_UpdateMover troca c[1]
                    InLab_Update_Recarregar c[1]
                )
                catch
                    InLab_Log ("Atualização: NÃO DESFEZ (" + getCurrentException() + "). Confira " + c[1] + ", " + c[2] + " e " + troca + ".") tipo:#err
            )
            causa
        )
    )
)

fn InLab_UpdateReverter =
(
    local u = InLab_Update
    if u.estado == #baixando or u.estado == #aplicando then
    (
        InLab_Log "Atualização: espere a atualização em andamento terminar." tipo:#warn
        false
    )
    else
    (
        local de = INLAB_VERSAO
        local para = InLab_UpdateVersaoBak()
        local causa = InLab_UpdateReverterEm INLAB_ROOT
        u = InLab_Update   -- o reload recria a instância
        if causa == "" then
        (
            u.aviso = "Voltou para v" + INLAB_VERSAO + "."
            u.msgErro = ""
            u.estado = if u.versaoRemota != "" and (InLab_CompararVersao INLAB_VERSAO u.versaoRemota) == -1 then #disponivel else #ocioso
            InLab_Log ("Atualização: voltou da v" + (de as string) + " para a v" + (para as string) + ". A v" + (de as string) + " ficou no .bak.") tipo:#ok
            InLab_UpdatePintarHeader()
            true
        )
        else
        (
            u.silencioso = false
            InLab_UpdateFalhar ("não voltou de versão: " + causa)
            false
        )
    )
)
