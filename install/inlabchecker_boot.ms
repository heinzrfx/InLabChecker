/*
================================================================================
 install\inlabchecker_boot.ms — script de startup (23/09/2026, issue #11)
--------------------------------------------------------------------------------
 ÚNICO arquivo que o artista instala à mão, UMA vez, em
   (getDir #userStartupScripts)
   = %LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\scripts\startup\
 Pasta de usuário: sem admin, sem UAC, e o updater escreve nela livre.

 NA ABERTURA DO MAX, NÃO ABRE O PAINEL: só roda
   (getDir #userScripts)\InLabChecker\install\registrar.ms
 que registra o botão "InLabChecker" (categoria InLab) e copia o ícone. O
 painel abre no clique do botão da barra de ferramentas.
 23/09/2026: até aqui o boot fazia fileIn do InLabChecker.ms e o painel abria
 sozinho em toda abertura do Max; a equipe pediu abertura só pelo ícone.

 FORA DO MANIFESTO e FORA DO ZIP da release (vai como anexo separado): o
 updater troca a pasta do plugin, não este arquivo. Por isso a lógica fica no
 registrar.ms, dentro do plugin, e este arquivo não muda. Sem a pasta do
 plugin, não faz nada. Erro vai para o Listener, sem derrubar a abertura.
================================================================================
*/
(
    local reg = (getDir #userScripts) + "\\InLabChecker\\install\\registrar.ms"
    if doesFileExist reg do
        try ( fileIn reg ) catch ( format "InLabChecker: falha ao registrar o botão (%)\n  %\n" reg (getCurrentException()) )
)
