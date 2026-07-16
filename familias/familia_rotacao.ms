/*
================================================================================
 familias\familia_rotacao.ms
 Fonte: Spec Funcional v2.0 — seções 2.1 / 2.3 / 3.3 (V-30, V-39, V-40) / 4
--------------------------------------------------------------------------------
 Rotação · Lote 2 · ANIMADA (portas e pratos giratórios)
 Particularidades:
   - DOIS subtipos de pivot na mesma família (tabela seção 4 da spec):
       porta → aresta da dobradiça, eixo Z (V-28)
       prato → centro geométrico do prato, eixo Z (V-28b)
     A resolução porta vs. prato acontece em verif_pivot.ms (Fase 4);
     o pivotRule abaixo é descritivo e cobre os dois casos.
   - Interior modelado obrigatório (V-39) e estado inicial fechado (V-40).
================================================================================
*/

global cfgRotacao = FamiliaConfig()
cfgRotacao.nome             = "rotacao"
cfgRotacao.lote             = 2
cfgRotacao.animado          = true                                          -- V-30
cfgRotacao.animationType    = "rotacao"
cfgRotacao.pivotRule        = "aresta_dobradica | centro_prato"             -- V-28 / V-28b · eixo Z
cfgRotacao.maxFileMB        = 20                                            -- V-01
cfgRotacao.maxSkpMB         = undefined
cfgRotacao.polyMin          = 100000                                        -- V-03/04
cfgRotacao.polyMax          = 200000
cfgRotacao.drawCallsRule    = "1 por parte"                                 -- V-05
cfgRotacao.requiresInterior = true                                          -- V-39
cfgRotacao.tampoAcessorio   = false
cfgRotacao.materialTypes    = #()
cfgRotacao.validNames       = #()

InLab_RegistrarFamilia cfgRotacao
