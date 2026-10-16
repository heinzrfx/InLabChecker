# Botão nativo na Main Toolbar (igual ao ArchToolz)

Data: 16/10/2026 · Versão base: 1.2.1

## Intenção e o porquê

Hoje, depois de instalar o InLabChecker pelo `.mzp`, o desenhista precisa
**arrastar o botão à mão** no *Customize > Customize User Interface* (passo 2 do
`install/README.md`). É o único passo manual da instalação e a maior fonte de
suporte ("o botão não apareceu"). O InLabChecker contorna isso hoje com uma
**janela flutuante** (`install/registrar.ms`), recriada a cada abertura do Max
pelo `install/inlabchecker_boot.ms` — uma janelinha solta, que não é um botão de
barra de verdade.

O ArchToolz — referência da equipe — não tem esse passo: o botão **nasce sozinho
na barra principal do Max**. Ele faz isso injetando um `<Item>` no arquivo de UI
(`.cuix`) na instalação. Queremos o mesmo comportamento no InLabChecker.

O `registrar.ms` (cabeçalho, 16/10) documenta que injetar no `.cuix` foi
*rejeitado* por ser "arquivo não-suportado da Autodesk (risco de corromper a
UI)". Este design **reverte essa decisão**, com base no spike abaixo e no fato de
o ArchToolz usar exatamente isso em produção.

### Spike (16/10, Max 2024, no Max do usuário)

Validado e revertido sem deixar rastro:
- A injeção no `.cuix` (abrir o XML de `cui.getConfigFile()`, achar
  `Window[@objectName='Main Toolbar']`, anexar um `<Item type="CTB_MACROBUTTON"
  actionTableID="647394" actionID="<macro>\`<categoria>">`, salvar,
  `cui.loadConfig`) **põe o botão nativo na Main Toolbar automaticamente**.
- A **lâmpada branca** (BMP `InLabChecker_16i/16a/24i/24a.bmp` em `$usericons`,
  via `icon:#("InLabChecker",1)`) **renderiza com transparência** no botão
  nativo. O problema de transparência citado no `registrar.ms:30-35` era de
  botão de *rollout*; no botão nativo o BMP+máscara funciona (é o que o ArchToolz
  usa). → O truque PNG+dotNet deixa de ser necessário para o botão.
- Tudo reversível por backup/restore do `.cuix`.
- Confirmado: o arquivo de macro é `$usermacros\<categoria>-<nome>.mcr`
  (ex.: `InLab-InLabChecker_Abrir.mcr`).

## Objetivos

- Depois do `.mzp`, o botão da lâmpada branca **aparece sozinho** na Main
  Toolbar do Max. Zero passo manual de Customize.
- O botão **persiste** entre aberturas do Max e **sobrevive à atualização
  semanal** pela pastilha (aponta para um macro/caminho estáveis).
- **Rede de segurança:** se o desenhista resetar a UI / trocar de workspace e o
  botão sumir, ele **volta sozinho na próxima abertura** do Max.
- Clicar no botão abre o painel (carregando o plugin se preciso); o painel
  **não** abre sozinho na abertura do Max (contrato atual preservado).

## Não-objetivos

- **Sem** diálogo INSTALAR/REMOVER (o ArchToolz tem; nós não queremos). A
  instalação do `.mzp` segue silenciosa, como hoje.
- Não mexer no updater (pastilha) nem no `empacotar.ps1`/`publicar_semana.ps1`
  além do necessário (os arquivos já vão no pacote).
- Não redesenhar o ícone: a lâmpada branca já está aprovada.

## Anti-objetivos (o que seria fracasso mesmo "funcionando")

- Reescrever o `.cuix` a cada abertura do Max (risco de corromper/embolar a UI,
  lentidão, perder o arranjo do usuário). A rede de segurança **só grava quando o
  botão está faltando**; no caso normal é leitura barata e nada mais.
- Perder o arranjo de toolbars do usuário na instalação. O `.cuix` é salvo
  (`cui.saveConfigAs`) antes de editar, e a edição é cirúrgica por `actionID`.
- Deixar dois pontos de entrada confusos (a janela flutuante **e** o botão
  nativo). A janela flutuante sai.

## Restrições

