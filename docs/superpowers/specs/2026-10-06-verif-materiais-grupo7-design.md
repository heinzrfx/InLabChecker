# Grupo 7 · Verificações de materiais (V-23, V-24, V-25, V-35, V-36, V-37, V-38)

Issue #103 (parte do epic #38). Data: 06/10/2026.

## 1. Objetivo

Ligar ao motor de verificação as sete checagens de material do grupo 7 da spec v2.0 (seção 5, "Materiais"), com critérios que façam sentido para o acervo real. A spec funcional fica fora do repo, porque é um documento interno e o repo é público: v2.0 em `G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\Specs\plugin_spec_inlab_v2.pdf` (seções 3.2, 3.4 e 6); V-23 a V-25 na v1.0 (`...\SCRIPT GLB\plugin_spec_inlab.md`, tabela da seção 2).

Com este grupo, o aviso de relatório parcial do orquestrador passa a citar só o grupo 4 (animação), que fica para o v2.

## 2. Decisões (06/10/2026, com o usuário)

1. **As verificações leem o material Corona, não o glTF Material.** O acervo de materiais é Corona, e o glTF é o passo final, que herda tudo do Corona na conversão (`fn_material_convert.ms`). Verificar a fonte é verificar o que a conversão vai receber.
2. **Qualquer mapa conta como slot preenchido**, procedural incluído (`CoronaColorCorrect`, `CoronaMix`, `CoronaTriplanar`, `CoronaColor`, ...). Esses mapas mudam o resultado final do material. Toda checagem percorre a árvore inteira de cada slot, não só o mapa de cima.
3. **V-23 não reprova material com um mapa só.** Ter só o base color é exceção válida. Roughness ou normal vazios saem como nota.
4. **V-24 não reprova PNG em material que precisa de alpha:** palha (pelo nome) ou qualquer material com mapa de opacidade.
5. **V-36 nunca reprova por valor.** Roughness, IOR e intensidade de refração ficam livres, porque o artista pode precisar mexer neles para chegar no resultado (ex.: vidro jateado é fosco de propósito). Só confere se a refração está ligada.
6. O bake de procedurais 3D na conversão (`CoronaTriplanar` e mapas Corona via `renderMap`) é problema do conversor, fora deste grupo: issue #110.

## 3. O que o piloto mostrou (sondagem de 06/10/2026, Max 2024)

| Arquivo | Classes | Observação |
|---|---|---|
| Aparador Zucchi | CoronaLegacyMtl | `Material #30`: só difuso (`CoronaColor`) |
| Poltrona Mentha | CoronaLegacyMtl, 1 Multi/Sub (IDs 1–10) | glossiness por `CoronaTriplanar`; difuso por `CoronaMix`/`RGB_Multiply` |
| Mesa Lateral Nambu | CoronaLegacyMtl | `metal dourado artefacto` sem difuso mapeado |
| Mesa Lateral Louise Jateada | CoronaLegacyMtl | `Vidro Jateado` e `Glass Bronze Distorted`: refração 1,0, sem mapas |
| Puff Pol | VRayMtl (todos) | |

- Nenhum CoronaPhysicalMtl e quase nenhum bitmap direto: os slots são procedurais.
- Os nomes de material são genéricos até a renomeação pelo JSON (seção Produto).
- O CoronaLegacyMtl não expõe propriedade de 2-sided (`twoSided` = undefined).

## 4. Arquitetura

### 4.1 Arquivo novo

`verifications/verif_materiais.ms`, no manifesto (`INLAB_MODULOS`) depois de `verif_mapeamento.ms` e antes de `report_generator.ms`. Usa `fn_material_convert.ms` (perfil de slots, tipo de material, detecção de palha/cristal) e `fn_renomear_produto.ms` (produto importado, árvore de mapas), que carregam antes.

### 4.2 Perfil de slots compartilhado com o conversor

