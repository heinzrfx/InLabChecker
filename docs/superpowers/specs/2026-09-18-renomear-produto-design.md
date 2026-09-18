# Renomeação automática a partir do JSON de produto

**Data:** 18/09/2026 · **Status:** aprovado em conversa, aguardando revisão da spec

## Objetivo

Depois de importar o JSON de nomenclatura na seção **Produto**, o modelador
aplica os nomes oficiais no produto aberto no Max, com um clique:

- **material** de cada parte → `material_id` da parte (ex.: `ART_P_Base`)
- **mapas** (texmaps) dentro desse material → `<material_id>_<canal>`
- **objeto** → `mesh_final` das partes que ele usa (ex.: `05111058`)

Nada no disco é alterado. Tudo é um único passo de undo.

## Pré-requisito já entregue (18/09)

`functions/fn_json.ms` agora faz o parse via .NET (JavaScriptSerializer) e o
leitor MAXScript puro virou fallback. Validado no Max 2024: export da linha
Contract/Health (943 KB, 209 produtos) em ~1,9 s; `nomenclatura_projeto.json`
(6,5 MB) em ~4,4 s; decimais, inteiros grandes, null e acentos corretos.

## Entrada: o JSON

Formato `versao_export: "nomenclatura-3D-v2"` (export por linha da plataforma).
Campos consumidos, por produto em `produtos[]`:

| Campo | Uso |
|---|---|
| `cod_est` | identifica o produto; casado com o nome do .max |
| `nome` | exibição na lista de produtos |
| `partes[].nome_parte` + `qualificador` | rótulo da parte na UI (`Encosto (Externo)`) |
| `partes[].tipo` | só para aviso: tipo vazio ⇒ `material_id` provisório |
| `partes[].material_id` | novo nome do material ligado e prefixo dos mapas |
| `partes[].mesh_final` | novo nome do objeto que usa aquela parte |

Fatos verificados no export real: `material_id` nunca se repete dentro de um
produto; `cod_est` nunca se repete; toda parte tem `mesh_final`; 13 produtos
têm mais de uma mesh (peças animadas soltas, ex.: `Gavetas → ART_C_Gavetas`);
24 partes têm `tipo` vazio (geram `ART_Base`, `ART_Tampo`...).

Fora do escopo: `nomenclatura_projeto.json` (schema `linhas/classes/familias/
skus`, é o arquivo de trabalho do app, não o export). Se importado, a lista de
produtos fica vazia e o log explica que o arquivo esperado é o export.

## Fluxo na UI (seção Produto)

1. **Importar JSON do Produto...** (já existe) — além de guardar a árvore,
   preenche um dropdown **Produto** com `cod_est – nome` de cada item de
   `produtos[]`. Pré-seleciona o produto cujo `cod_est` é igual ao nome do
   .max aberto (`getFilenameFile maxFileName`); se não houver, fica no 1º e o
   log avisa.
2. **Ler materiais da seleção** — coleta os materiais dos objetos
   selecionados, sem repetição. De um Multi/Sub-Object entram os
   submateriais; o multi em si não (não é acabamento de nenhuma parte).
3. **Ligação** — lista com uma linha por parte (`Encosto (Externo)  →
   material`) + dropdown "Material da parte marcada" (primeira opção
   `— nenhum —`). Pré-preenchida: 1º material que já se chama o
   `material_id`; 2º nome do material, sem acento e em minúsculas, contém
   `nome_parte` normalizado (e o `qualificador`, se houver). O modelador
   confere e ajusta.
4. **Aplicar nomes** — valida e aplica (abaixo).
5. **Desfazer nomes** — restaura os nomes guardados na última aplicação.

Controles nativos (listbox + dropdown), não tabela dotNet: o número de
partes varia por produto (1 a ~12), rollouts MAXScript não criam controles
dinamicamente, e controles nativos têm menos risco sem poder testar a UI
fora do Max.

## Aplicar

**Validação (bloqueia, nada é renomeado):**
- o mesmo material ligado a mais de uma parte (um material só pode ter um
  nome); o log lista as partes em conflito.

