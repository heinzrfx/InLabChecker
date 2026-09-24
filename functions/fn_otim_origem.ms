/*
================================================================================
 functions\fn_otim_origem.ms — Otimização · passo 1 · Reduzir na origem
--------------------------------------------------------------------------------
 Spec: docs\superpowers\specs\2026-09-23-otimizacao-design.md, seção 3.2.
 Contrato: ver o cabeçalho de functions\fn_otim_nucleo.ms.

 23/09/2026 (issue #60): versão mínima (Calcular devolvia #()).
 24/09/2026 (issue #61): o passo de verdade.
   - LEVANTAR os "botões de peso" do stack vivo de cada nó da seleção:
     iterações de TurboSmooth/MeshSmooth/OpenSubdiv e do NURMS do Editable
     Poly, segmentos de Chamfer/Shell/Lathe/Extrude, lados/segmentos das
     primitivas e passos/lados de spline renderizável. Nomes de propriedade
     sondados no Max 2024 (24/09/2026); cada um é conferido com isProperty
     e, se faltar no build, é pulado com log.
   - FICAM FORA: modificador desligado (enabled ou enabledInViews falso),
     propriedade animada (tem controlador: mexer nela criaria/deslocaria
     key) e SEGMENTOS QUE DEFINEM FORMA — todo botão que não é de subdivisão
     e está ABAIXO, no stack, de uma subdivisão ou deformador ligado (Bend,
     Twist, Taper, FFD, Noise, Displace). A spec cita a base (primitiva /
     Editable Poly); estendemos a modificadores abaixo (um Chamfer embaixo do
     TurboSmooth também é gaiola). Ali o botão válido é o da subdivisão.
   - MEDIR sem deixar nada alterado: muda o valor, avalia os nós que usam o
     objeto (classof + GetTriMeshFaceCount), volta. O guloso mantém os
     degraus escolhidos aplicados só durante o cálculo; no fim TODO botão
     volta ao valor original, inclusive se der exceção no meio (restauração
     fora do try do cálculo), com undo desligado.
   - INSTÂNCIAS: o custo é a soma dos triângulos de TODOS os nós que
     dependem do objeto (refs.dependentNodes) — instância de base e
     modificador instanciado em nós diferentes multiplicam a economia. O
     botão compartilhado aparece uma vez só e é alterado uma vez só.
   - GULOSO por economia/dano (dano_subdiv / dano_outros, tabela de pisos)
     até o total da CENA chegar no centro da faixa, sem descer do mínimo; se
     tudo chega no piso antes, loga quanto falta (entra no passo 2).
   - Degrau: 1 para iterações e segmentos; para lados e segmentos de peças
     redondas (lados, esfera, toro, Lathe, lados de spline) ~1/8 do valor,
     sempre PAR (mín. 2): não gasta dezenas de medições em 64 → 12 e mantém
     a paridade (64 → 56 → 50 ... → 12, sem 15 lados).
   - Splines renderizáveis contam triângulos aqui (InLab_OtimOrigem_TrisNo):
     InLab_Otim_Triangulos só conta GeometryClass, e uma Line renderizável
     sem modificador é Shape. O total do cálculo usa este contador para a
     economia da spline não ficar fora da conta.
   - Laço limitado por INLAB_OTIM_ORIGEM_MAX_AVAL avaliações e
     INLAB_OTIM_ORIGEM_MAX_SEG segundos (CLAUDE.md, "Desempenho"): passou,
     para com o que já tem e loga.
   - APLICAR em undo, registro #(alvo, prop, valorAntes) em
     InLab_UltimaOtimOrigem; com useRenderIterations ligado, renderIterations
     acima do novo valor desce junto (também no registro). REVERTER devolve
     os valores exatos (InLab_Otim_Restaurar, ordem inversa).
   - Nunca colapsa, apaga ou troca modificador.

 `global` antes de cada fn (mesmo já declarada em fn_otim_nucleo.ms): este
 arquivo pode ser carregado sozinho por InLab_RecarregarPlugin() — padrão de
 functions\fn_renomear_produto.ms.
================================================================================
*/

