# Botão "Mapear": mapeamento automático do canal 1

**Data:** 23/10/2026
**Situação:** proposta para aprovação. Nada implementado no plugin.
**Base:** `2026-10-22-automapeamento-estudo.md` (padrões dos assets profissionais), sondas `2026-10-22-sonda-uv-assets.ms` e `2026-10-23-sonda-uv-cortes.ms`, e o teste descartável de 23/10 nas poltronas Mentha e Vimen (seção 9).

## 1. Por que

O time mapeia o canal 1 com UVW Box. A escala sai certa, mas:

- **o veio da madeira sai atravessado** nos pés, travessas e anéis;
- **vivos e costuras** ficam com cortes à vista e a trama trocando de sentido;
- **peça espelhada** (escala −1) inverte o veio e o relevo do bump;
- o Real World Fix troca o Triplanar por projeção em caixa, que **abre cortes no estofado curvo**.

Ninguém conserta à mão: vai assim para o GLB. O botão existe para que o padrão de um bom mapeamento saia automático, sem o desenhista ter de saber fazer.

## 2. O que é um bom mapeamento (alvo, medido nos assets profissionais)

1. **Densidade uniforme por material** (a escala UV/cm quase não varia na peça).
2. **Direção certa:** o veio da madeira segue o comprimento de cada parte; a trama do vivo corre ao longo dele.
3. **Pouca distorção** (esticamento mediano entre 1,00 e 1,10).
4. **Poucas emendas e escondidas** (embaixo, atrás, em quina viva).
5. **Sem espelhamento.**
6. Material sem textura não precisa de cuidado com UV.

## 3. Objetivos e não-objetivos

**Objetivos**
- Um botão **Mapear** que grava o canal 1 de cada peça conforme a matéria-prima da parte, vinda do JSON.
- Refazer **só o que está ruim ou sem mapeamento**; peça bem mapeada (inclusive unwrap feito à mão) fica como está.
- Log por peça dizendo o que foi feito e por quê, e onde ainda sobra corte à vista.
- Desfazer além do Ctrl+Z.

**Não-objetivos**
- Não substitui o unwrap: as emendas escondidas e a distorção mínima de um unwrap feito à mão não são alcançáveis por projeção.
- Não mexe no canal 3 (Auto UV/bake).
- Não cria materiais nem troca texturas.

**Anti-objetivos (falha mesmo funcionando)**
- Estragar um mapeamento que já estava bom.
- Mudar o tamanho com que a textura aparece em relação ao que o desenhista via no Corona, sem avisar.
- Botão lento a ponto de travar o Max sem retorno (sem log de progresso).

## 4. Onde entra no fluxo

Na seção **UV e Texturas**, depois do Real World Fix: `1 · Real World Fix`, `2 · Mapear`, e o Auto UV (opcional) como hoje. *(Decisão do Claude: o RWF continua obrigatório pela V-42; o Mapear vem depois para não brigar com ele.)*

Pré-requisito: a renomeação pelo JSON já aplicada (materiais `ART_...`/`PD_...`). Peça cujo material não casa com uma parte do JSON é tratada como "sem família" (seção 5.6).

Atua nos **objetos selecionados**, como os outros botões da seção. *(Decisão do Claude.)*

## 5. Como cada peça é mapeada

### 5.1 Classificação

Por material da peça (por ID de material, se for Multi/Sub):

1. Nome do material → parte do JSON (`material_id`).
2. Parte → `materia_prima.familia` (Madeira, Tecido, Metal, Vidro, Fibra de Vidro).
3. Subparte `so3d` (Porta_1, Tampa_1, Puxador_1...) vem com família vazia de propósito: herda da parte-mãe (`subparte_de`).
4. Tabela família → regra (export de 23/10/2026, `G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\Specs\nomenclatura_piloto_60.json`, sem campo de tipo de textura):

| Família (matéria) | Regra |
|---|---|
| Madeira | Veio na aresta longa (5.2) |
| Madeira (Microtextura) | Acabamento pintado, sem veio: peça grande (5.4), trama alinhada |
| Tecido | Tubos (5.3) ou peça grande (5.4) |
| Couro | Igual a Tecido |
| Soleta (couro reconstituído forrando tampos e faixas, costura nas quinas) | Igual a Tecido. Com peças retas, a emenda cai na quina, como no produto real |
| Metal, Fibra de Vidro, Louise (acrílico: Transparente, Jateado, Preto), Vidro | Só garante o canal 1 (5.5) |
| Vazia ou desconhecida | Sem família (5.6) |

