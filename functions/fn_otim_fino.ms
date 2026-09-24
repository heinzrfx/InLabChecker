/*
================================================================================
 functions\fn_otim_fino.ms — Otimização · passo 2 · Ajuste fino
--------------------------------------------------------------------------------
 Spec: docs\superpowers\specs\2026-09-23-otimizacao-design.md, seção 3.3.
 Contrato: ver o cabeçalho de functions\fn_otim_nucleo.ms.

 O QUE FAZ: um ProOptimizer VIVO por peça (por stack compartilhado), com meta
 de triângulos por peça e as proteções ligadas.

 META POR PEÇA (InLab_OtimFino_DividirMeta): o orçamento que a seleção pode
 ter é dividido por ÁREA DE SUPERFÍCIE (meta = λ · área, com λ igual para
 todas). Peça densa para o tamanho perde mais; peça que já está abaixo de
 λ · área fica intacta e a sobra dela vai para as outras (λ é achado por busca
 binária com as metas presas entre o piso e os triângulos atuais — "enchimento
 de água"). Área = soma de meshop.getFaceArea do snapshot em mundo (nativo,
 rápido mesmo em malha grande).
 PISO POR PEÇA: nunca abaixo de max(piso_fino_pct% dos triângulos atuais,
 piso_fino_min) — padrão 60% e 300, sobrescritos no InLabChecker.ini
 (InLab_Otim_Piso "fino_pct"/"fino_min", fn_otim_nucleo.ms). Peça com menos
 triângulos que o mínimo não é proposta.
 INSTÂNCIAS (issue #42): InLab_DeduplicarInstancias (core\utils.ms) — um
 ProOptimizer por stack; o custo do grupo no orçamento é triângulos × número
 de nós do stack (o GLB exporta cada nó), inclusive instâncias fora da seleção,
 que também são reduzidas pelo modificador compartilhado.

 PROTEÇÕES (sondadas no Max 2024 .2.14 em 24/09/2026 com showProperties):
   LockMat = true        fronteira de material (padrão de fábrica já true)
   KeepUV  = true        mantém as coordenadas UV (padrão false)
   LockUV  = true        trava a borda de ilha UV (padrão false)
   KeepNormals = true    (padrão true)
   OptimizationMode = 2  "Exclude Borders". Medido num Plane 40x40 a 20%:
                         0 (Crunch) deixou 52 de 160 arestas abertas, 1
                         (Protect, o padrão) 57 de 160, 2 (Exclude) 160 de 160.
                         Só o 2 protege borda aberta de fato — "Protect" não.
 KeepUV SOME SOZINHO em peça sem UV no canal 1: o ProOptimizer desliga o
 flag no Calculate (lido de volta = false; conferido com Sphere mapcoords:false
 vs true em 24/09/2026). Não é falha: não há UV para manter. O Aplicar loga
 #info por peça quando isso acontece.
 Todas existem nesse build. Cada uma é sondada com isProperty antes de setar;
 a que faltar é logada (#warn) uma vez por Aplicar, e a que der erro ao setar
 é logada por objeto (#err). O canal 3 (AO do Auto UV) sobrevive ao
 ProOptimizer com KeepUV (conferido na mesma sondagem).

 PRECISÃO: VertexPercent inicial = meta / triângulos atuais. Mede; se errou a
 meta em mais de 10%, uma segunda passada corrige o percentual pela razão
 meta/obtido (triângulos acompanham vértices quase linearmente: 50% -> 1982
 de 3968, 30% -> 1186 numa Sphere segs:64). Se ainda errar, loga #warn.

 CONTEXTO OBRIGATÓRIO DO .Calculate: o mesmo documentado no cabeçalho de
 functions\fn_prooptimizer.ms — nó SELECIONADO, painel Modify, modificador
 CORRENTE (modPanel.setCurrentObject). Fora disso o Calculate é descartado em
 silêncio. As proteções são setadas ANTES do Calculate. NÃO REMOVA esse bloco.

 REGISTRO: InLab_UltimoAjusteFino (FinoRecord por stack). Reverter remove
 exatamente esses modificadores; Comparar liga/desliga enabledInViews deles.
 O modificador se chama INLAB_FINO_NOME_MOD ("InLab · Ajuste fino").

 NUNCA EMPILHA (revisão de 24/09/2026): peça que já tem um ProOptimizer do
 ajuste fino (no registro OU com esse nome no stack) não é recalculada nem
 recebe um segundo — seria redução sobre redução, e o Reverter/Comparar
 perderiam o primeiro. Calcular loga #warn "já tem ajuste fino — use Reverter
 antes de recalcular" e trata a peça como resto fixo da cena. O registro
 ACUMULA entre Aplicar; só o Reverter zera (e remove todos os registrados).
 Erro inesperado numa peça é logado e não aborta o Aplicar: seleção, painel
 e resumo sempre são restaurados/logados.

 HISTÓRICO:
 23/09/2026 (issue #60): versão provisória — percentual único pela meta,
 usando InLab_ProOptimizer de fn_prooptimizer.ms.
 24/09/2026 (issue #62): meta por peça por área, piso, proteções, segunda
 passada e registro próprio. Não usa mais fn_prooptimizer.ms, que saiu do
 manifesto (o arquivo e tests\test_prooptimizer.ms ficam até a limpeza #52).

 `global` antes de cada fn (mesmo já declarada em fn_otim_nucleo.ms): este
 arquivo pode ser carregado sozinho por InLab_RecarregarPlugin() — padrão de
 functions\fn_renomear_produto.ms.
================================================================================
*/

