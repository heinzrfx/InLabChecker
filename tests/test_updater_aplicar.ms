/*
 tests\test_updater_aplicar.ms — teste automatico da parte 2 do updater
 (functions\fn_updater.ms: download, validacao, troca e rollback — issue #13)
 NAO TOCA A REDE. Monta um INLAB_ROOT FALSO no temp e zips de pacote na hora
 (ZipFile.CreateFromDirectory). InLab_Update_Recarregar vira stub: em vez de
 fileIn do entry point (que abriria o painel), le a versao da pasta — ou
 falha de proposito, para exercitar o rollback.
 RODAR NUMA CENA QUALQUER: nao cria nem apaga objeto de cena. Apaga tudo o
 que criou no temp.
 Resultado: <pasta temp do Max>\inlab_test_updater_aplicar.txt
*/
global InLab_Log, INLAB_VERSAO, INLAB_ROOT, InLab_CompararVersao
global InLab_PrefLer, InLab_PrefGravar, InLab_ParseJSON, InLab_JSON_Obter
global InLab_Update, InLab_Update_Recarregar, InLab_Header_Estado, InLab_Update_WC
global InLab_UpdateLerManifesto, InLab_UpdateLerVersao, InLab_UpdateValidarPacote
global InLab_UpdateAplicarZip, InLab_UpdateReverterEm, InLab_UpdateBaixarEAplicar
global InLab_UpdateCancelar, InLab_Update_OnBaixado, InLab_UpdateEstadoTexto
global InLab_SecUpdate_Atualizar, INLAB_UPDATE_HIST
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS, INLAB_TESTE_RECARGAS, INLAB_TESTE_FALHAR_CARGA
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_updater_aplicar.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local Dir = dotNetClass "System.IO.Directory"
    local Arq = dotNetClass "System.IO.File"
    local base = (getDir #temp) + "\\inlab_teste_aplicar"
    local fakeRaiz = base + "\\scripts\\InLabChecker"     -- sem barra
    local bak = fakeRaiz + ".bak"

    fn escrever caminho texto =
    (
        (dotNetClass "System.IO.Directory").CreateDirectory (getFilenamePath caminho)
        (dotNetClass "System.IO.File").WriteAllText caminho texto
    )
    -- Pacote minimo: entry point com manifesto (comentario com parenteses de
    -- proposito), core\versao.ms e um modulo. semModulo: o manifesto lista
    -- core\b.ms mas o arquivo nao vai.
    fn montarPacote dir versao semModulo:false =
    (
        (dotNetClass "System.IO.Directory").CreateDirectory dir
        local entry = "-- pacote de teste\nglobal INLAB_MODULOS = #(\n    -- comentario (com parenteses) no meio\n    @\"core\\versao.ms\",\n    @\"core\\a.ms\"" + \
            (if semModulo then ",\n    @\"core\\b.ms\"  -- este falta)\n" else "\n") + ")\n"
        escrever (dir + "\\InLabChecker.ms") entry
        escrever (dir + "\\core\\versao.ms") ("global INLAB_VERSAO = \"" + versao + "\"\n")
        escrever (dir + "\\core\\a.ms") ("-- modulo a da v" + versao + "\n")
    )
    fn montarZip versao semModulo:false versaoInterna:unsupplied =
    (
        local src = (getDir #temp) + "\\inlab_teste_aplicar\\src_" + versao
        local zip = (getDir #temp) + "\\inlab_teste_aplicar\\v" + versao + ".zip"
        local vi = if versaoInterna == unsupplied then versao else versaoInterna
        montarPacote src vi semModulo:semModulo
        (dotNetClass "System.Reflection.Assembly").LoadWithPartialName "System.IO.Compression.FileSystem"
        if doesFileExist zip do (dotNetClass "System.IO.File").Delete zip
        (dotNetClass "System.IO.Compression.ZipFile").CreateFromDirectory src zip
        zip
    )
    fn tamanho arq = ((dotNetObject "System.IO.FileInfo" arq).Length) as integer
    fn existeDir p = (dotNetClass "System.IO.Directory").Exists p

    struct ArgsFalso (Cancelled = false, Error = undefined, UserState = 0)

    local logOriginal = InLab_Log
    local headerOriginal = InLab_Header_Estado
    local updateOriginal = InLab_Update
    local secaoOriginal = InLab_SecUpdate_Atualizar
    InLab_SecUpdate_Atualizar = undefined
    local histOriginal = INLAB_UPDATE_HIST
    local rootOriginal = INLAB_ROOT
    local versaoOriginal = INLAB_VERSAO
    local recarregarOriginal = undefined

    try
    (
        fileIn (raiz + @"core\versao.ms")
        fileIn (raiz + @"core\prefs.ms")
        fileIn (raiz + @"functions\fn_json.ms")
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        fileIn (raiz + @"functions\fn_updater.ms")
        recarregarOriginal = InLab_Update_Recarregar
        InLab_Header_Estado = fn _stubHeader estado versao:unsupplied pct:0 = true
        INLAB_TESTE_RECARGAS = #()
        INLAB_TESTE_FALHAR_CARGA = false
        InLab_Update_Recarregar = fn _stubRecarregar r =
        (
            append INLAB_TESTE_RECARGAS r
            if INLAB_TESTE_FALHAR_CARGA then undefined else InLab_UpdateLerVersao r
        )

        if existeDir base do Dir.Delete base true

        -- 1. LEITOR DE MANIFESTO NO ENTRY POINT REAL
        -- Os comentarios do manifesto real tem parenteses: o leitor nao pode
        -- fechar a lista num ")" de comentario.
        local modsReais = InLab_UpdateLerManifesto (raiz + "InLabChecker.ms")
        checar "Manifesto real: leu os @\"...\" de INLAB_MODULOS" (modsReais.count > 30)
        checar "Manifesto real: 1o e core\\versao.ms" (modsReais[1] == @"core\versao.ms")
        checar "Manifesto real: ultimo e ui\\rollout_main.ms" (modsReais[modsReais.count] == @"ui\rollout_main.ms")
        checar "Pacote real (o repo) passa na validacao" ((InLab_UpdateValidarPacote raiz INLAB_VERSAO) == "")

        -- 2. INSTALACAO FALSA v1.0
        montarPacote fakeRaiz "1.0"
        checar "Instalacao falsa em v1.0" ((InLab_UpdateLerVersao fakeRaiz) == "1.0")

        -- 3. ZIP SEM UM MODULO: aborta sem tocar em nada
        local zipInc = montarZip "2.0" semModulo:true
        local causa = InLab_UpdateAplicarZip zipInc fakeRaiz "2.0" (tamanho zipInc)
        checar "Sem modulo: aborta" (causa != "")
        checar "Sem modulo: msgErro nomeia o arquivo" (matchPattern causa pattern:"*core\\b.ms*")
        checar "Sem modulo: instalacao intacta (v1.0)" ((InLab_UpdateLerVersao fakeRaiz) == "1.0")
        checar "Sem modulo: nenhum .bak criado" (not (existeDir bak))
        checar "Sem modulo: nenhuma recarga" (INLAB_TESTE_RECARGAS.count == 0)
        checar "Sem modulo: .novo apagado" (not (existeDir (fakeRaiz + ".novo")))

        -- 4. TAMANHO DIFERENTE: aborta antes de extrair
        local zip2 = montarZip "2.0"
        causa = InLab_UpdateAplicarZip zip2 fakeRaiz "2.0" ((tamanho zip2) + 1)
        checar "Tamanho errado: aborta com 'incompleto'" (matchPattern causa pattern:"*incompleto*")
        checar "Tamanho errado: nao extraiu" (not (existeDir (fakeRaiz + ".novo")))
        checar "Tamanho errado: instalacao intacta" ((InLab_UpdateLerVersao fakeRaiz) == "1.0")

        -- 5. VERSAO DO PACOTE DIFERENTE DA TAG
        local zipTroca = montarZip "2.5" versaoInterna:"9.9"
        causa = InLab_UpdateAplicarZip zipTroca fakeRaiz "2.5" (tamanho zipTroca)
        checar "Pacote com versao diferente da tag: aborta" (matchPattern causa pattern:"*v9.9*v2.5*")
        checar "Pacote com versao diferente: instalacao intacta" ((InLab_UpdateLerVersao fakeRaiz) == "1.0" and not (existeDir bak))

        -- 6. ZIP COMPLETO: aplica
        causa = InLab_UpdateAplicarZip zip2 fakeRaiz "2.0" (tamanho zip2)
        checar "Completo: aplica sem causa" (causa == "")
        checar "Completo: instalacao tem os arquivos novos" ((InLab_UpdateLerVersao fakeRaiz) == "2.0" and doesFileExist (fakeRaiz + "\\core\\a.ms"))
        checar "Completo: .bak existe com a versao anterior" ((InLab_UpdateLerVersao bak) == "1.0")
        checar "Completo: recarregou a partir da raiz" (INLAB_TESTE_RECARGAS.count == 1)
        checar "Completo: sem .novo nem .bak.old sobrando" (not (existeDir (fakeRaiz + ".novo")) and not (existeDir (fakeRaiz + ".bak.old")))

        -- 7. FALHA NA CARGA DEPOIS DA TROCA: rollback
        local zip3 = montarZip "3.0"
        INLAB_TESTE_RECARGAS = #()
        INLAB_TESTE_FALHAR_CARGA = true
        causa = InLab_UpdateAplicarZip zip3 fakeRaiz "3.0" (tamanho zip3)
        INLAB_TESTE_FALHAR_CARGA = false
        checar "Carga falhou: devolve a causa" (matchPattern causa pattern:"*n?o carregou*")
        checar "Carga falhou: instalacao volta para v2.0" ((InLab_UpdateLerVersao fakeRaiz) == "2.0")
        checar "Carga falhou: .bak continua o de antes (v1.0)" ((InLab_UpdateLerVersao bak) == "1.0")
        checar "Carga falhou: recarregou a nova e depois a anterior" (INLAB_TESTE_RECARGAS.count == 2)
        checar "Carga falhou: sem .novo nem .bak.old sobrando" (not (existeDir (fakeRaiz + ".novo")) and not (existeDir (fakeRaiz + ".bak.old")))

        -- 8. SEGUNDO UPDATE BEM-SUCEDIDO: descarta o .bak antigo, cria outro
        causa = InLab_UpdateAplicarZip zip3 fakeRaiz "3.0" (tamanho zip3)
        checar "Segundo update: aplica" (causa == "" and (InLab_UpdateLerVersao fakeRaiz) == "3.0")
        checar "Segundo update: .bak agora e a v2.0 (v1.0 descartada)" ((InLab_UpdateLerVersao bak) == "2.0")
        checar "Segundo update: sem .bak.old" (not (existeDir (fakeRaiz + ".bak.old")))

        -- 9. REVERTER
        causa = InLab_UpdateReverterEm fakeRaiz
        checar "Reverter: sem causa" (causa == "")
        checar "Reverter: instalacao volta ao conteudo anterior (v2.0)" ((InLab_UpdateLerVersao fakeRaiz) == "2.0" and doesFileExist (fakeRaiz + "\\core\\a.ms"))
        checar "Reverter: a v3.0 fica no .bak" ((InLab_UpdateLerVersao bak) == "3.0")
        checar "Reverter: sem .troca sobrando" (not (existeDir (fakeRaiz + ".troca")))
        INLAB_TESTE_FALHAR_CARGA = true
        causa = InLab_UpdateReverterEm fakeRaiz
        INLAB_TESTE_FALHAR_CARGA = false
        checar "Reverter com carga falhando: desfaz" (causa != "" and (InLab_UpdateLerVersao fakeRaiz) == "2.0" and (InLab_UpdateLerVersao bak) == "3.0")
        Dir.Delete bak true
        checar "Reverter sem .bak: recusa" ((InLab_UpdateReverterEm fakeRaiz) != "")

        -- 10. CHECKOUT DO GIT: recusa
        Dir.CreateDirectory (fakeRaiz + "\\.git")
        causa = InLab_UpdateAplicarZip zip3 fakeRaiz "3.0" (tamanho zip3)
        checar "Checkout do git: aplicar recusa" (matchPattern causa pattern:"*checkout*" and (InLab_UpdateLerVersao fakeRaiz) == "2.0")
        Dir.Delete (fakeRaiz + "\\.git") true

        -- 11. ESTADOS DO DOWNLOAD (sem rede)
        InLab_Update.estado = #ocioso
        checar "BaixarEAplicar em #ocioso: recusa" ((InLab_UpdateBaixarEAplicar()) == false)
        checar "Cancelar sem download: false" ((InLab_UpdateCancelar()) == false)

        InLab_Update.estado = #baixando
        InLab_Update.versaoRemota = "3.0"
        InLab_Update.token += 1
        InLab_Update_OnBaixado (dotNetObject "System.Net.WebClient") (ArgsFalso Cancelled:true UserState:InLab_Update.token)
        checar "Download cancelado volta para #disponivel" (InLab_Update.estado == #disponivel)

        InLab_Update.estado = #baixando
        InLab_Update.token += 1
        InLab_Update_OnBaixado (dotNetObject "System.Net.WebClient") (ArgsFalso Error:(dotNetObject "System.Exception" "conexao caiu") UserState:InLab_Update.token)
        checar "Download com erro vira #erro com a causa" (InLab_Update.estado == #erro and matchPattern InLab_Update.msgErro pattern:"*conexao caiu*")

        InLab_Update.estado = #baixando
        InLab_Update.token += 1
        InLab_Update_OnBaixado (dotNetObject "System.Net.WebClient") (ArgsFalso UserState:(InLab_Update.token - 1))
        checar "Fim de download com token velho e descartado" (InLab_Update.estado == #baixando)

        InLab_Update.estado = #baixando
        InLab_Update_WC = dotNetObject "System.Net.WebClient"
        fileIn (raiz + @"functions\fn_updater.ms")
        InLab_Update_Recarregar = fn _stubRecarregar r = ( append INLAB_TESTE_RECARGAS r; InLab_UpdateLerVersao r )
        checar "Reload durante o download volta para #disponivel" (InLab_Update.estado == #disponivel)
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("FAIL  EXCECAO: " + getCurrentException())
    )

    -- LIMPEZA
    try ( if existeDir base do Dir.Delete base true ) catch ( linha ("      nao apagou " + base + ": " + getCurrentException()) )
    checar "Temp do teste apagado" (not (existeDir base))
    if recarregarOriginal != undefined do InLab_Update_Recarregar = recarregarOriginal
    InLab_Header_Estado = headerOriginal
    InLab_Log = logOriginal
    INLAB_ROOT = rootOriginal
    INLAB_VERSAO = versaoOriginal
    InLab_Update_WC = undefined
    if updateOriginal != undefined do InLab_Update = updateOriginal
    INLAB_UPDATE_HIST = if histOriginal != undefined then histOriginal else #()
    InLab_SecUpdate_Atualizar = secaoOriginal

    linha ("---- " + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
)
