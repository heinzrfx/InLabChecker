/*
================================================================================
 functions\fn_otim_escondidas.ms — Otimização · passo 3 · Faces escondidas
--------------------------------------------------------------------------------
 23/09/2026 (issue #60): versão MÍNIMA, só para a tela e o manifesto já
 existirem. A issue #63 troca o conteúdo deste arquivo pelo passo de verdade
 (spec 2026-09-23-otimizacao-design.md, seções 3.4 e 5), sem mexer na UI.
 Contrato: ver o cabeçalho de functions\fn_otim_nucleo.ms.

 `global` antes de cada fn (mesmo já declarada em fn_otim_nucleo.ms): este
 arquivo pode ser carregado sozinho por InLab_RecarregarPlugin() — padrão de
 functions\fn_renomear_produto.ms.
================================================================================
*/

global InLab_OtimEscondidas_Calcular
fn InLab_OtimEscondidas_Calcular objs =
(
    InLab_Log "Faces escondidas: em construção (issue #63)." tipo:#info
    #()
)

global InLab_OtimEscondidas_Aplicar
fn InLab_OtimEscondidas_Aplicar propostas =
(
    InLab_Log "Faces escondidas: em construção (issue #63)." tipo:#info
    0
)

global InLab_OtimEscondidas_Reverter
fn InLab_OtimEscondidas_Reverter =
(
    InLab_Log "Faces escondidas: nada a reverter." tipo:#info
    0
)
