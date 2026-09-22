/*
================================================================================
 functions\fn_realworldfix.ms — "Real World Fix" (22/Set)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Tira o Real-World Map Size dos objetos selecionados sem mudar o visual da
 textura. O WebGL (glTF) não entende mapeamento real-world: o UV precisa
 sair da malha já na escala da textura.

 COMO O REAL-WORLD FUNCIONA NO MAX (medido em 22/Set):
 - UVW Map com Real-World: UV = posição ÷ tamanho do gizmo, centrado em 0.
   No uso normal o gizmo fica 1×1×1 e o UV sai em cm.
 - Bitmap com Real-World (CoronaBitmap.uvwScale / Bitmaptexture
   realWorldWidth/Height): a textura repete a cada "tamanho" de UV, e o
   offset é contado em unidades de cena.

 A CONVERSÃO (render do Corona antes/depois idêntico, diferença de 0,001):
 1. UVW_Xform logo acima de cada UVW Map em Real-World, com
    U_Tile = 1/largura e V_Tile = 1/altura do bitmap de referência. Escala o
    UV em torno de 0, sem laço em MaxScript, e preserva o tipo de mapeamento
    e o gizmo originais.
 2. Colapsa o stack inteiro em Editable_mesh (decisão do usuário). Mesh e não
    poly: converter para poly retriangula tampas de primitiva (ver
    fn_autouv.ms).
 3. Nos bitmaps: Real-World desligado, escala 1 e offset ÷ tamanho de
    referência. Deixar o offset em cm (como faz o ArchToolz) desloca a
    textura.

 REFERÊNCIA = bitmap em Real-World do slot de difuso/base color. Os outros
 bitmaps em Real-World do material voltam para escala 1 e passam a repetir
 no tamanho da referência (decisão do usuário, igual ao ArchToolz); quando o
 tamanho deles era outro, o log avisa.

 MATERIAL COMPARTILHADO: desligar o Real-World de um bitmap quebra quem mais
 o usa. Os objetos fora da seleção que usam esses bitmaps e também têm UVW
 Map em Real-World entram no processamento (log #warn com o nome). Os que usam
 sem UVW em Real-World só geram aviso.

 Sem botão de reverter (decisão do usuário): o undo do Max cobre.

 ENGENHARIA REVERSA DO ARCHTOOLZ (Bake Rendermap > Real World Fix), por
 comparação de estado antes/depois, 22/Set:
 - troca o mapeamento por um Box de gizmo = tamanho do Bitmaptexture nativo
   (ignora os CoronaBitmap e o tipo original, ex.: Planar vira Box);
 - colapsa em Editable_mesh; desliga o Real-World e zera a escala de todos os
   bitmaps; mantém o offset em cm.
 Resultado: desloca a textura em meio tile e erra o offset. Por isso a
 conversão aqui é própria, não uma cópia.
================================================================================
*/

-- Slots de difuso/base color, em ordem de tentativa (Corona Physical,
-- Corona Legacy, Physical Material, Standard).
global INLAB_RWF_SLOTS_DIFUSO = #(#baseTexmap, #texmapDiffuse, #base_color_map, #diffuseMap)

--------------------------------------------------------------------------------
-- Bitmap em Real-World? Cobre CoronaBitmap e Bitmaptexture. Ler uma classe
-- inexistente em MaxScript devolve undefined, então sem Corona o teste da
-- classe simplesmente não bate.
--------------------------------------------------------------------------------
fn InLab_RWF_EhBitmapRW m =
(
    if m == undefined then false
    else if CoronaBitmap != undefined and classof m == CoronaBitmap then m.realWorldScale
    else if classof m == Bitmaptexture then m.coords.realWorldScale
    else false
)

-- Tamanho real [largura, altura] em unidades de cena.
fn InLab_RWF_TamanhoBitmap m =
(
    if classof m == Bitmaptexture then point2 m.coords.realWorldWidth m.coords.realWorldHeight
    else point2 m.uvwScale.x m.uvwScale.y
)

-- Bitmaps em Real-World dentro de um material ou mapa (inclusive aninhados).
fn InLab_RWF_BitmapsRW alvo =
(
    local res = #()
    if alvo != undefined do
    (
        if InLab_RWF_EhBitmapRW alvo do append res alvo
        local classes = #(Bitmaptexture)
        if CoronaBitmap != undefined do append classes CoronaBitmap
        for c in classes do
            for m in (getClassInstances c target:alvo) where InLab_RWF_EhBitmapRW m do appendIfUnique res m
    )
    res
)

-- Materiais-folha (abre Multi/Sub-Object recursivamente).
fn InLab_RWF_MateriaisFolha mtl =
(
    local res = #()
    if mtl != undefined do
    (
        if classof mtl == Multimaterial then
            for sub in mtl.materialList where sub != undefined do join res (InLab_RWF_MateriaisFolha sub)
        else append res mtl
    )
    res
)