global INLAB_OTIM_ORIGEM_MAX_AVAL = 3000
global INLAB_OTIM_ORIGEM_MAX_SEG = 60
-- Registro do último Aplicar. SEM inicializador: recarregar o plugin não pode
-- apagar o que o Reverter ainda precisa (mesmo motivo de INLAB_OTIM_META_MANUAL).
global InLab_UltimaOtimOrigem
if InLab_UltimaOtimOrigem == undefined do InLab_UltimaOtimOrigem = #()

-- Um botão de peso levantado da cena.
struct OtimOrigemBotao
(
    alvo,               -- modificador ou base object
    prop,               -- #iterations, #segs...
    chave,              -- chave em INLAB_OTIM_PISOS
    subdiv = false,
    redondo = false,    -- degrau de 1/8 do valor
    dono,               -- nó usado no rótulo
    nos = #(),          -- todos os nós que dependem do alvo
    original,
    valor,              -- valor proposto (durante o cálculo: aplicado de verdade)
    piso,
    dano,
    trisAntes = 0,
    economia = 0,
    prox,               -- #(valorNovo, economia) do próximo degrau, ou undefined
    esgotado = false
)

-- Classes (em minúsculas) que tornam "de forma" os botões abaixo delas.
global INLAB_OTIM_ORIGEM_SUBDIV = #("turbosmooth", "meshsmooth", "opensubdiv")
global INLAB_OTIM_ORIGEM_DEFORM = #("bend", "twist", "taper", "ffd_2x2x2", "ffd_3x3x3", "ffd_4x4x4",
                                    "ffdbox", "ffdcyl", "noisemodifier", "displace")

-- Botões por classe: #(classe, #(#(prop, chave, redondo), ...)). Subdivisão é
-- tratada à parte (INLAB_OTIM_ORIGEM_SUBDIV + NURMS do Editable Poly).
global INLAB_OTIM_ORIGEM_TABELA = #(
    #("chamfer",    #(#(#segments, "chamfer", false))),
    #("shell",      #(#(#segments, "shell", false))),
    #("lathe",      #(#(#segs, "lathe", true))),
    #("extrude",    #(#(#segs, "extrude", false))),
    #("box",        #(#(#lengthsegs, "boxsegs", false), #(#widthsegs, "boxsegs", false), #(#heightsegs, "boxsegs", false))),
    #("cylinder",   #(#(#sides, "lados", true), #(#heightsegs, "alturasegs", false), #(#capsegs, "alturasegs", false))),
    #("cone",       #(#(#sides, "lados", true), #(#heightsegs, "alturasegs", false), #(#capsegs, "alturasegs", false))),
    #("tube",       #(#(#sides, "lados", true), #(#heightsegs, "alturasegs", false), #(#capsegs, "alturasegs", false))),
    #("capsule",    #(#(#sides, "lados", true))),
    #("chamfercyl", #(#(#sides, "lados", true), #(#Fillet_Segments, "fillet", false))),
    #("chamferbox", #(#(#Fillet_Segments, "fillet", false))),
    #("sphere",     #(#(#segs, "esfera", true))),
    #("torus",      #(#(#segs, "torus_segs", true), #(#sides, "torus_lados", true)))
)

-- Chaves de piso que este passo usa (para o log dos pisos em uso).
global INLAB_OTIM_ORIGEM_CHAVES = #("turbosmooth", "meshsmooth", "opensubdiv", "nurms", "chamfer", "shell",
                                    "lathe", "extrude", "lados", "alturasegs", "esfera", "torus_segs",
                                    "torus_lados", "fillet", "boxsegs", "spline_passos", "spline_lados",
                                    "dano_subdiv", "dano_outros")

global InLab_OtimOrigem_NomeProp
fn InLab_OtimOrigem_NomeProp prop =
(
    case (prop as string) of
    (
        "iterations":       "iterações"
        "segments":         "segmentos"
        "segs":             "segmentos"
        "sides":            "lados"
        "heightsegs":       "segs de altura"
        "capsegs":          "segs da tampa"
        "lengthsegs":       "segs de comprimento"
        "widthsegs":        "segs de largura"
        "Fillet_Segments":  "segs do arredondado"
        "steps":            "passos"
        "render_sides":     "lados da espessura"
        default:            (prop as string)
    )
)

