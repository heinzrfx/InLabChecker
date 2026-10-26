# Mapear por painéis: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** botões **Painéis**, **Desfazer Painéis** e **Ver UV** na seção UV e Texturas, para o desenhista gerar, conferir e desfazer o UV do canal 1 de uma peça de tecido cortado nas costuras.

**Architecture:** dois módulos novos no manifesto. `functions/fn_mapear_paineis.ms` cuida da geometria (vivos, costuras, painéis, UV), do orquestrador e da pilha de desfazer; reusa a gravação, o registro e as guardas de `fn_mapear.ms`. `functions/fn_ver_uv.ms` cuida da troca temporária de material. A UI só lê a seleção e chama as funções `InLab_*`.

**Tech Stack:** MaxScript (3ds Max 2024; 2025 e 2027 sem Corona), polyop, `Unwrap_UVW` + `Unfold3DSolve`, `System.Drawing` (dotNet) para a textura de listras.

**Spec:** `docs/superpowers/specs/2026-10-26-mapear-paineis-design.md`. **Referência da lógica:** `docs/superpowers/specs/2026-10-26-spike-paineis.ms` (o script do teste, descartável; as funções `SPK_*` mostram cada passo funcionando em cópias). **Sondagem:** `docs/superpowers/specs/2026-10-26-mapear-paineis-sondagem.md`.

## Global Constraints

- Código, comentários, log e UI em português. Funções públicas `InLab_*`, constantes `INLAB_*`, cabeçalho `/* === ... === */` com histórico datado (CLAUDE.md).
- Módulo novo só existe no manifesto `INLAB_MODULOS` de `InLabChecker.ms`, na ordem de dependência: `fn_ver_uv.ms` e `fn_mapear_paineis.ms` **depois** de `functions\fn_mapear.ms`.
- `fn` que chama outro `fn` definido mais abaixo precisa de `global` antes (`tests/test_globais_adiantados.ms` confere).
- Toda coordenada usada na lógica é de **mundo**. `polyop.getVert` na base devolve coordenada de **objeto**: multiplique por `o.objectTransform`. Vivo de outro nó via `snapshotAsMesh` já vem em mundo.
- Frente do produto em −Y; cm.
- Escala: cm por tile vindo do registro do Mapear, senão a regra do RWF do Mapear 1.2.9, senão 60 (`INLAB_MAPEAR_CM_POR_TILE`).
- Valores da spec: vivo = elemento fechado com `2V/A < 1,5` cm e maior medida `> 12·r`; distâncias de costura testadas `#(0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 3.0)` cm; região grande ≥ `max(50, 3% das faces do corpo)`; amostra de vivo ≤ 8000 pontos; molde em caixa com limiar `0.97` e 4 passes de voto; eixo da caixa = menor medida se `< 0.8 ×` as outras duas, senão Z; trama torta = área com mais de 15° de desvio; Unfold3D do anel só se ganhar por 2 pontos; corte do anel: eixo Z em 135° (entre −X e +Y), eixo horizontal embaixo (−Z).
- Operação na cena dentro de `undo "InLab Painéis" on (...)`; `select`/`modPanel` em `with undo off`.
- Nunca usar `polyop.getFacesUsingEdge` aresta por aresta (travou o Max por 30 min): use `polyop.getEdgeFaces`.
- O material de listras do Ver UV nunca pode ser salvo nem exportado.
- Não dar mudança como validada sem rodar no Max (MCP). Testes: `fileIn @"<repo>\tests\test_<nome>.ms"` em cena vazia; resultado em `(getDir #temp) + "\inlab_test_<nome>.txt"`.

## Review Focus

1. **Peça com pivô longe da origem ou girada:** os painéis e o corte têm de sair iguais aos de uma cópia na origem (o espaço objeto × mundo já quebrou a sondagem). Teste na Task 2 e na Task 3.
2. **Ver UV ligado e o usuário salva, abre outra cena ou exporta:** o material original tem de voltar antes. Teste na Task 5.
3. **Painéis numa peça que o Mapear já refez, e depois Desfazer Mapear:** o canal 1 volta ao de antes do Mapear e a rodada de Painéis daquela peça sai da pilha, sem erro. Teste na Task 4.
4. **Seleção com peças que não são tecido, ou Multi/Sub com um ID de tecido:** só as faces de tecido mudam, e as outras peças ficam idênticas. Teste na Task 4.
5. **Peça grande (≥ 20 mil faces):** uma linha de progresso por peça, e nada de laço que passe de ~20 s. Medir na Task 4 com uma esfera de 20 mil faces (registrar o tempo no log do teste; falha se passar de 60 s).

