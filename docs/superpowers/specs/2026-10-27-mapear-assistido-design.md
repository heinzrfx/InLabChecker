# Mapear assistido: o desenhista marca as costuras, o plugin abre os painéis

Spec de 27/10/2026. Substitui o Painéis automático da v1.3.0 (`2026-10-26-mapear-paineis-design.md`). Estado de partida: `2026-10-27-mapeamento-estado-atual.md` (só local, sem commit). Proposta de origem: `delta_mapeamento_assistido_rafa.md` (base de dados da InLab, fora do repo).

## 1. Por que

O Painéis automático da v1.3.0 **travou o Max nos dois produtos** testados em 27/10 (uma CPU a 100%, 16 GB, minutos sem resposta). Nas peças que terminaram, **a trama saiu quebrada**. O plugin adivinha as costuras (pela distância até o vivo, ou pelo molde em caixa) e a direção (pelo eixo do anel ou pela normal), e julga o resultado por métricas que discordaram do olho no teste cego de 26/10.

O que o desenhista sabe fazer no olho, sem técnica de UV, é dizer **onde o tecido quebra** e **para que lado corre a trama**. O plugin passa a executar essa intenção: abrir, alinhar, pôr na escala e gravar.

## 2. Decisões do usuário (27/10)

1. **Só o assistido.** O Painéis automático sai: busca de vivo, molde em caixa e métricas como juiz deixam o código e a UI.
2. **Costuras por seleção de arestas,** feita pelo desenhista no modo aresta. Aresta que não fecha contorno é um "pique": o plugin avisa e destaca, mas segue.
3. **Direção pela aresta-guia** (não por seta na tela). O desenhista seleciona uma aresta que segue a trama no painel e clica em **Sentido**. Para diagonal, um ângulo.
4. **Painel sem aresta-guia segue a regra padrão:** painel em pé (lateral, faixa, encosto) fica com a trama na vertical do mundo; painel deitado (tampo, assento) com a trama de frente para trás.
5. **Fluxo de dois botões, Cortar e Sentido** (seção 4), aprovado como foi descrito.

## 3. Objetivos, não-objetivos e anti-objetivos

**Objetivos**
- O desenhista corta a peça de tecido nas costuras que ele escolheu e recebe o UV do canal 1 com a trama na direção certa e no tamanho real da textura, em segundos.
- Ajustar a direção de um painel custa uma seleção e um clique.
- Recortar não obriga a marcar tudo de novo.

**Não-objetivos**
- Decidir sozinho onde cortar ou para que lado vai a trama (fora a regra padrão do item 2.4).
- Editor de UV: nada de mover, escalar ou costurar ilhas à mão.
- Tocar no Mapear (madeira, vivos como tubo, Box) ou no RWF. Eles continuam como estão.
- Seta arrastada na superfície (pode vir depois, se o time pedir).
- Empacotar as ilhas em 0–1. O canal 1 é de textura repetida (tiling); ilhas sobrepostas não atrapalham. O canal 3 do bake é do Auto UV, à parte.

**Anti-objetivos (falha mesmo funcionando)**
- **Travar o Max:** laço que leve minutos, ou peça grande sem log de progresso.
- Mudar uma peça que o desenhista não selecionou.
- Mudar o tamanho da textura em relação ao Corona.
- Perder o caminho de volta (Desfazer Painéis e Ctrl+Z).
- O material de listras do Ver UV ir para um arquivo salvo ou para o GLB (a proteção do `InLab_VerUV_Garantir` continua).

## 4. Fluxo na seção UV e Texturas

Os botões **Painéis / Desfazer Painéis** dão lugar a:

| Linha | Controles |
|---|---|
| 1 | **Cortar** · **Desfazer Painéis** |
| 2 | **Sentido** · ângulo (spinner, 0° padrão, de −90° a 90°) |
| 3 | **Ver UV** (o mesmo de hoje) |

*(Nomes e disposição: decisão do Claude. Seguir o `ui/kit.ms`; a lógica fica em `functions/`.)*

1. **Cortar.** Com **uma** peça de tecido selecionada e as arestas de costura selecionadas na base Editable Poly, o desenhista clica. O plugin:
   - guarda as costuras na peça (seção 5.1);
   - recorta em painéis (seção 5.2);
   - abre cada painel com a direção da guia que ele já tinha (seção 5.5) ou com a regra padrão;
   - grava o canal 1, registra para o Desfazer e liga o Ver UV na peça.
   Com nenhuma aresta selecionada, usa as costuras guardadas da peça; se não houver, `#warn` "selecione as arestas de costura" e nada muda.
