# AutoUV de artista: Fase 0, APIs do Unwrap_UVW

Build: 3ds Max `#(26000, 64, 0, 26, 2, 14, 20518, 2024, ".2.14 Security Fix")` (3ds Max 2024.2.14). Data: 2026-09-18.

Instância 2027 não estava conectada no MCP (`list_max_instances` só listou `pid-33544`, `max_version: 2024`). Todas as colunas "2027" abaixo estão marcadas "não verificado".

**Nota sobre o MCP:** `safe_mode = true` em `%LOCALAPPDATA%\3dsmax-mcp\mcp_config.ini` bloqueia `createFile`. Todos os scripts abaixo foram adaptados para usar `openFile <caminho> mode:"wt"` no lugar de `createFile ... encoding:#utf8` — o resto do script do brief roda sem alteração. Isso é relevante para as Fases 1-4: qualquer dump/log em arquivo feito via MCP deve usar `openFile`, não `createFile`.

## Comportamento

| Pergunta | 2024 | 2027 |
|---|---|---|
| `node.baseObject = copia` restaura a base | Sim. `classOf b.baseObject == Editable_Poly` após reatribuir a cópia salva antes do `convertToMesh` deu `true`. | não verificado |
| `setMapChannel 3` sem diálogo modal | Sim, nenhum diálogo abriu; a chamada retornou normalmente. | não verificado |
| `getMapChannel()` devolve 3 | Sim, `uvw.getMapChannel()` retornou `3` logo após `uvw.setMapChannel 3`. | não verificado |
| Propriedade de canal do `UVW_Mapping_Clear` | `.mapID` (integer). `showProperties` só lista essa propriedade; `isProperty clr #mapID` deu `true`, `#mapChannel` e `#channel` deram `false`. | não verificado |
| `unfoldMethod = 46000` é | **Unfold3D** (o solver padrão do build atual). Ver evidência abaixo — não é um "chute": é o valor que um `Unwrap_UVW` recém-criado, sem nenhuma configuração manual, já traz por padrão neste build 2024.2.14. | não verificado |

### Evidência para `unfoldMethod = 46000`

Não foi possível reproduzir literalmente o passo do brief de "trocar o dropdown do solver na UI e reler a propriedade", porque isso exige clicar num combo box dentro do editor Edit UVWs — fora do alcance seguro do MCP (risco de diálogo/modo interativo travando a chamada). Em vez disso, usei duas evidências independentes que se confirmam:

1. **Valor da própria cena do ArchToolz:** `02.max`, objeto `Box013` (há dois nós chamados "Box013" na cena — o certo é o `Editable_mesh`, handle 22, com o modificador "Unwrap UVW"; o outro "Box013" é um `Editable_Poly` sem esse modificador). `u.unfoldMethod = 46000`.
2. **Valor padrão de fábrica neste build:** criei um `Unwrap_UVW` novo, do zero, numa cena vazia, sem tocar em nenhuma UI — `uvw.unfoldMethod` já vem `46000`. Ou seja, 46000 é o solver padrão do 3ds Max 2024.2.14 pronto de fábrica.
3. **Contraprova documentada:** a comunidade (thread "[SOLVED] 3dsmax 2024 force peel to use LSCM instead of unfold", polycount.com/discussion/234874) documenta um script de startup que força o modificador a usar LSCM (o solver legado, anterior ao Unfold3D) via `m.unfoldMethod = 45272`. Testei isso no mesmo modificador: `uvw.unfoldMethod = 45272` foi aceito e `getProperty` devolveu `45272` de volta (roundtrip válido), depois voltei para `46000` e também fez roundtrip. Os dois valores são membros válidos e distintos do mesmo enum.
4. Documentação oficial da Autodesk confirma que, a partir do 3ds Max 2022.2, o Peel/Pack/Relax do Unwrap UVW passou a usar o solver **Unfold3D** por padrão, com opção de reverter para o solver **LSCM** legado via dropdown no rollout Peel (Knowledge Network, "Improved UV Editing", What's New 2022.2; help.autodesk.com/.../GUID-853825B7...).

Juntando os quatro pontos: `46000` = **Unfold3D** (padrão de fábrica), `45272` = **LSCM** (legado, alternativa documentada). Não obtive uma tabela oficial da Autodesk com todos os valores do enum (não achei o `iunwrap.h` com essa definição publicamente, nem consegui abrir o dropdown da UI via MCP para testar mais valores) — então não sei se existem outros valores possíveis (ex.: "Diamond" ou métodos mais antigos do Unwrap clássico) nem seus números. Recomendo que qualquer código de produção trate `unfoldMethod` como opaco: leia e restaure o valor original, e só grave `46000` (Unfold3D) explicitamente quando quiser forçar esse solver, sem tentar enumerar todas as opções.

## APIs

Todas as assinaturas abaixo vêm do `showInterfaces` do `Unwrap_UVW` no build 2024.2.14 (arquivo `inlab_unwrap_api_26000.txt`, ver Passo 1 no relatório). Nenhuma foi testada em 2027 (instância indisponível).

| Necessidade | Método/propriedade | Assinatura (do showInterfaces) | 2024 | 2027 |
|---|---|---|---|---|
| Seams por ângulo | não existe um "criar seam por ângulo" direto; o mais próximo é o autoseam do Unfold3D, sem parâmetro de ângulo exposto | `<void>Unfold3DAutoseams()` (interface unwrap8) | Existe (não testado em cena real) | não verificado |
| Seams por aresta selecionada (edge loops) | `peltEdgeSelToSeam` (converte seleção de aresta de geometria em seam do Peel) / `peltSeamToEdgeSel` (inverso) | `<void>peltEdgeSelToSeam <boolean>replace` / `<void>peltSeamToEdgeSel <boolean>replace` (interface unwrap5) | Existe | não verificado |
| Selecionar arestas por ângulo / loop | `geomEdgeLoopSelection`, `geomEdgeRingSelection`, `uvLoop`, `uvRing`, `expandGeomEdgeSelection`/`contractGeomEdgeSelection` | `<void>geomEdgeLoopSelection()` / `<void>geomEdgeRingSelection()` (unwrap5); `<void>uvLoop <integer>mode` / `<void>uvRing <integer>mode` (unwrap6) | Existe | não verificado |
| Unfold conforme (Unfold3D / LSCM / peel) | `unfoldMap`, `Unfold3DSolve`, `LSCMSolve`, `LSCMReset`, `LSCMInteractive` | `<void>unfoldMap <integer>unfoldMethod <boolean>normalized` (unwrap2); `<void>Unfold3DSolve()` / `<void>Unfold3DOptimize()` (unwrap8); `<void>LSCMSolve()` / `<void>LSCMReset()` / `<void>LSCMInteractive <boolean>useExistingMapping` (unwrap6) | Existe | não verificado |
| Relax | `relax`, `fitRelax`, `relax2`, `RelaxOneClick`, `relaxThreaded`, `relaxBySpring`, `relaxByFaceAngle`, `relaxByEdgeAngle` | `<void>relax <integer>iterations <float>strength <boolean>lockEdges <boolean>matchArea` (unwrap2); `<void>fitRelax <integer>iterations <float>strength` (unwrap2); `<void>relax2()` (unwrap3); `<void>RelaxOneClick()` / `<void>relaxThreaded <enum>threadOp` `{#start\|#restart\|#stop}` (unwrap6); `<void>relaxBySpring <integer>frames <float>stretch <boolean>useOnlyVEdges` / `<void>relaxByFaceAngle <integer>iterations <float>stretch <float>strength <boolean>lockBoundaries` / `<void>relaxByEdgeAngle <integer>iterations <float>stretch <float>strength <boolean>lockBoundaries` (unwrap5) | Existe | não verificado |
| Straighten de ilha | `Straighten` | `<void>Straighten()` (unwrap6) | Existe | não verificado |
| Rescale (densidade uniforme) | `RescaleCluster`, `GetPackRescaleCluster`/`SetPackRescaleCluster`, `GroupGetTexelDensity`/`GroupSetTexelDensity` | `<void>RescaleCluster <bitArray>facesel <node>node` / `<boolean>GetPackRescaleCluster()` / `<void>SetPackRescaleCluster <boolean>rescale` (unwrap6); `<float>GroupGetTexelDensity()` / `<float>GroupSetTexelDensity <float>value` (unwrap6) | Existe | não verificado |
| Rotação de ilha (0°/90°, alinhar ao eixo) | `RotateSelectedCenter`, `RotateSelected`, `alignByPivotHorizontal`/`alignByPivotVertical`, `align` | `<void>RotateSelectedCenter <float>angle` / `<void>RotateSelected <float>angle <point3>axis` (unwrap2); `<void>alignByPivotHorizontal()` / `<void>alignByPivotVertical()` (unwrap6); `<void>align <boolean>horizontal` (unwrap, interface base) | Existe | não verificado |
| Pack com padding, sem rescale, sem rotação livre | `pack` (parâmetros diretos de rescale/rotate/padding), alternativa `Unfold3DPack` | `<void>pack <integer>method <float>spacing <boolean>normalize <boolean>rotate <boolean>fillholes` (unwrap2) — usar `rotate:false` e `normalize:false` (rescale) para atender "sem rescale, sem rotação livre"; `packDialog()`/`packNoParams()` (unwrap2); alternativa mais nova sem parâmetros expostos: `<void>Unfold3DPack()` (unwrap8) | Existe | não verificado |
| Seleção de faces sobrepostas | `selectOverlappedFaces` | `<void>selectOverlappedFaces()` (unwrap5) | Existe | não verificado |
| Leitura de distorção/texel density | `getArea`/`getAreaByNode` (área UVW vs. área geométrica, dá pra derivar densidade/distorção), `GroupGetTexelDensity`, `getShowEdgeDistortion`/`getEdgeDistortionScale` (só exibição, não leitura numérica por face) | `<void>getArea <bitArray>faceSelection <&float>x <&float>y <&float>width <&float>height <&float>areaUVW <&float>areaGeom` (unwrap4); `<void>getAreaByNode <bitArray>faceSelection <&float>areaUVW <&float>areaGeom <node>node` (unwrap6); `<float>GroupGetTexelDensity()` (unwrap6) | Existe | não verificado |

## Outras APIs úteis para as Fases 3-4 (além da tabela acima)

Notadas durante a leitura do dump completo (`inlab_unwrap_api_26000.txt`), com assinatura completa:

- `<void>FlattenBySmoothingGroup <boolean>rescale <boolean>rotate <float>padding` (unwrap6) — flatten automático por smoothing group, já com flags de rescale/rotate/padding: pode servir de base alternativa ao fluxo manual de seam+unfold+pack.
- `<void>FlattenByMaterialID <boolean>rescale <boolean>rotate <float>padding` (unwrap6) — igual ao acima, mas por Material ID.
- `<void>flattenMapByMatID <float>angleThreshold <float>spacing <boolean>normalize <integer>layOutType <boolean>rotateClusters <boolean>fillHoles` (unwrap4) — flatten com limiar de ângulo explícito (`angleThreshold`), a API mais próxima de "seam por ângulo" encontrada, embora seja um flatten completo (cria clusters e os separa), não uma função isolada "marcar seam onde ângulo > X".
- `<void>flattenMap <float>angleThreshold <point3 array>normalList <float>spacing <boolean>normalize <integer>layOutType <boolean>rotateClusters <boolean>fillHoles` (unwrap2) — mesma ideia, versão genérica por normais.
- `<void>WeldSelectedShared()` / `<void>WeldAllShared()` (unwrap6) — weld de vértices UV coincidentes, útil depois de qualquer unfold para evitar ilhas fragmentadas.
- `<void>expandSelection()` / `<void>contractSelection()` (interface base `unwrap`) — expande/contrai seleção de vértice/face UV (equivalente de "grow/shrink" em espaço UV).
- `<void>expandGeomFaceSelection()` / `<void>contractGeomFaceSelection()` (unwrap2) e `<void>expandGeomVertexSelection()` / `<void>contractGeomVertexSelection()` / `<void>expandGeomEdgeSelection()` / `<void>contractGeomEdgeSelection()` (unwrap5) — mesma ideia em espaço de geometria (não UV).
- `<void>selectFacesByNormal <point3>normal <float>threshold <boolean>update` (unwrap2) — seleciona faces por normal + limiar, pode ajudar a montar "seams por ângulo" manualmente (selecionar por normal, depois `peltEdgeSelToSeam`/`breakSelected`).
- `<void>selectClusterByNormal <float>threshold <integer>faceIndexSeed <boolean>relative <boolean>update` (unwrap2) — cresce seleção de um cluster plano a partir de uma face-semente e limiar de normal.
- `<void>breakSelected()` (interface base `unwrap`) — quebra (break) a seleção UV atual, criando descontinuidade — é a função clássica de "criar seam" a partir de aresta/vértice selecionado no editor UV.
- `<boolean>getRotationsRespectAspect()` / `<void>setRotationsRespectAspect <boolean>respect` (unwrap4) — controla se rotações de ilha respeitam a proporção (relevante para "rotação 0°/90°" sem distorcer).
- `<void>ScaleSelectedCenter <float>scale <integer>dir` / `<void>ScaleSelected <float>scale <integer>dir <point3>axis` / `<void>ScaleSelectedXY <float>scaleX <float>scaleY <point3>axis` (unwrap2/unwrap5) — rescale manual de ilha/seleção, complementar ao `RescaleCluster` do pack.
- `<void>fitSelectedElement()` (unwrap5) — encaixa (fit) o elemento selecionado no espaço 0-1, útil antes de comparar texel density entre ilhas.
- `<void>CleanDegenerateFaces()` (unwrap8) — limpa faces degeneradas antes de rodar Unfold3D; relevante para robustez do pipeline de Auto UV.
- `<boolean>getFilterSelected()` / `<void>setFilterSelected <boolean>filter` (unwrap2) — filtra a exibição por seleção geométrica, útil para depurar visualmente um lote de ilhas no editor.
- `.unfoldMethod`, `.unfoldIterations`, `.unfoldMapSize`, `.unfoldRoomSpace`, `.unfoldAutoPack`, `.unfoldFlipTriangle`, `.unfoldBorderIntersection` (propriedades do `showProperties`, sem interface nomeada) — todo o bloco de parâmetros do Unfold clássico/Unfold3D que fica salvo por modificador; a Fase 3 provavelmente vai querer ler/gravar esse bloco inteiro ao aplicar um preset de Auto UV.

## Scripts e arquivos gerados

Todos os arquivos abaixo foram gerados em `(getDir #temp)` deste build, que resolveu para `C:\Users\zn1eh\AppData\Local\Autodesk\3dsMax\2024 - 64bit\ENU\temp\`:

- `inlab_unwrap_api_26000.txt` — dump completo do Passo 1 (`showInterfaces`/`showProperties` de `Unwrap_UVW` e `UVW_Mapping_Clear`).
- `inlab_unwrap_perguntas.txt` — respostas (a)-(d) do Passo 2.
- `inlab_unfold_02.txt` / `inlab_unfold_02b.txt` — tentativas de leitura do `unfoldMethod` em `02.max` (a primeira falhou por causa do nó duplicado "Box013"; a segunda, filtrando por modificador, teve sucesso).
- `inlab_scan_02.txt` — varredura de todos os objetos/modificadores de `02.max`, usada para descobrir a duplicidade de nomes.
- `inlab_unfold_default.txt` — evidência do valor padrão de fábrica do `unfoldMethod` (Passo 3).
- Cópias de trabalho: `C:\Users\zn1eh\AppData\Local\Autodesk\3dsMax\2024 - 64bit\ENU\temp\inlab_autouv\01.max` e `\02.max` (copiadas de `G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\archtoolztest\`, originais não tocados).

## Achado colateral relevante para as próximas fases

O MCP roda com `safe_mode = true`, que bloqueia `createFile` (erro `SAFE_MODE`). `openFile <caminho> mode:"wt"` funciona normalmente e produz o mesmo resultado. As Fases 1-5, e os testes em `tests/test_*.ms` quando rodados via MCP (ao invés de rodados dentro do próprio Max via `fileIn`), devem preferir `openFile` a `createFile` para não travar em ambientes com safe mode ativo. Dentro do próprio `fileIn` do Max isso não é um problema (os testes do repo já usam esse padrão rodando de dentro do Max, não via `execute_maxscript`).

Além disso, `02.max` tem nós de geometria duplicados por nome (ex.: dois objetos chamados "Box013", um `Editable_Poly` sem UVs e outro `Editable_mesh` com `Unwrap_UVW`). `getNodeByName` devolve só o primeiro que encontra pela ordem interna da cena, não necessariamente o que se quer. Qualquer código de produção que precise achar um nó específico por nome nesses arquivos de teste do ArchToolz deve iterar `objects where o.name == "..."` e filtrar pelo modificador esperado, não confiar em `getNodeByName`.