---

### Task 1: Vivos e geometria em mundo

**Files:**
- Create: `functions/fn_mapear_paineis.ms` (cabeçalho, globais, esta parte)
- Modify: `InLabChecker.ms` (manifesto: `@"functions\fn_mapear_paineis.ms"` logo depois de `@"functions\fn_mapear.ms"`)
- Test: `tests/test_mapear_paineis.ms` (criado aqui, cresce nas próximas tasks)

**Interfaces:**
- Produces:
  - `InLab_Paineis_Vert o v` → point3 em mundo (`polyop.getVert (InLab_Mapear_PolyDe o) v * o.objectTransform`).
  - `InLab_Paineis_Elementos po faces` → array de bitarrays (elementos dentro de `faces`).
  - `InLab_Paineis_EhVivo o el` → `#(ehVivo:bool, raio:float, maiorMedida:float)` (fechado, `2V/A < 1.5`, maior medida `> 12·r`).
  - `InLab_Paineis_VivosDoProduto o` → array de point3 (mundo) dos vértices de vivo de todas as peças de tecido sob a mesma cabeça de hierarquia de `o`, inclusive da própria `o`. "Tecido" = `InLab_Paineis_EhTecido no produto` (Task 4) — aqui, receba a lista de nós como parâmetro opcional `nos:` para testar sem produto.

- [ ] **Step 1: Teste que falha.** Em `tests/test_mapear_paineis.ms` (padrão de `tests/test_mapear.ms`: globais pré-declaradas, `fileIn` dos módulos até `fn_mapear_paineis.ms`, logger no arquivo de saída), monte: um Box 100×100×20 arredondado (`ChamferBox` com `Fillet:5`, convertido em poly) e um `Torus radius1:50 radius2:0.6` em Z=10 (vivo). Checagens:
  - `"vivo: toro fino é vivo"` → `(InLab_Paineis_EhVivo toro el)[1] == true`
  - `"vivo: almofada não é vivo"` → `(InLab_Paineis_EhVivo almofada el)[1] == false`
  - `"vivo: VivosDoProduto acha os vértices do toro"` → `count == numVerts do toro`
  - `"mundo: vértice de nó com pivô em [5000,0,0]"` → igual ao `getVert (snapshotAsMesh o)` com tolerância 1e-3.
- [ ] **Step 2: Rodar e ver falhar** (`fileIn` do teste; o arquivo de saída mostra FAIL por função indefinida).
- [ ] **Step 3: Implementar** as quatro funções (ver `SPK_Elementos`, `SPK_VolArea`, `SPK_EhVivo` no spike; volume pelo produto misto dos triângulos do fan, área pela soma).
- [ ] **Step 4: Rodar e ver passar.** Rodar também `test_globais_adiantados.ms`.
- [ ] **Step 5: Commit** `feat(uv): vivos do produto para o Mapear por paineis` (incluir `docs/superpowers/specs/2026-10-26-spike-paineis.ms` neste commit).

### Task 2: Costuras e painéis

**Files:**
- Modify: `functions/fn_mapear_paineis.ms`
- Test: `tests/test_mapear_paineis.ms`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `InLab_Paineis_Separar o corpo vivoPts` → `#(paineis:array de bitarray, metodo:string, eixoCaixa:integer 1..3, diag:string)`. `metodo` = `"vivo (X cm)"` ou `"molde em caixa (eixo X|Y|Z)"`. `diag` = `""`, `"vivo não fechou o contorno (menor distância N cm)"` ou `"vivo a mais de 3 cm"`.
  - `InLab_Paineis_Contornos po fs` → integer (1 = disco, ≥2 = anel, 0 = inválido).
  - `INLAB_PAINEIS_DISTANCIAS = #(0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 3.0)`, `INLAB_PAINEIS_LIMIAR_CAIXA = 0.97`, `INLAB_PAINEIS_VIVO_MAX_PONTOS = 8000`.