-- Mapa do slot de difuso, ou undefined.
fn InLab_RWF_MapaDifuso mtl =
(
    local mapa = undefined
    for p in INLAB_RWF_SLOTS_DIFUSO while mapa == undefined do
        if hasProperty mtl p do mapa = getProperty mtl p
    mapa
)

-- UVW Maps ativos em Real-World no stack (canal de mapa, não vertex color).
fn InLab_RWF_UVWsRW o =
(
    for m in o.modifiers where classof m == Uvwmap and m.enabled and m.realWorldMapSize and m.channel == 0 collect m
)

--------------------------------------------------------------------------------
-- Bitmap de referência do objeto: o 1º bitmap em Real-World dentro do
-- difuso. Sem difuso em Real-World, o 1º bitmap em Real-World do material
-- (com aviso). Devolve undefined se o material não tem nenhum.
--------------------------------------------------------------------------------
fn InLab_RWF_Referencia o =
(
    local ref = undefined
    local tamanhos = #()
    for mtl in (InLab_RWF_MateriaisFolha o.material) do
    (
        local bmps = InLab_RWF_BitmapsRW (InLab_RWF_MapaDifuso mtl)
        if bmps.count > 0 do
        (
            if ref == undefined do ref = bmps[1]
            appendIfUnique tamanhos (InLab_RWF_TamanhoBitmap bmps[1])
        )
    )
    if tamanhos.count > 1 do
        InLab_Log (o.name + ": os sub-materiais têm difusos com tamanhos reais diferentes " + tamanhos as string +
                   ". Um canal UV só comporta um: usando " + ref.name + ".") tipo:#warn
    if ref == undefined do
    (
        local todos = InLab_RWF_BitmapsRW o.material
        if todos.count > 0 do
        (
            ref = todos[1]
            InLab_Log (o.name + ": difuso sem Real-World. Referência: " + ref.name + ".") tipo:#warn
        )
    )
    ref
)

--------------------------------------------------------------------------------
-- Converte um bitmap para UV 0-1: desliga o Real-World, escala 1 e offset
-- dividido pelo tamanho de referência (medido no render, ver cabeçalho).
--------------------------------------------------------------------------------
fn InLab_RWF_ConverterBitmap m tam =
(
    local proprio = InLab_RWF_TamanhoBitmap m
    if (abs (proprio.x - tam.x) > 0.001) or (abs (proprio.y - tam.y) > 0.001) do
        InLab_Log (m.name + ": tamanho real " + proprio as string + " diferente da referência " + tam as string +
                   ". Passa a repetir no tamanho da referência.") tipo:#warn
    if classof m == Bitmaptexture then
    (
        local c = m.coords
        if c.W_angle != 0.0 do InLab_Log (m.name + ": tem rotação (" + c.W_angle as string + "°). Conferir o resultado.") tipo:#warn
        c.realWorldScale = false
        c.U_Tiling = 1.0
        c.V_Tiling = 1.0
        c.U_Offset = c.U_Offset / tam.x
        c.V_Offset = c.V_Offset / tam.y
    )
    else
    (
        if m.wAngle != 0.0 do InLab_Log (m.name + ": tem rotação (" + m.wAngle as string + "°). Conferir o resultado.") tipo:#warn
        local ofs = m.uvwOffset
        m.realWorldScale = false
        m.uvwScale = [1, 1, 1]
        m.uvwOffset = point3 (ofs.x / tam.x) (ofs.y / tam.y) ofs.z
    )
)

