/*
 functions\fn_mapear_paineis.ms — Mapear por paineis (feature de 26/10/2026).
 Parte 1 (Tarefa 1): vivos (cordao/viés/debrum) e geometria em MUNDO.
 Spec/plano: docs\superpowers\specs e docs\superpowers\plans (Mapear por paineis);
 logica de referencia no spike docs\superpowers\specs\2026-10-26-spike-paineis.ms.

 Regras:
 - Toda a logica usa coordenadas de MUNDO. polyop.getVert na base devolve espaço
   de OBJETO: InLab_Paineis_Vert multiplica por o.objectTransform.
 - Vivo = elemento fechado, fino (2V/A < 1.5 cm, o raio do tubo) e comprido
   (maior medida > 12 x raio).
 - Nunca polyop.getFacesUsingEdge por aresta (travou o Max 30 min): usa getEdgeFaces.
 - InLab_Paineis_VivosDoProduto: com nos: indefinido varre a geometria sob a mesma
   cabeça de hierarquia de o (a Tarefa 4 restringe as pecas de tecido).
 - Pre-condicao: Vert, VolArea, EhVivo e Elementos exigem no cuja base seja
   Editable_Poly. Sem isso logam #err ("<nome>: base não é Editable_Poly (<classe>)")
   e devolvem valor neutro (Vert undefined, VolArea #(0,0), EhVivo #(false,0,0)).
 - VivosDoProduto avalia nos de base nao-poly (Editable_Mesh, spline renderizavel)
   ou com modificadores por uma copia temporaria em mundo (snapshotAsMesh ->
   Editable_Mesh com transform identidade -> convertToPoly), apagada no fim; malha
   avaliada sem faces: #warn e pula (fix 26/10/2026).
 Pegadinhas: nomes sao case-insensitive (local "a" esconde o parametro "A"); o
 parametro de fn usado dentro de collect em bloco aninhado da "Bad free thunk".
*/
global InLab_Log, InLab_EhGeometria
global InLab_Mapear_PolyDe
global InLab_Paineis_Vert, InLab_Paineis_Elementos, InLab_Paineis_VolArea
global InLab_Paineis_BaseOk, InLab_Paineis_CopiaMundo
global InLab_Paineis_EhVivo, InLab_Paineis_VivosDoProduto, InLab_Paineis_NosDaCabeca

-- base é Editable_Poly? Senão loga #err e devolve false
fn InLab_Paineis_BaseOk o =
(
    local ok = isValidNode o and (classof o.baseobject == Editable_Poly)
    if not ok do
        InLab_Log ((if isValidNode o then o.name else "<nó inválido>") + ": base não é Editable_Poly (" + (if isValidNode o then (classof o.baseobject) as string else "undefined") + ")") tipo:#err
    ok
)

-- cópia temporária em MUNDO (Editable_Poly, transform identidade) da malha avaliada
fn InLab_Paineis_CopiaMundo o =
(
    local c = undefined
    with undo off
    (
        local m = snapshotAsMesh o
        if m.numFaces > 0 do
        (
            c = Editable_Mesh name:(uniqueName "InLab_tmp_paineis")
            c.mesh = m
            update c
            convertToPoly c
        )
        delete m
    )
    c
)

-- vértice v da base de o em coordenadas de mundo
fn InLab_Paineis_Vert o v =
(
    if not (InLab_Paineis_BaseOk o) then undefined
    else (polyop.getVert (InLab_Mapear_PolyDe o) v) * o.objectTransform
)

-- elementos conexos (bitarrays de faces) dentro de faces
fn InLab_Paineis_Elementos po faces =
(
    local resta = copy faces
    local els = #()
    while not resta.isEmpty do
    (
        local f0 = 0
        for f in resta while f0 == 0 do f0 = f
        local el = (polyop.getElementsUsingFace po #{f0}) * faces
        append els el
        resta -= el
    )
    els
)

-- #(volume, area) em MUNDO de um conjunto de faces (fan dos poligonos)
fn InLab_Paineis_VolArea o fs =
(
    if not (InLab_Paineis_BaseOk o) then return #(0.0, 0.0)
    local po = InLab_Mapear_PolyDe o
    local tm = o.objectTransform
    local cache = #()
    local v = 0.0, a = 0.0
    for f in fs do
    (
        local vs = polyop.getFaceVerts po f
        local pts = #()
        for k = 1 to vs.count do
        (
            if cache[vs[k]] == undefined do cache[vs[k]] = (polyop.getVert po vs[k]) * tm
            append pts cache[vs[k]]
        )
        local p0 = pts[1]
        for k = 2 to pts.count - 1 do
        (
            local p1 = pts[k], p2 = pts[k+1]
            v += (dot p0 (cross p1 p2)) / 6.0
            a += (length (cross (p1 - p0) (p2 - p0))) / 2.0
        )
    )
    #(abs v, a)
)

-- #(ehVivo, raio, maiorMedida): fechado, 2V/A < 1.5 cm e maior medida > 12 x raio
fn InLab_Paineis_EhVivo o el =
(
    if not (InLab_Paineis_BaseOk o) then return #(false, 0.0, 0.0)
    local po = InLab_Mapear_PolyDe o
    local va = InLab_Paineis_VolArea o el
    local abertas = ((polyop.getOpenEdges po) * (polyop.getEdgesUsingFace po el)).numberSet
    local mn = [1e9,1e9,1e9], mx = [-1e9,-1e9,-1e9]
    for v in (polyop.getVertsUsingFace po el) do
    (
        local p = InLab_Paineis_Vert o v
        mn = [amin mn.x p.x, amin mn.y p.y, amin mn.z p.z]
        mx = [amax mx.x p.x, amax mx.y p.y, amax mx.z p.z]
    )
    local tam = amax #(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
    local r = if va[2] > 1e-6 then 2.0 * va[1] / va[2] else 0.0
    #(abertas == 0 and va[2] > 1e-6 and r < 1.5 and tam > 12.0 * r, r, tam)
)

-- o nó e todos os descendentes
fn InLab_Paineis_NosDaCabeca cabeca =
(
    local res = #(cabeca)
    local i = 1
    while i <= res.count do
    (
        for c in res[i].children do append res c
        i += 1
    )
    res
)

-- vértices (mundo) dos vivos das peças. nos: lista a varrer; indefinido = toda a
-- geometria sob a cabeça de hierarquia de o (inclusive o). Só varre base Editable_Poly.
fn InLab_Paineis_VivosDoProduto o nos:undefined =
(
    local lista = nos
    if lista == undefined do
    (
        local cabeca = o
        while cabeca.parent != undefined do cabeca = cabeca.parent
        lista = InLab_Paineis_NosDaCabeca cabeca
    )
    local pts = #()
    for n in lista where isValidNode n and (InLab_EhGeometria n) do
    (
        local alvo = n, temp = undefined
        if not (classof n.baseobject == Editable_Poly and n.modifiers.count == 0) do
        (
            temp = InLab_Paineis_CopiaMundo n
            if temp == undefined then
            (
                InLab_Log (n.name + ": malha avaliada sem faces, ignorada nos vivos") tipo:#warn
                alvo = undefined
            )
            else alvo = temp
        )
        if alvo != undefined do
        (
            local po = alvo.baseobject
            local tudo = #{1..(polyop.getNumFaces po)}
            for el in (InLab_Paineis_Elementos po tudo) do
            (
                if (InLab_Paineis_EhVivo alvo el)[1] do
                    for v in (polyop.getVertsUsingFace po el) do append pts (InLab_Paineis_Vert alvo v)
            )
        )
        if temp != undefined do with undo off ( delete temp )
    )
    pts
)
