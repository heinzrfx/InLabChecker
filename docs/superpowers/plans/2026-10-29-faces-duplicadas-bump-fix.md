# Faces duplicadas, intensidade do bump e Bump Fix — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** dar ao desenhista um jeito de achar as faces que reprovam a V-09, e levar a intensidade do bump do Corona para o GLB (na conversão e depois, pelo Bump Fix).

**Architecture:** a V-09a passa a ter uma função que devolve o bitarray das faces (a contagem vira `numberSet` dela), e o botão novo usa a mesma função. A intensidade é lida numa função própria em `fn_material_convert.ms` e gravada em `glTFMaterial.normal`; o Bump Fix grava o valor de um spinner nos glTF com `normalMap`. Os dois botões entram no grupo fixo Utilidades Rápidas.

**Tech Stack:** MaxScript, 3ds Max 2024, Corona, glTF Material nativo.

**Spec:** issue #214 (https://github.com/heinzrfx/InLabChecker/issues/214).

## Global Constraints

- Faces duplicadas: mesma regra e tolerância da V-09a (`InLab_Malha_FacesDuplicadas`, `InLab_Malha_Tolerancia()`); a V-09 e o botão usam a mesma função. Não apaga nada.
- Sem seleção, os dois botões agem em toda a geometria da cena (`InLab_EhGeometria`).
- `glTFMaterial.normal` = Bump amount × `multiplier` do CoronaNormal. Physical: `baseBumpMapAmount`; Legacy: `mapamountBump`. Sem essas propriedades (VRay), o amount vale 1.0.
- Bump Fix: só glTF Material **com** `normalMap`; log `"<material>: 1,00 → 0,30"` (vírgula, 2 casas); dentro de `undo "InLab Bump Fix" on`.
- Achados da sondagem de 29/10 no Max 2024: o glTF Material tem `normal` (float, padrão 1.0) e `normalMap` (texmap) — `#normal` NÃO pode ser candidato para o mapa; os triângulos de `snapshotAsMesh` de um Editable Poly de stack vazio saem na ordem dos polígonos, `grau − 2` cada.
- Textos de UI e log em português; commits `feat(util): ...` / `feat(material): ...`, sem acento no assunto.

## Review Focus

- Peça com modificadores ou primitiva (não Editable Poly/Mesh de stack vazio): não dá para selecionar no nível de polígono da base. Esperado: conta e loga `#warn` "colapse o stack para selecionar", sem mexer na peça. Teste na Task 2.
- Várias peças com duplicata: o Modify só abre o subnível com um nó. Esperado: seleciona todas as que têm duplicata, grava a seleção de faces em cada uma e só abre o polígono se for uma. Teste na Task 2.
- Instâncias: a seleção de faces vai na base compartilhada; contar a mesma base duas vezes duplica o log. Esperado: uma linha por nó, sem erro. Teste na Task 2.
- Multimaterial com sub glTF: o Bump Fix tem que descer nos submateriais. Teste na Task 4.
- Material Corona ainda não convertido na seleção: o Bump Fix ignora (só glTF), com o resumo dizendo quantos mudaram, e `#warn` se nenhum. Teste na Task 4.

---

### Task 1: V-09a devolve as faces

**Files:**
- Modify: `verifications/verif_malha.ms:279-314` (`InLab_Malha_FacesDuplicadas`) e cabeçalho
- Test: `tests/test_verif_malha.ms`

**Interfaces:**
- Produces: `InLab_Malha_FacesDuplicadasSet m tol` → `bitArray` de índices de face da TriMesh `m`. `InLab_Malha_FacesDuplicadas m tol` → `integer` continua existindo (`(InLab_Malha_FacesDuplicadasSet m tol).numberSet`).

