/*
================================================================================
 functions\fn_json.ms — Fase 5.1: parser JSON genérico, 100% MAXScript nativo
--------------------------------------------------------------------------------
 POR QUE NÃO dotNet (Json.NET / JavaScriptSerializer): o plugin roda em
 máquinas de modelador do 3ds Max 2024 ao 2027 sem etapa de instalação
 extra. JavaScriptSerializer depende da assembly System.Web.Extensions, que
 nem sempre está presente/carregável em toda instalação — um parser escrito
 em MAXScript puro (recursive descent sobre a string) não depende de nada
 além da linguagem em si.

 REPRESENTAÇÃO ESCOLHIDA (decisão desta fase, documentada conforme pedido):
   objeto JSON {...}  → Array MAXScript de pares #(chave, valor), chave
                         sempre String — NÃO o struct nativo `dictionary`.
   array JSON  [...]  → Array MAXScript comum (#())
   string / number / boolean / null → String / Integer|Float / true|false / undefined

 Por que array-de-pares e não `dictionary`: mantém a árvore inteira em
 tipos MAXScript simples e universais (Array/String/Number/Boolean), fáceis
 de inspecionar direto no Listener (basta dar print) e de percorrer com
 `for`, sem depender do comportamento exato da classe Dictionary em cada
 versão do Max. Use InLab_JSON_Obter para buscar uma chave por nome.

 CONTRATO DE ERRO: InLab_ParseJSON NUNCA deixa uma exceção escapar pro
 chamador. Em caso de JSON malformado, loga via InLab_Log tipo:#err e
 retorna undefined.

 TESTE MANUAL (Listener):
   local r = InLab_ParseJSON "{\"nome\": \"teste\", \"valor\": 42, \"itens\": [1, 2, 3], \"ativo\": true}"
   InLab_JSON_Obter r "nome"   -> "teste"
   InLab_JSON_Obter r "valor"  -> 42
   InLab_JSON_Obter r "itens"  -> #(1, 2, 3)
   InLab_JSON_Obter r "ativo"  -> true
================================================================================
*/

--------------------------------------------------------------------------------
-- HELPERS DE BAIXO NÍVEL (uso só interno a este arquivo)
--------------------------------------------------------------------------------

fn InLab_JSON_EhEspaco c =
(
    c == " " or c == "\t" or c == "\n" or c == "\r"
)

-- Avança pos enquanto houver espaço em branco; JSON não é sensível a
-- formatação entre tokens.
fn InLab_JSON_Pular texto pos =
(
    local n = texto.count
    while pos <= n and (InLab_JSON_EhEspaco texto[pos]) do pos += 1
    pos
)

fn InLab_JSON_EhDigito c =
(
    (findString "0123456789" c) != undefined
)

-- Converte uma string de exatamente 4 dígitos hex (\uXXXX) num inteiro,
-- sem usar `execute` (evita rodar texto vindo de um arquivo externo como
-- código MAXScript).
fn InLab_JSON_HexParaInt hex =
(
    local digitos = "0123456789abcdef"
    local val = 0
    for i = 1 to hex.count do
    (
        local c = toLower hex[i]
        local idx = findString digitos c
        if idx == undefined do throw ("dígito hexadecimal inválido em \\u: '" + c + "'")
        val = val * 16 + (idx - 1)
    )
    val
)

--------------------------------------------------------------------------------
-- PARSERS POR TIPO — cada um recebe (texto, pos) com pos apontando para o
-- primeiro caractere do valor, e devolve #(valorConvertido, posApósOValor).
-- Recursivos entre si (objeto/array chamam InLab_JSON_ParsearValor) — a
-- ordem de definição no arquivo não importa em MAXScript (nomes de fn são
-- resolvidos em tempo de chamada, não de definição).
--------------------------------------------------------------------------------

