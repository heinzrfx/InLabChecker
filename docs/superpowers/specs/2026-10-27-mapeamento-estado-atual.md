# Mapeamento do canal 1: como está hoje (v1.3.0)

Resumo de 27/10/2026, para estudar outras abordagens. Descreve o que o plugin faz hoje na seção **UV e Texturas**, sem propor nada. As specs completas são `2026-10-23-mapear-design.md` (Mapear) e `2026-10-26-mapear-paineis-design.md` (Painéis).

## 1. O problema que o mapeamento resolve

- O time mapeia o canal 1 com **UVW Box**. A escala sai certa, mas o veio da madeira sai atravessado, os vivos e as costuras ficam com cortes à vista, e a peça espelhada inverte o veio.
- O tecido costuma usar **CoronaTriplanar**, que não tem emenda. O glTF não tem Triplanar, então o UV precisa ser real. Projeção em caixa num estofado curvo **corta a trama** nas quinas.
- **O VFB do Corona com o material original engana:** o Triplanar ignora o UV e sempre fica bom. Para avaliar, vale o viewport ou o render depois do Real World Fix, que mostram o UV como no GLB.

**O que é um bom mapeamento** (medido em assets profissionais): densidade uniforme por material, direção certa (veio no comprimento da peça, trama ao longo do vivo), pouca distorção (esticamento entre 1,00 e 1,10), poucas emendas e escondidas (embaixo, atrás, em quina viva) e nenhum espelhamento.

## 2. Fluxo na seção UV e Texturas

| Ordem | Botão | O que faz | Módulo |
|---|---|---|---|
| 1 | **Real World Fix** (obrigatório) | Troca Real-World e Triplanar por `Uvwmap` + `UVW_Xform` chamados "InLab RWF*", com o tamanho real da textura | `fn_realworldfix.ms` |
| 2 | **Mapear** / Desfazer Mapear | Refaz o canal 1 **só onde está ruim**, pela matéria-prima do JSON | `fn_mapear*.ms` |
| 3 | **Painéis** / Desfazer Painéis | Refaz o canal 1 do tecido selecionado cortando em painéis | `fn_mapear_paineis.ms` |
| — | **Ver UV** (liga e desliga) | Material temporário de listras com "F", para conferir no viewport | `fn_ver_uv.ms` |
| opcional | Unwrap / Auto UV / Limpar UV | Canal 3, só para bake (V2) | `fn_autouv.ms` |
| — | **Desfazer UV** | Desfaz os Painéis, o Mapear, o RWF e o Auto UV | — |

Pré-requisitos do Mapear e do Painéis: produto escolhido, RWF feito na peça e material ligado a uma parte do JSON.

## 3. Mapear (automático, 23/10)

Orquestrador: `InLab_Mapear` (`fn_mapear.ms`). Para cada peça (uma vez por grupo de instâncias):

1. **Guardas.** Peça com Real-World ou Triplanar sem RWF: pulada. UVW Map, Unwrap ou Xform do usuário no canal 1: pulada. Outros modificadores: aviso, e o UV é calculado na base.
2. **Por ID de material** (ou na peça inteira):
   - **Classifica** a parte pela família do JSON (`fn_mapear_classe.ms`): `#madeira`, `#pintada` (madeira com Microtextura), `#tecido`, `#liso` ou `#semFamilia`.
   - **Direção do veio** pela imagem do difuso: reduz para 128×128 e compara a variação de brilho vertical com a horizontal (razão de 1,15). Se o W do bitmap estiver perto de 90°, as direções trocam.
   - **Mede o UV atual** (`fn_mapear_medir.ms`, numa amostra de até 20 mil faces): escala, p10/p90, emenda à vista com quebra de direção, faces espelhadas e veio alinhado.
   - **Decide se refaz.** Refaz quando qualquer critério falha: falta canal 1; escala de Real-World (> 0,2 UV/cm); escala fora de ±30% do alvo; p90/p10 > 1,3; emenda à vista > 2%; espelhado > 5%; veio atravessado (< 60%).
3. **Geradores** (`fn_mapear_gerar.ms`, todos em espaço de objeto da base):
   - **Madeira:** veio na aresta longa, projeção por face alisada pelo voto dos vizinhos, sem espelhar. Com veio vertical, o UV gira 90°.
   - **Tubo** (vivos do tecido): grade comprimento × volta por quads, um elemento por vez. Exige comprimento ≥ 4× a volta.
   - **Box:** projeção por face pelo eixo dominante.
   - **Grande** (corpo do tecido): hoje é o próprio Box. A versão "alisada" foi reprovada em 23/10 e o Unwrap/Unfold3D também perdeu, por isso não aparece na UI.
4. **Escala:** o tamanho que o RWF deu (Xform ou UVW Map "InLab RWF*" do canal 1); senão a densidade atual, se ficar entre 10 e 300 cm por tile; senão o tamanho do mesmo bitmap em outra peça; senão **60 cm por tile**.
5. **Gravação:** a base vira Editable_Poly (os triângulos são conferidos). O registro (`MapearRecord`) guarda o canal 1 exato, os modificadores RWF e o canal/tiling dos bitmaps. Os "InLab RWF*" do canal 1 saem e os bitmaps que liam o canal do Triplanar voltam a ler o canal 1. Depois a peça é medida de novo e um corte à vista gera aviso.

**Resultado no teste de 23/10** (Mentha e Vimen): emendas dos vivos de 11–13% para 0%, madeira sem espelhamento e veio ao longo dos pés. **O que não resolveu:** o corpo grande do estofado continua em Box, com corte nas quinas.

## 4. Painéis (manual, peça a peça, 26/10)

