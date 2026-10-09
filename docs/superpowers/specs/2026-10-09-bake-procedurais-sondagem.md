# Sondagem: bake de procedurais na conversão (issue #110)

09/10/2026 · Max 2024.2.14 · Corona 12 Update 2 · epic #122.
Pergunta da issue: o `renderMap` da conversão (`InLab_BakeTexmap` / `InLab_BitmapDoTexmap`, `fn_material_convert.ms`) reproduz os procedurais do acervo? Ele sai preto com mapa Corona fora do Corona? E o `CoronaTriplanar`, que é 3D, como fica?

## Material

- **Piloto:** os 64 blocos de `PILOTO PLUGIN INLAB`. **34 abrem no 2024**, e 29 deles têm material Corona/VRay com mapa. Leitura só, nada salvo.
- **Inventário:** cada material usado pelas peças (`InLab_Mat_Uso` + `InLab_Mat_Resolver`) e cada slot que a conversão lê (base color, glossiness, bump, opacidade). Dá **75 materiais e 138 slots com mapa**.
- **Por slot:**
  - classe do mapa de topo e todas as classes da árvore;
  - marcas de "3D": `CoronaTriplanar`, coordenada `StandardXYZGen` e `falloff`;
  - `renderMap` de 64 px duas vezes, com o renderizador da cena e com o Scanline: média RGB, desvio da luminância e fração preta.
- **Arquivos:** cada bitmap dos materiais usados (110), com caminho bruto e caminho resolvido pelos *map paths* (`mapPaths.getFullFilePath`).
- **RWF:** os 14 blocos com Triplanar, antes e depois do `InLab_RealWorldFix`, que o Auto UV roda desde o #129.
- **Tiling depois do RWF:** em todo slot que vai para bake (topo que não é bitmap), o tiling e o offset dos bitmaps da árvore.

## Resultados

### 1. O que existe nos slots

| Slot | Mapa de topo (nº de slots) |
|---|---|
| Base color | CoronaColorCorrect 16 · CoronaBitmap 10 · CoronaColor 10 · **falloff 6** · CoronaMix 3 · Color_Correction 3 · Bitmaptexture 2 · RGB_Multiply 1 |
| Glossiness | **CoronaTriplanar 8** · CoronaMix 8 · CoronaBitmap 7 · Color_Correction 5 · falloff 2 |
| Bump | CoronaNormal 29 · **Noise 9** · Bitmaptexture 8 · CoronaBitmap 8 |
| Opacidade | Bitmaptexture 3 |

- Na árvore: `CoronaTriplanar` em **27 slots**, `Noise` em coordenada 3D (XYZ) em 9 e `falloff` em 9.
- Nenhum mapa "só de render" do Corona (AO, RoundEdges, Curvature, Distance...).
- Os cenas usam três renderizadores: Corona (99 slots), Arnold (23) e Scanline (16).

### 2. "Mapa Corona sai preto fora do Corona": não se confirmou

- O `renderMap` deu **o mesmo resultado com o renderizador da cena e com o Scanline nos 138 slots**, incluindo `CoronaMix`, `CoronaColorCorrect`, `CoronaNormal`, `CoronaTriplanar` e `CoronaBitmap`. Não houve nenhum erro.
- **36 slots saíram pretos**, mas a causa é outra: **textura ausente**. Saíram pretos até `Bitmaptexture` e `CoronaBitmap` simples, todos com arquivo que não existe nesta máquina (seção 5).
- A palha "100% transparente" do teste de 08/Jul deve ter a mesma origem, mas não reproduzi aquele caso.

### 3. CoronaTriplanar: o RWF já resolve no fluxo real

| | Blocos | Triplanares antes | Depois do RWF |
|---|---|---|---|
| Com Triplanar | 14 | 24, todos em espaço 0 (objeto) | **0** |

- O RWF troca cada Triplanar por um UVW Map Box equivalente e deixa o mapa de dentro no material. O render antes e depois sai igual: sondagem do #128.
- **No fluxo Auto UV → Converter, nenhum Triplanar chega à conversão.** Ele só chega se o artista converter sem rodar o Auto UV, e aí o `renderMap` faz uma projeção qualquer: sai textura (desvio 19 a 40), mas não a do render.
- **Aviso frequente do RWF:** "Triplanar e bitmap em Real-World no mesmo canal 1. O UV do Triplanar prevalece; conferir o bitmap." Apareceu em 8 dos 14 blocos (Luang, Nambu, Zazah). Fica para conferir à parte, porque o bitmap de fora do Triplanar pode mudar de escala.

### 4. Procedurais que o glTF não tem

