/*
 tests\test_updater_checagem.ms — teste automatico da checagem do updater
 (functions\fn_updater.ms, issue #12)
 NAO TOCA A REDE: InLab_Update_Disparar e trocado por um stub e o callback
 (InLab_UpdateProcessar) e chamado direto com o JSON REAL da release v0.12
 (tests\fixtures\release_latest_v0.12.json), com a tag trocada por texto.
 A pastilha do header tambem vira stub, para nao pintar o painel aberto.
 Mexe nas chaves reais autoCheck/ultimaChecagem/versaoIgnorada do ini e
 devolve os valores de antes no final.
 RODAR NUMA CENA QUALQUER: nao cria nem apaga objeto de cena.
 Resultado: <pasta temp do Max>\inlab_test_updater_checagem.txt
*/
global InLab_Log, INLAB_VERSAO, InLab_CompararVersao
global InLab_PrefLer, InLab_PrefGravar, InLab_PrefApagar
global InLab_ParseJSON, InLab_JSON_Obter
global InLab_Update, InLab_UpdateChecar, InLab_UpdateProcessar, InLab_UpdateEstadoTexto
global InLab_Update_Disparar, InLab_Header_Estado, InLab_UpdateAgora
global InLab_UpdateIgnorar, InLab_UpdateTamanhoTexto, InLab_UpdateLog, INLAB_UPDATE_HIST
global InLab_UpdateTextoDoLog, InLab_UpdateExecutar, InLab_UpdateUltimaChecagemTexto
global InLab_SecUpdate_Atualizar
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS, INLAB_TESTE_DISPAROS, INLAB_TESTE_HEADER
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_updater_checagem.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    local headerOriginal = InLab_Header_Estado
    local disparoOriginal = undefined
    local updateOriginal = InLab_Update
    -- A secao Atualizacao do painel aberto repintaria com o estado do teste.
    local secaoOriginal = InLab_SecUpdate_Atualizar
    InLab_SecUpdate_Atualizar = undefined
    local histOriginal = INLAB_UPDATE_HIST
    local chaves = #("autoCheck", "ultimaChecagem", "versaoIgnorada")
    local ausente = "__ausente__"
    local prefsAntes = #()

    try
    (
        fileIn (raiz + @"core\versao.ms")
        fileIn (raiz + @"core\prefs.ms")
        fileIn (raiz + @"functions\fn_json.ms")
        -- Logger e stubs DEPOIS dos fileIn (o fileIn redefiniria por cima).
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        prefsAntes = for c in chaves collect (InLab_PrefLer c ausente)
        fileIn (raiz + @"functions\fn_updater.ms")
        disparoOriginal = InLab_Update_Disparar

        INLAB_TESTE_DISPAROS = #()
        INLAB_TESTE_HEADER = #()
        InLab_Update_Disparar = fn _stubDisparar url tok = ( append INLAB_TESTE_DISPAROS #(url, tok); true )
        InLab_Header_Estado = fn _stubHeader estado versao:unsupplied pct:0 = ( append INLAB_TESTE_HEADER #(estado, versao); true )
        InLab_PrefApagar "versaoIgnorada"

        local fixture = (dotNetClass "System.IO.File").ReadAllText (raiz + @"tests\fixtures\release_latest_v0.12.json")
        fn comTag json tag = substituteString json "\"tag_name\": \"v0.12\"" ("\"tag_name\": \"" + tag + "\"")
        local jsonMaior = comTag fixture "v99.0"
        local jsonIgual = comTag fixture ("v" + INLAB_VERSAO)

        -- Estado limpo e um token em voo, como depois de um InLab_UpdateChecar.
        fn novaConsulta silencioso:false =
        (
            InLab_Update.token += 1
            InLab_Update.silencioso = silencioso
            InLab_Update.estado = #checando
            InLab_Update.ignorada = false
            InLab_Update.versaoRemota = ""
            InLab_Update.urlZip = ""
            InLab_Update.tamanhoZip = 0
            InLab_Update.msgErro = ""
            INLAB_TESTE_HEADER = #()
            InLab_Update.token
        )

        -- 1. FIXTURE
        checar "Fixture tem a tag v0.12" (matchPattern fixture pattern:"*\"tag_name\": \"v0.12\"*")
        checar "Troca de tag funcionou" (matchPattern jsonMaior pattern:"*\"tag_name\": \"v99.0\"*")

        -- 2. TAG MAIOR -> #disponivel
        local tok = novaConsulta()
        checar "Processar aceita o token atual" ((InLab_UpdateProcessar tok jsonMaior) == true)
        checar "Tag maior vira #disponivel" (InLab_Update.estado == #disponivel)
        checar "versaoRemota sem o v" (InLab_Update.versaoRemota == "99.0")
        checar "urlZip do asset .zip" (InLab_Update.urlZip == "https://github.com/heinzrfx/InLabChecker/releases/download/v0.12/InLabChecker-v0.12.zip")
        checar "tamanhoZip do asset" (InLab_Update.tamanhoZip == 123193)
        checar "notasUrl da release" (InLab_Update.notasUrl == "https://github.com/heinzrfx/InLabChecker/releases/tag/v0.12")
        local ultHeader = INLAB_TESTE_HEADER[INLAB_TESTE_HEADER.count]
        checar "Pastilha acende #disponivel com a versao nova" (ultHeader[1] == #disponivel and ultHeader[2] == "99.0")
        checar "Texto do estado cita a versao" (matchPattern (InLab_UpdateEstadoTexto()) pattern:"v99.0 dispon*")

        -- 3. TAG IGUAL -> #ocioso
        tok = novaConsulta()
        InLab_UpdateProcessar tok jsonIgual
        checar "Tag igual a INLAB_VERSAO vira #ocioso" (InLab_Update.estado == #ocioso)
        ultHeader = INLAB_TESTE_HEADER[INLAB_TESTE_HEADER.count]
        checar "Pastilha em #ocioso com a versao instalada" (ultHeader[1] == #ocioso and ultHeader[2] == INLAB_VERSAO)

        -- 4. VERSAO IGNORADA
        InLab_PrefGravar "versaoIgnorada" "99.0"
        tok = novaConsulta()
        InLab_UpdateProcessar tok jsonMaior
        checar "Ignorada: estado continua #disponivel" (InLab_Update.estado == #disponivel)
        checar "Ignorada: marcada como ignorada" (InLab_Update.ignorada == true)
        local acendeu = false
        for h in INLAB_TESTE_HEADER where h[1] == #disponivel do acendeu = true
        checar "Ignorada: pastilha NAO acende" (not acendeu)
        InLab_PrefApagar "versaoIgnorada"

        -- 5. TOKEN DIVERGENTE
        tok = novaConsulta()
        local antes = InLab_Update.estado
        checar "Token velho e descartado" ((InLab_UpdateProcessar (tok - 1) jsonMaior) == false)
        checar "Token velho nao altera o estado" (InLab_Update.estado == antes and InLab_Update.versaoRemota == "")
        checar "Token undefined e descartado" ((InLab_UpdateProcessar undefined jsonMaior) == false)

        -- 6. RELOAD DURANTE O VOO
        tok = novaConsulta()
        fileIn (raiz + @"functions\fn_updater.ms")
        InLab_Update_Disparar = fn _stubDisparar url tok = ( append INLAB_TESTE_DISPAROS #(url, tok); true )
        checar "Reload sobe o token" (InLab_Update.token == tok + 1)
        checar "Reload tira do #checando" (InLab_Update.estado == #ocioso)
        checar "Resposta de antes do reload e descartada" ((InLab_UpdateProcessar tok jsonMaior) == false)

        -- 7. INTERVALO DE 4 H
        local agora = InLab_UpdateAgora()
        InLab_PrefGravar "ultimaChecagem" ((agora - 3600) as string)
        INLAB_TESTE_DISPAROS = #()
        checar "1 h atras: silenciosa NAO dispara" ((InLab_UpdateChecar silencioso:true) == false and INLAB_TESTE_DISPAROS.count == 0)
        checar "1 h atras: manual dispara" ((InLab_UpdateChecar silencioso:false) == true and INLAB_TESTE_DISPAROS.count == 1)
        InLab_PrefGravar "ultimaChecagem" ((agora - 5 * 3600) as string)
        INLAB_TESTE_DISPAROS = #()
        checar "5 h atras: silenciosa dispara" ((InLab_UpdateChecar silencioso:true) == true and INLAB_TESTE_DISPAROS.count == 1)
        checar "Disparo leva o token atual" (INLAB_TESTE_DISPAROS[1][2] == InLab_Update.token)
        checar "Disparo vai para /releases/latest" (matchPattern INLAB_TESTE_DISPAROS[1][1] pattern:"*/repos/heinzrfx/InLabChecker/releases/latest")
        checar "Disparo grava ultimaChecagem" (((InLab_PrefLer "ultimaChecagem" "0") as integer) >= agora)
        InLab_PrefApagar "ultimaChecagem"
        INLAB_TESTE_DISPAROS = #()
        checar "Sem ultimaChecagem: silenciosa dispara" ((InLab_UpdateChecar silencioso:true) == true)

        -- 8. ERROS
        tok = novaConsulta()
        InLab_UpdateProcessar tok (substituteString fixture ".zip\"" ".txt\"")
        checar "Sem asset .zip vira #erro" (InLab_Update.estado == #erro)
        checar "Sem asset .zip preenche msgErro" (matchPattern InLab_Update.msgErro pattern:"*.zip*")

        tok = novaConsulta()
        InLab_UpdateProcessar tok "{isto nao e json"
        checar "JSON malformado vira #erro" (InLab_Update.estado == #erro and InLab_Update.msgErro != "")

        tok = novaConsulta()
        InLab_UpdateProcessar tok undefined status:404 erro:"(404) Not Found"
        checar "404 nao e erro: fica #ocioso" (InLab_Update.estado == #ocioso)
        checar "404 explica que nao ha release" (matchPattern InLab_Update.msgErro pattern:"Nenhuma release*")

        tok = novaConsulta()
        InLab_UpdateProcessar tok undefined status:403 erro:"(403) Forbidden"
        checar "403 vira #erro com mensagem de limite" (InLab_Update.estado == #erro and matchPattern InLab_Update.msgErro pattern:"*limite*")

        tok = novaConsulta silencioso:true
        InLab_UpdateProcessar tok undefined status:0 erro:"The remote name could not be resolved"
        checar "Sem rede vira #erro" (InLab_Update.estado == #erro)
        ultHeader = INLAB_TESTE_HEADER[INLAB_TESTE_HEADER.count]
        checar "Sem rede no silencioso: pastilha fica quieta" (ultHeader[1] == #ocioso)

        tok = novaConsulta silencioso:false
        InLab_UpdateProcessar tok undefined status:0 erro:"The remote name could not be resolved"
        ultHeader = INLAB_TESTE_HEADER[INLAB_TESTE_HEADER.count]
        checar "Sem rede no manual: pastilha em #erro" (ultHeader[1] == #erro)

        -- 9. APOIO DA SECAO ATUALIZACAO (#14)
        tok = novaConsulta()
        InLab_UpdateProcessar tok jsonMaior
        checar "publicadaEm vem de published_at (dd/mm/aaaa)" (InLab_Update.publicadaEm == "23/09/2026")
        checar "Ignorar em #disponivel devolve true" ((InLab_UpdateIgnorar()) == true)
        checar "Ignorar grava versaoIgnorada no ini" ((InLab_PrefLer "versaoIgnorada" "") == "99.0")
        checar "Ignorar marca ignorada e apaga a pastilha" (InLab_Update.ignorada and INLAB_TESTE_HEADER[INLAB_TESTE_HEADER.count][1] == #ocioso)
        InLab_PrefApagar "versaoIgnorada"
        InLab_Update.estado = #ocioso
        checar "Ignorar fora de #disponivel devolve false" ((InLab_UpdateIgnorar()) == false)
        checar "Tamanho em KB" ((InLab_UpdateTamanhoTexto 123193) == "120 KB")
        checar "Tamanho em MB com virgula" ((InLab_UpdateTamanhoTexto 1363148) == "1,3 MB")
        checar "Tamanho zero vira vazio" ((InLab_UpdateTamanhoTexto 0) == "")
        for i = 1 to 15 do InLab_UpdateLog ("linha " + i as string)
        checar "Historico guarda so as 10 ultimas" (INLAB_UPDATE_HIST.count == 10 and matchPattern INLAB_UPDATE_HIST[10] pattern:"*linha 15")
        checar "Texto do log leva versao e historico" (matchPattern (InLab_UpdateTextoDoLog()) pattern:("*v" + INLAB_VERSAO + "*linha 15*"))
        checar "Acao desconhecida devolve false" ((InLab_UpdateExecutar #banana) == false)
        INLAB_TESTE_DISPAROS = #()
        checar "Acao #procurar dispara a checagem manual" ((InLab_UpdateExecutar #procurar) == true and INLAB_TESTE_DISPAROS.count == 1)
        checar "Ultima checagem vira texto dd/MM HH:mm" (matchPattern (InLab_UpdateUltimaChecagemTexto()) pattern:"??/?? ??:??")
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("FAIL  EXCECAO: " + getCurrentException())
    )

    -- LIMPEZA: ini como estava, stubs desfeitos
    for i = 1 to chaves.count do
        try
        (
            if prefsAntes.count >= i and prefsAntes[i] != ausente then InLab_PrefGravar chaves[i] prefsAntes[i]
            else InLab_PrefApagar chaves[i]
        ) catch ()
    if disparoOriginal != undefined do InLab_Update_Disparar = disparoOriginal
    InLab_Header_Estado = headerOriginal
    InLab_Log = logOriginal
    if updateOriginal != undefined do InLab_Update = updateOriginal
    INLAB_UPDATE_HIST = if histOriginal != undefined then histOriginal else #()
    InLab_SecUpdate_Atualizar = secaoOriginal

    linha ("---- " + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
)
