/*
================================================================================
 core\struct_produto.ms
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Lê e interpreta o .json de produto baixado da plataforma externa (Lovable +
 Supabase). Essa é a nova fonte de dados por produto — SUBSTITUI o banco de
 famílias que antes ficava embutido no plugin: agora cada .json traz apenas
 os dados daquele produto específico (nomenclaturas corretas, diretrizes de
 aprovação e critérios de reprovação).

 ESCOPO DESTA ETAPA: só leitura/parse do .json + estrutura de dados nativa
 pra guardar o resultado. NENHUMA verificação/validação de cena acontece
 aqui — isso fica pra uma etapa posterior, que vai CONSUMIR o struct
 DadosProduto definido abaixo (do mesmo jeito que as verificações da Fase 4
 hoje consomem FamiliaConfig, em struct_familia.ms).

 ABORDAGEM DE PARSE: dotNet JavaScriptSerializer (System.Web.Extensions) —
 parser JSON maduro e já disponível em qualquer instalação do 3ds Max, sem
 exigir nenhuma DLL externa ao projeto. O resultado (Dictionary/ArrayList do
 .NET) é convertido recursivamente para Arrays 100% nativos do MaxScript
 logo em seguida (InLab_DotNetParaNativo) — o código escrito depois (etapa
 de verificação) nunca precisa lidar com sintaxe dotNet, só com arrays
 nativos.

 REPRESENTAÇÃO GENÉRICA (antes do mapeamento pro struct tipado):
   objeto JSON  → Array de pares #(chave, valor), chave sempre String
   array JSON   → Array MaxScript comum
   string/num/bool/null → String / Integer|Float / true|false / undefined

 SCHEMA DO JSON: como o schema exato exportado pelo Supabase ainda não foi
 compartilhado, os nomes de campo do struct DadosProduto abaixo
 (codigoProduto / nomenclaturas / diretrizesAprovacao / criteriosReprovacao)
 são um mapeamento provisório dos nomes descritos no pedido. Qualquer campo
 do JSON que não bata com esses nomes continua acessível via
 dadosProduto.dadosBrutos (a árvore completa, já convertida pra nativo) e
 InLab_ObterCampoJson — trocar os nomes abaixo quando o schema real chegar
 é uma edição pontual em InLab_MapearDadosProduto, sem mexer no resto.
================================================================================
*/

--------------------------------------------------------------------------------
-- HELPERS GENÉRICOS DE JSON-COMO-ARRAY-NATIVO
--------------------------------------------------------------------------------

-- Busca o valor de "chave" num objeto-JSON-como-array-de-pares. Retorna
-- undefined se a chave não existir ou se "objetoComoPares" nem for um
-- objeto (ex.: veio um array JSON na raiz) — nunca lança erro, permite
-- checar campos opcionais sem try/catch no código chamador.
fn InLab_ObterCampoJson objetoComoPares chave =
(
    local achado = undefined
    if isKindOf objetoComoPares Array do
        for par in objetoComoPares where isKindOf par Array and par.count == 2 and par[1] == chave do
            achado = par[2]
    achado
)

