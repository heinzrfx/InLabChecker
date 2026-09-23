/*
================================================================================
 install\registrar.ms — registra o botão do InLabChecker na abertura do Max
 (23/09/2026)
--------------------------------------------------------------------------------
 Chamado pelo install\inlabchecker_boot.ms (pasta startup) a cada abertura do
 Max. NÃO carrega o plugin e NÃO abre o painel: o painel abre só no clique do
 botão "InLabChecker" da barra de ferramentas (pedido da equipe, 23/09/2026 —
 até a v0.12 o boot abria o painel sozinho).

 O QUE FAZ
 1. Copia a arte do ícone (ui\img\InLabChecker_16i.bmp e _24i.bmp, a lâmpada
    âmbar do logo sobre o fundo da barra) para (getDir #userIcons), se faltar
    ou tiver mudado. Ver install\instalar_icone.ms para o porquê do formato
    (BMP legado, sem máscara).
 2. Define o macroScript InLabChecker_Abrir (categoria "InLab"), o MESMO nome
    e categoria do install\instalar_icone.ms: um botão que já esteja numa barra
    continua funcionando, e passa a apontar para a pasta INSTALADA. O macro do
    instalar_icone.ms embutia a raiz de quem o rodou (o repositório, no caso do
    desenvolvedor); este usa (getDir #userScripts)\InLabChecker\ na hora do
    clique.
 3. No clique: se o plugin já está carregado (InLab_AbrirUI existe), só reabre
    o painel; senão, faz fileIn do entry point, que carrega e abre.

 FORA DO MANIFESTO (não é módulo do plugin), mas DENTRO DO ZIP da release:
 mora na pasta do plugin para o updater poder trocar esta lógica numa versão
 nova. O boot, que o artista copia à mão, só faz fileIn deste arquivo e fica
 estável.

 O ícone copiado na abertura só aparece na barra na abertura SEGUINTE do Max:
 a barra é desenhada antes dos scripts de startup rodarem.
================================================================================
*/
(
    local raiz = (getDir #userScripts) + "\\InLabChecker\\"
    local fileIO = dotNetClass "System.IO.File"
    for nome in #("InLabChecker_16i.bmp", "InLabChecker_24i.bmp") do
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
