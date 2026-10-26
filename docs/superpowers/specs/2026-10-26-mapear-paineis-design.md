# Mapear por painéis: UV do tecido cortado nas costuras

**Data:** 26/10/2026
**Situação:** proposta para aprovação. Nada implementado no plugin.
**Base:** sondagem `2026-10-26-mapear-paineis-sondagem.md` (Gap assento e encosto, Puff Dorset quadrado) e dois testes cegos com o usuário em 26/10 (15 produtos, 47 peças julgadas, seção 9). Script do teste, descartável e fora do repo: `spike_paineis.ms` no scratchpad da sessão. A lógica está descrita na seção 5.

## 1. Por que

O tecido costuma usar CoronaTriplanar, que mistura três projeções e não mostra emenda. O glTF não tem Triplanar, então o Real World Fix troca o Triplanar por UVW Box. Uma caixa projetada num estofado curvo corta a trama onde muda o lado da caixa (quina da frente com o tampo, quinas verticais). O corte aparece no GLB e no IR do Corona depois do RWF. O Mapear de hoje usa Box nas peças grandes de tecido, e a projeção "alisada" foi reprovada em 23/10.

Um estofado de verdade é costurado em painéis (tampo, faixa, laterais). Cortar o UV só nas costuras e abrir cada painel deixa a emenda onde o tecido real também tem costura, embaixo do vivo ou num lugar escondido.

**Importante para quem testar:** o VFB do Corona com o material original (Triplanar) ignora o UV e sempre fica bom. Para avaliar o mapeamento vale a viewport, ou o render depois do RWF. Os dois mostram o UV exatamente como o GLB (conferido em 26/10).

## 2. Decisões do usuário

1. **Quem decide é o desenhista, peça a peça,** se a peça usa painéis ou fica como está. Nada é aplicado sozinho. O automático foi testado e reprovado (seção 9): acertou 70% e escolheu algo pior que o Box em 3 de 47 peças.
2. **O fluxo tem de ser simples.** O desenhista não marca costura nem escolhe molde: seleciona a peça, clica, confere e, se não gostar, desfaz.
3. **Sem sugestão automática no log.** Com 61% de acerto no segundo teste, a sugestão confundiria mais do que ajudaria (proposta do Claude, aceita).
4. **O colapso do stack continua como está** (não colapsar).
5. **Um botão próprio, Desfazer Painéis,** que volta só a última aplicação de Painéis. A peça fica como o Mapear tinha deixado, e o Desfazer Mapear continua como hoje (decisão do usuário, depois da revisão).

## 3. Objetivos, não-objetivos e anti-objetivos

**Objetivos**
- Um botão **Painéis** que gera o UV do canal 1 da peça de tecido selecionada, cortado nas costuras, com a trama alinhada e no tamanho real da textura.
- Um botão de liga e desliga **Ver UV**, que troca por um tempo o material das peças selecionadas por uma textura de listras com "F", para conferir direção, emendas e esticamento, e devolve o material ao desligar.
- Um botão **Desfazer Painéis**, que volta só a última aplicação de Painéis, sem mexer no que o Mapear fez. O Ctrl+Z também funciona.

**Não-objetivos**
- Decidir sozinho onde usar painéis.
- Melhorar cascas, encostos e cabeceiras, onde o Box ainda ganha nos testes.
- Reconhecer e preservar o UV que já vem bom no arquivo (do Marvelous ou feito à mão). O Mapear de hoje já mantém um UV bom; o botão Painéis só age quando o desenhista clica.
- Mexer nos vivos. O Mapear já os trata como tubo.
- Bake, Triplanar no visualizador da plataforma e unwrap opcional.

**Anti-objetivos (falha mesmo funcionando)**
- Mudar uma peça que o desenhista não selecionou.
- Mudar o tamanho da textura em relação ao Corona (a escala vem do RWF, como no Mapear 1.2.9).
- **O material de listras do Ver UV ir para um arquivo salvo ou para o GLB.**
- Travar o Max sem retorno: peça grande (60 mil faces) sem log de progresso, ou laço que leve minutos.
- Perder o Desfazer.

## 4. Onde entra no fluxo

Seção **UV e Texturas**, logo abaixo de `Mapear` / `Desfazer Mapear`, com o mesmo tamanho dos botões de cima: uma linha com **Painéis** e **Desfazer Painéis**, e outra com **Ver UV** (botão de liga e desliga). *(Disposição: decisão do Claude.)*