Hoje `InLab_ConverterCoronaMtl` monta dentro de si as listas de nomes de propriedade por tipo (`candCor`, `candMapaBase`, `candMapaGloss`, `candBump`, `candOpacMapa`, `candRefrVal`, `candIOR`). Elas saem para uma função de `fn_material_convert.ms`:

```maxscript
struct PerfilSlots ( cor, mapaBase, valGloss, mapaGloss, bump, opacMapa, refrVal, ior )
fn InLab_Material_PerfilSlots tipo = ( ... )   -- tipo: #physical | #legacy | #vray
```

O conversor passa a ler o perfil dessa função, sem mudar de comportamento (os testes `test_material_convert.ms` e `test_material_utils.ms` confirmam). As verificações leem os mesmos slots. Nome de propriedade novo numa build do Corona se corrige num lugar só.

### 4.3 Helpers do módulo

- `InLab_Mat_Resolvidos objetos` devolve os materiais a verificar, cada um uma vez: Multi/Sub vira os sub-materiais **usados por alguma face**; Layered vira o material base (`#baseMtl`, `#baseMaterial`, `#base`, como na conversão). Cada item guarda o material, o tipo (`InLab_TipoDeMaterial`) e os objetos que o usam.
- `InLab_Mat_MapasDoSlot mtl nomes` lê o slot pelo perfil (primeiro nome de propriedade que existe) e devolve a árvore inteira de mapas (reaproveita `InLab_Produto_ColetarMapas`).
- `InLab_Mat_ArquivoDoMapa tm`: caminho de `Bitmaptexture` (`.filename`) e `CoronaBitmap` (`.filename`), ou `undefined`.
- Material de tipo `#outro` (Standard, Physical Material, ...) não sai convertido: vira advertência na V-23 e as outras checagens de slot pulam esse material.

Falha ao ler um material nunca passa em silêncio: o material vira "não medido" na mensagem, vai para o log e o laço segue.

## 5. As verificações

| ID | Regra | Severidade |
|---|---|---|
| V-23 | Material sem nenhum mapa no base color → advertência. Material de tipo que a conversão não suporta → advertência. Roughness ou normal vazios: só nota na mensagem ("sem roughness: a, b; sem normal: c"). | Advertência provisória (`critico:true provisorio:true`) |
| V-24 | Bitmap `.png` em qualquer ponto da árvore do base color ou do roughness. Exceção: palha (`InLab_DetectarEspecial` = `#palha`) ou material com algum mapa no slot de opacidade; a mensagem registra "PNG aceito (alpha): material". | Crítica |
| V-25 | Para cada objeto com Multi/Sub: face com ID que não leva a um sub-material (slot vazio ou ID fora da lista) → falha, listando objeto e ID. Com produto importado, parte do produto (`material_id` de `InLab_Produto_PartesDeMaterial`) sem nenhuma face na cena sai só como **nota** na mensagem, sem reprovar: um bloco pode não ter todas as partes de propósito (estrutura sem o tampo acessório, variante de posição). O nome do sub-material contra o `material_id` não entra, porque a V-20 já confere. | Crítica (só a regra dos IDs) |
| V-35 | Material de palha sem mapa no slot de opacidade → advertência. O 2-sided não é conferido: o conversor liga `doubleSided` sozinho no glTF, e o CoronaLegacyMtl não tem a propriedade. Sem palha na cena: "não se aplica". | Advertência provisória |
| V-36 | Material de cristal/vidro (`#cristal`) com refração 0 → advertência. Valor de refração, roughness e IOR não são conferidos (decisão 5). VRay: refração = cor de `refraction` diferente de preto. Sem cristal: "não se aplica". | Advertência provisória |
| V-37 | Só se a família tem `"zona_acabamento"` em `materialTypes` (hoje Estrutura + Estofado). Com produto: cada parte `tecido: true` precisa ter faces com o seu `material_id`; parte de tecido sem faces → advertência. Sem produto: o estofado num único ID em todos os objetos → advertência ("pode ser produto sem desmembramento"). Família sem zona: "não se aplica". | Advertência provisória |
| V-38 | Só se `InLab_TampoAcessorioProduto` ou `cfg.tampoAcessorio`. Com produto: a cena tem faces com o material da parte "tampo" marcada `acessorio: true` E faces com material de outra parte → advertência ("separe estrutura e tampo em arquivos"). Sem produto: "pendente". Sem tampo acessório: "não se aplica". | Advertência (`critico:false`) |