2. **Sentido.** Na mesma peça já cortada, o desenhista seleciona uma ou mais arestas-guia, no máximo uma por painel, ajusta o ângulo se quiser e clica. O plugin reorienta só os painéis dessas arestas, guarda as guias (seção 5.1) e grava. Os outros painéis não mudam. Duas guias no mesmo painel: `#warn` e vale a primeira. Uma aresta de costura é borda de dois painéis, então guia em aresta de costura é recusada com `#warn` (o desenhista escolhe uma aresta de dentro do painel).
3. **Recortar.** O desenhista muda a seleção de costuras e clica em Cortar de novo. As guias guardadas continuam valendo nos painéis novos que contêm a aresta-guia.
4. **Conferir e terminar.** O desenhista confere nas listras e desliga o Ver UV no próprio botão. Não há botão "Pronto".
5. **Desfazer Painéis** volta a peça como estava antes do Cortar mais recente (seção 6).

A seleção de costuras vai sendo trocada pela de guias. Por isso as costuras ficam guardadas: sem isso, o Recortar obrigaria a remarcar tudo.

**Regras da seleção** *(decisões do Claude, depois da revisão)*:
- A seleção de arestas no Cortar é **o conjunto completo** de costuras, não uma mudança sobre as guardadas.
- **Ao fim de todo Cortar e de todo Sentido, a seleção de arestas da base volta a ser a das costuras guardadas.** Assim o desenhista vê onde cortou, um Cortar logo depois de um Sentido não toma as guias por costuras, e o Recortar é só somar ou tirar arestas da seleção que já está ali. Só as costuras guardadas ficam selecionadas: o corte automático do anel sai no log (`#info` com o número de arestas), não na seleção. Os piques aparecem no log (quantos) e não mudam a seleção.
- Num primeiro Cortar, uma seleção de arestas que sobrou da modelagem é tomada como costura. O log diz quantas arestas foram usadas, e o desenhista vê o resultado nas listras.
- **Onde selecionar:** na base Editable Poly, sem conversão. Base de outra classe (Editable Mesh, primitiva): `#warn` "converta a base para Editable Poly e marque as costuras" e nada muda (a conversão renumera as arestas e a seleção feita antes perderia o sentido). Seleção feita num Edit_Poly do stack não vale: o Cortar lê só a base. Modificador acima da base que muda a topologia (TurboSmooth, Symmetry, Shell) segue as guardas de stack do Painéis de hoje (`#warn` e cálculo na base).
- **Tirar uma guia:** fica fora desta versão. Um Sentido novo no mesmo painel troca a guia; voltar à regra padrão só pelo Desfazer Painéis.

**Pré-requisitos (iguais aos do Painéis de hoje):** produto escolhido, RWF feito na peça (`InLab_Mapear_SemRWF`), material ligado a uma parte do JSON. Só age nas faces dos IDs de família tecido (`InLab_Paineis_EhTecido`); IDs que não são tecido ficam como estão. As guardas de stack (`InLab_Mapear_VarrerStack`), a conversão da base para Editable_Poly com os triângulos conferidos, os grupos abertos e fechados e as instâncias seguem o Painéis de hoje.

**Uma peça por vez** *(decisão do Claude)*: as arestas selecionadas são de uma malha. Com mais de uma peça selecionada, `#warn` e nada muda. Instâncias da peça recebem o mesmo UV, como hoje.

## 5. Como funciona por dentro

### 5.1 O que fica guardado na peça

- **Costuras:** o conjunto de arestas da base usado no último Cortar.
- **Guias:** para cada guia, a aresta e o ângulo.
- Guardados no próprio nó, para irem junto no `.max` salvo e sobreviverem a reabrir o arquivo e a recarregar o plugin. Mecanismo adotado: custom attribute scripted no objeto base (entra no Ctrl+Z e é compartilhado pelas instâncias; appData não entra no undo).
- Os índices de aresta valem para a topologia da base no momento do Cortar. Se a topologia mudou (número de arestas ou de faces), as costuras e guias guardadas são descartadas com `#warn` "a malha mudou desde o último corte; marque as costuras de novo".

