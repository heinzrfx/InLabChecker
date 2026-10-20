/*
================================================================================
 install\instalar.ms — instalador do .mzp (13/10/2026)
--------------------------------------------------------------------------------
 Roda quando o artista arrasta InLabChecker-v<versão>.mzp para o viewport (ou
 abre pelo Scripting > Run Script). O mzp.run extrai o pacote numa pasta
 temporária e chama este arquivo de lá. Substitui os passos 2 a 6 do
 install\README.md, que eram feitos à mão.

 O QUE FAZ
 1. Copia o pacote extraído para (getDir #userScripts)\InLabChecker.novo.
 2. Se já há uma instalação, ela vira InLabChecker.bak (o mesmo .bak do
    updater: o "Reverter" do painel volta para ela). O .bak anterior é apagado.
 3. Põe o .novo no lugar. Falha aqui desfaz a troca e mantém a instalação
    antiga.
 4. Copia install\inlabchecker_boot.ms para (getDir #userStartupScripts).
 5. Roda install\registrar.ms (macro do botão + ícone + o botão na barra) e
    abre o painel.

 BOTÃO NA BARRA SOZINHO (16/10/2026): o registrar.ms agora injeta o botão na
 Main Toolbar nativa (InLab_GarantirBotaoToolbar), então não há mais o passo
 manual do Customize User Interface — o aviso final só diz que o botão já está lá.

 20/10/2026: o aviso final confere o botão (InLab_GarantirBotaoToolbar) em vez
 de afirmar que ele está na barra. No Max 2025 recém-instalado a injeção falhava
 (cuix em Program Files, ver registrar.ms) e o aviso dizia que tinha dado certo.

 Pasta de checkout (com .git) no destino: não instala por cima, igual ao
 updater (InLab_UpdateEhCheckout).

 Teste automatizado: INLAB_INSTALAR_SILENCIOSO = true pula os messageBox (que
 travam o Max) e INLAB_INSTALAR_DESTINO troca a pasta de destino. O resultado
 ("" ou a causa da falha) fica em INLAB_INSTALAR_RESULTADO.
================================================================================
*/
global INLAB_INSTALAR_SILENCIOSO, INLAB_INSTALAR_DESTINO, INLAB_INSTALAR_RESULTADO
global InLab_GarantirBotaoToolbar -- definido pelo install\registrar.ms no meio do bloco
(
    local Dir = dotNetClass "System.IO.Directory"
    local Arq = dotNetClass "System.IO.File"
    local silencioso = (INLAB_INSTALAR_SILENCIOSO == true)

    fn semBarra p = ( if p.count > 0 and p[p.count] == "\\" then substring p 1 (p.count - 1) else p )

    -- Cópia recursiva (o .NET não tem Directory.Copy).
    fn copiarArvore Dir Arq de para =
    (
        Dir.CreateDirectory para
        for f in (Dir.GetFiles de) do Arq.Copy f (para + "\\" + (filenameFromPath f)) true
        for d in (Dir.GetDirectories de) do
            copiarArvore Dir Arq d (para + "\\" + (filenameFromPath d))
    )

    local origem = semBarra (pathConfig.removePathLeaf (semBarra (getFilenamePath (getSourceFileName()))))
    local destino = if INLAB_INSTALAR_DESTINO != undefined then semBarra INLAB_INSTALAR_DESTINO else ((getDir #userScripts) + "\\InLabChecker")
    local novo = destino + ".novo"
    local bak = destino + ".bak"
    local causa = ""
    local passo = ""
    local antigoParaBak = false
    local botaoNaBarra = false

    -- Versão do pacote, só para as mensagens (lida do core\versao.ms).
    local versao = "?"
    try
    (
        local f = openFile (origem + "\\core\\versao.ms") mode:"rt"
        while not eof f do
        (
            local l = readLine f
            if matchPattern l pattern:"global INLAB_VERSAO*" do
            (
                local partes = filterString l "\""
                if partes.count >= 2 do versao = partes[2]
            )
        )
        close f
    )
    catch ()

    if not (doesFileExist (origem + "\\InLabChecker.ms")) then
        causa = "pacote incompleto: InLabChecker.ms não está em " + origem + "."
    else if Dir.Exists (destino + "\\.git") then
        causa = destino + " é uma cópia do repositório (tem .git). Não instalo por cima dela."

    if causa == "" do
    (
        try
        (
            passo = "copiar os arquivos para " + novo
            if Dir.Exists novo do Dir.Delete novo true
            copiarArvore Dir Arq origem novo
            if doesFileExist (novo + "\\mzp.run") do deleteFile (novo + "\\mzp.run")

            if Dir.Exists destino do
            (
                passo = "apagar a cópia anterior " + bak
                if Dir.Exists bak do Dir.Delete bak true
                passo = "guardar a instalação atual em " + bak
                Dir.Move destino bak
                antigoParaBak = true
            )
            passo = "pôr a versão nova em " + destino
            Dir.Move novo destino
        )
        catch
        (
            causa = "falha ao " + passo + " (" + getCurrentException() + ")."
            try ( if antigoParaBak and not (Dir.Exists destino) do Dir.Move bak destino ) catch ()
            try ( if Dir.Exists novo do Dir.Delete novo true ) catch ()
        )
    )

    if causa == "" do
    (
        try
        (
            passo = "copiar o script de startup"
            local dirStartup = getDir #userStartupScripts
            Dir.CreateDirectory dirStartup
            Arq.Copy (destino + "\\install\\inlabchecker_boot.ms") (dirStartup + "\\inlabchecker_boot.ms") true
            -- O registrar.ms registra o botão a partir de (getDir #userScripts)\InLabChecker.
            -- Com destino de teste, o painel abre direto pelo entry point.
            passo = "registrar o botão"
            fileIn (destino + "\\install\\registrar.ms")
            -- O registrar já tentou pôr o botão; a 2ª chamada só lê o .cuix e diz
            -- se ele está lá (#jaExistia) ou tenta de novo.
            passo = "conferir o botão na barra"
            local rBotao = InLab_GarantirBotaoToolbar()
            botaoNaBarra = (rBotao == #jaExistia or rBotao == #adicionado)
            if not botaoNaBarra do format "InLabChecker: botão não foi para a barra (%)\n" rBotao
            passo = "abrir o painel"
            fileIn (destino + "\\InLabChecker.ms")
        )
        catch
            causa = "os arquivos foram instalados, mas falhou ao " + passo + " (" + getCurrentException() + ")."
    )

    INLAB_INSTALAR_RESULTADO = causa
    if causa == "" then
    (
        format "InLabChecker v% instalado em %\n" versao destino
        if not silencioso do
            messageBox ("InLabChecker v" + versao + " instalado.\n\n" + \
                (if botaoNaBarra then
                    "O botão da lâmpada já está na barra de ferramentas do Max.\nClique nele para abrir o painel."
                else
                    "O botão da lâmpada não entrou na barra agora. Feche e abra o Max:\nna abertura ele é colocado lá.")) title:"InLabChecker"
    )
    else
    (
        format "InLabChecker: instalação falhou: %\n" causa
        if not silencioso do
            messageBox ("A instalação do InLabChecker falhou:\n\n" + causa + "\n\nMande esta mensagem para quem cuida do plugin.") title:"InLabChecker"
    )
    causa
)