Uso típico:
1. Real World Fix e Mapear, como hoje.
2. O desenhista liga o **Ver UV** com o produto selecionado e olha as peças de tecido.
3. Seleciona a peça que quer melhorar e clica em **Painéis**. O log diz o que foi feito.
4. Confere no Ver UV. Se não gostou, clica em **Desfazer Painéis**, e a peça volta ao que o Mapear tinha deixado.
5. Desliga o Ver UV.

**Pré-requisitos, iguais aos do Mapear:** produto escolhido, RWF feito na peça (`InLab_Mapear_SemRWF`) e material da peça ligado a uma parte do JSON. **Painéis só age em parte de família tecido** (`InLab_Mapear_RegraDaParte` = `#tecido`). As outras famílias são puladas com `#warn` "Painéis é só para tecido". Num Multi/Sub, age só nos IDs de tecido. *(Decisão do Claude.)*

## 5. Como os painéis são gerados

Tudo em espaço de **mundo**. `polyop.getVert` na base devolve coordenada do **objeto**, e o vivo de outro nó vem do mundo; misturar os dois foi um bug na sondagem (pivô longe da origem).

### 5.1 Vivos do produto

Vivo é um elemento **fechado**, **fino** e **comprido**: raio efetivo `r = 2·V/A < 1,5 cm` (volume e área do elemento; num tubo, 2V/A é o raio) e maior medida `> 12·r`. Os vivos são procurados em todas as peças de tecido do mesmo produto (a mesma cabeça de hierarquia), inclusive dentro da própria peça. Elementos que são vivo não recebem painéis; o UV deles fica como está.

### 5.2 Costuras pelo vivo

As arestas do corpo a menos de `d` de um vértice de vivo são costura. Testa `d` em 0,4 / 0,6 / 0,8 / 1,0 / 1,5 / 2,0 / 3,0 cm e fica com o **menor** que divide o corpo em pelo menos **2 regiões grandes**, cada uma com `max(50, 3%)` das faces. As faces que sobram (a tira embaixo do vivo) vão para o painel vizinho por voto dos vizinhos de aresta.

O limite depende da malha: deu 6 mm no assento da Gap, 1,5 cm no encosto e 1 cm na almofada do Dorset. Por isso a lista de tentativas, e não um número fixo.

Busca de distância por grade espacial de 1 cm. Com mais de 8.000 vértices de vivo, usa uma amostra de até 8.000 (sem amostra, uma peça levou 4,5 min).

**Quando o vivo não separa:** nos testes, o vivo muitas vezes **encosta** no corpo (distância 0) mas não fecha o contorno, ou fica a mais de 3 cm. O log diz qual dos dois casos foi, e a peça segue para o 5.3.

### 5.3 Sem vivo: molde em caixa

Faixa + tampo + fundo pela normal. O eixo é o da **menor medida** da peça, se ela for menor que 0,8 × as outras duas (almofada em pé, fina em Y); senão, Z. Face com `n·eixo > 0,97` é tampo, `< −0,97` é fundo, e o resto é faixa. A fronteira é alisada com 4 passes de voto dos vizinhos.

Com o limiar 0,97, a faixa leva as quinas arredondadas, e a emenda vai para a parte plana do tampo e do fundo, que normalmente fica escondida (embaixo da almofada, no chão).

### 5.4 Tipo de cada painel

Pelo número de contornos (componentes das arestas de borda): **1 = disco**, **2 ou mais = anel**, **0 = inválido**.

### 5.5 Disco

Projeção plana na normal média do painel: T horizontal (`[−n.y, n.x, 0]`; X do mundo se a normal for quase vertical) e `B = n × T`. Depois `Unwrap_UVW` + `Unfold3DSolve` num **nó temporário** com as faces do painel (`polyop.detachFaces ... delete:false asNode:true`). A escala sai da área (área 3D / área UV), para o tamanho real, e a posição do centro. Por fim o giro é travado: o X do mundo cai no U (normal quase vertical), ou o Z do mundo no V (os outros casos). Se o resultado sair espelhado, inverte U.

### 5.6 Anel

**Eixo:** no molde em caixa, o eixo da caixa. Pelo vivo, o eixo do mundo (X, Y ou Z) ao qual as normais do painel ficam mais perpendiculares (menor soma de área × |n·eixo|).

**Corte extra**, para abrir o anel, sempre num lugar escondido: eixo vertical → numa quina de trás (direção entre −X e +Y); eixo horizontal → embaixo (−Z). A frente do produto é −Y.

