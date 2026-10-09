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
    local materiais = #() -- materiais lidos da seleção
    local ligacoes = #()  -- paralelo às partes do produto escolhido: material ou undefined
    -- 24/09/2026 (#54): objetos têm lista própria (objeto → nome), mesmo
    -- padrão da lista de partes. O Aplicar não renomeia mais objetos.
    local objsMesh = #()   -- objetos lidos para "Renomear meshes"
    local nomesMesh = #()  -- paralelo a objsMesh: mesh_final escolhido ou ""
    local meshesProd = #() -- mesh_final distintos do produto escolhido

    label lblProdutoAtivo "Nenhum produto carregado." align:#left
    button btnImportarProduto "Importar informações do produto" width:395 height:24 tooltip:"Abre o arquivo do produto exportado da plataforma (.json)."
    dropdownlist ddlProduto "Produto:" items:#() width:395
    -- 08/10/2026 (issue #138): família que as verificações usam. Não é mais
    -- escolhida: vem do campo "natureza" do produto (InLab_Produto_Familia).
    label lblFamilia "Família: importe o produto" align:#left width:395
    button btnLerSelecao "Ler materiais" width:395 height:24 tooltip:"Lista os materiais dos objetos selecionados."
    listbox lbxPartes "Parte  →  material:" items:#() height:6 width:395
    dropdownlist ddlMaterial "Material da parte:" items:#() width:395
    button btnAplicar "Renomear materiais" width:395 height:24 tooltip:"Dá o nome oficial aos materiais ligados e aos mapas deles. Os objetos são renomeados em 'Renomear objetos', abaixo."
    button btnLerObjetos "Ler objetos" width:395 height:24 tooltip:"Lista os objetos selecionados e sugere o nome de cada um: pelo material ligado acima ou pela semelhança do nome."
    listbox lbxObjetos "Objeto  →  nome novo:" items:#() height:6 width:395
    dropdownlist ddlMesh "Nome do objeto:" items:#() width:395
    button btnRenomearMeshes "Renomear objetos" width:195 height:24 align:#left offset:[2,0] across:2 tooltip:"Dá a cada objeto da lista o nome escolhido. Objeto sem nome escolhido fica como está."
    button btnDesfazer "Desfazer nomes" width:195 height:24 align:#right offset:[-1,0] tooltip:"Volta os nomes de materiais, mapas e objetos ao que eram antes de 'Renomear materiais' e 'Renomear objetos'."

    fn produtoEscolhido =
        if ddlProduto.selection > 0 and ddlProduto.selection <= produtos.count then produtos[ddlProduto.selection] else undefined

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
        lblFamilia.text = if InLab_FamiliaAtiva == undefined then "Família: importe o produto (vem do campo natureza)"
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
        ddlProduto.items = #()
        lblProdutoAtivo.text = "Nenhum produto carregado."
        sugerir()
        sugerirMeshes()
        aplicarFamilia()
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
                    local idx = InLab_Produto_IndicePorArquivo produtos cod -- cod_est ou variante de posição (#92)
                    if idx > 0 then
                        InLab_Log ("Produto do arquivo aberto: " + ddlProduto.items[idx]) tipo:#ok
                    else
                    (
                        idx = 1
                        InLab_Log ("Nenhum produto com cod_est ou variante '" + cod + "' (nome do .max) — escolha na lista.") tipo:#warn
                    )
                    ddlProduto.selection = idx
                )
                sugerir()
                sugerirMeshes()
                aplicarFamilia()
                avisarNaoLiberado()
            )
        )
    )

    on ddlProduto selected i do
    (
        sugerir()
        sugerirMeshes()
        aplicarFamilia()
        avisarNaoLiberado()
    )

    -- Reabrir o painel zera a lista de produtos: a família ativa sai junto.
    on InLabSecProduto open do aplicarFamilia()

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

    on btnDesfazer pressed do
    (
        InLab_Produto_Reverter()
        atualizarTela()
        atualizarMeshes()
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
    button btnF2 "Auto UV" width:130 height:24 align:#left offset:[2,0] across:2 tooltip:"Cria um UV próprio para bake de textura e sombra nos objetos selecionados. Antes, converte a escala real dos mapas (Real World Fix) para funcionar na web."
    spinner spnAnguloUV "" range:[10, 90, 55] type:#float fieldWidth:45 align:#left offset:[-63,3] tooltip:"Ângulo de corte (°). Quanto maior, menos cortes no UV."
    -- 22/Set: o Check Texture e o Verificar Escala saíram da aba (as funções
    -- continuam em functions\, a V-19 usa INLAB_UNIDADE_PADRAO). No lugar,
    -- o Real World Fix (functions\fn_realworldfix.ms), no trio com Limpar e
    -- Desfazer UV (30/09/2026, #58).
    -- 08/10/2026 (issue #129): o Real World Fix roda dentro do Auto UV e o
    -- botão saiu; ficam Limpar e Desfazer UV (que desfaz também o RWF).
    button btnF2Clean "Limpar UV" width:195 height:24 align:#left offset:[2,0] across:2 tooltip:"Remove o UV de bake dos objetos selecionados. O UV do material fica."
    button btnF2Reverter "Desfazer UV" width:195 height:24 align:#right offset:[-1,0] tooltip:"Volta os objetos ao que eram antes do Auto UV, inclusive a escala real dos mapas."

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
            InLab_ProgressoIniciar "Convertendo materiais..."
            InLab_ConverterObjetos objs tamanhoBake:INLAB_RESOLUCAO_BAKE fazerBake:chkBakeProc.checked
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
            InLab_AbrirExportadorRealTime objs somenteSelecao:soSelecao
        )
    )
)

