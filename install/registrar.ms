/*
================================================================================
 install\registrar.ms — registra o botão e o coloca na Main Toolbar nativa
 (23/09/2026; barra flutuante 16/10; BOTÃO NATIVO via .cuix 16/10/2026)
--------------------------------------------------------------------------------
 Chamado pelo install\inlabchecker_boot.ms (pasta startup) a cada abertura do
 Max e pelo install\instalar.ms na instalação. NÃO carrega o plugin e NÃO abre o
 painel: o painel abre só no clique do botão da lâmpada (pedido da equipe,
 23/09/2026).

 O QUE FAZ
 1. Copia a arte do ícone para (getDir #userIcons): os BMP da toolbar nativa
    (InLabChecker_16i/_24i.bmp e as máscaras _16a/_24a.bmp).
 2. Define o macroScript InLabChecker_Abrir (categoria "InLab"), ícone
    #("InLabChecker",1).
 3. GARANTE o botão na Main Toolbar nativa (InLab_GarantirBotaoToolbar): injeta
    um <Item> de macro no .cuix se ele não estiver lá. Assim o botão aparece
    sozinho na barra, sem o passo manual do Customize.

 BOTÃO NATIVO VIA .cuix, E NÃO JANELA FLUTUANTE (16/10/2026)
 - Até 16/10 isto montava uma janela flutuante (createDialog), porque injetar no
   .cuix fora tido como arriscado. Um spike no Max 2024 (ver
   docs\superpowers\specs\2026-10-16-botao-toolbar-nativo-design.md) mostrou que
   a injeção é segura e é o que o ArchToolz faz em produção: o botão nasce na
   Main Toolbar com a lâmpada branca (o BMP+máscara dá transparência no botão
   NATIVO — o problema de transparência de antes era do botão de ROLLOUT).
 - A edição é cirúrgica por actionID, idempotente (só grava quando o botão falta
   ou está desatualizado) e com backup/restauração do .cuix. No boot, com o botão
   já presente, é só uma leitura barata do XML — nada é gravado.

 REDE DE SEGURANÇA: como o boot chama este arquivo a cada abertura, se o artista
 resetar a UI / trocar de workspace e o botão sumir, ele volta sozinho na próxima
 abertura (InLab_GarantirBotaoToolbar re-injeta). O botão aponta para um macro e
 um actionID estáveis, então sobrevive à troca da pasta do plugin pela pastilha.

 TESTE: com INLAB_TOOLBAR_SO_DEFINIR == true no fileIn, o arquivo só DEFINE a
 função (não chama a garantia na UI viva). InLab_GarantirBotaoToolbar aceita
 caminho: (um .cuix de fixture) e recarregar:false (não toca na UI). Ver
 tests\test_toolbar_botao.ms.

 FORA DO MANIFESTO (não é módulo do plugin), mas DENTRO DO ZIP da release: mora
 na pasta do plugin para o updater poder trocar esta lógica numa versão nova. O
 boot, que o artista copia à mão, só faz fileIn deste arquivo e fica estável.
================================================================================
*/
global InLab_GarantirBotaoToolbar, INLAB_TOOLBAR_ACTIONID, INLAB_TOOLBAR_SO_DEFINIR

-- actionID do <Item> na toolbar = <macro>`<categoria>.
INLAB_TOOLBAR_ACTIONID = "InLabChecker_Abrir`InLab"