Algoritmo (spike: `SPK_MontarGrade`, `SPK_Dist`, `SPK_Regioes`, `SPK_Juntar` e o bloco "molde em caixa" de `SPK_Peca`): grade de 1 cm dos pontos de vivo; distância de cada aresta do corpo (ponto médio, em mundo) ao vivo mais perto (raio de 3 células); para cada distância da lista, arestas abaixo dela viram costura; a menor que dá ≥2 regiões grandes vence; faces soltas por voto. Sem vencedor: molde em caixa pelo `eixoCaixa`.

- [ ] **Step 1: Testes que falham** (reusar a almofada e o toro da Task 1):
  - `"costura: almofada com vivo no meio dá 2 painéis pelo vivo"` → `paineis.count == 2` e `matchPattern metodo pattern:"vivo*"`
  - `"costura: os 2 painéis cobrem todas as faces do corpo"` → soma dos `numberSet` == faces do corpo, sem interseção
  - `"caixa: sem vivo dá molde em caixa no eixo Z com 3 painéis"` (mesma almofada, `vivoPts = #()`) → `count == 3`, `eixoCaixa == 3`
  - `"caixa: almofada em pé (fina em Y) usa o eixo Y"` (ChamferBox 90×20×36) → `eixoCaixa == 2`
  - `"caixa: cilindro Ø40 × 45 fica no eixo Z"` → `eixoCaixa == 3`
  - `"diag: vivo a 5 cm não separa e o motivo diz isso"` (toro deslocado 5 cm para fora) → molde em caixa e `diag` contém `"3 cm"`
  - `"mundo: a mesma almofada com pivô em [5000,300,0] dá os mesmos painéis"` → contagem de faces por painel igual
  - `"contornos: anel 2, disco 1"` na faixa e no tampo do molde em caixa
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar** `InLab_Paineis_Separar` e `InLab_Paineis_Contornos` com os valores das Global Constraints. A amostra de vivo é por passo fixo (`passo = amax 1 (n / 8000)`) num `while` (não `collect` com parâmetro: "Bad free thunk").
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** `feat(uv): costuras pelo vivo e molde em caixa no Mapear por paineis`

### Task 3: UV de cada painel

**Files:**
- Modify: `functions/fn_mapear_paineis.ms`
- Test: `tests/test_mapear_paineis.ms`

**Interfaces:**
- Consumes: Task 2.
- Produces:
  - `InLab_Paineis_UV o paineis metodo eixoCaixa escala` → `#(uvs, mapa, resumo:string)` no formato de `InLab_Mapear_Gravar o uvs mapa` (`uvs` = array de point3; `mapa` = `#(#(face, #(índices em uvs)))`), **sem gravar**. `escala` = UV por cm. `resumo`, por exemplo: `"faixa pelo perfil, corte embaixo; 2 discos"`.
  - `InLab_Paineis_Torta uvs mapa o fs dir alvo` → fração 0..1 da área com desvio > 15° (spike: `SPK_DesalinhoRef`).

Regras (spec 5.5 e 5.6; spike: `SPK_UVDisco`, `SPK_UVAnel` com `perfil:`, `SPK_Unfold`, `SPK_AngDir`, `SPK_Girar`, `SPK_FlipU`, `SPK_Espelho`):
- Disco: plano na normal média, Unfold3D num nó temporário (`polyop.detachFaces ... asNode:true`, apagado no fim; `select`/`modPanel` em `with undo off`), escala pela área, giro travado (X→U se `|n.z| > 0.9`, senão Z→V), inverte U se espelhado.
- Anel: eixo = `eixoCaixa` no molde em caixa, senão o eixo do mundo com menor `Σ área·|n·eixo|`; três candidatos (volta, Unfold3D a partir da volta, perfil varrido); fica o de menor torta, e o Unfold3D só se ganhar por 0,02.
- Unfold3D que falha num disco → a função devolve `undefined` (a peça fica como estava, Task 4).
- O Unfold3D renumera os vértices de UV: leia por canto de face (`getVertexIndexFromFace`).

