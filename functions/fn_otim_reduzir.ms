/*
================================================================================
 functions\fn_otim_reduzir.ms — Otimização · Reduzir 30% por clique (issue #124)
--------------------------------------------------------------------------------
 Epic #121 / issue #123 (ajustes pós-v1 do teste com a Bia, 07/10/2026): a
 Otimização fica só com o ProOptimizer. Cada clique em Reduzir tira 30% dos
 vértices de cada peça selecionada; Desfazer volta o último clique.

 O QUE FAZ: um ProOptimizer por stack, chamado INLAB_REDUZIR_NOME_MOD
 ("InLab · Reduzir"). O 1º clique cria o modificador (VertexPercent 70); os
 seguintes reaproveitam o mesmo e multiplicam o VertexPercent por
 INLAB_REDUZIR_FATOR (70 → 49 → 34,3...): cada clique tira 30% do que a peça
 TEM, nunca chega a zero. Não empilha um ProOptimizer por clique. O piso é
 INLAB_REDUZIR_PCT_MIN (1% dos vértices originais).

 UM CLIQUE = UM PASSO DE CTRL+Z: cada chamada de InLab_OtimReduzir fica num
 `undo "InLab Reduzir 30%" on` só, com todas as peças.

 SONDAGEM (Max 2024, 08/10/2026, Sphere segs:64 = 3968 triângulos):
   - Só o Calculate do modificador NOVO precisa do contexto (nó selecionado,
     painel Modify, modificador corrente — ver o antigo fn_otim_fino.ms, removido na #126). Depois dele,
     mudar o VertexPercent recalcula sem seleção nem painel: 90% = 3570,
     81% = 3212 triângulos.
   - O cálculo sobrevive a salvar e reabrir o .max: VertexPercent num
     modificador carregado do arquivo reduz sem novo Calculate.
   - Ctrl+Z volta o VertexPercent (81 → 90) e depois remove o modificador.

 PROTEÇÕES: as mesmas do ajuste fino (sondadas em 24/09/2026, ver
 fn_otim_fino.ms, removido na #126): LockMat, KeepUV, LockUV, KeepNormals e OptimizationMode 2
 (Exclude Borders). Copiadas para INLAB_REDUZIR_PROTECOES porque o ajuste fino
 saiu do plugin (#126). Peça sem UV no canal 1: o ProOptimizer desliga KeepUV
 sozinho — loga #info.

 INSTÂNCIAS: um modificador por stack (InLab_DeduplicarInstancias); as
 instâncias fora da seleção também reduzem. GRUPOS FECHADOS: abre os grupos
 acima do nó antes do `select` (senão seleciona o grupo todo) e fecha depois.

 PEÇA QUE NÃO REDUZ (as proteções seguram tudo, ou já está no piso): o clique
 desfaz o próprio passo nela (remove o modificador recém-criado ou volta o
 VertexPercent) e loga #warn. Fica fora do registro.

 REGISTRO: InLab_ReduzirHistorico = um item por clique, cada um um array de
 ReduzirRecord (uma por stack). InLab_OtimReduzir_Desfazer tira o último
 clique: remove o modificador que o clique criou ou volta o VertexPercent
 anterior, num undo próprio. Se o estado no stack não bate com o registro
 (o usuário já deu Ctrl+Z, colapsou, apagou), pula a peça com #warn.

 HISTÓRICO:
 08/10/2026: passo de 10% (fator 0,9) para 30% (fator 0,7) por clique, a
 pedido do usuário.
 08/10/2026 (teste adversarial por agente, 4 modelos do piloto + primitivas):
   - Mudança ABAIXO do modificador (vértice movido, modificador inserido
     embaixo) invalida o cálculo: o ProOptimizer devolve a malha inteira e a
     peça nunca mais reduzia. Agora, se o clique não reduz numa peça que já
     tinha o modificador, refaz o Calculate no contexto e tenta de novo
     (InLab_OtimReduzir_Calcular) — nesse clique a queda pode passar de 30%,
     porque a peça volta do original direto para o VertexPercent do clique.
   - Modificador desligado pelo usuário: avisa em vez de culpar as proteções.
   - #info de KeepUV desligado só aparece depois de avaliar o nó (classof).
   - Histórico do Desfazer é zerado em reset, cena nova e arquivo aberto.
   - Segundo teste (undo): o ProOptimizer NÃO refaz a malha quando o
     VertexPercent SOBE (24 → 34,3 continua com a malha de 24%; nos modelos
     reais Porter e Mentha o Ctrl+Z e o Desfazer dos cliques do meio davam a
     malha errada, a que o export pegaria). Ctrl+Z/Redo: callback
     #sceneUndo/#sceneRedo liga e desliga os modificadores
     (InLab_OtimReduzir_Refrescar). Desfazer: o liga/desliga dentro do script
     não bastou (sondado com o bule), então refaz o Calculate no contexto. Passar
     por 100% antes do alvo também funcionou na sonda, mas sem explicação: não
     usado. Seleção, grupos e painel do Calculate ficam fora do undo (o Ctrl+Z
     mexia na seleção: última peça, membros de grupo sem a cabeça, peça com
     instância); o Calculate fica dentro, senão o Redo volta a peça inteira.
   LIMITE CONHECIDO: Ctrl+Z de um Desfazer não devolve o registro dele ao
   histórico (o Desfazer seguinte pula as peças com #warn); o Ctrl+Z continua
   funcionando. Clique em que nada reduz deixa um passo vazio no Ctrl+Z.
   Fica como está: peça que as proteções seguram desde o 1º clique refaz o
   Calculate em todo clique (~0,6 s por peça), porque o modificador que não
   reduziu é removido.

 `global` antes de cada fn: o arquivo pode ser recarregado sozinho por
 InLab_RecarregarPlugin() — padrão de functions\fn_renomear_produto.ms.
================================================================================
*/