Família nova que aparecer no JSON cai em "sem família", com aviso, até entrar na tabela.

Dentro da família Tecido, a peça (ou o elemento da malha) é **tubo** quando a malha é uma grade de quads em anel (vivo, costura, debrum), e **peça grande** nos outros casos.

### 5.2 Madeira: veio na aresta longa

Testado na cadeira de 22/10 e na Vimen de 23/10.

- Projeção por face: o eixo dominante da normal escolhe o plano.
- O U (direção do veio) vai na aresta mais longa do polígono: nas laterais, U vertical se ela for mais vertical que horizontal; no topo, U em X ou em Y.
- Decisão alisada por voto dos vizinhos por aresta, 4 passes, peso `min(4, lado maior / lado menor − 1)`, separando laterais de topo.
- Base sempre com `T × B = normal`: **nenhuma face espelhada**.
- Vértices de UV compartilhados por (vértice, plano, sentido, modo).
- **Direção do veio na imagem: varia de textura para textura** (resposta do usuário). O Mapear descobre a direção pela própria imagem:
  - reduz o difuso para 128×128 e soma a variação de brilho entre vizinhos na horizontal (gx) e na vertical (gy);
  - o veio forma linhas, então a imagem varia mais atravessando o veio: gy/gx > 1,15 é veio horizontal (U = veio), < 1/1,15 é veio vertical (V = veio), e entre os dois é "sem direção";
  - a rotação W do bitmap entra na conta (W = 90° troca o resultado);
  - "sem direção" é textura sem veio: usa U horizontal e avisa no log.
  - Testado em 23/10 em 11 texturas: wengé 1,60 (horizontal), o mesmo girado 0,63 (vertical); walnut da pasta Substance 2,33 (horizontal); oak 0,54 (vertical); mais quatro horizontais e três verticais, conferidas a olho; e uma "madeira" que era pedra marmorizada deu 0,95 (sem direção), também certo.
  - Leitura da imagem por `dotNetObject "System.Drawing.Bitmap"`, com o arquivo copiado e descartado na hora (pegadinha do arquivo travado, CLAUDE.md). Um resultado por arquivo, guardado em cache durante a rodada.
- Limites conhecidos: junta entre peças (pé com anel) com algum ruído; curva a 45° com o veio diagonal.

### 5.3 Tecido, tubos: ao longo do tubo

Testado em 10 tubos (vivos da Vimen, costuras da Mentha), todos reconhecidos.

- Percorre a malha por quads (passo para a direita / para cima a partir de um quad), montando a grade comprimento × volta. Fechada ou aberta em cada direção; tampas (n-gons) ficam com projeção plana.
- Grade irregular (faixas de tamanhos diferentes) → não é tubo, cai na regra de peça grande.
- U ao longo do comprimento (comprimento real acumulado), V na volta.
- Emenda da volta no lado que aponta para o centro do elemento (onde encosta na almofada); emenda do comprimento, em anel fechado, atrás (+Y, a frente do produto é −Y).
- Orientação conferida por amostragem: se a maioria sair espelhada, inverte o V.
- Resultado do teste: emendas à vista com quebra de direção de 11–13% para 0%, espelhamento 0%, 8,7 s nas 12 peças de teste.

### 5.4 Tecido, peças grandes: projeção melhorada

**Não testado ainda; precisa de um teste antes de virar código.** Ideia:

- Projeção em caixa por face, com densidade da família e trama alinhada (U horizontal nas laterais, U em X no topo).
- Regiões grandes: a escolha do lado da caixa é alisada por voto dos vizinhos (como na madeira), para as emendas caírem em quinas e não no meio de uma área lisa.
- Emendas que sobrarem em superfície lisa vão para baixo e para trás quando houver escolha.
- No fim, mede com a sonda de cortes e **avisa no log** as peças que ainda têm corte à vista, sugerindo o unwrap opcional.

