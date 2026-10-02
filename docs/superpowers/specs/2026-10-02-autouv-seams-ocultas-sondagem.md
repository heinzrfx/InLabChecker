# AutoUV: seams nas regiões ocultas, sondagem (issue #4)

Build: 3ds Max 2024. Data: 2026-10-02. Tarefa 7b do plano `docs/superpowers/plans/2026-09-18-autouv-artista.md`.

## Resposta curta

- **A costura funciona mecanicamente**, mas não compensa: tirar seam da região visível custa distorção e, principalmente, aproveitamento do 0–1.
- **Critério de saída da issue** (seams laterais para trás e para baixo, sem piorar distorção e densidade em mais de 0,05×): na almofada só passa com o limite da costura em 1,12, e com ganho parcial; no Box013 só passa com ganho de 14% e aproveitamento de 18%.
- **Decisão (usuário, 02/10/2026):** a issue #4 fecha como "não compensa nestas peças". O checkbox "Preferir seams em regiões ocultas" continua fora da UI.

## Peças e medidas

- Almofada: `ChamferBox length:40 width:40 height:12 fillet:3 filletSegs:3`, como Editable_Poly e como primitiva (mesmos números).
- Box013 da cópia de `01.max` (Editable_Poly, 3 456 triângulos), com os grupos acima abertos.
- Flatten a 55°, padding de 1K, canal 3.
- **Aresta oculta:** a normal média das duas faces aponta para o fundo (`z < −0,5`) ou para a traseira (`y > 0,5`). O resto conta como visível. Frente = −Y.
- **Seam:** aresta de geometria com duas faces cujos vértices UV diferem nas pontas. O comprimento é o da aresta no mundo, em cm.
- Distorção, densidade e aproveitamento: `InLab_MedirUV` depois do pack.

Pipeline de hoje (flatten → `InLab_UnfoldComGuarda` → pack), que é a base de comparação:

| Peça | Ilhas | Seam visível | Seam oculta | Distorção | Densidade | Aproveitamento |
|---|---|---|---|---|---|---|
| Almofada | 6 | 175 cm (28 arestas) | 181 cm (32) | 1,07× | 1,00× | 72% |
| Box013 | 6 | 161 cm (97) | 226 cm (113) | 1,04× | 1,00× | 50% |

O flatten sozinho já deixa mais da metade da seam em região oculta: 51% na almofada e 58% no Box013.

## O que funciona

`WeldSelectedShared` em modo vértice junta duas ilhas vizinhas pela borda:

```maxscript
-- u: Unwrap_UVW no canal 3, ativo no Modify. chaves: arestas de geometria da borda.
local vs = #{}
for cada aresta da borda, para cada uma das 2 faces f e canto k dela do
(
    vs[u.getVertexIndexFromFace f k] = true
    vs[u.getVertexIndexFromFace f (k + 1, com volta)] = true
)
u.setTVSubObjectMode 1
u.selectVertices vs
u.WeldSelectedShared()
u.setTVSubObjectMode 3
```

Numa caixa: 6 ilhas → 5. O `Unfold3DSolve` depois desdobra a ilha costurada a partir da geometria, sem depender das posições que o weld deixou. Nenhuma rodada deu face sobreposta, invertida ou fora do 0–1, e a densidade ficou em 1,00–1,01×.

## Caminho 1: costurar onde a ocultação é baixa

Guloso: pares de ilhas do flatten com borda visível em comum, da maior borda para a menor. Cada tentativa refaz o flatten, aplica as costuras aceitas mais a candidata, roda `InLab_UnfoldComGuarda` e pack. Aceita se a distorção da ilha costurada (`InLab_DistorcaoIlhas`) fica no limite e não há sobreposição.

