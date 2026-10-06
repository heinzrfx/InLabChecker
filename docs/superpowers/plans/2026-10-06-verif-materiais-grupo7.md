# Grupo 7 · Verificações de materiais — Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIA: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para implementar este plano task a task. Os passos usam checkbox (`- [ ]`).

**Objetivo:** ligar ao motor de verificação as sete checagens de material do grupo 7 (V-23, V-24, V-25, V-35, V-36, V-37, V-38), lendo o material Corona de origem.

**Arquitetura:** arquivo novo `verifications/verif_materiais.ms`. O perfil de slots por tipo de material (Physical, Legacy, VRay) sai de dentro do conversor (`fn_material_convert.ms`) para `InLab_Material_PerfilSlots`, que o conversor e as verificações usam. O uso de material por face é calculado uma vez (`InLab_Mat_Uso`) e compartilhado pela V-25, V-37 e V-38; os materiais resolvidos (Multi/Sub aberto, Layered pelo base) alimentam a V-23, V-24, V-35 e V-36.

**Tech stack:** MaxScript, 3ds Max 2024, Corona 12, VRay (opcional). Testes rodam dentro do Max pelo MCP do 3ds Max.

**Spec:** `docs/superpowers/specs/2026-10-06-verif-materiais-grupo7-design.md` (ler antes de começar).

## Restrições globais

- Código, comentários, log e mensagens em português. Commits em português, sem acento no assunto, `feat(verif): ...` / `refactor(material): ...` / `test(verif): ...`, terminando com a linha `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Funções públicas com prefixo `InLab_`; constantes `INLAB_MAIUSCULO`. Tudo global, sem módulos. Nomes são case-insensitive: não reutilize um nome de variável que difira só por maiúsculas (ex.: `P` e `p` no mesmo escopo são a mesma variável).
- **As verificações leem o material Corona, não o glTF Material.**
- **Qualquer mapa conta como slot preenchido**, procedural incluído; toda checagem percorre a árvore inteira do slot (`InLab_Produto_ColetarMapas`).
- **V-23 não reprova material com um mapa só** (só base color é exceção válida).
- **V-24 não reprova PNG em material que precisa de alpha:** palha (`InLab_DetectarEspecial` = `#palha`) ou com algum mapa no slot de opacidade.
- **V-36 nunca reprova por valor** (refração, roughness, IOR livres); só confere se a refração está ligada.
- Severidade: V-24 e V-25 críticas (`critico:true`); V-23, V-35, V-36, V-37 advertência provisória (`critico:true provisorio:true`); V-38 advertência (`critico:false`).
- Falha ao ler um material ou objeto nunca passa em silêncio: vira "não medido" (`passou:false critico:false`), vai para o log e o laço segue.
- Listas nas mensagens: no máximo 8 itens com `InLab_ListaResumida` (`core/utils.ms`).
- Cabeçalho `/* === ... === */` em arquivo novo e histórico datado (06/10/2026) em arquivo alterado.
- Safe mode do MCP: nada de `createFile`/`copyFile`/`deleteFile` no código enviado pelo `execute_maxscript` (o arquivo de teste pode usar, porque roda por `fileIn`).

### Como rodar um teste (usado em todas as tasks)

Pelo MCP (`execute_maxscript`), numa chamada:

```maxscript
(
local n = "verif_materiais"   -- nome do teste sem "test_"
resetMaxFile #noPrompt
local arq = (getDir #temp) + "\\inlab_test_" + n + ".txt"
local erro = ""
try (fileIn (@"G:\Meu Drive\GitHub\InLabChecker\tests\test_" + n + ".ms")) catch (erro = getCurrentException())
local p = 0, f = 0, falhas = ""
local fs = openFile arq
if fs != undefined do (
  while not eof fs do (
    local l = readLine fs
    if matchPattern l pattern:"PASS*" then p += 1
    else if matchPattern l pattern:"FAIL*" or matchPattern l pattern:"EXCE*" do (f += 1; falhas += "\n   " + l)
  )
  close fs
)
resetMaxFile #noPrompt
n + ": " + p as string + " PASS, " + f as string + " FAIL" + (if erro != "" then " ERRO " + erro else "") + falhas
)
```

Exceções: `test_renomear_produto.ms` grava em `inlab_test_renomear.txt` (ler pelo shell).

## Pré-requisito

O PR #107 (grupo 6) precisa estar na `main` antes da **Task 7**. As Tasks 1 a 6 não dependem dele. Antes da Task 7: `git fetch && git rebase origin/main` (a branch só tem commits de spec, plano e arquivos novos até ali; o conflito esperado é nenhum).

## Foco de revisão

1. **Material com sub-material `undefined` no Multi/Sub e face apontando para ele** → a V-25 deve listar "objeto: ID n sem sub-material", nunca lançar. (Teste na Task 4.)
2. **Objeto sem material (`o.material == undefined`)** → ignorado por todas as checagens, sem exceção. (Teste na Task 2.)
3. **Layered sem material base legível** → vira tipo `#outro` (advertência na V-23 "não convertível"), sem exceção. (Teste na Task 2.)
4. **Bitmap com caminho vazio ou `undefined`** (`Bitmaptexture()` sem arquivo) → `InLab_Mat_ArquivoDoMapa` devolve `undefined` e a V-24 ignora, sem exceção. (Teste na Task 3.)
5. **Mesmo material em vários objetos e em vários slots de Multi/Sub** → aparece uma vez só nas mensagens. (Teste na Task 3.)

---

### Task 1: Perfil de slots compartilhado (`InLab_Material_PerfilSlots`)

**Files:**
- Modify: `functions/fn_material_convert.ms` (cabeçalho; nova função antes de `InLab_ConverterCoronaMtl`; linhas ~444-481 de `InLab_ConverterCoronaMtl`)
- Create: `tests/test_verif_materiais.ms`

**Interfaces:**
- Produz: `struct PerfilSlots (cor, mapaBase, valGloss, mapaGloss, bump, opacMapa, refrVal, ior)` — cada campo é um array de nomes de propriedade (`#(#texmapDiffuse)`), na ordem de tentativa.
- Produz: `fn InLab_Material_PerfilSlots tipo` — `tipo` é `#physical | #legacy | #vray | #outro`; devolve `PerfilSlots`. `#outro` e `#physical` devolvem o perfil Physical (mesmo comportamento do `default` atual do conversor).

- [ ] **Step 1: Criar o arquivo de teste com o caso do perfil**

`tests/test_verif_materiais.ms`:

```maxscript
/*
 tests\test_verif_materiais.ms — teste do grupo 7 de verificações (issue #103)
 Spec: docs\superpowers\specs\2026-10-06-verif-materiais-grupo7-design.md
 RODAR NUMA CENA VAZIA (File > New): cria e apaga os objetos de cada caso.
 Resultado: <pasta temp do Max>\inlab_test_verif_materiais.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_VerifResults, InLab_ResetarResultados, InLab_ObterFamilia
global InLab_Material_PerfilSlots, InLab_TipoDeMaterial, InLab_ParseJSON, InLab_Produto_Lista
global InLab_Mat_Uso, InLab_Mat_Resolver, InLab_Mat_MapasDoSlot, InLab_Mat_ArquivoDoMapa
global InLab_V23_SlotsPBR, InLab_V24_PNG, InLab_V25_IDsDeMaterial
global InLab_V35_Palha, InLab_V36_Cristal, InLab_V37_ZonasEstofado, InLab_V38_TampoAcessorio
global InLab_TampoAcessorioProduto
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_verif_materiais.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn statusDe idV =
    (
        local achado = #ausente
        for r in InLab_VerifResults where r.id == idV do achado = r.status
        achado
    )
    fn mensagemDe idV =
    (
        local achado = ""
        for r in InLab_VerifResults where r.id == idV do achado = r.mensagem
        achado
    )
    fn limparCena = ( delete (for o in objects collect o) )
    fn tem txt trecho = (findString txt trecho) != undefined

    local logOriginal = InLab_Log
    local unidadeOriginal = units.SystemType

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms",
                   @"familias\familia_corpo_unico.ms", @"familias\familia_pernas_tampo.ms", @"familias\familia_estrutura_estofado.ms",
                   @"functions\fn_json.ms", @"functions\fn_renomear_produto.ms", @"functions\fn_material_convert.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        units.SystemType = #Centimeters
        limparCena()

        ---------------------------------------------------------------- perfil
        local pl = InLab_Material_PerfilSlots #legacy
        checar "Perfil Legacy: base = texmapDiffuse" (pl.mapaBase[1] == #texmapDiffuse)
        checar "Perfil Legacy: gloss = texmapReflectGlossiness" (pl.mapaGloss[1] == #texmapReflectGlossiness)
        checar "Perfil Legacy: bump = texmapBump, opacidade = texmapOpacity, refração = levelRefract" (pl.bump[1] == #texmapBump and pl.opacMapa[1] == #texmapOpacity and pl.refrVal[1] == #levelRefract)
        local pp = InLab_Material_PerfilSlots #physical
        checar "Perfil Physical: base = baseTexmap, roughness = baseRoughnessTexmap" (pp.mapaBase[1] == #baseTexmap and pp.mapaGloss[1] == #baseRoughnessTexmap)
        local pv = InLab_Material_PerfilSlots #vray
        checar "Perfil VRay: base = texmap_diffuse, opacidade = texmap_opacity" (pv.mapaBase[1] == #texmap_diffuse and pv.opacMapa[1] == #texmap_opacity)
        checar "Perfil #outro = Physical" ((InLab_Material_PerfilSlots #outro).mapaBase[1] == #baseTexmap)
        -- Os nomes do perfil existem de verdade nos materiais da build.
        local mL = CoronaLegacyMtl()
        checar "Perfil Legacy: todos os slots de mapa existem no CoronaLegacyMtl" ((for n in #(pl.mapaBase[1], pl.mapaGloss[1], pl.bump[1], pl.opacMapa[1], pl.refrVal[1]) where not (isProperty mL n) collect n).count == 0)
        local mP = CoronaPhysicalMtl()
        checar "Perfil Physical: todos os slots de mapa existem no CoronaPhysicalMtl" ((for n in #(pp.mapaBase[1], pp.mapaGloss[1], pp.bump[1], pp.opacMapa[1], pp.refrVal[1]) where not (isProperty mP n) collect n).count == 0)

        -- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    try ( limparCena() ) catch ()
    units.SystemType = unidadeOriginal
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
```

