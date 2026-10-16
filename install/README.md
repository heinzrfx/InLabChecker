# Instalação do InLabChecker

Para 3ds Max 2024 a 2027 (ver a nota no fim do passo a passo). Não precisa ser administrador. Leva uns 5 minutos e é feito uma vez só por máquina: depois disso o plugin se atualiza pelo próprio painel.

## Do que você precisa

**Pré-requisito: Corona Renderer instalado na mesma versão do Max.** Os materiais do acervo são Corona: sem ele, a conversão de material, o Real World Fix e as verificações de material (V-23 a V-38) não funcionam.

Na página da última release (<https://github.com/heinzrfx/InLabChecker/releases/latest>), em **Assets**, baixe o `InLabChecker-v<versão>.mzp`.

## Passo a passo

**1. Abra o 3ds Max e arraste o `.mzp` para dentro do viewport.** (Ou **Scripting > Run Script...** e escolha o `.mzp`.)

O instalador copia o plugin para a pasta de scripts do seu usuário, instala o script que registra o botão na abertura do Max e abre o painel. No fim aparece a mensagem **"InLabChecker v<versão> instalado"**. Se já havia uma instalação, ela fica guardada como `InLabChecker.bak`.

**2. O botão da lâmpada branca já está na barra** de ferramentas do Max — o instalador o coloca lá sozinho. Nas próximas aberturas do Max o painel **não** abre sozinho: clique no botão para abrir.

Se o botão não aparecer (por exemplo, depois de resetar a UI do Max ou trocar de workspace), feche e abra o Max: na abertura, o `inlabchecker_boot.ms` recoloca o botão na barra.

**3. Confira a versão.** A primeira linha do log do painel mostra `Sessão InLabChecker v<versão> · ...`.

A instalação é separada por versão do Max, de propósito: cada build pode expor APIs diferentes. Se usar mais de uma versão do Max na mesma máquina, arraste o `.mzp` em cada uma. Depois disso o plugin se atualiza pelo próprio painel.

### Instalação manual (sem o .mzp)

Se o `.mzp` não rodar, baixe o `InLabChecker-v<versão>.zip` e o `inlabchecker_boot.ms` da mesma release e:

1. Feche o 3ds Max.
2. `Win + R` e abra `%LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\scripts` (troque `2024` pelo ano da sua versão).
3. Crie ali a pasta `InLabChecker` (exatamente assim) e extraia o zip dentro dela. O `InLabChecker.ms` tem que ficar **direto** em `scripts\InLabChecker\`, sem uma pasta a mais no meio.
4. Copie `inlabchecker_boot.ms` para `scripts\startup\` (crie a pasta se não existir).
5. Abra o Max. Na abertura, o `inlabchecker_boot.ms` registra o botão e o coloca na barra de ferramentas; clique nele para abrir o painel.

## Atualizar

O `.mzp` é só para a primeira instalação. Toda segunda sai uma versão nova, com a lista de produtos da semana e as correções.

- **Automático:** ao abrir o painel, o plugin procura versão nova no GitHub (no máximo uma vez a cada 4 horas). Quando há, a pastilha de versão no topo do painel fica laranja. Clique nela para atualizar.
- **Na hora:** clique na pastilha mesmo sem ela estar laranja. O plugin procura na hora e, se houver versão nova, pergunta se quer atualizar.
- A pastilha mostra a versão instalada. Antes de começar o dia de trabalho, confira se ela é a da última release.
- Se a busca falhar (rede ou firewall bloqueando o GitHub), o log do painel mostra o erro. Nesse caso, baixe o `.mzp` da [última release](https://github.com/heinzrfx/InLabChecker/releases/latest) e arraste para o viewport.

## Se o botão não aparecer ou o painel não abrir

- A instalação pelo `.mzp` falhou: a mensagem diz em que passo. Mande o texto dela junto com o aviso.
- O botão não apareceu na barra: confira se `inlabchecker_boot.ms` está em `scripts\startup\` e reabra o Max (ele recoloca o botão na abertura).
- Clicou e apareceu "InLabChecker não encontrado": confira se `InLabChecker.ms` está direto em `scripts\InLabChecker\`.
- Abra **Scripting > MAXScript Listener**: um erro aparece lá como `InLabChecker: falha ao ...`. Mande essa linha junto com o aviso.
- Se aparecer a janela **"Instalação Incompleta"**, faltam arquivos na pasta: arraste o `.mzp` de novo.

## Desinstalar

Apague primeiro `scripts\startup\inlabchecker_boot.ms` (senão o botão volta na próxima abertura) e a pasta `scripts\InLabChecker`. Depois tire o botão da barra: clique direito nele > **Delete Button**. As preferências ficam em `%LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\plugcfg\InLabChecker.ini` e podem ser apagadas também.

---

## Para quem publica a release

### Release semanal (lista de produtos + correções)

Toda segunda:

1. Exporte a lista de produtos da plataforma (o export da linha, `nomenclatura_export_...json`) e salve em `G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\Lista semanal\produtos.json`, por cima da anterior.
2. As correções de código da semana já devem estar na `main` (por PR).
3. Na raiz do repo, na `main`, sem mudança local:
   ```
   powershell -ExecutionPolicy Bypass -File install\publicar_semana.ps1 -Json "G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\Lista semanal\produtos.json"
   ```
   O script copia a lista para `dados\produtos.json`, sobe a versão (último número + 1, ou `-Versao 1.2.0`), faz o commit e o push na `main` e publica a release com o zip, o mzp e o boot. As notas listam a lista de produtos e os commits desde a última versão. Com `-Teste`, ele só confere a lista e a versão, sem gravar nada.

A lista vai junto no zip público da release: qualquer pessoa pode baixá-la.

### Release manual

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
