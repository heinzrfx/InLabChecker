/*
================================================================================
 familias\familia_giro_assento.ms
 Fonte: Spec Funcional v2.0 — seções 2.2 (JSON de exemplo) / 2.3 / 3.3
--------------------------------------------------------------------------------
 Giro de Assento · Lote 2 · ANIMADA
 Esta é a família usada como JSON de exemplo na spec (seção 2.2) — os valores
 abaixo replicam aquele exemplo 1:1.
 Particularidades:
   - V-31: pivot Z do conjunto giratório na ALTURA DO ASSENTO, nunca em Z=0.
     Referências de blocos reais: POLLUX ≈ 0.43 m · CALIX ≈ 0.51 m.
   - V-33: conjunto giratório atachado (1 objeto) + base separada e estática.
   - Estofado → V-37 (zonas de acabamento por Material ID).
================================================================================
*/

global cfgGiroAssento = FamiliaConfig()
cfgGiroAssento.nome             = "giro_assento"
cfgGiroAssento.lote             = 2
cfgGiroAssento.animado          = true                                      -- V-30
cfgGiroAssento.animationType    = "giro_assento"
cfgGiroAssento.pivotRule        = "altura_assento"                          -- V-31 · eixo Z
cfgGiroAssento.maxFileMB        = 15                                        -- V-01
cfgGiroAssento.maxSkpMB         = undefined                                 -- (o JSON de exemplo cita max_skp_mb:10, mas a tabela 2.3 não define SKP p/ esta família — mantido sem limite; confirmar)
cfgGiroAssento.polyMin          = 80000                                     -- V-03/04
cfgGiroAssento.polyMax          = 150000
cfgGiroAssento.drawCallsRule    = "conjunto_giratorio_1 + base_1 + rodizios" -- V-05 / V-33
cfgGiroAssento.requiresInterior = false
cfgGiroAssento.tampoAcessorio   = false
cfgGiroAssento.materialTypes    = #("zona_acabamento")                      -- V-37
cfgGiroAssento.validNames       = #()

InLab_RegistrarFamilia cfgGiroAssento
