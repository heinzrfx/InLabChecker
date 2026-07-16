/*
================================================================================
 report\report_generator.ms — Fase 5 (formato texto na UI/log)
--------------------------------------------------------------------------------
 Consome o coletor InLab_VerifResults (as linhas individuais já foram logadas
 pela fábrica durante a execução) e emite o VEREDITO:
 aprovado = 100% dos itens critico:true em #pass. Advertências não bloqueiam.
 Formatos adicionais (HTML/PDF) ficam para a Fase 6, conforme o plano.
================================================================================
*/

fn InLab_GerarRelatorio cfg =
(
    local nPass = 0
    local nFail = 0
    local nWarn = 0
    for r in InLab_VerifResults do
        case r.status of
        (
            #pass:    nPass += 1
            #fail:    nFail += 1
            #warning: nWarn += 1
        )

    local aprovado = InLab_AprovacaoFinal()
    InLab_Log "=============== RELATÓRIO FINAL ==============="
    InLab_Log ("Família: " + cfg.nome + " · " + (nPass + nFail + nWarn) as string + " verificações executadas")
    InLab_Log ("PASS: " + nPass as string + " · FAIL: " + nFail as string + " · ADVERTÊNCIA: " + nWarn as string)
    if aprovado then
        InLab_Log "RESULTADO: APROVADO — todos os itens críticos passaram." tipo:#ok
    else
        InLab_Log "RESULTADO: REPROVADO — corrigir os itens FAIL listados acima." tipo:#err
    InLab_Log "==============================================="
    aprovado
)