### 5.2 Painéis a partir das costuras

- **Faces consideradas:** as faces dos IDs de tecido da peça, menos os elementos que são vivo. O teste por elemento (`InLab_Paineis_EhVivo`: fechado, fino, comprido) continua, porque é barato. Sai a busca de vivo nas outras peças (grade de 1 cm, `VivosDoProduto`, `Separar`, `MontarGrade`, `Dist`, `Juntar`) e o molde em caixa.
- **Regiões:** `InLab_Paineis_Regioes` com as costuras como barreira (já existe). Cada elemento sem costura vira um painel inteiro.
- **Pique:** aresta de costura com a mesma região dos dois lados. Ela não divide nada, mas entra como corte no UV, para o painel abrir melhor. `#info` com quantas arestas são pique; ao fim do Cortar, essas arestas ficam selecionadas na base para o desenhista ver.
- **Painel minúsculo** (menos de 4 faces) gerado por costura mal fechada: `#warn` com o número de faces. Ele é aberto como os outros.

### 5.3 Abertura

**Um Unfold3D só, para a peça inteira** *(decisão do Claude, a confirmar na sonda da seção 9)*, em vez de um nó temporário por painel como hoje:

1. UV inicial por painel com projeção plana pela normal média (o mesmo de `InLab_Paineis_UVDisco`), cada painel uma ilha separada, e os piques também abertos no UV inicial.
2. Esse UV vai para um nó temporário (cópia da base, como `InLab_Paineis_CopiaBase`), com **um** `Unwrap_UVW` e **um** `Unfold3DSolve` em todas as faces. O solve respeita a topologia do UV, então cada ilha abre sozinha.
3. O resultado é lido por canto de face, no poly colapsado. O `Unfold3DSolve` renumera os vértices UV (CLAUDE.md).

**Painel em anel** (a faixa que dá a volta, ou seja, região com dois ou mais contornos de borda e nenhum pique que a abra): sem um corte a mais ele não abre plano. O plugin faz esse corte sozinho (pergunta 1 da seção 10): um caminho de arestas de um contorno de borda ao outro, no lado mais escondido do painel (atrás, Y maior, se o eixo do anel é vertical; embaixo, Z menor, se é horizontal). O caminho entra como pique no UV inicial, sai no log com `#info` e **não fica selecionado** (só as costuras guardadas ficam) nem é guardado como costura: num Recortar ele é recalculado, a não ser que o desenhista tenha marcado um pique no anel. O algoritmo do caminho (o mais curto entre as bordas, restrito ao lado escondido) fica com quem implementar.

**Peça grande:** log de progresso por etapa. O `Unfold3DSolve` é síncrono e não pode ser interrompido, então o teto é uma **previsão pelo tamanho** (faces da peça), calibrada na sonda: acima dele, ou se o solve falhar, a peça fica com a projeção plana do passo 1, com `#warn`. A peça não fica sem UV.

### 5.4 Escala

A regra de hoje, sem mudança: `InLab_Paineis_Escala o id` (cmPorID do Mapear > "InLab RWF*" > densidade medida > tamanho do RWF do mesmo bitmap > 60 cm), por ID. Cada ilha é escalada pela própria área (área 3D / área UV), para o tamanho real. O painel que mistura IDs usa a escala do ID com mais faces nele.

### 5.5 Direção da trama

**Convenção:** a trama é o **V** da textura (o vertical da imagem do tecido). É a mesma convenção do Painéis de hoje (disco em pé: Z do mundo no V; deitado: X no U, logo Y no V).

- **Com aresta-guia:** a direção de referência é o vetor da aresta-guia em mundo, girado pelo ângulo em torno da normal local das faces da aresta-guia (em painel de anel a normal média se anula). A ilha é girada até essa direção, levada ao UV face a face, cair no V em média pela área (`InLab_Paineis_AngDir` + `InLab_Paineis_Girar`, hoje com o eixo deduzido). O sinal da aresta não importa (a trama não tem sentido): fica o giro menor.
- **Sem guia (regra padrão):** normal média do painel (pela área) com `|n.z| > 0,7` = deitado: referência = Y do mundo (frente para trás; a frente é −Y). Senão, em pé: referência = Z do mundo. O limiar 0,7 é *decisão do Claude*, ajustável numa constante.
- **Espelho:** se a ilha sair espelhada (sentido de render, com o sinal do nó como hoje em `InLab_Paineis_EspelhoUV`), inverte o U.
- **Sentido** recalcula só o giro e o espelho das ilhas dos painéis com guia nova. Não roda o Unfold3D de novo: lê o UV atual da peça, gira e grava.

