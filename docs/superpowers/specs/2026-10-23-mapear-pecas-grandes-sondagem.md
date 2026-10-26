# Mapear: peças grandes de tecido, sondagem da projeção melhorada (23/10/2026)

Teste pedido pela spec `2026-10-23-mapear-design.md`, seção 5.4, com o critério da seção 12, item 4: no corpo da Mentha, as emendas à vista com quebra de direção (`emendaVistaQuebra` de `InLab_Mapear_Medir`) têm de cair **pelo menos pela metade** em relação ao Box do RWF.

**Resultado: não passou.** `InLab_Mapear_GerarGrande` ficou como alias de `InLab_Mapear_GerarBox` (`functions\fn_mapear_gerar.ms`). O orquestrador (Tarefa 5) mede cada peça e avisa no log o corte à vista, sugerindo o unwrap opcional.

## O que foi testado

Uma projeção em caixa por face, igual à do `GerarBox` (eixo dominante da normal; laterais com U horizontal, topo com U = X; T × B = normal; vértices de UV compartilhados por vértice, eixo e sinal), mas com a escolha do lado da caixa alisada por voto dos vizinhos por aresta:

- cada face tem um dos 6 lados (eixo × sinal);
- em cada passe, soma a área dos vizinhos por lado; a face troca de lado só quando outro lado tem mais da metade da área dos vizinhos;
- só votam os vizinhos **lisos** (normais a menos de 30 graus, o mesmo limite da medição), para que a emenda fique na quina;
- o lado novo tem de estar de frente para a face (`cos >= 0,5`), senão a projeção estica demais;
- 4 passes (pedido), e também 12, para ver se mais alisamento ajudava.

## Cena e método

- Cena: cópia de `poltronas_mentha_vimen_23-10.max` (não salva). Corpo `Metal marrom microtextra ` (com espaço no fim), no grupo POLTRONA MENTHA, com o modificador "InLab RWF Triplanar" (UVW Map Box de 40 cm).
- Cópia na memória: `snapshot` do nó (malha avaliada, com o UV do RWF) → `convertToPoly`, 29.060 polígonos, 60.252 triângulos, muitos elementos pequenos (botões etc.). A cópia foi apagada no fim.
- Escala dos geradores: 1/40 UV/cm, a mesma do RWF.
- Medição: `InLab_Mapear_Medir` (amostra de 15.063 triângulos; emendas em blocos de 16 faces).

## Números

| Variante | emendaVistaQuebra | Relação ao RWF | Tempo para gerar |
|---|---|---|---|
| RWF Box (UV atual, base) | 0,785% | 1,00 | — |
| `GerarBox` | 0,800% | 1,02 | 12 s |
| Alisada, 4 passes, cos ≥ 0,5 (721 trocas) | 0,754% | 0,96 | 31 s |
| Alisada, 12 passes, cos ≥ 0,5 (1.705 trocas) | 0,691% | 0,88 | 33 s |
| Alisada, 12 passes, cos ≥ 0,3 (1.731 trocas) | 0,688% | 0,88 | 33 s |
| Alisada sem o filtro de vizinho liso, 4 passes | 0,757% | 0,96 | 31 s |
| Alisada sem o filtro de vizinho liso, 12 passes | 0,697% | 0,89 | 33 s |

Meta: 0,39% ou menos. O melhor caso só tirou 12%. Espelhado ficou em 0,013% em todas (igual ao RWF) e a escala não mudou (0,0240 UV/cm, p10 0,021, p90 0,025).

Na esfera achatada do teste unitário (`Sphere segs:32`, escala [1, 1, 0,6]), a versão alisada de 4 passes foi de 4,9% (Box) para 3,8%.

A base medida hoje é 0,79%, não o 1% citado no plano. A causa provável é a correção da amostragem em `fn_mapear_medir.ms` (passo com teto e emendas em blocos), mas isso não foi conferido.

## Por que não passa

Numa superfície estofada lisa, a caixa sempre tem uma fronteira entre lados, e ali o U gira 90 graus (lateral com lateral) ou 180 graus (topo com a lateral +Y, onde o U da lateral é −X e o do topo é +X). O voto só tira o serrilhado dessa fronteira, sem eliminá-la: a fronteira continua no meio da superfície lisa, porque a Mentha quase não tem quina para recebê-la. Para cair pela metade, seria preciso outra coisa (unwrap por regiões, ou alinhar o U do topo com o lado vizinho), fora do escopo da primeira entrega.

## Código testado (não ficou no plugin)

Usado entre `BoxLados` (eixo dominante por face) e a montagem do UV do `BoxLocal`:

```maxscript
fn InLab_Mapear_AlisarLados o faces eixo sinal =
(
    local nf = polyop.getNumFaces o
    local lado = #(); local area = #(); local nor = #(); local viz = #()
    lado.count = nf; area.count = nf; nor.count = nf; viz.count = nf
    for f in faces do
    (
        lado[f] = (eixo[f] - 1) * 2 + (if sinal[f] > 0 then 1 else 2)
        area[f] = polyop.getFaceArea o f
        nor[f] = polyop.getFaceNormal o f
    )
    for f in faces do
    (
        local vs = ((polyop.getFacesUsingEdge o (polyop.getFaceEdges o f)) - #{f}) * faces
        viz[f] = for g in vs where (dot nor[f] nor[g]) > 0.866 collect g
    )
    local trocas = 0
    for passe = 1 to INLAB_MAPEAR_GRANDE_PASSES do
    (
        local novo = copy lado #nomap
        local mudou = 0
        for f in faces where viz[f].count > 0 do
        (
            local w = #(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            local tot = 0.0
            for g in viz[f] do ( w[lado[g]] += area[g]; tot += area[g] )
            local melhor = lado[f]; local wm = 0.0
            for c = 1 to 6 where w[c] > wm do ( wm = w[c]; melhor = c )
            if melhor != lado[f] and wm > 0.5 * tot do
            (
                local a = (melhor + 1) / 2
                local sg = if (mod melhor 2) == 1 then 1.0 else -1.0
                if nor[f][a] * sg >= INLAB_MAPEAR_GRANDE_COS_MIN do ( novo[f] = melhor; mudou += 1 )
            )
        )
        lado = novo
        trocas += mudou
        if mudou == 0 do exit
    )
    for f in faces do ( eixo[f] = (lado[f] + 1) / 2; sinal[f] = (if (mod lado[f] 2) == 1 then 1 else -1) )
    trocas
)
```
