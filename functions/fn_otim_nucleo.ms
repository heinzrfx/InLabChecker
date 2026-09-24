/*
================================================================================
 functions\fn_otim_nucleo.ms — núcleo da Otimização em 3 passos (23/09/2026)
--------------------------------------------------------------------------------
 Spec: docs\superpowers\specs\2026-09-23-otimizacao-design.md (issue #60).
 Base compartilhada dos 3 passos (Reduzir na origem, Ajuste fino, Faces
 escondidas): contagem em TRIÂNGULOS, faixa-alvo, estado do medidor, pisos
 de segurança (padrão aqui + ajuste da equipe no InLabChecker.ini, que
 sobrevive ao updater), registro de reversão e o despachante que a UI usa.

 CONTRATO DE CADA PASSO (um arquivo por passo, functions\fn_otim_*.ms):
   InLab_Otim<Passo>_Calcular objs     → #(OtimProposta), nada muda na cena
   InLab_Otim<Passo>_Aplicar propostas → aplica as marcadas, em undo, com registro
   InLab_Otim<Passo>_Reverter          → desfaz exatamente o último Aplicar
 <Passo> = Origem (1), Fino (2), Escondidas (3). A UI só fala com
 InLab_Otim_Calcular/Aplicar/Reverter passo — por isso #61, #62 e #63 só
 trocam o próprio arquivo.

 UNIDADE: triângulos por NÓ (instância conta uma vez por nó, como o GLB
 exporta). É o que o site carrega e não muda antes/depois do ProOptimizer
 (decisão do brainstorm de 23/09/2026).

 24/09/2026 (issue #63, revisão): o passo 3 apaga faces por ÍNDICE
 (Mesh_Select + DeleteMesh no topo do stack). Qualquer mudança ABAIXO dele
 (passo 1 aplicado ou revertido, passo 2 revertido) muda a triangulação e o
 DeleteMesh passaria a apagar as faces erradas em silêncio. Por isso o
 despachante dos passos 1 e 2 (Calcular, Aplicar e Reverter) pula toda peça
 (stack) com o passo 3 aplicado e loga #warn "<nome>: tem o passo 3 aplicado
 — reverta o passo 3 antes". No Reverter, as entradas puladas continuam no
 registro do passo, para reverter depois do passo 3. Ctrl+Z do passo 1/2 por
 cima do passo 3 não passa por aqui (limite conhecido).
================================================================================
*/

-- Nomes do contrato, declarados aqui porque os arquivos dos passos carregam
-- depois deste e o despachante abaixo é compilado antes deles.
global InLab_OtimOrigem_Calcular, InLab_OtimOrigem_Aplicar, InLab_OtimOrigem_Reverter
global InLab_OtimFino_Calcular, InLab_OtimFino_Aplicar, InLab_OtimFino_Reverter, InLab_OtimFino_Comparar
global InLab_OtimEscondidas_Calcular, InLab_OtimEscondidas_Aplicar, InLab_OtimEscondidas_Reverter
global InLab_OtimEscondidas_TemModificador
global InLab_UltimaOtimOrigem, InLab_UltimoAjusteFino

