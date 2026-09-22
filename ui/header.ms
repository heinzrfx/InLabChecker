/*
================================================================================
 ui\header.ms — v0.12 (22/09/2026): faixa de marca no topo do painel
--------------------------------------------------------------------------------
 O QUE E: um System.Windows.Forms.Panel de 56px que mora dentro de
 InLabChecker_Rollout, com a marca a esquerda, o titulo no meio, e a direita o
 botao Reload e a pastilha de versao. A pastilha E o aviso de atualizacao.

 POR QUE dotNet E NAO CONTROLE DE ROLLOUT: rollout nao cria controle em tempo
 de execucao (pegadinha ja no CLAUDE.md), e nao pinta faixa. A restricao vale
 pra controle DE ROLLOUT — filho de Panel dotNet e criado a hora que quiser, e
 e por isso que os 5 estados da pastilha cabem num controle so.

 TODO ESTADO EM GLOBAL, DE PROPOSITO: handler de evento dotNet roda num escopo
 que NAO enxerga `local` do rollout que o declarou — so globais e funcoes de
 nivel superior. Mesma causa-raiz documentada em ui\splash.ms. Nenhum handler
 deste arquivo le local de rollout.

 A ARTE PODE FALTAR: o pacote do updater e validado so contra INLAB_MODULOS,
 que e tudo .ms — um pacote sem ui\img\header_bulbo.png passa na validacao. O
 header entao monta sem a imagem, so com a tipografia, e loga #warn. Ver a
 spec 2026-09-22-header-kit-ui-design.md, secao 6.

 O PNG NAO PODE FICAR TRAVADO: Image.FromFile e Bitmap(String) seguram o
 arquivo enquanto a imagem viver, e o updater precisa renomear a pasta de
 instalacao. Por isso a imagem e copiada pra um Bitmap novo e o original e
 descartado na hora.

 DE ONDE VEM A ARTE: ui\img\header_bulbo.png e derivada de
 G:\Meu Drive\Trabalhos\2026\Artefacto\Logo\9.png, um ativo de design que
 mora FORA deste repo (nao versionado). Só a derivada 120x160 gerada dele —
 ui\img\header_bulbo.png — fica versionada aqui.

 OS 5 ESTADOS (Task 4, 22/09/2026): InLab_Header_Estado pinta a mesma
 pastilha para #ocioso | #checando | #disponivel | #baixando | #erro, via
 InLab_Kit_Pastilha. A pastilha E o aviso de atualizacao — fica ambar e
 clicavel em #disponivel, vermelha e clicavel em #erro; nos demais estados o
 clique (InLab_Header_OnPastilha) nao faz nada. Devolve false em vez de
 levantar excecao porque quem chama e um callback assincrono do updater
 (sub-projeto 3, ainda nao existe) — excecao la dentro morre sem rastro.

 PRE-CONDICAO DE THREAD DE InLab_Header_Estado (22/09/2026): chamar SEMPRE na
 thread principal do 3ds Max. A funcao toca global de MaxScript e controle
 WinForms, e nenhuma das duas coisas e segura fora dela — um callback de
 download NAO roda na thread principal. Quem marshala e o CHAMADOR (o updater,
 sub-projeto 3): ele que faca o Invoke/BeginInvoke num controle do painel, ou
 enfileire num System.Windows.Forms.Timer, antes de chamar isto. Esta funcao
 nao tenta adivinhar a thread de quem chamou.

 O ESTADO SOBREVIVE AO RELOAD (22/09/2026): InLab_Header_EstadoAtual e
 InLab_Header_Versao sao declarados SEM valor e so inicializados se ainda nao
 existirem — `global X = expr` re-executa e sobrescreve a cada fileIn, e o
 fileIn de TODOS os modulos e exatamente o que InLab_RecarregarPlugin faz. Sem
 isso, o cenario real quebrava: o updater acha a v0.13, poe a pastilha em
 #disponivel, o artista clica no Reload que o PROPRIO header hospeda, e o
 aviso sumia. Por isso InLab_Header_Montar termina repintando a partir do
 estado corrente (InLab_Header_Estado InLab_Header_EstadoAtual) em vez de um
 #INFO fixo, e InLabChecker_Rollout.open faz o mesmo em vez de forcar #ocioso.

 RELOAD DE DENTRO DO PROPRIO HEADER (Task 5, 22/09/2026): InLab_RecarregarPlugin
 refaz o fileIn de TODOS os modulos, inclusive deste arquivo, que contem o
 handler que disparou a chamada — mesma classe de risco do passo 5 do updater
 (codigo se substituindo enquanto roda). CAMINHO QUE FICOU: o handler DIRETO
 (InLab_Header_OnReload chamando InLab_RecarregarPlugin() na hora), sem timer.
 Testado no Max via MCP com InLab_Header_BtnReload.PerformClick() (clique de
 verdade no dotNet Button, nao so chamar a funcao do handler à mao): o painel
 fechou, reabriu com o header montado (pnlHeader.Controls.Count > 0 depois),
 altura 604 (valor novo, confirma que rollout_main.ms recarregou de fato), e o
 log mostrou a nova linha de sessao seguida de "Plugin recarregado com
 sucesso." — sem excecao, sem travar. O caminho alternativo com
 System.Windows.Forms.Timer (que adia a chamada pro tick, depois do clique
 retornar) NAO foi necessario e nao foi adicionado a este arquivo; fica
 descrito, com o codigo, no plano — docs\superpowers\plans\
 2026-09-22-header-kit-ui.md, Task 5, Step 7 — como plano B caso um build
 futuro do Max quebre esse caminho direto. (Ate 22/09/2026 este paragrafo
 apontava pro brief em .superpowers\sdd\..., que o .gitignore desta mesma
 branch deixou de fora do repo: depois do merge aquele caminho so existiria
 na maquina de quem escreveu.)

 PENDENCIA CONHECIDA — ESCALA DO WINDOWS A 150% (Task 5, 22/09/2026): NAO
 TESTADO. Testar exige reiniciar o 3ds Max, o que derruba a sessao do MCP no
 meio da tarefa — ninguem confirmou visualmente o header a 150% ainda. Os 56px
 fixos do pnlHeader e o subtitulo em 7pt (InLab_Header_Sub) sao os pontos de
 risco listados na spec (secao 7): a 150% o Max redesenha a UI e as duas
 coisas podem nao acompanhar, cortando o subtitulo ou empurrando a pastilha
 pra fora da faixa. NAO afirmar que funciona a 150% sem ter visto. Se quebrar,
 o conserto nao e chutar outro numero fixo: e trocar os 56px fixos por altura
 DERIVADA da fonte — depois de InLab_Header_Titulo e InLab_Header_Sub terem
 AutoSize:true (ja tem), ler `InLab_Header_Titulo.Height + InLab_Header_Sub.Height
 + 16` dentro de InLab_Header_Montar e devolver esse valor pro pnlHeader.Height
 (e pro InLabChecker_Rollout ajustar o layout abaixo, ja que rdoLado e
 subSecoes tem pos: fixo hoje).
================================================================================
*/

