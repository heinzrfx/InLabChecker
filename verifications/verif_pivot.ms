/*
================================================================================
 verifications\verif_pivot.ms — V-17/18 (raiz) · [V-27/28/28b/31/32/32b: Grupo 4]
--------------------------------------------------------------------------------
 Pivôs. Nesta entrega: pivot raiz na base/centro (V-17) e eixos sem rotação
 residual (V-18). Os pivôs de ANIMAÇÃO por tipo de movimento (tabela seção 4
 da spec) entram no Grupo 4.

 23/09/2026: raiz = nó do topo da hierarquia (issue #30: produto agrupado
 passava sem checar nada) e tolerância de ±1 mm de verdade (issue #31: era
 ±1 unidade do sistema = ±1 cm). Sem raiz nenhuma, V-17/V-18 não dão PASS.
 04/11/2026 (mesa Berriz 00124600): com "animacao": true no JSON, a raiz que
 é uma mesh animada (toda mesh do produto fora a do cod_est e as variantes,
 ex.: 00124600_Prato_Giratorio) fica fora da V-17: o pivot dela é o do
 movimento. A V-18 continua valendo para ela.
================================================================================
*/

-- Raízes = nós do TOPO da hierarquia de cada geometria (subindo por
-- .parent), sem repetir. Pode ser a própria geometria (objeto solto) ou um
-- helper: cabeça de grupo, Dummy, Point. É o nó que o glTF exporta como raiz.
-- 23/09/2026 (issue #30): antes eram só as geometrias com parent undefined.
-- Num produto agrupado a lista ficava VAZIA e V-17/V-18 davam PASS sem checar
-- nada ("0 raiz(es) OK") — reproduzido no Max 2024.
fn InLab_RaizesGeometria objetos =
(
    local raizes = #()
    for o in objetos do
    (
        local topo = o
        while topo.parent != undefined do topo = topo.parent
        appendIfUnique raizes topo
    )
    raizes
)

-- Bounding box [min, max] das geometrias de `objetos` que descendem de `raiz`
-- (ou são ela). A de uma cabeça de grupo não serve: .min/.max de um Dummy é
-- a caixinha do próprio helper, não a do produto (medido no Max 2024).
fn InLab_BBoxDaRaiz raiz objetos =
(
    local bMin = undefined
    local bMax = undefined
    for o in objetos do
    (
        local topo = o
        while topo.parent != undefined do topo = topo.parent
        if topo == raiz do
        (
            if bMin == undefined then ( bMin = copy o.min; bMax = copy o.max )
            else
            (
                bMin = [amin bMin.x o.min.x, amin bMin.y o.min.y, amin bMin.z o.min.z]
                bMax = [amax bMax.x o.max.x, amax bMax.y o.max.y, amax bMax.z o.max.z]
            )
        )
    )
    #(bMin, bMax)
)

-- 04/11/2026 (mesa Berriz 00124600, prato giratório): fn_renomear_produto.ms.
global InLab_Produto_Booleano, InLab_Produto_MeshesDoProduto, InLab_Produto_Variantes
global InLab_Produto_Texto

-- Nomes (minúsculos) das meshes ANIMADAS do produto: com "animacao": true no
-- JSON, toda mesh do produto que não é a principal (cod_est) nem variante de
-- posição. É a peça que a spec manda separar para animar (prato giratório,
-- codEst_Porta_1...). Sem produto ou sem animação: vazio.
fn InLab_Pivot_MeshesAnimadas produto =
(
    local nomes = #()
    if produto != undefined and InLab_Produto_Booleano != undefined and (InLab_Produto_Booleano produto "animacao") do
    (
        local principais = #(toLower (InLab_Produto_Texto produto "cod_est"))
        for v in (InLab_Produto_Variantes produto) do append principais (toLower v)
        for n in (InLab_Produto_MeshesDoProduto produto) where (findItem principais (toLower n)) == 0 do
            appendIfUnique nomes (toLower n)
    )
    nomes
)

-- true se a raiz é uma peça animada: ela mesma, ou todas as geometrias embaixo
-- dela, têm o nome de uma mesh animada.
fn InLab_Pivot_RaizAnimada raiz objetos animadas =
(
    if animadas.count == 0 then false
    else if (findItem animadas (toLower raiz.name)) > 0 then true
    else
    (
        local nGeos = 0
        local todas = true
        for o in objetos do
        (
            local topo = o
            while topo.parent != undefined do topo = topo.parent
            if topo == raiz do
            (
                nGeos += 1
                if (findItem animadas (toLower o.name)) == 0 do todas = false
            )
        )
        nGeos > 0 and todas
    )
)

-- V-17 · Pivot da raiz em Z=0 do MUNDO e centrado em XY no bbox do produto.
-- Tolerância: ±1 mm FIXO (spec), convertido para a unidade do sistema.
-- 23/09/2026 (issue #31): era `tol = 1.0` em UNIDADES DO SISTEMA — com a cena
-- em cm (a V-19 exige), ±1 cm. Pivot 5 mm acima passava. A mensagem também
-- dizia "mm" num valor em unidade do sistema.
-- 04/11/2026 (mesa Berriz 00124600): a peça animada fica separada (raiz
-- própria) e o pivot dela é o do movimento, fora do chão: o prato giratório
-- reprovava com "Z +701.0 mm do chão". Com o produto do JSON marcado
-- "animacao": true, raiz que é mesh animada (InLab_Pivot_MeshesAnimadas) fica
-- fora da V-17 (Z e XY: a porta gira na dobradiça, fora do centro) e é citada
-- na mensagem. O pivot de animação é do Grupo 4 (#117). A raiz principal
-- continua conferida. Sem produto carregado, tudo é conferido como antes.
fn InLab_V17_PivotRaiz objetos produto:undefined =
(
    local raizes = InLab_RaizesGeometria objetos
    local animadas = InLab_Pivot_MeshesAnimadas produto
    local puladas = #()
    local problemas = #()
    local mm = units.decodeValue "1mm"   -- 1 mm na unidade do sistema (cm → 0.1)
    local tol = mm
    fn emMM v mm = (if v >= 0 then "+" else "") + (formattedPrint (v / mm) format:".1f") + " mm"
    for o in raizes do
    if InLab_Pivot_RaizAnimada o objetos animadas then append puladas o.name
    else
    (
        local bb = InLab_BBoxDaRaiz o objetos
        local cx = (bb[1].x + bb[2].x) / 2.0
        local cy = (bb[1].y + bb[2].y) / 2.0
        local dz = o.pivot.z
        local dx = o.pivot.x - cx
        local dy = o.pivot.y - cy
        local desvios = #()
        if (abs dz) > tol do
            append desvios ("Z " + (emMM dz mm) + " do chão" +
                            (if (abs (o.pivot.z - bb[1].z)) <= tol then " (pivot na base, mas o produto flutua)" else ""))
        if (abs dx) > tol do append desvios ("X " + (emMM dx mm) + " do centro")
        if (abs dy) > tol do append desvios ("Y " + (emMM dy mm) + " do centro")
        if desvios.count > 0 do
        (
            local txt = o.name + ":"
            for d in desvios do txt += " " + d + ";"
            append problemas txt
        )
    )

    local msg = if raizes.count == 0 then "nenhuma raiz encontrada — nada verificado"
                else if problemas.count == 0 then ((raizes.count - puladas.count) as string + " raiz(es) OK")
                else (problemas as string)
    if puladas.count > 0 do
    (
        msg += " · peça animada fora (pivot de animação):"
        for n in puladas do msg += " " + n
    )
    InLab_RegistrarVerif "V-17" "Pivot raiz em Z=0 (mundo), centrado em XY" (raizes.count > 0 and problemas.count == 0) msg critico:true
)

-- V-18 · Eixos do pivot alinhados ao mundo (sem rotação residual no nó).
-- Ângulo do quaternion de rotação deve ser ~0° (tolerância 0.5°).
-- Nota: acos() do MaxScript retorna GRAUS.
fn InLab_V18_EixosPivot objetos =
(
    local problemas = #()
    local raizes = InLab_RaizesGeometria objetos
    for o in raizes do
    (
        local w = abs o.rotation.w
        if w > 1.0 do w = 1.0
        local anguloGraus = 2.0 * (acos w)
        if anguloGraus > 0.5 do append problemas (o.name + " rot:" + (formattedPrint anguloGraus format:".2f") + "°")
    )
    local msg = if raizes.count == 0 then "nenhuma raiz encontrada — nada verificado"
                else if problemas.count == 0 then "sem rotação residual nas raízes"
                else (problemas as string)
    InLab_RegistrarVerif "V-18" "Eixos do pivot alinhados ao mundo" (raizes.count > 0 and problemas.count == 0) msg critico:true
)