(
    local raiz = (getDir #userScripts) + "\\InLabChecker\\"
    local fileIO = dotNetClass "System.IO.File"
    for nome in #("InLabChecker_16i.bmp", "InLabChecker_24i.bmp", "InLabChecker_16a.bmp", "InLabChecker_24a.bmp") do
    (
        local de = raiz + "ui\\img\\" + nome
        local para = (getDir #userIcons) + "\\" + nome
        try
        (
            if doesFileExist de and (not (doesFileExist para) or (getFileSize de) != (getFileSize para)) do
                fileIO.Copy de para true
        )
        catch ( format "InLabChecker: não copiou o ícone % (%)\n" nome (getCurrentException()) )
    )
)

macroScript InLabChecker_Abrir
    category:"InLab"
    tooltip:"InLabChecker"
    buttonText:"InLabChecker"
    icon:#("InLabChecker", 1)
(
    on execute do
    (
        global InLab_AbrirUI
        if InLab_AbrirUI != undefined then
            InLab_AbrirUI()
        else
        (
            local entry = (getDir #userScripts) + "\\InLabChecker\\InLabChecker.ms"
            if doesFileExist entry then
                fileIn entry   -- carrega os módulos e abre o painel
            else
                messageBox ("InLabChecker não encontrado em:\n" + entry + \
                    "\n\nReinstale pelo zip da release (install\\README.md).") title:"InLabChecker"
        )
    )
)

-- Garante o botão na Main Toolbar nativa do Max, injetando um <Item> no .cuix.
--  caminho:    .cuix a editar; undefined usa cui.getConfigFile() (+ fallback).
--  recarregar: true faz flush+backup+loadConfig na UI viva; false só edita o
--              arquivo (seam de teste, não toca na UI).
-- Devolve: #adicionado | #jaExistia | #semBarra | #erro.
fn InLab_GarantirBotaoToolbar caminho:undefined recarregar:true =
(
    local resultado = #erro

    -- Analisa um XmlDocument já carregado: acha o <Items> da Main Toolbar (pelo
    -- nome, não por posição), lista os <Item> que casam o nosso actionID e diz se
    -- já está correto (exatamente 1, com os atributos de identidade). Devolve
    -- #(itens, casados, correto) ou undefined se não houver Main Toolbar/<Items>.
    fn _analisar xmlDoc =
    (
        -- Lê um atributo pelo nome, case-insensitive (o Max pode salvar actionID
        -- como actionId). Devolve "" se não houver.
        fn _lerAttr node nome =
        (
            local alvo = toLower nome
            local v = ""
            for a = 0 to node.Attributes.count - 1 do
            (
                local atr = node.Attributes.itemOf[a]
                if (toLower (atr.Name as string)) == alvo do v = (atr.Value as string)
            )
            v
        )
        local r = undefined
        local barras = xmlDoc.selectNodes "//ADSK_CUI/CUIWindows/Window[@objectName='Main Toolbar']"
        if barras.count > 0 do
        (
            local itens = barras.itemOf[0].selectSingleNode "Items"
            if itens != undefined do
            (
                local casados = #()
                for i = 0 to itens.ChildNodes.count - 1 do
                (
                    local filho = itens.ChildNodes.itemOf[i]
                    if (filho.Name == "Item") and ((_lerAttr filho "actionID") == INLAB_TOOLBAR_ACTIONID) do
                        append casados filho
                )
                -- Correto = 1 item com os atributos de identidade. NÃO exige
                -- imageName=="": o Max pode re-serializá-lo e não é essencial ao
                -- botão (o ícone vem do macro), então exigir isso daria regravação
                -- a cada boot (churn).
                local correto = false
                if casados.count == 1 do
                (
                    local it = casados[1]
                    correto = ((_lerAttr it "type") == "CTB_MACROBUTTON") and \
                              ((_lerAttr it "macroType") == "MB_TYPE_ACTION") and \
                              ((_lerAttr it "actionTableID") == "647394")
                )
                r = #(itens, casados, correto)
            )
        )
        r
    )

    try
    (
        local Arq = dotNetClass "System.IO.File"
        local cfg = caminho
        if cfg == undefined do cfg = cui.getConfigFile()
        if cfg == undefined do cfg = (getDir #maxData) + "\\UI\\Workspaces\\usersave\\Workspace__usersave__.cuix"

        if not (doesFileExist cfg) then
        (
            format "InLabChecker: .cuix não encontrado (%)\n" (cfg as string)
            resultado = #erro
        )
        else
        (
            dotnet.loadAssembly "system.xml"
            local xml = dotNetObject "System.Xml.XmlDocument"
            xml.load cfg
            local a = _analisar xml
            if a == undefined then
            (
                format "InLabChecker: Main Toolbar/Items não encontrada no .cuix\n"
                resultado = #semBarra
            )
            else if a[3] then
                resultado = #jaExistia   -- já correto: nada a gravar (caso comum do boot)
            else
            (
                local escrever = true
                local bak = cfg + ".inlab.bak"
                if recarregar do
                (
                    -- Flush do arranjo atual pro disco ANTES de reler o xml: senão o
                    -- xml.save (de um xml lido antes do flush) descartaria as
                    -- mudanças de toolbar não-salvas do usuário.
                    try ( cui.saveConfig() ) catch ()
                    -- Backup do estado recém-salvo. Sem backup não há como
                    -- restaurar, então aborta a gravação em vez de arriscar.
                    local temBak = false
                    try ( Arq.Copy cfg bak true; temBak = true ) catch ()
                    if not temBak then
                    (
                        format "InLabChecker: não consegui fazer backup do .cuix; não vou gravar\n"
                        resultado = #erro
                        escrever = false
                    )
                    else
                    (
                        xml.load cfg       -- relê já com o flush aplicado
                        a = _analisar xml
                        if a == undefined do ( resultado = #erro; escrever = false )
                    )
                )

                if escrever do
                (
                    local itens = a[1]
                    for it in a[2] do itens.RemoveChild it
                    local novo = xml.createElement "Item"
                    novo.setAttribute "typeID" "2"
                    novo.setAttribute "type" "CTB_MACROBUTTON"
                    novo.setAttribute "width" "0"
                    novo.setAttribute "height" "0"
                    novo.setAttribute "controlID" "0"
                    novo.setAttribute "macroTypeID" "3"
                    novo.setAttribute "macroType" "MB_TYPE_ACTION"
                    novo.setAttribute "actionTableID" "647394"
                    novo.setAttribute "imageID" "-1"
                    novo.setAttribute "imageName" ""
                    novo.setAttribute "actionID" INLAB_TOOLBAR_ACTIONID
                    itens.AppendChild novo

                    if recarregar then
                    (
                        local ok = true
                        try
                        (
                            xml.save cfg
                            cui.loadConfig cfg
                        )
                        catch
                        (
                            ok = false
                            format "InLabChecker: falha ao gravar/recarregar o .cuix (%)\n" (getCurrentException() as string)
                            try ( if doesFileExist bak do ( Arq.Copy bak cfg true; cui.loadConfig cfg ) ) catch ()
                        )
                        if ok do
                        (
                            try ( colorMan.reInitIcons() ) catch ()
                            try ( colorMan.repaintUI #repaintAll ) catch ()
                        )
                        try ( if doesFileExist bak do Arq.Delete bak ) catch ()
                        resultado = if ok then #adicionado else #erro
                    )
                    else
                    (
                        xml.save cfg   -- só edita o arquivo, não toca na UI
                        resultado = #adicionado
                    )
                )
            )
        )
    )
    catch
    (
        format "InLabChecker: erro ao garantir o botão da toolbar (%)\n" (getCurrentException() as string)
        resultado = #erro
    )
    resultado
)

-- No boot/instalação (não no teste): garante o botão e limpa o .ini órfão que a
-- antiga janela flutuante deixava.
if (INLAB_TOOLBAR_SO_DEFINIR != true) do
(
    InLab_GarantirBotaoToolbar()
    try
    (
        local iniVelho = (getDir #userStartupScripts) + "\\inlabchecker_barra.ini"
        if doesFileExist iniVelho do deleteFile iniVelho
    )
    catch ()
)
