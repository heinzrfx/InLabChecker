/*
================================================================================
 familias\familia_corpo_portas_gavetas.ms
 Fonte: arquétipo 4 de Arquetipos_Modelagem_FAST.md (Bianca, 02/10/2026);
        limites da spec de Buffet v1.0 (20 MB, 100k–200k)
--------------------------------------------------------------------------------
 Corpo + Portas/Gavetas · Lote 1 · sem animação no v1
 Classes: Buffet, Caixa Bar, Cômoda, Escrivaninha, Estante, Mesa de
 Cabeceira, Móvel Bar, Vanity Desk.

 05/10/2026: criada. Limites decididos pelo usuário, provisórios (referência
 do piloto, como as outras famílias): 20 MB, 100k–200k triângulos e 20 draw
 calls — o mesmo teto de Translação, que é a versão animada deste arquétipo.
 Sem limite SKP, como as outras famílias da v2.0.
 Particularidades:
   - Caixaria: as partes que abrem contam como blocos. No v1 o produto
     animado entra como estático, então interior modelado (V-39) e pivot de
     gaveta/porta (V-27/28) ficam para Translação/Rotação no v2.
================================================================================
*/

global cfgCorpoPortasGavetas = FamiliaConfig()
cfgCorpoPortasGavetas.nome             = "corpo_portas_gavetas"
cfgCorpoPortasGavetas.lote             = 1
cfgCorpoPortasGavetas.animado          = false
cfgCorpoPortasGavetas.animationType    = ""
cfgCorpoPortasGavetas.pivotRule        = ""
cfgCorpoPortasGavetas.maxFileMB        = 20                     -- V-01 · provisório
cfgCorpoPortasGavetas.maxSkpMB         = undefined
cfgCorpoPortasGavetas.polyMin          = 100000                 -- V-03 · provisório
cfgCorpoPortasGavetas.polyMax          = 200000
cfgCorpoPortasGavetas.drawCallsRule    = "1 por parte"          -- V-05
cfgCorpoPortasGavetas.maxDrawCalls     = 20  -- V-05 · provisório (igual a Translação)
cfgCorpoPortasGavetas.requiresInterior = false                  -- V-39 é de animado (v2)
cfgCorpoPortasGavetas.tampoAcessorio   = false
cfgCorpoPortasGavetas.materialTypes    = #()

InLab_RegistrarFamilia cfgCorpoPortasGavetas