global InLab_OtimOrigem_SplineRenderizavel
fn InLab_OtimOrigem_SplineRenderizavel o =
(
    superclassof o == Shape and \
        ((try (o.render_displayRenderMesh == true) catch (false)) or (try (o.render_renderable == true) catch (false)))
)

-- Triângulos de UM nó, forçando a avaliação (classof). Geometria como
-- InLab_Otim_Triangulos; spline renderizável pelo snapshot (a malha de render).
global InLab_OtimOrigem_TrisNo
fn InLab_OtimOrigem_TrisNo o =
(
    if not isValidNode o then 0
    else
    (
        classof o
        if InLab_EhGeometria o then (GetTriMeshFaceCount o)[1]
        else if InLab_OtimOrigem_SplineRenderizavel o then
        (
            local n = 0
            try
            (
                local m = snapshotAsMesh o
                n = m.numfaces
                delete m
            )
            catch ( InLab_Log (o.name + ": não medi a spline renderizável (" + getCurrentException() + ").") tipo:#warn )
            n
        )
        else 0
    )
)

global InLab_OtimOrigem_TrisNos
fn InLab_OtimOrigem_TrisNos nos =
(
    local t = 0
    for o in nos do t += InLab_OtimOrigem_TrisNo o
    t
)

global InLab_OtimOrigem_Conta
fn InLab_OtimOrigem_Conta o = isValidNode o and (InLab_EhGeometria o or InLab_OtimOrigem_SplineRenderizavel o)

global InLab_OtimOrigem_Ativo
fn InLab_OtimOrigem_Ativo m =
    (try (m.enabled != false) catch (true)) and (try (m.enabledInViews != false) catch (true))

-- Tenta registrar um botão. Devolve o botão, ou undefined se ficou fora (com log).
global InLab_OtimOrigem_NovoBotao
fn InLab_OtimOrigem_NovoBotao o alvo prop chave subdiv redondo botoes =
(
    local nomeAlvo = (classof alvo) as string
    local jaTem = false
    for b in botoes where b.alvo == alvo and b.prop == prop do jaTem = true
    if jaTem then undefined
    else if not (isProperty alvo prop) then
    (
        InLab_Log (o.name + ": " + nomeAlvo + "." + prop as string + " não existe neste build — pulado.") tipo:#warn
        undefined
    )
    else
    (
        local v = try (getProperty alvo prop) catch (undefined)
        local ctrl = try (getPropertyController alvo prop) catch (undefined)
        if not (isKindOf v Integer) then
        (
            InLab_Log (o.name + ": " + nomeAlvo + "." + prop as string + " não é inteiro (" + v as string + ") — pulado.") tipo:#warn
            undefined
        )
        else if ctrl != undefined then
        (
            InLab_Log (o.name + ": " + nomeAlvo + " · " + (InLab_OtimOrigem_NomeProp prop) + " é animado — pulado.") tipo:#warn
            undefined
        )
        else
        (
            local nos = for n in (refs.dependentNodes alvo) where InLab_OtimOrigem_Conta n collect n
            if (findItem nos o) == 0 do append nos o
            local b = OtimOrigemBotao alvo:alvo prop:prop chave:chave subdiv:subdiv redondo:redondo dono:o nos:nos \
                        original:v valor:v piso:((InLab_Otim_Piso chave) as integer) \
                        dano:(InLab_Otim_Piso (if subdiv then "dano_subdiv" else "dano_outros"))
            append botoes b
            b
        )
    )
)

-- Levanta os botões de um nó e acrescenta em `botoes` (sem repetir alvo+prop).
global InLab_OtimOrigem_Levantar
fn InLab_OtimOrigem_Levantar o botoes =
(
    local nMods = o.modifiers.count
    -- Menor índice (mais perto do topo) de subdivisão/deformador ligado.
    -- Botão não-subdivisão com índice MAIOR que ele (abaixo) define forma.
    local limiteForma = 0
    local nomeForma = ""
    for i = nMods to 1 by -1 do
    (
        local m = o.modifiers[i]
        local cn = toLower ((classof m) as string)
        if (InLab_OtimOrigem_Ativo m) and ((findItem INLAB_OTIM_ORIGEM_SUBDIV cn) > 0 or (findItem INLAB_OTIM_ORIGEM_DEFORM cn) > 0) do
        (
            limiteForma = i
            nomeForma = (classof m) as string
        )
    )
    fn defineForma i limiteForma = limiteForma > 0 and i > limiteForma

    -- Modificadores (índice 1 = topo).
    for i = 1 to nMods do
    (
        local m = o.modifiers[i]
        local cn = toLower ((classof m) as string)
        if not (InLab_OtimOrigem_Ativo m) then
        (
            if (findItem INLAB_OTIM_ORIGEM_SUBDIV cn) > 0 or (for t in INLAB_OTIM_ORIGEM_TABELA where t[1] == cn collect t).count > 0 do
                InLab_Log (o.name + ": " + m.name + " desligado — ignorado.") tipo:#info
        )
        else if (findItem INLAB_OTIM_ORIGEM_SUBDIV cn) > 0 then
            InLab_OtimOrigem_NovoBotao o m #iterations cn true false botoes
        else
        (
            for t in INLAB_OTIM_ORIGEM_TABELA where t[1] == cn do
            (
                if defineForma i limiteForma then
                    InLab_Log (o.name + ": " + m.name + " fica como está — alimenta " + nomeForma + " acima (define a forma).") tipo:#info
                else
                    for d in t[2] do InLab_OtimOrigem_NovoBotao o m d[1] d[2] false d[3] botoes
            )
        )
    )

    -- Base object.
    local base = o.baseobject
    local cn = toLower ((classof base) as string)
    local baseForma = defineForma (nMods + 1) limiteForma
    if cn == "editable_poly" then
    (
        if (try (base.surfSubdivide == true) catch (false)) do
            InLab_OtimOrigem_NovoBotao o base #iterations "nurms" true false botoes
    )
    else if superclassof base == Shape then
    (
        if baseForma then
            InLab_Log (o.name + ": spline fica como está — alimenta " + nomeForma + " acima (define a forma).") tipo:#info
        else
        (
            InLab_OtimOrigem_NovoBotao o base #steps "spline_passos" false false botoes
            if InLab_OtimOrigem_SplineRenderizavel o do
                InLab_OtimOrigem_NovoBotao o base #render_sides "spline_lados" false true botoes
        )
    )
    else
    (
        for t in INLAB_OTIM_ORIGEM_TABELA where t[1] == cn do
        (
            if baseForma then
                InLab_Log (o.name + ": segmentos de " + (classof base) as string + " ficam como estão — alimentam " + nomeForma + " acima (definem a forma).") tipo:#info
            else
                for d in t[2] do InLab_OtimOrigem_NovoBotao o base d[1] d[2] false d[3] botoes
        )
    )
    botoes
)

global InLab_OtimOrigem_Degrau
fn InLab_OtimOrigem_Degrau b =
    if b.redondo then amax 2 (2 * (b.valor / 16)) else 1

-- Mede o próximo degrau de um botão com o estado atual dos outros e volta.
-- Devolve quantas avaliações fez.
global InLab_OtimOrigem_MedirProx
fn InLab_OtimOrigem_MedirProx b =
(
    b.prox = undefined
    if b.esgotado or b.valor <= b.piso then ( b.esgotado = true; 0 )
    else
    (
        local nv = amax b.piso (b.valor - (InLab_OtimOrigem_Degrau b))
        local antes = InLab_OtimOrigem_TrisNos b.nos
        setProperty b.alvo b.prop nv
        local depois = InLab_OtimOrigem_TrisNos b.nos
        setProperty b.alvo b.prop b.valor
        if antes - depois > 0 then b.prox = #(nv, antes - depois)
        else b.esgotado = true
        2
    )
)

global InLab_OtimOrigem_LogPisos
fn InLab_OtimOrigem_LogPisos =
(
    local s = "Reduzir na origem · pisos em uso:"
    for k in INLAB_OTIM_ORIGEM_CHAVES do
    (
        local v = InLab_Otim_Piso k
        s += " " + k + "=" + (if v == (floor v) then (v as integer) as string else v as string)
    )
    InLab_Log s tipo:#info
)

global InLab_OtimOrigem_Calcular
fn InLab_OtimOrigem_Calcular objs =
(
    local faixa = InLab_Otim_Faixa()
    if faixa == undefined then
    (
        InLab_Log "Reduzir na origem: escolha a família (seção Produto) ou digite a meta." tipo:#warn
        return #()
    )
    InLab_OtimOrigem_LogPisos()

    local botoes = #()
    for o in objs where InLab_OtimOrigem_Conta o do InLab_OtimOrigem_Levantar o botoes
    if botoes.count == 0 then
    (
        InLab_Log "Reduzir na origem: nenhum botão de peso na seleção (stack sem subdivisão, chanfro, primitiva etc.)." tipo:#info
        return #()
    )

    local total = InLab_OtimOrigem_TrisNos (for o in objects where InLab_OtimOrigem_Conta o collect o)
    local totalInicial = total
    local alvo = faixa[3]
    local minimo = faixa[1]
    if total <= alvo then
    (
        InLab_Log ("Reduzir na origem: a cena já está no centro da faixa ou abaixo (" + (InLab_Otim_Milhar total) + " triângulos).") tipo:#ok
        return #()
    )

    local aval = 0
    local t0 = timeStamp()
    local limite = false
    local erro = undefined
    with undo off with redraw off
    (
        try
        (
            for b in botoes do b.trisAntes = InLab_OtimOrigem_TrisNos b.nos
            for b in botoes do aval += InLab_OtimOrigem_MedirProx b
            while total > alvo do
            (
                if aval >= INLAB_OTIM_ORIGEM_MAX_AVAL or (timeStamp() - t0) > INLAB_OTIM_ORIGEM_MAX_SEG * 1000 do
                ( limite = true; exit )
                local melhor = undefined
                local melhorRazao = 0.0
                for b in botoes where b.prox != undefined and (total - b.prox[2]) >= minimo do
                (
                    local razao = b.prox[2] as float / (amax 0.001 b.dano)
                    if razao > melhorRazao do ( melhor = b; melhorRazao = razao )
                )
                if melhor == undefined do exit
                -- Mantém o degrau aplicado durante o cálculo (volta no fim).
                setProperty melhor.alvo melhor.prop melhor.prox[1]
                melhor.valor = melhor.prox[1]
                melhor.economia += melhor.prox[2]
                total -= melhor.prox[2]
                -- Remede quem divide nó com o escolhido (o custo deles mudou).
                for b in botoes where not b.esgotado do
                (
                    local divide = false
                    for n in b.nos where (findItem melhor.nos n) > 0 do divide = true
                    if divide do aval += InLab_OtimOrigem_MedirProx b
                )
            )
        )
        catch ( erro = getCurrentException() )

        -- Nada fica alterado, com ou sem exceção.
        for b in botoes do
            try ( if (getProperty b.alvo b.prop) != b.original do setProperty b.alvo b.prop b.original )
            catch ( InLab_Log (b.dono.name + ": não voltou " + b.prop as string + " (" + getCurrentException() + ").") tipo:#err )
    )
    if erro != undefined do
    (
        InLab_Log ("Reduzir na origem: erro no cálculo — nada proposto (" + erro + ").") tipo:#err
        return #()
    )
    if limite do
        InLab_Log ("Reduzir na origem: cálculo parou no limite (" + aval as string + " avaliações, " +
                   ((timeStamp() - t0) / 1000) as string + " s) — proposta parcial. Cena pesada: rode por partes.") tipo:#warn

    local propostas = for b in botoes where b.valor < b.original collect
    (
        local nomeNo = b.dono.name + (if b.nos.count > 1 then " (+" + (b.nos.count - 1) as string + ")" else "")
        OtimProposta no:b.dono alvo:b.alvo prop:b.prop antes:b.original depois:b.valor \
            trisAntes:b.trisAntes trisDepois:(b.trisAntes - b.economia) \
            rotulo:(nomeNo + "  ·  " + (classof b.alvo) as string + "  ·  " + (InLab_OtimOrigem_NomeProp b.prop) + " " +
                    b.original as string + " → " + b.valor as string + "  ·  " +
                    (InLab_Otim_Milhar b.trisAntes) + " → " + (InLab_Otim_Milhar (b.trisAntes - b.economia))) \
            motivo:((if b.subdiv then "subdivisão" else "densidade") + (if b.nos.count > 1 then " · compartilhado por " + b.nos.count as string + " nós" else ""))
    )

    InLab_Log ("Reduzir na origem: " + propostas.count as string + " ajuste(s), cena " + (InLab_Otim_Milhar totalInicial) + " → " +
               (InLab_Otim_Milhar total) + " triângulos (centro da faixa: " + (InLab_Otim_Milhar alvo) + ", " + aval as string + " avaliações).") tipo:#info
    if total > alvo do
        InLab_Log ("Reduzir na origem: com os botões no piso ainda faltam " + (InLab_Otim_Milhar (total - alvo)) +
                   " triângulos para o centro da faixa — use o passo 2 (Ajuste fino).") tipo:#warn
    propostas
)

global InLab_OtimOrigem_Aplicar
fn InLab_OtimOrigem_Aplicar propostas =
(
    local marcadas = for p in propostas where p.marcada and p.alvo != undefined collect p
    if marcadas.count == 0 then
    (
        InLab_Log "Reduzir na origem: nenhuma linha marcada." tipo:#warn
        return 0
    )
    local reg = #()
    local n = 0
    undo "InLab Reduzir na origem" on
    (
        for p in marcadas do
        (
            local nome = if isValidNode p.no then p.no.name else "?"
            local rot = (classof p.alvo) as string + " · " + (InLab_OtimOrigem_NomeProp p.prop)
            try
            (
                local atual = getProperty p.alvo p.prop
                if atual != p.antes then
                    InLab_Log (nome + ": " + rot + " mudou desde o Calcular (" + atual as string + ", esperado " + p.antes as string + ") — pulado. Calcule de novo.") tipo:#warn
                else
                (
                    InLab_Otim_Guardar reg p.alvo p.prop
                    setProperty p.alvo p.prop p.depois
                    -- Render: com useRenderIterations, não deixa o render acima do novo valor.
                    if p.prop == #iterations and (isProperty p.alvo #useRenderIterations) and (isProperty p.alvo #renderIterations) do
                        if p.alvo.useRenderIterations and p.alvo.renderIterations > p.depois do
                        (
                            InLab_Otim_Guardar reg p.alvo #renderIterations
                            p.alvo.renderIterations = p.depois
                        )
                    n += 1
                    InLab_Log (nome + ": " + rot + " " + p.antes as string + " → " + p.depois as string + ".") tipo:#ok
                )
            )
            catch ( InLab_Log (nome + ": " + rot + " não aplicou (" + getCurrentException() + ").") tipo:#err )
        )
    )
    if reg.count > 0 do InLab_UltimaOtimOrigem = reg
    InLab_Log ("Reduzir na origem: " + n as string + " de " + marcadas.count as string + " ajuste(s) aplicado(s).") tipo:(if n == marcadas.count then #ok else #warn)
    n
)

global InLab_OtimOrigem_Reverter
fn InLab_OtimOrigem_Reverter =
(
    if InLab_UltimaOtimOrigem == undefined or InLab_UltimaOtimOrigem.count == 0 then
    (
        InLab_Log "Reduzir na origem: nada a reverter." tipo:#info
        0
    )
    else
    (
        local n = 0
        undo "InLab Reverter redução na origem" on ( n = InLab_Otim_Restaurar InLab_UltimaOtimOrigem )
        InLab_Log ("Reduzir na origem: " + n as string + " de " + InLab_UltimaOtimOrigem.count as string + " valor(es) revertido(s).") tipo:(if n == InLab_UltimaOtimOrigem.count then #ok else #warn)
        InLab_UltimaOtimOrigem = #()
        n
    )
)
