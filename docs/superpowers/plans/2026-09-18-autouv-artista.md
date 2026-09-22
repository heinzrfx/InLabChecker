# AutoUV de artista (issue #1): plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIA: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa por tarefa. Os passos usam checkbox (`- [ ]`) para acompanhamento.

**Objetivo:** substituir o pipeline do Auto UV por um que grava um 0–1 empacotado por objeto no **canal 3** (bake de textura e AO), sem tocar no canal 1. O ângulo de flatten passa a ser controlável e as seams vão para as regiões ocultas. A meta é igualar o ArchToolz 2026 onde ele acerta e superá-lo onde erra.

**Arquitetura:** a medição de UV fica num módulo só de leitura (`verifications/verif_uv.ms`), testado com UVs montados à mão. Todas as fases seguintes medem com ele. O Auto UV (`functions/fn_autouv.ms`) passa a trabalhar no canal 3 sobre uma base `Editable_mesh`, com o `Unwrap_UVW` vivo no stack, e guarda a base original para o Reverter. A UI só lê os controles e chama `InLab_AutoUV`.

**Stack técnica:** MaxScript (3ds Max 2024 principal, 2027 secundário), `meshop` sobre `snapshotAsMesh` para medir e `Unwrap_UVW` para gerar.

**Spec:** issue #1 do GitHub (`gh issue view 1`), "feat(autouv): AutoUV com controle de ângulo flatten e abertura de artista (ref. ArchToolz 2026)". Leia a issue inteira antes de começar. Ela tem a tabela de referência do ArchToolz, as decisões confirmadas e os critérios de aceite.

## Restrições globais

