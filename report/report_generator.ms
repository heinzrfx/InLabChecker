/*
================================================================================
 report\report_generator.ms — Fase 5 (log + arquivo JSON)
--------------------------------------------------------------------------------
 Consome o coletor InLab_VerifResults (as linhas individuais já foram logadas
 pela fábrica durante a execução) e emite o VEREDITO:
 aprovado = 100% dos itens critico:true em #pass. Advertências não bloqueiam.

 28/09/2026 (issue #37): além do log, cada rodada grava DOIS arquivos:
   <base>_verificacao.json → para a plataforma (campos estáveis, sem acento
                             nas chaves, UTF-8 sem BOM)
   <base>_verificacao.html → para gente ler (página única, CSS embutido,
                             abre em qualquer navegador, sem internet)
 <base> = cod_est do produto escolhido na seção Produto; sem produto, o nome
 do .max; cena sem nome → "cena_sem_nome". Pasta: a do .max; cena nunca salva
 → pasta temp do Max. Mesmo nome a cada rodada: a última sobrescreve (a
 plataforma sempre acha o arquivo no mesmo lugar). O log mostra os caminhos e
 InLab_UltimoRelatorio guarda #(json, html).
 Escrita por System.IO.File.WriteAllText com UTF8Encoding(false): o createFile
 do MaxScript não é confiável para acento e o MCP bloqueia createFile.
 14/10/2026 (ajustes do Rafa, item 1): o JSON abre com "formato":
 "inlabchecker.result/v1", o nome que a plataforma usa para ele.
 15/10/2026: o _verificacao.html saiu (pedido do time: só o JSON
 é usado). Saíram InLab_Relatorio_HTML e InLab_Relatorio_EscaparHtml, e
 InLab_UltimoRelatorio passou a guardar só o caminho do JSON.
================================================================================
*/

global InLab_UltimoRelatorio = undefined

-- Texto do status no JSON (sem acento: chave estável para a plataforma).
fn InLab_Relatorio_Status r =
(
    case r.status of
    (
        #pass:    "pass"
        #fail:    "fail"
        #warning: "advertencia"
        default:  "desconhecido"
    )
)

fn InLab_Relatorio_Contagem =
(
    local c = #(0, 0, 0) -- pass, fail, advertência
    for r in InLab_VerifResults do
        case r.status of
        (
            #pass:    c[1] += 1
            #fail:    c[2] += 1
            #warning: c[3] += 1
        )
    c
)

fn InLab_Relatorio_Agora formato = ((dotNetClass "System.DateTime").Now).ToString formato

-- String JSON entre aspas. Barra invertida primeiro, depois o resto.
fn InLab_Relatorio_JsonTexto s =
(
    s = s as string
    s = substituteString s "\\" "\\\\"
    s = substituteString s "\"" "\\\""
    s = substituteString s "\r" "\\r"
    s = substituteString s "\n" "\\n"
    s = substituteString s "\t" "\\t"
    "\"" + s + "\""
)

fn InLab_Relatorio_JsonBool b = if b then "true" else "false"

-- Relatório em JSON (string). Chaves estáveis — a plataforma lê por elas.
fn InLab_Relatorio_JSON cfg aprovado codEst:"" nomeProduto:"" =
(
    local c = InLab_Relatorio_Contagem()
    local q = InLab_Relatorio_JsonTexto
    local ss = stringStream ""
    format "{\n" to:ss
    format "  \"formato\": \"inlabchecker.result/v1\",\n" to:ss
    format "  \"plugin\": \"InLabChecker\",\n" to:ss
    format "  \"versao_plugin\": %,\n" (q INLAB_VERSAO) to:ss
    format "  \"data\": %,\n" (q (InLab_Relatorio_Agora "yyyy-MM-dd'T'HH:mm:ss")) to:ss
    format "  \"arquivo_max\": %,\n" (q (maxFilePath + maxFileName)) to:ss
    format "  \"produto\": { \"cod_est\": %, \"nome\": % },\n" (q codEst) (q nomeProduto) to:ss
    format "  \"familia\": %,\n" (q cfg.nome) to:ss
    format "  \"limites_provisorios\": %,\n" (InLab_Relatorio_JsonBool INLAB_LIMITES_PROVISORIOS) to:ss
    format "  \"aprovado\": %,\n" (InLab_Relatorio_JsonBool aprovado) to:ss
    format "  \"contagem\": { \"pass\": %, \"fail\": %, \"advertencia\": % },\n" c[1] c[2] c[3] to:ss
    format "  \"verificacoes\": [" to:ss
    for i = 1 to InLab_VerifResults.count do
    (
        local r = InLab_VerifResults[i]
        format "%\n    { \"id\": %, \"nome\": %, \"status\": %, \"critico\": %, \"provisorio\": %, \"mensagem\": % }" \
            (if i == 1 then "" else ",") (q r.id) (q r.nome) (q (InLab_Relatorio_Status r)) \
            (InLab_Relatorio_JsonBool r.critico) (InLab_Relatorio_JsonBool r.provisorio) (q r.mensagem) to:ss
    )
    format "\n  ]\n}\n" to:ss
    ss as string
)

-- Grava o JSON. pasta:/base: só para teste (padrão: a do .max, ou a
-- temp do Max com cena nunca salva; base = cod_est, nome do .max ou
-- "cena_sem_nome"). Devolve o caminho do JSON, ou undefined se não gravou.
fn InLab_SalvarRelatorio cfg aprovado codEst:"" nomeProduto:"" pasta:unsupplied base:unsupplied =
(
    if pasta == unsupplied do pasta = if maxFilePath != "" then maxFilePath else ((getDir #temp) + "\\")
    if base == unsupplied do
        base = if codEst != "" then codEst else if maxFileName != "" then (getFilenameFile maxFileName) else "cena_sem_nome"
    -- Nome de arquivo sem caractere proibido no Windows.
    for ch in #("\\", "/", ":", "*", "?", "\"", "<", ">", "|") do base = substituteString base ch "_"
    local arqJson = pasta + base + "_verificacao.json"
    try
    (
        local io = dotNetClass "System.IO.File"
        local utf8 = dotNetObject "System.Text.UTF8Encoding" false
        io.WriteAllText arqJson (InLab_Relatorio_JSON cfg aprovado codEst:codEst nomeProduto:nomeProduto) utf8
        InLab_Log ("Relatório salvo: " + arqJson) tipo:#ok
        arqJson
    )
    catch
    (
        InLab_Log ("Não foi possível salvar o relatório em " + pasta + " — " + getCurrentException()) tipo:#err
        undefined
    )
)

fn InLab_GerarRelatorio cfg codEst:"" nomeProduto:"" =
(
    local c = InLab_Relatorio_Contagem()
    local aprovado = InLab_AprovacaoFinal()
    InLab_Log "=============== RELATÓRIO FINAL ==============="
    InLab_Log ("Família: " + cfg.nome + " · " + (c[1] + c[2] + c[3]) as string + " verificações executadas")
    InLab_Log ("PASS: " + c[1] as string + " · FAIL: " + c[2] as string + " · ADVERTÊNCIA: " + c[3] as string)
    if aprovado then
        InLab_Log "RESULTADO: APROVADO — todos os itens críticos passaram." tipo:#ok
    else
        InLab_Log "RESULTADO: REPROVADO — corrigir os itens FAIL listados acima." tipo:#err
    InLab_UltimoRelatorio = InLab_SalvarRelatorio cfg aprovado codEst:codEst nomeProduto:nomeProduto
    InLab_Log "==============================================="
    aprovado
)