- [ ] **Step 1: Testes que falham:**
  - `"anel: rolo deitado em X (cilindro 100 × r15) dá U ao longo de X"` → torta (dir X, alvo 0°) `< 0.05`
  - `"anel: corte do rolo fica embaixo"` → as faces com UV descontínuo (vértice de mapa diferente em aresta comum) têm `z` médio abaixo do centro − 0,8·raio
  - `"anel: faixa vertical (molde em caixa) corta na quina de trás"` → faces da costura com `y > centro.y` e `x < centro.x`
  - `"disco: tampo plano sai com o X do mundo no U"` → torta `< 0.02`
  - `"escala: 1/200 por cm dá 200 cm por tile"` → `InLab_Mapear_Medir` na peça gravada: `1/escala` entre 190 e 210
  - `"espelho: nenhum painel espelhado"` → nenhuma face com área de UV negativa (produto vetorial 2D das arestas de UV < 0) em todos os painéis
  - `"mundo: rolo com pivô em [5000,0,0] e girado 30° em Z dá a mesma torta (±0.02)"`
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar** `InLab_Paineis_UV` e `InLab_Paineis_Torta`.
- [ ] **Step 4: Rodar e ver passar.** Conferir também `test_mapear.ms` (nada do Mapear mudou ainda).
- [ ] **Step 5: Commit** `feat(uv): UV de discos e aneis no Mapear por paineis`

### Task 4: Botão Painéis, pilha e Desfazer Painéis

**Files:**
- Modify: `functions/fn_mapear_paineis.ms`
- Modify: `functions/fn_mapear.ms` (`MapearRecord` ganha `cmPorID = #()`, preenchido em `InLab_Mapear_Peca` com `#(id, d.alvo)` de cada decisão refeita; `InLab_ReverterMapear` chama `InLab_Paineis_EsquecerPeca rec.no` depois de restaurar cada peça; cabeçalho com a data)
- Modify: `functions/fn_autouv.ms` (Desfazer UV: antes do `InLab_ReverterMapear`, se `InLab_PilhaPaineis.count > 0`, chama `InLab_DesfazerPaineis tudo:true` e loga `#info` "Desfazer UV: desfazendo antes os painéis.")
- Test: `tests/test_mapear_paineis.ms`, `tests/test_mapear.ms` (regressão do `cmPorID`)

**Interfaces:**
- Consumes: Tasks 1–3; `InLab_Mapear_ParteDoMaterial`, `InLab_Mapear_RegraDaParte`, `InLab_Mapear_SemRWF`, `InLab_Mapear_ConverterBase`, `InLab_Mapear_Gravar`, `InLab_Mapear_UVAvaliado`, `InLab_Mapear_LerCanal1`, `InLab_Mapear_Restaurar`, `InLab_Mapear_DensRWF`, `InLab_Mapear_Grupos`, `InLab_Instancias`, `InLab_DeduplicarInstancias`, `InLab_AbrirGruposAcima`/`InLab_FecharGrupos`.
- Produces:
  - `global InLab_PilhaPaineis = #()`: cada item é uma rodada, `#(MapearRecord...)`.
  - `InLab_Paineis objs produto` → nº de peças refeitas.
  - `InLab_DesfazerPaineis tudo:false` → nº de peças restauradas (só a última rodada, ou todas com `tudo:true`).
  - `InLab_Paineis_EsquecerPeca no` → tira da pilha os registros desse nó (rodadas vazias somem).
  - `InLab_Paineis_EhTecido o produto id:undefined` → bool (`#tecido` pela parte do JSON do material do ID).
  - `InLab_Paineis_Escala o id` → UV por cm (1º o `cmPorID` do último `MapearRecord` da peça em `InLab_UltimoMapear`; 2º `InLab_Mapear_DensRWF` dos "InLab RWF*" no canal do difuso; 3º `1/INLAB_MAPEAR_CM_POR_TILE`).

Comportamento (spec 4, 5.8, 5.9, 6, 8):
- Sem produto → `#warn` e nada muda. Peça sem RWF (`InLab_Mapear_SemRWF`) → `#err` e pulada. Peça sem ID de tecido → `#warn` "Painéis é só para tecido" e pulada.
- Faces que recebem UV novo: as dos IDs de tecido, menos os elementos de vivo. As outras faces mantêm o UV avaliado (como o Mapear, `InLab_Mapear_UVAvaliado`) quando um "InLab RWF*" do canal 1 sai.
- Registro por peça idêntico ao do Mapear (canal 1, `modsTirados`, `bitmapsAntes`, `graus`), numa rodada empilhada em `InLab_PilhaPaineis`.
- Instâncias: uma vez por base; `#warn` se uma instância tem rotação ou espelho diferente da peça selecionada (compare `normalize` das linhas de `objectTransform`, tolerância 1°).
- Log por peça (spec 8) e uma linha de progresso `"<nome>: mapeando por painéis (N faces)..."`.

