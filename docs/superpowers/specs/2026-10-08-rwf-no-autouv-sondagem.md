# Sondagem: Real World Fix dentro do Auto UV (issue #128)

08/10/2026 · Max 2024.2.14 · epic #121 (ajuste 5 do teste com a Bia).
Pedido: o Real World Fix (RWF, `functions/fn_realworldfix.ms`) passa a rodar dentro do Auto UV (`functions/fn_autouv.ms`), e o botão próprio dele sai.

## Material

- **Primitivas:** um caso de cada situação do RWF.
  - **A:** ChamferBox poly com UVW Map Box em Real-World, mais CoronaBitmap 60×40 com offset 15,10 e Bitmaptexture em Real-World.
  - **A2:** objeto fora da seleção com o mesmo material.
  - **B:** cilindro poly com UV em cm gravado e Bitmaptexture 50×50.
  - **C:** Box poly girado com CoronaTriplanar de escala 75.
  - **D:** sem Real-World.
- **Blocos reais:**
  - **MESA LATERAL NAMBU:** Shape020 (metal, caso B), Shape021 (Triplanar), Shape025 (B e C juntos), Shape026 (sem material).
  - **POLTRONA MENTHA:** Box002 (17 mil triângulos, carpet), Shape018 (3 Triplanares), Cylinder003 (Triplanar compartilhado).

## Resultados

### 1. Ordem

| Combinação | Canal 1 | Canal 3 / Reverter do Auto UV |
|---|---|---|
| Auto UV → RWF atual | dividido certo | o `convertToMesh` grava o canal 3 na malha. O Reverter loga "Unwrap do Auto UV não encontrado", e a base vira Editable_mesh |
| RWF atual → Auto UV | dividido certo | o Reverter tira o Unwrap. O RWF fica (base mesh, bitmaps alterados) e só o Ctrl+Z desfaz |
| RWF sem colapso, qualquer ordem | dividido certo | stack `Editable_Poly [UVW Map > InLab RWF > InLab AutoUV]`. O Reverter tira só o Unwrap |

O canal 1 final é idêntico nas 4 combinações. Com o RWF depois do Auto UV, nos casos B e C o Xform/UVW Box fica acima do Unwrap. Por isso o RWF vai **antes**.

### 2. Qualidade do canal 3

Ilhas · aproveitamento · densidade · distorção · sobrepostas/invertidas.

| Peça | (a) base original | (b) depois do RWF atual (mesh) | (c) RWF sem colapso |
|---|---|---|---|
| Box002 (17k) | 6 · 80,9% · 1,00 · 1,07 · 0/0 | **8** · 80,8% · 1,00 · 1,07 · 0/0 | = (a) |
| Shape018 (5,9k) | 8 · 44,1% · 1,00 · 1,05 · 366/8 | **11** · 42,1% · **1,05** · **1,65** · 360/0 | = (a) |
| Cylinder003 | 12 · 36,3% · 1,00 · 1,00 | 12 · 35,7% | = (a) |
| Shape025 | 27,2% | 27,0% | 27,2% |
| NAMBU 020/021/026, primitivas | iguais | iguais | iguais |

