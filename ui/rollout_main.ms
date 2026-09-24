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
-- Repinta o medidor da Otimização. Definida depois de InLabSecOtimizacao;
-- declarada aqui porque a seção Produto (abaixo) a chama quando a família muda.
global InLab_OtimUI_Atualizar
-- 24/Set/2026 (issue #47): mesmo padrão pro rótulo do limite do Find Objects
-- (seção Utilidades Rápidas) — definida depois de InLabSecUtil, chamada
-- daqui quando a família muda no dropdown.
global InLab_UtilUI_AtualizarLimite
global INLAB_OTIM_PROPOSTAS = #()

global InLab_ProdutoAtivo = undefined -- árvore crua do JSON importado (formato de InLab_ParseJSON)

rollout InLabSecProduto "Produto" width:420
(
    local produtos = #()  -- itens de "produtos" do export importado
    local materiais = #() -- materiais lidos da seleção
    local ligacoes = #()  -- paralelo às partes do produto escolhido: material ou undefined
    -- 24/09/2026 (#54): objetos têm lista própria (objeto → nome), mesmo
    -- padrão da lista de partes. O Aplicar não renomeia mais objetos.
    local objsMesh = #()   -- objetos lidos para "Renomear meshes"
    local nomesMesh = #()  -- paralelo a objsMesh: mesh_final escolhido ou ""
    local meshesProd = #() -- mesh_final distintos do produto escolhido

    label lblProdutoAtivo "Nenhum produto carregado." align:#left
    button btnImportarProduto "Importar JSON do Produto..." width:395 height:26
    dropdownlist ddlProduto "Produto:" items:#() width:395
    -- 23/09/2026: família que as verificações e o "Alvo da família" usam.
    -- Item 1 = nenhuma; os demais seguem a ordem de InLab_Familias.
    dropdownlist ddlFamilia "Família (verificações):" items:#() width:395
    button btnLerSelecao "Ler materiais da seleção" width:395 height:24
    listbox lbxPartes "Parte  →  material:" items:#() height:6 width:395
    dropdownlist ddlMaterial "Material da parte marcada:" items:#() width:395
    button btnAplicar "Aplicar nomes" width:395 height:26 tooltip:"Dá o nome oficial aos materiais ligados e aos mapas deles. Os objetos são renomeados em 'Renomear meshes', abaixo."
    button btnLerObjetos "Ler objetos da seleção" width:395 height:24 tooltip:"Lista os objetos selecionados e sugere o nome de cada um: pelo material ligado acima ou pela semelhança do nome."
    listbox lbxObjetos "Objeto  →  nome novo:" items:#() height:6 width:395
    dropdownlist ddlMesh "Nome do objeto marcado:" items:#() width:395
    button btnRenomearMeshes "Renomear meshes" width:192 height:26 across:2 tooltip:"Dá a cada objeto da lista o nome escolhido. Objeto sem nome escolhido fica como está."
    button btnDesfazer "Desfazer nomes" width:192 height:26 tooltip:"Volta os nomes de materiais, mapas e objetos ao que eram antes de 'Aplicar nomes' e 'Renomear meshes'."

    fn produtoEscolhido =
        if ddlProduto.selection > 0 and ddlProduto.selection <= produtos.count then produtos[ddlProduto.selection] else undefined

    fn partesEscolhidas =
    (
        local p = produtoEscolhido()
        local partes = if p != undefined then InLab_JSON_Obter p "partes" else undefined
        if isKindOf partes Array then partes else #()
    )

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
        nomesMesh = InLab_Produto_SugerirMeshes p ligacoes objsMesh
        atualizarMeshes()
    )

    fn familiaEscolhida =
        if ddlFamilia.selection > 1 and ddlFamilia.selection <= InLab_Familias.count + 1 then InLab_Familias[ddlFamilia.selection - 1].nome else ""

    fn mostrarFamilia =
    (
        ddlFamilia.items = #("— nenhuma —") + (for f in InLab_Familias collect (InLab_FamiliaRotulo f.nome))
        local idx = 0
        if InLab_FamiliaAtiva != undefined do
            for i = 1 to InLab_Familias.count where InLab_Familias[i].nome == InLab_FamiliaAtiva.nome do idx = i
        ddlFamilia.selection = idx + 1
    )

    -- Pré-preenche a família pelo produto escolhido (só sugestão: o
    -- modelador confirma ou troca no dropdown).
    fn sugerirFamilia =
    (
        local p = produtoEscolhido()
        if p != undefined do
        (
            local sug = InLab_Produto_SugerirFamilia p
            if sug[1] == "" then
                InLab_Log ("Família não sugerida (" + sug[2] + ") — escolha no dropdown Família.") tipo:#warn
            else
            (
                InLab_Log ("Família sugerida pelo produto (" + sug[2] + ") — confira no dropdown Família.") tipo:#warn
                InLab_DefinirFamiliaAtiva sug[1]
            )
            mostrarFamilia()
            if InLab_OtimUI_Atualizar != undefined do InLab_OtimUI_Atualizar()
            if InLab_UtilUI_AtualizarLimite != undefined do InLab_UtilUI_AtualizarLimite()
        )
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
        ddlProduto.items = #()
        lblProdutoAtivo.text = "Nenhum produto carregado."
        sugerir()
        sugerirMeshes()
    )

    on btnImportarProduto pressed do
    (
        local caminho = getOpenFileName caption:"Selecionar .json do produto" types:"JSON (*.json)|*.json"
        if caminho == undefined then
            InLab_Log "Importação de produto cancelada — nenhum arquivo selecionado." tipo:#warn
        else
        (
            local texto = InLab_JSON_LerArquivoUTF8 caminho
            local dados = if texto == undefined then undefined else InLab_ParseJSON texto
            if dados == undefined then limparProduto()
            else
            (
                InLab_ProdutoAtivo = dados
                local nomeArquivo = filenameFromPath caminho
                lblProdutoAtivo.text = "Produto carregado: " + nomeArquivo
                InLab_Log ("Produto importado com sucesso: " + nomeArquivo) tipo:#ok
                produtos = InLab_Produto_Lista dados
                ddlProduto.items = for p in produtos collect ((InLab_Produto_Texto p "cod_est") + " – " + (InLab_Produto_Texto p "nome"))
                if produtos.count == 0 then
                    InLab_Log "Este JSON não tem lista de produtos — importe o export da linha (nomenclatura_export_...json), não o nomenclatura_projeto.json." tipo:#warn
                else
                (
                    local cod = getFilenameFile maxFileName
                    local idx = InLab_Produto_IndicePorCodigo produtos cod
                    if idx > 0 then
                        InLab_Log ("Produto do arquivo aberto: " + ddlProduto.items[idx]) tipo:#ok
                    else
                    (
                        idx = 1
                        InLab_Log ("Nenhum produto com cod_est '" + cod + "' (nome do .max) — escolha na lista.") tipo:#warn
                    )
                    ddlProduto.selection = idx
                )
                sugerir()
                sugerirMeshes()
                sugerirFamilia()
            )
        )
    )

    on ddlProduto selected i do
    (
        sugerir()
        sugerirMeshes()
        sugerirFamilia()
    )

    on ddlFamilia selected i do
    (
        InLab_DefinirFamiliaAtiva (familiaEscolhida())
        if InLab_OtimUI_Atualizar != undefined do InLab_OtimUI_Atualizar()
        if InLab_UtilUI_AtualizarLimite != undefined do InLab_UtilUI_AtualizarLimite()
    )

    on InLabSecProduto open do mostrarFamilia()

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
            InLab_Log "Importe o JSON e escolha o produto antes de aplicar." tipo:#warn
        else if materiais.count == 0 then
            InLab_Log "Clique em 'Ler materiais da seleção' antes de aplicar." tipo:#warn
        else
        (
            InLab_Produto_Aplicar p ligacoes
            atualizarTela()
        )
    )

    on btnLerObjetos pressed do
    (
        local p = produtoEscolhido()
        if p == undefined then
            InLab_Log "Importe o JSON e escolha o produto antes de ler os objetos." tipo:#warn
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
            InLab_Log "Clique em 'Ler objetos da seleção' antes de renomear." tipo:#warn
        else
        (
            InLab_Produto_RenomearMeshes objsMesh nomesMesh
            atualizarMeshes()
        )
    )

    on btnDesfazer pressed do
    (
        InLab_Produto_Reverter()
        atualizarTela()
        atualizarMeshes()
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Otimização em 3 passos (issue #60)
----------------------------------------------------------------------
-- Spec: docs\superpowers\specs\2026-09-23-otimizacao-design.md. Medidor da
-- cena inteira (triângulos x faixa da família) + lista de revisão. A seção
-- só fala com o despachante InLab_Otim_Calcular/Aplicar/Reverter passo
-- (functions\fn_otim_nucleo.ms): cada passo mora no próprio arquivo.
-- O botão antigo do ProOptimizer (percentual + "Alvo da família") saiu: o
-- passo 2 faz o mesmo, por peça, até a issue #62 trazer a meta por peça.
rollout InLabSecOtimizacao "Otimização" width:420
(
    local comparando = false

    dotNetControl lblMedidor "System.Windows.Forms.Label" width:395 height:24
    spinner spnMeta "Meta (triângulos):" range:[1000, 5000000, 100000] type:#integer fieldWidth:70 align:#left enabled:false
    radiobuttons rdoPasso labels:#("1 · Reduzir", "2 · Ajuste fino", "3 · Escondidas") default:2 columns:3
    button btnCalcular "Calcular" width:395 height:24 tooltip:"Mostra o que o passo propõe para a seleção. Nada muda até Aplicar."
    dotNetControl lvPropostas "System.Windows.Forms.ListView" width:395 height:150
    button btnAplicar "Aplicar" width:126 height:24 across:3 tooltip:"Aplica só as linhas marcadas."
    button btnComparar "Comparar" width:126 height:24 tooltip:"Liga e desliga o ajuste fino na tela para ver o antes e o depois."
    button btnReverter "Reverter" width:126 height:24 tooltip:"Desfaz o último Aplicar deste passo."

    fn pintarMedidor =
    (
        local faixa = InLab_Otim_Faixa()
        spnMeta.enabled = (InLab_FamiliaAtiva == undefined)
        local total = InLab_Otim_Triangulos (InLab_ObjetosVerificacao())
        local suf = case (InLab_Otim_Estado total faixa) of
        (
            #dentro: "OK"
            #perto:  "WARN"
            #longe:  "ERR"
            default: "INFO"
        )
        lblMedidor.Text = InLab_Otim_TextoMedidor total faixa
        lblMedidor.BackColor = InLab_Kit_Cor ((suf + "_FUNDO") as name)
        lblMedidor.ForeColor = InLab_Kit_Cor ((suf + "_TEXTO") as name)
    )

    fn encherLista =
    (
        lvPropostas.Items.Clear()
        for p in INLAB_OTIM_PROPOSTAS do
        (
            local it = dotNetObject "System.Windows.Forms.ListViewItem" p.rotulo
            it.Checked = p.marcada
            lvPropostas.Items.Add it
        )
    )

    fn lerMarcadas =
        for i = 1 to INLAB_OTIM_PROPOSTAS.count where i <= lvPropostas.Items.Count do
            INLAB_OTIM_PROPOSTAS[i].marcada = lvPropostas.Items.Item[i - 1].Checked

    fn pararComparacao =
        if comparando do
        (
            InLab_OtimFino_Comparar true
            comparando = false
            btnComparar.text = "Comparar"
        )

    on InLabSecOtimizacao open do
    (
        lblMedidor.Font = InLab_Kit_Fonte 9
        lblMedidor.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleLeft
        lvPropostas.View = (dotNetClass "System.Windows.Forms.View").Details
        lvPropostas.CheckBoxes = true
        lvPropostas.FullRowSelect = true
        lvPropostas.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").None
        lvPropostas.Columns.Add "Proposta" 372
        lvPropostas.BackColor = InLab_Kit_Cor #LOG
        lvPropostas.ForeColor = InLab_Kit_Cor #TEXTO
        -- 23/09/2026 (revisão final): sem isto, INLAB_OTIM_META_MANUAL fica
        -- undefined até o usuário mexer no spinner, mesmo com o spinner
        -- mostrando 100000 — o medidor caía no texto "digite a meta" com um
        -- número já visível na tela.
        if INLAB_OTIM_META_MANUAL != undefined then spnMeta.value = INLAB_OTIM_META_MANUAL
        else INLAB_OTIM_META_MANUAL = spnMeta.value
        btnComparar.enabled = (rdoPasso.state == 2)
        encherLista()
        pintarMedidor()
    )

    -- 23/09/2026 (revisão final): fechar o painel (ou InLab_RecarregarPlugin)
    -- durante uma comparação deixava o ProOptimizer desligado (enabledInViews
    -- = false) pra sempre na viewport — pararComparacao() nunca era chamado.
    on InLabSecOtimizacao close do pararComparacao()

    on spnMeta changed v do
    (
        INLAB_OTIM_META_MANUAL = v
        pintarMedidor()
    )

    on rdoPasso changed s do
    (
        pararComparacao()
        INLAB_OTIM_PROPOSTAS = #()
        encherLista()
        btnComparar.enabled = (s == 2)
    )

    on btnCalcular pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            pararComparacao()
            InLab_ProgressoIniciar "Calculando..."
            INLAB_OTIM_PROPOSTAS = InLab_Otim_Calcular rdoPasso.state objs
            InLab_ProgressoParar()
            encherLista()
            pintarMedidor()
            if INLAB_OTIM_PROPOSTAS.count > 0 do
                InLab_Log ("Otimização · passo " + rdoPasso.state as string + ": " + INLAB_OTIM_PROPOSTAS.count as string +
                           " proposta(s). Desmarque o que não quiser e clique em Aplicar.")
        )
    )

    on btnAplicar pressed do
    (
        -- 23/09/2026 (revisão final): Aplicar durante uma comparação zerava
        -- InLab_UltimaOtimizacao (InLab_ProOptimizer limpa o registro no
        -- início) com o ProOptimizer do passo anterior ainda desligado na
        -- viewport — o registro que ligaria ele de volta sumia antes.
        pararComparacao()
        if INLAB_OTIM_PROPOSTAS.count == 0 then
            InLab_Log "Clique em Calcular antes de Aplicar." tipo:#warn
        else
        (
            lerMarcadas()
            InLab_ProgressoIniciar "Aplicando..."
            InLab_Otim_Aplicar rdoPasso.state INLAB_OTIM_PROPOSTAS
            InLab_ProgressoParar()
            INLAB_OTIM_PROPOSTAS = #()
            encherLista()
            pintarMedidor()
        )
    )

    on btnComparar pressed do
    (
        -- 23/09/2026 (revisão final): sem o teste de retorno, comparar sem
        -- nada aplicado (InLab_UltimaOtimizacao vazio) virava "Mostrar
        -- ajuste" sem alternar coisa nenhuma na viewport — o botão ficava
        -- preso nesse rótulo até um Aplicar de verdade.
        local ligar = comparando -- estado ANTES do clique: false liga->desliga, true desliga->liga
        local n = InLab_OtimFino_Comparar ligar
        if n == 0 then
            InLab_Log "Nada para comparar — aplique o passo 2 antes." tipo:#warn
        else
        (
            comparando = not comparando
            btnComparar.text = if comparando then "Mostrar ajuste" else "Comparar"
        )
    )

    on btnReverter pressed do
    (
        pararComparacao()
        InLab_Otim_Reverter rdoPasso.state
        pintarMedidor()
    )
)

fn InLab_OtimUI_Atualizar =
    try ( InLabSecOtimizacao.pintarMedidor() )
    catch ( InLab_Log ("Otimização: medidor não atualizou (" + getCurrentException() + ").") tipo:#warn )

----------------------------------------------------------------------
-- SEÇÃO: UV e Texturas (issue #60)
----------------------------------------------------------------------
-- Auto UV, Clean UV e Real World Fix saíram da seção Otimização sem mudar
-- nada: mesmos controles, mesmos handlers. Os textos entram na revisão #58.
rollout InLabSecUV "UV e Texturas" width:420
(
    -- 18/Set (issue #1): o padding sai da resolução do bake; o Auto UV grava
    -- no canal 3 e não toca no canal 1. Os itens do dropdown seguem a ordem
    -- de INLAB_UV_RESOLUCOES (functions\fn_autouv.ms).
    -- 22/Set: saiu o checkbox "Preferir seams em regiões ocultas", que nunca
    -- teve efeito. Volta quando a sondagem da Tarefa 7b der resultado.
    label lblF2 "Auto UV  (canal 3 · bake de textura e AO)" align:#left
    spinner spnAnguloUV "Ângulo flatten (°):" range:[10, 90, 55] type:#float fieldWidth:40 align:#left
    dropdownlist ddlResolucaoUV "Resolução do bake:" items:#("1024", "2048", "4096") selection:1 width:120 align:#left
    button btnF2 "Auto UV na Seleção" width:126 across:3
    button btnF2Clean "Clean UV" width:126
    button btnF2Reverter "Reverter Auto UV" width:126

    -- 22/Set: o Check Texture e o Verificar Escala saíram da aba (as funções
    -- continuam em functions\, a V-19 usa INLAB_UNIDADE_PADRAO). No lugar,
    -- o Real World Fix (functions\fn_realworldfix.ms).
    label lblF34 "Real World Fix  (tira o Real-World Map Size · WebGL)" align:#left across:1
    button btnRWFix "Real World Fix" width:390 height:25

    on btnF2 pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            InLab_ProgressoIniciar "Gerando Auto UV..."
            InLab_AutoUV objs angulo:spnAnguloUV.value resolucao:INLAB_UV_RESOLUCOES[ddlResolucaoUV.selection]
            InLab_ProgressoParar()
        )
    )
    on btnF2Clean pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_CleanUV objs
    )
    on btnF2Reverter pressed do InLab_ReverterAutoUV()

    on btnRWFix pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_RealWorldFix objs
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Utilidades Rápidas
----------------------------------------------------------------------
rollout InLabSecUtil "Utilidades Rápidas" width:420
(
    button btnUResetX "Reset XForm" width:130 across:3
    button btnUCenter "Center Pivot" width:130
    button btnUBase "Base Pivot" width:130

    label lblFind "Objetos pesados da cena" align:#left across:1
    label lblFindLimite "limite: carregue uma família" align:#left
    button btnUFind "Find Objects" width:395 height:24 tooltip:(
        "Seleciona os objetos acima de " + ((INLAB_FIND_FRACAO_POLYMAX * 100) as integer) as string +
        "% do polyMax da família ativa (em triângulos). Sem família ativa: os " +
        INLAB_FIND_TOP_N as string + " objetos mais pesados da cena.")

    label lblUDetach "Detach por Material (propaga IDs para os pedaços)" align:#left across:1
    button btnUDetach "Detach por Material na Seleção" width:395 height:24

    -- 24/Set/2026 (issue #47): rótulo do limite do Find Objects — mesma
    -- lógica do texto que InLab_FindObjectsPesados usa pra decidir o
    -- critério (functions\fn_utilidades.ms), só pra exibição.
    fn atualizarLimite =
    (
        lblFindLimite.text = if InLab_FamiliaAtiva != undefined then
            ("limite: " + ((InLab_FamiliaAtiva.polyMax * INLAB_FIND_FRACAO_POLYMAX) as integer) as string +
             " triângulos (" + ((INLAB_FIND_FRACAO_POLYMAX * 100) as integer) as string +
             "% do polyMax de '" + InLab_FamiliaAtiva.nome + "')")
        else
            ("limite: sem família ativa — mostra os " + INLAB_FIND_TOP_N as string + " objetos mais pesados da cena")
    )

    on btnUResetX pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_ResetXFormSelecao objs
    )
    on btnUCenter pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_CentralizarPivot objs
    )
    on btnUBase pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_BasePivot objs
    )
    on btnUFind pressed do InLab_FindObjectsPesados()
    on btnUDetach pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_DetachPorMaterialSelecao objs
    )

    -- Atualiza o rótulo do limite sempre que a seção é exibida — mantém o
    -- valor visível sincronizado com a família carregada (não é campo
    -- editável: vem sempre do polyMax, conforme decisão da equipe).
    -- 24/Set/2026 (issue #47): não bastava mais só no open — InLab_UtilUI_
    -- AtualizarLimite (definida abaixo) também é chamada pelo dropdown
    -- Família (seção Produto) sempre que a família muda.
    on InLabSecUtil open do atualizarLimite()
)

