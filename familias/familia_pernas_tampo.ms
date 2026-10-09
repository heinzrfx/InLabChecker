/*
================================================================================
 familias\familia_pernas_tampo.ms
 Fonte: Spec Funcional v2.0 — seções 2.1 / 2.3 / 3.2 (V-36) / 3.4 (V-38)
--------------------------------------------------------------------------------
 Pernas + Tampo · Lote 1 · sem animação
 Particularidades:
   - Limites de peso e polígono são POR BLOCO (estrutura e tampo separados).
   - Material de cristal → V-36 (Transmission, não Opacity). Desde
     09/10/2026 (#145) a V-36 reconhece o vidro pela matéria-prima da parte
     no JSON (familia "Vidro", exceto "Vidro Espelho"), com volta ao nome.
   - tampoAcessorio: false por padrão. É uma propriedade do PRODUTO, não da
     família inteira (decisão da Fase 0). A V-38 já existe e lê o checkbox
     "Produto com tampo acessório" da seção Verificações
     (InLab_TampoAcessorioProduto); este campo só a liga para a família
     inteira.
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
cfgPernasTampo.maxDrawCalls     = 8  -- V-05 · provisório (benchmark 28/09/2026, docs/superpowers/specs/2026-09-28-draw-calls-benchmark.md)
cfgPernasTampo.requiresInterior = false
cfgPernasTampo.tampoAcessorio   = false                        -- V-38 · toggle por produto (ver cabeçalho)
cfgPernasTampo.materialTypes    = #("cristal")                 -- V-36

InLab_RegistrarFamilia cfgPernasTampo
