/*
================================================================================
 report\report_generator.ms — Fase 5 (log + arquivos JSON e HTML)
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
================================================================================
*/

global InLab_UltimoRelatorio = undefined

-- Texto do status no JSON/HTML (sem acento: chave estável para a plataforma).
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

fn InLab_Relatorio_EscaparHtml s =
(
    s = s as string
    s = substituteString s "&" "&amp;"
    s = substituteString s "<" "&lt;"
    s = substituteString s ">" "&gt;"
    s = substituteString s "\"" "&quot;"
    s
)

-- Relatório em JSON (string). Chaves estáveis — a plataforma lê por elas.
fn InLab_Relatorio_JSON cfg aprovado codEst:"" nomeProduto:"" =
(
    local c = InLab_Relatorio_Contagem()
    local q = InLab_Relatorio_JsonTexto
    local ss = stringStream ""
    format "{\n" to:ss
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

-- Relatório em HTML (string): página única com CSS embutido.
fn InLab_Relatorio_HTML cfg aprovado codEst:"" nomeProduto:"" =
(
    local c = InLab_Relatorio_Contagem()
    local h = InLab_Relatorio_EscaparHtml
    local ss = stringStream ""
    local produto = if codEst == "" and nomeProduto == "" then "—" else (h (codEst + (if codEst != "" and nomeProduto != "" then " · " else "") + nomeProduto))
    format "<!DOCTYPE html>\n<html lang=\"pt-BR\">\n<head>\n<meta charset=\"utf-8\">\n" to:ss
    format "<title>Verificação % · InLabChecker</title>\n" (if codEst != "" then h codEst else h cfg.nome) to:ss
    format "<style>\n" to:ss
    format "body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#1f2328;background:#fff}\n" to:ss
    format "h1{font-size:20px;margin:0 0 4px}.meta{color:#57606a;font-size:13px;margin-bottom:16px}\n" to:ss
    format ".veredito{display:inline-block;padding:8px 16px;border-radius:6px;font-weight:600;color:#fff;margin-bottom:8px}\n" to:ss
    format ".ok{background:#1a7f37}.nok{background:#cf222e}\n" to:ss
    format "table{border-collapse:collapse;width:100\%;font-size:13px}th,td{text-align:left;padding:6px 8px;border-bottom:1px solid #d0d7de;vertical-align:top}\n" to:ss
    format "th{background:#f6f8fa}.st{font-weight:600;white-space:nowrap}.pass{color:#1a7f37}.fail{color:#cf222e}.advertencia{color:#9a6700}\n" to:ss
    format ".tag{font-size:11px;color:#57606a;border:1px solid #d0d7de;border-radius:10px;padding:0 6px;margin-left:4px}\n" to:ss
    format "</style>\n</head>\n<body>\n" to:ss
    format "<h1>Relatório de verificação</h1>\n" to:ss
    format "<div class=\"meta\">Produto: % · Família: % · Arquivo: % · % · InLabChecker v%</div>\n" \
        produto (h cfg.nome) (if maxFileName == "" then "cena não salva" else h maxFileName) \
        (InLab_Relatorio_Agora "dd/MM/yyyy HH:mm") (h INLAB_VERSAO) to:ss
    format "<div class=\"veredito %\">%</div>\n" (if aprovado then "ok" else "nok") \
        (if aprovado then "APROVADO — todos os itens críticos passaram" else "REPROVADO — corrigir os itens FAIL") to:ss
    format "<p class=\"meta\">PASS: % · FAIL: % · ADVERTÊNCIA: %%</p>\n" c[1] c[2] c[3] \
        (if INLAB_LIMITES_PROVISORIOS then " · limites provisórios: estouro vira advertência até validação do Birô" else "") to:ss
    format "<table>\n<tr><th>ID</th><th>Verificação</th><th>Status</th><th>Mensagem</th></tr>\n" to:ss
    for r in InLab_VerifResults do
    (
        local st = InLab_Relatorio_Status r
        local tags = (if r.critico then "<span class=\"tag\">crítico</span>" else "") + \
                     (if r.provisorio then "<span class=\"tag\">limite provisório</span>" else "")
        format "<tr><td>%</td><td>%%</td><td class=\"st %\">%</td><td>%</td></tr>\n" \
            (h r.id) (h r.nome) tags st (toUpper (r.statusTexto())) (h r.mensagem) to:ss
    )
    format "</table>\n</body>\n</html>\n" to:ss
    ss as string
)

-- Grava o JSON e o HTML. pasta:/base: só para teste (padrão: a do .max, ou a
-- temp do Max com cena nunca salva; base = cod_est, nome do .max ou
-- "cena_sem_nome"). Devolve #(json, html), ou undefined se não gravou.
fn InLab_SalvarRelatorio cfg aprovado codEst:"" nomeProduto:"" pasta:unsupplied base:unsupplied =
(
    if pasta == unsupplied do pasta = if maxFilePath != "" then maxFilePath else ((getDir #temp) + "\\")
    if base == unsupplied do
        base = if codEst != "" then codEst else if maxFileName != "" then (getFilenameFile maxFileName) else "cena_sem_nome"
    -- Nome de arquivo sem caractere proibido no Windows.
    for ch in #("\\", "/", ":", "*", "?", "\"", "<", ">", "|") do base = substituteString base ch "_"
    local arqJson = pasta + base + "_verificacao.json"
    local arqHtml = pasta + base + "_verificacao.html"
    try
    (
        local io = dotNetClass "System.IO.File"
        local utf8 = dotNetObject "System.Text.UTF8Encoding" false
        io.WriteAllText arqJson (InLab_Relatorio_JSON cfg aprovado codEst:codEst nomeProduto:nomeProduto) utf8
        io.WriteAllText arqHtml (InLab_Relatorio_HTML cfg aprovado codEst:codEst nomeProduto:nomeProduto) utf8
        InLab_Log ("Relatório salvo: " + arqHtml) tipo:#ok
        InLab_Log ("Relatório (plataforma): " + arqJson) tipo:#info
        #(arqJson, arqHtml)
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