global INLAB_ROOT
global INLAB_HEADER_VERSAO_PADRAO = "0.11"  -- maior versao declarada no repo
                                            -- (InLabChecker.ms). Unificar as
                                            -- strings e do core\versao.ms, na
                                            -- spec do updater.
global InLab_Header_Pnl, InLab_Header_Marca, InLab_Header_Titulo
global InLab_Header_Sub, InLab_Header_BtnReload, InLab_Header_Pastilha
global InLab_Header_Montar, InLab_Header_OnReload
global InLab_RecarregarPlugin

global INLAB_HEADER_ESTADOS = #(#ocioso, #checando, #disponivel, #baixando, #erro)

-- DECLARADOS SEM VALOR, DE PROPOSITO: `global X = expr` re-executa e
-- sobrescreve a cada fileIn, e InLab_RecarregarPlugin refaz o fileIn de todos
-- os modulos. Assim o estado da pastilha (e a versao exibida) sobrevive ao
-- Reload que o proprio header hospeda. Ver o cabecalho.
global InLab_Header_EstadoAtual
global InLab_Header_Versao
if InLab_Header_EstadoAtual == undefined do InLab_Header_EstadoAtual = #ocioso
if InLab_Header_Versao == undefined do InLab_Header_Versao = INLAB_HEADER_VERSAO_PADRAO

global InLab_Header_Estado, InLab_Header_OnPastilha

