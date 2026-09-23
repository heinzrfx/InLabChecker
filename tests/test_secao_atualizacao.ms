/*
 tests\test_secao_atualizacao.ms — teste automatico de ui\rollout_update.ms
 (secao Atualizacao, issue #14)
 Abre a secao num createDialog PROPRIO, percorre os 6 estados do mockup
 mexendo em InLab_Update e confere texto, cor (do kit), barra, historico e
 botoes. NAO TOCA A REDE (disparo e pastilha viram stub). Fecha o dialogo e
 devolve as globais do painel real no final.
 RODAR NUMA CENA QUALQUER: nao cria nem apaga objeto de cena.
 Resultado: <pasta temp do Max>\inlab_test_secao_atualizacao.txt
*/
global InLab_Log, INLAB_VERSAO, INLAB_ROOT, INLAB_KIT_CORES, InLab_Kit_Cor
global InLab_PrefLer, InLab_PrefGravar, InLab_PrefApagar
global InLab_Update, InLab_Update_Disparar, InLab_Header_Estado, InLab_UpdateLog, INLAB_UPDATE_HIST
global InLabSecUpdate, InLab_SecUpdate_Atualizar, InLab_SecUpdate_Mostrar, INLAB_SECUPDATE_ACOES
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_secao_atualizacao.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn corIgual a b = (a.R == b.R and a.G == b.G and a.B == b.B)
    -- Botoes visiveis como #(#(texto, habilitado), ...)
    fn botoes r = for b in #(r.btnA, r.btnB, r.btnC) where b.visible collect #(b.text, b.enabled)

    local logOriginal = InLab_Log
    local headerOriginal = InLab_Header_Estado
    local disparoOriginal = InLab_Update_Disparar
    local updateOriginal = InLab_Update
    local secaoOriginal = InLabSecUpdate
    local atualizarOriginal = InLab_SecUpdate_Atualizar
    local histOriginal = INLAB_UPDATE_HIST
    local autoAntes = undefined
    local aberto = false

    try
    (
        fileIn (raiz + @"core\versao.ms")
        fileIn (raiz + @"core\prefs.ms")
        -- core\log.ms NAO e recarregado: zeraria o log do painel aberto. O
        -- logger do teste entra antes do kit, que e o primeiro a logar.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        fileIn (raiz + @"ui\kit.ms")
        fileIn (raiz + @"functions\fn_json.ms")
        fileIn (raiz + @"functions\fn_updater.ms")
        InLab_Update_Disparar = fn _stubDisparar url tok = true
        InLab_Header_Estado = fn _stubHeader estado versao:unsupplied pct:0 = true
        fileIn (raiz + @"ui\rollout_update.ms")
        INLAB_UPDATE_HIST = #()

        -- 1. CHECKBOX LE autoCheck NA ABERTURA
        autoAntes = InLab_PrefLer "autoCheck" "__ausente__"
        InLab_PrefGravar "autoCheck" "false"
        createDialog InLabSecUpdate 420 200
        aberto = true
        local r = InLabSecUpdate
        checar "Checkbox desligado quando autoCheck = false" (r.chkAuto.checked == false)
        checar "Instalada mostra INLAB_VERSAO" (r.lblInstalada.text == "Instalada: v" + INLAB_VERSAO)

        local u = InLab_Update

        -- 2. OCIOSO
        u.estado = #ocioso; u.versaoRemota = INLAB_VERSAO; u.aviso = ""; u.msgErro = ""
        InLab_SecUpdate_Atualizar()
        checar "Ocioso: verde" (corIgual r.lblStatus.BackColor (InLab_Kit_Cor #OK_FUNDO))
        checar "Ocioso: versao mais recente" (matchPattern r.lblStatus.Text pattern:"*vers?o mais recente*")
        local bs = botoes r
        checar "Ocioso: so Procurar (sem .bak)" (bs.count == 1 and matchPattern bs[1][1] pattern:"Procurar*" and bs[1][2])
        checar "Ocioso: Procurar ocupa a largura toda" (r.btnA.width == 398)
        checar "Ocioso: sem barra e sem historico" (not r.pbDown.visible and not r.lblHist.visible)

        -- 3. CHECANDO
        u.estado = #checando
        InLab_SecUpdate_Atualizar()
        checar "Checando: neutra (PROGRESSO)" (corIgual r.lblStatus.BackColor (InLab_Kit_Cor #PROGRESSO_FUNDO))
        bs = botoes r
        checar "Checando: Procurar desabilitado" (bs.count == 1 and not bs[1][2])

        -- 4. DISPONIVEL
        u.estado = #disponivel; u.versaoRemota = "99.0"; u.tamanhoZip = 1363148; u.publicadaEm = "22/09/2026"; u.notasUrl = "https://x"; u.ignorada = false
        InLab_SecUpdate_Atualizar()
        checar "Disponivel: ambar" (corIgual r.lblStatus.BackColor (InLab_Kit_Cor #WARN_FUNDO))
        checar "Disponivel: versao, tamanho e data" (matchPattern r.lblStatus.Text pattern:"*v99.0 dispon*1,3 MB*22/09/2026*")
        bs = botoes r
        checar "Disponivel: Atualizar, Notas, Ignorar" (bs.count == 3 and bs[1][1] == "Atualizar agora" and bs[2][1] == "Notas" and bs[3][1] == "Ignorar")
        checar "Disponivel: acoes dos botoes" (INLAB_SECUPDATE_ACOES[1] == #aplicar and INLAB_SECUPDATE_ACOES[2] == #notas and INLAB_SECUPDATE_ACOES[3] == #ignorar)
        checar "Disponivel: botoes nao se sobrepoem" (r.btnA.pos.x + r.btnA.width <= r.btnB.pos.x and r.btnB.pos.x + r.btnB.width <= r.btnC.pos.x and r.btnC.pos.x + r.btnC.width <= 408)
        u.ignorada = true
        InLab_SecUpdate_Atualizar()
        bs = botoes r
        checar "Ignorada: secao continua mostrando '(ignorada)'" (matchPattern r.lblStatus.Text pattern:"*(ignorada)*")
        checar "Ignorada: botao vira 'Ignorada', desabilitado" (bs[3][1] == "Ignorada" and not bs[3][2])
        u.ignorada = false

        -- 5. BAIXANDO / APLICANDO
        u.estado = #baixando; u.pct = 62
        InLab_SecUpdate_Atualizar()
        checar "Baixando: barra visivel em 62" (r.pbDown.visible and r.pbDown.value == 62)
        checar "Baixando: percentual no texto" (matchPattern r.lblStatus.Text pattern:"*Baixando v99.0*62%*")
        bs = botoes r
        checar "Baixando: so Cancelar, habilitado" (bs.count == 1 and bs[1][1] == "Cancelar" and bs[1][2] and INLAB_SECUPDATE_ACOES[1] == #cancelar)
        checar "Baixando: checkbox travado" (not r.chkAuto.enabled)
        u.estado = #aplicando
        InLab_SecUpdate_Atualizar()
        bs = botoes r
        checar "Aplicando: barra cheia, Cancelar desabilitado" (r.pbDown.value == 100 and not bs[1][2])

        -- 6. POS-SUCESSO
        InLab_UpdateLog "Pacote v99.0 extraido e validado."
        InLab_UpdateLog "v99.0 instalada." tipo:#ok
        u.estado = #ocioso; u.aviso = "Atualizado para v99.0."; u.pct = 0
        InLab_SecUpdate_Atualizar()
        checar "Sucesso: verde com o aviso" (corIgual r.lblStatus.BackColor (InLab_Kit_Cor #OK_FUNDO) and matchPattern r.lblStatus.Text pattern:"*Atualizado para v99.0*")
        checar "Sucesso: historico visivel com as ultimas linhas" (r.lblHist.visible and matchPattern r.lblHist.Text pattern:"*v99.0 instalada*")
        checar "Sucesso: barra escondida e checkbox livre" (not r.pbDown.visible and r.chkAuto.enabled)

        -- 7. ERRO
        u.aviso = ""; u.estado = #erro; u.msgErro = "nao aplicou a v99.0: pacote incompleto, falta(m) 1 modulo(s): verifications\\verif_uv.ms."
        InLab_SecUpdate_Atualizar()
        checar "Erro: vermelho com a causa" (corIgual r.lblStatus.BackColor (InLab_Kit_Cor #ERR_FUNDO) and matchPattern r.lblStatus.Text pattern:"*verif_uv.ms*")
        checar "Erro: diz em que versao o artista continua" (matchPattern r.lblStatus.Text pattern:("*continua na v" + INLAB_VERSAO + "*"))
        bs = botoes r
        checar "Erro: Tentar de novo e Copiar log" (bs.count == 2 and bs[1][1] == "Tentar de novo" and bs[2][1] == "Copiar log do erro")
        checar "Erro: acoes #tentar e #copiar" (INLAB_SECUPDATE_ACOES[1] == #tentar and INLAB_SECUPDATE_ACOES[2] == #copiar)
        -- A causa quebra em linhas: o texto medido tem que caber na caixa.
        local g = r.lblStatus.CreateGraphics()
        local sz = g.MeasureString r.lblStatus.Text r.lblStatus.Font (r.lblStatus.Width - 12)
        g.Dispose()
        checar "Erro: causa longa cabe na caixa de status" (sz.Height + 8 <= r.lblStatus.Height - 2)

        -- 8. PAINEL FECHADO: repintar nao levanta, Mostrar devolve false
        destroyDialog InLabSecUpdate
        aberto = false
        local levantou = false
        try ( InLab_SecUpdate_Atualizar() ) catch ( levantou = true )
        checar "Secao fechada: repintar nao levanta" (not levantou)
        checar "Secao fechada: Mostrar devolve false" ((InLab_SecUpdate_Mostrar()) == false)
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("FAIL  EXCECAO: " + getCurrentException())
    )

    -- LIMPEZA
    if aberto do try ( destroyDialog InLabSecUpdate ) catch ()
    if autoAntes != undefined do
    (
        if autoAntes == "__ausente__" then InLab_PrefApagar "autoCheck" else InLab_PrefGravar "autoCheck" autoAntes
    )
    InLab_Log = logOriginal
    InLab_Header_Estado = headerOriginal
    if disparoOriginal != undefined do InLab_Update_Disparar = disparoOriginal
    if updateOriginal != undefined do InLab_Update = updateOriginal
    InLab_SecUpdate_Atualizar = atualizarOriginal
    InLabSecUpdate = secaoOriginal
    INLAB_UPDATE_HIST = if histOriginal != undefined then histOriginal else #()

    linha ("---- " + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
)
