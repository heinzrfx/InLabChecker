/*
 functions\fn_mapear_cortar.ms — Mapear assistido: Cortar e Sentido (feature de 27/10/2026).
 Parte 1 (Tarefa 2): marcas guardadas na peça. O desenhista seleciona arestas de costura na
 base Editable Poly; o plugin guarda as costuras (bitarray de arestas) e as guias de veio
 (aresta + angulo) no proprio no via setAppData, para sobreviverem a salvar e reabrir o .max.
 Formato: costuras = "<nFaces>;<nArestas>;<e1>,<e2>,..." ; guias = "<e>:<ang>;<e>:<ang>"
 (angulo com formattedPrint format:".2f", ponto decimal garantido na gravacao e na leitura).
 Se nFaces/nArestas nao batem com a base (malha mudou), a leitura apaga as marcas e avisa.
 Spec: docs\superpowers\specs\2026-10-27-mapear-assistido-design.md
*/
global INLAB_CORTAR_APPDATA_COSTURAS = 7301
global INLAB_CORTAR_APPDATA_GUIAS = 7302
global InLab_Log

struct InLab_CortarMarcas ( nFaces, nArestas, costuras, guias )

fn InLab_Cortar_TemMarcas o =
(
    (getAppData o INLAB_CORTAR_APPDATA_COSTURAS) != undefined
)

fn InLab_Cortar_ApagarMarcas o =
(
    deleteAppData o INLAB_CORTAR_APPDATA_COSTURAS
    deleteAppData o INLAB_CORTAR_APPDATA_GUIAS
    true
)

fn InLab_Cortar_GravarMarcas o marcas =
(
    local b = o.baseobject
    local nF = polyop.getNumFaces b
    local nE = polyop.getNumEdges b
    local s = nF as string + ";" + nE as string + ";"
    local primeiro = true
    for e in marcas.costuras do
    (
        if not primeiro do s += ","
        s += e as string
        primeiro = false
    )
    setAppData o INLAB_CORTAR_APPDATA_COSTURAS s
    local g = ""
    for k = 1 to marcas.guias.count do
    (
        local a = formattedPrint (marcas.guias[k][2] as float) format:".2f"
        a = substituteString a "," "."
        if k > 1 do g += ";"
        g += (marcas.guias[k][1] as string) + ":" + a
    )
    setAppData o INLAB_CORTAR_APPDATA_GUIAS g
    true
)

fn InLab_Cortar_LerMarcas o =
(
    local sc = getAppData o INLAB_CORTAR_APPDATA_COSTURAS
    if sc == undefined do return undefined
    local b = o.baseobject
    local partes = filterString sc ";"
    local nF = if partes.count >= 1 then (partes[1] as integer) else undefined
    local nE = if partes.count >= 2 then (partes[2] as integer) else undefined
    if nF != polyop.getNumFaces b or nE != polyop.getNumEdges b do
    (
        InLab_Log (o.name + ": a malha mudou desde o último corte; marque as costuras de novo.") tipo:#warn
        InLab_Cortar_ApagarMarcas o
        return undefined
    )
    local cost = #{}
    if partes.count >= 3 do
        for t in (filterString partes[3] ",") do ( local v = t as integer; if v != undefined and v > 0 do cost[v] = true )
    local guias = #()
    local sg = getAppData o INLAB_CORTAR_APPDATA_GUIAS
    if sg != undefined do
        for par in (filterString sg ";") do
        (
            local kv = filterString par ":"
            if kv.count == 2 do
            (
                local ang = (substituteString kv[2] "," ".") as float
                append guias #(kv[1] as integer, ang)
            )
        )
    InLab_CortarMarcas nFaces:nF nArestas:nE costuras:cost guias:guias
)