fn InLab_JSON_ParsearString texto pos =
(
    -- pos aponta para a aspas de abertura
    local n = texto.count
    pos += 1
    local resultado = ""
    local fechou = false
    while not fechou do
    (
        if pos > n do throw "string JSON não fechada (aspas de fechamento ausente)"
        local c = texto[pos]
        if c == "\"" then
        (
            pos += 1
            fechou = true
        )
        else if c == "\\" then
        (
            pos += 1
            if pos > n do throw "escape incompleto no fim da string JSON"
            local e = texto[pos]
            if e == "u" then
            (
                if (pos + 4) > n do throw "escape \\u incompleto (menos de 4 dígitos hex)"
                local hex = substring texto (pos + 1) 4
                resultado += (bit.intAsChar (InLab_JSON_HexParaInt hex))
                pos += 5
            )
            else
            (
                local literal = if e == "\"" then "\""
                    else if e == "\\" then "\\"
                    else if e == "/" then "/"
                    else if e == "n" then "\n"
                    else if e == "t" then "\t"
                    else if e == "r" then "\r"
                    else if e == "b" then (bit.intAsChar 8)
                    else if e == "f" then (bit.intAsChar 12)
                    else throw ("escape desconhecido '\\" + e + "' na posição " + (pos as string))
                resultado += literal
                pos += 1
            )
        )
        else
        (
            resultado += c
            pos += 1
        )
    )
    #(resultado, pos)
)

fn InLab_JSON_ParsearNumero texto pos =
(
    local n = texto.count
    local inicio = pos
    if pos <= n and texto[pos] == "-" do pos += 1
    while pos <= n and (InLab_JSON_EhDigito texto[pos]) do pos += 1
    local ehFloat = false
    if pos <= n and texto[pos] == "." then
    (
        ehFloat = true
        pos += 1
        while pos <= n and (InLab_JSON_EhDigito texto[pos]) do pos += 1
    )
    if pos <= n and (texto[pos] == "e" or texto[pos] == "E") then
    (
        ehFloat = true
        pos += 1
        if pos <= n and (texto[pos] == "+" or texto[pos] == "-") do pos += 1
        while pos <= n and (InLab_JSON_EhDigito texto[pos]) do pos += 1
    )
    local bruto = substring texto inicio (pos - inicio)
    if bruto == "" or bruto == "-" do throw ("número JSON inválido na posição " + (inicio as string))
    local valor = if ehFloat then (bruto as float) else (bruto as integer)
    #(valor, pos)
)

fn InLab_JSON_ParsearBooleano texto pos =
(
    local n = texto.count
    if (pos + 3) <= n and (substring texto pos 4) == "true" then #(true, pos + 4)
    else if (pos + 4) <= n and (substring texto pos 5) == "false" then #(false, pos + 5)
    else throw ("valor booleano inválido na posição " + (pos as string))
)

fn InLab_JSON_ParsearNull texto pos =
(
    local n = texto.count
    if (pos + 3) <= n and (substring texto pos 4) == "null" then #(undefined, pos + 4)
    else throw ("valor 'null' inválido na posição " + (pos as string))
)

fn InLab_JSON_ParsearArray texto pos =
(
    -- pos aponta para o '[' de abertura
    local n = texto.count
    pos += 1
    local itens = #()
    pos = InLab_JSON_Pular texto pos
    if pos <= n and texto[pos] == "]" then
    (
        pos += 1
    )
    else
    (
        local continuar = true
        while continuar do
        (
            local rValor = InLab_JSON_ParsearValor texto pos
            append itens rValor[1]
            pos = InLab_JSON_Pular texto rValor[2]
            if pos > n do throw "fim inesperado dentro de um array JSON"
            if texto[pos] == "," then
            (
                pos += 1
            )
            else if texto[pos] == "]" then
            (
                pos += 1
                continuar = false
            )
            else throw ("esperava ',' ou ']' na posição " + (pos as string))
        )
    )
    #(itens, pos)
)