-- Converte recursivamente um valor devolvido pelo JavaScriptSerializer
-- (dotNet Dictionary/ArrayList/String/número-boxed) em estruturas nativas
-- do MaxScript. É o ÚNICO ponto do arquivo que fala a sintaxe dotNet —
-- tudo que sai daqui pra frente já é Array/String/Number/Boolean puro.
--
-- Detecção de objeto-vs-array via interface (IDictionary / IList) em vez
-- do nome completo do tipo genérico: Dictionary<string,object> e ArrayList
-- (os tipos que o JavaScriptSerializer usa por padrão) implementam essas
-- interfaces não-genéricas, e checar por elas evita depender de como cada
-- versão do .NET formata o nome de um tipo genérico.
fn InLab_DotNetParaNativo valor =
(
    if valor == undefined then undefined
    else if classof valor != dotNetObject then valor -- já é nativo
    else if isKindOf valor (dotNetClass "System.Collections.IDictionary") then
    (
        -- objeto JSON → array de pares #(chave, valorConvertido)
        local pares = #()
        for chave in valor.Keys do
            append pares #(chave as string, (InLab_DotNetParaNativo (valor.get_Item chave)))
        pares
    )
    else if isKindOf valor (dotNetClass "System.Collections.IList") then
    (
        -- array JSON → array MaxScript
        local itens = #()
        for i = 0 to valor.Count - 1 do
            append itens (InLab_DotNetParaNativo (valor.get_Item i))
        itens
    )
    else
    (
        -- valor escalar (string / boolean / número, ainda embrulhado em dotNetObject)
        -- (encadear .GetType().Name direto não parseia no MaxScript — precisa
        -- passar por uma variável intermediária)
        local tipoDotNet = valor.GetType()
        local tipoNome = tipoDotNet.Name
        case tipoNome of
        (
            "String":  valor as string
            "Boolean": ((valor as string) == "True")
            default:
            (
                -- número (Int32/Int64/Double etc.) — passa por string pra
                -- não depender de como cada tipo numérico boxed converte
                -- direto pra float, depois decide integer vs float.
                local s = valor as string
                local f = try (s as float) catch (undefined)
                if f == undefined then s
                else
                (
                    local fInt = f as integer
                    if f == (fInt as float) then fInt else f
                )
            )
        )
    )
)

--------------------------------------------------------------------------------
-- ESTRUTURA TIPADA DO PRODUTO
--------------------------------------------------------------------------------

struct DadosProduto
(
    codigoProduto       = "",  -- código digitado na plataforma pra gerar este .json
    nomenclaturas       = #(), -- nomenclaturas corretas do produto (V-20)
    diretrizesAprovacao = #(), -- regras/critérios que aprovam o produto
    criteriosReprovacao = #(), -- condições que reprovam o produto
    dadosBrutos         = #(), -- árvore COMPLETA do JSON (array de pares), já
                                -- convertida pra nativo — fallback pra qualquer
                                -- campo ainda não mapeado explicitamente acima
    caminhoArquivo       = ""   -- de onde este produto foi carregado (rastreio/log)
)

-- Monta um DadosProduto a partir da árvore genérica já convertida por
-- InLab_DotNetParaNativo. Fica separado da leitura de arquivo de propósito,
-- pra permitir testar o mapeamento isoladamente (ex.: com uma árvore montada
-- à mão no Listener, sem precisar de um arquivo em disco).
fn InLab_MapearDadosProduto arvore caminho =
(
    local d = DadosProduto()
    d.caminhoArquivo       = caminho
    d.dadosBrutos          = arvore
    d.codigoProduto        = InLab_ObterCampoJson arvore "codigoProduto"
    d.nomenclaturas        = InLab_ObterCampoJson arvore "nomenclaturas"
    d.diretrizesAprovacao  = InLab_ObterCampoJson arvore "diretrizesAprovacao"
    d.criteriosReprovacao  = InLab_ObterCampoJson arvore "criteriosReprovacao"

    if d.codigoProduto == undefined do d.codigoProduto = ""
    if d.nomenclaturas == undefined do d.nomenclaturas = #()
    if d.diretrizesAprovacao == undefined do d.diretrizesAprovacao = #()
    if d.criteriosReprovacao == undefined do d.criteriosReprovacao = #()
    d
)

--------------------------------------------------------------------------------
-- LEITURA DO ARQUIVO + PARSE
--------------------------------------------------------------------------------

-- Nome completo da classe usada tanto pra carregar a assembly quanto pra
-- construir o serializer (fn InLab_CarregarDadosProduto). Centralizado aqui
-- pra não repetir a string em dois lugares.
global INLAB_JSON_SERIALIZER_TIPO = "System.Web.Script.Serialization.JavaScriptSerializer"

