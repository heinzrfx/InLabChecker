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
 o usa. Os objetos fora da seleção que usam esses bitmaps (ou os Triplanares
 abaixo) entram no processamento (log #warn com o nome).

 22/Set (teste do usuário numa cadeira): objeto JÁ COLAPSADO não tinha UVW
 Map no stack e o botão ignorava. Dois casos novos:
 - UV em cm gravado na malha + bitmap em Real-World: UVW_Xform no topo, no
   canal do bitmap, com o mesmo fator. Render idêntico pelo mesmo motivo.
 - CoronaTriplanar (era o caso da cadeira: escala 75 cm, o UV nem era usado):
   vira um UVW Map Box equivalente (medição em InLab_RWF_GizmoTriplanar) e o
   Triplanar sai do material via replaceInstances, ficando o mapa que estava
   dentro dele. O blend das emendas se perde nas superfícies curvas.
 Pegadinhas achadas: "CoronaTriplanar name:..." no construtor dá
 EXCEPTION_ACCESS_VIOLATION (criar sem argumentos e setar depois); o
 .gizmo do Uvwmap só existe depois da 1ª avaliação do nó.

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

-- Definida mais abaixo, usada antes (InLab_RWF_Referencia).
global InLab_RWF_BitmapsRWFora

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
    local fora = InLab_RWF_BitmapsRWFora o.material
    for mtl in (InLab_RWF_MateriaisFolha o.material) do
    (
        local bmps = for b in (InLab_RWF_BitmapsRW (InLab_RWF_MapaDifuso mtl)) where findItem fora b > 0 collect b
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
        local todos = fora
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
-- CoronaTriplanar (22/Set). Projeta pela posição no espaço e ignora o UV.
-- Medido no render (blend 0, caixa girada, antes/depois idêntico):
--   space 0 = objeto, space 1 = mundo; scale = tamanho de um ladrilho;
--   equivale a um UVW Map Box de lado "scale" com o gizmo girado 180° em Z,
--   centrado no pivot (space 0) ou na origem do mundo (space 1), deslocado
--   por −offset. O blend só muda onde a normal é curva (emendas perdem a
--   mistura). Rotação e space 2 (nó de referência) não foram medidos.
--------------------------------------------------------------------------------
fn InLab_RWF_Triplanares mtl =
(
    if mtl == undefined or CoronaTriplanar == undefined then #()
    else getClassInstances CoronaTriplanar target:mtl
)

-- Bitmaps em Real-World fora de qualquer Triplanar (os de dentro não usam UV).
fn InLab_RWF_BitmapsRWFora mtl =
(
    local dentro = #()
    for t in (InLab_RWF_Triplanares mtl) do join dentro (InLab_RWF_BitmapsRW t)
    for b in (InLab_RWF_BitmapsRW mtl) where findItem dentro b == 0 collect b
)

-- true se o objeto tem UV no canal. getMapSupport dá erro com canal >=
-- getNumMaps em vez de devolver false (ver CLAUDE.md).
fn InLab_RWF_TemCanal o canal =
(
    local m = snapshotAsMesh o
    local tem = canal < (meshop.getNumMaps m) and (meshop.getMapSupport m canal)
    delete m
    tem
)

-- Canal de mapa de um bitmap (1 se não souber).
fn InLab_RWF_CanalBitmap m =
(
    if m == undefined then 1
    else if classof m == Bitmaptexture then m.coords.mapChannel
    else if CoronaBitmap != undefined and classof m == CoronaBitmap then m.uvwChannel
    else 1
)

-- Canal que o conteúdo do Triplanar vai ler depois de sair dele.
fn InLab_RWF_CanalTriplanar t =
(
    local canal = 1
    local classes = #(Bitmaptexture)
    if CoronaBitmap != undefined do append classes CoronaBitmap
    local achou = false
    for c in classes while not achou do
    (
        local bs = if t.texmapX == undefined then #() else getClassInstances c target:t.texmapX
        if classof t.texmapX == c do bs = #(t.texmapX)
        if bs.count > 0 do ( canal = InLab_RWF_CanalBitmap bs[1]; achou = true )
    )
    canal
)

-- Gizmo do UVW Box equivalente ao Triplanar, no espaço do objeto.
fn InLab_RWF_GizmoTriplanar t o =
(
    local tm = (rotateZMatrix 180) * (transMatrix (-t.offset))
    if t.space == 1 then tm * (inverse o.objectTransform) else tm
)

-- Triplanar que dá para converter (sem log).
fn InLab_RWF_TriplanarConvertivel t =
(
    (t.space == 0 or t.space == 1) and t.texmapX != undefined
)

-- Idem, logando o motivo quando não dá e os avisos quando dá.
fn InLab_RWF_TriplanarSuportado t =
(
    if t.space != 0 and t.space != 1 then
    (
        InLab_Log (t.name + ": Triplanar em espaço " + t.space as string + " (nó de referência) não é convertido.") tipo:#warn
        false
    )
    else if t.texmapX == undefined then
    (
        InLab_Log (t.name + ": Triplanar sem mapa no X, não é convertido.") tipo:#warn
        false
    )
    else
    (
        if t.Blend > 0.0 do
            InLab_Log (t.name + ": Triplanar com blend " + t.Blend as string + ". Nas partes curvas as emendas perdem a mistura (~1% da imagem no teste).") tipo:#info
        if t.rotation != [0,0,0] do
            InLab_Log (t.name + ": Triplanar com rotação " + t.rotation as string + " não medida; a rotação é ignorada. Conferir.") tipo:#warn
        if not t.onlyTexmapX and (t.texmapY != t.texmapX or t.texmapZ != t.texmapX) do
            InLab_Log (t.name + ": Triplanar com mapas diferentes em Y/Z; fica só o do X.") tipo:#warn
        true
    )
)

--------------------------------------------------------------------------------
-- Entrada do botão. objs = seleção. Devolve o nº de objetos convertidos.
-- Três casos, que podem vir juntos no mesmo objeto:
--   A. UVW Map em Real-World no stack → UVW_Xform logo acima dele.
--   B. objeto colapsado (UV em cm gravado na malha) com bitmap em
--      Real-World no material → UVW_Xform no topo, no canal do bitmap.
--   C. CoronaTriplanar no material → UVW Map Box equivalente no topo, e o
--      Triplanar sai do material (fica o mapa que estava dentro dele).
--------------------------------------------------------------------------------
fn InLab_RealWorldFix objs =
(
    ----------------------------------------------------------------------
    -- 1. Candidatos: geometria com UVW em Real-World, bitmap em
    --    Real-World fora de Triplanar, ou Triplanar suportado no material.
    ----------------------------------------------------------------------
    fn precisa o =
    (
        (InLab_RWF_UVWsRW o).count > 0 or (InLab_RWF_BitmapsRWFora o.material).count > 0 or
        (for t in (InLab_RWF_Triplanares o.material) where InLab_RWF_TriplanarConvertivel t collect t).count > 0
    )
    local alvos = for o in objs where InLab_EhGeometria o and (precisa o) collect o
    local ignorados = objs.count - alvos.count
    if ignorados > 0 do
        InLab_Log ("Real World Fix: " + ignorados as string + " objeto(s) da seleção sem Real-World nem Triplanar, ignorado(s).") tipo:#info

    ----------------------------------------------------------------------
    -- 2. Fecho pelo material: quem mais usa os bitmaps e Triplanares que
    --    vão mudar entra na conversão.
    ----------------------------------------------------------------------
    local bitmaps = #()
    local triplanares = #()
    local i = 1
    while i <= alvos.count do
    (
        local mapas = #()
        for b in (InLab_RWF_BitmapsRWFora alvos[i].material) where findItem bitmaps b == 0 do ( append bitmaps b; append mapas b )
        for t in (InLab_RWF_Triplanares alvos[i].material) where findItem triplanares t == 0 do
        (
            append triplanares t
            if InLab_RWF_TriplanarConvertivel t do append mapas t
        )
        for mp in mapas do
            for n in (refs.dependentNodes mp) where findItem alvos n == 0 do
            (
                if InLab_EhGeometria n then
                (
                    append alvos n
                    InLab_Log (n.name + ": fora da seleção, mas usa " + mp.name + ". Incluído na conversão.") tipo:#warn
                )
                else InLab_Log (n.name + ": usa " + mp.name + " mas não é geometria. Conferir.") tipo:#warn
            )
        i += 1
    )
    local tpOk = for t in triplanares collect (InLab_RWF_TriplanarSuportado t)

    if alvos.count == 0 then
    (
        InLab_Log "Real World Fix: nenhum objeto com Real-World ou Triplanar." tipo:#warn
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
            for b in (InLab_RWF_BitmapsRWFora alvos[k].material) do
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
        local nTp = 0
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
                    local partes = #()
                    local nMods = o.modifiers.count
                    local uvws = InLab_RWF_UVWsRW o
                    local canalRW = 0
                    if refs_[k] != undefined do
                    (
                        local tam = InLab_RWF_TamanhoBitmap refs_[k]
                        local txtTam = (formattedPrint tam.x format:".4g") + " × " + (formattedPrint tam.y format:".4g")
                        if uvws.count > 0 then
                        (
                            -- A. Xform logo acima de cada UVW Map em Real-World
                            for u in uvws do
                            (
                                local idx = 0
                                for iM in 1 to o.modifiers.count where o.modifiers[iM] == u do idx = iM
                                local x = UVW_Xform name:"InLab RWF" U_Tile:(1.0 / tam.x) V_Tile:(1.0 / tam.y) Map_Channel:u.mapChannel
                                if idx > 1 then addModifier o x before:(idx - 1) else addModifier o x
                                canalRW = u.mapChannel
                            )
                            append partes ("UV ÷ " + txtTam + " (referência " + refs_[k].name + ")")
                        )
                        else
                        (
                            -- B. UV já gravado na malha: Xform no topo, no canal do bitmap
                            canalRW = InLab_RWF_CanalBitmap refs_[k]
                            if InLab_RWF_TemCanal o canalRW then
                            (
                                addModifier o (UVW_Xform name:"InLab RWF" U_Tile:(1.0 / tam.x) V_Tile:(1.0 / tam.y) Map_Channel:canalRW)
                                append partes ("UV gravado no canal " + canalRW as string + " ÷ " + txtTam + " (referência " + refs_[k].name + ")")
                            )
                            else
                                InLab_Log (o.name + ": sem UV no canal " + canalRW as string + " para o bitmap " + refs_[k].name +
                                           ". Precisa de mapeamento; nada a dividir.") tipo:#warn
                        )
                    )
                    -- C. Triplanar → UVW Map Box equivalente no topo
                    local tps = for t in (InLab_RWF_Triplanares o.material) where tpOk[findItem triplanares t] collect t
                    if tps.count > 0 do
                    (
                        local t = tps[1]
                        -- difuso e bump costumam ter Triplanares iguais; só avisa se diferem
                        local diferentes = for t2 in tps where t2.scale != t.scale or t2.space != t.space or t2.offset != t.offset collect t2
                        if diferentes.count > 0 do
                            InLab_Log (o.name + ": material com Triplanares de escala/espaço/offset diferentes; o UV segue o " + t.name + ".") tipo:#warn
                        local canal = InLab_RWF_CanalTriplanar t
                        if canal == canalRW do
                            InLab_Log (o.name + ": Triplanar e bitmap em Real-World no mesmo canal " + canal as string +
                                       ". O UV do Triplanar prevalece; conferir o bitmap.") tipo:#warn
                        addModifier o (Uvwmap name:"InLab RWF Triplanar" maptype:4 length:t.scale width:t.scale height:t.scale mapChannel:canal)
                        classof o   -- o gizmo só existe depois da 1ª avaliação
                        o.modifiers[1].gizmo.transform = InLab_RWF_GizmoTriplanar t o
                        append partes ("Triplanar " + t.name + " → Box " + (formattedPrint t.scale format:".4g") + " no canal " + canal as string +
                                       " (espaço " + (if t.space == 1 then "mundo" else "objeto") + ")")
                    )
                    if partes.count == 0 do append partes "sem bitmap em Real-World no material; UV colapsado como estava"
                    local txt = partes[1]
                    for p in 2 to partes.count do txt += " · " + partes[p]
                    convertToMesh o
                    InLab_Log (o.name + ": " + txt + ". Stack de " + nMods as string + " modificador(es) colapsado.") tipo:#ok
                )
                catch
                (
                    ok = false
                    InLab_Log (o.name + ": falhou (" + getCurrentException() + ").") tipo:#err
                    -- tira o que o Real World Fix pôs no stack sem colapsar
                    if isValidNode o do
                        for iM = o.modifiers.count to 1 by -1 where matchPattern o.modifiers[iM].name pattern:"InLab RWF*" do deleteModifier o iM
                )
                if ok then feitos += 1 else
                (
                    join falhos (InLab_RWF_BitmapsRW o.material)
                    join falhos (InLab_RWF_Triplanares o.material)
                )
            )
            -- Triplanar sai do material: quem o referencia passa a usar o mapa
            -- que estava dentro dele (lendo o UV Box que acabou de ser gravado).
            for j in 1 to triplanares.count where tpOk[j] do
            (
                local t = triplanares[j]
                if findItem falhos t > 0 then
                    InLab_Log (t.name + ": Triplanar mantido, um objeto que o usa falhou.") tipo:#err
                else
                (
                    replaceInstances t t.texmapX
                    nTp += 1
                )
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
                   nBitmaps as string + "/" + bitmaps.count as string + " bitmap(s) sem Real-World · " +
                   nTp as string + "/" + triplanares.count as string + " Triplanar(es) removido(s).") tipo:tipoResumo
        feitos
    )
)