----------------------------------------------------------------------
-- SEÇÃO: Verificações (sem mudanças de lógica — só reordenada)
----------------------------------------------------------------------
rollout InLabSecFase4 "Verificações" width:420
(
    checkbox chkTampoAcess "Produto com tampo acessório" checked:false tooltip:"Só para mesas (família Pernas + Tampo)."
    button btnVerificar "Verificar" width:395 height:24 tooltip:"Confere o produto e salva o relatório ao lado do arquivo."

    on btnVerificar pressed do
    (
        if InLab_FamiliaAtiva == undefined then
            InLab_Log "Sem família: importe o JSON e escolha o produto na seção Produto (a família vem do campo natureza)." tipo:#warn
        else if InLab_SalvarAntesDeVerificar() do
        (
            -- Produto escolhido na seção Produto vai para o relatório (issue #37)
            -- e para a V-20, que confere os nomes contra ele (issue #36).
            local p = try (InLabSecProduto.produtoEscolhido()) catch undefined
            local cod = if p == undefined then "" else InLab_Produto_Texto p "cod_est"
            local nomeP = if p == undefined then "" else InLab_Produto_Texto p "nome"
            InLab_ProgressoIniciar "Rodando verificações..."
            InLab_RodarVerificacoes InLab_FamiliaAtiva tampoAcessorio:chkTampoAcess.checked codEst:cod nomeProduto:nomeP produto:p
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
    --
    -- UTILIDADES RÁPIDAS (08/10/2026, issue #125): grupo FIXO entre o header
    -- e as seções — não abre nem fecha. Recebe os botões da antiga seção
    -- InLabSecUtil e o ProOptimizer (30% por clique, functions\
    -- fn_otim_reduzir.ms), que substitui a seção Otimização inteira.
    -- subSecoes desce de pos:[4,64] para pos:[4,188].
    groupBox grpUtil "Utilidades Rápidas" pos:[4,60] width:438 height:122
    button btnUResetX "Reset XForm" pos:[12,78] width:136 height:24
    button btnUCenter "Center Pivot" pos:[154,78] width:136 height:24
    button btnUBase "Base Pivot" pos:[296,78] width:138 height:24
    button btnUOtimizar "ProOptimizer" pos:[12,106] width:208 height:24 tooltip:(
        "Tira " + ((100 - INLAB_REDUZIR_FATOR * 100 + 0.5) as integer) as string +
        "% dos vértices de cada peça selecionada. Cada clique é um passo do Ctrl+Z.")
    button btnUOtimDesfazer "Desfazer" pos:[226,106] width:208 height:24 tooltip:"Volta o último clique do ProOptimizer."
    button btnUFind "Find Objects" pos:[12,134] width:208 height:24 tooltip:(
        "Seleciona os objetos acima de " + ((INLAB_FIND_FRACAO_POLYMAX * 100) as integer) as string +
        "% do máximo de triângulos da família. Sem família: os " +
        INLAB_FIND_TOP_N as string + " objetos mais pesados da cena.")
    button btnUDetach "Separar por material" pos:[226,134] width:208 height:24 tooltip:"Divide cada objeto selecionado em um objeto por material."
    label lblFindLimite "limite: escolha a família" pos:[12,162] width:422

    subRollout subSecoes width:438 height:508 pos:[4,188]

    -- Rótulo do limite do Find Objects (issue #47) — mesma lógica do texto
    -- que InLab_FindObjectsPesados usa para decidir o critério
    -- (functions\fn_utilidades.ms), só para exibição. Chamada no open e pela
    -- seção Produto quando a família muda (InLab_UtilUI_AtualizarLimite).
    fn atualizarLimite =
    (
        lblFindLimite.text = if InLab_FamiliaAtiva != undefined then
            ("limite do Find Objects: " + ((InLab_FamiliaAtiva.polyMax * INLAB_FIND_FRACAO_POLYMAX) as integer) as string +
             " triângulos (" + ((INLAB_FIND_FRACAO_POLYMAX * 100) as integer) as string +
             "% do máximo da família '" + InLab_FamiliaAtiva.nome + "')")
        else
            ("limite do Find Objects: sem família ativa — os " + INLAB_FIND_TOP_N as string + " objetos mais pesados da cena")
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
    on btnUOtimizar pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_OtimReduzir objs
    )
    on btnUOtimDesfazer pressed do InLab_OtimReduzir_Desfazer()
    on btnUFind pressed do InLab_FindObjectsPesados()
    on btnUDetach pressed do
    (
        local objs = InLab_SelecaoValida()
        if objs.count > 0 do InLab_DetachPorMaterialSelecao objs
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

        AddSubRollout subSecoes InLabSecProduto
        AddSubRollout subSecoes InLabSecUV rolledUp:true
        AddSubRollout subSecoes InLabSecF5 rolledUp:true
        AddSubRollout subSecoes InLabSecF6 rolledUp:true
        AddSubRollout subSecoes InLabSecFase4 rolledUp:true
        AddSubRollout subSecoes InLabSecUpdate rolledUp:true   -- ui\rollout_update.ms (#14)
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
    createDialog InLabChecker_Rollout 446 704 pos:(InLab_PosicaoPainelLer())
)
