/*
================================================================================
 functions\fn_realworldscale.ms — FUNÇÃO 4 (Fase 1.2)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Define INLAB_UNIDADE_PADRAO (CENTÍMETROS — confirmado pela equipe em
 Jul/2026), a constante de unidade de sistema que a V-19 usa.

 24/09/2026 (issue #52, limpeza): InLab_VerificarUnidade, InLab_VerificarEscala
 e InLab_FatorParaMetros (diagnóstico/correção de unidade, transform scale e
 bounding box) removidas — código morto, nenhuma chamada em UI/verificação
 (grep confirmou). INLAB_UNIDADE_PADRAO fica: é a base da V-19.
================================================================================
*/

-- ===== CONSTANTES DO PIPELINE =====
global INLAB_UNIDADE_PADRAO = #Centimeters   -- CONFIRMADO pela equipe (base da V-19)
