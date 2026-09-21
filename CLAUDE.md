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

**Carga por manifesto.** `InLabChecker.ms` define `INLAB_MODULOS`, a lista ordenada de todos os `.ms` carregados: core → famílias → funções → verificações/relatório → UI. A ordem é a ordem de dependência. **Módulo novo só existe se for adicionado ali.** Arquivos fora do manifesto não são carregados (hoje: `functions/fn_clipboard.ms`, `core/struct_produto.ms`, `functions/_placeholder.ms`).

**Tudo é global.** Não há sistema de módulos. Cada arquivo declara `global`s e `fn`s no escopo global, e os módulos se comunicam só por esses globais. Funções públicas levam o prefixo `InLab_`, constantes `INLAB_MAIUSCULO` (ex.: `INLAB_CANAL_UV` em `fn_autouv.ms`). Um global usado antes do arquivo que o define precisa ser pré-declarado com `global Nome` (ver o topo de `InLabChecker.ms` e dos testes).

**Camadas:**
- `core/`: `struct_result.ms` (`VerifResult` e o coletor `InLab_VerifResults`), `struct_familia.ms` (`FamiliaConfig` e `InLab_RegistrarFamilia`), `log.ms` (`InLab_Log msg tipo:#ok|#warn|#err|#info`, que escreve num RichTextBox dotNet colorido, e `InLab_ProgressoIniciar/Parar`, hoje no-op sem a barra de progresso), `utils.ms` (`InLab_EhGeometria`, contagem de polígonos, tamanho de arquivo).
- `familias/`: um arquivo por família de produto. Cada um instancia `FamiliaConfig` com os limites (MB, faixa de polígonos, regra de pivot, etc.) e chama `InLab_RegistrarFamilia`. Os limites são provisórios até validação do Birô.
- `functions/`: ferramentas de preparação chamadas pelos botões (`fn_prooptimizer`, `fn_autouv`, `fn_material_convert`, `fn_export_gltf`, `fn_json` + `fn_renomear_produto`, ...).
- `verifications/`: cada `verif_*.ms` implementa verificações `InLab_Vxx_*` que registram o resultado com `InLab_RegistrarVerif id nome passou msg critico: provisorio:`. `verif_orquestrador.ms` (`InLab_RodarVerificacoes cfg`) roda os grupos em ordem de custo crescente e chama `report/report_generator.ms` (`InLab_GerarRelatorio`). Aprovação = todos os críticos em `#pass`. Falha em limite `provisorio:true` vira `#warning` enquanto `INLAB_LIMITES_PROVISORIOS` for true.
- `ui/rollout_main.ms`: cada seção é um `rollout` independente (Produto, Otimização, Utilidades, Converter Material, ...). Os handlers `on btn... pressed` só leem controles e chamam funções `InLab_*`. A lógica fica em `functions/`, não na UI.

A spec funcional (v1.0/v2.0, com numeração V-xx e seções) é citada nos comentários, mas não está no repo. Specs e planos de features novas ficam em `docs/superpowers/specs/` e `docs/superpowers/plans/`.

## Convenções

- **Cabeçalho de arquivo:** bloco `/* === ... === */` com caminho, o que o arquivo faz e as decisões e correções relevantes, com data. Mantenha esse histórico ao alterar um comportamento.
- **APIs que variam por build** (especialmente `Unwrap_UVW`, exportadores, classes de material): tente as variantes em cadeia de `try/catch` e registre no log **qual rodou**, ou que nenhuma estava disponível (padrão de `InLab_TentarRelax` em `fn_autouv.ms` e da resolução de classe glTF). Nunca engula um erro sem `InLab_Log`.
- **Operações na cena:** ficam dentro de `undo "InLab ..." on ( ... )` e guardam um registro próprio (ex.: `InLab_UltimoAutoUV`, com struct `*Record`) para um botão "Reverter"/"Desfazer" que funcione além do Ctrl+Z.
- **Log por objeto:** `InLab_Log (o.name + ": ...") tipo:#ok|#warn|#err` e uma linha de resumo no final.
- **Unidades e orientação:** cenas em cm. A frente do produto aponta para `−Y` (viewport Front), com pivot na base (Z=0 do mundo, ±1 mm).
- **Pegadinhas do MaxScript** já documentadas no código: `case` inline com `;` não parseia (use multi-linha). `listbox` nativo não suporta cor. Rollouts não criam controles dinamicamente.
- **Pegadinhas do painel Modify e do `Unwrap_UVW`** (achadas no Auto UV, ver cabeçalho de `fn_autouv.ms`):
  - `select o` num membro de grupo **fechado** seleciona o grupo todo, e `modPanel.addModToSelection` instancia um só modificador em todos os membros. Abra os grupos acima do nó (`InLab_AbrirGruposAcima` / `InLab_FecharGrupos`) e use `addModifier o`.
  - Instâncias compartilham o stack: um modificador numa instância aparece em todas. `convertToMesh` numa instância torna todas únicas.
  - `meshop.getMapSupport` dá erro de runtime com canal ≥ `meshop.getNumMaps`, em vez de devolver `false`. Numa malha nova, chame `meshop.setNumMaps` antes de ativar o canal 3.
  - `relax` do Unwrap sobre um flatten piora o UV: com as bordas soltas encolhe as ilhas até virarem linhas, com as bordas travadas dobra faces. O `Unfold3DPack` ignora `unfoldRoomSpace`, e os valores `unfold*` de um Unwrap novo são só os padrões de fábrica.
- **Desempenho:** laço em MaxScript sobre faces ou vértices não escala para malhas de centenas de milhares de faces: `InLab_MedirUV` leva ~3 min em 300 mil faces. Em código de produção, prefira operações nativas (`selectOverlappedFaces`, contagens de `meshop`) e limite o que é medido pelo tamanho da malha (`INLAB_UV_MEDIR_MAX_FACES`).
- **MCP do 3ds Max:** roda em `safe_mode`, que bloqueia `createFile`/`copyFile` no código enviado. Use `openFile ... mode:"wt"` e copie arquivos pelo shell. Uma chamada que passa de 120 s vai para segundo plano e, enquanto isso, a thread principal do Max fica ocupada.
- **Testes** seguem `tests/test_renomear_produto.ms`: pré-declarar os globais, fazer `fileIn` só dos módulos necessários, substituir `InLab_Log` por um logger que escreve no arquivo de saída, criar a cena de teste, `checar "descrição" condição` e apagar o que foi criado no final.
- **Git:** commits em português, sem acento no assunto, no formato `feat(escopo): ...` / `fix(escopo): ...`. Branch por feature (`feat/...`) a partir de `main`.