--------------------------------------------------------------------------------
-- Entrada do botão. objs = seleção. Devolve o nº de objetos convertidos.
--------------------------------------------------------------------------------
fn InLab_RealWorldFix objs =
(
    ----------------------------------------------------------------------
    -- 1. Candidatos: geometria com UVW Map ativo em Real-World.
    ----------------------------------------------------------------------
    local alvos = for o in objs where InLab_EhGeometria o and (InLab_RWF_UVWsRW o).count > 0 collect o
    local ignorados = objs.count - alvos.count
    if ignorados > 0 do
        InLab_Log ("Real World Fix: " + ignorados as string + " objeto(s) da seleção sem UVW Map em Real-World, ignorado(s).") tipo:#info

    ----------------------------------------------------------------------
    -- 2. Fecho pelo material: quem mais usa os bitmaps que vão mudar.
    ----------------------------------------------------------------------
    local bitmaps = #()
    local semRW = #()
    local i = 1
    while i <= alvos.count do
    (
        for b in (InLab_RWF_BitmapsRW alvos[i].material) where findItem bitmaps b == 0 do
        (
            append bitmaps b
            for n in (refs.dependentNodes b) where findItem alvos n == 0 do
            (
                if InLab_EhGeometria n and (InLab_RWF_UVWsRW n).count > 0 then
                (
                    append alvos n
                    InLab_Log (n.name + ": fora da seleção, mas usa " + b.name + ". Incluído na conversão.") tipo:#warn
                )
                else appendIfUnique semRW n
            )
        )
        i += 1
    )
    for n in semRW do
        InLab_Log (n.name + ": usa bitmap em Real-World sem UVW Map em Real-World. A textura dele vai mudar de escala.") tipo:#warn

    if alvos.count == 0 then
    (
        InLab_Log "Real World Fix: nenhum objeto com UVW Map em Real-World." tipo:#warn
        0
    )
    else
    (
        --------------------------------------------------------------------
        -- 3. Referência de cada objeto e de cada bitmap.
        --------------------------------------------------------------------
        local refs_ = for o in alvos collect (InLab_RWF_Referencia o)
        local tamBitmap = for b in bitmaps collect undefined
        for k in 1 to alvos.count where refs_[k] != undefined do
        (
            local tam = InLab_RWF_TamanhoBitmap refs_[k]
            for b in (InLab_RWF_BitmapsRW alvos[k].material) do
            (
                local j = findItem bitmaps b
                if tamBitmap[j] == undefined then tamBitmap[j] = tam
                else if tamBitmap[j] != tam do
                    InLab_Log (b.name + ": usado por objetos com referências diferentes (" + tamBitmap[j] as string +
                               " e " + tam as string + "). Offset convertido pela primeira.") tipo:#warn
            )
        )

        --------------------------------------------------------------------
        -- 4. Conversão.
        --------------------------------------------------------------------
        local feitos = 0
        local falhos = #()   -- bitmaps dos objetos que falharam
        local nBitmaps = 0
        undo "InLab Real World Fix" on
        (
            for k in 1 to alvos.count do
            (
                local o = alvos[k]
                local ok = true
                try
                (
                    if (InLab_Instancias o).count > 1 do
                    (
                        InstanceMgr.MakeObjectsUnique o #individual
                        InLab_Log (o.name + ": era instância. Ficou único para colapsar.") tipo:#warn
                    )
                    local txt = ""
                    if refs_[k] != undefined then
                    (
                        local tam = InLab_RWF_TamanhoBitmap refs_[k]
                        for u in (InLab_RWF_UVWsRW o) do
                        (
                            local idx = 0
                            for iM in 1 to o.modifiers.count where o.modifiers[iM] == u do idx = iM
                            local x = UVW_Xform name:"InLab RWF" U_Tile:(1.0 / tam.x) V_Tile:(1.0 / tam.y) Map_Channel:u.mapChannel
                            if idx > 1 then addModifier o x before:(idx - 1) else addModifier o x
                        )
                        txt = "UV ÷ " + (formattedPrint tam.x format:".4g") + " × " + (formattedPrint tam.y format:".4g") +
                              " (referência " + refs_[k].name + ")"
                    )
                    else txt = "sem bitmap em Real-World no material; UV colapsado como estava"
                    local nMods = o.modifiers.count
                    convertToMesh o
                    InLab_Log (o.name + ": " + txt + ". Stack de " + nMods as string + " modificador(es) colapsado.") tipo:#ok
                )
                catch
                (
                    ok = false
                    InLab_Log (o.name + ": falhou (" + getCurrentException() + ").") tipo:#err
                    -- tira o Xform que ficou no stack sem colapsar
                    if isValidNode o do
                        for iM = o.modifiers.count to 1 by -1 where o.modifiers[iM].name == "InLab RWF" do deleteModifier o iM
                )
                if ok then feitos += 1 else join falhos (InLab_RWF_BitmapsRW o.material)
            )
            -- Bitmap de objeto que falhou fica em Real-World: o UV dele não mudou.
            for j in 1 to bitmaps.count do
            (
                if findItem falhos bitmaps[j] > 0 then
                    InLab_Log (bitmaps[j].name + ": Real-World mantido, um objeto que o usa falhou.") tipo:#err
                else if tamBitmap[j] != undefined then
                (
                    InLab_RWF_ConverterBitmap bitmaps[j] tamBitmap[j]
                    nBitmaps += 1
                )
                else InLab_Log (bitmaps[j].name + ": sem referência, Real-World mantido.") tipo:#warn
            )
        )
        local tipoResumo = if feitos == alvos.count then #ok else #warn
        InLab_Log ("Real World Fix: " + feitos as string + "/" + alvos.count as string + " objeto(s) convertido(s) · " +
                   nBitmaps as string + "/" + bitmaps.count as string + " bitmap(s) sem Real-World.") tipo:tipoResumo
        feitos
    )
)