## 6. Gravação, registro e desfazer

- **Gravação:** a mesma do Painéis de hoje (`InLab_Mapear_Gravar`, RWF do canal 1 fora com o UV avaliado das faces que não são tecido, bitmaps religados ao canal 1, `cmPorID`), dentro de `undo "InLab Cortar" on (...)`.
- **Cortar** empilha uma rodada na `InLab_PilhaPaineis` (um `MapearRecord`), como o Painéis de hoje. Recortar empilha outra: o Desfazer Painéis volta ao corte anterior, e outro clique volta ao de antes.
- **Sentido não empilha rodada** *(decisão do Claude)*. Ele grava dentro de `undo "InLab Sentido" on (...)`, então o Ctrl+Z desfaz um Sentido. O Desfazer Painéis volta para antes do Cortar, levando junto os Sentidos feitos depois dele. As guias guardadas também voltam ao estado de antes do Cortar desfeito.
- As regras de convivência com o Mapear continuam: o Mapear não refaz peça com rodada na pilha; o Desfazer Mapear e o Desfazer UV desfazem antes a pilha da peça.
- **Depois de reabrir o .max** *(decisão do Claude)*: a pilha fica só na memória, como hoje, então o Desfazer Painéis não volta mais. As costuras guardadas na peça (seção 5.1) servem de marca de "peça cortada": o Mapear também pula peça com costuras guardadas (`#info` "peça cortada nas costuras; use Cortar"), para não sobrescrever o corte sem aviso.

## 7. Log

- Por peça, no Cortar: `"<peça>: N painéis pelas costuras (K piques), M com guia, R pela regra; <cm> cm por tile (em <s> s)."`
- No Sentido: `"<peça>: sentido de N painel(is) ajustado."`
- `#warn` dos casos das seções 4, 5.1, 5.2 e 5.3 com o nome da peça. Nunca engolir erro sem `InLab_Log`.

## 8. O que sai

Do código e da UI: o botão Painéis automático, `InLab_Paineis_VivosDoProduto`, `InLab_Paineis_NosDaCabeca` (se ninguém mais usar), `InLab_Paineis_MontarGrade`, `InLab_Paineis_Dist`, `InLab_Paineis_Separar`, `InLab_Paineis_Juntar`, o molde em caixa, os geradores de anel (volta, perfil varrido) e a escolha por "trama torta" (`TortaP`, `Torta`), as constantes `INLAB_PAINEIS_DISTANCIAS`, `INLAB_PAINEIS_LIMIAR_CAIXA` e `INLAB_PAINEIS_VIVO_MAX_PONTOS`, e os testes que só cobriam isso. O histórico fica no git. Quem implementar confere com grep que nada fora do módulo usa o que for apagado, e atualiza o cabeçalho do arquivo, o CLAUDE.md (bullet do `fn_mapear_paineis`) e o `tests/test_globais_adiantados.ms`.

## 9. Sonda antes do plano

Na própria cena das peças que travaram em 27/10 (pergunta 2 da seção 10), pelo MCP:
1. Medir cada etapa do Painéis atual numa peça que travou, para confirmar onde estava o travamento.
2. Marcar costuras à mão nessa peça e medir o caminho da seção 5.3: projeção por painel, um Unfold3D, leitura.
3. Ver o resultado no Ver UV e mostrar ao usuário antes de seguir para o plano.

Se o Unfold3D único não aguentar a peça grande, a seção 5.3 volta para decisão antes do plano.

### 9.1 Resultado da sonda (27/10, cena do usuário com o rolo e o assento)

Script da sonda fora do repo (scratchpad da sessão): costuras simuladas pela normal (tampo, fundo e faixa no eixo do assento; pontas no eixo do rolo), projeção plana por painel, `InLab_Paineis_UVAnel` na faixa, **um** `InLab_Paineis_Unfold` com todas as faces do corpo, giro pela regra padrão, gravação numa cópia, Ver UV e render no VFB do Corona.

