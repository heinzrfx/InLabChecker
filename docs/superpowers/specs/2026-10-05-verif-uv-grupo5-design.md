# Grupo 5 · Verificações de UV (V-14, V-15, V-16)

Issue #101, parte do epic #38. Desenho aprovado em 05/10/2026.

## 1. Objetivo

Ligar ao motor de verificação as três checagens de UV do grupo 5 da spec v2.0 (seção 5, "UV"), com critérios que façam sentido para o pipeline atual, que tem dois canais de UV. A spec funcional fica fora do repo, porque é um documento interno e o repo é público: v2.0 em `G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\Specs\plugin_spec_inlab_v2.pdf`; critérios da V-14 à V-16 na v1.0 (`...\SCRIPT GLB\plugin_spec_inlab.md`, seção 2.5). A V-29 e a V-39 (interior de peça animada) ficam para o v2.

Sucesso:
- as três verificações rodam pela UI e pelo motor, com teste;
- não travam o Max em peça grande;
- não deixam resto na cena: nem modificador, nem seleção trocada, nem painel trocado;
- não reprovam peça correta do piloto.

## 2. Contexto e sondagem (Max 2024, 05/10/2026)

**Dois canais de UV** (`functions/fn_autouv.ms`):
- **Canal 1** é o UV do material, em escala real. O Auto UV nunca mexe nele.
- **Canal 3** é o UV de 0–1 empacotado, para o bake de textura e AO.

A spec v1.0 foi escrita antes dessa divisão e manda checar sobreposição "no espaço 0–1" do canal 1.

**Piloto** (Aparador Zucchi, Puff Dorset, Poltrona Mentha, Mesa Lateral Nambu):
- Só existe o canal 1, porque o Auto UV ainda não foi aplicado.
- No canal 1, o UV é quase todo em escala real e repetido (u e v de −37 a +39 na Mentha). Sobrepõe de propósito: a V-15 literal reprovaria quase todas as peças.
- Três peças do Puff não têm UV nenhum, o que é defeito de verdade.
- Nenhuma textura do piloto existe neste computador.
- A cor base chega aos bitmaps por dentro de mapas aninhados (ColorCorrect, Mix, Multiply), e a varredura da cena também acha o HDR do ambiente.

**Sobreposição: medição atual contra Unwrap nativo**
- `InLab_MedirUV` (`verif_uv.ms`) levou 3,5 s em 16 mil triângulos e 17,7 s em 65 mil (cerca de 0,27 ms por triângulo).
- O `Unwrap_UVW` temporário com `selectOverlappedFaces` levou 0,8 s, 0,9 s e 1,3 s em 16, 65 e 262 mil triângulos. Achou as mesmas faces.

**Revisão de riscos do Unwrap temporário** (todos os casos com malha sobreposta, para o resultado provar a medição):
- UV limpo dá 0, e o Box com os 6 lados no mesmo 0–1 dá 12 de 12.
- Instância: mede, e o modificador sai das duas.
- Membro de grupo fechado: mede, sem deixar resto, mas a seleção vira o grupo inteiro.
- Peça oculta ou congelada: mede, e ela continua oculta ou congelada.
- Peça com Bend no stack: mede, e o Bend fica intacto.
- `getSaveRequired` não muda.
- **Seleção e painel do usuário mudam** (Create → Modify; Box → peça medida): é preciso restaurar.
- **No Editable Poly**, `getSelectedFaces` conta **polígonos** (Box poly deu 6 em vez de 12).
- **Peça sem canal 3:** `setMapChannel 3` não falha. O Unwrap monta um mapeamento padrão e acusa sobreposição (12 de 12). **Falso positivo:** a existência do canal tem que ser conferida antes.
- Tempo: cerca de 1 s por peça com redesenho; 0,37 s com `disableSceneRedraw` + `suspendEditing`, com o mesmo resultado e sem modificador sobrando.

## 3. Regras

| ID | Nome no relatório | Critério | Severidade |
|---|---|---|---|
| V-14 | UV presente (canal 1) | Toda peça tem o canal 1, com UV que não está colapsado num ponto: o bbox dos vértices de mapa tem largura e altura > 1e-6. UV fora do 0–1 é aceito (escala real). | Crítica |
| V-15 | UV de bake sem sobreposição (canal 3) | Nas peças que têm o canal 3: nenhuma face sobreposta (`selectOverlappedFaces`) e nenhum vértice de mapa fora do 0–1 (tolerância 1e-4). Peça sem canal 3: "não se aplica". | Crítica |
| V-16 | Resolução das texturas (≥ 2048) | Todo bitmap usado pelos materiais das peças verificadas tem o menor lado ≥ 2048 px. | Advertência |

