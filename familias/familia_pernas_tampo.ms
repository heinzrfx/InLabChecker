/*
================================================================================
 familias\familia_pernas_tampo.ms
 Fonte: Spec Funcional v2.0 — seções 2.1 / 2.3 / 3.2 (V-36) / 3.4 (V-38)
--------------------------------------------------------------------------------
 Pernas + Tampo · Lote 1 · sem animação
 Particularidades:
   - Limites de peso e polígono são POR BLOCO (estrutura e tampo separados).
   - Material de cristal → V-36 (Transmission, não Opacity).
   - tampoAcessorio: false por padrão. É uma propriedade do PRODUTO, não da
     família inteira — precisará de toggle na UI quando a V-38 for
     implementada (decisão registrada na entrega da Fase 0).
================================================================================
*/

global cfgPernasTampo = FamiliaConfig()
cfgPernasTampo.nome             = "pernas_tampo"
cfgPernasTampo.lote             = 1
cfgPernasTampo.animado          = false
cfgPernasTampo.animationType    = ""
cfgPernasTampo.pivotRule        = ""
cfgPernasTampo.maxFileMB        = 12                           -- V-01 · POR BLOCO
cfgPernasTampo.maxSkpMB         = undefined                    -- sem limite SKP na tabela da spec
cfgPernasTampo.polyMin          = 40000                        -- V-03/04 · POR BLOCO
cfgPernasTampo.polyMax          = 100000
cfgPernasTampo.drawCallsRule    = "1 estrutura + 1 tampo"      -- V-05
cfgPernasTampo.requiresInterior = false
cfgPernasTampo.tampoAcessorio   = false                        -- V-38 · toggle por produto (ver cabeçalho)
cfgPernasTampo.materialTypes    = #("cristal")                 -- V-36
cfgPernasTampo.validNames       = #()

InLab_RegistrarFamilia cfgPernasTampo