-- Handler de nivel superior: so le global.
fn InLab_Header_OnReload sender arg =
(
    try ( InLab_RecarregarPlugin() )
    catch ( InLab_Log ("Header: falha no Reload — " + getCurrentException()) tipo:#err )
)

-- Carrega o PNG sem deixar o arquivo travado. Devolve a imagem ou undefined.
fn InLab_Header_CarregarArte caminho =
(
    if not (doesFileExist caminho) then
    (
        InLab_Log ("Header: arte ausente (" + caminho + ") — seguindo sem a marca.") tipo:#warn
        undefined
    )
    else
    (
        local img = undefined
        try
        (
            local tmp = dotNetObject "System.Drawing.Bitmap" caminho
            img = dotNetObject "System.Drawing.Bitmap" tmp
            tmp.Dispose()   -- solta o arquivo; sem isso o updater nao renomeia a pasta
        )
        catch
        (
            InLab_Log ("Header: falha ao ler a arte — " + getCurrentException()) tipo:#warn
            img = undefined
        )
        img
    )
)

fn InLab_Header_Montar pnl =
(
    InLab_Header_Pnl = pnl
    pnl.Controls.Clear()   -- idempotente: montar 2x nao duplica
    pnl.BackColor = InLab_Kit_Cor #FUNDO_HEADER

    -- SEM Anchor (22/09/2026): a pastilha e o Reload tinham Anchor Top|Right,
    -- que nunca dispara — o painel do plugin nao redimensiona e o pnlHeader e
    -- fixo em 446. Como as posicoes ja sao calculadas a partir de pnl.Width,
    -- a ancora era so ruido.

    -- MARCA
    InLab_Header_Marca = dotNetObject "System.Windows.Forms.PictureBox"
    InLab_Header_Marca.Location = dotNetObject "System.Drawing.Point" 10 8
    InLab_Header_Marca.Size = dotNetObject "System.Drawing.Size" 30 40
    InLab_Header_Marca.SizeMode = (dotNetClass "System.Windows.Forms.PictureBoxSizeMode").Zoom
    InLab_Header_Marca.BackColor = InLab_Kit_Cor #FUNDO_HEADER
    local img = InLab_Header_CarregarArte (INLAB_ROOT + @"ui\img\header_bulbo.png")
    if img != undefined do InLab_Header_Marca.Image = img
    pnl.Controls.Add InLab_Header_Marca

    -- TITULO
    InLab_Header_Titulo = dotNetObject "System.Windows.Forms.Label"
    InLab_Header_Titulo.Text = "InLabChecker"
    InLab_Header_Titulo.Font = InLab_Kit_Fonte 11 bold:true
    InLab_Header_Titulo.ForeColor = InLab_Kit_Cor #TEXTO_FORTE
    InLab_Header_Titulo.BackColor = InLab_Kit_Cor #FUNDO_HEADER
    InLab_Header_Titulo.AutoSize = true
    InLab_Header_Titulo.Location = dotNetObject "System.Drawing.Point" 51 10
    pnl.Controls.Add InLab_Header_Titulo

    -- SUBTITULO
    InLab_Header_Sub = dotNetObject "System.Windows.Forms.Label"
    InLab_Header_Sub.Text = "preparação e verificação · InLab artefacto"
    InLab_Header_Sub.Font = InLab_Kit_Fonte 7
    InLab_Header_Sub.ForeColor = InLab_Kit_Cor #TEXTO_FRACO
    InLab_Header_Sub.BackColor = InLab_Kit_Cor #FUNDO_HEADER
    InLab_Header_Sub.AutoSize = true
    InLab_Header_Sub.Location = dotNetObject "System.Drawing.Point" 53 32
    pnl.Controls.Add InLab_Header_Sub

    -- PASTILHA (canto direito; Task 4 pinta o estado)
    InLab_Header_Pastilha = dotNetObject "System.Windows.Forms.Button"
    InLab_Header_Pastilha.Size = dotNetObject "System.Drawing.Size" 74 28
    InLab_Header_Pastilha.Location = dotNetObject "System.Drawing.Point" (pnl.Width - 84) 14
    dotNet.addEventHandler InLab_Header_Pastilha "Click" InLab_Header_OnPastilha
    pnl.Controls.Add InLab_Header_Pastilha

    -- RELOAD
    InLab_Header_BtnReload = dotNetObject "System.Windows.Forms.Button"
    InLab_Header_BtnReload.Size = dotNetObject "System.Drawing.Size" 28 28
    InLab_Header_BtnReload.Location = dotNetObject "System.Drawing.Point" (pnl.Width - 118) 14
    InLab_Header_BtnReload.Text = "⟳"
    InLab_Kit_BotaoIcone InLab_Header_BtnReload
    InLab_Header_BtnReload.Font = InLab_Kit_Fonte 12
    dotNet.addEventHandler InLab_Header_BtnReload "Click" InLab_Header_OnReload
    pnl.Controls.Add InLab_Header_BtnReload

    -- Repinta a partir do ESTADO CORRENTE, nao de um #INFO fixo: depois de um
    -- Reload disparado pelo proprio header, InLab_Header_EstadoAtual pode ser
    -- #disponivel, e o aviso tem que reaparecer. A global esta pre-declarada la
    -- em cima, entao a resolucao em tempo de chamada acha InLab_Header_Estado
    -- mesmo ela sendo definida depois neste arquivo.
    InLab_Header_Estado InLab_Header_EstadoAtual

    true
)

-- Clique na pastilha. Só faz sentido em #disponivel e #erro; nos outros
-- estados a pastilha não é clicável e o handler não faz nada.
--
-- Abrir a seção Atualização é do sub-projeto 3, que ainda não existe: por
-- enquanto o clique registra no log, que é onde o artista já olha.
fn InLab_Header_OnPastilha sender arg =
(
    case InLab_Header_EstadoAtual of
    (
        #disponivel: InLab_Log ("Atualização v" + InLab_Header_Versao + " disponível — a seção Atualização entra no próximo sub-projeto.") tipo:#warn
        #erro:       InLab_Log "A última atualização falhou e foi revertida — o motivo está acima neste log." tipo:#err
        default:     ()
    )
)

-- Pinta a pastilha conforme o estado. Os controles EXISTEM SEMPRE; só mudam
-- cor, texto e cursor — é o que permite cobrir 5 estados num rollout, que não
-- cria controle em tempo de execução.
--
--   estado : #ocioso | #checando | #disponivel | #baixando | #erro
--   versao : troca a versão exibida (em #disponivel, é a versão NOVA)
--   pct    : só usado em #baixando
--
-- Devolve true se aceitou e pintou, false se o estado é inválido OU se a
-- pintura falhou — nunca levanta exceção, porque quem vai chamar isto é um
-- callback assíncrono do updater e uma exceção lá dentro morre sem deixar
-- rastro. O try/catch em volta da pintura é o que torna isso mecanismo e não
-- promessa: com o painel fechado, o controle dotNet pode já ter sido
-- destruído. O estado fica guardado de qualquer jeito, então a próxima
-- montagem do header repinta certo.
--
-- CHAMAR NA THREAD PRINCIPAL DO MAX — ver o cabeçalho deste arquivo.
fn InLab_Header_Estado estado versao:unsupplied pct:0 =
(
    if (findItem INLAB_HEADER_ESTADOS estado) == 0 then
    (
        InLab_Log ("Header: estado desconhecido '" + (estado as string) + "' — mantendo " + (InLab_Header_EstadoAtual as string) + ".") tipo:#warn
        return false
    )
    if versao != unsupplied do InLab_Header_Versao = versao
    InLab_Header_EstadoAtual = estado

    if InLab_Header_Pastilha == undefined then
    (
        InLab_Log "Header: estado mudou antes de o header ser montado — só guardei." tipo:#info
        return true
    )

    local tipo = #INFO
    local texto = "v" + InLab_Header_Versao
    local clicavel = false
    case estado of
    (
        -- #ocioso é INFO (fundo #333333, borda #454545, texto #A8A8A8), como
        -- manda a spec, seção 5. Até 22/09/2026 estava pintando OK (verde) —
        -- o plano é que divergia da spec nessa linha; a spec é a autoridade.
        #ocioso:
        (
            tipo = #INFO
        )
        #checando:
        (
            tipo = #PROGRESSO
            texto = "v" + InLab_Header_Versao + " ···"
        )
        #disponivel:
        (
            tipo = #WARN
            clicavel = true
        )
        #baixando:
        (
            tipo = #PROGRESSO
            texto = (pct as integer) as string + "%"
        )
        #erro:
        (
            tipo = #ERR
            clicavel = true
        )
    )
    local pintou = false
    try
    (
        InLab_Kit_Pastilha InLab_Header_Pastilha tipo texto clicavel:clicavel
        pintou = true
    )
    catch
    (
        InLab_Log ("Header: não consegui pintar a pastilha (painel fechado?) — " + getCurrentException()) tipo:#warn
    )
    pintou
)