- [ ] **Step 1: Testes que falham** (produto montado por JSON no teste, como em `test_mapear.ms`, com uma parte `Tecido` e uma `Madeira`; materiais Standard com bitmap; RWF simulado com `append InLab_RWF_Feitos`):
  - `"Painéis: almofada com vivo é refeita e o log diz '2 painéis pelo vivo'"`
  - `"Painéis: peça de madeira na seleção fica idêntica, com #warn 'só para tecido'"`
  - `"Painéis: Multi/Sub muda só as faces do ID de tecido"` (canal 1 das faces do outro ID idêntico)
  - `"Painéis: sem produto, #warn e nada muda"`
  - `"Painéis: sem RWF, #err e peça pulada"`
  - `"Escala: depois do Mapear de 200 cm, os painéis saem com 200 cm"` (Mapear antes → `cmPorID` → medir 190..210)
  - `"Desfazer Painéis: volta a peça ao estado do Mapear, sem mexer em outra peça refeita pelo Mapear"`
  - `"Desfazer Painéis: duas rodadas, dois cliques, uma de cada vez"`
  - `"Desfazer Mapear depois de Painéis: canal 1 de antes do Mapear e pilha sem a peça"` (Review Focus 3)
  - `"Desfazer UV desfaz antes os painéis"` (`InLab_ReverterAutoUV`, log `#info`)
  - `"Instância girada: mesmo UV nas duas e #warn"`
  - `"Peça de 20 mil faces: tempo no log abaixo de 60 s"` (Review Focus 5)
  - Em `test_mapear.ms`: `"cmPorID: MapearRecord guarda o tamanho usado por ID"`
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar** `InLab_Paineis`, `InLab_DesfazerPaineis`, `InLab_Paineis_EsquecerPeca`, `InLab_Paineis_EhTecido`, `InLab_Paineis_Escala` e as mudanças em `fn_mapear.ms` e `fn_autouv.ms`.
- [ ] **Step 4: Rodar e ver passar** `test_mapear_paineis.ms`, `test_mapear.ms`, `test_autouv.ms`, `test_realworldfix.ms`, `test_globais_adiantados.ms`.
- [ ] **Step 5: Commit** `feat(uv): botao Paineis com Desfazer Paineis proprio`

### Task 5: Ver UV

**Files:**
- Create: `functions/fn_ver_uv.ms` (no manifesto depois de `fn_mapear.ms` e antes de `fn_mapear_paineis.ms`)
- Create: `ui/img/uv_listras.png` (512×512; gerar uma vez com o mesmo código do fallback e conferir a imagem)
- Modify: `functions/fn_mapear.ms` e `functions/fn_mapear_paineis.ms`: onde leem `o.material` para achar parte e bitmaps, passam a ler `InLab_VerUV_MaterialDe o`. O `fn_mapear.ms` carrega antes do `fn_ver_uv.ms`: pré-declare `global InLab_VerUV_MaterialDe` e use `o.material` quando ela for `undefined` (testes que não carregam o Ver UV).
- Modify: `functions/fn_export_gltf.ms`: `InLab_AbrirExportadorRealTime` e `InLab_ExportGLTF` chamam `InLab_VerUV_Desligar()` antes de exportar
- Test: `tests/test_ver_uv.ms` (novo)

