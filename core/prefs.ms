/*
================================================================================
 core\prefs.ms — preferências persistentes em ini (23/09/2026, issue #10)
--------------------------------------------------------------------------------
 Primeira persistência de preferência do projeto. Até aqui tudo era global em
 memória (ex.: InLab_LadoPainel em ui\rollout_main.ms), perdido a cada reload
 e a cada vez que o Max fecha.

 ONDE FICA O INI: (getDir #plugcfg) + "\InLabChecker.ini" — FORA da pasta do
 plugin, DE PROPÓSITO. O updater (issue #13) aplica a versão nova renomeando
 INLAB_ROOT inteiro. Preferência guardada dentro da pasta do plugin morreria a
 cada atualização: o artista desliga o auto-update, atualiza uma vez, e ele
 volta ligado sozinho. #plugcfg é por usuário e não é tocado pelo update.

 API genérica (chave/valor, não uma função por preferência), numa seção só
 ([InLabChecker]):
   InLab_PrefLer chave padrao   → string gravada, ou `padrao` (sem conversão)
                                  quando a chave não existe. Não dá erro se o
                                  ini ainda não existe (primeira execução).
   InLab_PrefGravar chave valor → grava `valor as string`; devolve true/false.
   InLab_PrefApagar chave       → remove a chave (usado pelos testes).
   InLab_PrefArquivo()          → caminho do ini.

 Tudo volta como STRING: quem lê converte ("true"/"false" → booleano etc.).
 A ausência é testada com hasINISetting, não com o "" de getINISetting, para
 que um valor gravado vazio não vire o padrão.

 Chaves previstas pela spec do updater: autoCheck ("true"/"false"),
 ultimaChecagem (timestamp), versaoIgnorada.
================================================================================
*/

global InLab_Log  -- core\log.ms carrega depois; resolvido na chamada
global INLAB_PREFS_SECAO = "InLabChecker"

fn InLab_PrefArquivo = (getDir #plugcfg) + "\\InLabChecker.ini"

fn InLab_PrefLer chave padrao =
(
    local arq = InLab_PrefArquivo()
    local r = padrao
    try
    (
        if (doesFileExist arq) and (hasINISetting arq INLAB_PREFS_SECAO chave) do
            r = getINISetting arq INLAB_PREFS_SECAO chave
    )
    catch
        InLab_Log ("Preferências: falha ao ler '" + chave + "' (" + getCurrentException() + "). Usando o padrão.") tipo:#warn
    r
)

fn InLab_PrefGravar chave valor =
(
    local ok = false
    try
    (
        ok = setINISetting (InLab_PrefArquivo()) INLAB_PREFS_SECAO chave (valor as string)
        if not ok do
            InLab_Log ("Preferências: não gravou '" + chave + "' em " + InLab_PrefArquivo() + ".") tipo:#warn
    )
    catch
        InLab_Log ("Preferências: falha ao gravar '" + chave + "' (" + getCurrentException() + ").") tipo:#err
    ok
)

fn InLab_PrefApagar chave =
(
    local arq = InLab_PrefArquivo()
    local r = false
    try ( if doesFileExist arq do r = delIniSetting arq INLAB_PREFS_SECAO chave )
    catch ( InLab_Log ("Preferências: falha ao apagar '" + chave + "' (" + getCurrentException() + ").") tipo:#warn )
    r
)
