# Mapear assistido (Cortar e Sentido): plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** trocar o Painéis automático pelos botões **Cortar** e **Sentido**. O desenhista marca as costuras (arestas da base) e a aresta-guia da trama; o plugin abre os painéis com um Unfold3D só, na escala e na direção certas, e grava o canal 1.

**Architecture:** um módulo novo, `functions/fn_mapear_cortar.ms`, com as marcas guardadas no nó, os painéis pelas costuras, o UV e os orquestradores `InLab_Cortar` e `InLab_Sentido`. Ele carrega depois de `fn_mapear_paineis.ms`, que fica só com a infraestrutura comum: vivos por elemento, regiões, contornos, UV de disco e anel, Unfold3D, escala, gravação, pilha e Desfazer Painéis. O `InLab_Paineis_Peca` é dividido em preparar (guardas, base) e aplicar (RWF fora, gravação, registro), e o Cortar reusa os dois. O automático (busca de vivo, molde em caixa, trama torta) sai.

**Tech Stack:** MaxScript (3ds Max 2024; 2025 e 2027 sem Corona), polyop, `Unwrap_UVW` + `Unfold3DSolve`, appData do nó.

**Spec:** `docs/superpowers/specs/2026-10-27-mapear-assistido-design.md` (inclui o resultado da sonda, seção 9.1). **Referência da sonda:** a lógica testada em 27/10 está descrita na seção 9.1; o fluxo dela é o da Task 4 (projeção por painel → um `InLab_Paineis_Unfold` com todas as faces → giro por painel).

## Global Constraints

- Código, comentários, log e UI em português; funções públicas `InLab_*`, constantes `INLAB_*`; cabeçalho `/* === ... === */` com histórico datado (CLAUDE.md).
- Módulo novo só existe no manifesto `INLAB_MODULOS` (`InLabChecker.ms`), logo depois de `functions\fn_mapear_paineis.ms`.
- `fn` que chama outro `fn` definido mais abaixo precisa de `global` antes (`tests/test_globais_adiantados.ms`).
- Coordenadas da lógica em **mundo**: `polyop.getVert` na base × `o.objectTransform`.
- Trama = **V** da textura. Regra padrão: painel em anel → eixo do anel; senão normal média (pela área) com `|n.z| > 0,7` = deitado → Y do mundo; senão Z do mundo. Limiar numa constante `INLAB_CORTAR_LIMIAR_DEITADO = 0.7`.
- Painel minúsculo: menos de **4** faces → `#warn`, aberto mesmo assim.
- Ângulo do Sentido de **−90° a 90°**, padrão 0°.
- Escala: `InLab_Paineis_Escala o id` por ID; painel que mistura IDs usa a do ID com mais faces nele.
- Face morta na base sai antes de ler índices (`InLab_Paineis_TirarMortas`, hotfix 1.3.2).
- Operação na cena em `undo "InLab Cortar" on (...)` / `undo "InLab Sentido" on (...)`; `select`/`modPanel` em `with undo off`.
- Nunca `polyop.getFacesUsingEdge` aresta por aresta: use `polyop.getEdgeFaces`.
- Funções que trocam material ou exportam chamam `InLab_VerUV_Garantir()` (guarda `!= undefined`).
- Validar no Max (MCP). Teste: `fileIn @"<repo>\tests\test_<nome>.ms"` em cena vazia; resultado em `(getDir #temp) + "\inlab_test_<nome>.txt"`. Cada arquivo de teste abaixo de 120 s.
- Commits em português, sem acento no assunto, `feat(uv): ...` / `fix(uv): ...`.

## Review Focus