**Interfaces:**
- Produces:
  - `InLab_VerUV_Ligar objs` → nº de nós trocados (`#warn` e 0 sem objetos).
  - `InLab_VerUV_Desligar()` → nº de nós devolvidos (nós apagados são ignorados).
  - `InLab_VerUV_Ligado()` → bool.
  - `InLab_VerUV_MaterialDe o` → o material original se `o` está no Ver UV, senão `o.material`.
  - `InLab_VerUV_Textura()` → caminho do PNG (`INLAB_ROOT + "ui\\img\\uv_listras.png"`; se faltar, gera em `(getDir #temp) + "\\inlab_uv_listras.png"` com `System.Drawing`: fundo `(240,235,220)`, 8 listras de 18 px `(180,60,30)`, "F" Arial Bold 150 `(30,60,200)` em (170,120); spike: o bloco que gerou `uv_listras_F.png`).
  - Material: `StandardMaterial name:"InLab Ver UV"`, `diffuseMap` = `BitmapTexture` no canal 1, `U_Tiling`/`V_Tiling` = 3, `showInViewport:true`.
  - Callbacks com `id:#InLabVerUV` em `#filePreSave`, `#systemPreReset`, `#systemPreNew`, `#filePreOpen` chamando `InLab_VerUV_Desligar()`.

- [ ] **Step 1: Testes que falham:**
  - `"Ver UV: liga, troca o material de 2 nós e guarda os originais"`
  - `"Ver UV: desliga e devolve exatamente os materiais (inclusive Multi/Sub e undefined)"`
  - `"Ver UV: nó apagado com o Ver UV ligado não quebra o Desligar"`
  - `"Ver UV: salvar com o Ver UV ligado salva o material original"` (`saveMaxFile` em `(getDir #temp)`, recarregar, conferir o nome do material) (Review Focus 2)
  - `"Ver UV: resetMaxFile desliga"`
  - `"Ver UV: MaterialDe devolve o original enquanto ligado"`
  - `"Ver UV: sem o PNG no repo, gera a textura no temp"`
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar** `fn_ver_uv.ms`, o PNG e as trocas para `InLab_VerUV_MaterialDe`.
- [ ] **Step 4: Rodar e ver passar** `test_ver_uv.ms`, `test_mapear.ms`, `test_mapear_paineis.ms`, `test_export_gltf.ms`.
- [ ] **Step 5: Commit** `feat(uv): Ver UV troca o material por listras para conferir o mapeamento`

### Task 6: Botões na UI, documentação e suíte

**Files:**
- Modify: `ui/rollout_main.ms` (rollout `InLabSecUV`, logo abaixo de `btnMapear`/`btnMapearRev`: `button btnPaineis "Painéis"` e `button btnPaineisRev "Desfazer Painéis"` com `width:195 height:24` e `across:2`, como a linha de cima; abaixo, `checkbutton btnVerUV "Ver UV" width:395 height:24`. Handlers: Painéis lê `InLab_SelecaoValida()` e `InLabSecProduto.produtoEscolhido()` e chama `InLab_Paineis`; Desfazer chama `InLab_DesfazerPaineis()`; Ver UV liga com a seleção e desliga, e se o ligar devolver 0 volta o `checkbutton` para desligado. `on InLabChecker_Rollout close` chama `InLab_VerUV_Desligar()`. Comentário datado.)
- Modify: `CLAUDE.md` (pegadinhas novas da spec, seção 10: `getFacesUsingEdge`, "Bad free thunk", objeto × mundo na base)
- Test: suíte completa

- [ ] **Step 1: Teste que falha:** em `tests/test_reload.ms`, `"UI: InLabSecUV tem btnPaineis, btnPaineisRev e btnVerUV"` (conferir pelos controles do rollout depois do reload).
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar** os controles e handlers; textos de tooltip no tom dos vizinhos (Painéis: "Refaz o UV do tecido selecionado cortando nas costuras (vivo) ou em painéis de caixa. Confira com o Ver UV."; Ver UV: "Troca por um tempo o material da seleção por listras para conferir o mapeamento. Desliga sozinho ao salvar e exportar.").
- [ ] **Step 4: Rodar a suíte inteira** (os 31 arquivos de hoje mais `test_mapear_paineis.ms` e `test_ver_uv.ms`): todos PASS. Abrir o plugin pelo `fileIn` do `InLabChecker.ms` e conferir a seção na tela (captura da viewport do painel pelo MCP).
- [ ] **Step 5: Teste manual no Max** com a cena `teste2_cena.max` do scratchpad, se ainda existir, ou o assento da Gap: Painéis numa almofada com vivo, Ver UV, Desfazer Painéis, salvar com o Ver UV ligado e reabrir. Registrar no PR.
- [ ] **Step 6: Commit** `feat(ui): botoes Paineis, Desfazer Paineis e Ver UV na secao UV e Texturas`
