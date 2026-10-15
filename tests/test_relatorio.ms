/*
 tests\test_relatorio.ms — teste automático do relatório em arquivo (issue #37)
 Registra resultados à mão, gera o JSON numa pasta temporária e confere o
 conteúdo (JSON lido de volta pelo InLab_ParseJSON, acentos, veredito) e o
 nome/pasta do arquivo. 15/10/2026: o HTML saiu; confere que não é gravado.
 RODAR NUMA CENA VAZIA (File > New).
 Resultado: <pasta temp do Max>\inlab_test_relatorio.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_VerifResults, InLab_ResetarResultados, InLab_RegistrarVerif, INLAB_LIMITES_PROVISORIOS
global InLab_ObterFamilia, InLab_ParseJSON, InLab_JSON_Obter, InLab_JSON_LerArquivoUTF8
global InLab_Relatorio_JSON, InLab_SalvarRelatorio, InLab_GerarRelatorio, InLab_UltimoRelatorio
global INLAB_VERSAO, INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_relatorio.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn contem txt trecho = (findString txt trecho) != undefined

    local logOriginal = InLab_Log
    local provOriginal = true
    local pasta = (getDir #temp) + "\\inlab_teste_relatorio\\"

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms",
                   @"familias\familia_corpo_unico.ms", @"familias\familia_giro_assento.ms",
                   @"functions\fn_json.ms", @"report\report_generator.ms") do
            fileIn (raiz + m)
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        provOriginal = INLAB_LIMITES_PROVISORIOS
        INLAB_LIMITES_PROVISORIOS = true
        makeDir pasta all:true
        for f in getFiles (pasta + "*") do deleteFile f

        local cfg = InLab_ObterFamilia "giro_assento"
        InLab_ResetarResultados()
        InLab_RegistrarVerif "V-19" "Unidade do sistema" true "#centimeters" critico:true
        InLab_RegistrarVerif "V-03" "Triângulos totais" false "abaixo da faixa" provisorio:true
        InLab_RegistrarVerif "V-21" "Nomes sem acentos/espaços" false "Pé <Mesa> & \"Cadeira\"" critico:true
        InLab_RegistrarVerif "V-22" "Sufixos" false "lacuna" critico:false

        ---------------------------------------------------------------- JSON
        local js = InLab_Relatorio_JSON cfg false codEst:"POL-001" nomeProduto:"Poltrona Iandará"
        local d = InLab_ParseJSON js
        checar "JSON: o texto gerado é JSON válido" (d != undefined)
        checar "JSON: versão do plugin" ((InLab_JSON_Obter d "versao_plugin") == INLAB_VERSAO)
        checar "JSON: formato inlabchecker.result/v1 (#181)" ((InLab_JSON_Obter d "formato") == "inlabchecker.result/v1")
        checar "JSON: família" ((InLab_JSON_Obter d "familia") == "giro_assento")
        checar "JSON: aprovado = false" ((InLab_JSON_Obter d "aprovado") == false)
        checar "JSON: limites_provisorios = true" ((InLab_JSON_Obter d "limites_provisorios") == true)
        local prod = InLab_JSON_Obter d "produto"
        checar "JSON: produto.cod_est" ((InLab_JSON_Obter prod "cod_est") == "POL-001")
        checar "JSON: produto.nome com acento" ((InLab_JSON_Obter prod "nome") == "Poltrona Iandará")
        local cont = InLab_JSON_Obter d "contagem"
        checar "JSON: contagem pass/fail/advertencia = 1/1/2" ((InLab_JSON_Obter cont "pass") == 1 and (InLab_JSON_Obter cont "fail") == 1 and (InLab_JSON_Obter cont "advertencia") == 2)
        local vs = InLab_JSON_Obter d "verificacoes"
        checar "JSON: 4 verificações" (isKindOf vs Array and vs.count == 4)
        local v03 = vs[2]
        checar "JSON: V-03 com status 'advertencia' e provisorio = true" ((InLab_JSON_Obter v03 "id") == "V-03" and (InLab_JSON_Obter v03 "status") == "advertencia" and (InLab_JSON_Obter v03 "provisorio") == true)
        local v21 = vs[3]
        checar "JSON: V-21 'fail' e crítico" ((InLab_JSON_Obter v21 "status") == "fail" and (InLab_JSON_Obter v21 "critico") == true)
        checar "JSON: aspas e acento na mensagem voltam iguais" ((InLab_JSON_Obter v21 "mensagem") == "Pé <Mesa> & \"Cadeira\"")
        checar "JSON: data ISO" (matchPattern (InLab_JSON_Obter d "data") pattern:"????-??-??T??:??:??")

        ---------------------------------------------------------------- ARQUIVOS
        local arq = InLab_SalvarRelatorio cfg false codEst:"POL-001" nomeProduto:"Poltrona Iandará" pasta:pasta base:"POL-001"
        checar ("Arquivos: JSON existe (" + arq as string + ")") (isKindOf arq String and doesFileExist arq and arq == pasta + "POL-001_verificacao.json")
        checar "Arquivos: não grava HTML" (not (doesFileExist (pasta + "POL-001_verificacao.html")))
        local lido = InLab_ParseJSON (InLab_JSON_LerArquivoUTF8 arq)
        checar "Arquivos: JSON em UTF-8 lido de volta com acento" ((InLab_JSON_Obter (InLab_JSON_Obter lido "produto") "nome") == "Poltrona Iandará")
        local bytes = (dotNetClass "System.IO.File").ReadAllBytes arq
        checar "Arquivos: JSON sem BOM (começa com '{')" (bytes.count > 0 and bytes[1] == 123)
        local arq2 = InLab_SalvarRelatorio cfg true pasta:pasta base:"POL-001"
        checar "Arquivos: nova rodada sobrescreve (mesmo nome)" (arq2 == arq and (getFiles (pasta + "*")).count == 1)

        -- Pelo gerador (o que o orquestrador chama): cena nunca salva → pasta temp.
        InLab_UltimoRelatorio = undefined
        InLab_GerarRelatorio cfg codEst:"POL-001"
        checar "Gerador: guarda o caminho do JSON em InLab_UltimoRelatorio" (isKindOf InLab_UltimoRelatorio String and doesFileExist InLab_UltimoRelatorio)
        if maxFileName == "" do
            checar ("Gerador: cena nunca salva grava na pasta temp (" + InLab_UltimoRelatorio + ")") ((getFilenamePath InLab_UltimoRelatorio) == (getDir #temp) + "\\" and (filenameFromPath InLab_UltimoRelatorio) == "POL-001_verificacao.json")
        deleteFile InLab_UltimoRelatorio
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    try ( for f in getFiles (pasta + "*") do deleteFile f ) catch ()
    INLAB_LIMITES_PROVISORIOS = provOriginal
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