Mensagens: no máximo 8 itens e depois "(+N)". "Não medido" = `passou:false critico:false` (vira `#warning`), como no resto do motor.

### 3.1 V-14

Para cada peça do universo (`InLab_ObjetosVerificacao`), uma vez por grupo de instâncias:
1. `snapshotAsMesh`.
2. Canal 1 existe? Usar `InLab_UV_TemCanal m 1` (`verif_uv.ms`, que confere o intervalo antes de `meshop.getMapSupport`).
3. Se existe, varrer os vértices do canal (não as faces) para o bbox.
4. Apagar a malha.

Mensagem de falha: `Box244448649: sem UV no canal 1` ou `Peca: UV colapsado num ponto`. Falha de leitura vira "não analisado" (não medido), com `InLab_Log`.

### 3.2 V-15

Para cada grupo de instâncias:
1. **Confere o canal 3 antes de tudo**, no `snapshotAsMesh` (`InLab_UV_TemCanal m 3`). Sem o canal, a peça entra na lista "não se aplica" e o Unwrap **não** é usado. Isso evita o falso positivo da seção 2.
2. **Fora do 0–1:** varre os vértices do canal 3 do snapshot e conta os que saem de [−1e-4, 1+1e-4] em u ou v.
3. **Sobreposição** com o Unwrap temporário:
   - antes de qualquer peça: guarda a seleção e o modo do painel, `disableSceneRedraw()`, `suspendEditing()`;
   - por peça, com `undo off`:
     - abre os grupos acima do nó (`InLab_AbrirGruposAcima`, em `fn_autouv.ms`);
     - `addModifier o uw`, `select o`, `max modify mode`, `modPanel.setCurrentObject uw`;
     - `uw.setMapChannel 3`, `uw.selectOverlappedFaces()`;
     - `n = (uw.getSelectedFaces()).numberSet`;
   - remove o `uw` **sempre**, inclusive depois de exceção (o `try` da medição é separado do `try` da remoção), e fecha os grupos de novo (`InLab_FecharGrupos`);
   - no fim, mesmo com exceção: `resumeEditing()`, `enableSceneRedraw()`, restaura a seleção e o modo do painel.
4. Exceção na medição: a peça vira "não medida" na mensagem e o log diz qual chamada falhou. É o padrão de API que muda entre versões do Max.

Mensagem: `Peca: 24 face(s) sobreposta(s) no canal 3`. São faces, não triângulos: no Editable Poly, `getSelectedFaces` conta polígonos. Também `Peca: 3 vértice(s) de UV fora do 0–1 no canal 3`. Quando passa, cita quantas peças tinham canal 3 e quantas ficaram "não se aplica". Se nenhuma peça tem canal 3: `#pass` com "não se aplica: nenhuma peça com UV de bake (canal 3)".

### 3.3 V-16

Usa `InLab_CheckTexture escopo:#selecao objs:objetos` (`functions/fn_checktexture.ms`), que já pega Bitmaptexture e CoronaBitmap, desce pelos mapas aninhados e deixa de fora o HDR do ambiente, porque o mapa precisa ser usado por uma das peças.

A função ganha um parâmetro `logar:true`. A V-16 chama com `logar:false` para não despejar o inventário inteiro no log da verificação.

Para cada textura:
- existe e o menor lado < 2048: entra na lista de baixa resolução, `nome.jpg: 1024x1024`;
- não existe no disco ou não deu para ler a resolução: entra na lista de "não medidas".

Resultado:
- nada abaixo de 2048 e nada sem medir: `#pass`, com o número de texturas;
- caso contrário: `#warning`, listando os dois grupos.

Peça sem textura nenhuma: `#pass` com "nenhuma textura nas peças".

## 4. Estrutura