fn InLab_JSON_ParsearObjeto texto pos =
(
    -- pos aponta para o '{' de abertura
    local n = texto.count
    pos += 1
    local pares = #()
    pos = InLab_JSON_Pular texto pos
    if pos <= n and texto[pos] == "}" then
    (
        pos += 1
    )
    else
    (
        local continuar = true
        while continuar do
        (
            pos = InLab_JSON_Pular texto pos
            if pos > n or texto[pos] != "\"" do throw ("esperava uma chave (string) na posição " + (pos as string))
            local rChave = InLab_JSON_ParsearString texto pos
            local chave = rChave[1]
            pos = InLab_JSON_Pular texto rChave[2]
            if pos > n or texto[pos] != ":" do throw ("esperava ':' na posição " + (pos as string))
            pos += 1
            local rValor = InLab_JSON_ParsearValor texto pos
            append pares #(chave, rValor[1])
            pos = InLab_JSON_Pular texto rValor[2]
            if pos > n do throw "fim inesperado dentro de um objeto JSON"
            if texto[pos] == "," then
            (
                pos += 1
            )
            else if texto[pos] == "}" then
            (
                pos += 1
                continuar = false
            )
            else throw ("esperava ',' ou '}' na posição " + (pos as string))
        )
    )
    #(pares, pos)
)

fn InLab_JSON_ParsearValor texto pos =
(
    pos = InLab_JSON_Pular texto pos
    if pos > texto.count do throw "fim inesperado do JSON (esperava um valor)"
    local c = texto[pos]
    if c == "{" then InLab_JSON_ParsearObjeto texto pos
    else if c == "[" then InLab_JSON_ParsearArray texto pos
    else if c == "\"" then InLab_JSON_ParsearString texto pos
    else if c == "t" or c == "f" then InLab_JSON_ParsearBooleano texto pos
    else if c == "n" then InLab_JSON_ParsearNull texto pos
    else if c == "-" or (InLab_JSON_EhDigito c) then InLab_JSON_ParsearNumero texto pos
    else throw ("caractere inesperado '" + c + "' na posição " + (pos as string))
)

--------------------------------------------------------------------------------
-- PONTO DE ENTRADA — chamado de outros módulos (UI etc.), por isso o
-- `global` explícito antes da definição (mesma cautela de escopo de reload
-- já documentada em ui\rollout_main.ms / core\struct_familia.ms).
--------------------------------------------------------------------------------

global InLab_ParseJSON
fn InLab_ParseJSON texto =
(
    local resultado = undefined
    if texto == undefined or texto == "" then
        InLab_Log "InLab_ParseJSON: texto vazio ou indefinido — nada para interpretar." tipo:#err
    else
    (
        local ok = true
        local mensagemErro = ""
        local valorFinal = undefined
        try
        (
            local r = InLab_JSON_ParsearValor texto 1
            valorFinal = r[1]
            local posFinal = InLab_JSON_Pular texto r[2]
            if posFinal <= texto.count do
                throw ("texto sobrando após o fim do JSON válido, a partir da posição " + (posFinal as string))
        )
        catch
        (
            ok = false
            mensagemErro = getCurrentException()
        )
        if ok then resultado = valorFinal
        else InLab_Log ("InLab_ParseJSON: JSON malformado — " + mensagemErro) tipo:#err
    )
    resultado
)

-- Busca o valor de "chave" num objeto-JSON-como-array-de-pares (o formato
-- de InLab_ParseJSON para {...}). Retorna undefined se a chave não existir
-- ou se o nó nem for um objeto — nunca lança erro, permite checar campos
-- opcionais sem try/catch no código chamador.
fn InLab_JSON_Obter objetoComoPares chave =
(
    local achado = undefined
    if isKindOf objetoComoPares Array do
        for par in objetoComoPares where (isKindOf par Array and par.count == 2 and par[1] == chave) do achado = par[2]
    achado
)

--------------------------------------------------------------------------------
-- LEITURA DE ARQUIVO — utilitário associado (o .json do produto é sempre
-- UTF-8, exportado da plataforma Lovable/Supabase). `global` explícito pelo
-- mesmo motivo de InLab_ParseJSON acima: é chamado a partir da UI (Fase 5.2).
--------------------------------------------------------------------------------

global InLab_JSON_LerArquivoUTF8
fn InLab_JSON_LerArquivoUTF8 caminho =
(
    local conteudo = undefined
    local f = try ( openFile caminho mode:"r" encoding:#utf8 ) catch ( undefined )
    if f == undefined then
        InLab_Log ("Não foi possível abrir o arquivo: " + caminho) tipo:#err
    else
    (
        local partes = ""
        while not (eof f) do
        (
            local linha = readLine f
            partes += linha + "\n"
        )
        close f
        conteudo = partes
    )
    conteudo
)
