# Export v2 de produtos: respostas da Bianca e o que mudou no plugin

Data: 2026-10-02. Fontes (fora do repo, em `G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\`):
- `Resposta_Rafa_teste_plugin_v2.md`: respostas da Bianca às perguntas do teste do plugin.
- `produtos teste plugin rafa v2.json`: export `nomenclatura-3D-v2` com 66 produtos, exportado em 2026-10-02.

## Regras confirmadas pela Bianca

| Assunto | Regra |
|---|---|
| Nome do `.max` | É o `cod_est`. A pré-seleção do produto pelo nome do arquivo basta; não precisa de busca aproximada. |
| Nome de mesh | Mesh principal = `cod_est` (produto inteiro atachado). Parte solta animada = `codEst_nomedaparte`. `ART`/`P`/etc. é material, não mesh. |
| `so3d: true` | Subparte só de 3D (Porta_1, Tampa_1, Puxador_1). Vem com `subparte_de` e `tipo: ""` de propósito. O material sem letra de tipo (`ART_Porta_1`) é proposital. Não é falta de classificação. |
| `\|` no `mesh_final` | A parte está em mais de um grupo de mesh. Divide no `\|`; não é um nome só. |
| Material da porta | A configurável é a parte-mãe (`ART_P_Porta`). A subparte (`ART_Porta_1`) é só geometria de animação; o cliente não vê. |
| `bloco_3d` | `papel: copia` + `duplicar_renomear: true` = duplica o GLB do `base_codest` e renomeia. Todo `master` aponta para o próprio código. |
| `glb_multiplos` | 1 `.max` exporta N GLBs, renomeando a mesh em cada export, nome `codEst_acabId`. As variantes vêm em `glb_multiplos.variantes`; `meshes[]` traz só o `cod_est` base. Vale para variação de tecido com a mesma geometria. Puff que muda de forma por "Posição" é produto próprio, não `glb_multiplos`. |
| `ok_3d: false` | O plugin avisa e pula. Não trava e não ignora em silêncio. |
| `ok_fd` | Não é critério nesta leva (é teste de plugin). |
| Família por "giratória" | Em mesa gira o prato, não o assento. A regra tem que ser por classe. |

## Conferência do JSON v2

Bate com o que a Bianca afirmou:
- 0 `cod_est` duplicado em 66 produtos.
- 0 `mesh_final` apontando para mesh fora de `meshes[]` (dividindo no `|`).
- Todo `master` com `base_codest` igual ao próprio código; 9 cópias, todas com `duplicar_renomear: true` e base presente no arquivo.
- 12 partes `so3d`, todas com `tipo: ""`; nenhuma parte sem tipo fora delas.
- 1 parte com `|`: Prato da Mesa Berriz (`00124600|00124600_Prato_Giratoria`).
- 2 produtos com `glb_multiplos`: 07132220 e 07132222, 4 variantes cada.

Pontos para devolver à Bianca:
1. **07119245 (Cadeira Luang Living):** as 6 partes estão com `mesh_final` vazio e `meshes[0].partes` vazio. Nenhuma tem subparte, então não é o caso da parte-mãe. O plugin não tem nome de objeto para sugerir neste produto.
2. **`ok_3d: false` em 5 produtos:** 00111091, 00122093, 09125006, 09125010, 07131A31. O 09125010 é base da cópia 09125015.
3. **Vanity Desk (00261002):** nomes de mesh com espaço (`00261002_Tampa_1 _Puxador_1`, `00261002_Tampa_2 _ Puxador_2`). Ela classificou como cosmético, mas o plugin dá exatamente esse nome ao objeto.
4. **`acab_id: "L14_L33"`** no 07132220: ela já ia conferir.

## O que mudou no plugin (branch `feat/produto-json-v2`)

`functions/fn_renomear_produto.ms` e a seção Produto de `ui/rollout_main.ms`:

- **`so3d`:** o aviso "sem tipo no JSON … Classificar a parte na plataforma" não sai mais para subparte `so3d`. O material ligado a ela continua sendo renomeado para o `material_id` do JSON.
- **`|`:** `InLab_Produto_MeshesDaParte` divide o `mesh_final`. `InLab_Produto_MeshesDoProduto` e `InLab_Produto_SugerirMeshes` usam os nomes separados. Antes `"A|B"` entrava no dropdown como um nome só.
- **Parte-mãe sem mesh:** parte que é mãe de subparte `so3d` e vem sem `mesh_final` sai como `#info` ("a geometria está nas subpartes"), não `#warn`.
- **`ok_3d: false`:** `InLab_Produto_Liberado3D`. A seção Produto avisa ao escolher o produto; "Renomear materiais" e "Renomear objetos" avisam e não renomeiam nada. Export sem o campo conta como liberado.
- **Família:** animado com "giratória" no nome e classe de mesa (ou "coluna de jantar") sugere Rotação, não Giro de Assento.

Testes: seção 11 de `tests/test_renomear_produto.ms` (inclui a leitura do export v2 real, quando o arquivo existe) e um caso novo em `tests/test_familia_ativa.ms`.

## Em aberto

- **Tabela classe → família** (Bianca vai mandar). Escrivaninha, Mesa de Jogo e Vanity Desk seguem sem sugestão quando estáticas. No v2: 1 escrivaninha e 1 mesa de jogo estáticas.
- **`glb_multiplos`:** exportar N GLBs de um `.max`, renomeando a mesh para `codEst_acabId` a cada export. Não existe no plugin. Precisa de desenho (o que troca entre as variantes além do nome; onde entra na seção Exportar).
- **`bloco_3d` cópia:** duplicar o GLB do `base_codest` com o nome da cópia. Não existe no plugin. Precisa de desenho (a mesh dentro do GLB muda de nome? de onde vem o GLB base?).
- **Material da subparte `so3d`:** a resposta A diz que a configurável é a mãe (`ART_P_Porta`) e que a subparte é só geometria. Falta confirmar qual material o objeto `codEst_Porta_1` carrega no GLB: `ART_P_Porta` ou `ART_Porta_1`. Hoje o plugin lista a subparte como parte ligável e, sem material ligado, avisa "sem material ligado".
- **V-20 (issue #36):** a convenção de nomes acima permite tirar os nomes válidos de `meshes[]` e `material_id` do produto importado, em vez de lista fixa por família. Os limites por parte (V-04) e a validação do Birô não foram respondidos nesta leva.
