/*
 tests\test_globais_adiantados.ms — teste estático da ordem de declaração dos globais
 14/10/2026: na v1.1, o Converter Material deu "Call needs function or class,
 got: undefined" (fn_material_convert.ms, linha 294) num Max recém-aberto.
 InLab_AvisosDoSlot chamava InLab_TransformDoBitmap, que só era declarado
 global mais abaixo no arquivo. No PRIMEIRO fileIn, o MaxScript compila o
 nome que ainda não é global como variável local, e ela fica undefined.
 Chamada recursiva funciona: o nome do próprio fn já vale dentro do corpo.
 Num reload o global já existe e o erro some, por isso nenhum teste que roda
 depois de carregar o plugin pega esse caso.
 Este teste lê os arquivos do manifesto (INLAB_MODULOS, em InLabChecker.ms)
 na ordem de carga e falha em todo uso de um nome InLab_* / INLAB_* que é
 definido em algum módulo mas ainda não foi declarado (`global` ou `fn`)
 naquele ponto.
 Não mexe na cena. Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_globais_adiantados.txt (PASS/FAIL por item).
*/
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_globais_adiantados.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local Regex = dotNetClass "System.Text.RegularExpressions.Regex"
    local opIgnorar = (dotNetClass "System.Text.RegularExpressions.RegexOptions").IgnoreCase
    local reNome = dotNetObject "System.Text.RegularExpressions.Regex" "\\b(InLab_\\w+|INLAB_\\w+)\\b" opIgnorar
    local reFn = dotNetObject "System.Text.RegularExpressions.Regex" "^\\s*(mapped\\s+)?fn\\s+(\\w+)" opIgnorar
    local reGlobal = dotNetObject "System.Text.RegularExpressions.Regex" "^\\s*global\\s+(.*)$" opIgnorar

    fn lerLinhas arq =
    (
        local r = #()
        local f = openFile arq mode:"rt"
        if f != undefined do
        (
            while not (eof f) do append r (readLine f)
            close f
        )
        r
    )

    -- Linha sem comentário (-- e /* */) e sem o conteúdo das strings.
    -- emBloco: #(bool) compartilhado entre as linhas do arquivo.
    fn limparLinha s emBloco =
    (
        local r = ""
        local i = 1
        local n = s.count
        local emString = false
        while i <= n do
        (
            local c = s[i]
            local c2 = if i < n then s[i + 1] else ""
            if emBloco[1] then
            (
                if c == "*" and c2 == "/" then ( emBloco[1] = false ; i += 2 ) else i += 1
            )
            else if emString then
            (
                if c == "\\" then i += 2
                else ( if c == "\"" do emString = false ; i += 1 )
            )
            else if c == "-" and c2 == "-" then i = n + 1
            else if c == "/" and c2 == "*" then ( emBloco[1] = true ; i += 2 )
            else if c == "\"" then ( emString = true ; r += " " ; i += 1 )
            else ( r += c ; i += 1 )
        )
        r
    )

    fn nomesDoGlobal resto reNome =
    (
        -- "A, B = 1" / "A = fn ..." : os nomes vêm antes do primeiro "="
        local antes = (filterString resto "=")[1]
        if antes == undefined do antes = ""
        for p in (filterString antes ", \t") where (reNome.IsMatch p) collect (toLower p)
    )

    -- Manifesto: os @"..." dentro de INLAB_MODULOS = #( ... )
    local entrada = raiz + "InLabChecker.ms"
    local linhasEntrada = lerLinhas entrada
    local modulos = #()
    local dentro = false
    local preDeclarados = #()
    local blocoE = #(false)
    for s in linhasEntrada do
    (
        if not dentro and (findString s "INLAB_MODULOS = #(") != undefined then dentro = true
        else if dentro then
        (
            local t = trimLeft s
            if t.count > 0 and t[1] == ")" then dentro = false
            else
            (
                local m = (dotNetObject "System.Text.RegularExpressions.Regex" "@\"([^\"]+)\"").Match s
                if m.Success do append modulos (m.Groups.Item[1]).Value
            )
        )
        local limpa = limparLinha s blocoE
        local mg = reGlobal.Match limpa
        if mg.Success do join preDeclarados (nomesDoGlobal (mg.Groups.Item[1]).Value reNome)
    )
    checar ("manifesto lido (" + modulos.count as string + " módulos)") (modulos.count > 20)

    -- 1ª passada: todos os nomes definidos em algum módulo.
    local conteudo = #() -- paralelo a modulos: linhas limpas
    local definidos = #()
    for m in modulos do
    (
        local bloco = #(false)
        local limpas = for s in (lerLinhas (raiz + m)) collect (limparLinha s bloco)
        append conteudo limpas
        for s in limpas do
        (
            local mf = reFn.Match s
            if mf.Success and reNome.IsMatch (mf.Groups.Item[2]).Value do appendIfUnique definidos (toLower (mf.Groups.Item[2]).Value)
            local mg = reGlobal.Match s
            if mg.Success do for nm in (nomesDoGlobal (mg.Groups.Item[1]).Value reNome) do appendIfUnique definidos nm
        )
    )

    -- 2ª passada: uso antes da declaração.
    local declarados = for nm in preDeclarados collect nm
    local problemas = #()
    for k = 1 to modulos.count do
    (
        local limpas = conteudo[k]
        for i = 1 to limpas.count do
        (
            local s = limpas[i]
            local mg = reGlobal.Match s
            if mg.Success do join declarados (nomesDoGlobal (mg.Groups.Item[1]).Value reNome)
            local mf = reFn.Match s
            if mf.Success do append declarados (toLower (mf.Groups.Item[2]).Value)
            local usos = reNome.Matches s
            for j = 0 to usos.Count - 1 do
            (
                local nm = toLower (usos.Item[j]).Value
                if (findItem definidos nm) > 0 and (findItem declarados nm) == 0 do
                    appendIfUnique problemas (modulos[k] + ":" + i as string + " usa " + (usos.Item[j]).Value + " antes de declarar o global")
            )
        )
    )

    for p in problemas do linha ("      " + p)
    checar ("nenhum global InLab_/INLAB_ usado antes de declarado (" + problemas.count as string + " casos)") (problemas.count == 0)

    linha ("TOTAL FALHAS: " + INLAB_TESTE_FALHAS as string)
    close INLAB_TESTE_SAIDA
)