-- Definidas em functions\fn_autouv.ms, que carrega depois deste arquivo.
global InLab_AbrirGruposAcima, InLab_FecharGrupos

-- Um passo de redução numa peça (um stack).
struct ReduzirRecord
(
    no,               -- representante do stack
    modificador,      -- o ProOptimizer "InLab · Reduzir" do stack
    criado = false,   -- o clique criou o modificador (Desfazer remove)
    pctAntes = 100.0, -- VertexPercent antes do clique
    pctDepois = 100.0,
    trisAntes = 0,
    trisDepois = 0,
    instancias = 1
)

-- Sem inicializador no `global`: recarregar o arquivo não apaga o histórico
-- (mesmo padrão do registro do antigo ajuste fino).
global InLab_ReduzirHistorico
if InLab_ReduzirHistorico == undefined do InLab_ReduzirHistorico = #()

-- Cena nova, reset ou arquivo aberto: o histórico é da cena anterior (achado
-- no teste de 08/10/2026: sobrevivia a resetMaxFile/loadMaxFile).
callbacks.removeScripts id:#InLabReduzirHistorico
for ev in #(#systemPostReset, #systemPostNew, #filePostOpen) do
    callbacks.addScript ev "InLab_ReduzirHistorico = #()" id:#InLabReduzirHistorico

global INLAB_REDUZIR_NOME_MOD = "InLab · Reduzir"
global INLAB_REDUZIR_FATOR = 0.7
global INLAB_REDUZIR_PCT_MIN = 1.0

-- Proteções: #(propriedade, valor, descrição para o log). Ver cabeçalho.
global INLAB_REDUZIR_PROTECOES = #(
    #(#LockMat, true, "fronteira de material"),
    #(#KeepUV, true, "manter UV"),
    #(#LockUV, true, "borda de ilha UV"),
    #(#KeepNormals, true, "normais"),
    #(#OptimizationMode, 2, "bordas abertas (Exclude Borders)")
)

-- O ProOptimizer "InLab · Reduzir" do stack de `o`, ou undefined.
global InLab_OtimReduzir_Modificador
fn InLab_OtimReduzir_Modificador o =
(
    local achado = undefined
    for m in o.modifiers where achado == undefined and classof m == ProOptimizer and m.name == INLAB_REDUZIR_NOME_MOD do achado = m
    achado
)

-- O modificador `m` ainda está no stack de `o`?
global InLab_OtimReduzir_NoStack
fn InLab_OtimReduzir_NoStack o m =
(
    local tem = false
    for x in o.modifiers where x == m do tem = true
    tem
)

