# Botão nativo na Main Toolbar — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Depois do `.mzp`, o botão da lâmpada branca aparece sozinho na Main Toolbar do 3ds Max (sem o passo manual do Customize), persiste entre sessões e volta sozinho se o botão sumir.

**Architecture:** Uma função `InLab_GarantirBotaoToolbar` injeta um `<Item>` de macro na Main Toolbar do `.cuix` (igual ao ArchToolz, validado em spike no Max 2024), de forma idempotente e com backup/restauração. Ela substitui a janela flutuante do `registrar.ms`. Como o `instalar.ms` (instalação) e o `inlabchecker_boot.ms` (abertura do Max) **já** fazem `fileIn` do `registrar.ms`, a fiação do install e da rede-de-segurança já existe: basta o `registrar.ms` passar a chamar a garantia no fim.

**Tech Stack:** MaxScript, `.NET System.Xml.XmlDocument` e `System.IO.File`, struct `cui` do 3ds Max.

**Spec:** `docs/superpowers/specs/2026-10-16-botao-toolbar-nativo-design.md`

## Global Constraints

- Tudo em português (código, comentário, log, UI).
- Prefixo `InLab_` em função pública, `INLAB_MAIUSCULO` em constante.
- Global usado antes do arquivo que o define, ou `fn` que chama outro `fn` abaixo, precisa de `global Nome` adiantado (ver topo dos arquivos e `tests/test_globais_adiantados.ms`).
- Cabeçalho `/* === ... === */` em todo arquivo tocado, com data e a decisão nova.
- MCP do Max em `safe_mode`: copiar/mover arquivo por `.NET System.IO.File`, nunca `copyFile`/`createFile` de MaxScript no código enviado.
- Operação em disco e na UI sempre em `try/catch` com `InLab_Log` ou `format`; nunca engolir erro mudo.
- `actionID` do item = `"InLabChecker_Abrir`InLab"` (macro `InLabChecker_Abrir`, categoria `InLab`, já definidos no `registrar.ms`). `actionTableID = "647394"`. Atributos do `<Item>` (do spike/ArchToolz): `typeID="2" type="CTB_MACROBUTTON" width="0" height="0" controlID="0" macroTypeID="3" macroType="MB_TYPE_ACTION" actionTableID="647394" imageID="-1" imageName=""`.
- Alvo Max 2024–2027. Spike cobriu só o 2024; 2025/2027 validados fora do código (ver Spec, seção "Validação e entrega").

## Review Focus

- **Main Toolbar ausente no `.cuix`** (workspace sem a barra principal): a garantia não pode travar — loga e retorna `#semBarra`. → teste no Task 1.
- **Idempotência:** rodar a garantia duas vezes não pode duplicar o `<Item>`. → teste no Task 1.
- **Item velho com o mesmo `actionID` mas atributos diferentes** (reinstalação/versão antiga): é removido e re-adicionado, sobrando exatamente um. → teste no Task 1.
- **Caso do atributo `actionID` vs `actionId`:** o Max pode re-serializar o nome do atributo com outra caixa ao salvar o `.cuix`. O casamento idempotente lê o atributo de forma **case-insensitive** (aceita `actionID` e `actionId`), senão a 2ª abertura duplica o botão. → teste no Task 1 (fixture com `actionId`) + conferir num `.cuix` salvo pelo Max na validação.
- **Falha ao salvar o XML / `loadConfig`** (arquivo travado, XML inválido): restaura o `.cuix` do backup e não deixa a UI corrompida. → coberto pela disciplina de backup no Task 1 (teste de que o backup é criado antes da gravação).

---

### Task 1: `InLab_GarantirBotaoToolbar` substitui a janela flutuante

**Files:**
- Modify: `install/registrar.ms` (tira o bloco da barra flutuante, linhas ~45-166; mantém a cópia dos BMP ~48-62 e o `macroScript InLabChecker_Abrir` ~64-85)
- Test: `tests/test_toolbar_botao.ms` (novo)

