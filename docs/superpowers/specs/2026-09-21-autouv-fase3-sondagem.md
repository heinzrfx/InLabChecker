# AutoUV de artista: Fase 3, sondagem do solver com seams

Build: 3ds Max 2024.2.14. Data: 2026-09-21. Tarefa 6 do plano `docs/superpowers/plans/2026-09-18-autouv-artista.md`.

## Resposta curta

- **Solver que respeita seams:** nenhum dos candidatos do plano funciona como estava escrito. O que funciona é destacar as ilhas **por face** e cortar dentro de uma ilha **por aresta UV**, com `Unfold3DSolve` no fim. Num cilindro: 3 ilhas, distorção 1,00×, densidade 1,00×.
- **Achado principal:** para as peças da issue, o próprio `flattenMap` sobre base **Editable_Poly** já dá a abertura de artista (Box013: 6 ilhas, igual ao ArchToolz) e não gera a ilha extra da escada no Box014 (6 ilhas sobre poly, contra 7 sobre mesh). Um `Unfold3DSolve` depois reduz a distorção para ~1,05× e deixa a densidade em 1,00×.
- **Proposta:** a Tarefa 7 troca o desenho "seams por ângulo + Dijkstra" por "flatten sobre poly → `Unfold3DSolve` com guarda por ilha → pack". Isso fica mais simples, é todo nativo e o corte de tubos deixa de ser necessário. Falta resolver a **ocultação das seams**, que o flatten não controla (ver "Em aberto").

## Candidatos do plano (caixa com o topo cortado)

Todos partem de: base Editable_Poly → Unwrap no canal 3 → `WeldAllShared()` (1 ilha) → `setSelectedGeomEdges <arestas do topo>` → `peltEdgeSelToSeam true`. As seams ficam gravadas certas (`getPeltSelectedSeams` = arestas do `polyop`).

| Candidato | Resultado |
|---|---|
| seams → `peltSeamToEdgeSel` → `uvEdgeSelect` → `breakSelected` → `LSCMSolve` | 1 ilha, 5 sobrepostas, distorção 1 278× (nenhuma aresta UV selecionada) |
| `RegularMapExpand #peltseams` → `LSCMSolve` | **EXCEPTION_ACCESS_VIOLATION** dentro do Max. Não usar. |
| `LSCMInteractive false` → `LSCMSolve` | 1 ilha, 5 sobrepostas, distorção 1 278× |
| `Unfold3DSolve` | 1 ilha, 0 sobrepostas, distorção 2,47× (seams ignoradas) |

Conclusão: nem o LSCM nem o Unfold3D leem as seams do Pelt. Só as quebras reais no UV contam.

## Sequência que funciona (cilindro 24 lados, 3 segmentos de altura)

```maxscript
-- u: Unwrap_UVW no canal 3, ativo no Modify; base Editable_Poly
u.setTVSubObjectMode 3
u.selectFaces #{1..np}
u.WeldAllShared()                                   -- 1 ilha
for ilha in ilhasDeFaces do ( u.selectFaces ilha ; u.breakSelected() )   -- separa as ilhas
-- corte dentro de uma ilha (tubo): aresta de geometria -> aresta UV
fn uvDe u f vGeom = (
    local r = undefined
    for k = 1 to (u.numberPointsInFace f) while r == undefined where (u.getVertexGeomIndexFromFace f k) == vGeom do r = u.getVertexIndexFromFace f k
    r
)
local arestasUV = #{}
for e in corte do (
    local vs = polyop.getEdgeVerts obj e
    local f = ((polyop.getEdgeFaces obj e) as array)[1]
    u.setTVSubObjectMode 1
    u.selectVertices #{(uvDe u f vs[1]), (uvDe u f vs[2])}
    u.vertToEdgeSelect partialSelect:false
    arestasUV += u.getSelectedEdges()
)
u.setTVSubObjectMode 2
u.selectEdges arestasUV
u.breakSelected()
u.setTVSubObjectMode 3
u.selectFaces #{1..np}
u.Unfold3DSolve()          -- LSCMSolve aqui sobrepõe faces (144 no cilindro)
```

