# Mapear: tecido por painéis cortados nas costuras, sondagem no assento da Gap (26/10/2026)

Pedido do usuário: o Mapear não tirou o recorte da textura no estofado da Poltrona Gap, e o recorte aparece também no IR do Corona. Esta sondagem testa um caminho que o Box (RWF e Mapear) e a projeção alisada (`2026-10-23-mapear-pecas-grandes-sondagem.md`) não cobrem: **cortar o UV só nas costuras e abrir cada painel**.

**Resultado: promissor.** O recorte da curva entre a frente e o tampo some no render do Corona. A emenda que sobra fica na borda da lateral, embaixo do vivo, onde a costura real também está.

## Por que o recorte existe

O tecido original usa CoronaTriplanar de 75 cm com blend 0,5. A mistura das três projeções esconde as emendas. O glTF não tem Triplanar, então o RWF troca o Triplanar por um UVW Box de 75 cm, que projeta cada face por um único lado e sem mistura. Onde o estofado curvo passa de um lado da caixa para outro, a trama salta. Como o RWF troca o mapa no próprio material, o IR do Corona mostra o mesmo corte que vai para o GLB.

## Cena

- Cena do usuário (Gap já renomeada, 4 objetos), cópia de segurança em scratchpad, restaurada no fim. Nada foi salvo no arquivo dele.
- Assento `ART_T_Assento`: 32.818 polígonos, 65.636 triângulos, com o UVW Map Box do usuário (L = 84,3 cm).
- Trabalho numa cópia (`snapshot` → `convertToPoly`), apagada no fim.

## O que a malha mostra

- **2 elementos fechados:** o corpo (13.450 faces, 116 × 96 × 41 cm) e o **vivo** (19.368 faces), que contorna as duas laterais.
- **Sem vinco de costura:** só 56 de 65.636 arestas passam de 30°. A costura não aparece como quina na malha, então ângulo entre faces não serve para achá-la.
- **O vivo marca a costura:** as arestas do corpo a menos de **6 mm** de um vértice do vivo (grade espacial de 1 cm, 15 s) cortam o corpo em **3 painéis**, mais 560 faces soltas embaixo do vivo, que vão para o painel vizinho por voto.

| Painel | Faces | Contornos | Forma |
|---|---|---|---|
| Faixa | 9.109 | 2 | anel em volta de X: frente, tampo, trás e fundo |
| Lateral −X | 2.170 | 1 | disco, 7,6 cm de profundidade |
| Lateral +X | 2.171 | 1 | disco, 7,6 cm de profundidade |

Com 3 mm sai um painel só (o vivo não fecha o contorno). Com 1 cm sai o mesmo molde, com mais faces soltas.

## UV gerado (75 cm por tile, sem espelho, trama horizontal)

- **Faixa:** U = X; V = comprimento do perfil (no plano YZ, medido numa fatia do meio, 2,42 m de volta), ao longo do ângulo em volta do centro do perfil. Um corte a mais **embaixo do assento** (fundo, −Z) abre o anel. Sentido de V: da frente para o tampo, com T × B = normal.
- **Laterais:** projeção plana em X (U = ±Y, V = Z, com o sinal pela normal), depois `Unwrap_UVW` + `Unfold3DSolve` num nó temporário. Giro e posição encaixados de volta na projeção plana (Procrustes 2D, sem espelho: giro de 0,1 a 0,2°). Escala pela área, para dar 75 cm. Leitura por canto de face (`getVertexIndexFromFace`), porque o solve renumera os vértices.
- Tempo total: menos de 25 s, a maior parte na distância até o vivo.

## Números (`InLab_Mapear_Medir`, só as faces do corpo)

| | Quebra nas emendas à vista | Espelhado | cm por tile | Densidade p90/p10 |
|---|---|---|---|---|
| Hoje (UVW Box do usuário) | 0,8% | 0% | 85,2 | 1,2 |
| Painéis, laterais planas | 0,5% | 0% | 74,4 | 1,2 |
| Painéis, laterais com Unfold3D | 0,5% | 0% | 73,7 | **1,0** |