-- Um ProOptimizer aplicado pelo ajuste fino (um por stack).
struct FinoRecord
(
    no,             -- representante do stack
    modificador,    -- a instância exata do ProOptimizer adicionada
    instancias = 1, -- nós que compartilham o stack
    meta = 0,       -- triângulos por nó pedidos
    trisAntes = 0,
    trisDepois = 0,
    passadas = 1    -- 2 quando a segunda passada corrigiu o percentual
)

-- Sem inicializador no `global`: recarregar o arquivo não pode apagar o
-- registro dos Aplicar (mesmo padrão de INLAB_OTIM_META_MANUAL). Acumula até
-- o Reverter.
global InLab_UltimoAjusteFino
if InLab_UltimoAjusteFino == undefined do InLab_UltimoAjusteFino = #()

-- Nome do ProOptimizer que o ajuste fino põe no stack (identifica a peça já
-- ajustada mesmo depois de recarregar o plugin, quando o registro se perdeu).
global INLAB_FINO_NOME_MOD = "InLab · Ajuste fino"

-- Erro relativo aceito antes da segunda passada (spec 3.3).
global INLAB_FINO_TOLERANCIA = 0.10

-- Proteções: #(propriedade, valor, descrição para o log). Ver cabeçalho.
global INLAB_FINO_PROTECOES = #(
    #(#LockMat, true, "fronteira de material"),
    #(#KeepUV, true, "manter UV"),
    #(#LockUV, true, "borda de ilha UV"),
    #(#KeepNormals, true, "normais"),
    #(#OptimizationMode, 2, "bordas abertas (Exclude Borders)")
)