**Três formas de abrir; fica a de trama menos torta:**
1. **Volta:** U = comprimento ao longo do contorno de fora (o maior raio a cada 2°), V = coordenada no eixo. Num eixo horizontal os papéis se trocam (U = eixo, V = volta).
2. **Unfold3D a partir da volta:** o UV inicial já traz o corte, e o solve respeita a topologia do UV. Depois, giro travado pelo eixo.
3. **Perfil varrido:** como a volta, mas no lugar da coordenada no eixo entra o comprimento medido ao longo do perfil da seção (no plano raio × eixo). Resolve a quina arredondada que dobra para dentro, onde a volta esmaga a textura.

"Trama torta" é a fração da área em que a direção de referência do painel (o eixo do anel), projetada na face e levada ao UV pela combinação exata das arestas, sai a mais de 15° do ângulo alvo. A referência é a do **próprio painel**, não a horizontal do mundo: numa almofada, a trama reta do painel desce pela lateral, e isso está certo.

O Unfold3D só é escolhido se ganhar da melhor das outras duas por pelo menos 2 pontos.

### 5.7 Escala

Por ordem *(decisão do Claude, depois da revisão)*:
1. **A peça já passou pelo Mapear:** o Mapear apaga os "InLab RWF*" do canal 1 quando refaz a peça. Por isso o `MapearRecord` passa a guardar o tamanho que o Mapear usou (cm por tile, por ID), e o Painéis usa esse.
2. **A peça só passou pelo RWF:** a regra do Mapear 1.2.9. Vale o tamanho do "InLab RWF*" da peça (Xform ou UVW Map do Triplanar), ou o tamanho que o RWF deu ao mesmo bitmap em outra peça selecionada.
3. **Senão:** 60 cm.

O Painéis funciona com ou sem o Mapear ter rodado antes. Os bitmaps religados ao canal 1 seguem o Mapear (`InLab_Mapear_CanalOriginal`).

**Por ID** *(revisão final, 26/10)*: cada ID de tecido tem a própria escala (`InLab_Paineis_Escala o id`), o `cmPorID` da rodada grava o cm de cada ID e o tiling de cada bitmap religado usa a escala do ID dele. Um painel que mistura IDs usa a escala do ID com mais faces nele. O log mostra um tamanho só, ou "ID 1 30,0, ID 2 120,0 cm por tile" quando diferem.

### 5.9 Instâncias

Como no Mapear, a base é compartilhada e todas as instâncias recebem o mesmo UV. O corte escondido e o giro são calculados no espaço de mundo da peça selecionada. Se uma instância estiver girada ou espelhada em relação a ela, o log avisa ("instância X girada: corte e trama calculados pela peça Y"). *(Decisão do Claude.)*

### 5.8 Quando não gera

Painel inválido, Unfold3D que falha num disco, ou nenhuma regra que dê pelo menos 2 painéis: a peça **fica como estava**, com `#warn` explicando por quê. Não há avaliação de "ficou melhor que o Box" para aceitar ou recusar. Quem julga é o desenhista, no Ver UV (seção 2). As métricas de qualidade se mostraram pouco confiáveis como juiz (seção 9).

## 6. Gravação, registro e desfazer

Usa a mesma infraestrutura do Mapear (`fn_mapear.ms`):
- base Editable_Poly (`InLab_Mapear_ConverterBase`), com as mesmas guardas de Unwrap acima da base, instâncias e grupos;
- canal 1 gravado na base (`InLab_Mapear_Gravar`);
- modificadores "InLab RWF*" do canal 1 removidos como no Mapear;
- tudo dentro de `undo "InLab Painéis" on (...)`.

**Registro próprio.** Cada clique em Painéis guarda **uma rodada**: as peças e, de cada uma, o canal 1, os modificadores tirados e os bitmaps religados, como o `MapearRecord`. As rodadas ficam numa **pilha** separada do `InLab_UltimoMapear`.
- **Desfazer Painéis** volta só a **última rodada**, e a peça fica exatamente como estava antes dela (o que o Mapear tinha deixado). Com a topologia mudada desde então, `#warn` "use o Ctrl+Z", como no Mapear. Cliques seguidos voltam as rodadas anteriores, uma por vez.
- **Desfazer Mapear** volta antes as rodadas de Painéis da peça que ainda estão na pilha (são mais novas que o Mapear), da mais nova para a mais velha, e tira-as da pilha; depois devolve o registro do Mapear (`InLab_Paineis_RestaurarPeca`). *(Comportamento final, revisão de 26/10.)*
- **O Mapear não refaz peça com painéis** *(decisão do controlador na revisão final)*: uma peça (ou instância) com rodada de Painéis na pilha é pulada pelo Mapear com `#info` "tem painéis; o Mapear não mexe (use Desfazer Painéis antes)" e conta como mantida. Refazer com Box por cima dos painéis perdia o caminho de volta ao UV de antes deles (os "InLab RWF*" e os bitmaps religados que a rodada de Painéis guarda). Por isso o `InLab_Paineis_EsquecerPeca motivo:"o Mapear refez a peça"` não é mais chamado pelo Mapear (a função fica).
- **Desfazer UV** (que já desfaz o Mapear e o RWF) desfaz antes toda a pilha de Painéis, depois o Mapear e por fim o RWF: RWF → Painéis → Mapear → Desfazer UV volta o canal 1 e o stack de antes do RWF.