A medida conta como "à vista" também as emendas embaixo do vivo, então os 0,5% são quase todos a borda dos painéis. O que decide é a imagem:

- **Listras de diagnóstico:** hoje há corte na curva da frente para o tampo, e o "F" do tampo vira de lado. Com os painéis, as listras passam contínuas da frente para o tampo. A projeção plana da lateral entortava as listras na quina; com o Unfold3D, não.
- **Render Corona** (12 passes, cena sem luz): a linha de corte do tampo some. Fica a emenda na borda da lateral, embaixo do vivo.

## Encosto (mesmo dia)

Encosto `ART_T_Encosto`: rolo de 116 × 36 × 31 cm, 4.864 faces em 5 elementos: o corpo (2.176 faces) e **4 vivos**, dois nas pontas (x ≈ −20 e 87) e dois no meio (x ≈ 8 e 60). O UV de hoje é o do Mapear 1.2.9 (tubos nos vivos, Box no corpo).

- **Limite de distância:** a malha é mais grossa que a do assento, e com 6 mm o vivo não fecha o contorno. Com **1,5 cm** saem os 5 painéis esperados: três trechos do rolo (anéis em volta de X, dois deles em cúpula perto das pontas) e duas tampas. **O limite tem de acompanhar o tamanho das arestas**, não ser fixo.
- **UV:** os anéis pela volta em torno de X (V = ângulo × raio médio, com o corte embaixo) e as tampas planas pela normal média. Depois, **Unfold3D em todos**, inclusive nos anéis: o UV inicial já traz o corte, e o solve respeita a topologia do UV. Escala pela área (75 cm). 7 s nos 5 painéis.
- **Giro:** encaixar pelo UV inicial (Procrustes) deixou os trechos das pontas 5° tortos. O certo é girar cada painel até o X do mundo cair no U, com o X projetado no plano de cada face e levado ao UV pelas arestas (combinação exata, não a aresta mais alinhada, que errou até 12°). Depois disso, as listras dos três trechos ficam paralelas.

| | Quebra nas emendas à vista | Espelhado | cm por tile | Densidade p90/p10 |
|---|---|---|---|---|
| Hoje (Mapear 1.2.9) | 1,7% | 0% | 78,3 | 1,2 |
| Painéis, UV inicial | 0,6% | 0% | 76,4 | 1,2 |
| Painéis + Unfold3D + giro pelo X | 0,8% | 0% | 73,9 | **1,0** |

Listras: hoje elas ondulam e quebram no alto do trecho do meio (a emenda do Box). Com os painéis, correm retas ao longo do rolo, e as tampas ficam com a trama horizontal e o "F" de pé. Render Corona: a trama deste tecido é fina e clara, e a diferença aparece menos. Fica uma marca no alto do rolo de hoje, e nos painéis as emendas ficam só nos anéis de vivo.

## Puff Dorset quadrado (mesmo dia): estofado sem vivo embaixo

Cena do usuário (07132631, 46 × 46 × 45 cm, não salva, cópia de segurança restaurada no fim). Tecido em VRayMtl (bitmap `Fabric_Ligh222.jpg`, tiling 0,7).

- **Corpo** (`Box244448650`, 24 mil triângulos, caixa arredondada de 46 × 46 × 30): **sem vivo e sem vinco** (nenhuma aresta passa de 15°). O tampo fica coberto pela almofada e o fundo pelo friso e pelo chão.
- **Almofada** (`Box244448649`, 5 mil triângulos): vivo (`Shape009`) só no alto. Embaixo ela apoia no corpo.
- **Achado à parte:** os dois têm **ProOptimizer com `KeepUV` desligado**. A base tem canal 1, mas a malha avaliada (a que vai para o GLB) sai sem UV nenhum.

**Molde sem vivo:** faixa das laterais + tampo + fundo, pela normal (|n.z| acima do limiar = tampo/fundo), com 4 passes de voto dos vizinhos na fronteira. Duas posições da fronteira:

