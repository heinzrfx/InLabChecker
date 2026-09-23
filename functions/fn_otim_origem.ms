/*
================================================================================
 functions\fn_otim_origem.ms — Otimização · passo 1 · Reduzir na origem
--------------------------------------------------------------------------------
 23/09/2026 (issue #60): versão MÍNIMA, só para a tela e o manifesto já
 existirem. A issue #61 troca o conteúdo deste arquivo pelo passo de verdade
 (spec 2026-09-23-otimizacao-design.md, seção 3.2), sem mexer na UI.
 Contrato: ver o cabeçalho de functions\fn_otim_nucleo.ms.

 `global` antes de cada fn (mesmo já declarada em fn_otim_nucleo.ms): este
 arquivo pode ser carregado sozinho por InLab_RecarregarPlugin() — padrão de
 functions\fn_renomear_produto.ms.
================================================================================
*/

global InLab_OtimOrigem_Calcular
fn InLab_OtimOrigem_Calcular objs =
(
    InLab_Log "Reduzir na origem: em construção (issue #61)." tipo:#info
    #()
)

global InLab_OtimOrigem_Aplicar
fn InLab_OtimOrigem_Aplicar propostas =
(
    InLab_Log "Reduzir na origem: em construção (issue #61)." tipo:#info
    0
)

global InLab_OtimOrigem_Reverter
fn InLab_OtimOrigem_Reverter =
(
    InLab_Log "Reduzir na origem: nada a reverter." tipo:#info
    0
)