Resultado: 3 ilhas, 0 sobrepostas, 0 invertidos, distorção 1,00×, densidade 1,00×.

Ressalvas:
- `vertToEdgeSelect` com os dois vértices de uma aresta só é seguro aresta por aresta. Com todos os vértices do corte de uma vez, ele pegaria também arestas entre duas linhas de corte vizinhas, como um chanfro de um segmento.
- A caixa com o topo cortado sai com 2 ilhas e distorção de 37×. Está certo: uma caixa aberta de 5 faces não planifica sem cortar as quinas verticais. O critério "2 ilhas com distorção ≤ 1,2" do plano estava errado para essa forma.

## Ilha fechada (almofada ChamferBox)

Com `filletSegs:3`, cada segmento do chanfro dobra 30°. A 55° não sai nenhuma seam por ângulo, e a ilha fica fechada, sem borda. `Unfold3DAutoseams` + `Unfold3DSolve` deram 1 ilha com distorção 4,41×, longe da abertura de artista. Já o `flattenMap` a 55° agrupa pelo desvio em relação à normal da semente, não pelo diedro, e acerta essa abertura: topo e fundo inteiros e laterais em tiras.

## Flatten sobre poly × mesh, com e sem `Unfold3DSolve` (01.max, 55°)

| Peça | Base | Flatten | + `Unfold3DSolve` + pack |
|---|---|---|---|
| Box014 | mesh | 7 ilhas, dens 1,24, dist 1,51 | 11 ilhas, aprov 39%, dens 1,00, dist 1,06 |
| Box014 | **poly** | **6 ilhas**, dens 1,09, dist 1,51 | **6 ilhas**, aprov 39%, dens 1,00, dist 1,06 |
| Box013 | mesh | 6 ilhas, dens 1,09, dist 1,56 | 6 ilhas, aprov 50%, dens 1,00, dist 1,04 |
| Box013 | **poly** | 6 ilhas, dens 1,09, dist 1,69 | **6 ilhas, aprov 50%, dens 1,00, dist 1,04** |
| Box008 | mesh | 37 ilhas, dens 1,31, dist 1,71 | 40 ilhas, aprov 10%, dens 1,01, **dist 2 377** |
| Box008 | poly | 38 ilhas, dens 1,29, dist 1,74 | 44 ilhas, aprov 10%, dens 1,01, **dist 80** |

0 sobrepostas e 0 invertidos em todos. No Box008, o `Unfold3DSolve` degenera alguma ilha e cria outras 6. Sem guarda por ilha, ele não pode entrar.

## Tempos

| Operação | 1 800 pol. | 7 200 pol. | 16 200 pol. | 306 mil tris (pillow 02) |
|---|---|---|---|---|
| `WeldAllShared` | 17 ms | 224 ms | 1,1 s | — |
| `Unfold3DAutoseams` | 0,8 s | 1,7 s | 3,1 s | 33 s |
| `Unfold3DSolve` | 0,15 s | 0,5 s | 1,2 s | 49 s |
| `flattenMap` (Box013/014/008) | 28–164 ms | | | 40–55 s |

Em malha pequena, flatten + solve cabe folgado no orçamento de ≤ 5 s por peça. Na pillow 02, o solve sozinho (49 s) estoura o orçamento de 45 s. Malha grande fica com o caminho da Fase 2.

## Em aberto

1. ~~**Guarda do `Unfold3DSolve` por ilha (Box008).**~~ Resolvido, ver a seção "Guarda do `Unfold3DSolve` por ilha (validada)" abaixo.
2. **Seams nas regiões ocultas.** O flatten decide sozinho onde corta. Caminhos para a Tarefa 7:
   - costurar ilhas vizinhas pelas bordas visíveis (`stitch` ou weld das arestas compartilhadas) quando o solve da ilha costurada continua com distorção baixa;
   - ou cortar só onde a ocultação é alta, a partir das bordas das ilhas do flatten.

   Precisa de outra sondagem curta antes de ter código.