-- Área de superfície em mundo (unidades do sistema ao quadrado).
global InLab_OtimFino_Area
fn InLab_OtimFino_Area o =
(
    local area = 0.0
    try
    (
        local m = snapshotAsMesh o
        if m.numfaces > 0 do area = meshop.getFaceArea m #{1..m.numfaces}
        delete m
    )
    catch ( InLab_Log (o.name + ": não medi a área (" + getCurrentException() + ") — peça fica no piso.") tipo:#warn )
    area
)

-- A peça (ou o stack dela) já tem um ProOptimizer do ajuste fino?
global InLab_OtimFino_TemAjuste
fn InLab_OtimFino_TemAjuste o =
(
    local tem = false
    for m in o.modifiers where classof m == ProOptimizer and m.name == INLAB_FINO_NOME_MOD do tem = true
    if not tem do
        for r in InLab_UltimoAjusteFino where isValidNode r.no and r.modificador != undefined do
            for m in o.modifiers where m == r.modificador do tem = true
    tem
)

-- Piso de uma peça com `tris` triângulos: max(pct%, mínimo), nunca acima de tris.
global InLab_OtimFino_PisoPeca
fn InLab_OtimFino_PisoPeca tris =
(
    local pct = InLab_Otim_Piso "fino_pct"
    local minimo = InLab_Otim_Piso "fino_min"
    amin tris (amax (tris * pct / 100.0) minimo)
)

-- Divide o orçamento (triângulos) entre as peças, proporcional à área, com cada
-- meta presa entre o piso e os triângulos atuais. `pesos` = nós por stack.
-- Devolve as metas por nó (float). Se nem com tudo no piso couber, devolve os
-- pisos. Função pura (sem cena) para o teste conferir a conta.
global InLab_OtimFino_DividirMeta
fn InLab_OtimFino_DividirMeta tris areas pesos pisos orcamento =
(
    local n = tris.count
    fn metaCom lam tris areas pisos i = amin tris[i] (amax pisos[i] (lam * areas[i]))
    fn somaCom lam tris areas pesos pisos n =
    (
        local s = 0.0
        for i = 1 to n do s += pesos[i] * (amin tris[i] (amax pisos[i] (lam * areas[i])))
        s
    )
    local lamMax = 0.0
    for i = 1 to n where areas[i] > 0 do lamMax = amax lamMax (tris[i] / areas[i])
    local lam
    if (somaCom 0.0 tris areas pesos pisos n) >= orcamento then lam = 0.0
    else if (somaCom lamMax tris areas pesos pisos n) <= orcamento then lam = lamMax
    else
    (
        local lo = 0.0
        local hi = lamMax
        for k = 1 to 60 do
        (
            local mid = (lo + hi) / 2.0
            if (somaCom mid tris areas pesos pisos n) > orcamento then hi = mid else lo = mid
        )
        lam = lo
    )
    for i = 1 to n collect (metaCom lam tris areas pisos i)
)

global InLab_OtimFino_Calcular
fn InLab_OtimFino_Calcular objs =
(
    local geo = for o in objs where InLab_EhGeometria o collect o
    local faixa = InLab_Otim_Faixa()
    local total = InLab_Otim_Triangulos geo
    if faixa == undefined then
    (
        InLab_Log "Ajuste fino: escolha a família (seção Produto) ou digite a meta." tipo:#warn
        #()
    )
    else
    (
        -- Peça já ajustada fica fora (nunca empilha) e conta como resto fixo
        -- da cena no orçamento abaixo.
        local grupos = #()
        for g in InLab_DeduplicarInstancias geo do
        (
            if InLab_OtimFino_TemAjuste g.no then
                InLab_Log (g.no.name + ": já tem ajuste fino — use Reverter antes de recalcular.") tipo:#warn
            else append grupos g
        )
        local tris = #(), areas = #(), pesos = #(), pisos = #()
        local custoGrupos = 0
        for g in grupos do
        (
            local t = (GetTriMeshFaceCount g.no)[1]
            local k = (for i in g.instancias where isValidNode i and InLab_EhGeometria i collect i).count
            if k < 1 do k = 1
            append tris t
            append areas (InLab_OtimFino_Area g.no)
            append pesos k
            append pisos (InLab_OtimFino_PisoPeca t)
            custoGrupos += t * k
        )
        -- Orçamento dos grupos: alvo da faixa menos o resto da cena, que fica
        -- como está. Instâncias fora da seleção entram no custo do grupo
        -- (o modificador compartilhado reduz todas).
        local cena = InLab_Otim_Triangulos (for o in geometry collect o)
        local orcamento = amax 0 (faixa[3] - (cena - custoGrupos))
        InLab_Log ("Ajuste fino: pisos por peça = " + (InLab_Otim_Piso "fino_pct") as string + "% e " +
                   (InLab_Otim_Piso "fino_min") as string + " triângulos (piso_fino_pct / piso_fino_min no InLabChecker.ini).") tipo:#info
        if custoGrupos == 0 or custoGrupos <= orcamento then
        (
            InLab_Log ("Ajuste fino: a seleção já cabe na meta (" + (InLab_Otim_Milhar total) + " triângulos).") tipo:#ok
            #()
        )
        else
        (
            local metas = InLab_OtimFino_DividirMeta tris areas pesos pisos orcamento
            local somaAreas = 0.0, somaTris = 0.0
            for i = 1 to grupos.count do ( somaAreas += areas[i] * pesos[i]; somaTris += tris[i] * pesos[i] )
            local densMedia = if somaAreas > 0 then somaTris / somaAreas else 0.0
            local previsto = 0
            local props = #()
            for i = 1 to grupos.count do
            (
                local o = grupos[i].no
                local meta = (metas[i] + 0.5) as integer
                -- Menos de 2% de redução não vale um modificador: peça intacta.
                if meta <= tris[i] * 0.98 then
                (
                    previsto += meta * pesos[i]
                    local pct = amax 0.1 (100.0 * meta / tris[i])
                    local dens = if areas[i] > 0 and densMedia > 0 then (tris[i] / areas[i]) / densMedia else 0.0
                    local nomeInst = if pesos[i] > 1 then (o.name + " (×" + pesos[i] as string + ")") else o.name
                    local noPiso = meta <= pisos[i] + 1
                    append props (OtimProposta no:o alvo:o prop:#VertexPercent antes:100.0 depois:pct \
                        trisAntes:tris[i] trisDepois:meta \
                        rotulo:(nomeInst + "  ·  " + (InLab_Otim_Milhar tris[i]) + " → " + (InLab_Otim_Milhar meta) +
                                "  ·  " + (formattedPrint pct format:".0f") + "%" + (if noPiso then "  ·  no piso" else "")) \
                        motivo:("densidade " + (formattedPrint dens format:".1f") + "× a média" + (if noPiso then ", parou no piso" else "")))
                )
                else if tris[i] <= pisos[i] then
                (
                    previsto += tris[i] * pesos[i]
                    InLab_Log (o.name + ": fica intacta (" + tris[i] as string + " triângulos, abaixo do piso mínimo).") tipo:#info
                )
                else
                (
                    previsto += tris[i] * pesos[i]
                    InLab_Log (o.name + ": fica intacta (já econômica para o tamanho).") tipo:#info
                )
            )
            -- Folga de 1 triângulo por peça (arredondamento das metas).
            if previsto > orcamento + grupos.count do
                InLab_Log ("Ajuste fino: com os pisos por peça a proposta fica " + (InLab_Otim_Milhar (previsto - orcamento)) +
                           " triângulos acima da meta.") tipo:#warn
            props
        )
    )
)

-- Liga as proteções no ProOptimizer `po`. Devolve os nomes que não existem
-- nesta build (para logar uma vez só no fim do Aplicar).
global InLab_OtimFino_Proteger
fn InLab_OtimFino_Proteger po nomeNo =
(
    local faltando = #()
    for p in INLAB_FINO_PROTECOES do
    (
        if isProperty po p[1] then
        (
            try ( setProperty po p[1] p[2] )
            catch ( InLab_Log (nomeNo + ": ProOptimizer." + p[1] as string + " (" + p[3] + ") não aceitou " +
                               p[2] as string + " (" + getCurrentException() + ").") tipo:#err )
        )
        else append faltando p[1]
    )
    faltando
)

global InLab_OtimFino_Aplicar
fn InLab_OtimFino_Aplicar propostas =
(
    local marcadas = for p in propostas where p.marcada and isValidNode p.no collect p
    if marcadas.count == 0 then
    (
        InLab_Log "Ajuste fino: nenhuma peça marcada." tipo:#warn
        0
    )
    else
    (
        -- O registro NÃO é zerado aqui: acumula até o Reverter (ver cabeçalho).
        local aplicados = 0
        local varCalc = undefined
        local faltando = #()
        local selOriginal = selection as array
        local painelOriginal = getCommandPanelTaskMode()
        -- Segurança extra: a proposta já é por stack, mas duas linhas do mesmo
        -- stack (lista montada à mão) empilhariam dois ProOptimizer.
        local nosMarcados = for p in marcadas collect p.no
        local reps = for g in InLab_DeduplicarInstancias nosMarcados collect g.no
        local feitos = #()

        undo "InLab Ajuste fino" on
        (
            for p in marcadas where findItem reps p.no > 0 and findItem feitos p.no == 0 do
            (
                local o = p.no
                append feitos o
                if InLab_OtimFino_TemAjuste o then
                    InLab_Log (o.name + ": já tem ajuste fino — não empilho outro (use Reverter antes).") tipo:#warn
                else
                (
                    local po = undefined
                    local registrado = false
                    -- Erro inesperado numa peça não pode abortar o Aplicar antes
                    -- de restaurar seleção/painel e logar o resumo.
                    try
                    (
                        local nInst = (InLab_InstanciasDoNo o).count
                        local meta = p.trisDepois
                        local triAntes = (GetTriMeshFaceCount o)[1]
                        local vertAntes = (GetTriMeshFaceCount o)[2]

                        -- CONTEXTO OBRIGATÓRIO DO .Calculate (ver cabeçalho e
                        -- fn_prooptimizer.ms): selecionado + Modify + corrente.
                        select o
                        setCommandPanelTaskMode #modify
                        try ( subObjectLevel = 0 )
                        catch ( InLab_Log (o.name + ": não zerei o subObjectLevel (" + getCurrentException() + ").") tipo:#warn )
                        po = ProOptimizer()
                        po.name = INLAB_FINO_NOME_MOD
                        addModifier o po
                        try ( modPanel.setCurrentObject po ) catch ( InLab_Log (o.name + ": não pus o ProOptimizer como corrente no Modify (" + getCurrentException() + ").") tipo:#warn )

                        for f in (InLab_OtimFino_Proteger po o.name) where findItem faltando f == 0 do append faltando f

                        local calcOk = false
                        for c in #(#Calculate, #CalculationEnabled) while not calcOk do
                            if isProperty po c do
                                ( try ( setProperty po c true; calcOk = true; if varCalc == undefined do varCalc = c )
                                  catch ( InLab_Log (o.name + ": ProOptimizer." + c as string + " falhou (" + getCurrentException() + ").") tipo:#warn ) )

                        if not calcOk then
                        (
                            deleteModifier o po
                            InLab_Log (o.name + ": ProOptimizer sem Calculate/CalculationEnabled nesta build — peça NÃO otimizada.") tipo:#err
                        )
                        else
                        (
                            if isProperty po #KeepUV and not po.KeepUV do
                                InLab_Log (o.name + ": sem UV no canal 1 — o ProOptimizer desligou KeepUV sozinho.") tipo:#info
                            local pct = amax 0.1 (100.0 * meta / (amax 1 triAntes))
                            local obtido = triAntes
                            local passadas = 1
                            try
                            (
                                po.VertexPercent = pct
                                obtido = (GetTriMeshFaceCount o)[1]
                                -- Segunda passada (spec 3.3): errou mais de 10%.
                                if meta > 0 and (abs (obtido - meta)) > meta * INLAB_FINO_TOLERANCIA and obtido > 0 do
                                (
                                    pct = amin 100.0 (amax 0.1 (pct * meta / obtido))
                                    po.VertexPercent = pct
                                    obtido = (GetTriMeshFaceCount o)[1]
                                    passadas = 2
                                )
                            )
                            catch ( InLab_Log (o.name + ": ProOptimizer.VertexPercent falhou (" + getCurrentException() + ").") tipo:#err )

                            local vertDepois = (GetTriMeshFaceCount o)[2]
                            if vertDepois >= vertAntes then
                            (
                                deleteModifier o po
                                InLab_Log (o.name + ": ProOptimizer NÃO reduziu (" + vertAntes as string + " → " +
                                           vertDepois as string + " vértices). Modificador removido — malha intacta.") tipo:#warn
                            )
                            else
                            (
                                append InLab_UltimoAjusteFino (FinoRecord no:o modificador:po instancias:nInst meta:meta trisAntes:triAntes trisDepois:obtido passadas:passadas)
                                registrado = true
                                aplicados += 1
                                local erro = if meta > 0 then (100.0 * (obtido - meta) / meta) else 0.0
                                local txt = o.name + (if nInst > 1 then (" (×" + nInst as string + " instâncias, 1 modificador)") else "") +
                                            ": " + (InLab_Otim_Milhar triAntes) + " → " + (InLab_Otim_Milhar obtido) + " triângulos (meta " +
                                            (InLab_Otim_Milhar meta) + ", " + (formattedPrint erro format:"+.1f") + "%, " +
                                            (formattedPrint pct format:".1f") + "%" + (if passadas == 2 then ", 2ª passada" else "") + ")"
                                if (abs erro) > INLAB_FINO_TOLERANCIA * 100.0 then
                                    InLab_Log (txt + " — ainda fora dos " + (formattedPrint (INLAB_FINO_TOLERANCIA * 100.0) format:".0f") + "% (as proteções seguram a redução).") tipo:#warn
                                else InLab_Log txt tipo:#ok
                            )
                        )
                    )
                    catch
                    (
                        InLab_Log (o.name + ": erro no ajuste fino (" + getCurrentException() + ") — peça NÃO otimizada.") tipo:#err
                        -- Não deixa um ProOptimizer sem registro no stack.
                        if po != undefined and not registrado do
                            for m in o.modifiers where m == po do
                                try ( deleteModifier o po )
                                catch ( InLab_Log (o.name + ": não removi o ProOptimizer após o erro (" + getCurrentException() + ").") tipo:#err )
                    )
                )
            )
        )

        -- Restaura seleção e painel FORA do undo (não é parte da operação).
        try
        (
            if selOriginal.count > 0 then select (for s in selOriginal where isValidNode s collect s) else clearSelection()
            setCommandPanelTaskMode painelOriginal
        )
        catch ( InLab_Log ("Ajuste fino: não restaurei seleção/painel (" + getCurrentException() + ").") tipo:#warn )

        if varCalc != undefined do
            InLab_Log ("Ajuste fino: cálculo do ProOptimizer disparado por ." + varCalc as string + ".") tipo:#info
        if faltando.count > 0 do
            InLab_Log ("Ajuste fino: proteção(ões) inexistente(s) nesta build do ProOptimizer: " +
                       (for f in faltando collect f as string) as string + " — aplicado sem ela(s).") tipo:#warn
        InLab_Log ("Ajuste fino: " + aplicados as string + " de " + reps.count as string + " peça(s) otimizada(s).") \
            tipo:(if aplicados == reps.count then #ok else if aplicados == 0 then #err else #warn)
        aplicados
    )
)

-- Remove exatamente os ProOptimizer registrados (todos os Aplicar desde o
-- último Reverter). Devolve quantos saíram.
global InLab_OtimFino_Reverter
fn InLab_OtimFino_Reverter =
(
    local n = 0
    if InLab_UltimoAjusteFino.count == 0 then
        InLab_Log "Ajuste fino: nada aplicado nesta sessão para reverter." tipo:#warn
    else
    (
        undo "InLab Reverter ajuste fino" on
        (
            for r in InLab_UltimoAjusteFino do
            (
                if not isValidNode r.no then InLab_Log "Ajuste fino: objeto do registro não existe mais na cena." tipo:#warn
                else if (for m in r.no.modifiers where m == r.modificador collect m).count == 0 then
                    InLab_Log (r.no.name + ": ProOptimizer do ajuste fino não está mais no stack (colapsado ou removido?).") tipo:#warn
                else
                (
                    try
                    (
                        deleteModifier r.no r.modificador
                        InLab_Log (r.no.name + ": ProOptimizer removido (volta a " + (InLab_Otim_Milhar r.trisAntes) + " triângulos).") tipo:#ok
                        n += 1
                    )
                    catch ( InLab_Log (r.no.name + ": não removi o ProOptimizer (" + getCurrentException() + ").") tipo:#err )
                )
            )
        )
        InLab_UltimoAjusteFino = #()
        InLab_Log ("Ajuste fino revertido: " + n as string + " peça(s).") tipo:#ok
    )
    n
)

-- Liga/desliga na viewport os ProOptimizer registrados (Comparar).
global InLab_OtimFino_Comparar
fn InLab_OtimFino_Comparar ligar =
(
    local n = 0
    for r in InLab_UltimoAjusteFino where r.modificador != undefined and isValidNode r.no do
    (
        try ( r.modificador.enabledInViews = ligar; n += 1 )
        catch ( InLab_Log (r.no.name + ": Comparar não alternou o ProOptimizer (" + getCurrentException() + ").") tipo:#warn )
    )
    n
)
