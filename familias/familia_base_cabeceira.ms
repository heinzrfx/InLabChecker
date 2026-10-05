/*
================================================================================
 familias\familia_base_cabeceira.ms
 Fonte: arquétipo 5 de Arquetipos_Modelagem_FAST.md (Bianca, 02/10/2026)
--------------------------------------------------------------------------------
 Base + Cabeceira · Lote 1 · sem animação
 Classes: Cama, Bicama. Estrado/base + cabeceira (+ estofado quando houver).

 05/10/2026: criada. Nenhuma spec tem número para cama: os limites foram
 decididos pelo usuário, provisórios (referência do piloto). Partem de
 Estrutura + Estofado, esticados para o tamanho de uma cama: 18 MB (teto de
 Estrutura Modular), 80k–180k triângulos e 12 draw calls (entre Estofado,
 10, e Modular, 16).
 Particularidades:
   - Cabeceira/base estofada → V-37 (zonas de acabamento por Material ID;
     advertência).
================================================================================
*/

global cfgBaseCabeceira = FamiliaConfig()
cfgBaseCabeceira.nome             = "base_cabeceira"
cfgBaseCabeceira.lote             = 1
cfgBaseCabeceira.animado          = false
cfgBaseCabeceira.animationType    = ""
cfgBaseCabeceira.pivotRule        = ""
cfgBaseCabeceira.maxFileMB        = 18                     -- V-01 · provisório
cfgBaseCabeceira.maxSkpMB         = undefined
cfgBaseCabeceira.polyMin          = 80000                  -- V-03 · provisório
cfgBaseCabeceira.polyMax          = 180000
cfgBaseCabeceira.drawCallsRule    = "base + cabeceira, 1 por parte"   -- V-05
cfgBaseCabeceira.maxDrawCalls     = 12  -- V-05 · provisório
cfgBaseCabeceira.requiresInterior = false
cfgBaseCabeceira.tampoAcessorio   = false
cfgBaseCabeceira.materialTypes    = #("zona_acabamento")   -- V-37
cfgBaseCabeceira.validNames       = #()

InLab_RegistrarFamilia cfgBaseCabeceira
