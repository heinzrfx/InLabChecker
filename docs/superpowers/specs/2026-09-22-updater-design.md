# Pipeline de atualizacao assincrona do InLabChecker

**Data:** 22/09/2026
**Status:** aprovado, aguardando implementacao
**Epic:** feat(updater): pipeline de atualizacao assincrona do plugin

---

## 1. Problema

O InLabChecker nao tem distribuicao. Nao existe pacote, nao existe release,
nao existe instalador: cada maquina recebe os arquivos na mao. Isso cria tres
problemas que ja aparecem no codigo de hoje:

- Ninguem sabe em que versao o artista esta. As strings de versao estao
  escritas na mao em 4 lugares e **ja divergiram**: `InLabChecker.ms` diz
  v0.11, `ui/rollout_main.ms` diz v0.10 no titulo e v0.10 na linha de sessao
  do log, `core/log.ms` cita v0.10 no cabecalho.
- Uma correcao entregue nao chega em quem precisa, porque depende de alguem
  lembrar de copiar pasta.
- Um bug reportado nao tem versao junto, entao nao da pra saber se ja foi
  corrigido.

Este documento desenha o mecanismo que resolve os tres: um updater que checa
em segundo plano, avisa, e so aplica com aprovacao do artista.

## 2. Sondagem — o que o ambiente permite

Medido no 3ds Max 2024 via MCP em 22/09/2026, nesta maquina:

| Sondagem | Resultado |
| --- | --- |
| `WebClient.DownloadStringAsync` | chamada retorna em **16 ms**; callback dispara sozinho em **306 ms** |
| Thread do callback | `main_tid=1`, `cb_tid=1` — **callback volta na thread principal do Max** |
| TLS 1.2 + `raw.githubusercontent.com` | 200 OK, sem token |
| `api.github.com/repos/heinzrfx/InLabChecker` | 200 OK — repo publico, acessivel anonimo |
| `api.github.com/.../releases/latest` | **404 — nao existe release publicada** |
| `System.IO.Compression.ZipFile` via `Assembly.Load` (nome forte) | falha |
| ... via `Assembly.LoadWithPartialName` | **OK** — `ZipFile` e `ZipArchive` disponiveis |
| `System.Net.Http.HttpClient` | indisponivel (UNDEF) |
| CLR | 4.0.30319.42000 |

**A medicao que define a arquitetura e a segunda.** Como o callback do
`WebClient` e remarshalado para a thread principal, ele pode escrever no
`InLab_Log`, mexer no rollout e ler a cena sem nenhuma protecao de thread.
Isso elimina a necessidade de `BackgroundWorker`, de fila de mensagens e de
timer de polling. O padrao fica sendo `WebClient` + `dotnet.addEventHandler`
— a mesma disciplina de evento dotNet que `ui/splash.ms` ja usa.

## 3. Decisoes

