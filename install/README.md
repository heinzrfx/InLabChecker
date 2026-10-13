# Instalação do InLabChecker

Para 3ds Max 2024 a 2027 (ver nota no fim do passo 2). Não precisa ser administrador. Leva uns 5 minutos e é feito uma vez só por máquina: depois disso o plugin se atualiza pelo próprio painel.

## Do que você precisa

**Pré-requisito: Corona Renderer instalado na mesma versão do Max.** Os materiais do acervo são Corona: sem ele, a conversão de material, o Real World Fix e as verificações de material (V-23 a V-38) não funcionam.

Na página da última release (<https://github.com/heinzrfx/InLabChecker/releases/latest>), em **Assets**, baixe o `InLabChecker-v<versão>.mzp`.

## Passo a passo

**1. Abra o 3ds Max e arraste o `.mzp` para dentro do viewport.** (Ou **Scripting > Run Script...** e escolha o `.mzp`.)

O instalador copia o plugin para a pasta de scripts do seu usuário, instala o script que registra o botão na abertura do Max e abre o painel. No fim aparece a mensagem **"InLabChecker v<versão> instalado"**. Se já havia uma instalação, ela fica guardada como `InLabChecker.bak`.

**2. Ponha o botão numa barra** (só na primeira vez). Nas próximas aberturas do Max o painel **não** abre sozinho: ele abre pelo botão com a lâmpada âmbar.

1. **Customize > Customize User Interface...**
2. Aba **Toolbars**, lista **Category**: escolha **InLab**.
3. Arraste **InLabChecker** da lista para uma barra de ferramentas do Max.

Se o botão aparecer sem a lâmpada (só o texto ou um quadrado vazio), feche e abra o Max de novo: o ícone só aparece na barra a partir da próxima abertura.

**3. Confira a versão.** A primeira linha do log do painel mostra `Sessão InLabChecker v<versão> · ...`.

A instalação é separada por versão do Max, de propósito: cada build pode expor APIs diferentes. Se usar mais de uma versão do Max na mesma máquina, arraste o `.mzp` em cada uma. Depois disso o plugin se atualiza pelo próprio painel.

### Instalação manual (sem o .mzp)

Se o `.mzp` não rodar, baixe o `InLabChecker-v<versão>.zip` e o `inlabchecker_boot.ms` da mesma release e:

1. Feche o 3ds Max.
2. `Win + R` e abra `%LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\scripts` (troque `2024` pelo ano da sua versão).
3. Crie ali a pasta `InLabChecker` (exatamente assim) e extraia o zip dentro dela. O `InLabChecker.ms` tem que ficar **direto** em `scripts\InLabChecker\`, sem uma pasta a mais no meio.
4. Copie `inlabchecker_boot.ms` para `scripts\startup\` (crie a pasta se não existir).
5. Abra o Max e siga o passo 2 acima.

## Se o botão não aparecer ou o painel não abrir

- A instalação pelo `.mzp` falhou: a mensagem diz em que passo. Mande o texto dela junto com o aviso.
- Sem a categoria **InLab** no Customize User Interface: confira se `inlabchecker_boot.ms` está em `scripts\startup\` e reabra o Max.
- Clicou e apareceu "InLabChecker não encontrado": confira se `InLabChecker.ms` está direto em `scripts\InLabChecker\`.
- Abra **Scripting > MAXScript Listener**: um erro aparece lá como `InLabChecker: falha ao ...`. Mande essa linha junto com o aviso.
- Se aparecer a janela **"Instalação Incompleta"**, faltam arquivos na pasta: arraste o `.mzp` de novo.

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
   Gera `InLabChecker-v<versão>.zip` (pacote do updater) e `InLabChecker-v<versão>.mzp` (instalador) a partir do commit, não da pasta de trabalho.
3. Crie a release com a tag `v<versão>` (igual a `INLAB_VERSAO`, com `v` na frente) e anexe o zip, o mzp **e** `install/inlabchecker_boot.ms` (para a instalação manual):
   ```
   gh release create v0.12 InLabChecker-v0.12.zip InLabChecker-v0.12.mzp install/inlabchecker_boot.ms --title "InLabChecker v0.12" --notes "..."
   ```
4. Confira que `https://api.github.com/repos/heinzrfx/InLabChecker/releases/latest` devolve a tag nova com o zip em `assets`.
