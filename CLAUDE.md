# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é

InLabChecker é um plugin **MaxScript** para 3ds Max (alvo: 2024, também 2027) usado pela InLab/Artefacto para preparar e verificar modelos 3D de móveis antes da entrega: otimização, Auto UV, conversão de material, export glTF, renomeação pelo JSON de produto e um motor de verificações (V-01 a V-40) que gera relatório de aprovação por família de produto.

Todo o código, comentários, log e UI são em **português**.

## Rodar, recarregar e testar

Não há build, linter nem test runner fora do Max. Tudo roda dentro do 3ds Max, de preferência pelo **MCP do 3ds Max** (`execute_maxscript` etc.).

- **Abrir o plugin:** `fileIn @"<repo>\InLabChecker.ms"` (ou Scripting > Run Script). Precisa ser executado como arquivo: o entry point usa `getSourceFileName()` para achar `INLAB_ROOT`.
- **Recarregar depois de editar:** `InLab_RecarregarPlugin()`. Refaz o `fileIn` de todos os módulos na ordem do manifesto e reabre a UI, sem reiniciar o Max.
- **Rodar um teste:** `fileIn @"<repo>\tests\test_<nome>.ms"` numa cena vazia (`resetMaxFile #noPrompt`). O resultado sai em `(getDir #temp) + "\inlab_test_<nome>.txt"`, uma linha `PASS`/`FAIL` por item. Leia esse arquivo para conferir.
- Não dê uma mudança como validada sem ter rodado no Max. Se o MCP não estiver conectado, avise.

## Arquitetura

**Carga por manifesto.** `InLabChecker.ms` define `INLAB_MODULOS`, a lista ordenada de todos os `.ms` carregados: core → famílias → funções → verificações/relatório → UI. A ordem é a ordem de dependência. **Módulo novo só existe se for adicionado ali.** Arquivos fora do manifesto não são carregados (hoje: `functions/fn_prooptimizer.ms`, substituído pelo passo 2 da Otimização e mantido só até uma limpeza depois do merge).

**Tudo é global.** Não há sistema de módulos. Cada arquivo declara `global`s e `fn`s no escopo global, e os módulos se comunicam só por esses globais. Funções públicas levam o prefixo `InLab_`, constantes `INLAB_MAIUSCULO` (ex.: `INLAB_CANAL_UV` em `fn_autouv.ms`). Um global usado antes do arquivo que o define precisa ser pré-declarado com `global Nome` (ver o topo de `InLabChecker.ms` e dos testes).

**Camadas:**
- `core/`: `struct_result.ms` (`VerifResult` e o coletor `InLab_VerifResults`), `struct_familia.ms` (`FamiliaConfig` e `InLab_RegistrarFamilia`), `log.ms` (`InLab_Log msg tipo:#ok|#warn|#err|#info`, que escreve num RichTextBox dotNet colorido, e `InLab_ProgressoIniciar/Parar`, hoje no-op sem a barra de progresso), `utils.ms` (`InLab_EhGeometria`, contagem de polígonos, tamanho de arquivo).
- `familias/`: um arquivo por família de produto. Cada um instancia `FamiliaConfig` com os limites (MB, faixa de polígonos, regra de pivot, etc.) e chama `InLab_RegistrarFamilia`. Os limites são provisórios até validação do Birô.
- `functions/`: ferramentas de preparação chamadas pelos botões (`fn_otim_nucleo` + `fn_otim_origem`/`fn_otim_fino`/`fn_otim_escondidas`, os 3 passos da Otimização; `fn_autouv`, `fn_material_convert`, `fn_export_gltf`, `fn_json` + `fn_renomear_produto`, ...).
- `verifications/`: cada `verif_*.ms` implementa verificações `InLab_Vxx_*` que registram o resultado com `InLab_RegistrarVerif id nome passou msg critico: provisorio:`. `verif_orquestrador.ms` (`InLab_RodarVerificacoes cfg`) roda os grupos em ordem de custo crescente e chama `report/report_generator.ms` (`InLab_GerarRelatorio`). Aprovação = todos os críticos em `#pass`. Falha em limite `provisorio:true` vira `#warning` enquanto `INLAB_LIMITES_PROVISORIOS` for true.
- `ui/rollout_main.ms`: cada seção é um `rollout` independente (Produto, Otimização, Utilidades, Converter Material, ...). Os handlers `on btn... pressed` só leem controles e chamam funções `InLab_*`. A lógica fica em `functions/`, não na UI. `ui/kit.ms` é a fonte das cores/fontes/widgets compartilhados (`InLab_Kit_Cor`, `InLab_Kit_Fonte`, `InLab_Kit_BotaoIcone`, `InLab_Kit_Pastilha`) — seção nova lê cor de lá, nunca literal. `ui/header.ms` monta a faixa de marca do topo (`InLab_Header_Montar`) dentro de um `System.Windows.Forms.Panel` (`pnlHeader`) que mora em `InLabChecker_Rollout`: **filho de `Panel` dotNet pode ser criado em tempo de execução** — a pegadinha "rollout não cria controle dinamicamente" (linha abaixo) vale só para controle DE ROLLOUT. `ui/img/` guarda a arte (PNGs); o header monta normalmente sem ela se faltar (loga `#warn`).