| Limiar | Tampo / fundo / faixa | Onde fica a emenda de cima |
|---|---|---|
| 0,7071 (quina a 45°) | 6.396 / 6.262 / 11.338 | na meia-cana da quina, à mostra |
| **0,97** (só a parte plana) | 4.016 / 3.882 / 16.098 | **na parte plana do tampo, escondida pela almofada** |

Faixa: anel em volta de Z, U pela volta (corte vertical numa quina de trás, −X +Y), V = Z. Tampo e fundo planos em Z. Unfold3D em todos, giro travado (Z do mundo no V da faixa, X no U do tampo e do fundo), 75 cm.

Listras: o Box de hoje dá "F" duplicado e salto nas **quatro quinas verticais**. Os painéis dão a volta sem salto. Com o limiar 0,97, as listras passam também por cima da quina de cima, e a emenda vai para onde ninguém vê. Os números de quebra empatam (1,0% a 1,1%): a medida não sabe o que fica escondido.

**Almofada:** o vivo corta tampo e faixa (limite de 1 cm; as arestas têm 2,8 cm de média). O fundo é a parte plana de baixo (n.z < −0,97, 440 faces, apoiada no corpo).

- **Unfold3D na faixa da almofada entortou a trama na diagonal.** A faixa é baixa (~8 cm) e leva a quina de baixo, mais cone que cilindro, e um cone planificado vira arco. Sem o Unfold3D, só com a volta cilíndrica (U = comprimento ao longo do contorno, V = Z), a trama fica horizontal e contínua nas quinas. **Regra: faixa pela volta cilíndrica; Unfold3D só em tampa plana.** (No encosto da Gap, o Unfold3D nos anéis funcionou porque lá os trechos são tubos de verdade.)
- O perímetro tirado dos vértices de cima da faixa saiu 226 cm, contra uns 180 esperados, porque pegou pontos do contorno de dentro. Precisa vir do contorno de fora (ou do próprio vivo).

**Render:** o material é VRayMtl e a iluminação da cena estoura o render do Corona. A comparação ficou pelas listras na viewport.

**Pegadinha:** `polyop.getVert` na base dá coordenada do **objeto**. Para comparar com outra peça (o vivo, via `snapshotAsMesh`, em mundo), passe a outra para o espaço do objeto (`* inverse node.objectTransform`). No Gap passou despercebido porque o pivô estava perto da origem.

## Limites e o que falta para virar código

1. **Sem vivo:** no Dorset, o molde em caixa (faixa + tampo + fundo pela normal) funcionou, com a emenda empurrada para a parte plana escondida. Isso supõe uma peça em forma de caixa ou de cilindro de pé. Forma livre sem vivo ainda não tem regra, e aí continua o Box (ou entra uma seleção de arestas marcada pelo modelador).
2. **Faixa:** no assento ela foi aberta pela fórmula do perfil. No encosto, o Unfold3D partindo de um UV inicial com o corte funcionou em anéis e cúpulas. Os dois casos ainda supõem o eixo X (o rolo e a faixa correm em X). Peça girada ou com outro eixo precisa achar o eixo antes (por exemplo, pela menor variação das normais).
3. **O vivo do assento não foi remapeado.** O Mapear trata esse vivo como peça grande (Box, 6,7% de corte à vista): o detector de tubo não o reconhece, porque são dois contornos num elemento só. O vivo deveria sair como tubo ao longo do comprimento. Os 4 vivos do encosto o Mapear já reconhece.
4. **Testado em assento e encosto de um produto só (Gap).** Falta um estofado sem vivo e um com formas livres.
8. **Limite da distância até o vivo:** 6 mm no assento e 1,5 cm no encosto. Precisa ser relativo ao tamanho das arestas.
5. **Onde fica o corte da faixa:** embaixo (−Z) é escondido no assento. No encosto seria atrás (+Y).
6. **Desempenho:** a distância até o vivo é laço em MaxScript (15 s em 27 mil arestas). Numa malha maior precisa de amostra ou de grade mais grossa.
7. **Pegadinha encontrada:** um laço com `polyop.getFacesUsingEdge` por aresta, nas 65 mil arestas, travou o Max por mais de 30 minutos. Use `polyop.getEdgeFaces`, que é instantâneo (0,2 s nas mesmas arestas).