**Unwrap opcional** (decisão do usuário: só se a pessoa julgar importante). Uma caixa "Unwrap nas peças grandes de tecido", desligada por padrão. Ligada, essas peças passam pelo motor do Auto UV (Unfold3D) **no canal 1**. Depois a densidade é normalizada para a da família e as ilhas são giradas para a trama ficar alinhada. *(Decisão do Claude: o Auto UV de hoje grava no canal 3, então a opção vive dentro do Mapear e não é o botão Auto UV.)*

### 5.5 Metal, Vidro, Fibra de Vidro

Só garante que o canal 1 existe: Box simples na densidade da família, e só em peça com bitmap. Os profissionais não se preocupam com isso, e material liso não mostra UV.

### 5.6 Sem família

Parte com `materia_prima.familia` vazia (11 partes no export de 18/10, todas de acabamento complementar) ou material que não casa com o JSON: Box simples, com aviso "parte sem matéria-prima no JSON" no log.

## 6. Escala (densidade)

A textura tem de sair no GLB do **mesmo tamanho real** que tinha no Corona. Por ordem:

1. Se o material traz o tamanho real (bitmap em Real-World, Triplanar com `scale`, ou o que o RWF guardou na rodada), usa esse tamanho.
2. Senão, a convenção da família, numa tabela única e ajustável (`INLAB_MAPEAR_ESCALA`):
   - Madeira: **60 cm por tile** (mediana dos assets profissionais: 43 a 76 cm).
   - Tecido: 60 cm por tile (provisório; nos profissionais varia com o padrão, de 17 a 89 cm).
   - Metal, Vidro, Fibra de Vidro: 60 cm por tile (provisório).
3. **Pendente:** a convenção da biblioteca Substance (cm por tile e direção do veio). O usuário ainda não sabe; quando sair, troca-se a tabela sem mexer na lógica.

## 7. O que conta como "ruim" (refazer só o necessário)

Medido por material da peça, com as métricas das duas sondas. Refaz se **qualquer** valer:

| Critério | Limite inicial |
|---|---|
| Sem canal 1 | sempre |
| Escala na faixa do Real-World (UV em cm, ~1 UV/cm) | escala > 0,2 UV/cm |
| Escala longe do alvo | mediana fora de ±30% do alvo da seção 6 |
| Densidade desigual | p90/p10 > 1,3 |
| Emenda à vista com quebra de direção (> 30°) | > 2% do comprimento das arestas |
| UV espelhado (no sentido de render, ver 8) | > 5% das faces |
| Madeira com o veio atravessado | menos de 60% das faces alongadas com U na aresta longa |

Os limites saem das peças medidas e ficam numa tabela ajustável. *(Decisão do Claude; calibrar no plano.)*

## 8. Cuidados técnicos já conhecidos

- **Peça espelhada (escala negativa):** a medida de espelhamento tem de considerar o sinal do transform do nó (o snapshot vem do avesso e o render vira a face). Corrigido na sonda de cortes.
- **Instâncias** compartilham o stack: mapear uma muda todas; tratar uma vez por grupo de instâncias e logar.
- **Grupo fechado:** abrir acima do nó antes de mexer (`InLab_AbrirGruposAcima`), como no Auto UV.
- **`maxOps.cloneNodes` em membro de grupo** também clona as cabeças de grupo e outros membros. Se precisar clonar, não use em membro de grupo.
- **Desempenho:** laço em MaxScript sobre faces; o teste fez 77 mil faces em ~9 s. Para malhas grandes, log de progresso por peça.
- **Pegadinhas do CLAUDE.md** que morderam no teste: `case` inline com `;` e `fn` chamado antes de ser definido sem `global`.

## 9. Evidência do teste (23/10, cena não salva com as poltronas Mentha e Vimen)

| Peça | Antes | Depois |
|---|---|---|
| Vivos da Vimen | 11–13% de emendas à vista com quebra de direção | 0% |
| Costuras da Mentha | 5–12% | 0% |
| Madeira da Vimen | 23% e 76% de faces espelhadas, textura repetindo a cada ~1 cm | 0%, veio ao longo dos pés, 60 cm por tile |

