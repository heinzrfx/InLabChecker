/*
================================================================================
 familias\familia_translacao.ms
 Fonte: Spec Funcional v2.0 — seções 2.1 / 2.3 / 3.3 (V-30, V-39, V-40) / 4
--------------------------------------------------------------------------------
 Translação · Lote 2 · ANIMADA (gavetas)
 Particularidades:
   - Pivot: face frontal interna da gaveta, eixo Y (V-27).
   - Interior modelado obrigatório em partes que abrem (V-39, advertência).
   - Estado inicial fechado (V-40, advertência).
================================================================================
*/

global cfgTranslacao = FamiliaConfig()
cfgTranslacao.nome             = "translacao"
cfgTranslacao.lote             = 2
cfgTranslacao.animado          = true                              -- V-30: exige keyframes no arquivo
cfgTranslacao.animationType    = "translacao"
cfgTranslacao.pivotRule        = "face_frontal_interna_gaveta"     -- V-27 · eixo Y
cfgTranslacao.maxFileMB        = 20                                -- V-01
cfgTranslacao.maxSkpMB         = undefined
cfgTranslacao.polyMin          = 100000                            -- V-03/04
cfgTranslacao.polyMax          = 200000
cfgTranslacao.drawCallsRule    = "1 por parte"                     -- V-05 (considera partes animadas sincronizadas)
cfgTranslacao.requiresInterior = true                              -- V-39
cfgTranslacao.tampoAcessorio   = false
cfgTranslacao.materialTypes    = #()
cfgTranslacao.validNames       = #()

InLab_RegistrarFamilia cfgTranslacao