1. **Peça girada, com pivô longe da origem ou espelhada (escala −1):** painéis, guia e trama iguais aos de uma cópia na origem; nenhuma ilha espelhada no sentido de render. Teste na Task 4.
2. **Seleção de arestas feita num Edit_Poly do stack, ou base Editable Mesh:** nada muda e o log diz o que fazer; a base nunca é convertida pelo Cortar. Teste na Task 5.
3. **Cortar logo depois de um Sentido** (a seleção da base voltou a ser a das costuras): o corte sai igual ao anterior, sem tomar as guias por costuras. Teste na Task 6.
4. **Reabrir o .max (ou recarregar o plugin) depois do Cortar:** costuras e guias continuam na peça, o Mapear pula a peça com `#info`, e um Sentido ainda funciona. Teste na Task 5 (appData depois de `holdMaxFile`/`fetchMaxFile`).
5. **Peça grande (≥ 30 mil faces) ou com face morta:** termina em menos de 60 s, com uma linha de log por etapa, e sem laço que não termina. Teste na Task 5 (ChamferBox denso de ~30 mil faces com uma face morta).

---

### Task 1: Dividir o InLab_Paineis_Peca em preparar e aplicar

Sem mudança de comportamento: o Painéis automático continua funcionando até a Task 7.

**Files:**
- Modify: `functions/fn_mapear_paineis.ms` (`InLab_Paineis_Peca`, ~linhas 1390–1690; cabeçalho)
- Modify: `functions/fn_mapear.ms:145-154` (campo novo em `MapearRecord`)
- Test: `tests/test_mapear_paineis.ms`, `tests/test_mapear_paineis2.ms` (já existem)

**Interfaces:**
- Produces:
  - `struct InLab_PaineisPrep ( tec, grupos, rwfMods, baseAntes, convertida, copiaBase )`
  - `InLab_Paineis_Preparar o produto` → `InLab_PaineisPrep` ou `undefined` (com o log de cada guarda de hoje: não é tecido, modificador de mapeamento no canal 1, Unwrap sobre base não-poly, conversão que muda os triângulos). Inclui os passos 1 e 2 de hoje e o `InLab_Paineis_TirarMortas`.
  - `InLab_Paineis_Aplicar o prep uv refeitasCmPorID rodada` → `#(#refeita, MapearRecord)` ou `#(#pulada, undefined)`. `uv` = `#(uvs, mapa)`; `refeitasCmPorID` = `#(#(id, cm)...)`. Faz os passos 5 e 6 de hoje (RWF fora, bitmaps religados, UV avaliado das faces sem painel, registro, gravação, `catch` que restaura). Não faz log de resumo: quem chama faz.
  - `InLab_Paineis_DevolverBase o prep` (a "revisão final" de hoje: peça não refeita volta à base de antes).
  - `MapearRecord` ganha `marcas = undefined` (o Cortar guarda ali as marcas de antes, Task 5).
- Consumes: as funções de `fn_mapear.ms` que o `InLab_Paineis_Peca` já usa.

