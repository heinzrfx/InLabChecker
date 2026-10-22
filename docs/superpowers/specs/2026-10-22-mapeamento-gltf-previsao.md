# Previsão: mapeamento que muda de sentido na conversão para glTF

**Data:** 22/10/2026
**Situação:** só documentado. Decisão do usuário: **não mexer no código por enquanto**. Fica registrado como possível erro futuro.
**Origem:** relato do time sobre o Banco Monzon ("mudou o sentido em uma parte" depois de converter para glTF). Até esta data, o .max do time não tinha chegado para análise. Os Monzon locais (piloto e biblioteca) não têm a versão preparada.

## O que foi confirmado no Max (cenas de teste, não no Monzon)

### 1. O Real World Fix ignora a rotação do CoronaTriplanar

`InLab_RWF_GizmoTriplanar` (`functions/fn_realworldfix.ms`) monta o gizmo do UVW Box só com `rotateZMatrix 180` e o `offset` do Triplanar. A propriedade `rotation` não entra; `InLab_RWF_TriplanarSuportado` só loga um aviso.

Teste: cubos com Triplanar girado (Z 90° e X 45°), render Corona antes do RWF, depois do RWF e depois da conversão. Depois do RWF, as listras mudaram de sentido. A conversão manteve o resultado do RWF, então o glTF sai com o sentido errado.

Renders na pasta temp do Max: `inlab_tri_antes.png`, `inlab_tri_depois_rwf.png`, `inlab_tri_depois_gltf.png`.

### 2. A conversão de material perde rotação, espelho e "sem repetir" do bitmap

`InLab_TransformDoBitmap` e `InLab_AplicarTransform` (`functions/fn_material_convert.ms`) só copiam tiling U/V, offset U/V e canal. Ficam para trás:

- a rotação: `coords.W_angle` / `U_Angle` / `V_Angle` do Bitmaptexture, e `wAngle` / `uAngle` do CoronaBitmap;
- o espelho: `U_Mirror` / `V_Mirror`;
- o "sem repetir": `U_Tile` / `V_Tile` e o `tilingU` / `tilingV` do CoronaBitmap;
- o recorte (clipping/crop).

Teste: bitmap com W 90° voltou para 0, e o espelho voltou para false.

Tudo isso tem saída no glTF. O exportador do Max 2024 grava a rotação do `W_angle` em `KHR_texture_transform` (90° vira `rotation` 1.5708) e o `U_Mirror` em `wrapS` 33648 (`MIRRORED_REPEAT`). Copiar esses valores na conversão resolveria.

## Correção proposta (quando for retomada)

1. O RWF passa a levar a rotação do Triplanar para o gizmo do UVW Box. Antes disso, medir a ordem e o sinal da rotação do Corona com renders comparados pixel a pixel (X, Y, Z e combinada). Teste em `tests/test_realworldfix.ms`.
2. A conversão passa a copiar para o bitmap do glTF a rotação (W/U/V angle; wAngle/uAngle), o espelho e o "sem repetir".
3. Uma rotação que não dá para converter deixa a peça fora do RWF, e a V-42 acusa.

## Para confirmar a causa no Monzon

Com o .max de antes da conversão, conferir nas peças que mudaram:

- se o material usa CoronaTriplanar com `rotation` diferente de zero (causa 1);
- se algum bitmap tem rotação, espelho ou "sem repetir" (causa 2).

## O que foi feito no mesmo dia

O outro bug do time (produto não convertido para glTF aprovado nas verificações) foi corrigido com a V-43 "Materiais convertidos para glTF", crítica (`verifications/verif_materiais.ms`).