- **`verifications/verif_mapeamento.ms` (novo)**, no manifesto depois de `verif_uv.ms`.
  - Depende de `verif_uv.ms` (`InLab_UV_TemCanal`), `fn_checktexture.ms` (`InLab_CheckTexture`), `fn_autouv.ms` (`InLab_AbrirGruposAcima`, `InLab_FecharGrupos`) e `core/utils.ms` (`InLab_DeduplicarInstancias`).
  - Funções: `InLab_V14_UVPresente objetos`, `InLab_V15_UVBake objetos`, `InLab_V16_ResolucaoTexturas objetos`, mais os auxiliares:
    - `InLab_Mapa_SobrepostasUnwrap o` → número de faces, ou `undefined` com o erro no log;
    - `InLab_Mapa_ForaDe01 m canal` → contagem;
    - `InLab_Mapa_Lista itens maximo:8`.
- **`functions/fn_checktexture.ms`:** parâmetro `logar:true` em `InLab_CheckTexture`. Com `false`, não loga o relatório; o retorno não muda.
- **`verifications/verif_orquestrador.ms`:** bloco "Grupo 5 · UV" depois do grupo 3, chamando V-14, V-15 e V-16. O aviso de relatório parcial deixa de citar o grupo 5, e o cabeçalho de status marca o grupo 5 como entregue. Se o PR #107 (grupo 6) entrar antes, o grupo 5 fica **antes** do grupo 6, seguindo a ordem da spec v2.0.
- **`core/struct_result.ms`:** a V-16 entra na lista de não críticas do cabeçalho.
- **Testes que carregam o orquestrador** (`test_verificacoes.ms`, `test_familia_ativa.ms`, `test_posicao_painel.ms`): incluir `fn_checktexture.ms`, `fn_autouv.ms` e `verif_uv.ms` se ainda não estiverem, e `verif_mapeamento.ms`.

## 5. Testes

`tests/test_verif_mapeamento.ms`, no padrão dos outros testes (logger no arquivo de saída, cena criada e apagada). Escritos antes do código.

| Caso | Espera |
|---|---|
| Box com `mapcoords:true` | V-14 passa |
| Box convertido para Mesh com o canal 1 removido (`meshop.setMapSupport m 1 false`) | V-14 `#fail` com "sem UV no canal 1" |
| Box com todos os vértices do canal 1 no mesmo ponto | V-14 `#fail` com "colapsado" |
| UV do canal 1 fora do 0–1 (escala real) | V-14 passa |
| Peça sem canal 3 | V-15 `#pass` com "não se aplica"; **o Unwrap não é chamado** (nenhum falso positivo) |
| Plano com o canal 3 limpo (cópia do canal 1 de um Plane) | V-15 passa |
| Box com o canal 3 = canal 1 (6 lados no mesmo 0–1) | V-15 `#fail` com "sobreposta" |
| Canal 3 com um vértice em u = 1,3 | V-15 `#fail` com "fora do 0–1" |
| Membro de grupo fechado com canal 3 sobreposto | V-15 `#fail`, sem modificador sobrando, grupo fechado de novo |
| Instâncias | uma medição, sem modificador sobrando em nenhuma |
| Seleção e painel antes / depois | iguais (ex.: seleção = um Box qualquer, painel Create) |
| Exceção simulada na medição | V-15 "não medido", sem modificador sobrando |
| Material com bitmap 1024² (gerado no teste com `bitmap 1024 1024`, salvo em `getDir #temp`) | V-16 `#warning` com "1024x1024" |
| Material com bitmap 2048² | V-16 passa |
| Bitmap com arquivo inexistente | V-16 `#warning` com "não medida" |
| Peça sem material | V-16 passa com "nenhuma textura" |

Também: rodada completa do motor com V-14, V-15 e V-16 presentes (`test_verificacoes.ms`); a suíte inteira no Max; e o piloto (Aparador, Puff, Mentha, Nambu), conferindo:
- V-14 reprova só o Puff, nas 3 peças sem UV;
- V-15 sai "não se aplica";
- V-16 avisa as texturas "não medidas", porque nenhuma existe neste computador.

## 6. Fora do escopo

- V-29 e V-39 (interior de animados): v2.
- Outras classes de bitmap (VRayBitmap, OSL): o inventário atual não as cobre.
- Densidade de texel, distorção, gutter e aproveitamento: `InLab_MedirUV` mede, mas a spec não pede.
- Exigir o canal 3 em toda peça: decisão de 05/10/2026, ele é opcional no v1.
- Corrigir: as verificações só apontam.
