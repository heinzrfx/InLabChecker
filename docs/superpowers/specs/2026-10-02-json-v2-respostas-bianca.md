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

---

# Respostas v3 (mesmo dia): escopo do v1 e fechamento das perguntas

Fonte: `Resposta_Rafa_teste_plugin_v3_1.md` (mesma pasta). O JSON `produtos_teste_plugin_rafa_v3.json` citado nela **não estava na pasta** em 02/10/2026; a conferência acima continua sendo a do v2.

O que está abaixo **substitui** o que as seções de cima dizem sobre família, material da subparte, `glb_multiplos` e cópias.

## Escopo do v1 do plugin

O v1 trabalha **só com produto estático**. Produto animado entra tratado como estático. Os campos de animação do JSON (`animacao`, `so3d`, pares, meshes separadas) ficam, sem uso: as ferramentas de animação são do v2. Não existe "família de animação" no v1.

## Respostas

| Pergunta | Resposta |
|---|---|
| Material da subparte `so3d` | O objeto `codEst_Porta_1` carrega o material da **parte-mãe** (`ART_P_Porta`). As subpartes saem da lista de materiais. |
| `glb_multiplos` (07132220 / 07132222) | **Não é tecido.** São blocos de produto diferentes, cada um com seu `.max` e seu GLB. `L11`, `L12`… é indicador de **posição** de um detalhe físico: não é acabamento e não entra no `material_id`. O L-code é o nome do GLB final (`codEst_L11.glb`). |
| `L14_L33` | A confirmar com a Bia. |
| Cópia (`duplicar_renomear`) | A mesh dentro do GLB **muda** para o `cod_est` da cópia. Copiar o arquivo não basta: tem que reexportar com a mesh renomeada. |
| Material da cópia | Mesmos `material_id` do master. Outdoor × Freijó é acabamento, não slot. |
| Cópia de base não liberada | A cópia segue a base. O 09125010 foi liberado para o teste. |
| Luang 07119245 | A definir com a Bia: ou as 6 partes entram na mesh, ou o produto vira `ok_3d=false`. |
| `ok_3d=false` no v3 | 00111091, 00122093, 07131A31. |
| Vanity | As meshes com espaço serão limpas (`00261002_Tampa1_Puxador1`). |

## Tabela classe → família (estrutural)

| Classe | Família |
|---|---|
| Aparador | Corpo Único (simples) · Pernas + Tampo (se o tampo é acessório) |
| Mesa de Centro / Jantar / Lateral | Corpo Único |
| Mesa de Jogo | Corpo Único |
| Banco / Puff | Corpo Único (simples) · Estrutura + Estofado (composto/estofado) |
| Escrivaninha | Pernas + Tampo |
| Mesa Bar / Mesa de Chá / Bistrô | Pernas + Tampo |
| Cadeira / Poltrona / Chaise Longue | Estrutura + Estofado |
| Estante / Carro Bar | Estrutura Modular |

A definir pela equipe: Vanity Desk, Buffet, Sofá.

## O que mudou no plugin (branch `feat/produto-v1-estatico`)

- **Família:** `InLab_Produto_SugerirFamilia` usa a tabela acima e não olha mais animação. Saiu o palpite por "giratória"/porta/gaveta, inclusive o "mesa giratória → Rotação" da manhã. Produto animado recebe a família da classe, com "entra como estático nesta versão" no motivo.
- **Classes com duas famílias:** saem do dado. Aparador com parte "Tampo" marcada `acessorio: true` → Pernas + Tampo. Banco ou Puff com alguma parte `tecido: true` → Estrutura + Estofado. No v2: 1 de 7 bancos e 16 de 18 puffs têm tecido; nenhum aparador tem tampo acessório.
- **Classes sem definição:** Sofá, Buffet e as que não entraram na tabela (Módulo, Banqueta, Cabeceira, Cama, Bicama, Longarina, Mesa Componível, Coluna de Jantar, Mesa de Cabeceira) mantêm o palpite antigo, com "provisório" no motivo. Vanity Desk segue sem sugestão.
- **Subpartes `so3d`:** `InLab_Produto_PartesDeMaterial` tira as subpartes da lista "Parte → material". `ligacoes` passa a ser paralelo a essa lista.