Só as faces de tecido da peça (os IDs de tecido, menos os elementos de vivo) recebem UV novo; as outras mantêm o UV avaliado, como o Mapear já faz (`InLab_Mapear_UVAvaliado`). Nas faces sem painel (vivos) de um ID cujo bitmap é religado ao canal 1, o canal 1 recebe o UV avaliado **do canal do RWF que o bitmap lia** (× escala / densidade do RWF, que compensa o tiling ajustado): o vivo não muda de tamanho. Bitmap que fica preso no canal do RWF (usado fora da rodada ou por um ID que não é de tecido) gera `#warn` "o material continua lendo o canal N".

Nós temporários (`InLab_tmp_*`) ficam na camada 0, visíveis e não congelados; numa exceção, quem criou apaga, e o fim de `InLab_Paineis` apaga sempre os que sobraram, com `#warn`.

## 7. Ver UV

- **Ligar:** guarda `#(nó, material)` de cada geometria da seleção e aplica um material Standard com a textura de listras e "F" no canal 1 (tiling 3), com `showInViewport`. Sem seleção, `#warn` e não liga.
- **Desligar:** devolve os materiais guardados, incluindo nós que saíram da seleção enquanto estava ligado.
- **Nunca pode ir para o arquivo nem para o GLB:** desliga sozinho antes de salvar (callback `#filePreSave`), ao abrir ou resetar uma cena, ao exportar (no Exportar GLB do plugin) e ao fechar o painel. *(Decisão do Claude.)*
- **A textura de listras** vai no repo, em `ui/img/uv_listras.png` (512 × 512: listras horizontais e um "F" azul que mostra espelhamento). Se faltar, o plugin a gera na hora com `System.Drawing`. *(Decisão do Claude.)*
- Funciona em qualquer peça, não só em tecido. Também serve para conferir a madeira.
- **Painéis com o Ver UV ligado:** o Painéis (e o Mapear) lêem o material **original** guardado pelo Ver UV, e não o de listras, para achar a parte do JSON e os bitmaps. O Ver UV continua ligado e já mostra o UV novo. *(Decisão do Claude.)* A guarda "bitmap usado fora desta rodada" soma os nós do Ver UV cujo material original usa o bitmap (`InLab_VerUV_NosQueUsam`): `refs.dependentNodes` não vê os nós com as listras.
- **`InLab_VerUV_Garantir()`** *(revisão final, 26/10)* = varredura + `InLab_VerUV_Desligar()`; devolve o nº de nós que continuam com as listras. A varredura procura em `objects` nó com o material das listras fora do registro (clone com Shift+arrastar, apagar → salvar → Ctrl+Z, Hold/Fetch): instância de um nó registrado (`InLab_Instancias`) recebe o original dele (`#info`); o resto dá `#err` "aplique o material de novo". Função que troca `o.material` ou exporta chama o Garantir antes: Converter Material (`InLab_ConverterObjetos`, `InLab_ReverterConversao`), RWF (`InLab_RealWorldFix`), Renomear pelo JSON (`InLab_Produto_MateriaisDaSelecao`, `InLab_Produto_Aplicar`), `InLab_ExportGLTF`, `InLab_AbrirExportadorRealTime` e `InLab_RodarVerificacoes`. Os três últimos **recusam** (`#err`, `false`) se ainda sobrar nó com as listras. Os callbacks e o botão Ver UV desligado também usam o Garantir. Sem custom attribute para o original (fica para depois); o autobackup pode disparar `#filePreSave` e desligar o Ver UV (aceito).
- **Desligar** só devolve o original quando o nó ainda está com as listras; material trocado com o Ver UV ligado fica, com `#warn` "material trocado com o Ver UV ligado; mantido". **Ligar** não registra nó que já está com as listras sem registro (guardaria as listras como original).