3. **Estabilidade.** O `RegularMapExpand #peltseams` derrubou o Max com access violation. O código de produção não deve usá-lo.

## Guarda do `Unfold3DSolve` por ilha (validada)

Protótipo em três passos, todos com funções nativas do Unwrap:
1. **Ilhas:** para cada face ainda sem ilha, `selectFaces #{f}` → `selectElement()` → `getSelectedFaces()`. É uma chamada por ilha. O union-find em MaxScript sobre `getVertexIndexFromFace` levava 2,7 s no Box008; isto leva 0,2 s.
2. **Antes do solve:** guardar `getVertexPosition 0 v` de todos os vértices UV, que são as posições do flatten.
3. **Depois do solve:** distorção por ilha com `getArea #{f}` por face, max(r, 1/r) contra a densidade da ilha. Nas ilhas com distorção > 2,0: `selectFaces ilha` → `faceToVertSelect()` → `setVertexPosition 0 v posFlat[v]`.

| Peça | Ilhas | Revertidas | Final (depois do pack) | Tempo (ilhas + solve + guarda) |
|---|---|---|---|---|
| Box008 | 38 | 11 | 44 ilhas, aprov 11%, **dens 1,05, dist 2,10**, 0 sobrepostas | 0,2 + 1,7 + 1,5 s |
| Box014 | 6 | 0 | 6 ilhas, aprov 39%, dens 1,00, dist 1,06 | 0,02 + 1,1 + 0,6 s |
| Box013 | 6 | 0 | 6 ilhas, aprov 50%, dens 1,00, dist 1,04 | 0,01 + 0,8 + 0,2 s |

O que não funcionou:
- **Reverter com flatten só na seleção:** o flatten normaliza a seleção num 0–1 próprio, e o Box008 foi a densidade 1,31× e 65 ilhas.
- **`RescaleCluster`** depois disso: não corrigiu a densidade.

## Correção da guarda (22/Set, validação na cadeira)

O protótipo acima voltava as ilhas por índice de vértice (`getVertexPosition 0 v` antes, `setVertexPosition 0 v posFlat[v]` depois). Mas o `Unfold3DSolve` **renumera os vértices UV das faces**. No Box050 são 78 de 294 faces. É uma permutação: os mesmos 408 vértices continuam em uso, só com outros índices. Por isso a reversão gravava as posições nos vértices errados. Na cadeira inteira, 7 peças saíram com faces sobrepostas, invertidas e distorção de até 1,3 milhão × (Box050/051, Rectangle001, Box001, Box005, Box062, Box063). Nas peças da issue a reversão não deu defeito visível (o Box008 reverteu 11 ilhas e saiu certo), e por isso a sondagem não viu o problema. Não investiguei por que o Box008 escapou.

A correção guarda a posição do flatten **por canto de face** e, depois do solve, grava cada canto no vértice que `getVertexIndexFromFace f k` aponta. O teste `test_autouv.ms` agora usa um Torus (o solve renumera 99 de 288 faces), força a reversão de todas as ilhas e exige o UV idêntico ao flatten, canto por canto. Caixa, cilindro e ChamferBox não renumeram.

Cadeira de `01.max` (125 peças) depois da correção: canal 1 idêntico e pai preservado em todas, **0 sobrepostas, 0 invertidos, 0 fora do 0–1 em todas** (Box002 e Box063, sobrepostas na Fase 2, também zeraram), densidade média 1,01×, distorção média 1,50×, **3,7 s por peça em média**.

Achado colateral: com o grupo fechado (a seleção pega o grupo inteiro), o `Unfold3DSolve` dá `EXCEPTION_ACCESS_VIOLATION`. O `InLab_AutoUV` já abre os grupos antes. Isso só apareceu num script de sondagem que não abria.
