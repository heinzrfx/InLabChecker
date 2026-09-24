# Instalação do InLabChecker

Para 3ds Max 2024 (também roda no 2027 — ver nota no fim do passo 2). Não precisa ser administrador. Leva uns 5 minutos e é feito uma vez só por máquina: depois disso o plugin se atualiza pelo próprio painel.

## Do que você precisa

Na página da última release (<https://github.com/heinzrfx/InLabChecker/releases/latest>), em **Assets**, baixe os dois arquivos:

- `InLabChecker-v<versão>.zip`: o plugin.
- `inlabchecker_boot.ms`: o arquivo que registra o botão do InLabChecker na barra de ferramentas quando o Max abre.

## Passo a passo

**1. Feche o 3ds Max.**

**2. Abra a pasta de scripts do seu usuário.** Aperte `Win + R`, cole o caminho abaixo e dê Enter:

```
%LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\scripts
```

No 3ds Max 2027, o caminho é o mesmo trocando `2024` por `2027` — repita os passos 2 a 6 nessa segunda pasta se usar as duas versões do Max na mesma máquina (instalação separada por versão, de propósito: cada build pode expor APIs diferentes).

**3. Crie ali uma pasta chamada `InLabChecker`** (exatamente assim, com o I, o L e o C maiúsculos).

**4. Extraia o zip dentro dela.** Clique com o botão direito no zip > **Extrair tudo...** > escolha a pasta `InLabChecker` do passo 3. No final, o arquivo `InLabChecker.ms` tem que estar **direto** dentro da pasta, assim:

```
scripts\
  InLabChecker\
    InLabChecker.ms
    core\
    familias\
    functions\
    install\
    report\
    ui\
    verifications\
```

Se ficou `scripts\InLabChecker\InLabChecker-v0.12\InLabChecker.ms` (uma pasta a mais no meio), mova o conteúdo para cima.

**5. Copie `inlabchecker_boot.ms` para a pasta `startup`**, que fica dentro da mesma pasta `scripts`:

```
%LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\scripts\startup
```

Se a pasta `startup` não existir, crie.

**6. Abra o 3ds Max e ponha o botão numa barra** (só na primeira vez). O painel **não** abre sozinho: ele abre pelo botão com a lâmpada âmbar.

1. **Customize > Customize User Interface...**
2. Aba **Toolbars**, lista **Category**: escolha **InLab**.
3. Arraste **InLabChecker** da lista para uma barra de ferramentas do Max.

**7. Clique no botão.** O painel abre, e a primeira linha do log mostra a versão instalada: `Sessão InLabChecker v<versão> · ...`.

Se o botão aparecer sem a lâmpada (só o texto ou um quadrado vazio), feche e abra o Max de novo: o ícone é copiado na primeira abertura e a barra só o mostra na seguinte.

## Se o botão não aparecer ou o painel não abrir

- Sem a categoria **InLab** no Customize User Interface: confira se `inlabchecker_boot.ms` está em `scripts\startup\` (passo 5) e reabra o Max.
- Clicou e apareceu "InLabChecker não encontrado": confira se `InLabChecker.ms` está direto em `scripts\InLabChecker\` (passo 4).
- Abra **Scripting > MAXScript Listener**: um erro aparece lá como `InLabChecker: falha ao ...`. Mande essa linha junto com o aviso.
- Se aparecer a janela **"Instalação Incompleta"**, faltam arquivos na pasta: extraia o zip de novo.

## Desinstalar

Apague `scripts\startup\inlabchecker_boot.ms` e a pasta `scripts\InLabChecker`, e tire o botão da barra (clique direito nele > **Delete Button**). As preferências ficam em `%LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\plugcfg\InLabChecker.ini` e podem ser apagadas também.

---

## Para quem publica a release

1. Suba `INLAB_VERSAO` em `core/versao.ms` e faça o merge na `main`.
2. Na raiz do repo, com a `main` atualizada:
   ```
   powershell -ExecutionPolicy Bypass -File install\empacotar.ps1
   ```
   (`-ExecutionPolicy Bypass` porque o Windows bloqueia `.ps1` por padrão.)
   Gera `InLabChecker-v<versão>.zip` a partir do commit (não da pasta de trabalho).
3. Crie a release com a tag `v<versão>` (igual a `INLAB_VERSAO`, com `v` na frente) e anexe o zip **e** `install/inlabchecker_boot.ms`:
   ```
   gh release create v0.12 InLabChecker-v0.12.zip install/inlabchecker_boot.ms --title "InLabChecker v0.12" --notes "..."
   ```
4. Confira que `https://api.github.com/repos/heinzrfx/InLabChecker/releases/latest` devolve a tag nova com o zip em `assets`.