| Peça | Limite | Seam visível | Distorção | Aproveitamento | Critério (≤ +0,05) |
|---|---|---|---|---|---|
| Almofada | 1,20 (o da issue) | 175 → 58 cm (−67%) | 1,07 → 1,19 | 72% → 32% | falha |
| Almofada | 1,15 | 175 → 81 cm (−54%) | 1,07 → 1,19 | 72% → 41% | falha |
| Almofada | 1,12 | 175 → 98 cm (−44%) | 1,07 → 1,11 | 72% → 44% | passa |
| Box013 | 1,20 (o da issue) | 161 → 14 cm (−91%) | 1,04 → 1,28 | 50% → 39% | falha |
| Box013 | 1,10 | 161 → 64 cm (−60%) | 1,04 → 1,14 | 50% → 40% | falha |
| Box013 | 1,08 | 161 → 81 cm (−50%) | 1,04 → 1,13 | 50% → 39% | falha |
| Box013 | 1,06 | 161 → 138 cm (−14%) | 1,04 → 1,05 | 50% → 18% | passa, com ganho pequeno |

Tempo: ~0,2 s por par na almofada e ~0,6 s no Box013, com 7 a 8 pares por peça.

## Caminho 2: cortar só onde a ocultação é alta

Ordem inversa sobre as mesmas bordas: começa com todas as bordas de maioria visível costuradas (a borda inteira; só as ocultas ficam como corte) e reabre cortes, da menor borda visível para a maior, na ilha de pior distorção, até a distorção de `InLab_MedirUV` caber no limite. No fim tenta recosturar o que foi reaberto, da maior para a menor. Solve com `Unfold3DSolve` direto, sem a guarda.

| Peça | Limite | Seam visível | Distorção | Aproveitamento | Critério (≤ +0,05) |
|---|---|---|---|---|---|
| Almofada | 1,12 (base + 0,05) | 175 → 101 cm (−42%) | 1,07 → 1,11 | 72% → 49% | passa |
| Almofada | 1,20 | 175 → 95 cm (−46%) | 1,07 → 1,19 | 72% → 36% | falha |
| Box013 | 1,09 (base + 0,05) | 161 → 138 cm (−14%) | 1,04 → 1,05 | 50% → 18% | passa, com ganho pequeno |
| Box013 | 1,20 | 161 → 64 cm (−60%) | 1,04 → 1,15 | 50% → 39% | falha |

- Tudo costurado não desdobra: distorção 2,49 na almofada e 1,21 no Box013.
- Na almofada, reabrir só as duas quinas verticais da frente (9 cm cada) e deixar o topo ligado às laterais ainda dá 1,42. O que resolve é cortar as bordas longas do topo (35–40 cm cada), que são as visíveis.
- Com limite apertado, os dois caminhos param praticamente nas mesmas costuras.
- Tempo: ~4 s na almofada e ~16–18 s no Box013, contra 1–3 s do pipeline de hoje.

**Não testado:** cortes novos atravessando faces ocultas, fora das bordas do flatten. A distorção nasce na região visível costurada (o chanfro arredondado tem dupla curvatura), então um corte atrás ou embaixo não deve aliviá-la. Isto é raciocínio, não medição.

## Achados para quem voltar a isto

1. **Aproveitamento é o custo maior.** As ilhas costuradas são maiores e empacotam pior: perda de 20 a 30 pontos. O critério da issue não cobria isso.
2. **Guarda × medição.** `InLab_DistorcaoIlhas` mede por polígono e `InLab_MedirUV` por triângulo. No Box013, a costura aceita com 1,17 pela guarda terminou em 1,28 no log. Um limite de costura tem que usar a mesma medida do critério.
3. **`InLab_UnfoldComGuarda` apaga as costuras quando reverte.** A volta ao flatten refaz o flatten da malha inteira. Aconteceu uma vez na almofada. Em produção a guarda teria que reaplicar as costuras depois de refazer o flatten.
4. **Costura parcial de borda** (1 aresta visível de uma borda quase toda oculta) vira uma dobradiça entre duas ilhas. O caminho 2 só costura bordas de maioria visível, e a borda inteira.
5. **Pegadinha de MaxScript:** `#{1..t.np}` (propriedade de struct dentro do literal de bitarray) e um `for ... collect` passado direto como argumento junto com acesso a struct deram `No "get" function for <struct>`. Copiar para uma `local` antes resolve.
