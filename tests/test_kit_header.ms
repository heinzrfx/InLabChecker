/*
 tests\test_kit_header.ms — teste automatico de ui\kit.ms e ui\header.ms
 RODAR NUMA CENA QUALQUER: nao cria nem apaga objeto de cena.
 Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_kit_header.txt (PASS/FAIL por item).
*/
global InLab_Log, InLab_CorDoTipo
global INLAB_KIT_CORES, InLab_Kit_Cor, InLab_Kit_Fonte
global InLab_Kit_BotaoIcone, InLab_Kit_Pastilha
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
global INLAB_ROOT, INLAB_HEADER_VERSAO_PADRAO
global InLab_Header_Montar, InLab_Header_Pnl, InLab_Header_Pastilha
global InLab_Header_Titulo, InLab_Header_Marca
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_kit_header.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn corIgual a b = (a.R == b.R and a.G == b.G and a.B == b.B)

    local logOriginal = InLab_Log

    try
    (
        -- ATENCAO A ORDEM: core\log.ms DEFINE InLab_Log. Trocar o logger antes
        -- deste fileIn nao adianta — o fileIn redefine por cima e o teste passa
        -- a escrever no RichTextBox (ou em nada) em vez do arquivo de saida.
        -- Por isso o fileIn vem primeiro e a troca vem depois.
        fileIn (raiz + @"core\log.ms")
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )

        fileIn (raiz + @"ui\kit.ms")

        -- ui\header.ms le INLAB_ROOT pra achar a arte. Fora do plugin, o teste
        -- define a raiz na mao.
        INLAB_ROOT = raiz
        fileIn (raiz + @"ui\header.ms")

        -- 1. CORES BASICAS
        local marca = InLab_Kit_Cor #MARCA
        checar "MARCA e o ambar amostrado do logo (232,164,41)" (marca.R == 232 and marca.G == 164 and marca.B == 41)
        local fundo = InLab_Kit_Cor #FUNDO_HEADER
        checar "FUNDO_HEADER e #1F1F1F" (fundo.R == 31 and fundo.G == 31 and fundo.B == 31)

        -- 2. O KIT NAO PODE DIVERGIR DO LOG
        -- Trava os dois lados: quebra se alguem mudar um sem o outro.
        checar "OK_ACENTO == InLab_CorDoTipo #ok"     (corIgual (InLab_Kit_Cor #OK_ACENTO)   (InLab_CorDoTipo #ok))
        checar "ERR_ACENTO == InLab_CorDoTipo #err"   (corIgual (InLab_Kit_Cor #ERR_ACENTO)  (InLab_CorDoTipo #err))
        checar "WARN_ACENTO == InLab_CorDoTipo #warn" (corIgual (InLab_Kit_Cor #WARN_ACENTO) (InLab_CorDoTipo #warn))
        checar "INFO_ACENTO == InLab_CorDoTipo #info" (corIgual (InLab_Kit_Cor #INFO_ACENTO) (InLab_CorDoTipo #info))
        checar "WARN_ACENTO e a cor da MARCA" (corIgual (InLab_Kit_Cor #WARN_ACENTO) marca)

        -- 3. PROGRESSO nao vem do log: e papel novo
        local p = InLab_Kit_Cor #PROGRESSO_ACENTO
        checar "PROGRESSO_ACENTO e #6F8FB0" (p.R == 111 and p.G == 143 and p.B == 176)

        -- 4. OS 5 TIPOS TEM OS 4 SUFIXOS
        local faltando = #()
        for t in #("OK", "WARN", "ERR", "INFO", "PROGRESSO") do
            for s in #("_ACENTO", "_FUNDO", "_BORDA", "_TEXTO") do
            (
                local nm = (t + s) as name
                local achou = false
                for par in INLAB_KIT_CORES where par[1] == nm do achou = true
                if not achou do append faltando (t + s)
            )
        checar ("Todos os 20 nomes de status existem (faltando: " + faltando as string + ")") (faltando.count == 0)

        -- 5. NOME DESCONHECIDO: magenta e log, sem excecao
        local ruim = InLab_Kit_Cor #NAO_EXISTE
        checar "Cor desconhecida devolve magenta" (ruim.R == 255 and ruim.G == 0 and ruim.B == 255)

        -- 6. FONTE
        local f = InLab_Kit_Fonte 10.5
        checar "Fonte e Segoe UI" (f.FontFamily.Name == "Segoe UI")
        checar "Fonte respeita o tamanho" (abs (f.Size - 10.5) < 0.01)
        local fb = InLab_Kit_Fonte 10.5 bold:true
        checar "Fonte bold e bold" (fb.Bold == true)

        -- 7. MONTAGEM DO HEADER
        local pnlTeste = dotNetObject "System.Windows.Forms.Panel"
        pnlTeste.Width = 446
        pnlTeste.Height = 56
        checar "Montar devolve true" ((InLab_Header_Montar pnlTeste) == true)
        checar "Montar criou controles" (pnlTeste.Controls.Count > 0)
        local qtd1 = pnlTeste.Controls.Count
        InLab_Header_Montar pnlTeste
        checar "Montar 2x nao duplica controle" (pnlTeste.Controls.Count == qtd1)
        checar "Fundo do header e FUNDO_HEADER" (corIgual pnlTeste.BackColor (InLab_Kit_Cor #FUNDO_HEADER))
        checar "Titulo diz InLabChecker" (InLab_Header_Titulo.Text == "InLabChecker")
        checar "Versao padrao e a do repo" (INLAB_HEADER_VERSAO_PADRAO == "0.11")

        -- 8. ARTE AUSENTE NAO DERRUBA O HEADER
        -- O pacote do updater e validado so contra INLAB_MODULOS, que e tudo
        -- .ms: um pacote sem o PNG passa na validacao. O header tem que montar
        -- assim mesmo. Ver spec, secao 6, item 2.
        local raizBoa = INLAB_ROOT
        INLAB_ROOT = "Z:\\nao_existe_de_proposito\\"
        local pnlSemArte = dotNetObject "System.Windows.Forms.Panel"
        pnlSemArte.Width = 446
        pnlSemArte.Height = 56
        local okSemArte = false
        try ( okSemArte = (InLab_Header_Montar pnlSemArte) ) catch ( okSemArte = false )
        checar "Monta sem a arte, sem excecao" (okSemArte == true)
        checar "Sem arte, o texto continua la" (pnlSemArte.Controls.Count > 0)
        INLAB_ROOT = raizBoa

        -- 9. O PNG NAO PODE FICAR TRAVADO
        -- Image.FromFile e Bitmap(String) seguram o arquivo enquanto a imagem
        -- viver. Um PNG travado impede o updater de renomear a pasta de
        -- instalacao (passo 5 da spec do updater). Se o arquivo puder ser
        -- aberto pra escrita com o header montado, nao esta travado.
        local arte = INLAB_ROOT + @"ui\img\header_bulbo.png"
        local travado = true
        try
        (
            -- UMA LINHA SO, de proposito. MaxScript nao tem continuacao por
            -- "\", e parenteses formam BLOCO DE EXPRESSOES: quebrar a chamada
            -- dentro deles viraria varias expressoes, nao uma chamada com
            -- varios argumentos. Por isso os aliases curtos acima.
            local fMode = dotNetClass "System.IO.FileMode"
            local fAcc = dotNetClass "System.IO.FileAccess"
            local fShare = dotNetClass "System.IO.FileShare"
            local fs = dotNetObject "System.IO.FileStream" arte fMode.Open fAcc.ReadWrite fShare.None
            fs.Close()
            travado = false
        )
        catch ( travado = true )
        checar "PNG nao fica travado pelo header" (travado == false)
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCECAO: " + getCurrentException())
    )

    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluido — %\n" arqSaida
)
