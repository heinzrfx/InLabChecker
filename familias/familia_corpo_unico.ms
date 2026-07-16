/*
================================================================================
 familias\familia_corpo_unico.ms
 Fonte: Spec Funcional v2.0 — seções 2.1 / 2.3
--------------------------------------------------------------------------------
 Corpo Único · Lote 1 · sem animação
 Única família com limite de .skp definido na tabela da spec (8 MB).
 LIMITES PROVISÓRIOS — pendem validação com o Birô antes de virarem
 critério de reprovação real (spec, seção 6).
================================================================================
*/

global cfgCorpoUnico = FamiliaConfig()
cfgCorpoUnico.nome             = "corpo_unico"
cfgCorpoUnico.lote             = 1
cfgCorpoUnico.animado          = false
cfgCorpoUnico.animationType    = ""
cfgCorpoUnico.pivotRule        = ""                      -- sem animação; pivot raiz coberto pelas V-17/18 genéricas
cfgCorpoUnico.maxFileMB        = 12                      -- V-01
cfgCorpoUnico.maxSkpMB         = 8                       -- V-02
cfgCorpoUnico.polyMin          = 40000                   -- V-03/04
cfgCorpoUnico.polyMax          = 100000
cfgCorpoUnico.drawCallsRule    = "1 a 2 objetos"         -- V-05 (regra codificada na verificação)
cfgCorpoUnico.requiresInterior = false
cfgCorpoUnico.tampoAcessorio   = false
cfgCorpoUnico.materialTypes    = #()                     -- sem materiais especiais mapeados
cfgCorpoUnico.validNames       = #()                     -- pendente nomenclatura oficial (V-20 em advertência)

-- Inscreve a config no registro global consumido pela UI.
InLab_RegistrarFamilia cfgCorpoUnico