fn InLab_UtilUI_AtualizarLimite =
    try ( InLabSecUtil.atualizarLimite() )
    catch ( InLab_Log ("Utilidades: rótulo do limite não atualizou (" + getCurrentException() + ").") tipo:#warn )

----------------------------------------------------------------------
-- SEÇÃO: Converter Material
----------------------------------------------------------------------
rollout InLabSecF5 "Converter Material" width:420
(
    dropdownlist ddlConversao items:#("Corona → glTF (Physical / Legacy / VRay)") selection:1 width:395
    dropdownlist ddlBakeRes items:#("512", "1024", "2048", "4096") selection:2 width:90 align:#left across:2
    checkbox chkBakeProc "Bake de mapas procedurais" checked:true align:#right
    button btnF5 "Converter Materiais da Seleção" width:192 across:2
    button btnF5Rev "Reverter Conversão" width:192

    on btnF5 pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do
        (
            local tam = ddlBakeRes.selected as integer
            InLab_ProgressoIniciar "Convertendo materiais..."
            InLab_ConverterObjetos objs tamanhoBake:tam fazerBake:chkBakeProc.checked
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
    button btnF6 "Abrir Real-Time Exporter..." width:395 height:24

    on btnF6 pressed do
    (
        local soSelecao = (rdoEscopoExp.state == 1)
        if soSelecao and selection.count == 0 then
            InLab_Log "Selecione os objetos a exportar (ou mude para cena inteira)." tipo:#warn
        else
        (
            local objs = if soSelecao then (for o in selection collect o) else undefined
            InLab_AbrirExportadorRealTime objs somenteSelecao:soSelecao
        )
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Verificações (sem mudanças de lógica — só reordenada)
----------------------------------------------------------------------
rollout InLabSecFase4 "Verificações (grupos 1-3 ativos)" width:420
(
    checkbox chkTampoAcess "Produto com tampo acessório (V-38 · Pernas+Tampo)" checked:false
    button btnVerificar "Rodar Verificações" width:395 height:26

    on btnVerificar pressed do
    (
        if InLab_FamiliaAtiva == undefined then
            InLab_Log "Escolha a família no dropdown Família da seção Produto antes de verificar." tipo:#warn
        else
        (
            InLab_ProgressoIniciar "Rodando verificações..."
            InLab_RodarVerificacoes InLab_FamiliaAtiva tampoAcessorio:chkTampoAcess.checked
            InLab_ProgressoParar()
        )
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Log (sempre por último — regra fixa independente de novas seções)
----------------------------------------------------------------------
rollout InLabSecLog "Log de Sessão" width:420
(
    dotNetControl rtbLog "System.Windows.Forms.RichTextBox" width:398 height:220
    button btnLimpar "Limpar" width:126 across:3
    button btnSalvar "Salvar .txt" width:126
    button btnFechar "Fechar Plugin" width:126

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
    on btnFechar pressed do destroyDialog InLabChecker_Rollout
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
        InLab_PrefGravar "painelX" (caixa.x as integer)
        InLab_PrefGravar "painelY" (caixa.y as integer)
        ok = true
    )
    catch ( InLab_Log ("Preferências: falha ao gravar a posição do painel (" + getCurrentException() + ").") tipo:#warn )
    ok
)

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
    subRollout subSecoes width:438 height:508 pos:[4,64]

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

        AddSubRollout subSecoes InLabSecProduto
        AddSubRollout subSecoes InLabSecOtimizacao rolledUp:true
        AddSubRollout subSecoes InLabSecUV rolledUp:true
        AddSubRollout subSecoes InLabSecUtil rolledUp:true
        AddSubRollout subSecoes InLabSecF5 rolledUp:true
        AddSubRollout subSecoes InLabSecF6 rolledUp:true
        AddSubRollout subSecoes InLabSecFase4 rolledUp:true
        AddSubRollout subSecoes InLabSecUpdate rolledUp:true   -- ui\rollout_update.ms (#14)
        AddSubRollout subSecoes InLabSecLog

        InLab_Log ("Sessão InLabChecker v" + INLAB_VERSAO + " · " + localTime)
        InLab_Log ("Famílias registradas: " + InLab_Familias.count as string + " de 8")
        InLab_Log ("Unidade do sistema: " + (InLab_UnidadeSistema() as string))
        if InLab_Familias.count != 8 do
            InLab_Log "Nem todas as famílias foram carregadas — verificar o manifesto." tipo:#err

        -- Checagem de atualização (issue #12): retorna na hora, a resposta
        -- chega depois pelo callback. O intervalo de 4 h fica dentro de
        -- InLab_UpdateChecar, então reabrir/recarregar o painel não consulta
        -- o GitHub de novo. autoCheck vira checkbox na seção Atualização (#14).
        if (InLab_PrefLer "autoCheck" "true") == "true" do
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

        InLab_LogUI = undefined
        InLab_Header_Pnl = undefined
        InLab_Header_Marca = undefined
        InLab_Header_Titulo = undefined
        InLab_Header_Sub = undefined
        InLab_Header_BtnReload = undefined
        InLab_Header_Pastilha = undefined
    )
)

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
    createDialog InLabChecker_Rollout 446 580 pos:(InLab_PosicaoPainelLer())
)