Render com listras de diagnóstico: no vivo do rolo as listras atravessavam o tubo e passaram a correr ao longo dele; no pé de madeira, o veio passou a seguir o pé. Ressalva: as costuras da Mentha têm ~1,6 mm de diâmetro e a melhora não se vê nelas, só nos números.

## 10. Achados fora do escopo (para decidir à parte)

- **UV na escala do Real-World colapsado:** costuras da Mentha e madeira da Vimen repetem a textura a cada ~1 cm, e a V-42 não pega (sem modificador, bitmap já fora do Real-World). Na madeira o RWF já tinha rodado: pode ser bug do RWF. Candidato a verificação nova.
- **Lista embutida desatualizada:** o plugin tem o export de 08/10 (66 produtos); o mais recente é o de 18/10 (60 produtos). A release 1.2.4 não trocou a lista.

## 11. Testes

`tests/test_mapear.ms`, no padrão dos outros testes, com cenas sintéticas:

- tubo fechado (toro), tubo aberto com tampas, anel achatado;
- peça de madeira (pé cônico + travessa) e a mesma espelhada;
- caixa de tecido e peça curva grande;
- peça já bem mapeada (não pode ser refeita);
- instância, grupo fechado e material Multi/Sub.

Cada caso confere pelas métricas das sondas (emendas à vista, espelhamento, escala, veio). Rodar também nas poltronas Mentha e Vimen.

## 12. Decisões técnicas (revisão de 23/10)

Decisões do Claude, para o usuário conferir:

1. **Onde o UV é gravado:** no objeto base (Editable Poly/Mesh), sem colapsar o stack.
   - Os modificadores que só geravam o canal 1 da peça refeita (UVW Map/Xform "InLab RWF*") saem do stack, porque o Mapear os substitui.
   - O resto fica, inclusive o "InLab AutoUV" no canal 3.
   - Instâncias continuam instâncias (o objeto base é compartilhado).
   - O Desfazer guarda o canal 1 antigo do objeto base e as referências dos modificadores tirados, e os recoloca na mesma posição.
   - Isso respeita a decisão de não colapsar (#129).
2. **Escala sem tamanho real no material:** preserva a densidade atual se ela for plausível (de 10 a 300 cm por tile) e só usa a tabela da seção 6 quando ela for absurda (como o UV na escala do Real-World, ~1 cm) ou não existir. Quando trocar, avisa no log com o tamanho antigo e o novo. O critério "escala longe do alvo" da seção 7 passa a valer só contra um tamanho real conhecido.
3. **Triplanar que o RWF mandou para outro canal (#169):** o Mapear grava só o canal 1 e religa ao canal 1 os bitmaps que liam o canal extra. Material com dois tamanhos reais diferentes (Triplanar de 50 cm e bitmap de 300 cm) fica com o tiling de cada bitmap acertado pela razão entre os tamanhos. A troca de canal e de tiling entra no registro do Desfazer. O GLB passa a ter um UV só.
4. **Primeira entrega:** madeira, tubos, metal/vidro/fibra e sem família, mais o teste da projeção melhorada (5.4) como etapa do plano. Critério de aprovação do 5.4: no corpo da Mentha, as emendas à vista com quebra de direção caem pelo menos pela metade em relação ao Box do RWF. Se o teste falhar, as peças grandes de tecido ficam com Box simples e um aviso no log sugerindo o unwrap opcional.
5. **JSON com mais informações:** o plano implementa pela `materia_prima.familia`, com um ponto único de classificação (uma função que devolve o tipo de mapeamento da parte). Um campo novo entra ali sem mexer no resto.
6. **Ordem no fluxo:** o Mapear exige o RWF antes nas peças com Real-World ou Triplanar, do mesmo jeito que o Auto UV (`InLab_RWF_Feitos`), e bloqueia com aviso. Ele pode rodar depois do Auto UV: ele não toca no canal 3 nem no modificador "InLab AutoUV".

## 13. O que fica para o construtor

- Organização em arquivos (sugestão: `functions/fn_mapear.ms`; métricas reaproveitadas das sondas).
- O registro para o Desfazer (struct `*Record`, como nos outros botões).
- O desenho exato da projeção melhorada (5.4), depois do teste.
- Os limites finais da tabela da seção 7.