- O código só roda dentro do 3ds Max. Rode tudo pelo MCP do 3ds Max (`execute_maxscript`). **Se o MCP não estiver conectado, pare e avise.** Nenhuma tarefa conta como validada sem o arquivo de resultado do teste lido.
- Rodar um teste: `resetMaxFile #noPrompt` e depois `fileIn @"G:\Meu Drive\GitHub\InLabChecker\tests\test_<nome>.ms"`. O resultado sai em `(getDir #temp) + "\inlab_test_<nome>.txt"`.
- **Canal 1 nunca muda.** Vale para qualquer objeto e qualquer função (Auto UV, Clean UV, Reverter).
- Não desagrupe nem reparenteie objetos. Não colapse o stack.
- Não edite `01.max` / `02.max` em `G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\archtoolztest\`. Copie para `(getDir #temp) + "\inlab_autouv\"` e abra só as cópias.
- Toda fn chamada de fora do próprio arquivo leva `global <Nome>` antes da definição. Um global usado antes do arquivo que o define é pré-declarado no topo de quem usa.
- APIs do `Unwrap_UVW` que variam por build: cadeia de `try/catch`, e o log diz qual variante rodou. Nunca engula um erro sem `InLab_Log`.
- Log só via `InLab_Log msg tipo:#info|#ok|#warn|#err`. Comentários, log e UI em português.
- Operações na cena dentro de `undo "InLab ..." on ( ... )`.
- Commits em português, sem acento no assunto, `feat(autouv): ...` / `fix(autouv): ...`. **Commit, push, PR e comentário na issue só com autorização explícita do usuário.**
- Fora de escopo: atlas compartilhado entre objetos, presets por tipo de peça, o bake em si.

## Pré-requisito: branch

A branch atual `feat/renomear-produto` tem `ui/rollout_main.ms` modificado e não commitado (UI da seção Produto) e o arquivo não rastreado `InLabCheckervs.ms`. A Fase 2 também edita `ui/rollout_main.ms`. Antes da Tarefa 1, o usuário decide: fechar e mergear `feat/renomear-produto` em `main` e criar `feat/autouv-artista` a partir de `main` (recomendado, como a issue pede), ou criar `feat/autouv-artista` a partir de `feat/renomear-produto`. **Não comece sem essa decisão.**

## Estrutura de arquivos

| Arquivo | Ação | Responsabilidade |
|---|---|---|
| `verifications/verif_uv.ms` | criar (Fase 1) | medição de UV por objeto e canal, assinatura do canal, texto para o log |
| `tests/test_verif_uv.ms` | criar (Fase 1) | teste do helper com UVs de valores conhecidos |
| `InLabChecker.ms:295-299` | modificar (Fase 1) | incluir `verif_uv.ms` no manifesto |
| `functions/fn_autouv.ms` | reescrever (Fase 2) | canais 1/3, base `Editable_mesh`, pipeline provisório, Clean UV do canal 3, Reverter com base |
| `tests/test_autouv.ms` | criar (Fase 2) | teste de canais, stack, grupo, Clean UV e Reverter |
| `ui/rollout_main.ms:196-199, 244-258` | modificar (Fase 2) | ângulo, seams ocultas, resolução e botão Reverter |
| `docs/superpowers/specs/2026-09-18-autouv-fase0-apis.md` | criar (Fase 0) | tabela de APIs e respostas da investigação |
| `docs/superpowers/plans/2026-09-18-autouv-artista.md` | atualizar (fim da Fase 0) | detalhar as Fases 3 a 5 com as APIs confirmadas |
| `docs/superpowers/specs/2026-09-21-autouv-fase3-sondagem.md` | criar (Fase 3) | sequência do solver com seams e tempos |

## Por que as Fases 3 a 5 ainda não estão detalhadas

As seams por ângulo, o straighten, o rescale e o pack com opções dependem de APIs do `Unwrap_UVW` que ainda não foram confirmadas nesta build. Isso é exatamente o que a Fase 0 levanta. Escrever o código dessas fases agora seria chutar assinaturas. Por isso este plano detalha as Fases 0 a 2 e, para as Fases 3 a 5, fixa escopo, entregáveis e critérios de saída. A última tarefa da Fase 0 é reescrever essa parte com código real.

---

### Tarefa 1 (Fase 0): investigação das APIs, sem código de produção

**Arquivos:**
- Criar: `docs/superpowers/specs/2026-09-18-autouv-fase0-apis.md`

**Interfaces:**
- Consome: nada.
- Produz: as respostas abaixo, que as Tarefas 2 a 4 e o plano das Fases 3 a 5 usam. Em especial: (a) `node.baseObject = <cópia>` funciona? (b) `setMapChannel 3` abre diálogo modal? (c) `getMapChannel()` devolve 3 depois de `setMapChannel 3`? (d) qual propriedade de canal o `UVW_Mapping_Clear` usa?

- [x] **Passo 1: despejar a API do `Unwrap_UVW` e do `UVW_Mapping_Clear` num arquivo**

Rode pelo MCP numa cena vazia:

```maxscript
resetMaxFile #noPrompt
(
    local arq = (getDir #temp) + "\\inlab_unwrap_api_" + ((maxVersion())[1] as string) + ".txt"
    local f = createFile arq encoding:#utf8
    local b = Box()
    select b
    max modify mode
    local uvw = Unwrap_UVW()
    modPanel.addModToSelection uvw
    modPanel.setCurrentObject uvw
    format "=== showInterfaces Unwrap_UVW ===\n" to:f
    showInterfaces uvw to:f
    format "\n=== showProperties Unwrap_UVW ===\n" to:f
    showProperties uvw to:f
    format "\n=== showProperties UVW_Mapping_Clear ===\n" to:f
    try ( showProperties (UVW_Mapping_Clear()) to:f ) catch ( format "UVW_Mapping_Clear indisponível: %\n" (getCurrentException()) to:f )
    close f
    delete b
    arq
)
```

Esperado: o caminho do arquivo. Leia o arquivo e filtre as linhas relevantes:

```bash
grep -inE "seam|angle|straighten|rescale|rotate|align|pack|relax|unfold3d|texel|density|overlap|peel|flatten|mapchannel|channel" "<arquivo devolvido>"
```

- [x] **Passo 2: responder às quatro perguntas de comportamento**

```maxscript
resetMaxFile #noPrompt
(
    local r = #()
    -- (a) base settável?
    local b = Box()
    convertToPoly b
    local copia = copy b.baseObject
    convertToMesh b
    local okBase = try ( b.baseObject = copia ; classOf b.baseObject == Editable_Poly ) catch ( getCurrentException() )
    append r ("baseObject settável: " + okBase as string)
    -- (b) + (c) canal 3 sem diálogo e getMapChannel
    select b
    max modify mode
    local uvw = Unwrap_UVW()
    modPanel.addModToSelection uvw
    modPanel.setCurrentObject uvw
    uvw.setMapChannel 3
    append r ("getMapChannel após setMapChannel 3: " + (uvw.getMapChannel()) as string)
    -- (d) propriedade de canal do UVW_Mapping_Clear
    local clr = try ( UVW_Mapping_Clear() ) catch ( undefined )
    if clr != undefined do
        for p in #(#mapChannel, #channel, #mapID) do append r ("UVW_Mapping_Clear." + p as string + ": " + (isProperty clr p) as string)
    delete b
    r
)
```

Esperado: um array de textos. Se a chamada do MCP travar, é porque o `setMapChannel` abriu um diálogo modal. Nesse caso anote, feche o diálogo à mão (peça ao usuário) e procure uma alternativa (propriedade de canal no `showProperties` do passo 1).

- [x] **Passo 3: identificar `unfoldMethod = 46000`**

Copie os arquivos de teste e inspecione o `Unwrap_UVW` que o ArchToolz deixou:

```bash
mkdir -p "$TEMP/inlab_autouv" && cp "G:/Meu Drive/Trabalhos/2026/Artefacto/InlabChecker/archtoolztest/0"{1,2}.max "$TEMP/inlab_autouv/"
```

```maxscript
(
    loadMaxFile ((getDir #temp) + "\\inlab_autouv\\02.max") quiet:true
    local o = getNodeByName "Box013"
    local u = undefined
    for md in o.modifiers where isKindOf md Unwrap_UVW do u = md
    local r = #()
    for p in getPropNames u where matchPattern (p as string) pattern:"unfold*" do
        append r (p as string + " = " + (getProperty u p) as string)
    r
)
```

Depois, com o modificador na tela do Modify, troque `u.unfoldMethod` para os valores oferecidos pela UI do Unfold3D (mude o dropdown do solver na UI e releia a propriedade depois de cada troca) para mapear número → nome. Consulte também a documentação do Max 2024 (`mcp__plugin_context7_context7__query-docs` ou WebSearch "Unwrap_UVW unfoldMethod"). **Se não for possível identificar o solver, pare e pergunte ao usuário**, como a issue manda.

- [x] **Passo 4: repetir os passos 1 e 2 no Max 2027, se estiver instalado**

Use `mcp__3dsmax-mcp__list_max_instances` para ver se há uma instância 2027. Se não houver, marque a coluna 2027 como "não verificado" na tabela.

- [x] **Passo 5: escrever o documento da Fase 0**

`docs/superpowers/specs/2026-09-18-autouv-fase0-apis.md` com:

```markdown
# AutoUV de artista: Fase 0, APIs do Unwrap_UVW

Build: 3ds Max <versão exata de maxVersion()>. Data: <data>.

## Comportamento

| Pergunta | 2024 | 2027 |
|---|---|---|
| `node.baseObject = copia` restaura a base | | |
| `setMapChannel 3` sem diálogo modal | | |
| `getMapChannel()` devolve 3 | | |
| Propriedade de canal do `UVW_Mapping_Clear` | | |
| `unfoldMethod = 46000` é | | |

## APIs

| Necessidade | Método/propriedade | Assinatura (do showInterfaces) | 2024 | 2027 |
|---|---|---|---|---|
| Seams por ângulo | | | | |
| Seams por aresta selecionada (edge loops) | | | | |
| Selecionar arestas por ângulo / loop | | | | |
| Unfold conforme (Unfold3D / LSCM / peel) | | | | |
| Relax | | | | |
| Straighten de ilha | | | | |
| Rescale (densidade uniforme) | | | | |
| Rotação de ilha (0°/90°, alinhar ao eixo) | | | | |
| Pack com padding, sem rescale, sem rotação livre | | | | |
| Seleção de faces sobrepostas | | | | |
| Leitura de distorção/texel density | | | | |
```

Preencha só com o que foi visto no arquivo do passo 1. Linha sem API = "não existe", sem palpite.

- [x] **Passo 6: pedir autorização e publicar**

Mostre a tabela ao usuário. Com autorização, commit (`docs(autouv): registra investigacao da API do Unwrap_UVW (fase 0)`) e comentário na issue: `gh issue comment 1 --body-file docs/superpowers/specs/2026-09-18-autouv-fase0-apis.md`.

---

### Tarefa 2 (Fase 1): helper de medição `verif_uv.ms` e teste

**Arquivos:**
- Criar: `verifications/verif_uv.ms`
- Criar: `tests/test_verif_uv.ms`
- Modificar: `InLabChecker.ms:295-299` (manifesto)

**Interfaces:**
- Consome: `InLab_Log`.
- Produz (todas `global`):
  - `struct UVMetricas` com `canal`, `nFaces`, `nIlhas`, `aproveitamento` (fração do 0–1, 0,18 = 18%), `densidadeRazao` (densidade linear máx/mín entre ilhas), `densidadeRazaoArea` (a mesma razão em área, que é o quadrado da linear), `distorcaoMax` (≥ 1,0), `foraDe01` (nº de vértices de mapa), `sobrepostas` (nº de faces), `invertidos` (nº de faces), `espelhado` (bool), `gutterMin` (UV, `undefined` com uma ilha só, limitado a `INLAB_UV_GUTTER_BUSCA`), `bordaMin` (UV, negativo se houver UV fora).
  - `InLab_MedirUV obj canal` → `UVMetricas`, ou `undefined` (com `#warn` no log) se o canal não existir.
  - `InLab_AssinaturaCanal obj canal` → String com o UV de cada canto de face (5 casas), ou `undefined` se o canal não existir. Dois estados são iguais se e só se as strings forem iguais.
  - `InLab_UVMetricasTexto met` → uma linha para o log.
  - `INLAB_UV_GUTTER_BUSCA = 0.02`: raio de busca do gutter. Acima disso o texto mostra "≥0.020".

- [x] **Passo 1: escrever o teste `tests/test_verif_uv.ms`**

```maxscript
/*
 tests\test_verif_uv.ms — teste automático de verifications\verif_uv.ms
 RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt): cria malhas com UV no canal 3
 montado à mão (valores conhecidos) e apaga tudo no final.
 Resultado: <pasta temp do Max>\inlab_test_verif_uv.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_MedirUV, InLab_AssinaturaCanal, InLab_UVMetricasTexto
global INLAB_UV_GUTTER_BUSCA
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_verif_uv.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn perto a b = ( a != undefined and abs (a - b) <= 0.001 )

    -- 4 UVs de um quadrado (x0,y0) de lado "lado", no sentido anti-horário
    fn quadUV x0 y0 lado = #([x0, y0, 0], [x0 + lado, y0, 0], [x0 + lado, y0 + lado, 0], [x0, y0 + lado, 0])
    -- o mesmo quadrado espelhado em U: inverte o sentido das faces no UV
    fn quadUVEspelhado x0 y0 lado = #([x0 + lado, y0, 0], [x0, y0, 0], [x0, y0 + lado, 0], [x0 + lado, y0 + lado, 0])

    -- Uma malha com um quadrado 10×10 cm (2 triângulos) por item de "quads",
    -- lado a lado em X. Cada item traz os 4 UVs do quadrado no canal 3.
    fn criarMalha quads =
    (
        local verts = #(), fcs = #()
        for i = 1 to quads.count do
        (
            local x = 20.0 * (i - 1)
            join verts #([x, 0, 0], [x + 10, 0, 0], [x + 10, 10, 0], [x, 10, 0])
            local b = 4 * (i - 1)
            join fcs #([b + 1, b + 2, b + 3], [b + 1, b + 3, b + 4])
        )
        local o = mesh vertices:verts faces:fcs
        meshop.setMapSupport o 3 true
        meshop.setNumMapVerts o 3 verts.count
        meshop.setNumMapFaces o 3 fcs.count
        for i = 1 to quads.count do
            for k = 1 to 4 do meshop.setMapVert o 3 (4 * (i - 1) + k) quads[i][k]
        for f = 1 to fcs.count do meshop.setMapFace o 3 f fcs[f]
        update o
        o
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    local criados = #()

    try
    (
        fileIn (raiz + @"verifications\verif_uv.ms")

        -- 1. CASO BASE: duas ilhas iguais separadas por 0,1
        local o = criarMalha #(quadUV 0.1 0.1 0.3, quadUV 0.5 0.1 0.3)
        append criados o
        local m = InLab_MedirUV o 3
        linha ("      " + InLab_UVMetricasTexto m)
        checar "Base: 4 faces" (m.nFaces == 4)
        checar "Base: 2 ilhas" (m.nIlhas == 2)
        checar "Base: aproveitamento 18%" (perto m.aproveitamento 0.18)
        checar "Base: densidade 1,00×" (perto m.densidadeRazao 1.0)
        checar "Base: densidade de área 1,00×" (perto m.densidadeRazaoArea 1.0)
        checar "Base: distorção 1,00×" (perto m.distorcaoMax 1.0)
        checar "Base: nada fora do 0–1" (m.foraDe01 == 0)
        checar "Base: 0 sobrepostas" (m.sobrepostas == 0)
        checar "Base: 0 invertidos" (m.invertidos == 0)
        checar "Base: não espelhado" (not m.espelhado)
        checar "Base: gutter no limite de busca" (perto m.gutterMin INLAB_UV_GUTTER_BUSCA)
        checar "Base: borda 0,1" (perto m.bordaMin 0.1)

        -- 2. GUTTER PEQUENO: 0,01 entre as ilhas
        o = criarMalha #(quadUV 0.1 0.1 0.3, quadUV 0.41 0.1 0.3)
        append criados o
        m = InLab_MedirUV o 3
        checar "Gutter 0,01" (perto m.gutterMin 0.01)

        -- 3. DENSIDADE: mesma área 3D, ilha B com metade do lado
        o = criarMalha #(quadUV 0.1 0.1 0.3, quadUV 0.5 0.1 0.15)
        append criados o
        m = InLab_MedirUV o 3
        checar "Densidade linear 2,00×" (perto m.densidadeRazao 2.0)
        checar "Densidade de área 4,00×" (perto m.densidadeRazaoArea 4.0)

        -- 4. SOBREPOSIÇÃO: ilha B invade 0,1 da ilha A
        o = criarMalha #(quadUV 0.1 0.1 0.3, quadUV 0.3 0.1 0.3)
        append criados o
        m = InLab_MedirUV o 3
        checar "Sobreposição: 4 faces" (m.sobrepostas == 4)
        checar "Sobreposição: gutter 0" (perto m.gutterMin 0.0)

        -- 5. INVERTIDOS: ilha B espelhada no UV
        o = criarMalha #(quadUV 0.1 0.1 0.3, quadUVEspelhado 0.5 0.1 0.3)
        append criados o
        m = InLab_MedirUV o 3
        checar "Invertidos: 2 faces" (m.invertidos == 2)
        checar "Invertidos: 0 sobrepostas" (m.sobrepostas == 0)

        -- 6. FORA DO 0–1: ilha B vai até u = 1,2
        o = criarMalha #(quadUV 0.1 0.1 0.3, quadUV 0.9 0.1 0.3)
        append criados o
        m = InLab_MedirUV o 3
        checar "Fora do 0–1: 2 vértices" (m.foraDe01 == 2)
        checar "Fora do 0–1: borda -0,2" (perto m.bordaMin (-0.2))

        -- 7. DISTORÇÃO: um quadrado, uma face com o dobro da área UV da outra
        o = criarMalha #(#([0.1, 0.1, 0], [0.4, 0.1, 0], [0.4, 0.4, 0], [0.1, 0.7, 0]))
        append criados o
        m = InLab_MedirUV o 3
        checar "Distorção: 1 ilha" (m.nIlhas == 1)
        checar "Distorção máx 1,50×" (perto m.distorcaoMax 1.5)
        checar "Uma ilha: gutter indefinido" (m.gutterMin == undefined)

        -- 8. ESPELHADO, CANAL INEXISTENTE E ASSINATURA
        o.scale = [-1, 1, 1]
        checar "Espelhado detectado" ((InLab_MedirUV o 3).espelhado)
        checar "Canal inexistente devolve undefined" ((InLab_MedirUV o 5) == undefined)
        local s1 = InLab_AssinaturaCanal o 3
        checar "Assinatura estável" (s1 != undefined and s1 == (InLab_AssinaturaCanal o 3))
        meshop.setMapVert o 3 1 [0.2, 0.1, 0]
        update o
        checar "Assinatura muda com o UV" (s1 != (InLab_AssinaturaCanal o 3))
        checar "Assinatura de canal inexistente = undefined" ((InLab_AssinaturaCanal o 5) == undefined)

        -- 9. DESEMPENHO: ~15 mil faces (tamanho do Box008) no canal 1
        local esf = Sphere segs:124 mapcoords:true
        append criados esf
        local t0 = timeStamp()
        m = InLab_MedirUV esf 1
        local ms = timeStamp() - t0
        linha ("      esfera: " + m.nFaces as string + " faces em " + ms as string + " ms · " + InLab_UVMetricasTexto m)
        checar "Desempenho: 15 mil faces em menos de 30 s" (m.nFaces > 14000 and ms < 30000)
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    for o in criados where isValidNode o do delete o
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
```

Conta dos valores esperados: no caso base, cada ilha tem 0,3 × 0,3 = 0,09 de área UV e as duas somam 0,18. No caso 7, a face 1 tem área UV 0,045 e a face 2 tem 0,09, com a mesma área 3D (50 cm²). Então r = 0,667 e 1,333 contra a média da ilha, e o pior é 1/0,667 = 1,5.

- [x] **Passo 2: rodar e ver falhar**

Pelo MCP: `resetMaxFile #noPrompt` e depois `fileIn @"G:\Meu Drive\GitHub\InLabChecker\tests\test_verif_uv.ms"`. Leia `(getDir #temp) + "\inlab_test_verif_uv.txt"`.
Esperado: `EXCEÇÃO:` (o `fileIn` de `verif_uv.ms` falha porque o arquivo não existe) e `1 FALHA(S)`.

- [x] **Passo 3: escrever `verifications/verif_uv.ms`**

```maxscript
/*
================================================================================
 verifications\verif_uv.ms — medição de UV por objeto e canal (18/Set · issue #1)
--------------------------------------------------------------------------------
 Só leitura: tira um snapshotAsMesh do objeto (stack avaliado, espaço do
 mundo) e mede o canal pedido. Não registra verificação V-xx: é o helper que
 o Auto UV usa no log e que as fases da issue #1 usam para comparar com o
 ArchToolz 2026.

   nIlhas             componentes conexos pelos vértices de mapa (union-find)
   aproveitamento     soma da área UV das faces / área do 0–1. Sobreposição
                      conta duas vezes, por isso "sobrepostas" vem junto.
   densidadeRazao     densidade LINEAR, sqrt(áreaUV/área3D), da ilha mais
                      densa sobre a menos densa. densidadeRazaoArea = a mesma
                      razão em área (= densidadeRazao²).
   distorcaoMax       pior face: max(r, 1/r), r = densidade de área da face
                      sobre a densidade de área da ilha dela
   foraDe01           vértices de mapa usados fora de [0,1]
   sobrepostas        faces que cruzam outra face (grade + eixo separador);
                      faces vizinhas que só encostam numa aresta não contam
   invertidos         faces com área UV negativa (sentido horário)
   espelhado          transform com determinante negativo: aí a inversão é
                      esperada e deve ser reportada, não corrigida
   gutterMin          menor distância entre arestas de borda de ilhas
                      diferentes, procurada até INLAB_UV_GUTTER_BUSCA (acima
                      disso fica no limite). 0 se ilhas diferentes se cruzam.
                      undefined com uma ilha só.
   bordaMin           menor distância de um UV usado até a borda do 0–1
                      (negativa se houver UV fora)
================================================================================
*/

global INLAB_UV_EPS = 1e-6
global INLAB_UV_TOL_SOBREPOSICAO = 1e-5
global INLAB_UV_GUTTER_BUSCA = 0.02
global INLAB_UV_GRADE_SOBREPOSICAO = 64

struct UVMetricas
(
    canal,
    nFaces = 0,
    nIlhas = 0,
    aproveitamento = 0.0,
    densidadeRazao = 1.0,
    densidadeRazaoArea = 1.0,
    distorcaoMax = 1.0,
    foraDe01 = 0,
    sobrepostas = 0,
    invertidos = 0,
    espelhado = false,
    gutterMin = undefined,
    bordaMin = undefined
)

global InLab_UV_Raiz, InLab_UV_Unir, InLab_UV_AreaSinal, InLab_UV_TriSobrepoe
global InLab_UV_DistPontoSeg, InLab_UV_Celula
global InLab_MedirUV, InLab_AssinaturaCanal, InLab_UVMetricasTexto

-- Union-find com compressão de caminho. "pai" é alterado no lugar.
fn InLab_UV_Raiz pai i =
(
    while pai[i] != i do
    (
        pai[i] = pai[pai[i]]
        i = pai[i]
    )
    i
)

fn InLab_UV_Unir pai a b =
(
    local ra = InLab_UV_Raiz pai a
    local rb = InLab_UV_Raiz pai b
    if ra != rb do pai[rb] = ra
)

-- Área com sinal do triângulo no UV: positiva no sentido anti-horário.
fn InLab_UV_AreaSinal a b c = ((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2.0

-- Teste do eixo separador entre dois triângulos 2D (arrays de 3 Point3 com
-- z = 0). Encostar numa aresta, como faces vizinhas fazem, não conta.
fn InLab_UV_TriSobrepoe t1 t2 =
(
    local separados = false
    for t in #(t1, t2) while not separados do
        for k = 1 to 3 while not separados do
        (
            local p = t[k]
            local q = t[if k == 3 then 1 else k + 1]
            local eixo = [p.y - q.y, q.x - p.x, 0]
            local tam = length eixo
            if tam > INLAB_UV_EPS do
            (
                eixo = eixo / tam
                local mn1 = 1e30, mx1 = -1e30, mn2 = 1e30, mx2 = -1e30
                for v in t1 do ( local d = dot v eixo ; if d < mn1 do mn1 = d ; if d > mx1 do mx1 = d )
                for v in t2 do ( local d = dot v eixo ; if d < mn2 do mn2 = d ; if d > mx2 do mx2 = d )
                if ((amin mx1 mx2) - (amax mn1 mn2)) <= INLAB_UV_TOL_SOBREPOSICAO do separados = true
            )
        )
    not separados
)

fn InLab_UV_DistPontoSeg p a b =
(
    local ab = b - a
    local l2 = dot ab ab
    local t = if l2 < 1e-12 then 0.0 else (dot (p - a) ab) / l2
    t = amax 0.0 (amin 1.0 t)
    distance p (a + ab * t)
)

-- Índice (1..n) da célula de x numa grade de n células a partir de "mn",
-- cada uma com largura "tam".
fn InLab_UV_Celula x mn tam n = amax 1 (amin n ((floor ((x - mn) / tam)) as integer + 1))

fn InLab_MedirUV obj canal =
(
    local m = snapshotAsMesh obj
    local res = undefined
    if not (meshop.getMapSupport m canal) then
        InLab_Log (obj.name + ": canal " + canal as string + " inexistente — sem medição.") tipo:#warn
    else
    (
        res = UVMetricas canal:canal
        local nF = m.numfaces
        local nV = meshop.getNumMapVerts m canal
        local tm = obj.transform
        res.nFaces = nF
        res.espelhado = (dot (cross tm.row1 tm.row2) tm.row3) < 0

        -- UVs em 2D (a 3ª coordenada do canal é ignorada) e cantos por face
        local uv = for v = 1 to nV collect ( local p = meshop.getMapVert m canal v ; [p.x, p.y, 0] )
        local cantos = for f = 1 to nF collect ( local c = meshop.getMapFace m canal f ; #(c.x as integer, c.y as integer, c.z as integer) )

        -- 1. ILHAS
        local pai = for v = 1 to nV collect v
        for c in cantos do
        (
            InLab_UV_Unir pai c[1] c[2]
            InLab_UV_Unir pai c[1] c[3]
        )
        local ilhaDaRaiz = for v = 1 to nV collect 0
        local ilhaFace = for c in cantos collect
        (
            local r = InLab_UV_Raiz pai c[1]
            if ilhaDaRaiz[r] == 0 do ( res.nIlhas += 1 ; ilhaDaRaiz[r] = res.nIlhas )
            ilhaDaRaiz[r]
        )

        -- 2. ÁREAS, INVERTIDOS E APROVEITAMENTO
        local areaUVIlha = for i = 1 to res.nIlhas collect 0.0
        local area3DIlha = for i = 1 to res.nIlhas collect 0.0
        local areaUV = #()
        local area3D = #()
        for f = 1 to nF do
        (
            local c = cantos[f]
            local s = InLab_UV_AreaSinal uv[c[1]] uv[c[2]] uv[c[3]]
            if s < -1e-12 do res.invertidos += 1
            areaUV[f] = abs s
            area3D[f] = meshop.getFaceArea m f
            areaUVIlha[ilhaFace[f]] += areaUV[f]
            area3DIlha[ilhaFace[f]] += area3D[f]
            res.aproveitamento += areaUV[f]
        )

        -- 3. DENSIDADE ENTRE ILHAS E DISTORÇÃO DENTRO DA ILHA
        local densMax = 0.0, densMin = 1e30
        for i = 1 to res.nIlhas where area3DIlha[i] > INLAB_UV_EPS and areaUVIlha[i] > 1e-12 do
        (
            local d = areaUVIlha[i] / area3DIlha[i]
            densMax = amax densMax d
            densMin = amin densMin d
        )
        if densMax > 0.0 do
        (
            res.densidadeRazaoArea = densMax / densMin
            res.densidadeRazao = sqrt res.densidadeRazaoArea
        )
        for f = 1 to nF where area3D[f] > INLAB_UV_EPS and areaUV[f] > 1e-12 do
        (
            local i = ilhaFace[f]
            local r = (areaUV[f] / area3D[f]) / (areaUVIlha[i] / area3DIlha[i])
            res.distorcaoMax = amax res.distorcaoMax (amax r (1.0 / r))
        )

        -- 4. FORA DO 0–1, BORDA E BBOX DOS UVs USADOS
        local usados = #{}
        for c in cantos do ( usados[c[1]] = true ; usados[c[2]] = true ; usados[c[3]] = true )
        local uMin = 1e30, uMax = -1e30, vMin = 1e30, vMax = -1e30
        if usados.numberSet > 0 do res.bordaMin = 1e30
        for v in usados do
        (
            local p = uv[v]
            if p.x < -INLAB_UV_EPS or p.x > 1.0 + INLAB_UV_EPS or p.y < -INLAB_UV_EPS or p.y > 1.0 + INLAB_UV_EPS do
                res.foraDe01 += 1
            res.bordaMin = amin #(res.bordaMin, p.x, p.y, 1.0 - p.x, 1.0 - p.y)
            uMin = amin uMin p.x ; uMax = amax uMax p.x
            vMin = amin vMin p.y ; vMax = amax vMax p.y
        )

        -- 5. SOBREPOSIÇÃO: grade N×N sobre o bbox, eixo separador por par
        local sobreEntreIlhas = false
        if nF > 1 do
        (
            local N = INLAB_UV_GRADE_SOBREPOSICAO
            local tamU = (amax (uMax - uMin) INLAB_UV_EPS) / N
            local tamV = (amax (vMax - vMin) INLAB_UV_EPS) / N
            local celulas = for i = 1 to N * N collect #()
            local caixas = #()
            for f = 1 to nF where areaUV[f] > 1e-12 do
            (
                local c = cantos[f]
                local a = uv[c[1]], b = uv[c[2]], d = uv[c[3]]
                caixas[f] = #(amin #(a.x, b.x, d.x), amin #(a.y, b.y, d.y), amax #(a.x, b.x, d.x), amax #(a.y, b.y, d.y))
                for i = (InLab_UV_Celula caixas[f][1] uMin tamU N) to (InLab_UV_Celula caixas[f][3] uMin tamU N) do
                    for j = (InLab_UV_Celula caixas[f][2] vMin tamV N) to (InLab_UV_Celula caixas[f][4] vMin tamV N) do
                        append celulas[(j - 1) * N + i] f
            )
            local sobre = #{}
            sobre.count = nF
            for cel in celulas where cel.count > 1 do
                for p = 1 to cel.count - 1 do
                    for q = p + 1 to cel.count do
                    (
                        local f1 = cel[p], f2 = cel[q]
                        if not (sobre[f1] and sobre[f2]) do
                        (
                            local b1 = caixas[f1], b2 = caixas[f2]
                            if b1[1] < b2[3] and b2[1] < b1[3] and b1[2] < b2[4] and b2[2] < b1[4] do
                            (
                                local t1 = for k in cantos[f1] collect uv[k]
                                local t2 = for k in cantos[f2] collect uv[k]
                                if InLab_UV_TriSobrepoe t1 t2 do
                                (
                                    sobre[f1] = true
                                    sobre[f2] = true
                                    if ilhaFace[f1] != ilhaFace[f2] do sobreEntreIlhas = true
                                )
                            )
                        )
                    )
            res.sobrepostas = sobre.numberSet
        )

        -- 6. GUTTER: arestas de borda (usadas por uma face só) de ilhas diferentes
        if res.nIlhas > 1 do
        (
            local vizinhos = for v = 1 to nV collect #() -- vértice menor → vértices maiores
            local contagem = for v = 1 to nV collect #() -- paralelo: faces por aresta
            for c in cantos do
                for k = 1 to 3 do
                (
                    local a = c[k], b = c[if k == 3 then 1 else k + 1]
                    local lo = amin a b, hi = amax a b
                    local idx = findItem vizinhos[lo] hi
                    if idx == 0 then ( append vizinhos[lo] hi ; append contagem[lo] 1 )
                    else contagem[lo][idx] += 1
                )
            local segs = #() -- #(pontoA, pontoB, ilha)
            for lo = 1 to nV do
                for idx = 1 to vizinhos[lo].count where contagem[lo][idx] == 1 do
                    append segs #(uv[lo], uv[vizinhos[lo][idx]], ilhaDaRaiz[InLab_UV_Raiz pai lo])

            local R = INLAB_UV_GUTTER_BUSCA
            local nx = (ceil ((uMax - uMin) / R)) as integer + 1
            local ny = (ceil ((vMax - vMin) / R)) as integer + 1
            if nx * ny > 250000 then
                InLab_Log (obj.name + ": canal " + canal as string + " espalhado demais para medir o gutter.") tipo:#warn
            else
            (
                local grade = for i = 1 to nx * ny collect #()
                for s = 1 to segs.count do
                (
                    local a = segs[s][1], b = segs[s][2]
                    for i = (InLab_UV_Celula (amin a.x b.x) uMin R nx) to (InLab_UV_Celula (amax a.x b.x) uMin R nx) do
                        for j = (InLab_UV_Celula (amin a.y b.y) vMin R ny) to (InLab_UV_Celula (amax a.y b.y) vMin R ny) do
                            append grade[(j - 1) * nx + i] s
                )
                local g = if sobreEntreIlhas then 0.0 else R
                for s in segs while g > 0.0 do
                    for p in #(s[1], s[2]) do
                    (
                        local ci = InLab_UV_Celula p.x uMin R nx
                        local cj = InLab_UV_Celula p.y vMin R ny
                        for i = ci - 1 to ci + 1 where i >= 1 and i <= nx do
                            for j = cj - 1 to cj + 1 where j >= 1 and j <= ny do
                                for t in grade[(j - 1) * nx + i] where segs[t][3] != s[3] do
                                    g = amin g (InLab_UV_DistPontoSeg p segs[t][1] segs[t][2])
                    )
                res.gutterMin = g
            )
        )
    )
    res
)

-- Texto que identifica o UV de cada canto de face do canal. Serve para
-- provar que um canal não mudou (antes == depois). undefined se não existe.
fn InLab_AssinaturaCanal obj canal =
(
    local m = snapshotAsMesh obj
    local s = undefined
    if meshop.getMapSupport m canal do
    (
        local ss = stringStream ""
        for f = 1 to m.numfaces do
        (
            local c = meshop.getMapFace m canal f
            for k in #(c.x, c.y, c.z) do
            (
                local p = meshop.getMapVert m canal (k as integer)
                format "%,%;" (formattedPrint p.x format:".5f") (formattedPrint p.y format:".5f") to:ss
            )
        )
        s = ss as string
    )
    s
)

fn InLab_UVMetricasTexto met =
(
    if met == undefined then "sem medição"
    else
    (
        "canal " + met.canal as string +
        " · " + met.nIlhas as string + " ilha(s)" +
        " · aproveitamento " + (formattedPrint (met.aproveitamento * 100.0) format:".0f") + "%" +
        " · densidade máx/mín " + (formattedPrint met.densidadeRazao format:".2f") + "×" +
        " · distorção máx " + (formattedPrint met.distorcaoMax format:".2f") + "×" +
        " · fora do 0–1: " + met.foraDe01 as string +
        " · sobrepostas: " + met.sobrepostas as string +
        " · invertidos: " + met.invertidos as string + (if met.espelhado then " (objeto espelhado)" else "") +
        " · gutter mín " + (if met.gutterMin == undefined then "n/d"
                            else if met.gutterMin >= INLAB_UV_GUTTER_BUSCA then "≥" + (formattedPrint INLAB_UV_GUTTER_BUSCA format:".3f")
                            else formattedPrint met.gutterMin format:".4f") +
        " · borda mín " + (if met.bordaMin == undefined then "n/d" else formattedPrint met.bordaMin format:".4f")
    )
)
```

- [x] **Passo 4: rodar o teste e ver passar**

Mesmo comando do Passo 2. Esperado: todas as linhas `PASS` e `TUDO OK`. Se o caso de desempenho passar de 30 s, anote o tempo medido e avise antes de seguir. O Box008 tem 15 mil faces e o Auto UV mede cada objeto.

- [x] **Passo 5: registrar no manifesto**

Em `InLabChecker.ms`, no bloco `-- 4. VERIFICAÇÃO + relatório`, depois de `@"verifications\verif_animacao.ms",`:

```maxscript
            @"verifications\verif_animacao.ms",
            -- medição de UV (issue #1): só leitura, usada pelo Auto UV no log
            @"verifications\verif_uv.ms",
            @"report\report_generator.ms",
```

Pelo MCP: `InLab_RecarregarPlugin()`. Esperado: `true` e "Plugin recarregado com sucesso." no log.

- [x] **Passo 6: medir o baseline (pipeline atual e ArchToolz) com o helper**

Ainda com o `fn_autouv.ms` antigo (o que grava no canal 1). Com as cópias da Tarefa 1 em `(getDir #temp)\inlab_autouv\` e o plugin carregado:

```maxscript
(
    local pasta = (getDir #temp) + "\\inlab_autouv\\"
    local saida = createFile (pasta + "baseline.txt") encoding:#utf8
    local pecas = #("Box007", "Box008", "Box009", "Box013", "Box014")

    loadMaxFile (pasta + "02.max") quiet:true
    format "=== ArchToolz (02.max, canal 3) ===\n" to:saida
    for n in pecas do
    (
        local o = getNodeByName n
        format "% · % faces · %\n" n (getPolygonCount o)[1] (InLab_UVMetricasTexto (InLab_MedirUV o 3)) to:saida
    )

    loadMaxFile (pasta + "01.max") quiet:true
    format "\n=== Pipeline atual (01.max → InLab_AutoUV, canal 1) ===\n" to:saida
    for n in pecas do
    (
        local o = getNodeByName n
        local t0 = timeStamp()
        InLab_AutoUV #(o)
        format "% · % ms · %\n" n (timeStamp() - t0) (InLab_UVMetricasTexto (InLab_MedirUV o 1)) to:saida
    )
    close saida
    resetMaxFile #noPrompt
    pasta + "baseline.txt"
)
```

Leia `baseline.txt`. Compare as linhas do ArchToolz com a tabela da issue. **Se a razão de densidade medida bater com a da issue só em área (`densidadeRazaoArea`, o quadrado da linear), avise o usuário antes de seguir.** A meta "≤ 1,10×" precisa usar a mesma definição que a tabela do ArchToolz, e só o usuário decide qual das duas vale.

- [x] **Passo 7: pedir autorização, commit e PR da Fase 1**

```bash
git add verifications/verif_uv.ms tests/test_verif_uv.ms InLabChecker.ms
git commit -m "feat(autouv): adiciona medicao de UV por canal (verif_uv)"
```

Com autorização: PR referenciando `#1` e comentário na issue com a tabela do baseline (atual × ArchToolz, mesmo formato da tabela da issue: faces, ilhas, aproveitamento, densidade).

---

### Tarefa 3 (Fase 2): canal 3, base `Editable_mesh`, Clean UV e Reverter

**Arquivos:**
- Reescrever: `functions/fn_autouv.ms`
- Criar: `tests/test_autouv.ms`

**Interfaces:**
- Consome: `InLab_MedirUV`, `InLab_AssinaturaCanal`, `InLab_UVMetricasTexto` (Tarefa 2); `InLab_EhGeometria` (`core/utils.ms`); respostas (a) a (d) da Tarefa 1.
- Produz:
  - `INLAB_CANAL_UV_MATERIAL = 1`, `INLAB_CANAL_UV_BAKE = 3`, `INLAB_UV_RESOLUCOES = #(1024, 2048, 4096)`. `INLAB_CANAL_UV` deixa de existir (hoje só é usado dentro de `fn_autouv.ms`).
  - `InLab_PaddingUV resolucao` → Float (4 px a 1K, 8 px a 2K, 16 px a 4K, em UV).
  - `InLab_AutoUV objs angulo:55.0 seamsOcultas:true resolucao:1024` → Integer (objetos processados).
  - `InLab_CleanUV objs` → Integer.
  - `InLab_ReverterAutoUV()`.
  - `struct AutoUVRecord (no, modificador, baseOriginal)` e `InLab_UltimoAutoUV`, com um registro por objeto acumulado até o Reverter.

**Decisões desta tarefa (confirmar com o usuário se discordar):**
- Base **com** modificadores no stack não é convertida, porque converter exigiria colapsar. Fica como está, com `#warn` no log. Base sem modificadores vira `Editable_mesh`, e uma cópia da original vai para o Reverter.
- Rodar o Auto UV de novo num objeto substitui o `Unwrap` anterior em vez de empilhar. O Reverter volta ao estado de antes da **primeira** rodada.
- O Clean UV passa a remover só os modificadores de UV do **canal 3**. Hoje ele apaga qualquer `*UVW*`/`*Unwrap*`, o que inclui o UVW Map do material no canal 1 e quebraria o critério "canal 1 idêntico".
- Pipeline provisório (a issue permite): `flattenMap` com o ângulo da UI → relax → pack com o padding da resolução. O checkbox de seams ocultas é aceito, mas só registra no log que entra na Fase 3.
- **Se a Tarefa 1 mostrar que `node.baseObject = copia` não funciona:** pare. A alternativa (`convertToPoly` no Reverter) perde a topologia original de polígonos, e isso precisa de aprovação do usuário.

- [x] **Passo 1: escrever o teste `tests/test_autouv.ms`**

```maxscript
/*
 tests\test_autouv.ms — teste automático de functions\fn_autouv.ms (issue #1, Fase 2)
 RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt): cria uma caixa Editable_Poly,
 uma caixa dentro de um grupo e um cilindro com UVW Map no canal 1, e apaga
 tudo no final.
 Resultado: <pasta temp do Max>\inlab_test_autouv.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_EhGeometria
global InLab_MedirUV, InLab_AssinaturaCanal, InLab_UVMetricasTexto
global InLab_AutoUV, InLab_CleanUV, InLab_ReverterAutoUV, InLab_PaddingUV, InLab_UltimoAutoUV
global INLAB_CANAL_UV_MATERIAL, INLAB_CANAL_UV_BAKE
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_autouv.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn temModificador o cls =
    (
        local achou = false
        for md in o.modifiers where isKindOf md cls do achou = true
        achou
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    local criados = #()

    try
    (
        fileIn (raiz + @"core\utils.ms")
        fileIn (raiz + @"verifications\verif_uv.ms")
        fileIn (raiz + @"functions\fn_autouv.ms")

        -- 0. PADDING POR RESOLUÇÃO
        checar "Padding 1K = 4 px" (abs ((InLab_PaddingUV 1024) - 4.0 / 1024) < 1e-9)
        checar "Padding 2K = 8 px" (abs ((InLab_PaddingUV 2048) - 8.0 / 2048) < 1e-9)
        checar "Padding 4K = 16 px" (abs ((InLab_PaddingUV 4096) - 16.0 / 4096) < 1e-9)

        -- CENA
        local bPoly = Box name:"uv_poly" length:20 width:20 height:20
        convertToPoly bPoly
        local bGrupo = Box name:"uv_grupo" length:20 width:40 height:10 pos:[60, 0, 0]
        local grp = group #(bGrupo) name:"uv_grp"
        local cil = Cylinder name:"uv_cil" radius:10 height:30 sides:24 pos:[120, 0, 0]
        addModifier cil (Uvwmap maptype:4 mapChannel:1)
        criados = #(bPoly, bGrupo, cil, grp)
        local objs = #(bPoly, bGrupo, cil)
        local antes = for o in objs collect InLab_AssinaturaCanal o INLAB_CANAL_UV_MATERIAL
        local facesAntes = polyop.getNumFaces bPoly
        checar "Cena: canal 1 existe nos 3 objetos" ((for s in antes where s == undefined collect s).count == 0)

        -- 1. AUTO UV
        checar "Auto UV processa 3 objetos" ((InLab_AutoUV objs angulo:55.0 seamsOcultas:true resolucao:1024) == 3)
        for i = 1 to objs.count do
        (
            local o = objs[i]
            local topo = o.modifiers[1]
            checar (o.name + ": Unwrap no topo, canal 3") (isKindOf topo Unwrap_UVW and topo.getMapChannel() == 3)
            checar (o.name + ": canal 1 idêntico") ((InLab_AssinaturaCanal o INLAB_CANAL_UV_MATERIAL) == antes[i])
            local m = InLab_MedirUV o INLAB_CANAL_UV_BAKE
            linha ("      " + o.name + ": " + InLab_UVMetricasTexto m)
            checar (o.name + ": nada fora do 0–1") (m != undefined and m.foraDe01 == 0)
            checar (o.name + ": 0 sobrepostas") (m != undefined and m.sobrepostas == 0)
            checar (o.name + ": 0 invertidos") (m != undefined and m.invertidos == 0)
        )
        checar "Base Editable_Poly virou Editable_mesh" (classOf bPoly.baseObject == Editable_mesh)
        checar "Base do objeto no grupo virou Editable_mesh" (classOf bGrupo.baseObject == Editable_mesh)
        checar "Base com modificadores ficou como estava" (classOf cil.baseObject == Cylinder)
        checar "UVW Map do canal 1 continua no stack" (temModificador cil Uvwmap)
        checar "Objeto continua no grupo" (bGrupo.parent == grp and isGroupMember bGrupo)
        checar "Registro: 3 objetos" (InLab_UltimoAutoUV.count == 3)

        -- 2. RODAR DE NOVO: substitui o Unwrap, não empilha
        InLab_AutoUV #(bPoly) angulo:30.0 seamsOcultas:false resolucao:2048
        checar "Rodar de novo não empilha Unwrap" (bPoly.modifiers.count == 1)
        checar "Rodar de novo mantém um registro por objeto" (InLab_UltimoAutoUV.count == 3)

        -- 3. CLEAN UV: tira só o que é do canal 3
        InLab_CleanUV #(cil)
        checar "Clean UV remove o Unwrap do canal 3" (not (temModificador cil Unwrap_UVW))
        checar "Clean UV mantém o UVW Map do canal 1" (temModificador cil Uvwmap)
        checar "Clean UV: canal 1 idêntico" ((InLab_AssinaturaCanal cil INLAB_CANAL_UV_MATERIAL) == antes[3])

        -- 4. REVERTER
        InLab_ReverterAutoUV()
        checar "Reverter: base volta a Editable_Poly" (classOf bPoly.baseObject == Editable_Poly)
        checar "Reverter: mesmo nº de polígonos" (classOf bPoly.baseObject == Editable_Poly and (polyop.getNumFaces bPoly) == facesAntes)
        checar "Reverter: base do grupo volta a Box" (classOf bGrupo.baseObject == Box)
        checar "Reverter: sem Unwrap" (bPoly.modifiers.count == 0 and bGrupo.modifiers.count == 0)
        checar "Reverter: canal 1 idêntico" ((InLab_AssinaturaCanal bPoly INLAB_CANAL_UV_MATERIAL) == antes[1] and (InLab_AssinaturaCanal bGrupo INLAB_CANAL_UV_MATERIAL) == antes[2])
        checar "Reverter: grupo preservado" (bGrupo.parent == grp)
        checar "Reverter: registro zerado" (InLab_UltimoAutoUV.count == 0)

        -- Ctrl+Z nativo NÃO é testável daqui: rodado de dentro do script,
        -- `max undo` desfaz o script inteiro. Conferir à mão pela UI.
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    for o in criados where isValidNode o do delete o
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
```

- [x] **Passo 2: rodar e ver falhar**

Pelo MCP: `resetMaxFile #noPrompt` e depois `fileIn @"G:\Meu Drive\GitHub\InLabChecker\tests\test_autouv.ms"`. Leia `inlab_test_autouv.txt`.
Esperado: `FAIL` a partir de "Padding 1K" (`InLab_PaddingUV` não existe) ou `EXCEÇÃO`. Nenhuma linha "TUDO OK".

- [x] **Passo 3: reescrever `functions/fn_autouv.ms`**

Arquivo inteiro:

```maxscript
/*
================================================================================
 functions\fn_autouv.ms — FUNÇÃO 2 · "Auto UV" (reescrita · bug 2, 13/Jul ·
 canal de bake, 18/Set)
--------------------------------------------------------------------------------
 18/Set (issue #1, Fase 2): o Auto UV não mexe mais no canal 1. O canal 1 é do
 material (UV em escala real) e fica intacto. O 0–1 empacotado para bake de
 textura e AO vai para o canal 3, como no ArchToolz 2026. A base sem
 modificadores vira Editable_mesh (uma cópia da base original fica guardada
 para o Reverter) e o Unwrap_UVW fica vivo no stack. O padding sai da
 resolução do bake: 4 px a 1K, 8 px a 2K, 16 px a 4K.
 Pipeline PROVISÓRIO até as Fases 3–4: Flatten pelo ângulo da UI → relax →
 pack. Cada objeto sai no log com as métricas de verifications\verif_uv.ms e
 com a checagem de que o canal 1 não mudou.
 O Clean UV passa a remover só os modificadores do canal 3. Antes ele apagava
 qualquer UVW, inclusive o UVW Map do material no canal 1.

 13/Jul (bug 2): o relax falhava silenciosamente (assinatura errada engolida
 por try/catch). Ele roda SEMPRE, com cadeia de 3 assinaturas testadas em
 ordem, e o log registra QUAL rodou (ou acusa "relax indisponível").

 UNDO: undo "InLab ..." + registro dedicado (InLab_UltimoAutoUV) para o
 Reverter, que alcança além do Ctrl+Z.
================================================================================
*/

-- Pré-declarados: definidos em verifications\verif_uv.ms, carregado depois.
global InLab_MedirUV, InLab_AssinaturaCanal, InLab_UVMetricasTexto

-- ===== PADRÃO InLab: canais de UV (ponto único de mudança) =====
global INLAB_CANAL_UV_MATERIAL = 1  -- UV do material, em escala real: o Auto UV nunca altera
global INLAB_CANAL_UV_BAKE = 3      -- 0–1 empacotado por objeto, para bake de textura e AO
global INLAB_UV_RESOLUCOES = #(1024, 2048, 4096) -- mesma ordem do dropdown da UI

-- Registro de um Auto UV aplicado (para o Reverter dedicado).
struct AutoUVRecord
(
    no,            -- nó da cena
    modificador,   -- instância exata do Unwrap_UVW adicionada (a mais recente)
    baseOriginal   -- cópia da base de antes do convertToMesh (undefined se não converteu)
)

-- Um registro por objeto, acumulado até o Reverter. Se o Auto UV rodar de
-- novo no mesmo objeto, o registro é reaproveitado e a base original
-- continua sendo a da primeira vez.
global InLab_UltimoAutoUV = #()

global InLab_TentarRelax, InLab_PaddingUV, InLab_AutoUV_PrepararBase, InLab_AutoUV_Registro
global InLab_AutoUV, InLab_CanalDoModificadorUV, InLab_CleanUV, InLab_ReverterAutoUV

--------------------------------------------------------------------------------
-- RELAX com cadeia de assinaturas (a causa do bug 2 era confiar numa só):
-- tenta as variantes documentadas em ordem e retorna o nome da que rodou,
-- ou undefined se nenhuma existir nesta build.
--------------------------------------------------------------------------------
fn InLab_TentarRelax uvw =
(
    local usado = undefined
    try ( uvw.relax 100 0.1 false true ; usado = "relax(100, 0.1)" ) catch()
    if usado == undefined do
        try ( uvw.RelaxOneClick() ; usado = "RelaxOneClick" ) catch()
    if usado == undefined do
        try ( uvw.relaxByFaceAngle 100 0.05 0.05 false ; usado = "relaxByFaceAngle" ) catch()
    usado
)

--------------------------------------------------------------------------------
-- Gutter entre ilhas, em unidades de UV: 4 px a 1K, 8 px a 2K, 16 px a 4K
-- (issue #1). Dá ~0,0039 em qualquer resolução.
--------------------------------------------------------------------------------
fn InLab_PaddingUV resolucao =
(
    local px = case resolucao of
    (
        2048: 8.0
        4096: 16.0
        default: 4.0
    )
    px / resolucao
)

--------------------------------------------------------------------------------
-- Converte a base para Editable_mesh (como o ArchToolz) e devolve uma cópia
-- da base original para o Reverter. Com modificadores no stack a base fica
-- como está, porque converter exigiria colapsar (proibido pela issue #1).
--------------------------------------------------------------------------------
fn InLab_AutoUV_PrepararBase o =
(
    local original = undefined
    if classOf o.baseObject != Editable_mesh do
    (
        if o.modifiers.count > 0 then
            InLab_Log (o.name + ": base " + (classOf o.baseObject) as string + " mantida — há " +
                       o.modifiers.count as string + " modificador(es) no stack e converter colapsaria.") tipo:#warn
        else
        (
            original = copy o.baseObject
            convertToMesh o
        )
    )
    original
)

fn InLab_AutoUV_Registro o =
(
    local achado = undefined
    for r in InLab_UltimoAutoUV do
        if achado == undefined and r.no == o do achado = r
    achado
)

--------------------------------------------------------------------------------
-- AUTO UV sobre a seleção. Grava no canal INLAB_CANAL_UV_BAKE.
--------------------------------------------------------------------------------
fn InLab_AutoUV objs angulo:55.0 seamsOcultas:true resolucao:1024 =
(
    local processados = 0
    local padding = InLab_PaddingUV resolucao
    local normais = #([1,0,0], [-1,0,0], [0,1,0], [0,-1,0], [0,0,1], [0,0,-1])
    InLab_Log ("Auto UV: canal " + INLAB_CANAL_UV_BAKE as string + " · ângulo " + (formattedPrint angulo format:".0f") +
               "° · " + resolucao as string + " px (padding " + (formattedPrint padding format:".4f") + ")")
    if seamsOcultas do
        InLab_Log "Auto UV: \"Preferir seams em regiões ocultas\" ainda não tem efeito (entra na Fase 3 da issue #1)." tipo:#warn

    undo "InLab AutoUV" on
    (
        max modify mode

        for o in objs where InLab_EhGeometria o do
        (
            if (getPolygonCount o)[1] == 0 then
                InLab_Log (o.name + ": sem faces — ignorado.") tipo:#warn
            else
            (
                local canal1Antes = InLab_AssinaturaCanal o INLAB_CANAL_UV_MATERIAL

                -- Rodar de novo substitui o Unwrap anterior em vez de empilhar.
                local rec = InLab_AutoUV_Registro o
                if rec == undefined then
                (
                    rec = AutoUVRecord no:o baseOriginal:(InLab_AutoUV_PrepararBase o)
                    append InLab_UltimoAutoUV rec
                )
                else if rec.modificador != undefined do
                    try ( deleteModifier o rec.modificador )
                    catch ( InLab_Log (o.name + ": Unwrap anterior do Auto UV não encontrado (removido à mão?).") tipo:#warn )

                select o
                local uvw = Unwrap_UVW()
                uvw.name = "InLab AutoUV"
                modPanel.addModToSelection uvw
                modPanel.setCurrentObject uvw
                rec.modificador = uvw

                local falhou = false
                try ( uvw.setMapChannel INLAB_CANAL_UV_BAKE )
                catch ( InLab_Log (o.name + ": falha em setMapChannel.") tipo:#err ; falhou = true )

                local nPolysUV = (getPolygonCount o)[1]
                try ( nPolysUV = uvw.numberPolygons() ) catch ( nPolysUV = (GetTriMeshFaceCount o)[1] )
                try ( uvw.selectFaces #{1..nPolysUV} )
                catch ( InLab_Log (o.name + ": falha em selectFaces.") tipo:#err ; falhou = true )

                if not falhou do
                (
                    InLab_Log (o.name + ": Auto UV em processamento (a UI pode congelar alguns segundos)...")
                    try ( windows.processPostedMessages() ) catch()

                    ------------------------------------------------------
                    -- 1 · FLATTEN pelo ângulo da UI (provisório até a Fase 3)
                    ------------------------------------------------------
                    local metodo = undefined
                    try ( uvw.flattenMap angulo normais padding true 0 true true ; metodo = "Flatten " + (formattedPrint angulo format:".0f") + "°" )
                    catch ( InLab_Log (o.name + ": flattenMap falhou — " + getCurrentException()) tipo:#err )

                    if metodo != undefined do
                    (
                        ------------------------------------------------------
                        -- 2 · RELAX (sempre — correção do bug 2)
                        ------------------------------------------------------
                        local relaxUsado = InLab_TentarRelax uvw
                        if relaxUsado == undefined do
                            InLab_Log (o.name + ": relax indisponível nesta build — resultado pode sair distorcido; reportar.") tipo:#warn

                        ------------------------------------------------------
                        -- 3 · PACK com o padding da resolução; fallback Unfold3DPack
                        ------------------------------------------------------
                        local packUsado = undefined
                        try ( uvw.pack 1 padding true true true ; packUsado = "pack recursivo" ) catch()
                        if packUsado == undefined do
                            try ( uvw.Unfold3DPack() ; packUsado = "Unfold3DPack" ) catch()
                        if packUsado == undefined do
                            InLab_Log (o.name + ": pack indisponível — ilhas podem ficar fora do 0-1.") tipo:#warn

                        ------------------------------------------------------
                        -- 4 · MEDIÇÃO + guarda do canal 1
                        ------------------------------------------------------
                        if (InLab_AssinaturaCanal o INLAB_CANAL_UV_MATERIAL) != canal1Antes do
                            InLab_Log (o.name + ": o canal 1 mudou durante o Auto UV — reportar.") tipo:#err
                        local met = InLab_MedirUV o INLAB_CANAL_UV_BAKE
                        InLab_Log (o.name + ": Auto UV OK · " + metodo +
                                   " → " + (if relaxUsado != undefined then relaxUsado else "sem relax") +
                                   " → " + (if packUsado != undefined then packUsado else "sem pack") +
                                   " · " + InLab_UVMetricasTexto met) tipo:#ok
                        processados += 1
                    )
                )
            )
        )
        try ( select objs ) catch()
    )

    InLab_Log ("Auto UV: " + processados as string + " de " + objs.count as string + " objeto(s).")
    processados
)

--------------------------------------------------------------------------------
-- Canal em que um modificador de UV escreve, ou undefined se não der para
-- ler (quem chama loga).
--------------------------------------------------------------------------------
fn InLab_CanalDoModificadorUV md =
(
    local canal = undefined
    if isKindOf md Unwrap_UVW then
        try ( canal = md.getMapChannel() ) catch()
    else
        for p in #(#mapChannel, #channel, #mapID) while canal == undefined do
            if isProperty md p do canal = getProperty md p
    canal
)

--------------------------------------------------------------------------------
-- CLEAN UV: remove os modificadores de UV do canal de bake e aplica o UVW
-- Mapping Clear nesse canal. Modificadores de outros canais (ex.: o UVW Map
-- do material no canal 1) ficam. O Clear FICA no stack (colapso é decisão do
-- desenhista — V-11 aponta antes do export).
--------------------------------------------------------------------------------
fn InLab_CleanUV objs =
(
    local n = 0
    undo "InLab CleanUV" on
    (
        for o in objs where InLab_EhGeometria o do
        (
            -- De cima para baixo para não invalidar os índices.
            local removidos = 0
            for i = o.modifiers.count to 1 by -1 do
            (
                local md = o.modifiers[i]
                local nomeCls = (classof md) as string
                if (matchPattern nomeCls pattern:"*Unwrap*") or (matchPattern nomeCls pattern:"*UVW*") do
                (
                    local canal = InLab_CanalDoModificadorUV md
                    if canal == INLAB_CANAL_UV_BAKE then
                    (
                        deleteModifier o i
                        removidos += 1
                    )
                    else if canal == undefined do
                        InLab_Log (o.name + ": " + md.name + " mantido — não deu para ler o canal.") tipo:#warn
                )
            )

            local limpou = false
            try
            (
                local clr = UVW_Mapping_Clear()
                try ( clr.channel = INLAB_CANAL_UV_BAKE ) catch()
                try ( clr.mapID   = INLAB_CANAL_UV_BAKE ) catch()
                addModifier o clr
                limpou = true
            )
            catch()

            InLab_Log (o.name + ": Clean UV · " + removidos as string + " modificador(es) do canal " + INLAB_CANAL_UV_BAKE as string + " removido(s)" +
                       (if limpou then " · canal " + INLAB_CANAL_UV_BAKE as string + " limpo (colapsar antes do export)" else " · UVW Mapping Clear indisponível nesta build")) tipo:#ok
            n += 1
        )
    )
    InLab_Log ("Clean UV: " + n as string + " objeto(s).")
    n
)

--------------------------------------------------------------------------------
-- Reverte todos os Auto UV registrados desde o último Reverter: remove o
-- Unwrap e devolve a base original (Editable_Poly, primitiva...).
--------------------------------------------------------------------------------
fn InLab_ReverterAutoUV =
(
    if InLab_UltimoAutoUV.count == 0 then
        InLab_Log "Nenhum Auto UV registrado nesta sessão para reverter." tipo:#warn
    else
    (
        local revertidos = 0
        undo "InLab Reverter AutoUV" on
        (
            for r in InLab_UltimoAutoUV where isValidNode r.no do
            (
                local ok = true
                try ( deleteModifier r.no r.modificador )
                catch ( InLab_Log (r.no.name + ": Unwrap do Auto UV não encontrado (removido ou colapsado?).") tipo:#warn ; ok = false )
                if r.baseOriginal != undefined do
                    try ( r.no.baseObject = r.baseOriginal )
                    catch ( InLab_Log (r.no.name + ": não foi possível restaurar a base original — " + getCurrentException()) tipo:#err ; ok = false )
                if ok do
                (
                    InLab_Log (r.no.name + ": Auto UV revertido" +
                               (if r.baseOriginal != undefined then " · base " + (classOf r.baseOriginal) as string + " restaurada." else ".")) tipo:#ok
                    revertidos += 1
                )
            )
        )
        InLab_UltimoAutoUV = #()
        InLab_Log ("Reversão de UV concluída: " + revertidos as string + " objeto(s).")
    )
)
```

Ajuste antes de rodar: se a Tarefa 1 mostrou que o `UVW_Mapping_Clear` usa outra propriedade de canal (resposta d), troque as duas linhas `clr.channel` / `clr.mapID` por ela.

- [x] **Passo 4: rodar o teste e ver passar**

Mesmo comando do Passo 2. Esperado: `TUDO OK`. As linhas `[LOG ...]` mostram as métricas de cada objeto. Se "canal 1 idêntico" falhar para `uv_poly`, investigue (`superpowers:systematic-debugging`) antes de mexer: pode ser a triangulação do `convertToMesh` diferente da do snapshot da `Editable_Poly`.

- [x] **Passo 5: rodar o teste da Fase 1 de novo**

`resetMaxFile #noPrompt` e `fileIn @"...\tests\test_verif_uv.ms"`. Esperado: `TUDO OK`.

- [x] **Passo 6: commit**

```bash
git add functions/fn_autouv.ms tests/test_autouv.ms
git commit -m "feat(autouv): grava o 0-1 do bake no canal 3 e preserva o canal 1"
```

---

### Tarefa 4 (Fase 2): UI da seção Otimização e validação nas peças reais

**Arquivos:**
- Modificar: `ui/rollout_main.ms:196-199` (controles) e `ui/rollout_main.ms:244-258` (handlers)

**Interfaces:**
- Consome: `InLab_AutoUV objs angulo: seamsOcultas: resolucao:`, `InLab_CleanUV`, `InLab_ReverterAutoUV`, `INLAB_UV_RESOLUCOES` (Tarefa 3).
- Produz: controles `spnAnguloUV`, `chkSeamsOcultas`, `ddlResolucaoUV`, `btnF2Reverter`. `spnPadding` deixa de existir.

- [x] **Passo 1: trocar os controles**

Substituir:

```maxscript
    label lblF2 "Auto UV" align:#left across:1
    spinner spnPadding "Padding:" range:[0.0, 0.05, 0.005] scale:0.001 type:#float fieldWidth:50 align:#left
    button btnF2 "Auto UV na Seleção" width:192 across:2
    button btnF2Clean "Clean UV" width:192
```

por:

```maxscript
    -- 18/Set (issue #1): o padding sai da resolução do bake; o Auto UV grava
    -- no canal 3 e não toca no canal 1.
    label lblF2 "Auto UV  (canal 3 · bake de textura e AO)" align:#left across:1
    spinner spnAnguloUV "Ângulo flatten (°):" range:[10, 90, 55] type:#float fieldWidth:40 align:#left
    checkbox chkSeamsOcultas "Preferir seams em regiões ocultas" checked:true
    dropdownlist ddlResolucaoUV "Resolução do bake:" items:#("1024", "2048", "4096") selection:1 width:120 align:#left
    button btnF2 "Auto UV na Seleção" width:126 across:3
    button btnF2Clean "Clean UV" width:126
    button btnF2Reverter "Reverter Auto UV" width:126
```

O rótulo do dropdown precisa bater com `INLAB_UV_RESOLUCOES`, na mesma ordem.

- [x] **Passo 2: trocar os handlers**

Substituir o handler `on btnF2 pressed do ( ... )` por:

```maxscript
    on btnF2 pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            InLab_ProgressoIniciar "Gerando Auto UV..."
            InLab_AutoUV objs angulo:spnAnguloUV.value seamsOcultas:chkSeamsOcultas.checked \
                resolucao:INLAB_UV_RESOLUCOES[ddlResolucaoUV.selection]
            InLab_ProgressoParar()
        )
    )
```

E, logo depois do handler `on btnF2Clean pressed do ( ... )`, que continua igual:

```maxscript
    on btnF2Reverter pressed do InLab_ReverterAutoUV()
```

- [x] **Passo 3: recarregar e conferir a carga**

Pelo MCP: `InLab_RecarregarPlugin()`. Esperado: `true`. Tire um `capture_screen` da janela para conferir o layout da seção. Depois peça ao usuário para clicar em cada botão (Auto UV, Clean UV, Reverter) numa caixa e conferir o Ctrl+Z, que não dá para testar por script.

- [x] **Passo 4: medir nas peças reais**

Numa cópia de `01.max` (`(getDir #temp)\inlab_autouv\01.max`):

```maxscript
(
    local pasta = (getDir #temp) + "\\inlab_autouv\\"
    loadMaxFile (pasta + "01.max") quiet:true
    local pecas = for n in #("Box007", "Box008", "Box009", "Box013", "Box014") collect getNodeByName n
    local antes = for o in pecas collect InLab_AssinaturaCanal o 1
    local saida = createFile (pasta + "fase2.txt") encoding:#utf8
    for i = 1 to pecas.count do
    (
        local t0 = timeStamp()
        InLab_AutoUV #(pecas[i]) angulo:55.0 seamsOcultas:false resolucao:1024
        format "% · % ms · canal 1 idêntico: % · pai: % · %\n" pecas[i].name (timeStamp() - t0) \
            ((InLab_AssinaturaCanal pecas[i] 1) == antes[i]) pecas[i].parent \
            (InLab_UVMetricasTexto (InLab_MedirUV pecas[i] 3)) to:saida
    )
    close saida
    resetMaxFile #noPrompt
    pasta + "fase2.txt"
)
```

Leia `fase2.txt`. Esperado: canal 1 idêntico = `true` nas 5 peças e o pai igual ao de antes. As métricas são do pipeline provisório e **não** precisam bater a meta nesta fase, mas registre-as. Se o Box008 levar mais de alguns minutos, avise.

- [x] **Passo 5: pedir autorização, commit e PR da Fase 2**

```bash
git add ui/rollout_main.ms
git commit -m "feat(autouv): angulo flatten, seams ocultas e resolucao do bake na UI"
```

Com autorização: PR referenciando `#1` e comentário na issue com a tabela do `fase2.txt`.

---

### Tarefa 5 (fim da Fase 0/2): detalhar as Fases 3 a 5 neste plano

- [x] **Passo 1:** reescrever a seção abaixo com as APIs confirmadas e os números medidos (21/Set).

---

## O que a Fase 2 entregou de diferente do plano (21/Set, PR #2)

Quem for executar as Fases 3 a 5 parte de `functions/fn_autouv.ms` como ficou no PR #2, **não** do código da Tarefa 3. As diferenças estão no cabeçalho do arquivo:

- **Grupos:** `select o` num membro de grupo fechado seleciona o grupo todo, e o `modPanel.addModToSelection` antigo instanciava um Unwrap em 26 peças. Agora `InLab_AbrirGruposAcima` / `InLab_FecharGrupos` envolvem o Unwrap, e o modificador entra com `addModifier o`.
- **Relax:** saiu do pipeline. Sobre o flatten ele dobra faces (8 de 125 objetos). `InLab_TentarRelax` continua no arquivo para a Fase 4.
- **Instâncias:** a base instanciada não é convertida, e o Unwrap fica compartilhado. `InLab_Instancias` e `InLab_AutoUV_Registro` tratam o conjunto de instâncias.
- **Gutter:** o `pack` entrega 70–80% do espaçamento pedido. Em malha pequena, há até 3 repassadas medidas (`INLAB_UV_ESPACAMENTO_MAX = 8`).
- **Malha grande** (> `INLAB_UV_MEDIR_MAX_FACES = 30000` triângulos): o flatten usa espaçamento × `INLAB_UV_FOLGA_ESPACAMENTO = 1.4`, não há pack extra nem métricas completas, e só a sobreposição nativa (`selectOverlappedFaces`) é checada.
- **Canal 1:** o código confere `uvw.getMapChannel() == 3` e a contagem de vértices/faces de mapa (`InLab_ContagemCanal`). A assinatura completa ficou só nos testes.
- **Unfold3DPack:** ignora `unfoldRoomSpace` (gutter ~1 px com qualquer valor). Os valores `unfold*` que a issue lista para o ArchToolz são os padrões de fábrica de um Unwrap novo.

## Números de partida (Max 2024, 55°, 1024 px)

| Peça | Ilhas | Aproveitamento (Fase 2 / ArchToolz) | Densidade (Fase 2 / ArchToolz) | Distorção máx |
|---|---|---|---|---|
| Box013 | 6 | 50% / 58% | 1,03× / 1,17× | 1,55× |
| Box014 | 7 | 37% / 45% | 1,10× / 1,35× | 1,52× |
| Box007/009 | 8 | 23% / 24% | 1,05× / 1,54× | 1,68× |
| Box008 | 37 | 11% / 20% | 1,13× / 1,52× | 3,47× |
| " Armchair pillow 02" (306 mil tris) | — | não medido | não medido | — |

- **Tempo:** ~2,8 s por peça da cadeira. Na pillow 02: 44 s, contra ~30 s do ArchToolz. O `flattenMap` sozinho leva 40–55 s nessa malha; o Unfold3D completo leva 82 s.
- **Medição:** `InLab_MedirUV` leva 186 s na pillow 02. Serve para teste e validação, não para o Auto UV em malha grande.

## O que já foi confirmado para a Fase 3 (sondagem de 21/Set)

- Sobre base **Editable_Poly**, o Unwrap enxerga as mesmas arestas do `polyop`: 12 numa caixa, com a mesma numeração. `uvw.setSelectedGeomEdges <arestas do polyop>` seguido de `uvw.peltEdgeSelToSeam true` grava as seams exatamente nessas arestas (conferido com `getPeltSelectedSeams`).
- Sobre base **Editable_mesh**, o Unwrap enxerga 18 arestas numa caixa, diagonais incluídas, sem ligação direta com a numeração do mesh. Seams calculadas no mesh passam pelas diagonais dos triângulos, que é o defeito em escada do ArchToolz no Box014 (ele converte para mesh antes de abrir).
- `uvw.WeldAllShared()` junta o objeto numa ilha antes de cortar.
- **Ainda não achado:** o solver que respeita as seams do Pelt. `LSCMSolve()` e `Unfold3DSolve()` rodados depois de `peltEdgeSelToSeam` ignoraram as seams: a caixa com o topo cortado saiu como 1 ilha. `breakSelected()` depois de `peltSeamToEdgeSel` não pegou nenhuma aresta UV. Isso é o primeiro passo da Tarefa 6.

## Decisão do usuário (21/Set): base Editable_Poly

**Decidido: opção 1, manter `Editable_Poly`.** O Auto UV não converte mais a base para mesh. Isso muda `InLab_AutoUV_PrepararBase` na Tarefa 7 (Passo 5) e o teste "Base Editable_Poly virou Editable_mesh" de `tests/test_autouv.ms`, que passa a esperar `Editable_Poly`. Contexto da decisão:

**Base da peça.** A issue fixou "base convertida para `Editable_mesh`", igual ao ArchToolz. Seams que seguem edge loops precisam da topologia de polígonos, e sobre mesh a numeração não bate. Opções:
1. **Recomendado:** base `Editable_Poly` sem modificadores continua `Editable_Poly`, e o Auto UV não converte mais. O Reverter fica mais simples (só remove o Unwrap).
2. Converter para mesh depois de gravar o UV, perdendo as seams vivas no Unwrap.

A decisão muda `InLab_AutoUV_PrepararBase`. Peças que já chegam como `Editable_mesh` triangulado (as pillows do teste) não têm edge loops. Nelas, o caminho de seams por ângulo usa o fallback flatten da Fase 2.

## Restrições novas (valem para as Tarefas 6 a 9)

- **Orçamento de tempo:** o Auto UV completo leva no máximo 1,5× o ArchToolz. Referências: pillow 02 ≤ 45 s, e peças da cadeira ≤ 5 s cada. Laço em MaxScript sobre faces ou arestas precisa ter o custo medido em 300 mil faces antes de entrar. Acima de `INLAB_UV_MEDIR_MAX_FACES`, nada de `InLab_MedirUV` dentro do Auto UV.
- **Canal 1** idêntico, **grupos e instâncias** preservados, **Reverter** e **Ctrl+Z**: os testes da Fase 2 (`tests/test_autouv.ms`) continuam passando em toda tarefa.
- Só via MCP, conforme as Restrições globais do topo deste plano.

---

### Tarefa 6 (Fase 3, parte 1): sondagem do solver com seams e do custo das seams por ângulo

Sem código de produção. O entregável é `docs/superpowers/specs/2026-09-21-autouv-fase3-sondagem.md`, com as respostas e os tempos.

- [x] **Passo 1: achar a sequência que respeita as seams.** Numa cena vazia, rode o script abaixo. Ele prepara a caixa com o topo cortado e testa cada candidato. A resposta certa dá **2 ilhas**, 0 sobrepostas e distorção ≤ 1,2.

```maxscript
(
    resetMaxFile #noPrompt
    fileIn @"G:\Meu Drive\GitHub\InLabChecker\InLabChecker.ms"
    max modify mode
    fn preparar =
    (
        local b = Box length:20 width:20 height:20 mapcoords:true
        convertToPoly b
        local fTop = (for f = 1 to polyop.getNumFaces b where (polyop.getFaceNormal b f).z > 0.9 collect f)[1]
        select b
        local u = Unwrap_UVW()
        addModifier b u
        modPanel.setCurrentObject u
        u.setMapChannel 3
        local np = u.numberPolygons()
        u.selectFaces #{1..np}
        u.WeldAllShared()
        u.setSelectedGeomEdges (polyop.getEdgesUsingFace b #{fTop})
        u.peltEdgeSelToSeam true
        #(b, u, np)
    )
    fn resultado b = ( local m = InLab_MedirUV b 3 ; "ilhas " + m.nIlhas as string + " sobre " + m.sobrepostas as string + " dist " + (formattedPrint m.distorcaoMax format:".2f") )
    local candidatos = #(
        #("seams -> UV edge sel (modo aresta) -> break -> LSCM", fn c u np = ( u.setTVSubObjectMode 2 ; u.peltSeamToEdgeSel true ; u.uvEdgeSelect() ; u.breakSelected() ; u.setTVSubObjectMode 3 ; u.selectFaces #{1..np} ; u.LSCMSolve() )),
        #("RegularMapExpand #peltseams por ilha -> LSCM", fn c u np = ( u.selectFaces #{1} ; u.RegularMapExpand #peltseams ; u.LSCMSolve() )),
        #("LSCMInteractive false", fn c u np = ( u.selectFaces #{1..np} ; u.LSCMInteractive false ; u.LSCMSolve() )),
        #("Unfold3DSolve com a opção de seams do Pelt", fn c u np = ( u.selectFaces #{1..np} ; u.Unfold3DSolve() ))
    )
    local saida = openFile ((getDir #temp) + "\\inlab_fase3_solver.txt") mode:"wt"
    for c in candidatos do
    (
        local p = preparar()
        local ok = try ( c[2] c p[2] p[3] ; "ok" ) catch ( getCurrentException() )
        format "% · % · %\n" c[1] ok (resultado p[1]) to:saida
        delete p[1]
    )
    close saida
)
```

Se nenhum candidato der 2 ilhas, procure no dump `inlab_unwrap_api_26000.txt` da Fase 0 funções com "peel", "pelt" ou "quick", acrescente cada uma como candidato e rode de novo. **Se ainda assim nada respeitar as seams: pare e avise o usuário.** Sem isso, a Fase 3 precisa de outro desenho (por exemplo, cortar a malha em elementos antes do Unwrap), e essa decisão é dele.

- [x] **Passo 2 (substituído pela sondagem de 21/Set, ver o documento): custo das seams por ângulo e do corte de tubos.** Com o candidato vencedor, rode `InLab_SeamsPorAngulo` e `InLab_CortarTubos` da Tarefa 7 (o código está lá) num `Editable_Poly` de ~150 mil polígonos: `Sphere segs:400`, convertido. Anote o tempo de cada função e o do solver. Se a soma passar de 45 s, registre qual parte estoura. Essa parte ganha um caminho nativo ou um limite por tamanho na Tarefa 7.

- [x] **Passo 3: documento e comentário.** Escreva o documento da sondagem: a sequência vencedora com o código, os tempos e o que ficou de fora. Mostre ao usuário. Com autorização: `docs(autouv): registra sondagem do solver com seams (fase 3)` e comentário na issue #1.

---

### Tarefa 7 (Fase 3, parte 2): flatten sobre poly + `Unfold3DSolve` com guarda por ilha

**Redesenhada em 21/Set com a sondagem da Tarefa 6** (`docs/superpowers/specs/2026-09-21-autouv-fase3-sondagem.md`). O desenho anterior (seams por ângulo + Dijkstra) saiu: nenhum solver lê as seams do Pelt, e o flatten sobre poly já dá a abertura de artista das peças da issue. Aprovado pelo usuário.

**Arquivos:**
- Modificar: `functions/fn_autouv.ms` (base Editable_Poly; etapa nova "unfold com guarda" entre o flatten e o pack, só em malha pequena)
- Modificar: `tests/test_autouv.ms`

**Interfaces:**
- Consome: `InLab_MedirUV` (só no teste).
- Produz (todas `global`, em `fn_autouv.ms`):
  - `InLab_IlhasDoUnwrap uvw np` → Array de BitArrays de faces do Unwrap, uma por ilha UV (`selectElement` nativo).
  - `InLab_DistorcaoIlhas uvw ilhas` → Array de Float: max(r, 1/r) da pior face de cada ilha, r = densidade da face / densidade da ilha (`getArea` por face).
  - `InLab_UnfoldComGuarda uvw np` → Integer: nº de ilhas revertidas para o flatten, ou −1 se o `Unfold3DSolve` não estiver disponível.
  - `INLAB_UV_DISTORCAO_MAX_SOLVE = 2.0`: acima disto a ilha volta às posições do flatten.
- Muda: `InLab_AutoUV_PrepararBase`. `Editable_Poly` e `Editable_mesh` ficam como estão. Outras bases sem modificadores (primitivas) viram `Editable_Poly`, com cópia da original para o Reverter. Base com modificadores ou instanciada continua como na Fase 2.

- [x] **Passo 1: atualizar o teste.** Em `tests/test_autouv.ms`:
  - "Base Editable_Poly virou Editable_mesh" passa a ser `checar "Base Editable_Poly continua Editable_Poly" (classOf bPoly.baseObject == Editable_Poly)`.
  - "Base do objeto no grupo virou Editable_mesh" passa a ser `checar "Primitiva no grupo virou Editable_Poly" (classOf bGrupo.baseObject == Editable_Poly)`.
  - "Reverter: base volta a Editable_Poly" e "Reverter: mesmo nº de polígonos" continuam iguais (a base nem muda).
  - Acrescentar a seção abaixo antes da seção 6 (malha grande):

```maxscript
        -- 5b. UNFOLD COM GUARDA (Fase 3): flatten sobre poly + Unfold3DSolve por ilha
        local almof = ChamferBox name:"uv_almofada" length:40 width:40 height:12 fillet:3 filletSegs:3 mapcoords:true pos:[0, 220, 0]
        convertToPoly almof
        append criados almof
        local t0a = timeStamp()
        InLab_AutoUV #(almof) angulo:55.0 seamsOcultas:false resolucao:1024
        local msA = timeStamp() - t0a
        local mA = InLab_MedirUV almof INLAB_CANAL_UV_BAKE
        linha ("      uv_almofada: " + msA as string + " ms · " + InLab_UVMetricasTexto mA)
        checar "Almofada: base continua Editable_Poly" (classOf almof.baseObject == Editable_Poly)
        checar "Almofada: no máximo 6 ilhas (topo, fundo e tiras)" (mA.nIlhas <= 6)
        checar "Almofada: distorção ≤ 1,2 (o flatten sozinho dava ~1,6)" (mA.distorcaoMax <= 1.2)
        checar "Almofada: densidade ≤ 1,05" (mA.densidadeRazao <= 1.05)
        checar "Almofada: 0 sobrepostas, nada fora do 0–1" (mA.sobrepostas == 0 and mA.foraDe01 == 0)
        checar "Almofada: menos de 5 s" (msA < 5000)

        -- a guarda: distorção por ilha de um UV conhecido (caixa com flatten = 1,0)
        local cxG = Box name:"uv_guarda" length:20 width:20 height:20 mapcoords:true pos:[80, 220, 0]
        convertToPoly cxG
        append criados cxG
        max modify mode
        select cxG
        local uG = Unwrap_UVW()
        addModifier cxG uG
        modPanel.setCurrentObject uG
        uG.setMapChannel 3
        local npG = uG.numberPolygons()
        uG.selectFaces #{1..npG}
        uG.flattenMap 55.0 #([1,0,0], [-1,0,0], [0,1,0], [0,-1,0], [0,0,1], [0,0,-1]) 0.01 true 0 true true
        local ilG = InLab_IlhasDoUnwrap uG npG
        checar "Guarda: caixa tem 6 ilhas" (ilG.count == 6)
        checar "Guarda: distorção por ilha 1,0" ((for d in (InLab_DistorcaoIlhas uG ilG) where abs (d - 1.0) > 0.01 collect d).count == 0)
```

- [x] **Passo 2: rodar e ver falhar** (`InLab_IlhasDoUnwrap` indefinida e bases ainda convertidas para mesh).

- [x] **Passo 3: implementar em `functions/fn_autouv.ms`.**

Constante, junto das outras:

```maxscript
-- Acima disto (max(r, 1/r) da pior face) a ilha do Unfold3DSolve volta às
-- posições do flatten. O flatten puro não passou de 1,74 nas peças da issue.
global INLAB_UV_DISTORCAO_MAX_SOLVE = 2.0
```

Funções (antes de `InLab_AutoUV`, com `global` na linha de declarações):

```maxscript
--------------------------------------------------------------------------------
-- Ilhas UV do Unwrap ativo, como BitArrays de faces. selectElement nativo:
-- uma chamada por ilha (o union-find em MaxScript levava 2,7 s no Box008).
--------------------------------------------------------------------------------
fn InLab_IlhasDoUnwrap uvw np =
(
    local ilhas = #()
    local resta = #{1..np}
    uvw.setTVSubObjectMode 3
    while resta.numberSet > 0 do
    (
        local f0 = (for f in resta while true collect f)[1]
        uvw.selectFaces #{f0}
        uvw.selectElement()
        local s = uvw.getSelectedFaces()
        if s.numberSet == 0 do s = #{f0}
        append ilhas s
        resta -= s
    )
    ilhas
)

--------------------------------------------------------------------------------
-- Distorção de área por ilha: max(r, 1/r) da pior face, r = densidade da
-- face / densidade da ilha. Mesma definição de InLab_MedirUV, só que por ilha.
--------------------------------------------------------------------------------
fn InLab_DistorcaoIlhas uvw ilhas =
(
    for s in ilhas collect
    (
        local x, y, w, h, aUV, aG
        local totUV = 0.0, totG = 0.0
        local faces = #()
        for f in s do
        (
            uvw.getArea #{f} &x &y &w &h &aUV &aG
            append faces #(aUV, aG)
            totUV += aUV
            totG += aG
        )
        local dI = if totG > 1e-9 then totUV / totG else 0.0
        local pior = 1.0
        if dI > 1e-12 do
            for p in faces where p[2] > 1e-9 and p[1] > 1e-12 do
            (
                local r = (p[1] / p[2]) / dI
                pior = amax pior (amax r (1.0 / r))
            )
        if dI <= 1e-12 then 1e9 else pior
    )
)

--------------------------------------------------------------------------------
-- Unfold3DSolve sobre o flatten, com guarda: as ilhas que o solve degenera
-- (Box008: distorção 80×) voltam às posições do flatten. Devolve o nº de
-- ilhas revertidas, ou -1 se o solve não existir nesta build.
--------------------------------------------------------------------------------
fn InLab_UnfoldComGuarda uvw np =
(
    local ilhas = InLab_IlhasDoUnwrap uvw np
    local nUV = uvw.numberVertices()
    local posFlat = for v = 1 to nUV collect uvw.getVertexPosition 0 v
    uvw.selectFaces #{1..np}
    local ok = try ( uvw.Unfold3DSolve() ; true ) catch ( false )
    if not ok then -1
    else
    (
        local dist = InLab_DistorcaoIlhas uvw ilhas
        local revertidas = 0
        for i = 1 to ilhas.count where dist[i] > INLAB_UV_DISTORCAO_MAX_SOLVE do
        (
            uvw.selectFaces ilhas[i]
            uvw.faceToVertSelect()
            for v in (uvw.getSelectedVertices()) where v <= nUV do uvw.setVertexPosition 0 v posFlat[v]
            uvw.setTVSubObjectMode 3
            revertidas += 1
        )
        uvw.selectFaces #{1..np}
        revertidas
    )
)
```

Em `InLab_AutoUV_PrepararBase`, troque o `convertToMesh o` por:

```maxscript
            -- 21/Set (Fase 3, decisão do usuário): a base fica Editable_Poly. O Unwrap
            -- sobre poly usa a numeração de arestas do polyop e o flatten agrupa
            -- polígonos inteiros, sem a escada das diagonais de triângulo.
            original = copy o.baseObject
            convertToPoly o
```

e a condição `if classOf o.baseObject != Editable_mesh do` por `if classOf o.baseObject != Editable_Poly and classOf o.baseObject != Editable_mesh do`.

Em `InLab_AutoUV`, logo depois do flatten dar certo e antes do pack:

```maxscript
                        ------------------------------------------------------
                        -- 1b · UNFOLD COM GUARDA (Fase 3): só em malha pequena.
                        -- Na pillow 02 (306 mil tris) o solve sozinho leva 49 s.
                        ------------------------------------------------------
                        if not grande do
                        (
                            local rev = InLab_UnfoldComGuarda uvw nPolysUV
                            if rev < 0 then
                                InLab_Log (o.name + ": Unfold3DSolve indisponível — fica o flatten.") tipo:#warn
                            else
                                metodo += " → Unfold3D" + (if rev > 0 then " (" + rev as string + " ilha(s) voltaram ao flatten)" else "")
                        )
```

Atualize o cabeçalho do arquivo com um bloco "21/Set (Fase 3)", no padrão dos outros.

- [x] **Passo 4: rodar os testes.** Rode `test_autouv` e `test_verif_uv`. Esperado: TUDO OK.

- [x] **Passo 5: medir nas peças reais.** Rode a cadeira inteira de `01.max` com o script de validação da Fase 2. Esperado:
  - canal 1 idêntico;
  - 0 sobrepostas além das 2 peças conhecidas (Box002, Box063);
  - Box013 com 6 ilhas e distorção ≤ 1,1;
  - ≤ 5 s por peça em média.

  Mostre ao usuário a tabela das peças da issue (Fase 2 × Fase 3 × ArchToolz) e capturas do UV do Box013 e do Box014.

- [ ] **Passo 6:** com autorização, `feat(autouv): base editable poly e unfold3d com guarda por ilha`.

---

### Tarefa 7b (Fase 3, parte 3): seams nas regiões ocultas — sondagem

O flatten decide sozinho onde corta. Antes de ter código, uma sondagem curta testa na almofada (ChamferBox) e no Box013:
- **Costura de ilhas:** juntar duas ilhas vizinhas do flatten pela borda que elas dividem (`selectFaces` das duas + `WeldSelectedShared` só nos vértices da borda visível), rodar `InLab_UnfoldComGuarda` e aceitar se a distorção ficar ≤ 1,2. As bordas candidatas são as de ocultação baixa (frente −Y, topo +Z); as de ocultação alta (fundo −Z, traseira +Y) ficam como corte.
- **Critério de saída:** na almofada, as seams laterais passam para a face de trás e de baixo, e as métricas não pioram mais que 0,05× em distorção e densidade.

Se funcionar, vira a Tarefa 7c no mesmo formato da Tarefa 7. Se não, avise o usuário: o checkbox "Preferir seams em regiões ocultas" ficaria sem efeito, e ele decide se sai da UI.

---

### Tarefa 8 (Fase 4): organizar e empacotar

**Arquivos:** modificar `functions/fn_autouv.ms` (etapa 2) e `tests/test_autouv.ms`.

**Interfaces:**
- Consome: a etapa 1 da Tarefa 7.
- Produz: `InLab_OrganizarIlhas uvw` (straighten + alinhamento 0°/90° + densidade uniforme) e `InLab_EmpacotarUV uvw padding` (pack sem rotação livre, gutter ≥ padding e borda ≥ padding/2).

APIs confirmadas na Fase 0: `Straighten()`, `RotateSelectedCenter <float>`, `alignByPivotHorizontal()`/`alignByPivotVertical()`, `RescaleCluster <bitArray> <node>`, `pack <method> <spacing> <normalize> <rotate> <fillholes>`.

- [ ] **Passo 1: testes de métrica.** Em `tests/test_autouv.ms`, depois da seção 1, acrescente para `uv_poly`, `uv_grupo` e `uv_cil`:

```maxscript
        -- Fase 4: densidade uniforme e gutter/borda pela resolução
        for o in objs do
        (
            local m = InLab_MedirUV o INLAB_CANAL_UV_BAKE
            checar (o.name + ": densidade ≤ 1,10×") (m.densidadeRazao <= 1.10)
            checar (o.name + ": borda ≥ metade do padding") (m.bordaMin >= (InLab_PaddingUV 1024) / 2.0 * 0.98)
        )
```

- [ ] **Passo 2: implementar.** Em `fn_autouv.ms`, depois da etapa 1:

```maxscript
-- Densidade uniforme, straighten das ilhas quase retas e alinhamento ao
-- eixo. Tudo nativo: nada de laço por face em MaxScript.
fn InLab_OrganizarIlhas uvw o =
(
    local np = uvw.numberPolygons()
    uvw.selectFaces #{1..np}
    -- RescaleCluster não entra: a densidade já sai ~1,0 do Unfold3DSolve (Tarefa 7) e
    -- ele não corrigiu ilhas com escala diferente na sondagem.
    try ( uvw.Straighten() ) catch ( InLab_Log (o.name + ": Straighten indisponível.") tipo:#warn )
    try ( uvw.alignByPivotHorizontal() ) catch ( InLab_Log (o.name + ": alinhamento indisponível.") tipo:#warn )
)

-- Pack sem rotação livre (0°/90° já vêm do alinhamento), com a correção de
-- gutter da Fase 2 para malha pequena.
fn InLab_EmpacotarUV uvw padding =
(
    local np = uvw.numberPolygons()
    uvw.selectFaces #{1..np}
    uvw.pack 1 padding true false true
)
```

Chame `InLab_OrganizarIlhas uvw o` logo depois da etapa 1. Troque o `uvw.pack 1 padding true true true` da etapa 2 por `InLab_EmpacotarUV uvw padding`, mantendo a correção de gutter. Para a borda, depois do pack, escale tudo em `(1 − padding)` a partir do centro (0,5; 0,5) com `uvw.ScaleSelectedCenter (1.0 - padding) 0`.

- [ ] **Passo 3: rodar e medir.** Rode os três testes e a cadeira inteira. Se `densidade ≤ 1,10×` falhar com o `RescaleCluster`, **pare e traga os números** (a issue prevê relaxar a meta). O mesmo vale se o aproveitamento ficar abaixo do ArchToolz em mais de 5 pontos na média das peças da issue.

- [ ] **Passo 4:** com autorização, `feat(autouv): densidade uniforme, alinhamento e pack sem rotacao`.

---

### Tarefa 9 (Fase 5): validação final

- [ ] **Passo 1:** rode todos os critérios de aceite da issue nas peças Box007/008/009/013/014 e na cadeira inteira de `01.max`, e também na " Armchair pillow 02" (só tempo e sobreposição nativa, pelo tamanho). Monte a tabela atual × ArchToolz × novo por peça, no formato da tabela da issue.
- [ ] **Passo 2:** capture o template UV do Box008, do Box013 e do Box014 (`renderUV` do Unwrap, 1024 px) e compare com o ArchToolz lado a lado.
- [ ] **Passo 3:** peça ao usuário para conferir pela UI numa peça real e no Max 2027, se disponível.
- [ ] **Passo 4:** com autorização, comentário na issue #1 com a tabela e as capturas, e PR das Fases 3 a 5.

**Pontos de parada:** nenhum solver respeita as seams (Tarefa 6); o orçamento de tempo estoura sem caminho nativo (Tarefa 7); a densidade ≤ 1,10× ou o aproveitamento fica inalcançável (Tarefa 8).
