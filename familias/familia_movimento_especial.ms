/*
================================================================================
 familias\familia_movimento_especial.ms
 Fonte: Spec Funcional v2.0 — seções 2.1 / 2.3 / 3.2 (V-35) / 3.3 (V-32) / 4
--------------------------------------------------------------------------------
 Movimento Especial · Lote 2 · ANIMADA (balanços, reclináveis)
 Particularidades:
   - DOIS subtipos de pivot na mesma família (tabela seção 4 da spec):
       balanço    → ponto de suspensão elevado, eixo Y oscila (V-32; ref. MAUI ≈ 3.0 m)
       reclinação → aresta inferior do encosto, eixo X (V-32b)
     A resolução por subclasse acontece em verif_pivot.ms (Fase 4).
   - Palha/trama → V-35 · Estofado → V-37 · Estado inicial de repouso → V-40.
================================================================================
*/

global cfgMovimentoEspecial = FamiliaConfig()
cfgMovimentoEspecial.nome             = "movimento_especial"
cfgMovimentoEspecial.lote             = 2
cfgMovimentoEspecial.animado          = true                                        -- V-30
cfgMovimentoEspecial.animationType    = "movimento_especial"
cfgMovimentoEspecial.pivotRule        = "ponto_suspensao | aresta_inferior_encosto" -- V-32 / V-32b
cfgMovimentoEspecial.maxFileMB        = 20                                          -- V-01
cfgMovimentoEspecial.maxSkpMB         = undefined
cfgMovimentoEspecial.polyMin          = 100000                                      -- V-03/04
cfgMovimentoEspecial.polyMax          = 200000
cfgMovimentoEspecial.drawCallsRule    = "1 por parte"                               -- V-05
cfgMovimentoEspecial.requiresInterior = false
cfgMovimentoEspecial.tampoAcessorio   = false
cfgMovimentoEspecial.materialTypes    = #("zona_acabamento", "palha")               -- V-37 + V-35
cfgMovimentoEspecial.validNames       = #()

InLab_RegistrarFamilia cfgMovimentoEspecial