- **`Noise` 3D no bump** dos vidros da Louise (9 slots): o `renderMap` sai **cinza chapado** (128, desvio 0), porque o ruído em XYZ avaliado no plano do UV some.
  - A conversão já não leva esse bump: só converte `CoronaNormal` e avisa "bump escalar não convertido".
  - O GLB perde a "distorção" do vidro. Não há como levar esse ruído para o glTF sem bake por projeção, e o efeito é pequeno.
- **`falloff` na base color** (depende do ângulo de visão):
  - No couro do Puff Pol, o `renderMap` sai quase a cor de frente (desvio de 0,5 a 3). É uma aproximação aceitável.
  - Nos tecidos do Jaen e da Luang (`falloff` com Triplanar dentro), sai a textura de dentro (desvio de 16 a 25).
  - Em todos os casos o glTF fica sem o efeito de borda, porque não existe falloff no PBR.

### 5. Textura ausente e caminho resolvido

| Bitmaps usados | Acha pelo caminho bruto | Acha pelos map paths | Não acha |
|---|---|---|---|
| 110 | **0** | 57 | **53** (16 blocos) |

- **Os 53 que faltam** apontam para bibliotecas da equipe que esta máquina não vê:
  - `Z:\BIBLIOTECA 3D\...`
  - `Z:\BIRÔ\BIBLIOTECA DIGITAL DE TEXTURAS\...`
  - `\\198.9.100.251\desenho\...`
  - `D:\Artefacto\...`
  - `f:\00biblioteca\...`
- **Os 57 que o Max acha** só são achados pelos *map paths*, por exemplo uma cópia ao lado do .max. O plugin confere com `doesFileExist` do caminho bruto em três lugares: `InLab_CheckTexture` (V-16), `InLab_BitmapDoTexmap` e o reaproveitamento do arquivo em `InLab_TexmapParaGLTF`. Esses 57 aparecem como "arquivo não encontrado" na V-16, e a conversão grava o caminho bruto no glTF Material.

### 6. Ladrilho do bake: tiling não inteiro

- O bake avalia o procedural **no quadrado 0–1 do UV**, e o GLB repete essa imagem. Se o bitmap de dentro não completa um número inteiro de repetições no 0–1, o ladrilho não fecha e aparece **emenda**.
- **Depois do RWF, 40 de 42 slots de procedural fecham.** Os 2 que não fecham são `Color_Correction` em volta de um bitmap só, com tiling **0,7** (Puff Dorset, Tecido Marrom01) e **2,5** (Puff Pol, tecido filippa almo).

## Recomendação

1. **Não fazer Render-To-Texture por projeção agora.** O caso 3D que mais pesa, o Triplanar, já chega resolvido pelo RWF, e os 2D bakeiam igual em qualquer renderizador. O que sobra (`Noise` 3D, `falloff`) não tem equivalente no glTF, nem com RTT.
2. **Avisar na conversão**, por material e slot, como pede a issue:
   - **Triplanar na árvore:** "rode o Auto UV antes de converter (o Real World Fix troca o Triplanar por UVW Map)".
   - **Mapa em coordenada 3D (XYZ):** "procedural 3D: o bake sai sem o padrão".
   - **`falloff`:** "o efeito de borda não vai para o glTF; o bake aproxima pela cor de frente".
   - **Tiling não inteiro** em bitmap dentro de procedural: "o ladrilho não fecha: emenda no GLB". Esse dá para corrigir depois, bakeando um ladrilho com tiling 1 e passando o tiling para o UV.
3. **Textura ausente e map paths** (issue nova): resolver o caminho com `mapPaths.getFullFilePath` antes do `doesFileExist`, na V-16, no Check Texture e na conversão.
   - A conversão deve avisar com `#err` quando o arquivo não existe. Hoje o GLB sai apontando para um arquivo inexistente, ou com o bake preto, sem aviso.
   - Com isso, a V-16 deixa de dar falso "não encontrado" em textura que o Max acha.

## Riscos e o que falta

- **Fidelidade visual:** não comparei o render Corona com o GLB no viewer. A comparação foi pelo `renderMap`, ou seja, pela avaliação do Max. Um teste visual com 2 ou 3 materiais (Mentha couro, Nambu #18, Jaen tecido) fecharia a questão.
- **Blocos fora:** os 30 que não abrem no 2024 ficaram de fora, entre eles os maiores (Sanur, Patong, Chet).
- **Arnold:** 23 slots vêm de cena com o Arnold de renderizador. O resultado foi igual ao do Scanline, mas não testei material Arnold (todos eram Corona Legacy ou VRay).