- Alvo 3ds Max 2024–2027. **Spike só cobriu o 2024**; 2025 e 2027 precisam de
  validação antes de publicar (a equipe usa 2025; o 2027 não tem Corona). A
  *DialogBar* já quebrou no 2025 no passado — a injeção no `.cuix` é outro
  caminho, o mesmo do ArchToolz 2026.
- MCP do Max roda em `safe_mode` (sem `createFile`/`copyFile` de MaxScript): usar
  `.NET System.IO.File` para copiar, como o resto do `install/`.
- `units.decodeValue`, `case` inline, nomes case-insensitive e as demais
  pegadinhas do `CLAUDE.md` continuam valendo.
- Tudo em português (código, comentário, log, UI).

## Decisões já tomadas (chamadas minhas, revisáveis)

1. **Macro e actionID:** reusar o macro que já existe no `registrar.ms` —
   `macroScript InLabChecker_Abrir`, categoria `InLab`, `icon:#("InLabChecker",1)`.
   `actionID = "InLabChecker_Abrir\`InLab"`, `actionTableID = "647394"` (tabela
   padrão de macroscripts, confirmada no ArchToolz e no spike).
2. **Posição:** anexar no **fim** da Main Toolbar (igual ao ArchToolz). Simples e
   seguro; o botão fica na ponta direita da barra.
3. **Ícone:** manter o conjunto BMP `16i/16a/24i/24a` copiado para `$usericons`.
   O PNG+dotNet da lâmpada continua existindo para onde já é usado (header), mas
   **não** é mais o caminho do botão.
4. **A janela flutuante sai:** o `registrar.ms` deixa de montar
   `InLabChecker_Barra` (createDialog) e passa a **garantir o botão no `.cuix`**:
   lê o `.cuix`, e se não houver `<Item>` com o nosso `actionID`, injeta + salva +
   `loadConfig`; se já houver, não faz nada. Idempotente e barato no boot.
5. **Instalação (`instalar.ms`):** depois de copiar os arquivos e registrar o
   macro, roda a mesma garantia do item 4 (primeira injeção). Segue silenciosa;
   a mensagem final deixa de mandar abrir o Customize.
6. **Startup:** o `inlabchecker_boot.ms` continua chamando o `registrar.ms` a
   cada abertura — agora é ele que serve de rede de segurança. Sem script de
   startup novo.
7. **Updater:** sem mudança. O botão aponta para
   `(getDir #userScripts)\InLabChecker\InLabChecker.ms` (caminho estável) e para
   o `actionID` estável, então sobrevive à troca da pasta pela pastilha.
8. **Docs:** reescrever o passo 2 do `install/README.md` (o botão já aparece
   sozinho; cai o arrasto no Customize), trocar "lâmpada âmbar" por "lâmpada
   branca" e ajustar a seção de desinstalar (tirar o botão = clique direito >
   Delete Button, ou volta no próximo boot se o `.cuix` não for salvo).

## O que fica para quem implementa

- Escrever a injeção/garantia no `.cuix` como função reutilizável (ex.:
  `InLab_GarantirBotaoToolbar`) chamada tanto pelo `instalar.ms` quanto pelo
  `registrar.ms` (boot), com o padrão de fallback do `cui.getConfigFile()`
  undefined (workspace `usersave`), tudo em `try/catch` com `InLab_Log`/`format`.
- Remover o código da janela flutuante (`InLabChecker_Barra`,
  `InLab_Barra_Montar`, `InLab_Barra_Salvar`, `InLab_Barra_IniPath`) do
  `registrar.ms`, mantendo a cópia dos BMP para `$usericons` e o macro.
- Decidir o destino do `install/fixar_barra.ms` (experimento de 15/10 com
  `RegisterDialogBar`, hoje `?? untracked`): provavelmente apagar, já que o botão
  nativo o torna desnecessário.
- Validar em **2025 e 2027** (pelo menos: botão aparece, ícone com transparência,
  clique abre o painel, sobrevive a fechar/reabrir o Max).
- Teste automatizado no padrão `tests/` para a parte testável sem UI (ex.: a
  garantia é idempotente — rodar duas vezes não duplica o `<Item>`; achar o nó da
  Main Toolbar). O `instalar.ms` já tem o modo silencioso
  (`INLAB_INSTALAR_SILENCIOSO`).
