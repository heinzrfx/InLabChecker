# Otimizacao em 3 passos com revisao

**Data:** 23/09/2026
**Status:** aprovado no brainstorm, aguardando revisao da spec
**Issue de origem:** #57 (epic #53)

---

## 1. Problema

A secao Otimizacao so tem o ProOptimizer com um **percentual unico** (VertexPercent) para a selecao inteira. Os modelos da InLab sao modelados no proprio 3ds Max, **com o stack vivo** (TurboSmooth, Chamfer, Shell, primitivas parametricas), e o peso vem da construcao: iteracoes altas, chanfros com muitos segmentos, faces que ninguem ve.

Reduzir a malha pronta com um percentual unico produz, segundo a equipe, **todos** estes sintomas:

- arredondados e curvas facetados;
- pecas pequenas (puxador, ponteira) deformadas ou sumindo;
- textura e UV distorcidos;
- fronteira entre acabamentos (material ID) serrilhada;
- buracos, faces invertidas, sombreamento quebrado;
- e mesmo assim o produto nao chega na faixa de poligonos da familia.

As duas dores escolhidas pela equipe foram **reduzir sem estragar** e **limpar faces escondidas**.

Contexto do produto final (nota tecnica "RA para o site", ago/2026): 1 GLB por SKU no model-viewer, acabamento trocavel por parte em tempo real, AO assado por bloco no canal 3 (o do Auto UV). Nada nesta spec pode quebrar isso.

## 2. Decisoes

| Tema | Decisao |
| --- | --- |
| Abordagem | 3 passos independentes, **cada um com revisao** antes de aplicar (automatico com revisao: menor chance de erro) |
| Ordem de entrega | 1 reduzir na origem -> 2 ajuste fino -> 3 faces escondidas |
| Unidade de contagem | **triangulos** (o que o GLB carrega; nao muda antes/depois do ProOptimizer) |
| Pisos de seguranca | padrao no codigo + ajuste da equipe no `InLabChecker.ini` (sobrevive ao updater). Tela de edicao: nao por enquanto |
| Faces escondidas | contato, peca interna e ponta embutida. **Fundo nao entra** (a RA mostra o produto por baixo) |
| Tela | medidor no topo + os 3 passos numa lista so; Auto UV / Clean UV / Real World Fix vao para uma secao nova "UV e Texturas" |

## 3. Arquitetura

Tres modulos novos em `functions/`, um por passo, mais um nucleo compartilhado. A UI so le controles e chama `InLab_*` (convencao do projeto).

| Arquivo | Responsabilidade |
| --- | --- |
| `functions/fn_otim_nucleo.ms` | contagem em triangulos (`InLab_Otim_Triangulos objs`), faixa-alvo da familia, leitura dos pisos (padrao + `.ini`), registro de reversao generico |
| `functions/fn_otim_origem.ms` | Passo 1: levantar botoes de peso, propor, aplicar, reverter |
| `functions/fn_otim_fino.ms` | Passo 2: ProOptimizer com meta por peca e protecoes (substitui `fn_prooptimizer.ms`, que fica ate o passo 2 entrar) |
| `functions/fn_otim_escondidas.ms` | Passo 3: detectar faces escondidas, aplicar como modificador |

Os tres passos seguem o mesmo contrato, para a UI tratar todos igual:

```
InLab_Otim<Passo>_Calcular objs  -> array de propostas (uma linha da lista cada)
InLab_Otim<Passo>_Aplicar propostas marcadas -> aplica dentro de undo, guarda registro
InLab_Otim<Passo>_Reverter        -> desfaz exatamente o ultimo Aplicar desse passo
```

Proposta = struct com: no, rotulo para a lista, valor antes, valor proposto, triangulos antes, triangulos estimados depois, motivo.

### 3.1 Medidor e contagem