- **Causa do travamento da v1.3.0: face morta na base.** O assento (`Box001`) tem 2 faces mortas (32.820 em `polyop.getNumFaces`, 32.818 em `getPolygonCount`). Em face morta, `polyop.getElementsUsingFace` devolve vazio, e `InLab_Paineis_Elementos` nunca tira a face do conjunto: laço sem fim, com a RAM subindo até 23 GB. Reproduzido duas vezes. Não era a quantidade de elementos (o rolo tem 5, o assento 2) nem o Unfold3D.
- **Segundo efeito da face morta:** o `polyop.detachFaces` do Unfold3D compacta a malha de origem (tira as faces mortas e renumera as faces depois delas), e a leitura por índice volta errada. Na sonda, `polyop.collapseDeadStructs` numa cópia resolveu.
- **Tempos com um Unfold3D só:** rolo, 2.176 faces de tecido, 3 painéis, **2,8 s** no total (2,4 s de solve). Assento, 13.450 faces de tecido, 3 painéis, **8,3 a 8,8 s** (3,8 a 4,1 s de solve). Nada perto de travar; o teto pelo tamanho da seção 5.3 pode ser generoso.
- **Visual (viewport e VFB):** a faixa do rolo abre limpa em volta; tampas e tampo sem rasgo nem esticamento visível. As listras curvam um pouco na borda das tampas arredondadas.
- **Regra padrão errada na faixa em anel:** a normal média de uma faixa que dá a volta se anula, e a faixa foi tomada por "deitada" (trama na diagonal no VFB). Com a referência = **eixo do anel** para painel em anel, a faixa do assento ficou com a trama na vertical.

**O que muda na spec por causa da sonda:**
- Seção 5.2: no início do Cortar, a base com faces ou arestas mortas passa por `polyop.collapseDeadStructs` (dentro do undo). Faces mortas são invisíveis; a seleção de arestas continua valendo. `#info` com quantas foram tiradas. Toda varredura de elementos ignora face morta e sempre tira a face de partida do conjunto.
- Seção 5.5: painel em anel (dois ou mais contornos antes do corte automático) usa o eixo do anel como referência da regra padrão, não a normal média.
- A correção do laço em `InLab_Paineis_Elementos` vale também para a v1.3.x instalada no time (hotfix à parte, a decidir com o usuário).

## 10. Perguntas abertas para o usuário

Respondidas pelo usuário em 27/10:

1. **Painel em anel sem pique: corte automático.** O plugin abre o anel com um corte reto num lugar escondido (atrás, ou embaixo), com `#info` no log, e a aresta do corte fica selecionada junto com as costuras ao fim do Cortar. Se o desenhista não gostar do lugar, marca o pique onde quiser e corta de novo: um pique marcado no anel dispensa o corte automático.
2. **Cena da sonda:** o usuário abre no Max a cena de um dos produtos que travaram, e a sonda lê pelo MCP qual cena está aberta.

## 11. Testes (tests/)

No padrão de `tests/test_renomear_produto.ms`, numa cena vazia:
- Caixa de tecido com costuras nas 12 arestas de quina: 6 painéis; trama vertical nas 4 laterais, frente para trás no tampo e no fundo.
- Mesma caixa sem costura nenhuma num elemento: 1 painel por elemento.
- Pique: aresta de costura com a mesma região dos dois lados; `#info` e a aresta selecionada no fim.
- Anel: faixa sem pique recebe o corte automático atrás, com `#info`, e abre plana; com um pique marcado no anel, o corte automático não acontece.
- Guia: aresta no meio de uma lateral, horizontal, ângulo 0 → trama horizontal naquela lateral só; ângulo 45 → diagonal.
- Guia em aresta de costura → `#warn` e nada muda.
- Recortar com guia guardada: a guia continua no painel novo que contém a aresta.
- Topologia mudada depois do Cortar: costuras guardadas descartadas com `#warn`.
- Escala: densidade medida dentro de 10% do alvo em cada ilha.
- Desfazer Painéis depois de Cortar + Sentido: canal 1 exato de antes do Cortar.
- Peça espelhada (escala −1): nenhuma ilha espelhada no sentido de render.
- Ver UV: ligado ao fim do Cortar na peça; o `InLab_VerUV_Garantir` das outras funções continua valendo.

## 12. Fica com quem implementar

O formato de gravação das costuras e guias; os nomes internos das funções; como destacar os piques além da seleção; o teto de tempo do Unfold3D (pela sonda); manter ou não a projeção plana como etapa separada.