- Atualizar o `install/README.md` e os cabeçalhos dos arquivos tocados, com data,
  conforme a convenção.

## Respostas à revisão (16/10) — chamadas minhas

Um revisor leu este design e levantou 3 pontos que mudam o plano. Resolvidos
abaixo (não mudam *o que* é entregue, só *como* é feito):

1. **Assinatura testável de `InLab_GarantirBotaoToolbar`.** A função recebe
   `caminho:` (default `cui.getConfigFile()`) e `recarregar:` (default `true`),
   no mesmo espírito de `INLAB_INSTALAR_DESTINO`/`INLAB_INSTALAR_SILENCIOSO`. A
   parte **pura** (ler o XML, checar o `actionID`, injetar o `<Item>`, salvar o
   arquivo) é separada do **efeito colateral na UI viva** (`cui.saveConfig` +
   `cui.loadConfig`), que só roda quando `recarregar:true`. O teste do `tests/`
   aponta `caminho:` para um `.cuix` de fixture em `(getDir #temp)` com
   `recarregar:false`, e confere o XML escrito + a **idempotência** (rodar duas
   vezes não duplica o `<Item>`) sem tocar na UI do testador.

2. **Flush / backup / restauração em volta da edição viva.** Quando
   `recarregar:true` e o botão está faltando, a ordem é: (a) **flush** do arranjo
   em memória para o disco com `cui.saveConfig()` — assim nenhuma mudança de
   toolbar não-salva do usuário se perde no `loadConfig`; (b) **backup** do
   `.cuix` para um caminho fixo `<cuix>.inlab.bak` (sobrescrito a cada vez) via
   `.NET File.Copy`; (c) editar o XML e salvar; (d) `cui.loadConfig`. Se
   **qualquer** passo de (c)/(d) lançar exceção, **restaura** o `.cuix` do backup
   e refaz o `loadConfig`. Em sucesso, apaga o `.bak`. (Isso é o que o spike já
   fazia.) No caso normal do boot — botão presente — **não há flush, nem
   gravação, nem loadConfig**: só a leitura barata do XML.

3. **No `instalar.ms` (meio da sessão): mostra o botão na hora.** Igual ao
   ArchToolz, o `instalar.ms` chama a garantia com `recarregar:true`, então o
   botão aparece imediatamente (não só no próximo restart). O flush do item 2
   protege o arranjo atual do usuário contra o `loadConfig` do meio da sessão.

Pontos menores que ficam com quem implementa (confirmados): a forma serializada
do atributo `actionId`/`actionID` para o casamento idempotente (inspecionável no
`.cuix` do spike), apagar o `inlabchecker_barra.ini` órfão que a janela flutuante
deixava, commitar os assets da lâmpada (`ui/img/*lamp*`, `_16a/_24a.bmp`) que
estão em `git status`, e a tensão da remoção permanente (clique direito > Delete
Button; a rede de segurança readiciona no próximo boot — comportamento aceito).

## Validação e entrega (decidido com o usuário, 16/10)

- **2024:** spike já validou a injeção + ícone. A implementação completa (fluxo do
  `.mzp`, boot, rede de segurança) é testada aqui de novo via MCP.
- **2027:** eu testo via MCP. **Requer um 3ds Max 2027 aberto e conectado ao
  MCP** — hoje só há o 2024 rodando. Aviso quando o código estiver pronto para o
  usuário abrir o 2027. (2027 não tem Corona, mas isso não afeta esta feature.)
- **2025:** eu gero um `.mzp` **provisório a partir do branch** (via
  `install/empacotar.ps1 -Ref <branch/commit>`) e **entrego o arquivo ao
  usuário**, que testa no 2025 na máquina dele. **Sem publicar:** nada de
  `publicar_semana.ps1`, sem release no GitHub, sem subir versão na `main`. O
  provisório é um artefato de teste, não uma release.
- Só depois do 2025 passar é que a feature entra numa release de verdade.

## Fluxo de entrega

Issue [#194](https://github.com/heinzrfx/InLabChecker/issues/194) + branch
`feat/botao-toolbar-nativo` a partir da `main`. Entra numa release depois de
validado nas três versões. Não é hotfix.