-- Garante que a assembly do JavaScriptSerializer (System.Web.Extensions)
-- esteja carregada — cacheia o resultado num global pra não tentar de novo
-- a cada chamada. Retorna true/false; nunca lança exceção pra cima (quem
-- chama decide o que fazer se o parser não estiver disponível).
global INLAB_JsonAssemblyCarregada = undefined
fn InLab_GarantirAssemblyJson =
(
    if INLAB_JsonAssemblyCarregada == undefined do
        INLAB_JsonAssemblyCarregada = try ( dotNet.loadAssembly "System.Web.Extensions"; true ) catch ( false )
    INLAB_JsonAssemblyCarregada
)

-- Lê um arquivo texto por completo, em UTF-8 (JSON exportado do
-- Supabase/Lovable é UTF-8). System.IO.File.ReadAllText é mais robusto que
-- ler linha a linha em MaxScript puro — não depende de quebras de linha,
-- o que importa porque JSON costuma vir minificado numa linha só.
fn InLab_LerArquivoTexto caminho =
(
    (dotNetClass "System.IO.File").ReadAllText caminho
)

-- global explícito aqui: mesmo bug de escopo de reload já documentado em
-- ui\rollout_main.ms (InLab_AbrirUI) — se este arquivo for recarregado de
-- dentro de InLab_RecarregarPlugin(), a definição da função pode ficar
-- presa ao escopo local do chamador em vez do global.
global InLab_CarregarDadosProduto

-- FUNÇÃO PRINCIPAL — chamar isso a partir da UI.
--   caminho: opcional; se omitido (ou "" ou undefined), abre o diálogo
--            "Abrir arquivo" pra o usuário escolher o .json na hora.
-- Retorna um DadosProduto preenchido, ou undefined em qualquer falha
-- (nenhum arquivo escolhido, arquivo inexistente, parser indisponível,
-- JSON inválido) — o motivo específico sempre vai pro log via InLab_Log.
-- Nunca lança exceção pra cima: um .json ruim não deve travar a UI.
fn InLab_CarregarDadosProduto caminho:undefined =
(
    local resultado = undefined

    if caminho == undefined or caminho == "" do
        caminho = getOpenFileName caption:"Selecionar .json do produto" types:"Arquivo JSON (*.json)|*.json|Todos os arquivos (*.*)|*.*"

    if caminho == undefined then
        InLab_Log "Carregar produto cancelado — nenhum arquivo selecionado." tipo:#warn
    else if not (doesFileExist caminho) then
        InLab_Log ("Arquivo não encontrado: " + caminho) tipo:#err
    else
    (
        if not (InLab_GarantirAssemblyJson()) then
            InLab_Log "Não foi possível carregar o parser JSON (System.Web.Extensions ausente no .NET Framework)." tipo:#err
        else
        (
            local texto = try ( InLab_LerArquivoTexto caminho ) catch ( undefined )
            if texto == undefined or texto == "" then
                InLab_Log ("Falha ao ler o arquivo (vazio ou inacessível): " + caminho) tipo:#err
            else
            (
                local serializer = dotNetObject INLAB_JSON_SERIALIZER_TIPO
                serializer.MaxJsonLength = (dotNetClass "System.Int32").MaxValue
                local bruto = try ( serializer.DeserializeObject texto ) catch ( undefined )
                if bruto == undefined then
                    InLab_Log ("JSON inválido — não foi possível interpretar: " + caminho) tipo:#err
                else
                (
                    local arvore = InLab_DotNetParaNativo bruto
                    resultado = InLab_MapearDadosProduto arvore caminho
                    local sufixoCodigo = if resultado.codigoProduto != "" then ("  ·  código: " + resultado.codigoProduto) else ""
                    InLab_Log ("Produto carregado de " + (filenameFromPath caminho) + sufixoCodigo) tipo:#ok
                )
            )
        )
    )
    resultado
)