- Isso confirma, em peça real, o achado da Fase 3 (2026-09-21): sobre Editable_mesh o flatten cria ilhas a mais e a distorção sobe.
- Sem colapso, o canal 3 sai bit a bit igual ao da base.
- As 366 sobrepostas da Shape018 já existem na base (é a #140).
- **Tempo:** RWF de 7 a 110 ms. O Auto UV leva o mesmo nas três condições: ~5,6 s nas primitivas, ~9,6 s no NAMBU e ~45 s no MENTHA.

### 3. Canal 1 sem colapso

- O canal 1 é **idêntico** ao do RWF colapsado em todos os objetos: 14 do NAMBU, 11 do MENTHA e 5 primitivas, inclusive a Shape019 com 73 mil triângulos.
- Batem as contagens de vértices e faces de mapa, e a diferença máxima por canto é 0,00 (tolerância 1e-4).
- **glTF** (export de A, B e C com glTFMaterial): TEXCOORD_0 e TEXCOORD_1 saem idênticos do stack vivo e do colapsado.

### 4. Reverter conjunto

Testado na prática. O canal 1 volta ao original e um dump recursivo dos materiais sai **idêntico** em todos os objetos. Precisa guardar, antes do RWF:

- **CoronaBitmap:** `realWorldScale`, `uvwScale`, `uvwOffset`.
- **Bitmaptexture:** `coords.realWorldScale`, `realWorldWidth/Height`, `U_Tiling/V_Tiling`, `U_Offset/V_Offset`.
- **Cada CoronaTriplanar:** os slots (dono + propriedade) que apontavam para ele, tirados de `refs.dependents` + `getPropNames`. A volta é `setProperty dono prop triplanar`. **Não** use `replaceInstances texmapX triplanar`: isso pega também os outros usos do bitmap.
- **No Reverter:** remover os modificadores "InLab RWF*" com `deleteModifier`. A base não muda.

O registro tem que ser **por rodada**, não por objeto: os bitmaps são compartilhados, e reverter um objeto obriga a reverter todos os que foram puxados com ele.

### 5. Objetos fora da seleção

O RWF puxa quem compartilha os mapas:
- **NAMBU:** 4 peças selecionadas puxaram +10 (9 de metal e a Shape019, de 73 mil triângulos).
- **MENTHA:** 3 peças selecionadas puxaram +8 (7 de carpet e a Cylinder004).

Os puxados precisam do RWF, porque sem ele a textura deles quebra quando o bitmap muda. Auto UV neles não é necessário: o canal 3 é por objeto. Fazer o Auto UV também nos puxados multiplicaria o tempo (~15 s por peça grande).

### 6. Sem Real-World

Em p_D e na Shape026, o RWF não toca em nada: não colapsa, e o stack e a base ficam iguais. O canal 3 sai igual ao da base.

## Recomendação

1. **O RWF roda antes do Unwrap,** dentro do `InLab_AutoUV`, só nos objetos que precisam dele.
2. **Sem `convertToMesh`.** Os modificadores "InLab RWF" ficam vivos no stack. A base continua poly, o canal 3 não piora e o canal 1 e o glTF saem iguais.
3. **Reverter conjunto.** O Desfazer UV passa a desfazer também o RWF da rodada (bitmaps, Triplanares por slot e modificadores), com um registro por rodada.
4. **Objetos puxados recebem só o RWF.** Eles entram no registro, e o log continua avisando.
5. **Instâncias:** deduplicar por instância (um modificador no stack compartilhado), em vez de `MakeObjectsUnique`, que só existia para colapsar.

Isso muda duas decisões antigas do RWF: "colapsa o stack inteiro em Editable_mesh" e "sem botão de reverter". As duas valiam com o RWF como botão próprio.

## Riscos e o que falta

- **Modificadores "InLab RWF" vivos:** o Clean UV não os remove, e está certo (canal 1). Falta conferir V-11, o ProOptimizer e colapsos posteriores (exportador, Converter).
- **Triplanar:** a captura de slots não cobre ArrayParameter (lista de Multi/Sub) nem o Material Editor.
- **Instância puxada sem deduplicação:** receberia um 2º Xform no stack compartilhado, com escala dupla. Isso é dedução, não medição.
- **Não testado:** render visual, caso A em arquivo real (nenhum .max aberto tinha UVW Map RW no stack, e ~15 arquivos do B&C/ARTEFACTO não abriram no 2024), Box014, undo da combinação e Auto UV duas vezes com o RWF.
- **Pegadinha do MCP:** um global definido por `fileIn` dentro de uma chamada não vale nessa mesma chamada, porque a chamada é compilada antes do `fileIn` rodar. Faça o `fileIn` numa chamada e use na seguinte.