Mudança de sugestão em relação ao que o plugin fazia: Mesa de Jantar / Centro / Lateral eram Pernas + Tampo e viraram Corpo Único; Cadeira era Corpo Único e virou Estrutura + Estofado; Estante era Corpo Único e virou Estrutura Modular.

## Em aberto depois do v3

- **Dropdown Família ainda tem 8 famílias** (4 estruturais + Translação, Rotação, Giro de Assento, Movimento Especial). A sugestão não aponta mais para as 4 animadas, mas elas continuam escolhíveis e com verificações próprias. Tirar ou esconder é decisão de produto.
- **Nomes de objeto de produto animado no v1:** se o animado entra como estático, o objeto é um só (`cod_est`) ou as meshes separadas (`codEst_Porta_1`, `codEst_GavetaFrente_Gaveta`) continuam valendo? Hoje o dropdown "Nome do objeto" oferece todos os nomes de `mesh_final`.
- **Variantes de posição (issue #92):** como se chama o `.max` de cada variante, e a pré-seleção pelo nome do arquivo precisa reconhecer `codEst_L11`.
- **`L14_L33`** e **Luang 07119245:** com a Bia.

## Cópias de `bloco_3d` no plugin (issue #93, branch `feat/produto-copias-bloco3d`)

A cópia não tem `.max` próprio: sai do `.max` do master com a mesh renomeada e os mesmos `material_id`. O fluxo usa o que já existia:

1. Abrir o `.max` do master (pré-selecionado pelo nome do arquivo), renomear e exportar.
2. Escolher a cópia no dropdown Produto. Os materiais já vêm ligados (mesmo `material_id`) e "Ler objetos" sugere o nome da cópia.
3. "Renomear objetos" e exportar.
4. Para voltar ao master: escolher o master de novo e "Renomear objetos". **Não usar "Desfazer nomes"** para isso: ele desfaz a sessão inteira, inclusive a renomeação do master.

O que entrou: o log da escolha do produto diz de qual master a cópia sai e lista as cópias de um master; cópia cuja base está com `ok_3d = false` é pulada junto (a cópia segue a base); base fora do arquivo de produtos gera aviso, sem bloquear.

## Conferência do JSON v3 (`produtos teste plugin rafa v3.json`, exportado 02/10/2026 16:08 UTC)

Mesmos 66 produtos do v2, mesmas chaves. Bate com o que a Bianca afirmou:
- 0 `cod_est` duplicado, 0 `mesh_final` órfão, todo master com a própria base.
- `ok_3d = false` só em 00111091, 00122093 e 07131A31 (09125006 e 09125010 foram liberados).
- As 9 cópias têm exatamente os mesmos `material_id` do master.

Diferenças em relação ao v2: 00150099 (Kalao master) ganhou a parte Deslizador; 09125006 e 09125010 mudaram `ok_fd` e `ok_3d`. Nada mais.

Pontos para devolver:
1. **00150099 (Kalao master):** o Deslizador novo veio com `mesh_final` vazio e fora de `meshes[0].partes`. Na cópia 06150000 ele está na mesh `06150000`.
2. **Vanity (00261002):** os nomes de mesh com espaço continuam (ela disse que serão limpos).
3. **Luang (07119245):** continua com as 6 partes sem mesh (a definir com a Bia).

No plugin, com o v3: só a Vanity Desk fica sem sugestão de família; Banqueta, Buffet e Sofá saem com sugestão provisória; os 3 produtos com `ok_3d = false` são pulados e nenhuma cópia fica bloqueada pela base.

## JSON v5 (`produtos_teste_plugin_rafa_v5.json`, exportado 02/10/2026 18:20 UTC)

Mesmos 66 produtos. Os três pontos devolvidos no v3 foram corrigidos: o Deslizador do Kalao master (00150099) entrou na mesh; a Luang (07119245) ganhou `mesh_final` nas 6 partes; as meshes da Vanity perderam os espaços (`00261002_Tampa1_Puxador1`). Nenhuma parte fora de subparte ficou sem mesh, nenhum nome com espaço, nenhum órfão. Segue em aberto só o `acab_id "L14_L33"`. O teste de dado real passa a ler o v5.

## Teste com os assets do piloto (02/10/2026)

Pasta `PILOTO PLUGIN INLAB\ARTEFACTO` (19 `.max`, nomeados pelo nome do produto, não pelo `cod_est`). Seis foram copiados para a pasta temp do Max com o `cod_est` no nome e passaram pelas funções da seção Produto e do botão Verificar: 05125111, 07129404, 07132200, 00125400, 00111091 e 09125004.

- Funcionou: pré-seleção pelo nome do arquivo, família pela classe, bloqueio do `ok_3d = false` (00111091), aviso de base de cópia (09125004), animado como estático (00125400), mensagem da V-20.
- **Sugestão zerada nos seis:** 0 materiais ligados e 0 objetos com nome sugerido. Os assets crus têm nomes genéricos (`Cylinder002`, `Material #18`, `Iron Clean`).
- Todos reprovam na V-17 (pivot da raiz 22 a 36 cm acima do chão): arquivos ainda não preparados.
- Pontuais: Puff Dorset sem material; Mentha com keyframes em `Plane009`; Louise com escala não resetada (inclusive negativa). Dois arquivos (Louise Amarela) não têm produto no JSON.

## Decisões do usuário (02/10/2026, branch `feat/v20-critica-familias-v1`)

- **V-20 crítica com produto importado.** Nome errado reprova. Sem produto importado continua em advertência.
- **Dropdown Família só com as 4 estruturais.** `INLAB_FAMILIAS_ANIMADAS_NA_UI = false` em `core/struct_familia.ms`; as 4 animadas continuam registradas para o v2.
- **Nome único:** produto com um só nome de objeto sugere esse nome para todos os objetos lidos (5 dos 6 assets do piloto).

---

# Respostas finais do dia (`Resposta_Rafa.md` e `Arquetipos_Modelagem_FAST.md`)

## O que a Bianca fechou

| Pergunta | Resposta |
|---|---|
| Nome do `.max` de cada variante | `codEst_id` (`07132220_L11.max`). O GLB e a mesh saem com o mesmo nome. Vale na V-20. |
| `L14_L33` | Cada variante é um id e um `.max`. O "L14_L33" é pendência dela: se forem duas posições, viram duas variantes e o JSON é reenviado. |
| Animado no v1 | **Mantém as meshes separadas** (`codEst_Porta_1`, `codEst_Prato_Giratoria`…). Os nomes continuam válidos no dropdown e na V-20. |
| Critério Aparador / Banco / Puff | Aceito. |
| Arquivos do piloto | **Renomear os 19 `.max` para o `cod_est`.** O plugin não aceita o nome do produto: a base de nomes tem inconsistência e casar por nome daria falha silenciosa. |
| Louise Amarela | Tratar como não cadastrada; ela confere no legado. |
| Limites (Birô) | Para o teste, valem os limites que já estão no plugin, como **referência do teste, não definitivos**. Pode liberar as 25 verificações em cima deles. Se for preciso medir taxa de reprovação, pode ligar como corte temporário. |
| "Por bloco" | **1 bloco = 1 arquivo `.max`**. Os limites por bloco valem por arquivo. |

## Arquétipos de modelagem (5)

O que o plugin chama de família é o arquétipo de blocos. Esta tabela **substitui** a tabela v3 acima (as mesas voltaram para Pernas + Tampo).

1. Corpo Único · 2. Pernas + Tampo · 3. Estrutura + Estofado · 4. Corpo + Portas/Gavetas · 5. Base + Cabeceira

| Arquétipo | Classes |
|---|---|
| Pernas + Tampo | Carro Bar, Carro Chá, Mesa Bar, Mesa Componível, Mesa de Centro, Mesa de Chá, Mesa de Jantar, Mesa de Jogo, Mesa Lateral |
| Estrutura + Estofado | Chaise Longue, Módulo, Sofá |
| Corpo Único | Biombo, Cabeceira, Cavalete, Coluna de Jantar |
| Corpo + Portas/Gavetas | Buffet, Caixa Bar, Cômoda, Escrivaninha, Estante, Mesa de Cabeceira, Móvel Bar, Vanity Desk |
| Base + Cabeceira | Bicama, Cama |
| Pelo dado: tecido → Estrutura + Estofado; senão Corpo Único | Balanço, Banco, Banqueta, Cadeira, Longarina, Poltrona, Puff |
| Pelo dado: tampo acessório → Pernas + Tampo; senão Corpo Único | Aparador |

## O que mudou no plugin (branch `feat/arquetipos-e-variantes`)

- **Sugestão de família** pela tabela acima. Sai a tabela "provisória".
- **Dois arquétipos ainda não têm família no plugin** (Corpo + Portas/Gavetas e Base + Cabeceira): as classes deles ficam sem sugestão, com o motivo no log. No export Contract/Health são 14 de 209 produtos; no v5 são 5 de 66 (2 buffets, 2 escrivaninhas, 1 vanity desk).
- **Variantes de posição (issue #92):** `InLab_Produto_Variantes` e `InLab_Produto_IndicePorArquivo`. O `.max` chamado `codEst_id` pré-seleciona o produto; os nomes das variantes entram no dropdown "Nome do objeto"; no `.max` de uma variante todo objeto recebe o nome dela; a V-20 aceita o arquivo e exige exatamente esse nome nos objetos.

## Em aberto

- **Criar as duas famílias novas** (Corpo + Portas/Gavetas, Base + Cabeceira): precisam de limites (peso, faixa de polígonos, draw calls). Decisão de produto.
- **Estrutura Modular** existe no plugin e não aparece na tabela da equipe: nenhuma classe sugere mais essa família.
- **V-04 (polígonos por parte):** a Bianca fala em "limites que você recomendou", mas `limitesPorParte` está vazio nas 8 famílias. Sem números, a V-04 continua "pendente".
- **Ligar os limites como corte** (`INLAB_LIMITES_PROVISORIOS = false`) durante o teste: liberado por ela, decisão do usuário.
- **As 25 verificações (#38):** liberadas por ela. A spec v2.0 que as define não está no repo.
- **`L14_L33`** e **Louise Amarela:** com a Bianca.

---

# Atualização de 05/10/2026

O que fechou desde a lista "Em aberto" acima:

- **`L14_L33`:** no sistema existem dois acabamentos com o mesmo significado. L33 quer dizer "sem acabamento" e L14 quer dizer "sem acessório": nos dois casos, o detalhe não existe no bloco. Então `07132220_L14_L33` é **uma variante só**, a que não tem o detalhe. Não são duas posições e o JSON não precisa ser reenviado. O plugin já trata esse nome como qualquer outra variante: nenhuma mudança.
- **Louise Amarela:** está inativa e fica fora do piloto. Nenhuma mudança no plugin.
- **Famílias novas:** Corpo + Portas/Gavetas (20 MB, 100k–200k triângulos, 20 draw calls) e Base + Cabeceira (18 MB, 80k–180k, 12 draw calls), com limites provisórios decididos pelo usuário. Todo produto da tabela recebe sugestão. No export Contract/Health, 209 de 209.
- **V-04:** removida (PR #104). O produto estático chega como uma mesh só, sem objeto por parte para medir.
- **As 25 verificações (#38):** spec v2.0 localizada fora do repo, que é público. Recorte do v1 com 15 verificações, nas sub-issues #101, #102 e #103.

Segue em aberto: **Estrutura Modular** sem classe na tabela da equipe, e **ligar os limites como corte** durante o teste.