-- O ProOptimizer não refaz a malha quando o VertexPercent SOBE (Ctrl+Z ou
-- Desfazer de um clique do meio): continua mostrando a malha do percentual
-- mais baixo — e é ela que o export pegaria. Desligar e religar o modificador
-- força a reavaliação (completeRedraw e classof não bastam). Sem undo: não
-- pode virar um passo do Ctrl+Z nem apagar o Redo. `mods` = undefined
-- refresca todos os "InLab · Reduzir" da cena.
global InLab_OtimReduzir_Refrescar
fn InLab_OtimReduzir_Refrescar mods:undefined =
(
    if mods == undefined do
    (
        mods = #()
        for o in geometry do
            for m in o.modifiers where classof m == ProOptimizer and m.name == INLAB_REDUZIR_NOME_MOD and findItem mods m == 0 do append mods m
    )
    with undo off
        for m in mods where m.enabled do ( m.enabled = false; m.enabled = true )
    mods.count
)

-- Ctrl+Z e Redo do Max não passam pelo plugin: refresca depois de cada um.
callbacks.removeScripts id:#InLabReduzirRefrescar
for ev in #(#sceneUndo, #sceneRedo) do
    callbacks.addScript ev "try ( InLab_OtimReduzir_Refrescar() ) catch ( try ( InLab_Log (\"Reduzir: não refresquei o ProOptimizer depois do Ctrl+Z/Redo (\" + getCurrentException() + \") — confira a malha.\") tipo:#warn ) catch () )" id:#InLabReduzirRefrescar