| Decisao | Escolha | Por que |
| --- | --- | --- |
| Canal | GitHub Releases (zip anexado, tag = versao) | Publicar e ato deliberado. A `main` pode ficar quebrada sem derrubar a equipe. |
| Politica | Checa sozinho, instala so com aprovacao | Nunca troca arquivo debaixo de um trabalho em andamento. |
| Local de instalacao | `%LOCALAPPDATA%\Autodesk\3dsMax\2024 - 64bit\ENU\scripts\InLabChecker\` | Sem admin, sem UAC; o updater escreve livre. Max 2027 vira segunda instalacao, o que e desejavel: APIs variam por build e as versoes precisam poder divergir. |
| Estrategia de troca | Renomeia instalacao para `.bak`, move a nova, recarrega | Rollback e um `renameFile`. |
| Rede de seguranca | Valida `INLAB_MODULOS` no pacote **extraido**, antes de tocar na instalacao | O erro mais provavel (pacote incompleto) e pego com a versao boa ainda intacta. |
| JSON | Reusa `InLab_ParseJSON` de `functions/fn_json.ms` | Ja existe, usa `JavaScriptSerializer` com parser MaxScript como plano B, e nunca deixa excecao escapar. |
| Descompactacao | `ZipFile.ExtractToDirectory` apos `LoadWithPartialName` | Unico caminho que funcionou na sondagem. |

### Descartado

- **Sync arquivo-a-arquivo por hash.** 1,3 MB de texto baixa em menos de um
  segundo; atualizacao incremental nao paga o encadeamento de callbacks
  assincronos nem a manutencao de um `manifesto.json` por release.
- **Stage aplicado no boot** (trocar pastas no script de startup, com o
  plugin ainda nao carregado). Mais seguro, mas o artista clica "Atualizar" e
  nada acontece ate reabrir o Max. Aproveitamos so a ideia de validar antes
  de tocar na instalacao.
- **Rodar o plugin direto do Google Drive.** Arquivo reescrito pelo Drive no
  meio de um `fileIn` produz plugin meio-carregado.

## 4. Componentes

### `core/versao.ms` — primeiro do manifesto

```
global INLAB_VERSAO = "0.12"
fn InLab_CompararVersao a b   -- -1 | 0 | 1
```

`InLab_CompararVersao` compara **componente a componente como numero**, nunca
como string. Em comparacao de string `"0.9"` e maior que `"0.10"`, e esse bug
faria o updater parar de oferecer atualizacao exatamente na virada de dezena.
Aceita e descarta um `v` inicial (`"v0.13"` e `"0.13"` sao iguais), porque a
tag do GitHub costuma ter o prefixo e a constante nao.

Junto vem a limpeza: titulo do rollout, linha de sessao do log e cabecalho do
entry point passam a concatenar `INLAB_VERSAO`.

### `core/prefs.ms`

```
fn InLab_PrefLer chave padrao
fn InLab_PrefGravar chave valor
```

Sobre `getINISetting` / `setINISetting` em
**`(getDir #plugcfg) + "\InLabChecker.ini"`**.

O caminho e fora da pasta do plugin **de proposito**: o update renomeia a
pasta inteira, entao uma preferencia guardada la dentro morreria a cada
atualizacao. Chaves: `autoCheck` (o checkbox), `ultimaChecagem` (timestamp) e
`versaoIgnorada`.

Nasce generico porque o projeto ainda nao tem nenhuma persistencia —
`InLab_LadoPainel` e global em memoria e se perde a cada reload, e e o
proximo candidato obvio a virar preferencia de verdade.

### `functions/fn_updater.ms`

Um unico global de estado, `InLab_Update`, instancia de `UpdateEstado`:

| Campo | Conteudo |
| --- | --- |
| `estado` | `#ocioso` \| `#checando` \| `#disponivel` \| `#baixando` \| `#aplicando` \| `#erro` |
| `versaoRemota` | tag da release, sem o `v` |
| `urlZip`, `tamanhoZip` | asset da release |
| `notasUrl` | link da release, para o botao Notas |
| `msgErro` | causa da ultima falha |
| `token` | inteiro; descarta callback obsoleto |

Publico:

```
fn InLab_UpdateChecar silencioso:false
fn InLab_UpdateBaixarEAplicar
fn InLab_UpdateCancelar
fn InLab_UpdateReverter
fn InLab_UpdateEstadoTexto
```

### `ui/rollout_update.ms`

A secao "Atualizacao", em arquivo proprio. Nao por tamanho de
`rollout_main.ms` (559 linhas), mas porque e a unica secao com estado
assincrono — todas as outras sao sincronas e sem estado.

Os controles **existem sempre** e so mudam `.text`, `.enabled` e `.visible`
conforme `InLab_Update.estado`: rollout em MaxScript nao cria controle em
tempo de execucao, pegadinha ja documentada no CLAUDE.md.

A secao entra por ultimo no `AddSubRollout`, acima do Log — nao e uso diario.
A descoberta fica por conta da tarja (abaixo).

### Tarja de aviso em `ui/rollout_main.ms`

Um `label` logo abaixo do botao "Reload Plugin", `visible:false` por padrao,
que aparece com `"v0.13 disponivel — abra a secao Atualizacao"` quando o
estado e `#disponivel` e a versao nao esta ignorada.

Existe porque **nao da pra trocar a legenda de um rollout em tempo de
execucao** — a ideia mais direta (titulo da secao virar "Atualizacao · v0.13
disponivel") nao e suportada pela linguagem.

### `install/inlabchecker_boot.ms` — fora do manifesto

Tres linhas, copiadas para `...\ENU\scripts\startup\`. Faz `fileIn` do entry
point se ele existir. E o unico arquivo que o artista instala na mao, uma vez.

## 5. Fluxo

### Checagem

`InLab_UpdateChecar silencioso:true` roda na abertura, se `autoCheck` estiver
ligado. Incrementa `token`, dispara `DownloadStringAsync` contra
`/releases/latest` e **retorna imediatamente** (16 ms medidos). O Max abre
normal; ~300 ms depois o callback chega na thread principal.

Duas guardas no callback, as duas por problema real:

- **Token.** Se o artista der "Reload Plugin" durante o voo, o callback volta
  para um rollout destruido e um `InLab_Update` recriado. O callback compara
  seu token com o atual e, divergindo, descarta em silencio. Toda escrita na
  UI vai em `try/catch`.
- **Intervalo minimo.** A API do GitHub da 60 requisicoes/hora por IP
  anonimo. Um estudio atras de um IP, com gente reabrindo o Max o dia todo,
  chega perto. A checagem automatica so roda se passaram 4 h desde
  `ultimaChecagem`. O botao manual ignora o intervalo.

Sendo `InLab_CompararVersao INLAB_VERSAO remota` igual a `-1`, o estado vira
`#disponivel`. **Nada e baixado.** No modo silencioso nao abre janela
nenhuma: so a tarja, a secao e uma linha no log.

### Aplicacao — so no clique

1. `DownloadFileAsync` do zip para `(getDir #temp)\inlab_update\v0.13.zip`.
   `DownloadProgressChanged` alimenta a barra e o log.
2. Confere o tamanho baixado contra o `size` do asset. Pega download
   truncado, que e a falha silenciosa mais provavel.
3. `LoadWithPartialName "System.IO.Compression.FileSystem"`, depois
   `ZipFile.ExtractToDirectory` para `...\inlab_update\v0.13\`.
4. **Valida o manifesto no extraido**: todo caminho de `INLAB_MODULOS` existe
   no pacote? Nao existindo, aborta aqui — instalacao ainda intacta.
5. Renomeia `INLAB_ROOT` para `InLabChecker.bak` (apagando um `.bak` anterior)
   e move o extraido para o lugar.
6. `InLab_RecarregarPlugin()`.

O passo 6 e a segunda rede de seguranca: o reload ja valida os 30 modulos e
**aborta sem carregar nada** se faltar arquivo. Um pacote incompleto nunca
vira plugin meio-carregado.

### Rollback

Disparado se 4, 5 ou 6 falharem: apaga o que entrou, renomeia o `.bak` de
volta, `InLab_RecarregarPlugin()` de novo, loga `tipo:#err` com a causa. O
artista volta a trabalhar na versao anterior sem fechar o Max.

O `.bak` **sobrevive ao sucesso** e so e descartado na proxima atualizacao
bem-sucedida. Isso cobre o caso real: a versao nova subiu, carregou sem erro,
e so entao o artista descobre que quebrou o fluxo dele no meio do turno. O
botao "Voltar para a vX" continua disponivel no estado `#ocioso` enquanto
existir `.bak`.

### Detalhe que parece perigoso e nao e

O passo 5 renomeia a pasta que contem o `fn_updater.ms` **que esta executando
naquele instante**. E seguro: o MaxScript ja compilou o codigo em memoria e
nao rele o arquivo. Vai documentado no cabecalho do arquivo, porque e
exatamente o tipo de coisa que alguem "conserta" depois e quebra.

## 6. Estados da UI

| Estado | Caixa de status | Botoes |
| --- | --- | --- |
| `#ocioso` | verde, "Voce esta na versao mais recente." | Procurar atualizacao agora; Voltar para a vX (se houver `.bak`) |
| `#checando` | neutra, "Consultando o GitHub em segundo plano..." | Procurar (desabilitado) |
| `#disponivel` | ambar, "vX disponivel · N MB" + data | Atualizar agora; Notas; Ignorar |
| `#baixando` / `#aplicando` | neutra + `progressBar` | Cancelar (`WebClient.CancelAsync`) |
| pos-sucesso | verde, "Atualizado para vX" + 3 linhas de log | Voltar para a vX |
| `#erro` | vermelha, "Falha ao aplicar a vX — revertido para vY" | Tentar de novo; Copiar log do erro |

"Ignorar" grava `versaoIgnorada` no ini e silencia **a tarja** daquela versao
— a secao continua mostrando "vX disponivel (ignorada)". Fica calado, nao
invisivel: um artista tres versoes atras ainda e visivel para quem olhar o
painel dele. A proxima versao volta a avisar normalmente.

Mockup navegavel dos seis estados: https://claude.ai/artifact/BmdGKqEzK5qiDALMdcC99L

## 7. Tratamento de erro

Nenhum `try` engole erro sem `InLab_Log`, conforme o CLAUDE.md.

| Falha | Tratamento |
| --- | --- |
| Sem rede / DNS / timeout | `#erro` silencioso no modo automatico (so linha de log `tipo:#warn`); visivel no modo manual |
| 404 em `/releases/latest` | "Nenhuma release publicada ainda" — nao e erro do artista |
| 403 rate limit | Mensagem propria, sugerindo tentar mais tarde |
| JSON malformado | `InLab_ParseJSON` ja retorna `undefined` e loga; updater vira `#erro` |
| Release sem asset `.zip` | `#erro` com causa explicita |
| Tamanho do zip diferente do esperado | Aborta antes de extrair |
| Falha ao extrair | Aborta; instalacao intacta |
| Modulo faltando no pacote | Aborta com a lista dos ausentes; instalacao intacta |
| Falha no swap ou no reload | Rollback completo |
| Callback obsoleto (reload durante o voo) | Descartado pelo token, sem log |

## 8. Testes

Seguem `tests/test_renomear_produto.ms`: pre-declarar globais, `fileIn` so
dos modulos necessarios, substituir `InLab_Log` por logger de arquivo,
`checar "descricao" condicao`, limpar no final. Saida em
`(getDir #temp) + "\inlab_test_<nome>.txt"`.

**Nenhum teste toca a rede.** O que e assincrono e testado pelo callback,
chamado direto com um argumento montado a mao.

| Arquivo | Cobre |
| --- | --- |
| `tests/test_versao.ms` | `0.9 < 0.10`; `v0.13 == 0.13`; igualdade; numero diferente de componentes |
| `tests/test_prefs.ms` | grava e le; padrao quando a chave nao existe; ini sobrevive a pasta do plugin sumir |
| `tests/test_updater_checagem.ms` | JSON de release fixo vira `#disponivel`; versao igual vira `#ocioso`; versao ignorada nao acende a tarja; token divergente e descartado; intervalo de 4 h respeitado |
| `tests/test_updater_aplicar.ms` | zip montado no temp: pacote completo aplica; pacote sem um modulo aborta com instalacao intacta; rollback restaura o `.bak` |

## 9. Ordem de implementacao

1. `feat(versao)` — constante unica e comparacao
2. `feat(prefs)` — ini persistente
3. `chore(dist)` — script de startup e **primeira release publicada**
4. `feat(updater)` — checagem assincrona
5. `feat(updater)` — download, validacao e troca com rollback
6. `feat(ui)` — secao e tarja

A (3) vem antes das (4) e (5) de proposito. Hoje `/releases/latest` responde
404 porque nao existe release nenhuma; sem publicar a primeira, as duas so
podem ser testadas contra JSON de mentira e o primeiro teste real
aconteceria na maquina do artista.

As (4) e (5) sao o mesmo arquivo e mesmo assim ficam separadas: a (4) termina
em `#disponivel` sem baixar nada e a (5) comeca dali. Juntas seriam uma
entrega de ~500 linhas sem ponto de verificacao no meio.

## 10. Fora de escopo

- Atualizacao automatica sem aprovacao do artista.
- Canal de beta / versao por artista.
- Atualizacao do proprio `inlabchecker_boot.ms` (3 linhas estaveis; muda na mao).
- Telemetria de qual maquina esta em qual versao.
- Instalacao para Max 2027 — mesmo mecanismo, instalacao separada, quando o 2027 entrar em uso.