A spec funcional (v1.0/v2.0, com numeração V-xx e seções) é citada nos comentários, mas não está no repo. Specs e planos de features novas ficam em `docs/superpowers/specs/` e `docs/superpowers/plans/`.

## Convenções

- **Cabeçalho de arquivo:** bloco `/* === ... === */` com caminho, o que o arquivo faz e as decisões e correções relevantes, com data. Mantenha esse histórico ao alterar um comportamento.
- **APIs que variam por build** (especialmente `Unwrap_UVW`, exportadores, classes de material): tente as variantes em cadeia de `try/catch` e registre no log **qual rodou**, ou que nenhuma estava disponível (padrão de `InLab_TentarRelax` em `fn_autouv.ms` e da resolução de classe glTF). Nunca engula um erro sem `InLab_Log`.
- **Operações na cena:** ficam dentro de `undo "InLab ..." on ( ... )` e guardam um registro próprio (ex.: `InLab_UltimoAutoUV`, com struct `*Record`) para um botão "Reverter"/"Desfazer" que funcione além do Ctrl+Z.
- **Log por objeto:** `InLab_Log (o.name + ": ...") tipo:#ok|#warn|#err` e uma linha de resumo no final.
- **Unidades e orientação:** cenas em cm. A frente do produto aponta para `−Y` (viewport Front), com pivot na base (Z=0 do mundo, ±1 mm).
- **Pegadinhas do MaxScript** já documentadas no código: `case` inline com `;` não parseia (use multi-linha). Chamar método depois de `()` não parseia (`x.A().B "s"` dá syntax error): parentize, `(x.A()).B "s"`. Numa sub-seção (`AddSubRollout`), `.open` é "desenrolada" (lê e escreve) e `.isDisplayed` é "está no painel"; `.rolledUp` só existe como parâmetro do `AddSubRollout`, não como propriedade (ver `ui/rollout_update.ms`). `listbox` nativo não suporta cor. Rollouts não criam controles dinamicamente (controle DE ROLLOUT — filho de um `Panel` dotNet dentro do rollout pode, ver `ui/header.ms`). `Image.FromFile`/`Bitmap(String)` travam o arquivo em disco enquanto a imagem viver; a saída é copiar para um `Bitmap` novo (`dotNetObject "System.Drawing.Bitmap" <bitmapOriginal>`) e descartar o original (`.Dispose()`) na hora.
- **Pegadinhas do painel Modify e do `Unwrap_UVW`** (achadas no Auto UV, ver cabeçalho de `fn_autouv.ms`):
  - `select o` num membro de grupo **fechado** seleciona o grupo todo, e `modPanel.addModToSelection` instancia um só modificador em todos os membros. Abra os grupos acima do nó (`InLab_AbrirGruposAcima` / `InLab_FecharGrupos`) e use `addModifier o`.
  - Instâncias compartilham o stack: um modificador numa instância aparece em todas. `convertToMesh` numa instância torna todas únicas.
  - `meshop.getMapSupport` dá erro de runtime com canal ≥ `meshop.getNumMaps`, em vez de devolver `false`. Numa malha nova, chame `meshop.setNumMaps` antes de ativar o canal 3.
  - `relax` do Unwrap sobre um flatten piora o UV: com as bordas soltas encolhe as ilhas até virarem linhas, com as bordas travadas dobra faces. O `Unfold3DPack` ignora `unfoldRoomSpace`, e os valores `unfold*` de um Unwrap novo são só os padrões de fábrica.
  - `Unfold3DSolve` renumera os vértices UV das faces (é uma permutação). Posição guardada por índice de vértice antes do solve não serve depois. Guarde por canto de face (`getVertexIndexFromFace f k`). Com grupo fechado e vários nós selecionados, o solve dá `EXCEPTION_ACCESS_VIOLATION`.