-- Põe a peça no contexto obrigatório do Calculate (grupos acima abertos, nó
-- selecionado, painel Modify, `po` corrente) e dispara o cálculo. Devolve true
-- se alguma das variantes (#Calculate, #CalculationEnabled) rodou. Fecha os
-- grupos que abriu; a seleção e o painel quem chama restaura.
global InLab_OtimReduzir_Calcular
fn InLab_OtimReduzir_Calcular o po =
(
    -- Grupos, seleção e painel FORA do undo (teste de undo de 08/10/2026):
    -- dentro dele, o Ctrl+Z do clique deixava na seleção os membros de grupo
    -- sem a cabeça, e o setCurrentObject numa peça com instância punha a peça
    -- na seleção. O Calculate fica DENTRO: fora dele o Redo traz o modificador
    -- sem o cálculo e a peça volta inteira.
    local grupos = #()
    with undo off grupos = InLab_AbrirGruposAcima o
    local calcOk = false
    try
    (
        with undo off
        (
            select o
            setCommandPanelTaskMode #modify
            try ( subObjectLevel = 0 )
            catch ( InLab_Log (o.name + ": não zerei o subObjectLevel (" + getCurrentException() + ").") tipo:#warn )
            try ( modPanel.setCurrentObject po )
            catch ( InLab_Log (o.name + ": não pus o ProOptimizer como corrente no Modify (" + getCurrentException() + ").") tipo:#warn )
        )
        for c in #(#Calculate, #CalculationEnabled) while not calcOk do
            if isProperty po c do
                ( try ( setProperty po c true; calcOk = true )
                  catch ( InLab_Log (o.name + ": ProOptimizer." + c as string + " falhou (" + getCurrentException() + ").") tipo:#warn ) )
    )
    catch ( InLab_Log (o.name + ": erro ao calcular o ProOptimizer (" + getCurrentException() + ").") tipo:#err )
    with undo off InLab_FecharGrupos grupos
    calcOk
)

-- Cria o ProOptimizer na peça, com as proteções, e dispara o Calculate no
-- contexto obrigatório. Devolve o modificador, ou undefined se não deu (e já
-- removeu o que criou). `faltando` acumula as proteções inexistentes na build.
global InLab_OtimReduzir_Criar
fn InLab_OtimReduzir_Criar o faltando =
(
    local po = ProOptimizer()
    po.name = INLAB_REDUZIR_NOME_MOD
    try
    (
        addModifier o po

        for p in INLAB_REDUZIR_PROTECOES do
        (
            if isProperty po p[1] then
            (
                try ( setProperty po p[1] p[2] )
                catch ( InLab_Log (o.name + ": ProOptimizer." + p[1] as string + " (" + p[3] + ") não aceitou " +
                                   p[2] as string + " (" + getCurrentException() + ").") tipo:#err )
            )
            else if findItem faltando p[1] == 0 do append faltando p[1]
        )

        if not (InLab_OtimReduzir_Calcular o po) then
        (
            deleteModifier o po
            po = undefined
            InLab_Log (o.name + ": ProOptimizer sem Calculate/CalculationEnabled nesta build — peça NÃO reduzida.") tipo:#err
        )
        else
        (
            -- O KeepUV só vira false depois que o nó é avaliado (achado no
            -- teste de 08/10/2026): ler logo após o Calculate dá sempre true.
            classof o
            if isProperty po #KeepUV and not po.KeepUV do
                InLab_Log (o.name + ": sem UV no canal 1 — o ProOptimizer desligou KeepUV sozinho.") tipo:#info
        )
    )
    catch
    (
        InLab_Log (o.name + ": erro ao criar o ProOptimizer (" + getCurrentException() + ") — peça NÃO reduzida.") tipo:#err
        if InLab_OtimReduzir_NoStack o po do
            try ( deleteModifier o po )
            catch ( InLab_Log (o.name + ": não removi o ProOptimizer após o erro (" + getCurrentException() + ").") tipo:#err )
        po = undefined
    )
    po
)

-- Um clique: tira 30% dos vértices de cada peça (stack) de `objs`. Devolve
-- quantas peças reduziram.
global InLab_OtimReduzir
fn InLab_OtimReduzir objs =
(
    local geo = for o in objs where isValidNode o and InLab_EhGeometria o collect o
    if geo.count == 0 then
    (
        InLab_Log "Reduzir: selecione as peças a reduzir." tipo:#warn
        0
    )
    else
    (
        local clique = #()
        local faltando = #()
        local reps = for g in InLab_DeduplicarInstancias geo collect g.no
        local selOriginal = selection as array
        local painelOriginal = getCommandPanelTaskMode()
        local somaAntes = 0, somaDepois = 0

        undo "InLab Reduzir 30%" on
        (
            for o in reps do
            (
                try
                (
                    local nInst = (InLab_InstanciasDoNo o).count
                    local trisAntes = (GetTriMeshFaceCount o)[1]
                    local po = InLab_OtimReduzir_Modificador o
                    local criado = (po == undefined)
                    local pctAntes = if criado then 100.0 else po.VertexPercent
                    if not criado and not po.enabled then
                        InLab_Log (o.name + ": o modificador \"" + INLAB_REDUZIR_NOME_MOD + "\" está desligado no stack — ligue-o para reduzir.") tipo:#warn
                    else if not criado and pctAntes <= INLAB_REDUZIR_PCT_MIN + 0.001 then
                        InLab_Log (o.name + ": já está no mínimo (" + (formattedPrint pctAntes format:".1f") + "% dos vértices).") tipo:#warn
                    else
                    (
                        if criado do po = InLab_OtimReduzir_Criar o faltando
                        if po != undefined do
                        (
                            local pctDepois = amax INLAB_REDUZIR_PCT_MIN (pctAntes * INLAB_REDUZIR_FATOR)
                            po.VertexPercent = pctDepois
                            local trisDepois = (GetTriMeshFaceCount o)[1]
                            -- Malha ABAIXO do modificador mudou (vértice movido,
                            -- modificador inserido embaixo): o cálculo guardado
                            -- não vale mais e o ProOptimizer devolve a malha
                            -- inteira. Refaz o Calculate e tenta de novo.
                            if trisDepois >= trisAntes and not criado do
                            (
                                if InLab_OtimReduzir_Calcular o po do
                                (
                                    po.VertexPercent = pctDepois
                                    trisDepois = (GetTriMeshFaceCount o)[1]
                                    if trisDepois < trisAntes do
                                        InLab_Log (o.name + ": a malha abaixo do ProOptimizer mudou — recalculado.") tipo:#info
                                )
                            )
                            if trisDepois >= trisAntes then
                            (
                                -- As proteções seguraram: desfaz o passo nesta peça.
                                if criado then deleteModifier o po
                                else ( po.VertexPercent = pctAntes; InLab_OtimReduzir_Refrescar mods:#(po) )
                                InLab_Log (o.name + ": não reduziu (" + (InLab_Otim_Milhar trisAntes) +
                                           " triângulos — as proteções seguram). Peça intacta.") tipo:#warn
                            )
                            else
                            (
                                append clique (ReduzirRecord no:o modificador:po criado:criado pctAntes:pctAntes pctDepois:pctDepois \
                                                             trisAntes:trisAntes trisDepois:trisDepois instancias:nInst)
                                somaAntes += trisAntes * nInst
                                somaDepois += trisDepois * nInst
                                InLab_Log (o.name + (if nInst > 1 then (" (×" + nInst as string + " instâncias, 1 modificador)") else "") +
                                           ": " + (InLab_Otim_Milhar trisAntes) + " → " + (InLab_Otim_Milhar trisDepois) +
                                           " triângulos (" + (formattedPrint pctDepois format:".1f") + "% dos vértices).") tipo:#ok
                            )
                        )
                    )
                )
                catch ( InLab_Log (o.name + ": erro ao reduzir (" + getCurrentException() + ") — peça pulada.") tipo:#err )
            )
        )

        -- Restaura seleção e painel FORA do undo (não é parte da operação).
        try
        (
            if selOriginal.count > 0 then select (for s in selOriginal where isValidNode s collect s) else clearSelection()
            setCommandPanelTaskMode painelOriginal
        )
        catch ( InLab_Log ("Reduzir: não restaurei seleção/painel (" + getCurrentException() + ").") tipo:#warn )

        if faltando.count > 0 do
            InLab_Log ("Reduzir: proteção(ões) inexistente(s) nesta build do ProOptimizer: " +
                       (for f in faltando collect f as string) as string + " — aplicado sem ela(s).") tipo:#warn
        if clique.count > 0 do append InLab_ReduzirHistorico clique
        InLab_Log ("Reduzir 30%: " + clique.count as string + " de " + reps.count as string + " peça(s) reduzida(s)" +
                   (if clique.count > 0 then (", " + (InLab_Otim_Milhar somaAntes) + " → " + (InLab_Otim_Milhar somaDepois) + " triângulos.") else ".")) \
            tipo:(if clique.count == reps.count then #ok else #warn)
        clique.count
    )
)

-- Desfaz o último clique de Reduzir (além do Ctrl+Z). Devolve quantas peças
-- voltaram.
global InLab_OtimReduzir_Desfazer
fn InLab_OtimReduzir_Desfazer =
(
    local n = 0
    if InLab_ReduzirHistorico.count == 0 then
        InLab_Log "Desfazer: nenhuma redução nesta sessão." tipo:#warn
    else
    (
        local clique = InLab_ReduzirHistorico[InLab_ReduzirHistorico.count]
        deleteItem InLab_ReduzirHistorico InLab_ReduzirHistorico.count
        local selOriginal = selection as array
        local painelOriginal = getCommandPanelTaskMode()
        undo "InLab Desfazer redução" on
        (
            for r in clique do
            (
                if not isValidNode r.no then InLab_Log "Desfazer: objeto do registro não existe mais na cena." tipo:#warn
                else if not (InLab_OtimReduzir_NoStack r.no r.modificador) then
                    InLab_Log (r.no.name + ": o ProOptimizer não está mais no stack (Ctrl+Z, colapsado ou removido?) — pulada.") tipo:#warn
                else if (abs (r.modificador.VertexPercent - r.pctDepois)) > 0.001 then
                    InLab_Log (r.no.name + ": o VertexPercent mudou depois do clique (Ctrl+Z ou edição à mão?) — pulada.") tipo:#warn
                else
                (
                    try
                    (
                        if r.criado then deleteModifier r.no r.modificador
                        else
                        (
                            -- Subir o VertexPercent não refaz a malha (ver
                            -- InLab_OtimReduzir_Refrescar); no Desfazer o
                            -- liga/desliga não bastou: refaz o Calculate.
                            r.modificador.VertexPercent = r.pctAntes
                            if InLab_OtimReduzir_Calcular r.no r.modificador then
                                r.modificador.VertexPercent = r.pctAntes
                            else
                                InLab_Log (r.no.name + ": não recalculei o ProOptimizer — a malha pode continuar a do clique desfeito.") tipo:#warn
                        )
                        InLab_Log (r.no.name + ": volta a " + (InLab_Otim_Milhar (GetTriMeshFaceCount r.no)[1]) + " triângulos.") tipo:#ok
                        n += 1
                    )
                    catch ( InLab_Log (r.no.name + ": não desfiz (" + getCurrentException() + ").") tipo:#err )
                )
            )
        )
        try
        (
            if selOriginal.count > 0 then select (for s in selOriginal where isValidNode s collect s) else clearSelection()
            setCommandPanelTaskMode painelOriginal
        )
        catch ( InLab_Log ("Desfazer: não restaurei seleção/painel (" + getCurrentException() + ").") tipo:#warn )
        InLab_Log ("Desfazer: " + n as string + " de " + clique.count as string + " peça(s) voltaram ao clique anterior.") \
            tipo:(if n == clique.count then #ok else #warn)
    )
    n
)
