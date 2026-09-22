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