**Avisos (não bloqueiam):**
- parte sem material ligado → pulada;
- parte com `tipo` vazio → aplica o `material_id` provisório e avisa;
- mapa usado por mais de um material ligado → recebe o nome pelo primeiro e
  avisa;
- objeto selecionado que usa partes de `mesh_final` diferentes → não é
  renomeado;
- objeto selecionado que não usa nenhum material ligado → não é renomeado.

**Renomeação**, dentro de `undo "InLab: Renomear pelo JSON" on ( ... )` e
guardando cada nome antigo em `InLab_UltimaRenomeacao` (o undo nativo pode
não cobrir `.name` de material/texmap alterado por script; o botão
**Desfazer nomes** usa essa lista — mesmo padrão do "Desfazer Otimização"):
1. cada material ligado: `mtl.name = material_id`;
2. cada texmap alcançável a partir desse material (recursivo por
   `getNumSubTexmaps` / `getSubTexmap`, incluindo mapas dentro de mapas, ex.:
   bitmap dentro de CoronaNormal): `map.name = material_id + "_" + canal`,
   onde `canal` = `getSubTexmapSlotName` do slot no material de topo, sem
   espaços e sem acento (ex.: `ART_P_Base_BaseColorMap`). Mapas aninhados
   herdam o canal do slot de topo; se houver mais de um no mesmo canal,
   recebem sufixo `_2`, `_3`...;
3. cada objeto selecionado com exatamente um `mesh_final` entre as partes que
   usa: `obj.name = mesh_final`.

Genérico por design: não assume nomes de propriedade de Corona nem de glTF
Material — só a interface de sub-texmaps que todo material do Max expõe.

Ao final, resumo no log: N materiais, N mapas, N objetos renomeados, N avisos.

## Estrutura de código

- **`functions/fn_renomear_produto.ms`** (novo) — lógica sem UI:
  - `InLab_Produto_Lista dados` → array de produtos do export (ou `#()`)
  - `InLab_Produto_IndicePorCodigo produtos cod` → índice ou 0
  - `InLab_Produto_Rotulo parte` → `"Encosto (Externo)"`
  - `InLab_Produto_MateriaisDaSelecao objs` → materiais únicos (subs do multi)
  - `InLab_Produto_SugerirLigacoes partes mtls` → array paralelo a `partes`
    com o material sugerido ou `undefined`
  - `InLab_Produto_Aplicar produto ligacoes objs` → valida, renomeia, loga;
    devolve `true`/`false`
  - `InLab_Produto_Reverter()` → restaura os nomes da última aplicação
- **`tests/test_renomear_produto.ms`** (novo) — teste automático do módulo.
- **`ui/rollout_main.ms`** — seção Produto ampliada (produto, Ler materiais,
  ligação, Aplicar, Desfazer). Só chama as funções acima.
- **`InLabChecker.ms`** — `fn_renomear_produto.ms` no manifesto, logo após
  `fn_json.ms`.

`core/struct_produto.ms` (parser .NET antigo, fora do manifesto) continua
órfão e intocado.

## Teste

O código só roda no 3ds Max; quem executa é o usuário.

1. **Automático** — `tests/test_renomear_produto.ms`, rodado numa cena vazia:
   monta um produto de teste (qualificadores, tipo vazio, 2 meshes) e uma
   cena com materiais Standard, Normal_Bump e Multi/Sub; confere sugestão,
   conflito (nada renomeado), nomes de materiais/mapas/objetos, objeto que
   mistura meshes, Desfazer, e registra se o `max undo` nativo cobre nomes
   de material. Grava PASS/FAIL em `<temp do Max>\inlab_test_renomear.txt`.
2. **Manual (UI)** — numa **cópia** de `Blocos_3d\05111058.max`: importar o
   export, conferir o produto pré-selecionado, ligar as 4 partes, aplicar,
   conferir nomes no Material Editor, desfazer.

## Fora do escopo

Juntar objetos em uma mesh (attach), renomear arquivos de textura no disco,
botões/apelidos do cliente (`botoes_*`), acessórios (`acessorio_*`),
atualizar a verificação V-20 para usar o JSON.