- [ ] **Step 1: teste.** Em `test_verif_malha.ms`, numa malha de 2 boxes atachados no mesmo lugar (24 tris), `checar "FacesDuplicadasSet: 24 faces marcadas" ((InLab_Malha_FacesDuplicadasSet m tol).numberSet == 24)` e `checar "FacesDuplicadasSet: bitarray" (classof (...) == BitArray)`; malha de um box só → `numberSet == 0`. Pré-declarar o global no topo do teste.
- [ ] **Step 2:** rodar `fileIn tests\test_verif_malha.ms` em cena vazia; os itens novos falham ("Call needs function").
- [ ] **Step 3:** renomear o corpo para `InLab_Malha_FacesDuplicadasSet` (devolve `dup`; `nf < 2` → `#{}`) e redefinir `InLab_Malha_FacesDuplicadas` como o wrapper. `global InLab_Malha_FacesDuplicadasSet` antes do wrapper. Nota no cabeçalho com data (#214).
- [ ] **Step 4:** rodar o teste; todos PASS (os antigos da V-09 também).
- [ ] **Step 5:** commit `feat(verif): V-09a devolve as faces duplicadas (#214)`.

### Task 2: botão Faces duplicadas (função)

**Files:**
- Create: `functions/fn_faces_duplicadas.ms`
- Modify: `InLabChecker.ms` (manifesto: depois de `functions\fn_utilidades.ms`), `tests/test_globais_adiantados.ms` se ele listar módulos à mão
- Test: `tests/test_faces_duplicadas.ms` (novo, no padrão de `test_utilidades.ms`)

**Interfaces:**
- Consumes: `InLab_Malha_FacesDuplicadasSet`, `InLab_Malha_Tolerancia` (verif_malha carrega depois: pré-declarar com `global`), `InLab_EhGeometria`.
- Produces: `InLab_FacesDuplicadas objs:undefined` → `integer` (total de faces duplicadas, em triângulos). `objs:undefined` = seleção geométrica, ou a cena toda se a seleção está vazia.
- Produces: `InLab_FacesDup_TriParaPoly o tris` → `bitArray` de polígonos da base Editable Poly `o` (mapeamento por `grau − 2`).

- [ ] **Step 1: testes.**
  - `TriParaPoly`: Editable Poly com um quad e um pentágono (graus 4 e 5); `tris #{1,2}` → `#{1}`; `#{3}` → `#{2}`; `#{2,5}` → `#{1,2}`.
  - Poly com box duplicado atachado: `InLab_FacesDuplicadas objs:#(o)` devolve 24, `polyop.getFaceSelection o == #{1..12}`, `subObjectLevel == 4`, `selection[1] == o`, `polyop.getNumFaces o` igual ao de antes (não apagou).
  - Editable Mesh com o mesmo caso: `getFaceSelection o` com 24 faces.
  - Box com modificador `Bend` e faces duplicadas (Box + cópia atachada antes do Bend): devolve 24, loga `#warn` contendo "colapse", e a seleção de faces da base não muda.
  - Duas peças com duplicata: as duas selecionadas, `subObjectLevel` não forçado (sem erro).
  - Peça limpa: devolve 0 e loga `#ok`.
  - Instância de peça com duplicata: duas linhas de log, sem exceção.
  - Sem seleção: age na cena (cria peça com duplicata, `clearSelection()`, devolve 24).
- [ ] **Step 2:** rodar; falham.
- [ ] **Step 3: implementar.** Por nó: `snapshotAsMesh` → `InLab_Malha_FacesDuplicadasSet` → apagar o snapshot. Editable Poly de stack vazio: `polyop.setFaceSelection o (InLab_FacesDup_TriParaPoly o tris)`; Editable Mesh de stack vazio: `setFaceSelection o tris`; outros: só log `#warn` "<n> face(s) coincidente(s) — colapse o stack para selecionar". Log por objeto: `#err` "<n> face(s) coincidente(s), selecionadas" / `#ok` "sem faces duplicadas"; resumo final. Ao fim, `select` os nós com duplicata (`with undo off`; abrir grupos acima com `InLab_AbrirGruposAcima`); se for um só e selecionável: `max modify mode`, `subObjectLevel = 4` (poly) ou `3` (mesh). Cabeçalho do arquivo no padrão do projeto. Adicionar ao manifesto.
- [ ] **Step 4:** rodar o teste novo e `test_globais_adiantados.ms`; tudo PASS.
- [ ] **Step 5:** commit `feat(util): botao Faces duplicadas seleciona as faces da V-09 (#214)`.

### Task 3: conversão leva a intensidade do bump

**Files:**
- Modify: `functions/fn_material_convert.ms:909-926` (bloco NORMAL/BUMP) e cabeçalho
- Test: `tests/test_material_convert.ms`

**Interfaces:**
- Produces: `InLab_IntensidadeBump mtl mapaBump` → `float` = (`baseBumpMapAmount` | `mapamountBump` | 1.0) × (`mapaBump.multiplier` | 1.0).

- [ ] **Step 1: testes** (pular com PASS "Corona ausente" se a classe faltar):
  - Physical `baseBumpMapAmount = 0.5`, CoronaNormal `multiplier = 0.6` com um Bitmaptexture em `normalMap` → glTF convertido com `normal` ≈ 0.3 (tol 1e-4) e `normalMap != undefined`.
  - Legacy `mapamountBump = 0.4`, multiplier 1 → `normal` ≈ 0.4.
  - Sem bump → `normal == 1.0`.
  - O log tem uma linha com "intensidade do normal" e "0,30".
- [ ] **Step 2:** rodar; falham (normal fica 1.0).
- [ ] **Step 3:** implementar `InLab_IntensidadeBump` (via `InLab_PropSafe`) e, quando o normal map é gravado, `InLab_SetPropSafe g #(#normal) (InLab_IntensidadeBump mtl mapaBump)` com log `#info` "<mtl>: intensidade do normal 0,30 (amount 0,50 × multiplier 0,60)". Tirar `#normal` da lista de candidatos do **mapa** (`#(#normalMap, #normalTexmap)`). Incluir `normal:` na linha de `InLab_AuditarGLTF`. Formatação com vírgula: função local `InLab_Num2 x` (2 casas, `substituteString` de "." por ","), definida uma vez neste arquivo e reutilizada na Task 4.
- [ ] **Step 4:** rodar; tudo PASS.
- [ ] **Step 5:** commit `feat(material): conversao leva a intensidade do bump para o glTF (#214)`.

### Task 4: Bump Fix (função + UI dos dois botões)

**Files:**
- Modify: `functions/fn_material_convert.ms` (fim do arquivo), `ui/rollout_main.ms:925-940` (grupo Utilidades) e `:1116` (altura), cabeçalhos
- Test: `tests/test_material_convert.ms`

**Interfaces:**
- Consumes: `InLab_FacesDuplicadas` (Task 2), `InLab_Num2` (Task 3), `InLab_VerUV_Garantir` (guarda `!= undefined`; com Ver UV ligado, ler o material de verdade por `InLab_VerUV_MaterialDe o`).
- Produces: `InLab_BumpFix valor objs:undefined` → `integer` (materiais alterados).

- [ ] **Step 1: testes.**
  - Dois objetos com glTF `normalMap` setado (normal 1.0) + um glTF sem normal map + um Corona: `InLab_BumpFix 0.3 objs:#(...)` devolve 2; os dois com normal ≈ 0.3; o sem mapa fica 1.0.
  - Multimaterial com um sub glTF com normal map → alterado.
  - Material compartilhado por dois nós conta uma vez.
  - `max undo` volta o `normal` para 1.0.
  - Log tem "1,00 → 0,30"; seleção sem glTF com normal map → 0 e `#warn`.
- [ ] **Step 2:** rodar; falham.
- [ ] **Step 3: implementar `InLab_BumpFix`.** Junta materiais únicos (desce em `Multimaterial.materialList`), filtra classe glTF com `normalMap != undefined`, grava dentro de `undo "InLab Bump Fix" on`. Chama `InLab_VerUV_Garantir()` antes.
- [ ] **Step 4: UI.** No grupo fixo, nova linha em `y = 162`: `btnUFacesDup "Faces duplicadas"` pos:[12,162] w:208; `spnUBump "Intensidade" range:[0,5,0.3] scale:0.05` pos:[226,164] w:100 (fieldwidth ~40); `btnUBumpFix "Bump Fix"` pos:[334,162] w:100. `lblFindLimite` desce para y=190; `grpUtil` height 150; `subSecoes` pos:[4,216]; `createDialog` 446 → altura 732 (216 + 508 + 8) com nota no comentário. Handlers: `InLab_FacesDuplicadas()` e `InLab_BumpFix spnUBump.value`. Tooltips curtas em português.
- [ ] **Step 5:** rodar os testes de material, `test_posicao_painel.ms`, `test_globais_adiantados.ms`; tudo PASS. Abrir o plugin pelo `fileIn InLabChecker.ms` e conferir por captura de viewport/tela que a linha nova não sobrepõe nada.
- [ ] **Step 6:** commit `feat(util): Bump Fix e botoes no grupo Utilidades Rapidas (#214)`.

### Task 5: suíte, Nambu e PR

- [ ] **Step 1:** rodar a suíte inteira (`tests\test_*.ms`) em cena vazia; anotar PASS/FAIL.
- [ ] **Step 2:** se o .max da Nambu 00125400 estiver acessível, abrir, rodar Faces duplicadas e conferir que as 660 faces da V-09 aparecem selecionadas (salvar cópia da cena do usuário antes).
- [ ] **Step 3:** push e PR para `main` com "Closes #214". Sem release.
