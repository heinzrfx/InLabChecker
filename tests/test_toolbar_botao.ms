/*
 tests\test_toolbar_botao.ms — teste de install\registrar.ms:InLab_GarantirBotaoToolbar
 (16/10/2026)
 RODAR NUMA CENA QUALQUER (Scripting > Run Script..., ou fileIn pelo MCP).
 Monta .cuix de fixture em (getDir #temp) e exercita a injeção do <Item> na
 Main Toolbar com recarregar:false (sem tocar na UI viva do Max).
 Saída: (getDir #temp)\inlab_test_toolbar.txt — PASS/FAIL por item.
 Usa openFile mode:"wt" (não createFile): o safe_mode do MCP bloqueia createFile.
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_GarantirBotaoToolbar, INLAB_TOOLBAR_ACTIONID, INLAB_TOOLBAR_SO_DEFINIR
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_toolbar.txt"
    INLAB_TESTE_SAIDA = openFile arqSaida mode:"wt"
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local File = dotNetClass "System.IO.File"

    -- Escreve um .cuix de fixture. temBarra: tem a Main Toolbar. temItemVelho:
    -- põe um <Item actionId="..."> (caixa minúscula no 'd', atributos velhos).
    fn escreverCuix caminho temBarra temItemVelho =
    (
        local sb = stringStream ""
        format "<?xml version=\"1.0\" encoding=\"utf-8\"?>" to:sb
        format "<ADSK_CUI><CUIWindows>" to:sb
        if temBarra then
        (
            format "<Window objectName=\"Main Toolbar\" name=\"Main Toolbar\" type=\"T\"><Items>" to:sb
            if temItemVelho do
                format "<Item typeID=\"2\" type=\"CTB_MACROBUTTON\" actionId=\"InLabChecker_Abrir`InLab\" imageName=\"velho\"/>" to:sb
            format "</Items></Window>" to:sb
        )
        else
            format "<Window objectName=\"Outra Barra\" name=\"Outra\" type=\"T\"><Items></Items></Window>" to:sb
        format "</CUIWindows></ADSK_CUI>" to:sb
        File.WriteAllText caminho (sb as string)
    )

    -- Conta os <Item> cujo atributo actionID/actionId (case-insensitive) == alvo.
    fn contaItens caminho alvo =
    (
        local xml = dotNetObject "System.Xml.XmlDocument"
        xml.load caminho
        local itens = xml.selectNodes "//Item"
        local n = 0
        for i = 0 to itens.count - 1 do
        (
            local it = itens.itemOf[i]
            local aid = undefined
            for a = 0 to it.Attributes.count - 1 do
            (
                local atr = it.Attributes.itemOf[a]
                if (toLower (atr.Name as string)) == "actionid" do aid = (atr.Value as string)
            )
            if aid == alvo do n += 1
        )
        n
    )

    try
    (
        -- Só define a função; não chama a garantia na UI viva.
        INLAB_TOOLBAR_SO_DEFINIR = true
        fileIn (raiz + "install\\registrar.ms")

        -- 1. Main Toolbar vazia -> adiciona
        local fx = (getDir #temp) + "\\inlab_fx_vazio.cuix"
        escreverCuix fx true false
        checar "adiciona o item (#adicionado)" ((InLab_GarantirBotaoToolbar caminho:fx recarregar:false) == #adicionado)
        checar "1 item com o actionID" ((contaItens fx INLAB_TOOLBAR_ACTIONID) == 1)

        -- 2. Idempotente: 2a vez não duplica e devolve #jaExistia
        checar "idempotente devolve #jaExistia" ((InLab_GarantirBotaoToolbar caminho:fx recarregar:false) == #jaExistia)
        checar "idempotente nao duplica (segue 1)" ((contaItens fx INLAB_TOOLBAR_ACTIONID) == 1)

        -- 3. Item velho (caixa diferente, atributos velhos) é trocado, sobra 1
        local fxVelho = (getDir #temp) + "\\inlab_fx_velho.cuix"
        escreverCuix fxVelho true true
        InLab_GarantirBotaoToolbar caminho:fxVelho recarregar:false
        checar "troca item velho, sobra 1" ((contaItens fxVelho INLAB_TOOLBAR_ACTIONID) == 1)

        -- 4. Sem Main Toolbar -> #semBarra
        local fxSemBarra = (getDir #temp) + "\\inlab_fx_sembarra.cuix"
        escreverCuix fxSemBarra false false
        checar "sem barra devolve #semBarra" ((InLab_GarantirBotaoToolbar caminho:fxSemBarra recarregar:false) == #semBarra)

        for p in #(fx, fxVelho, fxSemBarra) do try ( if doesFileExist p do deleteFile p ) catch ()
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("FAIL  EXCECAO: " + (getCurrentException() as string))
    )

    linha ("--- " + (if INLAB_TESTE_FALHAS == 0 then "TODOS PASS" else ((INLAB_TESTE_FALHAS as string) + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    INLAB_TESTE_FALHAS
)