- **Pegadinhas de Corona e UVW Map por script** (achadas no Real World Fix, ver cabeçalho de `fn_realworldfix.ms`):
  - `CoronaTriplanar name:"..."` no construtor dá `EXCEPTION_ACCESS_VIOLATION`. Crie com `CoronaTriplanar()` e defina as propriedades depois.
  - O `.gizmo` de um `Uvwmap` recém-adicionado só existe depois que o nó é avaliado (`classof o`). O mesmo vale para o ajuste automático do tamanho: o UV lido antes da 1ª avaliação é de antes do ajuste.
  - `Box` criado por script não tem UV no canal 1. Use `mapcoords:true`.
- **Pegadinhas de `dotNetControl` em rollout e de sondagem pelo MCP** (achadas na sondagem do header, ver `docs/superpowers/specs/2026-09-22-header-sondagem.md`):
  - O `.Parent` de um `dotNetControl` declarado direto no rollout é `undefined` — e `.FindForm()` também. O MaxScript hospeda esse controle por `SetParent` nativo (Win32), não por `Controls.Add` do WinForms, então a propriedade gerenciada nunca reflete o parentesco. Para a hierarquia real de janelas (medir margem, posição, achar o host) use a API nativa do struct `windows`: `windows.getParentHWND`, `windows.getHWNDData`, `windows.getWindowPos`, `windows.postMessage`. O HWND de partida é `ctrl.Handle as integer`.
  - Global de rollout criado dentro de uma chamada do MCP **não sobrevive de forma confiável** para a chamada seguinte, mesmo declarado `global` (é do bridge, não do MaxScript — via `fileIn` dentro do Max os globais de rollout persistem normalmente). Sondagem que precise ler estado depois de `createDialog` tem que criar, ler e devolver tudo na MESMA chamada, e fechar diálogo órfão enumerando o desktop (`windows.getChildrenHWND (windows.getDesktopHWND())`, filtrar pela classe `"MAXScriptDialog"`) em vez de confiar em `destroyDialog <variável>`.
  - `format` dentro de `on <rollout> open do` não aparece no resultado de `execute_maxscript` — só volta o valor da última expressão do script. Para ler algo calculado dentro de um handler, grave numa global e devolva essa global como string no fim do MESMO script.
- **Spline renderizável** (Line com `render_displayRenderMesh`/`render_renderable`, sem modificador) é `Shape`, não `GeometryClass`: `InLab_EhGeometria`, `InLab_Otim_Triangulos` (medidor, V-03/V-04) não a contam, e `GetTriMeshFaceCount` nela devolve 0 até o nó ser avaliado (`classof o`); `snapshotAsMesh` dá a malha de render. Enquanto o medidor não contar, a Otimização deixa essas splines fora (ver `fn_otim_origem.ms`). Para medir custo mudando uma propriedade por script, use `with undo off` e volte o valor original mesmo com exceção.
- **Desempenho:** laço em MaxScript sobre faces ou vértices não escala para malhas de centenas de milhares de faces: `InLab_MedirUV` leva ~3 min em 300 mil faces. Em código de produção, prefira operações nativas (`selectOverlappedFaces`, contagens de `meshop`) e limite o que é medido pelo tamanho da malha (`INLAB_UV_MEDIR_MAX_FACES`).
- **MCP do 3ds Max:** roda em `safe_mode`, que bloqueia `createFile`/`copyFile` no código enviado. Use `openFile ... mode:"wt"` e copie arquivos pelo shell. Uma chamada que passa de 120 s vai para segundo plano e, enquanto isso, a thread principal do Max fica ocupada.
- **Testes** seguem `tests/test_renomear_produto.ms`: pré-declarar os globais, fazer `fileIn` só dos módulos necessários, substituir `InLab_Log` por um logger que escreve no arquivo de saída, criar a cena de teste, `checar "descrição" condição` e apagar o que foi criado no final.
- **Git:** commits em português, sem acento no assunto, no formato `feat(escopo): ...` / `fix(escopo): ...`. Branch por feature (`feat/...`) a partir de `main`.