"Advertência provisória" = `provisorio:true`: vira `#warning` enquanto `INLAB_LIMITES_PROVISORIOS` for true (decisão de 05/10/2026 na issue #103).

Mensagens listam no máximo 8 itens com `InLab_ListaResumida` (`core/utils.ms`).

## 6. Orquestrador

```maxscript
-- ===== Grupo 7 · Materiais (issue #103, verif_materiais.ms) =====
local mats = InLab_Mat_Resolvidos objetos
InLab_V23_SlotsPBR mats
InLab_V24_PNG mats
InLab_V25_IDsDeMaterial objetos produto
InLab_V35_Palha mats
InLab_V36_Cristal mats
InLab_V37_ZonasEstofado cfg objetos produto
InLab_V38_TampoAcessorio cfg objetos produto

-- ===== Grupo 4 · próxima entrega (v2) =====
InLab_Log "Grupo 4 (animação avançada) fica para o v2 — relatório parcial." tipo:#warn
```

Atualizar o status do grupo 7 no cabeçalho do orquestrador e a nota de não críticos em `core/struct_result.ms` (V-38).

## 7. Testes

`tests/test_verif_materiais.ms`, no padrão de `test_verif_malha.ms`. Materiais criados por script: CoronaLegacyMtl e CoronaPhysicalMtl; VRayMtl só se a classe existir (senão o caso é pulado, com linha `PASS ... pulado: VRay ausente`). Bitmaps de teste gravados em `(getDir #temp)` com `openFile`/`bitmap` (sem `createFile`, por causa do safe_mode do MCP).

| Caso | Esperado |
|---|---|
| Legacy com `CoronaColor` no difuso, sem gloss/bump | V-23 passa, nota "sem roughness/normal" |
| Legacy sem mapa no difuso | V-23 advertência |
| Standard material | V-23 advertência (não convertível) |
| PNG dentro de `CoronaMix` no difuso | V-24 falha |
| PNG no difuso de material "Palha natural" | V-24 passa, mensagem "PNG aceito" |
| PNG no difuso com mapa de opacidade | V-24 passa |
| JPG no difuso e no gloss | V-24 passa |
| Multi/Sub com face de ID sem sub-material | V-25 falha, lista objeto e ID |
| Produto com parte sem faces | V-25 passa, com nota listando a parte |
| Palha sem opacidade / com opacidade | V-35 advertência / passa |
| "Vidro Jateado" com refração 1,0 e glossiness baixo | V-36 passa |
| Vidro com refração 0 | V-36 advertência |
| Estofado com 2 partes de tecido, uma sem faces | V-37 advertência |
| Família sem zona | V-37 não se aplica |
| Tampo acessório com tampo e pernas na cena | V-38 advertência |
| Material que lança ao ler | "não medido", sem exceção |
| Perfil de slots | conversor converte igual antes e depois da extração |

Também: rodada completa em `test_verificacoes.ms` (grupo 7 presente: V-23, V-24, V-25, V-35, V-36, V-37, V-38), listas de módulos dos testes que carregam o orquestrador, suíte inteira no Max e o piloto (Zucchi, Mentha, Nambu, Louise Jateada, Puff Pol), conferindo que nenhuma verificação lança e que nenhum procedural do acervo vira falso "slot vazio".

## 8. Fora do escopo

- Bake fiel de procedurais 3D na conversão: #110.
- Conferir o glTF Material depois da conversão (decisão 1).
- V-26 a V-34, V-39 e V-40 (animação): v2.
