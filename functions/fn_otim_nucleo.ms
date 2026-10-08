/*
================================================================================
 functions\fn_otim_nucleo.ms — medidor de triângulos da Otimização
--------------------------------------------------------------------------------
 InLab_Otim_Triangulos: triângulos por NÓ (instância conta uma vez por nó,
 como o GLB exporta). É o que o site carrega e não muda antes/depois do
 ProOptimizer (decisão do brainstorm de 23/09/2026). Usado pela V-03
 (verifications\verif_peso_poly.ms), pelo Find Objects
 (functions\fn_utilidades.ms) e pelo ProOptimizer (functions\fn_otim_reduzir.ms).
 InLab_Otim_Milhar: 182340 → "182.340" para o log.

 HISTÓRICO:
 23/09/2026 (issue #60): nasceu como o núcleo da Otimização em 3 passos
 (Reduzir na origem, Ajuste fino, Faces escondidas — spec
 docs\superpowers\specs\2026-09-23-otimizacao-design.md): faixa-alvo, estado
 do medidor, pisos de segurança (INLAB_OTIM_PISOS + "piso_*" no
 InLabChecker.ini), registro de reversão e o despachante
 InLab_Otim_Calcular/Aplicar/Reverter passo.
 08/10/2026 (issue #126, epic #121 — ajustes pós-v1): a Otimização ficou só
 com o ProOptimizer de 30% por clique (fn_otim_reduzir.ms, #124) e os 3
 passos saíram do plugin (fn_otim_origem.ms, fn_otim_fino.ms,
 fn_otim_escondidas.ms e os testes deles; estão no histórico do git). Daqui
 saiu tudo que só eles usavam; ficaram as duas funções abaixo. As chaves
 "piso_*" de um InLabChecker.ini antigo ficam sem efeito.
================================================================================
*/

global InLab_Otim_Triangulos
fn InLab_Otim_Triangulos objs =
(
    local total = 0
    for o in objs where InLab_EhGeometria o do total += (GetTriMeshFaceCount o)[1]
    total
)

-- 182340 → "182.340" (separador de milhar brasileiro).
global InLab_Otim_Milhar
fn InLab_Otim_Milhar n =
(
    local s = (n as integer) as string
    local r = ""
    for i = 1 to s.count do
    (
        r += s[i]
        local resta = s.count - i
        if resta > 0 and (mod resta 3) == 0 do r += "."
    )
    r
)
