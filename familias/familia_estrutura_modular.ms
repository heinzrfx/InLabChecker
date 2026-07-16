/*
================================================================================
 familias\familia_estrutura_modular.ms
 Fonte: Spec Funcional v2.0 — seções 2.1 / 2.3
--------------------------------------------------------------------------------
 Estrutura Modular · Lote 1 · sem animação
 PREMISSA ASSUMIDA (confirmar com a equipe): modulares estofados entram na
 V-37 (zona de acabamento por Material ID) — a spec diz "Lote 1 + Lote 2
 estofados" sem listar famílias. Se a família modular NÃO for estofada,
 esvaziar materialTypes abaixo.
================================================================================
*/

global cfgEstruturaModular = FamiliaConfig()
cfgEstruturaModular.nome             = "estrutura_modular"
cfgEstruturaModular.lote             = 1
cfgEstruturaModular.animado          = false
cfgEstruturaModular.animationType    = ""
cfgEstruturaModular.pivotRule        = ""
cfgEstruturaModular.maxFileMB        = 18                      -- V-01
cfgEstruturaModular.maxSkpMB         = undefined
cfgEstruturaModular.polyMin          = 70000                   -- V-03/04
cfgEstruturaModular.polyMax          = 160000
cfgEstruturaModular.drawCallsRule    = "1 por parte"           -- V-05
cfgEstruturaModular.requiresInterior = false
cfgEstruturaModular.tampoAcessorio   = false
cfgEstruturaModular.materialTypes    = #("zona_acabamento")    -- V-37 · premissa assumida (ver cabeçalho)
cfgEstruturaModular.validNames       = #()

InLab_RegistrarFamilia cfgEstruturaModular