- [ ] **Step 1:** Atualize a branch com a `main` (hotfix 1.3.2, PR #210): `git merge main`. Rode `tests/test_mapear_paineis.ms` e `tests/test_mapear_paineis2.ms` no Max. Esperado: 69 PASS e 8 PASS, nenhum FAIL (a linha de base).
- [ ] **Step 2:** Extraia `InLab_Paineis_Preparar`, `InLab_Paineis_Aplicar` e `InLab_Paineis_DevolverBase` de dentro de `InLab_Paineis_Peca`, que passa a chamar os três (passos 3 e 4 ficam nele). Acrescente `marcas = undefined` ao `MapearRecord`. Pré-declare os globais novos no bloco `global` do topo.
- [ ] **Step 3:** Rode de novo os dois testes e `tests/test_globais_adiantados.ms`. Esperado: os mesmos 69 e 8 PASS, e PASS no de globais.
- [ ] **Step 4:** Commit: `refactor(uv): Paineis dividido em preparar e aplicar`.

---

### Task 2: Marcas guardadas na peça (costuras e guias)

**Files:**
- Create: `functions/fn_mapear_cortar.ms` (cabeçalho, globais, esta parte)
- Modify: `InLabChecker.ms` (manifesto: depois de `functions\fn_mapear_paineis.ms`)
- Test: `tests/test_mapear_cortar.ms` (novo, no padrão de `tests/test_mapear_paineis.ms`: pré-declarar globais, `fileIn` dos módulos de `test_mapear_paineis.ms` + `fn_mapear_cortar.ms`, logger no arquivo, `checar`, apagar o criado)

**Interfaces:**
- Produces:
  - `INLAB_CORTAR_APPDATA_COSTURAS = 7301`, `INLAB_CORTAR_APPDATA_GUIAS = 7302` (índices de `setAppData` no nó; nenhum outro módulo usa appData hoje).
  - `struct InLab_CortarMarcas ( nFaces, nArestas, costuras, guias )`, com `costuras` = bitarray de arestas da base e `guias` = `#(#(aresta, angulo)...)`.
  - `InLab_Cortar_LerMarcas o` → `InLab_CortarMarcas` ou `undefined` (sem marca). Se `nFaces`/`nArestas` não batem com a base: `#warn (o.name + ": a malha mudou desde o último corte; marque as costuras de novo.")`, apaga as marcas e devolve `undefined`.
  - `InLab_Cortar_GravarMarcas o marcas` (grava as duas appData).
  - `InLab_Cortar_ApagarMarcas o` e `InLab_Cortar_TemMarcas o` → bool (não confere topologia; para o Mapear).
  - Formato *(decisão deste plano)*: costuras = `"<nFaces>;<nArestas>;<e1>,<e2>,..."`; guias = `"<e>:<ang>;<e>:<ang>"` (ângulo com `formattedPrint ... format:".2f"`, ponto decimal).

- [ ] **Step 1: Teste que falha.** Em `tests/test_mapear_cortar.ms`, num `ChamferBox` convertido para Editable Poly:
  - `checar "marcas: sem marca devolve undefined" ((InLab_Cortar_LerMarcas cx) == undefined)`
  - grave costuras `#{1,5,9}` e guias `#(#(12, 45.0))`, leia: `checar "marcas: ida e volta" (m.costuras as string == "#{1, 5, 9}" and m.guias[1][1] == 12 and m.guias[1][2] == 45.0)`
  - `holdMaxFile()` + `fetchMaxFile quiet:true`, pegue o nó pelo nome e leia de novo: `checar "marcas: sobrevive ao salvar e reabrir" (...)`
  - mude a topologia (`polyop.deleteFaces` de uma face) e leia: `checar "marcas: topologia mudada descarta com #warn" (r == undefined and temLog logs #warn "a malha mudou" "" and not (InLab_Cortar_TemMarcas cx))`
- [ ] **Step 2:** Rode. Esperado: FAIL ("Call needs function or class").
- [ ] **Step 3:** Implemente as funções da seção Interfaces em `functions/fn_mapear_cortar.ms` e acrescente o módulo ao manifesto.
- [ ] **Step 4:** Rode o teste e `tests/test_globais_adiantados.ms`. Esperado: PASS em tudo.
- [ ] **Step 5:** Commit: `feat(uv): marcas de costura e guia guardadas na peca`.

---

### Task 3: Painéis pelas costuras, piques e corte do anel

Só geometria: nada é gravado.

**Files:**
- Modify: `functions/fn_mapear_cortar.ms`
- Modify: `functions/fn_mapear_paineis.ms` (`InLab_Paineis_UVAnel` ganha `corte:undefined`)
- Test: `tests/test_mapear_cortar.ms`

**Interfaces:**
- Consumes: `InLab_Paineis_Elementos`, `InLab_Paineis_EhVivo`, `InLab_Paineis_Regioes po faces costura`, `InLab_Paineis_Contornos po fs`.
- Produces:
  - `struct InLab_CortarPaineis ( paineis, aneis, piques, cortesAuto, minusculos )`: `paineis` = array de bitarrays de faces; `aneis` = array de bool (paralelo); `piques` = bitarray de arestas; `cortesAuto` = bitarray das arestas do corte automático; `minusculos` = quantos painéis têm menos de 4 faces.
  - `InLab_Cortar_Paineis o corpo costuras` → `InLab_CortarPaineis`. `corpo` = faces de tecido sem os vivos (bitarray da base).
  - `InLab_Cortar_IdsCanto po fs cortes` → `#(mapa, nIds)`, com `mapa` = `#(#(face, #(id por canto)))`. Cada vértice ganha um id por grupo de faces de `fs` em volta dele ligadas por arestas que não estão em `cortes`. É o que abre o UV inicial nas costuras e nos piques.
  - `InLab_Paineis_UVAnel po posM fs k escala perfil:false corte:undefined`: `corte` em graus substitui o 135°/−90° de hoje.
- Regras (da spec 5.2 e 5.3):
  - Pique = aresta de costura com a mesma região dos dois lados.
  - Anel = região com `InLab_Paineis_Contornos >= 2`. Se nenhum pique da região toca as duas bordas, é corte automático. O corte é o caminho mais curto de arestas (Dijkstra pelo comprimento em mundo) entre um vértice de cada contorno, só por vértices do lado escondido: Y maior que o centro da região, ou Z menor se o eixo do anel é horizontal. Ele entra em `cortesAuto`.
  - O eixo do anel é `InLab_Paineis_EixoAnel`.

- [ ] **Step 1: Testes que falham** (`ChamferBox length:100 width:100 height:20 fillet:5`, segmentos densos como em `test_mapear_paineis.ms`):
  - Costuras nas arestas entre faces de normal `|n.z| > 0,7` e as outras (calcule no teste, como a sonda): `checar "paineis: caixa com costura no tampo e no fundo dá 3 painéis, 1 anel" (r.paineis.count == 3 and (for a in r.aneis where a collect a).count == 1)`
  - `checar "paineis: anel sem pique ganha corte automático atrás" (not r.cortesAuto.isEmpty and <todo vértice de r.cortesAuto tem y > centro.y>)`
  - Sem costura: `checar "paineis: sem costura, 1 painel por elemento" (r.paineis.count == 1)`
  - Uma aresta de costura solta no meio do tampo: `checar "paineis: aresta solta vira pique" (r.piques.numberSet == 1)`
  - Uma costura que isola 2 faces: `checar "paineis: painel minúsculo contado" (r.minusculos == 1)`
  - `InLab_Cortar_IdsCanto` num plano 2×2 com a aresta do meio como corte: `checar "ids: corte duplica os vértices da aresta" (nIds == 9 + 2)`
- [ ] **Step 2:** Rode. Esperado: FAIL.
- [ ] **Step 3:** Implemente `InLab_Cortar_Paineis` e `InLab_Cortar_IdsCanto`, e o `corte:` do `UVAnel`. Monte a adjacência uma vez (`polyop.getEdgeFaces`, `polyop.getEdgeVerts`) e nada por aresta com `getFacesUsingEdge`.
- [ ] **Step 4:** Rode este teste e `tests/test_mapear_paineis.ms` (o `UVAnel` sem `corte:` tem que dar o mesmo de antes). Esperado: PASS.
- [ ] **Step 5:** Commit: `feat(uv): paineis pelas costuras, piques e corte do anel`.

---

### Task 4: UV da peça: projeção, um Unfold3D, escala e direção

**Files:**
- Modify: `functions/fn_mapear_cortar.ms`
- Test: `tests/test_mapear_cortar.ms`

**Interfaces:**
- Consumes: `InLab_CortarPaineis` (Task 3), `InLab_Paineis_UVDisco`, `InLab_Paineis_UVAnel ... corte:`, `InLab_Paineis_CopiaBase`, `InLab_Paineis_Unfold`, `InLab_Paineis_AngDir`, `InLab_Paineis_EspelhoUV`, `InLab_Paineis_Sinal`, `InLab_Paineis_PosMundo`, `InLab_Paineis_NormalArea`.
- Produces:
  - `InLab_Cortar_UV o pn escPorPainel guias` → `#(uvs, mapa, nGuia, nRegra)` ou `undefined` (com `#warn`). `pn` = `InLab_CortarPaineis`; `escPorPainel` = UV por cm de cada painel; `guias` = `#(#(aresta, angulo)...)`.
  - `InLab_Cortar_DirRef o po posM fs anel guia` → vetor de mundo da trama do painel: com guia, o vetor da aresta girado pelo ângulo em torno da normal média; sem guia, a regra padrão (Global Constraints).
  - `InLab_Cortar_Orientar o po posM uvs sub dir` gira os índices de UV do painel até `dir` cair no V (o menor giro, já que a aresta não tem sentido) e inverte o U se a ilha sai espelhada. Devolve o ângulo final.
  - `INLAB_CORTAR_MAX_FACES_UNFOLD = 200000` *(decisão deste plano, pela sonda: 13.450 faces em 4 s)*. Acima disso, ou se o `InLab_Paineis_Unfold` devolve `undefined`, a peça fica com a projeção do UV inicial, com `#warn`.
- Fluxo (o da sonda, seção 9.1 da spec):
  1. UV inicial por painel com os ids de `InLab_Cortar_IdsCanto` sobre costuras + piques + `cortesAuto`. O disco usa as posições do `UVDisco`; o anel usa as do `UVAnel` (com `corte:` no ângulo do pique, se houver).
  2. Um `InLab_Paineis_Unfold` com todas as faces dos painéis. Se as escalas dos painéis diferem, use 1 cm = 1 unidade e reescale cada ilha pela área depois.
  3. Cada ilha é reescalada pela própria área (área 3D / área UV × `escPorPainel`) e orientada com `InLab_Cortar_Orientar`.
  4. Painel que contém a aresta de uma guia usa a guia; se tem duas, vale a primeira, com `#warn`.

- [ ] **Step 1: Testes que falham** (a caixa da Task 3, escala 1/60):
  - `checar "uv: tampo deitado com trama de frente para trás" (<ângulo de Y do mundo no UV do tampo dentro de 90 ± 2>)`, usando `InLab_Paineis_AngDir` com `[0,1,0]`
  - `checar "uv: faixa com trama no eixo do anel (Z)" (<ângulo de Z no UV da faixa dentro de 90 ± 2>)`
  - `checar "uv: densidade de cada ilha dentro de 10% de 1/60" (...)`, com a área UV / área 3D de cada painel
  - Guia numa aresta horizontal no meio da faixa, ângulo 0: `checar "uv: guia horizontal põe a trama na horizontal só na faixa" (<faixa: X no V>; <tampo igual ao sem guia>)`; ângulo 45: `checar "uv: guia a 45 graus" (<dentro de 45 ± 3>)`
  - Mesma caixa com `scale [-1,1,1]` e girada 30° em Z, com o pivô em `[500,300,0]`: `checar "uv: peça espelhada e girada sem ilha espelhada" (<InLab_Paineis_EspelhoUV de cada ilha < 0.01>)` e `checar "uv: mesmos ângulos da cópia na origem" (...)`
  - `checar "uv: nenhum InLab_tmp_* sobra" (...)`
- [ ] **Step 2:** Rode. Esperado: FAIL.
- [ ] **Step 3:** Implemente as três funções e a constante.
- [ ] **Step 4:** Rode. Esperado: PASS, com o arquivo abaixo de 120 s.
- [ ] **Step 5:** Commit: `feat(uv): UV do Cortar com um Unfold3D e direcao por guia ou regra`.

---

### Task 5: Botão Cortar (orquestrador, pilha, marcas, Mapear)

**Files:**
- Modify: `functions/fn_mapear_cortar.ms`
- Modify: `functions/fn_mapear_paineis.ms` (`InLab_DesfazerPaineis` devolve `rec.marcas`)
- Modify: `functions/fn_mapear.ms` (`InLab_Mapear_Peca`: pula peça com marcas, junto da guarda de `InLab_Paineis_TemPeca`, ~linha 811)
- Test: `tests/test_mapear_cortar2.ms` (novo; produto e RWF no padrão de `tests/test_mapear_paineis2.ms`)

**Interfaces:**
- Consumes: Tasks 1 a 4, `InLab_PilhaPaineis`, `InLab_VerUV_Ligar`, `InLab_Mapear_SemRWF`, `InLab_Instancias`, `InLab_AbrirGruposAcima`/`InLab_FecharGrupos`.
- Produces:
  - `InLab_Cortar objs produto` → número de peças cortadas (0 ou 1).
  - `InLab_Cortar_SelecaoArestas o` → bitarray (`polyop.getEdgeSelection o.baseobject`).
- Ordem dentro de `undo "InLab Cortar" on (...)`:
  1. Guardas, cada uma com `#warn` e nada muda: sem produto; nenhuma ou mais de uma peça (`"Cortar: selecione uma peça de tecido só."`); sem RWF; base que não é Editable_Poly (`o.name + ": converta a base para Editable Poly e marque as costuras."`); não é tecido.
  2. Costuras = a seleção de arestas da base, se não vazia, senão `InLab_Cortar_LerMarcas o`. Sem as duas: `#warn (o.name + ": selecione as arestas de costura.")`.
  3. `InLab_Paineis_Preparar`, depois corpo (tecido sem vivos), `InLab_Cortar_Paineis`, escala por painel, `InLab_Cortar_UV` com as guias guardadas, e `InLab_Paineis_Aplicar`.
  4. O `rec.marcas` recebe as marcas de antes (ou `undefined`). Grave as marcas novas (costuras da etapa 2 e guias de antes) e empilhe `#(rec)` em `InLab_PilhaPaineis`.
  5. A seleção de arestas da base passa a ser costuras + `cortesAuto` (os piques não mudam a seleção). Ligue o `InLab_VerUV_Ligar #(o)`.
  6. Log: `o.name + ": N painéis pelas costuras (K piques), M com guia, R pela regra; <cm> cm por tile (em <s> s)."`, mais um `#info` por etapa (painéis, Unfold3D, gravação) com o tempo.
- O Mapear pula a peça com marcas: `#info (o.name + ": peça cortada nas costuras; use Cortar.")`.
- O Desfazer Painéis, depois do `InLab_Mapear_Restaurar` de um rec com `marcas` definido, grava `rec.marcas` de volta (ou apaga as marcas se `rec.marcas == #nenhuma`). *Decisão deste plano: `#nenhuma` marca "não havia marca".*

- [ ] **Step 1: Testes que falham** (`tests/test_mapear_cortar2.ms`):
  - Cortar com costuras na caixa: `checar "cortar: 3 painéis, canal 1 gravado, Ver UV ligado" (...)`, `checar "cortar: marcas guardadas" (InLab_Cortar_TemMarcas cx)`, `checar "cortar: seleção volta às costuras + corte automático" (...)`
  - Sem seleção e com marcas: `checar "cortar: usa as costuras guardadas" (...)`
  - Sem seleção e sem marcas: `checar "cortar: pede as costuras e nada muda" (temLog logs #warn "selecione as arestas" "" and <canal 1 igual>)`
  - Duas peças: `checar "cortar: uma peça só" (...)`
  - Base Editable_Mesh: `checar "cortar: base não-poly recusada sem converter" ((classof cx.baseobject) == Editable_Mesh and temLog logs #warn "converta a base" "")`
  - Seleção de arestas num `Edit_Poly` do stack, e nenhuma na base: `checar "cortar: seleção no stack não vale" (temLog logs #warn "selecione as arestas" "")`
  - Cortar + Desfazer Painéis: `checar "cortar: Desfazer volta o canal 1 exato e as marcas de antes" (...)`
  - `checar "mapear: pula peça cortada" (temLog logs #info "peça cortada nas costuras" "")`
  - ChamferBox de ~30 mil faces com uma face morta (`polyop.setFaceFlags po #{k} 2 mask:2 undoable:false`): `checar "cortar: peça grande com face morta em menos de 60 s" (...)`
  - Reabrir: `holdMaxFile`/`fetchMaxFile`, depois Mapear: `checar "cortar: depois de reabrir, o Mapear ainda pula a peça" (...)`
- [ ] **Step 2:** Rode. Esperado: FAIL.
- [ ] **Step 3:** Implemente `InLab_Cortar`, o pulo no `InLab_Mapear_Peca` e a volta das marcas no `InLab_DesfazerPaineis`.
- [ ] **Step 4:** Rode `test_mapear_cortar2.ms`, `test_mapear_cortar.ms`, `test_mapear_paineis2.ms` e `tests/test_mapear.ms` (o Mapear não pode mudar fora da peça cortada). Esperado: PASS em todos.
- [ ] **Step 5:** Commit: `feat(uv): botao Cortar com marcas guardadas e Desfazer Paineis`.

---

### Task 6: Botão Sentido

**Files:**
- Modify: `functions/fn_mapear_cortar.ms`
- Test: `tests/test_mapear_cortar2.ms`

**Interfaces:**
- Consumes: `InLab_Cortar_LerMarcas`/`GravarMarcas`, `InLab_Cortar_Paineis`, `InLab_Cortar_DirRef`, `InLab_Cortar_Orientar`, `InLab_Mapear_Gravar`.
- Produces: `InLab_Sentido objs angulo` → número de painéis ajustados.
- Comportamento (spec 4.2 e 5.5): a peça precisa de marcas (senão `#warn "corte a peça antes (Cortar)"`). As guias são a seleção de arestas da base menos as costuras. Guia que é costura: `#warn` e ignorada. Duas guias num painel: `#warn`, vale a primeira. Os painéis vêm de `InLab_Cortar_Paineis` com as costuras guardadas. O Sentido lê o UV atual do canal 1 da base (`polyop.getMapFace`/`getMapVert`), reorienta só os painéis com guia nova, grava com `InLab_Mapear_Gravar` dentro de `undo "InLab Sentido" on`, atualiza as guias guardadas (guia nova no mesmo painel troca a antiga), volta a seleção às costuras e loga `o.name + ": sentido de N painel(is) ajustado."`. Não roda Unfold3D e não empilha.

- [ ] **Step 1: Testes que falham:**
  - Depois do Cortar, guia horizontal na faixa, Sentido com 0: `checar "sentido: só a faixa muda" (<faixa com X no V; tampo e fundo com o UV idêntico ao de antes>)`
  - `checar "sentido: Ctrl+Z desfaz" (<max undo; canal 1 igual ao de antes do Sentido>)`
  - Guia numa aresta de costura: `checar "sentido: guia em costura recusada" (temLog logs #warn "costura" "" and <canal 1 igual>)`
  - Sentido seguido de Cortar sem mexer na seleção: `checar "cortar depois de sentido: mesmo corte e guia mantida" (<mesmos painéis; faixa com X no V>)`
  - `checar "sentido: Desfazer Painéis volta para antes do Cortar" (...)`
- [ ] **Step 2:** Rode. Esperado: FAIL.
- [ ] **Step 3:** Implemente `InLab_Sentido`.
- [ ] **Step 4:** Rode `test_mapear_cortar2.ms`. Esperado: PASS.
- [ ] **Step 5:** Commit: `feat(uv): botao Sentido com aresta-guia e angulo`.

---

### Task 7: UI e saída do Painéis automático

**Files:**
- Modify: `ui/rollout_main.ms:541-606` (seção UV e Texturas)
- Modify: `functions/fn_mapear_paineis.ms` (apagar o automático; cabeçalho)
- Modify: `tests/test_mapear_paineis.ms`, `tests/test_mapear_paineis2.ms` (tirar os casos do automático), `CLAUDE.md` (bullet do `fn_mapear_paineis` + `fn_mapear_cortar`)

**Interfaces:**
- Consumes: `InLab_Cortar objs produto`, `InLab_Sentido objs angulo`, `InLab_DesfazerPaineis()`.
- UI *(da spec seção 4)*: linha 1 `button btnCortar "Cortar"` + `button btnPaineisRev "Desfazer Painéis"`; linha 2 `button btnSentido "Sentido"` + `spinner spnAngulo "" range:[-90,90,0] type:#float`; linha 3 o `btnVerUV` de hoje. Cores e fontes de `ui/kit.ms`. Tooltips: Cortar, "Abre o UV do tecido nas arestas de costura selecionadas na base Editable Poly. Confira com o Ver UV."; Sentido, "Alinha a trama do painel à aresta selecionada (mais o ângulo)." Os handlers só leem os controles e chamam as funções.
- Apagar (spec seção 8): `InLab_Paineis` (o botão automático), `InLab_Paineis_Peca` (o que sobrou dele), `VivosDoProduto`, `NosDaCabeca` (confira com grep se alguém fora do módulo usa), `MontarGrade`, `Dist`, `Separar`, `Juntar`, `InLab_Paineis_UV` (o do automático), `TortaP`, `Torta`, `SPerfil`, o `perfil:` do `UVAnel` (se só o automático usa), as constantes `INLAB_PAINEIS_DISTANCIAS`, `INLAB_PAINEIS_LIMIAR_CAIXA` e `INLAB_PAINEIS_VIVO_MAX_PONTOS`, e os globais `INLAB_PAINEIS_GRADE/GMIN/GN/VIVOP`.

- [ ] **Step 1:** Para cada nome a apagar, `Grep` no repo (fora de `docs/`). Esperado: só referências dentro de `fn_mapear_paineis.ms` e dos testes do automático.
- [ ] **Step 2:** Apague as funções e os casos de teste correspondentes, troque os botões na UI e atualize os cabeçalhos e o CLAUDE.md.
- [ ] **Step 3:** Rode `test_mapear_paineis.ms`, `test_mapear_paineis2.ms`, `test_mapear_cortar.ms`, `test_mapear_cortar2.ms`, `test_mapear.ms` e `test_globais_adiantados.ms`. Esperado: PASS em todos. Depois abra o plugin com `fileIn` do `InLabChecker.ms` num Max recém-aberto, sem reload. Esperado: a seção UV e Texturas abre sem erro, com os botões novos.
- [ ] **Step 4:** Commit: `feat(uv): secao UV com Cortar e Sentido; sai o Paineis automatico`.

---

### Task 8: Validação na cena do usuário

**Files:** nenhum (só registro na spec, seção 9.1, se aparecer algo novo).

- [ ] **Step 1:** Na cena com o rolo (`Box002`) e o assento (`Box001`), com o produto escolhido e o RWF feito: marque as costuras pela UI (as do vivo do rolo e as das quinas do assento) e clique em Cortar. Esperado: cada peça em menos de 15 s, o Ver UV ligado, e o log com o resumo da seção 5 da Task 5.
- [ ] **Step 2:** Capture o viewport e renderize no VFB (Corona, `progressive_passLimit` 12 temporário, devolvido depois), como na sonda. Mostre ao usuário.
- [ ] **Step 3:** Selecione uma aresta-guia na faixa do assento e use o Sentido com 0° e com 45°. Capture e renderize de novo.
- [ ] **Step 4:** Desfazer Painéis nas duas peças. Esperado: canal 1 e materiais como antes do Cortar.
- [ ] **Step 5:** Pedir a aprovação do usuário antes do PR.
