# Instalação do InLabChecker

Para 3ds Max 2024. Não precisa ser administrador. Leva uns 5 minutos e é feito uma vez só por máquina: depois disso o plugin se atualiza pelo próprio painel.

## Do que você precisa

Na página da última release (<https://github.com/heinzrfx/InLabChecker/releases/latest>), em **Assets**, baixe os dois arquivos:

- `InLabChecker-v<versão>.zip`: o plugin.
- `inlabchecker_boot.ms`: o arquivo que abre o plugin junto com o Max.

## Passo a passo

**1. Feche o 3ds Max.**

**2. Abra a pasta de scripts do seu usuário.** Aperte `Win + R`, cole o caminho abaixo e dê Enter:

```
%LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\scripts
```

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

**6. Abra o 3ds Max.** O painel do InLabChecker abre sozinho. No log, a primeira linha mostra a versão instalada: `Sessão InLabChecker v0.12 · ...`.

## Opcional: botão na barra de ferramentas

Com o Max aberto: **Scripting > Run Script...** > `scripts\InLabChecker\install\instalar_icone.ms`. Depois, **Customize > Customize User Interface** > aba **Toolbars** > categoria **InLab** > arraste **InLabChecker** para uma barra.

## Se o painel não abrir

- Confira se `InLabChecker.ms` está direto em `scripts\InLabChecker\` (passo 4).
- Confira se `inlabchecker_boot.ms` está em `scripts\startup\` (passo 5).
- Abra **Scripting > MAXScript Listener**: um erro de carga aparece lá como `InLabChecker: falha ao carregar ...`. Mande essa linha junto com o aviso.
- Se aparecer a janela **"Instalação Incompleta"**, faltam arquivos na pasta: extraia o zip de novo.

## Desinstalar

Apague `scripts\startup\inlabchecker_boot.ms` e a pasta `scripts\InLabChecker`. As preferências ficam em `%LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\plugcfg\InLabChecker.ini` e podem ser apagadas também.

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