-- Uma linha da lista de revisão. `alvo`/`prop`/`antes`/`depois` descrevem o
-- ajuste (ex.: um TurboSmooth, #iterations, 3, 2); cada passo usa o que precisa.
struct OtimProposta
(
    no,              -- nó da cena que a linha afeta
    rotulo = "",     -- texto da linha na lista
    alvo,            -- objeto que recebe o ajuste (modificador, base object ou o nó)
    prop,            -- propriedade ajustada (#iterations, #VertexPercent...)
    antes,
    depois,
    trisAntes = 0,
    trisDepois = 0,
    motivo = "",
    marcada = true   -- caixa da lista; o Aplicar só usa as marcadas
)

-- Pisos de segurança e pesos (spec 3.2 e 3.3). Cada chave pode ser
-- sobrescrita no InLabChecker.ini como "piso_<chave>=valor".
global INLAB_OTIM_PISOS = #(
    #("turbosmooth", 1), #("meshsmooth", 1), #("opensubdiv", 1), #("nurms", 1),
    #("chamfer", 1), #("shell", 1), #("lathe", 8), #("extrude", 1),
    #("lados", 12), #("alturasegs", 1), #("esfera", 12),
    #("torus_segs", 12), #("torus_lados", 8), #("fillet", 1), #("boxsegs", 1),
    #("spline_passos", 2), #("spline_lados", 6),
    #("dano_subdiv", 2), #("dano_outros", 1),
    #("fino_pct", 60), #("fino_min", 300)
)

-- Meta digitada na tela quando não há família ativa (triângulos).
-- 23/09/2026 (revisão final): SEM inicializador — `global X = undefined`
-- reatribui X toda vez que este arquivo é recarregado (InLab_RecarregarPlugin,
-- ou um fileIn manual), zerando a meta que o usuário tinha digitado. Declarar
-- sem valor não mexe num global que já existe (mesmo padrão de ui\kit.ms).
global INLAB_OTIM_META_MANUAL

global InLab_Otim_Triangulos
fn InLab_Otim_Triangulos objs =
(
    local total = 0
    for o in objs where InLab_EhGeometria o do total += (GetTriMeshFaceCount o)[1]
    total
)

global InLab_Otim_Piso
fn InLab_Otim_Piso chave =
(
    local padrao = undefined
    for p in INLAB_OTIM_PISOS where p[1] == chave do padrao = p[2]
    if padrao == undefined then
    (
        InLab_Log ("Otimização: piso '" + chave + "' não existe na tabela INLAB_OTIM_PISOS.") tipo:#err
        undefined
    )
    else
    (
        local txt = InLab_PrefLer ("piso_" + chave) ""
        if txt == "" then padrao
        else
        (
            local v = txt as float
            if v == undefined or v < 0 then
            (
                InLab_Log ("Otimização: piso_" + chave + "='" + txt + "' no InLabChecker.ini não é um número válido — usando " + padrao as string + ".") tipo:#warn
                padrao
            )
            else v
        )
    )
)

-- #(mínimo, máximo, alvo). Família ativa tem prioridade; sem família, a meta
-- manual vira #(0, meta, meta); sem nenhuma das duas, undefined.
global InLab_Otim_Faixa
fn InLab_Otim_Faixa =
(
    if InLab_FamiliaAtiva != undefined then
        #(InLab_FamiliaAtiva.polyMin, InLab_FamiliaAtiva.polyMax, (InLab_FamiliaAtiva.polyMin + InLab_FamiliaAtiva.polyMax) / 2)
    else if INLAB_OTIM_META_MANUAL != undefined then
        #(0, INLAB_OTIM_META_MANUAL, INLAB_OTIM_META_MANUAL)
    else undefined
)

-- Cor do medidor: #dentro (verde), #perto (até 10% fora, amarelo), #longe
-- (vermelho), #sem (sem faixa).
global InLab_Otim_Estado
fn InLab_Otim_Estado total faixa =
(
    if faixa == undefined then #sem
    else if total >= faixa[1] and total <= faixa[2] then #dentro
    else
    (
        local fora = if total > faixa[2] then ((total - faixa[2]) as float / (amax 1 faixa[2]))
                     else ((faixa[1] - total) as float / (amax 1 faixa[1]))
        if fora <= 0.10 then #perto else #longe
    )
)

-- 182340 → "182.340" (separador de milhar brasileiro).
global InLab_Otim_Milhar
fn InLab_Otim_Milhar n =
(
    local s = (n as integer) as string
    local r = ""
    for i = 1 to s.count do
    (
        r += s[i]
        local resta = s.count - i
        if resta > 0 and (mod resta 3) == 0 do r += "."
    )
    r
)

global InLab_Otim_TextoMedidor
fn InLab_Otim_TextoMedidor total faixa =
(
    local t = "Triângulos: " + (InLab_Otim_Milhar total)
    if faixa == undefined then t + "  ·  escolha a família (seção Produto) ou digite a meta"
    else if faixa[1] == 0 then t + "  ·  meta: " + (InLab_Otim_Milhar faixa[2])
    else t + "  ·  faixa da família: " + (InLab_Otim_Milhar faixa[1]) + " a " + (InLab_Otim_Milhar faixa[2])
)

-- Quanto a SELEÇÃO pode ter para a CENA inteira cair no alvo da faixa.
global InLab_Otim_AlvoSelecao
fn InLab_Otim_AlvoSelecao objs faixa =
(
    if faixa == undefined then undefined
    else
    (
        local cena = InLab_Otim_Triangulos (for o in geometry collect o)
        local sel = InLab_Otim_Triangulos objs
        amax 0 (faixa[3] - (cena - sel))
    )
)

-- Registro de reversão genérico: #(alvo, prop, valorAntes) por alteração.
global InLab_Otim_Guardar
fn InLab_Otim_Guardar registro alvo prop =
(
    append registro #(alvo, prop, getProperty alvo prop)
    registro
)

-- Volta na ORDEM INVERSA: se a mesma propriedade mudou duas vezes, termina no
-- valor mais antigo. Devolve quantas voltaram.
global InLab_Otim_Restaurar
fn InLab_Otim_Restaurar registro =
(
    local n = 0
    for i = registro.count to 1 by -1 do
    (
        local r = registro[i]
        try ( setProperty r[1] r[2] r[3]; n += 1 )
        catch ( InLab_Log ("Otimização: não voltou " + (r[2] as string) + " (" + getCurrentException() + ").") tipo:#err )
    )
    n
)

--------------------------------------------------------------------------------
-- DESPACHANTE: a UI só chama estas três. passo = 1 (origem), 2 (fino), 3 (escondidas).
--------------------------------------------------------------------------------

-- Nó com o passo 3 aplicado? Chamada só em tempo de execução
-- (fn_otim_escondidas.ms carrega depois deste arquivo).
global InLab_Otim_TemPasso3
fn InLab_Otim_TemPasso3 o =
    isValidNode o and InLab_OtimEscondidas_TemModificador != undefined and (InLab_OtimEscondidas_TemModificador o)

-- Nós afetados por um alvo de ajuste (nó, modificador ou objeto base).
global InLab_Otim_NosDoAlvo
fn InLab_Otim_NosDoAlvo alvo =
(
    if alvo == undefined then #()
    else if isValidNode alvo then #(alvo)
    else ( try ( for n in (refs.dependentNodes alvo) where isValidNode n collect n ) catch ( #() ) )
)

-- Primeiro nó com o passo 3 entre `nos`, ou undefined.
global InLab_Otim_Passo3Em
fn InLab_Otim_Passo3Em nos =
(
    local r = undefined
    for n in nos where r == undefined and (InLab_Otim_TemPasso3 n) do r = n
    r
)

global InLab_Otim_AvisarPasso3
fn InLab_Otim_AvisarPasso3 o avisados =
(
    if findItem avisados o == 0 do
    (
        append avisados o
        InLab_Log (o.name + ": tem o passo 3 aplicado — reverta o passo 3 antes.") tipo:#warn
    )
)

-- Tira da lista de objetos os que têm o passo 3 (passos 1 e 2, Calcular).
global InLab_Otim_SemPasso3
fn InLab_Otim_SemPasso3 objs =
(
    local avisados = #()
    local r = #()
    for o in objs do
        if InLab_Otim_TemPasso3 o then InLab_Otim_AvisarPasso3 o avisados else append r o
    r
)
global InLab_Otim_Calcular
fn InLab_Otim_Calcular passo objs =
(
    case passo of
    (
        1: InLab_OtimOrigem_Calcular (InLab_Otim_SemPasso3 objs)
        2: InLab_OtimFino_Calcular (InLab_Otim_SemPasso3 objs)
        3: InLab_OtimEscondidas_Calcular objs
        default: ( InLab_Log ("Otimização: passo " + passo as string + " não existe.") tipo:#err; #() )
    )
)

global InLab_Otim_Aplicar
fn InLab_Otim_Aplicar passo propostas =
(
    -- Passos 1 e 2: linha que mexe numa peça com o passo 3 fica fora.
    if passo == 1 or passo == 2 do
    (
        local avisados = #()
        propostas = for p in propostas collect
        (
            local nos = InLab_Otim_NosDoAlvo p.alvo
            if isValidNode p.no do appendIfUnique nos p.no
            local o3 = InLab_Otim_Passo3Em nos
            if o3 != undefined then ( InLab_Otim_AvisarPasso3 o3 avisados; dontCollect ) else p
        )
    )
    case passo of
    (
        1: InLab_OtimOrigem_Aplicar propostas
        2: InLab_OtimFino_Aplicar propostas
        3: InLab_OtimEscondidas_Aplicar propostas
        default: ( InLab_Log ("Otimização: passo " + passo as string + " não existe.") tipo:#err; 0 )
    )
)

-- Reverter dos passos 1 e 2 sem mexer em peça com o passo 3: as entradas
-- dessas peças saem do registro durante o Reverter e voltam para ele depois
-- (revertidas quando o passo 3 sair).
global InLab_Otim_ReverterSemPasso3
fn InLab_Otim_ReverterSemPasso3 passo =
(
    local reg = if passo == 1 then InLab_UltimaOtimOrigem else InLab_UltimoAjusteFino
    if reg == undefined do reg = #()
    local avisados = #()
    local livres = #(), presos = #()
    for r in reg do
    (
        local nos = if passo == 1 then (InLab_Otim_NosDoAlvo r[1]) else (if isValidNode r.no then (InLab_InstanciasDoNo r.no) else #())
        local o3 = InLab_Otim_Passo3Em nos
        if o3 != undefined then ( InLab_Otim_AvisarPasso3 o3 avisados; append presos r ) else append livres r
    )
    local n = 0
    if presos.count > 0 and livres.count == 0 then
        InLab_Log ("Otimização · passo " + passo as string + ": nada revertido — todas as peças têm o passo 3.") tipo:#warn
    else
    (
        if passo == 1 then ( InLab_UltimaOtimOrigem = livres; n = InLab_OtimOrigem_Reverter() )
        else ( InLab_UltimoAjusteFino = livres; n = InLab_OtimFino_Reverter() )
    )
    if presos.count > 0 do
    (
        if passo == 1 then InLab_UltimaOtimOrigem = presos else InLab_UltimoAjusteFino = presos
    )
    n
)

global InLab_Otim_Reverter
fn InLab_Otim_Reverter passo =
(
    case passo of
    (
        1: InLab_Otim_ReverterSemPasso3 1
        2: InLab_Otim_ReverterSemPasso3 2
        3: InLab_OtimEscondidas_Reverter()
        default: ( InLab_Log ("Otimização: passo " + passo as string + " não existe.") tipo:#err; 0 )
    )
)