**Interfaces:**
- Produces:
  - `fn InLab_GarantirBotaoToolbar caminho:undefined recarregar:true` → símbolo `#adicionado | #jaExistia | #semBarra | #erro`. `caminho:undefined` usa `cui.getConfigFile()` (e o fallback `(getDir #maxData) + "UI\\Workspaces\\usersave\\Workspace__usersave__.cuix"` se vier `undefined`). `recarregar:true` faz o flush+backup+`loadConfig` na UI viva; `recarregar:false` só edita o arquivo em `caminho` e não toca na UI (seam de teste).
  - `global INLAB_TOOLBAR_ACTIONID = "InLabChecker_Abrir`InLab"`.
  - `global INLAB_TOOLBAR_SO_DEFINIR` — se `== true` no momento do `fileIn` do `registrar.ms`, o arquivo **só define** a função (não chama a garantia na UI viva). O teste liga esse global antes do `fileIn`.
- Consumes: o `macroScript InLabChecker_Abrir` e a cópia dos BMP, que seguem no próprio `registrar.ms`.

- [ ] **Step 1: Escrever o teste que falha** — `tests/test_toolbar_botao.ms`, no molde de `tests/test_renomear_produto.ms` (globais adiantados; `INLAB_TOOLBAR_SO_DEFINIR = true` antes do `fileIn (raiz + "install\\registrar.ms")`; saída em `(getDir #temp)\\inlab_test_toolbar.txt`). O teste monta um `.cuix` mínimo de fixture em `(getDir #temp)` e usa `recarregar:false`:

