/*
================================================================================
 core\versao.ms — versão única do plugin (23/09/2026, issue #9)
--------------------------------------------------------------------------------
 INLAB_VERSAO é a ÚNICA fonte da versão do InLabChecker. Antes ela estava
 escrita à mão em 4 lugares e já tinha divergido (entry point v0.11, rollout e
 log v0.10). O título do rollout, a linha de sessão do log e a versão inicial
 da pastilha do header passam a ler daqui.

 Primeiro item de INLAB_MODULOS: tem que valer antes de qualquer outro módulo,
 porque a LEGENDA de InLabChecker_Rollout é avaliada quando rollout_main.ms
 é carregado (testado no Max 2024: `rollout r ("... v" + GLOBAL)` aceita a
 expressão, desde que a global já tenha valor naquele momento).

 Para subir a versão: mudar SÓ a string abaixo. A tag da release no GitHub é
 "v" + INLAB_VERSAO.

 InLab_CompararVersao a b → -1 (a < b) | 0 (iguais) | 1 (a > b)
   Compara componente a componente COMO NÚMERO, nunca como string: em string
   "0.9" > "0.10", e o updater pararia de oferecer atualização exatamente na
   virada de dezena, sem erro nenhum no log. Aceita e descarta um "v"/"V"
   inicial (a tag do GitHub tem, a constante não). Componente que falta vale 0
   ("1.2" == "1.2.0"); componente não numérico também vale 0.
================================================================================
*/

global INLAB_VERSAO = "0.12"

fn InLab_VersaoComponentes v =
(
    local s = trimLeft (trimRight (v as string))
    if s.count > 0 and (s[1] == "v" or s[1] == "V") do s = substring s 2 -1
    for p in (filterString s ".") collect
    (
        local n = p as integer
        if n == undefined then 0 else n
    )
)

fn InLab_CompararVersao a b =
(
    local ca = InLab_VersaoComponentes a
    local cb = InLab_VersaoComponentes b
    local r = 0
    for i = 1 to (amax ca.count cb.count) while r == 0 do
    (
        local x = if i <= ca.count then ca[i] else 0
        local y = if i <= cb.count then cb[i] else 0
        if x < y then r = -1
        else if x > y do r = 1
    )
    r
)
