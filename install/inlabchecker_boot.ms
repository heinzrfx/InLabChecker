/*
================================================================================
 install\inlabchecker_boot.ms — script de startup (23/09/2026, issue #11)
--------------------------------------------------------------------------------
 ÚNICO arquivo que o artista instala à mão, UMA vez, em
   (getDir #userStartupScripts)
   = %LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\scripts\startup\
 Na abertura do Max, carrega o plugin de
   (getDir #userScripts)\InLabChecker\InLabChecker.ms
 Pasta de usuário: sem admin, sem UAC, e o updater escreve nela livre.

 FORA DO MANIFESTO e FORA DO ZIP da release (vai como anexo separado): o
 updater troca a pasta do plugin, não este arquivo. Fica estável de propósito;
 se mudar, o artista copia de novo. Sem a pasta do plugin, não faz nada.
 Erro na carga vai para o Listener, sem derrubar a abertura do Max.
================================================================================
*/
(
    local entry = (getDir #userScripts) + "\\InLabChecker\\InLabChecker.ms"
    if doesFileExist entry do
        try ( fileIn entry ) catch ( format "InLabChecker: falha ao carregar %\n  %\n" entry (getCurrentException()) )
)