## 8. Log

Por peça, por exemplo:
- `07129418 (Assento): 3 painéis pelo vivo (6 mm); faixa aberta pelo perfil, corte embaixo; 75 cm por tile.`
- `07129418 (Encosto): vivo não fechou o contorno; molde em caixa (eixo Z), 3 painéis.`
- `07129418 (Almofada): não gerei painéis (painel sem contorno); peça como estava.`

Mais uma linha de progresso por peça ("mapeando por painéis (N faces)...") e uma linha de resumo no fim.

## 9. Evidência dos testes (26/10)

Teste cego: imagens com Box à esquerda e painéis à direita (no 2º, também o UV original), mesma escala de 60 cm, listras com "F". O usuário escolheu sem ver a decisão automática.

| Teste | Produtos | Peças julgadas | Acerto do automático | Escolheu pior que o Box |
|---|---|---|---|---|
| 1 | Dizzy, Una, Cole, Daphne II, Group001, Papillon, Patong, Jaen | 19 | 16 (84%) | 1 |
| 2 | Almofadas Cosmopolitan II e Tulum, Dorset Ø 40, Oscar, Campeche, Harrison II, Lounge, Coquille | 28 | 17 (61%) | 2 |

O que os testes mostraram:
- **Os painéis ganham em almofadas,** com ou sem vivo (Jaen Box017, Group001 Box003, almofadas do Lounge e da Coquille, Dorset Ø 40). Em cascas, encostos, cabeceira e chaise, o Box ainda é melhor.
- **As métricas erram como juiz.** "Espelhado" e "trama torta" barraram painéis que o usuário preferiu (curvatura natural de almofada, normais invertidas no modelo).
- **Às vezes o UV original é o melhor** (Oscar, Coquille). O Mapear de hoje já mantém um UV bom.
- **Comentários do usuário para melhorias futuras:** os encaixes entre painéis, a trama ondulada em algumas faixas e a borda do topo no Oscar.
- **Achados à parte:** ProOptimizer com Keep UV desligado no Dorset (a peça vai para o GLB sem UV); normais invertidas na Dizzy; arquivos do Costa II salvos no Max 2025.

## 10. Pegadinhas já encontradas (seguir o CLAUDE.md, e mais estas)

- `polyop.getFacesUsingEdge` aresta por aresta, em 65 mil arestas, travou o Max por mais de 30 min. Use `polyop.getEdgeFaces`.
- Coordenada de objeto x mundo (seção 5). `snapshotAsMesh` dá mundo.
- `Unfold3DSolve` renumera os vértices de UV: leia por canto de face (`getVertexIndexFromFace`).
- Nomes não diferenciam maiúsculas: a local `a` engole o parâmetro `A`.
- Num `for`, `where` vem antes de `while`.
- Parâmetro de função usado dentro de `collect` num bloco aninhado dá "Bad free thunk"; use um laço.
- Peças com o mesmo nome em produtos diferentes: guarde o nó, não o nome.

## 11. Testes (tests/)

Um teste novo, `test_mapear_paineis.ms`, seguindo o padrão do repo, com geometria montada por script:
- almofada (caixa arredondada) com um anel de vivo no meio da altura → 2 painéis pelo vivo;
- caixa sem vivo → molde em caixa (eixo Z) com 3 painéis, emenda na parte plana;
- almofada em pé (fina em Y) → eixo Y;
- cilindro deitado em X (rolo) → anel X com corte embaixo;
- nó com pivô longe da origem → mesmo resultado (regressão do espaço objeto × mundo);
- escala pelo RWF (Xform de 1/200) → 200 cm por tile;
- Ver UV liga e desliga, devolve os materiais e desliga sozinho no `#filePreSave`;
- Desfazer Painéis volta a peça ao estado do Mapear (canal 1, modificadores e bitmaps), sem mexer nas outras peças que o Mapear refez;
- duas rodadas de Painéis seguidas → dois Desfazer Painéis voltam uma de cada vez;
- Desfazer Mapear depois de Painéis descarta da pilha a rodada da peça;
- peça de família não tecido → pulada com `#warn`.

## 12. Fica com quem implementar

- Os textos exatos de botões, tooltips e log (no tom dos de hoje).
- A estrutura interna: um arquivo novo (`functions/fn_mapear_paineis.ms`, no manifesto depois de `fn_mapear.ms`) ou funções dentro de `fn_mapear.ms`.
- A geometria exata dos testes.
- O desempenho: meta de até 20 s por peça de 20 mil faces, com uma linha de progresso por peça.