- `InLab_Otim_Triangulos objs`: soma de `(GetTriMeshFaceCount o)[1]` das geometrias (`InLab_EhGeometria`), contando instancias **por no** (o GLB exporta cada no).
- Faixa: `polyMin`/`polyMax` da familia ativa (#29). Sem familia, o modelador digita a meta.
- Cor: verde dentro da faixa, amarelo ate 10% fora, vermelho alem disso.
- **V-03 e V-04 passam a contar triangulos** (mesma funcao). A V-05 conta objetos (draw calls) e nao muda. As faixas das familias foram escritas sem unidade e precisam ser conferidas pela equipe (#36): ate la continuam `provisorio:true`.

### 3.2 Passo 1 · Reduzir na origem

**Botoes de peso** (sondados no Max 2024 em 23/09/2026):

| Onde | Propriedade | Piso padrao |
| --- | --- | --- |
| TurboSmooth, MeshSmooth, OpenSubdiv | `iterations` (e `renderIterations` se `useRenderIterations`) | 1 |
| Editable Poly com NURMS (`surfSubdivide`) | `iterations` | 1 |
| Chamfer (modificador) | `segments` | 1 |
| Shell | `segments` | 1 |
| Lathe, Extrude | `segs` | 8 (Lathe), 1 (Extrude) |
| Cylinder, Cone, Tube, Capsule, ChamferCyl | `sides` | 12 |
| Cylinder, Cone, Tube | `heightsegs`, `capsegs` | 1 |
| Sphere | `segs` | 12 |
| Torus | `segs`, `sides` | 12, 8 |
| ChamferBox, ChamferCyl | `Fillet_Segments` | 1 |
| Box | `lengthsegs`, `widthsegs`, `heightsegs` | 1 |
| Splines renderizaveis (Line e afins) | `steps`, `render_sides` | 2, 6 |

Modificador desligado (`enabled` falso ou `enabledInViews` falso) e ignorado: nao conta no export.

**Segmentos que definem forma ficam fora.** Segmento de primitiva (Box, Cylinder etc.) ou de Editable Poly que alimenta, mais acima no stack, um modificador de subdivisao (TurboSmooth, MeshSmooth, OpenSubdiv) ou um deformador (Bend, Twist, Taper, FFD, Noise, Displace) **nao e proposto**: ali os segmentos sao a gaiola ou o suporte da deformacao, e baixar muda a forma da peca, nao so a densidade. Nesses casos o botao valido e o da subdivisao, nao o da base.

**Calculo da proposta:**

1. Para cada botao, medir o custo de baixar **um degrau**: alterar o valor, avaliar o no, ler `GetTriMeshFaceCount`, voltar ao valor original. Nada fica alterado ao fim do levantamento.
2. Modificador compartilhado por instancias: a economia e multiplicada pelo numero de nos que o usam.
3. Guloso: a cada rodada, baixar o degrau com maior `economia / dano`. Dano por degrau: **2** para iteracao de subdivisao (o degrau corta ~75% das faces daquela etapa e e o que mais muda a silhueta), **1** para os demais. Os pesos ficam na mesma tabela dos pisos. Parar quando o total entrar na faixa (mira no centro) ou quando todos os botoes estiverem no piso.
4. Se nao couber nem com tudo no piso: a proposta vai ate o piso, e o log diz quantos triangulos ainda faltam (entrada do passo 2).

**Pisos:** tabela `INLAB_OTIM_PISOS` no topo de `fn_otim_nucleo.ms`. Cada entrada pode ser sobrescrita no `.ini` (`InLab_PrefLer "piso_<chave>"`, ex.: `piso_turbosmooth=2`). O log mostra os pisos em uso a cada calculo. Pisos por familia: nao agora; se precisar, vira campo de `FamiliaConfig` que vale por cima dos gerais.

**Registro:** `#(alvo, propriedade, valorAntes)` por botao alterado. Reverter devolve os valores exatos.

**Nunca:** colapsar, apagar ou trocar modificador. Propriedade que nao existe no build: pula e loga (padrao de APIs que variam por build).

### 3.3 Passo 2 · Ajuste fino

- Entra depois do passo 1, se o total ainda estiver acima da faixa, ou direto em peca sem stack.
- **Meta por peca:** o orcamento que falta e dividido por **area de superficie**. Peca densa para o tamanho perde mais; peca ja economica fica intacta e a sobra dela vai para as outras.
- **Piso por peca:** nunca abaixo de `max(60% dos triangulos atuais, 300)` (os dois no `.ini`: `piso_fino_pct`, `piso_fino_min`).
- **Instancias:** um ProOptimizer por stack compartilhado (incorpora a correcao de #42).
- **Protecoes ligadas:** `LockMat` (fronteira de material), `KeepUV` + `LockUV` (borda de ilha), `KeepNormals`, `OptimizationMode` protegendo bordas abertas. Cada uma por sondagem de propriedade, logando a que faltar.
- **Precisao:** calcular, medir, e uma segunda passada se errou a meta em mais de 10%.
- **Comparar:** liga/desliga os ProOptimizer aplicados (`enabledInViews`) para ver antes/depois sem desfazer.
- Mantem o contexto obrigatorio do `.Calculate` documentado em `fn_prooptimizer.ms` (no selecionado, painel Modify, modificador corrente).
- Modificador vivo no stack; Reverter remove exatamente os aplicados.

### 3.4 Passo 3 · Faces escondidas

**Criterio:** so marca face com prova geometrica. A face inteira (centro e os 3 cantos recuados 10% para o centro) tem que passar num destes testes contra **outra** peca:

- **Contato:** raio que sai de `amostra - normal * tol` pela normal bate na outra peca a ate `2 * tol` (tol = 0,5 mm na unidade do sistema, via `units.decodeValue "0.5mm"`).
- **Dentro:** paridade impar de acertos, deduplicados pela distancia, em pelo menos 2 de 3 direcoes "tortas" (nao alinhadas a eixo).

Com isso cobre contato (assento sobre estrutura), peca interna (quadro dentro do estofado) e ponta embutida (pe dentro do tampo).

**Nunca entram:** o fundo (nao ha objeto de chao); pecas animadas (tem keys, V-30) e as faces que encostam nelas (interior de gaveta e porta: V-39); face so parcialmente coberta.

**Implementacao (resultado da sondagem, secao 5):** um `RayMeshGridIntersect` **por peca**, com filtro pelo bbox da peca antes de lancar raio.

**Aplicacao nao destrutiva:** modificador no topo do stack, nomeado `InLab · Faces escondidas` (selecao das faces + apagar). Motivos:

- o bake de AO (V2) precisa das pecas inteiras para a sombra de contato: desliga o modificador, assa, liga de novo;
- Reverter = remover o modificador;
- o colapso acontece no export, onde a V-11 ja exige stack colapsado.

**Revisao:** faces candidatas destacadas na viewport, lista por peca com contagem e motivo (contato / dentro), caixa para desmarcar peca inteira.

**Progresso:** barra por peca; ~20 a 25 s para 100 mil triangulos (secao 5).

## 4. Tela

```
[ Otimizacao ]
  Triangulos: 182.340   faixa da familia: 100 a 200 mil   (verde/amarelo/vermelho)
  Passo:  (1) Reduzir na origem  (2) Ajuste fino  (3) Faces escondidas
  [ Calcular ]
  +-------------------------------------------------------------+
  | [x] Braco_01 · TurboSmooth · iteracoes 3 -> 2 · 42.000 -> 10.500 |
  | [x] Pe_01..04 · Cylinder · lados 32 -> 16 · 1.024 -> 512      |
  +-------------------------------------------------------------+
  [ Aplicar marcados ]  [ Comparar ]*  [ Reverter ]        (* so passo 2)

[ UV e Texturas ]   (secao nova, sem mudar comportamento)
  Auto UV · Clean UV · Reverter Auto UV · Real World Fix
```

- A lista e um `dotNetControl` ListView com checkboxes (linhas criadas em tempo de execucao; mesmo recurso do header). Trocar de passo troca o conteudo.
- Textos seguem a regra de #58: simples, botao com 1 a 3 palavras, detalhe no tooltip.
- O ProOptimizer atual (percentual + alvo da familia) sai quando o passo 2 entrar.

## 5. Sondagem do passo 3 (23/09/2026, Max 2024, via MCP)

**Precisao, cena com resposta conhecida:**

| Caso | Esperado | Marcado |
| --- | --- | --- |
| Base com topo 10x10 sob caixa 5x5 apoiada (contato) | 32 | 32 |
| Caixa apoiada, faces de baixo (contato) | 50 | 50 |
| Esfera dentro de caixa (peca interna) | 224 | 224 |
| Perna entrando 3 cm no tampo (ponta embutida) | 84 | 84 |
| Caixa externa, tampo, laterais | 0 | 0 |

**"Sofa" sintetico** (estrutura, 3 assentos, encosto com TurboSmooth, quadro interno, 4 pes embutidos): nenhuma face marcada visivel. Conferido por numero (raio pela normal de toda face marcada bate em outra peca) e por captura de viewport.

**Tempo:** 15.296 triangulos em 1,7 s; 55.232 em 10,5 s (~190 us/triangulo, levemente superlinear).

**Armadilhas encontradas (entram no CLAUDE.md quando o passo 3 for implementado):**

- `RayMeshGridIntersect` com varios nos: raios erram as pecas longe do primeiro `addNode` (a grade parece dimensionada por ele). Usar uma grade por peca.
- `intersectRay` conta **triangulos** atingidos: raio pela diagonal de um quad conta 2. Deduplicar pela distancia e usar direcoes nao alinhadas a eixo.
- `intersectSphere` devolveu 0 em todos os raios e posicoes testados: nao usar. Distancia ate a malha: `closestFace p` e depois `getHitDist 1`.
- A grade e um retrato do momento do `buildGrid`: mover o no depois nao atualiza.
- `-bitarray` complementa so ate o maior indice marcado, nao ate o total de faces: usar `#{1..n} - marcadas`.

## 6. Testes

Um arquivo por passo, no padrao de `tests/test_renomear_produto.ms`:

- `tests/test_otim_nucleo.ms`: triangulos por no com instancias; faixa com e sem familia; piso do `.ini` sobrescreve o padrao e e apagado no fim.
- `tests/test_otim_origem.ms`: cena com TurboSmooth, Chamfer, Shell, Cylinder, spline renderizavel e instancias. Proposta cai na faixa; pisos respeitados; levantamento nao deixa nada alterado; Reverter volta os valores exatos; modificador desligado ignorado.
- `tests/test_otim_fino.ms`: protecoes ligadas; cada peca a ate 10% da meta; piso protege peca pequena; instancias com um modificador so; Reverter limpa.
- `tests/test_otim_escondidas.ms`: a cena da secao 5 com os numeros exatos; peca animada excluida; fundo nunca marcado; modificador aplicado e removido pelo Reverter.

## 7. Entregas (viram issues no epic #53)

| # | Entrega | Depende de |
| --- | --- | --- |
| O1 | Nucleo + medidor + contagem em triangulos (V-03/V-05) + secao "UV e Texturas" + **tela completa dos 3 passos** | #29 (familia ativa), #55 (mesmo arquivo de UI) |
| O2 | Passo 1 · Reduzir na origem | O1 |
| O3 | Passo 2 · Ajuste fino (substitui o ProOptimizer atual) | O1, #42 |
| O4 | Passo 3 · Faces escondidas | O1 |

**O1 monta a tela inteira**, ja ligada aos 3 passos pelo contrato da secao 3, e cria `fn_otim_origem.ms`, `fn_otim_fino.ms` e `fn_otim_escondidas.ms` no manifesto com uma versao minima:

- passos 1 e 3: `Calcular` devolve `#()` e loga "em construcao";
- passo 2: o comportamento atual do ProOptimizer (percentual unico calculado pela meta), agora como uma linha por peca na lista. Assim a Otimizacao nunca fica sem ferramenta, e o controle antigo (percentual + "Alvo da familia") sai da UI ja em O1.

Com isso O2, O3 e O4 so preenchem o proprio arquivo e o proprio teste: **nao tocam na UI nem no manifesto**, e podem andar em paralelo depois de O1.

## 8. Fora de escopo

- Bake de AO (V2; esta spec so garante que o passo 3 nao atrapalhe).
- Draw calls / attach por material e peso de textura (dores C e D, nao escolhidas agora).
- Pisos por familia e tela de edicao de pisos.
- Otimizacao dedicada ao SketchUp (roadmap item 3).
