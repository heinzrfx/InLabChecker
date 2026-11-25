/*
================================================================================
 ui\rollout_main.ms — orquestra as seções do painel principal (rollout)
--------------------------------------------------------------------------------
 HISTÓRICO (13/Jul, v0.10) — reorganização completa de UI (pedido da equipe,
 ref. ArchToolz):
   - Ordem "Somente seleção" / "Cena inteira" padronizada em todo o plugin.
   - Seções reordenadas: Produto → Otimização → Utilidades → Converter
     Material → Exportar → Verificações → Log (sempre por último). (Seção
     "Família" foi renomeada para "Produto" depois, ver ajuste 23/09/2026
     abaixo.)
   - Log colorido (dotNet RichTextBox — listbox nativo não suporta cor).
   - Splash screen ao abrir.
   - Opção de fixar o painel à esquerda/direita da tela (reposicionamento
     de janela — NÃO é docking real; ver ressalva entregue à equipe).

 AJUSTE 15/Set (debug de UI, pedido Rafael): removidos dois blocos fixos que
 ficavam acima/abaixo das seções:
   - Barra de ferramentas do topo (Copy/Paste Objs/Mat, Paste DWG, Pick Mat)
     — os botões nem chamavam funções carregadas (fn_clipboard.ms não está
     no manifesto INLAB_MODULOS de InLabChecker.ms), então pressioná-los já
     dava erro. Removida por inteiro; fn_clipboard.ms continua no repo,
     intocado, caso a equipe decida reconectar essa função depois.
   - Barra de progresso fixa abaixo das seções (dncProgress/dncProgressLbl).
     InLab_ProgressoIniciar/Parar (core\log.ms) já protegem contra
     InLab_ProgressUI/InLab_ProgressLbl == undefined, então essas chamadas
     (ProOptimizer, Auto UV, Verificações) continuam funcionando normalmente
     como no-op silencioso — nada mais a ajustar nesses outros arquivos.

 ARQUITETURA: cada seção segue sendo um rollout independente, define-before-
 use, comunicação só via globais — mesma disciplina desde a v0.7.

 AJUSTE 22/Set (header-kit-ui, Tarefa 5): botão "Reload Plugin" de 395x22 saiu
 do topo do rollout principal — vira ícone dentro do header (ui\header.ms),
 montado por InLab_Header_Montar em InLabChecker_Rollout.open, antes dos
 AddSubRollout. rdoLado e subSecoes descem 56px (pos: explícito) pra abrir
 espaço pro pnlHeader em pos:[0,0]. A LINHA DE LOG de sessão passa a citar
 INLAB_HEADER_VERSAO_PADRAO em vez de v0.10 hardcoded; a LEGENDA do rollout
 continua literal ("· v0.11") porque legenda de rollout é avaliada em tempo de
 DEFINIÇÃO do rollout, quando um global ainda não vale nada — não dá pra
 interpolar. As duas ficaram na mesma versão, mas por caminhos diferentes: a
 legenda tem que ser atualizada na mão quando a versão subir. A unificação
 geral das strings de versão é do core\versao.ms, de outro sub-projeto.
 23/09/2026 (issue #9): unificado. Legenda e linha de sessão leem INLAB_VERSAO
 (core\versao.ms). A legenda PODE ser expressão — basta a global ter valor
 quando este arquivo é carregado, e versao.ms é o 1º item do manifesto
 (testado no Max 2024). O motivo acima para deixá-la literal não vale mais.
 23/09/2026 (issue #12): o `on open` termina disparando InLab_UpdateChecar
 silencioso:true se a preferência autoCheck (padrão "true") estiver ligada.
 Retorna em ~10 ms; o intervalo de 4 h fica dentro de fn_updater.ms.
 Altura do subRollout (508) e da janela (ver InLab_AbrirUI) MEDIDAS no Max com
 o header montado, não estimadas.

 CONSERTOS DO REVIEW FINAL (22/09/2026): a montagem do header em `on open`
 ganhou try/catch — uma exceção ali deixava o painel SEM SEÇÃO NENHUMA, porque
 os 8 AddSubRollout vêm depois. E o `on open` repinta o ESTADO CORRENTE
 (InLab_Header_EstadoAtual) em vez de forçar #ocioso: forçar apagava o aviso de
 atualização a cada Reload. O `on close` zera também as globais dos controles
 do header, pra não ficarem apontando pra controle destruído.

 23/09/2026 (família ativa): dropdown "Família (verificações)" na seção
 Produto. Escolher um produto pré-preenche a família por
 InLab_Produto_SugerirFamilia (classe + animacao do JSON); mudar o dropdown
 chama InLab_DefinirFamiliaAtiva. Sem isso InLab_FamiliaAtiva nunca tinha
 valor e "Rodar Verificações" / "Alvo da família" só avisavam.

 23/09/2026 (issue #55): seção "Materiais — Utilidades" (InLabSecMatUtil)
 removida da UI e do AddSubRollout. "Selecionar por Material Similar" e
 "Nome do Objeto → Nome do Material" saem de vez (código de
 functions\fn_material_utils.ms e fn_clipboard.ms fica intocado, apagado
 só na limpeza da #52). O botão "Detach por Material" migra para
 Utilidades Rápidas (InLabSecUtil), único uso que sobra da seção.

 23/09/2026 (issue #60): seção Otimização reescrita — medidor em triângulos
 (cena x faixa da família), seletor de passo 1/2/3 e lista de revisão
 (ListView com checkbox). Fala só com InLab_Otim_Calcular/Aplicar/Reverter.
 O ProOptimizer por percentual saiu da tela (o passo 2 faz o mesmo por peça).
 Auto UV, Clean UV e Real World Fix foram para a seção nova "UV e Texturas",
 sem mudar comportamento. A seção Produto repinta o medidor quando a família
 muda (InLab_OtimUI_Atualizar).

 08/10/2026 (issue #129): sai o botão Real World Fix da seção UV e Texturas.
 O RWF roda dentro do Auto UV (antes do Unwrap, sem colapsar) e o Desfazer
 UV desfaz os dois. Limpar UV e Desfazer UV ficam lado a lado.
 14/10/2026 (#185, ajustes do Rafa, item 5): o botão Real World Fix volta,
 acima do Auto UV ("1 · Real World Fix", "2 · Auto UV"); o Auto UV fica
 bloqueado até o objeto passar pelo RWF.

 08/10/2026 (issue #138): sai o dropdown Família da seção Produto. A família
 ativa é a "natureza" do produto escolhido (InLab_Produto_Familia), mostrada
 num rótulo; sem produto ou sem natureza válida fica sem família, e Verificar
 não roda. Família de animação loga #warn (verificações de animação, #117).

 08/10/2026 (issue #125, epic #121 — ajustes pós-v1): a seção Otimização SAI
 inteira (passos 1/2/3, medidor, lista, Comparar) e InLab_OtimUI_Atualizar
 com ela. A seção Utilidades Rápidas (InLabSecUtil) deixa de ser rollout e
 vira um grupo FIXO no painel principal, entre o header e as seções, com os
 mesmos botões mais ProOptimizer + Desfazer (InLab_OtimReduzir, 30% por
 clique, functions\fn_otim_reduzir.ms). O código dos passos antigos sai na
 issue #126. O texto abaixo sobre o medidor é histórico.

 24/09/2026 (issue #54): seção Produto ganha "Ler objetos da seleção" + lista
 objeto → nome + dropdown + "Renomear meshes" (InLab_Produto_RenomearMeshes).
 "Aplicar nomes" passa a renomear só materiais e mapas; "Desfazer nomes"
 volta os dois (mesmo histórico acumulado).

 24/Set/2026 (issue #47): botão "Find Objects" (Utilidades Rápidas) chamava
 InLab_FindObjectsPesados, que não existia — implementada em
 functions\fn_utilidades.ms. lblFindLimite (texto do critério) deixou de
 depender só do `on InLabSecUtil open`: a seção Produto agora também chama
 InLab_UtilUI_AtualizarLimite quando o dropdown Família muda, mesmo padrão
 já usado pelo medidor da Otimização (InLab_OtimUI_Atualizar).

 24/09/2026 (issue #56): saem os radiobuttons "Fixar à esquerda/à direita"
 (rdoLado) — só reposicionavam a janela, não faziam docking de verdade, e
 confundiam o artista. O painel agora abre ONDE FOI FECHADO da última vez,
 lembrado em preferências (core\prefs.ms, chaves "painelX"/"painelY", mesmo
 ini de autoCheck etc.). Substituem InLab_LadoPainel/InLab_PosicionarPainel:
   - InLab_PosicaoValida (pura, testável sem o Max) valida um ponto x,y
     contra uma lista de áreas de trabalho — usada tanto no produto quanto
     no teste com áreas inventadas;
   - InLab_AreasDeTrabalho lê os monitores de verdade (Screen.AllScreens);
   - InLab_PosicaoPainelPadrao é o topo-à-direita de sempre (fallback);
   - InLab_PosicaoPainelLer devolve sempre uma posição válida: lembrada se
     existir e caber na área de trabalho atual, senão o padrão — cobre
     monitor desligado/removido e resolução menor depois de gravar;
   - InLab_PosicaoPainelGravar recebe o rollout (não fixo em
     InLabChecker_Rollout, pra dar de testar com um rollout qualquer) e
     grava a posição atual da janela nas preferências.
 ACHADO NA SONDAGEM: um Rollout aberto não tem propriedade `.pos` legível
 nem gravável ("Unknown property: pos") — só `pos:` no momento do
 createDialog funciona. O antigo `InLabChecker_Rollout.pos = [x, area.Top]`
 (rdoLado changed) sempre lançava essa exceção, engolida pelo try/catch ao
 redor — nunca tinha reposicionado nada de verdade depois da abertura. Pra
 LER a posição de um diálogo já aberto, InLab_PosicaoPainelGravar usa a API
 nativa de janela (InLab_RolloutHWND + windows.getWindowPos), mesma família
 de InLab_FecharPaineisOrfaos logo abaixo.
 A posição agora é aplicada no `createDialog` (InLab_AbrirUI, via pos:),
 não mais dentro de `on open` — sem essa migração não havia risco de frame
 no lugar errado (motivo do "ANTES de qualquer outra coisa" antigo), porque
 createDialog já nasce posicionado. `on close` grava a posição atual antes
 de fechar. subSecoes sobe os 24px do radio removido (pos:[4,88] →
 pos:[4,64]); a altura do diálogo cai de 604 para 580 (mesma conta de
 sempre: 64 + 508 do subRollout + 8 de margem — reconferida no Max).
 ui\splash.ms também lia InLab_LadoPainel (removida): como o splash está
 desligado e não tem mais um "lado" fixo pra herdar, ele volta a abrir
 sempre no topo à direita (mesmo padrão do painel principal na primeira
 vez) — ajuste mínimo só pra não quebrar se alguém religar o splash depois.

 24/09/2026 (issue #63): a Otimização redesenha a viewport depois de
 Calcular, ao trocar de passo e ao marcar/desmarcar uma linha do passo 3 —
 o destaque das faces escondidas (functions\fn_otim_escondidas.ms) só
 desenha as linhas marcadas que estão em INLAB_OTIM_PROPOSTAS.

 30/09/2026 (issue #58): textos da UI simplificados, tabela aprovada em
 docs\superpowers\specs\2026-09-28-textos-ui.md. Regra: o nome fica no
 botão (1 a 3 palavras) e o detalhe vai para o tooltip, sem rótulo
 explicativo em cima (como o ArchToolz). "Desfazer" no lugar de "Reverter".
 Saíram os rótulos lblF2 (Auto UV), lblF34 (Real World Fix) e lblUDetach;
 o ângulo do flatten (spnAnguloUV) ficou sem rótulo, ao lado do Auto UV.
 Saiu o botão "Fechar Plugin" do Log: a janela fecha pelo X.

 15/10/2026: saiu o botão "Usar outro .json..." da seção Produto (o time só
 usa a lista embutida). Verificações ganhou um lembrete fixo no topo,
 acima do tampo acessório (lblLembreteVerif): exceção pedida à regra de 30/09 de não pôr
 rótulo explicativo, porque o passo é esquecido antes de verificar.

 29/10/2026 (issue #214): linha nova no grupo Utilidades Rápidas com Faces
 duplicadas (InLab_FacesDuplicadas, functions\fn_faces_duplicadas.ms), o
 campo Intensidade e o Bump Fix (InLab_BumpFix, fn_material_convert.ms). O
 grupo cresce 28px (122 → 150), subSecoes desce para pos:[4,216] e a janela
 vai de 704 para 732.

 03/11/2026 (pedido do usuário, mockup aprovado: proposta A + fundo escuro da
 B): Utilidades Rápidas reorganizada em 4 linhas com rótulo (Pivot, Malha,
 Material, UV), botões de 21px, sobre um Panel dotNet escuro (pnlUtil, cor
 #FUNDO_PAINEL do kit). Rótulos e botões são controles dotNet filhos das
 peças do fundo (InLab_Util_Montar, INLAB_UTIL_PECAS), com as cores #UTIL_*
 do kit; o clique vai por InLab_Util_Acao. Os campos Bump e canal são
 spinners NATIVOS do Max (comportamento todo do Max, como no ArchToolz),
 ENTRE as peças. Tentativas do mesmo dia que saíram: botões nativos por
 cima de um Panel (o PrintWindow mostrava certo, mas na tela o Panel cobria
 os botões a cada repintura; nem SetWindowPos HWND_BOTTOM nem Region no
 Panel resolveram, porque a janela hospedeira "Afx:..." do dotNetControl
 continua por cima), NumericUpDown (setas brancas do tema do Windows) e
 TextBox com setas próprias (não era o spinner do Max). O limite do Find
 Objects saiu do topo e foi para a dica do botão (atualizarLimite). Botão
 "↶" (só a flecha) ao lado do canal, que desfaz o UVW Clear (InLab_UVWClear_Desfazer). Linha UV nova: UVW Clear (InLab_UVWClear,
 functions\fn_utilidades.ms) com o canal ao lado. Grupo de 150 para 124px,
 subSecoes em pos:[4,188], janela de 732 para 704.
 Minimizar: botão nativo na barra de título, ao lado do X, como no ArchToolz
 (createDialog com #style_minimizebox, InLab_AbrirUI). Minimizada, a janela
 vira uma barra de 160px no canto da tela, e InLab_PosicaoPainelGravar não
 grava essa posição. (Antes houve um botão ▁ no header, que só encolhia a
 janela até o header; trocado a pedido do usuário no mesmo dia.)
================================================================================
*/

