/*
================================================================================
 familias\familia_estrutura_estofado.ms
 Fonte: Spec Funcional v2.0 — seções 2.1 / 2.3 / 3.2 (V-35, V-37)
--------------------------------------------------------------------------------
 Estrutura + Estofado · Lote 1 · sem animação
 Particularidades:
   - Palha/trama → V-35 (Opacity + 2-Sided → alphaMode BLEND + doubleSided).
   - Estofado → V-37 (zonas de acabamento por Material ID; advertência).
================================================================================
*/

global cfgEstruturaEstofado = FamiliaConfig()
cfgEstruturaEstofado.nome             = "estrutura_estofado"
cfgEstruturaEstofado.lote             = 1
cfgEstruturaEstofado.animado          = false
cfgEstruturaEstofado.animationType    = ""
cfgEstruturaEstofado.pivotRule        = ""
cfgEstruturaEstofado.maxFileMB        = 15                     -- V-01
cfgEstruturaEstofado.maxSkpMB         = undefined
cfgEstruturaEstofado.polyMin          = 80000                  -- V-03/04
cfgEstruturaEstofado.polyMax          = 150000
cfgEstruturaEstofado.drawCallsRule    = "1 por parte"          -- V-05
cfgEstruturaEstofado.requiresInterior = false
cfgEstruturaEstofado.tampoAcessorio   = false
cfgEstruturaEstofado.materialTypes    = #("zona_acabamento", "palha")   -- V-37 + V-35
cfgEstruturaEstofado.validNames       = #()

InLab_RegistrarFamilia cfgEstruturaEstofado
