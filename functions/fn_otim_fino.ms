/*
================================================================================
 functions\fn_otim_fino.ms — Otimização · passo 2 · Ajuste fino
--------------------------------------------------------------------------------
 23/09/2026 (issue #60): versão PROVISÓRIA. Faz o que o botão antigo do
 ProOptimizer fazia (percentual ÚNICO calculado pela meta), agora como uma
 linha por peça na lista de revisão, para a seção Otimização nunca ficar sem
 ferramenta. A issue #62 troca o conteúdo deste arquivo pela meta por peça
 com proteções (spec 2026-09-23-otimizacao-design.md, seção 3.3).
 Usa InLab_ProOptimizer / InLab_ReverterOtimizacao de fn_prooptimizer.ms.
 Contrato: ver o cabeçalho de functions\fn_otim_nucleo.ms.

 `global` antes de cada fn (mesmo já declarada em fn_otim_nucleo.ms): este
 arquivo pode ser carregado sozinho por InLab_RecarregarPlugin() — padrão de
 functions\fn_renomear_produto.ms.
================================================================================
*/

global InLab_OtimFino_Calcular
fn InLab_OtimFino_Calcular objs =
(
    local geo = for o in objs where InLab_EhGeometria o collect o
    local total = InLab_Otim_Triangulos geo
    local alvo = InLab_Otim_AlvoSelecao geo (InLab_Otim_Faixa())
    if alvo == undefined then
    (
        InLab_Log "Ajuste fino: escolha a família (seção Produto) ou digite a meta." tipo:#warn
        #()
    )
    else if total == 0 or total <= alvo then
    (
        InLab_Log ("Ajuste fino: a seleção já cabe na meta (" + (InLab_Otim_Milhar total) + " triângulos).") tipo:#ok
        #()
    )
    else
    (
        local pct = amax 1.0 (100.0 * alvo / total)
        for o in geo collect
        (
            local t = InLab_Otim_Triangulos #(o)
            local depois = (t * pct / 100.0) as integer
            OtimProposta no:o alvo:o prop:#VertexPercent antes:100.0 depois:pct trisAntes:t trisDepois:depois \
                rotulo:(o.name + "  ·  " + (formattedPrint pct format:".0f") + "%  ·  " + (InLab_Otim_Milhar t) + " → " + (InLab_Otim_Milhar depois)) \
                motivo:"percentual único (provisório até a issue #62)"
        )
    )
)

global InLab_OtimFino_Aplicar
fn InLab_OtimFino_Aplicar propostas =
(
    local marcadas = for p in propostas where p.marcada and isValidNode p.no collect p
    if marcadas.count == 0 then
    (
        InLab_Log "Ajuste fino: nenhuma peça marcada." tipo:#warn
        0
    )
    else InLab_ProOptimizer (for p in marcadas collect p.no) marcadas[1].depois
)

-- InLab_ReverterOtimizacao() devolve o texto do InLab_Log, não um inteiro —
-- o contrato (InLab_Otim_Reverter passo -> integer) exige a CONTAGEM. Lê
-- InLab_UltimaOtimizacao ANTES de reverter, porque a própria função zera
-- esse array no final (ver fn_prooptimizer.ms).
global InLab_OtimFino_Reverter
fn InLab_OtimFino_Reverter =
(
    local n = InLab_UltimaOtimizacao.count
    InLab_ReverterOtimizacao()
    n
)

-- Liga/desliga na viewport os ProOptimizer do último Aplicar (Comparar).
global InLab_OtimFino_Comparar
fn InLab_OtimFino_Comparar ligar =
(
    local n = 0
    for r in InLab_UltimaOtimizacao where r.modificador != undefined do
    (
        try ( r.modificador.enabledInViews = ligar; n += 1 )
        catch ( InLab_Log ("Comparar: não alternou o ProOptimizer de um objeto (" + getCurrentException() + ").") tipo:#warn )
    )
    n
)