- [ ] **Step 2: Rodar e ver falhar**

Rodar `verif_materiais` (snippet das Restrições globais). Esperado: `EXCEÇÃO` com "Call needs function or class, got: undefined" (`InLab_Material_PerfilSlots` não existe).

- [ ] **Step 3: Implementar o perfil**

Em `functions/fn_material_convert.ms`, logo antes do bloco de comentário de `InLab_ConverterCoronaMtl` ("Converte UM CoronaPhysicalMtl em glTF Material"), inserir:

```maxscript
--------------------------------------------------------------------------------
-- 06/10/2026 (issue #103): nomes de propriedade por tipo de material, em
-- ordem de tentativa (InLab_PropSafe). Usado pela conversão e pelas
-- verificações do grupo 7 (verif_materiais.ms), para as duas lerem
-- exatamente os mesmos slots. #outro devolve o perfil Physical (era o
-- "default" da conversão).
--------------------------------------------------------------------------------
struct PerfilSlots ( cor, mapaBase, valGloss, mapaGloss, bump, opacMapa, refrVal, ior )

fn InLab_Material_PerfilSlots tipo =
(
    case tipo of
    (
        #legacy: PerfilSlots cor:#(#colorDiffuse, #diffuse) mapaBase:#(#texmapDiffuse) \
            valGloss:#(#reflectGlossiness, #levelReflectGlossiness) mapaGloss:#(#texmapReflectGlossiness) \
            bump:#(#texmapBump) opacMapa:#(#texmapOpacity) refrVal:#(#levelRefract) ior:#(#ior, #fresnelIor)
        #vray: PerfilSlots cor:#(#diffuse) mapaBase:#(#texmap_diffuse) \
            valGloss:#(#reflection_glossiness) mapaGloss:#(#texmap_reflectionGlossiness, #texmap_reflection_glossiness) \
            bump:#(#texmap_bump) opacMapa:#(#texmap_opacity) refrVal:#(#refraction_amount) ior:#(#refraction_ior)
        default: PerfilSlots cor:#(#baseColor) mapaBase:#(#baseTexmap) \
            valGloss:#(#baseRoughness, #roughness) mapaGloss:#(#baseRoughnessTexmap, #roughnessTexmap) \
            bump:#(#baseBumpTexmap, #bumpTexmap) opacMapa:#(#opacityTexmap) refrVal:#(#refractionAmount, #refraction) ior:#(#ior)
    )
)
```

(O `refrVal` do VRay continua `#(#refraction_amount)`, igual ao conversor de hoje: a sondagem de 06/10/2026 mostrou que essa propriedade não existe no VRayMtl, mas corrigir o conversor está fora deste grupo. A V-36 lê a cor `#refraction` do VRay direto, Task 5.)

Em `InLab_ConverterCoronaMtl`, substituir o bloco das linhas `local candCor = #(#baseColor)` até o `)` que fecha o `case tipoMtl of` (inclusive) por:

```maxscript
        local perfil = InLab_Material_PerfilSlots tipoMtl
        local candCor       = perfil.cor
        local candMapaBase  = perfil.mapaBase
        local candValGloss  = perfil.valGloss
        local candMapaGloss = perfil.mapaGloss
        local candBump      = perfil.bump
        local candOpacMapa  = perfil.opacMapa
        local candRefrVal   = perfil.refrVal
        local candIOR       = perfil.ior
        case tipoMtl of
        (
            #legacy: InLab_Log (mtl.name + ": perfil CoronaLegacyMtl (workflow glossiness).")
            #vray: InLab_Log (mtl.name + ": perfil VRayMtl (workflow glossiness).")
            default: ()
        )
```