```
-- fixture: ADSK_CUI > CUIWindows > Window[objectName='Main Toolbar'] > Items (vazio)
checar "adiciona o item" ((InLab_GarantirBotaoToolbar caminho:fx recarregar:false) == #adicionado)
checar "1 item com o actionID"  (contaItens fx INLAB_TOOLBAR_ACTIONID == 1)
checar "idempotente (2a vez)"    ((InLab_GarantirBotaoToolbar caminho:fx recarregar:false) == #jaExistia and contaItens fx INLAB_TOOLBAR_ACTIONID == 1)
-- fixture com um <Item actionId="InLabChecker_Abrir`InLab"> (caixa diferente, atributos velhos)
checar "troca item velho, sobra 1" (InLab_GarantirBotaoToolbar caminho:fxVelho recarregar:false; contaItens fxVelho INLAB_TOOLBAR_ACTIONID == 1)
-- fixture sem Main Toolbar
checar "sem barra -> #semBarra" ((InLab_GarantirBotaoToolbar caminho:fxSemBarra recarregar:false) == #semBarra)
```

`contaItens` é um helper do teste que carrega o XML e conta os `Item` cujo atributo `actionID`/`actionId` (case-insensitive) é igual ao alvo.

- [ ] **Step 2: Rodar e ver falhar** — `fileIn @"<repo>\tests\test_toolbar_botao.ms"` numa cena vazia; ler `(getDir #temp)\inlab_test_toolbar.txt`. Esperado: FAIL (`InLab_GarantirBotaoToolbar` indefinida / "Call needs function").

- [ ] **Step 3: Implementar a função em `install/registrar.ms`.** Assinatura e retorno acima. Corpo: resolver `caminho` (default `cui.getConfigFile()` + fallback); carregar o XML (`System.Xml.XmlDocument`); achar `//ADSK_CUI/CUIWindows/Window[@objectName='Main Toolbar']` → se `count==0`, logar e retornar `#semBarra`; pegar o nó `Items`; varrer os `Item` e remover os que casam o `actionID` (leitura **case-insensitive** do atributo); se não havia nenhum, criar o `<Item>` com os atributos da seção Global Constraints e `AppendChild`; se já havia e nada mudou, retornar `#jaExistia`. **Quando `recarregar:true`:** antes de editar, `cui.saveConfig()` (flush) e `File.Copy caminho (caminho + ".inlab.bak") true` (backup); depois de `xml.save caminho`, `cui.loadConfig caminho`, `colorMan.reInitIcons()`, `colorMan.repaintUI #repaintAll`, e apagar o `.bak`; se a gravação ou o `loadConfig` lançar, restaurar `caminho` do `.bak`, refazer `loadConfig` e retornar `#erro`. **Quando `recarregar:false`:** só `xml.save caminho`, sem tocar em `cui`/backup. No fim do arquivo, **substituir** `InLab_Barra_Montar()` por `if (INLAB_TOOLBAR_SO_DEFINIR != true) do InLab_GarantirBotaoToolbar()`. Remover o `rollout InLabChecker_Barra`, `InLab_Barra_Montar/Salvar/IniPath` e os globais da barra; apagar uma vez o `inlabchecker_barra.ini` órfão em `(getDir #userStartupScripts)`. Atualizar o cabeçalho do arquivo (data 16/10, a decisão nova e o motivo).

- [ ] **Step 4: Rodar e ver passar** — mesmo comando do Step 2. Esperado: todas PASS em `inlab_test_toolbar.txt`.

- [ ] **Step 5: Rodar `tests/test_globais_adiantados.ms`** para garantir que os novos globais do `registrar.ms` estão pré-declarados. Esperado: PASS.

- [ ] **Step 6: Commit**

```
git commit -m "feat(install): botao nativo na toolbar via injecao no cuix"
```

---

### Task 2: Instalação e boot sem o passo do Customize

**Files:**
- Modify: `install/instalar.ms` (messageBox final, linhas ~129-134)
- Modify: `install/inlabchecker_boot.ms` (só o cabeçalho; a lógica já faz `fileIn` do `registrar.ms`)
- Delete: `install/fixar_barra.ms` (experimento de 15/10 com `RegisterDialogBar`, desnecessário; hoje `?? untracked`)

**Interfaces:**
- Consumes: `InLab_GarantirBotaoToolbar` (Task 1), que o `instalar.ms` já dispara ao fazer `fileIn (destino + "\\install\\registrar.ms")` (passo "registrar o botão", linha ~117). Nenhuma lógica nova de injeção aqui.

- [ ] **Step 1: Editar a mensagem de sucesso do `instalar.ms`** (linhas ~129-134): tirar o texto que manda abrir o Customize e arrastar o botão; trocar por algo como "O botão da lâmpada já está na barra de ferramentas." Ajustar o cabeçalho do arquivo (a nota "NÃO põe o botão na barra" das linhas ~19-21 deixa de valer; registrar a mudança com data).

- [ ] **Step 2: Atualizar o cabeçalho do `inlabchecker_boot.ms`** explicando que o `registrar.ms` agora garante o botão nativo (rede de segurança no boot), sem mudar a lógica (o `fileIn` do `registrar.ms` continua igual).

- [ ] **Step 3: Apagar `install/fixar_barra.ms`** (`git rm` / remover o arquivo não-rastreado).

- [ ] **Step 4: Verificar que o empacotamento não precisa mudar** — `install/empacotar.ps1` já inclui `install/registrar.ms` no zip e no mzp, e nenhum arquivo novo foi criado (a função mora no `registrar.ms`). Conferir que `fixar_barra.ms` não está nas listas do `git archive` (não está). Nada a editar; marcar como conferido.

- [ ] **Step 5: Commit**

```
git commit -m "feat(install): instalacao e boot sem o passo do Customize"
```

---

### Task 3: Documentação (README do instalador)

**Files:**
- Modify: `install/README.md`

**Interfaces:** nenhuma (docs).

- [ ] **Step 1: Reescrever o passo 2** (linhas ~17-23): o botão já aparece sozinho na barra depois do `.mzp`; cai o "Customize > Customize User Interface > arraste InLabChecker". Explicar que, se o botão não aparecer (reset de UI), basta reabrir o Max que ele volta.

- [ ] **Step 2: Trocar "lâmpada âmbar" por "lâmpada branca"** (linha ~17) e ajustar a seção "Se o botão não aparecer" (linhas ~48-54) e "Desinstalar" (linha ~58): tirar o botão = clique direito > Delete Button (e, se o `.cuix` não for salvo, ele volta no próximo boot).

- [ ] **Step 3: Rever a seção "Instalação manual"** (linhas ~29-37): o passo 5 ("siga o passo 2 acima") muda, já que não há mais arrasto manual — o `inlabchecker_boot.ms` no startup garante o botão na próxima abertura.

- [ ] **Step 4: Commit**

```
git commit -m "docs(install): botao aparece sozinho, lampada branca"
```

---

## Validação no Max (fora dos commits, antes da release)

Conforme a Spec (seção "Validação e entrega"), após os commits:
1. **2024 (MCP):** rodar o fluxo completo (instalar num destino de teste, conferir o botão na barra com a lâmpada, clicar e abrir o painel, reabrir o Max e ver o botão persistir, apagar o botão e ver a rede de segurança readicionar no boot). Confirmar a caixa do atributo `actionID` num `.cuix` salvo pelo Max.
2. **2027 (MCP):** repetir o essencial (pede um Max 2027 aberto e conectado).
3. **2025 (usuário):** gerar `.mzp` provisório do branch (`install/empacotar.ps1 -Ref feat/botao-toolbar-nativo`), entregar o arquivo, sem publicar.
