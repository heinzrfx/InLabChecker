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
================================================================================
*/

-- Nomes do contrato, declarados aqui porque os arquivos dos passos carregam
-- depois deste e o despachante abaixo é compilado antes deles.
global InLab_OtimOrigem_Calcular, InLab_OtimOrigem_Aplicar, InLab_OtimOrigem_Reverter
global InLab_OtimFino_Calcular, InLab_OtimFino_Aplicar, InLab_OtimFino_Reverter, InLab_OtimFino_Comparar
global InLab_OtimEscondidas_Calcular, InLab_OtimEscondidas_Aplicar, InLab_OtimEscondidas_Reverter

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
global INLAB_OTIM_META_MANUAL = undefined

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