Criado para o corpo do estofado. O desenhista seleciona a peça, clica e confere no Ver UV; se não gostar, desfaz. Só age nos IDs de família tecido. Orquestrador: `InLab_Paineis` → `InLab_Paineis_Peca`.

### 4.1 Separar em painéis (`InLab_Paineis_Separar`)

1. **Vivos do produto.** Varre toda a geometria sob a mesma cabeça de hierarquia. Vivo é um elemento fechado, fino (2V/A < 1,5 cm) e comprido (maior medida > 12× o raio). Nós com modificadores ou base não-poly são lidos por uma cópia temporária em mundo.
2. **Costura pelo vivo.** Amostra até 8.000 pontos de vivo numa grade de 1 cm. A aresta do corpo a menos de `d` de um vivo vira costura. Testa `d` = 0,4 / 0,6 / 0,8 / 1,0 / 1,5 / 2,0 / 3,0 cm e fica com o **menor** que divide o corpo em ≥ 2 regiões grandes (max(50 faces, 3%)). As faces soltas vão para o painel vizinho por voto.
3. **Sem vivo que feche o contorno: molde em caixa.** O eixo é a menor medida da peça, se for < 0,8× as outras; senão Z. Normal·eixo > 0,97 é tampo, < −0,97 é fundo, e o resto é faixa. A fronteira é alisada em 4 passes de voto ponderado pelo comprimento da aresta.

### 4.2 UV de cada painel (`InLab_Paineis_UV`)

O tipo sai do número de contornos de borda: **1 = disco**, **≥ 2 = anel**, **0 = inválido** (a peça fica como estava).

- **Disco:** projeção plana pela normal média, depois `Unfold3DSolve` num nó temporário (detach de uma cópia da base). A escala sai da área. O giro é travado: X do mundo no U (tampo) ou Z no V (lateral). Se sair espelhado, inverte o U.
- **Anel:** o eixo é o da caixa, ou o eixo do mundo mais perpendicular às normais. Um corte extra abre o anel num lugar escondido (quina de trás, ou embaixo). Três candidatos, e fica o de **trama menos torta** (fração da área com a direção de referência a mais de 15° do alvo):
  1. **Volta:** U = comprimento ao longo do contorno de fora, V = coordenada no eixo.
  2. **Perfil varrido:** como a volta, mas o V é o comprimento ao longo do perfil da seção.
  3. **Unfold3D** a partir da volta, só tentado se a melhor das duas passar de 2% e só aceito se ganhar por ≥ 2 pontos.

### 4.3 Escala, gravação e desfazer

- **Escala por ID:** o tamanho que o Mapear usou (`cmPorID`); senão o "InLab RWF*"; senão a densidade medida; senão o tamanho do RWF do mesmo bitmap; senão 60 cm.
- A gravação segue o Mapear. A **pilha própria** (`InLab_PilhaPaineis`) permite desfazer só a última rodada. O Mapear não refaz peça com Painéis na pilha.

### 4.4 Evidência (teste cego de 26/10)

| Teste | Peças | Acerto do automático | Pior que o Box |
|---|---|---|---|
| 1 (Dizzy, Una, Cole, Daphne II, Papillon, Patong, Jaen…) | 19 | 84% | 1 |
| 2 (Cosmopolitan II, Tulum, Dorset, Oscar, Campeche, Harrison II, Lounge, Coquille) | 28 | 61% | 2 |

- Os painéis **ganharam em almofadas**. Em **cascas, encostos, cabeceiras e chaise o Box ainda é melhor**.
- As métricas ("espelhado", "trama torta") **erram como juiz**: barraram painéis que o usuário preferiu. Por isso quem decide é o desenhista.
- Às vezes o UV original do arquivo é o melhor (Oscar, Coquille).
- Ficaram pendentes: encaixe entre painéis, trama ondulada em algumas faixas, borda do topo no Oscar.

## 5. O que aconteceu no teste da v1.3.0 (27/10)

- Em **dois produtos**, o Painéis **travou o Max** (uma CPU a 100%, 16 GB de RAM, "Não respondendo" por vários minutos).
- Nas peças que saíram, **as direções ficaram quebradas** (a trama muda de sentido entre painéis ou dentro deles).
- A causa do travamento não foi investigada (o Max não respondia ao MCP). Os suspeitos pelo código são a busca de costura pelo vivo (grade de 1 cm e distância de cada aresta, em `Separar`/`MontarGrade`) e o Unfold3D por painel em peça grande.

## 6. Limites da abordagem atual

1. **Tudo é adivinhado pela geometria.** O vivo muitas vezes encosta no corpo sem fechar o contorno, ou fica a mais de 3 cm, e a peça cai no molde em caixa, que não segue as costuras reais.
2. **A direção da trama é deduzida** pelo eixo do anel ou da normal. Nada no modelo diz para que lado a trama corre em cada painel.
3. **Não há juiz automático confiável:** as métricas discordam do olho. A decisão fica toda com o desenhista, no Ver UV.
4. **Desempenho:** muitos laços em MaxScript por face e por aresta, mais o Unfold3D por painel. Isso não escala para corpos de dezenas de milhares de faces.
5. **Complexidade:** ~6 mil linhas entre Mapear, Painéis, Ver UV, RWF e Auto UV, com interações entre os registros (pilha de Painéis × Mapear × RWF) que pesam em cada mudança.

## 7. Ideia levantada em 27/10 (não decidida)

O desenhista selecionaria à mão as **arestas de costura** (e, se possível, indicaria a **direção** da trama em cada painel), e o plugin usaria isso como limite em vez de procurar os vivos. A etapa que recorta a peça por um conjunto de arestas de costura já existe (`InLab_Paineis_Regioes`). Ficou em aberto enquanto o usuário estuda outras abordagens.