No cabeçalho do arquivo, depois da nota de 24/09/2026 (issue #52), acrescentar:

```
 06/10/2026 (issue #103): o perfil de propriedades por tipo de material saiu
 de InLab_ConverterCoronaMtl para InLab_Material_PerfilSlots, compartilhado
 com as verificações do grupo 7. Sem mudança de comportamento. Achado na
 sondagem: o VRayMtl não tem refraction_amount (a refração é a cor
 "refraction"), então a conversão não liga transmission em vidro VRay.
```

- [ ] **Step 4: Rodar e ver passar**

Rodar `verif_materiais`. Esperado: 8 PASS, 0 FAIL. Rodar também `material_convert` e `material_utils`. Esperado: 0 FAIL em ambos (mesmas contagens de antes: 25 e 20 PASS).

- [ ] **Step 5: Commit**

```bash
git add functions/fn_material_convert.ms tests/test_verif_materiais.ms
git commit -m "refactor(material): perfil de slots compartilhado com as verificacoes (#103)"
```

---

### Task 2: Módulo `verif_materiais.ms` e os helpers de material

**Files:**
- Create: `verifications/verif_materiais.ms`
- Modify: `InLabChecker.ms` (manifesto `INLAB_MODULOS`, depois de `@"verifications\verif_mapeamento.ms",`)
- Modify: `tests/test_verif_materiais.ms` (lista de `fileIn` e casos)

**Interfaces:**
- Consome: `InLab_Material_PerfilSlots`, `InLab_TipoDeMaterial`, `InLab_DetectarEspecial`, `InLab_PropSafe`, `InLab_ClasseContem` (`fn_material_convert.ms`); `InLab_Produto_ColetarMapas` (`fn_renomear_produto.ms`).
- Produz:
  - `struct MatUso (usados = #(), orfaos = #(), naoMedidos = #())` — `usados`: materiais (sub-material de Multi/Sub ou material direto) com pelo menos uma face; `orfaos`: strings `"<obj>: ID <n> sem sub-material"`; `naoMedidos`: strings `"<obj> (<exceção>)"`.
  - `fn InLab_Mat_Uso objetos` → `MatUso`.
  - `struct MatInfo (mtl, base, tipo, especial)` — `mtl`: o material usado (o nome vale para mensagens e palavras-chave); `base`: material lido nos slots (o próprio, ou o base de um Layered; `undefined` se o Layered não tem base); `tipo`: `#physical|#legacy|#vray|#outro`; `especial`: `#palha|#cristal|#nenhum`.
  - `fn InLab_Mat_Resolver uso` → array de `MatInfo`, um por material de `uso.usados`.
  - `fn InLab_Mat_MapasDoSlot info campo` — `campo`: nome de campo de `PerfilSlots` (`#mapaBase`, `#mapaGloss`, `#bump`, `#opacMapa`); devolve array de todos os texmaps da árvore do slot (`#()` se vazio ou tipo `#outro`).
  - `fn InLab_Mat_ArquivoDoMapa tm` → caminho (string não vazia) de `Bitmaptexture` ou `CoronaBitmap`, senão `undefined`.
  - `fn InLab_Mat_Registrar idV titulo problemas naoMedidos okMsg critico:true provisorio:false` — registra no padrão do grupo 5.

- [ ] **Step 1: Escrever os testes dos helpers**

Em `tests/test_verif_materiais.ms`, acrescentar `@"verifications\verif_materiais.ms"` no fim da lista de `fileIn` e, no lugar de `-- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI`, inserir (mantendo a linha-marcador no fim):

```maxscript
        ---------------------------------------------------------------- helpers
        fn caixa nome p = ( local b = Box name:nome length:10 width:10 height:10 mapcoords:true pos:p; convertToPoly b; b )
        fn legacyCom nome difuso = ( local m = CoronaLegacyMtl(); m.name = nome; m.texmapDiffuse = difuso; m )
        -- Material direto: usado. Objeto sem material: ignorado.
        local m1 = legacyCom "Madeira" (CoronaColor())
        local b1 = caixa "b1" [0, 0, 0]
        b1.material = m1
        local b0 = caixa "b0" [30, 0, 0]
        local uso = InLab_Mat_Uso #(b1, b0)
        checar "Uso: material direto entra, objeto sem material é ignorado" (uso.usados.count == 1 and uso.usados[1] == m1 and uso.orfaos.count == 0 and uso.naoMedidos.count == 0)
        -- Multi/Sub: só os sub-materiais com faces entram.
        local mm = Multimaterial numsubs:3
        mm.materialList[1] = legacyCom "Tecido" (CoronaColor())
        mm.materialList[2] = legacyCom "Metal" (CoronaColor())
        mm.materialList[3] = legacyCom "Sem faces" (CoronaColor())
        local b2 = caixa "b2" [60, 0, 0]
        for f = 1 to (polyop.getNumFaces b2) do polyop.setFaceMatID b2 f (if f <= 3 then 1 else 2)
        b2.material = mm
        uso = InLab_Mat_Uso #(b2)
        checar "Uso: Multi/Sub entra pelos sub-materiais com faces (2 de 3)" (uso.usados.count == 2 and (findItem uso.usados mm.materialList[3]) == 0)
        -- Mesmo material em dois objetos: uma vez só.
        local b3 = caixa "b3" [90, 0, 0]
        b3.material = m1
        uso = InLab_Mat_Uso #(b1, b3)
        checar "Uso: mesmo material em dois objetos aparece uma vez" (uso.usados.count == 1)
        -- Resolver: tipo, especial e Layered.
        local mPalha = legacyCom "Palha natural" (CoronaColor())
        local lay = CoronaLayeredMtl()
        lay.name = "Camadas"
        lay.baseMtl = legacyCom "Base do layered" (CoronaColor())
        local layVazio = CoronaLayeredMtl()
        layVazio.name = "Camadas sem base"
        local mStd = StandardMaterial name:"Padrao"
        b1.material = mPalha
        b2.material = lay
        b3.material = mStd
        local b4 = caixa "b4" [120, 0, 0]
        b4.material = layVazio
        local infos = InLab_Mat_Resolver (InLab_Mat_Uso #(b1, b2, b3, b4))
        fn infoDe infos nome = ( local r = undefined; for i in infos where i.mtl.name == nome do r = i; r )
        checar "Resolver: Legacy com palavra palha = #legacy/#palha" ((infoDe infos "Palha natural").tipo == #legacy and (infoDe infos "Palha natural").especial == #palha)
        checar "Resolver: Layered lido pelo material base" ((infoDe infos "Camadas").tipo == #legacy and (infoDe infos "Camadas").base.name == "Base do layered")
        checar "Resolver: Layered sem base vira #outro, sem exceção" ((infoDe infos "Camadas sem base").tipo == #outro and (infoDe infos "Camadas sem base").base == undefined)
        checar "Resolver: Standard vira #outro" ((infoDe infos "Padrao").tipo == #outro)
        -- Árvore do slot: o bitmap dentro do CoronaMix aparece.
        local mix = CoronaMix()
        local bmt = Bitmaptexture filename:((getDir #temp) + "\\inlab_v24_dentro.png")
        setSubTexmap mix 1 bmt
        local mArv = legacyCom "Arvore" mix
        b1.material = mArv
        local iArv = (InLab_Mat_Resolver (InLab_Mat_Uso #(b1)))[1]
        local mapas = InLab_Mat_MapasDoSlot iArv #mapaBase
        checar "MapasDoSlot: percorre a árvore (CoronaMix + bitmap)" ((findItem mapas mix) > 0 and (findItem mapas bmt) > 0)
        checar "MapasDoSlot: slot vazio devolve #()" ((InLab_Mat_MapasDoSlot iArv #bump).count == 0)
        checar "ArquivoDoMapa: Bitmaptexture devolve o caminho" ((InLab_Mat_ArquivoDoMapa bmt) == bmt.filename)
        local cbm = CoronaBitmap()
        cbm.filename = (getDir #temp) + "\\inlab_v24_corona.png"
        checar "ArquivoDoMapa: CoronaBitmap devolve o caminho" ((InLab_Mat_ArquivoDoMapa cbm) == cbm.filename)
        checar "ArquivoDoMapa: procedural devolve undefined" ((InLab_Mat_ArquivoDoMapa mix) == undefined)
        checar "ArquivoDoMapa: Bitmaptexture sem arquivo devolve undefined" ((InLab_Mat_ArquivoDoMapa (Bitmaptexture())) == undefined)
        limparCena()

        -- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI
```

- [ ] **Step 2: Rodar e ver falhar**

Rodar `verif_materiais`. Esperado: `EXCEÇÃO` no `fileIn` ("can't open file ... verif_materiais.ms").

- [ ] **Step 3: Criar `verifications/verif_materiais.ms`**

```maxscript
/*
================================================================================
 verifications\verif_materiais.ms — Grupo 7 · V-23, V-24, V-25, V-35, V-36,
                                    V-37, V-38 (materiais)
--------------------------------------------------------------------------------
 Spec: docs\superpowers\specs\2026-10-06-verif-materiais-grupo7-design.md
 (issue #103).

 Lê o material CORONA de origem, não o glTF Material: o acervo é Corona e a
 conversão (fn_material_convert.ms) herda tudo dele. Os slots são os mesmos
 que a conversão lê (InLab_Material_PerfilSlots). Qualquer mapa conta como
 slot preenchido, procedural incluído, e a árvore inteira do slot é
 percorrida (InLab_Produto_ColetarMapas).

 06/10/2026 — sondagem do piloto (Max 2024): quase tudo CoronaLegacyMtl, o
 Puff Pol inteiro em VRayMtl, nenhum CoronaPhysicalMtl; slots procedurais
 (CoronaColorCorrect, CoronaMix, CoronaTriplanar, CoronaColor), quase nenhum
 bitmap direto. O CoronaLegacyMtl não tem propriedade de 2-sided e o VRayMtl
 não tem refraction_amount (a refração é a cor "refraction").
================================================================================
*/

-- Uso de material pelas faces, calculado uma vez e compartilhado pela V-25,
-- V-37 e V-38. usados: material direto ou sub-material de Multi/Sub com pelo
-- menos uma face. orfaos: "obj: ID n sem sub-material". naoMedidos: falhas.
struct MatUso ( usados = #(), orfaos = #(), naoMedidos = #() )

fn InLab_Mat_Uso objetos =
(
    local uso = MatUso()
    for o in objetos where o.material != undefined do
    (
        try
        (
            local m = o.material
            if classof m == Multimaterial then
            (
                local malha = snapshotAsMesh o
                local ids = #{}
                for f = 1 to malha.numfaces do ids[getFaceMatID malha f] = true
                delete malha
                for id in ids do
                (
                    local idx = findItem m.materialIDList id
                    local sub = if idx > 0 then m.materialList[idx] else undefined
                    if sub == undefined then append uso.orfaos (o.name + ": ID " + id as string + " sem sub-material")
                    else appendIfUnique uso.usados sub
                )
            )
            else appendIfUnique uso.usados m
        )
        catch
        (
            local erro = getCurrentException()
            append uso.naoMedidos (o.name + " (" + erro + ")")
            InLab_Log (o.name + ": material não lido — " + erro) tipo:#err
        )
    )
    uso
)

-- mtl: o material usado (nome para mensagens e palavras-chave). base: o que
-- se lê nos slots (o próprio, ou o base de um Layered). tipo: #physical,
-- #legacy, #vray ou #outro (a conversão não suporta). especial: #palha,
-- #cristal ou #nenhum (mesmas palavras da conversão).
struct MatInfo ( mtl, base, tipo, especial )

fn InLab_Mat_Resolver uso =
(
    for m in uso.usados collect
    (
        local base = m
        if InLab_ClasseContem m "CoronaLayeredMtl" do base = InLab_PropSafe m #(#baseMtl, #baseMaterial, #base)
        local tipo = if base == undefined then #outro else InLab_TipoDeMaterial base
        MatInfo mtl:m base:base tipo:tipo especial:(InLab_DetectarEspecial m.name)
    )
)

-- Todos os texmaps da árvore do slot `campo` (#mapaBase, #mapaGloss, #bump,
-- #opacMapa). #() se o slot está vazio ou o tipo é #outro.
fn InLab_Mat_MapasDoSlot info campo =
(
    if info.tipo == #outro then #()
    else
    (
        local nomes = getProperty (InLab_Material_PerfilSlots info.tipo) campo
        local tm = InLab_PropSafe info.base nomes
        if tm == undefined then #() else InLab_Produto_ColetarMapas tm #()
    )
)

-- Caminho do arquivo de Bitmaptexture ou CoronaBitmap; undefined se não é
-- mapa de arquivo ou se o caminho está vazio.
fn InLab_Mat_ArquivoDoMapa tm =
(
    local arq = undefined
    if classof tm == Bitmaptexture or (InLab_ClasseContem tm "CoronaBitmap") do
        arq = try ( tm.filename ) catch ( undefined )
    if arq == undefined or arq == "" then undefined else arq
)

-- Registro no padrão do grupo 5: problema → falha (critico/provisorio);
-- só "não medido" → advertência; senão passa com okMsg.
fn InLab_Mat_Registrar idV titulo problemas naoMedidos okMsg critico:true provisorio:false =
(
    if problemas.count > 0 then
        InLab_RegistrarVerif idV titulo false (InLab_ListaResumida (problemas + naoMedidos)) critico:critico provisorio:provisorio
    else if naoMedidos.count > 0 then
        InLab_RegistrarVerif idV titulo false ("não medido: " + InLab_ListaResumida naoMedidos) critico:false
    else
        InLab_RegistrarVerif idV titulo true okMsg critico:critico provisorio:provisorio
)
```

No manifesto de `InLabChecker.ms`, depois da linha `@"verifications\verif_mapeamento.ms",`, inserir:

```maxscript
            -- grupo 7 de materiais (issue #103): usa fn_material_convert e fn_renomear_produto
            @"verifications\verif_materiais.ms",
```

- [ ] **Step 4: Rodar e ver passar**

Rodar `verif_materiais`. Esperado: 0 FAIL (8 do perfil + 15 dos helpers).

- [ ] **Step 5: Commit**

```bash
git add verifications/verif_materiais.ms InLabChecker.ms tests/test_verif_materiais.ms
git commit -m "feat(verif): helpers de material do grupo 7 (#103)"
```

---

### Task 3: V-23 (slots PBR) e V-24 (PNG)

**Files:**
- Modify: `verifications/verif_materiais.ms` (acrescentar no fim)
- Modify: `tests/test_verif_materiais.ms`

**Interfaces:**
- Consome: `MatInfo`, `InLab_Mat_MapasDoSlot`, `InLab_Mat_ArquivoDoMapa`, `InLab_Mat_Registrar`.
- Produz: `fn InLab_V23_SlotsPBR infos` e `fn InLab_V24_PNG infos` (`infos`: array de `MatInfo`).

- [ ] **Step 1: Escrever os testes**

No lugar do marcador, inserir (mantendo o marcador no fim):

```maxscript
        ---------------------------------------------------------------- V-23 / V-24
        fn salvarBitmap nome = ( local arq = (getDir #temp) + "\\" + nome; local bm = bitmap 8 8 color:gray filename:arq; save bm; close bm; arq )
        local arqPng = salvarBitmap "inlab_v24.png"
        local arqJpg = salvarBitmap "inlab_v24.jpg"
        fn rodarMats f objs idV = ( InLab_ResetarResultados(); f (InLab_Mat_Resolver (InLab_Mat_Uso objs)); statusDe idV )
        local c1 = caixa "c1" [0, 0, 0]
        -- Só base color (procedural): passa, com nota.
        c1.material = legacyCom "So base" (CoronaColor())
        checar "V-23: só base color (procedural) passa" ((rodarMats InLab_V23_SlotsPBR #(c1) "V-23") == #pass)
        checar ("V-23: nota de roughness e normal vazios ('" + mensagemDe "V-23" + "')") (tem (mensagemDe "V-23") "sem roughness: So base" and tem (mensagemDe "V-23") "sem normal: So base")
        -- Sem mapa no base color: advertência provisória.
        c1.material = legacyCom "Sem base" undefined
        checar "V-23: base color sem mapa vira advertência" ((rodarMats InLab_V23_SlotsPBR #(c1) "V-23") == #warning)
        checar ("V-23: mensagem cita o material ('" + mensagemDe "V-23" + "')") (tem (mensagemDe "V-23") "Sem base: base color sem mapa")
        -- Standard: não convertível.
        c1.material = StandardMaterial name:"Padrao"
        checar "V-23: Standard vira advertência (não convertível)" ((rodarMats InLab_V23_SlotsPBR #(c1) "V-23") == #warning and tem (mensagemDe "V-23") "Padrao: tipo")
        -- Três slots preenchidos: passa sem nota.
        local mCheio = legacyCom "Cheio" (CoronaColor())
        mCheio.texmapReflectGlossiness = CoronaColor()
        mCheio.texmapBump = CoronaNormal()
        c1.material = mCheio
        checar "V-23: três slots preenchidos passa sem nota" ((rodarMats InLab_V23_SlotsPBR #(c1) "V-23") == #pass and not (tem (mensagemDe "V-23") "sem roughness"))

        -- V-24: PNG dentro de CoronaMix no base color reprova.
        local mixP = CoronaMix()
        setSubTexmap mixP 1 (Bitmaptexture filename:arqPng)
        c1.material = legacyCom "Laca" mixP
        checar "V-24: PNG dentro de CoronaMix no base color reprova" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #fail)
        checar ("V-24: mensagem cita material, slot e arquivo ('" + mensagemDe "V-24" + "')") (tem (mensagemDe "V-24") "Laca (base color): inlab_v24.png")
        -- PNG no roughness (CoronaBitmap) reprova.
        local mR = legacyCom "Verniz" (CoronaColor())
        local cbR = CoronaBitmap()
        cbR.filename = arqPng
        mR.texmapReflectGlossiness = cbR
        c1.material = mR
        checar "V-24: PNG em CoronaBitmap no roughness reprova" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #fail and tem (mensagemDe "V-24") "Verniz (roughness)")
        -- Palha com PNG: aceito.
        c1.material = legacyCom "Palha natural" (Bitmaptexture filename:arqPng)
        checar "V-24: PNG em palha passa" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #pass and tem (mensagemDe "V-24") "PNG aceito (alpha): Palha natural")
        -- Material com opacidade e PNG: aceito.
        local mOp = legacyCom "Tela" (Bitmaptexture filename:arqPng)
        mOp.texmapOpacity = CoronaColor()
        c1.material = mOp
        checar "V-24: PNG em material com opacidade passa" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #pass)
        -- JPG passa; PNG no bump não conta.
        local mJ = legacyCom "Carvalho" (Bitmaptexture filename:arqJpg)
        mJ.texmapReflectGlossiness = Bitmaptexture filename:arqJpg
        mJ.texmapBump = Bitmaptexture filename:arqPng
        c1.material = mJ
        checar "V-24: JPG em base e roughness passa (PNG no bump não conta)" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #pass)
        -- Bitmap sem arquivo: ignorado.
        c1.material = legacyCom "Vazio" (Bitmaptexture())
        checar "V-24: bitmap sem arquivo é ignorado" ((rodarMats InLab_V24_PNG #(c1) "V-24") == #pass)
        -- Mesmo material com PNG em dois objetos: listado uma vez.
        c1.material = legacyCom "Laca" mixP
        local c2 = caixa "c2" [30, 0, 0]
        c2.material = c1.material
        rodarMats InLab_V24_PNG #(c1, c2) "V-24"
        local msg24 = mensagemDe "V-24"
        local ocorr = 0
        local pos = findString msg24 "Laca (base color)"
        while pos != undefined do ( ocorr += 1; msg24 = substring msg24 (pos + 1) -1; pos = findString msg24 "Laca (base color)" )
        checar ("V-24: material repetido listado uma vez (" + ocorr as string + ")") (ocorr == 1)
        try ( deleteFile arqPng; deleteFile arqJpg ) catch ( linha ("aviso: não apaguei os bitmaps de teste (" + getCurrentException() + ")") )
        limparCena()

        -- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI
```

- [ ] **Step 2: Rodar e ver falhar**

Rodar `verif_materiais`. Esperado: `EXCEÇÃO` "Call needs function or class, got: undefined" (`InLab_V23_SlotsPBR`).

- [ ] **Step 3: Implementar**

No fim de `verifications/verif_materiais.ms`:

```maxscript
-- V-23 · Slots PBR (advertência provisória). Base color sem nenhum mapa ou
-- material que a conversão não suporta → advertência. Roughness ou normal
-- vazios: só nota (decisão de 06/10/2026: um mapa só é exceção válida).
fn InLab_V23_SlotsPBR infos =
(
    local titulo = "Slots PBR (base color, roughness, normal)"
    local problemas = #(), naoMedidos = #(), semRough = #(), semNormal = #()
    for i in infos do
    (
        try
        (
            if i.tipo == #outro then
                append problemas (i.mtl.name + ": tipo " + (classof i.mtl) as string + " não é convertido para glTF")
            else
            (
                if (InLab_Mat_MapasDoSlot i #mapaBase).count == 0 do append problemas (i.mtl.name + ": base color sem mapa")
                if (InLab_Mat_MapasDoSlot i #mapaGloss).count == 0 do append semRough i.mtl.name
                if (InLab_Mat_MapasDoSlot i #bump).count == 0 do append semNormal i.mtl.name
            )
        )
        catch ( append naoMedidos (i.mtl.name + " (" + getCurrentException() + ")") )
    )
    local nota = ""
    if semRough.count > 0 do nota += " · sem roughness: " + InLab_ListaResumida semRough
    if semNormal.count > 0 do nota += " · sem normal: " + InLab_ListaResumida semNormal
    if problemas.count > 0 do append problemas (nota)
    InLab_Mat_Registrar "V-23" titulo (for p in problemas where p != "" collect p) naoMedidos \
        (infos.count as string + " material(is) com base color mapeado" + nota) critico:true provisorio:true
)

-- V-24 · PNG proibido no base color e no roughness (crítica). Exceção: palha
-- ou material com mapa de opacidade (o alpha exige PNG; decisão de 06/10/2026).
fn InLab_V24_PNG infos =
(
    local titulo = "Sem PNG no base color e no roughness"
    local problemas = #(), naoMedidos = #(), aceitos = #()
    for i in infos where i.tipo != #outro do
    (
        try
        (
            local alpha = i.especial == #palha or (InLab_Mat_MapasDoSlot i #opacMapa).count > 0
            for par in #(#(#mapaBase, "base color"), #(#mapaGloss, "roughness")) do
                for tm in (InLab_Mat_MapasDoSlot i par[1]) do
                (
                    local arq = InLab_Mat_ArquivoDoMapa tm
                    if arq != undefined and (toLower (getFilenameType arq)) == ".png" do
                    (
                        if alpha then appendIfUnique aceitos i.mtl.name
                        else appendIfUnique problemas (i.mtl.name + " (" + par[2] + "): " + filenameFromPath arq)
                    )
                )
        )
        catch ( append naoMedidos (i.mtl.name + " (" + getCurrentException() + ")") )
    )
    local okMsg = "nenhum PNG no base color nem no roughness"
    if aceitos.count > 0 do okMsg = "PNG aceito (alpha): " + InLab_ListaResumida aceitos
    InLab_Mat_Registrar "V-24" titulo problemas naoMedidos okMsg critico:true
)
```

Nota para o implementador: na V-23, a nota de roughness/normal vai junto da mensagem também quando há problema; por isso ela entra como último item de `problemas` (a lista resumida mostra os 8 primeiros, então a nota pode ser cortada quando houver mais de 7 problemas — aceito).

- [ ] **Step 4: Rodar e ver passar**

Rodar `verif_materiais`. Esperado: 0 FAIL.

- [ ] **Step 5: Commit**

```bash
git add verifications/verif_materiais.ms tests/test_verif_materiais.ms
git commit -m "feat(verif): V-23 slots PBR e V-24 PNG proibido (#103)"
```

---

### Task 4: V-25 (IDs de material ↔ partes)

**Files:**
- Modify: `verifications/verif_materiais.ms` (fim)
- Modify: `tests/test_verif_materiais.ms`

**Interfaces:**
- Consome: `MatUso`, `InLab_Produto_PartesDeMaterial`, `InLab_Produto_Texto` (`fn_renomear_produto.ms`).
- Produz: `fn InLab_V25_IDsDeMaterial uso produto:undefined` e o helper `fn InLab_Mat_NomesUsados uso` (array de nomes de `uso.usados`).

- [ ] **Step 1: Escrever os testes**

No lugar do marcador, inserir (mantendo o marcador):

```maxscript
        ---------------------------------------------------------------- V-25
        local js = "{\"produtos\": [{\"cod_est\": \"0090\", \"nome\": \"POLTRONA\", \"partes\": [" +
            "{\"nome_parte\": \"Estrutura\", \"tipo\": \"P\", \"so3d\": false, \"tecido\": false, \"acessorio\": false, \"material_id\": \"ART_P_Estrutura\", \"mesh_final\": \"0090\"}, " +
            "{\"nome_parte\": \"Assento\", \"tipo\": \"T\", \"so3d\": false, \"tecido\": true, \"acessorio\": false, \"material_id\": \"ART_T_Assento\", \"mesh_final\": \"0090\"}, " +
            "{\"nome_parte\": \"Encosto\", \"tipo\": \"T\", \"so3d\": false, \"tecido\": true, \"acessorio\": false, \"material_id\": \"ART_T_Encosto\", \"mesh_final\": \"0090\"}, " +
            "{\"nome_parte\": \"Tampo\", \"tipo\": \"P\", \"so3d\": false, \"tecido\": false, \"acessorio\": true, \"material_id\": \"ART_P_Tampo\", \"mesh_final\": \"0090\"}]}]}"
        local prod = (InLab_Produto_Lista (InLab_ParseJSON js))[1]
        fn multiCom nomes = ( local mm = Multimaterial numsubs:nomes.count; for k = 1 to nomes.count do mm.materialList[k] = legacyCom nomes[k] (CoronaColor()); mm )
        fn idsNasFaces o ids = ( local n = polyop.getNumFaces o; for f = 1 to n do polyop.setFaceMatID o f ids[1 + (mod (f - 1) ids.count) as integer]; o )
        fn rodar25 objs p = ( InLab_ResetarResultados(); InLab_V25_IDsDeMaterial (InLab_Mat_Uso objs) produto:p; statusDe "V-25" )
        local d1 = caixa "0090" [0, 0, 0]
        d1.material = multiCom #("ART_P_Estrutura", "ART_T_Assento", "ART_T_Encosto", "ART_P_Tampo")
        idsNasFaces d1 #(1, 2, 3, 4)
        checar ("V-25: todos os IDs com sub-material e todas as partes com faces passa ('" + (rodar25 #(d1) prod) as string + "')") ((rodar25 #(d1) prod) == #pass and not (tem (mensagemDe "V-25") "sem faces"))
        -- Face com ID fora da lista: reprova (crítica).
        idsNasFaces d1 #(1, 2, 3, 7)
        checar "V-25: ID sem sub-material reprova" ((rodar25 #(d1) prod) == #fail)
        checar ("V-25: mensagem cita objeto e ID ('" + mensagemDe "V-25" + "')") (tem (mensagemDe "V-25") "0090: ID 7 sem sub-material")
        -- Slot do Multi/Sub vazio com faces apontando para ele: reprova, sem exceção.
        d1.material.materialList[4] = undefined
        idsNasFaces d1 #(1, 2, 3, 4)
        checar "V-25: sub-material undefined com faces reprova sem exceção" ((rodar25 #(d1) prod) == #fail and tem (mensagemDe "V-25") "0090: ID 4 sem sub-material")
        -- Parte do produto sem faces: passa com nota (bloco sem o tampo acessório).
        d1.material = multiCom #("ART_P_Estrutura", "ART_T_Assento", "ART_T_Encosto")
        idsNasFaces d1 #(1, 2, 3)
        checar "V-25: parte sem faces passa com nota" ((rodar25 #(d1) prod) == #pass and tem (mensagemDe "V-25") "parte(s) do produto sem faces: ART_P_Tampo")
        -- Sem produto: só a regra dos IDs.
        checar "V-25: sem produto, IDs ok passa" ((rodar25 #(d1) undefined) == #pass)
        -- Material direto (não Multi/Sub): passa.
        d1.material = legacyCom "ART_P_Estrutura" (CoronaColor())
        checar "V-25: material direto passa" ((rodar25 #(d1) undefined) == #pass)
        limparCena()

        -- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI
```

- [ ] **Step 2: Rodar e ver falhar**

Esperado: `EXCEÇÃO` (`InLab_V25_IDsDeMaterial` undefined).

- [ ] **Step 3: Implementar**

No fim de `verifications/verif_materiais.ms`:

```maxscript
fn InLab_Mat_NomesUsados uso = ( for m in uso.usados collect m.name )

-- material_id das partes do produto (sem as subpartes so3d), filtradas por
-- `filtro` (fn parte -> bool) quando dado.
fn InLab_Mat_IdsDasPartes produto filtro:undefined =
(
    local ids = #()
    for p in (InLab_Produto_PartesDeMaterial produto) where (filtro == undefined or (filtro p)) do
    (
        local id = InLab_Produto_Texto p "material_id"
        if id != "" do appendIfUnique ids id
    )
    ids
)

-- V-25 · IDs de material com correspondência de parte (crítica). Face com ID
-- que não leva a um sub-material reprova. Parte do produto sem faces é só
-- nota: o bloco pode não ter todas as partes (tampo acessório, variante).
-- O nome do sub-material contra o material_id é da V-20.
fn InLab_V25_IDsDeMaterial uso produto:undefined =
(
    local titulo = "IDs de material com sub-material"
    local okMsg = "todos os IDs de material das faces têm sub-material"
    if produto != undefined do
    (
        local usados = InLab_Mat_NomesUsados uso
        local semFaces = for id in (InLab_Mat_IdsDasPartes produto) where (findItem usados id) == 0 collect id
        if semFaces.count > 0 do okMsg += " · nota: parte(s) do produto sem faces: " + InLab_ListaResumida semFaces
    )
    InLab_Mat_Registrar "V-25" titulo uso.orfaos uso.naoMedidos okMsg critico:true
)
```

- [ ] **Step 4: Rodar e ver passar**

Esperado: 0 FAIL.

- [ ] **Step 5: Commit**

```bash
git add verifications/verif_materiais.ms tests/test_verif_materiais.ms
git commit -m "feat(verif): V-25 IDs de material com sub-material (#103)"
```

---

### Task 5: V-35 (palha) e V-36 (cristal)

**Files:**
- Modify: `verifications/verif_materiais.ms` (fim)
- Modify: `tests/test_verif_materiais.ms`

**Interfaces:**
- Consome: `MatInfo`, `InLab_Mat_MapasDoSlot`, `InLab_Material_PerfilSlots`, `InLab_PropSafe`, `InLab_Mat_Registrar`.
- Produz: `fn InLab_V35_Palha infos`, `fn InLab_V36_Cristal infos`.

- [ ] **Step 1: Escrever os testes**

No lugar do marcador (mantendo-o):

```maxscript
        ---------------------------------------------------------------- V-35 / V-36
        local e1 = caixa "e1" [0, 0, 0]
        e1.material = legacyCom "Madeira" (CoronaColor())
        checar "V-35: sem palha não se aplica (passa)" ((rodarMats InLab_V35_Palha #(e1) "V-35") == #pass and tem (mensagemDe "V-35") "não se aplica")
        e1.material = legacyCom "Palha natural" (CoronaColor())
        checar "V-35: palha sem opacidade vira advertência" ((rodarMats InLab_V35_Palha #(e1) "V-35") == #warning and tem (mensagemDe "V-35") "Palha natural: sem mapa de opacidade")
        e1.material.texmapOpacity = CoronaColor()
        checar "V-35: palha com opacidade passa" ((rodarMats InLab_V35_Palha #(e1) "V-35") == #pass)

        e1.material = legacyCom "Madeira" (CoronaColor())
        checar "V-36: sem cristal não se aplica (passa)" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #pass and tem (mensagemDe "V-36") "não se aplica")
        -- Vidro jateado: refração ligada e glossiness baixo (fosco) passa.
        local mJat = legacyCom "Vidro Jateado" undefined
        mJat.levelRefract = 1.0
        mJat.reflectGlossiness = 0.3
        e1.material = mJat
        checar "V-36: vidro jateado (fosco) com refração passa" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #pass)
        mJat.levelRefract = 0.0
        checar "V-36: vidro com refração 0 vira advertência" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #warning and tem (mensagemDe "V-36") "Vidro Jateado: refração desligada")
        -- Physical.
        local mPh = CoronaPhysicalMtl()
        mPh.name = "Cristal liso"
        mPh.refractionAmount = 1.0
        e1.material = mPh
        checar "V-36: Physical com refração passa" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #pass)
        -- VRay (só se a classe existir).
        local mV = try ( VRayMtl() ) catch ( undefined )
        if mV == undefined then checar "V-36: VRay — pulado: VRay ausente" true
        else
        (
            mV.name = "Glass VRay"
            mV.refraction = color 255 255 255
            e1.material = mV
            checar "V-36: VRay com cor de refração passa" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #pass)
            mV.refraction = color 0 0 0
            checar "V-36: VRay com refração preta vira advertência" ((rodarMats InLab_V36_Cristal #(e1) "V-36") == #warning)
        )
        limparCena()

        -- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI
```

- [ ] **Step 2: Rodar e ver falhar**

Esperado: `EXCEÇÃO` (`InLab_V35_Palha` undefined).

- [ ] **Step 3: Implementar**

No fim de `verifications/verif_materiais.ms`:

```maxscript
-- V-35 · Palha com opacidade (advertência provisória). O 2-sided não é
-- conferido: a conversão liga doubleSided sozinha e o CoronaLegacyMtl não tem
-- a propriedade (sondagem de 06/10/2026).
fn InLab_V35_Palha infos =
(
    local titulo = "Palha com mapa de opacidade"
    local palhas = for i in infos where i.especial == #palha collect i
    local problemas = #(), naoMedidos = #()
    for i in palhas do
    (
        try
        (
            if i.tipo == #outro then append problemas (i.mtl.name + ": tipo não convertido para glTF")
            else if (InLab_Mat_MapasDoSlot i #opacMapa).count == 0 do append problemas (i.mtl.name + ": sem mapa de opacidade")
        )
        catch ( append naoMedidos (i.mtl.name + " (" + getCurrentException() + ")") )
    )
    local okMsg = if palhas.count == 0 then "não se aplica: nenhum material de palha" else (palhas.count as string + " material(is) de palha com opacidade")
    InLab_Mat_Registrar "V-35" titulo problemas naoMedidos okMsg critico:true provisorio:true
)

-- Refração ligada: VRay pela cor "refraction" (não tem refraction_amount);
-- Corona pelo valor do perfil (levelRefract / refractionAmount) > 0.
fn InLab_Mat_RefracaoLigada i =
(
    if i.tipo == #vray then
    (
        local c = InLab_PropSafe i.base #(#refraction)
        c != undefined and (c.r + c.g + c.b) > 0
    )
    else
    (
        local v = InLab_PropSafe i.base (InLab_Material_PerfilSlots i.tipo).refrVal
        v != undefined and v > 0
    )
)

-- V-36 · Cristal com refração (advertência provisória). Nunca reprova por
-- valor: roughness, IOR e intensidade ficam livres (decisão de 06/10/2026;
-- vidro jateado é fosco de propósito).
fn InLab_V36_Cristal infos =
(
    local titulo = "Cristal com refração ligada"
    local cristais = for i in infos where i.especial == #cristal collect i
    local problemas = #(), naoMedidos = #()
    for i in cristais do
    (
        try
        (
            if i.tipo == #outro then append problemas (i.mtl.name + ": tipo não convertido para glTF")
            else if not (InLab_Mat_RefracaoLigada i) do append problemas (i.mtl.name + ": refração desligada")
        )
        catch ( append naoMedidos (i.mtl.name + " (" + getCurrentException() + ")") )
    )
    local okMsg = if cristais.count == 0 then "não se aplica: nenhum material de cristal/vidro" else (cristais.count as string + " material(is) de cristal com refração")
    InLab_Mat_Registrar "V-36" titulo problemas naoMedidos okMsg critico:true provisorio:true
)
```

- [ ] **Step 4: Rodar e ver passar**

Esperado: 0 FAIL.

- [ ] **Step 5: Commit**

```bash
git add verifications/verif_materiais.ms tests/test_verif_materiais.ms
git commit -m "feat(verif): V-35 palha e V-36 cristal (#103)"
```

---

### Task 6: V-37 (zonas do estofado) e V-38 (tampo acessório)

**Files:**
- Modify: `verifications/verif_materiais.ms` (fim)
- Modify: `tests/test_verif_materiais.ms`

**Interfaces:**
- Consome: `MatUso`, `InLab_Mat_NomesUsados`, `InLab_Mat_IdsDasPartes`, `InLab_Produto_Booleano`, `InLab_Produto_Texto`, `InLab_Produto_Normalizar` (`fn_renomear_produto.ms`), `InLab_TampoAcessorioProduto` (global; definida no orquestrador, aqui só lida — pré-declarar com `global InLab_TampoAcessorioProduto` no topo do arquivo, sem valor, para não sobrescrever).
- Produz: `fn InLab_V37_ZonasEstofado cfg uso produto:undefined`, `fn InLab_V38_TampoAcessorio cfg uso produto:undefined`.

- [ ] **Step 1: Escrever os testes**

No lugar do marcador (mantendo-o). Usa `prod`, `multiCom` e `idsNasFaces` da Task 4:

```maxscript
        ---------------------------------------------------------------- V-37 / V-38
        local cfgEstof = InLab_ObterFamilia "estrutura_estofado"
        local cfgUnico = InLab_ObterFamilia "corpo_unico"
        local cfgTampo = InLab_ObterFamilia "pernas_tampo"
        fn rodar37 cfg objs p = ( InLab_ResetarResultados(); InLab_V37_ZonasEstofado cfg (InLab_Mat_Uso objs) produto:p; statusDe "V-37" )
        fn rodar38 cfg objs p = ( InLab_ResetarResultados(); InLab_V38_TampoAcessorio cfg (InLab_Mat_Uso objs) produto:p; statusDe "V-38" )
        local g1 = caixa "0090" [0, 0, 0]
        g1.material = multiCom #("ART_P_Estrutura", "ART_T_Assento", "ART_T_Encosto")
        idsNasFaces g1 #(1, 2, 3)
        checar "V-37: família sem zona de acabamento não se aplica" ((rodar37 cfgUnico #(g1) prod) == #pass and tem (mensagemDe "V-37") "não se aplica")
        checar "V-37: as duas partes de tecido com faces passa" ((rodar37 cfgEstof #(g1) prod) == #pass)
        idsNasFaces g1 #(1, 2)
        checar "V-37: parte de tecido sem faces vira advertência" ((rodar37 cfgEstof #(g1) prod) == #warning and tem (mensagemDe "V-37") "ART_T_Encosto")
        -- Sem produto: um material só em tudo → advertência; mais de um → passa.
        g1.material = legacyCom "Tecido unico" (CoronaColor())
        checar "V-37: sem produto, estofado num único material vira advertência" ((rodar37 cfgEstof #(g1) undefined) == #warning and tem (mensagemDe "V-37") "único")
        g1.material = multiCom #("Tecido A", "Tecido B")
        idsNasFaces g1 #(1, 2)
        checar "V-37: sem produto, mais de um material passa" ((rodar37 cfgEstof #(g1) undefined) == #pass)

        -- V-38
        InLab_TampoAcessorioProduto = false
        checar "V-38: sem tampo acessório não se aplica" ((rodar38 cfgUnico #(g1) prod) == #pass and tem (mensagemDe "V-38") "não se aplica")
        InLab_TampoAcessorioProduto = true
        g1.material = multiCom #("ART_P_Estrutura", "ART_P_Tampo")
        idsNasFaces g1 #(1, 2)
        checar "V-38: tampo e estrutura no mesmo arquivo vira advertência" ((rodar38 cfgUnico #(g1) prod) == #warning and tem (mensagemDe "V-38") "separe")
        g1.material = legacyCom "ART_P_Tampo" (CoronaColor())
        checar "V-38: só o tampo passa" ((rodar38 cfgUnico #(g1) prod) == #pass)
        g1.material = legacyCom "ART_P_Estrutura" (CoronaColor())
        checar "V-38: só a estrutura passa" ((rodar38 cfgUnico #(g1) prod) == #pass)
        checar "V-38: sem produto fica pendente (advertência)" ((rodar38 cfgUnico #(g1) undefined) == #warning and tem (mensagemDe "V-38") "pendente")
        InLab_TampoAcessorioProduto = false
        -- Pela família (cfg.tampoAcessorio), sem o checkbox; o valor volta no fim.
        local tampoOriginal = cfgTampo.tampoAcessorio
        cfgTampo.tampoAcessorio = true
        g1.material = multiCom #("ART_P_Estrutura", "ART_P_Tampo")
        idsNasFaces g1 #(1, 2)
        checar "V-38: tampo acessório pela família também ativa" ((rodar38 cfgTampo #(g1) prod) == #warning)
        cfgTampo.tampoAcessorio = tampoOriginal
        -- Não crítica: o resultado sai com critico:false e não bloqueia a aprovação.
        local r38 = undefined
        for r in InLab_VerifResults where r.id == "V-38" do r38 = r
        checar "V-38 é não crítica (critico:false, aprovação continua)" (r38 != undefined and not r38.critico and InLab_AprovacaoFinal())
        limparCena()

        -- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI
```

Também acrescentar `InLab_AprovacaoFinal` à linha de `global` do topo do teste.

- [ ] **Step 2: Rodar e ver falhar**

Esperado: `EXCEÇÃO` (`InLab_V37_ZonasEstofado` undefined).

- [ ] **Step 3: Implementar**

No topo de `verifications/verif_materiais.ms` (depois do cabeçalho), acrescentar:

```maxscript
-- Definida e preenchida pelo orquestrador (checkbox da UI); aqui só é lida.
global InLab_TampoAcessorioProduto
```

No fim do arquivo:

```maxscript
-- V-37 · Zonas de acabamento do estofado (advertência provisória). Só nas
-- famílias com "zona_acabamento" em materialTypes. Com produto: cada parte
-- tecido:true precisa ter faces com o seu material_id. Sem produto: um único
-- material em tudo → advertência ("pode ser produto sem desmembramento").
fn InLab_V37_ZonasEstofado cfg uso produto:undefined =
(
    local titulo = "Zonas de acabamento do estofado"
    if (findItem cfg.materialTypes "zona_acabamento") == 0 then
        InLab_RegistrarVerif "V-37" titulo true ("não se aplica: família " + cfg.nome + " sem zona de acabamento") critico:true provisorio:true
    else if produto != undefined then
    (
        local usados = InLab_Mat_NomesUsados uso
        local tecidos = InLab_Mat_IdsDasPartes produto filtro:(fn _t p = InLab_Produto_Booleano p "tecido")
        local faltam = for id in tecidos where (findItem usados id) == 0 collect ("parte de tecido sem faces: " + id)
        InLab_Mat_Registrar "V-37" titulo faltam uso.naoMedidos (tecidos.count as string + " parte(s) de tecido com o seu material") critico:true provisorio:true
    )
    else
    (
        local problemas = if uso.usados.count <= 1 then #("estofado num único material (pode ser produto sem desmembramento; importe o .json para conferir as partes)") else #()
        InLab_Mat_Registrar "V-37" titulo problemas uso.naoMedidos (uso.usados.count as string + " materiais no estofado") critico:true provisorio:true
    )
)

-- V-38 · Tampo acessório em bloco separado (advertência, critico:false).
-- Ativa pelo checkbox (InLab_TampoAcessorioProduto) ou pela família. Com
-- produto: faces do material do tampo acessório E de outra parte no mesmo
-- arquivo → advertência. Sem produto: pendente.
fn InLab_V38_TampoAcessorio cfg uso produto:undefined =
(
    local titulo = "Tampo acessório em arquivo separado"
    if not (InLab_TampoAcessorioProduto == true or cfg.tampoAcessorio) then
        InLab_RegistrarVerif "V-38" titulo true "não se aplica: produto sem tampo acessório" critico:false
    else if produto == undefined then
        InLab_RegistrarVerif "V-38" titulo false "pendente: importe o .json e escolha o produto na seção Produto para conferir estrutura e tampo" critico:false
    else
    (
        fn _ehTampo p = (InLab_Produto_Booleano p "acessorio") and (findString (InLab_Produto_Normalizar (InLab_Produto_Texto p "nome_parte")) "tampo") != undefined
        local idsTampo = InLab_Mat_IdsDasPartes produto filtro:_ehTampo
        local idsOutros = for id in (InLab_Mat_IdsDasPartes produto) where (findItem idsTampo id) == 0 collect id
        local usados = InLab_Mat_NomesUsados uso
        local temTampo = (for id in idsTampo where (findItem usados id) > 0 collect id).count > 0
        local temOutros = (for id in idsOutros where (findItem usados id) > 0 collect id).count > 0
        if temTampo and temOutros then
            InLab_RegistrarVerif "V-38" titulo false "estrutura e tampo acessório no mesmo arquivo: separe em dois blocos (intercambialidade)" critico:false
        else
            InLab_RegistrarVerif "V-38" titulo true (if temTampo then "arquivo só com o tampo" else "arquivo só com a estrutura") critico:false
    )
)
```

Antes de implementar, confirmar que `InLab_Produto_Normalizar` existe em `fn_renomear_produto.ms` (`grep -n "fn InLab_Produto_Normalizar" functions/fn_renomear_produto.ms`). Se a função local `fn _ehTampo` dentro do `else` não compilar no MaxScript (fn dentro de bloco de expressão), mover `_ehTampo` e `_t` para o escopo global do arquivo como `fn InLab_Mat_EhTampoAcessorio p = ...` e `fn InLab_Mat_EhTecido p = ...`, e passar esses nomes no `filtro:`.

- [ ] **Step 4: Rodar e ver passar**

Esperado: 0 FAIL.

- [ ] **Step 5: Commit**

```bash
git add verifications/verif_materiais.ms tests/test_verif_materiais.ms
git commit -m "feat(verif): V-37 zonas do estofado e V-38 tampo acessorio (#103)"
```

---

### Task 7: Ligar o grupo 7 ao motor, suíte inteira e piloto

**Pré-requisito:** #107 na `main` e a branch rebaseada (ver "Pré-requisito" no topo).

**Files:**
- Modify: `verifications/verif_orquestrador.ms` (cabeçalho de status; bloco depois do grupo 6)
- Modify: `core/struct_result.ms` (nota de não críticos)
- Modify: `tests/test_verificacoes.ms`, `tests/test_familia_ativa.ms`, `tests/test_posicao_painel.ms` (listas de `fileIn`; checagem do grupo 7)

**Interfaces:**
- Consome: todas as funções das Tasks 2 a 6.

- [ ] **Step 1: Escrever o teste da rodada completa**

Em `tests/test_verificacoes.ms`, logo depois da linha do `checar` "grupo 6 presente (V-07, V-08, V-09, V-10, V-13)", acrescentar:

```maxscript
            checar ("Rodada '" + cfg.nome + "': grupo 7 presente (V-23, V-24, V-25, V-35, V-36, V-37, V-38)") ((for idV in #("V-23", "V-24", "V-25", "V-35", "V-36", "V-37", "V-38") where (statusDe idV) == #ausente collect idV).count == 0)
```

Nas listas de `fileIn` de `test_verificacoes.ms`, `test_familia_ativa.ms` e `test_posicao_painel.ms`: inserir `@"verifications\verif_materiais.ms"` logo depois de `@"verifications\verif_mapeamento.ms"`, e garantir que `@"functions\fn_json.ms"`, `@"functions\fn_renomear_produto.ms"` e `@"functions\fn_material_convert.ms"` estão na lista antes dele (acrescentar os que faltarem, na ordem do manifesto de `InLabChecker.ms`). Conferir com `grep -n 'fn_json\|fn_renomear_produto\|fn_material_convert\|verif_materiais' tests/test_verificacoes.ms tests/test_familia_ativa.ms tests/test_posicao_painel.ms`. Escrever os caminhos com o Edit (não com Python sem string raw: `\v`, `\f` e `\r` viram caracteres de controle).

- [ ] **Step 2: Rodar e ver falhar**

Rodar `verificacoes`. Esperado: FAIL em "grupo 7 presente".

- [ ] **Step 3: Ligar no orquestrador**

Em `verifications/verif_orquestrador.ms`, trocar:

```maxscript
        -- ===== Grupos 4 e 7 · próximas entregas =====
        InLab_Log "Grupos 4 e 7 (animação avançada, materiais) ainda não implementados — relatório parcial." tipo:#warn
```

por:

```maxscript
        -- ===== Grupo 7 · Materiais (issue #103, verif_materiais.ms) =====
        local uso = InLab_Mat_Uso objetos
        local mats = InLab_Mat_Resolver uso
        InLab_V23_SlotsPBR mats
        InLab_V24_PNG mats
        InLab_V25_IDsDeMaterial uso produto:produto
        InLab_V35_Palha mats
        InLab_V36_Cristal mats
        InLab_V37_ZonasEstofado cfg uso produto:produto
        InLab_V38_TampoAcessorio cfg uso produto:produto

        -- ===== Grupo 4 · animação avançada (v2) =====
        InLab_Log "Grupo 4 (animação avançada) fica para o v2 — relatório parcial." tipo:#warn
```

No cabeçalho, trocar a linha do grupo 7:

```
   Grupo 7 (materiais)      → V-23/24/25, V-35/36/37, V-38       [ENTREGUE 06/10/2026 — verif_materiais.ms, issue #103]
```

e a do grupo 4 para `[v2]` no lugar de `[próxima entrega]`.

Em `core/struct_result.ms`, na lista "Implementados hoje como não críticos", acrescentar `V-38 (tampo acessório; 06/10/2026, issue #103),` depois da linha da V-16, e trocar "Previstos na spec: V-33, V-37 a V-40." por "Previstos na spec: V-33, V-39, V-40.".

- [ ] **Step 4: Rodar a suíte inteira**

Rodar os 25 arquivos de `tests/` (os 24 de antes e `test_verif_materiais.ms`), um `resetMaxFile #noPrompt` + `fileIn` por arquivo, em lotes que fiquem abaixo de 120 s por chamada (lotes usados em 06/10/2026: {verificacoes, familia_ativa, posicao_painel}, {verif_malha, verif_mapeamento, verif_uv, relatorio, reload, verif_materiais}, {kit_header, material_convert, material_utils, prefs, realworldfix, renomear_produto, secao_atualizacao, updater_aplicar, updater_checagem, utilidades, versao, export_gltf}, {otim_nucleo, otim_origem, otim_fino, otim_escondidas}, {autouv}). Esperado: 0 FAIL em todos.

- [ ] **Step 5: Rodar o piloto (só leitura, sem salvar)**

Numa chamada:

```maxscript
(
fileIn @"G:\Meu Drive\GitHub\InLabChecker\InLabChecker.ms"
local pasta = @"G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\PILOTO PLUGIN INLAB\ARTEFACTO\"
local out = ""
for a in #("APARADOR ZUCCHI - 147 X 042 X 072.5 H.max", "POLTRONA MENTHA - 080 X 080 X 072 H.max", "MESA LATERAL NAMBU - 055 X 040 X 055 H.max", "MESA LATERAL LOUISE - JATEADA - DIAM 032.6 X 041 H.max", "PUFF POL - DIAM 050.5 X 040 H.max") do
(
    loadMaxFile (pasta + a) quiet:true useFileUnits:true
    InLab_ResetarResultados()
    local objs = InLab_ObjetosVerificacao()
    local t0 = timeStamp()
    local uso = InLab_Mat_Uso objs
    local mats = InLab_Mat_Resolver uso
    InLab_V23_SlotsPBR mats; InLab_V24_PNG mats; InLab_V25_IDsDeMaterial uso
    InLab_V35_Palha mats; InLab_V36_Cristal mats
    InLab_V37_ZonasEstofado (InLab_ObterFamilia "estrutura_estofado") uso
    InLab_V38_TampoAcessorio (InLab_ObterFamilia "corpo_unico") uso
    out += "\n## " + a + " (" + ((timeStamp() - t0) / 1000.0) as string + " s)"
    for r in InLab_VerifResults do out += "\n  " + r.id + " " + r.status as string + " · " + r.mensagem
)
resetMaxFile #noPrompt
out
)
```

Esperado: nenhuma exceção e nenhum "não medido"; nenhum material com procedural no difuso (`CoronaColorCorrect`, `CoronaMix`, `CoronaColor`, `RGB_Multiply`) aparece como "base color sem mapa"; na Louise Jateada, V-36 passa (refração 1,0); no Puff Pol (VRay) as checagens rodam sem erro. Anotar os resultados (e o tempo) no cabeçalho de `verif_materiais.ms`, numa nota "06/10/2026 — piloto".

- [ ] **Step 6: Commit**

```bash
git add verifications/verif_orquestrador.ms verifications/verif_materiais.ms core/struct_result.ms tests/test_verificacoes.ms tests/test_familia_ativa.ms tests/test_posicao_painel.ms
git commit -m "feat(verif): grupo 7 de materiais no motor de verificacao (#103)"
```