----------------------------------------------------------------------
-- SEÇÃO: Produto (Fase 5.2 import · 18/Set renomeação pelo JSON)
----------------------------------------------------------------------
-- Importa o export de nomenclatura da plataforma (Lovable + Supabase),
-- escolhe o produto (pré-selecionado pelo nome do .max = cod_est), liga
-- cada parte a um material da seleção e aplica os nomes oficiais; cada
-- objeto é ligado a um mesh_final à parte ("Renomear meshes", #54). A lógica
-- toda está em functions\fn_renomear_produto.ms; aqui só fica o estado da
-- tela. Lista + dropdown nativos em vez de tabela dotNet: o número de
-- partes varia por produto e rollout não cria controles dinamicamente.
-- 24/Set/2026 (issue #47): mesmo padrão pro rótulo do limite do Find Objects
-- (grupo fixo Utilidades Rápidas do painel principal) — definida depois de
-- InLabChecker_Rollout, chamada
-- daqui quando a família muda no dropdown.
global InLab_UtilUI_AtualizarLimite

global InLab_ProdutoAtivo = undefined -- árvore crua do JSON importado (formato de InLab_ParseJSON)

rollout InLabSecProduto "Produto" width:420
(
    local produtos = #()  -- itens de "produtos" do export importado
    -- 09/10/2026 (issue #136): índices de `produtos` que a busca deixa no
    -- dropdown (paralelo a ddlProduto.items).
    local visiveis = #()
    local materiais = #() -- materiais lidos da seleção
    local ligacoes = #()  -- paralelo às partes do produto escolhido: material ou undefined
    -- 24/09/2026 (#54): objetos têm lista própria (objeto → nome), mesmo
    -- padrão da lista de partes. O Aplicar não renomeia mais objetos.
    local objsMesh = #()   -- objetos lidos para "Renomear meshes"
    local nomesMesh = #()  -- paralelo a objsMesh: mesh_final escolhido ou ""
    local meshesProd = #() -- mesh_final distintos do produto escolhido

    label lblProdutoAtivo "Nenhum produto carregado." align:#left width:395
    -- 09/10/2026 (issue #136): busca por parte do nome ou do código, sem
    -- diferenciar maiúsculas nem acentos. Vazia mostra todos.
    -- 14/10/2026 (#183): a lista vem embutida (dados\produtos.json) e o campo
    -- é para colar o cod_est copiado da plataforma; código exato (ou variante)
    -- escolhe o produto direto. O "Importar" virou "Usar outro .json", no fim.
    -- 15/10/2026: o "Usar outro .json" saiu.
    edittext edtBusca "Código:" width:395 tooltip:"Cole o cod_est copiado da plataforma. Também filtra por parte do nome."
    dropdownlist ddlProduto "Produto:" items:#() width:395
    -- 08/10/2026 (issue #138): família que as verificações usam. Não é mais
    -- escolhida: vem do campo "natureza" do produto (InLab_Produto_Familia).
    label lblFamilia "Família: cole o código do produto" align:#left width:395
    button btnLerSelecao "Ler materiais" width:395 height:24 tooltip:"Lista os materiais dos objetos selecionados."
    listbox lbxPartes "Parte  →  material:" items:#() height:6 width:395
    dropdownlist ddlMaterial "Material da parte:" items:#() width:395
    button btnAplicar "Renomear materiais" width:395 height:24 tooltip:"Dá o nome oficial aos materiais ligados e aos mapas deles. Os objetos são renomeados em 'Renomear objetos', abaixo."
    button btnLerObjetos "Ler objetos" width:395 height:24 tooltip:"Lista os objetos selecionados e sugere o nome de cada um: pelo material ligado acima ou pela semelhança do nome."
    listbox lbxObjetos "Objeto  →  nome novo:" items:#() height:6 width:395
    dropdownlist ddlMesh "Nome do objeto:" items:#() width:395
    button btnRenomearMeshes "Renomear objetos" width:195 height:24 align:#left offset:[2,0] across:2 tooltip:"Dá a cada objeto da lista o nome escolhido. Objeto sem nome escolhido fica como está."
    -- 09/10/2026 (issue #135): "Desfazer nomes" virou Limpar: desfaz os nomes
    -- e zera as listas. O JSON e o produto escolhido ficam.
    button btnLimpar "Limpar" width:195 height:24 align:#right offset:[-1,0] tooltip:"Volta os nomes de materiais, mapas e objetos ao que eram antes de renomear e limpa as listas. O produto escolhido continua."

    fn produtoEscolhido =
        if ddlProduto.selection > 0 and ddlProduto.selection <= visiveis.count then produtos[visiveis[ddlProduto.selection]] else undefined

    -- Refaz o dropdown com os produtos que contêm o termo da busca e mantém
    -- escolhido o produto `idxManter` (índice em `produtos`) se ele continuar
    -- na lista. Devolve true se o produto escolhido mudou.
    -- #183: cod_est exato (ou variante) vence o produto que já estava escolhido.
    fn filtrarProdutos idxManter =
    (
        visiveis = InLab_Produto_Filtrar produtos edtBusca.text
        ddlProduto.items = for i in visiveis collect InLab_Produto_RotuloDaLista produtos[i]
        local exato = InLab_Produto_IndicePorArquivo produtos (trimLeft (trimRight edtBusca.text))
        local pos = findItem visiveis exato
        if pos == 0 do pos = findItem visiveis idxManter
        ddlProduto.selection = if pos > 0 then pos else if visiveis.count > 0 then 1 else 0
        (pos == 0) or (visiveis[pos] != idxManter)
    )

    -- 02/10/2026 (v3): sem as subpartes so3d — o objeto delas usa o material
    -- da parte-mãe (InLab_Produto_PartesDeMaterial).
    fn partesEscolhidas = InLab_Produto_PartesDeMaterial (produtoEscolhido())

    fn atualizarTela =
    (
        local partes = partesEscolhidas()
        local sel = lbxPartes.selection
        lbxPartes.items = for i = 1 to partes.count collect
            ((InLab_Produto_Rotulo partes[i]) + "  →  " + (if ligacoes[i] == undefined then "(sem material)" else ligacoes[i].name))
        if sel > 0 and sel <= partes.count do lbxPartes.selection = sel
        ddlMaterial.items = #("— nenhum —") + (for m in materiais collect m.name)
        local i = lbxPartes.selection
        ddlMaterial.selection = if i > 0 and ligacoes[i] != undefined then (findItem materiais ligacoes[i]) + 1 else 1
    )

    fn atualizarMeshes =
    (
        local sel = lbxObjetos.selection
        lbxObjetos.items = for i = 1 to objsMesh.count collect
        (
            local o = objsMesh[i]
            (if isValidNode o then o.name else "(apagado)") + "  →  " + (if nomesMesh[i] == "" then "(não renomear)" else nomesMesh[i])
        )
        if sel > 0 and sel <= objsMesh.count do lbxObjetos.selection = sel
        ddlMesh.items = #("— não renomear —") + meshesProd
        local i = lbxObjetos.selection
        ddlMesh.selection = if i > 0 and nomesMesh[i] != "" then (findItem meshesProd nomesMesh[i]) + 1 else 1
    )

    -- Refaz a lista de nomes do produto e a pré-ligação dos objetos lidos
    -- (produto trocado ou objetos lidos de novo).
    fn sugerirMeshes =
    (
        local p = produtoEscolhido()
        meshesProd = InLab_Produto_MeshesDoProduto p
        nomesMesh = InLab_Produto_SugerirMeshes p ligacoes objsMesh nomeArquivo:(getFilenameFile maxFileName)
        atualizarMeshes()
    )

    fn mostrarFamilia =
        lblFamilia.text = if InLab_FamiliaAtiva == undefined then "Família: cole o código do produto (vem do campo natureza)"
                          else ("Família: " + (InLab_FamiliaRotulo InLab_FamiliaAtiva.nome) + "  (natureza do JSON)")

    -- 08/10/2026 (issue #138): a família ativa é a natureza do produto
    -- escolhido. Sem produto ou sem natureza válida, fica sem família e as
    -- verificações não rodam.
    fn aplicarFamilia =
    (
        local fam = InLab_Produto_Familia (produtoEscolhido())
        if fam[1] == "" then
        (
            if InLab_FamiliaAtiva != undefined do InLab_DefinirFamiliaAtiva ""
            if produtoEscolhido() != undefined do
                InLab_Log ("Sem família: " + fam[2] + ". As verificações não rodam.") tipo:#err
        )
        -- Mesma família: não define de novo (a importação e a escolha do
        -- produto chamam esta função em sequência; o log saía duplicado).
        else if InLab_FamiliaAtiva == undefined or InLab_FamiliaAtiva.nome != fam[1] do
        (
            InLab_DefinirFamiliaAtiva fam[1]
            if InLab_FamiliaAtiva != undefined and InLab_FamiliaAtiva.animado do
                InLab_Log ("Família de animação: as verificações de animação ainda não existem (issue #117) — rodam as gerais com os limites de " +
                           (InLab_FamiliaRotulo fam[1]) + ".") tipo:#warn
        )
        mostrarFamilia()
        if InLab_UtilUI_AtualizarLimite != undefined do InLab_UtilUI_AtualizarLimite()
    )

    -- 02/10/2026: avisos da escolha do produto — bloqueio (ok_3d = false, ou
    -- cópia de base não liberada: os botões de renomear pulam) e relação
    -- master/cópia de bloco_3d (#93). Ver fn_renomear_produto.ms.
    -- 06/10/2026: também avisa as partes sem matéria-prima (não tecido).
    fn avisarNaoLiberado =
    (
        InLab_Produto_AvisosDeBloco produtos (produtoEscolhido())
        InLab_Produto_AvisosMateriaPrima (produtoEscolhido())
    )

    fn sugerir =
    (
        ligacoes = InLab_Produto_SugerirLigacoes (partesEscolhidas()) materiais
        atualizarTela()
    )

    fn limparProduto =
    (
        InLab_ProdutoAtivo = undefined
        produtos = #()
        visiveis = #()
        ddlProduto.items = #()
        lblProdutoAtivo.text = "Nenhum produto carregado."
        sugerir()
        sugerirMeshes()
        aplicarFamilia()
    )

    -- #183: põe a lista na tela (embutida ou de outro .json). Escolhe o
    -- produto pelo nome do .max; sem ele, fica o 1º e o desenhista cola o
    -- cod_est no campo Código.
    fn carregarDados dados rotulo =
    (
        InLab_ProdutoAtivo = dados
        lblProdutoAtivo.text = rotulo
        produtos = InLab_Produto_Lista dados
        edtBusca.text = ""
        filtrarProdutos 0
        if produtos.count == 0 then
            InLab_Log "Este JSON não tem lista de produtos — use o export da linha (nomenclatura_export_...json), não o nomenclatura_projeto.json." tipo:#warn
        else
        (
            local cod = getFilenameFile maxFileName
            local idx = InLab_Produto_IndicePorArquivo produtos cod -- cod_est ou variante de posição (#92)
            if idx > 0 then
                InLab_Log ("Produto do arquivo aberto: " + ddlProduto.items[idx]) tipo:#ok
            else
                -- Sem produto escolhido (idx 0): nada de família nem aviso de
                -- um produto qualquer até o cod_est ser colado.
                InLab_Log ("Cole o cod_est do produto no campo Código" + (if cod == "" then "." else " (o arquivo '" + cod + "' não é um cod_est da lista).")) tipo:#info
            ddlProduto.selection = idx -- busca vazia: visiveis[idx] == idx
        )
        sugerir()
        sugerirMeshes()
        aplicarFamilia()
        avisarNaoLiberado()
    )

    fn carregarEmbutido =
    (
        local dados = InLab_Produto_CarregarEmbutido()
        if dados == undefined then limparProduto()
        else carregarDados dados ("Lista da plataforma: " + InLab_Produto_ResumoLista dados)
    )

    on ddlProduto selected i do
    (
        sugerir()
        sugerirMeshes()
        aplicarFamilia()
        avisarNaoLiberado()
    )

    -- A cada tecla: o produto escolhido fica se continuar na lista; se sair,
    -- passa a ser o 1º da lista filtrada (ou nenhum), como se fosse escolhido.
    on edtBusca changed txt do
    (
        local atual = if ddlProduto.selection > 0 and ddlProduto.selection <= visiveis.count then visiveis[ddlProduto.selection] else 0
        if filtrarProdutos atual do
        (
            sugerir()
            sugerirMeshes()
            aplicarFamilia()
            avisarNaoLiberado()
        )
    )

    -- Reabrir o painel zera a lista de produtos: a família ativa sai junto.
    -- 14/10/2026 (#183): e a lista embutida volta (lida uma vez por carga).
    on InLabSecProduto open do carregarEmbutido()

    on btnLerSelecao pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            materiais = InLab_Produto_MateriaisDaSelecao objs
            sugerir()
            local n = 0
            for l in ligacoes where l != undefined do n += 1
            InLab_Log (materiais.count as string + " material(is) em " + objs.count as string + " objeto(s) · " +
                       n as string + " parte(s) pré-ligada(s) — confira antes de aplicar.")
        )
    )

    on lbxPartes selected i do atualizarTela()

    on ddlMaterial selected j do
    (
        local i = lbxPartes.selection
        if i == 0 then
            InLab_Log "Marque uma parte na lista antes de escolher o material." tipo:#warn
        else
            ligacoes[i] = if j == 1 then undefined else materiais[j - 1]
        atualizarTela()
    )

    on btnAplicar pressed do
    (
        local p = produtoEscolhido()
        if p == undefined then
            InLab_Log "Importe as informações do produto e escolha o produto antes de renomear os materiais." tipo:#warn
        else if materiais.count == 0 then
            InLab_Log "Clique em 'Ler materiais' antes de renomear." tipo:#warn
        else
        (
            InLab_Produto_Aplicar p ligacoes produtos:produtos
            atualizarTela()
        )
    )

    on btnLerObjetos pressed do
    (
        local p = produtoEscolhido()
        if p == undefined then
            InLab_Log "Importe as informações do produto e escolha o produto antes de ler os objetos." tipo:#warn
        else
        (
            local sel = InLab_SelecaoValida()
            local objs = for o in sel where InLab_EhGeometria o collect o
            if sel.count > 0 and objs.count == 0 then
                InLab_Log "Nenhum objeto de geometria na seleção — nada lido." tipo:#warn
            else if objs.count > 0 do
            (
                objsMesh = objs
                sugerirMeshes()
                InLab_Produto_MeshesDoProduto p avisar:true -- só p/ avisar partes sem mesh_final
                local n = 0
                for nm in nomesMesh where nm != "" do n += 1
                InLab_Log (objs.count as string + " objeto(s) lido(s) · " + n as string + " com nome sugerido · " +
                           meshesProd.count as string + " nome(s) no produto — confira antes de renomear.")
            )
        )
    )

    on lbxObjetos selected i do atualizarMeshes()

    on ddlMesh selected j do
    (
        local i = lbxObjetos.selection
        if i == 0 then
            InLab_Log "Marque um objeto na lista antes de escolher o nome." tipo:#warn
        else
            nomesMesh[i] = if j == 1 then "" else meshesProd[j - 1]
        atualizarMeshes()
    )

    on btnRenomearMeshes pressed do
    (
        if objsMesh.count == 0 then
            InLab_Log "Clique em 'Ler objetos' antes de renomear." tipo:#warn
        else
        (
            InLab_Produto_RenomearMeshes objsMesh nomesMesh produto:(produtoEscolhido()) produtos:produtos
            atualizarMeshes()
        )
    )

    on btnLimpar pressed do
    (
        local n = InLab_Produto_Limpar()
        materiais = #()
        objsMesh = #()
        sugerir()       -- sem materiais: nenhuma parte ligada
        sugerirMeshes() -- sem objetos: lista vazia
        InLab_Log ("Seção Produto limpa" + (if n > 0 then "" else " (nenhum nome para desfazer)") +
                   ". O produto escolhido continua.") tipo:#ok
    )
)

----------------------------------------------------------------------
-- SEÇÃO: UV e Texturas (issue #60)
----------------------------------------------------------------------
-- Auto UV, Clean UV e Real World Fix saíram da seção Otimização sem mudar
-- nada: mesmos controles, mesmos handlers. Os textos entram na revisão #58.
rollout InLabSecUV "UV e Texturas" width:420
(
    -- 18/Set (issue #1): o padding sai da resolução do bake; o Auto UV grava
    -- no canal 3 e não toca no canal 1.
    -- 22/Set: saiu o checkbox "Preferir seams em regiões ocultas", que nunca
    -- teve efeito. 02/10/2026 (issue #4): a sondagem da Tarefa 7b mostrou que
    -- não compensa (docs\superpowers\specs\2026-10-02-autouv-seams-ocultas-
    -- sondagem.md); o checkbox não volta.
    -- 30/09/2026 (issue #58): saem os rótulos de cima do Auto UV e do Real
    -- World Fix: o nome fica no botão, o detalhe no tooltip. O ângulo do
    -- flatten fica sem rótulo, ao lado do botão Auto UV.
    -- 09/10/2026 (issue #131): saiu o dropdown de resolução; o bake é sempre
    -- 1024 (INLAB_RESOLUCAO_BAKE, functions\fn_autouv.ms).
    -- 14/10/2026 (#185, ajustes do Rafa, item 5): o Real World Fix volta a ter
    -- botão, em cima, e vem antes do Auto UV: o Auto UV fica bloqueado nos
    -- objetos que ainda não passaram por ele (InLab_RWF_Feitos).
    -- 22/10/2026 (decisão com a Bianca): o Auto UV é opcional nesta versão (o
    -- canal 3 só serve ao bake, que é V2). Saem os números "1 ·"/"2 ·"; o Auto
    -- UV e o Limpar UV só ligam com o chkAutoUV, desmarcado ao abrir
    -- (INLAB_AUTOUV_OBRIGATORIO, fn_autouv.ms). O Desfazer UV fica sempre
    -- ligado: ele também desfaz o Real World Fix.
    button btnRWF "Real World Fix" width:395 height:24 align:#left offset:[2,0] tooltip:"Converte a escala real dos mapas (Real-World e Triplanar) para funcionar na web. Obrigatório antes de converter e exportar."
    -- 23/10/2026 (botão Mapear, spec 2026-10-23-mapear-design.md): refaz o UV do
    -- material (canal 1) só onde ele está ruim, pela matéria-prima do JSON; vem
    -- depois do Real World Fix. O Desfazer Mapear devolve o UV de antes.
    -- Não há checkbox "Unwrap nas peças grandes de tecido": nas poltronas
    -- Mentha/Vimen o Unwrap (InLab_Mapear ... unwrapGrande:true) deu corte à
    -- vista de 0,7% contra 0,6% do Box no corpo da Mentha e levou 40 s contra
    -- 26 s; nas esferas dos testes unitários foi pior (6,8% contra 3,7%). O
    -- parâmetro unwrapGrande fica no código, sem controle na UI.
    button btnMapear "Mapear" width:195 height:24 align:#left offset:[2,0] across:2 tooltip:"Refaz o UV do material (canal 1) onde ele está ruim: veio da madeira, vivos e costuras, cortes. Usa a matéria-prima do JSON. Depois do Real World Fix."
    button btnMapearRev "Desfazer Mapear" width:195 height:24 align:#right offset:[-1,0] tooltip:"Devolve o UV do material como estava antes do Mapear."
    -- 27/10/2026 (Mapear assistido, spec 2026-10-27-mapear-assistido-design.md, seção 4): o
    -- Painéis automático saiu. Cortar abre o UV do tecido nas arestas de costura que o
    -- desenhista selecionou na base Editable Poly; Sentido alinha a trama do painel à aresta
    -- selecionada (mais o ângulo do spinner). O Desfazer Painéis tem pilha própria. O Ver UV
    -- (checkbutton) troca por um tempo o material da seleção por listras para conferir.
    button btnCortar "Cortar" width:195 height:24 align:#left offset:[2,0] across:2 tooltip:"Abre o UV do tecido nas arestas de costura selecionadas na base Editable Poly. Confira com o Ver UV."
    button btnPaineisRev "Desfazer Painéis" width:195 height:24 align:#right offset:[-1,0] tooltip:"Devolve o UV do tecido como estava antes do Cortar e do Sentido."
    button btnSentido "Sentido" width:195 height:24 align:#left offset:[2,0] across:2 tooltip:"Alinha a trama do painel à aresta selecionada (mais o ângulo)."
    spinner spnAngulo "" range:[-90, 90, 0] type:#float fieldWidth:60 align:#left offset:[8,3] tooltip:"Ângulo (°) somado à aresta-guia do Sentido."
    checkbutton btnVerUV "Ver UV" width:395 height:24 align:#left offset:[2,0] tooltip:"Troca por um tempo o material da seleção por listras para conferir o mapeamento. Desliga sozinho ao salvar e exportar."
    checkbox chkAutoUV "Unwrap" checked:INLAB_AUTOUV_OBRIGATORIO align:#left offset:[2,0]
    button btnF2 "Auto UV" width:130 height:24 align:#left offset:[2,0] across:2 tooltip:"Cria um UV próprio para bake de textura e sombra (canal 3) nos objetos selecionados. Só roda depois do Real World Fix."
    spinner spnAnguloUV "" range:[10, 90, 55] type:#float fieldWidth:45 align:#left offset:[-63,3] tooltip:"Ângulo de corte (°). Quanto maior, menos cortes no UV."
    -- 22/Set: o Check Texture e o Verificar Escala saíram da aba (as funções
    -- continuam em functions\, a V-19 usa INLAB_UNIDADE_PADRAO). No lugar,
    -- o Real World Fix (functions\fn_realworldfix.ms), no trio com Limpar e
    -- Desfazer UV (30/09/2026, #58).
    -- 08/10/2026 (issue #129): o Real World Fix roda dentro do Auto UV e o
    -- botão saiu; ficam Limpar e Desfazer UV (que desfaz também o RWF).
    -- 14/10/2026 (#185): o botão voltou (acima do Auto UV).
    button btnF2Clean "Limpar UV" width:195 height:24 align:#left offset:[2,0] across:2 tooltip:"Remove o UV de bake dos objetos selecionados. O UV do material fica."
    button btnF2Reverter "Desfazer UV" width:195 height:24 align:#right offset:[-1,0] tooltip:"Desfaz o Real World Fix e o Auto UV dos objetos (a escala real dos mapas volta)."

    fn ligarAutoUV estado =
    (
        btnF2.enabled = estado
        spnAnguloUV.enabled = estado
        btnF2Clean.enabled = estado
    )
    on InLabSecUV open do ligarAutoUV chkAutoUV.checked
    on chkAutoUV changed estado do ligarAutoUV estado

    on btnRWF pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_RWF_Rodar objs
    )
    on btnMapear pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            local prod = try (InLabSecProduto.produtoEscolhido()) catch undefined
            if prod == undefined then InLab_Log "Escolha o produto na seção Produto" tipo:#warn
            else
            (
                InLab_ProgressoIniciar "Mapeando..."
                InLab_Mapear objs prod
                InLab_ProgressoParar()
            )
        )
    )
    on btnMapearRev pressed do InLab_ReverterMapear()
    on btnCortar pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            local prod = try (InLabSecProduto.produtoEscolhido()) catch undefined
            if prod == undefined then InLab_Log "Escolha o produto na seção Produto" tipo:#warn
            else
            (
                InLab_ProgressoIniciar "Cortando o UV..."
                InLab_Cortar objs prod
                InLab_ProgressoParar()
            )
        )
    )
    on btnSentido pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            local prod = try (InLabSecProduto.produtoEscolhido()) catch undefined
            if prod == undefined then InLab_Log "Escolha o produto na seção Produto" tipo:#warn
            else
            (
                InLab_ProgressoIniciar "Alinhando o sentido..."
                InLab_Sentido objs spnAngulo.value produto:prod
                InLab_ProgressoParar()
            )
        )
    )
    on btnPaineisRev pressed do InLab_DesfazerPaineis()
    -- 26/10/2026: o botão acompanha o estado real do Ver UV (que também desliga
    -- sozinho ao salvar, resetar, exportar e verificar): reconcilia depois da chamada.
    on btnVerUV changed estado do
    (
        try
        (
            if estado then InLab_VerUV_Ligar (InLab_SelecaoValida())
            else InLab_VerUV_Garantir()   -- desliga e acerta clones com as listras
        )
        catch ( InLab_Log ("Ver UV: " + getCurrentException()) tipo:#err )
        try ( btnVerUV.checked = InLab_VerUV_Ligado() ) catch ()
    )
    on btnF2 pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            InLab_ProgressoIniciar "Gerando Auto UV..."
            InLab_AutoUV objs angulo:spnAnguloUV.value resolucao:INLAB_RESOLUCAO_BAKE
            InLab_ProgressoParar()
        )
    )
    on btnF2Clean pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_CleanUV objs
    )
    on btnF2Reverter pressed do InLab_ReverterAutoUV()
)

----------------------------------------------------------------------
-- SEÇÃO: Converter Material
----------------------------------------------------------------------
rollout InLabSecF5 "Converter Material" width:420
(
    dropdownlist ddlConversao items:#("Corona → glTF (Physical / Legacy / VRay)") selection:1 width:395
    -- 09/10/2026 (issue #131): saiu o dropdown de resolução; o bake é sempre
    -- 1024 (INLAB_RESOLUCAO_BAKE). Fica o checkbox de bake de procedurais.
    checkbox chkBakeProc "Bake de mapas procedurais" checked:true align:#left
    button btnF5 "Converter" width:195 height:24 align:#left offset:[2,0] across:2 tooltip:"Converte os materiais dos objetos selecionados."
    button btnF5Rev "Desfazer" width:195 height:24 align:#right offset:[-1,0] tooltip:"Volta os materiais originais."

    on btnF5 pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            -- 09/10/2026 (issue #153): o produto escolhido decide palha/cristal
            -- pela matéria-prima (materiais já renomeados para o material_id).
            local p = try (InLabSecProduto.produtoEscolhido()) catch undefined
            InLab_ProgressoIniciar "Convertendo materiais..."
            InLab_ConverterObjetos objs tamanhoBake:INLAB_RESOLUCAO_BAKE fazerBake:chkBakeProc.checked produto:p
            InLab_ProgressoParar()
        )
    )
    on btnF5Rev pressed do InLab_ReverterConversao()
)

----------------------------------------------------------------------
-- SEÇÃO: Exportar
----------------------------------------------------------------------
-- BUG 10/Set: o botão chamava export headless (#noPrompt) direto — nunca
-- abria a janela nativa do Real-Time Exporter. Agora ele só garante a
-- seleção certa na viewport e abre a janela nativa; formato/compressão/
-- caminho o usuário escolhe DENTRO dela (ver fn_export_gltf.ms).
rollout InLabSecF6 "Exportar" width:420
(
    radiobuttons rdoEscopoExp labels:#("Somente seleção", "Cena inteira") default:1 columns:2
    button btnF6 "Exportar GLB..." width:395 height:24 tooltip:"Abre o exportador do Max com as opções da InLab."

    on btnF6 pressed do
    (
        local soSelecao = (rdoEscopoExp.state == 1)
        if soSelecao and selection.count == 0 then
            InLab_Log "Selecione os objetos a exportar (ou mude para cena inteira)." tipo:#warn
        else
        (
            local objs = if soSelecao then (for o in selection collect o) else undefined
            -- 15/10/2026: master/cópia de bloco_3d (interno/externo) precisa
            -- de um export por código. Janela que o desenhista tem que fechar.
            local p = try (InLabSecProduto.produtoEscolhido()) catch undefined
            local aviso = if p == undefined then "" else InLab_Produto_AvisoExportCopias InLabSecProduto.produtos p
            if aviso != "" do
            (
                InLab_Log (substituteString aviso "\n" " ") tipo:#warn
                messageBox aviso title:"InLabChecker · exportar mais de uma vez"
            )
            InLab_AbrirExportadorRealTime objs somenteSelecao:soSelecao
        )
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Verificações (sem mudanças de lógica — só reordenada)
----------------------------------------------------------------------
rollout InLabSecFase4 "Verificações" width:420
(
    -- 15/10/2026: lembrete fixo do que fazer antes de verificar.
    label lblLembreteVerif "Antes de verificar: Reset XForm, Center Pivot, pivot na base e posição zerada (X, Y e Z = 0)." align:#left width:395 height:28
    checkbox chkTampoAcess "Produto com tampo acessório" checked:false tooltip:"Só para mesas (família Pernas + Tampo)."
    button btnVerificar "Verificar" width:395 height:24 tooltip:"Confere o produto e salva o relatório ao lado do arquivo."

    on btnVerificar pressed do
    (
        if InLab_FamiliaAtiva == undefined then
            InLab_Log "Sem família: cole o cod_est na seção Produto (a família vem do campo natureza)." tipo:#warn
        else
        (
            -- Produto escolhido na seção Produto vai para o relatório (issue #37)
            -- e para a V-20, que confere os nomes contra ele (issue #36). #184:
            -- com ele, o salvar pede <cod_est>.max se o arquivo está fora do padrão.
            local p = try (InLabSecProduto.produtoEscolhido()) catch undefined
            if InLab_SalvarAntesDeVerificar produto:p do
            (
                local cod = if p == undefined then "" else InLab_Produto_Texto p "cod_est"
                local nomeP = if p == undefined then "" else InLab_Produto_Texto p "nome"
                InLab_ProgressoIniciar "Rodando verificações..."
                InLab_RodarVerificacoes InLab_FamiliaAtiva tampoAcessorio:chkTampoAcess.checked codEst:cod nomeProduto:nomeP produto:p
                InLab_ProgressoParar()
            )
        )
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Log (sempre por último — regra fixa independente de novas seções)
----------------------------------------------------------------------
rollout InLabSecLog "Log de Sessão" width:420
(
    dotNetControl rtbLog "System.Windows.Forms.RichTextBox" width:398 height:220
    button btnLimpar "Limpar" width:195 height:24 align:#left offset:[2,0] across:2
    button btnSalvar "Salvar" width:195 height:24 align:#right offset:[-1,0]

    on InLabSecLog open do
    (
        rtbLog.ReadOnly   = true
        rtbLog.BackColor  = (dotNetClass "System.Drawing.Color").FromArgb 30 30 30
        rtbLog.ForeColor  = (dotNetClass "System.Drawing.Color").FromArgb 210 210 210
        rtbLog.Font       = dotNetObject "System.Drawing.Font" "Consolas" 9
        rtbLog.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").None
        InLab_LogUI = rtbLog
        InLab_RefreshLogUI()
    )

    on btnLimpar pressed do InLab_LimparLog()
    on btnSalvar pressed do
    (
        local f = getSaveFileName caption:"Salvar log da sessão" types:"Arquivo de texto (*.txt)|*.txt"
        if f != undefined do
        (
            local salvoEm = InLab_SalvarLog f
            if salvoEm != undefined then InLab_Log ("Log salvo em: " + salvoEm) tipo:#ok
            else InLab_Log "Falha ao salvar o log em ambos os caminhos — reportar." tipo:#err
        )
    )
)

----------------------------------------------------------------------
-- Gancho do Ver UV (26/10/2026): functions\fn_ver_uv.ms chama no fim de Ligar e
-- Desligar, inclusive nos desligamentos automaticos (salvar, resetar, exportar,
-- verificar), para o botao acompanhar o estado real. Nunca lanca erro.
----------------------------------------------------------------------
global InLabSecUV
InLab_VerUV_SincronizarUI = fn _sincronizarVerUV =
(
    try
    (
        if InLabSecUV != undefined and InLabSecUV.isDisplayed do
            InLabSecUV.btnVerUV.checked = (InLab_VerUV_Ligado())
    )
    catch ( try ( InLab_Log ("Ver UV: não sincronizei o botão (" + getCurrentException() + ")") tipo:#warn ) catch () )
)

----------------------------------------------------------------------
-- ROLLOUT PRINCIPAL
----------------------------------------------------------------------
-- POSIÇÃO DO PAINEL (issue #56) — lembrada nas preferências em vez de um
-- "lado" fixo. Ver o AJUSTE 24/09/2026 no cabeçalho do arquivo.
------------------------------------------------------------------
-- Largura fixa do diálogo — usada só pro fallback padrão (topo à direita).
global INLAB_PAINEL_LARGURA = 446

-- Quantos px do canto superior esquerdo do painel têm que caber dentro de
-- alguma área de trabalho pra posição contar como válida. Não é a largura
-- inteira do painel: só o suficiente pra garantir uma pegada (barra de
-- título) visível — o resto pode sobrar fora da tela sem problema.
global INLAB_PAINEL_MARGEM_VISIVEL = 80

-- PURA — testável sem o Max/dotNet: 'areas' é um array de arrays
-- #(esquerda, topo, direita, baixo), uma por monitor (formato que
-- InLab_AreasDeTrabalho devolve). x/y é o canto superior esquerdo do
-- painel. Cobre monitor desligado/removido e resolução menor depois de
-- a posição ter sido gravada.
global InLab_PosicaoValida
fn InLab_PosicaoValida x y areas =
(
    local ok = false
    if x != undefined and y != undefined and areas != undefined do
        for a in areas where (x >= a[1] and x <= (a[3] - INLAB_PAINEL_MARGEM_VISIVEL) \
                and y >= a[2] and y <= (a[4] - INLAB_PAINEL_MARGEM_VISIVEL)) do ok = true
    ok
)

-- Enumera os monitores de verdade no formato que InLab_PosicaoValida espera
-- (WorkingArea, não Bounds: não conta a barra de tarefas como área útil).
-- Falha (sessão sem dotNet, sem monitor) devolve array vazio — toda posição
-- vira inválida e InLab_PosicaoPainelLer cai no padrão; nunca trava.
global InLab_AreasDeTrabalho
fn InLab_AreasDeTrabalho =
(
    local areas = #()
    try
    (
        for tela in (dotNetClass "System.Windows.Forms.Screen").AllScreens do
        (
            local wa = tela.WorkingArea
            append areas #(wa.Left, wa.Top, wa.Right, wa.Bottom)
        )
    )
    catch ( InLab_Log ("Preferências: falha ao ler os monitores (" + getCurrentException() + ").") tipo:#warn )
    areas
)

-- Padrão de sempre: topo à direita da tela PRIMÁRIA. Usado na 1ª execução,
-- com posição inválida ou com o ini corrompido.
-- Devolve Point2 (não Array): é o que .pos e o parâmetro pos: de
-- createDialog esperam — ver InLab_AbrirUI e InLab_PosicaoPainelGravar.
global InLab_PosicaoPainelPadrao
fn InLab_PosicaoPainelPadrao =
(
    local area = (dotNetClass "System.Windows.Forms.Screen").PrimaryScreen.WorkingArea
    [area.Right - INLAB_PAINEL_LARGURA, area.Top]
)

-- Lê a posição lembrada nas preferências; sem preferência gravada, com
-- valor não numérico ou fora da área de trabalho atual, cai no padrão.
-- Sempre devolve uma posição válida (Point2) — quem chama nunca precisa
-- checar.
global InLab_PosicaoPainelLer
fn InLab_PosicaoPainelLer =
(
    local pos = InLab_PosicaoPainelPadrao()
    local xs = InLab_PrefLer "painelX" ""
    local ys = InLab_PrefLer "painelY" ""
    if xs != "" and ys != "" do
    (
        local x = undefined
        local y = undefined
        try ( x = xs as integer; y = ys as integer ) catch ()
        if x != undefined and y != undefined and (InLab_PosicaoValida x y (InLab_AreasDeTrabalho())) do
            pos = [x, y]
    )
    pos
)

-- ACHADO NA SONDAGEM (24/09/2026): um Rollout aberto por createDialog NÃO
-- tem propriedade `.pos` legível nem gravável ("Unknown property: pos") —
-- só `pos:` no MOMENTO do createDialog funciona (é o que InLab_AbrirUI usa
-- pra abrir já no lugar certo). O antigo `InLabChecker_Rollout.pos = [x,
-- area.Top]` (rdoLado changed) sempre lançava essa mesma exceção e o
-- try/catch ao redor engolia — nunca tinha reposicionado nada de verdade,
-- só o X inicial da abertura é que colava. Pra LER a posição atual de um
-- diálogo já aberto (grava no on close) tem que ir pela API nativa de
-- janela do struct `windows` (mesma família de InLab_FecharPaineisOrfaos,
-- abaixo, e da sondagem do header documentada no CLAUDE.md): acha o HWND
-- pelo título exato do rollout e lê windows.getWindowPos.
global InLab_RolloutHWND
fn InLab_RolloutHWND rlt =
(
    local hwnd = undefined
    local titulo = rlt.title
    local maxHwnd = windows.getMAXHWND()
    for w in (windows.getChildrenHWND (windows.getDesktopHWND()))
        where w[3] == maxHwnd and w[4] == "MAXScriptDialog" and w[5] == titulo do
        hwnd = w[1]
    hwnd
)

-- Grava a posição atual de 'rlt' nas preferências (chamada no on close).
-- Recebe o rollout em vez de usar InLabChecker_Rollout fixo — dá pra testar
-- com um rollout qualquer, sem abrir o painel inteiro.
global InLab_PosicaoPainelGravar
fn InLab_PosicaoPainelGravar rlt =
(
    local ok = false
    try
    (
        local caixa = windows.getWindowPos (InLab_RolloutHWND rlt)
        -- 03/11/2026: minimizada (botão da barra de título), a janela vira
        -- uma barra de 160px no canto da tela. Gravar essa posição reabriria o
        -- painel lá: fica a última posição boa. Minimizada, GetDialogSize
        -- devolve [0,0] (sondado no Max 2024; rlt.width dá 0 depois do
        -- createDialog com largura, não serve de referência).
        if (GetDialogSize rlt).x == 0 then
            InLab_Log "Painel fechado minimizado: a posição gravada continua a anterior." tipo:#info
        else
        (
            InLab_PrefGravar "painelX" (caixa.x as integer)
            InLab_PrefGravar "painelY" (caixa.y as integer)
            ok = true
        )
    )
    catch ( InLab_Log ("Preferências: falha ao gravar a posição do painel (" + getCurrentException() + ").") tipo:#warn )
    ok
)

-- UTILIDADES RÁPIDAS (03/11/2026): tudo é controle dotNet filho do pnlUtil
-- (rótulos, botões e os dois campos). Primeira versão punha botões NATIVOS
-- por cima do Panel: no print interno (PrintWindow) aparecia certo, mas na
-- tela o Panel cobria os botões a cada repintura (mouse por cima, janela na
-- frente); mandar o Panel para o fundo da pilha (SetWindowPos HWND_BOTTOM)
-- não resolveu. Filho de Panel não briga com ninguém, como no header.
-- Coordenadas em relação ao pnlUtil, que está em pos:[4,60] do painel.
-- Handler de evento dotNet não enxerga local de rollout (ver ui\header.ms):
-- os campos ficam em global e o clique passa por InLab_Util_Acao.
global InLab_Util_BtnFind, InLab_Util_SpnBump, InLab_Util_SpnCanal, InLab_Util_Dica
global InLab_Util_Montar, InLab_Util_Acao, InLab_Util_OnClique, InLab_Util_ValorCampo

-- CAMPOS NUMÉRICOS (03/11/2026): spinner NATIVO do Max (spnUBump,
-- spnUCanal no rollout), com o comportamento todo do Max (arrastar com o
-- cursor escondido, aceleração, botão direito zera), como no ArchToolz.
-- Saíram no mesmo dia: NumericUpDown (setas brancas do tema do Windows,
-- System.Decimal arredondado pelo MaxScript) e TextBox com setas próprias
-- (não é o spinner do Max).
-- O FUNDO É FEITO DE PEÇAS (INLAB_UTIL_PECAS): controle nativo por cima de
-- um dotNetControl some a cada repintura dele, e recortar o Panel (Region)
-- não basta, porque o MaxScript hospeda o dotNet numa janela "Afx:..." que
-- continua cobrindo o spinner (sondado no Max 2024). As peças só encostam
-- nos spinners, sem cobrir. InLab_Util_SpnBump/SpnCanal apontam para os
-- spinners (on open).
global INLAB_UTIL_PECAS, InLab_Util_ConferirCampos

-- Peças do fundo, em coordenadas do grupo (canto em pos:[4,60] do painel):
-- #(nome do dotNetControl, x, y, largura, altura). Os spinners ficam em
-- x 301..346, y 74..90 (Bump) e 99..115 (canal), medidos no Max 2024.
INLAB_UTIL_PECAS = #(
    #(#pnlUtil,     0,   0, 438, 71),   -- título, Pivot, Malha
    #(#pnlUtilEsq,  0,  71, 301, 53),   -- Material, UV (botões e rótulos)
    #(#pnlUtilDir, 346,  71,  92, 53),  -- Bump Fix, ↶ (desfaz o UVW Clear)
    #(#pnlUtilS1,  301,  71,  45,  3),  -- acima do Bump
    #(#pnlUtilS2,  301,  90,  45,  9),  -- entre Bump e canal
    #(#pnlUtilS3,  301, 115,  45,  9))  -- abaixo do canal

-- Valor de um spinner (nativo ou qualquer coisa com .value).
fn InLab_Util_ValorCampo spn = spn.value

-- Quantos pedaços de spinner (CustEdit, SpinnerControl) encostam por cima
-- de alguma peça do fundo. 0 = tudo certo. pecas: #(#(pnl, x, y)) com o
-- Panel já posicionado; dlg: HWND do diálogo.
fn InLab_Util_ConferirCampos pecas dlg =
(
    local n = 0
    for c in (windows.getChildrenHWND dlg) where c[2] == dlg and (c[4] == "CustEdit" or c[4] == "SpinnerControl") do
    (
        local s = windows.getWindowPos c[1]
        for pc in pecas do
        (
            local o = pc[1].PointToScreen (dotNetObject "System.Drawing.Point" 0 0)
            if s.x < o.X + pc[1].Width and o.X < s.x + s.w and s.y < o.Y + pc[1].Height and o.Y < s.y + s.h do n += 1
        )
    )
    n
)

-- Ação de cada botão, pelo Tag (nome). Separada do clique para dar teste.
fn InLab_Util_Acao acao =
(
    local comSelecao = #(#resetx, #center, #base, #otimizar, #separar, #uvwclear)
    local objs = if findItem comSelecao acao > 0 then InLab_SelecaoValida() else #()
    case acao of
    (
        #resetx:   if objs.count > 0 do InLab_ResetXFormSelecao objs
        #center:   if objs.count > 0 do InLab_CentralizarPivot objs
        #base:     if objs.count > 0 do InLab_BasePivot objs
        #otimizar: if objs.count > 0 do InLab_OtimReduzir objs
        #otimdesf: InLab_OtimReduzir_Desfazer()
        #find:     InLab_FindObjectsPesados()
        #facesdup: InLab_FacesDuplicadas()
        #separar:  if objs.count > 0 do InLab_DetachPorMaterialSelecao objs
        #bumpfix:  InLab_BumpFix (InLab_Util_ValorCampo InLab_Util_SpnBump)
        #uvwdesf:  InLab_UVWClear_Desfazer()
        #uvwclear:
        (
            local canal = (InLab_Util_ValorCampo InLab_Util_SpnCanal) as integer
            -- Canal 1 é o UV do material: limpar sem querer apaga o mapeamento.
            if objs.count > 0 and (canal != 1 or (queryBox "O canal 1 é o UV do material (texturas). Limpar mesmo assim?" title:"UVW Clear")) do
                InLab_UVWClear objs canal
        )
        default: InLab_Log ("Utilidades: ação desconhecida '" + acao as string + "'.") tipo:#err
    )
)

fn InLab_Util_OnClique sender arg =
(
    try ( InLab_Util_Acao (sender.Tag as name) )
    catch ( InLab_Log ("Utilidades: falha no botão '" + sender.Text + "' (" + getCurrentException() + ").") tipo:#err )
)

-- pecas: #(#(Panel, x, y)), x/y do canto da peça em coordenadas do grupo.
-- Cada controle vai para a peça que o contém inteiro (coordenadas abaixo
-- também do grupo). Um Panel só de 438x124 em #(#(pnl, 0, 0)) também serve
-- (é o que o teste usa).
global InLab_Util_PorNaPeca
fn InLab_Util_PorNaPeca pecas ctrl x y w h =
(
    local alvo = undefined
    for pc in pecas where alvo == undefined and x >= pc[2] and y >= pc[3] and         x + w <= pc[2] + pc[1].Width and y + h <= pc[3] + pc[1].Height do alvo = pc
    if alvo == undefined then
        InLab_Log ("Utilidades: '" + ctrl.Text + "' não cabe em nenhuma peça do fundo.") tipo:#err
    else
    (
        ctrl.Location = dotNetObject "System.Drawing.Point" (x - alvo[2]) (y - alvo[3])
        ctrl.Size = dotNetObject "System.Drawing.Size" w h
        alvo[1].Controls.Add ctrl
    )
    alvo != undefined
)

fn InLab_Util_Montar pecas =
(
    local fundo = InLab_Kit_Cor #FUNDO_PAINEL
    for pc in pecas do ( pc[1].Controls.Clear(); pc[1].BackColor = fundo )   -- idempotente
    InLab_Util_Dica = dotNetObject "System.Windows.Forms.ToolTip"
    local fonteBotao = InLab_Kit_Fonte 8.25

    -- #(acao, texto, x, y, largura, dica)
    local botoes = #(
        #("resetx",   "Reset XForm",          62, 22, 120, "ResetXForm e colapsa o stack dos objetos selecionados."),
        #("center",   "Center",              186, 22, 121, "Pivot no centro do bounding box do produto."),
        #("base",     "Base",                311, 22, 121, "Pivot na base do produto (centro XY, fundo em Z)."),
        #("otimizar", "ProOptimizer −30%",    62, 47, 118, ("Tira " + ((100 - INLAB_REDUZIR_FATOR * 100 + 0.5) as integer) as string +
                                                             "% dos vértices de cada peça selecionada. Cada clique é um passo do Ctrl+Z.")),
        #("otimdesf", "↶",                   184, 47,  24, "Desfaz o último clique do ProOptimizer."),
        #("find",     "Find Objects",        216, 47, 110, ("Seleciona os objetos acima de " + ((INLAB_FIND_FRACAO_POLYMAX * 100) as integer) as string +
                                                             "% do máximo de triângulos da família. Sem família: os " +
                                                             INLAB_FIND_TOP_N as string + " objetos mais pesados da cena.")),
        #("facesdup", "Faces dup.",          330, 47, 102, "Seleciona as faces coincidentes que a V-09 reprova. Sem seleção, procura na cena toda. Não apaga nada."),
        #("separar",  "Separar por material", 62, 72, 200, "Divide cada objeto selecionado em um objeto por material."),
        #("bumpfix",  "Bump Fix",            349, 72,  83, "Grava a intensidade ao lado nos materiais glTF com normal map da seleção (sem seleção, da cena toda)."),
        #("uvwclear", "UVW Clear",            62, 97, 200, "Limpa o canal ao lado nos objetos selecionados (UVW Mapping Clear) e colapsa o stack."),
        #("uvwdesf",  "↶",                   349, 97,  24, "Desfaz o último UVW Clear: volta o canal e os modificadores das peças."))
    for b in botoes do
    (
        local btn = dotNetObject "System.Windows.Forms.Button"
        btn.Tag = b[1]
        btn.Text = b[2]
        btn.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
        -- Sem contorno e de cantos arredondados, como no ArchToolz (pedido do
        -- usuário, 03/11/2026); 18px de altura, quase a do spinner (16px).
        btn.FlatAppearance.BorderSize = 0
        btn.FlatAppearance.MouseOverBackColor = InLab_Kit_Cor #UTIL_BOTAO_HOVER
        btn.FlatAppearance.MouseDownBackColor = InLab_Kit_Cor #UTIL_BOTAO_DOWN
        btn.BackColor = InLab_Kit_Cor #UTIL_BOTAO_FUNDO
        btn.ForeColor = InLab_Kit_Cor #UTIL_BOTAO_TEXTO
        btn.Font = fonteBotao
        btn.UseVisualStyleBackColor = false
        dotNet.addEventHandler btn "Click" InLab_Util_OnClique
        InLab_Util_Dica.SetToolTip btn b[6]
        if b[1] == "find" do InLab_Util_BtnFind = btn
        -- y + 1: centra os 18px na linha de 21 (o spinner fica em y+2..y+18).
        if InLab_Util_PorNaPeca pecas btn b[3] (b[4] + 1) b[5] 18 do InLab_Kit_BotaoArredondado btn
    )

    local alinhaDir = (dotNetClass "System.Drawing.ContentAlignment").MiddleRight
    local alinhaEsq = (dotNetClass "System.Drawing.ContentAlignment").MiddleLeft
    -- #(texto, x, y, largura, altura, alinhamento, fonte, cor)
    local itens = #(
        #("UTILIDADES RÁPIDAS", 6, 3, 150, 16, alinhaEsq, InLab_Kit_Fonte 7.5 bold:true, #TEXTO_FORTE),
        #("Pivot",    2, 22, 56, 21, alinhaDir, InLab_Kit_Fonte 8, #TEXTO_FRACO),
        #("Malha",    2, 47, 56, 21, alinhaDir, InLab_Kit_Fonte 8, #TEXTO_FRACO),
        #("Material", 2, 72, 56, 21, alinhaDir, InLab_Kit_Fonte 8, #TEXTO_FRACO),
        #("UV",       2, 97, 56, 21, alinhaDir, InLab_Kit_Fonte 8, #TEXTO_FRACO),
        #("Bump",   266, 72, 34, 21, alinhaEsq, InLab_Kit_Fonte 8, #TEXTO_FRACO),
        #("canal",  266, 97, 34, 21, alinhaEsq, InLab_Kit_Fonte 8, #TEXTO_FRACO))
    for it in itens do
    (
        local lb = dotNetObject "System.Windows.Forms.Label"
        lb.Text = it[1]
        lb.TextAlign = it[6]
        lb.Font = it[7]
        lb.ForeColor = InLab_Kit_Cor it[8]
        lb.BackColor = fundo
        InLab_Util_PorNaPeca pecas lb it[2] it[3] it[4] it[5]
    )
    true
)

-- Altura da janela: subSecoes em y=188 + 508 + 8 de folga.
global INLAB_PAINEL_ALTURA = 704

rollout InLabChecker_Rollout ("InLabChecker · InLab Artefacto · v" + INLAB_VERSAO) width:446
(
    ------------------------------------------------------------------
    -- HEADER (22/09/2026) — faixa de marca com Reload e pastilha de
    -- versão. Substitui o botão "Reload Plugin" de 395x22 que ficava
    -- aqui. O conteúdo é montado por InLab_Header_Montar (ui\header.ms):
    -- rollout não cria controle em tempo de execução, mas filho de Panel
    -- dotNet cria.
    ------------------------------------------------------------------
    dotNetControl pnlHeader "System.Windows.Forms.Panel" pos:[0,0] width:446 height:56

    -- POSIÇÃO DO PAINEL (issue #56): não é mais um controle da tela — sai
    -- daqui o antigo bloco "LADO DO PAINEL" com o radiobutton rdoLado.
    -- subSecoes sobe os 24px que o radio ocupava (pos:[4,88] → pos:[4,64]).
    -- A posição em si (x/y da janela) é lida das preferências e aplicada
    -- direto no createDialog (InLab_AbrirUI, via pos:) — ver o AJUSTE
    -- 24/09/2026 no cabeçalho do arquivo.
    --
    -- UTILIDADES RÁPIDAS (08/10/2026, issue #125): grupo FIXO entre o header
    -- e as seções — não abre nem fecha. Recebe os botões da antiga seção
    -- InLabSecUtil e o ProOptimizer (30% por clique, functions\
    -- fn_otim_reduzir.ms), que substitui a seção Otimização inteira.
    -- subSecoes desce de pos:[4,64] para pos:[4,188].
    -- 29/10/2026 (#214): + linha Faces duplicadas / Intensidade / Bump Fix;
    -- grupo com 150 e subSecoes em pos:[4,216].
    -- 03/11/2026: 4 linhas com rótulo (Pivot, Malha, Material, UV) num Panel
    -- escuro. Rótulos, botões e campos são filhos dele, montados por
    -- InLab_Util_Montar (ver o comentário lá: botão nativo por cima do Panel
    -- sumia na tela a cada repintura).
    -- Peças do fundo escuro (INLAB_UTIL_PECAS: pos = [4,60] + x/y de lá).
    -- Nenhuma cobre os spinners nativos logo abaixo.
    dotNetControl pnlUtil "System.Windows.Forms.Panel" pos:[4,60] width:438 height:71
    dotNetControl pnlUtilEsq "System.Windows.Forms.Panel" pos:[4,131] width:301 height:53
    dotNetControl pnlUtilDir "System.Windows.Forms.Panel" pos:[350,131] width:92 height:53
    dotNetControl pnlUtilS1 "System.Windows.Forms.Panel" pos:[305,131] width:45 height:3
    dotNetControl pnlUtilS2 "System.Windows.Forms.Panel" pos:[305,150] width:45 height:9
    dotNetControl pnlUtilS3 "System.Windows.Forms.Panel" pos:[305,175] width:45 height:9
    -- Spinners nativos do Max, entre as peças.
    spinner spnUBump "" pos:[306,134] width:44 fieldWidth:36 range:[0, 5, 0.3] scale:0.05 type:#float tooltip:"Intensidade do normal map no GLB."
    spinner spnUCanal "" pos:[306,159] width:44 fieldWidth:36 range:[1, 99, INLAB_UVWCLEAR_CANAL_PADRAO] type:#integer tooltip:"Canal de mapeamento a limpar. 1 = UV do material, 3 = UV de bake."

    subRollout subSecoes width:438 height:508 pos:[4,188]

    -- Rótulo do limite do Find Objects (issue #47) — mesma lógica do texto
    -- que InLab_FindObjectsPesados usa para decidir o critério
    -- (functions\fn_utilidades.ms), só para exibição. Chamada no open e pela
    -- seção Produto quando a família muda (InLab_UtilUI_AtualizarLimite).
    -- 03/11/2026: o texto saiu do topo das Utilidades (pedido do usuário) e
    -- foi para a dica do botão Find Objects.
    fn atualizarLimite =
    (
        if InLab_Util_BtnFind != undefined and InLab_Util_Dica != undefined do
            InLab_Util_Dica.SetToolTip InLab_Util_BtnFind (if InLab_FamiliaAtiva != undefined then
                ("Seleciona os objetos acima de " + ((InLab_FamiliaAtiva.polyMax * INLAB_FIND_FRACAO_POLYMAX) as integer) as string +
                 " triângulos (" + ((INLAB_FIND_FRACAO_POLYMAX * 100) as integer) as string +
                 "% do máximo da família '" + InLab_FamiliaAtiva.nome + "').")
            else
                ("Sem família escolhida: seleciona os " + INLAB_FIND_TOP_N as string + " objetos mais pesados da cena."))
    )

    ------------------------------------------------------------------
    -- EVENTOS
    ------------------------------------------------------------------
    on InLabChecker_Rollout open do
    (
        -- GUARDA OBRIGATÓRIA: os 8 AddSubRollout vêm DEPOIS. Sem o try/catch,
        -- uma falha no header (arte corrompida, dotNet fora do ar) abriria o
        -- painel sem nenhuma seção — o plugin inteiro inutilizado por causa de
        -- uma faixa decorativa. Com ele, o header pode faltar e o painel abre.
        try
        (
            InLab_Header_Montar pnlHeader
            -- Repinta o estado CORRENTE, não #ocioso fixo: depois de um Reload
            -- disparado pelo próprio header, InLab_Header_EstadoAtual pode ser
            -- #disponivel e o aviso de atualização tem que sobreviver.
            InLab_Header_Estado InLab_Header_EstadoAtual
        )
        catch
        (
            InLab_Log ("Falha ao montar o header — o painel abre sem a faixa. " + getCurrentException()) tipo:#err
        )
        -- Mesma guarda do header: sem o fundo e os rótulos, os botões das
        -- Utilidades continuam funcionando.
        InLab_Util_SpnBump = spnUBump
        InLab_Util_SpnCanal = spnUCanal
        try
        (
            local pecas = for pc in INLAB_UTIL_PECAS collect #((getProperty InLabChecker_Rollout pc[1]), pc[2], pc[3])
            InLab_Util_Montar pecas
            local dlg = InLab_RolloutHWND InLabChecker_Rollout
            local n = if dlg == undefined then 0 else InLab_Util_ConferirCampos pecas dlg
            if n > 0 do InLab_Log ("Utilidades: " + n as string + " pedaço(s) dos campos Bump/canal encostam no fundo escuro (escala do Windows?) e podem sumir ao repintar.") tipo:#warn
        )
        catch ( InLab_Log ("Utilidades: falha ao montar o fundo e os rótulos (" + getCurrentException() + ").") tipo:#err )

        AddSubRollout subSecoes InLabSecProduto
        AddSubRollout subSecoes InLabSecUV rolledUp:true
        AddSubRollout subSecoes InLabSecF5 rolledUp:true
        -- 09/10/2026 (issue #137): Verificações entre Converter e Exportar.
        AddSubRollout subSecoes InLabSecFase4 rolledUp:true
        AddSubRollout subSecoes InLabSecF6 rolledUp:true
        -- 09/10/2026 (issue #133): a seção Atualização saiu (pastilha do header).
        AddSubRollout subSecoes InLabSecLog
        atualizarLimite()

        InLab_Log ("Sessão InLabChecker v" + INLAB_VERSAO + " · " + localTime)
        -- 08/10/2026 (issue #147): esperado = famílias do manifesto, não 8 fixo.
        local esperadas = InLab_FamiliasEsperadas()
        InLab_Log ("Famílias registradas: " + InLab_Familias.count as string +
                   (if esperadas == undefined then "" else (" de " + esperadas as string)))
        InLab_Log ("Unidade do sistema: " + (InLab_UnidadeSistema() as string))
        if esperadas != undefined and InLab_Familias.count != esperadas do
            InLab_Log "Nem todas as famílias foram carregadas — verificar o manifesto." tipo:#err

        -- Checagem de atualização (issue #12): retorna na hora, a resposta
        -- chega depois pelo callback. O intervalo de 4 h fica dentro de
        -- InLab_UpdateChecar, então reabrir/recarregar o painel não consulta
        -- o GitHub de novo. 09/10/2026 (issue #133): sempre ligada; a
        -- preferência autoCheck (e o checkbox da seção Atualização) saiu.
        try ( InLab_UpdateChecar silencioso:true )
        catch ( InLab_Log ("Atualização: checagem automática falhou (" + getCurrentException() + ").") tipo:#warn )
    )

    -- Fechar o painel destrói os controles dotNet. As globais que apontavam
    -- pra eles têm que ser zeradas junto: InLab_Header_Estado é chamada por
    -- callback assíncrono do updater e, com a global apontando pra controle
    -- morto, ela tentaria pintar o que não existe mais. Zerada, ela cai no
    -- caminho "estado mudou antes de o header ser montado — só guardei", e a
    -- próxima abertura do painel repinta o estado certo.
    on InLabChecker_Rollout close do
    (
        -- Lembra onde o artista deixou o painel (issue #56) — grava ANTES de
        -- zerar as globais do header, mas a ordem entre as duas não importa
        -- de fato (não se tocam): só documentando que .pos ainda é válido
        -- aqui, o controle só morre depois que on close termina.
        InLab_PosicaoPainelGravar InLabChecker_Rollout

        -- 26/10/2026: fechar o painel devolve o material original da seleção
        -- (o Ver UV não pode ficar ligado sem o botão para desligar).
        try ( InLab_VerUV_Garantir() ) catch ( InLab_Log ("Ver UV: não desligou ao fechar: " + getCurrentException()) tipo:#warn )

        InLab_LogUI = undefined
        InLab_Header_Pnl = undefined
        InLab_Header_Marca = undefined
        InLab_Header_Titulo = undefined
        InLab_Header_Sub = undefined
        InLab_Header_BtnReload = undefined
        InLab_Header_Pastilha = undefined
        InLab_Header_Dica = undefined
        InLab_Util_BtnFind = undefined
        InLab_Util_SpnBump = undefined
        InLab_Util_SpnCanal = undefined
        InLab_Util_Dica = undefined
    )
)

-- Repinta o rótulo do limite do Find Objects (grupo Utilidades Rápidas do
-- painel principal). Chamada pela seção Produto quando a família muda.
fn InLab_UtilUI_AtualizarLimite =
    try ( InLabChecker_Rollout.atualizarLimite() )
    catch ( InLab_Log ("Utilidades: rótulo do limite não atualizou (" + getCurrentException() + ").") tipo:#warn )

-- Fecha instância anterior (se existir) e abre a janela já posicionada
-- conforme a última posição lembrada (padrão: topo à direita).
--
-- global explícito aqui: o fileIn deste arquivo pode acontecer de DENTRO
-- de InLab_RecarregarPlugin() (reload), um escopo de função aninhado, o
-- que pode amarrar esta definição ao escopo local do chamador em vez do
-- global — mesmo problema que já resolvemos no InLabChecker.ms, agora
-- também no lado de quem DEFINE a função (bug constatado em 29/Jul).
--
-- SPLASH DESLIGADO (10/Set, pedido Rafael): InLab_MostrarSplash() comentada
-- abaixo — não removida do arquivo (ui\splash.ms continua íntegro) pra ser
-- fácil religar depois. Só descomentar a linha pra voltar a mostrar.
--
-- 23/09/2026 (2 janelas abertas): além do destroyDialog, fecha qualquer
-- painel InLabChecker ÓRFÃO — diálogo cuja variável de rollout já foi
-- redefinida (fileIn do entry point com o painel aberto, bridge do MCP) e
-- que o destroyDialog não alcança mais. Acha pelo título, só entre as
-- janelas desta instância do Max (w[3] = janela principal do Max).
global InLab_FecharPaineisOrfaos
fn InLab_FecharPaineisOrfaos =
(
    local maxHwnd = windows.getMAXHWND()
    local n = 0
    for w in (windows.getChildrenHWND (windows.getDesktopHWND()))
        where w[4] == "MAXScriptDialog" and w[3] == maxHwnd and (matchPattern w[5] pattern:"InLabChecker ·*") do
    (
        try ( UIAccessor.CloseDialog w[1]; n += 1 )
        catch ( format "InLabChecker: não fechou o painel órfão % (%)\n" w[1] (getCurrentException()) )
    )
    n
)

global InLab_AbrirUI
fn InLab_AbrirUI =
(
    try (destroyDialog InLabChecker_Rollout) catch()
    InLab_FecharPaineisOrfaos()
    -- InLab_MostrarSplash()
    -- AJUSTE 24/09/2026 (issue #56) — 580 MEDIDO no Max (não mais estimado):
    -- com o header (56px) + subSecoes (altura 508, pos:[4,64], sem mais o
    -- radiobutton de lado que ocupava 24px acima dele), sobra abaixo do
    -- subRollout = 580 - (64+508) = 8px (mesma folga de sempre). Substitui o
    -- 604 do AJUSTE 22/Set, que incluía os 24px do radiobutton removido.
    -- A posição (x/y da janela) some daqui: agora é InLab_PosicaoPainelLer(),
    -- lida das preferências e aplicada de uma vez via pos: — sem o "pula pro
    -- canto" que existia dentro de on open.
    -- 08/10/2026 (issue #125): +124px do grupo fixo Utilidades Rápidas
    -- (subSecoes em pos:[4,188]): 188 + 508 + 8 de folga = 704.
    -- 29/10/2026 (#214): +28px da linha Faces duplicadas / Bump Fix:
    -- 216 + 508 + 8 = 732.
    -- 03/11/2026: Utilidades em 124px (subSecoes em y=188): 704
    -- (INLAB_PAINEL_ALTURA). Botão de minimizar nativo na barra de título,
    -- ao lado do X, como no ArchToolz (#style_minimizebox; o maximizar fica
    -- cinza). Minimizada, a janela vira uma barra no canto da tela.
    createDialog InLabChecker_Rollout 446 INLAB_PAINEL_ALTURA pos:(InLab_PosicaoPainelLer()) \
        style:#(#style_titlebar, #style_border, #style_sysmenu, #style_minimizebox)
)
